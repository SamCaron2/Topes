-- Card 3's board, Celestial Shard (Workspace.CelestialShardBoard) -
-- unlocked by EtherIsland floor Tile 4 (5,000,000 Astral Shard). Per
-- direct request ("You have to name this final shard"), named "Celestial
-- Shard" - this game's own long-planned name for Card 3 (see
-- LeyShardHandler.lua's own header comment: "Astral Shard" and
-- "Celestial Shard" are the planned names for cards 2 and 3"). Gold
-- themed, per direct request ("Maybe make this shard color gold"). Per
-- direct request ("For the time being it wont have any upgrades") this
-- is deliberately just a currency readout above a "Coming Soon" message -
-- same placeholder-shell treatment Card 2's own board used when it first
-- went up, before its own 2 real upgrade columns existed. Waits in a
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
local leyShardFloorTileBoughtEvent = remotes:WaitForChild("LeyShardFloorTileBought")

local board = Workspace:WaitForChild("CelestialShardBoard")

local GOLD = Color3.fromRGB(255, 215, 0)
local TEXT_STROKE_TRANSPARENCY = 0.4

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
-- X, unlike the 3-board row) - same rotation formula RuinRuneHandler's
-- own board uses, so "Right" is the same guess that board's own client
-- makes for its readable face; flip to Left if it renders backwards.
local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "CelestialShardBoardGui"
surfaceGui.Face = Enum.NormalId.Right
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

-- Same clear-readout template as every other board, denominated in
-- Celestial Shard - stays at 0 for now since there's no way to earn it
-- yet, per direct request ("For the time being it wont have any
-- upgrades").
local currencyReadout = Instance.new("Frame")
currencyReadout.Size = UDim2.new(0.7, 0, 0.06, 0)
currencyReadout.Position = UDim2.new(0.15, 0, 0.06, 0)
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
currencyReadoutText.Text = "0"
currencyReadoutText.Parent = currencyReadout

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.16, 0)
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

-- Same "Coming Soon" placeholder styling as Card 2's own board used for
-- its still-empty 3rd column, just filling the whole board here since
-- every column is still empty.
local comingSoonLabel = Instance.new("TextLabel")
comingSoonLabel.Size = UDim2.new(0.9, 0, 0.2, 0)
comingSoonLabel.Position = UDim2.new(0.05, 0, 0.55, 0)
comingSoonLabel.BackgroundTransparency = 1
comingSoonLabel.Font = Enum.Font.Gotham
comingSoonLabel.TextScaled = true
comingSoonLabel.TextColor3 = Color3.fromRGB(200, 190, 150)
comingSoonLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
comingSoonLabel.Text = "Coming Soon"
comingSoonLabel.Parent = background

-- Re-fetches on every floor tile purchase broadcast rather than only
-- once on load - harmless no-op for tiles 1-3/5, but means this board's
-- readout would pick up a live celestialShard value the instant a future
-- update adds one, without requiring a rejoin.
leyShardFloorTileBoughtEvent.OnClientEvent:Connect(function()
	local state = getCelestialShardStateFunction:InvokeServer()
	if state then
		currencyReadoutText.Text = NumberFormat.format(state.celestialShard or 0)
	end
end)
