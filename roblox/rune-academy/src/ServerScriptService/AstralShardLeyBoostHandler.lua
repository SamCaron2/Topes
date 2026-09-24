-- Server-authoritative "More Ley Shard" upgrade for the Astral Shard
-- board (Card 2's first real upgrade) - a flat multiplier on Ley Shard
-- yield, exactly like ManaBoostHandler's/LeyShardManaBoostHandler's own
-- shape (1x-5.9x over 50 levels), just paid in Astral Shard instead and
-- read by LeyShardHandler. Crucially, this is NOT one of the 3 Ley Shard
-- board levels that get wiped every time Ley Shard is converted into
-- Astral Shard (AstralShardConversionHandler.convert) - it's the whole
-- point of Card 2: a permanent boost that survives every reset, so the
-- SECOND (and every later) grind back up the Ley Shard board goes faster
-- than the first - per direct request ("to max out ley shards it takes a
-- bit but when you exchange for astral shards and buy more ley shards it
-- goes by quicker the second time"). Costed on an exponential curve (my
-- own call - "dont make the cost be 1 then 2 then 3 then 4 make it
-- spaceed out how you think the game should flow and keep someones
-- attention"): 1.15x per level, starting at exactly 1 Astral Shard for
-- level 1 per direct request, climbing to ~658 Astral Shard for the very
-- last level.

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 0.1 -- level 50 = 1 + 49 * 0.1 = 5.9x, same ramp as ManaBoostHandler/LeyShardManaBoostHandler
local COST_GROWTH = 1.15

local function costForLevel(currentLevel: number): number
	return math.ceil(COST_GROWTH ^ (currentLevel - 1))
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local AstralShardLeyBoostHandler = {}

-- Read by LeyShardHandler as another factor in its own Ley Shard yield
-- multiplier chain.
function AstralShardLeyBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.astralShardLeyBoostLevel) or 1
	return multiplierForLevel(level)
end

function AstralShardLeyBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.astralShardLeyBoostLevel or 1
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
function AstralShardLeyBoostHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local level = data.astralShardLeyBoostLevel or 1
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

	data.astralShardLeyBoostLevel = level

	return true, nil, AstralShardLeyBoostHandler.getUpgradeState(player)
end

return AstralShardLeyBoostHandler
