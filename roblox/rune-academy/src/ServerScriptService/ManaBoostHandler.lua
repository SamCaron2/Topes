-- Server-authoritative "More Mana" upgrade: a third Arcane Dust Upgrades
-- board column, per direct request ("another upgrade for mana, 50 total
-- upgrades, make them cost dust"). Unlike Arcane Dust's own two columns,
-- this one boosts Mana Per Pickup instead - a flat multiplier climbing
-- linearly from 1x at level 1 to 6x at level 50 (+0.1x per level), paid in
-- Arcane Dust. Mirrors ArcaneDustSpawnHandler's shape.

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 0.1 -- level 50 = 1 + 49 * 0.1 = 5.9x

local function costForLevel(currentLevel: number): number
	return currentLevel * 25
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local ManaBoostHandler = {}

function ManaBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.manaBoostLevel) or 1
	return multiplierForLevel(level)
end

function ManaBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.manaBoostLevel or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		arcaneDust = data.arcaneDust or 0,
	}
end

-- Lives physically on SecondIsland's Arcane Dust board - gated on
-- secondIslandUnlocked too, not just physical containment, so a
-- containment bug can't let anyone buy this from behind a locked door.
function ManaBoostHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.secondIslandUnlocked then
		return false, "SecondIsland not unlocked"
	end

	local level = data.manaBoostLevel or 1
	if level >= MAX_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.arcaneDust or 0) < cost then
		return false, "Not enough Arcane Dust"
	end

	data.arcaneDust -= cost
	level += 1

	if mode == "max" then
		while level < MAX_LEVEL and data.arcaneDust >= costForLevel(level) do
			data.arcaneDust -= costForLevel(level)
			level += 1
		end
	end

	data.manaBoostLevel = level

	return true, nil, ManaBoostHandler.getUpgradeState(player)
end

return ManaBoostHandler
