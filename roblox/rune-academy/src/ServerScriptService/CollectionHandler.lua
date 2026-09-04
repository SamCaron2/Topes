-- Server-authoritative Mana collection. Client fires a RemoteEvent per node
-- touched; server validates distance + debounce before granting anything.
-- Never trust a client-reported amount for currency.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local CollectionHandler = {}

local MAX_COLLECT_DISTANCE = 12
local COLLECT_DEBOUNCE_SECONDS = 0.2
local lastCollectAt = {} -- [player] = os.clock()

function CollectionHandler.collectNode(player: Player, node: Instance)
	local data = PlayerData.get(player)
	if not data or not node or not node:IsA("BasePart") then
		return false
	end

	local now = os.clock()
	if lastCollectAt[player] and now - lastCollectAt[player] < COLLECT_DEBOUNCE_SECONDS then
		return false
	end
	lastCollectAt[player] = now

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return false
	end

	if (rootPart.Position - node.Position).Magnitude > MAX_COLLECT_DISTANCE then
		return false
	end

	local power = data.stats.Power or 1
	local focus = data.stats.Focus or 1
	local gained = GameConfig.ResourceTiers[1].baseRate * power * focus

	data.resources.Mana = (data.resources.Mana or 0) + gained

	return true, gained
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastCollectAt[player] = nil
end)

return CollectionHandler
