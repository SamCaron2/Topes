-- Builds SecondIslandGate's "LOCKED" sign and its Unlock button. Unlike the
-- other boards, this one has to be interactive and needs to disappear once
-- THIS player unlocks it (while staying solid-looking for anyone who
-- hasn't), so it's built client-side instead of as a static server sign.
-- Pressing Unlock while you meet the requirement actually SPENDS the
-- Mana/Rebirths (SecondIslandHandler.unlock) - meeting the requirement
-- alone doesn't open it anymore, only the button does. Level is checked
-- but never spent.
--
-- Also reveals the ArcaneDustPad's floating label text LOCALLY the moment
-- this player is actually unlocked - per direct request ("keep the cards
-- so people see there is stuff on the island but the text on them does
-- not appear until you unlock"). The pad and both upgrade boards
-- themselves are always visible/solid (built that way in WorldBuilder);
-- only their text/UI waits on unlock - the boards' own SurfaceGuis are
-- withheld client-side in ArcaneDustUpgradeBoardClient/WizardTierBoardClient.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getSecondIslandStateFunction = remotes:WaitForChild("GetSecondIslandState")
local unlockSecondIslandFunction = remotes:WaitForChild("UnlockSecondIsland")
local getRebirthStateFunction = remotes:WaitForChild("GetRebirthState")
local getXPStateFunction = remotes:WaitForChild("GetXPState")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")
local rebirthsUpdatedEvent = remotes:WaitForChild("RebirthsUpdated")
local xpUpdatedEvent = remotes:WaitForChild("XPUpdated")

local gate = Workspace:WaitForChild("SecondIslandGate")
local arcaneDustPad = Workspace:WaitForChild("ArcaneDustPad")

local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_CAN_UNLOCK = Color3.fromRGB(70, 190, 60)
local COLOR_CANT_UNLOCK = Color3.fromRGB(200, 55, 55)

local function revealSecondIslandContent()
	local padLabel = arcaneDustPad:FindFirstChild("ArcaneDustPadLabel")
	if padLabel then
		padLabel.Enabled = true
	end
end

-- PlayerData might not be loaded the instant this script starts - retry a
-- few times rather than building the sign with nil/placeholder numbers.
local secondIslandState
for _ = 1, 10 do
	secondIslandState = getSecondIslandStateFunction:InvokeServer()
	if secondIslandState then
		break
	end
	task.wait(0.5)
end
secondIslandState = secondIslandState
	or { unlocked = false, meetsRequirement = false, manaRequirement = 40000000, rebirthsRequirement = 40000, levelRequirement = 25 }

-- Already unlocked (from a previous visit) - hide the gate for this player
-- only; it stays solid-looking for anyone who hasn't unlocked it yet,
-- since this is a local-only visual change, not a shared world edit.
if secondIslandState.unlocked then
	gate.Transparency = 1
	revealSecondIslandContent()
else
	-- Faces back toward the starting island, i.e. the -Z direction players
	-- approach from - a guess like the kiosk boards' SurfaceGui faces were;
	-- flip to Enum.NormalId.Back if it renders unreadable from the approach side.
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "SecondIslandGateGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Adornee = gate
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 36
	surfaceGui.Parent = gate

	local background = Instance.new("Frame")
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
	background.BackgroundTransparency = 0.35
	background.BorderSizePixel = 0
	background.Parent = surfaceGui

	local titleBanner = Instance.new("Frame")
	titleBanner.Size = UDim2.new(0.94, 0, 0.18, 0)
	titleBanner.Position = UDim2.new(0.03, 0, 0.04, 0)
	titleBanner.BackgroundColor3 = Color3.fromRGB(90, 15, 15)
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
	titleText.TextColor3 = Color3.fromRGB(255, 220, 90)
	titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	titleText.Text = "🔒 LOCKED"
	titleText.Parent = titleBanner

	local requirementLines = {
		("%s Mana"):format(NumberFormat.format(secondIslandState.manaRequirement)),
		("%s Rebirths"):format(NumberFormat.format(secondIslandState.rebirthsRequirement)),
		("Level %d"):format(secondIslandState.levelRequirement),
	}

	for i, line in requirementLines do
		local lineLabel = Instance.new("TextLabel")
		lineLabel.Size = UDim2.new(0.9, 0, 0.11, 0)
		lineLabel.Position = UDim2.new(0.05, 0, 0.25 + (i - 1) * 0.14, 0)
		lineLabel.BackgroundTransparency = 1
		lineLabel.Font = Enum.Font.GothamBold
		lineLabel.TextScaled = true
		lineLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		lineLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
		lineLabel.Text = line
		lineLabel.Parent = background
	end

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

	-- Tracked locally off the same live events the HUD uses, so the button
	-- enables/disables in real time without re-invoking the server on every
	-- Mana pickup. Seeded from the actual current values (not 0s) so the
	-- first recompute after this script starts doesn't wrongly disable the
	-- button using a stale default for whichever stat hasn't fired yet.
	local rebirthState = getRebirthStateFunction:InvokeServer()
	local xpState = getXPStateFunction:InvokeServer()
	local currentMana = (rebirthState and rebirthState.mana) or 0
	local currentRebirths = (rebirthState and rebirthState.rebirths) or 0
	local currentLevel = (xpState and xpState.level) or 1

	local canAfford = secondIslandState.meetsRequirement

	local function updateButton()
		unlockButton.Active = canAfford
		unlockButton.BackgroundColor3 = canAfford and COLOR_CAN_UNLOCK or COLOR_CANT_UNLOCK
	end
	updateButton()

	local function recomputeCanAfford()
		canAfford = currentMana >= secondIslandState.manaRequirement
			and currentRebirths >= secondIslandState.rebirthsRequirement
			and currentLevel >= secondIslandState.levelRequirement
		updateButton()
	end

	manaUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentMana = amount
		recomputeCanAfford()
	end)

	rebirthsUpdatedEvent.OnClientEvent:Connect(function(amount)
		currentRebirths = amount
		recomputeCanAfford()
	end)

	xpUpdatedEvent.OnClientEvent:Connect(function(state)
		if state then
			currentLevel = state.level
			recomputeCanAfford()
		end
	end)

	unlockButton.MouseButton1Click:Connect(function()
		if not canAfford then
			return
		end
		local success = unlockSecondIslandFunction:InvokeServer()
		if success then
			gate.Transparency = 1
			surfaceGui.Enabled = false
			revealSecondIslandContent()
		end
	end)
end
