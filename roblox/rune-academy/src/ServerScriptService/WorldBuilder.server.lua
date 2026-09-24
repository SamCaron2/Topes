-- Generates world content on server start. Rebuilding from scratch after the
-- full reset - starts with just the Mana collection platform, grows one piece
-- at a time as the new vision gets specified.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ManaHandler = require(script.Parent.ManaHandler)
local ManaSpawnHandler = require(script.Parent.ManaSpawnHandler)
local ArcaneDustHandler = require(script.Parent.ArcaneDustHandler)
local ArcaneDustSpawnHandler = require(script.Parent.ArcaneDustSpawnHandler)
local CollectionRangeHandler = require(script.Parent.CollectionRangeHandler)
local XPHandler = require(script.Parent.XPHandler)
local PlayerData = require(script.Parent.PlayerData)
local UpgradeTreeHandler = require(script.Parent.UpgradeTreeHandler)
local EtherHandler = require(script.Parent.EtherHandler)
local EtherClickSpeedHandler = require(script.Parent.EtherClickSpeedHandler)
local EtherAutoClickHandler = require(script.Parent.EtherAutoClickHandler)
local WizardTierHandler = require(script.Parent.WizardTierHandler)
local RuinRuneHandler = require(script.Parent.RuinRuneHandler)
local RuneHandler = require(script.Parent.RuneHandler)
local WorldDecor = require(script.Parent.WorldDecor)
local LeyShardHandler = require(script.Parent.LeyShardHandler)
local LeyShardSpeedHandler = require(script.Parent.LeyShardSpeedHandler)

local MANA_ZONE_SIZE = 60 -- studs, square
local BORDER_THICKNESS = 1
local BORDER_HEIGHT = 0.2
local MANA_NODE_MARGIN = 3 -- keep nodes off the border line

local ISLAND_SIZE = 120 -- studs, square - comfortably fits the platform + kiosk board with room to spare
local ISLAND_THICKNESS = 6
local ISLAND_TOP_Y = 60 -- how high above the void the starting island floats
local FALL_KILL_MARGIN = 30 -- studs below the island surface before a fallen player is destroyed and respawned

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotesFolder:WaitForChild("ManaUpdated")
local xpUpdatedEvent = remotesFolder:WaitForChild("XPUpdated")
local arcaneDustUpdatedEvent = remotesFolder:WaitForChild("ArcaneDustUpdated")
local etherUpdatedEvent = remotesFolder:WaitForChild("EtherUpdated")
local upgradeTreeTileBoughtEvent = remotesFolder:WaitForChild("UpgradeTreeTileBought")
local runeAltarCollectedEvent = remotesFolder:WaitForChild("RuneAltarCollected")
local leyShardUpdatedEvent = remotesFolder:WaitForChild("LeyShardUpdated")

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

-- A small glowing flask instead of a plain cube - per direct request
-- ("floating potions that are bobbing up and down"). Two parts (a rounded
-- body + a narrow neck) grouped into a Model so the Heartbeat loop below
-- can move both together with one PivotTo per frame. Floats clear of the
-- ground (BaseY well above the old cube's own resting height) since
-- "floating" was the explicit ask, not just resting on the platform.
local MANA_NODE_BASE_Y_OFFSET = 2
local MANA_NODE_BOB_AMPLITUDE = 0.35 -- studs, up and down from BaseY
local MANA_NODE_BOB_SPEED = 2.2 -- radians/second

local function spawnManaNode()
	local x, z = randomPointInZone()
	local baseY = groundY + MANA_NODE_BASE_Y_OFFSET

	local node = Instance.new("Model")
	node.Name = "ManaNode"

	local body = Instance.new("Part")
	body.Name = "PotionBody"
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Neon
	body.Color = Color3.fromRGB(150, 80, 255)
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.6, 1.3, 1.6)
	body.CFrame = CFrame.new(x, baseY, z)
	body.Parent = node

	local neck = Instance.new("Part")
	neck.Name = "PotionNeck"
	neck.Anchored = true
	neck.CanCollide = false
	neck.Material = Enum.Material.Neon
	neck.Color = Color3.fromRGB(195, 150, 255)
	neck.Shape = Enum.PartType.Cylinder
	neck.Size = Vector3.new(0.55, 0.45, 0.45) -- Cylinder's round axis is local X; rotated below to stand upright
	neck.CFrame = CFrame.new(x, baseY + 0.85, z) * CFrame.Angles(0, 0, math.rad(90))
	neck.Parent = node

	node.PrimaryPart = body
	-- Random phase so a room full of potions doesn't bob in perfect unison.
	node:SetAttribute("BobPhase", math.random() * math.pi * 2)
	node:SetAttribute("BaseX", x)
	node:SetAttribute("BaseY", baseY)
	node:SetAttribute("BaseZ", z)
	node.Parent = manaZone
end

-- One shared Heartbeat loop bobs every live potion up and down, rather
-- than a per-node loop/tween - cheap even with several nodes at once,
-- and naturally stops touching a node the instant it's destroyed (just
-- skipped next frame since it's no longer in manaZone's children).
RunService.Heartbeat:Connect(function()
	for _, node in manaZone:GetChildren() do
		if node:IsA("Model") and node.Name == "ManaNode" then
			local baseX = node:GetAttribute("BaseX")
			local baseY = node:GetAttribute("BaseY")
			local baseZ = node:GetAttribute("BaseZ")
			local phase = node:GetAttribute("BobPhase") or 0
			local bobY = MANA_NODE_BOB_AMPLITUDE * math.sin(os.clock() * MANA_NODE_BOB_SPEED + phase)
			node:PivotTo(CFrame.new(baseX, baseY + bobY, baseZ))
		end
	end
end)

local function collectNode(node: Model, player: Player)
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
-- ManaRingClient draws around their feet. Lowered from 0.15s to 0.05s per
-- direct report ("make the collection faster. It is kind of delayed.") -
-- up to 3x snappier at the moment a player enters range.
local COLLECT_CHECK_INTERVAL = 0.05

task.spawn(function()
	while true do
		task.wait(COLLECT_CHECK_INTERVAL)
		for _, node in manaZone:GetChildren() do
			if node:IsA("Model") and node.Name == "ManaNode" and node.Parent and node.PrimaryPart then
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local rootPart = character and character:FindFirstChild("HumanoidRootPart")
					if rootPart then
						local radius = CollectionRangeHandler.getRadius(player)
						if (rootPart.Position - node.PrimaryPart.Position).Magnitude <= radius then
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
local BRIDGE_THICKNESS = 1
local BRIDGE_RAIL_HEIGHT = 3
local BRIDGE_POST_SPACING = 10
-- Shifts the whole second-island complex right (from the POV of a player
-- facing +Z, right is -X) so it clears the RebirthShopBoard instead of
-- crowding it - nudge this further if it's still too close.
local SECOND_ISLAND_OFFSET_X = -25

for _, name in { "SecondIsland", "IslandBridge", "SecondIslandGate", "SecondIslandDecor" } do
	local existingPart = Workspace:FindFirstChild(name)
	if existingPart then
		existingPart:Destroy()
	end
end

-- Same Z axis SpawnLocation/StartingIsland already use, just further along
-- it and shifted over in X.
local islandEdgeZ = islandCenterZ + ISLAND_SIZE / 2
local secondIslandCenterZ = islandEdgeZ + BRIDGE_LENGTH + SECOND_ISLAND_SIZE / 2
local secondIslandCenterX = islandCenterX + SECOND_ISLAND_OFFSET_X

local secondIsland = Instance.new("Part")
secondIsland.Name = "SecondIsland"
secondIsland.Anchored = true
secondIsland.CanCollide = true
secondIsland.Material = Enum.Material.Grass
secondIsland.Color = Color3.fromRGB(90, 170, 60)
secondIsland.Size = Vector3.new(SECOND_ISLAND_SIZE, ISLAND_THICKNESS, SECOND_ISLAND_SIZE)
secondIsland.CFrame = CFrame.new(secondIslandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, secondIslandCenterZ)
secondIsland.Parent = Workspace

-- A rope-bridge look instead of a single flat slab: a thin plank deck with
-- wooden rails along both edges, held up by posts at regular intervals.
local bridgeFolder = Instance.new("Folder")
bridgeFolder.Name = "IslandBridge"
bridgeFolder.Parent = Workspace

local bridgeCenterZ = islandEdgeZ + BRIDGE_LENGTH / 2

local deck = Instance.new("Part")
deck.Name = "BridgeDeck"
deck.Anchored = true
deck.CanCollide = true
deck.Material = Enum.Material.WoodPlanks
deck.Color = Color3.fromRGB(150, 110, 70)
deck.Size = Vector3.new(BRIDGE_WIDTH, BRIDGE_THICKNESS, BRIDGE_LENGTH)
deck.CFrame = CFrame.new(secondIslandCenterX, ISLAND_TOP_Y - BRIDGE_THICKNESS / 2, bridgeCenterZ)
deck.Parent = bridgeFolder

local function makeBridgeRail(xOffset: number)
	local rail = Instance.new("Part")
	rail.Name = "BridgeRail"
	rail.Anchored = true
	rail.CanCollide = false
	rail.Material = Enum.Material.Wood
	rail.Color = Color3.fromRGB(110, 80, 50)
	rail.Shape = Enum.PartType.Cylinder
	rail.Size = Vector3.new(BRIDGE_LENGTH, 0.6, 0.6) -- Cylinder's round axis is local X; rotated below to run along Z
	rail.CFrame = CFrame.new(secondIslandCenterX + xOffset, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT, bridgeCenterZ)
		* CFrame.Angles(0, math.rad(90), 0)
	rail.Parent = bridgeFolder
end
makeBridgeRail(BRIDGE_WIDTH / 2)
makeBridgeRail(-BRIDGE_WIDTH / 2)

for postZ = 0, BRIDGE_LENGTH, BRIDGE_POST_SPACING do
	for _, xOffset in { BRIDGE_WIDTH / 2, -BRIDGE_WIDTH / 2 } do
		local post = Instance.new("Part")
		post.Name = "BridgePost"
		post.Anchored = true
		post.CanCollide = false
		post.Material = Enum.Material.Wood
		post.Color = Color3.fromRGB(110, 80, 50)
		post.Size = Vector3.new(0.6, BRIDGE_RAIL_HEIGHT, 0.6)
		post.CFrame = CFrame.new(secondIslandCenterX + xOffset, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT / 2, islandEdgeZ + postZ)
		post.Parent = bridgeFolder
	end
end

-- Purely visual (CanCollide false, so it can never physically trap anyone on
-- either side) - the position-check loop further down is what actually
-- enforces the lock, by teleporting a not-yet-unlocked player back off the
-- bridge the moment they step onto it. Its UI (the "LOCKED" sign and the
-- Unlock button) is built client-side by SecondIslandGateClient, since it
-- needs to be interactive and hide itself locally once that player unlocks
-- it - not just a static server-built sign.
local gate = Instance.new("Part")
gate.Name = "SecondIslandGate"
gate.Anchored = true
gate.CanCollide = false
gate.Material = Enum.Material.ForceField
gate.Color = Color3.fromRGB(255, 60, 60)
gate.Transparency = 0.5
gate.Size = Vector3.new(BRIDGE_WIDTH, 14, 1)
gate.CFrame = CFrame.new(secondIslandCenterX, ISLAND_TOP_Y + 7, islandEdgeZ + 0.5)
gate.Parent = Workspace

-- Edge decoration - flowers, trees, bushes, purely visual dressing since
-- there's no kiosk content on this island yet. Built from several
-- overlapping/stacked parts per piece instead of one plain shape each, for a
-- fuller, less "primitive" look. Takes a folder so both SecondIsland and
-- LeaderboardIsland can scatter their own ring of these into their own
-- decor folder.
-- Edge decoration (trees/bushes/flowers, or SecondIsland's own
-- purple-wizard set) now lives in WorldDecor.lua - split out once this
-- script's own top-level locals crossed Luau's 200-register-per-chunk
-- limit ("Out of local registers... exceeded limit 200"). See that
-- module for the actual piece-building/scattering logic;
-- `WorldDecor.scatter(folder, centerX, centerZ, size, nearEdgeSign,
-- groundY, bridgeWidth, useWizardTheme?)` is the one entry point, called
-- 3 times below (SecondIsland, EtherIsland, LeaderboardIsland).

local secondIslandDecorFolder = Instance.new("Folder")
secondIslandDecorFolder.Name = "SecondIslandDecor"
secondIslandDecorFolder.Parent = Workspace

-- SecondIsland's bridge approaches from -Z, so that's the edge to skip.
-- Uses its own purple-wizard decor set (see WorldDecor), per direct request.
WorldDecor.scatter(
	secondIslandDecorFolder,
	secondIslandCenterX,
	secondIslandCenterZ,
	SECOND_ISLAND_SIZE,
	-1,
	ISLAND_TOP_Y,
	BRIDGE_WIDTH,
	true
)

-- Enforces the lock: a player who hasn't pressed the gate's Unlock button
-- yet (SecondIslandHandler.unlock, via SecondIslandGateClient) gets pushed
-- back onto the starting island the moment they step past the gate -
-- meeting the stat requirement alone no longer opens it, only pressing the
-- button does (that's the whole point of the button - it actually SPENDS
-- the Mana/Rebirths requirement instead of just checking it). Same
-- poll-loop pattern as the fall-kill check above.
--
-- BUG FIX: this used to check X within BRIDGE_WIDTH/2 (6 studs) of center,
-- meaning it only enforced the lock on the narrow bridge itself - once a
-- player made it across onto the much wider SecondIsland (120 studs) and
-- drifted off that 6-stud-wide corridor, the check silently stopped
-- matching and never caught them again, letting them walk right up to
-- and use every board/pad on the island without ever unlocking it. Now
-- checks the FULL island width so it keeps enforcing anywhere on
-- SecondIsland, not just the bridge crossing itself.
local GATE_CHECK_INTERVAL = 0.25
local GATE_Z = islandEdgeZ + 1 -- just onto the bridge past the starting island's edge

task.spawn(function()
	while true do
		task.wait(GATE_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if
				rootPart
				and rootPart.Position.Z >= GATE_Z
				and math.abs(rootPart.Position.X - secondIslandCenterX) <= SECOND_ISLAND_SIZE / 2
			then
				local data = PlayerData.get(player)
				if data and not data.secondIslandUnlocked then
					rootPart.CFrame = CFrame.new(secondIslandCenterX, groundY + 3, GATE_Z - 5)
				end
			end
		end
	end
end)

-- ===========================================================================
-- Arcane Dust: the second wizard resource, entirely separate from Mana (no
-- shared currency, no Rebirth Shop interaction, not reset by rebirthing).
-- Lives here on SecondIsland rather than a collection zone on the starting
-- island - a single stand-on pad instead of scattered pickup nodes, per
-- direct request. Standing on it grants Arcane Dust immediately, then
-- again every ArcaneDustSpawnHandler interval for as long as you stay -
-- step off and the timer resets, so it's "stand here to farm," not
-- "walk past to collect once."
-- Off to the side and near the edge, rather than dead center - moved there
-- per direct request. The pad sits in front of the board (along the
-- board's facing direction, +X - "in front," not off to the side along the
-- edge like the original layout), so standing on it faces you at the board.
local secondIslandNearEdgeZ = secondIslandCenterZ - (SECOND_ISLAND_SIZE / 2)
local ARCANE_DUST_PAD_RADIUS = 5
local ARCANE_DUST_AREA_X = secondIslandCenterX - (SECOND_ISLAND_SIZE / 2 - 15) -- 15 studs in from the -X edge (the board's X)
local ARCANE_DUST_AREA_Z = secondIslandNearEdgeZ + 25
local ARCANE_DUST_PAD_FRONT_OFFSET = 12 -- studs in front of the board, along its +X facing direction
local arcaneDustPadX = ARCANE_DUST_AREA_X + ARCANE_DUST_PAD_FRONT_OFFSET
local arcaneDustPadZ = ARCANE_DUST_AREA_Z

local existingArcaneDustPad = Workspace:FindFirstChild("ArcaneDustPad")
if existingArcaneDustPad then
	existingArcaneDustPad:Destroy()
end

local ARCANE_DUST_COLOR = Color3.fromRGB(60, 190, 230) -- matches the Arcane Dust icon's own blue, per direct request

-- Visible and solid from the start, even before SecondIsland is unlocked -
-- per direct request ("keep the cards so people see there is stuff on the
-- island but the text on them does not appear until you unlock"), replacing
-- the earlier fully-hidden treatment. The actual Arcane Dust grant is still
-- blocked server-side until `secondIslandUnlocked` (ArcaneDustHandler.collect
-- checks this directly), so standing here early just does nothing rather
-- than needing to be physically unreachable.
local arcaneDustPad = Instance.new("Part")
arcaneDustPad.Name = "ArcaneDustPad"
arcaneDustPad.Anchored = true
arcaneDustPad.CanCollide = true
arcaneDustPad.Material = Enum.Material.Neon
arcaneDustPad.Color = ARCANE_DUST_COLOR
arcaneDustPad.Shape = Enum.PartType.Cylinder
arcaneDustPad.Size = Vector3.new(0.6, ARCANE_DUST_PAD_RADIUS * 2, ARCANE_DUST_PAD_RADIUS * 2) -- Cylinder's round axis is local X; rotated below to lie flat
arcaneDustPad.CFrame = CFrame.new(arcaneDustPadX, ISLAND_TOP_Y + 0.3, arcaneDustPadZ) * CFrame.Angles(0, 0, math.rad(90))
arcaneDustPad.Transparency = 0
arcaneDustPad.Parent = Workspace

-- Small and only visible up close (MaxDistance) - per direct request, it
-- was reading as way too large/visible from across the map. Starts
-- disabled - this is the pad's "text," so it stays hidden until
-- SecondIslandGateClient reveals it once this player actually unlocks.
local padLabelGui = Instance.new("BillboardGui")
padLabelGui.Name = "ArcaneDustPadLabel"
padLabelGui.Size = UDim2.new(0, 100, 0, 24)
padLabelGui.StudsOffset = Vector3.new(0, 2.5, 0)
padLabelGui.MaxDistance = 20
padLabelGui.AlwaysOnTop = true
padLabelGui.Enabled = false
padLabelGui.Adornee = arcaneDustPad
padLabelGui.Parent = arcaneDustPad

local padLabelText = Instance.new("TextLabel")
padLabelText.Size = UDim2.new(1, 0, 1, 0)
padLabelText.BackgroundTransparency = 1
padLabelText.Font = Enum.Font.GothamBold
padLabelText.TextScaled = true
padLabelText.TextColor3 = ARCANE_DUST_COLOR
padLabelText.TextStrokeTransparency = 0.2
padLabelText.Text = "Stand for Arcane Dust"
padLabelText.Parent = padLabelGui

local arcaneDustNextGrant = {} -- [player] = os.clock() time of the next grant while standing on the pad

Players.PlayerRemoving:Connect(function(player)
	arcaneDustNextGrant[player] = nil
end)

local ARCANE_DUST_PAD_CHECK_INTERVAL = 0.5

task.spawn(function()
	while true do
		task.wait(ARCANE_DUST_PAD_CHECK_INTERVAL)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local onPad = rootPart
				and (Vector2.new(rootPart.Position.X, rootPart.Position.Z) - Vector2.new(arcaneDustPadX, arcaneDustPadZ)).Magnitude
					<= ARCANE_DUST_PAD_RADIUS

			if onPad then
				local nextGrant = arcaneDustNextGrant[player]
				if not nextGrant or now >= nextGrant then
					local newAmount = ArcaneDustHandler.collect(player)
					if newAmount then
						arcaneDustUpdatedEvent:FireClient(player, newAmount)
					end
					arcaneDustNextGrant[player] = now + ArcaneDustSpawnHandler.getRespawnSeconds(player)
				end
			else
				arcaneDustNextGrant[player] = nil
			end
		end
	end
end)

-- Its upgrade board sits at the edge (not rotated - thin along X, wide
-- along Z, running parallel to the edge like the starting island's kiosk
-- row does), facing inward toward the island's center: "Right" (+X
-- normal), since it's near the -X edge. The pad sits ARCANE_DUST_PAD_FRONT_OFFSET
-- studs in front of it along that same +X direction, at the same Z, so
-- standing on the pad faces you directly at the board. A guess like every
-- other board's face here; flip to Left if it renders unreadable.
-- Widened from 24 to 30 to fit its 3rd column ("More Mana").
local ARCANE_DUST_BOARD_WIDTH = 30

-- Visible/solid glass from the start, same reasoning as ArcaneDustPad above
-- - the board itself (an empty glass panel) is what tells players "there's
-- stuff here," while ArcaneDustUpgradeBoardClient still withholds the
-- actual upgrade UI (a SurfaceGui, which renders independent of this Part's
-- Transparency) until this player's SecondIsland is unlocked.
local arcaneDustBoard = Instance.new("Part")
arcaneDustBoard.Name = "ArcaneDustUpgradeBoard"
arcaneDustBoard.Anchored = true
arcaneDustBoard.CanCollide = true
arcaneDustBoard.Material = Enum.Material.Glass
arcaneDustBoard.Color = Color3.fromRGB(45, 45, 60)
arcaneDustBoard.Transparency = 0.7 -- glass, like every other board
arcaneDustBoard.Size = Vector3.new(1, 18, ARCANE_DUST_BOARD_WIDTH)
arcaneDustBoard.CFrame = CFrame.new(ARCANE_DUST_AREA_X, ISLAND_TOP_Y + 9, ARCANE_DUST_AREA_Z)
arcaneDustBoard.Parent = kiosksFolder

-- ===========================================================================
-- Wizard Tiers: a deeper prestige layer than Rebirths (WizardTierHandler).
-- Its board sits right next to the Arcane Dust Upgrades board - same X (so
-- both are coplanar, facing the same +X direction) and offset along +Z
-- (away from the bridge/near edge, where there's 80+ studs of room left on
-- this island, unlike the -Z side which is only ~10 studs from the edge) -
-- per direct request, "a card to the left of this that is decently
-- bigger." Left/right is a guess like every other board's face here; flip
-- the Z offset's sign if it actually lands on the right.
local WIZARD_TIER_BOARD_WIDTH = 36
local WIZARD_TIER_BOARD_GAP = 6
local wizardTierAreaZ = ARCANE_DUST_AREA_Z + (ARCANE_DUST_BOARD_WIDTH / 2 + WIZARD_TIER_BOARD_GAP + WIZARD_TIER_BOARD_WIDTH / 2)

-- Visible/solid from the start, same reasoning as the Arcane Dust board
-- above - WizardTierBoardClient still withholds its own SurfaceGui until
-- this player's SecondIsland is unlocked.
local wizardTierBoard = Instance.new("Part")
wizardTierBoard.Name = "WizardTierBoard"
wizardTierBoard.Anchored = true
wizardTierBoard.CanCollide = true
wizardTierBoard.Material = Enum.Material.Glass
wizardTierBoard.Color = Color3.fromRGB(45, 30, 70)
wizardTierBoard.Transparency = 0.7
wizardTierBoard.Size = Vector3.new(1, 24, WIZARD_TIER_BOARD_WIDTH)
wizardTierBoard.CFrame = CFrame.new(ARCANE_DUST_AREA_X, ISLAND_TOP_Y + 12, wizardTierAreaZ)
wizardTierBoard.Parent = kiosksFolder

-- ===========================================================================
-- Fantasy Ruin: Tier 3's unlock (WizardTierHandler.hasUnlockedRuin), built
-- further along +Z past WizardTierBoard - "to the left of the Tier card,"
-- same left/right guess as every other board here. Every part starts
-- hidden (Transparency 1, CanCollide false) - WizardRuinClient reveals it
-- LOCALLY (same per-player pattern as SecondIslandGate) for whichever
-- players have actually reached Tier 3, since different players can be at
-- different tiers at once and this is shared world geometry, not a
-- per-player instance. Purely a decorative milestone area, not a new
-- mechanic - broken stone pillars in an arc around a glowing rune circle,
-- a crumbling archway, and scattered rubble.
local RUIN_SIZE = 26 -- studs, square footprint
local RUIN_GAP_FROM_BOARD = 6
local ruinAreaZ = wizardTierAreaZ + (WIZARD_TIER_BOARD_WIDTH / 2 + RUIN_GAP_FROM_BOARD + RUIN_SIZE / 2)
local ruinAreaX = ARCANE_DUST_AREA_X + 15 -- shifted inward from the boards' near-edge X so the plaza doesn't hang off the island

local existingRuin = Workspace:FindFirstChild("FantasyRuin")
if existingRuin then
	existingRuin:Destroy()
end

local fantasyRuinFolder = Instance.new("Folder")
fantasyRuinFolder.Name = "FantasyRuin"
fantasyRuinFolder.Parent = Workspace

local function newRuinPart(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Material = material
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	-- Hidden/no-clip by default - WizardRuinClient flips both to true LOCALLY
	-- for players who've reached Tier 3.
	part.Transparency = 1
	part.CanCollide = false
	part.Parent = fantasyRuinFolder
	return part
end

local RUIN_STONE_COLOR = Color3.fromRGB(120, 120, 110)
local RUIN_MOSS_COLOR = Color3.fromRGB(95, 115, 80)

-- The glowing rune circle centerpiece - same flat-cylinder trick as
-- ArcaneDustPad, just bigger, and colored to match the Wizard Tiers
-- board's purple/gold theme instead of Arcane Dust's blue. This is the
-- actual Rune Altar now, not just decoration: stand on it (no clicking,
-- per direct correction - "There is no clicking on a ruin you just sit
-- and it collects") and it periodically spends Mana for a chance-based
-- Rune, same "stand here" interaction as ArcaneDustPad but paid/gated
-- differently - see the collection loop below and RuneHandler.collectAtAltar.
local ruinRuneCircle = newRuinPart(
	"RuinRuneCircle",
	Vector3.new(0.6, 20, 20),
	CFrame.new(ruinAreaX, ISLAND_TOP_Y + 0.3, ruinAreaZ) * CFrame.Angles(0, 0, math.rad(90)),
	Enum.Material.Neon,
	Color3.fromRGB(180, 120, 255)
)

-- A floating glowing orb centered above the rune circle - purely the
-- plaza's decorative focal point, visible from a distance once revealed.
local ruinOrb = Instance.new("Part")
ruinOrb.Name = "RuinOrb"
ruinOrb.Shape = Enum.PartType.Ball
ruinOrb.Anchored = true
ruinOrb.Material = Enum.Material.Neon
ruinOrb.Color = Color3.fromRGB(255, 220, 120)
ruinOrb.Size = Vector3.new(4, 4, 4)
ruinOrb.CFrame = CFrame.new(ruinAreaX, ISLAND_TOP_Y + 10, ruinAreaZ)
ruinOrb.Transparency = 1
ruinOrb.CanCollide = false
ruinOrb.Parent = fantasyRuinFolder

-- 6 broken pillars in a ring around the rune circle, each a different
-- height/rotation so they read as crumbling rather than a uniform circle
-- of identical columns.
local RUIN_PILLAR_COUNT = 6
local RUIN_PILLAR_RADIUS = 11
for i = 1, RUIN_PILLAR_COUNT do
	local angle = (i - 1) / RUIN_PILLAR_COUNT * math.pi * 2
	local pillarX = ruinAreaX + RUIN_PILLAR_RADIUS * math.cos(angle)
	local pillarZ = ruinAreaZ + RUIN_PILLAR_RADIUS * math.sin(angle)
	-- Heights vary (broken at different points) - a plain repeating height
	-- would read as intact columns, not ruins.
	local height = 6 + (i % 3) * 3
	local tilt = (i % 2 == 0) and math.rad(4) or 0 -- every other pillar leans slightly, like it's collapsing
	newRuinPart(
		("RuinPillar%d"):format(i),
		Vector3.new(3, height, 3),
		CFrame.new(pillarX, ISLAND_TOP_Y + height / 2, pillarZ) * CFrame.Angles(tilt, angle, 0),
		Enum.Material.Rock,
		(i % 2 == 0) and RUIN_MOSS_COLOR or RUIN_STONE_COLOR
	)
end

-- A crumbling archway on the far side from the boards (facing back toward
-- them) - two pillars plus a lintel, with the lintel's far end broken off
-- short instead of spanning the full gap, so it reads as a ruin rather
-- than an intact doorway.
local archZ = ruinAreaZ + RUIN_SIZE / 2 - 3
newRuinPart(
	"RuinArchPillarLeft",
	Vector3.new(3, 12, 3),
	CFrame.new(ruinAreaX - 6, ISLAND_TOP_Y + 6, archZ),
	Enum.Material.Rock,
	RUIN_STONE_COLOR
)
newRuinPart(
	"RuinArchPillarRight",
	Vector3.new(3, 9, 3), -- shorter than the left pillar - asymmetric, more ruined
	CFrame.new(ruinAreaX + 6, ISLAND_TOP_Y + 4.5, archZ),
	Enum.Material.Rock,
	RUIN_MOSS_COLOR
)
newRuinPart(
	"RuinArchLintel",
	Vector3.new(9, 2, 3), -- only spans from the left pillar partway across, not the full 12-stud gap
	CFrame.new(ruinAreaX - 2, ISLAND_TOP_Y + 12.5, archZ),
	Enum.Material.Rock,
	RUIN_STONE_COLOR
)

-- Scattered rubble blocks for detail, each a small randomly-rotated cube.
local RUIN_RUBBLE_COUNT = 8
for i = 1, RUIN_RUBBLE_COUNT do
	local angle = math.random() * math.pi * 2
	local radius = 4 + math.random() * (RUIN_SIZE / 2 - 5)
	local rubbleX = ruinAreaX + radius * math.cos(angle)
	local rubbleZ = ruinAreaZ + radius * math.sin(angle)
	local rubbleSize = 1 + math.random()
	newRuinPart(
		("RuinRubble%d"):format(i),
		Vector3.new(rubbleSize, rubbleSize, rubbleSize),
		CFrame.new(rubbleX, ISLAND_TOP_Y + rubbleSize / 2, rubbleZ)
			* CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi),
		Enum.Material.Rock,
		(i % 2 == 0) and RUIN_MOSS_COLOR or RUIN_STONE_COLOR
	)
end

-- Its upgrade board (RuinRuneHandler's 5 tiers) sits exactly where asked -
-- per direct request, given as exact world coordinates read off
-- DebugPositionClient's live X/Y/Z readout while standing there ("-38 195
-- and it facing towards 194"), rather than a guess from a screenshot like
-- every other placement in this file. Facing -Z (towards the lower Z
-- value, 194) needs no rotation change from the previous spot - the
-- existing 90°-around-Y rotation + `SurfaceGui.Face = Right` in
-- RuneAltarBoardClient already point the visible face at world -Z. Wide
-- along X, thin along Z, same "thin one way, wide the other" board shape
-- as every other board here. Hidden/no-collide by default like
-- ArcaneDustUpgradeBoard/WizardTierBoard - WizardRuinClient reveals it
-- (via its own Reveal* attributes, same mechanism) alongside the rest of
-- the ruin, since it's gated on the same hasUnlockedRuin check.
local RUNE_ALTAR_BOARD_WIDTH = 30
local runeAltarBoardX = -38
local runeAltarBoardZ = 195

local runeAltarBoard = Instance.new("Part")
runeAltarBoard.Name = "RuneAltarBoard"
runeAltarBoard.Anchored = true
runeAltarBoard.CanCollide = false
runeAltarBoard.Material = Enum.Material.Glass
runeAltarBoard.Color = Color3.fromRGB(60, 30, 80)
runeAltarBoard.Transparency = 1
runeAltarBoard.Size = Vector3.new(1, 18, RUNE_ALTAR_BOARD_WIDTH)
runeAltarBoard.CFrame = CFrame.new(runeAltarBoardX, ISLAND_TOP_Y + 9, runeAltarBoardZ) * CFrame.Angles(0, math.rad(90), 0)
runeAltarBoard:SetAttribute("RevealTransparency", 0.7) -- glass, like every other board
runeAltarBoard:SetAttribute("RevealCanCollide", true)
runeAltarBoard.Parent = kiosksFolder

-- Clears any decor piece (tree/mushroom/etc, all its parts land within a
-- couple studs of the same anchor point) that ended up under the board's
-- new exact spot - per direct request, "remove the trees if you need."
local RUNE_ALTAR_BOARD_CLEAR_RADIUS = 10
for _, decorPart in secondIslandDecorFolder:GetChildren() do
	if decorPart:IsA("BasePart") then
		local dx = decorPart.Position.X - runeAltarBoardX
		local dz = decorPart.Position.Z - runeAltarBoardZ
		if dx * dx + dz * dz <= RUNE_ALTAR_BOARD_CLEAR_RADIUS ^ 2 then
			decorPart:Destroy()
		end
	end
end

-- The Rune Altar itself (RuinRuneCircle): stand within its radius and it
-- periodically spends Mana for a chance-based Rune - no clicking, per
-- direct correction. Checked far more often than the tick itself
-- (RUNE_ALTAR_CHECK_INTERVAL) so Rune Speed's halved interval still lands
-- close to on-time; each player's own next-allowed tick is tracked
-- separately (RuinRuneHandler.getTickIntervalSeconds can differ per
-- player), same per-player timer pattern as ArcaneDustPad's own loop.
local RUNE_ALTAR_RADIUS = 10 -- RuinRuneCircle is a 20-stud diameter disc
local RUNE_ALTAR_CHECK_INTERVAL = 0.25
local runeAltarNextTick = {} -- [player] = os.clock() of the next tick this player is allowed to collect from

Players.PlayerRemoving:Connect(function(player)
	runeAltarNextTick[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(RUNE_ALTAR_CHECK_INTERVAL)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local onAltar = rootPart
				and (Vector2.new(rootPart.Position.X, rootPart.Position.Z) - Vector2.new(ruinAreaX, ruinAreaZ)).Magnitude
					<= RUNE_ALTAR_RADIUS

			if onAltar then
				local nextTick = runeAltarNextTick[player]
				if not nextTick or now >= nextTick then
					local results, newMana = RuneHandler.collectAtAltar(player)
					if results then
						manaUpdatedEvent:FireClient(player, newMana)
						runeAltarCollectedEvent:FireClient(player, results)
					end
					runeAltarNextTick[player] = now + RuinRuneHandler.getTickIntervalSeconds(player)
				end
			else
				runeAltarNextTick[player] = nil
			end
		end
	end
end)

-- ===========================================================================
-- Upgrade Tree: walk-over tiles (UpgradeTreeHandler), only reachable once a
-- player has reached Tier 3 - every tile is always solid/visible (plain
-- paving stone; nothing to hide, since walking onto one before Tier 3 just
-- silently no-ops server-side), but the info sign painted flat onto each
-- tile's top face only renders per-player once they're actually unlocked
-- (UpgradeTreeClient). Widened from an original 6x6 square to 9x6 and
-- rotated 180° around Y (both per direct request) so every sign reads
-- right-side-up from the direction players actually approach them.
--
-- Tile 1 was placed first, in the open grass between the Fantasy Ruin and
-- ArcaneDustPad (a screenshot-guess, same treatment as every placement
-- here). The other 8 extend outward from it in a straight 1-2-3-2-1
-- diamond chain along +X (away from the ruin/pad/board cluster, into the
-- open grass beyond) - per direct request, with the sign for the widest
-- middle row's center tile (Tile 5, Rune Bulk x2) and the final row's
-- single tile (Tile 9, unlocks Ether) landing exactly where asked ("one of
-- the cards in the middle" / "the very last tile on the opposite side").
-- UPGRADE_TREE_TILE_POSITIONS is keyed by UpgradeTreeHandler tile id so
-- the two stay in sync; nudge UPGRADE_TREE_SPACING or individual offsets
-- if the shape doesn't land right on the ground.
local UPGRADE_TREE_TILE_WIDTH = 9
local UPGRADE_TREE_TILE_DEPTH = 6
local UPGRADE_TREE_TILE_1_X = (ruinAreaX + arcaneDustPadX) / 2
local UPGRADE_TREE_TILE_1_Z = (ruinAreaZ + arcaneDustPadZ) / 2 - 5
local UPGRADE_TREE_SPACING = 10

local UPGRADE_TREE_TILE_POSITIONS = {
	[1] = { x = UPGRADE_TREE_TILE_1_X, z = UPGRADE_TREE_TILE_1_Z }, -- Dust x2 (built first, on its own)
	[2] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING, z = UPGRADE_TREE_TILE_1_Z - UPGRADE_TREE_SPACING / 2 }, -- Mana x2
	[3] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING, z = UPGRADE_TREE_TILE_1_Z + UPGRADE_TREE_SPACING / 2 }, -- XP x2
	[4] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 2, z = UPGRADE_TREE_TILE_1_Z - UPGRADE_TREE_SPACING }, -- Rebirths x2
	[5] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 2, z = UPGRADE_TREE_TILE_1_Z }, -- Rune Bulk x2 (middle of the widest row)
	[6] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 2, z = UPGRADE_TREE_TILE_1_Z + UPGRADE_TREE_SPACING }, -- Dust x2
	[7] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 3, z = UPGRADE_TREE_TILE_1_Z - UPGRADE_TREE_SPACING / 2 }, -- Mana x2
	[8] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 3, z = UPGRADE_TREE_TILE_1_Z + UPGRADE_TREE_SPACING / 2 }, -- Rebirths x2
	[9] = { x = UPGRADE_TREE_TILE_1_X + UPGRADE_TREE_SPACING * 4, z = UPGRADE_TREE_TILE_1_Z }, -- unlocks Ether (final tile, opposite end from Tile 1)
}

local existingUpgradeTree = Workspace:FindFirstChild("UpgradeTreeTiles")
if existingUpgradeTree then
	existingUpgradeTree:Destroy()
end

local upgradeTreeFolder = Instance.new("Folder")
upgradeTreeFolder.Name = "UpgradeTreeTiles"
upgradeTreeFolder.Parent = Workspace

local UPGRADE_TREE_TILE_RADIUS = math.max(UPGRADE_TREE_TILE_WIDTH, UPGRADE_TREE_TILE_DEPTH) / 2
local UPGRADE_TREE_CHECK_INTERVAL = 0.5

for _, tile in UpgradeTreeHandler.TILES do
	local position = UPGRADE_TREE_TILE_POSITIONS[tile.id]

	local tilePart = Instance.new("Part")
	tilePart.Name = ("UpgradeTreeTile%d"):format(tile.id)
	tilePart.Anchored = true
	tilePart.CanCollide = true
	tilePart.Material = Enum.Material.Marble
	tilePart.Color = Color3.fromRGB(200, 200, 210)
	tilePart.Size = Vector3.new(UPGRADE_TREE_TILE_WIDTH, 0.4, UPGRADE_TREE_TILE_DEPTH)
	tilePart.CFrame = CFrame.new(position.x, ISLAND_TOP_Y + 0.2, position.z) * CFrame.Angles(0, math.rad(180), 0)
	tilePart.Parent = upgradeTreeFolder
end

task.spawn(function()
	while true do
		task.wait(UPGRADE_TREE_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local playerPosition = Vector2.new(rootPart.Position.X, rootPart.Position.Z)
				for _, tile in UpgradeTreeHandler.TILES do
					local position = UPGRADE_TREE_TILE_POSITIONS[tile.id]
					local onTile = (playerPosition - Vector2.new(position.x, position.z)).Magnitude <= UPGRADE_TREE_TILE_RADIUS

					if onTile and UpgradeTreeHandler.buyTile(player, tile.id) then
						local data = PlayerData.get(player)
						if data then
							arcaneDustUpdatedEvent:FireClient(player, data.arcaneDust or 0)
						end
						upgradeTreeTileBoughtEvent:FireClient(player, tile.id)
					end
				end
			end
		end
	end
end)

-- ===========================================================================
-- Ether: the third wizard resource, unlocked only once Tile 9 (the
-- Upgrade Tree's final tile) is bought. Click-collected via a
-- ClickDetector on the Ether Shroud, not auto-collected/walked-over like
-- Mana/Arcane Dust, per direct request - a deliberately slower, more
-- active-attention resource. Placed further out past Tile 9, in the open
-- grass toward the tree line, per the circled screenshot - a guess like
-- every other placement here; nudge ETHER_SHROUD_OFFSET if it's off.
-- Themed purple throughout, per direct request, distinct from the Wizard
-- Tier board's own purple (deeper violet here vs. that board's
-- indigo/gold). Everything here starts hidden/no-collide - shared world
-- geometry, but players can be at different Upgrade Tree progress, so
-- EtherAreaClient reveals it LOCALLY per-player once
-- UpgradeTreeHandler.isEtherUnlocked reports true for them, same pattern
-- as the Fantasy Ruin.
local ETHER_COLOR = Color3.fromRGB(150, 60, 220)
local ETHER_SHROUD_OFFSET = 15 -- studs past Tile 9, continuing the same +X chain direction
local ETHER_BOARD_FRONT_OFFSET = 12 -- studs behind the shroud, same front/back relationship as ArcaneDustPad/its board
-- Tile 9 sits almost exactly on the same Z line the EtherIsland bridge
-- leaves from (secondIslandCenterZ), so without this offset the Shroud and
-- its board land right in the walking path from the tree to that bridge -
-- reported directly ("move the ether card and shroud over to the right so
-- its not blocking the path to the next island"). Shifted sideways in Z,
-- clear of both the bridge's own width and the tree's row spread; nudge if
-- it ever reads as off toward the wrong side.
local ETHER_AREA_Z_OFFSET = 30

local tile9Position = UPGRADE_TREE_TILE_POSITIONS[9]
local etherShroudX = tile9Position.x + ETHER_SHROUD_OFFSET
local etherShroudZ = tile9Position.z + ETHER_AREA_Z_OFFSET
local etherBoardX = etherShroudX + ETHER_BOARD_FRONT_OFFSET
local etherBoardZ = etherShroudZ

local existingEtherArea = Workspace:FindFirstChild("EtherArea")
if existingEtherArea then
	existingEtherArea:Destroy()
end

local etherAreaFolder = Instance.new("Folder")
etherAreaFolder.Name = "EtherArea"
etherAreaFolder.Parent = Workspace

-- The Shroud itself: a cluster of overlapping translucent spheres (a
-- "mist" look) around one solid core sphere that actually carries the
-- ClickDetector - clicking the core is what registers, the mist around it
-- is purely decorative.
local etherShroudCore = Instance.new("Part")
etherShroudCore.Name = "EtherShroudCore"
etherShroudCore.Shape = Enum.PartType.Ball
etherShroudCore.Anchored = true
etherShroudCore.Material = Enum.Material.Neon
etherShroudCore.Color = ETHER_COLOR
etherShroudCore.Size = Vector3.new(6, 6, 6)
etherShroudCore.CFrame = CFrame.new(etherShroudX, ISLAND_TOP_Y + 4, etherShroudZ)
etherShroudCore.Transparency = 1
etherShroudCore.CanCollide = false
etherShroudCore.Parent = etherAreaFolder

local etherClickDetector = Instance.new("ClickDetector")
etherClickDetector.MaxActivationDistance = 20
etherClickDetector.Parent = etherShroudCore

-- Starts disabled - EtherAreaClient enables it locally alongside revealing
-- the rest of the area, same "hidden until unlocked" treatment.
local etherShroudLabelGui = Instance.new("BillboardGui")
etherShroudLabelGui.Name = "EtherShroudLabel"
etherShroudLabelGui.Size = UDim2.new(0, 140, 0, 24)
etherShroudLabelGui.StudsOffset = Vector3.new(0, 4.5, 0)
etherShroudLabelGui.MaxDistance = 25
etherShroudLabelGui.AlwaysOnTop = true
etherShroudLabelGui.Enabled = false
etherShroudLabelGui.Adornee = etherShroudCore
etherShroudLabelGui.Parent = etherShroudCore

local etherShroudLabelText = Instance.new("TextLabel")
etherShroudLabelText.Size = UDim2.new(1, 0, 1, 0)
etherShroudLabelText.BackgroundTransparency = 1
etherShroudLabelText.Font = Enum.Font.GothamBold
etherShroudLabelText.TextScaled = true
etherShroudLabelText.TextColor3 = ETHER_COLOR
etherShroudLabelText.TextStrokeTransparency = 0.2
etherShroudLabelText.Text = "Click to Collect Ether"
etherShroudLabelText.Parent = etherShroudLabelGui

local ETHER_MIST_COUNT = 5
for i = 1, ETHER_MIST_COUNT do
	local angle = (i - 1) / ETHER_MIST_COUNT * math.pi * 2
	local radius = 3
	local mistPart = Instance.new("Part")
	mistPart.Name = ("EtherShroudMist%d"):format(i)
	mistPart.Shape = Enum.PartType.Ball
	mistPart.Anchored = true
	mistPart.Material = Enum.Material.ForceField
	mistPart.Color = ETHER_COLOR
	mistPart.Size = Vector3.new(5, 5, 5)
	mistPart.CFrame = CFrame.new(
		etherShroudX + radius * math.cos(angle),
		ISLAND_TOP_Y + 4 + math.sin(angle * 2),
		etherShroudZ + radius * math.sin(angle)
	)
	mistPart.Transparency = 1
	mistPart.CanCollide = false
	-- Revealed transparency is translucent (0.55), not fully opaque - it's
	-- meant to read as mist, not a solid ball.
	mistPart:SetAttribute("RevealTransparency", 0.55)
	mistPart.Parent = etherAreaFolder
end

-- Solid ground beneath the shroud so it doesn't just float over plain
-- grass - a small round platform, same hidden-until-unlocked treatment.
local etherPlatform = Instance.new("Part")
etherPlatform.Name = "EtherPlatform"
etherPlatform.Shape = Enum.PartType.Cylinder
etherPlatform.Anchored = true
etherPlatform.Material = Enum.Material.Marble
etherPlatform.Color = Color3.fromRGB(70, 40, 90)
etherPlatform.Size = Vector3.new(0.6, 12, 12)
etherPlatform.CFrame = CFrame.new(etherShroudX, ISLAND_TOP_Y + 0.3, etherShroudZ) * CFrame.Angles(0, 0, math.rad(90))
etherPlatform.Transparency = 1
etherPlatform.CanCollide = false
etherPlatform:SetAttribute("RevealCanCollide", true) -- solid ground once revealed, unlike the floating shroud/mist above it
etherPlatform.Parent = etherAreaFolder

-- Its upgrade board, same physical style as every other board (thin along
-- X, wide along Z, facing inward at the shroud) - "More Ether", "Click
-- Speed", "More Dust", and "Auto Click". Widened from 30 to 40 to fit its
-- 4th column, same "widen when a column is added" precedent as the Arcane
-- Dust board.
local ETHER_BOARD_WIDTH = 40

local etherBoard = Instance.new("Part")
etherBoard.Name = "EtherUpgradeBoard"
etherBoard.Anchored = true
etherBoard.Material = Enum.Material.Glass
etherBoard.Color = Color3.fromRGB(45, 25, 60)
etherBoard.Size = Vector3.new(1, 18, ETHER_BOARD_WIDTH)
etherBoard.CFrame = CFrame.new(etherBoardX, ISLAND_TOP_Y + 9, etherBoardZ)
etherBoard.Transparency = 1
etherBoard.CanCollide = false
-- Revealed transparency matches every other board's own "clear glass" look
-- (0.7) - per direct request ("the card needs to be clear"), since the
-- generic reveal logic would otherwise leave it fully opaque like the
-- Shroud itself.
etherBoard:SetAttribute("RevealTransparency", 0.7)
etherBoard:SetAttribute("RevealCanCollide", true) -- solid sign wall, matching every other board
etherBoard.Parent = etherAreaFolder

local ETHER_CLICK_COOLDOWN = {} -- [player] = os.clock() of the next click/auto-click this player is allowed to grant Ether from

-- Shared by an actual click and the Auto Click upgrade's background loop
-- below, so both go through the exact same cooldown table - a player who
-- owns Auto Click and also clicks manually doesn't get to double-dip past
-- their own Click Speed cooldown.
local function attemptEtherCollect(player: Player)
	if not UpgradeTreeHandler.isEtherUnlocked(player) then
		return
	end

	local now = os.clock()
	local nextAllowed = ETHER_CLICK_COOLDOWN[player]
	if nextAllowed and now < nextAllowed then
		return
	end

	local newAmount = EtherHandler.collect(player)
	if newAmount then
		etherUpdatedEvent:FireClient(player, newAmount)
	end

	ETHER_CLICK_COOLDOWN[player] = now + EtherClickSpeedHandler.getCooldownSeconds(player)
end

etherClickDetector.MouseClick:Connect(attemptEtherCollect)

Players.PlayerRemoving:Connect(function(player)
	ETHER_CLICK_COOLDOWN[player] = nil
end)

-- "Auto Click" (EtherAutoClickHandler): a one-time upgrade that, once
-- bought, collects Ether for that player automatically - no more clicking
-- the Shroud - per direct request ("a 1 time upgrade that gives you auto
-- click on the ether"). Checked far more often than any player's own
-- cooldown could realistically be (0.25s) so it fires close to on-time
-- the moment each player's own cooldown clears; `attemptEtherCollect`
-- itself is what actually throttles it, same as a real click would.
local ETHER_AUTO_CLICK_CHECK_INTERVAL = 0.25

task.spawn(function()
	while true do
		task.wait(ETHER_AUTO_CLICK_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			if EtherAutoClickHandler.isUnlocked(player) then
				attemptEtherCollect(player)
			end
		end
	end
end)

-- ===========================================================================
-- Ether Island: a further island bridged straight out along +X from
-- SecondIsland's own edge (continuing the same direction the Upgrade Tree
-- chain and Ether Shroud already extend in), gated behind an Ether
-- threshold instead of Mana/Rebirths/Level - per direct request ("add a
-- bridge to another island that is locked until you have what you think
-- is good to progress in terms of ether"). Same rope-bridge look and
-- locked-gate mechanic as SecondIsland's own bridge (EtherIslandHandler
-- mirrors SecondIslandHandler exactly, just Ether-only), just running
-- along X instead of Z since it leaves from SecondIsland's +X edge rather
-- than the starting island's own +Z edge. Nothing built on the island
-- itself yet beyond grass and decor - purely the gate/bridge/island for
-- now, ready for whatever goes on it next.
local ETHER_ISLAND_SIZE = ISLAND_SIZE

for _, name in { "EtherIsland", "EtherIslandBridge", "EtherIslandGate", "EtherIslandDecor" } do
	local existingPart = Workspace:FindFirstChild(name)
	if existingPart then
		existingPart:Destroy()
	end
end

local secondIslandEdgeX = secondIslandCenterX + SECOND_ISLAND_SIZE / 2
local etherIslandCenterX = secondIslandEdgeX + BRIDGE_LENGTH + ETHER_ISLAND_SIZE / 2
local etherIslandCenterZ = secondIslandCenterZ

local etherIsland = Instance.new("Part")
etherIsland.Name = "EtherIsland"
etherIsland.Anchored = true
etherIsland.CanCollide = true
etherIsland.Material = Enum.Material.Grass
etherIsland.Color = Color3.fromRGB(90, 170, 60)
etherIsland.Size = Vector3.new(ETHER_ISLAND_SIZE, ISLAND_THICKNESS, ETHER_ISLAND_SIZE)
etherIsland.CFrame = CFrame.new(etherIslandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, etherIslandCenterZ)
etherIsland.Parent = Workspace

-- Same rope-bridge look as IslandBridge/LeaderboardBridge, just running
-- along X (deck's long side is X here, not Z) since this bridge leaves
-- from SecondIsland's +X edge instead of a +Z/-Z edge.
local etherIslandBridgeFolder = Instance.new("Folder")
etherIslandBridgeFolder.Name = "EtherIslandBridge"
etherIslandBridgeFolder.Parent = Workspace

local etherBridgeCenterX = secondIslandEdgeX + BRIDGE_LENGTH / 2

local etherDeck = Instance.new("Part")
etherDeck.Name = "BridgeDeck"
etherDeck.Anchored = true
etherDeck.CanCollide = true
etherDeck.Material = Enum.Material.WoodPlanks
etherDeck.Color = Color3.fromRGB(150, 110, 70)
etherDeck.Size = Vector3.new(BRIDGE_LENGTH, BRIDGE_THICKNESS, BRIDGE_WIDTH)
etherDeck.CFrame = CFrame.new(etherBridgeCenterX, ISLAND_TOP_Y - BRIDGE_THICKNESS / 2, etherIslandCenterZ)
etherDeck.Parent = etherIslandBridgeFolder

local function makeEtherBridgeRail(zOffset: number)
	local rail = Instance.new("Part")
	rail.Name = "BridgeRail"
	rail.Anchored = true
	rail.CanCollide = false
	rail.Material = Enum.Material.Wood
	rail.Color = Color3.fromRGB(110, 80, 50)
	rail.Shape = Enum.PartType.Cylinder
	rail.Size = Vector3.new(BRIDGE_LENGTH, 0.6, 0.6) -- Cylinder's round axis is local X, which already points along world X here - no extra rotation needed, unlike the Z-oriented bridges
	rail.CFrame = CFrame.new(etherBridgeCenterX, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT, etherIslandCenterZ + zOffset)
	rail.Parent = etherIslandBridgeFolder
end
makeEtherBridgeRail(BRIDGE_WIDTH / 2)
makeEtherBridgeRail(-BRIDGE_WIDTH / 2)

for postX = 0, BRIDGE_LENGTH, BRIDGE_POST_SPACING do
	for _, zOffset in { BRIDGE_WIDTH / 2, -BRIDGE_WIDTH / 2 } do
		local post = Instance.new("Part")
		post.Name = "BridgePost"
		post.Anchored = true
		post.CanCollide = false
		post.Material = Enum.Material.Wood
		post.Color = Color3.fromRGB(110, 80, 50)
		post.Size = Vector3.new(0.6, BRIDGE_RAIL_HEIGHT, 0.6)
		post.CFrame = CFrame.new(secondIslandEdgeX + postX, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT / 2, etherIslandCenterZ + zOffset)
		post.Parent = etherIslandBridgeFolder
	end
end

-- Purely visual (CanCollide false) - the position-check loop below enforces
-- the lock. Thin along X (blocks the X-direction crossing) instead of Z,
-- matching this bridge's orientation. Its UI is built client-side by
-- EtherIslandGateClient, same reasoning as SecondIslandGateClient.
local etherIslandGate = Instance.new("Part")
etherIslandGate.Name = "EtherIslandGate"
etherIslandGate.Anchored = true
etherIslandGate.CanCollide = false
etherIslandGate.Material = Enum.Material.ForceField
etherIslandGate.Color = Color3.fromRGB(150, 60, 220)
etherIslandGate.Transparency = 0.5
etherIslandGate.Size = Vector3.new(1, 14, BRIDGE_WIDTH)
etherIslandGate.CFrame = CFrame.new(secondIslandEdgeX + 0.5, ISLAND_TOP_Y + 7, etherIslandCenterZ)
etherIslandGate.Parent = Workspace

local etherIslandDecorFolder = Instance.new("Folder")
etherIslandDecorFolder.Name = "EtherIslandDecor"
etherIslandDecorFolder.Parent = Workspace

-- WorldDecor.scatter's nearEdgeSign only skips a gap on a ±Z edge (every
-- other island's bridge approaches along Z) - this bridge approaches along
-- X instead, so there's no X-edge gap to skip; the ring is still a
-- reasonable decorative approximation (decor pieces are all CanCollide
-- false, so an uninterrupted row near the entrance is a cosmetic
-- imperfection at worst, not a blocked path). Plain green theme (no
-- `useWizardTheme`) - only SecondIsland was asked for the purple reskin.
WorldDecor.scatter(etherIslandDecorFolder, etherIslandCenterX, etherIslandCenterZ, ETHER_ISLAND_SIZE, -1, ISLAND_TOP_Y, BRIDGE_WIDTH)

-- Enforces the lock: a player who hasn't pressed the gate's Unlock button
-- yet (EtherIslandHandler.unlock, via EtherIslandGateClient) gets pushed
-- back onto SecondIsland the moment they step onto the bridge. Same
-- poll-loop pattern as SecondIsland's own gate check, just checking X
-- instead of Z since this bridge runs the other axis. Checks the FULL
-- island width (not just the bridge's own width) for the same reason
-- SecondIsland's own check does - a bridge-width-only check stops
-- matching, and so stops enforcing, the moment someone gets far enough
-- onto the much wider island itself.
local ETHER_GATE_CHECK_INTERVAL = 0.25
local ETHER_GATE_X = secondIslandEdgeX + 1 -- just onto the bridge past SecondIsland's edge

task.spawn(function()
	while true do
		task.wait(ETHER_GATE_CHECK_INTERVAL)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if
				rootPart
				and rootPart.Position.X >= ETHER_GATE_X
				and math.abs(rootPart.Position.Z - etherIslandCenterZ) <= ETHER_ISLAND_SIZE / 2
			then
				local data = PlayerData.get(player)
				if data and not data.etherIslandUnlocked then
					rootPart.CFrame = CFrame.new(ETHER_GATE_X - 5, ISLAND_TOP_Y + 3, etherIslandCenterZ)
				end
			end
		end
	end
end)

-- ===========================================================================
-- Ley Shard Mat: the first thing actually built on EtherIsland, and Card 1
-- of a planned 3-card wizard-material progression - per direct request
-- Wrapped in its own `do...end` block (unlike every other section in this
-- file) purely so its ~20 top-level locals go out of scope once it ends,
-- freeing their registers for reuse - this whole file is one single Luau
-- chunk, and adding this section on top of everything already declared
-- pushed it past the compiler's 200-local-register ceiling ("Out of local
-- registers... exceeded limit 200," caught with the real Luau compiler).
-- Nothing declared inside is referenced by name anywhere else in this
-- file, so scoping it away like this costs nothing.
do
-- ("New material x 80, 116 lets do another card and I want to build a 3
-- card system. Lets do the first card first"), placed at the exact world
-- coordinates given. A totally different collection interaction from every
-- earlier resource: click the mat to toggle levitating above it, and while
-- levitating you're paid Ley Shard automatically on a timer (starts at
-- 1.1s, LeyShardSpeedHandler's own upgrade shortens it) instead of
-- walking over nodes or clicking a shroud repeatedly - per direct request
-- ("you go to the mat and you click and you start levatating and you get
-- the resource every 1.1 second"). Reachable only past EtherIsland's own
-- gate, so - like the island's grass/decor themselves - this doesn't need
-- the SecondIsland/Fantasy-Ruin style per-player hide/reveal treatment;
-- it's solid and visible from the moment the island exists, same as
-- EtherIsland's own terrain. `etherIslandUnlocked` is still checked
-- directly in every handler function below, same defense-in-depth
-- reasoning as every other gated system in this game.
local LEY_SHARD_COLOR = Color3.fromRGB(90, 220, 190) -- a teal "ley energy" glow, distinct from Mana/Dust/Ether/Rebirths' own palette
local leyShardMatX = 80
local leyShardMatZ = 116
local LEY_SHARD_HOVER_HEIGHT = 6 -- studs above the mat a levitating player floats at

-- Everything purely about building the Instances lives in its own nested
-- `do...end` (only the two ClickDetectors survive it, pre-declared below
-- and assigned without `local` inside) - none of the Part/Gui
-- locals below are ever needed again once built, so scoping them away
-- frees their registers too, on top of the outer block's own savings.
-- (The board itself is built separately below, in the same block as the
-- Convert/Astral Shard boards - see that section for why.)
local leyShardMatClickDetector, leyShardCrystalClickDetector
do
	local existingLeyShardMat = Workspace:FindFirstChild("LeyShardMat")
	if existingLeyShardMat then
		existingLeyShardMat:Destroy()
	end

	local leyShardMat = Instance.new("Part")
	leyShardMat.Name = "LeyShardMat"
	leyShardMat.Anchored = true
	leyShardMat.CanCollide = true
	leyShardMat.Material = Enum.Material.Neon
	leyShardMat.Color = LEY_SHARD_COLOR
	leyShardMat.Shape = Enum.PartType.Cylinder
	leyShardMat.Size = Vector3.new(0.6, 10, 10) -- Cylinder's round axis is local X; rotated below to lie flat
	leyShardMat.CFrame = CFrame.new(leyShardMatX, ISLAND_TOP_Y + 0.3, leyShardMatZ) * CFrame.Angles(0, 0, math.rad(90))
	leyShardMat.Parent = Workspace

	leyShardMatClickDetector = Instance.new("ClickDetector")
	leyShardMatClickDetector.MaxActivationDistance = 15
	leyShardMatClickDetector.Parent = leyShardMat

	-- A floating crystal above the mat, same idea as the Ether Shroud's own
	-- clickable core - a flat pad right under your own feet is awkward to
	-- actually click (your cursor has to aim straight down at the ground
	-- you're standing on), so this gives an obvious, easy-to-click target
	-- at a natural eye-level height instead. Both this and the mat itself
	-- carry a ClickDetector wired to the same toggle, so either works.
	local leyShardCrystal = Instance.new("Part")
	leyShardCrystal.Name = "LeyShardCrystal"
	leyShardCrystal.Shape = Enum.PartType.Ball
	leyShardCrystal.Anchored = true
	leyShardCrystal.CanCollide = false
	leyShardCrystal.Material = Enum.Material.Neon
	leyShardCrystal.Color = LEY_SHARD_COLOR
	leyShardCrystal.Size = Vector3.new(3, 3, 3)
	leyShardCrystal.CFrame = CFrame.new(leyShardMatX, ISLAND_TOP_Y + 5, leyShardMatZ)
	leyShardCrystal.Parent = Workspace

	leyShardCrystalClickDetector = Instance.new("ClickDetector")
	leyShardCrystalClickDetector.MaxActivationDistance = 25
	leyShardCrystalClickDetector.Parent = leyShardCrystal

	-- Static text, not per-player state - the mat is a single shared Part,
	-- so there's no clean way to reflect "you're currently levitating" here
	-- for one specific player without it also being wrong for everyone
	-- else looking at the same label. Attached to the crystal (not the
	-- mat) so it reads at eye level, same placement as the Ether Shroud's
	-- own label.
	local leyShardMatLabelGui = Instance.new("BillboardGui")
	leyShardMatLabelGui.Name = "LeyShardMatLabel"
	leyShardMatLabelGui.Size = UDim2.new(0, 160, 0, 36)
	leyShardMatLabelGui.StudsOffset = Vector3.new(0, 3, 0)
	leyShardMatLabelGui.MaxDistance = 25
	leyShardMatLabelGui.AlwaysOnTop = true
	leyShardMatLabelGui.Adornee = leyShardCrystal
	leyShardMatLabelGui.Parent = leyShardCrystal

	local leyShardMatLabelText = Instance.new("TextLabel")
	leyShardMatLabelText.Size = UDim2.new(1, 0, 1, 0)
	leyShardMatLabelText.BackgroundTransparency = 1
	leyShardMatLabelText.Font = Enum.Font.GothamBold
	leyShardMatLabelText.TextScaled = true
	leyShardMatLabelText.TextColor3 = LEY_SHARD_COLOR
	leyShardMatLabelText.TextStrokeTransparency = 0.2
	leyShardMatLabelText.Text = "Click to Levitate\n(click again to stop)"
	leyShardMatLabelText.Parent = leyShardMatLabelGui
end

-- [player] = { nextCollectAt = os.clock() timestamp } while levitating;
-- absent entirely while grounded.
local LEY_SHARD_LEVITATING = {}

local function stopLevitating(player: Player)
	if not LEY_SHARD_LEVITATING[player] then
		return
	end
	LEY_SHARD_LEVITATING[player] = nil

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if rootPart then
		local existingForce = rootPart:FindFirstChild("LeyShardLevitation")
		if existingForce then
			existingForce:Destroy()
		end
	end
	if humanoid then
		humanoid.PlatformStand = false
	end
end

local function startLevitating(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.etherIslandUnlocked or LEY_SHARD_LEVITATING[player] then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return
	end

	humanoid.PlatformStand = true -- limp floating pose, and stops WalkSpeed fighting the hold below

	local hold = Instance.new("BodyPosition")
	hold.Name = "LeyShardLevitation"
	hold.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	hold.P = 3000
	hold.Position = Vector3.new(leyShardMatX, ISLAND_TOP_Y + LEY_SHARD_HOVER_HEIGHT, leyShardMatZ)
	hold.Parent = rootPart

	LEY_SHARD_LEVITATING[player] = { nextCollectAt = os.clock() + LeyShardSpeedHandler.getIntervalSeconds(player) }
end

local function toggleLeyShardLevitation(player: Player)
	if LEY_SHARD_LEVITATING[player] then
		stopLevitating(player)
	else
		startLevitating(player)
	end
end

leyShardMatClickDetector.MouseClick:Connect(toggleLeyShardLevitation)
leyShardCrystalClickDetector.MouseClick:Connect(toggleLeyShardLevitation)

Players.PlayerRemoving:Connect(function(player)
	LEY_SHARD_LEVITATING[player] = nil
end)

-- Dying/respawning while levitating (fall damage is off up here, but a
-- future hazard or /kill shouldn't leave someone banking Ley Shard forever
-- as a ragdoll) clears the state outright - the old BodyPosition/character
-- are already gone by the time a new one spawns, so there's nothing left
-- to clean up on the Instance side, just the tracking table.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		LEY_SHARD_LEVITATING[player] = nil
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			LEY_SHARD_LEVITATING[player] = nil
		end)
	end)
end)

-- Checked well more often than the fastest possible payout interval
-- (0.3s) so ticks land close to on-time for every levitating player.
local LEY_SHARD_CHECK_INTERVAL = 0.1

task.spawn(function()
	while true do
		task.wait(LEY_SHARD_CHECK_INTERVAL)
		local now = os.clock()
		for player, state in LEY_SHARD_LEVITATING do
			if now >= state.nextCollectAt then
				local newAmount = LeyShardHandler.collect(player)
				if newAmount then
					leyShardUpdatedEvent:FireClient(player, newAmount)
				end
				state.nextCollectAt = now + LeyShardSpeedHandler.getIntervalSeconds(player)
			end
		end
	end
end)
end

-- ===========================================================================
-- The 3-board row (LeyShardUpgradeBoard, LeyShardConversionBoard,
-- AstralShardUpgradeBoard), all built together here now that their
-- placement no longer derives from the mat's own position. Axis-aligned
-- along X at a fixed Z now, replacing the previous diagonal CFrame.lookAt
-- placement entirely - per direct request with an exact start/end span
-- ("Still off the map. Start the group of 3 cards at x80 z100 then it
-- ends at x155 z100"), after two earlier diagonal-placement attempts
-- still weren't landing right; a plain straight line along one axis is
-- far less error-prone to reason about correctly than an arbitrary
-- CFrame.lookAt angle. Astral Shard (Card 2) has NO collection mechanic
-- of its own - "there isnt a button or anything to get more of this
-- material" - the only way to get it is spending Ley Shard on the
-- Conversion board (AstralShardConversionHandler), 5,000 Ley Shard per 1
-- Astral Shard. Card 2's own board is a placeholder shell for now, per
-- direct request ("It should be the material x card with three upgrades
-- but dont put them in yet I just want to see the card") - 3 empty
-- "Coming Soon" slots, no real upgrade logic wired up yet.
-- The 3 boards' ORIGINAL combined width (34+20+34 plus two 6-stud gaps =
-- 100 studs) is wider than the given 75-stud span (80 to 155) could fit
-- even with zero gap (34+20+34 = 88 alone) - so all 3 are scaled down
-- proportionally (my own call, not specified) to 26/15/26 with a 4-stud
-- gap each, summing to exactly 75: 80 + 26 + 4 + 15 + 4 + 26 = 155.
-- Faces toward the middle of the island (+Z, "Back" in Roblox's NormalId
-- naming - the row sits at Z 100, the island's own center is at Z 150) -
-- still the original design intent from a few requests back ("facing
-- towards the miiddle of the 3rd island"), just realized here with a
-- plain identity orientation instead of CFrame.lookAt, since the row is a
-- straight line along X now rather than at an angle.
-- In its own `do...end` block, same register-budget reasoning as the Ley
-- Shard section above, with an inner nested `do...end` around just the 3
-- Parts' own construction locals for the same reason.
do
	local ROW_Z = 100
	local ROW_START_X = 80 -- left edge of the whole row
	local BOARD_GAP = 4
	local LEY_SHARD_WIDTH = 26
	local CONVERSION_WIDTH = 15
	local ASTRAL_SHARD_WIDTH = 26

	local leyShardBoardCFrame = CFrame.new(ROW_START_X + LEY_SHARD_WIDTH / 2, ISLAND_TOP_Y + 9, ROW_Z)
	local conversionBoardX = ROW_START_X + LEY_SHARD_WIDTH + BOARD_GAP
	local conversionBoardCFrame = CFrame.new(conversionBoardX + CONVERSION_WIDTH / 2, ISLAND_TOP_Y + 9, ROW_Z)
	local astralShardBoardX = conversionBoardX + CONVERSION_WIDTH + BOARD_GAP
	local astralShardBoardCFrame = CFrame.new(astralShardBoardX + ASTRAL_SHARD_WIDTH / 2, ISLAND_TOP_Y + 9, ROW_Z)

	do
		local existingLeyShardBoard = Workspace:FindFirstChild("LeyShardUpgradeBoard")
		if existingLeyShardBoard then
			existingLeyShardBoard:Destroy()
		end
		local existingConversionBoard = Workspace:FindFirstChild("LeyShardConversionBoard")
		if existingConversionBoard then
			existingConversionBoard:Destroy()
		end
		local existingAstralShardBoard = Workspace:FindFirstChild("AstralShardUpgradeBoard")
		if existingAstralShardBoard then
			existingAstralShardBoard:Destroy()
		end

		local leyShardBoard = Instance.new("Part")
		leyShardBoard.Name = "LeyShardUpgradeBoard"
		leyShardBoard.Anchored = true
		leyShardBoard.CanCollide = true
		leyShardBoard.Material = Enum.Material.Glass
		leyShardBoard.Color = Color3.fromRGB(30, 60, 55)
		leyShardBoard.Transparency = 0.7 -- clear glass, matching every other board
		leyShardBoard.Size = Vector3.new(LEY_SHARD_WIDTH, 18, 1)
		leyShardBoard.CFrame = leyShardBoardCFrame
		leyShardBoard.Parent = Workspace

		local conversionBoard = Instance.new("Part")
		conversionBoard.Name = "LeyShardConversionBoard"
		conversionBoard.Anchored = true
		conversionBoard.CanCollide = true
		conversionBoard.Material = Enum.Material.Glass
		conversionBoard.Color = Color3.fromRGB(30, 60, 55)
		conversionBoard.Transparency = 0.7
		conversionBoard.Size = Vector3.new(CONVERSION_WIDTH, 18, 1)
		conversionBoard.CFrame = conversionBoardCFrame
		conversionBoard.Parent = Workspace

		local astralShardBoard = Instance.new("Part")
		astralShardBoard.Name = "AstralShardUpgradeBoard"
		astralShardBoard.Anchored = true
		astralShardBoard.CanCollide = true
		astralShardBoard.Material = Enum.Material.Glass
		astralShardBoard.Color = Color3.fromRGB(40, 30, 65)
		astralShardBoard.Transparency = 0.7
		astralShardBoard.Size = Vector3.new(ASTRAL_SHARD_WIDTH, 18, 1)
		astralShardBoard.CFrame = astralShardBoardCFrame
		astralShardBoard.Parent = Workspace
	end

	-- Clearing decor near all 3 boards' new positions - per direct request
	-- ("please remove any bushes if eneded"/"you will probably have to get
	-- rid of these trees"). Widened from 18 to 30 studs - trees were still
	-- showing up between/around the boards at the smaller radius, since a
	-- tree sitting in the GAP between two board centers can easily be
	-- farther than half a board's own width away from either center. Same
	-- "destroy any decor part within a radius" precedent as
	-- RuneAltarBoard's own clear-radius pass.
	local BOARD_DECOR_CLEAR_RADIUS = 30
	local etherIslandDecorFolder = Workspace:FindFirstChild("EtherIslandDecor")
	if etherIslandDecorFolder then
		for _, decorPart in etherIslandDecorFolder:GetChildren() do
			if decorPart:IsA("BasePart") then
				local nearLey = (decorPart.Position - leyShardBoardCFrame.Position).Magnitude <= BOARD_DECOR_CLEAR_RADIUS
				local nearConversion = (decorPart.Position - conversionBoardCFrame.Position).Magnitude
					<= BOARD_DECOR_CLEAR_RADIUS
				local nearAstral = (decorPart.Position - astralShardBoardCFrame.Position).Magnitude
					<= BOARD_DECOR_CLEAR_RADIUS
				if nearLey or nearConversion or nearAstral then
					decorPart:Destroy()
				end
			end
		end
	end
end

-- ===========================================================================
-- Leaderboard island: a third island, straight out along -Z (the opposite
-- direction from SecondIsland, and the side that reads as "to the left" of
-- the Mana Upgrades board when facing it - the kiosk row itself grows in
-- +Z). Same bridge look as SecondIsland's, minus the gate - this one is
-- never locked. Holds 4 plain sign boards - Playtime, Robux Spent, Total
-- Mana, Runes Opened - each a top-5 list pulled from LeaderboardHandler.
local LEADERBOARD_ISLAND_SIZE = 80
local LEADERBOARD_BOARD_WIDTH = 16
local LEADERBOARD_BOARD_GAP = 4

for _, name in { "LeaderboardIsland", "LeaderboardBridge", "LeaderboardDecor" } do
	local existingPart = Workspace:FindFirstChild(name)
	if existingPart then
		existingPart:Destroy()
	end
end

local islandWestEdgeZ = islandCenterZ - ISLAND_SIZE / 2
local leaderboardIslandCenterZ = islandWestEdgeZ - BRIDGE_LENGTH - LEADERBOARD_ISLAND_SIZE / 2
local leaderboardIslandCenterX = islandCenterX

local leaderboardIsland = Instance.new("Part")
leaderboardIsland.Name = "LeaderboardIsland"
leaderboardIsland.Anchored = true
leaderboardIsland.CanCollide = true
leaderboardIsland.Material = Enum.Material.Grass
leaderboardIsland.Color = Color3.fromRGB(90, 170, 60)
leaderboardIsland.Size = Vector3.new(LEADERBOARD_ISLAND_SIZE, ISLAND_THICKNESS, LEADERBOARD_ISLAND_SIZE)
leaderboardIsland.CFrame = CFrame.new(leaderboardIslandCenterX, ISLAND_TOP_Y - ISLAND_THICKNESS / 2, leaderboardIslandCenterZ)
leaderboardIsland.Parent = Workspace

-- Same rope-bridge look as SecondIsland's (deck + rails + posts), just never
-- gated - reusing the same BRIDGE_* constants for a consistent look.
local leaderboardBridgeFolder = Instance.new("Folder")
leaderboardBridgeFolder.Name = "LeaderboardBridge"
leaderboardBridgeFolder.Parent = Workspace

local leaderboardBridgeCenterZ = islandWestEdgeZ - BRIDGE_LENGTH / 2

local leaderboardDeck = Instance.new("Part")
leaderboardDeck.Name = "BridgeDeck"
leaderboardDeck.Anchored = true
leaderboardDeck.CanCollide = true
leaderboardDeck.Material = Enum.Material.WoodPlanks
leaderboardDeck.Color = Color3.fromRGB(150, 110, 70)
leaderboardDeck.Size = Vector3.new(BRIDGE_WIDTH, BRIDGE_THICKNESS, BRIDGE_LENGTH)
leaderboardDeck.CFrame = CFrame.new(leaderboardIslandCenterX, ISLAND_TOP_Y - BRIDGE_THICKNESS / 2, leaderboardBridgeCenterZ)
leaderboardDeck.Parent = leaderboardBridgeFolder

local function makeLeaderboardBridgeRail(xOffset: number)
	local rail = Instance.new("Part")
	rail.Name = "BridgeRail"
	rail.Anchored = true
	rail.CanCollide = false
	rail.Material = Enum.Material.Wood
	rail.Color = Color3.fromRGB(110, 80, 50)
	rail.Shape = Enum.PartType.Cylinder
	rail.Size = Vector3.new(BRIDGE_LENGTH, 0.6, 0.6)
	rail.CFrame = CFrame.new(leaderboardIslandCenterX + xOffset, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT, leaderboardBridgeCenterZ)
		* CFrame.Angles(0, math.rad(90), 0)
	rail.Parent = leaderboardBridgeFolder
end
makeLeaderboardBridgeRail(BRIDGE_WIDTH / 2)
makeLeaderboardBridgeRail(-BRIDGE_WIDTH / 2)

for postOffsetZ = 0, BRIDGE_LENGTH, BRIDGE_POST_SPACING do
	for _, xOffset in { BRIDGE_WIDTH / 2, -BRIDGE_WIDTH / 2 } do
		local post = Instance.new("Part")
		post.Name = "BridgePost"
		post.Anchored = true
		post.CanCollide = false
		post.Material = Enum.Material.Wood
		post.Color = Color3.fromRGB(110, 80, 50)
		post.Size = Vector3.new(0.6, BRIDGE_RAIL_HEIGHT, 0.6)
		post.CFrame = CFrame.new(leaderboardIslandCenterX + xOffset, ISLAND_TOP_Y + BRIDGE_RAIL_HEIGHT / 2, islandWestEdgeZ - postOffsetZ)
		post.Parent = leaderboardBridgeFolder
	end
end

-- 4 boards in a row set well back from the island's near edge (the side
-- facing the bridge/starting island) - not just past the entrance - thin
-- along Z so their wide face, not their thin edge, points back at a player
-- crossing the bridge (coming from +Z), same Glass-card look as the main
-- kiosks. LeaderboardBoardClient finds each by name and builds its
-- SurfaceGui UI.
local leaderboardBoardZ = leaderboardIslandCenterZ + LEADERBOARD_ISLAND_SIZE / 2 - 22

local function makeLeaderboardBoard(name: string, xOffset: number)
	local boardPart = Instance.new("Part")
	boardPart.Name = name
	boardPart.Anchored = true
	boardPart.CanCollide = true
	boardPart.Material = Enum.Material.Glass
	boardPart.Color = Color3.fromRGB(45, 45, 60)
	boardPart.Transparency = 0.7
	boardPart.Size = Vector3.new(LEADERBOARD_BOARD_WIDTH, 14, 1)
	boardPart.CFrame = CFrame.new(leaderboardIslandCenterX + xOffset, ISLAND_TOP_Y + 7, leaderboardBoardZ)
	boardPart.Parent = kiosksFolder
	return boardPart
end

local LEADERBOARD_BOARD_NAMES = {
	"LeaderboardPlaytimeBoard",
	"LeaderboardRobuxBoard",
	"LeaderboardManaBoard",
	"LeaderboardRunesBoard",
}

local totalBoardsWidth = (#LEADERBOARD_BOARD_NAMES * LEADERBOARD_BOARD_WIDTH)
	+ ((#LEADERBOARD_BOARD_NAMES - 1) * LEADERBOARD_BOARD_GAP)
local leaderboardBoardStartX = -totalBoardsWidth / 2 + LEADERBOARD_BOARD_WIDTH / 2

for index, name in LEADERBOARD_BOARD_NAMES do
	makeLeaderboardBoard(name, leaderboardBoardStartX + (index - 1) * (LEADERBOARD_BOARD_WIDTH + LEADERBOARD_BOARD_GAP))
end

-- Same tree/bush/flower ring as SecondIsland, around this island's edge too.
local leaderboardDecorFolder = Instance.new("Folder")
leaderboardDecorFolder.Name = "LeaderboardDecor"
leaderboardDecorFolder.Parent = Workspace

-- LeaderboardIsland's bridge approaches from +Z, so that's the edge to
-- skip. Plain green theme, same as EtherIsland.
WorldDecor.scatter(leaderboardDecorFolder, leaderboardIslandCenterX, leaderboardIslandCenterZ, LEADERBOARD_ISLAND_SIZE, 1, ISLAND_TOP_Y, BRIDGE_WIDTH)
