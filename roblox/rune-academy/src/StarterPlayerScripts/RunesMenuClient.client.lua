-- The "Runes" side-menu panel: opened by clicking the Runes icon
-- (SideMenuClient fires OpenRunesRequested) - per direct request
-- ("clicking the runes button on the right side UI screen and nothing is
-- happening. I want it to mimic something like this. Shows all the tiers
-- you can unlock and if you haven't discovered one of the tiers it says
-- that"). Reuses the exact same 5-tier Rune Altar data
-- (RuinRuneHandler/GetRuinRuneState/BuyRuinRuneTier) and card design as
-- RuneAltarBoardClient's physical board, just in a modal reachable from
-- anywhere instead of only by standing at the Fantasy Ruin - both read
-- and write the same server state, so they always stay in sync. If the
-- Altar itself isn't unlocked yet (GetRuinRuneState returns nil), shows a
-- plain locked message instead of the tier grid, rather than the button
-- silently doing nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getRuinRuneStateFunction = remotes:WaitForChild("GetRuinRuneState")
local buyRuinRuneTierFunction = remotes:WaitForChild("BuyRuinRuneTier")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_LOCKED = Color3.fromRGB(110, 110, 110)
local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(90, 90, 90)

-- Same per-tier color ramp as RuneAltarBoardClient/the reference images.
local TIER_COLORS = {
	Color3.fromRGB(100, 220, 120),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(255, 215, 60),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunesMenuUI"
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
panel.Size = UDim2.new(0, 520, 0, 560)
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
titleLabel.Size = UDim2.new(0, 160, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = GOLD
titleLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleLabel.Text = "Runes"
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

-- Shown instead of the grid whenever GetRuinRuneState returns nil (the
-- Fantasy Ruin/Rune Altar isn't unlocked yet for this player - Wizard
-- Tier 3+ required).
local lockedLabel = Instance.new("TextLabel")
lockedLabel.Size = UDim2.new(1, -40, 1, -80)
lockedLabel.Position = UDim2.new(0, 20, 0, 68)
lockedLabel.BackgroundTransparency = 1
lockedLabel.Font = Enum.Font.Gotham
lockedLabel.TextScaled = true
lockedLabel.TextWrapped = true
lockedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
lockedLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
lockedLabel.Text = "🔒 Reach Wizard Tier 3 on SecondIsland to unlock the Fantasy Ruin and its Rune Altar."
lockedLabel.Visible = false
lockedLabel.Parent = panel

-- 5 cards, 2 per row (the 5th sits alone on its own row) - same explicit
-- grid math as RuneAltarBoardClient, not a UIGridLayout, so the odd one
-- out lands predictably.
local CARD_WIDTH = 228
local CARD_HEIGHT = 150
local CARD_GAP = 16
local GRID_LEFT = 20
local GRID_TOP = 68

local function cardPosition(index: number)
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	return UDim2.new(0, GRID_LEFT + column * (CARD_WIDTH + CARD_GAP), 0, GRID_TOP + row * (CARD_HEIGHT + CARD_GAP))
end

local cards = {} -- [tierIndex] = { frame, nameLabel, bodyLabel, buyButton }

local function buildCard(index: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	frame.Position = cardPosition(index)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.92
	frame.BorderSizePixel = 0
	frame.Parent = panel

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0.08, 0)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Thickness = 2
	frameStroke.Color = TIER_COLORS[index] or GOLD
	frameStroke.Transparency = 0.4
	frameStroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -16, 0, 28)
	nameLabel.Position = UDim2.new(0, 8, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = TIER_COLORS[index] or GOLD
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = "-"
	nameLabel.Parent = frame

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -16, 0, 1)
	divider.Position = UDim2.new(0, 8, 0, 40)
	divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Size = UDim2.new(1, -16, 0, 56)
	bodyLabel.Position = UDim2.new(0, 8, 0, 48)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextScaled = true
	bodyLabel.TextWrapped = true
	bodyLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	bodyLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	bodyLabel.Text = "-"
	bodyLabel.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(1, -16, 0, 34)
	buyButton.Position = UDim2.new(0, 8, 1, -42)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextScaled = true
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	buyButton.Visible = false
	buyButton.Parent = frame

	local buyButtonCorner = Instance.new("UICorner")
	buyButtonCorner.CornerRadius = UDim.new(0.25, 0)
	buyButtonCorner.Parent = buyButton

	cards[index] = { frame = frame, nameLabel = nameLabel, bodyLabel = bodyLabel, buyButton = buyButton }
	return cards[index]
end

local currentState = nil -- last GetRuinRuneState result (nil if not unlocked)

local function updateCardButton(index: number)
	local card = cards[index]
	local tierState = currentState and currentState.tiers[index]
	if not card or not tierState or not tierState.reachable then
		return
	end

	local canAfford = currentState.mana >= tierState.cost
	card.buyButton.Active = canAfford
	card.buyButton.BackgroundColor3 = canAfford and COLOR_CAN_BUY or COLOR_CANT_AFFORD
	card.buyButton.Text = ("Buy - %s Mana"):format(NumberFormat.format(tierState.cost))
end

local function renderCard(index: number)
	local card = cards[index]
	local tierState = currentState and currentState.tiers[index]
	if not card or not tierState then
		return
	end

	card.nameLabel.Text = tierState.name

	if tierState.bought then
		card.nameLabel.TextColor3 = TIER_COLORS[index] or GOLD
		card.bodyLabel.TextColor3 = TIER_COLORS[index] or GOLD
		card.bodyLabel.Text = ("%s\n[MAX]"):format(tierState.label)
		card.buyButton.Visible = false
	elseif tierState.reachable then
		card.nameLabel.TextColor3 = TIER_COLORS[index] or GOLD
		card.bodyLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		card.bodyLabel.Text = tierState.label
		card.buyButton.Visible = true
		updateCardButton(index)
	else
		card.nameLabel.TextColor3 = COLOR_LOCKED
		card.bodyLabel.TextColor3 = COLOR_LOCKED
		card.bodyLabel.Text = "🔒 Discover the rune"
		card.buyButton.Visible = false
	end
end

local function render(state)
	currentState = state

	local unlocked = state ~= nil
	lockedLabel.Visible = not unlocked
	for _, card in cards do
		card.frame.Visible = unlocked
	end

	if not unlocked then
		return
	end
	for index in cards do
		renderCard(index)
	end
end

for index = 1, 5 do
	local card = buildCard(index)
	card.buyButton.MouseButton1Click:Connect(function()
		local success, _, newState = buyRuinRuneTierFunction:InvokeServer()
		if success then
			render(newState)
		end
	end)
end

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	if not currentState then
		return
	end
	currentState.mana = amount
	for index in cards do
		updateCardButton(index)
	end
end)

local sideMenuHUD = player:WaitForChild("PlayerGui"):WaitForChild("SideMenuHUD")
local openRunesEvent = sideMenuHUD:WaitForChild("OpenRunesRequested")

openRunesEvent.Event:Connect(function()
	if screenGui.Enabled then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true
	render(getRuinRuneStateFunction:InvokeServer())
end)
