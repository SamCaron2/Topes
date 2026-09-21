-- Builds the 4 leaderboard sign boards on the Leaderboard island: Playtime,
-- Robux Spent, Total Mana, Runes Opened. Each is a plain white sign - no
-- Buy/Max buttons, nothing interactive - showing the top 5 players for that
-- stat, pulled from the server's GetLeaderboard remote (which reads
-- LeaderboardHandler's OrderedDataStores) and refreshed periodically.
-- Same SurfaceGui-on-a-physical-face approach as every other board here,
-- for the same reason - a BillboardGui would visibly slide around as the
-- camera orbits past it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getLeaderboardFunction = remotes:WaitForChild("GetLeaderboard")

local kiosks = Workspace:WaitForChild("Kiosks")

local REFRESH_INTERVAL = 20
local TEXT_STROKE_TRANSPARENCY = 0.4

local function formatPlaytime(totalSeconds: number): string
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	if hours > 0 then
		return ("%dh %dm"):format(hours, minutes)
	end
	return ("%dm"):format(minutes)
end

-- Each board's own value formatter, since Playtime/Robux/Mana/Runes all
-- read differently even though they share the same list layout.
local BOARDS = {
	{ partName = "LeaderboardPlaytimeBoard", statKey = "playtime", title = "Playtime", format = formatPlaytime },
	{ partName = "LeaderboardRobuxBoard", statKey = "robux", title = "Robux Spent", format = function(v)
		return "R$" .. NumberFormat.format(v)
	end },
	{ partName = "LeaderboardManaBoard", statKey = "mana", title = "Total Mana", format = NumberFormat.format },
	{ partName = "LeaderboardRunesBoard", statKey = "runes", title = "Runes Opened", format = NumberFormat.format },
}

local ROW_COUNT = 5

local function buildBoard(config)
	local board = kiosks:WaitForChild(config.partName)

	-- Faces back toward the starting island, i.e. the +Z direction players
	-- approach from when crossing the bridge (the opposite of SecondIslandGate's
	-- Front, since this island sits on the other side) - a guess like every
	-- other board's SurfaceGui face here; flip to Front if it renders
	-- unreadable from the approach side.
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = config.partName .. "Gui"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.Adornee = board
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = board

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	background.BackgroundTransparency = 0.15
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.9, 0, 0.14, 0)
	titleBanner.Position = UDim2.new(0.05, 0, 0.04, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	titleBanner.BorderSizePixel = 0
	titleBanner.Parent = background

	local titleBannerCorner = Instance.new("UICorner")
	titleBannerCorner.CornerRadius = UDim.new(0.2, 0)
	titleBannerCorner.Parent = titleBanner

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, 0, 1, 0)
	titleText.BackgroundTransparency = 1
	titleText.Font = Enum.Font.GothamBold
	titleText.TextScaled = true
	titleText.TextColor3 = Color3.fromRGB(255, 220, 90)
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = config.title
	titleText.Parent = titleBanner

	local rowLabels = {}
	local ROW_TOP_Y = 0.22
	local ROW_HEIGHT = 0.13
	for i = 1, ROW_COUNT do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.9, 0, ROW_HEIGHT, 0)
		row.Position = UDim2.new(0.05, 0, ROW_TOP_Y + (i - 1) * ROW_HEIGHT, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Gotham
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(30, 30, 40)
		row.Text = ("%d. -"):format(i)
		row.Parent = background
		rowLabels[i] = row
	end

	local function refresh()
		local entries = getLeaderboardFunction:InvokeServer(config.statKey)
		for i = 1, ROW_COUNT do
			local entry = entries[i]
			if entry then
				rowLabels[i].Text = ("%d. %s - %s"):format(i, entry.name, config.format(entry.value))
			else
				rowLabels[i].Text = ("%d. -"):format(i)
			end
		end
	end

	refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			refresh()
		end
	end)
end

for _, config in BOARDS do
	buildBoard(config)
end
