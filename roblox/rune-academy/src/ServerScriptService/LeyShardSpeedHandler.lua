-- Server-authoritative "Faster Levitation" upgrade for the Ley Shard Mat:
-- how often a levitating player gets paid out. 10 levels, the same linear
-- interpolation shape as EtherClickSpeedHandler (base cooldown down to a
-- fastest one) - just floating instead of clicking. Costed steeper than
-- Ether's own Click Speed (quadratic in Ley Shard instead of a flat
-- currentLevel*10) since this whole card is meant to be a noticeably
-- longer grind than the early boards, per direct request ("make that
-- pretty expensive so it might take a while").

local PlayerData = require(script.Parent.PlayerData)

local MAX_SPEED_LEVEL = 10
local BASE_INTERVAL_SECONDS = 1.1 -- "you get the resource every 1.1 second," per direct request
local FASTEST_INTERVAL_SECONDS = 0.3

local function costForLevel(currentLevel: number): number
	return currentLevel * currentLevel * 30
end

local function intervalForLevel(level: number): number
	local t = (level - 1) / (MAX_SPEED_LEVEL - 1)
	return BASE_INTERVAL_SECONDS + (FASTEST_INTERVAL_SECONDS - BASE_INTERVAL_SECONDS) * t
end

local LeyShardSpeedHandler = {}

-- Read by WorldBuilder's levitation loop to time each player's next payout.
function LeyShardSpeedHandler.getIntervalSeconds(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.leyShardSpeedLevel) or 1
	return intervalForLevel(level)
end

function LeyShardSpeedHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.leyShardSpeedLevel or 1
	local maxed = level >= MAX_SPEED_LEVEL
	return {
		level = level,
		maxLevel = MAX_SPEED_LEVEL,
		intervalSeconds = intervalForLevel(level),
		nextIntervalSeconds = not maxed and intervalForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		leyShard = data.leyShard or 0,
	}
end

function LeyShardSpeedHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local level = data.leyShardSpeedLevel or 1
	if level >= MAX_SPEED_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.leyShard or 0) < cost then
		return false, "Not enough Ley Shard"
	end

	data.leyShard -= cost
	level += 1

	if mode == "max" then
		while level < MAX_SPEED_LEVEL and data.leyShard >= costForLevel(level) do
			data.leyShard -= costForLevel(level)
			level += 1
		end
	end

	data.leyShardSpeedLevel = level

	return true, nil, LeyShardSpeedHandler.getUpgradeState(player)
end

return LeyShardSpeedHandler
