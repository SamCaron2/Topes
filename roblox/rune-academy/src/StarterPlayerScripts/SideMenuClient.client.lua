-- Right-side icon menu: Store, Runes, Profile, Settings, laid out 2x2 on a
-- high-opacity dark panel, with a small toggle tab above it to slide the
-- whole thing off-screen and hide it. Store, Settings, and Runes all use
-- uploaded icon images now; Profile gets the player's own live avatar
-- headshot instead (fetched via GetUserThumbnailAsync, no upload needed -
-- see below). Hovering grows the icon slightly to show what's highlighted.
-- Profile, Runes, and Settings are all wired to their own panels
-- (ProfileClient/RunesMenuClient/SettingsClient, via the
-- OpenProfileRequested/OpenRunesRequested/OpenSettingsRequested
-- BindableEvents below) - per direct request ("clicking the runes
-- button... nothing is happening" and "add some relevant settings in the
-- settings section"), Runes opens the same Rune Altar tier list the
-- physical board on SecondIsland shows, so it's checkable from anywhere,
-- not just standing at the Altar. Store still just needs to exist on
-- screen for now (nothing to sell yet).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local BUTTON_SIZE = 70
local GRID_GAP = 16
local HOVER_SCALE = 1.15
local HOVER_TWEEN_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MENU_ITEMS = {
	{ name = "Store", symbol = "$", color = Color3.fromRGB(70, 190, 90), imageId = "rbxassetid://87898848906072" },
	{ name = "Runes", symbol = "\u{2726}", color = Color3.fromRGB(150, 80, 255), imageId = "rbxassetid://94841473802618" },
	{ name = "Profile", symbol = "\u{263A}", color = Color3.fromRGB(70, 150, 220) },
	{ name = "Settings", symbol = "\u{2699}", color = Color3.fromRGB(120, 120, 130), imageId = "rbxassetid://90039600568167" },
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SideMenuHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local CELL_HEIGHT = BUTTON_SIZE + 36 -- room for the button, the gap, and the label below it
local PANEL_PADDING = 16
local PANEL_WIDTH = BUTTON_SIZE * 2 + GRID_GAP + PANEL_PADDING * 2
local PANEL_HEIGHT = CELL_HEIGHT * 2 + GRID_GAP + PANEL_PADDING * 2
local PANEL_EDGE_OFFSET = 20

-- A high-opacity dark panel behind the whole grid (not just transparent
-- background), per direct request, so the icons read as one solid unit
-- instead of floating loose over the world.
local panel = Instance.new("Frame")
panel.Name = "SideMenuPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -PANEL_EDGE_OFFSET, 0.5, 0)
panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.new(0.5, 0, 0.5, 0)
container.Size = UDim2.new(0, BUTTON_SIZE * 2 + GRID_GAP, 0, CELL_HEIGHT * 2 + GRID_GAP)
container.BackgroundTransparency = 1
container.Parent = panel

-- A small fixed tab above the panel - always in the same spot regardless
-- of collapsed state - that tweens the whole panel off-screen to the
-- right (and back), per direct request to be able to hide the menu.
local COLLAPSE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EXPANDED_POSITION = panel.Position
-- Shifted right by its own full width (plus the edge gap it started with),
-- guaranteeing the whole panel clears the screen's right edge.
local COLLAPSED_POSITION = UDim2.new(1, PANEL_WIDTH, 0.5, 0)

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "SideMenuToggle"
toggleButton.AnchorPoint = Vector2.new(1, 1)
toggleButton.Position = UDim2.new(1, -PANEL_EDGE_OFFSET, 0.5, -(PANEL_HEIGHT / 2) - 10)
toggleButton.Size = UDim2.new(0, 36, 0, 36)
toggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
toggleButton.BackgroundTransparency = 0.1
toggleButton.AutoButtonColor = false
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextScaled = true
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "\u{25B6}" -- ▶ - click collapses the panel this direction
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggleButton

local collapsed = false
toggleButton.MouseButton1Click:Connect(function()
	collapsed = not collapsed
	TweenService:Create(panel, COLLAPSE_TWEEN_INFO, { Position = collapsed and COLLAPSED_POSITION or EXPANDED_POSITION }):Play()
	toggleButton.Text = collapsed and "\u{25C0}" or "\u{25B6}" -- ◀ once collapsed (click to bring it back)
end)

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
	-- Real icon art already reads fine on its own - only the placeholder
	-- glyphs need the colored circle behind them for contrast/shape.
	button.BackgroundColor3 = color
	button.BackgroundTransparency = imageId and 1 or 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = wrapper

	if not imageId then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
	end

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

local buttonsByName = {}
for index, item in MENU_ITEMS do
	buttonsByName[item.name] = createMenuButton(index, item.name, item.symbol, item.color, item.imageId)
end

-- ProfileClient owns the actual panel (separate concern, separate script) -
-- this just fires a BindableEvent parented under this same ScreenGui so it
-- can be found reliably regardless of which script's PlayerAdded-equivalent
-- runs first.
local openProfileEvent = Instance.new("BindableEvent")
openProfileEvent.Name = "OpenProfileRequested"
openProfileEvent.Parent = screenGui

buttonsByName["Profile"].MouseButton1Click:Connect(function()
	openProfileEvent:Fire()
end)

local openRunesEvent = Instance.new("BindableEvent")
openRunesEvent.Name = "OpenRunesRequested"
openRunesEvent.Parent = screenGui

buttonsByName["Runes"].MouseButton1Click:Connect(function()
	openRunesEvent:Fire()
end)

local openSettingsEvent = Instance.new("BindableEvent")
openSettingsEvent.Name = "OpenSettingsRequested"
openSettingsEvent.Parent = screenGui

buttonsByName["Settings"].MouseButton1Click:Connect(function()
	openSettingsEvent:Fire()
end)

-- Profile gets the PLAYER'S OWN avatar headshot instead of a placeholder
-- symbol - fetched live via GetUserThumbnailAsync, no uploaded asset
-- needed since Roblox already renders and hosts this per-player. Swapped
-- in after the fact (starts as the usual placeholder circle+glyph, same
-- as Runes) since the fetch is a yielding network call.
task.spawn(function()
	local success, content = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if not success or not content then
		return
	end

	local profileButton = buttonsByName["Profile"]
	if not profileButton then
		return
	end

	-- Clear the placeholder glyph - the avatar image reads fine on its own,
	-- same as the Store/Settings uploaded icons, so drop the colored circle.
	for _, child in profileButton:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	profileButton.BackgroundTransparency = 1

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Image = content
	icon.Parent = profileButton

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = icon
end)
