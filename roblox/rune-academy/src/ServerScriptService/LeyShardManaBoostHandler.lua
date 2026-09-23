-- Server-authoritative "More Mana" upgrade for the Ley Shard board: a flat
-- multiplier on Mana Per Pickup, exactly like ManaBoostHandler's own
-- Arcane-Dust-funded column, just paid in Ley Shard instead and leveled to
-- 50 - per direct request ("the third upgrade do more mana please up to
-- 50"). Deliberately the steepest-costing column on this whole card -
-- quadratic instead of linear - per direct request ("make that pretty
-- expensive so it might take a while"), since this is meant to be the
-- card's real long-term grind, not the yield column above it.

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 0.1 -- level 50 = 1 + 49 * 0.1 = 5.9x, same ramp as ManaBoostHandler

local function costForLevel(currentLevel: number): number
	return currentLevel * currentLevel * 50
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local LeyShardManaBoostHandler = {}

-- Read by ManaHandler as another factor in its own Mana multiplier chain.
function LeyShardManaBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.leyShardManaBoostLevel) or 1
	return multiplierForLevel(level)
end

function LeyShardManaBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.leyShardManaBoostLevel or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		leyShard = data.leyShard or 0,
	}
end

function LeyShardManaBoostHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local level = data.leyShardManaBoostLevel or 1
	if level >= MAX_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.leyShard or 0) < cost then
		return false, "Not enough Ley Shard"
	end

	data.leyShard -= cost
	level += 1

	if mode == "max" then
		while level < MAX_LEVEL and data.leyShard >= costForLevel(level) do
			data.leyShard -= costForLevel(level)
			level += 1
		end
	end

	data.leyShardManaBoostLevel = level

	return true, nil, LeyShardManaBoostHandler.getUpgradeState(player)
end

return LeyShardManaBoostHandler
