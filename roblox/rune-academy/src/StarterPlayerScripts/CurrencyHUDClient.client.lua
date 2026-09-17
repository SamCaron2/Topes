-- The persistent on-screen UI is meant to be minimal - just a running list
-- of what you have, like the reference game's right-edge stat column. All
-- the deep interactive stuff (upgrades, prestige) lives on 3D kiosks in the
-- world instead (see UpgradeKioskClient.client.lua) or behind the left-side
-- menu icons (see SideMenuClient.client.lua), not stacked on this list.

local Players = game:GetService("Players")

local ROW_ORDER = { "Mana", "Essence", "Gold", "Scrolls", "Gems" }

-- Small colored square stands in for a real icon until actual art exists.
local ROW_COLORS = {
	Mana = Color3.fromRGB(150, 100, 240),
	Essence = Color3.fromRGB(90, 200, 200),
	Gold = Color3.fromRGB(230, 190, 60),
	Scrolls = Color3.fromRGB(220, 160, 90),
	Gems = Color3.fromRGB(90, 220, 230),
}

local player = Players.LocalPlayer

local NumberFormat = require(game:GetService("ReplicatedStorage").Modules.NumberFormat)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CurrencyHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.AnchorPoint = Vector2.new(1, 0)
mainFrame.Position = UDim2.new(1, -12, 0, 12)
mainFrame.Size = UDim2.new(0, 180, 0, 0)
mainFrame.AutomaticSize = Enum.AutomaticSize.Y
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
mainFrame.BackgroundTransparency = 0.35
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = mainFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = mainFrame

local valueLabels = {} -- [statName] = TextLabel

for index, statName in ROW_ORDER do
	local row = Instance.new("Frame")
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.Parent = mainFrame

	local icon = Instance.new("Frame")
	icon.Size = UDim2.new(0, 16, 0, 16)
	icon.Position = UDim2.new(0, 0, 0.5, -8)
	icon.BackgroundColor3 = ROW_COLORS[statName] or Color3.new(1, 1, 1)
	icon.Parent = row
	Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 4)

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Position = UDim2.new(0, 24, 0, 0)
	valueLabel.Size = UDim2.new(1, -24, 1, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 15
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Text = statName .. ": 0"
	valueLabel.Parent = row

	valueLabels[statName] = valueLabel
end

local leaderstats = player:WaitForChild("leaderstats")

for _, statName in ROW_ORDER do
	local stat = leaderstats:WaitForChild(statName)
	local label = valueLabels[statName]

	local function refresh()
		label.Text = statName .. ": " .. NumberFormat.format(stat.Value)
	end

	stat.Changed:Connect(refresh)
	refresh()
end
