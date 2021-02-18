modifier_bot = modifier_bot or class({})


function modifier_bot:GetTexture() return "tinker_rearm" end -- get the icon from a different ability

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
        for ID = 1, PlayerResource:GetPlayerCount() do
            self.bot:SetControllableByPlayer(ID - 1, false)
        end
        
        self:CreateItemProgression()

        -- Default Values
        self.talentlevel = 0
        self.invoker_orb_casts = 0
        
        self:StartIntervalThink(0.2)
    end
end

function modifier_bot:OnIntervalThink()
    if not self.bot or not self.bot:IsAlive() then return end   -- If the bot is dead or missing

    -- Bot improvement
    self:ShopForItems()
    if self.bot:GetAbilityPoints() > 0 then self:SpendAbilityPoints() end

    -- Cannot be ordered
    if self.bot:IsChanneling() then return end                  -- MMM Let's not interrupt this bot's concentration
    if self.bot:IsCommandRestricted() then return end           -- Can't really do anything now huh

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