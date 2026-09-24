-- Central tuning file. Change numbers here, not in scattered scripts.

local GameConfig = {}

-- Stats raised by Rune ranks (RuneHandler/RuneCollectionHandler). Of these
-- 5, only Fortune has any live gameplay effect (RuneHandler.weightedPick
-- biases Rune Altar odds by it) - Power/Focus/Haste/Familiar are written
-- by rank statBoosts but never read by anything active. Left in place
-- rather than trimmed during the Power Store cleanup below, since Fortune
-- is load-bearing for a real, currently-used mechanic and the 9
-- GameConfig.RuneRanks entries below already carry statBoosts values for
-- all 5 - trimming those without a real reason to felt riskier than
-- leaving 4 harmlessly unused fields.
GameConfig.Stats = {
	Power = { description = "Multiplies Mana per node collected", base = 1 },
	Fortune = { description = "Shifts Rune odds toward rarer tiers", base = 1 },
	Focus = { description = "Multiplies Mana per collection tick", base = 1 },
	Haste = { description = "Increases walkspeed + auto-collect tick rate", base = 1 },
	Familiar = { description = "Number of auto-collecting spectral duplicates", base = 0 },
}

-- Rune rarity table: odds are "1 in N" before Fortune adjustment.
-- statBoosts values are multiplicative bonuses applied to the named stat.
GameConfig.RuneRanks = {
	{ name = "Apprentice", oddsOneIn = 1, statBoosts = { Power = 1.01 } },
	{ name = "Novice", oddsOneIn = 5, statBoosts = { Power = 1.05 } },
	{ name = "Adept", oddsOneIn = 5, statBoosts = { Focus = 1.05 } },
	{ name = "Skilled", oddsOneIn = 7, statBoosts = { Haste = 1.1 } },
	{ name = "Expert", oddsOneIn = 260, statBoosts = { Power = 1.5, Fortune = 1.1 } },
	{ name = "Master", oddsOneIn = 5200, statBoosts = { Power = 3, Focus = 2 } },
	{ name = "Archmage", oddsOneIn = 104000, statBoosts = { Power = 10, Fortune = 2, Familiar = 1 } },
	{ name = "Mythic", oddsOneIn = 125000000, statBoosts = { Power = 100, Focus = 50, Haste = 10 } },
	{ name = "Ascendant", oddsOneIn = 750000000000, statBoosts = { Power = 1000, Fortune = 100, Familiar = 5 } },
}

-- ============================================================================
-- THE STORE
-- Real IDs are placeholders (0) until you create the matching GamePass /
-- Developer Product in Studio's Monetize tab and paste the real asset ID
-- in here - StoreHandler.promptPurchase silently no-ops on an id of 0, so
-- nothing crashes in the meantime, but nothing is purchasable either.
--
-- Rebuilt from scratch per direct request ("can I have you implement our
-- store? Make it look good I want a game pass, also smaller micro
-- transactions, a starter pack... do some research on best prices to
-- do") - the previous DevProducts/GamePasses here granted "gems"/
-- "freeScrolls"/stat multipliers/"instantAscend"/"autoCollect", all tied
-- to the scrapped Mana/Coins-era Gems/Scrolls/Ascension system, none of
-- which the current Mana/Arcane Dust/Rebirths/Ether/Ley Shard/Astral
-- Shard game actually has. Every grant below targets real, currently-live
-- systems instead.
--
-- Pricing follows current (2026) Roblox developer guidance: game passes
-- cluster 49-999 Robux with a "cheap/mid/premium" ladder, dev products
-- are priced as repeatable tiered bundles with a clear best-value anchor,
-- and a starter pack sits at the cheap end but bundles clearly more value
-- than its price alone would buy separately, to win a new player's FIRST
-- purchase (after which they're much likelier to buy again). All prices
-- below are a first pass, not final balance - like every other number in
-- this file, tune freely from Roblox Analytics once real sales data
-- exists (Roblox's own advice: change one price at a time, in 5-10%
-- steps, and judge by total revenue, not conversion rate alone).
--
-- Grant shapes, handled by StoreHandler.applyGrant/GamePassBoostHandler:
--   manaAmount / arcaneDustAmount : number, added directly to that currency's live balance
--   manaMultiplier / dustMultiplier / etherMultiplier / leyShardMultiplier
--                                  : number, permanent gamepass multiplier (GamePassBoostHandler)
--   runeCollectionMultiplier      : number, permanent bonus on top of RuneCollectionHandler's
--                                    own Rune-ownership multiplier (cascades into Mana/Rebirths/
--                                    Arcane Dust/Ether/Ley Shard alike, since RuneCollectionHandler
--                                    already folds into all 5)
--   earlyAutoMana                 : true, grants passive Mana collection before naturally
--                                    reaching Wizard Tier 2 (GamePassBoostHandler.hasEarlyAutoMana)
-- ============================================================================

-- Developer Products: repeatable microtransactions. Mana and Arcane Dust
-- specifically - this game's two earliest, most universally-needed
-- currencies (Arcane Dust funds the SecondIsland Upgrade Tree/Wizard
-- Tiers just like Mana does) - each get a Small/Medium/Large tier, sized
-- against real in-game costs so every tier is a clear, meaningful chunk
-- of an actual grind rather than an arbitrary round number:
--   Mana: SecondIslandHandler's own unlock costs 40,000,000 Mana;
--   Wizard Tier 1 costs 1,000,000,000 Mana. Small clears about a quarter
--   of the SecondIsland gate, Medium clears it outright with room to
--   spare, Large is the full Wizard Tier 1 cost.
--   Arcane Dust: UpgradeTreeHandler's 9 tiles range 1e9-16e9 Dust each.
--   Small/Medium/Large are sized to clear the tree's early/mid/late tiles.
-- Ether/Ley Shard/Astral Shard packs are a natural next addition once
-- these convert well - left out of this first pass to keep the store
-- from being overwhelming on day one (same "first pass, tune later"
-- spirit as every curve in this file).
GameConfig.DevProducts = {
	{
		key = "ManaCache_Small",
		id = 0,
		priceRobuxHint = 99,
		displayName = "Mana Cache (Small)",
		description = "+10,000,000 Mana instantly",
		grants = { manaAmount = 10000000 },
	},
	{
		key = "ManaCache_Medium",
		id = 0,
		priceRobuxHint = 249,
		displayName = "Mana Cache (Medium)",
		description = "+100,000,000 Mana instantly",
		grants = { manaAmount = 100000000 },
	},
	{
		key = "ManaCache_Large",
		id = 0,
		priceRobuxHint = 499,
		displayName = "Mana Cache (Large)",
		description = "+1,000,000,000 Mana instantly",
		grants = { manaAmount = 1000000000 },
	},

	{
		key = "DustCache_Small",
		id = 0,
		priceRobuxHint = 99,
		displayName = "Dust Cache (Small)",
		description = "+5,000,000 Arcane Dust instantly",
		grants = { arcaneDustAmount = 5000000 },
	},
	{
		key = "DustCache_Medium",
		id = 0,
		priceRobuxHint = 249,
		displayName = "Dust Cache (Medium)",
		description = "+500,000,000 Arcane Dust instantly",
		grants = { arcaneDustAmount = 500000000 },
	},
	{
		key = "DustCache_Large",
		id = 0,
		priceRobuxHint = 499,
		displayName = "Dust Cache (Large)",
		description = "+4,000,000,000 Arcane Dust instantly",
		grants = { arcaneDustAmount = 4000000000 },
	},
}

-- GamePasses: one-time purchases, permanent effect, granted once (tracked
-- via data.ownedPasses so a repeat "purchase"/rejoin never double-applies).
-- A cheap/mid/premium ladder, per Roblox's own pricing guidance, each
-- targeting a different real system:
--   VIPPass       (cheap, broad appeal)  - a modest permanent boost to
--                  every actively-collected currency at once.
--   DoubleManaPass (mid)                 - the classic incremental-game
--                  staple: permanently doubles Mana, the one currency
--                  that touches everything downstream of it (Rebirths
--                  come from Mana, Wizard Tiers cost Mana).
--   HeadStartPass (cheapest, pure QoL)   - grants passive Mana collection
--                  from the very start, instead of waiting to naturally
--                  reach Wizard Tier 2's free Auto Mana reward. A great
--                  low-commitment impulse buy for brand-new players.
--   FortunesFavorPass (premium)          - boosts the Rune Altar's
--                  combined collection bonus, which already cascades
--                  into Mana/Rebirths/Arcane Dust/Ether/Ley Shard all at
--                  once (RuneCollectionHandler.getMultiplier) - correctly
--                  the most expensive pass, since its payoff compounds
--                  across the whole economy.
GameConfig.GamePasses = {
	{
		key = "VIPPass",
		id = 0,
		priceRobuxHint = 149,
		displayName = "VIP Pass",
		description = "+25% Mana, Arcane Dust, Ether, and Ley Shard - forever",
		grants = { manaMultiplier = 1.25, dustMultiplier = 1.25, etherMultiplier = 1.25, leyShardMultiplier = 1.25 },
	},
	{
		key = "DoubleManaPass",
		id = 0,
		priceRobuxHint = 199,
		displayName = "Double Mana Pass",
		description = "Permanently 2x Mana from every source",
		grants = { manaMultiplier = 2 },
	},
	{
		key = "HeadStartPass",
		id = 0,
		priceRobuxHint = 99,
		displayName = "Head Start Pass",
		description = "Auto-collect Mana from the moment you join",
		grants = { earlyAutoMana = true },
	},
	{
		key = "FortunesFavorPass",
		id = 0,
		priceRobuxHint = 349,
		displayName = "Fortune's Favor Pass",
		description = "Doubles your Rune Altar bonus - boosts Mana, Rebirths, Arcane Dust, Ether, and Ley Shard all at once",
		grants = { runeCollectionMultiplier = 2 },
	},
}

-- The Starter Pack: also a GamePass under the hood (one-time by nature,
-- reuses the exact same ownedPasses/grant machinery as every pass above),
-- just called out separately so the Store UI can give it its own
-- "New Player Deal!" banner treatment instead of sitting in the plain
-- pass list. Priced at the cheap end but bundles clearly more than its
-- price alone would buy piecemeal (20M Mana + 10M Dust alone would cost
-- ~99 Robux via the Small caches above, PLUS the Head Start pass at 99
-- more - this bundles both of those, doubled, plus a small permanent
-- boost, for 149 total) - the classic "great first-purchase value" a
-- starter pack is supposed to be, to win a new player's first transaction.
GameConfig.StarterPack = {
	key = "StarterPack",
	id = 0,
	priceRobuxHint = 149,
	displayName = "Starter Pack",
	description = "20,000,000 Mana + 10,000,000 Arcane Dust, early Auto Mana, and +10% to every currency - forever. One-time only.",
	grants = {
		manaAmount = 20000000,
		arcaneDustAmount = 10000000,
		earlyAutoMana = true,
		manaMultiplier = 1.1,
		dustMultiplier = 1.1,
		etherMultiplier = 1.1,
		leyShardMultiplier = 1.1,
	},
}

-- ============================================================================
-- TITLES
-- One equippable title per player, shown above their head (see
-- TitleDisplayClient.client.lua). Every title needs: key (save-data id),
-- displayName (shown in-game), color (Color3), and a condition that
-- TitleHandler.lua checks to decide when it unlocks. rainbow = true
-- overrides color with an animated hue cycle client-side. Removed during
-- the Power Store cleanup above (mistaken for dead leftover scaffolding
-- alongside the actually-dead Gems/Scrolls/Ascension system), then
-- restored per direct follow-up ("Where did titles go on profile
-- section? My username and title also have stopped appearing") - this
-- floating username/title display was a real feature being used, unlike
-- Gems/Scrolls/Ascension which nothing ever read.
--
-- condition.type options:
--   "playtimeSeconds"  { value = seconds }              - data.playtimeSeconds >= value
--   "robuxSpent"       { value = robux }                 - data.robuxSpent >= value
--   "groupMember"                                        - player is in GameConfig.FanGroupId
--   "gamePassOwned"    { passKey = "GamePassKey" }        - data.ownedPasses[passKey]
--   "joinWindow"                                          - firstJoinedAt within OGWindowSeconds of ReleaseTimestampUnix
--   "manual"                                              - never auto-unlocked; granted via
--                                                            TitleHandler.grantManualTitle (admin/tester/owner allowlists, or a future admin command)
-- ============================================================================

-- Set this to the real launch time (os.time() value, e.g. via a one-off
-- `print(os.time())` in a test server) before release so the OG title means
-- something. Left nil until then - the OG condition never unlocks with it unset.
GameConfig.ReleaseTimestampUnix = nil
GameConfig.OGWindowSeconds = 24 * 60 * 60

-- Your group's id (from the group's page URL) for the Fan title. 0 = disabled.
GameConfig.FanGroupId = 0

-- UserIds auto-granted their title on join. Fill in with real UserIds
-- (yours included, for Owner) before shipping.
GameConfig.OwnerUserIds = { 11620037282 } -- Sam Caron (Kharened), per direct request
GameConfig.AdminUserIds = {}
GameConfig.TesterUserIds = {}

GameConfig.Titles = {
	{ key = "OG", displayName = "OG", color = Color3.fromRGB(255, 215, 0), condition = { type = "joinWindow" } },
	{ key = "Fan", displayName = "Fan", color = Color3.fromRGB(255, 105, 180), condition = { type = "groupMember" } },
	{ key = "Newbie", displayName = "Newbie", color = Color3.fromRGB(170, 170, 170), condition = { type = "playtimeSeconds", value = 60 * 60 } },
	{ key = "Regular", displayName = "Regular", color = Color3.fromRGB(100, 200, 120), condition = { type = "playtimeSeconds", value = 24 * 60 * 60 } },
	{ key = "VIP", displayName = "VIP", color = Color3.fromRGB(80, 160, 255), condition = { type = "playtimeSeconds", value = 7 * 24 * 60 * 60 } },
	{ key = "NoLife", displayName = "No Life", color = Color3.fromRGB(160, 80, 220), condition = { type = "playtimeSeconds", value = 30 * 24 * 60 * 60 } },
	{ key = "Supporter", displayName = "Supporter", color = Color3.fromRGB(80, 220, 180), condition = { type = "robuxSpent", value = 100 } },
	{ key = "Boss", displayName = "Boss", color = Color3.fromRGB(255, 140, 0), condition = { type = "robuxSpent", value = 1000 } },
	{ key = "Rich", displayName = "Rich", color = Color3.fromRGB(255, 255, 255), rainbow = true, condition = { type = "robuxSpent", value = 10000 } },
	{ key = "UltimateSpender", displayName = "Ultimate Spender", color = Color3.fromRGB(255, 0, 60), condition = { type = "robuxSpent", value = 100000 } },
	-- Repointed from the old "ElitePass" (removed along with the rest of
	-- the pre-Store gamepasses) to "FortunesFavorPass" - the current
	-- store's own premium pass, matching "Elite" in spirit and keeping
	-- this condition actually achievable again.
	{ key = "EliteGP", displayName = "EliteGP", color = Color3.fromRGB(0, 200, 255), condition = { type = "gamePassOwned", passKey = "FortunesFavorPass" } },
	{ key = "Tester", displayName = "Tester", color = Color3.fromRGB(0, 255, 150), condition = { type = "manual" } },
	{ key = "Admin", displayName = "Admin", color = Color3.fromRGB(255, 40, 40), condition = { type = "manual" } },
	{ key = "Owner", displayName = "Owner", color = Color3.fromRGB(255, 215, 0), condition = { type = "manual" } },
}

return GameConfig
