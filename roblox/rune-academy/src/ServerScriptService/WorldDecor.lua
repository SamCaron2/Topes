-- Decorative "island ring" scenery - trees/bushes/flowers scattered around
-- an island's perimeter, or (for SecondIsland) a "purple wizardy nature"
-- theme instead, per direct request. Split out of WorldBuilder.server.lua
-- once that script's own top-level locals crossed Luau's 200-local-
-- register-per-chunk limit ("Out of local registers when trying to
-- allocate index: exceeded limit 200" at compile time, reproduced exactly
-- with `luau-compile -O0`) - every ModuleScript compiles as its own
-- separate chunk with its own fresh register budget, so moving a
-- self-contained piece like this one out is the actual fix, not just a
-- workaround. `groundY`/`bridgeWidth` are passed in rather than hardcoded
-- since they're WorldBuilder's own constants (ISLAND_TOP_Y/BRIDGE_WIDTH).

local WorldDecor = {}

-- ===========================================================================
-- Plain green theme (EtherIsland/LeaderboardIsland). Built from several
-- overlapping/stacked parts per piece instead of one plain shape each, for
-- a fuller, less "primitive" look.
local function makeTree(folder: Folder, x: number, z: number, groundY: number)
	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(90, 60, 35)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(7, 2, 2) -- Cylinder's round axis is local X; rotated below to stand upright
	trunk.CFrame = CFrame.new(x, groundY + 3.5, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = folder

	-- Three overlapping canopy clumps instead of one perfect sphere, for a
	-- fuller, rounder silhouette closer to a real tree.
	local canopyClumps = {
		{ offset = Vector3.new(0, 9, 0), size = 6.5 },
		{ offset = Vector3.new(1.6, 7.5, 1), size = 5 },
		{ offset = Vector3.new(-1.6, 7.5, -1), size = 5 },
	}
	for _, clump in canopyClumps do
		local leaves = Instance.new("Part")
		leaves.Name = "TreeLeaves"
		leaves.Anchored = true
		leaves.CanCollide = false
		leaves.Material = Enum.Material.Grass
		leaves.Color = Color3.fromRGB(45, 130, 55)
		leaves.Shape = Enum.PartType.Ball
		leaves.Size = Vector3.new(clump.size, clump.size, clump.size)
		leaves.CFrame = CFrame.new(x + clump.offset.X, groundY + clump.offset.Y, z + clump.offset.Z)
		leaves.Parent = folder
	end
end

local function makeBush(folder: Folder, x: number, z: number, groundY: number)
	-- Three overlapping bumps (one bigger, two smaller) instead of one flat
	-- squashed ball - bigger overall and reads as an actual bush cluster.
	local bumps = {
		{ offset = Vector3.new(0, 0, 0), size = 4.5 },
		{ offset = Vector3.new(1.4, 0.2, 0.9), size = 3.4 },
		{ offset = Vector3.new(-1.3, 0.1, -1), size = 3.4 },
	}
	for _, bump in bumps do
		local part = Instance.new("Part")
		part.Name = "Bush"
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Grass
		part.Color = Color3.fromRGB(55, 125, 55)
		local height = bump.size * 0.8
		part.Size = Vector3.new(bump.size, height, bump.size)
		part.Shape = Enum.PartType.Ball
		part.CFrame = CFrame.new(x + bump.offset.X, groundY + height / 2, z + bump.offset.Z)
		part.Parent = folder
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 255, 255),
}

-- A thin green stem topped with a colored bloom, instead of a single flat
-- dot, so it actually reads as a flower rather than a pebble.
local function makeFlower(folder: Folder, x: number, z: number, groundY: number)
	local stem = Instance.new("Part")
	stem.Name = "FlowerStem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(60, 140, 60)
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(1.4, 0.25, 0.25)
	stem.CFrame = CFrame.new(x, groundY + 0.7, z) * CFrame.Angles(0, 0, math.rad(90))
	stem.Parent = folder

	local bloom = Instance.new("Part")
	bloom.Name = "FlowerBloom"
	bloom.Anchored = true
	bloom.CanCollide = false
	bloom.Material = Enum.Material.Neon
	bloom.Color = FLOWER_COLORS[math.random(#FLOWER_COLORS)]
	bloom.Shape = Enum.PartType.Ball
	bloom.Size = Vector3.new(1.2, 1.2, 1.2)
	bloom.CFrame = CFrame.new(x, groundY + 1.5, z)
	bloom.Parent = folder
end

-- ===========================================================================
-- SecondIsland's own decor theme: "purple wizardy nature," per direct
-- request ("this island can we do purple wizardy nature theme for
-- decorations make it look good"). Same overlapping-parts-per-piece
-- approach as makeTree/makeBush/makeFlower above (never one flat primitive
-- shape), just with a magical-forest palette and two brand new piece
-- types (crystal clusters, glowing mushrooms) instead of reusing the
-- plain green ones. Used only via SECOND_ISLAND_DECOR_KINDS below -
-- EtherIsland/LeaderboardIsland keep the original green theme.

-- A darker, purple-barked trunk under a glowing violet canopy instead of
-- green leaves - same 3-clump silhouette as makeTree, plus a 4th smaller,
-- brighter magenta clump tucked into the canopy for a bit of sparkle.
local function makeWizardTree(folder: Folder, x: number, z: number, groundY: number)
	local trunk = Instance.new("Part")
	trunk.Name = "WizardTreeTrunk"
	trunk.Anchored = true
	trunk.CanCollide = false
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(58, 42, 68)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(7, 2, 2) -- Cylinder's round axis is local X; rotated below to stand upright
	trunk.CFrame = CFrame.new(x, groundY + 3.5, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Parent = folder

	local canopyClumps = {
		{ offset = Vector3.new(0, 9, 0), size = 6.5, color = Color3.fromRGB(140, 70, 210) },
		{ offset = Vector3.new(1.6, 7.5, 1), size = 5, color = Color3.fromRGB(140, 70, 210) },
		{ offset = Vector3.new(-1.6, 7.5, -1), size = 5, color = Color3.fromRGB(140, 70, 210) },
		{ offset = Vector3.new(0.5, 10.5, -0.8), size = 3, color = Color3.fromRGB(210, 110, 255) },
	}
	for _, clump in canopyClumps do
		local leaves = Instance.new("Part")
		leaves.Name = "WizardTreeLeaves"
		leaves.Anchored = true
		leaves.CanCollide = false
		leaves.Material = Enum.Material.Neon
		leaves.Color = clump.color
		leaves.Shape = Enum.PartType.Ball
		leaves.Size = Vector3.new(clump.size, clump.size, clump.size)
		leaves.CFrame = CFrame.new(x + clump.offset.X, groundY + clump.offset.Y, z + clump.offset.Z)
		leaves.Parent = folder
	end
end

-- A jagged cluster of 4 translucent purple shards (elongated Balls, not
-- Wedges - reads as crystal spikes without needing exact wedge-orientation
-- math), each a different height/tilt/shade so the cluster looks grown,
-- not stamped out identically.
local CRYSTAL_SHARD_COLORS = {
	Color3.fromRGB(200, 160, 255),
	Color3.fromRGB(160, 100, 230),
	Color3.fromRGB(120, 70, 200),
}

local function makeCrystalCluster(folder: Folder, x: number, z: number, groundY: number)
	local shards = {
		{ offset = Vector3.new(0, 0, 0), radius = 1.3, height = 6.5, tilt = 0.06 },
		{ offset = Vector3.new(1.1, 0, 0.6), radius = 0.9, height = 4.5, tilt = -0.1 },
		{ offset = Vector3.new(-1, 0, 0.8), radius = 1, height = 5, tilt = 0.12 },
		{ offset = Vector3.new(0.2, 0, -1.2), radius = 0.7, height = 3.5, tilt = -0.08 },
	}
	for i, shard in shards do
		local part = Instance.new("Part")
		part.Name = "CrystalShard"
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Glass
		part.Color = CRYSTAL_SHARD_COLORS[(i - 1) % #CRYSTAL_SHARD_COLORS + 1]
		part.Transparency = 0.15
		part.Reflectance = 0.15
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(shard.radius * 2, shard.height, shard.radius * 2)
		part.CFrame = CFrame.new(x + shard.offset.X, groundY + shard.height / 2 - 0.5, z + shard.offset.Z)
			* CFrame.Angles(shard.tilt, i * 1.3, shard.tilt)
		part.Parent = folder
	end
end

-- A pale stem under a glowing magenta cap with a few small white spots -
-- classic enchanted-forest mushroom, with its own soft PointLight so the
-- cap actually lights up its surroundings a little at dusk/night.
local function makeGlowMushroom(folder: Folder, x: number, z: number, groundY: number)
	local stem = Instance.new("Part")
	stem.Name = "MushroomStem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.SmoothPlastic
	stem.Color = Color3.fromRGB(225, 215, 195)
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(2.6, 0.9, 0.9)
	stem.CFrame = CFrame.new(x, groundY + 1.3, z) * CFrame.Angles(0, 0, math.rad(90))
	stem.Parent = folder

	local cap = Instance.new("Part")
	cap.Name = "MushroomCap"
	cap.Anchored = true
	cap.CanCollide = false
	cap.Material = Enum.Material.Neon
	cap.Color = Color3.fromRGB(220, 90, 220)
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(2.8, 1.5, 2.8)
	cap.CFrame = CFrame.new(x, groundY + 2.6, z)
	cap.Parent = folder

	local capLight = Instance.new("PointLight")
	capLight.Color = cap.Color
	capLight.Range = 8
	capLight.Brightness = 1.2
	capLight.Parent = cap

	local spotOffsets = { Vector3.new(0.8, 0.4, 0.5), Vector3.new(-0.7, 0.5, -0.6), Vector3.new(0.1, 0.6, -0.9) }
	for i, spotOffset in spotOffsets do
		local spot = Instance.new("Part")
		spot.Name = ("MushroomSpot%d"):format(i)
		spot.Anchored = true
		spot.CanCollide = false
		spot.Material = Enum.Material.Neon
		spot.Color = Color3.fromRGB(255, 255, 255)
		spot.Shape = Enum.PartType.Ball
		spot.Size = Vector3.new(0.4, 0.4, 0.4)
		spot.CFrame = CFrame.new(x + spotOffset.X, groundY + 2.6 + spotOffset.Y, z + spotOffset.Z)
		spot.Parent = folder
	end
end

local WIZARD_FLOWER_COLORS = {
	Color3.fromRGB(200, 160, 255),
	Color3.fromRGB(230, 100, 220),
	Color3.fromRGB(140, 80, 220),
	Color3.fromRGB(225, 210, 255),
}

-- Same stem+bloom shape as makeFlower, just a deeper teal-toned stem and
-- blooms drawn only from the purple/lilac side of the palette.
local function makeGlowFlower(folder: Folder, x: number, z: number, groundY: number)
	local stem = Instance.new("Part")
	stem.Name = "GlowFlowerStem"
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Grass
	stem.Color = Color3.fromRGB(40, 90, 70)
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(1.4, 0.25, 0.25)
	stem.CFrame = CFrame.new(x, groundY + 0.7, z) * CFrame.Angles(0, 0, math.rad(90))
	stem.Parent = folder

	local bloom = Instance.new("Part")
	bloom.Name = "GlowFlowerBloom"
	bloom.Anchored = true
	bloom.CanCollide = false
	bloom.Material = Enum.Material.Neon
	bloom.Color = WIZARD_FLOWER_COLORS[math.random(#WIZARD_FLOWER_COLORS)]
	bloom.Shape = Enum.PartType.Ball
	bloom.Size = Vector3.new(1.2, 1.2, 1.2)
	bloom.CFrame = CFrame.new(x, groundY + 1.5, z)
	bloom.Parent = folder
end

local DECOR_INSET = 8
local DECOR_STEP = 12
local DECOR_JITTER = 3
local DECOR_KINDS = { makeTree, makeBush, makeFlower, makeFlower }
local SECOND_ISLAND_DECOR_KINDS = { makeWizardTree, makeCrystalCluster, makeGlowMushroom, makeGlowFlower }

-- Rings one island's perimeter at a fixed inset, cycling through 4 decor
-- kinds (the plain green set, or the purple-wizard set if `useWizardTheme`
-- is true - SecondIsland passes true, EtherIsland/LeaderboardIsland don't).
-- Skips the middle stretch of whichever edge faces the bridge
-- (nearEdgeSign -1 = that edge is at centerZ - half, i.e. SecondIsland,
-- whose bridge approaches from -Z; +1 = centerZ + half, i.e.
-- LeaderboardIsland, whose bridge approaches from +Z) so the entrance
-- stays clear. Each spot gets a small random jitter so the ring reads as
-- staggered/natural instead of a perfectly straight line.
function WorldDecor.scatter(
	folder: Folder,
	centerX: number,
	centerZ: number,
	size: number,
	nearEdgeSign: number,
	groundY: number,
	bridgeWidth: number,
	useWizardTheme: boolean?
)
	local kinds = useWizardTheme and SECOND_ISLAND_DECOR_KINDS or DECOR_KINDS
	local half = size / 2 - DECOR_INSET
	local decorIndex = 0
	local function placeNextDecor(x: number, z: number)
		decorIndex += 1
		local jitterX = (math.random() * 2 - 1) * DECOR_JITTER
		local jitterZ = (math.random() * 2 - 1) * DECOR_JITTER
		kinds[(decorIndex - 1) % #kinds + 1](folder, x + jitterX, z + jitterZ, groundY)
	end

	for offset = -half, half, DECOR_STEP do
		placeNextDecor(centerX + offset, centerZ - nearEdgeSign * half) -- far edge, always a full row
		if math.abs(offset) > bridgeWidth / 2 then -- near edge, minus the bridge's entrance gap
			placeNextDecor(centerX + offset, centerZ + nearEdgeSign * half)
		end
		placeNextDecor(centerX + half, centerZ + offset) -- far X edge
		placeNextDecor(centerX - half, centerZ + offset) -- near X edge
	end
end

return WorldDecor
