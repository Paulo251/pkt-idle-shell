-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Workspaces 1-3 sempre existem no monitor principal
hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "name:gaming", monitor = MONITOR1 })
