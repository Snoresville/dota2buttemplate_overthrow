BUTTINGS = {
	-- These will be the default settings shown on the Team Select screen.

	GAME_TITLE = WORKSHOP_TITLE,

	GAME_MODE = "AP",                   -- "AR" "AP" All Random/ All Pick
	ALLOW_SAME_HERO_SELECTION = 0,      -- 0 = everyone must pick a different hero, 1 = can pick same
	HERO_BANNING = 0,                   -- 0 = no banning, 1 = banning phase
	USE_BOTS = 1, 						-- Adds bots to the game
	MAX_LEVEL = MAX_LEVEL,              -- (default = 30) the max level a hero can reach

	UNIVERSAL_SHOP_MODE = 1,            -- 0 = normal, 1 = you can buy every item in every shop (secret/side/base).
	--ALWAYS_PASSIVE_GOLD = 0,			-- 0 = normal (always),  1 = when custom courier is dead passive gold is disabled;
	TEAM_COUNT_COMPENSATION	= 0,		-- Due to the gameplay of Overthrow, Gold and XP gains must be adjusted to match the usual gold and xp progression.
	COOLDOWN_PERCENTAGE = 100,          -- (default = 100) factor for all cooldowns
	GOLD_GAIN_PERCENTAGE = 100,         -- (default = 100) factor for gold income
	GOLD_PER_MINUTE = 95,               -- (default =  90) passive gold
	RESPAWN_TIME_PERCENTAGE = 10,      	-- (default = 100) factor for respawn time
	XP_GAIN_PERCENTAGE = 100,           -- (default = 100) factor for xp income

	TOMBSTONE = 0,                      -- 0 = normal, 1 = You spawn a tombstone when you die. Teammates can ressurect you by channeling it.
	MAGIC_RES_CAP = 0,                  -- 0 = normal, 1 = Keeps Magic Resistance <100%
	CLASSIC_ARMOR = 0,                  -- 0 = normal, 1 = Old armor formula (pre 7.20)
	                                    -- set this to 1, if your game mode will feature high amounts of armor or agility
	                                    -- otherwise the physical resistance can go to 100% making things immune to physical damage
	
	NO_UPHILL_MISS = 0,                 -- 0 = normal, 1 = 0% uphill muss chance
	OUTPOST_SHOP = 0,                   -- 0 = normal, 1 = jungle shops
	SIDE_SHOP = 0,                      -- 0 = normal, 1 = bring back sideshops
	--FREE_COURIER = 1,					-- 0 = vanilla couriers, 1 = custom couriers
	XP_PER_MINUTE = 0,                  -- (normal dota = 0) everyone gets passive experience (like the passive gold)
	COMEBACK_TIMER = 30,                -- timer (minutes) to start comeback XP / gold 
	COMEBACK_GPM = 60,                  -- passive gold for the poorest team
	COMEBACK_XPPM = 120,                -- passive experience for the lowest team
	SHARED_GOLD_PERCENTAGE = 0,         -- all gold (except passive) is shared with teammates
	SHARED_XP_PERCENTAGE = 0,           -- all experience (except passive) is shared with teammates

	TIME_UNTIL_AGH_SHARD = 1, 			-- Time until aghanim shard in minutes
	FREE_AGH_SHARD = 0, 				-- Whether the shard is free or not

	BONUS_COURIER_SPEED = 100,			-- % bonus movespeed for the courier
	COURIER_INVULNERABLE = 1,			-- Whether the courier can be killed or not

	ALT_WINNING = 0,                    -- 0 = normal, 1 = use these alternative winning conditions
	ALT_KILL_LIMIT = 30,               	-- Kills for alternative winnning
	ALT_TIME_LIMIT = 6,                	-- Timer for alternative winning
	OVERTIME_KILL_INCREASE = 1,
	NO_KILL_LIMIT = 0,

	BUYBACK_RULES = 1,                  -- 0 = normal, 1 = use buyback restrictions
	BUYBACK_LIMIT = 999,                -- Max amount of buybacks
	BUYBACK_COOLDOWN = 1,             	-- Cooldown for buyback
}

function BUTTINGS.ALTERNATIVE_XP_TABLE()	-- xp values if MAX_LEVEL is different than 30
	local ALTERNATIVE_XP_TABLE = {		
		0,
		230,
		600,
		1080,
		1660,
		2260,
		2980,
		3730,
		4510,
		5320,
		6160,
		7030,
		7930,
		9155,
		10405,
		11680,
		12980,
		14305,
		15805,
		17395,
		18995,
		20845,
		22945,
		25295,
		27895,
		31395,
		35895,
		41395,
		47895,
		55395,
	} for i = #ALTERNATIVE_XP_TABLE + 1, BUTTINGS.MAX_LEVEL do ALTERNATIVE_XP_TABLE[i] = ALTERNATIVE_XP_TABLE[i - 1] + (300 * ( i - 15 )) end
	return ALTERNATIVE_XP_TABLE
end

BUTTINGS.ALT_KILL_LIMIT = OVERTHROW_KILL_LIMITS[GetMapName()] or OVERTHROW_KILL_LIMITS["default"]

if IsInToolsMode() then 
	BUTTINGS.USE_BOTS = 1 
	BUTTINGS.ALT_KILL_LIMIT = 100
	BUTTINGS.ALT_TIME_LIMIT = 10
end

BUTTINGS_DEFAULT = table.copy(BUTTINGS)
