-- The Settings panel: opened by clicking the Settings icon
-- (SideMenuClient fires OpenSettingsRequested) - per direct request ("add
-- some relevant settings in the settings section"), since it previously
-- did nothing at all when clicked, same gap the Runes icon had. Two
-- session-only toggles (ClientSettings) picked as the two settings that
-- actually have a visible effect on something already built in this game:
-- "Reduce Effects" (turns the glow mushrooms' PointLights on/off - this
-- game's only real-time lights) and "Collection Popups" (the Rune Altar's
-- floating "+N RankName" text, RuneAltarClient). Neither is saved
-- server-side - they reset on rejoin, same as any other local display
-- preference.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientSettings = require(ReplicatedStorage.Modules.ClientSettings)

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_ON = Color3.fromRGB(70, 190, 60)
local COLOR_OFF = Color3.fromRGB(90, 90, 90)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel = 0
dim.Active = true -- Frames don't block input by default - without this, clicks would pass through to the side menu icons underneath
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 420, 0, 320)
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 2
panelStroke.Color = GOLD
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Position = UDim2.new(0, 20, 0, 16)
titleLabel.Size = UDim2.new(0, 200, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = GOLD
titleLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleLabel.Text = "Settings"
titleLabel.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -20, 0, 16)
closeButton.Size = UDim2.new(0, 100, 0, 36)
closeButton.BackgroundColor3 = Color3.fromRGB(90, 20, 20)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "Close"
closeButton.Parent = panel

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(0.3, 0)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

local rowsFrame = Instance.new("Frame")
rowsFrame.Position = UDim2.new(0, 20, 0, 70)
rowsFrame.Size = UDim2.new(1, -40, 1, -90)
rowsFrame.BackgroundTransparency = 1
rowsFrame.Parent = panel

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Padding = UDim.new(0, 12)
rowsLayout.Parent = rowsFrame

-- One row per toggle: a label/description on the left, an On/Off pill
-- button on the right. `getValue`/`setValue` read and write ClientSettings.
local function createToggleRow(layoutOrder: number, name: string, description: string, getValue: () -> boolean, setValue: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BackgroundTransparency = 0.92
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = rowsFrame

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0.15, 0)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.62, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0.04, 0, 0.08, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = name
	nameLabel.Parent = row

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Size = UDim2.new(0.62, 0, 0.36, 0)
	descriptionLabel.Position = UDim2.new(0.04, 0, 0.56, 0)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.TextScaled = true
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	descriptionLabel.Text = description
	descriptionLabel.Parent = row

	local toggleButton = Instance.new("TextButton")
	toggleButton.AnchorPoint = Vector2.new(1, 0.5)
	toggleButton.Position = UDim2.new(0.96, 0, 0.5, 0)
	toggleButton.Size = UDim2.new(0, 90, 0, 36)
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextScaled = true
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	toggleButton.Parent = row

	local toggleButtonCorner = Instance.new("UICorner")
	toggleButtonCorner.CornerRadius = UDim.new(0.3, 0)
	toggleButtonCorner.Parent = toggleButton

	local function refresh()
		local on = getValue()
		toggleButton.Text = on and "On" or "Off"
		toggleButton.BackgroundColor3 = on and COLOR_ON or COLOR_OFF
	end

	toggleButton.MouseButton1Click:Connect(function()
		setValue(not getValue())
		refresh()
	end)

	refresh()
end

createToggleRow(
	1,
	"Reduce Effects",
	"Turns off glowing mushroom lights (SecondIsland) for better performance.",
	function()
		return ClientSettings.reducedEffects
	end,
	ClientSettings.setReducedEffects
)

createToggleRow(
	2,
	"Collection Popups",
	"Shows the floating +N Rune text when standing on the Rune Altar.",
	function()
		return ClientSettings.collectionPopupsEnabled
	end,
	ClientSettings.setCollectionPopupsEnabled
)

local sideMenuHUD = player:WaitForChild("PlayerGui"):WaitForChild("SideMenuHUD")
local openSettingsEvent = sideMenuHUD:WaitForChild("OpenSettingsRequested")

openSettingsEvent.Event:Connect(function()
	screenGui.Enabled = not screenGui.Enabled
end)
