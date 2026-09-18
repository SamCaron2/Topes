-- Builds the Rebirths board: explains the mechanic (1,000 Mana = 1 Rebirth,
-- fractional), shows the player's current total and a live preview of what
-- rebirthing right now would give them, and a Rebirth button. Same
-- SurfaceGui-on-a-physical-face approach as the Mana Upgrades board, for
-- the same reason - a BillboardGui would visibly slide around as the
-- camera orbits past it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getRebirthStateFunction = remotes:WaitForChild("GetRebirthState")
local performRebirthFunction = remotes:WaitForChild("PerformRebirth")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("RebirthBoard")

local COLOR_CAN_REBIRTH = Color3.fromRGB(150, 80, 255)
local COLOR_CANT_REBIRTH = Color3.fromRGB(200, 55, 55)
local TEXT_STROKE_TRANSPARENCY = 0.4

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "RebirthBoardGui"
surfaceGui.Face = Enum.NormalId.Left
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(70, 60, 100)
background.BorderSizePixel = 0
background.Parent = surfaceGui

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.9, 0, 0.15, 0)
titleBanner.Position = UDim2.new(0.05, 0, 0.03, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(45, 30, 70)
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
titleText.TextColor3 = Color3.fromRGB(220, 180, 255)
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Rebirths"
titleText.Parent = titleBanner

local explainerLabel = Instance.new("TextLabel")
explainerLabel.Size = UDim2.new(0.9, 0, 0.16, 0)
explainerLabel.Position = UDim2.new(0.05, 0, 0.22, 0)
explainerLabel.BackgroundTransparency = 1
explainerLabel.Font = Enum.Font.Gotham
explainerLabel.TextScaled = true
explainerLabel.TextWrapped = true
explainerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
explainerLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
explainerLabel.Text = "Reset your Mana for Rebirths, a permanent currency for stronger upgrades later."
explainerLabel.Parent = background

local rateLabel = Instance.new("TextLabel")
rateLabel.Size = UDim2.new(0.9, 0, 0.09, 0)
rateLabel.Position = UDim2.new(0.05, 0, 0.4, 0)
rateLabel.BackgroundTransparency = 1
rateLabel.Font = Enum.Font.GothamBold
rateLabel.TextScaled = true
rateLabel.TextColor3 = Color3.fromRGB(220, 180, 255)
rateLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
rateLabel.Text = "1,000 Mana = 1 Rebirth"
rateLabel.Parent = background

local totalLabel = Instance.new("TextLabel")
totalLabel.Size = UDim2.new(0.9, 0, 0.09, 0)
totalLabel.Position = UDim2.new(0.05, 0, 0.51, 0)
totalLabel.BackgroundTransparency = 1
totalLabel.Font = Enum.Font.Gotham
totalLabel.TextScaled = true
totalLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
totalLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
totalLabel.Text = "Your Rebirths: -"
totalLabel.Parent = background

local previewLabel = Instance.new("TextLabel")
previewLabel.Size = UDim2.new(0.9, 0, 0.09, 0)
previewLabel.Position = UDim2.new(0.05, 0, 0.62, 0)
previewLabel.BackgroundTransparency = 1
previewLabel.Font = Enum.Font.GothamBold
previewLabel.TextScaled = true
previewLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
previewLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
previewLabel.Text = "Rebirth now for +- Rebirths"
previewLabel.Parent = background

local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(0.7, 0, 0.16, 0)
rebirthButton.Position = UDim2.new(0.15, 0, 0.78, 0)
rebirthButton.BackgroundColor3 = COLOR_CAN_REBIRTH
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
rebirthButton.Text = "Rebirth"
rebirthButton.Parent = background

local rebirthButtonCorner = Instance.new("UICorner")
rebirthButtonCorner.CornerRadius = UDim.new(0.3, 0)
rebirthButtonCorner.Parent = rebirthButton

local rebirthButtonPadding = Instance.new("UIPadding")
rebirthButtonPadding.PaddingTop = UDim.new(0.2, 0)
rebirthButtonPadding.PaddingBottom = UDim.new(0.2, 0)
rebirthButtonPadding.Parent = rebirthButton

local currentMana = 0
local minManaToRebirth = 1000
local manaPerRebirth = 1000

local function updateButton()
	local canRebirth = currentMana >= minManaToRebirth
	rebirthButton.Active = canRebirth
	rebirthButton.BackgroundColor3 = canRebirth and COLOR_CAN_REBIRTH or COLOR_CANT_REBIRTH
end

local function render(state)
	if not state then
		return
	end

	currentMana = state.mana
	minManaToRebirth = state.minManaToRebirth
	manaPerRebirth = state.manaPerRebirth

	totalLabel.Text = ("Your Rebirths: %.1f"):format(state.rebirths)
	previewLabel.Text = ("Rebirth now for +%.1f Rebirths"):format(state.rebirthPreview)

	updateButton()
end

render(getRebirthStateFunction:InvokeServer())

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentMana = amount
	previewLabel.Text = ("Rebirth now for +%.1f Rebirths"):format(amount / manaPerRebirth)
	updateButton()
end)

rebirthButton.MouseButton1Click:Connect(function()
	local success, _, newState = performRebirthFunction:InvokeServer()
	if success then
		render(newState)
	end
end)
