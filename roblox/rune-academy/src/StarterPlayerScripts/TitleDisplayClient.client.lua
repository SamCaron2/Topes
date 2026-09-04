-- Draws every player's equipped title above their head. Reads it straight
-- off Player attributes (Title/TitleColor/TitleRainbow), which TitleHandler
-- sets server-side and which replicate to all clients automatically - no
-- remote needed here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RAINBOW_CYCLE_SECONDS = 6

local function attachTitleGui(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TitleGui"
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = billboard

	local rainbowConnection: RBXScriptConnection? = nil

	local function setRainbow(enabled: boolean)
		if rainbowConnection then
			rainbowConnection:Disconnect()
			rainbowConnection = nil
		end
		if enabled then
			rainbowConnection = RunService.Heartbeat:Connect(function()
				local hue = (os.clock() / RAINBOW_CYCLE_SECONDS) % 1
				label.TextColor3 = Color3.fromHSV(hue, 1, 1)
			end)
		end
	end

	local function refresh()
		local title = player:GetAttribute("Title")
		billboard.Enabled = title ~= nil and title ~= ""
		if not billboard.Enabled then
			setRainbow(false)
			return
		end

		label.Text = title

		local rainbow = player:GetAttribute("TitleRainbow") == true
		setRainbow(rainbow)
		if not rainbow then
			local color = player:GetAttribute("TitleColor")
			label.TextColor3 = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
		end
	end

	refresh()
	player:GetAttributeChangedSignal("Title"):Connect(refresh)
	player:GetAttributeChangedSignal("TitleColor"):Connect(refresh)
	player:GetAttributeChangedSignal("TitleRainbow"):Connect(refresh)

	head.Destroying:Connect(function()
		setRainbow(false)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		attachTitleGui(player, character)
	end)
	if player.Character then
		attachTitleGui(player, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
