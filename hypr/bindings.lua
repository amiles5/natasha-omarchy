-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Was: Editor (default text editor, via { omarchy = "editor" })
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Joplin", { launch = "joplin-desktop" })

-- Was: Google Photos (default web app, via { webapp = "https://photos.google.com/" })
-- Ref: amiles5/ayana-cachyos (io.github.TaylanTatli.iCloud-Linux flatpak was
-- the original there, but it's no longer on Flathub - using the web app instead).
hl.unbind("SUPER + SHIFT + P")
o.bind("SUPER + SHIFT + P", "iCloud Photos", { webapp = "https://www.icloud.com/photos/", focus = true })

-- Was: Docker (default web app)
hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Moneydance", { launch = "/home/milesj/moneydance/Moneydance" })

-- Sonos web app (play.sonos.com), installed as a real Firefox PWA via
-- firefoxpwa - see natasha-omarchy README. Site ID is fixed at install
-- time; reinstalling generates a new one and this must be updated to match.
-- Was: Music (default, via { omarchy = "spotify" }) - only this key's
-- meaning changed. Previously also bound to SUPER+SHIFT+U, removed since
-- this is now the only Sonos binding.
hl.unbind("SUPER + SHIFT + M")
o.bind("SUPER + SHIFT + M", "Sonos", { launch = "firefoxpwa site launch 01M2X6JBSYM1EQA9QMQ3X4Q4RM" })

-- Was: Calendar (default web app, via { webapp = "https://app.hey.com/calendar/weeks/" })
-- Previously also bound to the default SUPER+SHIFT+ALT+G, removed below
-- since this is now the only WhatsApp binding.
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
hl.unbind("SUPER + SHIFT + ALT + G")

-- Was: ChatGPT (default web app, via { webapp = "https://chatgpt.com/" })
-- Launches the default coding agent (currently "claude") in a terminal,
-- via Omarchy's own omarchy-agent - see hypr/hyprland.lua for the matching
-- workspace rule (org.omarchy.agent, a fixed app-id set by the script
-- itself so every agent window shares one class regardless of which agent
-- is configured as default).
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + SHIFT + A", "Agent", { launch = "omarchy-agent" })
