-- Right-side icon menu: Store, Runes, Profile, Settings. Placeholder symbol
-- icons (safe basic Unicode glyphs, not emoji, so they render reliably) in
-- colored circles - no panels wired up yet, just needs to exist on screen.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local BUTTON_SIZE = 64
local MENU_ITEMS = {
	{ name = "Store", symbol = "$", color = Color3.fromRGB(70, 190, 90) },
	{ name = "Runes", symbol = "\u{2726}", color = Color3.fromRGB(150, 80, 255) },
	{ name = "Profile", symbol = "\u{263A}", color = Color3.fromRGB(70, 150, 220) },
	{ name = "Settings", symbol = "\u{2699}", color = Color3.fromRGB(120, 120, 130) },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SideMenuHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Vertically centered on the right edge, mirroring the Mana counter's
-- placement on the left.
local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 0.5)
container.Position = UDim2.new(1, -20, 0.5, 0)
container.Size = UDim2.new(0, BUTTON_SIZE, 0, #MENU_ITEMS * (BUTTON_SIZE + 30))
container.BackgroundTransparency = 1
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 14)
layout.Parent = container

local function createMenuButton(layoutOrder: number, name: string, symbol: string, color: Color3)
	local wrapper = Instance.new("Frame")
	wrapper.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE + 20)
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder = layoutOrder
	wrapper.Parent = container

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 0)
	button.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextSize = 30
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.5
	button.Text = symbol
	button.Parent = wrapper

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.new(0, 0, 1, 2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Text = name
	label.Parent = wrapper

	return button
end

for index, item in MENU_ITEMS do
	createMenuButton(index, item.name, item.symbol, item.color)
end
