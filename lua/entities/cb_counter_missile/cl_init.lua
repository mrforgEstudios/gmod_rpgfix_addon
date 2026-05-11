include("shared.lua")

local glowMaterial = Material("sprites/light_glow02_add")
local glowColor = Color(80, 190, 255, 220)

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() - self:GetForward() * 18

    render.SetMaterial(glowMaterial)
    render.DrawSprite(pos, 22, 22, glowColor)
end
