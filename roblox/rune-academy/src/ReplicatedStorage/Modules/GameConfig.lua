-- Central tuning file. Change numbers here, not in scattered scripts.

local GameConfig = {}

-- Resource chain: each tier resets the one above it (index 1 resets into index 2, etc).
GameConfig.ResourceTiers = {
	{ name = "Mana", resetsInto = "Essence", baseRate = 1 },
	{ name = "Essence", resetsInto = "Gold", resetRequirement = 1000 },
	{ name = "Gold", resetsInto = "Gems", resetRequirement = 1e6 },
	{ name = "Gems", resetsInto = nil }, -- premium-feel currency, not resettable
}

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

-- Ascension tiers. requirement is measured in Gold at time of ascending.
GameConfig.AscensionTiers = {
	{
		name = "Ascension I",
		requirement = 1e7,
		rewards = { statMultiplierAll = 2, unlocksRuneRankIndex = 2 },
	},
	{
		name = "Ascension II",
		requirement = 1e9,
		rewards = { autoCollect = true, hasteBonus = 5, unlocksRuneRankIndex = 4 },
	},
	{
		name = "Ascension III",
		requirement = 1e12,
		rewards = { statMultiplierAll = 2, unlocksRuneRankIndex = 6 },
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
}

return GameConfig
