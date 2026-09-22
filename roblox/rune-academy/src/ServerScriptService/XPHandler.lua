-- Server-authoritative XP/Level system: every Mana pickup grants a flat
-- amount of XP (10, scaled by the Rebirth Shop's "XP Multiplier"), and
-- enough XP levels you up. 50 levels total. The cost curve is deliberately
-- non-linear - a power curve, not a flat multiply-by-N each level - so the
-- gap between levels keeps changing instead of growing by the same amount
-- every time. Level 1 costs exactly 100 XP as specified. A separate
-- progression track from the 4 Mana-side upgrades RebirthHandler resets -
-- rebirthing does NOT touch level/xp.

local PlayerData = require(script.Parent.PlayerData)
local RebirthShopHandler = require(script.Parent.RebirthShopHandler)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)

local MAX_LEVEL = 50
local BASE_XP_PER_PICKUP = 10

local function costForLevel(currentLevel: number): number
	return math.floor(100 * currentLevel ^ 1.4)
end

local XPHandler = {}

function XPHandler.getState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.level or 1
	local maxed = level >= MAX_LEVEL
	return {
		level = level,
		maxLevel = MAX_LEVEL,
		xp = data.xp or 0,
		xpToNextLevel = not maxed and costForLevel(level) or nil,
	}
end

-- Called once per successful Mana pickup (see WorldBuilder's collection
-- loop). Always returns the resulting state so the caller can push it to
-- the client, even if the player was already at max level.
function XPHandler.grantXpForPickup(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.level or 1
	if level < MAX_LEVEL then
		data.xp = (data.xp or 0)
			+ BASE_XP_PER_PICKUP * RebirthShopHandler.getXpMultiplier(player) * UpgradeTreeHandler.getXpMultiplier(player)

		while level < MAX_LEVEL and data.xp >= costForLevel(level) do
			data.xp -= costForLevel(level)
			level += 1
		end

		data.level = level
	end

	return XPHandler.getState(player)
end

return XPHandler
