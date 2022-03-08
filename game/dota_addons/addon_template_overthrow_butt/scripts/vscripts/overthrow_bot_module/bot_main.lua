LinkLuaModifier("modifier_bot", "overthrow_bot_module/bot_hero.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bot_simple", "overthrow_bot_module/bot_unit.lua", LUA_MODIFIER_MOTION_NONE)

if OverthrowBot == nil then
	_G.OverthrowBot = class({})
	OverthrowBot.item_kv = LoadKeyValues("scripts/npc/items.txt")
	OverthrowBot.ability_kv = LoadKeyValues("scripts/npc/npc_abilities.txt")

    -- This is turned on once the game is in progress so we dont put bot_unit on units spawned before gameplay
    OverthrowBot.unit_spawn_ai_enabled = false
end

--
-- Overthrow Bot Functions
--
function OverthrowBot:GetAllBuildComponents(hero_build)
	local build_components = {}
	for _, item in pairs(hero_build) do
		local components = OverthrowBot:GetAllItemComponents(item)
		for _, component in pairs(components) do
			table.insert(build_components, component)
		end
	end
	return build_components
end

function OverthrowBot:GetAllItemComponents(item)
	local recipe_name = string.gsub(item, "item_", "item_recipe_")
	if OverthrowBot.item_kv[recipe_name] then
		local recipe = OverthrowBot.item_kv[recipe_name]
		local return_components = {}
		local item_requirements

		for _, requirements in pairs(recipe["ItemRequirements"]) do
			item_requirements = requirements
			break
		end
		--print(recipe_name)
		local subcomponents = string_split(item_requirements, ";")
		for i = 1, #subcomponents do
			subcomponents[i] = string.gsub(subcomponents[i], "*", "")
		end
		table.insert(subcomponents, recipe_name)

		for _, subcomponent in pairs(subcomponents) do
			local subsubcomponents = OverthrowBot:GetAllItemComponents(subcomponent)
			for _, subsubcomponent in pairs(subsubcomponents) do
				table.insert(return_components, subsubcomponent)
			end
		end

		return return_components
	else
		local itemCost = tonumber(OverthrowBot.item_kv[item]["ItemCost"])
		if itemCost ~= nil and itemCost > 0 then 
			return {item}
		else
			return {} 
		end
	end
end

function OverthrowBot:ItemName_GetGoldCost(item_name)
	return OverthrowBot.item_kv[item_name]["ItemCost"]
end

function OverthrowBot:ItemName_GetID(item_name)
	return OverthrowBot.item_kv[item_name]["ID"]
end

function CDOTABaseAbility:HasCharges()
	if OverthrowBot.ability_kv[self:GetAbilityName()] and OverthrowBot.ability_kv[self:GetAbilityName()]["AbilityCharges"] then return true end
	return false
end

function OverthrowBot:InitialiseRandom()
    print("[OverthrowBot] System time is: "..GetSystemTime())

    local newRandomSeed = math.random()

    for i in string.gmatch(GetSystemTime(), "%d") do
        newRandomSeed = newRandomSeed * (i + 1)
        math.randomseed(newRandomSeed)
        newRandomSeed = newRandomSeed + math.random()
    end
    --math.randomseed()
end

function HasBit(checker, value)
    local checkVal = checker
    if type(checkVal) == 'userdata' then
        checkVal = tonumber(checker:ToHexString(), 16)
    end
    return bit.band( checkVal, tonumber(value)) == tonumber(value)
end

--
-- Bot Modifier Script
--

function print_debug(unit, message)
    --print("[overthrow bot] "..unit:GetUnitName().." - "..message)
end

function OverthrowBot:OnIntervalThink()
    print_debug(self.bot, "onintervalthink")
    if GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME then return end
    if not self.bot or self.bot:IsNull() then return end -- If the bot is missing
    if self.bot:HasAttackCapability() == false then return end -- If this bot is practically useless
    if not self.bot:IsAlive() then 
        if self.bot:IsHero() and (not self.bot:IsClone() or self.bot:IsIllusion()) then
            if self.item_progression and #self.item_progression == 0 and self.bot:GetBuybackCooldownTime() <= 0 and self.bot:GetBuybackCost(false) <= self.bot:GetGold() then
                ExecuteOrderFromTable({
                    UnitIndex = self.bot:entindex(),
                    OrderType = DOTA_UNIT_ORDER_BUYBACK
                })
            end
        end
        return 
    end   

    -- Bot improvement
    OverthrowBot.ShopForItems(self)
    if self.bot.GetAbilityPoints and self.bot:GetAbilityPoints() > 0 then OverthrowBot.SpendAbilityPoints(self) end

    -- Cannot be ordered
    if self.bot:IsChanneling() then return end                  -- MMM Let's not interrupt this bot's concentration
    if self.bot:IsCommandRestricted() then return end           -- Can't really do anything now huh

    -- Search before moving
    local search = OverthrowBot.CanSeeEnemies(self)                         

    if search then                                              -- Bot can see at least one enemy
        OverthrowBot.TargetDecision(self, search[1])
    else                                                        -- Default move to arena
        if self.bot:IsAttacking() then return end
        OverthrowBot.Decision_GatherAtCenter(self)
    end
end

function OverthrowBot:GetCastableAbilities()
    print_debug(self.bot, "getcastableabilities")
    local abilities = {}

    -- Base Case
    if self.bot:IsSilenced() then return abilities end
    if self.bot:IsIllusion() and not self.bot:IsTempestDouble() then return abilities end

    for index = 0,15 do
		-- Ability in question
		local ability = self.bot:GetAbilityByIndex(index)
		
		-- Ability checkpoint
		if ability == nil then goto continue end
        if ability:GetLevel() == 0 then goto continue end
        if ability:IsHidden() then goto continue end
        --if --[[HasBit( ability:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET ) and]] HasBit( ability:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then goto continue end
		for _,behaviour in pairs(OverthrowBot.spell_filter_behavior) do
			if HasBit( ability:GetBehavior(), behaviour ) then goto continue end
		end
        if OverthrowBot.spell_filter_direct[ability:GetAbilityName()] then goto continue end
        if ability:GetCooldownTimeRemaining() ~= 0 then goto continue end
        if ability:GetManaCost(-1) > self.bot:GetMana() then goto continue end
        if not ability:IsActivated() then goto continue end
        if ability:HasCharges() and ability:GetCurrentAbilityCharges() == 0 then goto continue end
		
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
		for _,behaviour in pairs(OverthrowBot.spell_filter_behavior) do
			if HasBit( ability:GetBehavior(), behaviour ) then goto continue_item end
		end
		if OverthrowBot.spell_filter_direct[ability:GetAbilityName()] then goto continue_item end
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

function OverthrowBot:TargetDecision(hTarget)
    print_debug(self.bot, "targetdecision")
    local castableAbilities = OverthrowBot.GetCastableAbilities(self)
    local abilityQueued
    if #castableAbilities > 0 then
        abilityQueued = castableAbilities[math.random(#castableAbilities)]
    end

    if abilityQueued then
        --print(self.bot:GetUnitName() .. " IS ATTEMPTING TO CAST: " .. abilityQueued:GetAbilityName())
        --print(abilityQueued:GetAbilityName(), abilityQueued:GetCooldownTimeRemaining())
        --print(abilityQueued:GetAbilityName(), abilityQueued:GetCurrentAbilityCharges())
    end
    if abilityQueued and self.bot:CanEntityBeSeenByMyTeam(hTarget) then
        if OverthrowBot.Decision_Ability[abilityQueued:GetAbilityName()] then
            OverthrowBot.Decision_Ability[abilityQueued:GetAbilityName()](self, hTarget, abilityQueued)
        elseif OverthrowBot.spell_cast_nearby[abilityQueued:GetAbilityName()] then
            OverthrowBot.Decision_CastTargetNoneNearby(self, hTarget, abilityQueued, abilityQueued:GetSpecialValueFor(OverthrowBot.spell_cast_nearby[abilityQueued:GetAbilityName()]) * 0.9)
        elseif HasBit( abilityQueued:GetAbilityTargetType(), DOTA_UNIT_TARGET_TREE ) then
            OverthrowBot.Decision_Tree(self, hTarget, abilityQueued)
        elseif HasBit( abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_TOGGLE) then
            OverthrowBot.Decision_Toggle(self, hTarget, abilityQueued)
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            local search = OverthrowBot.GetClosestUnit(self, OverthrowBot.cannot_self_target[abilityQueued:GetAbilityName()] == true, abilityQueued)
            if abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_BOTH then
                OverthrowBot.Decision_CastTargetPreferEnemies(self, search[1], abilityQueued, hTarget)
            elseif abilityQueued:GetAbilityTargetTeam() == DOTA_UNIT_TARGET_TEAM_FRIENDLY then
                OverthrowBot.Decision_CastTargetRandomAlly(self, search[1], abilityQueued, hTarget)
            else
                OverthrowBot.Decision_CastTargetEntity(self, search[1], abilityQueued, hTarget)
            end
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_POINT) then
            OverthrowBot.Decision_CastTargetPoint(self, hTarget, abilityQueued)
        elseif HasBit(abilityQueued:GetBehavior(), DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
            OverthrowBot.Decision_CastTargetNone(self, hTarget, abilityQueued)
        end
    else
        OverthrowBot.Decision_AttackMove(self, hTarget)
    end
end

--
-- Decision Making
--

-- Attacking
function OverthrowBot:Decision_AttackTarget(hTarget)
    print_debug(self.bot, "decision-attacktarget")
    if self.bot:IsAttacking() then return end                   -- Bots won't be making second choices before throwing hands
    if hTarget:IsAlive() and not hTarget:IsAttackImmune() then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
            TargetIndex = hTarget:entindex()
        })
    else
        OverthrowBot.Decision_AttackMove(self, hTarget)
    end
end
function OverthrowBot:Decision_AttackMove(hTarget)
    print_debug(self.bot, "decision-attackmove")
    if self.bot:IsAttacking() then return end                   -- Bots won't be making second choices before throwing hands
    if self.bot:HasMovementCapability() then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = hTarget:GetAbsOrigin()
        })
    elseif self.bot:GetRangeToUnit(hTarget) <= self.bot:Script_GetAttackRange() then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_TARGET,
            TargetIndex = hTarget:entindex(),
        })
    end
end

-- Casting
function OverthrowBot:Decision_CastTargetEntity(hTarget, hAbility, hFallback)
    print_debug(self.bot, "decision-casttargetentity")
    if hTarget and UnitFilter(hTarget, hAbility:GetAbilityTargetTeam(), hAbility:GetAbilityTargetType(), hAbility:GetAbilityTargetFlags(), self.bot:GetTeamNumber()) then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_TARGET,
            TargetIndex = hTarget:entindex(),
            AbilityIndex = hAbility:entindex()
        })
    else
        OverthrowBot.Decision_AttackTarget(self, hFallback)
    end
end
function OverthrowBot:Decision_CastTargetPreferEnemies(hTarget, hAbility, hFallback)
    print_debug(self.bot, "decision-casttargetpreferenemies")
    local search_target = OverthrowBot.GetClosestUnits(self, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_ENEMY, hAbility:GetAbilityTargetType())
    if #search_target > 0 and RollPercentage(80) then
        search_target = search_target[1]
    else
        search_target = OverthrowBot.GetClosestUnit(self, OverthrowBot.cannot_self_target[hAbility:GetAbilityName()] == true, hAbility)[1]
    end
    OverthrowBot.Decision_CastTargetEntity(self, search_target, hAbility, hFallback)
end
function OverthrowBot:Decision_CastTargetRandomAlly(hTarget, hAbility, hFallback)
    print_debug(self.bot, "decision-casttargetrandomally")
    local search_target = OverthrowBot.GetClosestUnit(self, OverthrowBot.cannot_self_target[hAbility:GetAbilityName()] == true, hAbility)
    search_target = search_target[math.random(#search_target)]
    OverthrowBot.Decision_CastTargetEntity(self, search_target, hAbility, hFallback)
end
function OverthrowBot:Decision_CastTargetPoint(hTarget, hAbility)
    ExecuteOrderFromTable({
        UnitIndex = self.bot:entindex(),
        OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
        Position = hTarget:GetAbsOrigin(),
        AbilityIndex = hAbility:entindex()
    })
end
function OverthrowBot:Decision_CastTargetNone(hTarget, hAbility)
    print_debug(self.bot, "decision-casttargetnone")
    if (hAbility:GetCastRange(hTarget:GetAbsOrigin(), nil) == 0) or (self.bot:GetRangeToUnit(hTarget) <= hAbility:GetCastRange(hTarget:GetAbsOrigin(), nil)) then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
            AbilityIndex = hAbility:entindex()
        })
    else
        OverthrowBot.Decision_AttackTarget(self, hTarget)
    end
end

function OverthrowBot:Decision_CastTargetNoneNearby(hTarget, hAbility, radius)
    print_debug(self.bot, "decision-casttargetnonenearby")
    if self.bot:GetRangeToUnit(hTarget) <= radius then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
            AbilityIndex = hAbility:entindex()
        })
    else
        OverthrowBot.Decision_AttackTarget(self, hTarget)
    end
end

-- Misc
function OverthrowBot:Decision_GatherAtCenter()
    print_debug(self.bot, "decision-gatheratcenter")
    if self.bot:IsAttacking() then return end                   -- Bots won't be making second choices before throwing hands
    if self.bot:HasMovementCapability() then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = Vector(0,0,0)
        })
    end
end

function OverthrowBot:Decision_Tree(hTarget, hAbility)
    print_debug(self.bot, "decision-tree")
    local trees = GridNav:GetAllTreesAroundPoint(self.bot:GetAbsOrigin(), hAbility:GetCastRange(nil, nil) + self.bot:GetCastRangeBonus(), false)
    local tree
    for _, tree_check in pairs(trees) do
        if (tree_check and not tree_check:IsNull()) and tree_check.IsStanding and tree_check:IsStanding() then
            tree = tree_check
            break
        end
    end

    if tree then
        if HasBit(hAbility:GetBehavior(), DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
            ExecuteOrderFromTable({
                UnitIndex = self.bot:entindex(),
                OrderType = DOTA_UNIT_ORDER_CAST_TARGET_TREE,
                TargetIndex = GetTreeIdForEntityIndex(tree:entindex()),
                AbilityIndex = hAbility:entindex()
            })
        elseif HasBit(hAbility:GetBehavior(), DOTA_ABILITY_BEHAVIOR_POINT) then
            OverthrowBot.Decision_CastTargetPoint(self, tree, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    else
        OverthrowBot.Decision_AttackTarget(self, hTarget)
    end
end
function OverthrowBot:Decision_Toggle(hTarget, hAbility)
    print_debug(self.bot, "decision-toggle")
    -- Turn on the toggles
    if hAbility:IsToggle() and hAbility:GetToggleState() == false then
        hAbility:OnToggle()
    else
        OverthrowBot.Decision_AttackTarget(self, hTarget)
    end
end
function OverthrowBot:Decision_CastTargetPointAlly(hFallback, hAbility) 
    print_debug(self.bot, "decision-casttargetpointally")
    local targets = OverthrowBot.GetClosestUnits(self, hAbility:GetCastRange(nil, nil) + self.bot:GetCastRangeBonus(), DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC)
    local hTarget = targets[math.random(#targets)]
        if hTarget then
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_CAST_POSITION,
            Position = hTarget:GetAbsOrigin(),
            AbilityIndex = hAbility:entindex()
        })
    else
        OverthrowBot.Decision_AttackTarget(self, hFallback)
    end
end

-- Individual abilities
OverthrowBot.Decision_Ability = {
    tiny_toss = function(self, hTarget, hAbility)
        local search = OverthrowBot.GetClosestUnits(self, hAbility:GetSpecialValueFor("grab_radius") * 0.9, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_HERO)
        if #search > 1 then
            OverthrowBot.Decision_CastTargetEntity(self, hTarget, hAbility, hTarget)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    templar_assassin_meld = function(self, hTarget, hAbility)
        OverthrowBot.Decision_CastTargetNoneNearby(self, hTarget, hAbility, self.bot:Script_GetAttackRange() * 0.8)
    end,

    rattletrap_power_cogs = function(self, hTarget, hAbility)
        OverthrowBot.Decision_CastTargetNoneNearby(self, hTarget, hAbility, hAbility:GetSpecialValueFor("cogs_radius") * 0.75)
    end,

    hoodwink_scurry = function(self, hTarget, hAbility)
        if not self.bot:HasModifier("modifier_hoodwink_scurry_active") then
            OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    hoodwink_acorn_shot = function(self, hTarget, hAbility)
        OverthrowBot.Decision_CastTargetPoint(self, hTarget, hAbility)
    end,

    furion_force_of_nature = function(self, hTarget, hAbility)
        OverthrowBot.Decision_Tree(self, hTarget, hAbility)
    end,

    arc_warden_magnetic_field = function(self, hTarget, hAbility)
        OverthrowBot.Decision_CastTargetPointAlly(self, hTarget, hAbility)
    end,

    ember_spirit_activate_fire_remnant = function(self, hTarget, hAbility)
        if self.bot:HasModifier("modifier_ember_spirit_fire_remnant_timer") then
            OverthrowBot.Decision_CastTargetPoint(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    invoker_invoke = function(self, hTarget, hAbility)
        print_debug(self.bot, "decision-invoke")
        local orbs = {}
        for i = 0, 2 do
            if self.bot:GetAbilityByIndex(i):GetLevel() > 0 then
                table.insert(orbs, self.bot:GetAbilityByIndex(i))
            end
        end

        if #orbs == 0 then 
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        elseif self.invoker_orb_casts < 3 or RollPercentage(20) then
            self.invoker_orb_casts = self.invoker_orb_casts + 1
            OverthrowBot.Decision_CastTargetNone(self, hTarget, orbs[math.random(#orbs)])
        else
            self.invoker_orb_casts = 0
            OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        end
    end,

    item_ethereal_blade = function(self, hTarget, hAbility)
        local search = OverthrowBot.GetClosestUnits(self, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO)
        if #search > 0 then
            OverthrowBot.Decision_CastTargetEntity(self, hTarget, hAbility, hTarget)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    --[[
    troll_warlord_berserkers_rage = function(self, hTarget, hAbility)
        local ranged_axes = self.bot:FindAbilityByName("troll_warlord_whirling_axes_ranged")
        if ranged_axes and ranged_axes:GetLevel() > 0 and ranged_axes:GetCooldownTimeRemaining() <= 0 then
            print(ranged_axes:GetCooldownTimeRemaining())
            if hAbility:GetToggleState() == true then
                OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
            else
                OverthrowBot.Decision_CastTargetEntity(self, hTarget, ranged_axes, hTarget)
            end
        elseif hAbility:GetToggleState() == false then
            OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,
    ]]

    furion_teleportation = function(self, hTarget, hAbility)
        if hTarget:GetRangeToUnit(self.bot) > self.bot:Script_GetAttackRange() then
            OverthrowBot.Decision_CastTargetPoint(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    tinker_keen_teleport = function(self, hTarget, hAbility)
        if hAbility:GetLevel() < 3 then
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        else
            OverthrowBot.Decision_CastTargetPoint(self, hTarget, hAbility)
        end
    end,

    tinker_rearm = function(self, hTarget, hAbility)
        local abilities_on_cooldown = 0
        for i = 0, 5 do
            local ability = self.bot:GetAbilityByIndex(i)
            if ability and ability:GetCooldownTimeRemaining() > 0 then
                abilities_on_cooldown = abilities_on_cooldown + 1
            end
        end

        if RollPercentage(abilities_on_cooldown * 33) then
            OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    templar_assassin_trap = function(self, hTarget, hAbility)
        local counter = self.bot:FindModifierByName("modifier_templar_assassin_psionic_trap_counter")
        if counter and counter:GetStackCount() > 0 then
            OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        else
            OverthrowBot.Decision_AttackTarget(self, hTarget)
        end
    end,

    brewmaster_drunken_brawler = function(self, hTarget, hAbility)
        OverthrowBot.Decision_CastTargetNone(self, hTarget, hAbility)
        hAbility:StartCooldown(5)
    end
    
}

OverthrowBot.spell_cast_nearby = {
    slardar_slithereen_crush = "crush_radius",
    queenofpain_scream_of_pain = "area_of_effect",
    axe_berserkers_call = "radius",
    sandking_sand_storm = "sand_storm_radius",
    venomancer_poison_nova = "radius",
    pangolier_shield_crash = "jump_horizontal_distance",
    item_shivas_guard = "blast_radius",
    ursa_earthshock = "hop_distance",
    tidehunter_ravage = "speed",
    razor_plasma_field = "radius",
    brewmaster_thunder_clap = "radius",
    juggernaut_blade_fury = "blade_fury_radius",
    dark_willow_bedlam = "attack_radius",
    crystal_maiden_freezing_field = "radius",
    luna_eclipse = "radius",
    rattletrap_battery_assault = "radius",
    leshrac_diabolic_edict = "radius"
}

--
-- Filters
--
OverthrowBot.spell_filter_behavior = {
    DOTA_ABILITY_BEHAVIOR_PASSIVE,
    DOTA_ABILITY_BEHAVIOR_ATTACK,
}

OverthrowBot.spell_filter_direct = {
    -- Items
    ["item_radiance"] = true,
    ["item_branches"] = true,

    -- Misc
    ["generic_hidden"] = true,

    -- Elder Titan
    ["elder_titan_return_spirit"] = true,

    -- Hoodwink
    ["hoodwink_sharpshooter_release"] = true,

    -- Invoker
    ["invoker_quas"] = true,
    ["invoker_wex"] = true,
    ["invoker_exort"] = true,

    -- Keeper of the Light
    ["keeper_of_the_light_illuminate_end"] = true,

    -- Lone Druid
    ["lone_druid_spirit_bear_return"] = true,

    -- Mars
    ["mars_bulwark"] = true,

    -- Naga Siren
    ["naga_siren_song_of_the_siren_cancel"] = true,

    -- Pangolier
    ["pangolier_gyroshell_stop"] = true,

    -- Phantom Lancer
    ["phantom_lancer_phantom_edge"] = true,

    -- Phoenix
    ["phoenix_sun_ray_stop"] = true,
    ["phoenix_icarus_dive_stop"] = true,

    -- Primal Beast
    ["primal_beast_onslaught_release"] = true,
    
    -- Rubick
    ["rubick_empty1"] = true,
    ["rubick_empty2"] = true,
    ["rubick_hidden1"] = true,
    ["rubick_hidden2"] = true,
    ["rubick_hidden3"] = true,
    ["rubick_telekinesis_land"] = true,

    -- Shadow Demon
    ["shadow_demon_shadow_poison_release"] = true,

    -- Spectre
    ["spectre_reality"] = true,

    -- Tusk
    ["tusk_launch_snowball"] = true,

    -- Underlord
    ["abyssal_underlord_cancel_dark_rift"] = true,

    -- Visage
    ["visage_summon_familiars_stone_form"] = true,

    -- Wisp
    ["wisp_spirits_in"] = true,
    ["wisp_spirits_out"] = true,
    ["wisp_tether_break"] = true,
}

OverthrowBot.cannot_self_target = {
    -- Spells
    ["abaddon_death_coil"] = true,
    ["earth_spirit_boulder_smash"] = true,
    ["necrolyte_death_seeker"] = true,
    ["earth_spirit_geomagnetic_grip"] = true,
    ["wisp_tether"] = true,

    -- Items
    ["item_medallion_of_courage"] = true,
    ["item_solar_crest"] = true,
    ["item_sphere"] = true,
    ["item_shadow_amulet"] = true,
}

--
-- Search Functions
--
function OverthrowBot:CanSeeEnemies()
    print_debug(self.bot, "canseeenemies")
    local search = FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        FIND_UNITS_EVERYWHERE, 
        DOTA_UNIT_TARGET_TEAM_ENEMY, 
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, 
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS, 
        FIND_CLOSEST, false)

    return #search > 0 and search or false 
end

function OverthrowBot:GetClosestUnit(notSelfTarget, hAbility)
    print_debug(self.bot, "getclosestunit")
    local search_radius = (hAbility:GetAbilityTargetType() == DOTA_UNIT_TARGET_CREEP or hAbility:GetAbilityTargetType() == DOTA_UNIT_TARGET_BASIC) and (hAbility:GetCastRange(nil, nil) + self.bot:GetCastRangeBonus()) or FIND_UNITS_EVERYWHERE
    local search = OverthrowBot.GetClosestUnits(self, search_radius, hAbility:GetAbilityTargetTeam(), hAbility:GetAbilityTargetType())

    if notSelfTarget then
        if #search > 1 then
            return {search[2]}
        else
            return {}
        end
    end

    return #search > 0 and search or {} 
end

function OverthrowBot:GetClosestUnits(search_radius, flags_team, flags_type)
    print_debug(self.bot, "getclosestunitS")
    return FindUnitsInRadius(
        self.bot:GetTeam(), 
        self.bot:GetAbsOrigin(), 
        nil, 
        search_radius, 
        flags_team,
        flags_type, 
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 
        FIND_CLOSEST, false)
end

--
-- Hero Progression
--
OverthrowBot.levellable_basic_exceptions = {
    nevermore_necromastery = true,
    nevermore_dark_lord = true,
}
OverthrowBot.attribute_levels = {
    [17] = true,
    [19] = true,
    [21] = true,
    [22] = true,
    [23] = true,
    [24] = true,
    [26] = true
}

function OverthrowBot:SpendAbilityPoints()
    print_debug(self.bot, "spendabilitypoints")
    local basic = {self.bot:GetAbilityByIndex(0), self.bot:GetAbilityByIndex(1), self.bot:GetAbilityByIndex(2)}
    local ultimate = self.bot:GetAbilityByIndex(5)
    local level = self.bot:GetLevel()

    for i = 3,4 do
        local ability = self.bot:GetAbilityByIndex(i)
        if ability then
            local ability_name = ability:GetAbilityName()
            if ability_name ~= "generic_hidden" and OverthrowBot.levellable_basic_exceptions[ability_name] then
                table.insert(basic, self.bot:GetAbilityByIndex(i))
            end
        end
    end

    -- Upgrade Ultimate
    if level % 6 == 0 and ultimate:GetLevel() < ultimate:GetMaxLevel() and self.bot:GetAbilityPoints() > 0 then
        self.bot:UpgradeAbility(ultimate)
    end

    -- Upgrade Talent
    if self.talentlevel < 4 and level >= (2 + self.talentlevel) * 5 then
        local talent_bar = self.talentlevel + 2
        local talents = {self.bot:GetAbilityByIndex(2 + 2 * talent_bar), self.bot:GetAbilityByIndex(3 + 2 * talent_bar)}
        self.bot:SetAbilityPoints(1)
        self.bot:UpgradeAbility(talents[math.random(2)])

        self.talentlevel = self.talentlevel + 1
    elseif self.talentlevel >= 4 and self.talentlevel < 8 and level >= (23 + self.talentlevel) then
        local talent_bar = self.talentlevel - 2
        local talents = {self.bot:GetAbilityByIndex(2 + 2 * talent_bar), self.bot:GetAbilityByIndex(3 + 2 * talent_bar)}
        self.bot:SetAbilityPoints(1)
        self.bot:UpgradeAbility(talents[1]:GetLevel() == 0 and talents[1] or talents[2])

        self.talentlevel = self.talentlevel + 1
    end
    

    -- Upgrade Ability
    table.shuffle(basic)

    for i = 1, #basic do
        local basic_chosen = basic[i]
        if basic_chosen:GetLevel() * 2 < level and basic_chosen:GetLevel() < basic_chosen:GetMaxLevel() and self.bot:GetAbilityPoints() > 0 then -- Prevents level 1 abilites from getting levelled up at level 2 and etc.
            self.bot:UpgradeAbility(basic_chosen)

            -- Turn on the attacks!
            if HasBit(basic_chosen:GetBehavior(), DOTA_ABILITY_BEHAVIOR_ATTACK) and basic_chosen:GetAutoCastState() == false then
                basic_chosen:ToggleAutoCast()
            end
        end
    end

    -- Upgrade stats
    local special_bonus_attributes = self.bot:FindAbilityByName("special_bonus_attributes")
    if OverthrowBot.attribute_levels[level] and special_bonus_attributes and not special_bonus_attributes:IsNull() and special_bonus_attributes:GetLevel() < special_bonus_attributes:GetMaxLevel() then
        self.bot:SetAbilityPoints(1)
        self.bot:UpgradeAbility(special_bonus_attributes)
    end
end

function OverthrowBot:ShopForItems()
    print_debug(self.bot, "shopforitems")
    if not self.item_progression or #self.item_progression == 0 then return end

    local target_item = self.item_progression[1]

    if OverthrowBot:ItemName_GetGoldCost(target_item) <= self.bot:GetGold() then
        self.bot:AddItemByName(target_item)
        self.bot:SpendGold(OverthrowBot:ItemName_GetGoldCost(target_item), DOTA_ModifyGold_PurchaseItem)
        table.remove(self.item_progression, 1)
    end
end

function OverthrowBot:CreateItemProgression()
    print_debug(self.bot, "createitemprogression")
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
        "item_revenants_brooch",

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
        "item_eternal_shroud",
        "item_bloodstone",

        -- Magical
        "item_gungir",
        "item_octarine_core",
        "item_wind_waker",
        "item_refresher",
        "item_solar_crest",
        --"item_necronomicon_3",
        "item_dagon_5",

        -- Support
        "item_guardian_greaves",
        "item_pipe",
        "item_wraith_pact",
        "item_spirit_vessel",
        "item_boots_of_bearing",

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

    self.item_progression = OverthrowBot:GetAllBuildComponents(full_slots)
end


--
-- Bot Modifier Listeners
--
OverthrowBot.team_hash = {
    [DOTA_TEAM_GOODGUYS] = "radiant",
    [DOTA_TEAM_BADGUYS] = "dire",
    [DOTA_TEAM_CUSTOM_1] = "custom1",
    [DOTA_TEAM_CUSTOM_2] = "custom2",
    [DOTA_TEAM_CUSTOM_3] = "custom3",
    [DOTA_TEAM_CUSTOM_4] = "custom4",
    [DOTA_TEAM_CUSTOM_5] = "custom5",
    [DOTA_TEAM_CUSTOM_6] = "custom6",
    [DOTA_TEAM_CUSTOM_7] = "custom7",
    [DOTA_TEAM_CUSTOM_8] = "custom8",
}

function OverthrowBot:CreateBotName()
    local name = ""
    for _ = 1, 6 do
        name = name..math.random(0, 9)
    end
    return name
end

function OverthrowBot:CreateBots()
    local all_heroes = LoadKeyValues("scripts/npc/herolist.txt")
    local bot_choices = {}
    for hero_name, allowed in pairs(all_heroes) do
        if not _G.player_chosen_heroes[hero_name] and allowed ~= 0 then
            table.insert(bot_choices, hero_name)
        end
    end

    for selected_team = DOTA_TEAM_FIRST, DOTA_TEAM_CUSTOM_MAX do
        if OverthrowBot.team_hash[selected_team] then
            print("team "..selected_team, "human count: "..PlayerResource:GetPlayerCountForTeam(selected_team), "required bot count: "..GameRules:GetCustomGameTeamMaxPlayers(selected_team) - PlayerResource:GetPlayerCountForTeam(selected_team))
            for _ = 1, GameRules:GetCustomGameTeamMaxPlayers(selected_team) - PlayerResource:GetPlayerCountForTeam(selected_team) do
                local choice_index = math.random(#bot_choices)
                local new_hero_name = bot_choices[choice_index]
                table.remove(bot_choices, choice_index)
                
                PrecacheUnitByNameAsync(new_hero_name, function()
                    GameRules:AddBotPlayerWithEntityScript(new_hero_name, OverthrowBot:CreateBotName(), selected_team, "", false)
                end)
            end
        end
    end
end

ListenToGameEvent("game_rules_state_change", function()
    if BUTTINGS and BUTTINGS.USE_BOTS == 0 then return end
    local state = GameRules:State_Get()
	
    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
		OverthrowBot:InitialiseRandom()

		-- Added delay to get the bots in
		GameRules:SetStrategyTime( 10.0 )
	end

	if state == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		-- Filters out what bots can actually play based on the players' hero choices
		if IsServer() then
			_G.player_chosen_heroes = {}
			for ID = 1, PlayerResource:GetPlayerCount() do
				-- If the player is actually real
				local playerID = ID - 1
				if not PlayerResource:IsFakeClient(playerID) then
					_G.player_chosen_heroes[PlayerResource:GetSelectedHeroName(playerID)] = true
				end
			end
            
            OverthrowBot:CreateBots()
		end
	end

	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- Adds the bot ai to the bots
		if IsServer() then
            
            OverthrowBot.unit_spawn_ai_enabled = true
            
		end
	end
end, nil)

OverthrowBot.unit_ai_filter = {
    ["npc_dota_courier"] = true,
}

function OverthrowBot:RelocateBotToSpawn(hero)
    for _, spawn_point in pairs(Entities:FindAllByClassname("info_player_start_dota")) do
        if spawn_point:GetTeam() == hero:GetTeam() then
            FindClearSpaceForUnit(hero, spawn_point:GetAbsOrigin(), true)
            return
        end
    end
end

ListenToGameEvent("npc_spawned", function(keys)
	local unit = keys.entindex and EntIndexToHScript(keys.entindex)

	if unit then
        if unit:GetPlayerOwnerID() > -1 and PlayerResource:IsFakeClient(unit:GetPlayerOwnerID()) and unit:GetTeamNumber() ~= DOTA_TEAM_NEUTRALS then
            if unit:IsRealHero() and not (unit:IsIllusion() or unit:IsSummoned()) then
                if not unit:HasModifier("modifier_bot") then unit:AddNewModifier(unit, nil, "modifier_bot", {}) end
                if not OverthrowBot.unit_spawn_ai_enabled then
                    OverthrowBot:RelocateBotToSpawn(unit)
                end
            else
                unit:AddNewModifier(unit, nil, "modifier_bot_simple", {})
            end
        end
	end

end, nil)