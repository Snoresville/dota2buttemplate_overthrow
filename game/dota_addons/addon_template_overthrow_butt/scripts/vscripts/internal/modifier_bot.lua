modifier_bot = modifier_bot or class({})


function modifier_bot:GetTexture() return "rattletrap_power_cogs" end -- get the icon from a different ability

function modifier_bot:IsPermanent() return true end
function modifier_bot:RemoveOnDeath() return false end
function modifier_bot:IsHidden() return false end 	-- we can hide the modifier
function modifier_bot:IsDebuff() return false end 	-- make it red or green
function modifier_bot:AllowIllusionDuplicate() return false end

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
        
        self:StartIntervalThink(0.5)
    end
end

function modifier_bot:OnIntervalThink()
    if not self.bot or not self.bot:IsAlive() then return end   -- If the bot is dead or missing

    -- Bot improvement
    self:ShopForItems()
    if self.bot:GetAbilityPoints() > 0 then self:SpendAbilityPoints() end

    if self.bot:IsChanneling() then return end                  -- MMM Let's not interrupt this bot's concentration

    -- Search before moving
    local search = self:CanSeeEnemies()                         

    if search then                                              -- Bot can see at least one enemy
        self:TargetDecision(search[1])
    else                                                        -- Default move to arena
        if self.bot:IsAttacking() then return end
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
        --print("A BOT IS ATTEMPTING TO CAST: " .. abilityQueued:GetAbilityName())
        --print(abilityQueued:GetAbilityName(), abilityQueued:GetCooldownTimeRemaining())
        print(abilityQueued:GetAbilityName(), abilityQueued:GetCurrentAbilityCharges())
    end
    if abilityQueued then
        if HasBit( ability:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then
            self:Decision_Tree(abilityQueued)
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            if abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_FRIENDLY then  -- If it only targets friendlies
                local ally_search = self:GetClosestAlly(self.cannot_self_target[abilityQueued:GetAbilityName()] == true)
                self:Decision_CastTargetEntity(ally_search[1], abilityQueued, hTarget)
            elseif abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_BOTH then  -- Pick the closest guy
                local hero_search = self:FindClosestHero(self.cannot_self_target[abilityQueued:GetAbilityName()] == true)
                self:Decision_CastTargetEntity(hero_search[1], abilityQueued, hTarget)
            else
                self:Decision_CastTargetEntity(hTarget, abilityQueued, hTarget)             -- It's definitely an enemy-only target ability
            end
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_POINT) then
            self:Decision_CastTargetPoint(hTarget, abilityQueued)
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
            self:Decision_CastTargetNone(hTarget, abilityQueued)
        end
    else
        self:Decision_AttackMove(hTarget)
    end
end

function modifier_bot:Decision_AttackTarget(hTarget)
    if self.bot:IsAttacking() then return end                   -- Bots won't be making second choices before throwing hands
    if hTarget:IsAlive() then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
            TargetIndex = hTarget:entindex()
        })
    else
        self:Decision_AttackMove(hTarget)
    end
end

function modifier_bot:Decision_AttackMove(hTarget)
    if self.bot:IsAttacking() then return end                   -- Bots won't be making second choices before throwing hands
    ExecuteOrderFromTable({
        UnitIndex = self.bot:entindex(),
        OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
        Position = hTarget:GetAbsOrigin()
    })
end

function modifier_bot:Decision_CastTargetEntity(hTarget, hAbility, hFallback)
    if hTarget:IsAlive() and (CanCastOnSpellImmune(hAbility) or not hTarget:IsMagicImmune()) then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
            TargetIndex = hTarget:entindex(),
            AbilityIndex = hAbility:entindex()
        })
    else
        self:Decision_AttackTarget(hFallback)
    end
end

function modifier_bot:Decision_CastTargetPoint(hTarget, hAbility)
    ExecuteOrderFromTable({
        UnitIndex = self.bot:entindex(),
        OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
        Position = hTarget:GetAbsOrigin(),
        AbilityIndex = hAbility:entindex()
    })
end

function modifier_bot:Decision_CastTargetNone(hTarget, hAbility)
    --print(hAbility:GetAbilityName().." has cast range: "..hAbility:GetCastRange(nil, nil))
    if (hAbility:GetCastRange(nil, nil) == 0) or (self.bot:GetRangeToUnit(hTarget) <= hAbility:GetCastRange(nil, nil)) then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
            AbilityIndex = hAbility:entindex()
        })
    else
        self:Decision_AttackTarget(hTarget)
    end
end

function modifier_bot:Decision_Tree(hTarget, hAbility)
    local trees = GridNav:GetAllTreesAroundPoint(self.bot:GetAbsOrigin(), hAbility:GetCastRange(nil, nil) + self.bot:GetCastRangeBonus(), false)
    local tree
    for _, tree_check in pairs(trees) do
        if tree_check:IsStanding() then
            tree = tree_check
            break
        end
    end

    if tree then
        if HasBit(hAbility:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            ExecuteOrderFromTable({
                UnitIndex = self.bot:entindex(),
                OrderType = DOTA_UNIT_ORDER_CAST_TARGET_TREE,
                TargetIndex = tree:entindex(),
                AbilityIndex = hAbility:entindex()
            })
        elseif HasBit(hAbility:GetBehavior(), DOTA_ABILITY_BEHAVIOR_POINT) then
            self:Decision_CastTargetPoint(tree, hAbility)
        else
            self:Decision_AttackTarget(hTarget)
        end
    else
        self:Decision_AttackTarget(hTarget)
    end
end

modifier_bot:Decision_Ability = {
    tiny_toss = function(hTarget, hAbility)
        local search = FindUnitsInRadius(
            self.bot:GetTeam(), 
            self.bot:GetAbsOrigin(), 
            nil, 
            hAbility:GetSpecialValueFor("grab_radius"), 
            DOTA_UNIT_TARGET_TEAM_BOTH, 
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 
            DOTA_UNIT_TARGET_FLAG_NONE, 
            FIND_ANY_ORDER, false)
        if #search > 0 then
            self:Decision_CastTargetEntity(hTarget, abilityQueued, hTarget)
        else
            self:Decision_AttackTarget(hTarget)
        end
    end,
}

modifier_bot.spell_filter_behavior = {
    DOTA_ABILITY_BEHAVIOR_PASSIVE,
    DOTA_ABILITY_BEHAVIOR_ATTACK,
    DOTA_ABILITY_BEHAVIOR_TOGGLE,
}

modifier_bot.spell_filter_direct = {
    -- Misc
    "generic_hidden",

    -- Chen
    "chen_holy_persuasion",

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
    "templar_assassin_trap",
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
        --if --[[HasBit( ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET ) and]] HasBit( ability:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then goto continue end
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

    if notSelfTarget then
        if #search > 1 then
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
        else
            return false
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
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 
        FIND_ANY_ORDER, false)

    if notSelfTarget then
        if #search > 1 then
            while search[1] == self.bot do
                search = FindUnitsInRadius(
                    self.bot:GetTeam(), 
                    self.bot:GetAbsOrigin(), 
                    nil, 
                    FIND_UNITS_EVERYWHERE, 
                    DOTA_UNIT_TARGET_TEAM_FRIENDLY, 
                    DOTA_UNIT_TARGET_HERO --[[ + DOTA_UNIT_TARGET_BASIC ]], 
                    DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 
                    FIND_ANY_ORDER, false)
            end
        else
            return false
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
        --print(self.bot:GetUnitName().." purchases "..target_item, "price: "..ItemName_GetGoldCost(target_item))
        self.bot:AddItemByName(target_item)
        self.bot:SpendGold(ItemName_GetGoldCost(target_item), DOTA_ModifyGold_PurchaseItem)
        table.remove(self.item_progression, 1)
    end
end

function modifier_bot:CreateItemProgression()
    --local hero_build_name = string.gsub(self:GetParent():GetUnitName(), "npc_dota_hero", "default")
    --local hero_build = LoadKeyValues("itembuilds/" .. hero_build_name .. ".txt")["Items"]
    --for k,v in pairs(hero_build) do print(k,v) end

    local item_suggestions = {
        -- Weapons
        "item_abyssal_blade",
        "item_greater_crit",
        "item_bloodthorn",
        "item_bfury",
        "item_butterfly",
        "item_monkey_king_bar",
        "item_radiance",
        "item_desolator",
        "item_nullifier",
        "item_silver_edge",
        "item_ethereal_blade",

        -- Artifacts
        "item_satanic",
        "item_skadi",
        "item_mjollnir",
        "item_heavens_halberd",
        "item_sange_and_yasha",
        "item_yasha_and_kaya",
        "item_kaya_and_sange",
        "item_overwhelming_blink",
        "item_swift_blink",
        "item_arcane_blink",

        -- Armor
        "item_assault",
        "item_heart",
        "item_sphere",
        "item_manta",
        "item_shivas_guard",
        "item_hurricane_pike",
        "item_crimson_guard",
        "item_lotus_orb",
        "item_black_king_bar",
        "item_blade_mail",

        -- Magical
        "item_gungir",
        "item_octarine_core",
        "item_wind_waker",
        "item_refresher",
        "item_solar_crest",
        "item_necronomicon_3",
        "item_dagon_5",

        -- Support
        "item_guardian_greaves",
        "item_pipe",
        "item_vladmir",
        "item_spirit_vessel",

        -- Accessories
        "item_travel_boots_2",
        "item_mask_of_madness",
        "item_phase_boots",
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