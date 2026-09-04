-- Fires CollectNode whenever the player's character touches a part tagged
-- "ManaNode" (use CollectionService tags in Studio, not naming conventions).
-- The server re-validates distance/debounce - this script just triggers the ask.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local collectNodeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CollectNode")

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	rootPart.Touched:Connect(function(hit)
		if CollectionService:HasTag(hit, "ManaNode") then
			collectNodeEvent:FireServer(hit)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
