-- Server-authoritative Ether collection and its "More Ether" upgrade - the
-- third wizard resource, click-collected via a ClickDetector on the Ether
-- Shroud (see WorldBuilder) instead of auto-collected like Mana or
-- walked-over like Arcane Dust, per direct request. Mirrors
-- ArcaneDustHandler's exact shape and yield curve for consistency.

local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

local MAX_YIELD_LEVEL = 100

-- Same mildly convex curve as Mana/Arcane Dust's own yield upgrades -
-- later levels pay off faster than early ones. Level 1 gives 1, level 15
-- gives 50.
local function amountForLevel(level: number): number
	return math.floor(level * (level + 5) / 6)
end

-- Cost tracks the yield curve itself (amountForLevel * 10), same reasoning
-- as Mana/Arcane Dust: a flat level*10 curve made high levels feel cheap
-- relative to the payoff they were giving.
local function costForLevel(currentLevel: number): number
	return amountForLevel(currentLevel) * 10
end

local EtherHandler = {}

-- Ether requires Upgrade Tree Tile 9, which itself transitively requires
-- SecondIsland to be unlocked - but checking isEtherUnlocked directly here
-- too (not just at the WorldBuilder ClickDetector call site) means this
-- stays true even if called some other way, not just relying on every
-- caller remembering to check first.
function EtherHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data or not UpgradeTreeHandler.isEtherUnlocked(player) then
		return nil
	end
	local level = data.etherYieldLevel or 1
	data.ether = (data.ether or 0) + amountForLevel(level)
	return data.ether
end

function EtherHandler.getYieldUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.etherYieldLevel or 1
	local maxed = level >= MAX_YIELD_LEVEL
	return {
		level = level,
		maxLevel = MAX_YIELD_LEVEL,
		amountPerPickup = amountForLevel(level),
		nextAmountPerPickup = not maxed and amountForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		ether = data.ether or 0,
	}
end

-- mode "one" (default) buys a single level; "max" buys as many levels in a
-- row as the player can currently afford.
function EtherHandler.buyYieldUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not UpgradeTreeHandler.isEtherUnlocked(player) then
		return false, "Ether not unlocked"
	end

	local level = data.etherYieldLevel or 1
	if level >= MAX_YIELD_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.ether or 0) < cost then
		return false, "Not enough Ether"
	end

	data.ether -= cost
	level += 1

	if mode == "max" then
		while level < MAX_YIELD_LEVEL and data.ether >= costForLevel(level) do
			data.ether -= costForLevel(level)
			level += 1
		end
	end

	data.etherYieldLevel = level

	return true, nil, EtherHandler.getYieldUpgradeState(player)
end

return EtherHandler
