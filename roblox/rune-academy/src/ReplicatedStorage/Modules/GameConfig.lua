-- Central tuning file. Change numbers here, not in scattered scripts.

local GameConfig = {}

-- ============================================================================
-- ZONES & CURRENCIES
-- 16 currencies total, grouped into zones that unlock progressively via
-- Ascension count. Every currency runs on the same generic engine
-- (ResourceEngine.lua) through three independent, stackable layers:
--
--   1. upgrades       - 3 resettable production-multiplier slots per
--                        currency (the "More X / More X II / Faster X"
--                        buttons). Reset by that currency's own chainReset.
--   2. selfPrestige    - an ordered list of {cost, multiplier} tiers, each
--                        spendable once in order. Buying one resets this
--                        currency's amount + upgrade levels but permanently
--                        multiplies its base rate going forward - the
--                        "Prestige 1: 10k Shells -> resets Shells, starts
--                        at x5" mechanic. Optional; omit for currencies
--                        that don't have it.
--   3. chainReset      - converts the currency into the NEXT one in its
--                        zone's chain once `requirement` is reached.
--                        Grants floor(amount / requirement) of the next
--                        currency and permanently bumps that next
--                        currency's base rate by intoStartMultiplier,
--                        stacking every time you reset into it (so the
--                        more you've cycled Tier 1, the faster Tier 2
--                        starts out). Omit on a chain's top currency.
--
-- collectMode: "click" (tap a node), "stand" (stand on a part while it
-- ticks), or "chainOnly" (never collected directly - only gained via a
-- previous currency's chainReset, like Essence/Gold/Iron/Sand above tier 1).
--
-- Every currency's effective production rate is:
--   baseRate * (upgrade slot multipliers) * selfPrestige multiplier
--   * chainReset intoStartMultiplier bonus * floor tile multipliers
--   * global Stats (Power for click, Focus for stand/tick - see Stats below)
--
-- All numbers below are a reasonable FIRST PASS aimed at the "~2 weeks of
-- casual F2P play to fully complete" target, not final balance - see
-- DESIGN.md's Pacing section for the tuning method. Change freely; nothing
-- else in the codebase hardcodes these values.
-- ============================================================================

local function standardUpgrades(prefix, baseCost)
	return {
		{ id = prefix .. "1", displayName = "More " .. prefix, maxLevel = 200, baseCost = baseCost, costGrowth = 1.12, multiplierPerLevel = 1.03 },
		{ id = prefix .. "2", displayName = "More " .. prefix .. " II", maxLevel = 100, baseCost = baseCost * 15, costGrowth = 1.15, multiplierPerLevel = 1.02 },
		{ id = prefix .. "3", displayName = "Faster " .. prefix, maxLevel = 10, baseCost = baseCost * 100, costGrowth = 1.6, multiplierPerLevel = 1.1 },
	}
end

GameConfig.Zones = {
	{
		key = "Academy",
		displayName = "Rune Academy",
		unlockRequirement = nil, -- starting zone, always unlocked
		currencies = {
			{
				key = "Mana",
				displayName = "Mana",
				collectMode = "click",
				baseRate = 1,
				upgrades = standardUpgrades("Mana", 10),
				selfPrestigeTiers = {
					{ cost = 10000, multiplier = 5 },
					{ cost = 100000, multiplier = 4 },
					{ cost = 1000000, multiplier = 3 },
				},
				chainReset = { requirement = 5000000, into = "Essence", intoStartMultiplier = 1.05 },
			},
			{
				key = "Essence",
				displayName = "Essence",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Essence", 50),
				selfPrestigeTiers = {
					{ cost = 50000, multiplier = 5 },
					{ cost = 500000, multiplier = 4 },
				},
				chainReset = { requirement = 1e7, into = "Gold", intoStartMultiplier = 1.05 },
			},
			{
				key = "Gold",
				displayName = "Gold",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Gold", 200),
				selfPrestigeTiers = {
					{ cost = 500000, multiplier = 5 },
				},
				chainReset = nil, -- top of the Academy chain; spent on Ascension instead (see AscensionTiers)
			},
		},
		floorTiles = {
			{ key = "ManaVein1", displayName = "Mana Vein I", costCurrency = "Mana", cost = 500000, targetCurrency = "Mana", multiplier = 1.5 },
			{ key = "ManaVein2", displayName = "Mana Vein II", costCurrency = "Mana", cost = 5000000, targetCurrency = "Mana", multiplier = 1.5 },
			{ key = "EssenceWell1", displayName = "Essence Well I", costCurrency = "Essence", cost = 1000000, targetCurrency = "Essence", multiplier = 1.5 },
		},
	},
	{
		key = "FamiliarGrounds",
		displayName = "Familiar Grounds",
		unlockRequirement = { type = "ascensionCount", value = 0 }, -- open from the start alongside Academy
		currencies = {
			{
				key = "Whispers",
				displayName = "Whispers",
				collectMode = "click",
				baseRate = 1,
				upgrades = standardUpgrades("Whispers", 15),
				selfPrestigeTiers = {
					{ cost = 20000, multiplier = 5 },
					{ cost = 200000, multiplier = 4 },
				},
				chainReset = nil, -- endless side grind; feeds its own floor tiles rather than a further tier
			},
		},
		floorTiles = {
			{ key = "WhisperEcho1", displayName = "Echoing Whisper I", costCurrency = "Whispers", cost = 750000, targetCurrency = "Whispers", multiplier = 1.5 },
		},
	},
	{
		key = "Foundry",
		displayName = "The Foundry",
		unlockRequirement = { type = "ascensionCount", value = 1 },
		currencies = {
			{
				key = "Copper",
				displayName = "Copper",
				collectMode = "stand",
				baseRate = 1,
				upgrades = standardUpgrades("Copper", 10),
				selfPrestigeTiers = { { cost = 10000, multiplier = 5 } },
				chainReset = { requirement = 5e6, into = "Tin", intoStartMultiplier = 1.05 },
			},
			{
				key = "Tin",
				displayName = "Tin",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Tin", 100),
				selfPrestigeTiers = { { cost = 100000, multiplier = 5 } },
				chainReset = { requirement = 1e8, into = "Steel", intoStartMultiplier = 1.05 },
			},
			{
				key = "Steel",
				displayName = "Steel",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Steel", 1000),
				selfPrestigeTiers = { { cost = 1000000, multiplier = 5 } },
				chainReset = { requirement = 1e10, into = "Mithril", intoStartMultiplier = 1.05 },
			},
			{
				key = "Mithril",
				displayName = "Mithril",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Mithril", 10000),
				selfPrestigeTiers = { { cost = 1e7, multiplier = 5 } },
				chainReset = nil, -- top of the Foundry chain
			},
		},
		floorTiles = {
			{ key = "CopperSeam1", displayName = "Copper Seam I", costCurrency = "Copper", cost = 2000000, targetCurrency = "Copper", multiplier = 1.5 },
			{ key = "TinSeam1", displayName = "Tin Seam I", costCurrency = "Tin", cost = 5e7, targetCurrency = "Tin", multiplier = 1.5 },
		},
	},
	{
		key = "TidalGrotto",
		displayName = "Tidal Grotto",
		unlockRequirement = { type = "ascensionCount", value = 2 },
		currencies = {
			{
				key = "Pearls",
				displayName = "Pearls",
				collectMode = "click",
				baseRate = 1,
				upgrades = standardUpgrades("Pearls", 10),
				selfPrestigeTiers = { { cost = 10000, multiplier = 5 } },
				chainReset = { requirement = 5e6, into = "Coral", intoStartMultiplier = 1.05 },
			},
			{
				key = "Coral",
				displayName = "Coral",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Coral", 100),
				selfPrestigeTiers = { { cost = 100000, multiplier = 5 } },
				chainReset = { requirement = 1e8, into = "Driftglass", intoStartMultiplier = 1.05 },
			},
			{
				key = "Driftglass",
				displayName = "Driftglass",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Driftglass", 1000),
				selfPrestigeTiers = { { cost = 1000000, multiplier = 5 } },
				chainReset = { requirement = 1e10, into = "AbyssalSalt", intoStartMultiplier = 1.05 },
			},
			{
				key = "AbyssalSalt",
				displayName = "Abyssal Salt",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("AbyssalSalt", 10000),
				selfPrestigeTiers = { { cost = 1e7, multiplier = 5 } },
				chainReset = nil, -- top of the Tidal Grotto chain
			},
		},
		floorTiles = {
			{ key = "PearlBed1", displayName = "Pearl Bed I", costCurrency = "Pearls", cost = 2000000, targetCurrency = "Pearls", multiplier = 1.5 },
			{ key = "CoralReef1", displayName = "Coral Reef I", costCurrency = "Coral", cost = 5e7, targetCurrency = "Coral", multiplier = 1.5 },
		},
	},
	{
		key = "StarfallPeak",
		displayName = "Starfall Peak",
		unlockRequirement = { type = "ascensionCount", value = 3 },
		currencies = {
			{
				key = "Stardust",
				displayName = "Stardust",
				collectMode = "click",
				baseRate = 1,
				upgrades = standardUpgrades("Stardust", 100),
				selfPrestigeTiers = { { cost = 100000, multiplier = 5 } },
				chainReset = { requirement = 5e8, into = "CometShards", intoStartMultiplier = 1.05 },
			},
			{
				key = "CometShards",
				displayName = "Comet Shards",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("CometShards", 1000),
				selfPrestigeTiers = { { cost = 1000000, multiplier = 5 } },
				chainReset = { requirement = 1e11, into = "Celestium", intoStartMultiplier = 1.05 },
			},
			{
				key = "Celestium",
				displayName = "Celestium",
				collectMode = "chainOnly",
				baseRate = 1,
				upgrades = standardUpgrades("Celestium", 10000),
				selfPrestigeTiers = { { cost = 1e8, multiplier = 5 } },
				chainReset = nil, -- final currency; maxing this out is "100% completion"
			},
		},
		floorTiles = {
			{ key = "StardustField1", displayName = "Stardust Field I", costCurrency = "Stardust", cost = 2e8, targetCurrency = "Stardust", multiplier = 1.5 },
		},
	},
}

-- Gems is intentionally NOT in a zone: it's the global premium currency
-- (see Power Store below), earned in tiny amounts from milestones or
-- bought with Robux, never reset by chain resets, self-prestige, or
-- Ascension.

-- Stats raised by the upgrade tree and by Runes.
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

GameConfig.ScrollCostPerPull = 1

-- Ascension tiers. requirement is measured in Academy Gold at time of
-- ascending (Gold is the top of the Academy chain - our equivalent of the
-- reference game's "Cash used for rebirths"). Reaching a tier also unlocks
-- the next Zone (see Zones' unlockRequirement = { type = "ascensionCount" }),
-- which is what paces zone-by-zone progress toward the ~2 week completion
-- target instead of everything being available at once.
GameConfig.AscensionTiers = {
	{
		name = "Ascension I",
		requirementZone = "Academy",
		requirementCurrency = "Gold",
		requirement = 1e7,
		rewards = { statMultiplierAll = 2, unlocksRuneRankIndex = 2 },
	},
	{
		name = "Ascension II",
		requirementZone = "Academy",
		requirementCurrency = "Gold",
		requirement = 1e9,
		rewards = { autoCollect = true, hasteBonus = 5, unlocksRuneRankIndex = 4 },
	},
	{
		name = "Ascension III",
		requirementZone = "Academy",
		requirementCurrency = "Gold",
		requirement = 1e12,
		rewards = { statMultiplierAll = 2, unlocksRuneRankIndex = 6 },
	},
	{
		name = "Ascension IV",
		requirementZone = "Academy",
		requirementCurrency = "Gold",
		requirement = 1e15,
		rewards = { statMultiplierAll = 2 },
	},
}

GameConfig.CollectionTickSeconds = 1
GameConfig.AutoCollectYieldFraction = 0.5 -- Familiars collect at half a manual collect's rate, per Familiar

-- ============================================================================
-- POWER STORE
-- Real IDs are placeholders (0) until you create the matching GamePass /
-- Developer Product in Studio's Monetize tab and paste the real asset ID in.
-- Grant shapes, handled by StoreHandler.applyGrant:
--   gems             : number, added to Gems resource
--   freeScrolls      : number, added to Scrolls
--   statMultiplierAll: number, multiplies EVERY current stat (repeatable, stacks per purchase)
--   statMultiplier   : { StatName = number }, multiplies named stats (gamepass, applied once)
--   statAdd          : { StatName = number }, adds flat amount to named stats (gamepass, applied once)
--   instantAscend    : true, forces the next Ascension tier regardless of Gold requirement
--   autoCollect      : true, flags AutoCollectPass owned (read by the future Familiar auto-collect loop)
-- ============================================================================

-- Developer Products: repeatable purchases. PowerSurge is the core "spend more,
-- get stronger" lever - uncapped, stacks every time, this is what drives
-- long-term Robux spend from committed players rather than a one-time cap.
GameConfig.DevProducts = {
	{ key = "PowerSurge_Small", id = 0, priceRobuxHint = 99, grants = { statMultiplierAll = 1.25 } },
	{ key = "PowerSurge_Medium", id = 0, priceRobuxHint = 299, grants = { statMultiplierAll = 1.6 } },
	{ key = "PowerSurge_Large", id = 0, priceRobuxHint = 999, grants = { statMultiplierAll = 2.5 } },
	{ key = "GemPack_Small", id = 0, priceRobuxHint = 99, grants = { gems = 100 } },
	{ key = "GemPack_Medium", id = 0, priceRobuxHint = 399, grants = { gems = 500 } },
	{ key = "GemPack_Large", id = 0, priceRobuxHint = 999, grants = { gems = 1500 } },
	{ key = "ScrollBundle_10", id = 0, priceRobuxHint = 249, grants = { freeScrolls = 10 } },
	{ key = "InstantAscend", id = 0, priceRobuxHint = 199, grants = { instantAscend = true } },
}

-- GamePasses: one-time purchases, permanent effect, granted once (tracked via
-- data.ownedPasses so a repeat "purchase" / rejoin never double-applies).
GameConfig.GamePasses = {
	{ key = "ArchmagePass", id = 0, priceRobuxHint = 349, grants = { statMultiplier = { Power = 3 } } },
	{ key = "FortunePass", id = 0, priceRobuxHint = 349, grants = { statMultiplier = { Fortune = 3 } } },
	{ key = "AutoCollectPass", id = 0, priceRobuxHint = 249, grants = { autoCollect = true } },
	{ key = "VIPFamiliar", id = 0, priceRobuxHint = 149, grants = { statAdd = { Familiar = 2 } } },
	{ key = "ElitePass", id = 0, priceRobuxHint = 799, grants = { statMultiplier = { Power = 1.5, Fortune = 1.5 } } },
}

-- ============================================================================
-- TITLES
-- One equippable title per player, shown above their head (see
-- TitleDisplayClient.client.lua). Every title needs: key (save-data id),
-- displayName (shown in-game), color (Color3), and a condition that
-- TitleHandler.lua checks to decide when it unlocks. rainbow = true
-- overrides color with an animated hue cycle client-side.
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
GameConfig.OwnerUserIds = {}
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
	{ key = "EliteGP", displayName = "EliteGP", color = Color3.fromRGB(0, 200, 255), condition = { type = "gamePassOwned", passKey = "ElitePass" } },
	{ key = "Tester", displayName = "Tester", color = Color3.fromRGB(0, 255, 150), condition = { type = "manual" } },
	{ key = "Admin", displayName = "Admin", color = Color3.fromRGB(255, 40, 40), condition = { type = "manual" } },
	{ key = "Owner", displayName = "Owner", color = Color3.fromRGB(255, 215, 0), condition = { type = "manual" } },
}

return GameConfig
