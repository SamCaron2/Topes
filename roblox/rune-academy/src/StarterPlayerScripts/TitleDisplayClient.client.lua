-- Floating username + equipped title above every player's head (own
-- included, so it matches what everyone else sees), per direct request
-- ("I want it to say your username above your head and underneath the
-- username is your title. Have it be [None] if they don't equip
-- anything"). Reads Player attributes only (Title/TitleColor/
-- TitleRainbow, set by TitleHandler.applyAttributesFor/equipTitle) - no
-- remote round-trip needed, and this file is exactly what earlier
-- comments in TitleHandler already described but never actually built.
-- Updates live the moment someone (re)equips a different title, via
-- GetAttributeChangedSignal.
--
-- Suppresses Roblox's own default floating nameplate
-- (Humanoid.NameDisplayDistance = 0) so there's only ever one username
-- tag per player, not two stacked on top of each other.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NAME_COLOR = Color3.fromRGB(255, 255, 255)
local NO_TITLE_COLOR = Color3.fromRGB(140, 140, 140)
local NO_TITLE_TEXT = "[None]"
local TEXT_STROKE_TRANSPARENCY = 0.4
local BILLBOARD_SIZE = UDim2.new(0, 220, 0, 50)
local BILLBOARD_OFFSET = Vector3.new(0, 2.6, 0)
local MAX_DISTANCE = 60
local RAINBOW_CYCLE_SECONDS = 3 -- one full hue cycle, per GameConfig.Titles' own "rainbow = true overrides color with an animated hue cycle client-side"

-- [TextLabel] = true for every currently-displayed rainbow title - a
-- single shared Heartbeat loop below drives all of them off one hue
-- clock, rather than a separate loop per player.
local rainbowLabels = {}

local function updateTitleLabel(player: Player, titleLabel: TextLabel)
	rainbowLabels[titleLabel] = nil

	local titleText = player:GetAttribute("Title")
	if not titleText or titleText == "" then
		titleLabel.Text = NO_TITLE_TEXT
		titleLabel.TextColor3 = NO_TITLE_COLOR
		return
	end

	titleLabel.Text = titleText

	if player:GetAttribute("TitleRainbow") == true then
		rainbowLabels[titleLabel] = true
	else
		titleLabel.TextColor3 = player:GetAttribute("TitleColor") or Color3.fromRGB(255, 255, 255)
	end
end

local function buildDisplay(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end

	humanoid.NameDisplayDistance = 0

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TitleDisplay"
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = BILLBOARD_OFFSET
	billboard.MaxDistance = MAX_DISTANCE
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = NAME_COLOR
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Text = player.DisplayName
	nameLabel.Parent = billboard

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Position = UDim2.new(0, 0, 0.5, 0)
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleLabel.Text = NO_TITLE_TEXT
	titleLabel.TextColor3 = NO_TITLE_COLOR
	titleLabel.Parent = billboard

	updateTitleLabel(player, titleLabel)

	local function refresh()
		updateTitleLabel(player, titleLabel)
	end
	player:GetAttributeChangedSignal("Title"):Connect(refresh)
	player:GetAttributeChangedSignal("TitleColor"):Connect(refresh)
	player:GetAttributeChangedSignal("TitleRainbow"):Connect(refresh)

	character.Destroying:Connect(function()
		rainbowLabels[titleLabel] = nil
	end)
end

local function onPlayerAdded(player: Player)
	if player.Character then
		buildDisplay(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		buildDisplay(player, character)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

RunService.Heartbeat:Connect(function()
	if next(rainbowLabels) == nil then
		return
	end

	local hue = (tick() % RAINBOW_CYCLE_SECONDS) / RAINBOW_CYCLE_SECONDS
	local color = Color3.fromHSV(hue, 1, 1)
	for label in rainbowLabels do
		if label.Parent then
			label.TextColor3 = color
		else
			rainbowLabels[label] = nil
		end
	end
end)
