-- Server-authoritative "More Astral Shards" upgrade for the Astral Shard
-- board (Card 2's second real upgrade) - a flat multiplier on how many
-- Astral Shard each conversion grants (AstralShardConversionHandler),
-- climbing from 1x (the base "1 Astral Shard per 1,000 Ley Shard" rate)
-- up to a steep multiple - per direct request ("The next upgrade should
-- be more astral shards. so 1000 ley shards after a couple upgrades
-- maybe lets say gives you 30 astral shards instead of 1"). 50 levels,
-- same level count as the board's other column (my own call, not
-- specified). +3.2x per level lands almost exactly on that "30 instead
-- of 1" example by level 10 (1 + 9*3.2 = 29.8), reaching ~157.8x at level
-- 50. Same exponential cost curve as AstralShardLeyBoostHandler (1.15x
-- per level, starting at 1 Astral Shard) - per direct request, "dont make
-- the cost be 1 then 2 then 3 then 4 make it spaceed out."

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 3.2
local COST_GROWTH = 1.15

local function costForLevel(currentLevel: number): number
	return math.ceil(COST_GROWTH ^ (currentLevel - 1))
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local AstralShardConversionBoostHandler = {}

-- Read by AstralShardConversionHandler.convert as a multiplier on the
-- number of Astral Shard each conversion actually grants.
function AstralShardConversionBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.astralConversionBoostLevel) or 1
	return multiplierForLevel(level)
end

function AstralShardConversionBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.astralConversionBoostLevel or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		astralShard = data.astralShard or 0,
	}
end

-- Lives physically on EtherIsland - gate on etherIslandUnlocked directly
-- here too, same defense-in-depth reasoning as every other gated handler.
function AstralShardConversionBoostHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local level = data.astralConversionBoostLevel or 1
	if level >= MAX_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.astralShard or 0) < cost then
		return false, "Not enough Astral Shard"
	end

	data.astralShard -= cost
	level += 1

	if mode == "max" then
		while level < MAX_LEVEL and data.astralShard >= costForLevel(level) do
			data.astralShard -= costForLevel(level)
			level += 1
		end
	end

	data.astralConversionBoostLevel = level

	return true, nil, AstralShardConversionBoostHandler.getUpgradeState(player)
end

return AstralShardConversionBoostHandler
