if SERVER then
    AddCSLuaFile("weapons/weapon_cb_device/shared.lua")
    AddCSLuaFile("weapons/weapon_cb_device/cl_init.lua")
    AddCSLuaFile("weapons/weapon_cb_mortar/shared.lua")
    AddCSLuaFile("weapons/weapon_cb_mortar/cl_init.lua")
    AddCSLuaFile("entities/cb_counter_missile/cl_init.lua")
    AddCSLuaFile("entities/cb_counter_missile/shared.lua")
    AddCSLuaFile("entities/cb_mortar_shell/cl_init.lua")
    AddCSLuaFile("entities/cb_mortar_shell/shared.lua")
    AddCSLuaFile("entities/npc_combine_pvo/cl_init.lua")
    AddCSLuaFile("entities/npc_combine_pvo/shared.lua")
    AddCSLuaFile("entities/npc_combine_mortar/cl_init.lua")
    AddCSLuaFile("entities/npc_combine_mortar/shared.lua")
end

list.Set("NPC", "npc_combine_pvo", {
    Name = "Combine AA Mortar",
    Class = "npc_combine_pvo",
    Category = "Counter Battery",
})

list.Set("NPC", "npc_combine_mortar", {
    Name = "Combine Strike Mortar",
    Class = "npc_combine_mortar",
    Category = "Counter Battery",
})
