-- Teclado e mouse
hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "mac",       -- English (Macintosh, ABC, ANSI)
        accel_profile = "flat",   -- sem aceleração do mouse
        -- sensitivity = -0.25,
    },
    cursor = {
        no_hardware_cursors = 1,  -- cursor por software (evita bugs de cursor)
    },
})

-- Gestos de touchpad
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
