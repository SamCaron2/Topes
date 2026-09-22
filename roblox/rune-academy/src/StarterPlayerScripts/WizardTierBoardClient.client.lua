-- Builds the Wizard Tiers board on SecondIsland, right next to the Arcane
-- Dust Upgrades board: a title banner, the current/next tier's name, a
-- description of what buying in costs and grants, and a big Enter button -
-- styled after the reference "Summer Tiers" board (title -> tier name ->
-- description box -> big buy button), just without its prev/next arrows
-- since only Tier 1 exists so far. Buying a tier is a big, hard-to-undo
-- reset, so the button needs a second click to confirm before it actually
-- fires (see CONFIRM_WINDOW_SECONDS below), unlike every other buy button
-- on this island.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getWizardTierStateFunction = remotes:WaitForChild("GetWizardTierState")
local buyWizardTierFunction = remotes:WaitForChild("BuyWizardTier")
local manaUpdatedEvent = remotes:WaitForChild("ManaUpdated")

local board = Workspace:WaitForChild("Kiosks"):WaitForChild("WizardTierBoard")

local GOLD = Color3.fromRGB(255, 220, 90)
local COLOR_CAN_ENTER = Color3.fromRGB(200, 40, 40)
local COLOR_CANT_AFFORD = Color3.fromRGB(90, 90, 90)
local COLOR_CONFIRM = Color3.fromRGB(230, 140, 30)
local TEXT_STROKE_TRANSPARENCY = 0.4
local CONFIRM_WINDOW_SECONDS = 4

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "WizardTierBoardGui"
surfaceGui.Face = Enum.NormalId.Right
surfaceGui.Adornee = board
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 36
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(30, 20, 55)
background.BackgroundTransparency = 0.45
background.BorderSizePixel = 0
background.Parent = surfaceGui

local titleBanner = Instance.new("Frame")
titleBanner.Size = UDim2.new(0.9, 0, 0.13, 0)
titleBanner.Position = UDim2.new(0.05, 0, 0.04, 0)
titleBanner.BackgroundColor3 = Color3.fromRGB(60, 20, 90)
titleBanner.BackgroundTransparency = 0.1
titleBanner.BorderSizePixel = 0
titleBanner.Parent = background

local titleBannerCorner = Instance.new("UICorner")
titleBannerCorner.CornerRadius = UDim.new(0.25, 0)
titleBannerCorner.Parent = titleBanner

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.GothamBold
titleText.TextScaled = true
titleText.TextColor3 = GOLD
titleText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleText.Text = "Wizard Tiers"
titleText.Parent = titleBanner

local tierNameLabel = Instance.new("TextLabel")
tierNameLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
tierNameLabel.Position = UDim2.new(0.05, 0, 0.19, 0)
tierNameLabel.BackgroundTransparency = 1
tierNameLabel.Font = Enum.Font.GothamBold
tierNameLabel.TextScaled = true
tierNameLabel.TextColor3 = Color3.fromRGB(220, 180, 255)
tierNameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
tierNameLabel.Text = "-"
tierNameLabel.Parent = background

local descriptionBox = Instance.new("Frame")
descriptionBox.Size = UDim2.new(0.9, 0, 0.42, 0)
descriptionBox.Position = UDim2.new(0.05, 0, 0.29, 0)
descriptionBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
descriptionBox.BackgroundTransparency = 0.85
descriptionBox.BorderSizePixel = 0
descriptionBox.Parent = background

local descriptionBoxCorner = Instance.new("UICorner")
descriptionBoxCorner.CornerRadius = UDim.new(0.06, 0)
descriptionBoxCorner.Parent = descriptionBox

local descriptionText = Instance.new("TextLabel")
descriptionText.Size = UDim2.new(0.92, 0, 0.9, 0)
descriptionText.Position = UDim2.new(0.04, 0, 0.05, 0)
descriptionText.BackgroundTransparency = 1
descriptionText.Font = Enum.Font.Gotham
descriptionText.TextScaled = true
descriptionText.TextWrapped = true
descriptionText.TextColor3 = Color3.fromRGB(255, 255, 255)
descriptionText.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
descriptionText.Text = "-"
descriptionText.Parent = descriptionBox

local enterButton = Instance.new("TextButton")
enterButton.Size = UDim2.new(0.7, 0, 0.14, 0)
enterButton.Position = UDim2.new(0.15, 0, 0.8, 0)
enterButton.BackgroundColor3 = COLOR_CANT_AFFORD
enterButton.Font = Enum.Font.GothamBold
enterButton.TextScaled = true
enterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
enterButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
enterButton.Text = "-"
enterButton.Parent = background

local enterButtonCorner = Instance.new("UICorner")
enterButtonCorner.CornerRadius = UDim.new(0.25, 0)
enterButtonCorner.Parent = enterButton

local enterButtonPadding = Instance.new("UIPadding")
enterButtonPadding.PaddingTop = UDim.new(0.15, 0)
enterButtonPadding.PaddingBottom = UDim.new(0.15, 0)
enterButtonPadding.PaddingLeft = UDim.new(0.1, 0)
enterButtonPadding.PaddingRight = UDim.new(0.1, 0)
enterButtonPadding.Parent = enterButton

local currentMana = 0
local pendingNextTier = nil -- the {name, cost, ...} table for the tier a click would buy, nil once no further tiers exist
local awaitingConfirm = false
local confirmResetThread = nil

local function formatBonuses(tierInfo)
	local text = ("x%d Mana, x%d Rebirths, x%d Arcane Dust"):format(
		tierInfo.manaMultiplier,
		tierInfo.rebirthMultiplier,
		tierInfo.dustMultiplier
	)
	if tierInfo.autoMana then
		text ..= " + Auto Mana (collects Mana passively, no pickups needed)"
	end
	if tierInfo.unlockName then
		text ..= (" + unlocks the %s"):format(tierInfo.unlockName)
	end
	return text
end

local function resetConfirm()
	awaitingConfirm = false
	if confirmResetThread then
		task.cancel(confirmResetThread)
		confirmResetThread = nil
	end
end

local function updateButton()
	if not pendingNextTier then
		enterButton.Active = false
		enterButton.BackgroundColor3 = COLOR_CANT_AFFORD
		return
	end

	if awaitingConfirm then
		enterButton.Active = true
		enterButton.BackgroundColor3 = COLOR_CONFIRM
		enterButton.Text = "Click again to confirm!"
		return
	end

	local canAfford = currentMana >= pendingNextTier.cost
	enterButton.Active = canAfford
	enterButton.BackgroundColor3 = canAfford and COLOR_CAN_ENTER or COLOR_CANT_AFFORD
	enterButton.Text = ("Enter %s - %s Mana"):format(pendingNextTier.name, NumberFormat.format(pendingNextTier.cost))
end

local function render(state)
	if not state then
		return
	end

	currentMana = state.mana
	pendingNextTier = state.nextTier
	resetConfirm()

	if state.currentTier then
		tierNameLabel.Text = ("Current: %s (%s)"):format(state.currentTier.name, formatBonuses(state.currentTier))
	else
		tierNameLabel.Text = "No Tier Entered Yet"
	end

	if state.nextTier then
		descriptionText.Text = ("Spend %s Mana to enter %s.\n\nYour Mana, Rebirths, Level, and every upgrade on this island reset - but the SecondIsland unlock stays open, and you permanently gain %s from your very next pickup onward."):format(
			NumberFormat.format(state.nextTier.cost),
			state.nextTier.name,
			formatBonuses(state.nextTier)
		)
	else
		descriptionText.Text = "No further tiers yet - check back later for the next one."
	end

	updateButton()
end

render(getWizardTierStateFunction:InvokeServer())

manaUpdatedEvent.OnClientEvent:Connect(function(amount)
	currentMana = amount
	updateButton()
end)

enterButton.MouseButton1Click:Connect(function()
	if not pendingNextTier then
		return
	end

	if not awaitingConfirm then
		awaitingConfirm = true
		updateButton()
		confirmResetThread = task.delay(CONFIRM_WINDOW_SECONDS, function()
			confirmResetThread = nil
			awaitingConfirm = false
			updateButton()
		end)
		return
	end

	resetConfirm()
	local success, _, newState = buyWizardTierFunction:InvokeServer()
	if success then
		render(newState)
	else
		updateButton()
	end
end)
