-- Generates world content on server start. Rebuilding from scratch after the
-- full reset - starts with just the Mana collection platform, grows one piece
-- at a time as the new vision gets specified.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ManaHandler = require(script.Parent.ManaHandler)
local ManaSpawnHandler = require(script.Parent.ManaSpawnHandler)
local CollectionRangeHandler = require(script.Parent.CollectionRangeHandler)
local XPHandler = require(script.Parent.XPHandler)
local PlayerData = require(script.Parent.PlayerData)

local MANA_ZONE_SIZE = 60 -- studs, square
local BORDER_THICKNESS = 1
local BORDER_HEIGHT = 0.2
local MANA_NODE_SIZE = Vector3.new(2, 2, 2)
local MANA_NODE_MARGIN = 3 -- keep nodes off the border line

local ISLAND_SIZE = 120 -- studs, square - comfortably fits the platform + kiosk board with room to spare
local ISLAND_THICKNESS = 6
local ISLAND_TOP_Y = 60 -- how high above the void the starting island floats
local FALL_KILL_MARGIN = 30 -- studs below the island surface before a fallen player is destroyed and respawned

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotesFolder:WaitForChild("ManaUpdated")
local xpUpdatedEvent = remotesFolder:WaitForChild("XPUpdated")

-- Everything below is positioned relative to SpawnLocation, so building the
-- island here and lifting spawn onto its surface lifts the whole build with
-- it - nothing past this block needs to change for "up in the air."
local spawnPart = Workspace:FindFirstChildOfClass("SpawnLocation")
local islandCenterX = spawnPart and spawnPart.Position.X or 0
local islandCenterZ = spawnPart and spawnPart.Position.Z or 0

local existingIsland = Workspace:FindFirstChild("StartingIsland")
if existingIsland then
	existingIsland:Destroy()
end

local island = Instance.new("Part")
island.Name = "StartingIsland"
island.Anchored = true
island.CanCollide = true
island.Material = Enum.Material.Grass
island.Color = Color3.fromRGB(90, 170, 60)
island.Size = Vector3.new(ISLAND_SIZE, ISLAND_THICKNESS, ISLAND_SIZE)
island.CFrame = CFrame.new(islandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, islandCenterZ)
island.Parent = Workspace

if spawnPart then
	spawnPart.Position = Vector3.new(islandCenterX, ISLAND_TOP_Y + spawnPart.Size.Y / 2, islandCenterZ)
end

-- The first of those future areas - SecondIsland - is built near the bottom
-- of this file: another floating island bridged from this one, gated behind
-- a Mana + Rebirths + Level requirement.

-- Run off the edge and you fall into the void; once you're this far below
-- the island's surface, killing the Humanoid triggers Roblox's normal
-- death-and-respawn-at-SpawnLocation behavior. This is a manual poll rather
-- than the simpler Workspace.FallenPartsDestroyHeight because writing that
-- property from a normal server Script is blocked ("lacking capability
-- Plugin") - it's restricted to Studio/plugin contexts only.
local FALL_KILL_Y = ISLAND_TOP_Y - FALL_KILL_MARGIN
local FALL_CHECK_INTERVAL = 0.5

task.spawn(function()
	while true do
		task.wait(FALL_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if rootPart and humanoid and humanoid.Health > 0 and rootPart.Position.Y < FALL_KILL_Y then
				humanoid.Health = 0
			end
		end
	end
end)

local function findGroundAnchor()
	if spawnPart then
		return spawnPart.Position.X, spawnPart.Position.Z, spawnPart.Position.Y + spawnPart.Size.Y / 2
	end
	return islandCenterX, islandCenterZ, ISLAND_TOP_Y
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

-- Several Mana cubes spawned at once: get within range of one (see the
-- collection loop below) for Mana, and a replacement spawns elsewhere after
-- a delay set by the COLLECTING player's own "Mana Spawn Speed" level (see
-- ManaSpawnHandler). That same upgrade also raises how many nodes exist in
-- the world at once (3 at level 1, up to 10 at level 10) - TOP_UP_INTERVAL
-- polls for that rising instead of only reacting to pickups, so a purchase
-- (or another player joining with a higher level) adds nodes without
-- needing one to be collected first.
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
end

local function collectNode(node: BasePart, player: Player)
	node:Destroy()
	local newAmount = ManaHandler.collect(player)
	if newAmount then
		manaUpdatedEvent:FireClient(player, newAmount)
	end

	local xpState = XPHandler.grantXpForPickup(player)
	if xpState then
		xpUpdatedEvent:FireClient(player, xpState)
	end

	task.delay(ManaSpawnHandler.getRespawnSeconds(player), spawnManaNode)
end

-- Collection is range-based, not touch-based: every COLLECT_CHECK_INTERVAL,
-- any live node within a player's current "Collection Range" upgrade radius
-- (CollectionRangeHandler) gets collected automatically, matching the ring
-- ManaRingClient draws around their feet.
local COLLECT_CHECK_INTERVAL = 0.15

task.spawn(function()
	while true do
		task.wait(COLLECT_CHECK_INTERVAL)
		for _, node in manaZone:GetChildren() do
			if node.Name == "ManaNode" and node.Parent then
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local radius = CollectionRangeHandler.getRadius(player)
						if (rootPart.Position - node.Position).Magnitude <= radius then
							collectNode(node, player)
							break
						end
					end
				end
			end
		end
	end
end)

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

-- Thin along X (the approach direction), wide along Z, so its wide face -
-- not its thin edge - points back at the platform, toward the player.
-- Glass + partial transparency gives the card a see-through look (matching
-- the reference screenshot) instead of a solid opaque slab - purely visual,
-- CanCollide stays true so it's still a solid physical object.
local function makeKioskCard(name: string, offsetX: number, offsetZ: number, width: number, extraRotationY: number?)
	local card = Instance.new("Part")
	card.Name = name
	card.Anchored = true
	card.CanCollide = true
	card.Material = Enum.Material.Glass
	card.Color = Color3.fromRGB(45, 45, 60)
	card.Transparency = 0.7
	card.Size = Vector3.new(1, 18, width)
	card.CFrame = CFrame.new(centerX + offsetX, groundY + 9, centerZ + offsetZ)
		* CFrame.Angles(0, extraRotationY or 0, 0)
	card.Parent = kiosksFolder
	return card
end

local MANA_BOARD_WIDTH = 42
local REBIRTH_BOARD_WIDTH = 20
local REBIRTH_SHOP_BOARD_WIDTH = 32 -- fits its 3 active columns edge-to-edge
local BOARD_GAP = 4 -- studs between separate boards
local CARD_THICKNESS = 1 -- matches makeKioskCard's Size.X below

makeKioskCard("ManaUpgradeBoard", half + 6, 0, MANA_BOARD_WIDTH)

-- Placed just past the Mana board's edge, on the side that reads as "to the
-- right" of it when facing the boards. (The opposite sign than the
-- Left-face SurfaceGui coordinate math suggested - confirmed by testing.)
local rebirthBoardOffsetZ = (MANA_BOARD_WIDTH / 2) + BOARD_GAP + (REBIRTH_BOARD_WIDTH / 2)
makeKioskCard("RebirthBoard", half + 6, rebirthBoardOffsetZ, REBIRTH_BOARD_WIDTH)

-- Further along the same direction, just past the Rebirth board's own edge.
-- Rotated -90 degrees so it faces back along the row (toward the other two
-- boards) instead of straight ahead like they do - the natural direction to
-- face when it's the last board at the end of the line. That same rotation
-- swaps which of its dimensions runs along the row: its 16-stud width now
-- extends along X (depth) instead of Z, so only its 1-stud THICKNESS
-- extends along Z - use half of that, not half its width, to sit its edge
-- flush against the Rebirth board's edge instead of leaving a big gap.
local rebirthShopBoardOffsetZ = rebirthBoardOffsetZ + (REBIRTH_BOARD_WIDTH / 2) + BOARD_GAP + (CARD_THICKNESS / 2)
makeKioskCard("RebirthShopBoard", half + -10, rebirthShopBoardOffsetZ, REBIRTH_SHOP_BOARD_WIDTH, math.rad(-90))

-- ===========================================================================
-- Second island: the next part of the obby. Straight out from the starting
-- island along +Z (not tied to the kiosk row's own east-side X offset) -
-- the player faces +Z when the kiosks read as being on their left, which is
-- roughly the direction that got circled as "build the next island here."
-- Bridged across a gap; no upgrade kiosks on it yet, just the island, a
-- locked gate, and some edge decoration. If this lands in the wrong spot,
-- the numbers to nudge are SECOND_ISLAND_SIZE/BRIDGE_LENGTH/BRIDGE_WIDTH
-- below, same trial-and-error as the kiosk board offsets above.
local SECOND_ISLAND_SIZE = ISLAND_SIZE -- "around the same size as this starting one"
local BRIDGE_LENGTH = 30 -- gap of void the bridge spans
local BRIDGE_WIDTH = 12

local SECOND_ISLAND_MANA_REQUIREMENT = 40000000
local SECOND_ISLAND_REBIRTHS_REQUIREMENT = 40000
local SECOND_ISLAND_LEVEL_REQUIREMENT = 25

for _, name in { "SecondIsland", "IslandBridge", "SecondIslandGate", "SecondIslandDecor" } do
	local existingPart = Workspace:FindFirstChild(name)
	if existingPart then
		existingPart:Destroy()
	end
end

-- Same axis SpawnLocation/StartingIsland already use, just further along Z.
local islandEdgeZ = islandCenterZ + ISLAND_SIZE / 2
local secondIslandCenterZ = islandEdgeZ + BRIDGE_LENGTH + SECOND_ISLAND_SIZE / 2

local secondIsland = Instance.new("Part")
secondIsland.Name = "SecondIsland"
secondIsland.Anchored = true
secondIsland.CanCollide = true
secondIsland.Material = Enum.Material.Grass
secondIsland.Color = Color3.fromRGB(90, 170, 60)
secondIsland.Size = Vector3.new(SECOND_ISLAND_SIZE, ISLAND_THICKNESS, SECOND_ISLAND_SIZE)
secondIsland.CFrame = CFrame.new(islandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, secondIslandCenterZ)
secondIsland.Parent = Workspace

local bridge = Instance.new("Part")
bridge.Name = "IslandBridge"
bridge.Anchored = true
bridge.CanCollide = true
bridge.Material = Enum.Material.WoodPlanks
bridge.Color = Color3.fromRGB(130, 95, 60)
bridge.Size = Vector3.new(BRIDGE_WIDTH, ISLAND_THICKNESS, BRIDGE_LENGTH)
bridge.CFrame = CFrame.new(islandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, islandEdgeZ + BRIDGE_LENGTH / 2)
bridge.Parent = Workspace

-- Purely visual (CanCollide false, so it can never physically trap anyone on
-- either side) - the position-check loop further down is what actually
-- enforces the lock, by teleporting an under-leveled player back off the
-- bridge the moment they step onto it.
local gate = Instance.new("Part")
gate.Name = "SecondIslandGate"
gate.Anchored = true
gate.CanCollide = false
gate.Material = Enum.Material.ForceField
gate.Color = Color3.fromRGB(255, 60, 60)
gate.Transparency = 0.5
gate.Size = Vector3.new(BRIDGE_WIDTH, 14, 1)
gate.CFrame = CFrame.new(islandCenterX, ISLAND_TOP_Y + 7, islandEdgeZ + 0.5)
gate.Parent = Workspace

-- Faces back toward the starting island, i.e. the -Z direction players
-- approach from - a guess like the kiosk boards' SurfaceGui faces were;
-- flip to Enum.NormalId.Back if it renders unreadable from the approach side.
local gateGui = Instance.new("SurfaceGui")
gateGui.Name = "SecondIslandGateGui"
gateGui.Face = Enum.NormalId.Front
gateGui.Adornee = gate
gateGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gateGui.PixelsPerStud = 36
gateGui.Parent = gate

local gateBackground = Instance.new("Frame")
gateBackground.Size = UDim2.new(1, 0, 1, 0)
gateBackground.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
gateBackground.BackgroundTransparency = 0.35
gateBackground.BorderSizePixel = 0
gateBackground.Parent = gateGui

local gateText = Instance.new("TextLabel")
gateText.Size = UDim2.new(0.9, 0, 0.9, 0)
gateText.Position = UDim2.new(0.05, 0, 0.05, 0)
gateText.BackgroundTransparency = 1
gateText.Font = Enum.Font.GothamBold
gateText.TextScaled = true
gateText.TextWrapped = true
gateText.TextColor3 = Color3.fromRGB(255, 210, 210)
gateText.TextStrokeTransparency = 0.4
gateText.Text = "LOCKED\n40,000,000 Mana\n40,000 Rebirths\nLevel 25"
gateText.Parent = gateBackground

-- Edge decoration - flowers, trees, bushes, purely visual dressing since
-- there's no kiosk content on this island yet.
local decorFolder = Instance.new("Folder")
decorFolder.Name = "SecondIslandDecor"
decorFolder.Parent = Workspace

local function makeTree(x: number, z: number)
	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(90, 60, 35)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(5, 1.5, 1.5) -- Cylinder's round axis is local X; rotated below to stand upright
	trunk.CFrame = CFrame.new(x, ISLAND_TOP_Y + 2.5, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = decorFolder

	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Material = Enum.Material.Grass
	leaves.Color = Color3.fromRGB(50, 140, 60)
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(7, 7, 7)
	leaves.CFrame = CFrame.new(x, ISLAND_TOP_Y + 7, z)
	leaves.Parent = decorFolder
end

local function makeBush(x: number, z: number)
	local bush = Instance.new("Part")
	bush.Name = "Bush"
	bush.Anchored = true
	bush.CanCollide = false
	bush.Material = Enum.Material.Grass
	bush.Color = Color3.fromRGB(60, 130, 55)
	bush.Shape = Enum.PartType.Ball
	bush.Size = Vector3.new(3, 2.2, 3)
	bush.CFrame = CFrame.new(x, ISLAND_TOP_Y + 1.1, z)
	bush.Parent = decorFolder
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 255, 255),
}

local function makeFlower(x: number, z: number)
	local flower = Instance.new("Part")
	flower.Name = "Flower"
	flower.Anchored = true
	flower.CanCollide = false
	flower.Material = Enum.Material.Neon
	flower.Color = FLOWER_COLORS[math.random(#FLOWER_COLORS)]
	flower.Shape = Enum.PartType.Ball
	flower.Size = Vector3.new(0.8, 0.8, 0.8)
	flower.CFrame = CFrame.new(x, ISLAND_TOP_Y + 0.4, z)
	flower.Parent = decorFolder
end

-- Rings the perimeter at a fixed inset, cycling tree/bush/flower/flower so
-- flowers show up more often as small accents between the bigger anchors.
-- Skips the near edge's middle stretch so the bridge entrance stays clear.
local DECOR_INSET = 8
local DECOR_STEP = 12
local decorHalf = SECOND_ISLAND_SIZE / 2 - DECOR_INSET

local decorKinds = { makeTree, makeBush, makeFlower, makeFlower }
local decorIndex = 0
local function placeNextDecor(x: number, z: number)
	decorIndex += 1
	decorKinds[(decorIndex - 1) % #decorKinds + 1](x, z)
end

for offset = -decorHalf, decorHalf, DECOR_STEP do
	placeNextDecor(islandCenterX + offset, secondIslandCenterZ + decorHalf) -- far edge
	if math.abs(offset) > BRIDGE_WIDTH / 2 then -- near edge, minus the bridge's entrance gap
		placeNextDecor(islandCenterX + offset, secondIslandCenterZ - decorHalf)
	end
	placeNextDecor(islandCenterX + decorHalf, secondIslandCenterZ + offset) -- far X edge
	placeNextDecor(islandCenterX - decorHalf, secondIslandCenterZ + offset) -- near X edge
end

-- Enforces the lock: an under-leveled player who steps onto the bridge gets
-- pushed back onto the starting island, same poll-loop pattern as the
-- fall-kill check above. Restricted to the bridge's own width so it never
-- catches someone just walking near the starting island's edge elsewhere.
local function meetsSecondIslandRequirement(player: Player): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	return (data.mana or 0) >= SECOND_ISLAND_MANA_REQUIREMENT
		and (data.rebirths or 0) >= SECOND_ISLAND_REBIRTHS_REQUIREMENT
		and (data.level or 1) >= SECOND_ISLAND_LEVEL_REQUIREMENT
end

local GATE_CHECK_INTERVAL = 0.25
local GATE_Z = islandEdgeZ + 1 -- just onto the bridge past the starting island's edge

task.spawn(function()
	while true do
		task.wait(GATE_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart.Position.Z >= GATE_Z and math.abs(rootPart.Position.X - islandCenterX) <= BRIDGE_WIDTH / 2 and not meetsSecondIslandRequirement(player) then
				rootPart.CFrame = CFrame.new(islandCenterX, groundY + 3, GATE_Z - 5)
			end
		end
	end
end)
