-- Builds the Rune Altar's own upgrade board (RuneAltarBoard, just outside
-- the Fantasy Ruin's pillar ring): 5 named tiers (RuinRuneHandler),
-- bought here on the board - NOT by interacting with the Altar itself
-- (RuinRuneCircle, which you just stand on - see RuneAltarClient/
-- WorldBuilder's collection loop), per direct correction ("There is no
-- clicking on a ruin you just sit and it collects"). Same "card per tier"
-- look as a couple of reference screenshots given directly: tier name on
-- top, then either its cost/boost (reachable), its boost + a "MAX" tag
-- (bought), or "Discover the rune" in place of both (locked, still
-- further out than the next buyable one) - same progressive-reveal idea
-- as the Upgrade Tree tiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)
local LockIcon = require(ReplicatedStorage.Modules.LockIcon)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getSecondIslandStateFunction = remotes:WaitForChild("GetSecondIslandState")
local getRuinRuneStateFunction = remotes:WaitForChild("GetRuinRuneState")
local buyRuinRuneTierFunction = remotes:WaitForChild("BuyRuinRuneTier")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("RuneAltarBoard")

-- Shows a locked-padlock overlay (LockIcon) instead of just staying blank
-- while SecondIsland isn't unlocked yet - per direct request ("Make sure
-- all cards are locked with a locked emoji on them until you unlock
-- them... for the dust you unlock the door").
local lockGui = LockIcon.show(board, Enum.NormalId.Right)

while true do
	local state = getSecondIslandStateFunction:InvokeServer()
	if state and state.unlocked then
		break
	end
	task.wait(1)
end

lockGui:Destroy()

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_LOCKED = Color3.fromRGB(110, 110, 110)
local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_AFFORD = Color3.fromRGB(90, 90, 90)

-- One color per tier, matching the reference images' own per-tier ramp.
local TIER_COLORS = {
	Color3.fromRGB(100, 220, 120),
	Color3.fromRGB(80, 180, 255),
	Color3.fromRGB(190, 120, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(255, 215, 60),
}

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "RuneAltarBoardGui"
-- The board is now rotated 90° around Y in WorldBuilder (per direct
-- request, "rotate the card to face towards center of island"), so its
-- local Right face is the one pointing back south toward the ruin/island
-- center - a guess like every other board face here; flip to Left if
-- it renders backwards.
surfaceGui.Face = Enum.NormalId.Right
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(35, 20, 45)
background.BackgroundTransparency = 0.45
background.BorderSizePixel = 0
background.Parent = surfaceGui

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.94, 0, 0.11, 0)
titleBanner.Position = UDim2.new(0.03, 0, 0.03, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
titleBanner.BackgroundTransparency = 0.1
titleBanner.BorderSizePixel = 0
titleBanner.Parent = background

local titleBannerCorner = Instance.new("UICorner")
titleBannerCorner.CornerRadius = UDim.new(0.25, 0)
titleBannerCorner.Parent = titleBanner

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.TextScaled = true
titleText.TextColor3 = GOLD
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Rune Altar"
titleText.Parent = titleBanner

local subtitleText = Instance.new("TextLabel")
subtitleText.Size = UDim2.new(0.94, 0, 0.07, 0)
subtitleText.Position = UDim2.new(0.03, 0, 0.15, 0)
subtitleText.BackgroundTransparency = 1
subtitleText.Font = Enum.Font.Gotham
subtitleText.TextScaled = true
subtitleText.TextColor3 = Color3.fromRGB(210, 190, 230)
subtitleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
subtitleText.Text = "Stand on the Altar to collect"
subtitleText.Parent = background

-- 5 cards, 2 per row (the 5th sits alone on its own row) - explicit
-- scale-based positions so the layout stays proportional at any board size.
local COLUMN_WIDTH = 0.45
local COLUMN_GAP = 0.04
local ROW_HEIGHT = 0.24
local ROW_GAP = 0.02
local GRID_TOP = 0.26

local function cardPosition(index: number)
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	return UDim2.new(0.03 + column * (COLUMN_WIDTH + COLUMN_GAP), 0, GRID_TOP + row * (ROW_HEIGHT + ROW_GAP), 0, 0)
end

local cards = {} -- [tierIndex] = { nameLabel, bodyLabel, buyButton }

local function buildCard(index: number)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(COLUMN_WIDTH, 0, ROW_HEIGHT, 0)
	frame.Position = cardPosition(index)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0.92
	frame.BorderSizePixel = 0
	frame.Parent = background

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0.08, 0)
	frameCorner.Parent = frame

	local frameStroke = Instance.new("UIStroke")
	frameStroke.Thickness = 2
	frameStroke.Color = TIER_COLORS[index] or GOLD
	frameStroke.Transparency = 0.4
	frameStroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -12, 0.32, 0)
	nameLabel.Position = UDim2.new(0, 6, 0.05, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = TIER_COLORS[index] or GOLD
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = "-"
	nameLabel.Parent = frame

	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Size = UDim2.new(1, -12, 0.4, 0)
	bodyLabel.Position = UDim2.new(0, 6, 0.38, 0)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Font = Enum.Font.Gotham
	bodyLabel.TextScaled = true
	bodyLabel.TextWrapped = true
	bodyLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	bodyLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	bodyLabel.Text = "-"
	bodyLabel.Parent = frame

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(1, -12, 0.22, 0)
	buyButton.Position = UDim2.new(0, 6, 0.76, 0)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextScaled = true
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	buyButton.Visible = false
	buyButton.Parent = frame

	local buyButtonCorner = Instance.new("UICorner")
	buyButtonCorner.CornerRadius = UDim.new(0.25, 0)
	buyButtonCorner.Parent = buyButton

	cards[index] = { nameLabel = nameLabel, bodyLabel = bodyLabel, buyButton = buyButton }
	return cards[index]
end

local currentState = nil -- last GetRuinRuneState result

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

local function updateSubtitle()
	if not currentState then
		return
	end
	subtitleText.Text = ("Stand on the Altar - %s Mana every %.1fs"):format(
		NumberFormat.format(currentState.manaCostPerTick),
		currentState.tickIntervalSeconds
	)
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
	if not state then
		return
	end
	updateSubtitle()
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

render(getRuinRuneStateFunction:InvokeServer())
