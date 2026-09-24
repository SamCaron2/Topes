-- Renders the info sign for EtherIsland's own Ley Shard floor tiles (5 of
-- them now, each requiring the one before it bought first, same as the
-- SecondIsland tree - a tile's sign only exists once reachable) - exact
-- same styling/behavior as UpgradeTreeClient (colored background, title,
-- cost, painted flat onto the tile's own Top face with a SurfaceGui, not
-- a BillboardGui), just reading LeyShardFloorTileHandler's state (gated
-- on EtherIsland being unlocked, not Wizard Tier 3+) and costed/paid in
-- Ley Shard or Astral Shard instead of Arcane Dust - per direct request
-- ("x107 z134 start a floor tile upgrade. Lets do for 1k ley shards times
-- your ley by 2," then "Now two more floor tiles above that is one for
-- times 2 ley shrouds and 2x astra shrouds," then "Please do a fourth
-- and fith tile... cost 5 million astra shards and that unlocks the
-- third upgrade car[d]... Then the 5th tile... cost 1million ley shards
-- and that will unlock Auto Ley shards"). Color follows the same rule:
-- red (can't afford yet), yellow (affordable - walk over it to buy),
-- green (bought). Each tile's `currency` from the server state says which
-- balance/label to show and compare against, per-tile rather than
-- assuming Ley Shard throughout.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getLeyShardFloorTileStateFunction = remotes:WaitForChild("GetLeyShardFloorTileState")
local leyShardFloorTileBoughtEvent = remotes:WaitForChild("LeyShardFloorTileBought")
local leyShardUpdatedEvent = remotes:WaitForChild("LeyShardUpdated")
local astralShardUpdatedEvent = remotes:WaitForChild("AstralShardUpdated")
local playerEtherIslandUnlockedEvent = remotes:WaitForChild("PlayerEtherIslandUnlocked")

local tilesFolder = Workspace:WaitForChild("LeyShardFloorTiles")

local COLOR_LOCKED = Color3.fromRGB(200, 55, 55) -- red - not enough Ley Shard yet
local COLOR_READY = Color3.fromRGB(230, 200, 40) -- yellow - affordable, walk over it
local COLOR_BOUGHT = Color3.fromRGB(70, 190, 60) -- green - bought
local TEXT_STROKE_TRANSPARENCY = 0.3
local TILE_COUNT = 5

local CURRENCY_LABEL = {
	leyShard = "Ley Shard",
	astralShard = "Astral Shard",
}

local currentLeyShard = 0
local currentAstralShard = 0
local signs = {} -- [tileId] = { background = Frame, costText = TextLabel, cost = number, currency = string, bought = boolean }

local function balanceFor(currency: string): number
	if currency == "astralShard" then
		return currentAstralShard
	end
	return currentLeyShard
end

local function updateSign(tileId: number)
	local sign = signs[tileId]
	if not sign then
		return
	end

	if sign.bought then
		sign.background.BackgroundColor3 = COLOR_BOUGHT
		sign.costText.Text = "Bought!"
		return
	end

	local canAfford = balanceFor(sign.currency) >= sign.cost
	sign.background.BackgroundColor3 = canAfford and COLOR_READY or COLOR_LOCKED
	sign.costText.Text = ("Cost: %s %s"):format(NumberFormat.format(sign.cost), CURRENCY_LABEL[sign.currency] or "Ley Shard")
end

local function updateAllSigns()
	for tileId in signs do
		updateSign(tileId)
	end
end

local function buildSign(tileId: number, tilePart: BasePart, tileInfo)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = ("LeyShardFloorTile%dSign"):format(tileId)
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.Adornee = tilePart
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = tilePart

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = COLOR_LOCKED
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local backgroundOutline = Instance.new("UIStroke")
	backgroundOutline.Thickness = 4
	backgroundOutline.Color = Color3.fromRGB(255, 255, 255)
	backgroundOutline.Parent = background

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, 0, 0.45, 0)
	titleText.Position = UDim2.new(0, 0, 0.08, 0)
	titleText.BackgroundTransparency = 1
	titleText.Font = Enum.Font.GothamBold
	titleText.TextScaled = true
	titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = tileInfo.label
	titleText.Parent = background

	local costText = Instance.new("TextLabel")
	costText.Size = UDim2.new(0.94, 0, 0.35, 0)
	costText.Position = UDim2.new(0.03, 0, 0.58, 0)
	costText.BackgroundTransparency = 1
	costText.Font = Enum.Font.GothamBold
	costText.TextWrapped = true
	costText.TextScaled = true
	costText.TextColor3 = Color3.fromRGB(255, 255, 255)
	costText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	costText.Text = "-"
	costText.Parent = background

	signs[tileId] = {
		background = background,
		costText = costText,
		cost = tileInfo.cost,
		currency = tileInfo.currency,
		bought = tileInfo.bought,
	}
	updateSign(tileId)
end

local function render(state)
	if not state then
		return
	end

	currentLeyShard = state.leyShard
	currentAstralShard = state.astralShard

	if not state.unlocked then
		return
	end

	for tileId = 1, TILE_COUNT do
		local tileInfo = state.tiles[tileId]
		if signs[tileId] then
			signs[tileId].bought = tileInfo.bought
		elseif tileInfo.reachable then
			local tilePart = tilesFolder:WaitForChild(("LeyShardFloorTile%d"):format(tileId))
			buildSign(tileId, tilePart, tileInfo)
		end
	end

	updateAllSigns()
end

render(getLeyShardFloorTileStateFunction:InvokeServer())

leyShardUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentLeyShard = amount
	updateAllSigns()
end)

astralShardUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentAstralShard = amount
	updateAllSigns()
end)

leyShardFloorTileBoughtEvent.OnClientEvent:Connect(function()
	render(getLeyShardFloorTileStateFunction:InvokeServer())
end)

-- Unlocking EtherIsland makes this whole set reachable - re-check
-- immediately, no rejoin needed, same pattern as every other EtherIsland
-- board's own rebuild-on-unlock handling.
playerEtherIslandUnlockedEvent.OnClientEvent:Connect(function()
	render(getLeyShardFloorTileStateFunction:InvokeServer())
end)
