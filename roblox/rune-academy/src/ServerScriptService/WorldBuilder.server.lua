-- Procedurally builds every gameplay object (resource nodes, floor tiles)
-- straight from GameConfig.Zones. Adding/renaming a currency or floor tile
-- in config is enough - no manual part-placing in Studio needed for
-- anything gameplay-functional. Runs once each time the server starts;
-- Studio discards everything a Play session creates when you click Stop,
-- so this never accumulates duplicates across sessions.
--
-- Layout here is a plain grid - purely functional, not real level design.
-- Swap in actual terrain/art/building later without touching this file's
-- logic, since it only cares about position math and tagging/attributes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local ZONE_SPACING_STUDS = 300 -- how far apart each zone's grid sits, along X
local NODE_SPACING_STUDS = 10
local TILE_SPACING_STUDS = 8
local TILE_ROW_Z_OFFSET = 20
local KIOSK_SPACING_STUDS = 10
local KIOSK_ROW_Z_OFFSET = -15

local CURRENCY_COLORS = {
	Mana = Color3.fromRGB(150, 100, 240),
	Whispers = Color3.fromRGB(130, 220, 200),
	Copper = Color3.fromRGB(190, 110, 60),
	Pearls = Color3.fromRGB(230, 225, 240),
	Stardust = Color3.fromRGB(90, 180, 235),
}

local function colorForCurrency(currencyKey: string): Color3
	return CURRENCY_COLORS[currencyKey] or Color3.fromRGB(200, 200, 200)
end

local function addLabel(part: BasePart, text: string, yOffset: number, textSize: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 140, 0, 36)
	billboard.StudsOffset = Vector3.new(0, yOffset, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard
end

local function buildNode(parent: Instance, zoneKey: string, currency, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Node_" .. currency.key
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false -- touchable for collection, but never blocks walking
	part.Color = colorForCurrency(currency.key)
	part.Material = Enum.Material.Neon
	part.Parent = parent

	part:SetAttribute("ZoneKey", zoneKey)
	part:SetAttribute("CurrencyKey", currency.key)
	CollectionService:AddTag(part, "ResourceNode")

	addLabel(part, currency.displayName, 3.5, 16)

	return part
end

local function buildFloorTile(parent: Instance, zoneKey: string, tile, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Tile_" .. tile.key
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(6, 1, 6)
	part.Position = position
	part.Anchored = true
	part.Color = Color3.fromRGB(90, 200, 110)
	part.Material = Enum.Material.Neon
	part.Parent = parent

	part:SetAttribute("ZoneKey", zoneKey)
	part:SetAttribute("TileKey", tile.key)
	CollectionService:AddTag(part, "FloorTile")

	addLabel(part, ("%s\nx%.2f %s"):format(tile.displayName, tile.multiplier, tile.targetCurrency), 3, 13)

	return part
end

-- The physical stand an UpgradeKioskClient.client.lua BillboardGui gets
-- mounted onto - one per currency, regardless of collectMode, matching the
-- reference game having a board for every currency (Diamond Upgrades, Sand
-- Upgrades) not just the ones you click/stand on directly.
local function buildKiosk(parent: Instance, zoneKey: string, currency, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "Kiosk_" .. currency.key
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(6, 8, 1)
	part.Position = position
	part.Anchored = true
	part.Color = Color3.fromRGB(40, 34, 60)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent

	part:SetAttribute("ZoneKey", zoneKey)
	part:SetAttribute("CurrencyKey", currency.key)
	CollectionService:AddTag(part, "UpgradeKiosk")

	return part
end

-- One global stand-on altar (Runes aren't zone-specific) - standing on it
-- continuously pulls Runes for as long as Scrolls last, matching the
-- reference game's platform-based pull mechanic rather than a menu button.
local function buildRuneAltar(parent: Instance, position: Vector3)
	local part = Instance.new("Part")
	part.Name = "RuneAltar"
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90) -- lay the cylinder flat so its round face is the standable top
	part.Size = Vector3.new(2, 10, 10)
	part.Position = position
	part.Anchored = true
	part.Color = Color3.fromRGB(80, 60, 140)
	part.Material = Enum.Material.Neon
	part.Parent = parent

	CollectionService:AddTag(part, "RuneAltar")

	return part
end

local worldFolder = Instance.new("Folder")
worldFolder.Name = "GeneratedWorld"
worldFolder.Parent = Workspace

buildRuneAltar(worldFolder, Vector3.new(-15, 1, 0))

for zoneIndex, zone in GameConfig.Zones do
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "Zone_" .. zone.key
	zoneFolder.Parent = worldFolder

	local zoneOriginX = (zoneIndex - 1) * ZONE_SPACING_STUDS

	local nodeIndex = 0
	for _, currency in zone.currencies do
		if currency.collectMode == "click" or currency.collectMode == "stand" then
			local position = Vector3.new(zoneOriginX + nodeIndex * NODE_SPACING_STUDS, 3, 0)
			buildNode(zoneFolder, zone.key, currency, position)
			nodeIndex += 1
		end
	end

	local tileIndex = 0
	for _, tile in zone.floorTiles do
		local position = Vector3.new(zoneOriginX + tileIndex * TILE_SPACING_STUDS, 0.5, TILE_ROW_Z_OFFSET)
		buildFloorTile(zoneFolder, zone.key, tile, position)
		tileIndex += 1
	end

	local kioskIndex = 0
	for _, currency in zone.currencies do
		local position = Vector3.new(zoneOriginX + kioskIndex * KIOSK_SPACING_STUDS, 5, KIOSK_ROW_Z_OFFSET)
		buildKiosk(zoneFolder, zone.key, currency, position)
		kioskIndex += 1
	end
end
