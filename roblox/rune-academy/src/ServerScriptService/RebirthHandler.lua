-- Server-authoritative Rebirths: reset your Mana AND all four Mana-side
-- upgrades (Mana Per Pickup, Mana Spawn Speed, Walking Speed, Collection
-- Range) for a permanent Rebirths currency. 1,000 Mana = 1 Rebirth, and
-- it's fractional - 5,400 Mana gives exactly 5.4 Rebirths, not floored to
-- 5. Rebirth Shop upgrades (RebirthShopHandler) are NOT reset - they're
-- the whole point of rebirthing, so each run collects Mana faster than
-- the last.

local PlayerData = require(script.Parent.PlayerData)
local WalkSpeedHandler = require(script.Parent.WalkSpeedHandler)

local MANA_PER_REBIRTH = 1000
local MIN_MANA_TO_REBIRTH = MANA_PER_REBIRTH -- must have at least one full Rebirth's worth

local RebirthHandler = {}

function RebirthHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local mana = data.mana or 0
	return {
		rebirths = data.rebirths or 0,
		mana = mana,
		manaPerRebirth = MANA_PER_REBIRTH,
		minManaToRebirth = MIN_MANA_TO_REBIRTH,
		rebirthPreview = mana / MANA_PER_REBIRTH,
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

	data.rebirths = (data.rebirths or 0) + mana / MANA_PER_REBIRTH
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
