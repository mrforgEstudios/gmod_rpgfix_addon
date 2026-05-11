AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local MODEL = "models/props_combine/combine_mortar01a.mdl"
local SHELL_SPEED = 11000
local GRAVITY = 6000
local FIRE_DELAY = 2.5
local LAUNCH_OFFSET = Vector(0, 0, 186)

local function GetSortedMortars()
    local mortars = ents.FindByClass("npc_combine_mortar")

    table.sort(mortars, function(a, b)
        return a:EntIndex() < b:EntIndex()
    end)

    return mortars
end

local function UpdateMortarIds()
    for index, mortar in ipairs(GetSortedMortars()) do
        if IsValid(mortar) then
            mortar:SetNWInt("CounterBattery_MortarID", index)
        end
    end
end

local function CalculateBallisticVelocity(startPos, targetPos, speed, gravity)
    local delta = targetPos - startPos
    local horizontal = Vector(delta.x, delta.y, 0)
    local distance = horizontal:Length()

    if distance <= 0 then return nil end

    local height = delta.z
    local speedSqr = speed * speed
    local discriminant = speedSqr * speedSqr - gravity * (gravity * distance * distance + 2 * height * speedSqr)

    if discriminant < 0 then return nil end

    local root = math.sqrt(discriminant)
    local tanTheta = (speedSqr + root) / (gravity * distance)
    local cosTheta = 1 / math.sqrt(1 + tanTheta * tanTheta)
    local sinTheta = tanTheta * cosTheta
    local dir = horizontal:GetNormalized()

    return dir * (speed * cosTheta) + Vector(0, 0, speed * sinTheta)
end

function ENT:Initialize()
    self:SetModel(MODEL)
    self:SetHealth(220)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:PhysicsInit(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    self.NextFireTime = 0

    timer.Simple(0, UpdateMortarIds)
end

function ENT:OnRemove()
    timer.Simple(0, UpdateMortarIds)
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

function ENT:FireAtPosition(targetPos, caller)
    if CurTime() < self.NextFireTime then return false end

    local startPos = self:GetPos() + self:GetUp() * LAUNCH_OFFSET.z
    local velocity = CalculateBallisticVelocity(startPos, targetPos, SHELL_SPEED, GRAVITY)
    if not velocity then return false end

    self.NextFireTime = CurTime() + FIRE_DELAY
    self:EmitSound("weapons/mortar/mortar_fire1.wav", 95, 100)

    local shell = ents.Create("cb_mortar_shell")
    if not IsValid(shell) then return false end

    shell.InitialVelocity = velocity
    shell.Launcher = self
    shell:SetPos(startPos)
    shell:SetAngles(velocity:Angle())
    shell:SetOwner(IsValid(caller) and caller or self)
    shell:Spawn()
    shell:Activate()

    return shell
end
