include("shared.lua")

local LOCK_CONE_DEGREES = 12
local INTERCEPTOR_SPEED = 6000

surface.CreateFont("CounterBattery_HudSmall", {
    font = "Roboto",
    size = 22,
    weight = 700,
    antialias = true,
})

local function GetImpactCountdown(weapon)
    local interceptor = weapon:GetActiveInterceptor()
    if not IsValid(interceptor) then return nil end

    local impactTime = interceptor.GetEstimatedImpactTime and interceptor:GetEstimatedImpactTime() or 0

    if impactTime > CurTime() then
        return math.max(impactTime - CurTime(), 0)
    end

    local target = interceptor.GetTarget and interceptor:GetTarget() or NULL
    if not IsValid(target) then return nil end

    return interceptor:GetPos():Distance(target:WorldSpaceCenter()) / INTERCEPTOR_SPEED
end

function SWEP:DrawHUD()
    local ply = LocalPlayer()
    local fov = IsValid(ply) and ply:GetFOV() or 90
    local focalLength = (ScrW() * 0.5) / math.tan(math.rad(fov * 0.5))
    local radius = math.max(42, math.tan(math.rad(LOCK_CONE_DEGREES)) * focalLength)
    local x = ScrW() * 0.5
    local y = ScrH() * 0.5
    local locked = IsValid(self:GetLockedTarget())
    local color = locked and Color(80, 220, 120, 210) or Color(255, 255, 255, 150)

    surface.SetDrawColor(color)
    surface.DrawCircle(x, y, radius, color)
    surface.DrawLine(x - 8, y, x + 8, y)
    surface.DrawLine(x, y - 8, x, y + 8)

    local countdown = GetImpactCountdown(self)

    if countdown then
        local text = string.format("T-%0.1f", countdown)

        draw.SimpleText(text, "CounterBattery_HudSmall", x, y + radius + 18,
            Color(80, 220, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
