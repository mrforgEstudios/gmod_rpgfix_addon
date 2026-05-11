AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local VALID_TARGETS = {
    ["rpg_missile"] = true,
    ["apc_missile"] = true,
    ["npc_manhack"] = true,
    ["npc_cscanner"] = true,
    ["npc_clawscanner"] = true,
    ["npc_combinegunship"] = true,
    ["npc_helicopter"] = true,
    ["cb_mortar_shell"] = true,
}

local SPEED = 6000
local TURN_RATE = 14
local ARM_TIME = 0.08
local LIFE_TIME = 8
local HIT_RADIUS = 80
local MORTAR_HIT_RADIUS = 250
local VERTICAL_BOOST_TIME = 0.25
local VERTICAL_HOVER_TIME = 0.5
local TRAIL_COLOR = Color(80, 190, 255, 220)

local function IsValidTarget(ent)
    return IsValid(ent) and VALID_TARGETS[ent:GetClass()] == true
end

local function GetHitRadius(target)
    if IsValid(target) and target:GetClass() == "cb_mortar_shell" then
        return MORTAR_HIT_RADIUS
    end

    return HIT_RADIUS
end

function ENT:Initialize()
    self:SetModel("models/weapons/w_missile_launch.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionBounds(Vector(-8, -8, -8), Vector(8, 8, 8))
    self:SetHealth(1)

    self.SpawnTime = CurTime()
    self.DieTime = CurTime() + LIFE_TIME
    self.IsVerticalLaunch = self.CounterBatteryVerticalLaunch == true
    self.VerticalBoostEnd = CurTime() + VERTICAL_BOOST_TIME
    self.VerticalHoverEnd = self.VerticalBoostEnd + VERTICAL_HOVER_TIME
    self.Velocity = self.IsVerticalLaunch and Vector(0, 0, SPEED) or self:GetForward() * SPEED
    self:SetEstimatedImpactTime(0)

    util.SpriteTrail(self, 0, TRAIL_COLOR, false, 18, 3, 0.35, 1 / 18, "sprites/physbeama.vmt")
    self:EmitSound("weapons/rpg/rocketfire1.wav", 80, 115)
end

function ENT:ShouldIgnoreTraceEntity(ent)
    if not IsValid(ent) then return false end
    if ent == self then return true end
    if ent == self:GetOwner() then return true end

    local owner = self:GetOwner()
    if IsValid(owner) and ent:GetParent() == owner then
        return true
    end

    return false
end

function ENT:SteerTowardTarget(target, frameTime)
    local pos = self:GetPos()
    local targetPos = target:WorldSpaceCenter()
    local targetVel = target:GetVelocity()
    local distance = pos:Distance(targetPos)
    local leadTime = math.Clamp(distance / SPEED, 0, 1.2)
    local aimPos = targetPos + targetVel * leadTime
    local desired = (aimPos - pos):GetNormalized() * SPEED

    self.Velocity = LerpVector(math.Clamp(frameTime * TURN_RATE, 0, 1), self.Velocity, desired)
    self:SetAngles(self.Velocity:Angle())
end

function ENT:Think()
    if CurTime() >= self.DieTime then
        self:SelfDestruct()
        return
    end

    local target = self:GetTarget()
    if not IsValidTarget(target) then
        self:SelfDestruct()
        return
    end

    local frameTime = math.Clamp(FrameTime(), 0.001, 0.05)
    local distance = self:GetPos():Distance(target:WorldSpaceCenter())
    local startPos = self:GetPos()

    if self.IsVerticalLaunch and CurTime() < self.VerticalBoostEnd then
        self.Velocity = Vector(0, 0, SPEED)
        self:SetLocalVelocity(self.Velocity)
        self:SetAngles(Angle(-90, self:GetAngles().y, 0))
        self:SetEstimatedImpactTime(CurTime() + distance / SPEED + VERTICAL_HOVER_TIME)
        if not self:MoveWithTrace(startPos, startPos + self.Velocity * frameTime) then return end

        self:NextThink(CurTime())
        return true
    end

    if self.IsVerticalLaunch and CurTime() < self.VerticalHoverEnd then
        self.Velocity = Vector(0, 0, 0)
        self:SetLocalVelocity(self.Velocity)
        self:SetEstimatedImpactTime(CurTime() + distance / SPEED)
        self:NextThink(CurTime())
        return true
    end

    self.IsVerticalLaunch = false

    self:SteerTowardTarget(target, frameTime)
    self:SetLocalVelocity(self.Velocity)
    self:SetEstimatedImpactTime(CurTime() + distance / SPEED)

    if distance <= GetHitRadius(target) then
        self:Explode(target)
        return
    end

    local endPos = startPos + self.Velocity * frameTime
    if not self:MoveWithTrace(startPos, endPos) then return end

    self:NextThink(CurTime())
    return true
end

function ENT:MoveWithTrace(startPos, endPos)
    local tr = util.TraceHull({
        start = startPos,
        endpos = endPos,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        filter = function(ent)
            return not self:ShouldIgnoreTraceEntity(ent)
        end,
        mask = MASK_SHOT,
    })

    if tr.Hit and CurTime() <= self.SpawnTime + ARM_TIME then
        self:SetPos(endPos)
        return true
    end

    if tr.Hit and CurTime() > self.SpawnTime + ARM_TIME then
        self:SetPos(tr.HitPos)
        self:Explode(IsValidTarget(tr.Entity) and tr.Entity or nil)
        return false
    end

    self:SetPos(endPos)
    return true
end

function ENT:Touch()
end

function ENT:Explode(target)
    if self.Exploded then return end
    self.Exploded = true

    local pos = self:GetPos()

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    effectdata:SetRadius(16)
    util.Effect("Explosion", effectdata)

    if IsValidTarget(target) then
        local dmgInfo = DamageInfo()
        dmgInfo:SetDamage(500)
        dmgInfo:SetDamageType(DMG_BLAST)
        dmgInfo:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or game.GetWorld())
        dmgInfo:SetInflictor(self)
        dmgInfo:SetDamagePosition(pos)

        target:TakeDamageInfo(dmgInfo)

        if IsValid(target) and target:Health() <= 0 then
            target:Remove()
        elseif IsValid(target) and (target:GetClass() == "rpg_missile" or target:GetClass() == "apc_missile" or target:GetClass() == "cb_mortar_shell") then
            target:Remove()
        end
    else
        for className in pairs(VALID_TARGETS) do
            for _, missile in ipairs(ents.FindByClass(className)) do
                if IsValid(missile) and missile:WorldSpaceCenter():Distance(pos) <= HIT_RADIUS then
                    if missile:GetClass() == "rpg_missile" or missile:GetClass() == "apc_missile" or missile:GetClass() == "cb_mortar_shell" then
                        missile:Remove()
                    end
                end
            end
        end
    end

    self:Remove()
end

function ENT:SelfDestruct()
    if self.Exploded then return end
    self.Exploded = true

    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(0.5)
    util.Effect("cball_explode", effectdata)

    self:Remove()
end
