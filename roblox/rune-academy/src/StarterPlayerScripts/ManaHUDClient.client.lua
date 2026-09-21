-- Middle-left Mana counter (icon + amount, no word), plus a Rebirths
-- counter right below it - hidden until the player has at least one
-- Rebirth (the server only fires RebirthsUpdated once they do), so it only
-- appears once Rebirths are actually unlocked.

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

-- The icon overlapping the pill's left edge. The Rebirths icon (a mostly
-- round arrows glyph) gets a white circle backdrop for contrast against the
-- dark pill; the Mana icon (a potion with sparkles poking outside a round
-- silhouette) looks better with no backdrop at all, per direct request.
local function addIcon(parent: GuiObject, imageId: string, useCircleBadge: boolean)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, -16, 0.5, 0)
	holder.Size = UDim2.new(0, 44, 0, 44)
	holder.BackgroundTransparency = useCircleBadge and 0 or 1
	holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	holder.BorderSizePixel = 0
	holder.ZIndex = 2
	holder.Parent = parent

	if useCircleBadge then
		local holderCorner = Instance.new("UICorner")
		holderCorner.CornerRadius = UDim.new(1, 0)
		holderCorner.Parent = holder
	end

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ZIndex = 3
	icon.Parent = holder

	local iconPadding = Instance.new("UIPadding")
	iconPadding.PaddingTop = UDim.new(0.12, 0)
	iconPadding.PaddingBottom = UDim.new(0.12, 0)
	iconPadding.PaddingLeft = UDim.new(0.12, 0)
	iconPadding.PaddingRight = UDim.new(0.12, 0)
	iconPadding.Parent = icon
end

-- Builds an empty pill (background only) plus a child TextLabel reserved to
-- the right of the icon. UIPadding on a TextLabel does NOT inset its own
-- rendered Text (padding only repositions child Instances), so the only way
-- to keep text from running under the icon is a separate child label with
-- its own Size/Position actually carving out that space.
local function createCounterPill(name: string, yOffset: number, textColor: Color3, imageId: string, useCircleBadge: boolean)
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

	addIcon(pill, imageId, useCircleBadge)

	return pill, text
end

-- Middle-left of the screen: vertically centered, flush against the left edge.
local manaPill, manaText = createCounterPill("ManaCounter", 0, Color3.fromRGB(255, 255, 255), MANA_ICON_ID, false)
manaText.Text = "0"

local rebirthsPill, rebirthsText =
	createCounterPill("RebirthsCounter", 60, Color3.fromRGB(255, 90, 90), REBIRTHS_ICON_ID, true)
rebirthsPill.Visible = false
rebirthsText.Text = "0"

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaText.Text = NumberFormat.format(amount)
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	rebirthsPill.Visible = true
	rebirthsText.Text = ("%.1f"):format(amount)
end)
