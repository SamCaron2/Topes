-- The Store: turns Robux into real, permanent gameplay power. This is the
-- primary monetization driver for the whole game, so purchase handling
-- here has to be correct - a lost purchase after real money changed hands
-- is the worst possible bug in this codebase. Rebuilt from scratch per
-- direct request ("can I have you implement our store? ... I want a game
-- pass, also smaller micro transactions, a starter pack") - the actual
-- purchase-processing plumbing below (ProcessReceipt, idempotency via
-- purchaseHistory, PromptGamePassPurchaseFinished, reverifyGamePasses)
-- was already solid from an earlier, scrapped design, so only the grant
-- shapes (`applyGrant`) and GameConfig's content changed to target this
-- game's real currencies/systems instead of that design's Gems/Scrolls/
-- Stats.
--
-- Two purchase types, handled differently per Roblox's own API shape:
--   Developer Products -> MarketplaceService.ProcessReceipt (repeatable, e.g. a Mana Cache)
--   GamePasses          -> PromptGamePassPurchaseFinished (one-time, e.g. VIPPass; the Starter
--                           Pack is also handled as a GamePass under the hood - see GameConfig)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PlayerData = require(script.Parent.PlayerData)

local StoreHandler = {}

local PURCHASE_HISTORY_LIMIT = 50

-- ProcessReceipt/PromptGamePassPurchaseFinished are Roblox-driven callbacks,
-- not requests routed through Main.server.lua's usual OnServerInvoke
-- wrappers (which are what normally fire a currency's Updated event after
-- a handler returns a new state) - so a direct currency grant here would
-- otherwise sit in PlayerData without the corner HUD/boards ever finding
-- out until their next unrelated update. Reaching straight into
-- ReplicatedStorage.Remotes to fire those events is the same exception
-- WorldBuilder.server.lua's own background loops already make, for the
-- same reason (an independent server-side loop, not a request/response
-- remote call). Looked up lazily (not at module load time) and cached
-- after the first purchase, since StoreHandler is `require`d by
-- Main.server.lua BEFORE that same script creates the Remotes folder a
-- few lines later - a WaitForChild at the top of this file would deadlock
-- Main.server.lua's own thread waiting on a folder it hasn't created yet.
-- By the time an actual purchase fires (long after server startup), the
-- folder is long since there.
local remotesFolder
local manaUpdatedEvent
local arcaneDustUpdatedEvent

local function fireCurrencyUpdates(player: Player, data, grants)
	if not grants.manaAmount and not grants.arcaneDustAmount then
		return
	end

	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
		manaUpdatedEvent = remotesFolder:WaitForChild("ManaUpdated")
		arcaneDustUpdatedEvent = remotesFolder:WaitForChild("ArcaneDustUpdated")
	end

	if grants.manaAmount then
		manaUpdatedEvent:FireClient(player, data.mana or 0)
	end
	if grants.arcaneDustAmount then
		arcaneDustUpdatedEvent:FireClient(player, data.arcaneDust or 0)
	end
end

local function findByField(list, field, value)
	for _, entry in list do
		if entry[field] == value then
			return entry
		end
	end
	return nil
end

-- Applies a grant table (see GameConfig's Store comment for the shape) to
-- a player's data. Shared by both dev products (repeatable - caller
-- decides idempotency via purchaseHistory) and gamepasses/the Starter
-- Pack (caller gates via ownedPasses before ever calling this, so a
-- permanent multiplier is never applied twice). Direct currency grants
-- (manaAmount/arcaneDustAmount) add straight to the live balance; every
-- other grant field is just a flag/number read later by
-- GamePassBoostHandler's own getters - applyGrant itself doesn't need to
-- know what a multiplier means, only that owning the pass is enough for
-- ownedPasses[key] = true to make it take effect everywhere that reads it.
local function applyGrant(data, grants)
	if grants.manaAmount then
		data.mana = (data.mana or 0) + grants.manaAmount
	end

	if grants.arcaneDustAmount then
		data.arcaneDust = (data.arcaneDust or 0) + grants.arcaneDustAmount
	end
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

	applyGrant(data, product.grants)
	fireCurrencyUpdates(player, data, product.grants)
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
-- GamePasses (one-time) - the Starter Pack is included here too (it's
-- really just another one-time pass under the hood, see GameConfig's own
-- comment), so every lookup below checks both tables at once instead of
-- needing a parallel "or is it the Starter Pack" branch everywhere.
-- ============================================================================

local ALL_PASSES = {}
for _, pass in GameConfig.GamePasses do
	table.insert(ALL_PASSES, pass)
end
table.insert(ALL_PASSES, GameConfig.StarterPack)

function StoreHandler.onGamePassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end

	local pass = findByField(ALL_PASSES, "id", gamePassId)
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
	fireCurrencyUpdates(player, data, pass.grants)
	data.ownedPasses[pass.key] = true

	local priceSuccess, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
	end)
	if priceSuccess and productInfo and productInfo.PriceInRobux then
		data.robuxSpent = (data.robuxSpent or 0) + productInfo.PriceInRobux
	end

	PlayerData.save(player)
end

-- Re-verifies gamepass/Starter Pack ownership on join in case a purchase's
-- PromptGamePassPurchaseFinished event was missed (e.g. purchased from the
-- game's store page while offline). Cheap since it's one call per pass, once
-- per join, not on any hot path.
function StoreHandler.reverifyGamePasses(player: Player)
	local data = PlayerData.waitForLoad(player)
	if not data then
		warn(("StoreHandler: gave up waiting for %s's data to verify gamepasses"):format(player.Name))
		return
	end

	for _, pass in ALL_PASSES do
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
		local pass = findByField(ALL_PASSES, "key", key)
		if pass and pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end
	end
end

-- Read by StoreClient to render the whole catalog (prices, and whether
-- each pass/the Starter Pack is already owned) in one round trip.
function StoreHandler.getCatalog(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return nil
	end

	local passes = {}
	for i, pass in GameConfig.GamePasses do
		passes[i] = {
			key = pass.key,
			displayName = pass.displayName,
			description = pass.description,
			priceRobuxHint = pass.priceRobuxHint,
			owned = data.ownedPasses[pass.key] == true,
		}
	end

	local products = {}
	for i, product in GameConfig.DevProducts do
		products[i] = { key = product.key, displayName = product.displayName, description = product.description, priceRobuxHint = product.priceRobuxHint }
	end

	return {
		passes = passes,
		products = products,
		starterPack = {
			displayName = GameConfig.StarterPack.displayName,
			description = GameConfig.StarterPack.description,
			priceRobuxHint = GameConfig.StarterPack.priceRobuxHint,
			owned = data.ownedPasses[GameConfig.StarterPack.key] == true,
		},
	}
end

MarketplaceService.ProcessReceipt = StoreHandler.processReceipt
MarketplaceService.PromptGamePassPurchaseFinished:Connect(StoreHandler.onGamePassPurchaseFinished)

Players.PlayerAdded:Connect(function(player)
	task.spawn(StoreHandler.reverifyGamePasses, player)
end)

return StoreHandler
