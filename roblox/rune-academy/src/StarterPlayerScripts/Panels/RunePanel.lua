-- Builds the Rune pull panel's content: Pull button, Scrolls count, result,
-- and a live server-wide pull feed. Owns no toggle button/ScreenGui -
-- SideMenuClient parents this and controls visibility.

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

local RunePanel = {}

function RunePanel.build(parent: Instance): Frame
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local pullRuneFunction = remotes:WaitForChild("PullRune")
	local runePulledEvent = remotes:WaitForChild("RunePulledBroadcast")

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = container

	local scrollsLabel = Instance.new("TextLabel")
	scrollsLabel.LayoutOrder = 1
	scrollsLabel.Size = UDim2.new(1, 0, 0, 18)
	scrollsLabel.BackgroundTransparency = 1
	scrollsLabel.Font = Enum.Font.Gotham
	scrollsLabel.TextSize = 14
	scrollsLabel.TextColor3 = Color3.fromRGB(220, 200, 150)
	scrollsLabel.TextXAlignment = Enum.TextXAlignment.Left
	scrollsLabel.Text = "Scrolls: 0"
	scrollsLabel.Parent = container

	local pullButton = Instance.new("TextButton")
	pullButton.LayoutOrder = 2
	pullButton.Size = UDim2.new(1, 0, 0, 34)
	pullButton.BackgroundColor3 = Color3.fromRGB(190, 130, 50)
	pullButton.Font = Enum.Font.GothamBold
	pullButton.TextSize = 15
	pullButton.TextColor3 = Color3.new(1, 1, 1)
	pullButton.Text = ("Pull Rune (%d Scroll)"):format(GameConfig.ScrollCostPerPull)
	pullButton.Parent = container
	Instance.new("UICorner", pullButton).CornerRadius = UDim.new(0, 8)

	local resultLabel = Instance.new("TextLabel")
	resultLabel.LayoutOrder = 3
	resultLabel.Size = UDim2.new(1, 0, 0, 22)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 15
	resultLabel.TextColor3 = Color3.new(1, 1, 1)
	resultLabel.Text = ""
	resultLabel.Parent = container

	local feedTitle = Instance.new("TextLabel")
	feedTitle.LayoutOrder = 4
	feedTitle.Size = UDim2.new(1, 0, 0, 16)
	feedTitle.BackgroundTransparency = 1
	feedTitle.Font = Enum.Font.GothamBold
	feedTitle.TextSize = 12
	feedTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	feedTitle.TextXAlignment = Enum.TextXAlignment.Left
	feedTitle.Text = "Server pulls:"
	feedTitle.Parent = container

	local feedFrame = Instance.new("Frame")
	feedFrame.LayoutOrder = 5
	feedFrame.Size = UDim2.new(1, 0, 0, 160)
	feedFrame.BackgroundTransparency = 1
	feedFrame.Parent = container

	local feedLayout = Instance.new("UIListLayout")
	feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
	feedLayout.Parent = feedFrame

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

	return container
end

return RunePanel
