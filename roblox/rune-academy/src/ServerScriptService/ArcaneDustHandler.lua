-- Server-authoritative Arcane Dust collection and its "More Arcane Dust"
-- upgrade - the second wizard resource, entirely separate from Mana (no
-- Rebirth Shop multiplier, no interaction with Rebirths at all). Mirrors
-- ManaHandler's shape and yield curve for consistency, just its own
-- currency/upgrade level fields.

local PlayerData = require(script.Parent.PlayerData)

local MAX_YIELD_LEVEL = 100

-- Same mildly convex curve as Mana's "Mana Per Pickup" - later levels pay
-- off faster than early ones. Level 1 gives 1, level 15 gives 50.
local function amountForLevel(level: number): number
	return math.floor(level * (level + 5) / 6)
end

-- Cost tracks the yield curve itself (amountForLevel * 10), same reasoning
-- as ManaHandler: a flat level*10 curve made high levels feel cheap
-- relative to the payoff they were giving.
local function costForLevel(currentLevel: number): number
	return amountForLevel(currentLevel) * 10
end

local ArcaneDustHandler = {}

function ArcaneDustHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local level = data.arcaneDustYieldLevel or 1
	data.arcaneDust = (data.arcaneDust or 0) + amountForLevel(level)
	return data.arcaneDust
end

function ArcaneDustHandler.getYieldUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.arcaneDustYieldLevel or 1
	local maxed = level >= MAX_YIELD_LEVEL
	return {
		level = level,
		maxLevel = MAX_YIELD_LEVEL,
		amountPerPickup = amountForLevel(level),
		nextAmountPerPickup = not maxed and amountForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		arcaneDust = data.arcaneDust or 0,
	}
end

-- mode "one" (default) buys a single level; "max" buys as many levels in a
-- row as the player can currently afford.
function ArcaneDustHandler.buyYieldUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.arcaneDustYieldLevel or 1
	if level >= MAX_YIELD_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.arcaneDust or 0) < cost then
		return false, "Not enough Arcane Dust"
	end

	data.arcaneDust -= cost
	level += 1

	if mode == "max" then
		while level < MAX_YIELD_LEVEL and data.arcaneDust >= costForLevel(level) do
			data.arcaneDust -= costForLevel(level)
			level += 1
		end
	end

	data.arcaneDustYieldLevel = level

	return true, nil, ArcaneDustHandler.getYieldUpgradeState(player)
end

return ArcaneDustHandler
