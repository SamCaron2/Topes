-- Server-authoritative "More Astral Shard" upgrade for the Celestial Shard
-- board (Card 3's second upgrade) - a flat multiplier folded into
-- AstralShardConversionHandler's own Ley->Astral conversion rate, paid in
-- Celestial Shard. Astral Shard has no yield of its own to boost (same
-- reasoning as AstralShardLeyBoostHandler boosting Ley Shard's YIELD one
-- tier down, just applied to Astral Shard's own conversion RATE instead,
-- since that's the thing Card 2 actually has), so this is the "make
-- getting more Astral Shard faster" lever this deeper layer is built
-- around - same "each grind back up gets faster than the last" philosophy
-- as the Ley<->Astral system, extended one level further. Per direct
-- request ("Then another upgrade 0-25 for more astral cards again start
-- this at 3 and make the upgrades big"): 25 levels, cost starts at exactly
-- 3 Celestial Shard, big +4x/level ramp (level 25 = 1 + 24*4 = 97x).

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 25
local MULTIPLIER_PER_LEVEL = 4
local COST_BASE = 3
local COST_GROWTH = 1.2

local function costForLevel(currentLevel: number): number
	return math.ceil(COST_BASE * COST_GROWTH ^ (currentLevel - 1))
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local CelestialAstralBoostHandler = {}

-- Read by AstralShardConversionHandler as another factor in its own
-- Ley->Astral conversion-rate multiplier chain.
function CelestialAstralBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.celestialAstralBoostLevel) or 1
	return multiplierForLevel(level)
end

function CelestialAstralBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.celestialAstralBoostLevel or 1
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
function CelestialAstralBoostHandler.buyUpgrade(player: Player, mode: string?)
	local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)

	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not LeyShardFloorTileHandler.isCelestialShardUnlocked(player) then
		return false, "Celestial Shard not unlocked"
	end

	local level = data.celestialAstralBoostLevel or 1
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

	data.celestialAstralBoostLevel = level

	return true, nil, CelestialAstralBoostHandler.getUpgradeState(player)
end

return CelestialAstralBoostHandler
