-- Tracks how many of a player's Roblox friends are currently in the SAME
-- server instance. Purely a live/session concept, deliberately never
-- persisted to PlayerData - it should reflect who's online with you right
-- now, not who was there last time you played. Powers the Friend Boost
-- (GameConfig.FriendBoost) on any currency flagged friendBoost = true.
--
-- This is a virality lever as much as a gameplay one: it gives a concrete,
-- immediate reason to invite friends into the SAME server rather than just
-- recommending the game in the abstract.

local Players = game:GetService("Players")

local FriendBoostHandler = {}
local friendCounts = {} -- [player] = count, in-memory only, never saved

-- O(n^2) over the current player list - fine for this genre's server
-- sizes (dozens, not hundreds). Recomputed on every join/leave rather than
-- incrementally, since one join changes every existing player's count.
local function recomputeAll()
	local players = Players:GetPlayers()
	for _, player in players do
		local count = 0
		for _, other in players do
			if other ~= player then
				local success, isFriend = pcall(function()
					return player:IsFriendsWith(other.UserId)
				end)
				if success and isFriend then
					count += 1
				end
			end
		end
		friendCounts[player] = count
	end
end

function FriendBoostHandler.getFriendCount(player: Player): number
	return friendCounts[player] or 0
end

Players.PlayerAdded:Connect(function()
	task.defer(recomputeAll)
end)

Players.PlayerRemoving:Connect(function(player)
	friendCounts[player] = nil
	task.defer(recomputeAll)
end)

return FriendBoostHandler
