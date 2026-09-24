-- Builds the Ley Shard upgrade board (Workspace.LeyShardUpgradeBoard) on
-- EtherIsland: a small clear icon + amount readout above a "Ley Shard
-- Upgrades" title banner, then 3 columns filling the board edge-to-edge -
-- "More Ley Shard" (100 levels, the core yield), "Faster Levitation" (10
-- levels, how often a levitating player gets paid), and "More Mana" (50
-- levels, a flat Mana Per Pickup multiplier) - per direct request ("Make
-- the card have upgrades up to 100 for the material... 10 upgrades of
-- fast speed and third upgrade do more mana please up to 50"). Same
-- createUpgradeColumn template every other currency board uses (level/
-- max/nextLevelCost, Buy+Max buttons). Card 1 of a planned 3-card
-- wizard-material progression - naming/theming here is my own call.
-- Doesn't build AT ALL until `GetEtherIslandState().unlocked` is true for
-- this player, same reasoning as EtherUpgradeBoardClient: the mat/board
-- Parts themselves are already solid/visible (nothing on EtherIsland needs
-- per-player hiding, since the island's own gate is what's locked), but a
-- SurfaceGui would still render on the board even for someone who
-- shouldn't be able to buy anything yet. Converting Ley Shard into Astral
-- Shard (the Conversion board) resets all 3 of these columns back to
-- level 1 - per direct request ("when you exchange them it totally
-- resets your ley shard upgrades all 3") - so this also re-fetches every
-- column on the new `PlayerLeyShardConverted` event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherIslandStateFunction = remotes:WaitForChild("GetEtherIslandState")
local playerEtherIslandUnlockedEvent = remotes:WaitForChild("PlayerEtherIslandUnlocked")
local getLeyShardYieldStateFunction = remotes:WaitForChild("GetLeyShardYieldState")
local buyLeyShardYieldUpgradeFunction = remotes:WaitForChild("BuyLeyShardYieldUpgrade")
local getLeyShardSpeedStateFunction = remotes:WaitForChild("GetLeyShardSpeedState")
local buyLeyShardSpeedUpgradeFunction = remotes:WaitForChild("BuyLeyShardSpeedUpgrade")
local getLeyShardManaBoostStateFunction = remotes:WaitForChild("GetLeyShardManaBoostState")
local buyLeyShardManaBoostUpgradeFunction = remotes:WaitForChild("BuyLeyShardManaBoostUpgrade")
local leyShardUpdatedEvent = remotes:WaitForChild("LeyShardUpdated")
local playerLeyShardConvertedEvent = remotes:WaitForChild("PlayerLeyShardConverted")

local board = Workspace:WaitForChild("LeyShardUpgradeBoard")

local LEY_SHARD_COLOR = Color3.fromRGB(90, 220, 190)
local MANA_ICON_ID = "rbxassetid://119417928367783"

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

-- The board sits at Z 100 with plain identity orientation (WorldBuilder,
-- axis-aligned row along X) - the island's own center is at Z 150, a
-- larger Z, so the readable face needs its outward normal on local +Z -
-- "Back" in Roblox's NormalId naming - to actually point toward the
-- island's middle, per direct request ("facing towards the miiddle of
-- the 3rd island").
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "LeyShardUpgradeBoardGui"
surfaceGui.Face = Enum.NormalId.Back
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(20, 55, 50)
background.BackgroundTransparency = 0.55
background.BorderSizePixel = 0

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
currencyReadoutText.Text = "-"
currencyReadoutText.Parent = currencyReadout

-- Small diamond badge next to the readout - no uploaded Ley Shard image
-- yet, so this is a plain shape instead, matching the icon badge every
-- other board's readout carries.
local function addReadoutIcon(parent: Frame)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, -22, 0.5, 0)
	holder.Size = UDim2.new(0, 32, 0, 32)
	holder.Rotation = 45
	holder.BackgroundColor3 = LEY_SHARD_COLOR
	holder.ZIndex = 2
	holder.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = holder
end
addReadoutIcon(currencyReadout)

-- Reused by hand-built column icons below, same helper every other board
-- client keeps its own copy of.
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

-- A gem: a rotated square (diamond) with a smaller, lighter diamond inset
-- for a simple facet highlight. Built from plain UI shapes, no image/
-- glyph, same font-coverage-safe convention as the Mana board's own
-- hand-built icons.
local function buildLeyShardIcon(iconFrame: Frame)
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
	inner.BackgroundColor3 = LEY_SHARD_COLOR
	inner.BorderSizePixel = 0
	inner.Parent = outer

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.25, 0)
	innerCorner.Parent = inner
end

-- A stopwatch (hollow ring, crown nub, hand) - "how often you get paid,"
-- same motif already used for the Mana board's own Spawn Speed column.
local function buildSpeedIcon(iconFrame: Frame)
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

-- Reuses the real Mana icon, same as the Mana board's own "More Mana"
-- column - per the established precedent of pointing at the actual
-- currency's icon rather than inventing a new symbol for it.
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

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(20, 75, 65)
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
titleText.TextColor3 = LEY_SHARD_COLOR
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Ley Shard Upgrades"
titleText.Parent = titleBanner

local function createUpgradeColumn(slotIndex: number, name: string, buildIcon: (Frame) -> (), getStateRemote, buyRemote, formatDetail)
	-- Height shrunk from 0.7 to 0.62 - at 0.7 the column's own bottom edge
	-- (COLUMN_TOP_Y 0.33 + 0.7 = 1.03) actually overflowed past the whole
	-- board's bottom edge, which sits exactly at ground level (the board
	-- Part spans ISLAND_TOP_Y to ISLAND_TOP_Y+18 with no gap below it) -
	-- so the Buy/Max buttons near the bottom of each column were rendering
	-- into the ground itself. Per direct request ("the buy and max
	-- buttons... they are touching the ground on the cards").
	local column = Instance.new("Frame")
	column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.62, 0)
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
	nameLabel.TextColor3 = LEY_SHARD_COLOR
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

	local currentLeyShard = 0
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

		local canAfford = currentLeyShard >= nextLevelCost
		buyButton.Active = canAfford
		maxButton.Active = canAfford
		buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
		maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
	end

	local function render(state)
		if not state then
			return
		end

		currentLeyShard = state.leyShard
		nextLevelCost = state.nextLevelCost

		levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)
		detailLabel.Text = formatDetail(state)
		costLabel.Text = state.nextLevelCost and ("Cost: %s"):format(NumberFormat.format(state.nextLevelCost)) or "Cost: -"

		updateButtonColors()
	end

	render(getStateRemote:InvokeServer())

	leyShardUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentLeyShard = amount
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

	-- Returned so buildBoard can re-fetch this column on demand - converting
	-- Ley Shard into Astral Shard resets all 3 of these levels, and the
	-- board needs to reflect that immediately rather than keep showing
	-- stale pre-reset levels/costs until the next manual interaction.
	local function refresh()
		render(getStateRemote:InvokeServer())
	end
	return refresh
end

local function buildBoard()
	if built then
		return
	end
	built = true

	background.Parent = surfaceGui
	surfaceGui.Parent = board

	local columnRefreshFunctions = {
		createUpgradeColumn(1, "More Ley Shard", buildLeyShardIcon, getLeyShardYieldStateFunction, buyLeyShardYieldUpgradeFunction, function(state)
			if state.nextLevelCost then
				return ("+%s > +%s"):format(NumberFormat.format(state.amountPerPickup), NumberFormat.format(state.nextAmountPerPickup))
			end
			return ("+%s (MAX)"):format(NumberFormat.format(state.amountPerPickup))
		end),

		createUpgradeColumn(2, "Faster Levitation", buildSpeedIcon, getLeyShardSpeedStateFunction, buyLeyShardSpeedUpgradeFunction, function(state)
			if state.nextLevelCost then
				return ("%.1fs > %.1fs"):format(state.intervalSeconds, state.nextIntervalSeconds)
			end
			return ("%.1fs (MAX)"):format(state.intervalSeconds)
		end),

		createUpgradeColumn(3, "More Mana", buildManaIcon, getLeyShardManaBoostStateFunction, buyLeyShardManaBoostUpgradeFunction, function(state)
			if state.nextLevelCost then
				return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
			end
			return ("%.1fx (MAX)"):format(state.multiplier)
		end),
	}

	leyShardUpdatedEvent.OnClientEvent:Connect(function(amount)
		currencyReadoutText.Text = NumberFormat.format(amount)
	end)

	-- Converting Ley Shard into Astral Shard resets all 3 columns above
	-- back to level 1 - re-fetch every one so the board doesn't keep
	-- showing stale pre-reset levels/costs, same "re-fetch on an external
	-- reset event" pattern as ManaUpgradeBoardClient's own
	-- playerRebirthedEvent handling.
	playerLeyShardConvertedEvent.OnClientEvent:Connect(function()
		for _, refresh in columnRefreshFunctions do
			refresh()
		end
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
