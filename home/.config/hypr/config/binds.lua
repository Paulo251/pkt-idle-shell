-- Atalhos. SUPER = tecla Windows.
local mod = "SUPER"
local app = "uwsm app -- "   -- abre apps como unidades do systemd (uwsm)

-- Teclas numéricas pelo código físico (funciona em qualquer layout): 1..9 => 10..18, 0 => 19
local function digit(d) return "code:" .. (d == 0 and 19 or (9 + d)) end

---- Sessão ----
-- (SUPER+SHIFT+E agora abre o menu de energia do shell — ver shell.lua)
hl.bind(mod .. " + Escape",    hl.dsp.exec_cmd("hyprctl kill")) -- clicar numa janela para matá-la

---- Apps ----
hl.bind(mod .. " + Return",         hl.dsp.exec_cmd(app .. TERMINAL))
hl.bind(mod .. " + E",              hl.dsp.exec_cmd(app .. FILE_MANAGER))
hl.bind(mod .. " + B",              hl.dsp.exec_cmd(app .. BROWSER))   -- era SUPER+W (agora: barra do shell)
hl.bind(mod .. " + C",              hl.dsp.exec_cmd(app .. CALCULATOR))
hl.bind("XF86Calculator",           hl.dsp.exec_cmd(app .. CALCULATOR))
hl.bind("CONTROL + SHIFT + Escape", hl.dsp.exec_cmd(app .. TERMINAL .. " -e btop"))
hl.bind(mod .. " + P",              hl.dsp.exec_cmd("hyprpicker -a -n")) -- conta-gotas de cor

---- Janelas ----
hl.bind(mod .. " + Q",           hl.dsp.window.close())
hl.bind(mod .. " + V",           hl.dsp.window.float({ action = "toggle" })) -- era SUPER+ALT+Space
hl.bind(mod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ mode = 1 })) -- maximizar (era SUPER+D)
hl.bind(mod .. " + J",           hl.dsp.layout("togglesplit"))
hl.bind("ALT + Tab",             hl.dsp.window.cycle_next())

-- Foco
hl.bind(mod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + Down",  hl.dsp.focus({ direction = "down" }))

-- Mover janela
hl.bind(mod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "d" }))

-- Mouse: SUPER + arrastar (esquerdo move, direito redimensiona)
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize())

---- Workspaces ----
-- SUPER + 1..0 vai para a workspace; SUPER + SHIFT + 1..0 leva a janela junto
-- SUPER + SHIFT + ALT + 1..0 manda a janela sem ir junto
for i = 1, 10 do
    local k = digit(i % 10)
    hl.bind(mod .. " + " .. k,               hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. k,       hl.dsp.window.move({ workspace = i }))
    hl.bind(mod .. " + SHIFT + ALT + " .. k, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Workspace anterior/próxima
hl.bind(mod .. " + CONTROL + Right",         hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + CONTROL + Left",          hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CONTROL + Down",          hl.dsp.focus({ workspace = "emptym" })) -- próxima vazia
hl.bind(mod .. " + mouse_down",              hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + mouse_up",                hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + CONTROL + SHIFT + Right", hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mod .. " + CONTROL + SHIFT + Left",  hl.dsp.window.move({ workspace = "m-1" }))

-- Scratchpad (workspace especial)
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special())
hl.bind(mod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special" })) -- era SUPER+SHIFT+S

---- Zoom ----
local function zoom(delta)
    local z = hl.get_config("cursor:zoom_factor") + delta
    hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
hl.bind(mod .. " + Minus",   function() zoom(-0.3) end, { repeating = true })
hl.bind(mod .. " + Plus",    function() zoom(0.3)  end, { repeating = true })
hl.bind(mod .. " + code:82", function() zoom(-0.3) end, { repeating = true }) -- teclado numérico -
hl.bind(mod .. " + code:86", function() zoom(0.3)  end, { repeating = true }) -- teclado numérico +

---- Áudio e brilho ----
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

---- Captura de tela (vai para a área de transferência) ----
hl.bind("Print",               hl.dsp.exec_cmd([[sh -c 'grim -g "$(slurp)" - | wl-copy']])) -- região
hl.bind(mod .. " + Print",     hl.dsp.exec_cmd([[sh -c 'grim - | wl-copy']]))               -- tela inteira
