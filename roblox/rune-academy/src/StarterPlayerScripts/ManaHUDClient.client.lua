-- Left-side "Mana: <amount>" counter. Plain text for now - an icon comes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManaHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Middle-left of the screen: vertically centered, offset in from the left
-- edge (not flush against it) so it clears the Roblox top bar/menu icons.
local label = Instance.new("TextLabel")
label.Name = "ManaCounter"
label.AnchorPoint = Vector2.new(0, 0.5)
label.Position = UDim2.new(0, 220, 0.5, 0)
label.Size = UDim2.new(0, 220, 0, 50)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
label.BackgroundTransparency = 0.35
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 28
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeTransparency = 0.5
label.TextXAlignment = Enum.TextXAlignment.Center
label.Text = "Mana: 0"
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	label.Text = ("Mana: %d"):format(amount)
end)
