ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Counter Battery Missile"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Target")
    self:NetworkVar("Float", 0, "EstimatedImpactTime")
end
