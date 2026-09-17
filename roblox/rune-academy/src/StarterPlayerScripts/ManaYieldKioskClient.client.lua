-- Builds the Mana upgrades board's UI: a "Mana Upgrades" title banner across
-- the top, then upgrade columns left-to-right below it (only one column
-- exists so far - "More Mana" - with empty space to its right for more
-- later). Painted directly onto the card's face with a SurfaceGui, not a
-- BillboardGui - a Billboard always turns to face the camera, which is what
-- made an earlier version look like it was sliding around as you walked
-- past; a SurfaceGui is flat against one physical face, unreadable from
-- behind, exactly like a real sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaYieldStateFunction = remotes:WaitForChild("GetManaYieldState")
local buyManaYieldUpgradeFunction = remotes:WaitForChild("BuyManaYieldUpgrade")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local kiosk = Workspace:WaitForChild("Kiosks"):WaitForChild("ManaYieldKiosk")

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)

-- The card isn't rotated (its local axes match world axes), and it sits east
-- of the platform, so the face pointing back at the player is the -X face -
-- "Left" in Roblox's NormalId naming.
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "ManaYieldBoard"
surfaceGui.Face = Enum.NormalId.Left
surfaceGui.Adornee = kiosk
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = kiosk

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(70, 150, 220)
background.BorderSizePixel = 0
background.Parent = surfaceGui

-- Title banner across the top, matching the reference's "<Currency> Upgrades" pill.
local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.17, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.03, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(35, 70, 110)
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
titleText.TextStrokeTransparency = 0.5
titleText.Text = "Mana Upgrades"
titleText.Parent = titleBanner

-- One column, left-aligned, with empty space to the right for more later.
local column = Instance.new("Frame")
column.Size = UDim2.new(0.3, 0, 0.75, 0)
column.Position = UDim2.new(0.03, 0, 0.23, 0)
column.BackgroundTransparency = 1
column.Parent = background

-- Fake icon for now - a plain circle standing in for a real Mana icon later.
local iconFrame = Instance.new("Frame")
iconFrame.Size = UDim2.new(0.6, 0, 0.3, 0)
iconFrame.Position = UDim2.new(0.2, 0, 0, 0)
iconFrame.BackgroundColor3 = Color3.fromRGB(150, 80, 255)
iconFrame.BorderSizePixel = 0
iconFrame.Parent = column

local iconAspect = Instance.new("UIAspectRatioConstraint")
iconAspect.AspectRatio = 1
iconAspect.Parent = iconFrame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(1, 0)
iconCorner.Parent = iconFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0.13, 0)
nameLabel.Position = UDim2.new(0, 0, 0.32, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
nameLabel.TextStrokeTransparency = 0.6
nameLabel.Text = "More Mana"
nameLabel.Parent = column

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, 0, 0.11, 0)
levelLabel.Position = UDim2.new(0, 0, 0.46, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextScaled = true
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextStrokeTransparency = 0.6
levelLabel.Text = "(-/-)"
levelLabel.Parent = column

local yieldLabel = Instance.new("TextLabel")
yieldLabel.Size = UDim2.new(1, 0, 0.11, 0)
yieldLabel.Position = UDim2.new(0, 0, 0.58, 0)
yieldLabel.BackgroundTransparency = 1
yieldLabel.Font = Enum.Font.GothamBold
yieldLabel.TextScaled = true
yieldLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
yieldLabel.TextStrokeTransparency = 0.6
yieldLabel.Text = "+- > +-"
yieldLabel.Parent = column

local costLabel = Instance.new("TextLabel")
costLabel.Size = UDim2.new(1, 0, 0.1, 0)
costLabel.Position = UDim2.new(0, 0, 0.7, 0)
costLabel.BackgroundTransparency = 1
costLabel.Font = Enum.Font.Gotham
costLabel.TextScaled = true
costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
costLabel.TextStrokeTransparency = 0.6
costLabel.Text = "Cost: -"
costLabel.Parent = column

-- Bigger buttons spanning the bottom of the column.
local buyButton = Instance.new("TextButton")
buyButton.Size = UDim2.new(0.48, 0, 0.22, 0)
buyButton.Position = UDim2.new(0, 0, 0.78, 0)
buyButton.BackgroundColor3 = COLOR_CAN_BUY
buyButton.Font = Enum.Font.GothamBold
buyButton.TextScaled = true
buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyButton.Text = "Buy"
buyButton.Parent = column

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0.3, 0)
buyCorner.Parent = buyButton

local maxButton = Instance.new("TextButton")
maxButton.Size = UDim2.new(0.48, 0, 0.22, 0)
maxButton.Position = UDim2.new(0.52, 0, 0.78, 0)
maxButton.BackgroundColor3 = COLOR_MAX_ACTIVE
maxButton.Font = Enum.Font.GothamBold
maxButton.TextScaled = true
maxButton.TextColor3 = Color3.fromRGB(60, 50, 0)
maxButton.Text = "Max"
maxButton.Parent = column

local maxCorner = Instance.new("UICorner")
maxCorner.CornerRadius = UDim.new(0.3, 0)
maxCorner.Parent = maxButton

local currentMana = 0
local nextLevelCost = nil -- nil once maxed

local function updateButtonColors()
	if nextLevelCost == nil then
		buyButton.Active = false
		maxButton.Active = false
		buyButton.BackgroundColor3 = COLOR_MAXED_OUT
		maxButton.BackgroundColor3 = COLOR_MAXED_OUT
		return
	end

	local canAfford = currentMana >= nextLevelCost
	buyButton.Active = canAfford
	maxButton.Active = canAfford
	buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
	maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
end

local function render(state)
	if not state then
		return
	end

	currentMana = state.mana
	nextLevelCost = state.nextLevelCost

	levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)

	if state.nextLevelCost then
		yieldLabel.Text = ("+%d > +%d"):format(state.amountPerPickup, state.amountPerPickup + 1)
		costLabel.Text = ("Cost: %d Mana"):format(state.nextLevelCost)
	else
		yieldLabel.Text = ("+%d (MAX)"):format(state.amountPerPickup)
		costLabel.Text = "Cost: -"
	end

	updateButtonColors()
end

render(getManaYieldStateFunction:InvokeServer())

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentMana = amount
	updateButtonColors()
end)

buyButton.MouseButton1Click:Connect(function()
	local success, _, newState = buyManaYieldUpgradeFunction:InvokeServer("one")
	if success then
		render(newState)
	end
end)

maxButton.MouseButton1Click:Connect(function()
	local success, _, newState = buyManaYieldUpgradeFunction:InvokeServer("max")
	if success then
		render(newState)
	end
end)
