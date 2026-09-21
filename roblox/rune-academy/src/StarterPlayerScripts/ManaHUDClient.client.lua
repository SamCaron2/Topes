-- Middle-left Mana counter (icon + amount, no word, no background pill),
-- an Arcane Dust counter below that, then a Rebirths counter below that -
-- Rebirths hidden until the player has at least one (the server only fires
-- RebirthsUpdated once they do), so it only appears once Rebirths are
-- actually unlocked. Styled after a typical incremental-game HUD: icon
-- sitting right next to a bold number colored to match the icon, nothing
-- else around it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")
local arcaneDustUpdatedEvent = remotes:WaitForChild("ArcaneDustUpdated")

local MANA_ICON_ID = "rbxassetid://119417928367783"
local REBIRTHS_ICON_ID = "rbxassetid://119426569971477"
local ICON_SIZE = 46
local ICON_TEXT_GAP = 6

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- One row: icon on the left (the Rebirths icon gets a small white circle
-- behind it for contrast; the Mana icon has none, per direct request,
-- since its sparkles poke outside a round silhouette and looked bad boxed
-- into one), then the amount immediately next to it, left-aligned so it
-- actually sits close to the icon instead of centered in a wide box.
-- Arcane Dust has no uploaded image yet, so it passes `symbol` instead of
-- `imageId` - a safe basic Unicode glyph (not emoji) in a colored circle,
-- same placeholder treatment as the side menu's Runes/Profile icons.
local function createCounterRow(
	name: string,
	yOffset: number,
	textColor: Color3,
	imageId: string?,
	useCircleBadge: boolean,
	symbol: string?
)
	local row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(0, 0.5)
	row.Position = UDim2.new(0, 20, 0.5, yOffset)
	row.Size = UDim2.new(0, 200, 0, ICON_SIZE)
	row.BackgroundTransparency = 1
	row.Parent = screenGui

	local iconHolder = Instance.new("Frame")
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.new(0, 0, 0.5, 0)
	iconHolder.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	iconHolder.BackgroundTransparency = useCircleBadge and 0 or 1
	iconHolder.BackgroundColor3 = symbol and textColor or Color3.fromRGB(255, 255, 255)
	iconHolder.BorderSizePixel = 0
	iconHolder.Parent = row

	if useCircleBadge then
		local holderCorner = Instance.new("UICorner")
		holderCorner.CornerRadius = UDim.new(1, 0)
		holderCorner.Parent = iconHolder
	end

	if imageId then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.Parent = iconHolder

		local iconPadding = Instance.new("UIPadding")
		iconPadding.PaddingTop = UDim.new(0.1, 0)
		iconPadding.PaddingBottom = UDim.new(0.1, 0)
		iconPadding.PaddingLeft = UDim.new(0.1, 0)
		iconPadding.PaddingRight = UDim.new(0.1, 0)
		iconPadding.Parent = icon
	else
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.TextScaled = true
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextStrokeTransparency = 0.5
		icon.Text = symbol
		icon.Parent = iconHolder

		local iconPadding = Instance.new("UIPadding")
		iconPadding.PaddingTop = UDim.new(0.15, 0)
		iconPadding.PaddingBottom = UDim.new(0.15, 0)
		iconPadding.PaddingLeft = UDim.new(0.15, 0)
		iconPadding.PaddingRight = UDim.new(0.15, 0)
		iconPadding.Parent = icon
	end

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0, ICON_SIZE + ICON_TEXT_GAP, 0.5, 0)
	text.Size = UDim2.new(1, -(ICON_SIZE + ICON_TEXT_GAP), 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 32
	text.TextColor3 = textColor
	text.TextStrokeTransparency = 0.2
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = row

	return row, text
end

-- Middle-left of the screen. Text colors echo each icon's own palette -
-- violet for the Mana potion (matching the Mana nodes' own purple glow),
-- gold for Arcane Dust (matching its nodes' color), pink-red for the
-- Rebirths arrows (matching the Rebirth board's red theme).
local manaRow, manaText = createCounterRow("ManaCounter", 0, Color3.fromRGB(180, 120, 255), MANA_ICON_ID, false)
manaText.Text = "0"

local arcaneDustRow, arcaneDustText =
	createCounterRow("ArcaneDustCounter", ICON_SIZE + 14, Color3.fromRGB(255, 200, 80), nil, true, "\u{2726}")
arcaneDustText.Text = "0"

local rebirthsRow, rebirthsText =
	createCounterRow("RebirthsCounter", (ICON_SIZE + 14) * 2, Color3.fromRGB(255, 90, 130), REBIRTHS_ICON_ID, true)
rebirthsRow.Visible = false
rebirthsText.Text = "0"

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaText.Text = NumberFormat.format(amount)
end)

arcaneDustUpdatedEvent.OnClientEvent:Connect(function(amount)
	arcaneDustText.Text = NumberFormat.format(amount)
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	rebirthsRow.Visible = true
	rebirthsText.Text = ("%.1f"):format(amount)
end)
