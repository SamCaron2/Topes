-- Owns each player's save data: load on join, autosave on interval, save on leave.
-- Keep this the single source of truth other server scripts read/write through -
-- never let two scripts touch DataStore for the same player independently.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local GameConfig = require(game.ReplicatedStorage.Modules.GameConfig)

local SAVE_STORE = DataStoreService:GetDataStore("RuneAcademy_PlayerData_v1")
local AUTOSAVE_INTERVAL = 120

local PlayerData = {}
local sessions = {} -- [player] = dataTable

local function defaultData()
	local resources = {}
	for _, tier in GameConfig.ResourceTiers do
		resources[tier.name] = 0
	end

	local stats = {}
	for statName, statInfo in GameConfig.Stats do
		stats[statName] = statInfo.base
	end

	return {
		resources = resources,
		stats = stats,
		scrolls = 0,
		runesOpened = 0,
		runesOwned = {}, -- [rankName] = count
		ascensionCount = 0,
		robuxSpent = 0,
		playtimeSeconds = 0,
	}
end

function PlayerData.get(player: Player)
	return sessions[player]
end

function PlayerData.load(player: Player)
	local success, result = pcall(function()
		return SAVE_STORE:GetAsync("Player_" .. player.UserId)
	end)

	local data = (success and result) or defaultData()
	sessions[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("NumberValue")
	gold.Name = "Gold"
	gold.Value = data.resources.Gold or 0
	gold.Parent = leaderstats

	local ascensions = Instance.new("IntValue")
	ascensions.Name = "Ascensions"
	ascensions.Value = data.ascensionCount
	ascensions.Parent = leaderstats

	return data
end

function PlayerData.save(player: Player)
	local data = sessions[player]
	if not data then
		return
	end

	local success, err = pcall(function()
		SAVE_STORE:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn(("RuneAcademy: failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	sessions[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	PlayerData.load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			PlayerData.save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)

return PlayerData
