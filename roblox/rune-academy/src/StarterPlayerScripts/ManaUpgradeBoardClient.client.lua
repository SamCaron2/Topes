-- Builds the whole Mana upgrades board: a small clear icon + amount readout
-- (no "Mana" word, the icon says it) above a "Mana Upgrades" title banner,
-- then 4 upgrade columns
-- left-to-right below filling the board edge-to-edge - "More Mana", "Mana
-- Spawn Speed", "Walking Speed", and "Collection Range". The clear readout
-- is the template for every future currency board (Rebirths, etc.) - keep
-- that look consistent. Painted directly onto the board's face with a
-- SurfaceGui, not a BillboardGui - a Billboard always turns to face the
-- camera, which made an earlier version look like it was sliding around as
-- you walked past; a SurfaceGui is flat against one physical face,
-- unreadable from behind, exactly like a real sign.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaYieldStateFunction = remotes:WaitForChild("GetManaYieldState")
local buyManaYieldUpgradeFunction = remotes:WaitForChild("BuyManaYieldUpgrade")
local getManaSpawnStateFunction = remotes:WaitForChild("GetManaSpawnState")
local buyManaSpawnUpgradeFunction = remotes:WaitForChild("BuyManaSpawnUpgrade")
local getWalkSpeedStateFunction = remotes:WaitForChild("GetWalkSpeedState")
local buyWalkSpeedUpgradeFunction = remotes:WaitForChild("BuyWalkSpeedUpgrade")
local getCollectionRangeStateFunction = remotes:WaitForChild("GetCollectionRangeState")
local buyCollectionRangeUpgradeFunction = remotes:WaitForChild("BuyCollectionRangeUpgrade")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local playerRebirthedEvent = remotes:WaitForChild("PlayerRebirthed")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("ManaUpgradeBoard")

local MANA_ICON_ID = "rbxassetid://119417928367783"

-- Overlaps the readout pill's left edge - no circle backdrop for the Mana
-- icon specifically (its sparkles poke outside a round silhouette, so a
-- white circle behind it looked bad), unlike the Rebirths icon elsewhere.
local function addReadoutIcon(parent: Frame, imageId: string)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, -22, 0.5, 0)
	holder.Size = UDim2.new(0, 40, 0, 40)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 2
	holder.Parent = parent

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ZIndex = 3
	icon.Parent = holder

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
local TEXT_STROKE_TRANSPARENCY = 0.4 -- a subtle black outline behind every label, for a slight 3D look

-- Sized to fill the board edge-to-edge for exactly 4 columns (0.03 margin on
-- both sides) - there's a separate Rebirths board now for future growth, so
-- this one no longer needs to reserve empty space of its own.
local COLUMN_WIDTH = 0.205
local COLUMN_GAP = 0.04
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.33 -- clear gap below the title banner

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
background.BackgroundTransparency = 0.55 -- lets the card's glass show through behind it
background.BorderSizePixel = 0
background.Parent = surfaceGui

-- Small clear "currency readout" pill above the title, matching the live
-- Mana amount shown in the corner HUD. This is the template for every
-- future currency board (Rebirths, etc.) going forward - keep this look.
local currencyReadout = Instance.new("Frame")
currencyReadout.Size = UDim2.new(0.5, 0, 0.06, 0)
currencyReadout.Position = UDim2.new(0.25, 0, 0.02, 0)
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

addReadoutIcon(currencyReadout, MANA_ICON_ID)

-- Small helper reused by the hand-built (no image asset) column icons
-- below - a perfect circle Frame, optionally hollow (a ring: transparent
-- fill, UIStroke border only).
local function newCircle(parent: Instance, size: UDim2, position: UDim2, color: Color3, hollow: boolean, strokeThickness: number?)
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Size = size
	circle.Position = position
	circle.BackgroundTransparency = hollow and 1 or 0
	circle.BackgroundColor3 = color
	circle.BorderSizePixel = 0
	circle.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	if hollow then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = strokeThickness or 2
		stroke.Color = color
		stroke.Parent = circle
	end

	return circle
end

-- Per direct request ("lets do icons instead of these circles"). Built
-- from plain UI shapes for 3 of the 4 (no uploaded image, and no Unicode
-- glyph either - Roblox's default font doesn't cover most symbol/emoji
-- codepoints, confirmed the hard way earlier this session with "➜"/"⬅"
-- rendering as empty boxes), so these always render identically with no
-- font-coverage risk at all. "More Mana" reuses the real Mana icon
-- instead, per direct request ("for the more mana lets do our mana
-- icon").

-- No colored circle behind this one - same reasoning as `addReadoutIcon`
-- above (the Mana icon's own sparkles poke outside a round silhouette,
-- so a filled circle backdrop looks bad behind it specifically).
local function buildManaIcon(iconFrame: Frame)
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = MANA_ICON_ID
	icon.Parent = iconFrame

	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0.12, 0)
	iconPadding.PaddingBottom = UDim.new(0.12, 0)
	iconPadding.PaddingLeft = UDim.new(0.12, 0)
	iconPadding.PaddingRight = UDim.new(0.12, 0)
	iconPadding.Parent = icon
end

-- A stopwatch: a hollow ring (the face), a small rectangle poking out the
-- top (the crown button), and a thin rotated rectangle from center to
-- edge (the hand) - best represents "how often a new node spawns."
local function buildSpawnSpeedIcon(iconFrame: Frame)
	local white = Color3.fromRGB(255, 255, 255)

	newCircle(iconFrame, UDim2.new(0.66, 0, 0.66, 0), UDim2.new(0.5, 0, 0.56, 0), white, true, 3)

	local crown = Instance.new("Frame")
	crown.AnchorPoint = Vector2.new(0.5, 1)
	crown.Size = UDim2.new(0.14, 0, 0.12, 0)
	crown.Position = UDim2.new(0.5, 0, 0.22, 0)
	crown.BackgroundColor3 = white
	crown.BorderSizePixel = 0
	crown.Parent = iconFrame

	local crownCorner = Instance.new("UICorner")
	crownCorner.CornerRadius = UDim.new(0.4, 0)
	crownCorner.Parent = crown

	local hand = Instance.new("Frame")
	hand.AnchorPoint = Vector2.new(0.5, 1)
	hand.Size = UDim2.new(0.07, 0, 0.24, 0)
	hand.Position = UDim2.new(0.5, 0, 0.56, 0)
	hand.Rotation = 35
	hand.BackgroundColor3 = white
	hand.BorderSizePixel = 0
	hand.Parent = iconFrame

	local handCorner = Instance.new("UICorner")
	handCorner.CornerRadius = UDim.new(1, 0)
	handCorner.Parent = hand
end

-- A boot silhouette (ankle + sole) with 3 short motion lines trailing
-- behind it, per direct request ("like a pair of boots getting faster").
local function buildWalkSpeedIcon(iconFrame: Frame)
	local bootColor = Color3.fromRGB(90, 60, 40)

	local ankle = Instance.new("Frame")
	ankle.AnchorPoint = Vector2.new(0.5, 1)
	ankle.Size = UDim2.new(0.26, 0, 0.42, 0)
	ankle.Position = UDim2.new(0.62, 0, 0.62, 0)
	ankle.BackgroundColor3 = bootColor
	ankle.BorderSizePixel = 0
	ankle.Parent = iconFrame

	local ankleCorner = Instance.new("UICorner")
	ankleCorner.CornerRadius = UDim.new(0.3, 0)
	ankleCorner.Parent = ankle

	local sole = Instance.new("Frame")
	sole.AnchorPoint = Vector2.new(0.5, 1)
	sole.Size = UDim2.new(0.5, 0, 0.2, 0)
	sole.Position = UDim2.new(0.68, 0, 0.8, 0)
	sole.BackgroundColor3 = bootColor
	sole.BorderSizePixel = 0
	sole.Parent = iconFrame

	local soleCorner = Instance.new("UICorner")
	soleCorner.CornerRadius = UDim.new(0.35, 0)
	soleCorner.Parent = sole

	-- 3 shrinking lines trailing to the left, suggesting forward motion.
	local lineWidths = { 0.22, 0.16, 0.1 }
	for i, width in lineWidths do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(1, 0.5)
		line.Size = UDim2.new(width, 0, 0.06, 0)
		line.Position = UDim2.new(0.32, 0, 0.28 + (i - 1) * 0.14, 0)
		line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		line.BorderSizePixel = 0
		line.Parent = iconFrame

		local lineCorner = Instance.new("UICorner")
		lineCorner.CornerRadius = UDim.new(1, 0)
		lineCorner.Parent = line
	end
end

-- Concentric rings around a solid center dot - a pickup-radius pictogram.
local function buildCollectionRangeIcon(iconFrame: Frame)
	local white = Color3.fromRGB(255, 255, 255)
	newCircle(iconFrame, UDim2.new(0.86, 0, 0.86, 0), UDim2.new(0.5, 0, 0.5, 0), white, true, 2)
	newCircle(iconFrame, UDim2.new(0.58, 0, 0.58, 0), UDim2.new(0.5, 0, 0.5, 0), white, true, 2)
	newCircle(iconFrame, UDim2.new(0.22, 0, 0.22, 0), UDim2.new(0.5, 0, 0.5, 0), white, false)
end

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	currencyReadoutText.Text = NumberFormat.format(amount)
end)

-- Title banner across the top, matching the reference's "<Currency> Upgrades" pill.
local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
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
-- Returns a refresh() function so the caller can re-fetch this column's
-- state on demand (used after a rebirth resets all 4 columns' levels).
local function createUpgradeColumn(slotIndex: number, name: string, iconColor: Color3?, buildIcon: (Frame) -> (), getStateRemote, buyRemote, formatDetail)
	local column = Instance.new("Frame")
	column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.7, 0)
	column.Position = UDim2.new(COLUMN_START_X + (slotIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
	column.BackgroundTransparency = 1
	column.Parent = background

	local iconFrame = Instance.new("Frame")
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Size = UDim2.new(0.55, 0, 0.22, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	-- nil iconColor (Mana specifically) means no filled backdrop - see
	-- buildManaIcon's own comment for why.
	iconFrame.BackgroundTransparency = iconColor and 0 or 1
	iconFrame.BackgroundColor3 = iconColor or Color3.fromRGB(255, 255, 255)
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = column

	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = iconFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconFrame

	buildIcon(iconFrame)

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

	local BUY_SIZE = buyButton.Size
	local BUY_POSITION = buyButton.Position
	local MAXED_SIZE = UDim2.new(1, 0, 0.16, 0)
	local MAXED_POSITION = UDim2.new(0, 0, 0.82, 0)

	local currentMana = 0
	local nextLevelCost = nil -- nil once maxed

	local function updateButtonColors()
		if nextLevelCost == nil then
			-- One full-width "Maxed" button instead of two redundant ones.
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
		costLabel.Text = state.nextLevelCost and ("Cost: %s Mana"):format(NumberFormat.format(state.nextLevelCost)) or "Cost: -"

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

	local function refresh()
		render(getStateRemote:InvokeServer())
	end

	return refresh
end

local columnRefreshFunctions = {
	createUpgradeColumn(1, "More Mana", nil, buildManaIcon, getManaYieldStateFunction, buyManaYieldUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("+%s > +%s"):format(NumberFormat.format(state.amountPerPickup), NumberFormat.format(state.nextAmountPerPickup))
		end
		return ("+%s (MAX)"):format(NumberFormat.format(state.amountPerPickup))
	end),

	createUpgradeColumn(2, "Mana Spawn Speed", Color3.fromRGB(80, 220, 255), buildSpawnSpeedIcon, getManaSpawnStateFunction, buyManaSpawnUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.1fs > %.1fs"):format(state.respawnSeconds, state.nextRespawnSeconds)
		end
		return ("%.1fs (MAX)"):format(state.respawnSeconds)
	end),

	createUpgradeColumn(3, "Walking Speed", Color3.fromRGB(255, 200, 60), buildWalkSpeedIcon, getWalkSpeedStateFunction, buyWalkSpeedUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
		end
		return ("%.1fx (MAX)"):format(state.multiplier)
	end),

	createUpgradeColumn(4, "Collection Range", Color3.fromRGB(90, 220, 140), buildCollectionRangeIcon, getCollectionRangeStateFunction, buyCollectionRangeUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.0f > %.0f"):format(state.radius, state.nextRadius)
		end
		return ("%.0f (MAX)"):format(state.radius)
	end),
}

-- Rebirthing resets all 4 of these upgrades server-side; re-fetch every
-- column so the board doesn't keep showing stale pre-rebirth levels/costs.
playerRebirthedEvent.OnClientEvent:Connect(function()
	for _, refresh in columnRefreshFunctions do
		refresh()
	end
end)
