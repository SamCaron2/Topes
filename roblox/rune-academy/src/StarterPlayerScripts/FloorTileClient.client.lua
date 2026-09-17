-- Walking onto a part tagged "FloorTile" (WorldBuilder-generated) attempts
-- to buy/level it up. Server re-validates cost/level/lock - this triggers
-- the ask and renders live level/cost/locked state on the tile's label,
-- polling once per ZONE (not per tile) to keep remote calls down.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local TOUCH_DEBOUNCE_SECONDS = 1
local REFRESH_INTERVAL = 1

local LOCKED_COLOR = Color3.fromRGB(90, 90, 90)
local BOOST_COLOR = Color3.fromRGB(90, 200, 110)
local EXPAND_COLOR = Color3.fromRGB(210, 120, 60)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyFloorTileFunction = remotes:WaitForChild("BuyFloorTile")
local getFloorTilesFunction = remotes:WaitForChild("GetFloorTiles")

local function findZone(zoneKey: string)
	for _, zone in GameConfig.Zones do
		if zone.key == zoneKey then
			return zone
		end
	end
	return nil
end

local function findTile(zone, tileKey: string)
	for _, tile in zone.floorTiles do
		if tile.key == tileKey then
			return tile
		end
	end
	return nil
end

local function tileCost(tile, level: number): number
	return tile.baseCost * (tile.costGrowth ^ level)
end

-- Groups tiles by zone so each zone only needs one GetFloorTiles poll,
-- rather than one call per tile.
local tilesByZone = {} -- [zoneKey] = { {part=, tile=}, ... }

for _, part in CollectionService:GetTagged("FloorTile") do
	local zoneKey = part:GetAttribute("ZoneKey")
	local tileKey = part:GetAttribute("TileKey")
	local zone = zoneKey and findZone(zoneKey)
	local tile = zone and findTile(zone, tileKey)
	if zone and tile then
		tilesByZone[zoneKey] = tilesByZone[zoneKey] or {}
		table.insert(tilesByZone[zoneKey], { part = part, tile = tile, zone = zone })
	end
end

local function refreshZone(zoneKey: string, entries)
	local floorTiles = getFloorTilesFunction:InvokeServer(zoneKey)
	if not floorTiles then
		return
	end

	for _, entry in entries do
		local tile = entry.tile
		local level = floorTiles[tile.key] or 0
		local label = entry.part:FindFirstChild("InfoBoard") and entry.part.InfoBoard:FindFirstChild("InfoLabel")
		if not label then
			continue
		end

		local locked = false
		if tile.requiresTile then
			local requiredTile = findTile(entry.zone, tile.requiresTile)
			local requiredLevel = floorTiles[tile.requiresTile] or 0
			locked = not requiredTile or requiredLevel < requiredTile.maxLevel
		end

		if locked then
			local requiredTile = findTile(entry.zone, tile.requiresTile)
			label.Text = ("%s\nLocked: needs %s"):format(tile.displayName, requiredTile and requiredTile.displayName or "?")
			entry.part.Color = LOCKED_COLOR
		elseif tile.type == "expand" then
			entry.part.Color = EXPAND_COLOR
			if level >= tile.maxLevel then
				label.Text = tile.displayName .. "\nUNLOCKED"
			else
				label.Text = ("%s\nCost: %s %s"):format(tile.displayName, NumberFormat.format(tileCost(tile, level)), tile.costCurrency)
			end
		else
			entry.part.Color = BOOST_COLOR
			local currentMultiplier = tile.multiplierPerLevel ^ level
			if level >= tile.maxLevel then
				label.Text = ("%s (%d/%d)\nx%s %s\nMAXED"):format(
					tile.displayName,
					level,
					tile.maxLevel,
					NumberFormat.format(currentMultiplier),
					tile.targetCurrency
				)
			else
				label.Text = ("%s (%d/%d)\nx%s %s\nCost: %s %s"):format(
					tile.displayName,
					level,
					tile.maxLevel,
					NumberFormat.format(currentMultiplier),
					tile.targetCurrency,
					NumberFormat.format(tileCost(tile, level)),
					tile.costCurrency
				)
			end
		end
	end
end

local function startZoneRefreshLoop(zoneKey: string, entries)
	task.spawn(function()
		while true do
			refreshZone(zoneKey, entries)
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

for zoneKey, entries in tilesByZone do
	startZoneRefreshLoop(zoneKey, entries)
end

-- Tiles created after this script's initial scan (replication timing, not
-- a real race in practice, but cheap to handle) still get picked up: new
-- entries append to the same table the zone's loop already reads from.
CollectionService:GetInstanceAddedSignal("FloorTile"):Connect(function(part)
	local zoneKey = part:GetAttribute("ZoneKey")
	local tileKey = part:GetAttribute("TileKey")
	local zone = zoneKey and findZone(zoneKey)
	local tile = zone and findTile(zone, tileKey)
	if not (zone and tile) then
		return
	end

	local isNewZone = tilesByZone[zoneKey] == nil
	tilesByZone[zoneKey] = tilesByZone[zoneKey] or {}
	table.insert(tilesByZone[zoneKey], { part = part, tile = tile, zone = zone })

	if isNewZone then
		startZoneRefreshLoop(zoneKey, tilesByZone[zoneKey])
	end
end)

local lastTriedAt = {} -- [part] = os.clock()

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	rootPart.Touched:Connect(function(hit)
		if not CollectionService:HasTag(hit, "FloorTile") then
			return
		end

		local now = os.clock()
		if lastTriedAt[hit] and now - lastTriedAt[hit] < TOUCH_DEBOUNCE_SECONDS then
			return
		end
		lastTriedAt[hit] = now

		local zoneKey = hit:GetAttribute("ZoneKey")
		local tileKey = hit:GetAttribute("TileKey")
		if zoneKey and tileKey then
			buyFloorTileFunction:InvokeServer(zoneKey, tileKey)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
