-- Builds Card 2's board (Workspace.AstralShardUpgradeBoard) - a small
-- clear amount readout above an "Astral Shard" title banner, then 3 empty
-- "Coming Soon" placeholder slots, no real upgrade logic yet - per direct
-- request ("It should be the material x card with three upgrades but dont
-- put them in yet I just want to see the card"). Astral Shard itself has
-- no collection mechanic of its own; its only source is the conversion
-- board next to this one (see AstralShardConversionBoardClient... actually
-- LeyShardConversionBoardClient - the physical board is named
-- LeyShardConversionBoard). Same "doesn't build at all until unlocked"
-- gating as every other EtherIsland board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherIslandStateFunction = remotes:WaitForChild("GetEtherIslandState")
local playerEtherIslandUnlockedEvent = remotes:WaitForChild("PlayerEtherIslandUnlocked")
local astralShardUpdatedEvent = remotes:WaitForChild("AstralShardUpdated")

local board = Workspace:WaitForChild("AstralShardUpgradeBoard")

local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255)
local TEXT_STROKE_TRANSPARENCY = 0.4

local COLUMN_WIDTH = 0.29
local COLUMN_GAP = 0.03
local COLUMN_START_X = 0.03
local COLUMN_TOP_Y = 0.33

local built = false

local function buildBoard()
	if built then
		return
	end
	built = true

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

	-- 3 empty slots - a faded diamond icon, "???" for the name, and
	-- "Coming Soon" where a level/cost would go. No buttons at all, since
	-- there's nothing to buy yet.
	for slotIndex = 1, 3 do
		local column = Instance.new("Frame")
		column.Size = UDim2.new(COLUMN_WIDTH, 0, 0.7, 0)
		column.Position = UDim2.new(COLUMN_START_X + (slotIndex - 1) * (COLUMN_WIDTH + COLUMN_GAP), 0, COLUMN_TOP_Y, 0)
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
	end

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
