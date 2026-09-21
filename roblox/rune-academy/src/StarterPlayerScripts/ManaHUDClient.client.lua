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

-- Builds an empty pill (background only) plus a child TextLabel reserved to
-- the right of the icon badge. UIPadding on a TextLabel does NOT inset its
-- own rendered Text (padding only repositions child Instances), so the only
-- way to keep text from running under the badge is a separate child label
-- with its own Size/Position actually carving out that space.
local function createCounterPill(name: string, yOffset: number, textColor: Color3, imageId: string)
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.new(0, 10, 0.5, yOffset)
	pill.Size = UDim2.new(0, 220, 0, 50)
	pill.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	pill.BackgroundTransparency = 0.35
	pill.BorderSizePixel = 0
	pill.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = pill

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.new(1, -34, 1, 0)
	text.Position = UDim2.new(0, 34, 0, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 28
	text.TextColor3 = textColor
	text.TextStrokeTransparency = 0.5
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.Parent = pill

	addIconBadge(pill, imageId)

	return pill, text
end

-- Middle-left of the screen: vertically centered, flush against the left edge.
local manaPill, manaText = createCounterPill("ManaCounter", 0, Color3.fromRGB(255, 255, 255), MANA_ICON_ID)
manaText.Text = "Mana: 0"

local rebirthsPill, rebirthsText = createCounterPill("RebirthsCounter", 60, Color3.fromRGB(255, 90, 90), REBIRTHS_ICON_ID)
rebirthsPill.Visible = false
rebirthsText.Text = "Rebirths: 0"

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaText.Text = "Mana: " .. NumberFormat.format(amount)
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	rebirthsPill.Visible = true
	rebirthsText.Text = ("Rebirths: %.1f"):format(amount)
end)
