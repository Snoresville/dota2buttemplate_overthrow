modifier_bot_simple = modifier_bot_simple or class({})


function modifier_bot_simple:GetTexture() return "rattletrap_power_cogs" end -- get the icon from a different ability

function modifier_bot_simple:IsPermanent() return true end
function modifier_bot_simple:RemoveOnDeath() return false end
function modifier_bot_simple:IsHidden() return false end 	-- we can hide the modifier
function modifier_bot_simple:IsDebuff() return false end 	-- make it red or green
function modifier_bot_simple:AllowIllusionDuplicate() return true end

function modifier_bot_simple:GetAttributes()
	return 0
		+ MODIFIER_ATTRIBUTE_PERMANENT           -- Modifier passively remains until strictly removed. 
		-- + MODIFIER_ATTRIBUTE_MULTIPLE            -- Allows modifier to stack with itself. 
		-- + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE -- Allows modifier to be assigned to invulnerable entities. 
end

function modifier_bot_simple:OnCreated()
    if IsServer() then
        self.bot = self:GetParent()

        if self.bot:GetUnitName() == "npc_dota_lone_druid_bear4" then
            self:CreateItemProgression()
        end

        self:StartIntervalThink(0.25)
    end
end

function modifier_bot_simple:OnIntervalThink()
    OverthrowBot.OnIntervalThink(self)
    --[[
    if (not self.bot or self.bot:IsNull()) or not self.bot:IsAlive() then return end   -- If the bot is dead or missing
    if not self.bot:HasAttackCapability() then return end       -- If the bot can't attack

    -- Search before moving
    local search = self:CanSeeEnemies()                         

    if search then                                              -- Bot can see at least one enemy
        self:TargetDecision(search[1])
    elseif self.bot:HasMovementCapability() then                -- Default move to arena
        if self.bot:IsAttacking() then return end
        ExecuteOrderFromTable({
            UnitIndex = self.bot:entindex(),
            OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
            Position = Vector(0,0,0)
        })
    end
    ]]
end
