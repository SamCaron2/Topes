-- Renders the floating card above UpgradeTreeTile1 - styled like the
-- reference upgrade cards (colored border/background, title, cost) but
-- for a walk-over tile instead of a Buy button. Only exists at all once
-- the player has reached Tier 3 (WizardTierHandler) - the tile itself is
-- always solid ground, but no card floats above it before that, so it
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

local tile1 = Workspace:WaitForChild("UpgradeTreeTiles"):WaitForChild("UpgradeTreeTile1")

local COLOR_LOCKED = Color3.fromRGB(200, 55, 55) -- red - not enough Dust yet
local COLOR_READY = Color3.fromRGB(230, 200, 40) -- yellow - affordable, walk over it
local COLOR_BOUGHT = Color3.fromRGB(70, 190, 60) -- green - bought
local TEXT_STROKE_TRANSPARENCY = 0.3

local currentDust = 0
local tile1Cost = 0
local tile1Bought = false
local cardBuilt = false

local background, titleText, costText

local function updateCard()
	if not cardBuilt then
		return
	end

	if tile1Bought then
		background.BackgroundColor3 = COLOR_BOUGHT
		costText.Text = "Bought!"
		return
	end

	local canAfford = currentDust >= tile1Cost
	background.BackgroundColor3 = canAfford and COLOR_READY or COLOR_LOCKED
	costText.Text = canAfford and ("Walk over! Cost: %s Dust"):format(NumberFormat.format(tile1Cost))
		or ("Cost: %s Arcane Dust"):format(NumberFormat.format(tile1Cost))
end

local function buildCard()
	if cardBuilt then
		return
	end
	cardBuilt = true

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UpgradeTreeTile1Card"
	billboard.Size = UDim2.new(0, 220, 0, 110)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = tile1
	billboard.Parent = tile1

	background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = COLOR_LOCKED
	background.BorderSizePixel = 0
	background.Parent = billboard

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0.1, 0)
	backgroundCorner.Parent = background

	titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, 0, 0.45, 0)
	titleText.Position = UDim2.new(0, 0, 0.08, 0)
	titleText.BackgroundTransparency = 1
	titleText.Font = Enum.Font.GothamBold
	titleText.TextScaled = true
	titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = "Dust x2"
	titleText.Parent = background

	costText = Instance.new("TextLabel")
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

	updateCard()
end

local function render(state)
	if not state then
		return
	end

	currentDust = state.arcaneDust
	tile1Cost = state.tile1Cost
	tile1Bought = state.tile1Bought

	if state.unlocked then
		buildCard()
	end
end

render(getUpgradeTreeStateFunction:InvokeServer())

arcaneDustUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentDust = amount
	updateCard()
end)

upgradeTreeTileBoughtEvent.OnClientEvent:Connect(function(tileId)
	if tileId == "tile1" then
		tile1Bought = true
		updateCard()
	end
end)

-- Reaching Tier 3 fires this too (it fires on every Wizard Tier purchase) -
-- re-checking builds the card immediately, no rejoin needed.
playerWizardTieredEvent.OnClientEvent:Connect(function()
	render(getUpgradeTreeStateFunction:InvokeServer())
end)
