-- Server-authoritative "Walking Speed" upgrade: 10 levels, linear from 1x
-- (level 1, Roblox's default WalkSpeed of 16) up to 1.5x (level 10, 24) -
-- halved from the original 3x max, which felt too strong.
--
-- Costed steeply ON PURPOSE, not through the shared UpgradeCost curve: only
-- 10 levels total, but each should feel like real progress rather than a
-- quick fill-in upgrade, so it shouldn't be finishable as fast as Mana
-- Spawn Speed's 10 levels are. The first purchase costs 190 Mana (10x
-- UpgradeCost's flat curve at level 19 - a fixed reference point, no longer
-- tied to "More Mana" itself now that its cost curve is convex instead of
-- flat), and it climbs by that same amount every level after.

local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local UpgradeCost = require(script.Parent.UpgradeCost)

local MAX_SPEED_LEVEL = 10
local BASE_WALK_SPEED = 16
local MAX_MULTIPLIER = 1.5
local COST_PER_LEVEL = UpgradeCost.costForLevel(19) -- = 190 Mana right now

-- TEMP: testing only - per direct request ("make my sprint speed times 4
-- just so I can move around the map faster when I quality check each
-- time"), multiplies the real, level-based WalkSpeed on top of everything
-- above. Doesn't touch walkSpeedLevel/costForLevel/the upgrade board's own
-- displayed 1x-1.5x range at all - purely a QA convenience layered on at
-- the very end. Remove this multiplier once you're done testing.
local TEMP_QA_SPEED_MULTIPLIER = 4

local function multiplierForLevel(level: number): number
	local t = (level - 1) / (MAX_SPEED_LEVEL - 1)
	return 1 + (MAX_MULTIPLIER - 1) * t
end

local function walkSpeedForLevel(level: number): number
	return BASE_WALK_SPEED * multiplierForLevel(level)
end

local function costForLevel(currentLevel: number): number
	return currentLevel * COST_PER_LEVEL
end

local WalkSpeedHandler = {}

local function applyWalkSpeed(player: Player)
	local data = PlayerData.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (data and humanoid) then
		return
	end
	humanoid.WalkSpeed = walkSpeedForLevel(data.walkSpeedLevel or 1) * TEMP_QA_SPEED_MULTIPLIER
end

-- Exposed so RebirthHandler can re-apply Humanoid.WalkSpeed right after
-- resetting walkSpeedLevel back to 1 on rebirth - PlayerData changing alone
-- doesn't touch the live Humanoid.
function WalkSpeedHandler.applyCurrentSpeed(player: Player)
	applyWalkSpeed(player)
end

function WalkSpeedHandler.getUpgradeState(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local level = data.walkSpeedLevel or 1
	local maxed = level >= MAX_SPEED_LEVEL
	return {
		level = level,
		maxLevel = MAX_SPEED_LEVEL,
		multiplier = multiplierForLevel(level),
		nextMultiplier = not maxed and multiplierForLevel(level + 1) or nil,
		nextLevelCost = not maxed and costForLevel(level) or nil,
		mana = data.mana or 0,
	}
end

function WalkSpeedHandler.buyUpgrade(player: Player, mode: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "Not loaded"
	end

	local level = data.walkSpeedLevel or 1
	if level >= MAX_SPEED_LEVEL then
		return false, "Already at max level"
	end

	local cost = costForLevel(level)
	if (data.mana or 0) < cost then
		return false, "Not enough Mana"
	end

	data.mana -= cost
	level += 1

	if mode == "max" then
		while level < MAX_SPEED_LEVEL and data.mana >= costForLevel(level) do
			data.mana -= costForLevel(level)
			level += 1
		end
	end

	data.walkSpeedLevel = level
	applyWalkSpeed(player)

	return true, nil, WalkSpeedHandler.getUpgradeState(player)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.spawn(function()
			if PlayerData.waitForLoad(player) then
				applyWalkSpeed(player)
			end
		end)
	end)
end)

return WalkSpeedHandler
