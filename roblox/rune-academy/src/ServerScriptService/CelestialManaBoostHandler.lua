-- Server-authoritative "More Mana" upgrade for the Celestial Shard board
-- (Card 3's third upgrade) - a flat multiplier on Mana Per Pickup, exactly
-- the same role LeyShardManaBoostHandler/ManaBoostHandler play on their
-- own cards, just paid in Celestial Shard. Per direct request ("FInally
-- 0-50 on more mana. Make this start at 1 but take a bit to reach 50"):
-- 50 levels, cost starts at exactly 1 Celestial Shard, quadratic growth
-- (currentLevel^2, same shape as LeyShardManaBoostHandler's own
-- currentLevel^2*50 curve just without that x50 - dropped so level 1
-- actually costs 1 as requested) so the last level costs 49*49 = 2,401
-- Celestial Shard - a real, meaningfully steep grind ("take a bit to
-- reach 50") without the "big" +per-level multiplier the card's other two
-- columns explicitly asked for, so a gentler +1x/level ramp (level 50 =
-- 1 + 49*1 = 50x).

local PlayerData = require(script.Parent.PlayerData)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 1

local function costForLevel(currentLevel: number): number
	return currentLevel * currentLevel
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local CelestialManaBoostHandler = {}

-- Read by ManaHandler as another factor in its own Mana multiplier chain.
function CelestialManaBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.celestialManaBoostLevel) or 1
	return multiplierForLevel(level)
end

function CelestialManaBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.celestialManaBoostLevel or 1
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
function CelestialManaBoostHandler.buyUpgrade(player: Player, mode: string?)
	local LeyShardFloorTileHandler = require(script.Parent.LeyShardFloorTileHandler)

	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not LeyShardFloorTileHandler.isCelestialShardUnlocked(player) then
		return false, "Celestial Shard not unlocked"
	end

	local level = data.celestialManaBoostLevel or 1
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

	data.celestialManaBoostLevel = level

	return true, nil, CelestialManaBoostHandler.getUpgradeState(player)
end

return CelestialManaBoostHandler
