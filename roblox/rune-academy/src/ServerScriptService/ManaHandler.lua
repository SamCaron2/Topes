-- Server-authoritative Mana collection: a player touches a ManaNode part on
-- the ground and gets +1 Mana. Kept separate from ResourceEngine since this
-- is a fresh, much simpler mechanic for the new vision - no upgrades/zones
-- wired to it yet.

local PlayerData = require(script.Parent.PlayerData)

local MANA_PER_PICKUP = 1

local ManaHandler = {}

function ManaHandler.collect(player: Player): number?
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	data.mana = (data.mana or 0) + MANA_PER_PICKUP
	return data.mana
end

return ManaHandler
