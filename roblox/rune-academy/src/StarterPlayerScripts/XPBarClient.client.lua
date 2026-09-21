-- Bottom-middle XP bar: "Level <N>" above a progress bar that fills as XP
-- approaches the next level, with "<xp> / <xpToNextLevel> XP" over the bar
-- itself. Every Mana pickup grants XP server-side (XPHandler) and fires
-- XPUpdated - this just renders whatever state the server sends. Once
-- maxLevel is reached the bar shows full and "MAX LEVEL" instead of a
-- fraction, since xpToNextLevel is nil at that point.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getXPStateFunction = remotes:WaitForChild("GetXPState")
local xpUpdatedEvent = remotes:WaitForChild("XPUpdated")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XPBar"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "XPBarContainer"
container.AnchorPoint = Vector2.new(0.5, 1)
container.Position = UDim2.new(0.5, 0, 1, -20)
container.Size = UDim2.new(0, 340, 0, 54)
container.BackgroundTransparency = 1
container.Parent = screenGui

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(1, 0, 0, 20)
levelLabel.Position = UDim2.new(0, 0, 0, 0)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextSize = 18
levelLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
levelLabel.TextStrokeTransparency = 0.5
levelLabel.Text = "Level 1"
levelLabel.Parent = container

local barBackground = Instance.new("Frame")
barBackground.Name = "BarBackground"
barBackground.Position = UDim2.new(0, 0, 0, 24)
barBackground.Size = UDim2.new(1, 0, 0, 24)
barBackground.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
barBackground.BackgroundTransparency = 0.25
barBackground.BorderSizePixel = 0
barBackground.Parent = container

local barBackgroundCorner = Instance.new("UICorner")
barBackgroundCorner.CornerRadius = UDim.new(0.5, 0)
barBackgroundCorner.Parent = barBackground

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(150, 220, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBackground

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0.5, 0)
barFillCorner.Parent = barFill

local xpText = Instance.new("TextLabel")
xpText.Name = "XPText"
xpText.Size = UDim2.new(1, 0, 1, 0)
xpText.BackgroundTransparency = 1
xpText.Font = Enum.Font.GothamBold
xpText.TextSize = 16
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.TextStrokeTransparency = 0.4
xpText.Text = "0 / 100 XP"
xpText.ZIndex = 2
xpText.Parent = barBackground

local function render(state)
	if not state then
		return
	end

	levelLabel.Text = ("Level %d"):format(state.level)

	if state.xpToNextLevel then
		local fraction = math.clamp(state.xp / state.xpToNextLevel, 0, 1)
		barFill.Size = UDim2.new(fraction, 0, 1, 0)
		xpText.Text = ("%d / %d XP"):format(state.xp, state.xpToNextLevel)
	else
		barFill.Size = UDim2.new(1, 0, 1, 0)
		xpText.Text = "MAX LEVEL"
	end
end

render(getXPStateFunction:InvokeServer())

xpUpdatedEvent.OnClientEvent:Connect(render)
