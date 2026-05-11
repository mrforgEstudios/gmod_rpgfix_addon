SWEP.Base = "weapon_base"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.PrintName = "Combine mortar designator"
SWEP.Author = "rpgfix"
SWEP.Category = "Counter Battery"
SWEP.Instructions = "Aim at the ground and fire to order the nearest Combine mortar."

SWEP.ViewModel = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.HoldType = "slam"

local COMMAND_RANGE = 16000
local SALVO_INTERVAL = 0.5

function SWEP:GetActiveShell()
    return self:GetNWEntity("CounterBattery_ActiveMortarShell")
end

function SWEP:SetActiveShell(shell)
    self:SetNWEntity("CounterBattery_ActiveMortarShell", shell)
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:CanPrimaryAttack()
    return CurTime() >= (self.NextMortarCommand or 0)
end

local function FindNearestMortar(pos)
    local bestMortar
    local bestDist = COMMAND_RANGE * COMMAND_RANGE

    for _, mortar in ipairs(ents.FindByClass("npc_combine_mortar")) do
        if IsValid(mortar) then
            local dist = pos:DistToSqr(mortar:GetPos())

            if dist <= bestDist then
                bestMortar = mortar
                bestDist = dist
            end
        end
    end

    return bestMortar
end

local function GetSortedMortars()
    local mortars = {}

    for _, mortar in ipairs(ents.FindByClass("npc_combine_mortar")) do
        if IsValid(mortar) then
            mortars[#mortars + 1] = mortar
        end
    end

    table.sort(mortars, function(a, b)
        local idA = a:GetNWInt("CounterBattery_MortarID", a:EntIndex())
        local idB = b:GetNWInt("CounterBattery_MortarID", b:EntIndex())

        if idA == idB then
            return a:EntIndex() < b:EntIndex()
        end

        return idA < idB
    end)

    return mortars
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self.NextMortarCommand = CurTime() + self.Primary.Delay
    self:SetNextPrimaryFire(self.NextMortarCommand)
    self:SetNextSecondaryFire(self.NextMortarCommand)

    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = owner:GetEyeTrace()
    if not tr.Hit then return end

    local mortar = FindNearestMortar(owner:GetPos())
    if not IsValid(mortar) or not mortar.FireAtPosition then
        self:EmitSound("Weapon_AR2.Empty")
        return
    end

    local shell = mortar:FireAtPosition(tr.HitPos, owner)

    if IsValid(shell) then
        self:SetActiveShell(shell)
        self:EmitSound("buttons/button14.wav")
        self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
        owner:SetAnimation(PLAYER_ATTACK1)
    else
        self:EmitSound("Weapon_AR2.Empty")
    end
end

function SWEP:SecondaryAttack()
    if not self:CanPrimaryAttack() then return end

    self.NextMortarCommand = CurTime() + self.Primary.Delay
    self:SetNextSecondaryFire(self.NextMortarCommand)
    self:SetNextPrimaryFire(self.NextMortarCommand)

    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = owner:GetEyeTrace()
    if not tr.Hit then return end

    local mortars = GetSortedMortars()
    if #mortars == 0 then
        self:EmitSound("Weapon_AR2.Empty")
        return
    end

    local salvoDuration = (#mortars - 1) * SALVO_INTERVAL + self.Primary.Delay
    self.NextMortarCommand = CurTime() + salvoDuration
    self:SetNextSecondaryFire(self.NextMortarCommand)
    self:SetNextPrimaryFire(self.NextMortarCommand)

    local targetPos = tr.HitPos

    for index, mortar in ipairs(mortars) do
        timer.Simple((index - 1) * SALVO_INTERVAL, function()
            if not IsValid(self) or not IsValid(owner) or not IsValid(mortar) then return end
            if not mortar.FireAtPosition then return end

            local shell = mortar:FireAtPosition(targetPos, owner)

            if IsValid(shell) then
                self:SetActiveShell(shell)
            end
        end)
    end

    self:EmitSound("buttons/button14.wav")
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
end
