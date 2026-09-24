-- The Profile panel: opened by clicking the Profile icon in the side menu
-- (SideMenuClient fires OpenProfileRequested). A single "Stats" page -
-- avatar, name, and the 4 stats requested: Time Played, Total Mana, Runes
-- Opened, Robux Spent - pulling from the GetProfile remote. Used to also
-- have a "Titles" tab/page (every GameConfig.Titles entry, locked ones
-- grayed out with their unlock condition, unlocked ones with an
-- Equip/Unequip button), removed along with the rest of the Titles
-- system during the Power Store cleanup (it was leftover from an earlier,
-- scrapped design - nothing in the current game ever unlocked a title).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getProfileFunction = remotes:WaitForChild("GetProfile")

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4

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

-- Title label where the Stats/Titles tab bar used to sit, before the
-- Titles page was removed - "Stats" per the same direct request that
-- originally named this page ("was unnamed before").
local titleLabel = Instance.new("TextLabel")
titleLabel.Position = UDim2.new(0, 20, 0, 12)
titleLabel.Size = UDim2.new(0, 160, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = GOLD
titleLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleLabel.Text = "Stats"
titleLabel.Parent = panel

-- ===========================================================================
-- Stats page: avatar + name, then the 4 requested stats.
local profilePage = Instance.new("Frame")
profilePage.Position = UDim2.new(0, 0, 0, 40)
profilePage.Size = UDim2.new(1, 0, 1, -40)
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

local sideMenuHUD = player:WaitForChild("PlayerGui"):WaitForChild("SideMenuHUD")
local openProfileEvent = sideMenuHUD:WaitForChild("OpenProfileRequested")

openProfileEvent.Event:Connect(function()
	if screenGui.Enabled then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true

	local profile = getProfileFunction:InvokeServer()
	renderProfilePage(profile)
end)
