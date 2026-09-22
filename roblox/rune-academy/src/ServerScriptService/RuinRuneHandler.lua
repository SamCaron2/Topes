-- Server-authoritative Runes: 5 tiers unlocked by clicking the Fantasy
-- Ruin's orb (see WorldBuilder's ClickDetector on RuinOrb), only reachable
-- once the Ruin itself is (WizardTierHandler.hasUnlockedRuin, Tier 3+) -
-- per direct request ("for this rune we made on island 2 lets do 5 tiers").
-- Strictly linear like Wizard Tiers (buy tier N+1 only after tier N), paid
-- in Mana, and NEVER reset by anything - each tier is a permanent, one-time
-- x2 to one specific resource, per direct request ("each one boosts a
-- specific tribute times a certain amount"). Cost climbs 10x per tier
-- ("each tier gets harder to unlock"), same "cost scales, effect stays a
-- flat x2" convention as the Upgrade Tree.
--
-- Names and exact costs/targets are my call, per direct request ("this is
-- all the info I will give you") - picked from the game's own Rune rarity
-- ladder (GameConfig.RuneRanks) for theme, one tier per core resource:
-- Mana, Arcane Dust, Ether, Rebirths, and Rune Bulk (the pull-size boost
-- from Upgrade Tree Tile 5).

local PlayerData = require(script.Parent.PlayerData)
local WizardTierHandler = require(script.Parent.WizardTierHandler)

local TIERS = {
	{ name = "Apprentice Rune", cost = 1e9, kind = "mana", multiplier = 2, label = "Mana x2" },
	{ name = "Adept Rune", cost = 1e10, kind = "dust", multiplier = 2, label = "Arcane Dust x2" },
	{ name = "Master Rune", cost = 1e11, kind = "ether", multiplier = 2, label = "Ether x2" },
	{ name = "Archmage Rune", cost = 1e12, kind = "rebirth", multiplier = 2, label = "Rebirths x2" },
	{ name = "Ascendant Rune", cost = 1e13, kind = "runeBulk", multiplier = 2, label = "Rune Bulk x2" },
}

local RuinRuneHandler = {}
RuinRuneHandler.TIERS = TIERS

function RuinRuneHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and WizardTierHandler.hasUnlockedRuin(player)
end

-- Folds every bought tier matching `kind` together (multiplicatively) -
-- only ever one match per kind today, but written the same way as
-- UpgradeTreeHandler's foldMultiplier so a future tier re-using a kind
-- just works.
function RuinRuneHandler.getMultiplier(player: Player, kind: string): number
	local data = PlayerData.get(player)
	if not data then
		return 1
	end

	local tier = data.ruinRuneTier or 0
	local multiplier = 1
	for i = 1, tier do
		local tierInfo = TIERS[i]
		if tierInfo and tierInfo.kind == kind then
			multiplier *= tierInfo.multiplier
		end
	end
	return multiplier
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
		tiers = tiers,
	}
end

-- Lives entirely behind the Fantasy Ruin's own gate - checking
-- hasUnlockedRuin directly here too, not just at the WorldBuilder
-- ClickDetector call site, same defense-in-depth reasoning as every other
-- SecondIsland handler (a containment/reveal bug should never be able to
-- let this get bought early).
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
		return false, "No further Runes yet"
	end

	if (data.mana or 0) < nextTierInfo.cost then
		return false, "Not enough Mana"
	end

	data.mana -= nextTierInfo.cost
	data.ruinRuneTier = tier + 1

	return true, nil, RuinRuneHandler.getState(player)
end

return RuinRuneHandler
