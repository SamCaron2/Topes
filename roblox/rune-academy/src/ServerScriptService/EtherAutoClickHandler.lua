-- Server-authoritative one-time "Auto Click" upgrade for the Ether
-- Shroud, per direct request ("add a 1 time upgrade that gives you auto
-- click on the ether"). Unlike every other Ether board column, this is a
-- SINGLE purchase, not a leveled one (no `getYieldUpgradeState`-style
-- level/max/nextLevelCost shape) - once bought, WorldBuilder's background
-- auto-click loop collects Ether for this player automatically at exactly
-- the same rate a manual click already would (EtherClickSpeedHandler's
-- own cooldown), so buying this just means never having to click the
-- Shroud again.

local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

-- One-time cost, my own call - roughly the same order of magnitude as
-- maxing one of the other Ether columns, since this is a permanent
-- convenience upgrade rather than a repeatable one.
local COST = 5000

local EtherAutoClickHandler = {}

-- Read by WorldBuilder's background loop every tick for every online
-- player - cheap PlayerData lookup, no remote round-trip.
function EtherAutoClickHandler.isUnlocked(player: Player): boolean
	local data = PlayerData.get(player)
	return data ~= nil and data.etherAutoClickUnlocked == true
end

function EtherAutoClickHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		unlocked = data.etherAutoClickUnlocked == true,
		cost = COST,
		ether = data.ether or 0,
	}
end

-- Checks isEtherUnlocked directly here too, not just relying on the board
-- being physically unreachable pre-unlock, same defense-in-depth
-- reasoning as every other Ether/SecondIsland handler.
function EtherAutoClickHandler.buyUpgrade(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end
	if not UpgradeTreeHandler.isEtherUnlocked(player) then
		return false, "Ether not unlocked"
	end
	if data.etherAutoClickUnlocked then
		return false, "Already owned"
	end
	if (data.ether or 0) < COST then
		return false, "Not enough Ether"
	end

	data.ether -= COST
	data.etherAutoClickUnlocked = true

	return true, nil, EtherAutoClickHandler.getState(player)
end

return EtherAutoClickHandler
