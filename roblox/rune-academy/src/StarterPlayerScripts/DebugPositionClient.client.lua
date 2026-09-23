-- DEV/TESTING ONLY: a small always-on corner label showing this player's
-- live world position (rounded to the nearest stud), so positioning
-- requests can be given as exact numbers ("put it at X -260, Z 610")
-- instead of screenshots + guesswork. Remove this file before shipping -
-- it's not meant for real players to see.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DebugPositionUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 50
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0, 1)
label.Position = UDim2.new(0, 8, 1, -8)
label.Size = UDim2.new(0, 260, 0, 26)
label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
label.BackgroundTransparency = 0.4
label.BorderSizePixel = 0
label.Font = Enum.Font.Code
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextXAlignment = Enum.TextXAlignment.Left
label.Text = "X 0  Y 0  Z 0"
label.Parent = screenGui

local labelCorner = Instance.new("UICorner")
labelCorner.CornerRadius = UDim.new(0, 6)
labelCorner.Parent = label

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local pos = rootPart.Position
	label.Text = ("X %d  Y %d  Z %d"):format(math.round(pos.X), math.round(pos.Y), math.round(pos.Z))
end)
