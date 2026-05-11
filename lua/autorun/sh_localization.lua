-- sh_localization.lua
-- Локализация для gmod_rpgfix_addon

local L = {}

if GetConVar("gmod_language"):GetString() == "russian" then
    L = {
        ["loaded"] = "RPG Fix Addon загружен! Анти-ракеты и контрбатарея активны.",
        ["missile_shot_down"] = "🚀 Ракета сбита!",
        ["debug_enabled"] = "Debug режим включён",
        ["cv_enable"] = "Включает/выключает систему сбития ракет",
        ["cv_debug"] = "Включает debug режим (сетка и сообщения)",
        -- добавь остальные строки по необходимости
    }
else
    L = {
        ["loaded"] = "RPG Fix Addon loaded! Anti-missile and counter-battery active.",
        ["missile_shot_down"] = "🚀 Missile shot down!",
        ["debug_enabled"] = "Debug mode enabled",
        ["cv_enable"] = "Enable/Disable missile shootdown system",
        ["cv_debug"] = "Enable debug mode (grid and messages)",
    }
end

_G.RPGFix_L = L
