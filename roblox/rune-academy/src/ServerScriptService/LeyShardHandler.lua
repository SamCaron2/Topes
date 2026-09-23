-- Server-authoritative collection for Ley Shard - the first of a planned
-- 3-card wizard-material progression on EtherIsland (this game's own
-- wizard-flavored equivalent of a Bronze/Silver/Gold ladder, per direct
-- request: "Think of three wizard materials that get better with each
-- thing... instead of doing bronze silver and gold I want to do something
-- wizard, we are going to do the equivalent to that." Naming for all 3 is
-- my own call - "Ley Shard" for this first, cheapest card; "Astral Shard"
-- and "Celestial Shard" are the planned names for cards 2 and 3 later).
-- Collected passively while levitating above the Ley Shard Mat
-- (WorldBuilder's click-to-toggle loop calls collect() every tick) instead
-- of walked-over/clicked-once like every earlier resource - a deliberately
-- different, more visual interaction per direct request ("you go to the
-- mat and you click and you start levatating and you get the resource
-- every 1.1 second"). This module is just the "More Ley Shard" yield
-- track (1-100 levels); LeyShardSpeedHandler/LeyShardManaBoostHandler are
-- this card's other two columns. Mirrors ManaHandler/EtherHandler's own
-- yield-curve shape for consistency.

local PlayerData = require(script.Parent.PlayerData)
local RuneCollectionHandler = require(script.Parent.RuneCollectionHandler)

local MAX_YIELD_LEVEL = 100

-- Same mildly convex curve as every other yield upgrade in this game -
-- level 1 gives 1, level 15 gives 50.
local function amountForLevel(level: number): number
	return math.floor(level * (level + 5) / 6)
end

-- Standard "amountForLevel * 10" curve, same as every other yield board -
-- this card's real cost pressure comes from its low base trickle (only
-- while actively levitating) plus the Mana Boost column's own much
-- steeper curve, not from inflating this one too.
local function costForLevel(currentLevel: number): number
	return amountForLevel(currentLevel) * 10
end

local LeyShardHandler = {}

-- Lives entirely on EtherIsland - gate on etherIslandUnlocked directly
-- here too, not just physical containment (the mat's own ClickDetector
-- can only be reached post-unlock anyway), same defense-in-depth
-- reasoning as every other gated handler in this game.
function LeyShardHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data or not data.etherIslandUnlocked then
		return nil
	end

	local level = data.leyShardYieldLevel or 1
	local amount = math.floor(amountForLevel(level) * RuneCollectionHandler.getMultiplier(player))
	data.leyShard = (data.leyShard or 0) + amount
	return data.leyShard
end

function LeyShardHandler.getYieldUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.leyShardYieldLevel or 1
	local maxed = level >= MAX_YIELD_LEVEL
	return {
		level = level,
		maxLevel = MAX_YIELD_LEVEL,
		amountPerPickup = amountForLevel(level),
		nextAmountPerPickup = not maxed and amountForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		leyShard = data.leyShard or 0,
	}
end

-- mode "one" (default) buys a single level; "max" buys as many levels in a
-- row as the player can currently afford.
function LeyShardHandler.buyYieldUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not data.etherIslandUnlocked then
		return false, "EtherIsland not unlocked"
	end

	local level = data.leyShardYieldLevel or 1
	if level >= MAX_YIELD_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.leyShard or 0) < cost then
		return false, "Not enough Ley Shard"
	end

	data.leyShard -= cost
	level += 1

	if mode == "max" then
		while level < MAX_YIELD_LEVEL and data.leyShard >= costForLevel(level) do
			data.leyShard -= costForLevel(level)
			level += 1
		end
	end

	data.leyShardYieldLevel = level

	return true, nil, LeyShardHandler.getYieldUpgradeState(player)
end

return LeyShardHandler
