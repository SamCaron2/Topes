-- Card 3's board, Celestial Shard (Workspace.CelestialShardBoard) -
-- unlocked by EtherIsland floor Tile 4 (5,000,000 Astral Shard). Named
-- "Celestial Shard" per direct request ("You have to name this final
-- shard") - this game's own long-planned name for Card 3. Gold themed,
-- per direct request ("Maybe make this shard color gold"). A currency
-- readout above a title banner, then 3 real upgrade columns - per direct
-- request ("Okay time to do celestial shard... There are 3 upgrades. More
-- celestrial shard... Then another upgrade 0-25 for more astral cards...
-- FInally 0-50 on more mana"): "More Celestial Shard"
-- (CelestialConversionBoostHandler, 1-50) boosts how many Celestial Shard
-- each conversion grants, "More Astral Shard" (CelestialAstralBoostHandler,
-- 1-25) boosts the Ley->Astral conversion rate one tier down, and "More
-- Mana" (CelestialManaBoostHandler, 1-50) is a flat Mana Per Pickup
-- multiplier. Same shared `createUpgradeColumn` pattern (level/max/
-- nextLevelCost, Buy+Max buttons) as every other board. Waits in a
-- blocking loop on `GetCelestialShardState().unlocked` before building
-- anything at all, same "look locked until you actually unlock it"
-- pattern as every other gated board in this game.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getCelestialShardStateFunction = remotes:WaitForChild("GetCelestialShardState")
local celestialShardUpdatedEvent = remotes:WaitForChild("CelestialShardUpdated")
local getCelestialConversionBoostStateFunction = remotes:WaitForChild("GetCelestialConversionBoostState")
local buyCelestialConversionBoostUpgradeFunction = remotes:WaitForChild("BuyCelestialConversionBoostUpgrade")
local getCelestialAstralBoostStateFunction = remotes:WaitForChild("GetCelestialAstralBoostState")
local buyCelestialAstralBoostUpgradeFunction = remotes:WaitForChild("BuyCelestialAstralBoostUpgrade")
local getCelestialManaBoostStateFunction = remotes:WaitForChild("GetCelestialManaBoostState")
local buyCelestialManaBoostUpgradeFunction = remotes:WaitForChild("BuyCelestialManaBoostUpgrade")

local board = Workspace:WaitForChild("CelestialShardBoard")

local GOLD = Color3.fromRGB(255, 215, 0)
local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255)
local MANA_COLOR = Color3.fromRGB(120, 200, 255)

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

local COLUMN_WIDTH = 0.29
local COLUMN_GAP = 0.03
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.33

-- Same rotated-square gem icon as AstralShardUpgradeBoardClient's own
-- columns, just recolored per column to point at the currency it affects.
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
	nameLabel.TextColor3 = GOLD
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

	local currentCelestialShard = 0
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

		local canAfford = currentCelestialShard >= nextLevelCost
		buyButton.Active = canAfford
		maxButton.Active = canAfford
		buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
		maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
	end

	local function render(state)
		if not state then
			return
		end

		currentCelestialShard = state.celestialShard
		nextLevelCost = state.nextLevelCost

		levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)
		detailLabel.Text = formatDetail(state)
		costLabel.Text = state.nextLevelCost and ("Cost: %s"):format(NumberFormat.format(state.nextLevelCost)) or "Cost: -"

		updateButtonColors()
	end

	render(getStateRemote:InvokeServer())

	celestialShardUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentCelestialShard = amount
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

-- Waits (without building anything) until Tile 4 is actually bought - per
-- the same "look locked until you unlock it" reasoning as every other
-- gated board here. The board Part itself is always visible/solid; only
-- this SurfaceGui (which renders independent of its host Part's
-- Transparency) is withheld until unlock.
while true do
	local state = getCelestialShardStateFunction:InvokeServer()
	if state and state.unlocked then
		break
	end
	task.wait(1)
end

-- Rotated 90° around Y in WorldBuilder (its long axis runs along Z, not
-- X, unlike the 3-board row) - but its Size is (WIDTH, 18, 1), thickness
-- on local Z, same shape as the UN-rotated 3-board row, NOT RuinRuneBoard
-- (whose Size is (1, 18, WIDTH), thickness on local X instead). Copying
-- RuinRuneBoard's own Face = Right (then Left) both put the SurfaceGui on
-- the thin 1-stud edge strip instead of the actual big flat face - per
-- direct report, both rendered blank ("Why are the cards like this what
-- happened?" / "They are on the wrong side again"). The real flat face
-- normal is along local Z (Back/Front, matching the un-rotated boards),
-- which after this board's own 90° Y-rotation swings to point along world
-- X - Front (local -Z) lands on world -X, the side EtherIsland's floor
-- tiles/main board row approach from.
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "CelestialShardBoardGui"
surfaceGui.Face = Enum.NormalId.Front
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(50, 40, 10)
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
readoutIconHolder.BackgroundColor3 = GOLD
readoutIconHolder.ZIndex = 2
readoutIconHolder.Parent = currencyReadout

local readoutIconCorner = Instance.new("UICorner")
readoutIconCorner.CornerRadius = UDim.new(0.2, 0)
readoutIconCorner.Parent = readoutIconHolder

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(35, 28, 5)
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
titleText.TextColor3 = GOLD
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Celestial Shard"
titleText.Parent = titleBanner

createUpgradeColumn(background, 1, "More Celestial Shard", buildGemIcon(GOLD), getCelestialConversionBoostStateFunction, buyCelestialConversionBoostUpgradeFunction, function(state)
	if state.nextLevelCost then
		return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
	end
	return ("%.1fx (MAX)"):format(state.multiplier)
end)

createUpgradeColumn(background, 2, "More Astral Shard", buildGemIcon(ASTRAL_SHARD_COLOR), getCelestialAstralBoostStateFunction, buyCelestialAstralBoostUpgradeFunction, function(state)
	if state.nextLevelCost then
		return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
	end
	return ("%.1fx (MAX)"):format(state.multiplier)
end)

createUpgradeColumn(background, 3, "More Mana", buildGemIcon(MANA_COLOR), getCelestialManaBoostStateFunction, buyCelestialManaBoostUpgradeFunction, function(state)
	if state.nextLevelCost then
		return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
	end
	return ("%.1fx (MAX)"):format(state.multiplier)
end)

local function refreshCurrencyReadout()
	local state = getCelestialShardStateFunction:InvokeServer()
	if state then
		currencyReadoutText.Text = NumberFormat.format(state.celestialShard or 0)
	end
end

refreshCurrencyReadout()

celestialShardUpdatedEvent.OnClientEvent:Connect(function(amount)
	currencyReadoutText.Text = NumberFormat.format(amount)
end)
