hl.config({
    dwindle = { preserve_split = true },
    ecosystem = { no_update_news = true, no_donation_nag = true },
    misc = {
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "^(kitty|Alacritty)$",
        vrr = 3,                  -- VRR só em fullscreen de jogos
    },
    render = { direct_scanout = 2 },
    xwayland = { force_zero_scaling = true },
})
