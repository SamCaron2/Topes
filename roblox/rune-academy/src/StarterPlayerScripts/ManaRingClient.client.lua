-- Small ring under the player's feet, shown while standing inside either
-- collection zone - the Mana platform or the Arcane Dust zone, since
-- "Collection Range" is a single shared stat that applies to both. Built
-- from thin Neon segments (no image assets), same no-asset-outline style as
-- the platforms' square borders. Its radius IS the "Collection Range"
-- upgrade's real pickup radius (kept live via the CollectionRangeUpdated
-- event) - the ring shows exactly how far away a node will still get
-- auto-collected, in either zone.

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

-- Returns the ground Y of whichever collection zone (by folder name) the
-- given position is currently inside, or nil if it's in neither.
local function findZoneGroundY(pos: Vector3): number?
	for _, zoneName in { "ManaZone", "ArcaneDustZone" } do
		local zone = Workspace:FindFirstChild(zoneName)
		if zone then
			local centerX = zone:GetAttribute("CenterX")
			local centerZ = zone:GetAttribute("CenterZ")
			local size = zone:GetAttribute("Size")
			local groundY = zone:GetAttribute("GroundY")
			if centerX and centerZ and size and groundY then
				local half = size / 2
				if math.abs(pos.X - centerX) <= half and math.abs(pos.Z - centerZ) <= half then
					return groundY
				end
			end
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		setVisible(false)
		return
	end

	local pos = rootPart.Position
	local groundY = findZoneGroundY(pos)
	local inZone = groundY ~= nil

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
