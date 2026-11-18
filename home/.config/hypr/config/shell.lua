-- pkt-idle-shell: integração do shell (Quickshell) com o Hyprland.
-- Autostart, cores do wallpaper, atalhos e regras do desktop.

local HOME = os.getenv("HOME")
local mod  = "SUPER"
local function qs(name) return hl.dsp.global("quickshell:" .. name) end
local function script(s) return hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/" .. s) end

---- Autostart ----
-- Quickshell e hypridle rodam como serviços do systemd (reiniciam se caírem).
hl.on("hyprland.start", function()
    hl.exec_cmd(HOME .. "/.config/hypr/awww-start.sh")              -- wallpaper
    hl.exec_cmd("wl-paste --type text --watch cliphist store")      -- histórico do clipboard (texto)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")     -- histórico do clipboard (imagens)
end)

---- Cores do wallpaper (pywal) ----
-- set-wallpaper.sh gera ~/.cache/wal/colors-hyprland.lua; sem ele, ficam as cores atuais.
do
    local ok, wal = pcall(dofile, HOME .. "/.cache/wal/colors-hyprland.lua")
    if ok and type(wal) == "table" then
        hl.config({
            general = { col = {
                active_border   = { colors = wal.active_border, angle = wal.active_angle or 45 },
                inactive_border = wal.inactive_border,
            } },
            misc = { background_color = wal.background },
        })
    end
end

hl.config({
    misc = { force_default_wallpaper = 0, disable_hyprland_logo = true },
})

---- Atalhos do shell ----
-- Que vieram para o shell por escolha sua:
hl.bind(mod .. " + D",           qs("notch"))     -- Control Centre        (antes: maximizar → SUPER+SHIFT+F)
hl.bind(mod .. " + SHIFT + E",   qs("power"))     -- menu de energia       (antes: sair direto)
hl.bind(mod .. " + ALT + Space", qs("actions"))   -- menu de comandos      (antes: flutuar → SUPER+V)
hl.bind(mod .. " + W",           qs("bar"))       -- esconder/mostrar barra (antes: navegador → SUPER+B)
hl.bind(mod .. " + SHIFT + S",   script("screenshot-region.sh")) -- print de região (antes: scratchpad → SUPER+ALT+S)

-- Novos (teclas que estavam livres):
hl.bind(mod .. " + R",           qs("launcher"))  -- lançador de apps
hl.bind(mod .. " + Tab",         qs("overview"))  -- mapa das workspaces
hl.bind(mod .. " + SHIFT + Tab", qs("stage"))     -- Stage Manager
hl.bind(mod .. " + SHIFT + W",   qs("wallpaper")) -- escolher wallpaper (muda as cores de tudo)
hl.bind(mod .. " + SHIFT + D",   qs("system"))    -- CPU, memória, temperatura
hl.bind(mod .. " + SHIFT + M",   qs("media"))     -- player flutuante
hl.bind(mod .. " + SHIFT + O",   qs("poke"))      -- time pokémon (painel do notch)
hl.bind(mod .. " + I",           qs("pokeidle"))  -- PokéIdle: janela do jogo (resumo, mochila, centro, mart)
hl.bind(mod .. " + SHIFT + V",   qs("clipboard")) -- histórico do clipboard
hl.bind(mod .. " + N",           qs("notchstyle"))-- notch <-> ilha
hl.bind(mod .. " + comma",       qs("settings"))  -- configurações do shell
hl.bind(mod .. " + A",           qs("settings"))
hl.bind(mod .. " + K",           qs("keybinds"))  -- lista de todos os atalhos
hl.bind(mod .. " + G",           hl.dsp.exec_cmd(HOME .. "/.config/quickshell/reload.sh")) -- recarregar o shell
hl.bind(mod .. " + L",           hl.dsp.exec_cmd("loginctl lock-session"))                 -- bloquear (hyprlock)
hl.bind("XF86PowerOff",          qs("power"))

hl.bind(mod .. " + SHIFT + P",         script("screenshot-full.sh"))       -- print da tela inteira (salva + notifica)
hl.bind(mod .. " + CONTROL + S",       script("screenshot-annotate.sh"))   -- print e anotar (satty)
hl.bind(mod .. " + SHIFT + C",         script("colorpicker.sh"))           -- conta-gotas com notificação
hl.bind(mod .. " + SHIFT + N",         script("hyprsunset-toggle.sh"))     -- luz noturna
hl.bind(mod .. " + CONTROL + T",       script("ocr.sh"))                   -- copiar texto da tela (OCR)
hl.bind(mod .. " + CONTROL + R",       script("screenrecord.sh"))          -- gravar tela
hl.bind(mod .. " + CONTROL + SHIFT + R", script("screenrecord.sh --sonido")) -- gravar com som

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

---- Regras ----
hl.window_rule({
    name = "ajustes-quickshell",
    match = { class = "^(org\\.quickshell)$", title = "^(Ajustes)$" },
    float = true, size = { 900, 620 }, center = true,
})
hl.window_rule({
    name = "pokeidle",
    match = { class = "^(org\\.quickshell)$", title = "^(PokéIdle)$" },
    float = true, size = { 1100, 720 }, center = true,
})
hl.window_rule({
    name = "imv-flotante",
    match = { class = "^(imv)$" },
    float = true, size = "monitor_w*0.7 monitor_h*0.7", center = true,
})
hl.layer_rule({ name = "qs-bar",       match = { namespace = "^(quickshell:bar)$" },       no_anim = true })
hl.layer_rule({ name = "qs-stage",     match = { namespace = "^(quickshell:stage)$" },     no_anim = true })
hl.layer_rule({ name = "qs-wallpaper", match = { namespace = "^(quickshell:wallpaper)$" }, no_anim = true })
hl.layer_rule({ name = "qs-wallfx",    match = { namespace = "^(quickshell:wallfx)$" },    no_anim = true })
hl.layer_rule({ name = "qs-media",     match = { namespace = "^(quickshell:media)$" },     animation = "slide bottom" })
