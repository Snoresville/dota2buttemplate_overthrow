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
    if self:GetParent():HasModifier("modifier_monkey_king_fur_army_soldier") then self:Destroy() end
    if self:GetParent():HasModifier("modifier_monkey_king_fur_army_soldier_hidden") then self:Destroy() end
    if self:GetParent():HasModifier("modifier_monkey_king_fur_army_soldier_inactive") then self:Destroy() end

    if IsServer() then
        self.bot = self:GetParent()
        for ID = 1, PlayerResource:GetPlayerCount() do
            self.bot:SetControllableByPlayer(ID - 1, false)
        end
        
        OverthrowBot.CreateItemProgression(self)

        -- Default Values
        self.talentlevel = 0
        self.invoker_orb_casts = 0
        
        self:StartIntervalThink(0.2)
    end
end

function modifier_bot:OnIntervalThink()
    OverthrowBot.OnIntervalThink(self)
end