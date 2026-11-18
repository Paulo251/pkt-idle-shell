-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Janelas flutuantes lembram o tamanho
hl.window_rule({ match = { float = true }, persistent_size = true })

-- Picture-in-Picture: flutuante, fixo em todas as workspaces
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Jogos vão para a workspace "gaming", em tela cheia
local games = "^(steam_app.*|gamescope)$"
hl.window_rule({ match = { class = games }, workspace = "name:gaming" })
hl.window_rule({ match = { content = "game" }, workspace = "name:gaming" })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })

-- Heronite abre sempre na workspace 10, em tela cheia (só a janela principal)
hl.window_rule({
    match      = { class = "^(app\\.heronite\\.Heronite)$", title = "^(Heronite)$" },
    workspace  = "10",
    fullscreen = true,
})

-- Utilitários e diálogos flutuantes
local floats = {
    { class = "^(.*[Cc]alc.*)$" },
    { class = "^(qt[56]ct|nwg-look|org.pulseaudio.pavucontrol|blueman-manager|nm-connection-editor)$" },
    { class = "^([Xx]dg-desktop-portal-gtk|hyprland-share-picker)$" },
    { title = "^(Open|Open File|Save As|Choose Files|Authentication Required|File Upload)(.*)$" },
    { class = "^(.*dialog.*)$" },
}
for _, m in ipairs(floats) do hl.window_rule({ match = m, float = true }) end

-- Opacidade total em navegador, terminal e players de vídeo
hl.window_rule({ match = { class = "^(firefox|zen|google-chrome|kitty|Alacritty|mpv|.*vlc.*)$" }, opacity = "1.0 override" })

-- Ignora apps que tentam se maximizar sozinhos
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-- Corrige arrastar em apps XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
