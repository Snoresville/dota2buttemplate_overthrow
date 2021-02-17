LinkLuaModifier("modifier_bot", "internal/modifier_bot.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_bot_simple", "internal/modifier_bot_simple.lua", LUA_MODIFIER_MOTION_NONE)

ListenToGameEvent("game_rules_state_change", function()
    if BUTTINGS.USE_BOTS == 0 then return end
    local state = GameRules:State_Get()
	
    if state == DOTA_GAMERULES_STATE_HERO_SELECTION then
		-- Added delay to get the bots in
		if 1 == BUTTINGS.USE_BOTS then
			GameRules:SetStrategyTime( 10.0 )
		end
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