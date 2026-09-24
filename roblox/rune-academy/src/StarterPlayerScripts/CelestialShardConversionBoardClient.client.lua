-- Builds the new converter card (Workspace.CelestialShardConversionBoard):
-- the only way to actually get Celestial Shard, since Card 3 has no
-- collection mechanic of its own - same role LeyShardConversionBoardClient
-- plays one tier down. Per direct request ("Okay time to do celestial
-- shard. It should cost 5 million astra shroud for 1 celestrial... make a
-- converter card to the left. of the celestrial upgarade card"). Shows the
-- live rate (5,000,000 Astral Shard = N Celestial Shard, N climbing with
-- Card 3's own "More Celestial Shard" upgrade), live Astral Shard/Celestial
-- Shard readouts, a reset warning, and one "Convert" button that spends AS
-- MANY 5,000,000-Astral-Shard units as currently affordable in one press -
-- same "spend it all in one press" call as the Ley->Astral conversion.
-- Converting also completely resets the Astral Shard board's own 2 levels
-- back to 1 (CelestialShardConversionHandler.convert does this
-- server-side) - per direct request, "hitting this converter completely
-- resets your astral shards" - hence the warning text. Gold themed to
-- match the Celestial Shard board right next to it. Waits in a blocking
-- loop on `GetCelestialShardState().unlocked` before building anything at
-- all, same "look locked until you actually unlock it" pattern as every
-- other gated board in this game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getCelestialShardStateFunction = remotes:WaitForChild("GetCelestialShardState")
local getCelestialShardConversionStateFunction = remotes:WaitForChild("GetCelestialShardConversionState")
local convertAstralShardToCelestialShardFunction = remotes:WaitForChild("ConvertAstralShardToCelestialShard")
local astralShardUpdatedEvent = remotes:WaitForChild("AstralShardUpdated")
local leyShardFloorTileBoughtEvent = remotes:WaitForChild("LeyShardFloorTileBought")

local board = Workspace:WaitForChild("CelestialShardConversionBoard")

local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255)
local GOLD = Color3.fromRGB(255, 215, 0)
local COLOR_CAN_CONVERT = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_CONVERT = Color3.fromRGB(200, 55, 55)
local TEXT_STROKE_TRANSPARENCY = 0.4

-- Waits (without building anything) until Tile 4 is actually bought - same
-- "look locked until you unlock it" reasoning as CelestialShardBoardClient
-- right next to this board.
while true do
	local state = getCelestialShardStateFunction:InvokeServer()
	if state and state.unlocked then
		break
	end
	task.wait(1)
end

-- Same rotation AND same Size shape as CelestialShardBoard (thickness on
-- local Z, not local X) - same Front face fix as that board, see its own
-- client's header comment for why Right/Left were both wrong (the thin
-- edge strip, not the actual flat face).
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "CelestialShardConversionBoardGui"
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

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.9, 0, 0.14, 0)
titleBanner.Position = UDim2.new(0.05, 0, 0.06, 0)
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
rateText.Text = "5,000,000 Astral Shard = - Celestial Shard"
rateText.Parent = background

local astralShardReadout = Instance.new("TextLabel")
astralShardReadout.Size = UDim2.new(0.9, 0, 0.1, 0)
astralShardReadout.Position = UDim2.new(0.05, 0, 0.38, 0)
astralShardReadout.BackgroundTransparency = 1
astralShardReadout.Font = Enum.Font.GothamBold
astralShardReadout.TextScaled = true
astralShardReadout.TextColor3 = ASTRAL_SHARD_COLOR
astralShardReadout.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
astralShardReadout.Text = "Astral Shard: -"
astralShardReadout.Parent = background

local celestialShardReadout = Instance.new("TextLabel")
celestialShardReadout.Size = UDim2.new(0.9, 0, 0.1, 0)
celestialShardReadout.Position = UDim2.new(0.05, 0, 0.49, 0)
celestialShardReadout.BackgroundTransparency = 1
celestialShardReadout.Font = Enum.Font.GothamBold
celestialShardReadout.TextScaled = true
celestialShardReadout.TextColor3 = GOLD
celestialShardReadout.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
celestialShardReadout.Text = "Celestial Shard: -"
celestialShardReadout.Parent = background

-- Per direct request ("hitting this converter completely resets your
-- astral shards") - the Astral Shard board's own 2 levels get wiped every
-- time Convert is pressed, so this is called out directly rather than
-- left as a surprise.
local warningText = Instance.new("TextLabel")
warningText.Size = UDim2.new(0.9, 0, 0.08, 0)
warningText.Position = UDim2.new(0.05, 0, 0.6, 0)
warningText.BackgroundTransparency = 1
warningText.Font = Enum.Font.GothamBold
warningText.TextScaled = true
warningText.TextColor3 = Color3.fromRGB(255, 120, 120)
warningText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
warningText.Text = "Resets your Astral Shard upgrades!"
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

	astralShardReadout.Text = ("Astral Shard: %s"):format(NumberFormat.format(state.astralShard))
	celestialShardReadout.Text = ("Celestial Shard: %s"):format(NumberFormat.format(state.celestialShard))
	rateText.Text = ("%s Astral Shard = %.1f Celestial Shard"):format(
		NumberFormat.format(state.costPerCelestialShard),
		state.celestialPerUnit
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

render(getCelestialShardConversionStateFunction:InvokeServer())

astralShardUpdatedEvent.OnClientEvent:Connect(function()
	render(getCelestialShardConversionStateFunction:InvokeServer())
end)

-- Harmless no-op re-fetch for any other tile, but means this board picks
-- up Tile 4's unlock the instant it's bought without requiring a rejoin -
-- same precedent as CelestialShardBoardClient's own listener.
leyShardFloorTileBoughtEvent.OnClientEvent:Connect(function()
	render(getCelestialShardConversionStateFunction:InvokeServer())
end)

convertButton.MouseButton1Click:Connect(function()
	local success, _, newState = convertAstralShardToCelestialShardFunction:InvokeServer()
	if success then
		render(newState)
	end
end)
