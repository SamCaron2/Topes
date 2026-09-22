-- Renders the info sign for every Upgrade Tree tile (1-9) - styled like
-- the reference upgrade cards (colored background, title, cost) but
-- painted flat onto each tile's own Top face with a SurfaceGui, per direct
-- request ("no 3D dynamic text just stuck to the ground like a sign
-- laying down") - NOT a BillboardGui, which would float above the tile
-- and always turn to face the camera. Signs only exist at all once the
-- player has reached Tier 3 (WizardTierHandler) - every tile is always
-- solid ground, but no sign paints onto any of them before that, so it
-- doesn't spoil what's there early. Color follows the exact rule given:
-- red (can't afford yet), yellow (affordable - walk over it to buy),
-- green (bought). The actual purchase happens server-side (WorldBuilder's
-- proximity loop) - this just reflects state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getUpgradeTreeStateFunction = remotes:WaitForChild("GetUpgradeTreeState")
local upgradeTreeTileBoughtEvent = remotes:WaitForChild("UpgradeTreeTileBought")
local arcaneDustUpdatedEvent = remotes:WaitForChild("ArcaneDustUpdated")
local playerWizardTieredEvent = remotes:WaitForChild("PlayerWizardTiered")

local tilesFolder = Workspace:WaitForChild("UpgradeTreeTiles")

local COLOR_LOCKED = Color3.fromRGB(200, 55, 55) -- red - not enough Dust yet
local COLOR_READY = Color3.fromRGB(230, 200, 40) -- yellow - affordable, walk over it
local COLOR_BOUGHT = Color3.fromRGB(70, 190, 60) -- green - bought
local TEXT_STROKE_TRANSPARENCY = 0.3
local TILE_COUNT = 9

local currentDust = 0
local signsBuilt = false
local signs = {} -- [tileId] = { background = Frame, costText = TextLabel, cost = number, bought = boolean }

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

	local canAfford = currentDust >= sign.cost
	sign.background.BackgroundColor3 = canAfford and COLOR_READY or COLOR_LOCKED
	sign.costText.Text = ("Cost: %s Arcane Dust"):format(NumberFormat.format(sign.cost))
end

local function updateAllSigns()
	for tileId in signs do
		updateSign(tileId)
	end
end

-- Painted directly onto each tile's Top face with a SurfaceGui, same
-- flat-sign-on-the-ground approach as every board here uses on its own
-- face - not a BillboardGui, which would float above the tile and always
-- turn to face the camera instead of staying stuck flat to the ground.
local function buildSign(tileId: number, tilePart: BasePart, tileInfo)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = ("UpgradeTreeTile%dSign"):format(tileId)
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

	-- Outlined per direct request ("make the text bubble outlined") - a
	-- clean white border around the whole colored sign.
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
	costText.TextScaled = true
	costText.TextWrapped = true
	costText.TextColor3 = Color3.fromRGB(255, 255, 255)
	costText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	costText.Text = "-"
	costText.Parent = background

	signs[tileId] = {
		background = background,
		costText = costText,
		cost = tileInfo.cost,
		bought = tileInfo.bought,
	}
	updateSign(tileId)
end

local function buildAllSigns(tiles)
	signsBuilt = true
	for tileId = 1, TILE_COUNT do
		local tilePart = tilesFolder:WaitForChild(("UpgradeTreeTile%d"):format(tileId))
		buildSign(tileId, tilePart, tiles[tileId])
	end
end

local function render(state)
	if not state then
		return
	end

	currentDust = state.arcaneDust

	if not state.unlocked then
		return
	end

	if not signsBuilt then
		buildAllSigns(state.tiles)
		return
	end

	for tileId, tileInfo in state.tiles do
		if signs[tileId] then
			signs[tileId].bought = tileInfo.bought
		end
	end
	updateAllSigns()
end

render(getUpgradeTreeStateFunction:InvokeServer())

arcaneDustUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentDust = amount
	updateAllSigns()
end)

upgradeTreeTileBoughtEvent.OnClientEvent:Connect(function(tileId)
	if signs[tileId] then
		signs[tileId].bought = true
		updateSign(tileId)
	end
end)

-- Reaching Tier 3 fires this too (it fires on every Wizard Tier purchase) -
-- re-checking builds every sign immediately, no rejoin needed.
playerWizardTieredEvent.OnClientEvent:Connect(function()
	render(getUpgradeTreeStateFunction:InvokeServer())
end)
