-- Handles Ascension: the full-game prestige reset. Per-currency resets
-- (chain resets, self-prestige) live in ResourceEngine.lua - this module is
-- Ascension only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local ResetHandler = {}

-- Applies the next Ascension tier's reset + rewards to data, unconditionally.
-- Shared by the normal (requirement-gated) ascend and the Power Store's
-- InstantAscend dev product, which skips the requirement check.
local function applyNextAscension(data)
	local nextTier = GameConfig.AscensionTiers[data.ascensionCount + 1]
	if not nextTier then
		return nil
	end

	-- Zeroes every currency's amount + upgrade levels across every zone.
	-- Floor tiles, selfPrestigeTier, and chainBonusMultiplier are left
	-- alone deliberately - those are the "permanent progress" layers, same
	-- rule as Runes/Gems/Ascension count never resetting.
	for _, zone in GameConfig.Zones do
		local zoneState = data.zones[zone.key]
		for _, currency in zone.currencies do
			local state = zoneState.currencies[currency.key]
			state.amount = 0
			for _, slot in currency.upgrades do
				state.upgradeLevels[slot.id] = 0
			end
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

	local currentAmount = data.zones[nextTier.requirementZone].currencies[nextTier.requirementCurrency].amount
	if currentAmount < nextTier.requirement then
		return false, "Requirement not met"
	end

	local grantedTier = applyNextAscension(data)
	return true, grantedTier
end

-- Bypasses the requirement entirely - used by the Power Store's InstantAscend
-- purchase. Still returns nil (no-op) if already at max tier.
function ResetHandler.forceAscend(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return applyNextAscension(data)
end

return ResetHandler
