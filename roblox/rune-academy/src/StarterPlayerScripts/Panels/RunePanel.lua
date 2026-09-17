-- The Runes menu icon opens this: a collection summary (how many of each
-- rank you own) plus the live server-wide pull feed. Actually pulling
-- Runes happens by standing on the physical RuneAltar in the world
-- (RuneAltarClient.client.lua) - this panel is for checking your progress
-- and activity from anywhere, not a duplicate pull button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local MAX_FEED_ENTRIES = 8
local PROFILE_REFRESH_INTERVAL = 2

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
	local runePulledEvent = remotes:WaitForChild("RunePulledBroadcast")
	local getProfileFunction = remotes:WaitForChild("GetProfile")

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

	local titleLabel = Instance.new("TextLabel")
	titleLabel.LayoutOrder = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Your Rune Collection"
	titleLabel.Parent = container

	local collectionFrame = Instance.new("Frame")
	collectionFrame.LayoutOrder = 2
	collectionFrame.Size = UDim2.new(1, 0, 0, 150)
	collectionFrame.BackgroundTransparency = 1
	collectionFrame.Parent = container

	local collectionLayout = Instance.new("UIListLayout")
	collectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	collectionLayout.Parent = collectionFrame

	local rankLabels = {}
	for index, rank in GameConfig.RuneRanks do
		local rankLabel = Instance.new("TextLabel")
		rankLabel.LayoutOrder = index
		rankLabel.Size = UDim2.new(1, 0, 0, 16)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.TextSize = 13
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.TextColor3 = colorForRank(rank.name)
		rankLabel.Text = rank.name .. ": 0"
		rankLabel.Parent = collectionFrame
		rankLabels[rank.name] = rankLabel
	end

	local feedTitle = Instance.new("TextLabel")
	feedTitle.LayoutOrder = 3
	feedTitle.Size = UDim2.new(1, 0, 0, 16)
	feedTitle.BackgroundTransparency = 1
	feedTitle.Font = Enum.Font.GothamBold
	feedTitle.TextSize = 12
	feedTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	feedTitle.TextXAlignment = Enum.TextXAlignment.Left
	feedTitle.Text = "Server pulls:"
	feedTitle.Parent = container

	local feedFrame = Instance.new("Frame")
	feedFrame.LayoutOrder = 4
	feedFrame.Size = UDim2.new(1, 0, 0, 130)
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

	runePulledEvent.OnClientEvent:Connect(addFeedEntry)

	local function refreshCollection()
		local profile = getProfileFunction:InvokeServer()
		if not profile or not profile.runesOwned then
			return
		end
		for rankName, label in rankLabels do
			label.Text = rankName .. ": " .. (profile.runesOwned[rankName] or 0)
		end
	end

	task.spawn(function()
		while container.Parent do
			refreshCollection()
			task.wait(PROFILE_REFRESH_INTERVAL)
		end
	end)

	return container
end

return RunePanel
