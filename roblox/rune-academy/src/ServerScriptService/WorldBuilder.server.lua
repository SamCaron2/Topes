-- Generates world content on server start. Rebuilding from scratch after the
-- full reset - starts with just the Mana collection platform, grows one piece
-- at a time as the new vision gets specified.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ManaHandler = require(script.Parent.ManaHandler)
local ManaSpawnHandler = require(script.Parent.ManaSpawnHandler)

local MANA_ZONE_SIZE = 60 -- studs, square
local BORDER_THICKNESS = 1
local BORDER_HEIGHT = 0.2
local MANA_NODE_SIZE = Vector3.new(2, 2, 2)
local MANA_NODE_MARGIN = 3 -- keep nodes off the border line

local manaUpdatedEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ManaUpdated")

local function findGroundAnchor()
	local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
	if spawn then
		return spawn.Position.X, spawn.Position.Z, spawn.Position.Y + spawn.Size.Y / 2
	end
	return 0, 0, 0
end

local centerX, centerZ, groundY = findGroundAnchor()

local existing = Workspace:FindFirstChild("ManaZone")
if existing then
	existing:Destroy()
end

local manaZone = Instance.new("Folder")
manaZone.Name = "ManaZone"
-- Read by ManaRingClient so the feet-ring can tell whether a player is
-- standing inside the platform without duplicating these numbers client-side.
manaZone:SetAttribute("CenterX", centerX)
manaZone:SetAttribute("CenterZ", centerZ)
manaZone:SetAttribute("Size", MANA_ZONE_SIZE)
manaZone:SetAttribute("GroundY", groundY)
manaZone.Parent = Workspace

-- A hollow square outline (4 thin parts) rather than a filled platform, sitting
-- flush on the ground. Non-collide so it never trips up walking/running.
local function makeBorderPart(name, sizeX, sizeZ, offsetX, offsetZ)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(80, 180, 255)
	part.Size = Vector3.new(sizeX, BORDER_HEIGHT, sizeZ)
	part.CFrame = CFrame.new(centerX + offsetX, groundY + BORDER_HEIGHT / 2, centerZ + offsetZ)
	part.Parent = manaZone
	return part
end

local half = MANA_ZONE_SIZE / 2
makeBorderPart("BorderNorth", MANA_ZONE_SIZE, BORDER_THICKNESS, 0, -half + BORDER_THICKNESS / 2)
makeBorderPart("BorderSouth", MANA_ZONE_SIZE, BORDER_THICKNESS, 0, half - BORDER_THICKNESS / 2)
makeBorderPart("BorderEast", BORDER_THICKNESS, MANA_ZONE_SIZE, half - BORDER_THICKNESS / 2, 0)
makeBorderPart("BorderWest", BORDER_THICKNESS, MANA_ZONE_SIZE, -half + BORDER_THICKNESS / 2, 0)

-- Several Mana cubes spawned at once: touch one for Mana, a replacement
-- spawns elsewhere after a delay set by the COLLECTING player's own "Mana
-- Spawn Speed" level (see ManaSpawnHandler). That same upgrade also raises
-- how many nodes exist in the world at once (3 at level 1, up to 10 at level
-- 10) - TOP_UP_INTERVAL polls for that rising instead of only reacting to
-- pickups, so a purchase (or another player joining with a higher level)
-- adds nodes without needing one to be collected first.
local TOP_UP_INTERVAL = 2

local function randomPointInZone()
	local innerHalf = MANA_ZONE_SIZE / 2 - MANA_NODE_MARGIN
	local offsetX = (math.random() * 2 - 1) * innerHalf
	local offsetZ = (math.random() * 2 - 1) * innerHalf
	return centerX + offsetX, centerZ + offsetZ
end

local function spawnManaNode()
	local x, z = randomPointInZone()

	local node = Instance.new("Part")
	node.Name = "ManaNode"
	node.Anchored = true
	node.CanCollide = false
	node.Material = Enum.Material.Neon
	node.Color = Color3.fromRGB(150, 80, 255)
	node.Size = MANA_NODE_SIZE
	node.CFrame = CFrame.new(x, groundY + MANA_NODE_SIZE.Y / 2, z)
	node.Parent = manaZone

	local claimed = false
	node.Touched:Connect(function(hit)
		if claimed then
			return
		end
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		claimed = true

		local newAmount = ManaHandler.collect(player)
		if newAmount then
			manaUpdatedEvent:FireClient(player, newAmount)
		end

		node:Destroy()
		task.delay(ManaSpawnHandler.getRespawnSeconds(player), spawnManaNode)
	end)
end

-- The max across everyone online, so any player's Spawn Speed progress
-- raises the shared node count for the whole platform, not just for them.
local function getTargetNodeCount(): number
	local target = ManaSpawnHandler.getBaseNodeCount()
	for _, player in Players:GetPlayers() do
		target = math.max(target, ManaSpawnHandler.getNodeCount(player))
	end
	return target
end

local function countLiveNodes(): number
	local count = 0
	for _, child in manaZone:GetChildren() do
		if child.Name == "ManaNode" then
			count += 1
		end
	end
	return count
end

local function topUpNodes()
	local missing = getTargetNodeCount() - countLiveNodes()
	for _ = 1, missing do
		spawnManaNode()
	end
end

topUpNodes()

task.spawn(function()
	while true do
		task.wait(TOP_UP_INTERVAL)
		topUpNodes()
	end
end)

-- Upgrade cards live outside the platform, a few studs past the border.
-- ManaUpgradeBoardClient finds this part by name and builds its SurfaceGui UI.
local kiosksFolder = Workspace:FindFirstChild("Kiosks")
if kiosksFolder then
	kiosksFolder:Destroy()
end
kiosksFolder = Instance.new("Folder")
kiosksFolder.Name = "Kiosks"
kiosksFolder.Parent = Workspace

-- Wide and mostly empty on purpose: two upgrade columns fill the left side
-- so far, leaving room to add more left-to-right later without resizing the
-- board. Thin along X (the approach direction), wide along Z, so its wide
-- face - not its thin edge - points back at the platform, toward the player.
local function makeKioskCard(name: string, offsetX: number, offsetZ: number)
	local card = Instance.new("Part")
	card.Name = name
	card.Anchored = true
	card.CanCollide = true
	card.Material = Enum.Material.SmoothPlastic
	card.Color = Color3.fromRGB(45, 45, 60)
	card.Size = Vector3.new(1, 18, 42)
	card.CFrame = CFrame.new(centerX + offsetX, groundY + 9, centerZ + offsetZ)
	card.Parent = kiosksFolder
	return card
end

makeKioskCard("ManaUpgradeBoard", half + 6, 0)
