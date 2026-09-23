-- Client-only, session-only settings (not saved server-side - they reset
-- on rejoin, same as any other local display preference). A plain module
-- rather than a remote/PlayerData field since nothing server-authoritative
-- depends on these; every client that requires this gets its own separate
-- copy (module caching is per-client for LocalScripts), so one player's
-- settings never affect another's.

local ClientSettings = {}

-- Toggled by SettingsClient's "Reduce Effects" switch - GraphicsSettingsClient
-- listens and turns decor PointLights (currently just the glow mushrooms'
-- caps) on/off across every island's decor folder.
ClientSettings.reducedEffects = false
ClientSettings.ReducedEffectsChanged = Instance.new("BindableEvent")

function ClientSettings.setReducedEffects(value: boolean)
	ClientSettings.reducedEffects = value
	ClientSettings.ReducedEffectsChanged:Fire(value)
end

-- Toggled by SettingsClient's "Collection Popups" switch - RuneAltarClient
-- reads this directly (no event needed, checked fresh every time a Rune
-- is collected) to decide whether to show the floating "+N RankName" text.
ClientSettings.collectionPopupsEnabled = true

function ClientSettings.setCollectionPopupsEnabled(value: boolean)
	ClientSettings.collectionPopupsEnabled = value
end

return ClientSettings
