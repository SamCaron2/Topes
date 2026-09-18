-- Small ring under the player's feet, shown only while standing inside the
-- Mana collection platform. Built from thin Neon segments (no image assets),
-- same no-asset-outline style as the platform's square border. Its radius
-- IS the "Collection Range" upgrade's real pickup radius (kept live via the
-- CollectionRangeUpdated event) - the ring shows exactly how far away a
-- Mana node will still get auto-collected.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local collectionRangeUpdatedEvent = remotes:WaitForChild("CollectionRangeUpdated")

local SEGMENT_COUNT = 20
local SEGMENT_THICKNESS = 0.2

local currentRadius = 3 -- overwritten by the initial CollectionRangeUpdated fire on join

local ringModel = Instance.new("Model")
ringModel.Name = "ManaRing"

local segments = {}
for i = 1, SEGMENT_COUNT do
	local segment = Instance.new("Part")
	segment.Name = "Segment"
	segment.Anchored = true
	segment.CanCollide = false
	segment.CanQuery = false
	segment.Material = Enum.Material.Neon
	segment.Color = Color3.fromRGB(150, 80, 255)
	segment.Size = Vector3.new(1, SEGMENT_THICKNESS, SEGMENT_THICKNESS)
	segment.Parent = ringModel
	segments[i] = segment
end

collectionRangeUpdatedEvent.OnClientEvent:Connect(function(radius)
	currentRadius = radius
end)

local visible = false
local function setVisible(show: boolean)
	if show == visible then
		return
	end
	visible = show
	ringModel.Parent = show and Workspace or nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local zone = Workspace:FindFirstChild("ManaZone")
	if not rootPart or not zone then
		setVisible(false)
		return
	end

	local centerX = zone:GetAttribute("CenterX")
	local centerZ = zone:GetAttribute("CenterZ")
	local size = zone:GetAttribute("Size")
	local groundY = zone:GetAttribute("GroundY")
	if not (centerX and centerZ and size and groundY) then
		setVisible(false)
		return
	end

	local pos = rootPart.Position
	local half = size / 2
	local inZone = math.abs(pos.X - centerX) <= half and math.abs(pos.Z - centerZ) <= half

	setVisible(inZone)
	if not inZone then
		return
	end

	local segmentLength = (2 * math.pi * currentRadius) / SEGMENT_COUNT * 0.6
	for i, segment in segments do
		local angle = (i - 1) / SEGMENT_COUNT * math.pi * 2
		segment.Size = Vector3.new(segmentLength, SEGMENT_THICKNESS, SEGMENT_THICKNESS)
		segment.CFrame = CFrame.new(pos.X, groundY + 0.15, pos.Z)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(currentRadius, 0, 0)
			* CFrame.Angles(0, math.pi / 2, 0)
	end
end)
