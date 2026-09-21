-- Right-side icon menu: Store, Runes, Profile, Settings, laid out 2x2. Store
-- and Settings use uploaded icon images; Runes and Profile still use
-- placeholder symbol icons (safe basic Unicode glyphs, not emoji, so they
-- render reliably) until they get real art too. Hovering grows the icon
-- slightly to show what's highlighted. No panels wired up yet - just needs
-- to exist on screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local BUTTON_SIZE = 70
local GRID_GAP = 16
local HOVER_SCALE = 1.15
local HOVER_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MENU_ITEMS = {
	{ name = "Store", symbol = "$", color = Color3.fromRGB(70, 190, 90), imageId = "rbxassetid://87898848906072" },
	{ name = "Runes", symbol = "\u{2726}", color = Color3.fromRGB(150, 80, 255) },
	{ name = "Profile", symbol = "\u{263A}", color = Color3.fromRGB(70, 150, 220) },
	{ name = "Settings", symbol = "\u{2699}", color = Color3.fromRGB(120, 120, 130), imageId = "rbxassetid://90039600568167" },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SideMenuHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local CELL_HEIGHT = BUTTON_SIZE + 36 -- room for the button, the gap, and the label below it

-- Vertically centered on the right edge, mirroring the Mana counter's
-- placement on the left.
local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 0.5)
container.Position = UDim2.new(1, -20, 0.5, 0)
container.Size = UDim2.new(0, BUTTON_SIZE * 2 + GRID_GAP, 0, CELL_HEIGHT * 2 + GRID_GAP)
container.BackgroundTransparency = 1
container.Parent = screenGui

local layout = Instance.new("UIGridLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.CellSize = UDim2.new(0, BUTTON_SIZE, 0, CELL_HEIGHT)
layout.CellPadding = UDim2.new(0, GRID_GAP, 0, GRID_GAP)
layout.FillDirectionMaxCells = 2
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = container

local function createMenuButton(layoutOrder: number, name: string, symbol: string, color: Color3, imageId: string?)
	local wrapper = Instance.new("Frame")
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder = layoutOrder
	wrapper.Parent = container

	local baseSize = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
	local hoverSize = UDim2.new(0, BUTTON_SIZE * HOVER_SCALE, 0, BUTTON_SIZE * HOVER_SCALE)

	-- Centered (not top-anchored) so hover growth expands evenly in every
	-- direction instead of pushing down into the label below.
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.new(0.5, 0, 0, BUTTON_SIZE / 2)
	button.Size = baseSize
	button.BackgroundColor3 = color
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = wrapper

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	-- Real icon art when we have it (Store, Settings); everything else still
	-- falls back to a TextScaled glyph filling most of the circle.
	if imageId then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.Parent = button

		local iconPadding = Instance.new("UIPadding")
		iconPadding.PaddingTop = UDim.new(0.15, 0)
		iconPadding.PaddingBottom = UDim.new(0.15, 0)
		iconPadding.PaddingLeft = UDim.new(0.15, 0)
		iconPadding.PaddingRight = UDim.new(0.15, 0)
		iconPadding.Parent = icon
	else
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBold
		icon.TextScaled = true
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextStrokeTransparency = 0.5
		icon.Text = symbol
		icon.Parent = button

		local iconPadding = Instance.new("UIPadding")
		iconPadding.PaddingTop = UDim.new(0.2, 0)
		iconPadding.PaddingBottom = UDim.new(0.2, 0)
		iconPadding.PaddingLeft = UDim.new(0.2, 0)
		iconPadding.PaddingRight = UDim.new(0.2, 0)
		iconPadding.Parent = icon
	end

	-- Bold display font with a heavy stroke for a "cool logo" look, distinct
	-- from the plainer Gotham text used elsewhere in the HUD.
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Position = UDim2.new(0, 0, 0, BUTTON_SIZE + 8)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(255, 220, 90)
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Text = name
	label.Parent = wrapper

	button.MouseEnter:Connect(function()
		TweenService:Create(button, HOVER_TWEEN_INFO, { Size = hoverSize }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, HOVER_TWEEN_INFO, { Size = baseSize }):Play()
	end)

	return button
end

for index, item in MENU_ITEMS do
	createMenuButton(index, item.name, item.symbol, item.color, item.imageId)
end
