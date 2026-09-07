-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- Ref: amiles5/ayana-cachyos .config/hypr/config/inputs.lua
hl.config({
  input = {
    kb_layout = "gb",
    kb_model = "pc105",
    kb_options = "terminate:ctrl_alt_bksp",
    kb_rules = "evdev",
    follow_mouse = 1,

    -- Increase sensitivity for mouse/trackpad (default: 0).
    sensitivity = 0,

    -- Turn off mouse acceleration (default: adaptive).
    accel_profile = "flat",

    touchpad = {
      -- Use natural (inverse) scrolling.
      natural_scroll = false,

      -- -- Use two-finger clicks for right-click instead of lower-right corner.
      -- clickfinger_behavior = true,

      -- -- Control the speed of your scrolling.
      -- scroll_factor = 0.4,

      -- -- Enable the touchpad while typing.
      -- disable_while_typing = false,

      -- -- Left-click-and-drag with three fingers.
      -- drag_3fg = 1,
    },
  },
  -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
  -- cursor = {
  --     no_hardware_cursors = 1,
  -- },
})

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Touchpad gestures.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- Ref: amiles5/ayana-cachyos .config/hypr/config/inputs.lua
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "close" })
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left", action = "float" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })
