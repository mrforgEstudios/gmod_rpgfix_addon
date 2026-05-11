include("shared.lua")

surface.CreateFont("CounterBattery_MortarHudSmall", {
    font = "Roboto",
    size = 22,
    weight = 700,
    antialias = true,
})

local function GetImpactCountdown(weapon)
    local shell = weapon:GetActiveShell()
    if not IsValid(shell) then return nil end

    local impactTime = shell:GetNWFloat("CounterBattery_ImpactTime", 0)
    if impactTime <= 0 then return nil end

    return math.max(impactTime - CurTime(), 0)
end

function SWEP:DrawHUD()
    local owner = LocalPlayer()
    if not IsValid(owner) then return end

    local tr = owner:GetEyeTrace()
    local x = ScrW() * 0.5
    local y = ScrH() * 0.5
    local color = tr.Hit and Color(255, 255, 255, 210) or Color(255, 80, 80, 180)

    surface.SetDrawColor(color)
    surface.DrawLine(x - 10, y, x + 10, y)
    surface.DrawLine(x, y - 10, x, y + 10)
    surface.DrawCircle(x, y, 18, color)

    local countdown = GetImpactCountdown(self)

    if countdown then
        local text = string.format("T-%0.1f", countdown)

        draw.SimpleText(text, "CounterBattery_MortarHudSmall", x, y + 28,
            Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end
