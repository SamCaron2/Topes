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
-- Only Tier 1 is defined so far; TIERS is built so more can be appended
-- later without touching the logic below.

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
}

local WizardTierHandler = {}

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
		} or nil,
		nextTier = nextTierInfo and {
			name = nextTierInfo.name,
			cost = nextTierInfo.cost,
			manaMultiplier = nextTierInfo.manaMultiplier,
			rebirthMultiplier = nextTierInfo.rebirthMultiplier,
			dustMultiplier = nextTierInfo.dustMultiplier,
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
