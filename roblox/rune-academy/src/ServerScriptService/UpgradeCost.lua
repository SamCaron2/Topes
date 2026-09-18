-- Shared cost curve so every Mana upgrade "lines up" with the others: buying
-- the next level while CURRENTLY at level N costs N * 10 Mana, no matter
-- which upgrade it is - so the very first purchase (from level 1) always
-- costs 10, for every upgrade. Every Mana upgrade handler should cost its
-- levels through this, not its own formula, so they stay in lockstep as
-- more of them get added.

local UpgradeCost = {}

function UpgradeCost.costForLevel(currentLevel: number): number
	return currentLevel * 10
end

return UpgradeCost
