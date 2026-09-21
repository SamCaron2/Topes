-- Server-authoritative unlock for SecondIsland: reaching the gate no longer
-- auto-unlocks it just by having enough stats - the player has to press an
-- "Unlock" button, which actually SPENDS the Mana/Rebirths requirement
-- (unlike the old threshold-check-only design). Level 25 is checked but
-- never spent - there's nothing to "take away" from a level. Once
-- unlocked, secondIslandUnlocked is permanent; unlock() on an
-- already-unlocked player is a harmless no-op success so a stale client
-- retry can't double-charge them.

local PlayerData = require(script.Parent.PlayerData)

local MANA_REQUIREMENT = 40000000
local REBIRTHS_REQUIREMENT = 40000
local LEVEL_REQUIREMENT = 25

local SecondIslandHandler = {}

function SecondIslandHandler.meetsRequirement(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	return (data.mana or 0) >= MANA_REQUIREMENT
		and (data.rebirths or 0) >= REBIRTHS_REQUIREMENT
		and (data.level or 1) >= LEVEL_REQUIREMENT
end

-- Read by the gate's client UI to show the requirement and enable/disable
-- the Unlock button live as the player's stats change.
function SecondIslandHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	return {
		unlocked = data.secondIslandUnlocked or false,
		meetsRequirement = SecondIslandHandler.meetsRequirement(player),
		manaRequirement = MANA_REQUIREMENT,
		rebirthsRequirement = REBIRTHS_REQUIREMENT,
		levelRequirement = LEVEL_REQUIREMENT,
	}
end

-- Spends exactly the Mana/Rebirths requirement (not a threshold check left
-- untouched - an actual cost) and permanently flips secondIslandUnlocked.
function SecondIslandHandler.unlock(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	if data.secondIslandUnlocked then
		return true, nil, SecondIslandHandler.getState(player)
	end

	if not SecondIslandHandler.meetsRequirement(player) then
		return false, "Requirement not met"
	end

	data.mana -= MANA_REQUIREMENT
	data.rebirths -= REBIRTHS_REQUIREMENT
	data.secondIslandUnlocked = true

	return true, nil, SecondIslandHandler.getState(player)
end

return SecondIslandHandler
