-- Server-authoritative global leaderboards: Playtime, Robux Spent, Total
-- Mana, and Runes Opened, backed by one OrderedDataStore per stat so
-- rankings persist across server restarts and cover every player who's
-- ever played, not just who's online right now. Same "DataStores might be
-- unavailable in Studio" defensive pcall pattern as PlayerData.lua - a
-- missing store just means getTop returns an empty list instead of
-- crashing every script that requires this module.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

-- `dataField` is read straight off PlayerData's save table; `key` is what
-- the client/remote refers to the stat by.
local STATS = {
	{ key = "playtime", dataField = "playtimeSeconds", storeName = "RuneAcademy_Leaderboard_Playtime_v1" },
	{ key = "robux", dataField = "robuxSpent", storeName = "RuneAcademy_Leaderboard_Robux_v1" },
	{ key = "mana", dataField = "totalManaEarned", storeName = "RuneAcademy_Leaderboard_Mana_v1" },
	{ key = "runes", dataField = "runesOpened", storeName = "RuneAcademy_Leaderboard_Runes_v1" },
}

local stores = {} -- [statKey] = OrderedDataStore, or nil if DataStores are unavailable
for _, stat in STATS do
	local success, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(stat.storeName)
	end)
	stores[stat.key] = success and result or nil
end

local SYNC_INTERVAL = 60

local LeaderboardHandler = {}

-- Pushes one online player's current stats into every OrderedDataStore.
-- Called periodically for everyone, and once more when a player leaves so
-- their final playtime/etc. isn't lost to the sync interval's timing.
local function syncPlayer(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	for _, stat in STATS do
		local store = stores[stat.key]
		if store then
			local value = math.floor(data[stat.dataField] or 0)
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

-- Up to `limit` { name, value } entries for one stat, highest first. Names
-- are resolved live via Players:GetNameFromUserIdAsync (a network call per
-- entry), so this is meant to be called occasionally (board refreshes),
-- never every frame. Returns {} if that stat's store is unavailable or the
-- lookup fails, rather than erroring the caller.
function LeaderboardHandler.getTop(statKey: string, limit: number)
	local store = stores[statKey]
	if not store then
		return {}
	end

	local success, pages = pcall(function()
		return store:GetSortedAsync(false, limit)
	end)
	if not success then
		return {}
	end

	local entries = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		local name = entry.key
		if userId then
			local nameSuccess, resolvedName = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nameSuccess then
				name = resolvedName
			end
		end
		table.insert(entries, { name = name, value = entry.value })
	end
	return entries
end

task.spawn(function()
	while true do
		task.wait(SYNC_INTERVAL)
		for _, player in Players:GetPlayers() do
			syncPlayer(player)
		end
	end
end)

-- Not Players.PlayerRemoving directly - PlayerData.release() (which clears
-- the session this reads from) could easily run first, since Roblox
-- doesn't guarantee listener order across separate scripts. This hook fires
-- while the data is still there.
PlayerData.onBeforeRelease(syncPlayer)

return LeaderboardHandler
