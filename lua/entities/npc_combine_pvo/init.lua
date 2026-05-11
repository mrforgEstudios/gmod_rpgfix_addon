AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local SHOOTABLE_MISSILES = {
    ["rpg_missile"] = true,
    ["apc_missile"] = true,
    ["cb_mortar_shell"] = true,
}

local MODEL = "models/props_combine/combine_mortar01a.mdl"
local SCAN_RADIUS = 9000
local MORTAR_SCAN_RADIUS = 22000
local SCAN_INTERVAL = 0.03
local FIRE_DELAY = 1.2
local LAUNCH_OFFSET = Vector(0, 0, 86)

local function IsShootableMissile(ent)
    return IsValid(ent) and SHOOTABLE_MISSILES[ent:GetClass()] == true
end

local function MissileHasActiveInterceptor(missile)
    return IsValid(missile.CounterBatteryInterceptor)
end

function ENT:Initialize()
    self:SetModel(MODEL)
    self:SetHealth(180)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self.NextFireTime = 0
    self.NextScanTime = 0
end

function ENT:OnInjured(dmgInfo)
    self:SetHealth(self:Health() - dmgInfo:GetDamage())

    if self:Health() <= 0 then
        local effectdata = EffectData()
        effectdata:SetOrigin(self:WorldSpaceCenter())
        effectdata:SetMagnitude(1)
        effectdata:SetScale(1)
        effectdata:SetRadius(32)
        util.Effect("Explosion", effectdata)

        self:Remove()
    end
end

function ENT:FindMissileTarget()
    local pos = self:WorldSpaceCenter()
    local bestTarget
    local bestDist = math.huge
    local bestPriority = -1

    for className in pairs(SHOOTABLE_MISSILES) do
        local scanRadius = className == "cb_mortar_shell" and MORTAR_SCAN_RADIUS or SCAN_RADIUS
        local priority = className == "cb_mortar_shell" and 2 or 1

        for _, missile in ipairs(ents.FindByClass(className)) do
            if IsValid(missile) and not MissileHasActiveInterceptor(missile) then
                local dist = pos:DistToSqr(missile:WorldSpaceCenter())

                if dist <= scanRadius * scanRadius and (priority > bestPriority or (priority == bestPriority and dist < bestDist)) then
                    bestTarget = missile
                    bestDist = dist
                    bestPriority = priority
                end
            end
        end
    end

    return bestTarget
end

function ENT:FireAtMissile(target)
    if CurTime() < self.NextFireTime or not IsShootableMissile(target) then return end
    if MissileHasActiveInterceptor(target) then return end

    self.NextFireTime = CurTime() + FIRE_DELAY
    self:EmitSound("weapons/mortar/mortar_fire1.wav", 90, 120)

    local startPos = self:GetPos() + self:GetUp() * LAUNCH_OFFSET.z
    local missile = ents.Create("cb_counter_missile")
    if not IsValid(missile) then return end

    missile.CounterBatteryVerticalLaunch = true
    missile:SetPos(startPos)
    missile:SetAngles(Angle(-90, self:GetAngles().y, 0))
    missile:SetOwner(self)
    missile:SetTarget(target)
    missile:Spawn()
    missile:Activate()

    target.CounterBatteryInterceptor = missile

    missile:CallOnRemove("CounterBattery_ClearTarget_" .. missile:EntIndex(), function(removedMissile, missileTarget)
        if IsValid(missileTarget) and missileTarget.CounterBatteryInterceptor == removedMissile then
            missileTarget.CounterBatteryInterceptor = nil
        end
    end, target)
end

function ENT:Think()
    if CurTime() < self.NextScanTime then
        self:NextThink(CurTime() + SCAN_INTERVAL)
        return true
    end

    self.NextScanTime = CurTime() + SCAN_INTERVAL

    local target = self:FindMissileTarget()
    if IsShootableMissile(target) then
        self:FireAtMissile(target)
    end

    self:NextThink(CurTime() + SCAN_INTERVAL)
    return true
end
