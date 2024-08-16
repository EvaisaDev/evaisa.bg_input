dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "evaisa.bg_input" -- This should match the name of your mod's folder.
mod_settings_version = 1   -- This is a magic global that can be used to migrate settings to new mod versions. call mod_settings_get_version() before mod_settings_update() to get the old value.
mod_settings =
{
	{
		id = "client_count",
		ui_name = "Client Count",
		ui_description = "How many instances of Noita are we playing at once?",
		value_default = 2,
		value_min = 1,
		value_max = 7,
		value_display_multiplier = 1,
		value_display_formatting = " $0",
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},
	--[[{
		id = "mk_sync",
		ui_name = "Sync mouse and keyboard",
		ui_description = "Experimental, do not start new game with multiple instances open, or mod restart.",
		value_default = false,
		scope = MOD_SETTING_SCOPE_RUNTIME,
	},]]

}

function ModSettingsUpdate(init_scope)
    local old_version = mod_settings_get_version(mod_id)
    mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end