-- Walking onto a part tagged "FloorTile" (WorldBuilder.server.lua creates
-- these from GameConfig.Zones' floorTiles) attempts to buy it. Server
-- re-validates cost/ownership - this just triggers the ask, once per
-- contact rather than every physics step while standing on it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEBOUNCE_SECONDS = 1

local player = Players.LocalPlayer
local buyFloorTileFunction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyFloorTile")

local lastTriedAt = {} -- [part] = os.clock()

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	rootPart.Touched:Connect(function(hit)
		if not CollectionService:HasTag(hit, "FloorTile") then
			return
		end

		local now = os.clock()
		if lastTriedAt[hit] and now - lastTriedAt[hit] < DEBOUNCE_SECONDS then
			return
		end
		lastTriedAt[hit] = now

		local zoneKey = hit:GetAttribute("ZoneKey")
		local tileKey = hit:GetAttribute("TileKey")
		if zoneKey and tileKey then
			buyFloorTileFunction:InvokeServer(zoneKey, tileKey)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
