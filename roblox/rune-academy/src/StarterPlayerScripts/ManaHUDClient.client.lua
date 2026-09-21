-- Middle-left "Mana: <amount>" counter, plus a "Rebirths: <amount>" counter
-- right below it - hidden until the player has at least one Rebirth (the
-- server only fires RebirthsUpdated once they do), so it only appears once
-- Rebirths are actually unlocked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")

local MANA_ICON_ID = "rbxassetid://119417928367783"
local REBIRTHS_ICON_ID = "rbxassetid://119426569971477"

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- A small round white badge overlapping the pill's left edge, holding the
-- currency's icon - a white backdrop keeps every icon's own colors legible
-- against the dark pill instead of blending in.
local function addIconBadge(parent: GuiObject, imageId: string)
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, -16, 0.5, 0)
	badge.Size = UDim2.new(0, 44, 0, 44)
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.BorderSizePixel = 0
	badge.ZIndex = 2
	badge.Parent = parent

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ZIndex = 3
	icon.Parent = badge

	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0.12, 0)
	iconPadding.PaddingBottom = UDim.new(0.12, 0)
	iconPadding.PaddingLeft = UDim.new(0.12, 0)
	iconPadding.PaddingRight = UDim.new(0.12, 0)
	iconPadding.Parent = icon
end

-- Shifts the pill's text right so it doesn't run under the icon badge, while
-- keeping it centered in the remaining space.
local function addTextLeftPadding(label: TextLabel)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 34)
	padding.Parent = label
end

-- Middle-left of the screen: vertically centered, flush against the left edge.
local manaLabel = Instance.new("TextLabel")
manaLabel.Name = "ManaCounter"
manaLabel.AnchorPoint = Vector2.new(0, 0.5)
manaLabel.Position = UDim2.new(0, 10, 0.5, 0)
manaLabel.Size = UDim2.new(0, 220, 0, 50)
manaLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
manaLabel.BackgroundTransparency = 0.35
manaLabel.BorderSizePixel = 0
manaLabel.Font = Enum.Font.GothamBold
manaLabel.TextSize = 28
manaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
manaLabel.TextStrokeTransparency = 0.5
manaLabel.TextXAlignment = Enum.TextXAlignment.Center
manaLabel.Text = "Mana: 0"
manaLabel.Parent = screenGui

local manaCorner = Instance.new("UICorner")
manaCorner.CornerRadius = UDim.new(0, 8)
manaCorner.Parent = manaLabel

addIconBadge(manaLabel, MANA_ICON_ID)
addTextLeftPadding(manaLabel)

local rebirthsLabel = Instance.new("TextLabel")
rebirthsLabel.Name = "RebirthsCounter"
rebirthsLabel.Visible = false
rebirthsLabel.AnchorPoint = Vector2.new(0, 0.5)
rebirthsLabel.Position = UDim2.new(0, 10, 0.5, 60)
rebirthsLabel.Size = UDim2.new(0, 220, 0, 50)
rebirthsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
rebirthsLabel.BackgroundTransparency = 0.35
rebirthsLabel.BorderSizePixel = 0
rebirthsLabel.Font = Enum.Font.GothamBold
rebirthsLabel.TextSize = 28
rebirthsLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
rebirthsLabel.TextStrokeTransparency = 0.5
rebirthsLabel.TextXAlignment = Enum.TextXAlignment.Center
rebirthsLabel.Text = "Rebirths: 0"
rebirthsLabel.Parent = screenGui

local rebirthsCorner = Instance.new("UICorner")
rebirthsCorner.CornerRadius = UDim.new(0, 8)
rebirthsCorner.Parent = rebirthsLabel

addIconBadge(rebirthsLabel, REBIRTHS_ICON_ID)
addTextLeftPadding(rebirthsLabel)

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaLabel.Text = "Mana: " .. NumberFormat.format(amount)
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	rebirthsLabel.Visible = true
	rebirthsLabel.Text = ("Rebirths: %.1f"):format(amount)
end)
