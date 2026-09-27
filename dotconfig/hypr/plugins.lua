-- Plugin settings: hymission (the overview) and hyprglass (the glass on
-- windows, rofi and master-pick). Both follow the wallust palette from
-- colors.lua. Loaded after windowrules.lua, whose tags hyprglass reads.

-- Rewrites a wallust color from colors.lua with an explicit alpha.
local function hymission_color(color, alpha)
    local rgb = tostring(color):match("(%x%x%x%x%x%x)")
    return rgb and ("rgba(" .. rgb .. alpha .. ")") or nil
end

hl.config({
    plugin = {
        hymission = {
            backdrop_blur        = 1,

            -- Overview UI colors follow wallust. colors.lua is required at the
            -- top of this file, so its globals are in scope here. Alphas are the
            -- plugin's own defaults, kept as-is; only the hue changes.
            focus_selected_color              = hymission_color(color5,     "f2"),
            focus_hover_color                 = hymission_color(foreground, "8c"),
            focus_title_color                 = hymission_color(foreground, "ff"),

            close_button_color                = hymission_color(background, "eb"),
            -- close_button_hover_color stays at the plugin default red: wallust's
            -- color1 is not guaranteed to be one, and a destructive affordance
            -- should not depend on the wallpaper.
            close_button_glyph_color          = hymission_color(foreground, "fa"),

            workspace_strip_background_color  = hymission_color(background, "3d"),
            workspace_strip_inactive_color    = hymission_color(background, "2e"),
            workspace_strip_active_color      = hymission_color(color5,     "3d"),
            workspace_strip_empty_color       = hymission_color(background, "2e"),
            workspace_strip_new_color         = hymission_color(background, "42"),
            workspace_strip_hover_tint_color  = hymission_color(foreground, "0f"),
            workspace_strip_active_tint_color = hymission_color(color5,     "1a"),
            workspace_strip_plus_color        = hymission_color(foreground, "e0"),

            outer_padding_top    = 92,
            outer_padding_right  = 32,
            outer_padding_bottom = 32,
            outer_padding_left   = 32,
            row_spacing          = 32,
            column_spacing       = 32,
            min_window_length    = 120,
            min_preview_short_edge = 32,
            small_window_boost   = 1.35,
            max_preview_scale    = 0.95,
            workspace_overview_max_preview_scale = 0.95,
            min_slot_scale       = 0.10,
            natural_scale_flex   = 0.22,
            layout_engine        = "grid",
            layout_scale_weight  = 1.0,
            layout_space_weight  = 0.10,

            expand_selected_window             = 1,
            overview_focus_follows_mouse       = 1,
            multi_workspace_sort_recent_first  = 1,
            niri_mode                          = 0,
            niri_scroll_pixels_per_delta       = 1.0,
            niri_workspace_scale               = 1.0,
            toggle_switch_mode                 = 0,
            switch_toggle_auto_next            = 1,
            switch_release_key                 = "Super_L",
            gesture_invert_vertical            = 0,
            one_workspace_per_row              = 0,
            only_active_workspace              = 0,
            only_active_monitor                = 0,
            show_special                       = 0,
            workspace_change_keeps_overview    = 1,

            workspace_strip_anchor             = "left",
            workspace_strip_empty_mode         = "existing",
            workspace_strip_thickness          = 160,
            workspace_strip_gap                = 24,
            hide_bar_when_strip                = 1,
            hide_bar_animation                 = 1,
            hide_bar_animation_blur            = 1,
            hide_bar_animation_move_multiplier = 0.8,
            hide_bar_animation_scale_divisor   = 1.1,
            hide_bar_animation_alpha_end       = 0,
            bar_single_mission_control         = 0,
            show_focus_indicator               = 0,
            close_button_enabled               = 1,
            pick_labels_enabled                = 1,
            pick_labels_direct_activate        = 1,
            pick_labels_mode                   = "spatial",
            debug_logs                         = 0,
            debug_surface_logs                 = 0,
        },
    },
})


-- Glass renders below the window surface, so it only shows through windows with
-- real transparency -- in practice kitty, via background_opacity. Guarded so the
-- config survives the plugin failing to load after a Hyprland update.
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- colors.lua gives "rgb(...)", hyprglass wants a 0xRRGGBBAA int. Alpha here
    -- is tint strength, not transparency.
    local function tint(color, alpha)
        local rgb = tostring(color):match("(%x%x%x%x%x%x)")
        if not rgb then return nil end
        return tonumber(rgb, 16) * 256 + alpha
    end

    hg.preset("minor", {
        blur_strength        = 1.5,
        blur_iterations      = 2,
        edge_thickness       = 0.06,  -- band holding the whole liquid part, max 0.15
        refraction_strength  = 4.0,
        chromatic_aberration = 0.25,
        lens_distortion      = 0.4,
        fresnel_strength     = 0.7,
        specular_strength    = 1.0,

        dark = {
            tint_color   = tint(color5, 0x18),
            brightness   = 0.95,
            contrast     = 1.10,
            saturation   = 0.95,
            vibrancy     = 0.40,
            -- Dark default is 0.4, which kills the bright areas of the wallpaper
            -- -- the only thing making the glass visible on a dark terminal.
            adaptive_dim = 0.0,
        },
    })

    hg.config({
        default_theme  = "dark",
        default_preset = "minor",
        enabled        = true,

        -- Sets noblur on glassed windows; without it the new_optimizations cache
        -- hides the effect except while dragging.
        manage_window_blur = true,

        -- Opt-in per namespace below. Off for always-on bars: expensive, and
        -- the liquid band is only ~3px on a 46px waybar.
        layers = { enabled = true },
    })

    -- Pushed harder than "minor" because the pill is a fraction of a window's
    -- size -- below that the effect reads as a flat tinted box. Legibility
    -- doesn't matter here, it's on screen for a few seconds.
    hg.preset("master-pick-glass", {
        inherits             = "minor",
        blur_strength        = 1.1,
        edge_thickness       = 0.15,  -- plugin max
        refraction_strength  = 8.0,
        chromatic_aberration = 0.85,
        lens_distortion      = 0.5,
        fresnel_strength     = 1.0,   -- plugin max
        -- The real transparency dial: the shader saturates the composite to
        -- opaque at 1.0 no matter how transparent the pill's own CSS is.
        glass_opacity        = 0.95,
        -- Near-zero, unlike "minor": the accent dilutes across a kitty window
        -- but turns a pill this small solid purple.
        dark = { tint_color = tint(color5, 0x08) },
    })

    -- Namespace match is exact, not regex. mask_threshold keeps the pill's
    -- anti-aliased edge from counting as content.
    hg.layer("master-pick", { preset = "master-pick-glass", mask_threshold = 0.05 })
    hg.layer("rofi",        { preset = "minor",             mask_threshold = 0.05 })
end
