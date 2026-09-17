-- First real UI: upgrade cards + a chain-reset button for Academy Mana.
-- Deliberately hardcoded to one currency for now rather than a fully
-- generic panel - once this shape is proven out in-game, it's worth
-- generalizing into something that can render any zone/currency the same
-- way, but that's more machinery than a first pass needs.
--
-- The live Mana amount comes from the leaderstat (already synced every
-- 0.5s by PlayerData) rather than a remote poll - upgrade levels/costs
-- come from GetCurrencyState since those aren't in leaderstats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local ZONE_KEY = "Academy"
local CURRENCY_KEY = "Mana"
local REFRESH_INTERVAL = 1

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyUpgradeFunction = remotes:WaitForChild("BuyUpgrade")
local chainResetFunction = remotes:WaitForChild("ChainReset")
local getCurrencyStateFunction = remotes:WaitForChild("GetCurrencyState")

local function findZone(zoneKey: string)
	for _, zone in GameConfig.Zones do
		if zone.key == zoneKey then
			return zone
		end
	end
	return nil
end

local function findCurrency(zone, currencyKey: string)
	for _, currency in zone.currencies do
		if currency.key == currencyKey then
			return currency
		end
	end
	return nil
end

local zone = findZone(ZONE_KEY)
local currency = findCurrency(zone, CURRENCY_KEY)

-- ============================================================================
-- Build the UI
-- ============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ManaPanel"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.AnchorPoint = Vector2.new(0, 1)
mainFrame.Position = UDim2.new(0, 16, 1, -16)
mainFrame.Size = UDim2.new(0, 300, 0, 340)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
mainFrame.BackgroundTransparency = 0.1
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
layout.Parent = mainFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.LayoutOrder = 1
titleLabel.Size = UDim2.new(1, 0, 0, 24)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = currency.displayName
titleLabel.Parent = mainFrame

local amountLabel = Instance.new("TextLabel")
amountLabel.LayoutOrder = 2
amountLabel.Size = UDim2.new(1, 0, 0, 28)
amountLabel.BackgroundTransparency = 1
amountLabel.Font = Enum.Font.GothamBold
amountLabel.TextSize = 22
amountLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
amountLabel.TextXAlignment = Enum.TextXAlignment.Left
amountLabel.Text = "0"
amountLabel.Parent = mainFrame

-- One "card" per upgrade slot: name/level on top, cost + Buy/Max on bottom.
local slotRows = {} -- [slotId] = { costLabel, levelLabel }

for index, slot in currency.upgrades do
	local card = Instance.new("Frame")
	card.LayoutOrder = 2 + index
	card.Size = UDim2.new(1, 0, 0, 54)
	card.BackgroundColor3 = Color3.fromRGB(40, 34, 60)
	card.Parent = mainFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 8, 0, 4)
	nameLabel.Size = UDim2.new(0.6, 0, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = slot.displayName
	nameLabel.Parent = card

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Position = UDim2.new(0.6, 0, 0, 4)
	levelLabel.Size = UDim2.new(0.4, -8, 0, 18)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.TextSize = 13
	levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Text = "0/" .. slot.maxLevel
	levelLabel.Parent = card

	local costLabel = Instance.new("TextLabel")
	costLabel.Position = UDim2.new(0, 8, 0, 26)
	costLabel.Size = UDim2.new(0.5, -8, 0, 18)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.Gotham
	costLabel.TextSize = 13
	costLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Text = "Cost: ..."
	costLabel.Parent = card

	local buyButton = Instance.new("TextButton")
	buyButton.Position = UDim2.new(0.55, 0, 0, 24)
	buyButton.Size = UDim2.new(0.2, -4, 0, 22)
	buyButton.BackgroundColor3 = Color3.fromRGB(80, 170, 90)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 13
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.Text = "Buy"
	buyButton.Parent = card
	Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 6)

	local maxButton = Instance.new("TextButton")
	maxButton.Position = UDim2.new(0.77, 0, 0, 24)
	maxButton.Size = UDim2.new(0.23, 0, 0, 22)
	maxButton.BackgroundColor3 = Color3.fromRGB(190, 170, 60)
	maxButton.Font = Enum.Font.GothamBold
	maxButton.TextSize = 13
	maxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	maxButton.Text = "Max"
	maxButton.Parent = card
	Instance.new("UICorner", maxButton).CornerRadius = UDim.new(0, 6)

	buyButton.MouseButton1Click:Connect(function()
		buyUpgradeFunction:InvokeServer(ZONE_KEY, CURRENCY_KEY, slot.id, "one")
	end)
	maxButton.MouseButton1Click:Connect(function()
		buyUpgradeFunction:InvokeServer(ZONE_KEY, CURRENCY_KEY, slot.id, "max")
	end)

	slotRows[slot.id] = { costLabel = costLabel, levelLabel = levelLabel }
end

-- Chain reset card: "Cash in for Essence".
local resetCard = Instance.new("Frame")
resetCard.LayoutOrder = 10
resetCard.Size = UDim2.new(1, 0, 0, 54)
resetCard.BackgroundColor3 = Color3.fromRGB(60, 40, 70)
resetCard.Parent = mainFrame
Instance.new("UICorner", resetCard).CornerRadius = UDim.new(0, 8)

local resetLabel = Instance.new("TextLabel")
resetLabel.Position = UDim2.new(0, 8, 0, 4)
resetLabel.Size = UDim2.new(1, -16, 0, 18)
resetLabel.BackgroundTransparency = 1
resetLabel.Font = Enum.Font.GothamBold
resetLabel.TextSize = 13
resetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
resetLabel.TextXAlignment = Enum.TextXAlignment.Left
resetLabel.Text = ("Requires %s Mana"):format(NumberFormat.format(currency.chainReset.requirement))
resetLabel.Parent = resetCard

local resetButton = Instance.new("TextButton")
resetButton.Position = UDim2.new(0, 8, 0, 24)
resetButton.Size = UDim2.new(1, -16, 0, 22)
resetButton.BackgroundColor3 = Color3.fromRGB(150, 90, 200)
resetButton.Font = Enum.Font.GothamBold
resetButton.TextSize = 13
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Text = ("Cash in for %s"):format(currency.chainReset.into)
resetButton.Parent = resetCard
Instance.new("UICorner", resetButton).CornerRadius = UDim.new(0, 6)

resetButton.MouseButton1Click:Connect(function()
	local success, err = chainResetFunction:InvokeServer(ZONE_KEY, CURRENCY_KEY)
	if not success then
		warn("Chain reset failed: " .. tostring(err))
	end
end)

-- ============================================================================
-- Live refresh
-- ============================================================================

local function upgradeCost(slot, level: number): number
	return slot.baseCost * (slot.costGrowth ^ level)
end

local function refresh()
	local state = getCurrencyStateFunction:InvokeServer(ZONE_KEY, CURRENCY_KEY)
	if not state then
		return
	end

	for _, slot in currency.upgrades do
		local level = state.upgradeLevels[slot.id] or 0
		local row = slotRows[slot.id]
		row.levelLabel.Text = level .. "/" .. slot.maxLevel
		if level >= slot.maxLevel then
			row.costLabel.Text = "MAXED"
		else
			row.costLabel.Text = "Cost: " .. NumberFormat.format(upgradeCost(slot, level))
		end
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(REFRESH_INTERVAL)
	end
end)

local leaderstats = player:WaitForChild("leaderstats")
local manaStat = leaderstats:WaitForChild(CURRENCY_KEY)

local function updateAmountLabel()
	amountLabel.Text = NumberFormat.format(manaStat.Value)
end

manaStat.Changed:Connect(updateAmountLabel)
updateAmountLabel()
