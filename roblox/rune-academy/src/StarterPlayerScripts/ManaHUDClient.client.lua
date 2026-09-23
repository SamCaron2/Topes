-- Middle-left Mana counter (icon + amount, no word, no background pill),
-- an Arcane Dust counter below that, a Rebirths counter below that, then
-- an Ether counter, a Ley Shard counter, then an Astral Shard counter
-- below that - all five below Mana start hidden until the player has at
-- least one of each (the server only fires their Updated event once they
-- do), so Arcane Dust only shows up after first stepping on
-- ArcaneDustPad, Rebirths only once actually unlocked, Ether only after
-- first clicking the Ether Shroud, Ley Shard only after the first
-- levitation payout on EtherIsland, and Astral Shard only after the first
-- Ley Shard -> Astral Shard conversion - reflowLayout keeps the visible
-- rows stacked with no gap either way. Styled after a typical
-- incremental-game HUD: icon sitting right next to a bold number colored
-- to match the icon, nothing else around it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")
local arcaneDustUpdatedEvent = remotes:WaitForChild("ArcaneDustUpdated")
local etherUpdatedEvent = remotes:WaitForChild("EtherUpdated")
local leyShardUpdatedEvent = remotes:WaitForChild("LeyShardUpdated")
local astralShardUpdatedEvent = remotes:WaitForChild("AstralShardUpdated")

local MANA_ICON_ID = "rbxassetid://119417928367783"
local REBIRTHS_ICON_ID = "rbxassetid://119426569971477"
local ARCANE_DUST_ICON_ID = "rbxassetid://76299006281145"
local ARCANE_DUST_COLOR = Color3.fromRGB(60, 190, 230) -- matches the dust icon's own blue, per direct request
local ETHER_COLOR = Color3.fromRGB(150, 60, 220) -- matches the Ether Shroud's own purple
local LEY_SHARD_COLOR = Color3.fromRGB(90, 220, 190) -- matches the Ley Shard Mat's own teal
local ASTRAL_SHARD_COLOR = Color3.fromRGB(160, 140, 255) -- matches Card 2's own violet
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
-- blue for Arcane Dust (matching its own icon, per direct request), pink-red
-- for the Rebirths arrows (matching the Rebirth board's red theme). Created
-- all at yOffset 0 - reflowLayout below assigns real positions based on
-- which rows are currently visible, so a hidden Arcane Dust row (not
-- collected from yet) doesn't leave a gap before Rebirths.
local manaRow, manaText = createCounterRow("ManaCounter", 0, Color3.fromRGB(180, 120, 255), MANA_ICON_ID, false)
manaText.Text = "0"

local arcaneDustRow, arcaneDustText =
	createCounterRow("ArcaneDustCounter", 0, ARCANE_DUST_COLOR, ARCANE_DUST_ICON_ID, false)
arcaneDustRow.Visible = false
arcaneDustText.Text = "0"

local rebirthsRow, rebirthsText = createCounterRow("RebirthsCounter", 0, Color3.fromRGB(255, 90, 130), REBIRTHS_ICON_ID, true)
rebirthsRow.Visible = false
rebirthsText.Text = "0"

-- Ether has no uploaded image yet, so it passes `symbol` instead of
-- `imageId` - same placeholder treatment Arcane Dust used before its own
-- icon was uploaded.
local etherRow, etherText = createCounterRow("EtherCounter", 0, ETHER_COLOR, nil, true, "\u{2727}")
etherRow.Visible = false
etherText.Text = "0"

-- Ley Shard has no uploaded image yet either - same placeholder symbol
-- treatment, a plain diamond (a common, well-covered glyph, not a risky
-- arrow/emoji codepoint).
local leyShardRow, leyShardText = createCounterRow("LeyShardCounter", 0, LEY_SHARD_COLOR, nil, true, "\u{25C6}")
leyShardRow.Visible = false
leyShardText.Text = "0"

-- Astral Shard (Card 2) also has no uploaded image yet - same diamond
-- placeholder symbol as Ley Shard, just recolored.
local astralShardRow, astralShardText = createCounterRow("AstralShardCounter", 0, ASTRAL_SHARD_COLOR, nil, true, "\u{25C6}")
astralShardRow.Visible = false
astralShardText.Text = "0"

local ROW_SPACING = ICON_SIZE + 14
local orderedRows = { manaRow, arcaneDustRow, rebirthsRow, etherRow, leyShardRow, astralShardRow }

local function reflowLayout()
	local nextY = 0
	for _, row in orderedRows do
		if row.Visible then
			local position = row.Position
			row.Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, nextY)
			nextY += ROW_SPACING
		end
	end
end
reflowLayout()

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaText.Text = NumberFormat.format(amount)
end)

-- Visible only while amount > 0 (not just "ever shown") - a Wizard Tier
-- reset zeroes this back out, and it should hide again exactly like it did
-- before the first pickup, per the same "hidden until collected" rule.
arcaneDustUpdatedEvent.OnClientEvent:Connect(function(amount)
	local wasVisible = arcaneDustRow.Visible
	arcaneDustRow.Visible = amount > 0
	arcaneDustText.Text = NumberFormat.format(amount)
	if wasVisible ~= arcaneDustRow.Visible then
		reflowLayout()
	end
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	local wasVisible = rebirthsRow.Visible
	rebirthsRow.Visible = amount > 0
	rebirthsText.Text = NumberFormat.format(amount)
	if wasVisible ~= rebirthsRow.Visible then
		reflowLayout()
	end
end)

etherUpdatedEvent.OnClientEvent:Connect(function(amount)
	local wasVisible = etherRow.Visible
	etherRow.Visible = amount > 0
	etherText.Text = NumberFormat.format(amount)
	if wasVisible ~= etherRow.Visible then
		reflowLayout()
	end
end)

leyShardUpdatedEvent.OnClientEvent:Connect(function(amount)
	local wasVisible = leyShardRow.Visible
	leyShardRow.Visible = amount > 0
	leyShardText.Text = NumberFormat.format(amount)
	if wasVisible ~= leyShardRow.Visible then
		reflowLayout()
	end
end)

astralShardUpdatedEvent.OnClientEvent:Connect(function(amount)
	local wasVisible = astralShardRow.Visible
	astralShardRow.Visible = amount > 0
	astralShardText.Text = NumberFormat.format(amount)
	if wasVisible ~= astralShardRow.Visible then
		reflowLayout()
	end
end)
