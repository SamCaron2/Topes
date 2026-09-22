-- The Profile panel: opened by clicking the Profile icon in the side menu
-- (SideMenuClient fires OpenProfileRequested). Two pages in one panel -
-- "Profile" (avatar, name, and the 4 stats requested: Time Played, Total
-- Mana, Runes Opened, Robux Spent) and "Titles" (every GameConfig.Titles
-- entry, locked ones grayed out with their unlock condition, unlocked
-- ones with an Equip/Unequip button) - a "Titles" button on the Profile
-- page switches to it, a "Back" button on the Titles page returns. Both
-- pages pull from the existing GetProfile/EquipTitle remotes, which were
-- already wired server-side but never called from any client script until
-- now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getProfileFunction = remotes:WaitForChild("GetProfile")
local equipTitleFunction = remotes:WaitForChild("EquipTitle")

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_LOCKED = Color3.fromRGB(90, 90, 90)
local COLOR_EQUIP = Color3.fromRGB(70, 190, 60)
local COLOR_UNEQUIP = Color3.fromRGB(200, 55, 55)
local COLOR_EQUIPPED_TAG = Color3.fromRGB(255, 210, 60)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProfileUI"
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
panel.Size = UDim2.new(0, 460, 0, 480)
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

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(90, 20, 20)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Parent = panel

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(1, 0)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

-- ===========================================================================
-- Profile page: avatar + name, then the 4 requested stats.
local profilePage = Instance.new("Frame")
profilePage.Size = UDim2.new(1, 0, 1, 0)
profilePage.BackgroundTransparency = 1
profilePage.Parent = panel

local avatar = Instance.new("ImageLabel")
avatar.AnchorPoint = Vector2.new(0.5, 0)
avatar.Position = UDim2.new(0.5, 0, 0, 24)
avatar.Size = UDim2.new(0, 90, 0, 90)
avatar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
avatar.Parent = profilePage

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(1, 0)
avatarCorner.Parent = avatar

task.spawn(function()
	local success, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if success and content then
		avatar.Image = content
		avatar.BackgroundTransparency = 1
	end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.AnchorPoint = Vector2.new(0.5, 0)
nameLabel.Position = UDim2.new(0.5, 0, 0, 122)
nameLabel.Size = UDim2.new(1, -40, 0, 30)
nameLabel.BackgroundTransparency = 1
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = GOLD
nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
nameLabel.Text = player.DisplayName
nameLabel.Parent = profilePage

local statsFrame = Instance.new("Frame")
statsFrame.Position = UDim2.new(0, 30, 0, 175)
statsFrame.Size = UDim2.new(1, -60, 0, 200)
statsFrame.BackgroundTransparency = 1
statsFrame.Parent = profilePage

local statsLayout = Instance.new("UIListLayout")
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 10)
statsLayout.Parent = statsFrame

local function createStatRow(layoutOrder: number, label: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BackgroundTransparency = 0.9
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = statsFrame

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0.25, 0)
	rowCorner.Parent = row

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(0.55, 0, 1, 0)
	labelText.Position = UDim2.new(0.05, 0, 0, 0)
	labelText.BackgroundTransparency = 1
	labelText.Font = Enum.Font.Gotham
	labelText.TextScaled = true
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextColor3 = Color3.fromRGB(220, 220, 220)
	labelText.Text = label
	labelText.Parent = row

	local valueText = Instance.new("TextLabel")
	valueText.Size = UDim2.new(0.4, 0, 1, 0)
	valueText.Position = UDim2.new(0.55, 0, 0, 0)
	valueText.BackgroundTransparency = 1
	valueText.Font = Enum.Font.GothamBold
	valueText.TextScaled = true
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	valueText.Text = "-"
	valueText.Parent = row

	return valueText
end

local timePlayedValue = createStatRow(1, "Time Played")
local totalManaValue = createStatRow(2, "Total Mana")
local runesOpenedValue = createStatRow(3, "Runes Opened")
local robuxSpentValue = createStatRow(4, "Robux Spent")

local titlesPageButton = Instance.new("TextButton")
titlesPageButton.AnchorPoint = Vector2.new(0.5, 1)
titlesPageButton.Position = UDim2.new(0.5, 0, 1, -24)
titlesPageButton.Size = UDim2.new(0, 200, 0, 44)
titlesPageButton.BackgroundColor3 = Color3.fromRGB(90, 15, 15)
titlesPageButton.Font = Enum.Font.GothamBold
titlesPageButton.TextScaled = true
titlesPageButton.TextColor3 = GOLD
titlesPageButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titlesPageButton.Text = "Titles ➜"
titlesPageButton.Parent = profilePage

local titlesPageButtonCorner = Instance.new("UICorner")
titlesPageButtonCorner.CornerRadius = UDim.new(0.3, 0)
titlesPageButtonCorner.Parent = titlesPageButton

local function formatPlaytime(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	return ("%dh %dm"):format(hours, minutes)
end

local function renderProfilePage(profile)
	if not profile then
		return
	end
	timePlayedValue.Text = formatPlaytime(profile.playtimeSeconds or 0)
	totalManaValue.Text = NumberFormat.format(profile.totalManaEarned or 0)
	runesOpenedValue.Text = NumberFormat.format(profile.runesOpened or 0)
	robuxSpentValue.Text = ("R$%s"):format(NumberFormat.format(profile.robuxSpent or 0))
end

-- ===========================================================================
-- Titles page: every GameConfig.Titles entry, locked ones grayed out with
-- their unlock condition spelled out, unlocked ones with an Equip/Unequip
-- button.
local titlesPage = Instance.new("Frame")
titlesPage.Size = UDim2.new(1, 0, 1, 0)
titlesPage.BackgroundTransparency = 1
titlesPage.Visible = false
titlesPage.Parent = panel

local backButton = Instance.new("TextButton")
backButton.Position = UDim2.new(0, 12, 0, 12)
backButton.Size = UDim2.new(0, 90, 0, 32)
backButton.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
backButton.Font = Enum.Font.GothamBold
backButton.TextScaled = true
backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
backButton.Text = "⬅ Back"
backButton.Parent = titlesPage

local backButtonCorner = Instance.new("UICorner")
backButtonCorner.CornerRadius = UDim.new(0.3, 0)
backButtonCorner.Parent = backButton

local titlesHeader = Instance.new("TextLabel")
titlesHeader.AnchorPoint = Vector2.new(0.5, 0)
titlesHeader.Position = UDim2.new(0.5, 0, 0, 14)
titlesHeader.Size = UDim2.new(0, 200, 0, 30)
titlesHeader.BackgroundTransparency = 1
titlesHeader.Font = Enum.Font.GothamBold
titlesHeader.TextScaled = true
titlesHeader.TextColor3 = GOLD
titlesHeader.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titlesHeader.Text = "Titles"
titlesHeader.Parent = titlesPage

local titlesScroll = Instance.new("ScrollingFrame")
titlesScroll.Position = UDim2.new(0, 20, 0, 58)
titlesScroll.Size = UDim2.new(1, -40, 1, -78)
titlesScroll.BackgroundTransparency = 1
titlesScroll.BorderSizePixel = 0
titlesScroll.ScrollBarThickness = 6
titlesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
titlesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
titlesScroll.Parent = titlesPage

local titlesListLayout = Instance.new("UIListLayout")
titlesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
titlesListLayout.Padding = UDim.new(0, 8)
titlesListLayout.Parent = titlesScroll

-- Every GameConfig condition type in plain English - none of the config
-- entries carry a human-readable description, so this is what builds one.
local function describeCondition(title)
	local condition = title.condition
	if condition.type == "playtimeSeconds" then
		local hours = condition.value / 3600
		if hours < 24 then
			return ("Play for %g hour%s"):format(hours, hours == 1 and "" or "s")
		end
		return ("Play for %g day%s"):format(hours / 24, hours / 24 == 1 and "" or "s")
	elseif condition.type == "robuxSpent" then
		return ("Spend R$%s total"):format(NumberFormat.format(condition.value))
	elseif condition.type == "groupMember" then
		return "Join the group"
	elseif condition.type == "gamePassOwned" then
		return ("Own the %s gamepass"):format(condition.passKey)
	elseif condition.type == "joinWindow" then
		return "Join during launch week"
	end
	return "Granted manually"
end

local titleRows = {} -- [key] = { equipText = TextButton, nameLabel = TextLabel }
local currentProfile = nil

local function updateTitleRowVisual(title)
	local row = titleRows[title.key]
	if not row or not currentProfile then
		return
	end

	local unlocked = currentProfile.unlockedTitles and currentProfile.unlockedTitles[title.key]
	local equipped = currentProfile.equippedTitle == title.key

	row.nameLabel.TextColor3 = unlocked and title.color or COLOR_LOCKED

	if not unlocked then
		row.actionButton.Visible = false
		row.conditionLabel.Visible = true
	elseif equipped then
		row.actionButton.Visible = true
		row.actionButton.Text = "Equipped"
		row.actionButton.BackgroundColor3 = COLOR_EQUIPPED_TAG
		row.conditionLabel.Visible = false
	else
		row.actionButton.Visible = true
		row.actionButton.Text = "Equip"
		row.actionButton.BackgroundColor3 = COLOR_EQUIP
		row.conditionLabel.Visible = false
	end
end

local function buildTitleRow(layoutOrder: number, title)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 54)
	row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	row.BackgroundTransparency = 0.92
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.Parent = titlesScroll

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0.2, 0)
	rowCorner.Parent = row

	local nameText = Instance.new("TextLabel")
	nameText.Size = UDim2.new(0.5, 0, 0.5, 0)
	nameText.Position = UDim2.new(0.04, 0, 0.08, 0)
	nameText.BackgroundTransparency = 1
	nameText.Font = Enum.Font.GothamBold
	nameText.TextScaled = true
	nameText.TextXAlignment = Enum.TextXAlignment.Left
	nameText.TextColor3 = title.color
	nameText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameText.Text = title.displayName
	nameText.Parent = row

	local conditionLabel = Instance.new("TextLabel")
	conditionLabel.Size = UDim2.new(0.92, 0, 0.4, 0)
	conditionLabel.Position = UDim2.new(0.04, 0, 0.55, 0)
	conditionLabel.BackgroundTransparency = 1
	conditionLabel.Font = Enum.Font.Gotham
	conditionLabel.TextScaled = true
	conditionLabel.TextXAlignment = Enum.TextXAlignment.Left
	conditionLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	conditionLabel.Text = describeCondition(title)
	conditionLabel.Parent = row

	local actionButton = Instance.new("TextButton")
	actionButton.AnchorPoint = Vector2.new(1, 0.5)
	actionButton.Position = UDim2.new(0.96, 0, 0.5, 0)
	actionButton.Size = UDim2.new(0, 100, 0, 34)
	actionButton.Font = Enum.Font.GothamBold
	actionButton.TextScaled = true
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	actionButton.Parent = row

	local actionButtonCorner = Instance.new("UICorner")
	actionButtonCorner.CornerRadius = UDim.new(0.3, 0)
	actionButtonCorner.Parent = actionButton

	actionButton.MouseButton1Click:Connect(function()
		if not currentProfile then
			return
		end
		local equipped = currentProfile.equippedTitle == title.key
		local success = equipTitleFunction:InvokeServer(equipped and nil or title.key)
		if success then
			currentProfile.equippedTitle = equipped and nil or title.key
			for _, otherTitle in GameConfig.Titles do
				updateTitleRowVisual(otherTitle)
			end
		end
	end)

	titleRows[title.key] = { nameLabel = nameText, conditionLabel = conditionLabel, actionButton = actionButton }
end

for index, title in GameConfig.Titles do
	buildTitleRow(index, title)
end

local function renderTitlesPage()
	for _, title in GameConfig.Titles do
		updateTitleRowVisual(title)
	end
end

-- ===========================================================================
titlesPageButton.MouseButton1Click:Connect(function()
	profilePage.Visible = false
	titlesPage.Visible = true
	renderTitlesPage()
end)

backButton.MouseButton1Click:Connect(function()
	titlesPage.Visible = false
	profilePage.Visible = true
end)

local sideMenuHUD = player:WaitForChild("PlayerGui"):WaitForChild("SideMenuHUD")
local openProfileEvent = sideMenuHUD:WaitForChild("OpenProfileRequested")

openProfileEvent.Event:Connect(function()
	if screenGui.Enabled then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true
	profilePage.Visible = true
	titlesPage.Visible = false

	local profile = getProfileFunction:InvokeServer()
	currentProfile = profile
	renderProfilePage(profile)
end)
