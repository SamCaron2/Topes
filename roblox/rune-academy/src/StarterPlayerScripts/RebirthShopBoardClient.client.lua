-- Builds the Rebirth Shop board: permanent upgrades bought with Rebirths
-- that survive rebirthing (unlike the Mana Upgrades board's 4 columns,
-- which reset every rebirth) - a small clear icon + amount readout (no
-- "Rebirths" word, the icon says it) above a "Rebirth Upgrades" title
-- banner (same template as the Mana
-- Upgrades board), then 3 columns left-to-right filling the board
-- edge-to-edge: "Mana Value Multiplier", "Rebirth Multiplier", and
-- "XP Multiplier". Same createUpgradeColumn pattern as the Mana Upgrades
-- board, just costed in Rebirths instead of Mana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaValueMultiplierStateFunction = remotes:WaitForChild("GetManaValueMultiplierState")
local buyManaValueMultiplierFunction = remotes:WaitForChild("BuyManaValueMultiplier")
local getRebirthMultiplierStateFunction = remotes:WaitForChild("GetRebirthMultiplierState")
local buyRebirthMultiplierFunction = remotes:WaitForChild("BuyRebirthMultiplier")
local getXpMultiplierStateFunction = remotes:WaitForChild("GetXpMultiplierState")
local buyXpMultiplierFunction = remotes:WaitForChild("BuyXpMultiplier")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")
local playerRebirthedEvent = remotes:WaitForChild("PlayerRebirthed")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("RebirthShopBoard")

local REBIRTHS_ICON_ID = "rbxassetid://119426569971477"

-- A small round white badge overlapping the readout pill's left edge -
-- same look as the corner HUD's currency icons, so boards and HUD match.
local function addReadoutIcon(parent: Frame, imageId: string)
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, -22, 0.5, 0)
	badge.Size = UDim2.new(0, 40, 0, 40)
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = parent

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ZIndex = 3
	icon.Parent = badge

	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0.12, 0)
	iconPadding.PaddingBottom = UDim.new(0.12, 0)
	iconPadding.PaddingLeft = UDim.new(0.12, 0)
	iconPadding.PaddingRight = UDim.new(0.12, 0)
	iconPadding.Parent = icon
end

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

-- Sized to fill the board edge-to-edge for exactly 3 columns (0.03 margin on
-- both sides), same spacing scheme as the Mana Upgrades board's 4 columns.
local COLUMN_WIDTH = 0.2867
local COLUMN_GAP = 0.04
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.33

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "RebirthShopBoardGui"
surfaceGui.Face = Enum.NormalId.Left
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
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

-- Sized/positioned to leave room for the icon badge on the left - UIPadding
-- on a TextLabel doesn't inset its own rendered Text (it only repositions
-- child Instances), so the space has to be carved out here instead.
local currencyReadoutText = Instance.new("TextLabel")
currencyReadoutText.Size = UDim2.new(1, -26, 1, 0)
currencyReadoutText.Position = UDim2.new(0, 26, 0, 0)
currencyReadoutText.BackgroundTransparency = 1
currencyReadoutText.Font = Enum.Font.GothamBold
currencyReadoutText.TextScaled = true
currencyReadoutText.TextColor3 = Color3.fromRGB(255, 255, 255)
currencyReadoutText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
currencyReadoutText.Text = "-"
currencyReadoutText.Parent = currencyReadout

addReadoutIcon(currencyReadout, REBIRTHS_ICON_ID)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	currencyReadoutText.Text = ("%.1f"):format(amount)
end)

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(90, 15, 15)
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

-- Builds one upgrade column, identical structure to the Mana Upgrades
-- board's createUpgradeColumn but costed and gated in Rebirths instead of
-- Mana. Returns a refresh() function used after a rebirth (Rebirths itself
-- doesn't reset, but this keeps the pattern consistent with the Mana board).
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

	local BUY_SIZE = buyButton.Size
	local BUY_POSITION = buyButton.Position
	local MAXED_SIZE = UDim2.new(1, 0, 0.16, 0)
	local MAXED_POSITION = UDim2.new(0, 0, 0.82, 0)

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
		detailLabel.Text = formatDetail(state)
		costLabel.Text = state.nextLevelCost and ("Cost: %d Rebirths"):format(state.nextLevelCost) or "Cost: -"

		updateButtonColors()
	end

	render(getStateRemote:InvokeServer())

	rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentRebirths = amount
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

	local function refresh()
		render(getStateRemote:InvokeServer())
	end

	return refresh
end

local function formatMultiplierDetail(state)
	if state.nextLevelCost then
		return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
	end
	return ("%.1fx (MAX)"):format(state.multiplier)
end

local columnRefreshFunctions = {
	createUpgradeColumn(
		1,
		"Mana Value Multiplier",
		Color3.fromRGB(255, 200, 60),
		getManaValueMultiplierStateFunction,
		buyManaValueMultiplierFunction,
		formatMultiplierDetail
	),

	createUpgradeColumn(
		2,
		"Rebirth Multiplier",
		Color3.fromRGB(255, 100, 100),
		getRebirthMultiplierStateFunction,
		buyRebirthMultiplierFunction,
		formatMultiplierDetail
	),

	createUpgradeColumn(
		3,
		"XP Multiplier",
		Color3.fromRGB(150, 220, 255),
		getXpMultiplierStateFunction,
		buyXpMultiplierFunction,
		formatMultiplierDetail
	),
}

-- Rebirths and Rebirth Shop levels aren't reset by rebirthing, but refresh
-- anyway on the same event so this board never drifts from server state.
playerRebirthedEvent.OnClientEvent:Connect(function()
	for _, refresh in columnRefreshFunctions do
		refresh()
	end
end)
