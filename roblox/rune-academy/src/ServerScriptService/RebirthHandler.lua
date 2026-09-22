-- Server-authoritative Rebirths: reset your Mana AND all four Mana-side
-- upgrades (Mana Per Pickup, Mana Spawn Speed, Walking Speed, Collection
-- Range) for a permanent Rebirths currency. 1,000 Mana = 1 Rebirth before
-- the Rebirth Shop's "Rebirth Multiplier" (1x-50x) scales that up, and it's
-- fractional either way - not floored. Rebirth Shop upgrades
-- (RebirthShopHandler) are NOT reset - they're the whole point of
-- rebirthing, so each run collects Mana faster than the last.

local PlayerData = require(script.Parent.PlayerData)
local WalkSpeedHandler = require(script.Parent.WalkSpeedHandler)
local RebirthShopHandler = require(script.Parent.RebirthShopHandler)
local WizardTierHandler = require(script.Parent.WizardTierHandler)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

local MANA_PER_REBIRTH = 1000
local MIN_MANA_TO_REBIRTH = MANA_PER_REBIRTH -- must have at least one full Rebirth's worth

local RebirthHandler = {}

function RebirthHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local mana = data.mana or 0
	local multiplier = RebirthShopHandler.getRebirthMultiplier(player)
		* WizardTierHandler.getRebirthMultiplier(player)
		* UpgradeTreeHandler.getRebirthMultiplier(player)
	return {
		rebirths = data.rebirths or 0,
		mana = mana,
		manaPerRebirth = MANA_PER_REBIRTH,
		minManaToRebirth = MIN_MANA_TO_REBIRTH,
		rebirthPreview = (mana / MANA_PER_REBIRTH) * multiplier,
	}
end

function RebirthHandler.rebirth(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local mana = data.mana or 0
	if mana < MIN_MANA_TO_REBIRTH then
		return false, ("Need at least %d Mana to rebirth"):format(MIN_MANA_TO_REBIRTH)
	end

	local multiplier = RebirthShopHandler.getRebirthMultiplier(player)
		* WizardTierHandler.getRebirthMultiplier(player)
		* UpgradeTreeHandler.getRebirthMultiplier(player)
	data.rebirths = (data.rebirths or 0) + (mana / MANA_PER_REBIRTH) * multiplier
	data.mana = 0
	data.manaYieldLevel = 1
	data.manaSpawnSpeedLevel = 1
	data.walkSpeedLevel = 1
	data.collectionRangeLevel = 1

	-- PlayerData changing alone doesn't touch the live Humanoid.
	WalkSpeedHandler.applyCurrentSpeed(player)

	return true, nil, RebirthHandler.getState(player)
end

return RebirthHandler
