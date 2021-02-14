modifier_bot = modifier_bot or class({})


function modifier_bot:GetTexture() return "rattletrap_power_cogs" end -- get the icon from a different ability

function modifier_bot:IsPermanent() return not self:GetParent():IsIllusion() end
function modifier_bot:RemoveOnDeath() return self:GetParent():IsIllusion() end
function modifier_bot:IsHidden() return false end 	-- we can hide the modifier
function modifier_bot:IsDebuff() return false end 	-- make it red or green
function modifier_bot:AllowIllusionDuplicate() return true end

function modifier_bot:GetAttributes()
	return 0
		+ MODIFIER_ATTRIBUTE_PERMANENT           -- Modifier passively remains until strictly removed. 
		-- + MODIFIER_ATTRIBUTE_MULTIPLE            -- Allows modifier to stack with itself. 
		-- + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE -- Allows modifier to be assigned to invulnerable entities. 
end

function modifier_bot:OnCreated()
    if IsServer() then
        self.bot = self:GetParent()
        self:StartIntervalThink(1)
    end
end

function modifier_bot:OnIntervalThink()
    if not self.bot or not self.bot:IsAlive() then return end   -- If the bot is dead or missing

    if self.bot:GetAbilityPoints() > 0 then self:SpendAbilityPoints() end

    -- Search before moving
    local search = self:CanSeeEnemies()                         

    if search then                                              -- Bot can see at least one enemy
        self:TargetDecision(search[1])
    else                                                        -- Default move to arena
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = Vector(0,0,0)
        })
    end
end

function modifier_bot:TargetDecision(hTarget)
    local castableAbilities = self:GetCastableAbilities()
    local abilityQueued
    if #castableAbilities > 0 then
        abilityQueued = castableAbilities[math.random(#castableAbilities)]
    end

    if abilityQueued and hTarget:IsAlive() then
        if HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            if abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_FRIENDLY then -- If it only targets friendlies
                local ally_search = self:GetRandomAlly()
                if ally_search and self.bot:GetRangeToUnit(ally_search[1]) <= abilityQueued:GetCastRange(nil, nil) then
                    ExecuteOrderFromTable({
                        UnitIndex = self.bot:entindex(),
                        OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
                        TargetIndex = ally_search[1]:entindex(),
                        AbilityIndex = abilityQueued:entindex()
                    })
                else
                    ExecuteOrderFromTable({
                        UnitIndex = self.bot:entindex(),
                        OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
                        TargetIndex = hTarget:entindex()
                    })
                end
            else
                ExecuteOrderFromTable({
                    UnitIndex = self.bot:entindex(),
                    OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
                    TargetIndex = hTarget:entindex(),
                    AbilityIndex = abilityQueued:entindex()
                })
            end
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_POINT) then
            ExecuteOrderFromTable({
                UnitIndex = self.bot:entindex(),
                OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
                Position = hTarget:GetAbsOrigin(),
                AbilityIndex = abilityQueued:entindex()
            })
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
            ExecuteOrderFromTable({
                UnitIndex = self.bot:entindex(),
                OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
                AbilityIndex = abilityQueued:entindex()
            })
        end
    else
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = hTarget:GetAbsOrigin()
        })
    end
end

modifier_bot.spell_filter_behavior = {
    DOTA_ABILITY_BEHAVIOR_PASSIVE,
    DOTA_ABILITY_BEHAVIOR_ATTACK,
    DOTA_ABILITY_BEHAVIOR_HIDDEN,
    DOTA_ABILITY_BEHAVIOR_TOGGLE,
}

modifier_bot.spell_filter_direct = {
    -- Misc
    "generic_hidden",

    -- Pudge
    "pudge_rot",
    
    -- Rubick
    "rubick_empty1",
    "rubick_empty2",
    "rubick_hidden1",
    "rubick_hidden2",
    "rubick_hidden3",
}

function modifier_bot:GetCastableAbilities()
    local abilities = {}

    -- Base Case
    if self.bot:IsSilenced() then return abilities end
    if self.bot:IsIllusion() then return abilities end

    for index = 0,15 do
		-- Ability in question
		local ability = self.bot:GetAbilityByIndex(index)
		
		-- Ability checkpoint
		if ability == nil then goto continue end
        if ability:GetLevel() == 0 then goto continue end
        if HasBit( ability:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then goto continue end
		for _,behaviour in pairs(self.spell_filter_behavior) do
			if HasBit( ability:GetBehavior(), behaviour ) then goto continue end
		end
		for _,bannedAbility in pairs(self.spell_filter_direct) do
			if ability:GetAbilityName() == bannedAbility then goto continue end
		end
        if ability:GetCooldownTimeRemaining() ~= 0 then goto continue end
        if ability:GetManaCost(-1) > self.bot:GetMana() then goto continue end
        if not ability:IsActivated() then goto continue end
        if ability.RequiresCharges and ability:GetCurrentCharges() == 0 then goto continue end
		
		-- Add that ability after checkpoint
		--print(ability:GetAbilityName(), "Cooldown: " .. ability:GetCooldownTimeRemaining())
		table.insert(abilities, ability)
		
		-- Skip
		::continue::
	end

    return abilities
end

function modifier_bot:CanSeeEnemies()
    local search = FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        FIND_UNITS_EVERYWHERE, 
        DOTA_UNIT_TARGET_TEAM_ENEMY, 
        DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 
        FIND_CLOSEST, false)

    return #search > 0 and search or false 
end

function modifier_bot:GetRandomAlly()
    local search = FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        FIND_UNITS_EVERYWHERE, 
        DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
        DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
        DOTA_UNIT_TARGET_FLAG_NONE, 
        FIND_ANY_ORDER, false)

    return #search > 0 and search or false 
end

function modifier_bot:SpendAbilityPoints()
    local basic = {self.bot:GetAbilityByIndex(0), self.bot:GetAbilityByIndex(1), self.bot:GetAbilityByIndex(2)}
    local ultimate = self.bot:GetAbilityByIndex(5)
    local level = self.bot:GetLevel()

    -- Upgrade Ultimate
    if level % 6 == 0 then
        self.bot:UpgradeAbility(ultimate)
    end

    -- Upgrade Talent
    if level % 5 == 0 and level >= 10 then
        local talent_bar = level / 5
        local talents = {self.bot:GetAbilityByIndex(2 + 2 * talent_bar), self.bot:GetAbilityByIndex(3 + 2 * talent_bar)}
        self.bot:UpgradeAbility(talents[math.random(2)])
    end

    -- Upgrade Ability
    while self.bot:GetAbilityPoints() > 0 do
        local basic_chosen = basic[math.random(3)]
        if basic_chosen:GetLevel() * 2 < level then -- Prevents level 1 abilites from getting levelled up at level 2 and etc.
            self.bot:UpgradeAbility(basic_chosen)

            -- Toggle auto cast
            if basic_chosen:IsToggle() and not basic_chosen:GetAutoCastState() then
                basic_chosen:ToggleAutoCast()
            end
        end
    end
end