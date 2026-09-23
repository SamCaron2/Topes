-- Floating info card above the Rune Altar's orb, listing every Rune
-- rank's odds plus how the Mana-collection bonus is progressing for each
-- one - per direct request ("show the levels and odds to roll them as a
-- card above it... everytime you get [a rank] you get .2x mana until it
-- gets to 5x and it tells you that too"). Read-only display - the actual
-- bonus math lives server-side in RuneCollectionHandler. Gated on the
-- same hasUnlockedRuin check as every other Ruin-area script, since a
-- BillboardGui renders independent of its Adornee's own Transparency.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getWizardTierStateFunction = remotes:WaitForChild("GetWizardTierState")
local getRuneCollectionStateFunction = remotes:WaitForChild("GetRuneCollectionState")
local runeAltarCollectedEvent = remotes:WaitForChild("RuneAltarCollected")
local playerWizardTieredEvent = remotes:WaitForChild("PlayerWizardTiered")

local ruinOrb = Workspace:WaitForChild("FantasyRuin"):WaitForChild("RuinOrb")

-- Same rarity ramp as RuneAltarClient's own popup colors - a tiny table,
-- kept in sync by hand, same "small color list duplicated per script"
-- precedent as every other tier-color ramp in this game.
local RANK_COLORS = {
	Apprentice = Color3.fromRGB(200, 200, 200),
	Novice = Color3.fromRGB(100, 220, 120),
	Adept = Color3.fromRGB(80, 180, 255),
	Skilled = Color3.fromRGB(190, 120, 255),
	Expert = Color3.fromRGB(255, 120, 200),
	Master = Color3.fromRGB(255, 150, 60),
	Archmage = Color3.fromRGB(255, 70, 70),
	Mythic = Color3.fromRGB(80, 255, 230),
	Ascendant = Color3.fromRGB(255, 215, 60),
}
local DEFAULT_RANK_COLOR = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.3

local billboard = Instance.new("BillboardGui")
billboard.Name = "RuneOddsCard"
billboard.Size = UDim2.new(0, 340, 0, 400)
billboard.StudsOffset = Vector3.new(0, 9, 0)
billboard.MaxDistance = 45
billboard.AlwaysOnTop = true
billboard.Adornee = ruinOrb
billboard.Enabled = false
billboard.Parent = ruinOrb

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
background.BackgroundTransparency = 0.25
background.BorderSizePixel = 0
background.Parent = billboard

local backgroundCorner = Instance.new("UICorner")
backgroundCorner.CornerRadius = UDim.new(0.06, 0)
backgroundCorner.Parent = background

local backgroundStroke = Instance.new("UIStroke")
backgroundStroke.Thickness = 2
backgroundStroke.Color = GOLD
backgroundStroke.Transparency = 0.4
backgroundStroke.Parent = background

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 0.08, 0)
titleText.Position = UDim2.new(0, 0, 0.02, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.TextScaled = true
titleText.TextColor3 = GOLD
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Rune Odds"
titleText.Parent = background

local totalText = Instance.new("TextLabel")
totalText.Size = UDim2.new(1, 0, 0.06, 0)
totalText.Position = UDim2.new(0, 0, 0.11, 0)
totalText.BackgroundTransparency = 1
totalText.Font = Enum.Font.Gotham
totalText.TextScaled = true
totalText.TextColor3 = Color3.fromRGB(200, 200, 200)
totalText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
totalText.Text = "Total Mana Bonus: x1.0"
totalText.Parent = background

local ROW_COUNT = 9
local ROW_TOP = 0.2
local ROW_HEIGHT = 0.083

local rankLabels = {}
for i = 1, ROW_COUNT do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(0.94, 0, ROW_HEIGHT, 0)
	row.Position = UDim2.new(0.03, 0, ROW_TOP + (i - 1) * ROW_HEIGHT, 0)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamBold
	row.TextScaled = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = DEFAULT_RANK_COLOR
	row.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	row.Text = "-"
	row.Parent = background
	rankLabels[i] = row
end

local function render(state)
	if not state then
		return
	end

	totalText.Text = ("Total Mana Bonus: x%.1f"):format(state.totalManaMultiplier)

	for i, rankState in state.ranks do
		local label = rankLabels[i]
		if label then
			label.TextColor3 = RANK_COLORS[rankState.name] or DEFAULT_RANK_COLOR
			label.Text = ("%s  1/%s  •  Owned %d  •  x%.1f"):format(
				rankState.name,
				NumberFormat.format(rankState.oddsOneIn),
				rankState.owned,
				rankState.multiplier
			)
		end
	end
end

local function refresh()
	render(getRuneCollectionStateFunction:InvokeServer())
end

-- Same retry-if-not-loaded-yet guard every other Ruin-area script uses.
local RETRY_ATTEMPTS = 10
local RETRY_DELAY_SECONDS = 0.5

local function checkAndShow()
	for _ = 1, RETRY_ATTEMPTS do
		local state = getWizardTierStateFunction:InvokeServer()
		if state then
			if state.unlockedRuin then
				billboard.Enabled = true
				refresh()
			end
			return
		end
		task.wait(RETRY_DELAY_SECONDS)
	end
end

checkAndShow()
playerWizardTieredEvent.OnClientEvent:Connect(checkAndShow)
runeAltarCollectedEvent.OnClientEvent:Connect(refresh)
