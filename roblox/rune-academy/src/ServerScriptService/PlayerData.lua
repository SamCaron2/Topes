-- Owns each player's save data: load on join, autosave on interval, save on leave.
-- Keep this the single source of truth other server scripts read/write through -
-- never let two scripts touch DataStore for the same player independently.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

-- GetDataStore() itself throws (not just Get/SetAsync) when API access isn't
-- available - an unpublished Studio place, or a published one with "Enable
-- Studio Access to API Services" left off under Game Settings > Security.
-- Without this pcall that throw happens at module-load time, outside any
-- function we control, and takes down every script that requires PlayerData
-- with it. Falling back to nil here means Studio testing works out of the
-- box with no persistence, instead of refusing to run at all.
local SAVE_STORE
do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("RuneAcademy_PlayerData_v1")
	end)
	if success then
		SAVE_STORE = result
	else
		warn(
			"RuneAcademy: DataStores unavailable (enable 'Studio Access to API Services' under Game Settings > Security, and publish the place, to test saving). Progress will not persist between Play sessions until then."
		)
	end
end

local AUTOSAVE_INTERVAL = 120

local PlayerData = {}
local sessions = {} -- [player] = dataTable

local function defaultData()
	local stats = {}
	for statName, statInfo in GameConfig.Stats do
		stats[statName] = statInfo.base
	end

	return {
		-- Mana + the 4 fields below all get reset to these same defaults by
		-- RebirthHandler.rebirth() - keep that function's reset list in sync
		-- if any of these are renamed or a new Mana-side upgrade is added.
		mana = 0, -- collected from ManaNodes on the ground
		manaYieldLevel = 1, -- "Mana Per Pickup" upgrade level, 1-100, +1 Mana per pickup per level
		manaSpawnSpeedLevel = 1, -- "Mana Spawn Speed" upgrade level, 1-10, faster ManaNode respawns per level
		walkSpeedLevel = 1, -- "Walking Speed" upgrade level, 1-10, 1x-3x Humanoid.WalkSpeed
		collectionRangeLevel = 1, -- "Collection Range" upgrade level, 1-12, grows the auto-collect radius

		rebirths = 0, -- permanent currency from resetting Mana; fractional (1000 Mana = 1.0 Rebirth exactly)
		manaValueMultiplierLevel = 1, -- Rebirth Shop: "Mana Value Multiplier", 1-100, 1x-200x - NOT reset by rebirthing
		rebirthMultiplierLevel = 1, -- Rebirth Shop: "Rebirth Multiplier", 1-100, 1x-50x - NOT reset by rebirthing
		xpMultiplierLevel = 1, -- Rebirth Shop: "XP Multiplier", 1-25, boosts XP per pickup - NOT reset by rebirthing

		level = 1, -- XP level, 1-50 - a separate progression track, NOT reset by rebirthing
		xp = 0, -- current XP progress toward the next level

		secondIslandUnlocked = false, -- true once the player presses SecondIslandGate's Unlock button (SecondIslandHandler.unlock, which SPENDS the Mana/Rebirths requirement); permanent once set

		totalManaEarned = 0, -- lifetime Mana ever collected, NOT reset by rebirthing (unlike the live `mana` balance above) - feeds the "Total Mana" leaderboard

		arcaneDust = 0, -- second wizard resource, collected from ArcaneDustNodes; entirely separate from Mana/Rebirths, NOT reset by rebirthing
		arcaneDustYieldLevel = 1, -- "More Arcane Dust" upgrade level, 1-100
		arcaneDustSpawnSpeedLevel = 1, -- "Arcane Dust Spawn Speed" upgrade level, 1-10
		manaBoostLevel = 1, -- "More Mana" upgrade level, 1-50, paid in Arcane Dust (ManaBoostHandler); NOT reset by rebirthing

		-- Wizard Tiers: a deeper prestige layer than Rebirths (WizardTierHandler).
		-- Buying a tier wipes every field above this comment back to its
		-- default (except totalManaEarned, a lifetime stat) AND the four
		-- Rebirth Shop multiplier levels right below - but leaves
		-- secondIslandUnlocked and wizardTier itself alone, per direct
		-- request ("the entire lobby thus far resets except for the locked
		-- door that stays open"). Keep WizardTierHandler.buyNextTier's reset
		-- list in sync if any of these are renamed or a new upgrade is added.
		wizardTier = 0, -- count of Wizard Tiers purchased so far; permanent, never reset

		-- The ground upgrade tree (UpgradeTreeHandler): walk-over tiles, only
		-- reachable once wizardTier >= 3, each a one-time purchase (not a
		-- leveled upgrade) paid in Arcane Dust. The full 1-2-3-2-1 diamond
		-- chain, extending outward from Tile 1: Tile 1 (Dust x2) -> Tiles
		-- 2-3 (Mana x2, XP x2) -> Tiles 4-6 (Rebirths x2, Rune Bulk x2,
		-- Dust x2) -> Tiles 7-8 (Mana x2, Rebirths x2) -> Tile 9 (unlocks
		-- Ether, the next wizard resource - not built yet). Named per-tile
		-- (not a table) so each just needs a plain boolean here; see
		-- UpgradeTreeHandler.TILES for what each one actually does.
		dustTreeTile1 = false,
		dustTreeTile2 = false,
		dustTreeTile3 = false,
		dustTreeTile4 = false,
		dustTreeTile5 = false,
		dustTreeTile6 = false,
		dustTreeTile7 = false,
		dustTreeTile8 = false,
		dustTreeTile9 = false, -- also doubles as "has this player unlocked Ether"

		-- Ether: the third wizard resource, unlocked only once dustTreeTile9
		-- is bought (EtherHandler). Click-collected (a shroud with a
		-- ClickDetector, not auto-collected like Mana/walked-over like
		-- Arcane Dust), per direct request - deliberately slower-paced than
		-- the other two currencies. Its own 4-column board: "More Ether"
		-- (etherYieldLevel, 1-100, paid in Ether), "Click Speed"
		-- (etherClickSpeedLevel, 1-10, paid in Ether), "More Dust"
		-- (etherDustBoostLevel, 1-50, paid in Ether - boosts Arcane Dust
		-- yield, mirroring ManaBoostHandler's own Dust-funded Mana boost),
		-- and "Auto Click" (etherAutoClickUnlocked, EtherAutoClickHandler -
		-- a single one-time purchase, not a leveled upgrade, per direct
		-- request "a 1 time upgrade that gives you auto click on the
		-- ether" - once bought, a background loop collects Ether for this
		-- player automatically at the same rate manual clicks already use,
		-- no more clicking the Shroud required). Permanent like the
		-- Upgrade Tree itself - not reset by anything.
		ether = 0,
		etherYieldLevel = 1,
		etherClickSpeedLevel = 1,
		etherDustBoostLevel = 1,
		etherAutoClickUnlocked = false,

		-- EtherIsland: a third island bridged from SecondIsland, gated behind
		-- an Ether threshold instead of Mana/Rebirths/Level (EtherIslandHandler)
		-- - same explicit Unlock-button-that-actually-spends-the-requirement
		-- pattern as secondIslandUnlocked below, just Ether-only. Permanent
		-- once set.
		etherIslandUnlocked = false,

		-- Ley Shard: the first of a planned 3-material progression built on
		-- EtherIsland (this game's own wizard-flavored equivalent of a
		-- Bronze/Silver/Gold ladder - per direct request, "instead of doing
		-- bronze silver and gold I want to do something wizard"; naming is my
		-- own call). Collected passively while levitating above the Ley
		-- Shard Mat (LeyShardHandler), NOT walked-over/clicked-once like
		-- every earlier resource - a click toggles levitation, then a tick
		-- pays out every leyShardSpeedLevel-determined interval (1.1s at
		-- level 1) for as long as the player stays levitating. Its own
		-- 3-column board: "More Ley Shard" (leyShardYieldLevel, 1-100, paid
		-- in Ley Shard), "Faster Levitation" (leyShardSpeedLevel, 1-10, paid
		-- in Ley Shard), and "More Mana" (leyShardManaBoostLevel, 1-50, a
		-- flat Mana Per Pickup multiplier paid in Ley Shard, mirroring
		-- ManaBoostHandler's own Dust-funded column). Permanent, never reset.
		leyShard = 0,
		leyShardYieldLevel = 1,
		leyShardSpeedLevel = 1,
		leyShardManaBoostLevel = 1,

		-- Astral Shard: Card 2 of the 3-material progression, sitting next
		-- to the Ley Shard board on EtherIsland - per direct request ("to
		-- the right of ley shards we want another material card"). Unlike
		-- Ley Shard, it has NO collection mechanic of its own ("there isnt
		-- a button or anything to get more of this material") - the only
		-- way to get it is spending Ley Shard on the conversion board next
		-- to it (AstralShardConversionHandler), 1,000 Ley Shard per unit
		-- (lowered from an original 5,000). Converting is also the
		-- deliberate "prestige" trigger this whole 2-card system is built
		-- around - per direct request ("when you exchange them it totally
		-- resets your ley shard upgrades all 3") - every conversion wipes
		-- leyShardYieldLevel/leyShardSpeedLevel/leyShardManaBoostLevel
		-- above back to 1, but leaves everything below completely alone,
		-- so a permanent boost survives every reset and makes each later
		-- grind back up the Ley Shard board faster than the last. Permanent,
		-- never reset.
		astralShard = 0,
		astralShardLeyBoostLevel = 1, -- Card 2's "More Ley Shard" (AstralShardLeyBoostHandler), 1-50, a flat Ley Shard yield multiplier paid in Astral Shard
		astralConversionBoostLevel = 1, -- Card 2's "More Astral Shards" (AstralShardConversionBoostHandler), 1-50, boosts how many Astral Shard each conversion grants

		-- EtherIsland's own walk-over floor tiles, paid in Ley Shard - same
		-- one-time-purchase mechanic as the SecondIsland Upgrade Tree's own
		-- tiles (LeyShardFloorTileHandler), per direct request ("x107 z134
		-- start a floor tile upgrade. Lets do for 1k ley shards times your
		-- ley by 2" for Tile 1; "Now two more floor tiles above that is one
		-- for times 2 ley shrouds and 2x astra shrouds. Make them cost a
		-- decent amount" for Tiles 2-3, each requiring the one before it).
		-- Boolean flags, not levels - once bought, permanent, NOT reset by
		-- converting Ley Shard into Astral Shard. Tiles 4-5 (per direct
		-- follow-up request, "Please do a fourth and fith tile... cost 5
		-- million astra shards and that unlocks the third upgrade car[d]...
		-- Then the 5th tile... cost 1million ley shards and that will
		-- unlock Auto Ley shards") double as unlock flags too, same
		-- convention as dustTreeTile9 below: leyShardFloorTile4 also means
		-- "has this player unlocked Celestial Shard" (Card 3), and
		-- leyShardFloorTile5 also means "has Auto Ley Shard" (auto-collect
		-- Ley Shard + auto-convert some into Astral Shard on a timer
		-- without spending it - see AstralShardConversionHandler
		-- .autoConvertTick and WorldBuilder's own background loop).
		leyShardFloorTile1 = false,
		leyShardFloorTile2 = false,
		leyShardFloorTile3 = false,
		leyShardFloorTile4 = false,
		leyShardFloorTile5 = false,

		-- Card 3 of the wizard-material progression - per direct request
		-- ("You have to name this final shard"), named "Celestial Shard"
		-- per this game's own long-planned naming (see LeyShardHandler.lua's
		-- own header comment: "Astral Shard" and "Celestial Shard" are the
		-- planned names for cards 2 and 3"). Unlocked by leyShardFloorTile4
		-- above. Its only source is CelestialShardConversionHandler
		-- (5,000,000 Astral Shard = 1 Celestial Shard) - per direct request
		-- ("It should cost 5 million astra shroud for 1 celestrial"), which
		-- ALSO completely resets astralShardLeyBoostLevel/
		-- astralConversionBoostLevel above back to 1 - per direct request
		-- ("hitting this converter completely resets your astral shards"),
		-- same prestige-reset shape as AstralShardConversionHandler.convert
		-- one tier down.
		celestialShard = 0,
		celestialConversionBoostLevel = 1, -- Card 3's "More Celestial Shard" (CelestialConversionBoostHandler), 1-50, boosts how many Celestial Shard each conversion grants - per direct request ("More celestrial shard. 50 upgrades starting at costing 1 celestrial... the times is big")
		celestialAstralBoostLevel = 1, -- Card 3's "More Astral Shard" (CelestialAstralBoostHandler), 1-25, boosts the Ley->Astral conversion rate - per direct request ("0-25 for more astral cards again start this at 3 and make the upgrades big")
		celestialManaBoostLevel = 1, -- Card 3's "More Mana" (CelestialManaBoostHandler), 1-50, a flat Mana Per Pickup multiplier paid in Celestial Shard - per direct request ("0-50 on more mana. Make this start at 1 but take a bit to reach 50")

		-- Rune Altar upgrades (RuinRuneHandler): 5 tiers bought via
		-- RuneAltarBoard, paid in Mana - only reachable once the Fantasy
		-- Ruin itself is (Wizard Tier 3+). A single count like wizardTier,
		-- not a per-tile boolean set like the Upgrade Tree, since these are
		-- strictly linear (buy tier N+1 only after tier N). Each tier
		-- permanently upgrades the Rune Altar itself (RuinRuneCircle - stand
		-- on it, no clicking) - tick speed, odds, Runes per roll, extra
		-- rolls, or Mana cost per tick. Never reset.
		ruinRuneTier = 0,

		-- Stats (Power/Fortune/Focus/Haste/Familiar): only Fortune has any
		-- live gameplay effect (RuneHandler.weightedPick biases Rune Altar
		-- odds by it) - the other 4 are written by Rune ranks' statBoosts
		-- but never read by anything active. Left as-is (not part of the
		-- Power Store cleanup below) since Fortune is load-bearing for a
		-- real, currently-used mechanic.
		stats = stats,

		runesOpened = 0,
		runesOwned = {}, -- [rankName] = count

		-- Power Store bookkeeping (StoreHandler/GamePassBoostHandler) -
		-- generic, not tied to any one grant shape, so these survived the
		-- Gems/Scrolls/Ascension cleanup below untouched.
		robuxSpent = 0,
		ownedPasses = {}, -- [gamePassKey] = true, gates one-time gamepass grants from reapplying
		purchaseHistory = {}, -- bounded list of processed receiptInfo.PurchaseId, guards against double-granting a dev product

		playtimeSeconds = 0,

		-- Titles (TitleHandler.lua) - briefly removed alongside Gems/
		-- Scrolls/Ascension during the Power Store cleanup, then restored
		-- per direct follow-up report ("Where did titles go on profile
		-- section? My username and title also have stopped appearing") -
		-- the floating username/title display was a real feature in use,
		-- unlike the actually-dead Gems/Scrolls/Ascension system.
		unlockedTitles = {}, -- [titleKey] = true
		equippedTitle = nil,
		firstJoinedAt = nil, -- os.time() the first time this player's data was ever loaded; drives the OG title
	}
end

function PlayerData.get(player: Player)
	return sessions[player]
end

local DATA_LOAD_WAIT_TIMEOUT = 10
local DATA_LOAD_POLL_INTERVAL = 0.5

-- Other server modules that need a player's data right at PlayerAdded (title
-- checks, gamepass re-verification) can't assume PlayerData.load has finished:
-- Roblox spawns each PlayerAdded listener as an independent thread, so a
-- yield in load() (the DataStore call) doesn't block other listeners from
-- starting. Poll briefly instead of racing it.
function PlayerData.waitForLoad(player: Player)
	local elapsed = 0
	while elapsed < DATA_LOAD_WAIT_TIMEOUT do
		local data = sessions[player]
		if data then
			return data
		end
		task.wait(DATA_LOAD_POLL_INTERVAL)
		elapsed += DATA_LOAD_POLL_INTERVAL
	end
	return nil
end

function PlayerData.load(player: Player)
	local data
	if SAVE_STORE then
		local success, result = pcall(function()
			return SAVE_STORE:GetAsync("Player_" .. player.UserId)
		end)
		data = (success and result) or defaultData()
	else
		data = defaultData()
	end
	if not data.firstJoinedAt then
		data.firstJoinedAt = os.time()
	end

	-- TEMP: testing only - spawns in already past Tier 3 with every
	-- Upgrade Tree tile already bought (per direct request), so
	-- SecondIsland, the Fantasy Ruin, and the Ether Shroud/board are all
	-- immediately visible/testable without grinding through the tiers or
	-- tree first. Remove all of these lines once you're done testing.
	data.mana = 1e13
	data.rebirths = 1e13
	data.level = 50
	data.arcaneDust = 1e13
	data.ether = 1e13
	data.wizardTier = 3
	-- Also needed for UpgradeTreeHandler.isUnlocked (requires BOTH
	-- wizardTier >= 3 AND this) - without it, every fresh Studio session
	-- left the floor tile upgrades looking "greyed out" (no sign at all,
	-- since UpgradeTreeClient never builds one while unlocked is false)
	-- until the SecondIslandGate was manually re-unlocked by hand each time.
	data.secondIslandUnlocked = true
	data.dustTreeTile1 = true
	data.dustTreeTile2 = true
	data.dustTreeTile3 = true
	data.dustTreeTile4 = true
	data.dustTreeTile5 = true
	data.dustTreeTile6 = true
	data.dustTreeTile7 = true
	data.dustTreeTile8 = true
	data.dustTreeTile9 = true

	-- TEMP: testing only - per direct request ("spawn me in with more all
	-- ley shard card uogrades maxed just to see how much I gain"), also
	-- skips straight past the EtherIsland gate (its own real unlock still
	-- costs 1e9 Ether normally) and maxes all 3 Ley Shard columns, so the
	-- Mat/board are immediately usable/testable at full strength. Remove
	-- these lines once you're done testing.
	data.etherIslandUnlocked = true
	data.leyShardYieldLevel = 100
	data.leyShardSpeedLevel = 10
	data.leyShardManaBoostLevel = 50

	sessions[player] = data

	-- Real leaderstats for the current game, replacing the old Ascensions/
	-- Scrolls/Gems placeholders (leftover from the scrapped Mana/Coins
	-- design, removed in the Power Store cleanup) - Mana and Rebirths are
	-- this game's two most central currencies, so they're what shows on
	-- Roblox's default leaderboard now.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local mana = Instance.new("NumberValue")
	mana.Name = "Mana"
	mana.Value = data.mana or 0
	mana.Parent = leaderstats

	local rebirths = Instance.new("NumberValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths or 0
	rebirths.Parent = leaderstats

	return data
end

-- Returns true only if the save actually reached the DataStore. Callers that
-- just granted something purchase-critical (dev products especially) should
-- check this and avoid marking the purchase processed on failure, so Roblox's
-- automatic ProcessReceipt retry can grant it again later instead of losing it.
function PlayerData.save(player: Player): boolean
	local data = sessions[player]
	if not data or not SAVE_STORE then
		return false
	end

	local success, err = pcall(function()
		SAVE_STORE:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn(("RuneAcademy: failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end

	return success
end

-- Other modules that need a final look at a player's data before it's gone
-- (LeaderboardHandler's last sync, e.g.) subscribe here instead of their own
-- PlayerRemoving listener - Roblox doesn't guarantee listener order across
-- separate scripts, so a second PlayerRemoving connection could easily fire
-- after release() below has already cleared the session.
local beforeReleaseCallbacks = {}

function PlayerData.onBeforeRelease(callback: (Player) -> ())
	table.insert(beforeReleaseCallbacks, callback)
end

function PlayerData.release(player: Player)
	for _, callback in beforeReleaseCallbacks do
		callback(player)
	end
	PlayerData.save(player)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			PlayerData.save(player)
		end
	end
end)

-- Tracks playtime for the Profile screen's "Time Played" stat. Ticks every
-- session in memory once a second rather than per-player loops.
task.spawn(function()
	while true do
		task.wait(1)
		for _, data in sessions do
			data.playtimeSeconds = (data.playtimeSeconds or 0) + 1
		end
	end
end)

-- leaderstats NumberValues only reflect data at the moment they're created
-- otherwise - this is what keeps Mana/Rebirths live on the Leaderboard as a
-- player actually plays, instead of only updating on rejoin.
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, data in sessions do
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				leaderstats.Mana.Value = data.mana or 0
				leaderstats.Rebirths.Value = data.rebirths or 0
			end
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)

return PlayerData
