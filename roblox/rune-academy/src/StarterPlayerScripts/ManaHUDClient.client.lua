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

local label = Instance.new("TextLabel")
label.Name = "ManaCounter"
label.Position = UDim2.new(0, 20, 0, 20)
label.Size = UDim2.new(0, 200, 0, 40)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 24
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextStrokeTransparency = 0.5
label.TextXAlignment = Enum.TextXAlignment.Left
label.Text = "Mana: 0"
label.Parent = screenGui

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	label.Text = ("Mana: %d"):format(amount)
end)
