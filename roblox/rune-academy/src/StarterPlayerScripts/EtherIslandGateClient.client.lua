-- Builds EtherIslandGate's "LOCKED" sign and its Unlock button - same
-- pattern as SecondIslandGateClient, just gated on Ether alone instead of
-- Mana/Rebirths/Level. Has to be interactive and disappear once THIS
-- player unlocks it (while staying solid-looking for anyone who hasn't),
-- so it's built client-side instead of as a static server sign. Pressing
-- Unlock while you meet the requirement actually SPENDS the Ether
-- (EtherIslandHandler.unlock) - meeting the requirement alone doesn't
-- open it, only the button does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getEtherIslandStateFunction = remotes:WaitForChild("GetEtherIslandState")
local unlockEtherIslandFunction = remotes:WaitForChild("UnlockEtherIsland")
local etherUpdatedEvent = remotes:WaitForChild("EtherUpdated")

local gate = Workspace:WaitForChild("EtherIslandGate")

local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_CAN_UNLOCK = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_UNLOCK = Color3.fromRGB(200, 55, 55)

-- PlayerData might not be loaded the instant this script starts - retry a
-- few times rather than building the sign with nil/placeholder numbers.
local etherIslandState
for _ = 1, 10 do
	etherIslandState = getEtherIslandStateFunction:InvokeServer()
	if etherIslandState then
		break
	end
	task.wait(0.5)
end
etherIslandState = etherIslandState or { unlocked = false, meetsRequirement = false, etherRequirement = 1e9 }

-- Already unlocked (from a previous visit) - hide the gate for this player
-- only; it stays solid-looking for anyone who hasn't unlocked it yet,
-- since this is a local-only visual change, not a shared world edit.
if etherIslandState.unlocked then
	gate.Transparency = 1
else
	-- Faces back toward SecondIsland, i.e. the -X direction players
	-- approach from - a guess like every other gate/board face here; flip
	-- to Right if it renders unreadable from the approach side.
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "EtherIslandGateGui"
	surfaceGui.Face = Enum.NormalId.Left
	surfaceGui.Adornee = gate
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = gate

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(30, 10, 45)
	background.BackgroundTransparency = 0.35
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.94, 0, 0.18, 0)
	titleBanner.Position = UDim2.new(0.03, 0, 0.04, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
	titleBanner.BackgroundTransparency = 0.15
	titleBanner.BorderSizePixel = 0
	titleBanner.Parent = background

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0.25, 0)
	titleCorner.Parent = titleBanner

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(1, 0, 1, 0)
	titleText.BackgroundTransparency = 1
	titleText.Font = Enum.Font.GothamBold
	titleText.TextScaled = true
	titleText.TextColor3 = Color3.fromRGB(150, 60, 220)
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = "🔒 LOCKED"
	titleText.Parent = titleBanner

	local requirementLabel = Instance.new("TextLabel")
	requirementLabel.Size = UDim2.new(0.9, 0, 0.14, 0)
	requirementLabel.Position = UDim2.new(0.05, 0, 0.3, 0)
	requirementLabel.BackgroundTransparency = 1
	requirementLabel.Font = Enum.Font.GothamBold
	requirementLabel.TextScaled = true
	requirementLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	requirementLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	requirementLabel.Text = ("%s Ether"):format(NumberFormat.format(etherIslandState.etherRequirement))
	requirementLabel.Parent = background

	local unlockButton = Instance.new("TextButton")
	unlockButton.Size = UDim2.new(0.6, 0, 0.16, 0)
	unlockButton.Position = UDim2.new(0.2, 0, 0.78, 0)
	unlockButton.Font = Enum.Font.GothamBold
	unlockButton.TextScaled = true
	unlockButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	unlockButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	unlockButton.Text = "Unlock"
	unlockButton.Parent = background

	local unlockButtonCorner = Instance.new("UICorner")
	unlockButtonCorner.CornerRadius = UDim.new(0.3, 0)
	unlockButtonCorner.Parent = unlockButton

	-- Tracked locally off the same live Ether events the HUD uses, so the
	-- button enables/disables in real time without re-invoking the server
	-- on every click.
	local canAfford = etherIslandState.meetsRequirement

	local function updateButton()
		unlockButton.Active = canAfford
		unlockButton.BackgroundColor3 = canAfford and COLOR_CAN_UNLOCK or COLOR_CANT_UNLOCK
	end
	updateButton()

	etherUpdatedEvent.OnClientEvent:Connect(function(amount)
		canAfford = amount >= etherIslandState.etherRequirement
		updateButton()
	end)

	unlockButton.MouseButton1Click:Connect(function()
		if not canAfford then
			return
		end
		local success = unlockEtherIslandFunction:InvokeServer()
		if success then
			gate.Transparency = 1
			surfaceGui.Enabled = false
		end
	end)
end
