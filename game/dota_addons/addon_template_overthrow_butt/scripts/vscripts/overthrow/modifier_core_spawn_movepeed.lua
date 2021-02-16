modifier_core_spawn_movespeed = {
	GetTexture = function() return "item_boots" end,
	GetModifierMoveSpeedBonus_Constant = function() return 200 end,
	DeclareFunctions = function()
		return {
			MODIFIER_EVENT_ON_UNIT_MOVED,
			MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
		}
	end,
}