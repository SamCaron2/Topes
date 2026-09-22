-- Server-authoritative "More Dust" upgrade: the Ether board's 3rd column,
-- per direct request ("50 upgrades of more dust"). Mirrors
-- ManaBoostHandler exactly (same 50-level, 1x-6x curve, same cost curve)
-- but the other direction down the resource chain - Ether (the newest,
-- deepest resource) boosting Arcane Dust (the one below it), the same way
-- Arcane Dust's own "More Mana" boosts Mana (the one below that).

local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

local MAX_LEVEL = 50
local MULTIPLIER_PER_LEVEL = 0.1 -- level 50 = 1 + 49 * 0.1 = 5.9x

local function costForLevel(currentLevel: number): number
	return currentLevel * 25
end

local function multiplierForLevel(level: number): number
	return 1 + (level - 1) * MULTIPLIER_PER_LEVEL
end

local EtherDustBoostHandler = {}

function EtherDustBoostHandler.getMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.etherDustBoostLevel) or 1
	return multiplierForLevel(level)
end

function EtherDustBoostHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.etherDustBoostLevel or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		ether = data.ether or 0,
	}
end

function EtherDustBoostHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not UpgradeTreeHandler.isEtherUnlocked(player) then
		return false, "Ether not unlocked"
	end

	local level = data.etherDustBoostLevel or 1
	if level >= MAX_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.ether or 0) < cost then
		return false, "Not enough Ether"
	end

	data.ether -= cost
	level += 1

	if mode == "max" then
		while level < MAX_LEVEL and data.ether >= costForLevel(level) do
			data.ether -= costForLevel(level)
			level += 1
		end
	end

	data.etherDustBoostLevel = level

	return true, nil, EtherDustBoostHandler.getUpgradeState(player)
end

return EtherDustBoostHandler
