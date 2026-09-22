-- Floating feedback for the Rune Altar (RuinRuneCircle): each time
-- WorldBuilder's collection loop grants this player a Rune while they're
-- standing on it, the server fires RuneAltarCollected with one entry per
-- roll that tick (more than one once the Familiar tier is bought) - this
-- pops a small rising, fading "+<amount> <RankName>" label above their
-- head per entry, colored by rarity, so "sit there and it collects by
-- chance" is actually visible happening in real time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local runeAltarCollectedEvent = remotes:WaitForChild("RuneAltarCollected")

-- Not defined in GameConfig.RuneRanks itself (that table only carries
-- odds/statBoosts) - a plain ramp from common to rare, my own call, same
-- rising-vividness idea as every other tier-color ramp in this game.
local RANK_COLORS = {
	Apprentice = Color3.fromRGB(200, 200, 200),
	Novice = Color3.fromRGB(100, 220, 120),
	Adept = Color3.fromRGB(80, 180, 255),
	Skilled = Color3.fromRGB(190, 120, 255),
	Expert = Color3.fromRGB(255, 120, 200),
	Master = Color3.fromRGB(255, 150, 60),
	Archmage = Color3.fromRGB(255, 70, 70),
	Mythic = Color3.fromRGB(80, 255, 230),
	Ascendant = Color3.fromRGB(255, 215, 60),
}
local DEFAULT_RANK_COLOR = Color3.fromRGB(255, 255, 255)

local POPUP_RISE_STUDS = 3
local POPUP_DURATION_SECONDS = 1.2

local function showPopup(text: string, color: Color3, verticalOffset: number)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 3 + verticalOffset, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = rootPart
	billboard.Parent = rootPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = billboard

	local tweenInfo = TweenInfo.new(POPUP_DURATION_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, tweenInfo, { StudsOffset = billboard.StudsOffset + Vector3.new(0, POPUP_RISE_STUDS, 0) })
		:Play()
	TweenService:Create(label, tweenInfo, { TextTransparency = 1 }):Play()

	task.delay(POPUP_DURATION_SECONDS, function()
		billboard:Destroy()
	end)
end

runeAltarCollectedEvent.OnClientEvent:Connect(function(results)
	if type(results) ~= "table" then
		return
	end
	for i, result in results do
		local color = RANK_COLORS[result.name] or DEFAULT_RANK_COLOR
		local text = ("+%s %s"):format(NumberFormat.format(result.amount), result.name)
		-- Stacks extra simultaneous rolls (Familiar tier) a bit higher each,
		-- so they don't all overlap in the same spot.
		showPopup(text, color, (i - 1) * 1.4)
	end
end)
