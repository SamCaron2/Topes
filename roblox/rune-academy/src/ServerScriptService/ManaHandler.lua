-- Server-authoritative Mana collection and its one upgrade so far: a player
-- touches a ManaNode part on the ground and gets Mana per their current
-- "Mana Per Pickup" level (1-100). Kept separate from ResourceEngine since
-- this is a fresh, much simpler mechanic for the new vision - no Zones
-- wired to it yet.

local PlayerData = require(script.Parent.PlayerData)
local RebirthShopHandler = require(script.Parent.RebirthShopHandler)
local ManaBoostHandler = require(script.Parent.ManaBoostHandler)
local WizardTierHandler = require(script.Parent.WizardTierHandler)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)
local RuneCollectionHandler = require(script.Parent.RuneCollectionHandler)
local LeyShardManaBoostHandler = require(script.Parent.LeyShardManaBoostHandler)

local MAX_YIELD_LEVEL = 100

-- Mana Per Pickup's yield curve: mildly convex, not a flat +1/level, so
-- later levels pay off faster than early ones (per direct request to "mix
-- it up" rather than a straight line). Level 1 gives exactly 1 (the base,
-- unupgraded rate); by level 15 it's 50 - close to the ~46 that was asked
-- for, given as a rough target rather than an exact one. Easy to retune:
-- adjust the +5 / 6 constants.
local function amountForLevel(level: number): number
	return math.floor(level * (level + 5) / 6)
end

-- Cost tracks the yield curve itself (amountForLevel * 10) instead of the
-- shared UpgradeCost's flat level*10 - a flat curve made high levels feel
-- cheap relative to the payoff they were giving (e.g. level 10 only cost
-- ~90 for +25/pickup). This keeps the "payback" ratio roughly consistent
-- the whole way up: level 1 still costs 10 (unchanged), but level 9 (to
-- reach level 10, which gives +25/pickup) now costs 210 instead of 90.
local function costForLevel(currentLevel: number): number
	return amountForLevel(currentLevel) * 10
end

local ManaHandler = {}

-- Effective yield per pickup: the base yield curve scaled by the Rebirth
-- Shop's permanent "Mana Value Multiplier" (1x-2x, survives rebirthing -
-- that's the whole point), the Arcane Dust board's "More Mana" upgrade
-- (1x-6x), the Wizard Tier flat multiplier (1x until Tier 1, then 20x),
-- the Upgrade Tree's own Mana tiles (x2 each, x4 combined once both are
-- bought), the Rune collection bonus (RuneCollectionHandler - +0.2x per
-- copy owned of each Rune rank, capped at x5 per rank, all 9 ranks' own
-- multipliers combined together), and the Ley Shard board's own "More
-- Mana" column (LeyShardManaBoostHandler - 1x-5.9x, paid in Ley Shard).
-- Floored to keep Mana a whole number.
local function effectiveAmountForLevel(player: Player, level: number): number
	return math.floor(
		amountForLevel(level)
			* RebirthShopHandler.getManaValueMultiplier(player)
			* ManaBoostHandler.getMultiplier(player)
			* WizardTierHandler.getManaMultiplier(player)
			* UpgradeTreeHandler.getManaMultiplier(player)
			* RuneCollectionHandler.getMultiplier(player)
			* LeyShardManaBoostHandler.getMultiplier(player)
	)
end

function ManaHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	local amount = effectiveAmountForLevel(player, data.manaYieldLevel or 1)
	data.mana = (data.mana or 0) + amount
	-- Separate from the live balance above (which rebirthing resets to 0) -
	-- this is the lifetime total for the "Total Mana" leaderboard, so a
	-- rebirth never erases a player's standing on it.
	data.totalManaEarned = (data.totalManaEarned or 0) + amount
	return data.mana
end

-- Read-only snapshot for the kiosk UI: current level, current yield, the
-- yield one more level would give, and the Mana cost to buy it (nil once
-- maxed). amountPerPickup/nextAmountPerPickup already include the Rebirth
-- Shop multiplier, so the board always shows the real effective yield.
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
		amountPerPickup = effectiveAmountForLevel(player, level),
		nextAmountPerPickup = not maxed and effectiveAmountForLevel(player, level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
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

	local cost = costForLevel(level)
	if (data.mana or 0) < cost then
		return false, "Not enough Mana"
	end

	data.mana -= cost
	level += 1

	if mode == "max" then
		while level < MAX_YIELD_LEVEL and data.mana >= costForLevel(level) do
			data.mana -= costForLevel(level)
			level += 1
		end
	end

	data.manaYieldLevel = level

	return true, nil, ManaHandler.getYieldUpgradeState(player)
end

return ManaHandler
