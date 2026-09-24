-- Server-authoritative "More Celestial Shard" upgrade for the Celestial
-- Shard board (Card 3's first upgrade) - a flat multiplier on how many
-- Celestial Shard each conversion grants (CelestialShardConversionHandler),
-- exactly the same role AstralShardConversionBoostHandler plays one tier
-- down. Per direct request ("More celestrial shard. 50 upgrades starting
-- at costing 1 celestrial... the times is big on this celestial card by
-- the way"): 50 levels, cost starts at exactly 1 Celestial Shard, and a
-- big +5x/level ramp (level 50 = 1 + 49*5 = 246x) - bigger than either of
-- Card 2's own 50-level columns, matching "the times is big" and the
-- established pattern of each deeper prestige layer's own multiplier
-- dwarfing the one before it. Cost growth (1.15x/level, same curve
-- AstralShardConversionBoostHandler uses) kept gentler than Card 2's own
-- curves - my own call, not specified - since Celestial Shard itself is
-- already extraordinarily rare (5,000,000 Astral Shard per 1), so even a
-- modest exponential here already represents a colossal amount of
-- underlying grinding by the time it maxes out.

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 5
local COST_GROWTH = 1.15

local function costForLevel(currentLevel: number): number
	return math.ceil(COST_GROWTH ^ (currentLevel - 1))
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local CelestialConversionBoostHandler = {}

-- Read by CelestialShardConversionHandler.convert as a multiplier on the
-- number of Celestial Shard each conversion actually grants.
function CelestialConversionBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.celestialConversionBoostLevel) or 1
	return multiplierForLevel(level)
end

function CelestialConversionBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.celestialConversionBoostLevel or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		celestialShard = data.celestialShard or 0,
	}
end

-- Lives physically on EtherIsland's Celestial Shard board - gate on
-- isCelestialShardUnlocked directly here too, same defense-in-depth
-- reasoning as every other gated handler.
function CelestialConversionBoostHandler.buyUpgrade(player: Player, mode: string?)
	local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)

	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not LeyShardFloorTileHandler.isCelestialShardUnlocked(player) then
		return false, "Celestial Shard not unlocked"
	end

	local level = data.celestialConversionBoostLevel or 1
	if level >= MAX_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.celestialShard or 0) < cost then
		return false, "Not enough Celestial Shard"
	end

	data.celestialShard -= cost
	level += 1

	if mode == "max" then
		while level < MAX_LEVEL and data.celestialShard >= costForLevel(level) do
			data.celestialShard -= costForLevel(level)
			level += 1
		end
	end

	data.celestialConversionBoostLevel = level

	return true, nil, CelestialConversionBoostHandler.getUpgradeState(player)
end

return CelestialConversionBoostHandler
