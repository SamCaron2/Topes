-- Handles the tier-to-tier "cash in" resets (Mana -> Essence -> Gold) and
-- full Ascension resets. Both follow the same shape: check requirement,
-- zero out what's being reset, grant the permanent reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local ResetHandler = {}

function ResetHandler.resetTier(player: Player, tierName: string)
	local data = PlayerData.get(player)
	if not data then
		return false, "No data loaded"
	end

	local tierIndex
	for index, tier in GameConfig.ResourceTiers do
		if tier.name == tierName then
			tierIndex = index
			break
		end
	end

	if not tierIndex then
		return false, "Unknown tier"
	end

	local tier = GameConfig.ResourceTiers[tierIndex]
	if not tier.resetsInto then
		return false, "Tier cannot be reset"
	end

	local requirement = tier.resetRequirement or 0
	local currentAmount = data.resources[tier.name] or 0
	if currentAmount < requirement then
		return false, "Requirement not met"
	end

	data.resources[tier.name] = 0
	data.resources[tier.resetsInto] = (data.resources[tier.resetsInto] or 0) + 1

	return true, nil
end

-- Applies the next Ascension tier's reset + rewards to data, unconditionally.
-- Shared by the normal (requirement-gated) ascend and the Power Store's
-- InstantAscend dev product, which skips the requirement check.
local function applyNextAscension(data)
	local nextTier = GameConfig.AscensionTiers[data.ascensionCount + 1]
	if not nextTier then
		return nil
	end

	for _, tier in GameConfig.ResourceTiers do
		if tier.name ~= "Gems" then
			data.resources[tier.name] = 0
		end
	end

	if nextTier.rewards.statMultiplierAll then
		for statName, value in data.stats do
			data.stats[statName] = value * nextTier.rewards.statMultiplierAll
		end
	end

	data.ascensionCount += 1

	return nextTier
end

function ResetHandler.ascend(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "No data loaded"
	end

	local nextTier = GameConfig.AscensionTiers[data.ascensionCount + 1]
	if not nextTier then
		return false, "No further Ascension tiers"
	end

	local gold = data.resources.Gold or 0
	if gold < nextTier.requirement then
		return false, "Requirement not met"
	end

	local grantedTier = applyNextAscension(data)
	return true, grantedTier
end

-- Bypasses the Gold requirement entirely - used by the Power Store's
-- InstantAscend purchase. Still returns nil (no-op) if already at max tier.
function ResetHandler.forceAscend(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return applyNextAscension(data)
end

return ResetHandler
