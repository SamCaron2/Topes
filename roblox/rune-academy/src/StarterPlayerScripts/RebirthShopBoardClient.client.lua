-- Builds the Rebirth Shop board: permanent upgrades bought with Rebirths
-- that survive rebirthing (unlike the Mana Upgrades board's 4 columns,
-- which reset every rebirth) - a small clear "Rebirths: <amount>" readout
-- above a "Rebirth Upgrades" title banner (same template as the Mana
-- Upgrades board), then one column so far: "Mana Value Multiplier". Two
-- more columns are planned for this same board later - widen
-- REBIRTH_SHOP_BOARD_WIDTH in WorldBuilder and lay them out left-to-right
-- the way the Mana Upgrades board does, once they're specified.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaValueMultiplierStateFunction = remotes:WaitForChild("GetManaValueMultiplierState")
local buyManaValueMultiplierFunction = remotes:WaitForChild("BuyManaValueMultiplier")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("RebirthShopBoard")

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "RebirthShopBoardGui"
surfaceGui.Face = Enum.NormalId.Left
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(120, 70, 150)
background.BackgroundTransparency = 0.55
background.BorderSizePixel = 0
background.Parent = surfaceGui

-- Same clear-readout template as the Mana Upgrades board, denominated in
-- Rebirths here instead of Mana - keep this look for every future board.
local currencyReadout = Instance.new("Frame")
currencyReadout.Size = UDim2.new(0.7, 0, 0.06, 0)
currencyReadout.Position = UDim2.new(0.15, 0, 0.02, 0)
currencyReadout.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
currencyReadout.BackgroundTransparency = 0.75
currencyReadout.BorderSizePixel = 0
currencyReadout.Parent = background

local currencyReadoutCorner = Instance.new("UICorner")
currencyReadoutCorner.CornerRadius = UDim.new(0.3, 0)
currencyReadoutCorner.Parent = currencyReadout

local currencyReadoutText = Instance.new("TextLabel")
currencyReadoutText.Size = UDim2.new(1, 0, 1, 0)
currencyReadoutText.BackgroundTransparency = 1
currencyReadoutText.Font = Enum.Font.GothamBold
currencyReadoutText.TextScaled = true
currencyReadoutText.TextColor3 = Color3.fromRGB(255, 255, 255)
currencyReadoutText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
currencyReadoutText.Text = "Rebirths: -"
currencyReadoutText.Parent = currencyReadout

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	currencyReadoutText.Text = ("Rebirths: %.1f"):format(amount)
end)

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(70, 35, 90)
titleBanner.BackgroundTransparency = 0.15
titleBanner.BorderSizePixel = 0
titleBanner.Parent = background

local titleBannerCorner = Instance.new("UICorner")
titleBannerCorner.CornerRadius = UDim.new(0.25, 0)
titleBannerCorner.Parent = titleBanner

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.TextScaled = true
titleText.TextColor3 = Color3.fromRGB(255, 220, 90)
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Rebirth Upgrades"
titleText.Parent = titleBanner

-- Single column for now, centered, filling most of the board's width.
local column = Instance.new("Frame")
column.Size = UDim2.new(0.8, 0, 0.55, 0)
column.Position = UDim2.new(0.1, 0, 0.33, 0)
column.BackgroundTransparency = 1
column.Parent = background

local iconFrame = Instance.new("Frame")
iconFrame.AnchorPoint = Vector2.new(0.5, 0)
iconFrame.Size = UDim2.new(0.4, 0, 0.18, 0)
iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
iconFrame.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
iconFrame.BorderSizePixel = 0
iconFrame.Parent = column

local iconAspect = Instance.new("UIAspectRatioConstraint")
iconAspect.AspectRatio = 1
iconAspect.Parent = iconFrame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = iconFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0.09, 0)
nameLabel.Position = UDim2.new(0, 0, 0.22, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
nameLabel.Text = "Mana Value Multiplier"
nameLabel.Parent = column

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 0.08, 0)
levelLabel.Position = UDim2.new(0, 0, 0.34, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextScaled = true
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
levelLabel.Text = "(-/-)"
levelLabel.Parent = column

local detailLabel = Instance.new("TextLabel")
detailLabel.Size = UDim2.new(1, 0, 0.08, 0)
detailLabel.Position = UDim2.new(0, 0, 0.44, 0)
detailLabel.BackgroundTransparency = 1
detailLabel.Font = Enum.Font.GothamBold
detailLabel.TextScaled = true
detailLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
detailLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
detailLabel.Text = "-"
detailLabel.Parent = column

local costLabel = Instance.new("TextLabel")
costLabel.Size = UDim2.new(1, 0, 0.08, 0)
costLabel.Position = UDim2.new(0, 0, 0.54, 0)
costLabel.BackgroundTransparency = 1
costLabel.Font = Enum.Font.Gotham
costLabel.TextScaled = true
costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
costLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
costLabel.Text = "Cost: -"
costLabel.Parent = column

local buyButton = Instance.new("TextButton")
buyButton.Size = UDim2.new(0.46, 0, 0.16, 0)
buyButton.Position = UDim2.new(0, 0, 0.75, 0)
buyButton.BackgroundColor3 = COLOR_CAN_BUY
buyButton.Font = Enum.Font.GothamBold
buyButton.TextScaled = true
buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
buyButton.Text = "Buy"
buyButton.Parent = column

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0.3, 0)
buyCorner.Parent = buyButton

local buyPadding = Instance.new("UIPadding")
buyPadding.PaddingTop = UDim.new(0.22, 0)
buyPadding.PaddingBottom = UDim.new(0.22, 0)
buyPadding.PaddingLeft = UDim.new(0.15, 0)
buyPadding.PaddingRight = UDim.new(0.15, 0)
buyPadding.Parent = buyButton

local maxButton = Instance.new("TextButton")
maxButton.Size = UDim2.new(0.46, 0, 0.16, 0)
maxButton.Position = UDim2.new(0.54, 0, 0.75, 0)
maxButton.BackgroundColor3 = COLOR_MAX_ACTIVE
maxButton.Font = Enum.Font.GothamBold
maxButton.TextScaled = true
maxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
maxButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
maxButton.Text = "Max"
maxButton.Parent = column

local maxCorner = Instance.new("UICorner")
maxCorner.CornerRadius = UDim.new(0.3, 0)
maxCorner.Parent = maxButton

local maxPadding = Instance.new("UIPadding")
maxPadding.PaddingTop = UDim.new(0.22, 0)
maxPadding.PaddingBottom = UDim.new(0.22, 0)
maxPadding.PaddingLeft = UDim.new(0.15, 0)
maxPadding.PaddingRight = UDim.new(0.15, 0)
maxPadding.Parent = maxButton

local BUY_SIZE = buyButton.Size
local BUY_POSITION = buyButton.Position
local MAXED_SIZE = UDim2.new(1, 0, 0.16, 0)
local MAXED_POSITION = UDim2.new(0, 0, 0.75, 0)

local currentRebirths = 0
local nextLevelCost = nil -- nil once maxed

local function updateButtonColors()
	if nextLevelCost == nil then
		maxButton.Visible = false
		buyButton.Size = MAXED_SIZE
		buyButton.Position = MAXED_POSITION
		buyButton.Active = false
		buyButton.Text = "Maxed"
		buyButton.BackgroundColor3 = COLOR_MAXED_OUT
		return
	end

	maxButton.Visible = true
	buyButton.Size = BUY_SIZE
	buyButton.Position = BUY_POSITION
	buyButton.Text = "Buy"
	maxButton.Text = "Max"

	local canAfford = currentRebirths >= nextLevelCost
	buyButton.Active = canAfford
	maxButton.Active = canAfford
	buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
	maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
end

local function render(state)
	if not state then
		return
	end

	currentRebirths = state.rebirths
	nextLevelCost = state.nextLevelCost

	levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)
	if state.nextLevelCost then
		detailLabel.Text = ("%.2fx > %.2fx"):format(state.multiplier, state.nextMultiplier)
		costLabel.Text = ("Cost: %d Rebirths"):format(state.nextLevelCost)
	else
		detailLabel.Text = ("%.2fx (MAX)"):format(state.multiplier)
		costLabel.Text = "Cost: -"
	end

	updateButtonColors()
end

render(getManaValueMultiplierStateFunction:InvokeServer())

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentRebirths = amount
	updateButtonColors()
end)

buyButton.MouseButton1Click:Connect(function()
	local success, _, newState = buyManaValueMultiplierFunction:InvokeServer("one")
	if success then
		render(newState)
	end
end)

maxButton.MouseButton1Click:Connect(function()
	local success, _, newState = buyManaValueMultiplierFunction:InvokeServer("max")
	if success then
		render(newState)
	end
end)
