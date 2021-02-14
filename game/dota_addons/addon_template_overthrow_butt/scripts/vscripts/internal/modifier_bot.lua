modifier_bot = modifier_bot or class({})


function modifier_bot:GetTexture() return "rattletrap_power_cogs" end -- get the icon from a different ability

function modifier_bot:IsPermanent() return true end
function modifier_bot:RemoveOnDeath() return false end
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
        self.bot:SetControllableByPlayer(self.bot:GetPlayerOwnerID(), true)
        self:CreateItemProgression()
        
        self:StartIntervalThink(1)
    end
end

function modifier_bot:OnIntervalThink()
    if not self.bot or not self.bot:IsAlive() then return end   -- If the bot is dead or missing

    -- Bot improvement
    if self.bot:IsInRangeOfShop(DOTA_SHOP_HOME, true) then self:ShopForItems() end
    if self.bot:GetAbilityPoints() > 0 then self:SpendAbilityPoints() end

    if self.bot:IsChanneling() then return end                  -- MMM Let's not interrupt this bot's concentration

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

modifier_bot.cannot_self_target = {
    -- Spells
    ["abaddon_death_coil"] = true,

    -- Items
    ["item_sphere"] = true,
}

function modifier_bot:TargetDecision(hTarget)
    local castableAbilities = self:GetCastableAbilities()
    local abilityQueued
    if #castableAbilities > 0 then
        abilityQueued = castableAbilities[math.random(#castableAbilities)]
    end

    if abilityQueued then
        print("A BOT IS CASTING: " .. abilityQueued:GetAbilityName())
    end
    if abilityQueued and hTarget:IsAlive() then
        if HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            if abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_FRIENDLY then -- If it only targets friendlies
                local ally_search = self:GetClosestAlly(self.cannot_self_target[abilityQueued:GetAbilityName()] == true)
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
            elseif abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_BOTH then
                local hero_search = self:FindClosestHero(self.cannot_self_target[abilityQueued:GetAbilityName()] == true)
                if hero_search then
                    ExecuteOrderFromTable({
                        UnitIndex = self.bot:entindex(),
                        OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
                        TargetIndex = hero_search[1]:entindex(),
                        AbilityIndex = abilityQueued:entindex()
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
    DOTA_ABILITY_BEHAVIOR_TOGGLE,
}

modifier_bot.spell_filter_direct = {
    -- Misc
    "generic_hidden",

    -- Lifestealer
    "life_stealer_infest",

    -- Pudge
    "pudge_rot",
    
    -- Rubick
    "rubick_empty1",
    "rubick_empty2",
    "rubick_hidden1",
    "rubick_hidden2",
    "rubick_hidden3",

    -- Shadow Demon
    "shadow_demon_shadow_poison_release",

    -- Spectre
    "spectre_reality",

    -- Templar
    "templar_assassin_self_trap",
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
        if ability:IsHidden() then goto continue end
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

    for index = DOTA_ITEM_SLOT_1, DOTA_ITEM_SLOT_6 do
		-- Ability in question
		local ability = self.bot:GetItemInSlot(index)
		
		-- Ability checkpoint
		if ability == nil then goto continue_item end
        if HasBit( ability:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then goto continue_item end
		for _,behaviour in pairs(self.spell_filter_behavior) do
			if HasBit( ability:GetBehavior(), behaviour ) then goto continue_item end
		end
		for _,bannedAbility in pairs(self.spell_filter_direct) do
			if ability:GetAbilityName() == bannedAbility then goto continue_item end
		end
        if ability:GetCooldownTimeRemaining() ~= 0 then goto continue_item end
        if ability:GetManaCost(-1) > self.bot:GetMana() then goto continue_item end
        if not ability:IsActivated() then goto continue_item end
        if ability:RequiresCharges() and ability:GetCurrentCharges() == 0 then goto continue_item end
		
		-- Add that ability after checkpoint
		--print(ability:GetAbilityName(), "Cooldown: " .. ability:GetCooldownTimeRemaining())
		table.insert(abilities, ability)
		
		-- Skip
		::continue_item::
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
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 
        FIND_CLOSEST, false)

    return #search > 0 and search or false 
end

function modifier_bot:GetClosestAlly(notSelfTarget)
    local search = FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        FIND_UNITS_EVERYWHERE, 
        DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
        DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
        DOTA_UNIT_TARGET_FLAG_NONE, 
        FIND_ANY_ORDER, false)

    if notSelfTarget and #search > 1 then
        while search[1] == self.bot do
            search = FindUnitsInRadius(
                self.bot:GetTeam(), 
                self.bot:GetAbsOrigin(), 
                nil, 
                FIND_UNITS_EVERYWHERE, 
                DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
                DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
                DOTA_UNIT_TARGET_FLAG_NONE, 
                FIND_ANY_ORDER, false)
        end
    end

    return #search > 0 and search or false 
end

function modifier_bot:FindClosestHero(notSelfTarget)
    local search = FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        FIND_UNITS_EVERYWHERE, 
        DOTA_UNIT_TARGET_TEAM_BOTH, 
        DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
        DOTA_UNIT_TARGET_FLAG_NONE, 
        FIND_ANY_ORDER, false)

    if notSelfTarget and #search > 1 then
        while search[1] == self.bot do
            search = FindUnitsInRadius(
                self.bot:GetTeam(), 
                self.bot:GetAbsOrigin(), 
                nil, 
                FIND_UNITS_EVERYWHERE, 
                DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
                DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
                DOTA_UNIT_TARGET_FLAG_NONE, 
                FIND_ANY_ORDER, false)
        end
    end

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

function modifier_bot:ShopForItems()
    if #self.item_progression == 0 then return end

    local target_item = self.item_progression[1]

    if ItemName_GetGoldCost(target_item) <= self.bot:GetGold() then
        print(target_item, ItemName_GetID(target_item))
        self.bot:AddItemByName(target_item)
        self.bot:SpendGold(ItemName_GetGoldCost(target_item), DOTA_ModifyGold_PurchaseItem)
        EmitSoundOnLocationWithCaster(self.bot:GetAbsOrigin(), "General.Buy", self.bot)
        table.remove(self.item_progression, 1)
    end
end

function modifier_bot:CreateItemProgression()
    --local hero_build_name = string.gsub(self:GetParent():GetUnitName(), "npc_dota_hero", "default")
    --local hero_build = LoadKeyValues("itembuilds/" .. hero_build_name .. ".txt")["Items"]
    --for k,v in pairs(hero_build) do print(k,v) end

    local item_suggestions = {
        "item_abyssal_blade",
        "item_greater_crit",
        "item_bloodthorn",
        "item_bfury",
        "item_butterfly",
        "item_monkey_king_bar",
        "item_radiance",
        "item_desolator",
        "item_satanic",
        "item_skadi",
        "item_mjollnir",
        "item_assault",
        "item_heart",
        "item_sphere",
        "item_manta",
        "item_gungir",
        "item_octarine_core",
        "item_travel_boots_2",
        "item_guardian_greaves",
        "item_pipe",
        "item_vladmir",
        "item_spirit_vessel",
        "item_crimson_guard",
        "item_lotus_orb",
    }
    
    local full_slots = {}

    while #full_slots < 6 do
        local suggestion_index = math.random(#item_suggestions)
        local suggestion = item_suggestions[suggestion_index]

        table.remove(item_suggestions, suggestion_index)
        table.insert(full_slots, suggestion)
    end

    -- Aghs for good luck
    table.insert(full_slots, "item_ultimate_scepter_2")
    table.insert(full_slots, "item_aghanims_shard")

    self.item_progression = GetAllBuildComponents(full_slots)
end