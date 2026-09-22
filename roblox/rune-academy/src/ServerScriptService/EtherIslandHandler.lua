-- Server-authoritative unlock for EtherIsland - same pattern as
-- SecondIslandHandler (an explicit Unlock button that actually SPENDS the
-- requirement, not a passive threshold check), just gated on Ether alone
-- instead of Mana/Rebirths/Level, per direct request ("locked until you
-- have what you think is good to progress in terms of ether").
--
-- The requirement is derived the same way as every other milestone cost
-- in this game: fully maxing the whole 3-column Ether board (More Ether
-- to 100, Click Speed to 10, More Dust to 50) costs ~619,465 Ether total
-- - the same total as maxing the Arcane Dust board, since both boards'
-- column curves are identical. 1,000,000,000 Ether prices past that (a
-- genuine next milestone, not something maxing the board alone affords)
-- while also mirroring Tier 1's 1B Mana price and Upgrade Tree Tile 1's
-- 1B Dust price, keeping every resource's first big gate at the same
-- recognizable "1B" scale.
local PlayerData = require(script.Parent.PlayerData)

local ETHER_REQUIREMENT = 1e9

local EtherIslandHandler = {}

function EtherIslandHandler.meetsRequirement(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	return (data.ether or 0) >= ETHER_REQUIREMENT
end

-- Read by the gate's client UI to show the requirement and enable/disable
-- the Unlock button live as the player's Ether changes.
function EtherIslandHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		unlocked = data.etherIslandUnlocked or false,
		meetsRequirement = EtherIslandHandler.meetsRequirement(player),
		etherRequirement = ETHER_REQUIREMENT,
	}
end

-- Spends exactly the Ether requirement (not a threshold check left
-- untouched - an actual cost) and permanently flips etherIslandUnlocked.
function EtherIslandHandler.unlock(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	if data.etherIslandUnlocked then
		return true, nil, EtherIslandHandler.getState(player)
	end

	-- Its own gate is physically on SecondIsland, past the Ether Shroud -
	-- checking secondIslandUnlocked too, not just relying on players
	-- physically needing to be there, so this stays correct even if a
	-- containment bug ever lets someone reach the gate early.
	if not data.secondIslandUnlocked then
		return false, "SecondIsland not unlocked"
	end

	if not EtherIslandHandler.meetsRequirement(player) then
		return false, "Requirement not met"
	end

	data.ether -= ETHER_REQUIREMENT
	data.etherIslandUnlocked = true

	return true, nil, EtherIslandHandler.getState(player)
end

return EtherIslandHandler
