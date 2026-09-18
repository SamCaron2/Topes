-- Builds the whole Mana upgrades board: a "Mana Upgrades" title banner
-- across the top, then upgrade columns left-to-right below it - "More Mana"
-- and "Mana Spawn Speed" so far, with empty space to the right for more later.
-- Painted directly onto the board's face with a SurfaceGui, not a
-- BillboardGui - a Billboard always turns to face the camera, which made an
-- earlier version look like it was sliding around as you walked past; a
-- SurfaceGui is flat against one physical face, unreadable from behind,
-- exactly like a real sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaYieldStateFunction = remotes:WaitForChild("GetManaYieldState")
local buyManaYieldUpgradeFunction = remotes:WaitForChild("BuyManaYieldUpgrade")
local getManaSpawnStateFunction = remotes:WaitForChild("GetManaSpawnState")
local buyManaSpawnUpgradeFunction = remotes:WaitForChild("BuyManaSpawnUpgrade")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("ManaUpgradeBoard")

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4 -- a subtle black outline behind every label, for a slight 3D look

local COLUMN_WIDTH = 0.18
local COLUMN_GAP = 0.04
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.26 -- clear gap below the title banner

-- The board isn't rotated (its local axes match world axes), and it sits
-- east of the platform, so the face pointing back at the player is the -X
-- face - "Left" in Roblox's NormalId naming.
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "ManaUpgradeBoardGui"
surfaceGui.Face = Enum.NormalId.Left
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(70, 150, 220)
background.BorderSizePixel = 0
background.Parent = surfaceGui

-- Title banner across the top, matching the reference's "<Currency> Upgrades" pill.
local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
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
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Mana Upgrades"
titleText.Parent = titleBanner

-- Builds one upgrade column (icon, name, level, detail line, cost, Buy/Max)
-- at the given horizontal slot and wires it to a get-state/buy remote pair.
-- Shared by every upgrade on this board so they all look and behave alike.
local function createUpgradeColumn(slotIndex: number, name: string, iconColor: Color3, getStateRemote, buyRemote, formatDetail)
	local column = Instance.new("Frame")
	column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.7, 0)
	column.Position = UDim2.new(COLUMN_START_X + (slotIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
	column.BackgroundTransparency = 1
	column.Parent = background

	local iconFrame = Instance.new("Frame")
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Size = UDim2.new(0.55, 0, 0.22, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.BackgroundColor3 = iconColor
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
	nameLabel.Position = UDim2.new(0, 0, 0.28, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = name
	nameLabel.Parent = column

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.new(1, 0, 0.08, 0)
	levelLabel.Position = UDim2.new(0, 0, 0.4, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	levelLabel.Text = "(-/-)"
	levelLabel.Parent = column

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Size = UDim2.new(1, 0, 0.08, 0)
	detailLabel.Position = UDim2.new(0, 0, 0.5, 0)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamBold
	detailLabel.TextScaled = true
	detailLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	detailLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	detailLabel.Text = "-"
	detailLabel.Parent = column

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0.08, 0)
	costLabel.Position = UDim2.new(0, 0, 0.6, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.Gotham
	costLabel.TextScaled = true
	costLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	costLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	costLabel.Text = "Cost: -"
	costLabel.Parent = column

	-- Buttons near the bottom. UIPadding shrinks the area TextScaled fits
	-- into, so "Buy"/"Max" read smaller inside the box instead of
	-- stretching edge-to-edge.
	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0.46, 0, 0.16, 0)
	buyButton.Position = UDim2.new(0, 0, 0.82, 0)
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
	maxButton.Position = UDim2.new(0.54, 0, 0.82, 0)
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
		detailLabel.Text = formatDetail(state)
		costLabel.Text = state.nextLevelCost and ("Cost: %d Mana"):format(state.nextLevelCost) or "Cost: -"

		updateButtonColors()
	end

	render(getStateRemote:InvokeServer())

	manaUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentMana = amount
		updateButtonColors()
	end)

	buyButton.MouseButton1Click:Connect(function()
		local success, _, newState = buyRemote:InvokeServer("one")
		if success then
			render(newState)
		end
	end)

	maxButton.MouseButton1Click:Connect(function()
		local success, _, newState = buyRemote:InvokeServer("max")
		if success then
			render(newState)
		end
	end)
end

createUpgradeColumn(1, "More Mana", Color3.fromRGB(150, 80, 255), getManaYieldStateFunction, buyManaYieldUpgradeFunction, function(state)
	if state.nextLevelCost then
		return ("+%d > +%d"):format(state.amountPerPickup, state.nextAmountPerPickup)
	end
	return ("+%d (MAX)"):format(state.amountPerPickup)
end)

createUpgradeColumn(2, "Mana Spawn Speed", Color3.fromRGB(80, 220, 255), getManaSpawnStateFunction, buyManaSpawnUpgradeFunction, function(state)
	if state.nextLevelCost then
		return ("%.1fs > %.1fs"):format(state.respawnSeconds, state.nextRespawnSeconds)
	end
	return ("%.1fs (MAX)"):format(state.respawnSeconds)
end)
