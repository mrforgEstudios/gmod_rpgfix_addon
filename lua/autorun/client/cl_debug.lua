-- cl_debug.lua
-- Клиентская отрисовка отладочных линий и сфер

if not CLIENT then return end

local debugItems = {}  -- { type, data, expireTime }

-- Принимаем данные с сервера
net.Receive("MissileShootdown_Debug", function()
    local msgType  = net.ReadUInt(2)
    local duration = 0
    local item     = { type = msgType }

    if msgType == 0 then
        -- Линия
        item.startPos = net.ReadVector()
        item.endPos   = net.ReadVector()
        item.r        = net.ReadUInt(8)
        item.g        = net.ReadUInt(8)
        item.b        = net.ReadUInt(8)
        duration      = net.ReadFloat()
    elseif msgType == 1 then
        -- Сфера
        item.pos    = net.ReadVector()
        item.radius = net.ReadFloat()
        item.r      = net.ReadUInt(8)
        item.g      = net.ReadUInt(8)
        item.b      = net.ReadUInt(8)
        duration    = net.ReadFloat()
    end

    item.expireTime = CurTime() + duration
    debugItems[#debugItems + 1] = item
end)

-- Рисуем через 3D-рендер
hook.Add("PostDrawOpaqueRenderables", "MissileShootdown_DebugDraw", function()
    local now = CurTime()
    local alive = {}

    for _, item in ipairs(debugItems) do
        if item.expireTime < now then continue end
        alive[#alive + 1] = item

        render.SetColorMaterial()

        if item.type == 0 then
            -- Линия
            render.DrawLine(item.startPos, item.endPos,
                Color(item.r, item.g, item.b, 200), true)

        elseif item.type == 1 then
            -- Wireframe-сфера
            local c = Color(item.r, item.g, item.b, 80)
            render.DrawWireframeSphere(item.pos, item.radius, 12, 12, c, true)
        end
    end

    debugItems = alive
end)
