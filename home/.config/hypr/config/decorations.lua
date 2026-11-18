-- Visual: gaps, bordas, arredondamento, opacidade, blur
local green_light = "rgba(82dcccff)"
local green_dark  = "rgba(007d6fff)"
local blue_light  = "rgba(01ccffff)"
local blue_dark   = "rgba(111826ff)"
local gray        = "rgba(798bb2ff)"

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border   = { colors = { green_light, green_dark }, angle = 45 },
            inactive_border = gray,
        },
    },
    group = {
        col = {
            border_active = blue_light,
            border_inactive = gray,
            border_locked_active = blue_dark,
            border_locked_inactive = gray,
        },
        groupbar = {
            col = {
                active = green_light,
                inactive = gray,
                locked_active = blue_dark,
                locked_inactive = gray,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 12,
        rounding_power = 2,       -- 2 = canto circular; 3-4 = estilo "squircle" (macOS)
        active_opacity = 0.95,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1,
        blur = {
            size = 6,
            passes = 3,
            special = true,
            new_optimizations = true,
            noise = 0.02,
            vibrancy = 0.17,
        },
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            offset = "0 4",
            color = "rgba(00000066)",
            color_inactive = "rgba(00000033)",
        },
    },
    misc = {
        col = { splash = green_light },
    },
})
