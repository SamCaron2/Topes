-- The Power Store: turns Robux into real, permanent gameplay power. This is
-- the primary monetization driver for the whole game, so purchase handling
-- here has to be correct - a lost purchase after real money changed hands is
-- the worst possible bug in this codebase.
--
-- Two purchase types, handled differently per Roblox's own API shape:
--   Developer Products -> MarketplaceService.ProcessReceipt (repeatable, e.g. Power Surge)
--   GamePasses          -> PromptGamePassPurchaseFinished (one-time, e.g. Archmage Pass)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)
local ResetHandler = require(script.Parent.ResetHandler)

local StoreHandler = {}

local PURCHASE_HISTORY_LIMIT = 50

local function findByField(list, field, value)
	for _, entry in list do
		if entry[field] == value then
			return entry
		end
	end
	return nil
end

-- Applies a grant table (see GameConfig's Power Store comment for the shape)
-- to a player's data. Shared by both dev products (repeatable - caller
-- decides idempotency via purchaseHistory) and gamepasses (caller gates via
-- ownedPasses before ever calling this, so a permanent multiplier is never
-- applied twice).
local function applyGrant(data, grants)
	if grants.gems then
		data.resources.Gems = (data.resources.Gems or 0) + grants.gems
	end

	if grants.freeScrolls then
		data.scrolls = (data.scrolls or 0) + grants.freeScrolls
	end

	if grants.statMultiplierAll then
		for statName, value in data.stats do
			data.stats[statName] = value * grants.statMultiplierAll
		end
	end

	if grants.statMultiplier then
		for statName, multiplier in grants.statMultiplier do
			data.stats[statName] = (data.stats[statName] or 1) * multiplier
		end
	end

	if grants.statAdd then
		for statName, amount in grants.statAdd do
			data.stats[statName] = (data.stats[statName] or 0) + amount
		end
	end

	if grants.autoCollect then
		data.ownedPasses.AutoCollectPass = true
	end

	-- grants.instantAscend is intentionally not handled here: it needs the
	-- Player instance (ResetHandler.forceAscend takes a player, not raw
	-- data), so processReceipt calls that directly before applyGrant runs.
end

-- ============================================================================
-- Developer Products (repeatable)
-- ============================================================================

function StoreHandler.processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player likely left mid-purchase; Roblox will call ProcessReceipt
		-- again automatically (retries for up to 3 days), so just wait.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = PlayerData.get(player)
	if not data then
		-- Data hasn't finished loading yet - retry later rather than risk
		-- granting into a session we're about to overwrite.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.purchaseHistory = data.purchaseHistory or {}
	for _, processedId in data.purchaseHistory do
		if processedId == receiptInfo.PurchaseId then
			-- Already granted this exact purchase - tell Roblox it's done
			-- without granting a second time.
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	local product = findByField(GameConfig.DevProducts, "id", receiptInfo.ProductId)
	if not product then
		warn(("StoreHandler: unknown ProductId %d purchased by %s"):format(receiptInfo.ProductId, player.Name))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if product.grants.instantAscend then
		ResetHandler.forceAscend(player)
	end
	applyGrant(data, product.grants)

	data.robuxSpent = (data.robuxSpent or 0) + receiptInfo.CurrencySpent

	table.insert(data.purchaseHistory, receiptInfo.PurchaseId)
	while #data.purchaseHistory > PURCHASE_HISTORY_LIMIT do
		table.remove(data.purchaseHistory, 1)
	end

	local saved = PlayerData.save(player)
	if not saved then
		-- Grant is applied in memory but didn't persist. Returning
		-- NotProcessedYet means Roblox retries; the purchaseHistory check
		-- above stays correct because THIS session still holds the granted
		-- state - a save later (autosave, leave) will persist it.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================================
-- GamePasses (one-time)
-- ============================================================================

function StoreHandler.onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	local pass = findByField(GameConfig.GamePasses, "id", gamePassId)
	if not pass then
		return
	end

	StoreHandler.grantGamePass(player, pass)
end

function StoreHandler.grantGamePass(player: Player, pass)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	if data.ownedPasses[pass.key] then
		return -- already granted, never re-apply a permanent multiplier
	end

	applyGrant(data, pass.grants)
	data.ownedPasses[pass.key] = true

	local priceSuccess, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
	end)
	if priceSuccess and productInfo and productInfo.PriceInRobux then
		data.robuxSpent = (data.robuxSpent or 0) + productInfo.PriceInRobux
	end

	PlayerData.save(player)
end

local DATA_LOAD_WAIT_TIMEOUT = 10
local DATA_LOAD_POLL_INTERVAL = 0.5

-- PlayerData.load runs in its own PlayerAdded listener, which Roblox spawns
-- as an independent thread - a yield in it (the DataStore call) does not
-- block other PlayerAdded listeners from starting, so this can run before
-- data exists. Poll briefly rather than silently skipping verification.
local function waitForData(player: Player)
	local elapsed = 0
	while elapsed < DATA_LOAD_WAIT_TIMEOUT do
		local data = PlayerData.get(player)
		if data then
			return data
		end
		task.wait(DATA_LOAD_POLL_INTERVAL)
		elapsed += DATA_LOAD_POLL_INTERVAL
	end
	return nil
end

-- Re-verifies gamepass ownership on join in case a purchase's
-- PromptGamePassPurchaseFinished event was missed (e.g. purchased from the
-- game's store page while offline). Cheap since it's one call per pass, once
-- per join, not on any hot path.
function StoreHandler.reverifyGamePasses(player: Player)
	local data = waitForData(player)
	if not data then
		warn(("StoreHandler: gave up waiting for %s's data to verify gamepasses"):format(player.Name))
		return
	end

	for _, pass in GameConfig.GamePasses do
		if not data.ownedPasses[pass.key] then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if success and owns then
				StoreHandler.grantGamePass(player, pass)
			end
		end
	end
end

-- ============================================================================
-- Client-facing purchase prompts
-- ============================================================================

-- Server-side by design (matches ProcessReceipt's requirement and keeps the
-- id lookup off the client, so a modified client can't prompt an arbitrary
-- asset id through this game's remote).
function StoreHandler.promptPurchase(player: Player, kind: string, key: string)
	if kind == "product" then
		local product = findByField(GameConfig.DevProducts, "key", key)
		if product and product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	elseif kind == "pass" then
		local pass = findByField(GameConfig.GamePasses, "key", key)
		if pass and pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end
end

MarketplaceService.ProcessReceipt = StoreHandler.processReceipt
MarketplaceService.PromptGamePassPurchaseFinished:Connect(StoreHandler.onGamePassPurchaseFinished)

Players.PlayerAdded:Connect(function(player)
	task.spawn(StoreHandler.reverifyGamePasses, player)
end)

return StoreHandler
