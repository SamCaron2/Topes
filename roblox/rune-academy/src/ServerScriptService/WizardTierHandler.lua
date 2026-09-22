-- Server-authoritative Wizard Tiers: a deeper prestige layer than Rebirths.
-- Buying into a tier spends a flat Mana cost and, in exchange, wipes every
-- "lobby" currency/upgrade earned so far - Mana, Rebirths, Level/XP, and
-- every Mana/Rebirth Shop/Arcane Dust upgrade level - back to their
-- defaults, but grants a permanent flat multiplier on Mana, Rebirths, and
-- Arcane Dust that applies from the very next pickup onward. The
-- SecondIsland gate stays open - secondIslandUnlocked is deliberately left
-- alone, per direct request ("the entire lobby thus far resets except for
-- the locked door that stays open").
--
-- TIERS is built so more can be appended later without touching the logic
-- below.
--
-- Tier 2's cost is derived, not guessed: the total Mana it costs to fully
-- max every Mana-side upgrade (Mana Per Pickup to level 100, Mana Spawn
-- Speed/Walking Speed/Collection Range each to their cap) is ~600,390
-- Mana. Tier 1's 1e9 cost was already ~1,666x that total - it was always
-- meant as a grind target well past simply maxing upgrades, not "cost to
-- max everything" itself. Since Tier 1 grants a flat 20x Mana multiplier,
-- the exact same grind now produces 20x the raw Mana per hour of
-- playtime - scaling Tier 2's cost by that same 20x (1e9 * 20 = 2e10)
-- keeps the actual TIME it takes to reach Tier 2 comparable to what Tier 1
-- took, despite the much bigger raw number. Per direct request ("times
-- everything else again"), Tier 2's own multipliers are 20x Tier 1's
-- already-permanent multipliers (20x20=400x Mana, 20x20=400x Rebirths,
-- 5x5=25x Arcane Dust) - stored here as their final absolute values so
-- getManaMultiplier/etc. stay simple table lookups, no compounding logic
-- needed. Tier 2 also unlocks passive "Auto Mana" (autoMana = true) - see
-- hasAutoMana below and the background loop in Main.server.lua.
local PlayerData = require(script.Parent.PlayerData)
local WalkSpeedHandler = require(script.Parent.WalkSpeedHandler)

local TIERS = {
	{
		name = "Tier 1",
		cost = 1e9, -- Mana
		manaMultiplier = 20,
		rebirthMultiplier = 20,
		dustMultiplier = 5,
	},
	{
		name = "Tier 2",
		cost = 20e9, -- Mana - see the derivation above
		manaMultiplier = 400,
		rebirthMultiplier = 400,
		dustMultiplier = 25,
		autoMana = true,
	},
}

local WizardTierHandler = {}

-- True once the player has ever reached a tier that grants Auto Mana (Tier
-- 2+) - scans every tier up to their current one rather than just checking
-- the current tier's own flag, so the reward stays permanent even if a
-- later tier's table entry doesn't repeat it.
function WizardTierHandler.hasAutoMana(player: Player): boolean
	local data = PlayerData.get(player)
	local tier = data and data.wizardTier or 0
	for i = 1, tier do
		if TIERS[i] and TIERS[i].autoMana then
			return true
		end
	end
	return false
end

local function tierInfoFor(player: Player)
	local data = PlayerData.get(player)
	local tier = data and data.wizardTier or 0
	return TIERS[tier]
end

function WizardTierHandler.getManaMultiplier(player: Player): number
	local tierInfo = tierInfoFor(player)
	return tierInfo and tierInfo.manaMultiplier or 1
end

function WizardTierHandler.getRebirthMultiplier(player: Player): number
	local tierInfo = tierInfoFor(player)
	return tierInfo and tierInfo.rebirthMultiplier or 1
end

function WizardTierHandler.getDustMultiplier(player: Player): number
	local tierInfo = tierInfoFor(player)
	return tierInfo and tierInfo.dustMultiplier or 1
end

function WizardTierHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local tier = data.wizardTier or 0
	local currentTierInfo = TIERS[tier]
	local nextTierInfo = TIERS[tier + 1]

	return {
		tier = tier,
		mana = data.mana or 0,
		currentTier = currentTierInfo and {
			name = currentTierInfo.name,
			manaMultiplier = currentTierInfo.manaMultiplier,
			rebirthMultiplier = currentTierInfo.rebirthMultiplier,
			dustMultiplier = currentTierInfo.dustMultiplier,
			autoMana = currentTierInfo.autoMana or false,
		} or nil,
		nextTier = nextTierInfo and {
			name = nextTierInfo.name,
			cost = nextTierInfo.cost,
			manaMultiplier = nextTierInfo.manaMultiplier,
			rebirthMultiplier = nextTierInfo.rebirthMultiplier,
			dustMultiplier = nextTierInfo.dustMultiplier,
			autoMana = nextTierInfo.autoMana or false,
		} or nil,
	}
end

function WizardTierHandler.buyNextTier(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local tier = data.wizardTier or 0
	local nextTierInfo = TIERS[tier + 1]
	if not nextTierInfo then
		return false, "No further tiers yet"
	end

	if (data.mana or 0) < nextTierInfo.cost then
		return false, "Not enough Mana"
	end

	-- Full lobby reset - everything earned before this tier - except the
	-- SecondIsland gate (secondIslandUnlocked untouched) and lifetime stats
	-- that never reset (totalManaEarned, wizardTier itself, handled below).
	data.mana = 0
	data.manaYieldLevel = 1
	data.manaSpawnSpeedLevel = 1
	data.walkSpeedLevel = 1
	data.collectionRangeLevel = 1

	data.rebirths = 0
	data.manaValueMultiplierLevel = 1
	data.rebirthMultiplierLevel = 1
	data.xpMultiplierLevel = 1

	data.level = 1
	data.xp = 0

	data.arcaneDust = 0
	data.arcaneDustYieldLevel = 1
	data.arcaneDustSpawnSpeedLevel = 1
	data.manaBoostLevel = 1

	data.wizardTier = tier + 1

	-- PlayerData changing alone doesn't touch the live Humanoid.
	WalkSpeedHandler.applyCurrentSpeed(player)

	return true, nil, WizardTierHandler.getState(player)
end

return WizardTierHandler
