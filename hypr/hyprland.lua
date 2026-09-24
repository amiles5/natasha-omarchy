-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
o.window("^firefox$", { workspace = "5" })
o.window("^kitty$", { workspace = "1" })
o.window("^joplin-app-desktop$", { workspace = "7" })
o.window("^install4j-Moneydance$", { workspace = "3" })
o.window("^FFPWA-01M2X6JBSYM1EQA9QMQ3X4Q4RM$", { workspace = "6" })
o.window("^chrome-www.icloud.com__photos_-Default$", { workspace = "4" })
o.window("^chrome-web.whatsapp.com__-Default$", { workspace = "2" })
o.window("^milesj.agent$", { workspace = "10" })

-- TigerVNC's auth dialog (class Vncviewer, title "VNC authentication")
-- renders tiny by default - FLTK isn't Wayland-HiDPI-aware, so it ignores
-- the Studio Display's forced scale = 3 (see monitors.lua). Only matches
-- the auth dialog by title, not the connected session window (same class,
-- different title, e.g. "alexandre - TigerVNC").
o.window({ class = "^Vncviewer$", title = "^VNC [Aa]uthentication$" }, { float = true, center = true, size = { 500, 320 } })
