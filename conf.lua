-- =============================================================
-- conf.lua  –  LÖVE2D venster- en module-configuratie
-- Responsief venster dat schaalt naar elk schermformaat
-- =============================================================
function love.conf(t)
    t.identity         = "autodash"
    t.version          = "11.4"
    t.console          = false

    t.window.title     = "AutoDash"
    t.window.width     = 1280        -- Startgrootte (schaalt naar elk formaat)
    t.window.height    = 720
    t.window.resizable = true        -- Venster kan van grootte veranderen
    t.window.minwidth  = 640
    t.window.minheight = 360
    t.window.vsync     = 1

    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.video    = false
end
