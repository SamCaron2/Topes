-- Shared cost curve so every Mana upgrade "lines up" with the others: buying
-- INTO level N costs N * 10 Mana, no matter which upgrade it is. Every Mana
-- upgrade handler should cost its levels through this, not its own formula,
-- so they stay in lockstep as more of them get added.

local UpgradeCost = {}

function UpgradeCost.costForLevel(targetLevel: number): number
	return targetLevel * 10
end

return UpgradeCost
