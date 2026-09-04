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

-- Builds the { [zoneKey] = { currencies = { [currencyKey] = {...} }, floorTiles = {} } }
-- shape entirely from GameConfig.Zones, so a new/renamed zone or currency
-- never needs a matching change here.
local function defaultZoneState()
	local zones = {}
	for _, zone in GameConfig.Zones do
		local currencies = {}
		for _, currency in zone.currencies do
			currencies[currency.key] = {
				amount = 0,
				upgradeLevels = {}, -- [slotId] = level
				selfPrestigeTier = 0, -- count of selfPrestigeTiers purchased so far
				chainBonusMultiplier = 1, -- permanent bonus from being chain-reset INTO repeatedly
			}
		end
		zones[zone.key] = { currencies = currencies, floorTiles = {} } -- floorTiles: [tileKey] = true
	end
	return zones
end

local function defaultData()
	local stats = {}
	for statName, statInfo in GameConfig.Stats do
		stats[statName] = statInfo.base
	end

	return {
		zones = defaultZoneState(),
		gems = 0, -- global premium currency, outside any zone/chain
		stats = stats,
		scrolls = 0,
		runesOpened = 0,
		runesOwned = {}, -- [rankName] = count
		ascensionCount = 0,
		robuxSpent = 0,
		playtimeSeconds = 0,
		ownedPasses = {}, -- [gamePassKey] = true, gates one-time gamepass grants from reapplying
		purchaseHistory = {}, -- bounded list of processed receiptInfo.PurchaseId, guards against double-granting a dev product
		unlockedTitles = {}, -- [titleKey] = true
		equippedTitle = nil,
		firstJoinedAt = nil, -- os.time() the first time this player's data was ever loaded; drives the OG title
	}
end

function PlayerData.get(player: Player)
	return sessions[player]
end

local DATA_LOAD_WAIT_TIMEOUT = 10
local DATA_LOAD_POLL_INTERVAL = 0.5

-- Other server modules that need a player's data right at PlayerAdded (title
-- checks, gamepass re-verification) can't assume PlayerData.load has finished:
-- Roblox spawns each PlayerAdded listener as an independent thread, so a
-- yield in load() (the DataStore call) doesn't block other listeners from
-- starting. Poll briefly instead of racing it.
function PlayerData.waitForLoad(player: Player)
	local elapsed = 0
	while elapsed < DATA_LOAD_WAIT_TIMEOUT do
		local data = sessions[player]
		if data then
			return data
		end
		task.wait(DATA_LOAD_POLL_INTERVAL)
		elapsed += DATA_LOAD_POLL_INTERVAL
	end
	return nil
end

function PlayerData.load(player: Player)
	local success, result = pcall(function()
		return SAVE_STORE:GetAsync("Player_" .. player.UserId)
	end)

	local data = (success and result) or defaultData()
	if not data.firstJoinedAt then
		data.firstJoinedAt = os.time()
	end
	sessions[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("NumberValue")
	gold.Name = "Gold"
	gold.Value = data.zones.Academy.currencies.Gold.amount or 0
	gold.Parent = leaderstats

	local ascensions = Instance.new("IntValue")
	ascensions.Name = "Ascensions"
	ascensions.Value = data.ascensionCount
	ascensions.Parent = leaderstats

	return data
end

-- Returns true only if the save actually reached the DataStore. Callers that
-- just granted something purchase-critical (dev products especially) should
-- check this and avoid marking the purchase processed on failure, so Roblox's
-- automatic ProcessReceipt retry can grant it again later instead of losing it.
function PlayerData.save(player: Player): boolean
	local data = sessions[player]
	if not data then
		return false
	end

	local success, err = pcall(function()
		SAVE_STORE:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn(("RuneAcademy: failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end

	return success
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

-- Drives the playtime-based titles (Newbie/Regular/VIP/No Life). Ticks every
-- session in memory once a second rather than per-player loops.
task.spawn(function()
	while true do
		task.wait(1)
		for _, data in sessions do
			data.playtimeSeconds = (data.playtimeSeconds or 0) + 1
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerData.save(player)
	end
end)

return PlayerData
