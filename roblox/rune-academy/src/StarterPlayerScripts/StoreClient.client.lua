-- The Store panel: opened by clicking the Store icon in the side menu
-- (SideMenuClient fires OpenStoreRequested) - per direct request ("can I
-- have you implement our store? Make it look good I want a game pass,
-- also smaller micro transactions, a starter pack"). Same modal-panel
-- look as ProfileClient/RunesMenuClient (dim background, centered panel,
-- gold stroke, X to close), scrolled since there's a lot to fit: a
-- featured Starter Pack banner up top (hidden once owned), then every
-- Game Pass, then every Micro Transaction (Dev Product) grouped by which
-- currency it grants. Pulls the whole catalog (prices + owned state) from
-- one GetStoreCatalog round trip; buying either kind just fires the
-- existing RequestPurchase remote (already wired server-side to
-- StoreHandler.promptPurchase) - the actual Robux prompt is native Roblox
-- UI from there. Re-fetches the catalog after any gamepass purchase
-- prompt closes successfully, so an owned pass's card updates to "Owned"
-- immediately without having to close and reopen the panel.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getStoreCatalogFunction = remotes:WaitForChild("GetStoreCatalog")
local requestPurchaseEvent = remotes:WaitForChild("RequestPurchase")

local GOLD = Color3.fromRGB(255, 220, 90)
local TEXT_STROKE_TRANSPARENCY = 0.4
local COLOR_CAN_BUY = Color3.fromRGB(70, 190, 60)
local COLOR_OWNED = Color3.fromRGB(90, 90, 90)
local CARD_BACKGROUND = Color3.fromRGB(255, 255, 255)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StoreUI"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("Frame")
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.BorderSizePixel = 0
dim.Active = true -- Frames don't block input by default - without this, clicks would pass through to the side menu icons underneath
dim.Parent = screenGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 560, 0, 620)
panel.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 2
panelStroke.Color = GOLD
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Position = UDim2.new(0, 20, 0, 12)
titleLabel.Size = UDim2.new(0, 160, 0, 36)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = GOLD
titleLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
titleLabel.Text = "Store"
titleLabel.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(90, 20, 20)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Parent = panel

local closeButtonCorner = Instance.new("UICorner")
closeButtonCorner.CornerRadius = UDim.new(1, 0)
closeButtonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.new(0, 16, 0, 56)
scroll.Size = UDim2.new(1, -32, 1, -72)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Padding = UDim.new(0, 10)
scrollLayout.Parent = scroll

local function sectionHeader(layoutOrder: number, text: string): TextLabel
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 26)
	header.LayoutOrder = layoutOrder
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextScaled = true
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextColor3 = GOLD
	header.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	header.Text = text
	header.Parent = scroll
	return header
end

-- One purchasable row: name (bold), description (wrapped, gray), and a
-- price/Buy button on the right. `owned` (nil for repeatable dev
-- products, true/false for passes/the Starter Pack) decides whether the
-- button can ever show "Owned" - render(owned) flips it live after a
-- purchase completes.
local function buildCard(layoutOrder: number, height: number)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, height)
	card.LayoutOrder = layoutOrder
	card.BackgroundColor3 = CARD_BACKGROUND
	card.BackgroundTransparency = 0.92
	card.BorderSizePixel = 0
	card.Parent = scroll

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0.12, 0)
	cardCorner.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0, 14, 0, 8)
	nameLabel.Size = UDim2.new(0.62, 0, 0, 22)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	nameLabel.Parent = card

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Position = UDim2.new(0, 14, 0, 30)
	descriptionLabel.Size = UDim2.new(0.62, 0, 1, -38)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.TextScaled = true
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descriptionLabel.Parent = card

	local buyButton = Instance.new("TextButton")
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.Position = UDim2.new(1, -14, 0.5, 0)
	buyButton.Size = UDim2.new(0, 110, 0, 40)
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextScaled = true
	buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
	buyButton.Parent = card

	local buyButtonCorner = Instance.new("UICorner")
	buyButtonCorner.CornerRadius = UDim.new(0.25, 0)
	buyButtonCorner.Parent = buyButton

	-- The click handler is wired ONCE here, reading whatever `onBuy`
	-- render() most recently stashed on the row - render() runs again
	-- every time the panel opens (and after a gamepass purchase
	-- completes), so re-connecting MouseButton1Click there instead would
	-- stack a fresh connection on every render and fire the purchase
	-- prompt multiple times per click after a few opens.
	local row = { card = card, nameLabel = nameLabel, descriptionLabel = descriptionLabel, buyButton = buyButton, onBuy = nil }
	buyButton.MouseButton1Click:Connect(function()
		if row.onBuy then
			row.onBuy()
		end
	end)

	return row
end

local function renderCard(row, displayName: string, description: string, priceRobuxHint: number, owned: boolean?, onBuy: () -> ())
	row.nameLabel.Text = displayName
	row.descriptionLabel.Text = description
	row.onBuy = onBuy

	if owned then
		row.buyButton.Active = false
		row.buyButton.Text = "Owned"
		row.buyButton.BackgroundColor3 = COLOR_OWNED
	else
		row.buyButton.Active = true
		row.buyButton.Text = ("R$%d"):format(priceRobuxHint)
		row.buyButton.BackgroundColor3 = COLOR_CAN_BUY
	end
end

-- ===========================================================================
-- Starter Pack: a taller, gold-stroked banner card instead of a plain row,
-- so it stands out as the featured "new player deal" - hidden entirely
-- once owned (a one-time deal has nothing left to show once it's bought).
local starterPackCard = Instance.new("Frame")
starterPackCard.Size = UDim2.new(1, 0, 0, 128)
starterPackCard.LayoutOrder = 1
starterPackCard.BackgroundColor3 = Color3.fromRGB(90, 65, 15)
starterPackCard.BackgroundTransparency = 0.35
starterPackCard.BorderSizePixel = 0
starterPackCard.Parent = scroll

local starterPackCorner = Instance.new("UICorner")
starterPackCorner.CornerRadius = UDim.new(0.1, 0)
starterPackCorner.Parent = starterPackCard

local starterPackStroke = Instance.new("UIStroke")
starterPackStroke.Thickness = 2
starterPackStroke.Color = GOLD
starterPackStroke.Parent = starterPackCard

local starterPackTag = Instance.new("TextLabel")
starterPackTag.Position = UDim2.new(0, 14, 0, 6)
starterPackTag.Size = UDim2.new(0.6, 0, 0, 18)
starterPackTag.BackgroundTransparency = 1
starterPackTag.Font = Enum.Font.GothamBold
starterPackTag.TextScaled = true
starterPackTag.TextXAlignment = Enum.TextXAlignment.Left
starterPackTag.TextColor3 = GOLD
starterPackTag.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
starterPackTag.Text = "NEW PLAYER DEAL"
starterPackTag.Parent = starterPackCard

local starterPackName = Instance.new("TextLabel")
starterPackName.Position = UDim2.new(0, 14, 0, 26)
starterPackName.Size = UDim2.new(0.62, 0, 0, 26)
starterPackName.BackgroundTransparency = 1
starterPackName.Font = Enum.Font.GothamBold
starterPackName.TextScaled = true
starterPackName.TextXAlignment = Enum.TextXAlignment.Left
starterPackName.TextColor3 = Color3.fromRGB(255, 255, 255)
starterPackName.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
starterPackName.Parent = starterPackCard

local starterPackDescription = Instance.new("TextLabel")
starterPackDescription.Position = UDim2.new(0, 14, 0, 54)
starterPackDescription.Size = UDim2.new(0.62, 0, 1, -62)
starterPackDescription.BackgroundTransparency = 1
starterPackDescription.Font = Enum.Font.Gotham
starterPackDescription.TextScaled = true
starterPackDescription.TextWrapped = true
starterPackDescription.TextXAlignment = Enum.TextXAlignment.Left
starterPackDescription.TextYAlignment = Enum.TextYAlignment.Top
starterPackDescription.TextColor3 = Color3.fromRGB(230, 220, 200)
starterPackDescription.Parent = starterPackCard

local starterPackBuyButton = Instance.new("TextButton")
starterPackBuyButton.AnchorPoint = Vector2.new(1, 0.5)
starterPackBuyButton.Position = UDim2.new(1, -14, 0.5, 0)
starterPackBuyButton.Size = UDim2.new(0, 120, 0, 44)
starterPackBuyButton.Font = Enum.Font.GothamBold
starterPackBuyButton.TextScaled = true
starterPackBuyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
starterPackBuyButton.TextStrokeTransparency = TEXT_STROKE_TRANSPARENCY
starterPackBuyButton.Parent = starterPackCard

local starterPackBuyButtonCorner = Instance.new("UICorner")
starterPackBuyButtonCorner.CornerRadius = UDim.new(0.25, 0)
starterPackBuyButtonCorner.Parent = starterPackBuyButton

-- Connected once (not inside render()) since the Starter Pack always buys
-- the same fixed key - unlike the generic cards below, there's no
-- per-render `onBuy` to swap out.
starterPackBuyButton.MouseButton1Click:Connect(function()
	requestPurchaseEvent:FireServer("pass", "StarterPack")
end)

-- ===========================================================================
-- Game Passes and Micro Transactions: built once as empty rows here (in a
-- fixed layout order), filled in by render() once the catalog arrives -
-- GameConfig's own order decides which row is which, so the client never
-- hardcodes a pass/product key beyond "this is row N."
sectionHeader(2, "Game Passes")
local passCards = {}
for i = 1, 4 do
	passCards[i] = buildCard(2 + i, 80)
end

sectionHeader(10, "Micro Transactions")
sectionHeader(11, "Mana")
local manaProductCards = {}
for i = 1, 3 do
	manaProductCards[i] = buildCard(11 + i, 72)
end

sectionHeader(20, "Arcane Dust")
local dustProductCards = {}
for i = 1, 3 do
	dustProductCards[i] = buildCard(20 + i, 72)
end

local function render(catalog)
	if not catalog then
		return
	end

	if catalog.starterPack.owned then
		starterPackCard.Visible = false
	else
		starterPackCard.Visible = true
		starterPackName.Text = catalog.starterPack.displayName
		starterPackDescription.Text = catalog.starterPack.description
		starterPackBuyButton.Text = ("R$%d"):format(catalog.starterPack.priceRobuxHint)
		starterPackBuyButton.BackgroundColor3 = COLOR_CAN_BUY
	end

	for i, pass in catalog.passes do
		if passCards[i] then
			renderCard(passCards[i], pass.displayName, pass.description, pass.priceRobuxHint, pass.owned, function()
				requestPurchaseEvent:FireServer("pass", pass.key)
			end)
		end
	end

	-- Products 1-3 are the Mana caches, 4-6 the Arcane Dust caches, per
	-- GameConfig.DevProducts' own fixed order.
	for i, product in catalog.products do
		local row = i <= 3 and manaProductCards[i] or dustProductCards[i - 3]
		if row then
			renderCard(row, product.displayName, product.description, product.priceRobuxHint, nil, function()
				requestPurchaseEvent:FireServer("product", product.key)
			end)
		end
	end
end

local sideMenuHUD = player:WaitForChild("PlayerGui"):WaitForChild("SideMenuHUD")
local openStoreEvent = sideMenuHUD:WaitForChild("OpenStoreRequested")

local function refresh()
	render(getStoreCatalogFunction:InvokeServer())
end

openStoreEvent.Event:Connect(function()
	if screenGui.Enabled then
		screenGui.Enabled = false
		return
	end

	screenGui.Enabled = true
	refresh()
end)

-- Re-fetches the catalog once a gamepass purchase prompt closes
-- successfully, so an owned pass's card flips to "Owned" immediately
-- without needing to close and reopen the Store panel. Client-side, this
-- event only ever fires for prompts this LocalPlayer itself triggered,
-- but the player check below is a harmless belt-and-suspenders guard.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(purchasingPlayer, _gamePassId, wasPurchased)
	if purchasingPlayer == player and wasPurchased and screenGui.Enabled then
		refresh()
	end
end)
