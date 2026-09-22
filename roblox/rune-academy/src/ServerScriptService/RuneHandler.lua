-- Server-authoritative Rune gacha pulls. Client only ever asks "pull one rune" -
-- all odds math and reward granting happens here so it can't be spoofed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)
local RuinRuneHandler = require(script.Parent.RuinRuneHandler)

local RuneHandler = {}

-- Fortune shifts weight toward rarer ranks: each point of Fortune above 1
-- multiplies a rank's effective weight by fortuneBias^rankIndex, so higher
-- ranks (which sit later in GameConfig.RuneRanks) benefit more.
local FORTUNE_BIAS_PER_POINT = 0.02

local function weightedPick(fortune: number)
	local weights = {}
	local totalWeight = 0

	for index, rank in GameConfig.RuneRanks do
		local baseWeight = 1 / rank.oddsOneIn
		local fortuneMultiplier = (1 + FORTUNE_BIAS_PER_POINT * (fortune - 1)) ^ index
		local weight = baseWeight * fortuneMultiplier
		weights[index] = weight
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for index, weight in weights do
		cumulative += weight
		if roll <= cumulative then
			return GameConfig.RuneRanks[index]
		end
	end

	return GameConfig.RuneRanks[1]
end

function RuneHandler.pull(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil, "No data loaded"
	end

	if data.scrolls < GameConfig.ScrollCostPerPull then
		return nil, "Not enough Scrolls"
	end

	data.scrolls -= GameConfig.ScrollCostPerPull

	local fortune = data.stats.Fortune or 1
	local rank = weightedPick(fortune)

	-- Rune Bulk (Upgrade Tree Tile 5) multiplies how many of this rank a
	-- single pull actually grants - banked here now even with no pull UI
	-- wired up yet, per direct request ("we can do that another time I
	-- just want it on the tile").
	local runeBulk = UpgradeTreeHandler.getRuneBulkMultiplier(player)
	data.runesOpened += runeBulk
	data.runesOwned[rank.name] = (data.runesOwned[rank.name] or 0) + runeBulk

	for statName, multiplier in rank.statBoosts do
		data.stats[statName] = (data.stats[statName] or 1) * multiplier
	end

	return rank, nil
end

-- The Rune Altar (RuinRuneCircle on the Fantasy Ruin): stand on it and it
-- periodically spends Mana for a chance-based Rune, no clicking involved -
-- per direct correction ("There is no clicking on a ruin you just sit and
-- it collects... it cost mana to sit on the rune"). Called once per tick by
-- WorldBuilder's proximity loop for whichever player is currently standing
-- on it; safely no-ops (returns nil) if not unlocked or Mana is too low,
-- same "silently do nothing" shape as every other collection handler here.
-- Separate from `pull` above (that one is the older Scroll-costed manual
-- pull, unrelated to standing on the Altar) so RuinRuneHandler's Altar-only
-- upgrades (Rune Luck/Bulk/Familiar) never leak into it.
function RuneHandler.collectAtAltar(player: Player)
	local data = PlayerData.get(player)
	if not data or not RuinRuneHandler.isUnlocked(player) then
		return nil
	end

	local manaCost = RuinRuneHandler.getManaCostPerTick(player)
	if (data.mana or 0) < manaCost then
		return nil
	end
	data.mana -= manaCost

	local fortune = (data.stats.Fortune or 1) * RuinRuneHandler.getLuckMultiplier(player)
	local runeBulk = UpgradeTreeHandler.getRuneBulkMultiplier(player) * RuinRuneHandler.getBulkMultiplier(player)
	local rollCount = 1 + RuinRuneHandler.getExtraRolls(player)

	local results = {}
	for i = 1, rollCount do
		local rank = weightedPick(fortune)
		data.runesOpened += runeBulk
		data.runesOwned[rank.name] = (data.runesOwned[rank.name] or 0) + runeBulk

		for statName, multiplier in rank.statBoosts do
			data.stats[statName] = (data.stats[statName] or 1) * multiplier
		end

		results[i] = { name = rank.name, amount = runeBulk }
	end

	return results, data.mana
end

return RuneHandler
