-- pkt-idle-shell: configuração do Hyprland (Lua)
-- Cada arquivo em config/ cuida de uma parte. Recarregar: hyprctl reload

require("config.variables")   -- apps padrão e monitor
require("config.monitors")    -- resolução / taxa
require("config.workspaces")  -- workspaces persistentes
require("config.decorations") -- bordas, gaps, blur, cores
require("config.animations")
require("config.inputs")      -- teclado, mouse, gestos
require("config.misc")
require("config.windowrules")
require("config.autostart")
require("config.binds")       -- atalhos
require("config.shell")       -- pkt-idle-shell (Quickshell): autostart, cores, atalhos, regras

-- Efeitos salvos pelo shell (Ajustes > Aparência > Efeitos): arredondamento, motion blur.
-- Carregado por último para sobreviver ao `hyprctl reload`.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/efectos.lua")
