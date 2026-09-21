-- Server-authoritative "Arcane Dust Spawn Speed" upgrade (shown to players
-- as "Grant Speed" - how often ArcaneDustPad pays out while you stand on
-- it): 1.5s at level 1 down to 0.5s at level 10, per direct request (2.0s
-- felt too slow to start). Mirrors ManaSpawnHandler's shape; costed on its
-- own curve (currentLevel * 10, paid in Arcane Dust, not Mana's shared
-- UpgradeCost).

local PlayerData = require(script.Parent.PlayerData)

local MAX_SPEED_LEVEL = 10
local BASE_RESPAWN_SECONDS = 1.5
local FASTEST_RESPAWN_SECONDS = 0.5
local BASE_NODE_COUNT = 2
local MAX_NODE_COUNT = 6

local function costForLevel(currentLevel: number): number
	return currentLevel * 10
end

local function lerpByLevel(level: number, fromValue: number, toValue: number): number
	local t = (level - 1) / (MAX_SPEED_LEVEL - 1)
	return fromValue + (toValue - fromValue) * t
end

local function respawnSecondsForLevel(level: number): number
	return lerpByLevel(level, BASE_RESPAWN_SECONDS, FASTEST_RESPAWN_SECONDS)
end

local function nodeCountForLevel(level: number): number
	return math.floor(lerpByLevel(level, BASE_NODE_COUNT, MAX_NODE_COUNT) + 0.5)
end

local ArcaneDustSpawnHandler = {}

function ArcaneDustSpawnHandler.getRespawnSeconds(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.arcaneDustSpawnSpeedLevel) or 1
	return respawnSecondsForLevel(level)
end

function ArcaneDustSpawnHandler.getNodeCount(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.arcaneDustSpawnSpeedLevel) or 1
	return nodeCountForLevel(level)
end

function ArcaneDustSpawnHandler.getBaseNodeCount(): number
	return BASE_NODE_COUNT
end

function ArcaneDustSpawnHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.arcaneDustSpawnSpeedLevel or 1
	local maxed = level >= MAX_SPEED_LEVEL
	return {
		level = level,
		maxLevel = MAX_SPEED_LEVEL,
		respawnSeconds = respawnSecondsForLevel(level),
		nextRespawnSeconds = not maxed and respawnSecondsForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		arcaneDust = data.arcaneDust or 0,
	}
end

function ArcaneDustSpawnHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.arcaneDustSpawnSpeedLevel or 1
	if level >= MAX_SPEED_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.arcaneDust or 0) < cost then
		return false, "Not enough Arcane Dust"
	end

	data.arcaneDust -= cost
	level += 1

	if mode == "max" then
		while level < MAX_SPEED_LEVEL and data.arcaneDust >= costForLevel(level) do
			data.arcaneDust -= costForLevel(level)
			level += 1
		end
	end

	data.arcaneDustSpawnSpeedLevel = level

	return true, nil, ArcaneDustSpawnHandler.getUpgradeState(player)
end

return ArcaneDustSpawnHandler
