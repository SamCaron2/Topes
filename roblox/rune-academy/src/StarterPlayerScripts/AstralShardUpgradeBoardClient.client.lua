-- Builds Card 2's board (Workspace.AstralShardUpgradeBoard) - a small
-- clear amount readout above an "Astral Shard" title banner, then 2 real
-- upgrade columns plus 1 still-empty "Coming Soon" placeholder slot - per
-- direct request ("lets just start with those two upgrades"). "More Ley
-- Shard" (AstralShardLeyBoostHandler, 1-50) is a flat Ley Shard yield
-- multiplier that survives every Ley Shard board reset, and "More Astral
-- Shards" (AstralShardConversionBoostHandler, 1-50) boosts how many
-- Astral Shard each conversion grants - together the whole point of Card
-- 2, per direct request: "So to max out ley shards it takes a bit but
-- when you exchange for astral shards and buy more ley shards it goes by
-- quicker the second time." Same shared `createUpgradeColumn` pattern
-- (level/max/nextLevelCost, Buy+Max buttons) as every other board. Astral
-- Shard itself has no collection mechanic of its own; its only source is
-- the Conversion board next to this one (LeyShardConversionBoardClient).
-- Same "doesn't build at all until unlocked" gating as every other
-- EtherIsland board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)
local LockIcon = require(ReplicatedStorage.Modules.LockIcon)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherIslandStateFunction = remotes:WaitForChild("GetEtherIslandState")
local playerEtherIslandUnlockedEvent = remotes:WaitForChild("PlayerEtherIslandUnlocked")
local astralShardUpdatedEvent = remotes:WaitForChild("AstralShardUpdated")
local getAstralShardLeyBoostStateFunction = remotes:WaitForChild("GetAstralShardLeyBoostState")
local buyAstralShardLeyBoostUpgradeFunction = remotes:WaitForChild("BuyAstralShardLeyBoostUpgrade")
local getAstralShardConversionBoostStateFunction = remotes:WaitForChild("GetAstralShardConversionBoostState")
local buyAstralShardConversionBoostUpgradeFunction = remotes:WaitForChild("BuyAstralShardConversionBoostUpgrade")
local playerAstralShardConvertedEvent = remotes:WaitForChild("PlayerAstralShardConverted")

local board = Workspace:WaitForChild("AstralShardUpgradeBoard")

-- Shows a locked-padlock overlay (LockIcon) instead of just staying blank
-- until EtherIsland is unlocked - per direct request ("Make sure all
-- cards are locked with a locked emoji on them until you unlock them").
local lockGui = LockIcon.show(board, Enum.NormalId.Back)

local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255)
local LEY_SHARD_COLOR = Color3.fromRGB(90, 220, 190)

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

local COLUMN_WIDTH = 0.29
local COLUMN_GAP = 0.03
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.33

local built = false

-- A gem: a rotated square (diamond) with a smaller, lighter diamond inset
-- for a facet highlight - same shape as LeyShardUpgradeBoardClient's own
-- icon, just recolored per column so each one points at the currency it
-- actually affects (Ley Shard's own teal for "More Ley Shard", Astral
-- Shard's own violet for "More Astral Shards").
local function buildGemIcon(color: Color3): (Frame) -> ()
	return function(iconFrame: Frame)
		local outer = Instance.new("Frame")
		outer.AnchorPoint = Vector2.new(0.5, 0.5)
		outer.Position = UDim2.new(0.5, 0, 0.5, 0)
		outer.Size = UDim2.new(0.8, 0, 0.8, 0)
		outer.Rotation = 45
		outer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		outer.BorderSizePixel = 0
		outer.Parent = iconFrame

		local outerCorner = Instance.new("UICorner")
		outerCorner.CornerRadius = UDim.new(0.2, 0)
		outerCorner.Parent = outer

		local inner = Instance.new("Frame")
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.new(0.5, 0, 0.5, 0)
		inner.Size = UDim2.new(0.42, 0, 0.42, 0)
		inner.BackgroundColor3 = color
		inner.BorderSizePixel = 0
		inner.Parent = outer

		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(0.25, 0)
		innerCorner.Parent = inner
	end
end

local function createUpgradeColumn(background: Frame, slotIndex: number, name: string, buildIcon: (Frame) -> (), getStateRemote, buyRemote, formatDetail)
	local column = Instance.new("Frame")
	column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.62, 0) -- see LeyShardUpgradeBoardClient's own comment - 0.7 overflowed past the board's ground-level bottom edge
	column.Position = UDim2.new(COLUMN_START_X + (slotIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
	column.BackgroundTransparency = 1
	column.Parent = background

	local iconFrame = Instance.new("Frame")
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Size = UDim2.new(0.5, 0, 0.22, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = column

	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = iconFrame

	buildIcon(iconFrame)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.09, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.28, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = ASTRAL_SHARD_COLOR
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

	local currentAstralShard = 0
	local nextLevelCost = nil

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

		local canAfford = currentAstralShard >= nextLevelCost
		buyButton.Active = canAfford
		maxButton.Active = canAfford
		buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
		maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
	end

	local function render(state)
		if not state then
			return
		end

		currentAstralShard = state.astralShard
		nextLevelCost = state.nextLevelCost

		levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)
		detailLabel.Text = formatDetail(state)
		costLabel.Text = state.nextLevelCost and ("Cost: %s"):format(NumberFormat.format(state.nextLevelCost)) or "Cost: -"

		updateButtonColors()
	end

	render(getStateRemote:InvokeServer())

	astralShardUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentAstralShard = amount
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

	-- Converting Astral Shard into Celestial Shard resets both of this
	-- board's own levels back to 1 (CelestialShardConversionHandler.convert
	-- does the reset) - re-fetch so this column doesn't keep showing a
	-- stale pre-reset level/cost, same "broadcast a re-fetch signal"
	-- pattern LeyShardUpgradeBoardClient's own columns use for
	-- PlayerLeyShardConverted.
	playerAstralShardConvertedEvent.OnClientEvent:Connect(function()
		render(getStateRemote:InvokeServer())
	end)
end

local function buildBoard()
	if built then
		return
	end
	built = true

	lockGui:Destroy()

	-- The board sits at Z 100 with plain identity orientation (WorldBuilder,
	-- axis-aligned row along X) - the island's own center is at Z 150, a
	-- larger Z, so the readable face needs its outward normal on local +Z
	-- - "Back" in Roblox's NormalId naming - per direct request ("facing
	-- towards the miiddle of the 3rd island").
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "AstralShardUpgradeBoardGui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.Adornee = board
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = board

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(35, 25, 60)
	background.BackgroundTransparency = 0.55
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

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

	local currencyReadoutText = Instance.new("TextLabel")
	currencyReadoutText.Size = UDim2.new(1, -26, 1, 0)
	currencyReadoutText.Position = UDim2.new(0, 26, 0, 0)
	currencyReadoutText.BackgroundTransparency = 1
	currencyReadoutText.Font = Enum.Font.GothamBold
	currencyReadoutText.TextScaled = true
	currencyReadoutText.TextColor3 = Color3.fromRGB(255, 255, 255)
	currencyReadoutText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	currencyReadoutText.Text = "0"
	currencyReadoutText.Parent = currencyReadout

	local readoutIconHolder = Instance.new("Frame")
	readoutIconHolder.AnchorPoint = Vector2.new(0, 0.5)
	readoutIconHolder.Position = UDim2.new(0, -22, 0.5, 0)
	readoutIconHolder.Size = UDim2.new(0, 32, 0, 32)
	readoutIconHolder.Rotation = 45
	readoutIconHolder.BackgroundColor3 = ASTRAL_SHARD_COLOR
	readoutIconHolder.ZIndex = 2
	readoutIconHolder.Parent = currencyReadout

	local readoutIconCorner = Instance.new("UICorner")
	readoutIconCorner.CornerRadius = UDim.new(0.2, 0)
	readoutIconCorner.Parent = readoutIconHolder

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
	titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(35, 25, 70)
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
	titleText.TextColor3 = ASTRAL_SHARD_COLOR
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = "Astral Shard"
	titleText.Parent = titleBanner

	createUpgradeColumn(background, 1, "More Ley Shard", buildGemIcon(LEY_SHARD_COLOR), getAstralShardLeyBoostStateFunction, buyAstralShardLeyBoostUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
		end
		return ("%.1fx (MAX)"):format(state.multiplier)
	end)

	createUpgradeColumn(background, 2, "More Astral Shards", buildGemIcon(ASTRAL_SHARD_COLOR), getAstralShardConversionBoostStateFunction, buyAstralShardConversionBoostUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
		end
		return ("%.1fx (MAX)"):format(state.multiplier)
	end)

	-- Slot 3 stays an empty "Coming Soon" placeholder for now - per direct
	-- request ("lets just start with those two upgrades").
	local column = Instance.new("Frame")
	column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.62, 0)
	column.Position = UDim2.new(COLUMN_START_X + 2 * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
	column.BackgroundTransparency = 1
	column.Parent = background

	local iconFrame = Instance.new("Frame")
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Size = UDim2.new(0.4, 0, 0.22, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.BackgroundTransparency = 1
	iconFrame.Parent = column

	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.Parent = iconFrame

	local diamond = Instance.new("Frame")
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(0.5, 0, 0.5, 0)
	diamond.Size = UDim2.new(0.7, 0, 0.7, 0)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	diamond.BackgroundTransparency = 0.7
	diamond.BorderSizePixel = 0
	diamond.Parent = iconFrame

	local diamondCorner = Instance.new("UICorner")
	diamondCorner.CornerRadius = UDim.new(0.2, 0)
	diamondCorner.Parent = diamond

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.09, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.28, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = "???"
	nameLabel.Parent = column

	local comingSoonLabel = Instance.new("TextLabel")
	comingSoonLabel.Size = UDim2.new(1, 0, 0.1, 0)
	comingSoonLabel.Position = UDim2.new(0, 0, 0.45, 0)
	comingSoonLabel.BackgroundTransparency = 1
	comingSoonLabel.Font = Enum.Font.Gotham
	comingSoonLabel.TextScaled = true
	comingSoonLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	comingSoonLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	comingSoonLabel.Text = "Coming Soon"
	comingSoonLabel.Parent = column

	astralShardUpdatedEvent.OnClientEvent:Connect(function(amount)
		currencyReadoutText.Text = NumberFormat.format(amount)
	end)
end

local function checkAndBuild()
	local success, state = pcall(function()
		return getEtherIslandStateFunction:InvokeServer()
	end)
	if success and state and state.unlocked then
		buildBoard()
	end
end

checkAndBuild()

playerEtherIslandUnlockedEvent.OnClientEvent:Connect(checkAndBuild)
