-- Stand on the RuneAltar part (WorldBuilder-generated) and it continuously
-- pulls Runes for you, once per PULL_INTERVAL, for as long as you have
-- Scrolls - matches the reference game's stand-on-a-platform pull
-- mechanic rather than a menu button. Two boards float above it: the rune
-- rarity ladder + your pull count, and your current stat boosts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local PULL_INTERVAL = 1
local PROFILE_REFRESH_INTERVAL = 1

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

local STAT_ORDER = { "Power", "Fortune", "Focus", "Haste", "Familiar" }

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pullRuneFunction = remotes:WaitForChild("PullRune")
local getProfileFunction = remotes:WaitForChild("GetProfile")

local function buildAltarGui(part: BasePart)
	-- Left board: rune ladder + your pull count.
	local infoBoard = Instance.new("BillboardGui")
	infoBoard.Name = "RuneInfoBoard"
	infoBoard.Size = UDim2.new(9, 0, 9, 0)
	infoBoard.StudsOffset = Vector3.new(-6, 8, 0)
	infoBoard.MaxDistance = 60
	infoBoard.Parent = part

	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(1, 0, 1, 0)
	infoFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	infoFrame.BackgroundTransparency = 0.1
	infoFrame.Parent = infoBoard
	Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 12)

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoLayout.Padding = UDim.new(0, 3)
	infoLayout.Parent = infoFrame

	local infoPadding = Instance.new("UIPadding")
	infoPadding.PaddingTop = UDim.new(0, 10)
	infoPadding.PaddingBottom = UDim.new(0, 10)
	infoPadding.PaddingLeft = UDim.new(0, 10)
	infoPadding.PaddingRight = UDim.new(0, 10)
	infoPadding.Parent = infoFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.LayoutOrder = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 24)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = "Rune Altar"
	titleLabel.Parent = infoFrame

	local openedLabel = Instance.new("TextLabel")
	openedLabel.LayoutOrder = 2
	openedLabel.Size = UDim2.new(1, 0, 0, 18)
	openedLabel.BackgroundTransparency = 1
	openedLabel.Font = Enum.Font.Gotham
	openedLabel.TextSize = 13
	openedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	openedLabel.Text = "Runes Opened: 0"
	openedLabel.Parent = infoFrame

	local costLabel = Instance.new("TextLabel")
	costLabel.LayoutOrder = 3
	costLabel.Size = UDim2.new(1, 0, 0, 20)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextSize = 15
	costLabel.TextColor3 = Color3.fromRGB(220, 200, 150)
	costLabel.Text = ("Cost: %d Scroll"):format(GameConfig.ScrollCostPerPull)
	costLabel.Parent = infoFrame

	for index, rank in GameConfig.RuneRanks do
		local rankLabel = Instance.new("TextLabel")
		rankLabel.LayoutOrder = 3 + index
		rankLabel.Size = UDim2.new(1, 0, 0, 16)
		rankLabel.BackgroundTransparency = 1
		rankLabel.Font = Enum.Font.GothamBold
		rankLabel.TextSize = 13
		rankLabel.TextXAlignment = Enum.TextXAlignment.Left
		rankLabel.TextColor3 = colorForRank(rank.name)
		rankLabel.Text = ("%s (1/%s)"):format(rank.name, NumberFormat.format(rank.oddsOneIn))
		rankLabel.Parent = infoFrame
	end

	-- Right board: your current stat boosts + last pull result.
	local statsBoard = Instance.new("BillboardGui")
	statsBoard.Name = "RuneStatsBoard"
	statsBoard.Size = UDim2.new(6, 0, 6, 0)
	statsBoard.StudsOffset = Vector3.new(6, 8, 0)
	statsBoard.MaxDistance = 60
	statsBoard.Parent = part

	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(1, 0, 1, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	statsFrame.BackgroundTransparency = 0.1
	statsFrame.Parent = statsBoard
	Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 12)

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Padding = UDim.new(0, 4)
	statsLayout.Parent = statsFrame

	local statsPadding = Instance.new("UIPadding")
	statsPadding.PaddingTop = UDim.new(0, 10)
	statsPadding.PaddingBottom = UDim.new(0, 10)
	statsPadding.PaddingLeft = UDim.new(0, 10)
	statsPadding.PaddingRight = UDim.new(0, 10)
	statsPadding.Parent = statsFrame

	local lastPullLabel = Instance.new("TextLabel")
	lastPullLabel.LayoutOrder = 1
	lastPullLabel.Size = UDim2.new(1, 0, 0, 20)
	lastPullLabel.BackgroundTransparency = 1
	lastPullLabel.Font = Enum.Font.GothamBold
	lastPullLabel.TextSize = 15
	lastPullLabel.TextColor3 = Color3.new(1, 1, 1)
	lastPullLabel.Text = "Stand to pull"
	lastPullLabel.Parent = statsFrame

	local statLabels = {}
	for index, statName in STAT_ORDER do
		local statLabel = Instance.new("TextLabel")
		statLabel.LayoutOrder = 1 + index
		statLabel.Size = UDim2.new(1, 0, 0, 18)
		statLabel.BackgroundTransparency = 1
		statLabel.Font = Enum.Font.GothamBold
		statLabel.TextSize = 14
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
		statLabel.Text = statName .. ": x1"
		statLabel.Parent = statsFrame
		statLabels[statName] = statLabel
	end

	return openedLabel, lastPullLabel, statLabels
end

-- The altar is server-created (WorldBuilder.server.lua) and its tag needs a
-- moment to replicate - don't assume it's already there when this script
-- starts running.
local function waitForAltar(): BasePart?
	local existing = CollectionService:GetTagged("RuneAltar")[1]
	if existing then
		return existing
	end

	local found: BasePart? = nil
	local connection = CollectionService:GetInstanceAddedSignal("RuneAltar"):Connect(function(part)
		found = part
	end)

	local elapsed = 0
	while not found and elapsed < 10 do
		task.wait(0.5)
		elapsed += 0.5
	end
	connection:Disconnect()

	return found
end

local altarPart = waitForAltar()
if not altarPart then
	warn("RuneAltarClient: no RuneAltar part found after waiting")
	return
end

local openedLabel, lastPullLabel, statLabels = buildAltarGui(altarPart)

local function refreshProfile()
	local profile = getProfileFunction:InvokeServer()
	if not profile then
		return
	end

	openedLabel.Text = "Runes Opened: " .. NumberFormat.format(profile.runesOpened or 0)

	for statName, label in statLabels do
		local value = profile.stats and profile.stats[statName] or 1
		label.Text = statName .. ": x" .. NumberFormat.format(value)
	end
end

task.spawn(function()
	while true do
		refreshProfile()
		task.wait(PROFILE_REFRESH_INTERVAL)
	end
end)

local standing = false

local function pullLoop()
	if standing then
		return
	end
	standing = true

	local leaderstats = player:WaitForChild("leaderstats")
	local scrollsStat = leaderstats:WaitForChild("Scrolls")

	while standing do
		if scrollsStat.Value >= GameConfig.ScrollCostPerPull then
			local rank, err = pullRuneFunction:InvokeServer()
			if rank then
				lastPullLabel.Text = "You got: " .. rank.name
				lastPullLabel.TextColor3 = colorForRank(rank.name)
				refreshProfile()
			else
				lastPullLabel.Text = tostring(err)
				lastPullLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
			end
		else
			lastPullLabel.Text = "Out of Scrolls"
			lastPullLabel.TextColor3 = Color3.fromRGB(255, 110, 110)
		end
		task.wait(PULL_INTERVAL)
	end

	lastPullLabel.Text = "Stand to pull"
	lastPullLabel.TextColor3 = Color3.new(1, 1, 1)
end

local touchingParts = {} -- [part] = true, tracks all contact points so leaving one foot doesn't stop the loop early

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart")

	rootPart.Touched:Connect(function(hit)
		if hit == altarPart then
			touchingParts[hit] = true
			task.spawn(pullLoop)
		end
	end)

	rootPart.TouchEnded:Connect(function(hit)
		if hit == altarPart then
			touchingParts[hit] = nil
			if next(touchingParts) == nil then
				standing = false
			end
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
