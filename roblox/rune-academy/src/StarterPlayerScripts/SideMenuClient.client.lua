-- The left-side icon column (Shop/Runes/Profile/Settings). Clicking an icon
-- toggles a shared panel frame, building each panel's content lazily from
-- its module the first time it's opened and just hiding/showing it after -
-- keeps every menu behaving the same way instead of each panel owning its
-- own toggle button and position like before.

local Players = game:GetService("Players")

local StorePanel = require(script.Parent.Panels.StorePanel)
local RunePanel = require(script.Parent.Panels.RunePanel)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SideMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local iconColumn = Instance.new("Frame")
iconColumn.AnchorPoint = Vector2.new(0, 0.5)
iconColumn.Position = UDim2.new(0, 12, 0.5, 0)
iconColumn.Size = UDim2.new(0, 56, 0, 0)
iconColumn.AutomaticSize = Enum.AutomaticSize.Y
iconColumn.BackgroundTransparency = 1
iconColumn.Parent = screenGui

local iconLayout = Instance.new("UIListLayout")
iconLayout.SortOrder = Enum.SortOrder.LayoutOrder
iconLayout.Padding = UDim.new(0, 8)
iconLayout.Parent = iconColumn

local panelFrame = Instance.new("Frame")
panelFrame.AnchorPoint = Vector2.new(0, 0.5)
panelFrame.Position = UDim2.new(0, 80, 0.5, 0)
panelFrame.Size = UDim2.new(0, 300, 0, 420)
panelFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panelFrame.BackgroundTransparency = 0.1
panelFrame.Visible = false
panelFrame.Parent = screenGui
Instance.new("UICorner", panelFrame).CornerRadius = UDim.new(0, 12)

local function buildComingSoon(parent: Instance, title: string): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = title .. "\n\nComing soon"
	label.Parent = frame

	return frame
end

local PANEL_BUILDERS = {
	Shop = StorePanel.build,
	Runes = RunePanel.build,
	Profile = function(parent)
		return buildComingSoon(parent, "Profile")
	end,
	Settings = function(parent)
		return buildComingSoon(parent, "Settings")
	end,
}

local builtPanels = {} -- [key] = content Instance, kept alive and just hidden/shown
local currentPanelKey: string? = nil

local function showPanel(key: string)
	for panelKey, content in builtPanels do
		content.Visible = panelKey == key
	end

	if not builtPanels[key] then
		builtPanels[key] = PANEL_BUILDERS[key](panelFrame)
	end

	panelFrame.Visible = true
	currentPanelKey = key
end

local function toggleIcon(key: string)
	if currentPanelKey == key and panelFrame.Visible then
		panelFrame.Visible = false
		currentPanelKey = nil
	else
		showPanel(key)
	end
end

local ICONS = {
	{ key = "Shop", label = "Shop", color = Color3.fromRGB(60, 150, 90) },
	{ key = "Runes", label = "Runes", color = Color3.fromRGB(190, 130, 50) },
	{ key = "Profile", label = "Profile", color = Color3.fromRGB(80, 120, 200) },
	{ key = "Settings", label = "Settings", color = Color3.fromRGB(120, 120, 130) },
}

for index, icon in ICONS do
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Size = UDim2.new(0, 56, 0, 56)
	button.BackgroundColor3 = icon.color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = true
	button.Text = icon.label
	button.Parent = iconColumn
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

	button.MouseButton1Click:Connect(function()
		toggleIcon(icon.key)
	end)
end
