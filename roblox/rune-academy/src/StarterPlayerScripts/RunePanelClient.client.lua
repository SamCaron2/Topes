-- Persistent bottom-right panel: pull Runes with Scrolls, see your result,
-- and a live feed of every pull across the server (pure social-proof/FOMO,
-- no gameplay effect - matches the reference game's scrolling pull ticker).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MAX_FEED_ENTRIES = 8

local RANK_COLORS = {
	Apprentice = Color3.fromRGB(200, 200, 200),
	Novice = Color3.fromRGB(120, 200, 120),
	Adept = Color3.fromRGB(100, 180, 220),
	Skilled = Color3.fromRGB(130, 150, 240),
	Expert = Color3.fromRGB(210, 120, 220),
	Master = Color3.fromRGB(230, 150, 60),
	Archmage = Color3.fromRGB(230, 80, 80),
	Mythic = Color3.fromRGB(255, 215, 0),
	Ascendant = Color3.fromRGB(255, 255, 255),
}

local function colorForRank(rankName: string): Color3
	return RANK_COLORS[rankName] or Color3.new(1, 1, 1)
end

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pullRuneFunction = remotes:WaitForChild("PullRune")
local runePulledEvent = remotes:WaitForChild("RunePulledBroadcast")

-- ============================================================================
-- Build the UI
-- ============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunePanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.AnchorPoint = Vector2.new(1, 1)
mainFrame.Position = UDim2.new(1, -16, 1, -16)
mainFrame.Size = UDim2.new(0, 280, 0, 330)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 22, 15)
mainFrame.BackgroundTransparency = 0.1
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = mainFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.LayoutOrder = 1
titleLabel.Size = UDim2.new(1, 0, 0, 22)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Runes"
titleLabel.Parent = mainFrame

local scrollsLabel = Instance.new("TextLabel")
scrollsLabel.LayoutOrder = 2
scrollsLabel.Size = UDim2.new(1, 0, 0, 18)
scrollsLabel.BackgroundTransparency = 1
scrollsLabel.Font = Enum.Font.Gotham
scrollsLabel.TextSize = 14
scrollsLabel.TextColor3 = Color3.fromRGB(220, 200, 150)
scrollsLabel.TextXAlignment = Enum.TextXAlignment.Left
scrollsLabel.Text = "Scrolls: 0"
scrollsLabel.Parent = mainFrame

local pullButton = Instance.new("TextButton")
pullButton.LayoutOrder = 3
pullButton.Size = UDim2.new(1, 0, 0, 34)
pullButton.BackgroundColor3 = Color3.fromRGB(190, 130, 50)
pullButton.Font = Enum.Font.GothamBold
pullButton.TextSize = 15
pullButton.TextColor3 = Color3.new(1, 1, 1)
pullButton.Text = ("Pull Rune (%d Scroll)"):format(GameConfig.ScrollCostPerPull)
pullButton.Parent = mainFrame
Instance.new("UICorner", pullButton).CornerRadius = UDim.new(0, 8)

local resultLabel = Instance.new("TextLabel")
resultLabel.LayoutOrder = 4
resultLabel.Size = UDim2.new(1, 0, 0, 22)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 15
resultLabel.TextColor3 = Color3.new(1, 1, 1)
resultLabel.Text = ""
resultLabel.Parent = mainFrame

local feedTitle = Instance.new("TextLabel")
feedTitle.LayoutOrder = 5
feedTitle.Size = UDim2.new(1, 0, 0, 16)
feedTitle.BackgroundTransparency = 1
feedTitle.Font = Enum.Font.GothamBold
feedTitle.TextSize = 12
feedTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
feedTitle.TextXAlignment = Enum.TextXAlignment.Left
feedTitle.Text = "Server pulls:"
feedTitle.Parent = mainFrame

local feedFrame = Instance.new("Frame")
feedFrame.LayoutOrder = 6
feedFrame.Size = UDim2.new(1, 0, 0, 140)
feedFrame.BackgroundTransparency = 1
feedFrame.Parent = mainFrame

local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Parent = feedFrame

-- ============================================================================
-- Behavior
-- ============================================================================

local feedOrder = 0

local function addFeedEntry(playerName: string, rankName: string)
	feedOrder += 1

	local entry = Instance.new("TextLabel")
	entry.LayoutOrder = feedOrder
	entry.Size = UDim2.new(1, 0, 0, 16)
	entry.BackgroundTransparency = 1
	entry.Font = Enum.Font.Gotham
	entry.TextSize = 13
	entry.TextXAlignment = Enum.TextXAlignment.Left
	entry.TextColor3 = colorForRank(rankName)
	entry.Text = ("%s pulled %s"):format(playerName, rankName)
	entry.Parent = feedFrame

	local labels = {}
	for _, child in feedFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #labels > MAX_FEED_ENTRIES do
		table.remove(labels, 1):Destroy()
	end
end

pullButton.MouseButton1Click:Connect(function()
	local rank, err = pullRuneFunction:InvokeServer()
	if rank then
		resultLabel.Text = "You got: " .. rank.name
		resultLabel.TextColor3 = colorForRank(rank.name)
	else
		resultLabel.Text = tostring(err)
		resultLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
	end
end)

runePulledEvent.OnClientEvent:Connect(addFeedEntry)

local leaderstats = player:WaitForChild("leaderstats")
local scrollsStat = leaderstats:WaitForChild("Scrolls")

local function updateScrolls()
	scrollsLabel.Text = "Scrolls: " .. scrollsStat.Value
end

scrollsStat.Changed:Connect(updateScrolls)
updateScrolls()
