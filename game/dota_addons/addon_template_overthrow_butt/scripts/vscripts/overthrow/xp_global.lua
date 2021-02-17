dota_ability_xp_global = {
	GetIntrinsicModifierName = function() return "modifier_dota_ability_xp_global" end
}
dota_ability_xp_core_global = {
	GetIntrinsicModifierName = function() return "modifier_dota_ability_xp_core_global" end
}


LinkLuaModifier("modifier_dota_ability_xp_global", "overthrow/xp_global", LUA_MODIFIER_MOTION_NONE)
modifier_dota_ability_xp_global = {
	IsHidden = function() return true end,
	IsAura = function() return GameRules:GetDOTATime(false, true) > 0 end,
	GetModifierAura = function() return "modifier_get_xp_global" end,
	GetAuraRadius = function() return FIND_UNITS_EVERYWHERE end,
	GetAuraSearchTeam = function() return DOTA_UNIT_TARGET_TEAM_BOTH end,
	GetAuraSearchType = function() return DOTA_UNIT_TARGET_HERO end,
	GetAuraSearchFlags = function() return DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS end,
}

function modifier_dota_ability_xp_global:GetAuraEntityReject(entity)
	return entity:IsClone()
end

function modifier_dota_ability_xp_global:CheckState()
	return {
		[MODIFIER_STATE_UNSELECTABLE] = true,
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_INVULNERABLE] = true,
		[MODIFIER_STATE_OUT_OF_GAME] = true,
	}
end

LinkLuaModifier("modifier_dota_ability_xp_core_global", "overthrow/xp_global", LUA_MODIFIER_MOTION_NONE)
modifier_dota_ability_xp_core_global = class(modifier_dota_ability_xp_global)
modifier_dota_ability_xp_core_global.GetModifierAura = function() return "modifier_get_xp_core_global" end

LinkLuaModifier("modifier_get_xp_global", "overthrow/xp_global", LUA_MODIFIER_MOTION_NONE)
modifier_get_xp_global = {
	IsDebuff = function() return false end,
	GetTexture = function() return "alchemist_goblins_greed" end,
	GetEffectName = function() return "particles/econ/courier/courier_greevil_yellow/courier_greevil_yellow_ambient_3_b.vpcf" end,
}

function modifier_get_xp_global:OnCreated()
	if IsClient() then return end
	self:StartIntervalThink(0.5)
end

function modifier_get_xp_global:OnIntervalThink()
	local parent = self:GetParent()
	local ability = self:GetAbility()

	local xp = ability:GetSpecialValueFor("aura_xp")
	local gold = ability:GetSpecialValueFor("aura_gold")
	if parent:IsRealHero() then
		parent:ModifyGold(gold, false, 0)
		parent:AddExperienceCustom(xp, 0, false, false)
	end
end

LinkLuaModifier("modifier_get_xp_core_global", "overthrow/xp_global", LUA_MODIFIER_MOTION_NONE)
modifier_get_xp_core_global = class(modifier_get_xp_global)
function modifier_get_xp_core_global:IsHidden()
	return self:GetParent():HasModifier("modifier_get_xp")
end
function modifier_get_xp_core_global:OnIntervalThink()
	if not self:IsHidden() then
		modifier_get_xp_global.OnIntervalThink(self)
	end
end
