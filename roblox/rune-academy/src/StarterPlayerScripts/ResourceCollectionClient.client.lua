-- Fires CollectNode for any part tagged "ResourceNode" (CollectionService,
-- set in Studio) with ZoneKey/CurrencyKey attributes set to match a
-- currency in GameConfig.Zones. Works for both "click" and "stand"
-- collectModes the same way: fire repeatedly while touching, server
-- decides what that's actually worth (and rejects anything from a
-- chainOnly currency or too far away) - see ResourceEngine.collect.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COLLECT_FIRE_INTERVAL = 0.25

local player = Players.LocalPlayer
local collectNodeEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CollectNode")

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")
	local touchingNodes = {} -- [part] = true
	local loopRunning = false

	local function collectLoop()
		if loopRunning then
			return -- already running; new touches just get added to touchingNodes above
		end
		loopRunning = true

		while next(touchingNodes) ~= nil do
			for part in touchingNodes do
				local zoneKey = part:GetAttribute("ZoneKey")
				local currencyKey = part:GetAttribute("CurrencyKey")
				if zoneKey and currencyKey then
					collectNodeEvent:FireServer(zoneKey, currencyKey, part)
				end
			end
			task.wait(COLLECT_FIRE_INTERVAL)
		end

		loopRunning = false
	end

	rootPart.Touched:Connect(function(hit)
		if not CollectionService:HasTag(hit, "ResourceNode") or touchingNodes[hit] then
			return
		end
		touchingNodes[hit] = true
		task.spawn(collectLoop)
	end)

	rootPart.TouchEnded:Connect(function(hit)
		touchingNodes[hit] = nil
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
