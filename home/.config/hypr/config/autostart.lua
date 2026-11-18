-- Programas ao iniciar a sessão
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent") -- pedidos de senha de admin
    hl.exec_cmd("xhost +SI:localuser:root")              -- apps gráficos como root (XWayland)
    -- O resto do autostart do shell (wallpaper, clipboard, quickshell) está em shell.lua
end)
