-- Server-authoritative upgrades for the Rune Altar (RuinRuneCircle on
-- SecondIsland's Fantasy Ruin) - 5 tiers, only reachable once the Ruin
-- itself is (WizardTierHandler.hasUnlockedRuin, Tier 3+), bought via the
-- nearby RuneAltarBoard (NOT by clicking the altar itself - per direct
-- correction, "There is no clicking on a ruin you just sit and it
-- collects"). Strictly linear like Wizard Tiers (buy tier N+1 only after
-- tier N), paid in Mana, cost climbing 10x per tier ("each tier gets
-- harder to unlock"). Each tier is a permanent, one-time boost to ONE
-- specific stat of the altar itself - per direct request ("each one boosts
-- a specific tribute times a certain amount") - picked to match the
-- reference screenshots' own "Rune Speed / Rune Luck / Rune Bulk" language,
-- plus two more of my own choice (my call per "this is all the info I will
-- give you"): how often it ticks, how good the odds are, how many Runes
-- per successful roll, how many independent rolls per tick, and how much
-- Mana each tick costs. RuneHandler.collectAtAltar reads all 5 getters
-- every tick.

local PlayerData = require(script.Parent.PlayerData)
local WizardTierHandler = require(script.Parent.WizardTierHandler)

-- Every effect is a flat x2 (or, for Familiar, a flat +1) - cost is the
-- only thing that scales per tier, same convention as the Upgrade Tree and
-- Wizard Tiers.
local TIERS = {
	{ name = "Rune Speed", cost = 1e9, label = "2x faster ticks (Runes/sec)" },
	{ name = "Rune Luck", cost = 1e10, label = "x2 odds toward rarer Runes" },
	{ name = "Rune Bulk", cost = 1e11, label = "x2 Runes per successful roll" },
	{ name = "Familiar", cost = 1e12, label = "+1 free extra roll per tick" },
	{ name = "Mana Efficiency", cost = 1e13, label = "Half the Mana cost per tick" },
}

local RuinRuneHandler = {}
RuinRuneHandler.TIERS = TIERS

function RuinRuneHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and WizardTierHandler.hasUnlockedRuin(player)
end

local function tierBought(player: Player, tierIndex: number): boolean
	local data = PlayerData.get(player)
	local tier = data and data.ruinRuneTier or 0
	return tier >= tierIndex
end

-- Base tick interval is 1 second - "I wanted a runes per second" - halved
-- once Rune Speed (tier 1) is bought.
local BASE_TICK_INTERVAL_SECONDS = 1

function RuinRuneHandler.getTickIntervalSeconds(player: Player): number
	if tierBought(player, 1) then
		return BASE_TICK_INTERVAL_SECONDS / 2
	end
	return BASE_TICK_INTERVAL_SECONDS
end

function RuinRuneHandler.getLuckMultiplier(player: Player): number
	return tierBought(player, 2) and 2 or 1
end

function RuinRuneHandler.getBulkMultiplier(player: Player): number
	return tierBought(player, 3) and 2 or 1
end

function RuinRuneHandler.getExtraRolls(player: Player): number
	return tierBought(player, 4) and 1 or 0
end

local BASE_MANA_COST_PER_TICK = 1000

function RuinRuneHandler.getManaCostPerTick(player: Player): number
	if tierBought(player, 5) then
		return BASE_MANA_COST_PER_TICK / 2
	end
	return BASE_MANA_COST_PER_TICK
end

function RuinRuneHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data or not RuinRuneHandler.isUnlocked(player) then
		return nil
	end

	local tier = data.ruinRuneTier or 0
	local tiers = {}
	for i, tierInfo in TIERS do
		tiers[i] = {
			name = tierInfo.name,
			label = tierInfo.label,
			cost = tierInfo.cost,
			bought = i <= tier,
			reachable = i == tier + 1,
		}
	end

	return {
		unlocked = true,
		tier = tier,
		mana = data.mana or 0,
		manaCostPerTick = RuinRuneHandler.getManaCostPerTick(player),
		tickIntervalSeconds = RuinRuneHandler.getTickIntervalSeconds(player),
		tiers = tiers,
	}
end

-- Lives entirely behind the Fantasy Ruin's own gate - checking
-- hasUnlockedRuin directly here too, not just at the RuneAltarBoard's own
-- client-side wait loop, same defense-in-depth reasoning as every other
-- SecondIsland handler.
function RuinRuneHandler.buyNextTier(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not RuinRuneHandler.isUnlocked(player) then
		return false, "Ruin not unlocked"
	end

	local tier = data.ruinRuneTier or 0
	local nextTierInfo = TIERS[tier + 1]
	if not nextTierInfo then
		return false, "No further Rune Altar tiers yet"
	end

	if (data.mana or 0) < nextTierInfo.cost then
		return false, "Not enough Mana"
	end

	data.mana -= nextTierInfo.cost
	data.ruinRuneTier = tier + 1

	return true, nil, RuinRuneHandler.getState(player)
end

return RuinRuneHandler
