-- Builds Card 3 (Workspace.LeyShardConversionBoard): the only way to
-- actually get Astral Shard, since Card 2 has no collection mechanic of
-- its own - per direct request ("a card next to that where you can
-- convert your ley shards into that"). Shows the live rate (1,000 Ley
-- Shard = N Astral Shard, N climbing with Card 2's own "More Astral
-- Shards" upgrade - lowered from an original flat 5,000-per-1 per direct
-- request, "Lets make it actually 1k ley shards for astral"), live Ley
-- Shard/Astral Shard readouts, a reset warning, and one "Convert" button
-- that spends AS MANY 1,000-Ley-Shard units as currently affordable in
-- one press (my own call - not specified - since a fixed 1-per-click
-- would take many repeated presses to spend down a large Ley Shard
-- balance). Converting also totally resets the Ley Shard board's own 3
-- levels back to 1 (AstralShardConversionHandler.convert does this
-- server-side) - per direct request, "when you exchange them it totally
-- resets your ley shard upgrades all 3" - hence the warning text. Same
-- "doesn't build at all until unlocked" gating as every other EtherIsland
-- board.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherIslandStateFunction = remotes:WaitForChild("GetEtherIslandState")
local playerEtherIslandUnlockedEvent = remotes:WaitForChild("PlayerEtherIslandUnlocked")
local getAstralShardConversionStateFunction = remotes:WaitForChild("GetAstralShardConversionState")
local convertLeyShardToAstralShardFunction = remotes:WaitForChild("ConvertLeyShardToAstralShard")
local leyShardUpdatedEvent = remotes:WaitForChild("LeyShardUpdated")

local board = Workspace:WaitForChild("LeyShardConversionBoard")

local LEY_SHARD_COLOR = Color3.fromRGB(90, 220, 190)
local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255)
local COLOR_CAN_CONVERT = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_CONVERT = Color3.fromRGB(200, 55, 55)
local TEXT_STROKE_TRANSPARENCY = 0.4

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
	surfaceGui.Name = "LeyShardConversionBoardGui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.Adornee = board
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = board

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(30, 45, 55)
	background.BackgroundTransparency = 0.55
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.9, 0, 0.14, 0)
	titleBanner.Position = UDim2.new(0.05, 0, 0.06, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(25, 40, 55)
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
	titleText.Text = "Convert Shards"
	titleText.Parent = titleBanner

	local rateText = Instance.new("TextLabel")
	rateText.Size = UDim2.new(0.9, 0, 0.1, 0)
	rateText.Position = UDim2.new(0.05, 0, 0.24, 0)
	rateText.BackgroundTransparency = 1
	rateText.Font = Enum.Font.Gotham
	rateText.TextScaled = true
	rateText.TextColor3 = Color3.fromRGB(255, 255, 255)
	rateText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	rateText.Text = "1,000 Ley Shard = - Astral Shard"
	rateText.Parent = background

	local leyShardReadout = Instance.new("TextLabel")
	leyShardReadout.Size = UDim2.new(0.9, 0, 0.1, 0)
	leyShardReadout.Position = UDim2.new(0.05, 0, 0.38, 0)
	leyShardReadout.BackgroundTransparency = 1
	leyShardReadout.Font = Enum.Font.GothamBold
	leyShardReadout.TextScaled = true
	leyShardReadout.TextColor3 = LEY_SHARD_COLOR
	leyShardReadout.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	leyShardReadout.Text = "Ley Shard: -"
	leyShardReadout.Parent = background

	local astralShardReadout = Instance.new("TextLabel")
	astralShardReadout.Size = UDim2.new(0.9, 0, 0.1, 0)
	astralShardReadout.Position = UDim2.new(0.05, 0, 0.49, 0)
	astralShardReadout.BackgroundTransparency = 1
	astralShardReadout.Font = Enum.Font.GothamBold
	astralShardReadout.TextScaled = true
	astralShardReadout.TextColor3 = ASTRAL_SHARD_COLOR
	astralShardReadout.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	astralShardReadout.Text = "Astral Shard: -"
	astralShardReadout.Parent = background

	-- Per direct request ("when you exchange them it totally resets your
	-- ley shard upgrades all 3") - the Ley Shard board's own 3 levels get
	-- wiped every time Convert is pressed, so this is called out directly
	-- rather than left as a surprise.
	local warningText = Instance.new("TextLabel")
	warningText.Size = UDim2.new(0.9, 0, 0.08, 0)
	warningText.Position = UDim2.new(0.05, 0, 0.6, 0)
	warningText.BackgroundTransparency = 1
	warningText.Font = Enum.Font.GothamBold
	warningText.TextScaled = true
	warningText.TextColor3 = Color3.fromRGB(255, 120, 120)
	warningText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	warningText.Text = "Resets your Ley Shard upgrades!"
	warningText.Parent = background

	local convertButton = Instance.new("TextButton")
	convertButton.Size = UDim2.new(0.7, 0, 0.16, 0)
	convertButton.Position = UDim2.new(0.15, 0, 0.68, 0)
	convertButton.BackgroundColor3 = COLOR_CANT_CONVERT
	convertButton.Font = Enum.Font.GothamBold
	convertButton.TextScaled = true
	convertButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	convertButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	convertButton.Text = "Convert"
	convertButton.Parent = background

	local convertButtonCorner = Instance.new("UICorner")
	convertButtonCorner.CornerRadius = UDim.new(0.3, 0)
	convertButtonCorner.Parent = convertButton

	local convertButtonPadding = Instance.new("UIPadding")
	convertButtonPadding.PaddingTop = UDim.new(0.15, 0)
	convertButtonPadding.PaddingBottom = UDim.new(0.15, 0)
	convertButtonPadding.PaddingLeft = UDim.new(0.1, 0)
	convertButtonPadding.PaddingRight = UDim.new(0.1, 0)
	convertButtonPadding.Parent = convertButton

	local function render(state)
		if not state then
			return
		end

		leyShardReadout.Text = ("Ley Shard: %s"):format(NumberFormat.format(state.leyShard))
		astralShardReadout.Text = ("Astral Shard: %s"):format(NumberFormat.format(state.astralShard))
		rateText.Text = ("%s Ley Shard = %.1f Astral Shard"):format(
			NumberFormat.format(state.costPerAstralShard),
			state.astralPerUnit
		)

		if state.convertibleNow > 0 then
			convertButton.Active = true
			convertButton.BackgroundColor3 = COLOR_CAN_CONVERT
			convertButton.Text = ("Convert (%s)"):format(NumberFormat.format(state.convertibleNow))
		else
			convertButton.Active = false
			convertButton.BackgroundColor3 = COLOR_CANT_CONVERT
			convertButton.Text = "Convert"
		end
	end

	render(getAstralShardConversionStateFunction:InvokeServer())

	leyShardUpdatedEvent.OnClientEvent:Connect(function()
		render(getAstralShardConversionStateFunction:InvokeServer())
	end)

	convertButton.MouseButton1Click:Connect(function()
		local success, _, newState = convertLeyShardToAstralShardFunction:InvokeServer()
		if success then
			render(newState)
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
