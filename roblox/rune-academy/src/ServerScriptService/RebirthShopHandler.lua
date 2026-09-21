-- Server-authoritative Rebirth Shop: permanent upgrades bought with
-- Rebirths, NOT reset when you rebirth (unlike the Mana-side upgrades,
-- which DO reset - see RebirthHandler.rebirth) - that's the whole point,
-- so each rebirth run collects Mana faster than the last. Currently just
-- one column: "Mana Value Multiplier" (level 1-100, linear 1x -> 200x,
-- first purchase costs 1 Rebirth, cost climbs by 1 Rebirth per level
-- after). Two more columns are planned for this same board later.

local PlayerData = require(script.Parent.PlayerData)

local MAX_MULTIPLIER_LEVEL = 100
local MIN_MULTIPLIER = 1
local MAX_MULTIPLIER = 200

local function multiplierForLevel(level: number): number
	local t = (level - 1) / (MAX_MULTIPLIER_LEVEL - 1)
	return MIN_MULTIPLIER + (MAX_MULTIPLIER - MIN_MULTIPLIER) * t
end

-- Cost is in Rebirths, not Mana: 1 Rebirth for the first purchase (from
-- level 1), climbing by 1 Rebirth per level after.
local function costForLevel(currentLevel: number): number
	return currentLevel
end

local RebirthShopHandler = {}

-- Read by ManaHandler so every pickup is scaled by this permanent multiplier.
function RebirthShopHandler.getManaValueMultiplier(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.manaValueMultiplierLevel) or 1
	return multiplierForLevel(level)
end

function RebirthShopHandler.getManaValueMultiplierState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.manaValueMultiplierLevel or 1
	local maxed = level >= MAX_MULTIPLIER_LEVEL
	return {
		level = level,
		maxLevel = MAX_MULTIPLIER_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		rebirths = data.rebirths or 0,
	}
end

function RebirthShopHandler.buyManaValueMultiplier(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.manaValueMultiplierLevel or 1
	if level >= MAX_MULTIPLIER_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.rebirths or 0) < cost then
		return false, "Not enough Rebirths"
	end

	data.rebirths -= cost
	level += 1

	if mode == "max" then
		while level < MAX_MULTIPLIER_LEVEL and data.rebirths >= costForLevel(level) do
			data.rebirths -= costForLevel(level)
			level += 1
		end
	end

	data.manaValueMultiplierLevel = level

	return true, nil, RebirthShopHandler.getManaValueMultiplierState(player)
end

return RebirthShopHandler
