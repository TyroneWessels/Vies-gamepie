-- =============================================================
-- main.lua
-- Responsieve game die schaalt naar elk schermformaat.
-- Basis-resolutie is 1920x1080, wordt automatisch geschaald.
--
-- Layout (in virtuele coördinaten):
--   Y=0        ┌─────────────────────────────┐
--              │  LUCHT / ACHTERGROND         │
--   Y=660      ├─────────────────────────────┤  ← GROUND_Y (bovenkant asfalt)
--              │  ASFALT  (660 → 860)         │  ← auto en obstakels staan hier
--   Y=860      ├─────────────────────────────┤
--              │  HUD-BALK met knoppen        │
--   Y=1080     └─────────────────────────────┘
--
-- De auto-body + wielen passen VOLLEDIG boven GROUND_Y.
-- Lijnen op het asfalt zitten ONDER de auto (hoger Y-getal).
-- =============================================================

local Player   = require("player")
local Obstacle = require("obstacle")
local Score    = require("score")
local Levels   = require("levels")

-- ---------------------------------------------------------------
-- Basis (virtuele) resolutie - game wordt hierop ontworpen
-- Alles wordt automatisch geschaald naar het werkelijke venster
-- ---------------------------------------------------------------
local BASE_WIDTH  = 1920
local BASE_HEIGHT = 1080

-- Schaal-variabelen (worden berekend in updateScale)
local scale    = 1
local offsetX  = 0
local offsetY  = 0

-- ---------------------------------------------------------------
-- Eén centrale constante: de bovenkant van het asfalt.
-- ALLE andere Y-waarden worden hieruit afgeleid.
-- ---------------------------------------------------------------
local GROUND_Y = 660       -- bovenkant asfalt (pixels van boven)
local ROAD_H   = 200       -- hoogte asfaltblok
local HUD_H    = 220       -- hoogte onderste HUD-balk (knoppen)

local CFG = {
    SCREEN_WIDTH    = BASE_WIDTH,
    SCREEN_HEIGHT   = BASE_HEIGHT,
    TITLE           = "AutoDash",
    GROUND_Y        = GROUND_Y,
    ROAD_HEIGHT     = ROAD_H,
    -- Knoppen en HUD zitten in de zone ONDER het asfalt
    HUD_ZONE_Y      = GROUND_Y + ROAD_H,   -- = 860
    HUD_ZONE_H      = HUD_H,
    STRIPE_WIDTH    = 100,
    STRIPE_GAP      = 70,
    PARALLAX_SPEED  = 0.28,
    FINISH_DISTANCE = 41500,  -- Totale afstand over alle levels
}

local BTN   = {}
local STATE = { MENU="menu", PLAYING="playing", GAMEOVER="gameover", ENTER_NAME="enter_name" }

local gameState, player, obstacleMgr, scoreTracker
local roadOffset, bgOffset, hillOffsets, distanceTraveled
local fontBig, fontMed, fontSmall
local btnHeld = { jump=false, boost=false, toggleMusic=false }
local musicOn = true
local currentLevel, currentLevelData, levelProgress
local selectedLevel = 1       -- Geselecteerd level in menu
local playerName = ""         -- Naam voor leaderboard
local nameCursor = 0          -- Cursor positie in naam

-- ---------------------------------------------------------------
-- updateScale  –  bereken schaalfactor voor huidige venstergrootte
-- Behoudt aspect ratio met letterboxing indien nodig
-- ---------------------------------------------------------------
local function updateScale()
    local winW, winH = love.graphics.getDimensions()
    local scaleX = winW / BASE_WIDTH
    local scaleY = winH / BASE_HEIGHT
    
    -- Gebruik kleinste schaal om aspect ratio te behouden
    scale = math.min(scaleX, scaleY)
    
    -- Centreer de game als er letterboxing is
    offsetX = (winW - BASE_WIDTH * scale) / 2
    offsetY = (winH - BASE_HEIGHT * scale) / 2
end

-- ---------------------------------------------------------------
-- screenToGame  –  converteer schermcoördinaten naar game-coördinaten
-- ---------------------------------------------------------------
local function screenToGame(sx, sy)
    local gx = (sx - offsetX) / scale
    local gy = (sy - offsetY) / scale
    return gx, gy
end

-- ---------------------------------------------------------------
-- setupButtons  –  kleine ronde knoppen links en rechts
-- ---------------------------------------------------------------
local function setupButtons()
    local btnSize = 100  -- Vierkante knoppen
    local margin  = 20
    local centerY = CFG.HUD_ZONE_Y + (CFG.HUD_ZONE_H - btnSize) / 2

    -- SPRING links
    BTN.jump = {
        x = margin,
        y = centerY, w = btnSize, h = btnSize,
        label = "SPRING",
        color = { 0.12, 0.65, 0.20 },
        colorHeld = { 0.20, 1.0, 0.35 },
        action = "jump",
        round = true
    }
    -- BOOST rechts
    BTN.boost = {
        x = CFG.SCREEN_WIDTH - btnSize - margin,
        y = centerY + 20, w = btnSize, h = btnSize - 20,
        label = "BOOST",
        color = { 0.75, 0.12, 0.08 },
        colorHeld = { 1.0, 0.28, 0.15 },
        action = "boost",
        round = true
    }

    -- MUZIEK toggle knop
    BTN.music = {
        x = CFG.SCREEN_WIDTH - btnSize * 2 - margin * 1.5,
        y = centerY, w = btnSize, h = btnSize,
        label = "TURN ON",
        color = { 0.14, 0.48, 0.82 },
        colorHeld = { 0.35, 0.70, 1.0 },
        action = "toggleMusic",
        round = true
    }
end

-- ---------------------------------------------------------------
-- initGame  –  start game vanaf geselecteerd level
-- ---------------------------------------------------------------
local function initGame()
    player           = Player.new(CFG.GROUND_Y)
    obstacleMgr      = Obstacle.newManager(CFG.SCREEN_WIDTH, CFG.GROUND_Y)
    scoreTracker     = Score.new()
    roadOffset       = 0
    bgOffset         = 0
    btnHeld          = { jump=false, boost=false }
    playerName       = ""
    
    -- Maak random level volgorde, beginnend met geselecteerd level
    Levels.createRandomOrder(selectedLevel)
    
    -- Start altijd op positie 1 in de playOrder (het gekozen level)
    distanceTraveled = 0
    
    -- Level systeem initialiseren op positie 1 (geselecteerd level)
    currentLevel = 1
    currentLevelData = Levels.getPlayLevel(1)
    levelProgress = 0
    Obstacle.setLevelConfig(obstacleMgr, currentLevelData.obstacles, 
                            currentLevelData.spawnMin, currentLevelData.spawnMax)

    -- Heuvels alleen in de luchtzone (Y < GROUND_Y)
    hillOffsets = {}
    for i = 1, 12 do
        hillOffsets[i] = {
            x = (i-1) * 200 + math.random(0, 80),
            r = math.random(60, 140),
        }
    end
end

local function updateMusicPlayback()
    if not musicOn then
        menuMusic:stop()
        gameMusic:stop()
        if BTN.music then BTN.music.label = "MUTE" end
        return
    end

    if BTN.music then
        BTN.music.label = "MUSIEK"
    end

    if gameState == STATE.MENU then
        gameMusic:stop()
        if not menuMusic:isPlaying() then menuMusic:play() end
    elseif gameState == STATE.PLAYING then
        menuMusic:stop()
        if not gameMusic:isPlaying() then gameMusic:play() end
    end
end

-- ---------------------------------------------------------------
-- love.load
-- ---------------------------------------------------------------
function love.load()
    love.window.setTitle(CFG.TITLE)
    -- Venster is al geconfigureerd via conf.lua
    -- Bereken initiele schaal
    updateScale()
    
    fontBig   = love.graphics.newFont(44)
    fontMed   = love.graphics.newFont(30)
    fontSmall = love.graphics.newFont(22)
    love.graphics.setFont(fontSmall)
    math.randomseed(os.time())
    setupButtons()
    gameState = STATE.MENU
    initGame()

    menuMusic = love.audio.newSource("Music/beatvoorgamemenu.mp3", "stream")
    gameMusic = love.audio.newSource("music/Songvoordegame.mp3", "stream")
    menuMusic:setLooping(true)
    gameMusic:setLooping(true)

    musicOn = true
    updateMusicPlayback()
end

-- ---------------------------------------------------------------
-- love.resize  –  herbereken schaal bij venstergrootte wijziging
-- ---------------------------------------------------------------
function love.resize(w, h)
    updateScale()
end

-- ---------------------------------------------------------------
-- Input helpers
-- ---------------------------------------------------------------
local function pointInBtn(btn, mx, my)
    return mx >= btn.x and mx <= btn.x+btn.w
       and my >= btn.y and my <= btn.y+btn.h
end

local function handlePress(sx, sy)
    -- Converteer schermcoördinaten naar game-coördinaten
    local mx, my = screenToGame(sx, sy)
    
    if BTN.music and pointInBtn(BTN.music, mx, my) then
        btnHeld.toggleMusic = true
        musicOn = not musicOn
        updateMusicPlayback()
        return
    end

    if gameState == STATE.MENU then
        local cx = CFG.SCREEN_WIDTH/2
        local pw, ph = 800, 580
        local px = cx - pw/2
        local py = (CFG.GROUND_Y - ph) / 2 - 20
        
        -- Check level selectie boxes
        local lvlY = py + 140
        local lvlW = 150
        local lvlH = 40
        local lvlSpacingX = 15
        local lvlSpacingY = 12
        local cols = 3
        local startX = px + (pw - cols * lvlW - (cols-1) * lvlSpacingX) / 2
        
        local clickedLevel = nil
        for i = 1, Levels.getTotalLevels() do
            local col = (i-1) % cols
            local row = math.floor((i-1) / cols)
            local lx = startX + col * (lvlW + lvlSpacingX)
            local ly = lvlY + row * (lvlH + lvlSpacingY)
            
            if mx >= lx and mx <= lx + lvlW and my >= ly and my <= ly + lvlH then
                clickedLevel = i
                break
            end
        end
        
        if clickedLevel then
            selectedLevel = clickedLevel
            return
        end
        
        -- Check auto selectie boxes
        local carY = py + 295
        local carW = 110
        local carH = 70
        local carCols = 6
        local carStartX = px + (pw - carCols * carW - (carCols-1) * 8) / 2
        
        for i = 1, #Player.CAR_TYPES do
            local col = (i-1) % carCols
            local lx = carStartX + col * (carW + 8)
            local ly = carY
            
            if mx >= lx and mx <= lx + carW and my >= ly and my <= ly + carH then
                Player.selectedCar = i
                return
            end
        end
        
        -- Check clear leaderboard knop
        local lbx = px + pw + 30
        local clearBtnY = py + ph - 50
        if mx >= lbx+16 and mx <= lbx+16+288 and my >= clearBtnY and my <= clearBtnY+36 then
            scoreTracker.leaderboard = Score.clearLeaderboard()
            return
        end
        
        -- Klik ergens anders = start game
        initGame()
        gameState = STATE.PLAYING
        return
    end
    
    if gameState == STATE.GAMEOVER then
        gameState = STATE.ENTER_NAME
        playerName = ""
        return
    end
    
    if gameState == STATE.PLAYING then
        if pointInBtn(BTN.jump,  mx, my) then btnHeld.jump  = true; player:jump()  end
        if pointInBtn(BTN.boost, mx, my) then btnHeld.boost = true; player:boost() end
    end
end

local function handleRelease()
    btnHeld.jump        = false
    btnHeld.boost       = false
    btnHeld.toggleMusic = false
end

function love.mousepressed(mx, my, b)  if b==1 then handlePress(mx,my)   end end
function love.mousereleased(mx,my,b)   if b==1 then handleRelease()       end end
function love.touchpressed(id,x,y)     handlePress(x,y)                       end
function love.touchreleased(id,x,y)    handleRelease()                         end

function love.keypressed(key)
    if type(key) ~= "string" then return end
    
    -- Fullscreen toggle met F11
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        updateScale()
        return
    end

    if key == "m" then
        musicOn = not musicOn
        updateMusicPlayback()
        return
    end
    
    if gameState == STATE.MENU then
        -- Level selectie met pijltjes of cijfers
        if key == "left" then
            selectedLevel = math.max(1, selectedLevel - 1)
        elseif key == "right" then
            selectedLevel = math.min(Levels.getTotalLevels(), selectedLevel + 1)
        elseif key == "1" then selectedLevel = 1
        elseif key == "2" then selectedLevel = math.min(2, Levels.getTotalLevels())
        elseif key == "3" then selectedLevel = math.min(3, Levels.getTotalLevels())
        elseif key == "4" then selectedLevel = math.min(4, Levels.getTotalLevels())
        elseif key == "5" then selectedLevel = math.min(5, Levels.getTotalLevels())
        elseif key == "6" then selectedLevel = math.min(6, Levels.getTotalLevels())
        elseif key == "return" or key == "space" then 
            initGame()
            gameState = STATE.PLAYING 
        end
        
    elseif gameState == STATE.PLAYING then
        if key=="space" or key=="up"   then player:jump()  end
        if key=="r"     or key=="down" then player:boost() end
        
    elseif gameState == STATE.GAMEOVER then
        -- Ga naar naam invoer scherm
        gameState = STATE.ENTER_NAME
        playerName = ""
        
    elseif gameState == STATE.ENTER_NAME then
        if key == "return" then
            -- Sla score op met naam en ga terug naar menu
            scoreTracker:saveWithName(playerName)
            scoreTracker.leaderboard = Score.loadLeaderboard()
            gameState = STATE.MENU
        elseif key == "backspace" then
            playerName = playerName:sub(1, -2)
        elseif key == "escape" then
            -- Skip naam, sla op als ???
            scoreTracker:saveWithName("???")
            scoreTracker.leaderboard = Score.loadLeaderboard()
            gameState = STATE.MENU
        end
    end
    
    if key=="escape" and gameState ~= STATE.ENTER_NAME then 
        love.event.quit() 
    end
end

-- Tekst invoer voor naam
function love.textinput(text)
    if gameState == STATE.ENTER_NAME then
        -- Alleen letters, cijfers en enkele speciale tekens
        if #playerName < 10 and text:match("[%w%s%-_]") then
            playerName = playerName .. text
        end
    end
end

-- ---------------------------------------------------------------
-- love.update
-- ---------------------------------------------------------------
function love.update(dt)
    dt = math.min(dt, 0.05)

    updateMusicPlayback()

    if gameState ~= STATE.PLAYING then return end

    if btnHeld.boost then player:boost() end

    local speed = player:getSpeed()
    player:update(dt)
    Obstacle.updateManager(obstacleMgr, dt, speed)

    local total = CFG.STRIPE_WIDTH + CFG.STRIPE_GAP
    roadOffset       = (roadOffset + speed * dt) % total
    bgOffset         = bgOffset + speed * CFG.PARALLAX_SPEED * dt
    distanceTraveled = distanceTraveled + speed * dt
    scoreTracker:update(dt)
    
    -- Level check en update
    local newLevel, newLevelData, newProgress = Levels.getLevelAtDistance(distanceTraveled)
    if newLevel ~= currentLevel then
        currentLevel = newLevel
        currentLevelData = newLevelData
        levelProgress = newProgress
        -- Update obstacle types voor nieuw level
        Obstacle.setLevelConfig(obstacleMgr, currentLevelData.obstacles,
                                currentLevelData.spawnMin, currentLevelData.spawnMax)
    else
        levelProgress = newProgress
    end

    local px,py,pw,ph = player:getBoundingBox()
    if Obstacle.checkCollision(obstacleMgr, px,py,pw,ph) then
        player.isDead = true
        scoreTracker:finalize()
        gameState = STATE.GAMEOVER
    end
    if distanceTraveled >= Levels.getTotalDistance() then
        scoreTracker:finalize()
        gameState = STATE.GAMEOVER
    end
end
-- ---------------------------------------------------------------
-- drawBackground  –  lucht + heuvels (ALLEEN boven GROUND_Y)
-- Gebruikt thema kleuren van het huidige level
-- ---------------------------------------------------------------
local function drawBackground()
    local gy = CFG.GROUND_Y
    local theme = currentLevelData and currentLevelData.theme or Levels.getLevel(1).theme

    -- Lucht verloop
    love.graphics.setColor(theme.skyTop)
    love.graphics.rectangle("fill", 0, 0, CFG.SCREEN_WIDTH, gy * 0.5)
    love.graphics.setColor(theme.skyBottom)
    love.graphics.rectangle("fill", 0, gy * 0.5, CFG.SCREEN_WIDTH, gy * 0.5)

    -- Zon voor alle levels behalve ruimte
    if currentLevelData and currentLevelData.name ~= "RUIMTE" then
        love.graphics.setColor(1, 0.9, 0.3, 1)  -- Gele zon
        love.graphics.circle("fill", CFG.SCREEN_WIDTH * 0.8, gy * 0.2, 80)  -- Stilstaande zon rechtsboven
    end

    -- Heuvels: clip strikt boven GROUND_Y
    -- Verre laag
    love.graphics.setColor(theme.hillFar)
    local wrap = CFG.SCREEN_WIDTH + 500
    for _, h in ipairs(hillOffsets) do
        local hx = ((h.x - bgOffset * 0.15) % wrap) - 80
        local cy = gy - h.r * 0.5   -- middelpunt zodat onderkant cirkel op gy zit
        love.graphics.circle("fill", hx, cy, h.r)
    end
    -- Middel laag
    love.graphics.setColor(theme.hillNear)
    for _, h in ipairs(hillOffsets) do
        local hx = ((h.x - bgOffset * 0.40) % wrap) - 80
        local cy = gy - h.r * 0.45
        love.graphics.circle("fill", hx, cy, h.r * 0.8)
    end

    -- Grondbalk tussen heuvels en asfalt (dunne overgang)
    love.graphics.setColor(theme.hillNear[1] * 1.1, theme.hillNear[2] * 1.1, theme.hillNear[3] * 1.1)
    love.graphics.rectangle("fill", 0, gy - 20, CFG.SCREEN_WIDTH, 22)
    
    -- Sterren voor ruimte thema
    if currentLevelData and currentLevelData.name == "RUIMTE" then
        love.graphics.setColor(1, 1, 1, 0.8)
        math.randomseed(42)  -- Vaste seed voor consistente sterren
        for i = 1, 50 do
            local sx = math.random(0, CFG.SCREEN_WIDTH)
            local sy = math.random(0, gy - 50)
            local sz = math.random(1, 3)
            love.graphics.circle("fill", sx, sy, sz)
        end
        math.randomseed(os.time())
    end
end

-- ---------------------------------------------------------------
-- drawRoad  –  asfalt + wegmarkering
-- Rijstroken zitten IN het asfalt, ver onder de auto
-- Gebruikt thema kleuren van het huidige level
-- ---------------------------------------------------------------
local function drawRoad()
    local gy = CFG.GROUND_Y
    local rh = CFG.ROAD_HEIGHT
    local theme = currentLevelData and currentLevelData.theme or Levels.getLevel(1).theme

    -- Asfalt
    love.graphics.setColor(theme.road)
    love.graphics.rectangle("fill", 0, gy, CFG.SCREEN_WIDTH, rh)

    -- Bovenste kantlijn
    love.graphics.setColor(0.80, 0.80, 0.80, 0.9)
    love.graphics.rectangle("fill", 0, gy, CFG.SCREEN_WIDTH, 4)

    -- Onderste kantlijn
    love.graphics.rectangle("fill", 0, gy + rh - 4, CFG.SCREEN_WIDTH, 4)

    -- Scrollende gestippelde middenlijn
    -- Zit op 65% van de road-hoogte (dus GOED onder de auto)
    local lineY  = gy + rh * 0.55
    local total  = CFG.STRIPE_WIDTH + CFG.STRIPE_GAP
    local sx     = -(roadOffset % total)
    love.graphics.setColor(theme.stripe)
    local x = sx
    while x < CFG.SCREEN_WIDTH do
        local dw = math.min(CFG.STRIPE_WIDTH, CFG.SCREEN_WIDTH - x)
        if dw > 0 and x + dw > 0 then
            love.graphics.rectangle("fill", x, lineY, dw, 7)
        end
        x = x + total
    end

    -- HUD-zone achtergrond (donkere balk onder asfalt)
    love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", 0, CFG.HUD_ZONE_Y, CFG.SCREEN_WIDTH, CFG.HUD_ZONE_H)
    love.graphics.setColor(0.25, 0.35, 0.6, 0.5)
    love.graphics.rectangle("fill", 0, CFG.HUD_ZONE_Y, CFG.SCREEN_WIDTH, 3)
end

-- ---------------------------------------------------------------
-- drawTouchButtons
-- ---------------------------------------------------------------
local function drawTouchButtons()
    love.graphics.setFont(fontSmall)
    for _, btn in pairs(BTN) do
        local held = btnHeld[btn.action]
        local c    = held and btn.colorHeld or btn.color
        local r    = btn.round and math.min(btn.w, btn.h) / 2 or 14

        -- Schaduw
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", btn.x+3, btn.y+3, btn.w, btn.h, r, r)

        -- Knop
        love.graphics.setColor(c[1], c[2], c[3], held and 1.0 or 0.88)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, r, r)

        -- Rand
        love.graphics.setColor(1, 1, 1, held and 0.8 or 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, r, r)
        love.graphics.setLineWidth(1)

        -- Label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(btn.label, btn.x, btn.y + btn.h/2 - 10, btn.w, "center")
    end
end

-- ---------------------------------------------------------------
-- drawHUD  –  score + boost + level in HUD-zone links
-- ---------------------------------------------------------------
local function drawHUD()
    local hz = CFG.HUD_ZONE_Y + 14

    love.graphics.setFont(fontMed)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.print(string.format("SCORE  %06d", scoreTracker:getCurrentScore()), 20, hz)

    local m  = math.floor(scoreTracker.elapsed / 60)
    local s  = math.floor(scoreTracker.elapsed % 60)
    local ms = math.floor((scoreTracker.elapsed % 1) * 100)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.75, 0.92, 1, 1)
    love.graphics.print(string.format("TIJD  %02d:%02d.%02d", m,s,ms), 20, hz + 42)
    
    -- Level indicator
    love.graphics.setColor(0.5, 1, 0.6, 1)
    local levelName = currentLevelData and currentLevelData.name or "STAD"
    love.graphics.print(string.format("LEVEL %d: %s", currentLevel, levelName), 20, hz + 72)

    -- Boost balk
    player:drawHUD(20, hz + 105)
end

-- ---------------------------------------------------------------
-- drawProgressBar  –  bovenaan het scherm met level markers
-- ---------------------------------------------------------------
local function drawProgressBar()
    local bw  = 600
    local bh  = 20
    local bx  = CFG.SCREEN_WIDTH/2 - bw/2
    local by  = 16
    local totalDist = Levels.getTotalDistance()
    local pct = math.min(1, distanceTraveled / totalDist)

    love.graphics.setColor(0,0,0,0.55)
    love.graphics.rectangle("fill", bx-12,by-8, bw+24,bh+40, 6,6)
    love.graphics.setColor(0.15,0.15,0.15,0.9)
    love.graphics.rectangle("fill", bx, by, bw, bh, 4,4)
    
    -- Level kleuren in de progress bar
    local accumDist = 0
    for i, lvl in ipairs(Levels.data) do
        local startPct = accumDist / totalDist
        local endPct = (accumDist + lvl.distance) / totalDist
        accumDist = accumDist + lvl.distance
        
        -- Alleen tekenen als we daar al geweest zijn
        local fillEnd = math.min(endPct, pct)
        if fillEnd > startPct then
            local theme = lvl.theme
            local r, g, b = theme.skyBottom[1], theme.skyBottom[2], theme.skyBottom[3]
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 1)
            love.graphics.rectangle("fill", bx + bw * startPct, by, bw * (fillEnd - startPct), bh, 2,2)
        end
        
        -- Level markers
        if i > 1 then
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            love.graphics.rectangle("fill", bx + bw * startPct - 1, by - 2, 2, bh + 4)
        end
    end
    
    love.graphics.setColor(1,1,1,0.25)
    love.graphics.rectangle("line", bx, by, bw, bh, 4,4)

    love.graphics.setFont(fontSmall)
    -- START en FINISH tekst BUITEN de progress bar box
    love.graphics.setColor(1,1,1,0.8)
    love.graphics.print("START", bx - 60, by + 2)
    love.graphics.print("FINISH", bx + bw + 10, by + 2)
    
    -- Level naam onder de progressbar
    local levelName = currentLevelData and currentLevelData.name or "STAD"
    love.graphics.setColor(1, 0.9, 0.3, 1)
    love.graphics.printf(string.format("LEVEL %d: %s", currentLevel, levelName), bx, by+bh+6, bw, "center")

    -- Auto-marker
    love.graphics.setColor(0.2, 0.65, 1, 1)
    local mx = math.max(bx, math.min(bx+bw-16, bx + bw*pct - 8))
    love.graphics.rectangle("fill", mx, by-4, 16, bh+8, 3,3)
end

-- ---------------------------------------------------------------
-- drawLeaderboard  –  in het midden van de HUD-zone (tussen knoppen)
-- ---------------------------------------------------------------
local function drawLeaderboard()
    local lb  = scoreTracker.leaderboard
    -- Positioneer in het midden (tussen SPRING links en BOOST rechts)
    local w   = 500
    local x   = (CFG.SCREEN_WIDTH - w) / 2
    local y   = CFG.HUD_ZONE_Y + 10
    local h   = CFG.HUD_ZONE_H - 20

    love.graphics.setColor(0,0,0,0.4)
    love.graphics.rectangle("fill", x, y, w, h, 8,8)

    love.graphics.setFont(fontMed)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.print("TOP SCORES", x+16, y+10)

    love.graphics.setFont(fontSmall)
    -- 2 kolommen van 5
    for i, entry in ipairs(lb) do
        if i > 10 then break end
        local col  = (i <= 5) and 0 or 1
        local row  = (i-1) % 5
        local ex   = x + 16 + col * (w/2)
        local ey   = y + 48 + row * 28
        local name = entry.name or "???"
        local score = entry.score or 0
        love.graphics.setColor(1,1,1, 0.85)
        love.graphics.print(string.format("%d.%-6s %05d", i, name:sub(1,6), score), ex, ey)
    end
    if #lb == 0 then
        love.graphics.setColor(0.6,0.6,0.7,0.8)
        love.graphics.print("Nog geen scores", x+16, y+48)
    end
end

-- ---------------------------------------------------------------
-- drawMenu
-- ---------------------------------------------------------------
local function drawMenu()
    drawBackground()
    drawRoad()

    local cx = CFG.SCREEN_WIDTH/2
    -- Paneel in de luchtzone
    local pw, ph = 800, 580
    local px = cx - pw/2
    local py = (CFG.GROUND_Y - ph) / 2 - 20

    love.graphics.setColor(0,0,0,0.72)
    love.graphics.rectangle("fill", px, py, pw, ph, 16,16)
    love.graphics.setColor(0.2,0.45,0.9,0.5)
    love.graphics.rectangle("line", px, py, pw, ph, 16,16)

    love.graphics.setFont(fontBig)
    love.graphics.setColor(0.2, 0.65, 1, 1)
    love.graphics.printf("AUTO DASH", px, py+15, pw, "center")

    -- Instructies
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1,1,1,0.88)
    love.graphics.printf(
        "SPRINGEN: SPATIE/UP   |   BOOST: R/DOWN   |   FULLSCREEN: F11",
        px+40, py+65, pw-80, "center")
    
    -- Level selectie
    love.graphics.setFont(fontMed)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.printf("KIES LEVEL", px, py+100, pw, "center")
    
    love.graphics.setFont(fontSmall)
    local lvlY = py + 140
    local lvlW = 150
    local lvlH = 40
    local lvlSpacingX = 15
    local lvlSpacingY = 12
    local cols = 3
    local startX = px + (pw - cols * lvlW - (cols-1) * lvlSpacingX) / 2
    
    for i, lvl in ipairs(Levels.data) do
        local col = (i-1) % cols
        local row = math.floor((i-1) / cols)
        local lx = startX + col * (lvlW + lvlSpacingX)
        local ly = lvlY + row * (lvlH + lvlSpacingY)
        
        -- Achtergrond (highlight als geselecteerd)
        if i == selectedLevel then
            love.graphics.setColor(0.2, 0.6, 0.9, 0.9)
            love.graphics.rectangle("fill", lx, ly, lvlW, lvlH, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(0.15, 0.15, 0.25, 0.8)
            love.graphics.rectangle("fill", lx, ly, lvlW, lvlH, 8, 8)
            love.graphics.setColor(0.7, 0.7, 0.8, 0.9)
        end
        
        -- Level nummer en naam
        love.graphics.printf(tostring(i) .. ". " .. lvl.name, lx, ly + 10, lvlW, "center")
    end
    
    -- Auto selectie
    love.graphics.setFont(fontMed)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.printf("KIES AUTO", px, py+260, pw, "center")
    
    local carY = py + 295
    local carW = 110
    local carH = 70
    local carCols = 6
    local carStartX = px + (pw - carCols * carW - (carCols-1) * 8) / 2
    
    for i, car in ipairs(Player.CAR_TYPES) do
        local col = (i-1) % carCols
        local lx = carStartX + col * (carW + 8)
        local ly = carY
        
        -- Achtergrond
        if i == Player.selectedCar then
            love.graphics.setColor(0.2, 0.6, 0.9, 0.9)
            love.graphics.rectangle("fill", lx, ly, carW, carH, 8, 8)
        else
            love.graphics.setColor(0.15, 0.15, 0.25, 0.8)
            love.graphics.rectangle("fill", lx, ly, carW, carH, 8, 8)
        end
        
        -- Mini auto tekenen
        local miniX = lx + 20
        local miniY = ly + 12
        local miniW = 70
        local miniH = 30
        
        love.graphics.setColor(car.bodyColor[1], car.bodyColor[2], car.bodyColor[3])
        if car.style == "sports" then
            love.graphics.rectangle("fill", miniX+10, miniY+5, miniW-18, miniH*0.4, 4,4)
            love.graphics.rectangle("fill", miniX, miniY+miniH*0.35, miniW, miniH*0.65, 3,3)
        else
            love.graphics.rectangle("fill", miniX+8, miniY, miniW-16, miniH*0.5, 5,5)
            love.graphics.rectangle("fill", miniX, miniY+miniH*0.35, miniW, miniH*0.65, 3,3)
        end
        
        -- Wielen
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", miniX+12, miniY+miniH, 8)
        love.graphics.circle("fill", miniX+miniW-12, miniY+miniH, 8)
        
        -- Naam
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(car.name, lx, ly+carH-18, carW, "center")
    end

    -- Start instructie
    love.graphics.setFont(fontMed)
    love.graphics.setColor(1,1,1, 0.55 + math.sin(love.timer.getTime()*2.5)*0.45)
    love.graphics.printf("Druk ENTER of SPATIE om te starten", px, py+ph-50, pw, "center")

    -- Leaderboard preview rechts van paneel
    local lbx = px + pw + 30
    if lbx + 320 < CFG.SCREEN_WIDTH - 20 then
        local lb  = scoreTracker.leaderboard
        local lby = py
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill", lbx, lby, 320, ph, 12,12)
        love.graphics.setFont(fontMed)
        love.graphics.setColor(1,0.88,0.15,1)
        love.graphics.print("TOP 10", lbx+16, lby+16)
        love.graphics.setFont(fontSmall)
        for i, entry in ipairs(lb) do
            if i > 10 then break end
            love.graphics.setColor(1,1,1,0.85)
            local name = entry.name or "???"
            local score = entry.score or 0
            love.graphics.print(string.format("%2d. %-8s %06d", i, name:sub(1,8), score), lbx+16, lby+52+(i-1)*28)
        end
        if #lb == 0 then
            love.graphics.setColor(0.6,0.6,0.7,0.8)
            love.graphics.print("Nog geen scores", lbx+16, lby+56)
        end
        
        -- Clear knop onderaan leaderboard
        local clearBtnY = lby + ph - 50
        love.graphics.setColor(0.7, 0.15, 0.1, 0.9)
        love.graphics.rectangle("fill", lbx+16, clearBtnY, 288, 36, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(fontSmall)
        love.graphics.printf("WISSEN", lbx+16, clearBtnY+8, 288, "center")
    end
end

-- ---------------------------------------------------------------
-- drawGameOver
-- ---------------------------------------------------------------
local function drawGameOver()
    local sw, sh = CFG.SCREEN_WIDTH, CFG.SCREEN_HEIGHT
    local cx, cy = sw/2, sh/2

    love.graphics.setColor(0,0,0,0.78)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local pw, ph = 600, 350
    local px, py = cx-pw/2, cy-ph/2

    love.graphics.setColor(0.07,0.09,0.17,0.97)
    love.graphics.rectangle("fill", px, py, pw, ph, 16,16)
    love.graphics.setColor(0.22,0.38,0.8,0.55)
    love.graphics.rectangle("line", px, py, pw, ph, 16,16)

    -- Titelbalk
    local totalLevels = Levels.getTotalLevels()
    local completed = distanceTraveled >= Levels.getTotalDistance()
    if completed then
        love.graphics.setColor(0.15, 0.75, 0.25, 1)
        love.graphics.rectangle("fill", px+24, py+18, pw-48, 60, 8,8)
        love.graphics.setFont(fontBig)
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf("GEWONNEN!", px+24, py+28, pw-48, "center")
    else
        love.graphics.setColor(0.85,0.10,0.10,1)
        love.graphics.rectangle("fill", px+24, py+18, pw-48, 60, 8,8)
        love.graphics.setFont(fontBig)
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf("GAME OVER", px+24, py+28, pw-48, "center")
    end

    -- Score
    love.graphics.setFont(fontBig)
    love.graphics.setColor(1,0.88,0.15,1)
    love.graphics.printf(string.format("SCORE:  %06d", scoreTracker.finalScore or 0),
        px, py+100, pw, "center")
    
    -- Level bereikt
    love.graphics.setFont(fontMed)
    local levelName = currentLevelData and currentLevelData.name or "STAD"
    love.graphics.setColor(0.5, 1, 0.6, 1)
    love.graphics.printf(string.format("Level %d/%d: %s", currentLevel, totalLevels, levelName), 
        px, py+155, pw, "center")

    -- Instructie
    love.graphics.setFont(fontMed)
    love.graphics.setColor(1,1,1, 0.55+math.sin(love.timer.getTime()*3)*0.45)
    love.graphics.printf("Druk op een toets om je naam in te vullen",
        px, py+ph-80, pw, "center")
    
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.7,0.7,0.8,0.7)
    love.graphics.printf("(voor het leaderboard)",
        px, py+ph-45, pw, "center")
end

-- ---------------------------------------------------------------
-- drawEnterName  –  naam invoer scherm
-- ---------------------------------------------------------------
local function drawEnterName()
    local sw, sh = CFG.SCREEN_WIDTH, CFG.SCREEN_HEIGHT
    local cx, cy = sw/2, sh/2

    love.graphics.setColor(0,0,0,0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local pw, ph = 700, 500
    local px, py = cx-pw/2, cy-ph/2

    love.graphics.setColor(0.07,0.09,0.17,0.97)
    love.graphics.rectangle("fill", px, py, pw, ph, 16,16)
    love.graphics.setColor(0.22,0.38,0.8,0.55)
    love.graphics.rectangle("line", px, py, pw, ph, 16,16)

    -- Titel
    love.graphics.setFont(fontBig)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.printf("VOER JE NAAM IN", px, py+30, pw, "center")
    
    -- Score
    love.graphics.setFont(fontMed)
    love.graphics.setColor(0.5, 1, 0.6, 1)
    love.graphics.printf(string.format("Score: %06d", scoreTracker.finalScore or 0), px, py+85, pw, "center")

    -- Naam invoer veld
    local fieldW, fieldH = 400, 60
    local fieldX = cx - fieldW/2
    local fieldY = py + 140
    
    love.graphics.setColor(0.12, 0.12, 0.2, 0.95)
    love.graphics.rectangle("fill", fieldX, fieldY, fieldW, fieldH, 8, 8)
    love.graphics.setColor(0.4, 0.5, 0.8, 0.8)
    love.graphics.rectangle("line", fieldX, fieldY, fieldW, fieldH, 8, 8)
    
    -- Naam tekst met cursor
    love.graphics.setFont(fontBig)
    love.graphics.setColor(1, 1, 1, 1)
    local displayName = playerName
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        displayName = displayName .. "_"
    end
    love.graphics.printf(displayName, fieldX, fieldY + 10, fieldW, "center")
    
    -- Instructies
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
    love.graphics.printf("Max 10 tekens  |  ENTER om op te slaan  |  ESC om over te slaan", 
        px, fieldY + 80, pw, "center")
    
    -- Leaderboard preview
    love.graphics.setFont(fontMed)
    love.graphics.setColor(1, 0.88, 0.15, 1)
    love.graphics.printf("HUIDIGE TOP 10", px, py + 260, pw, "center")
    
    local lb = scoreTracker.leaderboard
    love.graphics.setFont(fontSmall)
    local lbY = py + 300
    for i, entry in ipairs(lb) do
        if i > 5 then break end
        local name = entry.name or "???"
        local score = entry.score or 0
        love.graphics.setColor(1,1,1,0.85)
        love.graphics.printf(string.format("%d. %-10s %06d", i, name:sub(1,10), score), 
            px + 50, lbY + (i-1) * 28, pw - 100, "left")
    end
    
    -- Rechter kolom
    for i = 6, 10 do
        local entry = lb[i]
        if not entry then break end
        local name = entry.name or "???"
        local score = entry.score or 0
        love.graphics.setColor(1,1,1,0.85)
        love.graphics.printf(string.format("%d. %-10s %06d", i, name:sub(1,10), score), 
            px + pw/2, lbY + (i-6) * 28, pw/2 - 50, "left")
    end
end

-- ---------------------------------------------------------------
-- love.draw  –  met schaaltransformatie voor responsief scherm
-- ---------------------------------------------------------------
function love.draw()
    local winW, winH = love.graphics.getDimensions()
    
    -- Eerst letterbox achtergrond tekenen (zwarte balken)
    love.graphics.clear(0, 0, 0)
    
    -- Sla huidige transform op en pas schaling toe
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    
    -- Teken game op virtuele 1920x1080 canvas
    love.graphics.setColor(0.04, 0.06, 0.12)
    love.graphics.rectangle("fill", 0, 0, BASE_WIDTH, BASE_HEIGHT)

    if gameState == STATE.MENU then
        drawMenu()
        love.graphics.pop()
        return
    end
    
    if gameState == STATE.ENTER_NAME then
        drawEnterName()
        love.graphics.pop()
        return
    end

    drawBackground()
    drawRoad()
    Obstacle.drawAll(obstacleMgr)
    player:draw()

    drawHUD()
    drawProgressBar()
    drawLeaderboard()
    drawTouchButtons()

    if gameState == STATE.GAMEOVER then
        drawGameOver()
    end
    
    -- Herstel transform
    love.graphics.pop()
end
