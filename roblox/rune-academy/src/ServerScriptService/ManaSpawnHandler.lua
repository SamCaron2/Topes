-- Server-authoritative "Mana Spawn Speed" upgrade: shortens how long it
-- takes a new ManaNode to respawn after the BUYING player collects one.
-- 10 levels, linear from 2.0s (level 1, the current base rate) down to 0.2s
-- (level 10). Costed through the same UpgradeCost curve as every other Mana
-- upgrade, so it lines up with "More Mana" level-for-level.

local PlayerData = require(script.Parent.PlayerData)
local UpgradeCost = require(script.Parent.UpgradeCost)

local MAX_SPEED_LEVEL = 10
local BASE_RESPAWN_SECONDS = 2.0
local FASTEST_RESPAWN_SECONDS = 0.2

local function respawnSecondsForLevel(level: number): number
	local t = (level - 1) / (MAX_SPEED_LEVEL - 1)
	return BASE_RESPAWN_SECONDS + (FASTEST_RESPAWN_SECONDS - BASE_RESPAWN_SECONDS) * t
end

local ManaSpawnHandler = {}

-- Read by WorldBuilder right after the given player collects a node, to time
-- that node's replacement.
function ManaSpawnHandler.getRespawnSeconds(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.manaSpawnSpeedLevel) or 1
	return respawnSecondsForLevel(level)
end

function ManaSpawnHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.manaSpawnSpeedLevel or 1
	local maxed = level >= MAX_SPEED_LEVEL
	return {
		level = level,
		maxLevel = MAX_SPEED_LEVEL,
		respawnSeconds = respawnSecondsForLevel(level),
		nextRespawnSeconds = not maxed and respawnSecondsForLevel(level + 1) or nil,
		nextLevelCost = not maxed and UpgradeCost.costForLevel(level + 1) or nil,
		mana = data.mana or 0,
	}
end

function ManaSpawnHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.manaSpawnSpeedLevel or 1
	if level >= MAX_SPEED_LEVEL then
		return false, "Already at max level"
	end

	local cost = UpgradeCost.costForLevel(level + 1)
	if (data.mana or 0) < cost then
		return false, "Not enough Mana"
	end

	data.mana -= cost
	level += 1

	if mode == "max" then
		while level < MAX_SPEED_LEVEL and data.mana >= UpgradeCost.costForLevel(level + 1) do
			data.mana -= UpgradeCost.costForLevel(level + 1)
			level += 1
		end
	end

	data.manaSpawnSpeedLevel = level

	return true, nil, ManaSpawnHandler.getUpgradeState(player)
end

return ManaSpawnHandler
