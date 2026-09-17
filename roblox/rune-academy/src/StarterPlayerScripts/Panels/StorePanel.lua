-- Builds the Power Store panel's content. Owns no toggle button and no
-- ScreenGui of its own - SideMenuClient parents this into its own layout
-- and controls visibility, so every menu panel behaves consistently.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local StorePanel = {}

function StorePanel.build(parent: Instance): Frame
	local requestPurchaseEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchase")

	local scroller = Instance.new("ScrollingFrame")
	scroller.Size = UDim2.new(1, 0, 1, 0)
	scroller.BackgroundTransparency = 1
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroller.ScrollBarThickness = 6
	scroller.Parent = parent

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = scroller

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = scroller

	local order = 0

	local function addSectionHeader(text: string)
		order += 1
		local header = Instance.new("TextLabel")
		header.LayoutOrder = order
		header.Size = UDim2.new(1, -8, 0, 20)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.GothamBold
		header.TextSize = 14
		header.TextColor3 = Color3.fromRGB(180, 220, 180)
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Text = text
		header.Parent = scroller
	end

	local function addProductRow(kind: string, product)
		order += 1
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -8, 0, 50)
		row.BackgroundColor3 = Color3.fromRGB(40, 55, 40)
		row.Parent = scroller
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.new(0, 8, 0, 4)
		nameLabel.Size = UDim2.new(0.65, 0, 0, 18)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = product.key
		nameLabel.Parent = row

		local priceLabel = Instance.new("TextLabel")
		priceLabel.Position = UDim2.new(0, 8, 0, 22)
		priceLabel.Size = UDim2.new(0.65, 0, 0, 18)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Font = Enum.Font.Gotham
		priceLabel.TextSize = 12
		priceLabel.TextColor3 = Color3.fromRGB(210, 200, 150)
		priceLabel.TextXAlignment = Enum.TextXAlignment.Left
		priceLabel.Text = "~" .. product.priceRobuxHint .. " R$"
		priceLabel.Parent = row

		local buyButton = Instance.new("TextButton")
		buyButton.Position = UDim2.new(0.7, 0, 0, 12)
		buyButton.Size = UDim2.new(0.28, 0, 0, 26)
		buyButton.BackgroundColor3 = Color3.fromRGB(220, 180, 60)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextSize = 13
		buyButton.TextColor3 = Color3.new(1, 1, 1)
		buyButton.Text = "Buy"
		buyButton.Parent = row
		Instance.new("UICorner", buyButton).CornerRadius = UDim.new(0, 6)

		buyButton.MouseButton1Click:Connect(function()
			requestPurchaseEvent:FireServer(kind, product.key)
		end)
	end

	addSectionHeader("Power Surges & Bundles")
	for _, product in GameConfig.DevProducts do
		addProductRow("product", product)
	end

	addSectionHeader("Gamepasses")
	for _, pass in GameConfig.GamePasses do
		addProductRow("pass", pass)
	end

	return scroller
end

return StorePanel
