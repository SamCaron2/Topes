-- Middle-left "Mana: <amount>" counter, plus a "Rebirths: <amount>" counter
-- right below it - hidden until the player has at least one Rebirth (the
-- server only fires RebirthsUpdated once they do), so it only appears once
-- Rebirths are actually unlocked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Middle-left of the screen: vertically centered, flush against the left edge.
local manaLabel = Instance.new("TextLabel")
manaLabel.Name = "ManaCounter"
manaLabel.AnchorPoint = Vector2.new(0, 0.5)
manaLabel.Position = UDim2.new(0, 10, 0.5, 0)
manaLabel.Size = UDim2.new(0, 220, 0, 50)
manaLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
manaLabel.BackgroundTransparency = 0.35
manaLabel.BorderSizePixel = 0
manaLabel.Font = Enum.Font.GothamBold
manaLabel.TextSize = 28
manaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
manaLabel.TextStrokeTransparency = 0.5
manaLabel.TextXAlignment = Enum.TextXAlignment.Center
manaLabel.Text = "Mana: 0"
manaLabel.Parent = screenGui

local manaCorner = Instance.new("UICorner")
manaCorner.CornerRadius = UDim.new(0, 8)
manaCorner.Parent = manaLabel

local rebirthsLabel = Instance.new("TextLabel")
rebirthsLabel.Name = "RebirthsCounter"
rebirthsLabel.Visible = false
rebirthsLabel.AnchorPoint = Vector2.new(0, 0.5)
rebirthsLabel.Position = UDim2.new(0, 10, 0.5, 60)
rebirthsLabel.Size = UDim2.new(0, 220, 0, 50)
rebirthsLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
rebirthsLabel.BackgroundTransparency = 0.35
rebirthsLabel.BorderSizePixel = 0
rebirthsLabel.Font = Enum.Font.GothamBold
rebirthsLabel.TextSize = 28
rebirthsLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
rebirthsLabel.TextStrokeTransparency = 0.5
rebirthsLabel.TextXAlignment = Enum.TextXAlignment.Center
rebirthsLabel.Text = "Rebirths: 0"
rebirthsLabel.Parent = screenGui

local rebirthsCorner = Instance.new("UICorner")
rebirthsCorner.CornerRadius = UDim.new(0, 8)
rebirthsCorner.Parent = rebirthsLabel

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	manaLabel.Text = ("Mana: %d"):format(amount)
end)

rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
	rebirthsLabel.Visible = true
	rebirthsLabel.Text = ("Rebirths: %.1f"):format(amount)
end)
