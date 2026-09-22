-- Server-authoritative "Click Speed" upgrade for the Ether Shroud: how
-- often you're allowed to click it for another grant. 10 levels, 1.1s at
-- level 1 down to 0.1s at level 10, exact values per direct request.
-- Costed on its own curve (currentLevel * 10, paid in Ether), shaped like
-- ArcaneDustSpawnHandler.

local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

local MAX_SPEED_LEVEL = 10
local BASE_COOLDOWN_SECONDS = 1.1
local FASTEST_COOLDOWN_SECONDS = 0.1

local function costForLevel(currentLevel: number): number
	return currentLevel * 10
end

local function cooldownForLevel(level: number): number
	local t = (level - 1) / (MAX_SPEED_LEVEL - 1)
	return BASE_COOLDOWN_SECONDS + (FASTEST_COOLDOWN_SECONDS - BASE_COOLDOWN_SECONDS) * t
end

local EtherClickSpeedHandler = {}

-- Read by WorldBuilder's ClickDetector handler to time the next allowed
-- click for this player.
function EtherClickSpeedHandler.getCooldownSeconds(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.etherClickSpeedLevel) or 1
	return cooldownForLevel(level)
end

function EtherClickSpeedHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.etherClickSpeedLevel or 1
	local maxed = level >= MAX_SPEED_LEVEL
	return {
		level = level,
		maxLevel = MAX_SPEED_LEVEL,
		cooldownSeconds = cooldownForLevel(level),
		nextCooldownSeconds = not maxed and cooldownForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		ether = data.ether or 0,
	}
end

function EtherClickSpeedHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not UpgradeTreeHandler.isEtherUnlocked(player) then
		return false, "Ether not unlocked"
	end

	local level = data.etherClickSpeedLevel or 1
	if level >= MAX_SPEED_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.ether or 0) < cost then
		return false, "Not enough Ether"
	end

	data.ether -= cost
	level += 1

	if mode == "max" then
		while level < MAX_SPEED_LEVEL and data.ether >= costForLevel(level) do
			data.ether -= costForLevel(level)
			level += 1
		end
	end

	data.etherClickSpeedLevel = level

	return true, nil, EtherClickSpeedHandler.getUpgradeState(player)
end

return EtherClickSpeedHandler
