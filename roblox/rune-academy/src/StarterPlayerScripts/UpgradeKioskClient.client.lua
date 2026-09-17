-- Builds a BillboardGui "board" on every UpgradeKiosk part WorldBuilder
-- creates (one per currency). This is the 3D-world equivalent of the old
-- screen-corner Mana panel - upgrade cards, self-prestige, chain-reset,
-- and Convert (sellInto), generalized to work for any currency instead of
-- hardcoded to one.
--
-- BillboardGui.Size's Scale component is measured in studs (not
-- screen-relative like a ScreenGui), so this genuinely appears as a
-- physical sign that shrinks with distance, matching the reference game's
-- boards rather than a flat screen overlay.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local NumberFormat = require(ReplicatedStorage.Modules.NumberFormat)

local REFRESH_INTERVAL = 1
local MAX_VIEW_DISTANCE = 60

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local buyUpgradeFunction = remotes:WaitForChild("BuyUpgrade")
local chainResetFunction = remotes:WaitForChild("ChainReset")
local sellCurrencyFunction = remotes:WaitForChild("SellCurrency")
local selfPrestigeFunction = remotes:WaitForChild("SelfPrestige")
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

local function findUpgradeSlot(currency, slotId: string)
	for _, slot in currency.upgrades do
		if slot.id == slotId then
			return slot
		end
	end
	return nil
end

local function upgradeCost(slot, level: number): number
	return slot.baseCost * (slot.costGrowth ^ level)
end

-- What a slot's card should say about its EFFECT (separate from cost/level,
-- which every kind shows the same way) - differs by kind since a
-- "tickInterval" slot's number is a duration, a "sellRate" slot's number
-- feeds a conversion rate elsewhere, and "yield" (the default) multiplies
-- this currency's own production, same as before.
local function describeEffect(currency, slot, level: number): string
	if slot.kind == "tickInterval" then
		local interval = slot.tickIntervalBase - (level * slot.tickIntervalStep)
		return ("%.1fs / collect"):format(interval)
	elseif slot.kind == "sellRate" then
		local rate = currency.sellInto.baseRate * (slot.multiplierPerLevel ^ level)
		return ("x%s %s"):format(NumberFormat.format(rate), currency.sellInto.into)
	else
		return ("x%s %s"):format(NumberFormat.format(slot.multiplierPerLevel ^ level), currency.displayName)
	end
end

local function buildKioskGui(part: BasePart, zoneKey: string, currencyKey: string)
	local zone = findZone(zoneKey)
	local currency = zone and findCurrency(zone, currencyKey)
	if not currency then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UpgradeBoard"
	billboard.Size = UDim2.new(6, 0, 8, 0) -- Scale = studs for BillboardGui, not screen-relative
	billboard.MaxDistance = MAX_VIEW_DISTANCE
	billboard.Parent = part

	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.Parent = billboard
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
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = currency.displayName .. " Upgrades"
	titleLabel.Parent = mainFrame

	local amountLabel = Instance.new("TextLabel")
	amountLabel.LayoutOrder = 2
	amountLabel.Size = UDim2.new(1, 0, 0, 22)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = Enum.Font.GothamBold
	amountLabel.TextSize = 18
	amountLabel.TextColor3 = Color3.fromRGB(180, 140, 255)
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.Text = "0"
	amountLabel.Parent = mainFrame

	local slotRows = {}

	for index, slot in currency.upgrades do
		local costCurrencyKey = slot.costCurrency or currencyKey
		local costCurrency = findCurrency(zone, costCurrencyKey)
		local costCurrencyName = costCurrency and costCurrency.displayName or costCurrencyKey

		local card = Instance.new("Frame")
		card.LayoutOrder = 2 + index
		card.Size = UDim2.new(1, 0, 0, 50)
		card.BackgroundColor3 = Color3.fromRGB(40, 34, 60)
		card.Parent = mainFrame
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 8, 0, 4)
		nameLabel.Size = UDim2.new(0.6, 0, 0, 16)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = slot.displayName
		nameLabel.Parent = card

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Position = UDim2.new(0.6, 0, 0, 4)
		levelLabel.Size = UDim2.new(0.4, -8, 0, 16)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.Gotham
		levelLabel.TextSize = 12
		levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Right
		levelLabel.Text = "0/" .. slot.maxLevel
		levelLabel.Parent = card

		local effectLabel = Instance.new("TextLabel")
		effectLabel.Position = UDim2.new(0, 8, 0, 22)
		effectLabel.Size = UDim2.new(1, -16, 0, 14)
		effectLabel.BackgroundTransparency = 1
		effectLabel.Font = Enum.Font.Gotham
		effectLabel.TextSize = 11
		effectLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
		effectLabel.TextXAlignment = Enum.TextXAlignment.Left
		effectLabel.Text = describeEffect(currency, slot, 0)
		effectLabel.Parent = card

		local costLabel = Instance.new("TextLabel")
		costLabel.Position = UDim2.new(0, 8, 0, 34)
		costLabel.Size = UDim2.new(0.5, -8, 0, 14)
		costLabel.BackgroundTransparency = 1
		costLabel.Font = Enum.Font.Gotham
		costLabel.TextSize = 11
		costLabel.TextColor3 = Color3.fromRGB(180, 220, 180)
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.Text = ("Cost: %s %s"):format(NumberFormat.format(upgradeCost(slot, 0)), costCurrencyName)
		costLabel.Parent = card

		local buyButton = Instance.new("TextButton")
		buyButton.Position = UDim2.new(0.55, 0, 0, 32)
		buyButton.Size = UDim2.new(0.2, -4, 0, 16)
		buyButton.BackgroundColor3 = Color3.fromRGB(80, 170, 90)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 11
		buyButton.TextColor3 = Color3.new(1, 1, 1)
		buyButton.Text = "Buy"
		buyButton.Parent = card
		Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 6)

		local maxButton = Instance.new("TextButton")
		maxButton.Position = UDim2.new(0.77, 0, 0, 32)
		maxButton.Size = UDim2.new(0.23, 0, 0, 16)
		maxButton.BackgroundColor3 = Color3.fromRGB(190, 170, 60)
		maxButton.Font = Enum.Font.GothamBold
		maxButton.TextSize = 11
		maxButton.TextColor3 = Color3.new(1, 1, 1)
		maxButton.Text = "Max"
		maxButton.Parent = card
		Instance.new("UICorner", maxButton).CornerRadius = UDim.new(0, 6)

		buyButton.MouseButton1Click:Connect(function()
			buyUpgradeFunction:InvokeServer(zoneKey, currencyKey, slot.id, "one")
		end)
		maxButton.MouseButton1Click:Connect(function()
			buyUpgradeFunction:InvokeServer(zoneKey, currencyKey, slot.id, "max")
		end)

		slotRows[slot.id] = { costLabel = costLabel, levelLabel = levelLabel, effectLabel = effectLabel, costCurrencyName = costCurrencyName }
	end

	local prestigeButton
	if currency.selfPrestigeTiers then
		prestigeButton = Instance.new("TextButton")
		prestigeButton.LayoutOrder = 10
		prestigeButton.Size = UDim2.new(1, 0, 0, 30)
		prestigeButton.BackgroundColor3 = Color3.fromRGB(140, 70, 190)
		prestigeButton.Font = Enum.Font.GothamBold
		prestigeButton.TextSize = 13
		prestigeButton.TextColor3 = Color3.new(1, 1, 1)
		prestigeButton.Text = "Prestige"
		prestigeButton.Parent = mainFrame
		Instance.new("UICorner", prestigeButton).CornerRadius = UDim.new(0, 6)

		prestigeButton.MouseButton1Click:Connect(function()
			selfPrestigeFunction:InvokeServer(zoneKey, currencyKey)
		end)
	end

	local resetButton
	if currency.chainReset then
		resetButton = Instance.new("TextButton")
		resetButton.LayoutOrder = 11
		resetButton.Size = UDim2.new(1, 0, 0, 30)
		resetButton.BackgroundColor3 = Color3.fromRGB(150, 90, 200)
		resetButton.Font = Enum.Font.GothamBold
		resetButton.TextSize = 13
		resetButton.TextColor3 = Color3.new(1, 1, 1)
		resetButton.Text = ("Cash in for %s"):format(currency.chainReset.into)
		resetButton.Parent = mainFrame
		Instance.new("UICorner", resetButton).CornerRadius = UDim.new(0, 6)

		resetButton.MouseButton1Click:Connect(function()
			chainResetFunction:InvokeServer(zoneKey, currencyKey)
		end)
	end

	-- "Convert" section: sell ANY amount of this currency into sellInto.into
	-- at any time (no threshold) - a different button from chain-reset above
	-- since it's a genuinely different mechanic (see ResourceEngine.sellCurrency).
	local convertRateLabel, convertButton
	if currency.sellInto then
		convertRateLabel = Instance.new("TextLabel")
		convertRateLabel.LayoutOrder = 12
		convertRateLabel.Size = UDim2.new(1, 0, 0, 16)
		convertRateLabel.BackgroundTransparency = 1
		convertRateLabel.Font = Enum.Font.Gotham
		convertRateLabel.TextSize = 12
		convertRateLabel.TextColor3 = Color3.fromRGB(220, 220, 150)
		convertRateLabel.Text = ("1 %s = %s %s"):format(
			currency.displayName,
			NumberFormat.format(currency.sellInto.baseRate),
			currency.sellInto.into
		)
		convertRateLabel.Parent = mainFrame

		convertButton = Instance.new("TextButton")
		convertButton.LayoutOrder = 13
		convertButton.Size = UDim2.new(1, 0, 0, 30)
		convertButton.BackgroundColor3 = Color3.fromRGB(190, 160, 60)
		convertButton.Font = Enum.Font.GothamBold
		convertButton.TextSize = 14
		convertButton.TextColor3 = Color3.new(1, 1, 1)
		convertButton.Text = ("Convert %s"):format(currency.displayName)
		convertButton.Parent = mainFrame
		Instance.new("UICorner", convertButton).CornerRadius = UDim.new(0, 6)

		convertButton.MouseButton1Click:Connect(function()
			sellCurrencyFunction:InvokeServer(zoneKey, currencyKey)
		end)
	end

	local function refresh()
		local state = getCurrencyStateFunction:InvokeServer(zoneKey, currencyKey)
		if not state then
			return
		end

		for _, slot in currency.upgrades do
			local level = state.upgradeLevels[slot.id] or 0
			local row = slotRows[slot.id]
			row.levelLabel.Text = level .. "/" .. slot.maxLevel
			if level >= slot.maxLevel then
				row.costLabel.Text = "MAXED"
				row.effectLabel.Text = describeEffect(currency, slot, level)
			else
				row.effectLabel.Text = describeEffect(currency, slot, level)
				row.costLabel.Text = ("Cost: %s %s"):format(NumberFormat.format(upgradeCost(slot, level)), row.costCurrencyName)
			end
		end

		if prestigeButton then
			local tier = currency.selfPrestigeTiers[state.selfPrestigeTier + 1]
			prestigeButton.Text = tier and ("Prestige (" .. NumberFormat.format(tier.cost) .. ")") or "Prestige (MAXED)"
		end

		if convertRateLabel then
			local rateSlot = currency.sellInto.rateSlotId and findUpgradeSlot(currency, currency.sellInto.rateSlotId)
			local rateLevel = rateSlot and (state.upgradeLevels[rateSlot.id] or 0) or 0
			local rateMultiplier = rateSlot and (rateSlot.multiplierPerLevel ^ rateLevel) or 1
			local rate = currency.sellInto.baseRate * rateMultiplier
			convertRateLabel.Text = ("1 %s = %s %s"):format(currency.displayName, NumberFormat.format(rate), currency.sellInto.into)
		end
	end

	task.spawn(function()
		while part.Parent do
			refresh()
			task.wait(REFRESH_INTERVAL)
		end
	end)

	-- Only currencies with a leaderstat (Mana/Coins right now) show a live
	-- amount here; others stay at "0" until they're reachable and get their
	-- own leaderstat added, same as everywhere else in the UI.
	local leaderstats = player:WaitForChild("leaderstats")
	local stat = leaderstats:FindFirstChild(currencyKey)
	if stat then
		local function updateAmount()
			amountLabel.Text = NumberFormat.format(stat.Value)
		end
		stat.Changed:Connect(updateAmount)
		updateAmount()
	end
end

for _, part in CollectionService:GetTagged("UpgradeKiosk") do
	buildKioskGui(part, part:GetAttribute("ZoneKey"), part:GetAttribute("CurrencyKey"))
end

CollectionService:GetInstanceAddedSignal("UpgradeKiosk"):Connect(function(part)
	buildKioskGui(part, part:GetAttribute("ZoneKey"), part:GetAttribute("CurrencyKey"))
end)
