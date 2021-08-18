BUTTINGS = BUTTINGS or {MAX_LEVEL = MAX_LEVEL}

require("internal/utils/butt_api")
LinkLuaModifier("modifier_courier_speed", "internal/modifier_courier_speed.lua", LUA_MODIFIER_MOTION_NONE)

ListenToGameEvent("game_rules_state_change", function()
	if (GameRules:State_Get()==DOTA_GAMERULES_STATE_HERO_SELECTION) then
		
		GameRules:SetSameHeroSelectionEnabled( 1 == BUTTINGS.ALLOW_SAME_HERO_SELECTION )
		GameRules:SetUseUniversalShopMode( 1 == BUTTINGS.UNIVERSAL_SHOP_MODE )
		GameRules:SetGoldTickTime( 60/BUTTINGS.GOLD_PER_MINUTE )

		GameRules:GetGameModeEntity():SetCustomXPRequiredToReachNextLevel( BUTTINGS.ALTERNATIVE_XP_TABLE() )
		GameRules:GetGameModeEntity():SetUseCustomHeroLevels(BUTTINGS.MAX_LEVEL~=25)
		GameRules:SetUseCustomHeroXPValues(BUTTINGS.MAX_LEVEL~=25)
		GameRules:GetGameModeEntity():SetCustomHeroMaxLevel(BUTTINGS.MAX_LEVEL)

		if ("AR"==BUTTINGS.GAME_MODE) then
			local time = ( 1 == BUTTINGS.HERO_BANNING ) and 16 or 0
			GameRules:GetGameModeEntity():SetThink( function()
				for p,player in pairs(PlayerList:GetValidTeamPlayers()) do
					player:MakeRandomHeroSelection()
				end
			end, time)
		end
		
		if ( 0 == BUTTINGS.HERO_BANNING ) then
			GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride( 0 )
		else
			GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride( 16 )
		end

		if ( 1 == BUTTINGS.SIDE_SHOP ) then
			for _,pos in pairs(Butt:OldSideshopLocations()) do
				Butt:CreateSideShop(pos)
			end
		end
		if ( 1 == BUTTINGS.OUTPOST_SHOP ) then
			for o,outpost in pairs(Butt:AllOutposts()) do
				Butt:CreateSideShop(outpost:GetAbsOrigin())
			end
		end
		GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)

		if BUTTINGS.SPECTATOR_MODE == 1 then
			GameRules:SetCustomGameTeamMaxPlayers( 1, 100 )
			--AddFOWViewer(1, Vector(0,0,0), 999999, 999999, false)
			--GameRules:GetGameModeEntity():SetCameraDistanceOverride( 1750 )
			for p=0,DOTA_MAX_PLAYERS do
				if (PlayerResource:IsValidPlayer(p)) and not (PlayerResource:IsFakeClient(p)) then
					PlayerResource:SetCustomTeamAssignment(p, 1)
				end
			end
		end
	end

	if (GameRules:State_Get()==DOTA_GAMERULES_STATE_STRATEGY_TIME) then
	end

	-- Remove the shard from the shop so I can re-add it with the timer later
	if (GameRules:State_Get()==DOTA_GAMERULES_STATE_PRE_GAME) then
		Timers:CreateTimer({
			endTime = FrameTime(),
			callback = function()
				for _,p in pairs(PlayerList:GetFirstPlayers()) do
					local pID = p:GetPlayerID()
					GameRules:SetItemStockCount( 0, PlayerResource:GetTeam( pID ), "item_aghanims_shard", pID )
				end
			end
		})
	end

	if (GameRules:State_Get()==DOTA_GAMERULES_STATE_GAME_IN_PROGRESS) then
		Timers:CreateTimer({
			endTime = BUTTINGS.TIME_UNTIL_AGH_SHARD*60,
			callback = function()
				if (0 == BUTTINGS.FREE_AGH_SHARD) then
					for _,p in pairs(PlayerList:GetFirstPlayers()) do
						local pID = p:GetPlayerID()

						GameRules:SetItemStockCount( 
							PlayerResource:GetPlayerCountForTeam(PlayerResource:GetTeam( pID )), 
							PlayerResource:GetTeam( pID ), 
							"item_aghanims_shard", 
							pID 
						)
					end
				else
					for _,p in pairs(PlayerList:GetValidTeamPlayers()) do
						local hero = PlayerResource:GetSelectedHeroEntity(p:GetPlayerID())
						hero:AddNewModifier(hero, nil, "modifier_item_aghanims_shard", {})
					end
				end
			end
		})
	end
end, nil)

ListenToGameEvent("npc_spawned", function(keys)
	local unit = keys.entindex and EntIndexToHScript(keys.entindex)

	if unit then
		if unit:GetClassname() == "npc_dota_watch_tower" then       --- BugFix by RoboBro
			Timers:CreateTimer(
				1, 
				function() unit:RemoveModifierByName("modifier_invulnerable") end
			)

		elseif unit:IsCourier() then 
			unit:AddNewModifier(unit, nil, "modifier_courier_speed", {})
		end
	end

end, nil)

ListenToGameEvent("dota_player_pick_hero", function(keys)
end, self)

ListenToGameEvent("dota_player_killed",function(kv)
	if (1==BUTTINGS.ALT_WINNING) then
		-- local unit = PlayerResource:GetSelectedHeroEntity(kv.PlayerID)
		for _,t in ipairs(TeamList:GetPlayableTeams()) do
			if (PlayerResource:GetTeamKills(t)>=BUTTINGS.ALT_KILL_LIMIT) then
				GameRules:SetGameWinner(t)
			end
		end
	end
end, nil)

ListenToGameEvent("entity_killed", function(keys)
	local killedUnit = EntIndexToHScript(keys.entindex_killed)
	if killedUnit:IsRealHero() and not killedUnit:IsTempestDouble() and not killedUnit:IsReincarnating() then

		-- tombstone
		if (1==BUTTINGS.TOMBSTONE) then
			local tombstoneItem = CreateItem("item_tombstone", killedUnit, killedUnit)
			if (tombstoneItem) then
				local tombstone = SpawnEntityFromTableSynchronous("dota_item_tombstone_drop", {})
				tombstone:SetContainedItem(tombstoneItem)
				tombstone:SetAngles(0, RandomFloat(0, 360), 0)
				FindClearSpaceForUnit(tombstone, killedUnit:GetAbsOrigin(), true)
			end
		end

	end
end, nil)
