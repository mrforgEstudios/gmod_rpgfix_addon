AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local MODEL = "models/weapons/w_missile_launch.mdl"
local TRAIL_COLOR = Color(255, 255, 255, 230)
local GRAVITY = Vector(0, 0, -6000)
local DEFAULT_SPEED = 11000
local LIFE_TIME = 12
local DAMAGE = 180
local BLAST_RADIUS = 260
local CLEAR_LAUNCHER_TIME = 0.35
local INCOMING_SOUND_LEAD_TIME = 1.25
local SIM_STEP = 0.04
local HULL_MINS = Vector(-8, -8, -8)
local HULL_MAXS = Vector(8, 8, 8)

function ENT:Initialize()
    self:SetModel(MODEL)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_NONE)
    self:SetCollisionBounds(HULL_MINS, HULL_MAXS)
    self:SetHealth(1)

    self.SpawnTime = CurTime()
    self.DieTime = self.SpawnTime + LIFE_TIME
    self.InitialVelocity = self.InitialVelocity or self:GetForward() * DEFAULT_SPEED
    self.CurrentVelocity = self.InitialVelocity
    self.IncomingSoundPlayed = false
    self.PathIndex = 1

    self:BuildTrajectory()
    self:SetNWFloat("CounterBattery_ImpactTime", self.SpawnTime + self.ImpactTime)
    self:SetNWVector("CounterBattery_ImpactPos", self.ImpactPos)
    self:SetAngles(self.CurrentVelocity:Angle())

    util.SpriteTrail(self, 0, TRAIL_COLOR, false, 12, 2, 0.6, 1 / 12, "trails/smoke.vmt")
end

function ENT:ShouldIgnoreTraceEntity(ent)
    if not IsValid(ent) then return false end
    if ent == self then return true end
    if ent == self:GetOwner() then return true end
    if ent == self.Launcher then return true end

    if IsValid(self.Launcher) and ent:GetParent() == self.Launcher then
        return true
    end

    return false
end

function ENT:BuildTrajectory()
    local path = {}
    local pos = self:GetPos()
    local velocity = self.InitialVelocity
    local elapsed = 0
    local impactTime = LIFE_TIME
    local impactPos = pos

    path[#path + 1] = { time = 0, pos = pos, velocity = velocity }

    while elapsed < LIFE_TIME do
        local nextVelocity = velocity + GRAVITY * SIM_STEP
        local nextPos = pos + nextVelocity * SIM_STEP
        local nextElapsed = elapsed + SIM_STEP

        if nextElapsed >= CLEAR_LAUNCHER_TIME then
            local tr = util.TraceHull({
                start = pos,
                endpos = nextPos,
                mins = HULL_MINS,
                maxs = HULL_MAXS,
                filter = function(ent)
                    return not self:ShouldIgnoreTraceEntity(ent)
                end,
                mask = MASK_SHOT,
            })

            if tr.Hit then
                impactTime = nextElapsed
                impactPos = tr.HitPos
                path[#path + 1] = { time = impactTime, pos = impactPos, velocity = nextVelocity }
                break
            end
        end

        elapsed = nextElapsed
        pos = nextPos
        velocity = nextVelocity
        impactPos = pos
        path[#path + 1] = { time = elapsed, pos = pos, velocity = velocity }
    end

    self.TrajectoryPath = path
    self.ImpactTime = impactTime
    self.ImpactPos = impactPos
end

function ENT:GetVelocity()
    return self.CurrentVelocity or Vector(0, 0, 0)
end

function ENT:Think()
    if self.Exploded then return end

    local now = CurTime()
    local elapsed = now - self.SpawnTime

    if now >= self.DieTime or elapsed >= self.ImpactTime then
        self:SetPos(self.ImpactPos)
        self:Explode()
        return
    end

    local path = self.TrajectoryPath
    if not path or #path == 0 then
        self:Explode()
        return
    end

    while self.PathIndex < #path and path[self.PathIndex + 1].time <= elapsed do
        self.PathIndex = self.PathIndex + 1
    end

    local a = path[self.PathIndex]
    local b = path[math.min(self.PathIndex + 1, #path)]
    local segmentTime = math.max(b.time - a.time, 0.001)
    local t = math.Clamp((elapsed - a.time) / segmentTime, 0, 1)
    local pos = LerpVector(t, a.pos, b.pos)

    self.CurrentVelocity = LerpVector(t, a.velocity, b.velocity)
    self:SetLocalVelocity(self.CurrentVelocity)
    self:SetPos(pos)
    self:SetAngles(self.CurrentVelocity:Angle())

    if not self.IncomingSoundPlayed and self.ImpactTime - elapsed <= INCOMING_SOUND_LEAD_TIME then
        self.IncomingSoundPlayed = true
        sound.Play("weapons/mortar/mortar_shell_incomming1.wav", self.ImpactPos, 95, 100, 1)
    end

    self:NextThink(now)
    return true
end

function ENT:Touch()
end

function ENT:OnTakeDamage(dmgInfo)
    if self.Exploded then return end

    self:SetHealth(self:Health() - dmgInfo:GetDamage())

    if self:Health() <= 0 then
        self:Explode()
    end
end

function ENT:Explode()
    if self.Exploded then return end
    self.Exploded = true

    local pos = self:GetPos()
    local attacker = IsValid(self:GetOwner()) and self:GetOwner() or game.GetWorld()

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    effectdata:SetRadius(32)
    util.Effect("Explosion", effectdata)

    util.BlastDamage(game.GetWorld(), attacker, pos, BLAST_RADIUS, DAMAGE)
    self:Remove()
end
