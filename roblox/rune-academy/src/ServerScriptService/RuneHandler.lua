-- Server-authoritative Rune gacha pulls. Client only ever asks "pull one rune" -
-- all odds math and reward granting happens here so it can't be spoofed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

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

	data.runesOpened += 1
	data.runesOwned[rank.name] = (data.runesOwned[rank.name] or 0) + 1

	for statName, multiplier in rank.statBoosts do
		data.stats[statName] = (data.stats[statName] or 1) * multiplier
	end

	return rank, nil
end

return RuneHandler
