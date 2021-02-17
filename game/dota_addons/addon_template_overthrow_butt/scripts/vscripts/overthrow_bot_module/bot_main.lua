LinkLuaModifier("modifier_bot", "overthrow_bot_module/bot_hero.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bot_simple", "overthrow_bot_module/bot_unit.lua", LUA_MODIFIER_MOTION_NONE)

if OverthrowBot == nil then
	_G.OverthrowBot = class({})
	OverthrowBot.item_kv = LoadKeyValues("scripts/npc/items.txt")
	OverthrowBot.ability_kv = LoadKeyValues("scripts/npc/npc_abilities.txt")
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
			subcomponents[i] = string_split(subcomponents[i], "*")[1]
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

function OverthrowBot:CanCastOnSpellImmune(hAbility)
	if not hAbility then return false end

	local spell_immunity_type
	if hAbility:IsItem() then
		spell_immunity_type = OverthrowBot.item_kv[hAbility:GetAbilityName()]["SpellImmunityType"]
	else
		spell_immunity_type = OverthrowBot.ability_kv[hAbility:GetAbilityName()]["SpellImmunityType"]
	end

	if not spell_immunity_type or spell_immunity_type == "SPELL_IMMUNITY_ENEMIES_NO" then return false end

	return true
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
			SendToConsole("dota_bot_populate")
		end
	end

	if state == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- Adds the bot ai to the bots
		if IsServer() then
			local all_heroes = LoadKeyValues("scripts/npc/herolist.txt")
			local bot_choices = {}
			for hero_name, allowed in pairs(all_heroes) do
				if not _G.player_chosen_heroes[hero_name] and allowed ~= 0 then
					table.insert(bot_choices, hero_name)
				end
			end
			for ID = 1, PlayerResource:GetPlayerCount() do
				-- If the player is actually a bot
				local playerID = ID - 1
				if PlayerResource:IsFakeClient(playerID) then
					local choice_index = math.random(#bot_choices)
					local new_hero_name = bot_choices[choice_index]
					table.remove(bot_choices, choice_index)
					Timers:CreateTimer(
						0.1, function() 
							if not PlayerResource:GetSelectedHeroEntity(playerID) then return 0.1 end
							local new_hero = PlayerResource:ReplaceHeroWith(playerID, new_hero_name, PlayerResource:GetGold(playerID), 0)
							new_hero:AddNewModifier(new_hero, nil, "modifier_bot", {})
							PrecacheUnitByNameAsync(new_hero_name, function(...) end)
						end
					)
				end
			end
		end
	end
end, nil)