-- Server-authoritative Mana collection and its one upgrade so far: a player
-- touches a ManaNode part on the ground and gets Mana equal to their current
-- "Mana Per Pickup" level (starts at 1, buyable up to 100, +1 per level).
-- Kept separate from ResourceEngine since this is a fresh, much simpler
-- mechanic for the new vision - no Zones wired to it yet.

local PlayerData = require(script.Parent.PlayerData)
local UpgradeCost = require(script.Parent.UpgradeCost)

local MAX_YIELD_LEVEL = 100

local ManaHandler = {}

-- How much Mana one pickup grants right now.
local function getYieldAmount(data): number
	return data.manaYieldLevel or 1
end

function ManaHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	data.mana = (data.mana or 0) + getYieldAmount(data)
	return data.mana
end

-- Read-only snapshot for the kiosk UI: current level, current yield, the
-- yield one more level would give, and the Mana cost to buy it (nil once maxed).
function ManaHandler.getYieldUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.manaYieldLevel or 1
	local maxed = level >= MAX_YIELD_LEVEL
	return {
		level = level,
		maxLevel = MAX_YIELD_LEVEL,
		amountPerPickup = getYieldAmount(data),
		nextAmountPerPickup = not maxed and (level + 1) or nil,
		nextLevelCost = not maxed and UpgradeCost.costForLevel(level + 1) or nil,
		mana = data.mana or 0,
	}
end

-- mode "one" (default) buys a single level; "max" buys as many levels in a
-- row as the player can currently afford (at least one, or it fails same as
-- "one" would).
function ManaHandler.buyYieldUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.manaYieldLevel or 1
	if level >= MAX_YIELD_LEVEL then
		return false, "Already at max level"
	end

	local cost = UpgradeCost.costForLevel(level + 1)
	if (data.mana or 0) < cost then
		return false, "Not enough Mana"
	end

	data.mana -= cost
	level += 1

	if mode == "max" then
		while level < MAX_YIELD_LEVEL and data.mana >= UpgradeCost.costForLevel(level + 1) do
			data.mana -= UpgradeCost.costForLevel(level + 1)
			level += 1
		end
	end

	data.manaYieldLevel = level

	return true, nil, ManaHandler.getYieldUpgradeState(player)
end

return ManaHandler
