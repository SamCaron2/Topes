-- Unlocks and equips Titles (GameConfig.Titles). Unlock state persists in
-- PlayerData; the currently equipped title is mirrored onto Player
-- attributes (Title/TitleColor/TitleRainbow) which replicate automatically
-- to every client, so TitleDisplayClient.client.lua just reads attributes -
-- no remote round-trip needed to draw the overhead label.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local TitleHandler = {}

local RECHECK_INTERVAL = 30

local function findTitle(key: string)
	for _, title in GameConfig.Titles do
		if title.key == key then
			return title
		end
	end
	return nil
end

local function meetsCondition(player: Player, data, title): boolean
	local condition = title.condition

	if condition.type == "playtimeSeconds" then
		return (data.playtimeSeconds or 0) >= condition.value
	elseif condition.type == "robuxSpent" then
		return (data.robuxSpent or 0) >= condition.value
	elseif condition.type == "gamePassOwned" then
		return data.ownedPasses[condition.passKey] == true
	elseif condition.type == "groupMember" then
		if not GameConfig.FanGroupId or GameConfig.FanGroupId == 0 then
			return false
		end
		local success, isMember = pcall(function()
			return player:IsInGroup(GameConfig.FanGroupId)
		end)
		return success and isMember
	elseif condition.type == "joinWindow" then
		if not GameConfig.ReleaseTimestampUnix or not data.firstJoinedAt then
			return false
		end
		return data.firstJoinedAt <= GameConfig.ReleaseTimestampUnix + GameConfig.OGWindowSeconds
	elseif condition.type == "manual" then
		return false -- only ever granted explicitly, see grantManualTitle
	end

	return false
end

-- Checks every non-manual title's condition and unlocks any newly-earned
-- ones. Cheap to call often - call it after anything that could satisfy a
-- condition (a purchase, a periodic tick) rather than only on join.
function TitleHandler.checkUnlocks(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	data.unlockedTitles = data.unlockedTitles or {}

	for _, title in GameConfig.Titles do
		if not data.unlockedTitles[title.key] and meetsCondition(player, data, title) then
			data.unlockedTitles[title.key] = true
		end
	end
end

-- For titles that can't be earned through gameplay (Tester/Admin/Owner).
-- Called from the UserId-allowlist check below now; a future admin command
-- system should call this too rather than editing unlockedTitles directly.
function TitleHandler.grantManualTitle(player: Player, key: string)
	local data = PlayerData.get(player)
	if not data or not findTitle(key) then
		return
	end

	data.unlockedTitles = data.unlockedTitles or {}
	data.unlockedTitles[key] = true
end

local function applyAttributesFor(player: Player, title)
	player:SetAttribute("Title", title and title.displayName or nil)
	player:SetAttribute("TitleColor", title and title.color or nil)
	player:SetAttribute("TitleRainbow", title and title.rainbow == true or nil)
end

-- key == nil/"" unequips. Returns true/false, errorMessage.
function TitleHandler.equipTitle(player: Player, key: string?)
	local data = PlayerData.get(player)
	if not data then
		return false, "No data loaded"
	end

	if key == nil or key == "" then
		data.equippedTitle = nil
		applyAttributesFor(player, nil)
		return true
	end

	data.unlockedTitles = data.unlockedTitles or {}
	if not data.unlockedTitles[key] then
		return false, "Title not unlocked"
	end

	local title = findTitle(key)
	if not title then
		return false, "Unknown title"
	end

	data.equippedTitle = key
	applyAttributesFor(player, title)
	return true
end

-- Re-applies the saved equipped title's attributes - needed on join since
-- attributes start empty for a freshly-loaded Player instance.
function TitleHandler.applyEquippedAttributes(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.equippedTitle then
		return
	end
	applyAttributesFor(player, findTitle(data.equippedTitle))
end

local function checkAllowlists(player: Player)
	for _, userId in GameConfig.OwnerUserIds do
		if player.UserId == userId then
			TitleHandler.grantManualTitle(player, "Owner")
		end
	end
	for _, userId in GameConfig.AdminUserIds do
		if player.UserId == userId then
			TitleHandler.grantManualTitle(player, "Admin")
		end
	end
	for _, userId in GameConfig.TesterUserIds do
		if player.UserId == userId then
			TitleHandler.grantManualTitle(player, "Tester")
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local data = PlayerData.waitForLoad(player)
		if not data then
			warn(("TitleHandler: gave up waiting for %s's data"):format(player.Name))
			return
		end

		checkAllowlists(player)
		TitleHandler.checkUnlocks(player)
		TitleHandler.applyEquippedAttributes(player)
	end)
end)

task.spawn(function()
	while true do
		task.wait(RECHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			TitleHandler.checkUnlocks(player)
		end
	end
end)

return TitleHandler
