SWEP.Base = "weapon_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.PrintName = "Standart issue counter battery device"
SWEP.Author = "rpgfix"
SWEP.Category = "Counter Battery"
SWEP.Instructions = "Aim at an incoming missile and fire."

SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 1.4

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.HoldType = "rpg"

if CLIENT then
    local lang = GetConVar("gmod_language")

    if lang and string.StartWith(string.lower(lang:GetString()), "ru") then
        SWEP.PrintName = "Устройство противобатарейной борьбы патруля"
    end
end

local PLAYER_TARGET_CLASSES = {
    ["rpg_missile"] = true,
    ["apc_missile"] = true,
    ["npc_manhack"] = true,
    ["npc_cscanner"] = true,
    ["npc_clawscanner"] = true,
    ["npc_combinegunship"] = true,
    ["npc_helicopter"] = true,
    ["cb_mortar_shell"] = true,
}

local LOCK_CONE_DEGREES = 12
local LOCK_DOT = math.cos(math.rad(LOCK_CONE_DEGREES))
local LOCK_RANGE = 12000

function SWEP:GetLockedTarget()
    return self:GetNWEntity("CounterBattery_LockedTarget")
end

function SWEP:SetLockedTarget(target)
    self:SetNWEntity("CounterBattery_LockedTarget", target)
end

function SWEP:GetActiveInterceptor()
    return self:GetNWEntity("CounterBattery_ActiveInterceptor")
end

function SWEP:SetActiveInterceptor(interceptor)
    self:SetNWEntity("CounterBattery_ActiveInterceptor", interceptor)
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:GetPrintName()
    if CLIENT then
        local lang = GetConVar("gmod_language")

        if lang and string.StartWith(string.lower(lang:GetString()), "ru") then
            return "Устройство противобатарейной борьбы патруля"
        end
    end

    return self.PrintName
end

local function IsShootableMissile(ent)
    return IsValid(ent) and PLAYER_TARGET_CLASSES[ent:GetClass()] == true
end

local function FindTargetInCone(origin, aimDir, owner)
    local bestTarget
    local bestDot = LOCK_DOT

    for className in pairs(PLAYER_TARGET_CLASSES) do
        for _, missile in ipairs(ents.FindByClass(className)) do
            if IsValid(missile) then
                local offset = missile:WorldSpaceCenter() - origin
                local distance = offset:Length()

                if distance <= LOCK_RANGE and distance > 0 then
                    local dot = aimDir:Dot(offset / distance)

                    if dot >= bestDot then
                        local tr = util.TraceLine({
                            start = origin,
                            endpos = missile:WorldSpaceCenter(),
                            filter = owner,
                            mask = MASK_SHOT,
                        })

                        if not tr.Hit or tr.Entity == missile then
                            bestTarget = missile
                            bestDot = dot
                        end
                    end
                end
            end
        end
    end

    return bestTarget
end

function SWEP:Think()
    if not SERVER then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    self:SetLockedTarget(FindTargetInCone(owner:EyePos(), owner:EyeAngles():Forward(), owner))
end

function SWEP:CanPrimaryAttack()
    return CurTime() >= (self.NextCounterBatteryFire or 0)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self.NextCounterBatteryFire = CurTime() + self.Primary.Delay
    self:SetNextPrimaryFire(self.NextCounterBatteryFire)

    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local target = self:GetLockedTarget()
    if not IsShootableMissile(target) then
        target = FindTargetInCone(owner:EyePos(), owner:EyeAngles():Forward(), owner)
    end

    if not IsShootableMissile(target) then
        self:EmitSound("Weapon_AR2.Empty")
        return
    end

    self:EmitSound("Weapon_RPG.Single")
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)

    local startPos = owner:EyePos() + owner:EyeAngles():Forward() * 36 - owner:EyeAngles():Up() * 6
    local missile = ents.Create("cb_counter_missile")
    if not IsValid(missile) then return end

    missile:SetPos(startPos)
    missile:SetAngles((target:WorldSpaceCenter() - startPos):Angle())
    missile:SetOwner(owner)
    missile:SetTarget(target)
    missile:Spawn()
    missile:Activate()

    self:SetActiveInterceptor(missile)
end

function SWEP:SecondaryAttack()
end
