local wezterm = require("wezterm")
local mux = wezterm.mux

-- maximize window when starting up
wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

-- toggle window opacity
wezterm.on("toggle-opacity", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if overrides.window_background_opacity == 1.0 then
		overrides.window_background_opacity = 0.85
	else
		overrides.window_background_opacity = 1.0
	end
	window:set_config_overrides(overrides)
end)

return {
	window_decorations = "RESIZE",
	tab_bar_at_bottom = true,
	show_new_tab_button_in_tab_bar = false,
	hide_tab_bar_if_only_one_tab = true,
}
