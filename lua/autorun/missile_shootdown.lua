-- missile_shootdown.lua
-- Lets bullets shoot down RPG/APC missiles.

if not SERVER then return end

AddCSLuaFile("autorun/client/missile_shootdown_cl.lua")
AddCSLuaFile("autorun/client/cl_debug.lua")

local SHOOTABLE_MISSILES = {
    ["rpg_missile"] = true,
    ["apc_missile"] = true,
    ["cb_mortar_shell"] = true,
}

local cv_enabled = CreateConVar("missile_shootdown_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Enable bullet missile shootdown.")

local cv_debug = CreateConVar("missile_shootdown_debug", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Enable missile shootdown debug drawing.")

local cv_hit_radius = CreateConVar("missile_shootdown_hit_radius", "32", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Fallback radius around bullet traces for missile shootdown.")

local cv_damage = CreateConVar("missile_shootdown_damage", "150", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Explosion damage when a missile is shot down.")

local cv_blast_radius = CreateConVar("missile_shootdown_blast_radius", "200", FCVAR_ARCHIVE + FCVAR_NOTIFY,
    "Explosion radius when a missile is shot down.")

util.AddNetworkString("MissileShootdown_Debug")

local function IsShootableMissile(ent)
    return IsValid(ent) and SHOOTABLE_MISSILES[ent:GetClass()] == true
end

local function DistPointToSegment(point, segA, segB)
    local ab = segB - segA
    local lenSq = ab:LengthSqr()

    if lenSq <= 0 then
        return segA, (point - segA):Length()
    end

    local t = math.Clamp((point - segA):Dot(ab) / lenSq, 0, 1)
    local closest = segA + ab * t

    return closest, (point - closest):Length()
end

local function SendDebugLine(startPos, endPos, color, duration)
    if not cv_debug:GetBool() then return end

    net.Start("MissileShootdown_Debug")
        net.WriteUInt(0, 2)
        net.WriteVector(startPos)
        net.WriteVector(endPos)
        net.WriteUInt(color.r, 8)
        net.WriteUInt(color.g, 8)
        net.WriteUInt(color.b, 8)
        net.WriteFloat(duration)
    net.Broadcast()
end

local function SendDebugSphere(pos, radius, color, duration)
    if not cv_debug:GetBool() then return end

    net.Start("MissileShootdown_Debug")
        net.WriteUInt(1, 2)
        net.WriteVector(pos)
        net.WriteFloat(radius)
        net.WriteUInt(color.r, 8)
        net.WriteUInt(color.g, 8)
        net.WriteUInt(color.b, 8)
        net.WriteFloat(duration)
    net.Broadcast()
end

local function BuildTraceFilter(shooter)
    local skip = {}

    if IsValid(shooter) then
        skip[shooter] = true

        if shooter.GetActiveWeapon then
            local weapon = shooter:GetActiveWeapon()
            if IsValid(weapon) then
                skip[weapon] = true
            end
        end
    end

    return function(ent)
        return not skip[ent]
    end
end

local function HasLineOfSight(startPos, endPos, missile, shooter)
    local tr = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = BuildTraceFilter(shooter),
        mask = MASK_SHOT,
    })

    return not tr.Hit or tr.Entity == missile
end

local function FindMissileNearSegment(startPos, endPos, shooter)
    local hitRadius = math.max(cv_hit_radius:GetFloat(), 0)
    if hitRadius <= 0 then return nil end

    local bestMissile
    local bestPoint
    local bestDist = hitRadius

    for className in pairs(SHOOTABLE_MISSILES) do
        for _, missile in ipairs(ents.FindByClass(className)) do
            if IsValid(missile) and not missile.MissileShootdown_Detonated then
                local closest, dist = DistPointToSegment(missile:GetPos(), startPos, endPos)

                if dist <= bestDist and HasLineOfSight(startPos, closest, missile, shooter) then
                    bestMissile = missile
                    bestPoint = closest
                    bestDist = dist
                end
            end
        end
    end

    return bestMissile, bestPoint, bestDist
end

local function DetonateMissile(missile, attacker, hitPos)
    if not IsShootableMissile(missile) or missile.MissileShootdown_Detonated then return end

    missile.MissileShootdown_Detonated = true

    local className = missile:GetClass()
    local pos = hitPos or missile:GetPos()
    local damage = math.max(cv_damage:GetFloat(), 0)
    local radius = math.max(cv_blast_radius:GetFloat(), 0)
    local owner = IsValid(attacker) and attacker or game.GetWorld()

    SendDebugSphere(pos, 10, Color(0, 120, 255), 0.5)

    local effectdata = EffectData()
    effectdata:SetOrigin(pos)
    effectdata:SetMagnitude(1)
    effectdata:SetScale(1)
    effectdata:SetRadius(16)
    util.Effect("Explosion", effectdata)

    missile:Remove()

    if radius > 0 and damage > 0 then
        util.BlastDamage(game.GetWorld(), owner, pos, radius, damage)
    end

    if radius > 0 then
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) then
                local phys = ent:GetPhysicsObject()

                if IsValid(phys) then
                    local distance = math.max(ent:GetPos():Distance(pos), 1)
                    local scale = math.Clamp(1 - distance / radius, 0, 1)
                    local direction = (ent:GetPos() - pos):GetNormalized()

                    phys:ApplyForceCenter(direction * 8000 * scale)
                end
            end
        end
    end

    print("[MissileShootdown] Missile shot down: " .. className)
end

hook.Add("EntityFireBullets", "MissileShootdown_BulletCallback", function(shooter, data)
    if not cv_enabled:GetBool() then return end

    local oldCallback = data.Callback

    data.Callback = function(attacker, trace, dmgInfo)
        local callbackResult

        if oldCallback then
            callbackResult = oldCallback(attacker, trace, dmgInfo)
        end

        if not cv_enabled:GetBool() or not trace then
            return callbackResult
        end

        local realAttacker = IsValid(attacker) and attacker or shooter
        local startPos = trace.StartPos or data.Src
        local endPos = trace.HitPos

        if not startPos or not endPos then
            return callbackResult
        end

        SendDebugLine(startPos, endPos, Color(255, 0, 0), 0.05)

        if IsShootableMissile(trace.Entity) then
            SendDebugLine(startPos, endPos, Color(0, 255, 0), 0.25)
            DetonateMissile(trace.Entity, realAttacker, trace.HitPos)
            return callbackResult
        end

        local missile, hitPos = FindMissileNearSegment(startPos, endPos, realAttacker)
        if IsShootableMissile(missile) then
            SendDebugLine(startPos, hitPos, Color(0, 255, 0), 0.25)
            SendDebugSphere(missile:GetPos(), cv_hit_radius:GetFloat(), Color(255, 200, 0), 0.25)
            DetonateMissile(missile, realAttacker, hitPos)
        end

        return callbackResult
    end

    return true
end)

print("[MissileShootdown] Loaded.")
print("[MissileShootdown] missile_shootdown_enabled 0/1")
print("[MissileShootdown] missile_shootdown_debug 0/1")
print("[MissileShootdown] missile_shootdown_hit_radius <units>")
