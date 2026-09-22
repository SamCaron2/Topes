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

-- Builds the { [zoneKey] = { currencies = { [currencyKey] = {...} }, floorTiles = {} } }
-- shape entirely from GameConfig.Zones, so a new/renamed zone or currency
-- never needs a matching change here.
local function defaultZoneState()
	local zones = {}
	for _, zone in GameConfig.Zones do
		local currencies = {}
		for _, currency in zone.currencies do
			currencies[currency.key] = {
				amount = 0,
				upgradeLevels = {}, -- [slotId] = level
				selfPrestigeTier = 0, -- count of selfPrestigeTiers purchased so far
				chainBonusMultiplier = 1, -- permanent bonus from being chain-reset INTO repeatedly
			}
		end
		zones[zone.key] = { currencies = currencies, floorTiles = {} } -- floorTiles: [tileKey] = true
	end
	return zones
end

local function defaultData()
	local stats = {}
	for statName, statInfo in GameConfig.Stats do
		stats[statName] = statInfo.base
	end

	return {
		zones = defaultZoneState(),
		-- Mana + the 4 fields below all get reset to these same defaults by
		-- RebirthHandler.rebirth() - keep that function's reset list in sync
		-- if any of these are renamed or a new Mana-side upgrade is added.
		mana = 0, -- collected from ManaNodes on the ground; not a Zone/ResourceEngine currency yet
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
		-- the other two currencies. Its own 3-column board: "More Ether"
		-- (etherYieldLevel, 1-100, paid in Ether), "Click Speed"
		-- (etherClickSpeedLevel, 1-10, paid in Ether), and "More Dust"
		-- (etherDustBoostLevel, 1-50, paid in Ether - boosts Arcane Dust
		-- yield, mirroring ManaBoostHandler's own Dust-funded Mana boost).
		-- Permanent like the Upgrade Tree itself - not reset by anything.
		ether = 0,
		etherYieldLevel = 1,
		etherClickSpeedLevel = 1,
		etherDustBoostLevel = 1,

		gems = 0, -- global premium currency, outside any zone/chain
		stats = stats,
		scrolls = 0,
		runesOpened = 0,
		runesOwned = {}, -- [rankName] = count
		ascensionCount = 0,
		robuxSpent = 0,
		playtimeSeconds = 0,
		ownedPasses = {}, -- [gamePassKey] = true, gates one-time gamepass grants from reapplying
		purchaseHistory = {}, -- bounded list of processed receiptInfo.PurchaseId, guards against double-granting a dev product
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
	data.dustTreeTile1 = true
	data.dustTreeTile2 = true
	data.dustTreeTile3 = true
	data.dustTreeTile4 = true
	data.dustTreeTile5 = true
	data.dustTreeTile6 = true
	data.dustTreeTile7 = true
	data.dustTreeTile8 = true
	data.dustTreeTile9 = true

	sessions[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- No per-currency leaderstats yet - GameConfig.Zones is empty pending
	-- the new vision. Add one NumberValue per currency worth showing here
	-- once there's something to show, same pattern as before.

	local ascensions = Instance.new("IntValue")
	ascensions.Name = "Ascensions"
	ascensions.Value = data.ascensionCount
	ascensions.Parent = leaderstats

	local scrolls = Instance.new("IntValue")
	scrolls.Name = "Scrolls"
	scrolls.Value = data.scrolls or 0
	scrolls.Parent = leaderstats

	local gems = Instance.new("NumberValue")
	gems.Name = "Gems"
	gems.Value = data.gems or 0
	gems.Parent = leaderstats

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

-- Drives the playtime-based titles (Newbie/Regular/VIP/No Life). Ticks every
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
-- otherwise - this is what keeps them live on the Leaderboard as a player
-- actually plays, instead of only updating on rejoin. Add a currency's
-- Value assignment here once it has a leaderstat again (see load() above).
task.spawn(function()
	while true do
		task.wait(0.5)
		for player, data in sessions do
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				leaderstats.Ascensions.Value = data.ascensionCount
				leaderstats.Scrolls.Value = data.scrolls
				leaderstats.Gems.Value = data.gems
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
