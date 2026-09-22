-- Builds the Ether upgrade board (Workspace.EtherArea.EtherUpgradeBoard):
-- a small clear icon + amount readout (no "Ether" word) above an "Ether
-- Upgrades" title banner, then 3 columns filling the board edge-to-edge -
-- "More Ether" (100 levels), "Click Speed" (10 levels, how often the
-- Shroud pays out per click), and "More Dust" (50 levels, boosts Arcane
-- Dust yield, mirroring the Arcane Dust board's own "More Mana" column).
-- Same createUpgradeColumn pattern as every other board, just costed in
-- Ether. Themed purple throughout, per direct request. Unlike every other
-- board, this one doesn't build AT ALL until `GetEtherUnlocked` reports
-- true for this player - the physical board Part is already hidden
-- per-player by EtherAreaClient, but that alone wouldn't stop a
-- SurfaceGui from still rendering on it, so the UI itself waits on the
-- same unlock check before it ever gets created.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherUnlockedFunction = remotes:WaitForChild("GetEtherUnlocked")
local getEtherYieldStateFunction = remotes:WaitForChild("GetEtherYieldState")
local buyEtherYieldUpgradeFunction = remotes:WaitForChild("BuyEtherYieldUpgrade")
local getEtherClickSpeedStateFunction = remotes:WaitForChild("GetEtherClickSpeedState")
local buyEtherClickSpeedUpgradeFunction = remotes:WaitForChild("BuyEtherClickSpeedUpgrade")
local getEtherDustBoostStateFunction = remotes:WaitForChild("GetEtherDustBoostState")
local buyEtherDustBoostUpgradeFunction = remotes:WaitForChild("BuyEtherDustBoostUpgrade")
local etherUpdatedEvent = remotes:WaitForChild("EtherUpdated")
local upgradeTreeTileBoughtEvent = remotes:WaitForChild("UpgradeTreeTileBought")

local board = Workspace:WaitForChild("EtherArea"):WaitForChild("EtherUpgradeBoard")

local ETHER_COLOR = Color3.fromRGB(150, 60, 220)

local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(200, 55, 55)
local COLOR_MAX_ACTIVE = Color3.fromRGB(240, 210, 40)
local COLOR_MAXED_OUT = Color3.fromRGB(90, 90, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

local COLUMN_WIDTH = 0.3
local COLUMN_GAP = 0.03
local COLUMN_START_X = 0.02
local COLUMN_TOP_Y = 0.33

local built = false

-- The shroud sits at a LOWER X than this board (see WorldBuilder), so the
-- board's readable face needs to point back toward it (-X) - "Left" in
-- Roblox's NormalId naming, the mirror of the Arcane Dust board's "Right".
-- A guess like every other board face here; flip to Right if it renders
-- unreadable from the shroud's side.
local function buildBoard()
	if built then
		return
	end
	built = true

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "EtherUpgradeBoardGui"
	surfaceGui.Face = Enum.NormalId.Left
	surfaceGui.Adornee = board
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = board

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(35, 15, 50)
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
	currencyReadoutText.Size = UDim2.new(1, 0, 1, 0)
	currencyReadoutText.BackgroundTransparency = 1
	currencyReadoutText.Font = Enum.Font.GothamBold
	currencyReadoutText.TextScaled = true
	currencyReadoutText.TextColor3 = Color3.fromRGB(255, 255, 255)
	currencyReadoutText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	currencyReadoutText.Text = "-"
	currencyReadoutText.Parent = currencyReadout

	etherUpdatedEvent.OnClientEvent:Connect(function(amount)
		currencyReadoutText.Text = NumberFormat.format(amount)
	end)

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
	titleBanner.Position = UDim2.new(0.03, 0, 0.1, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(25, 10, 40)
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
	titleText.TextColor3 = ETHER_COLOR
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = "Ether Upgrades"
	titleText.Parent = titleBanner

	local function createUpgradeColumn(slotIndex: number, name: string, iconColor: Color3, getStateRemote, buyRemote, formatDetail)
		local column = Instance.new("Frame")
		column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.7, 0)
		column.Position = UDim2.new(COLUMN_START_X + (slotIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
		column.BackgroundTransparency = 1
		column.Parent = background

		local iconFrame = Instance.new("Frame")
		iconFrame.AnchorPoint = Vector2.new(0.5, 0)
		iconFrame.Size = UDim2.new(0.4, 0, 0.22, 0)
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
		nameLabel.TextColor3 = ETHER_COLOR
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
		buyButton.Position = UDim2.new(0, 0, 0.7, 0)
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
		maxButton.Position = UDim2.new(0.54, 0, 0.7, 0)
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
		local MAXED_POSITION = UDim2.new(0, 0, 0.7, 0)

		local currentEther = 0
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

			local canAfford = currentEther >= nextLevelCost
			buyButton.Active = canAfford
			maxButton.Active = canAfford
			buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
			maxButton.BackgroundColor3 = canAfford and COLOR_MAX_ACTIVE or COLOR_CANT_AFFORD
		end

		local function render(state)
			if not state then
				return
			end

			currentEther = state.ether
			nextLevelCost = state.nextLevelCost

			levelLabel.Text = ("(%d/%d)"):format(state.level, state.maxLevel)
			detailLabel.Text = formatDetail(state)
			costLabel.Text = state.nextLevelCost and ("Cost: %s Ether"):format(NumberFormat.format(state.nextLevelCost)) or "Cost: -"

			updateButtonColors()
		end

		render(getStateRemote:InvokeServer())

		etherUpdatedEvent.OnClientEvent:Connect(function(amount)
			currentEther = amount
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

	createUpgradeColumn(1, "More Ether", ETHER_COLOR, getEtherYieldStateFunction, buyEtherYieldUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("+%s > +%s"):format(NumberFormat.format(state.amountPerPickup), NumberFormat.format(state.nextAmountPerPickup))
		end
		return ("+%s (MAX)"):format(NumberFormat.format(state.amountPerPickup))
	end)

	createUpgradeColumn(2, "Click Speed", Color3.fromRGB(190, 140, 255), getEtherClickSpeedStateFunction, buyEtherClickSpeedUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("Every %.1fs > %.1fs"):format(state.cooldownSeconds, state.nextCooldownSeconds)
		end
		return ("Every %.1fs (MAX)"):format(state.cooldownSeconds)
	end)

	createUpgradeColumn(3, "More Dust", Color3.fromRGB(120, 90, 220), getEtherDustBoostStateFunction, buyEtherDustBoostUpgradeFunction, function(state)
		if state.nextLevelCost then
			return ("%.1fx > %.1fx"):format(state.multiplier, state.nextMultiplier)
		end
		return ("%.1fx (MAX)"):format(state.multiplier)
	end)
end

local function checkAndBuild()
	local success, unlocked = pcall(function()
		return getEtherUnlockedFunction:InvokeServer()
	end)
	if success and unlocked then
		buildBoard()
	end
end

checkAndBuild()

-- Fires on every Upgrade Tree tile purchase (Tile 9 included) - re-checking
-- builds the board immediately once Ether is unlocked, no rejoin needed.
upgradeTreeTileBoughtEvent.OnClientEvent:Connect(checkAndBuild)
