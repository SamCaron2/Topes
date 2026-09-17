-- Builds the "Mana Per Pickup" upgrade card's BillboardGui: level, current
-- yield, next level's cost, and a Buy button. Sized in studs (not screen
-- scale) so it reads as a physical sign that shrinks with distance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getManaYieldStateFunction = remotes:WaitForChild("GetManaYieldState")
local buyManaYieldUpgradeFunction = remotes:WaitForChild("BuyManaYieldUpgrade")

local kiosk = Workspace:WaitForChild("Kiosks"):WaitForChild("ManaYieldKiosk")

-- StudsOffsetWorldSpace (not the rotation-relative StudsOffset) pushes the
-- flat, always-camera-facing panel out in front of the card's actual face
-- rather than leaving it coincident with the card's center - without that
-- gap, the panel and the card's real geometry visibly slide against each
-- other as the camera orbits, since one has depth and the other doesn't.
local billboard = Instance.new("BillboardGui")
billboard.Name = "ManaYieldBoard"
billboard.Size = UDim2.new(9, 0, 12, 0) -- Scale component = studs on a BillboardGui
billboard.StudsOffsetWorldSpace = Vector3.new(-(kiosk.Size.X / 2 + 0.6), 0, 0)
billboard.MaxDistance = 60
-- Without this, the panel is depth-tested against real 3D geometry, so the
-- card's own body (or anything else between it and the camera) cuts into
-- different parts of the flat panel as the camera orbits - looks like the
-- panel is "moving" when it's actually the card occluding it inconsistently.
billboard.AlwaysOnTop = true
billboard.Adornee = kiosk
billboard.Parent = kiosk

local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = billboard

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.08, 0)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Text = "Mana Per Pickup"
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0.2, 0)
title.Position = UDim2.new(0, 0, 0.03, 0)
title.Parent = frame

local levelLabel = Instance.new("TextLabel")
levelLabel.Font = Enum.Font.Gotham
levelLabel.TextSize = 18
levelLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
levelLabel.BackgroundTransparency = 1
levelLabel.Size = UDim2.new(1, 0, 0.15, 0)
levelLabel.Position = UDim2.new(0, 0, 0.25, 0)
levelLabel.Text = "Level -/-"
levelLabel.Parent = frame

local yieldLabel = Instance.new("TextLabel")
yieldLabel.Font = Enum.Font.Gotham
yieldLabel.TextSize = 18
yieldLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
yieldLabel.BackgroundTransparency = 1
yieldLabel.Size = UDim2.new(1, 0, 0.15, 0)
yieldLabel.Position = UDim2.new(0, 0, 0.4, 0)
yieldLabel.Text = "+- Mana / pickup"
yieldLabel.Parent = frame

local buyButton = Instance.new("TextButton")
buyButton.Font = Enum.Font.GothamBold
buyButton.TextSize = 20
buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
buyButton.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
buyButton.Size = UDim2.new(0.85, 0, 0.22, 0)
buyButton.Position = UDim2.new(0.075, 0, 0.72, 0)
buyButton.Text = "Buy: -"
buyButton.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = buyButton

local function render(state)
	if not state then
		return
	end

	levelLabel.Text = ("Level %d/%d"):format(state.level, state.maxLevel)
	yieldLabel.Text = ("+%d Mana / pickup"):format(state.amountPerPickup)

	if state.nextLevelCost then
		buyButton.Text = ("Buy: %d Mana"):format(state.nextLevelCost)
		buyButton.Active = true
		buyButton.BackgroundColor3 = Color3.fromRGB(90, 60, 200)
	else
		buyButton.Text = "MAX LEVEL"
		buyButton.Active = false
		buyButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	end
end

render(getManaYieldStateFunction:InvokeServer())

buyButton.MouseButton1Click:Connect(function()
	local success, _, newState = buyManaYieldUpgradeFunction:InvokeServer()
	if success then
		render(newState)
	end
end)
