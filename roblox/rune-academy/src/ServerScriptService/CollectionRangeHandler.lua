-- Server-authoritative "Collection Range" upgrade: grows the radius around
-- the player that automatically collects any Mana node inside it (checked
-- by WorldBuilder's collection loop). 12 levels, radius linear from 3 studs
-- (level 1 - matches the feet-ring's original fixed radius) to 9 (level 12,
-- halved from 18 - the old max felt too strong).
--
-- Costed on its OWN curve, deliberately not through the shared UpgradeCost
-- module, per direct request: the first purchase (currently at level 1)
-- costs 50 Mana, climbing linearly to 495 for the last purchase (currently
-- at level 11, buying into level 12) - a fixed target picked to be roughly
-- half of "More Mana"'s old (since-changed) level 100 cost; no longer tied
-- to that value directly now that More Mana's own curve is convex.

local PlayerData = require(script.Parent.PlayerData)

local MAX_RANGE_LEVEL = 12
local BASE_RADIUS = 3
local MAX_RADIUS = 9
local FIRST_PURCHASE_COST = 50
local LAST_PURCHASE_COST = 495

local function radiusForLevel(level: number): number
	local t = (level - 1) / (MAX_RANGE_LEVEL - 1)
	return BASE_RADIUS + (MAX_RADIUS - BASE_RADIUS) * t
end

-- currentLevel runs 1..(MAX_RANGE_LEVEL - 1) - the last level you ever buy
-- FROM, since level MAX_RANGE_LEVEL has nothing left to purchase.
local function costForLevel(currentLevel: number): number
	local lastPurchasableLevel = MAX_RANGE_LEVEL - 1
	local t = (currentLevel - 1) / (lastPurchasableLevel - 1)
	return math.floor(FIRST_PURCHASE_COST + (LAST_PURCHASE_COST - FIRST_PURCHASE_COST) * t + 0.5)
end

local CollectionRangeHandler = {}

-- Read by WorldBuilder's collection loop and by ManaRingClient, so the
-- visible ring always matches the real pickup radius.
function CollectionRangeHandler.getRadius(player: Player): number
	local data = PlayerData.get(player)
	local level = (data and data.collectionRangeLevel) or 1
	return radiusForLevel(level)
end

function CollectionRangeHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.collectionRangeLevel or 1
	local maxed = level >= MAX_RANGE_LEVEL
	return {
		level = level,
		maxLevel = MAX_RANGE_LEVEL,
		radius = radiusForLevel(level),
		nextRadius = not maxed and radiusForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		mana = data.mana or 0,
	}
end

function CollectionRangeHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.collectionRangeLevel or 1
	if level >= MAX_RANGE_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.mana or 0) < cost then
		return false, "Not enough Mana"
	end

	data.mana -= cost
	level += 1

	if mode == "max" then
		while level < MAX_RANGE_LEVEL and data.mana >= costForLevel(level) do
			data.mana -= costForLevel(level)
			level += 1
		end
	end

	data.collectionRangeLevel = level

	return true, nil, CollectionRangeHandler.getUpgradeState(player)
end

return CollectionRangeHandler
