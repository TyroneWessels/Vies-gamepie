-- =============================================================
-- obstacle.lua
-- GROUND_Y = bovenkant asfalt.
-- Obstakels staan OP het asfalt: y = groundY - height
-- Ondersteunt meerdere thema's en obstakel types
-- =============================================================

local Obstacle = {}
Obstacle.__index = Obstacle

local C = {
    MIN_SPAWN   = 1.4,
    MAX_SPAWN   = 3.0,
    MIN_W       = 50,
    MAX_W       = 100,
    MIN_H       = 60,
    MAX_H       = 130,
    SPAWN_OFS   = 150,
    CLEANUP_X   = -200,
    BASE_SPEED  = 480,
}

-- Alle obstakel types met hun kleuren
local COLORS = {
    -- Stad thema
    rock    = { { 0.50, 0.46, 0.42 }, { 0.36, 0.32, 0.28 } },
    barrel  = { { 0.90, 0.20, 0.08 }, { 0.62, 0.14, 0.05 } },
    barrier = { { 1.00, 0.78, 0.00 }, { 0.82, 0.52, 0.00 } },
    -- Woestijn thema
    cactus     = { { 0.20, 0.55, 0.20 }, { 0.15, 0.40, 0.15 } },
    tumbleweed = { { 0.65, 0.50, 0.30 }, { 0.50, 0.38, 0.22 } },
    -- Bos thema
    tree     = { { 0.30, 0.20, 0.10 }, { 0.18, 0.55, 0.22 } },
    log      = { { 0.45, 0.28, 0.12 }, { 0.35, 0.20, 0.08 } },
    mushroom = { { 0.85, 0.15, 0.15 }, { 0.95, 0.90, 0.80 } },
    -- Sneeuw thema
    snowman  = { { 0.95, 0.95, 0.98 }, { 0.20, 0.20, 0.25 } },
    iceberg  = { { 0.70, 0.85, 0.95 }, { 0.50, 0.70, 0.85 } },
    penguin  = { { 0.10, 0.10, 0.15 }, { 0.95, 0.95, 0.98 } },
    -- Ruimte thema
    meteor   = { { 0.40, 0.30, 0.25 }, { 0.80, 0.40, 0.15 } },
    alien    = { { 0.30, 0.85, 0.30 }, { 0.15, 0.15, 0.15 } },
    crater   = { { 0.25, 0.22, 0.30 }, { 0.15, 0.12, 0.20 } },
    -- Vulkaan thema
    lavarock = { { 0.30, 0.15, 0.10 }, { 0.95, 0.40, 0.10 } },
    fireball = { { 0.95, 0.55, 0.10 }, { 0.95, 0.20, 0.05 } },
    crack    = { { 0.20, 0.10, 0.08 }, { 0.95, 0.35, 0.05 } },
}

-- Grootte variaties per type (min/max multipliers)
local SIZE_VARIANTS = {
    -- Stad - standaard variatie
    rock    = { wMin = 0.7, wMax = 1.1, hMin = 0.6, hMax = 1.0 },
    barrel  = { wMin = 0.6, wMax = 0.9, hMin = 0.7, hMax = 1.1 },
    barrier = { wMin = 0.9, wMax = 1.5, hMin = 0.5, hMax = 0.8 },
    -- Woestijn - cactus iets groter, tumbleweed klein
    cactus     = { wMin = 0.7, wMax = 1.1, hMin = 0.9, hMax = 1.3 },
    tumbleweed = { wMin = 0.5, wMax = 0.8, hMin = 0.5, hMax = 0.8 },
    -- Bos - bomen normaal, paddenstoelen klein
    tree     = { wMin = 0.8, wMax = 1.2, hMin = 0.9, hMax = 1.3 },
    log      = { wMin = 1.0, wMax = 1.5, hMin = 0.4, hMax = 0.6 },
    mushroom = { wMin = 0.4, wMax = 0.7, hMin = 0.5, hMax = 0.8 },
    -- Sneeuw - sneeuwpop normaal, pinguin klein
    snowman  = { wMin = 0.7, wMax = 1.0, hMin = 0.8, hMax = 1.2 },
    iceberg  = { wMin = 1.0, wMax = 1.4, hMin = 0.7, hMax = 1.0 },
    penguin  = { wMin = 0.5, wMax = 0.7, hMin = 0.5, hMax = 0.8 },
    -- Ruimte - variabel maar kleiner
    meteor   = { wMin = 0.6, wMax = 1.1, hMin = 0.6, hMax = 1.1 },
    alien    = { wMin = 0.5, wMax = 0.9, hMin = 0.7, hMax = 1.0 },
    crater   = { wMin = 1.0, wMax = 1.5, hMin = 0.3, hMax = 0.5 },
    -- Vulkaan - kleiner gemaakt
    lavarock = { wMin = 0.8, wMax = 1.3, hMin = 0.7, hMax = 1.1 },
    fireball = { wMin = 0.5, wMax = 0.8, hMin = 0.5, hMax = 0.8 },
    crack    = { wMin = 1.2, wMax = 1.8, hMin = 0.3, hMax = 0.4 },
}

-- Speciale bewegings-types
local SPECIAL_BEHAVIORS = {
    tumbleweed = "rolling",    -- Rolt
    penguin    = "hopping",    -- Springt
    fireball   = "floating",   -- Zweeft op/neer
    meteor     = "falling",    -- Valt schuin
    alien      = "wobbling",   -- Wiebelt
}

function Obstacle.newManager(screenWidth, groundY)
    assert(type(screenWidth)=="number" and screenWidth>0)
    assert(type(groundY)=="number")
    return { 
        list={}, 
        spawnTimer=1.8, 
        screenWidth=screenWidth, 
        groundY=groundY,
        obstacleTypes = { "rock", "barrel", "barrier" },
        spawnMin = C.MIN_SPAWN,
        spawnMax = C.MAX_SPAWN,
    }
end

-- Update manager configuratie voor nieuw level
function Obstacle.setLevelConfig(mgr, obstacleTypes, spawnMin, spawnMax)
    mgr.obstacleTypes = obstacleTypes or { "rock", "barrel", "barrier" }
    mgr.spawnMin = spawnMin or C.MIN_SPAWN
    mgr.spawnMax = spawnMax or C.MAX_SPAWN
end

function Obstacle.newInstance(screenWidth, groundY, obstacleTypes)
    local self = setmetatable({}, Obstacle)
    
    -- Kies een type uit de beschikbare types
    local types = obstacleTypes or { "rock", "barrel", "barrier" }
    self.kind = types[math.random(#types)]
    
    -- Pas grootte aan op basis van type
    local sizeVar = SIZE_VARIANTS[self.kind] or { wMin=1, wMax=1, hMin=1, hMax=1 }
    local baseW = math.random(C.MIN_W, C.MAX_W)
    local baseH = math.random(C.MIN_H, C.MAX_H)
    local wMult = sizeVar.wMin + math.random() * (sizeVar.wMax - sizeVar.wMin)
    local hMult = sizeVar.hMin + math.random() * (sizeVar.hMax - sizeVar.hMin)
    self.w = math.floor(baseW * wMult)
    self.h = math.floor(baseH * hMult)
    
    self.x = screenWidth + C.SPAWN_OFS
    -- Onderkant obstakel staat op groundY (precies op het asfalt)
    self.baseY = groundY - self.h
    self.y = self.baseY
    
    -- Speciale eigenschappen voor animatie
    self.behavior = SPECIAL_BEHAVIORS[self.kind]
    self.animTime = math.random() * math.pi * 2  -- Random startfase
    self.rotation = 0
    
    return self
end

function Obstacle.updateManager(mgr, dt, speed)
    local sf = speed / C.BASE_SPEED
    for _, o in ipairs(mgr.list) do
        o.x = o.x - speed * sf * dt
        
        -- Update animatie tijd
        o.animTime = (o.animTime or 0) + dt
        
        -- Speciale bewegingen
        if o.behavior == "rolling" then
            -- Tumbleweed rolt
            o.rotation = (o.rotation or 0) + dt * 5
        elseif o.behavior == "hopping" then
            -- Pinguin springt
            local hop = math.abs(math.sin(o.animTime * 4)) * 20
            o.y = o.baseY - hop
        elseif o.behavior == "floating" then
            -- Vuurbal zweeft op en neer
            local float = math.sin(o.animTime * 3) * 15
            o.y = o.baseY - 20 + float
        elseif o.behavior == "wobbling" then
            -- Alien wiebelt
            o.rotation = math.sin(o.animTime * 5) * 0.15
        end
    end
    for i = #mgr.list, 1, -1 do
        if mgr.list[i].x + mgr.list[i].w < C.CLEANUP_X then
            table.remove(mgr.list, i)
        end
    end
    mgr.spawnTimer = mgr.spawnTimer - dt
    if mgr.spawnTimer <= 0 then
        table.insert(mgr.list, Obstacle.newInstance(mgr.screenWidth, mgr.groundY, mgr.obstacleTypes))
        mgr.spawnTimer = mgr.spawnMin + math.random() * (mgr.spawnMax - mgr.spawnMin)
    end
end

function Obstacle.drawAll(mgr)
    for _, o in ipairs(mgr.list) do
        Obstacle.drawOne(o)
    end
end

function Obstacle.drawOne(o)
    local x, y, w, h = math.floor(o.x), math.floor(o.y), o.w, o.h
    local c = COLORS[o.kind] or COLORS.rock

    -- Kleine schaduw op grond
    love.graphics.setColor(0,0,0,0.20)
    love.graphics.ellipse("fill", x+w/2, y+h+4, w*0.44, 7)

    -- STAD obstakels
    if o.kind == "rock" then
        love.graphics.setColor(c[1])
        love.graphics.polygon("fill",
            x+w*0.18, y+h,   x,       y+h*0.58,
            x+w*0.10, y+h*0.18, x+w*0.38, y,
            x+w*0.68, y+h*0.10, x+w, y+h*0.48,
            x+w*0.90, y+h)
        love.graphics.setColor(c[2])
        love.graphics.polygon("fill",
            x+w*0.36,y, x+w*0.54,y+h*0.30, x+w*0.26,y+h*0.42, x+w*0.12,y+h*0.20)

    elseif o.kind == "barrel" then
        love.graphics.setColor(c[1])
        love.graphics.rectangle("fill", x, y, w, h, 7,7)
        love.graphics.setColor(c[2])
        for _, f in ipairs({0.20,0.50,0.80}) do
            love.graphics.rectangle("fill", x, y+h*f-4, w, 7)
        end
        love.graphics.setColor(0.90,0.86,0.80)
        love.graphics.rectangle("fill", x+3, y, w-6, h*0.12, 4,4)

    elseif o.kind == "barrier" then
        love.graphics.setColor(c[1])
        love.graphics.rectangle("fill", x, y, w, h, 4,4)
        love.graphics.setColor(0.08,0.08,0.08,0.60)
        local sc, sw2 = 5, w/5
        for i = 0, sc-1 do
            if i%2==0 then love.graphics.rectangle("fill", x+i*sw2, y, sw2, h) end
        end

    -- WOESTIJN obstakels
    elseif o.kind == "cactus" then
        love.graphics.setColor(c[1])
        -- Stam
        love.graphics.rectangle("fill", x+w*0.35, y+h*0.2, w*0.3, h*0.8, 4,4)
        -- Armen
        love.graphics.rectangle("fill", x, y+h*0.35, w*0.35, h*0.15, 3,3)
        love.graphics.rectangle("fill", x+w*0.65, y+h*0.5, w*0.35, h*0.12, 3,3)
        love.graphics.rectangle("fill", x, y+h*0.35, w*0.12, h*0.35, 3,3)
        love.graphics.rectangle("fill", x+w*0.88, y+h*0.5, w*0.12, h*0.3, 3,3)
        -- Highlight
        love.graphics.setColor(c[2])
        love.graphics.rectangle("fill", x+w*0.42, y+h*0.25, w*0.08, h*0.65, 2,2)

    elseif o.kind == "tumbleweed" then
        -- Roterende tumbleweed
        love.graphics.push()
        love.graphics.translate(x+w/2, y+h/2)
        love.graphics.rotate(o.rotation or 0)
        love.graphics.setColor(c[1])
        love.graphics.circle("fill", 0, 0, math.min(w,h)*0.45)
        love.graphics.setColor(c[2])
        -- Takjes
        for i = 0, 7 do
            local ang = i * math.pi / 4
            local r = math.min(w,h)*0.35
            love.graphics.line(0, 0, math.cos(ang)*r, math.sin(ang)*r)
        end
        love.graphics.pop()

    -- BOS obstakels
    elseif o.kind == "tree" then
        -- Stam
        love.graphics.setColor(c[1])
        love.graphics.rectangle("fill", x+w*0.35, y+h*0.5, w*0.3, h*0.5, 3,3)
        -- Kroon (driehoek)
        love.graphics.setColor(c[2])
        love.graphics.polygon("fill",
            x+w*0.5, y,
            x, y+h*0.55,
            x+w, y+h*0.55)
        love.graphics.polygon("fill",
            x+w*0.5, y+h*0.15,
            x+w*0.1, y+h*0.45,
            x+w*0.9, y+h*0.45)

    elseif o.kind == "log" then
        love.graphics.setColor(c[1])
        love.graphics.rectangle("fill", x, y+h*0.3, w, h*0.7, 8,8)
        -- Jaarringen
        love.graphics.setColor(c[2])
        love.graphics.ellipse("fill", x+5, y+h*0.65, 5, h*0.25)
        love.graphics.setColor(c[1][1]*0.8, c[1][2]*0.8, c[1][3]*0.8)
        love.graphics.ellipse("fill", x+5, y+h*0.65, 3, h*0.15)

    elseif o.kind == "mushroom" then
        -- Stam
        love.graphics.setColor(c[2])
        love.graphics.rectangle("fill", x+w*0.35, y+h*0.5, w*0.3, h*0.5, 4,4)
        -- Hoed
        love.graphics.setColor(c[1])
        love.graphics.ellipse("fill", x+w*0.5, y+h*0.45, w*0.5, h*0.35)
        -- Stippen
        love.graphics.setColor(1,1,1,0.9)
        love.graphics.circle("fill", x+w*0.3, y+h*0.35, 5)
        love.graphics.circle("fill", x+w*0.55, y+h*0.22, 4)
        love.graphics.circle("fill", x+w*0.7, y+h*0.38, 4)

    -- SNEEUW obstakels
    elseif o.kind == "snowman" then
        love.graphics.setColor(c[1])
        -- Ballen
        love.graphics.circle("fill", x+w*0.5, y+h*0.8, w*0.35)
        love.graphics.circle("fill", x+w*0.5, y+h*0.45, w*0.28)
        love.graphics.circle("fill", x+w*0.5, y+h*0.18, w*0.2)
        -- Ogen en knoopjes
        love.graphics.setColor(c[2])
        love.graphics.circle("fill", x+w*0.4, y+h*0.14, 3)
        love.graphics.circle("fill", x+w*0.6, y+h*0.14, 3)
        love.graphics.circle("fill", x+w*0.5, y+h*0.40, 4)
        love.graphics.circle("fill", x+w*0.5, y+h*0.50, 4)
        -- Wortel neus
        love.graphics.setColor(0.95, 0.50, 0.15)
        love.graphics.polygon("fill", x+w*0.5, y+h*0.18, x+w*0.75, y+h*0.2, x+w*0.5, y+h*0.22)

    elseif o.kind == "iceberg" then
        love.graphics.setColor(c[1])
        love.graphics.polygon("fill",
            x+w*0.5, y,
            x, y+h,
            x+w*0.3, y+h*0.6,
            x+w*0.7, y+h*0.7,
            x+w, y+h)
        love.graphics.setColor(c[2])
        love.graphics.polygon("fill",
            x+w*0.5, y+h*0.15,
            x+w*0.2, y+h*0.7,
            x+w*0.6, y+h*0.55)

    elseif o.kind == "penguin" then
        -- Body
        love.graphics.setColor(c[1])
        love.graphics.ellipse("fill", x+w*0.5, y+h*0.55, w*0.35, h*0.45)
        -- Buik
        love.graphics.setColor(c[2])
        love.graphics.ellipse("fill", x+w*0.5, y+h*0.6, w*0.22, h*0.35)
        -- Hoofd
        love.graphics.setColor(c[1])
        love.graphics.circle("fill", x+w*0.5, y+h*0.15, w*0.25)
        -- Snavel
        love.graphics.setColor(0.95, 0.55, 0.15)
        love.graphics.polygon("fill", x+w*0.5, y+h*0.15, x+w*0.72, y+h*0.2, x+w*0.5, y+h*0.25)
        -- Ogen
        love.graphics.setColor(1,1,1)
        love.graphics.circle("fill", x+w*0.4, y+h*0.1, 4)
        love.graphics.setColor(0,0,0)
        love.graphics.circle("fill", x+w*0.4, y+h*0.1, 2)

    -- RUIMTE obstakels
    elseif o.kind == "meteor" then
        love.graphics.setColor(c[1])
        love.graphics.polygon("fill",
            x+w*0.2, y+h*0.3,
            x, y+h*0.6,
            x+w*0.15, y+h,
            x+w*0.6, y+h*0.85,
            x+w, y+h*0.4,
            x+w*0.7, y)
        -- Gloeiende rand
        love.graphics.setColor(c[2])
        love.graphics.polygon("fill",
            x+w*0.8, y+h*0.1,
            x+w, y+h*0.4,
            x+w*0.85, y+h*0.35)
        -- Kraters
        love.graphics.setColor(0.25, 0.20, 0.18)
        love.graphics.circle("fill", x+w*0.4, y+h*0.5, 6)
        love.graphics.circle("fill", x+w*0.6, y+h*0.7, 4)

    elseif o.kind == "alien" then
        -- Wiebelende alien
        love.graphics.push()
        love.graphics.translate(x+w*0.5, y+h)
        love.graphics.rotate(o.rotation or 0)
        love.graphics.translate(-w*0.5, -h)
        -- Body
        love.graphics.setColor(c[1])
        love.graphics.ellipse("fill", w*0.5, h*0.65, w*0.35, h*0.35)
        -- Hoofd
        love.graphics.ellipse("fill", w*0.5, h*0.25, w*0.4, h*0.25)
        -- Grote ogen
        love.graphics.setColor(c[2])
        love.graphics.ellipse("fill", w*0.32, h*0.2, w*0.15, h*0.12)
        love.graphics.ellipse("fill", w*0.68, h*0.2, w*0.15, h*0.12)
        -- Pupillen (kijken rond)
        local eyeOffset = math.sin((o.animTime or 0) * 2) * w * 0.05
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.circle("fill", w*0.35 + eyeOffset, h*0.2, 4)
        love.graphics.circle("fill", w*0.65 + eyeOffset, h*0.2, 4)
        -- Antennes
        love.graphics.setColor(c[1])
        love.graphics.line(w*0.3, h*0.05, w*0.35, h*0.15)
        love.graphics.line(w*0.7, h*0.05, w*0.65, h*0.15)
        love.graphics.circle("fill", w*0.3, h*0.03, 4)
        love.graphics.circle("fill", w*0.7, h*0.03, 4)
        love.graphics.pop()

    elseif o.kind == "crater" then
        love.graphics.setColor(c[1])
        love.graphics.ellipse("fill", x+w*0.5, y+h*0.7, w*0.5, h*0.3)
        love.graphics.setColor(c[2])
        love.graphics.ellipse("fill", x+w*0.5, y+h*0.65, w*0.35, h*0.2)
        -- Rand
        love.graphics.setColor(c[1][1]*1.2, c[1][2]*1.2, c[1][3]*1.2)
        love.graphics.ellipse("line", x+w*0.5, y+h*0.7, w*0.48, h*0.28)

    -- VULKAAN obstakels
    elseif o.kind == "lavarock" then
        love.graphics.setColor(c[1])
        love.graphics.polygon("fill",
            x+w*0.2, y+h,
            x, y+h*0.5,
            x+w*0.3, y,
            x+w*0.7, y+h*0.1,
            x+w, y+h*0.6,
            x+w*0.85, y+h)
        -- Gloeiende scheuren
        love.graphics.setColor(c[2])
        love.graphics.line(x+w*0.3, y+h*0.2, x+w*0.4, y+h*0.8)
        love.graphics.line(x+w*0.5, y+h*0.4, x+w*0.7, y+h*0.9)
        love.graphics.setLineWidth(3)
        love.graphics.line(x+w*0.35, y+h*0.3, x+w*0.45, y+h*0.7)
        love.graphics.setLineWidth(1)

    elseif o.kind == "fireball" then
        -- Vuur kern
        love.graphics.setColor(c[1])
        love.graphics.circle("fill", x+w*0.5, y+h*0.5, math.min(w,h)*0.4)
        -- Binnen kern
        love.graphics.setColor(1, 0.95, 0.5)
        love.graphics.circle("fill", x+w*0.5, y+h*0.5, math.min(w,h)*0.2)
        -- Vlammen
        love.graphics.setColor(c[2])
        for i = 0, 4 do
            local ang = i * math.pi * 2 / 5 + love.timer.getTime() * 2
            local cx, cy = x+w*0.5, y+h*0.5
            local r = math.min(w,h)*0.35
            love.graphics.circle("fill", cx + math.cos(ang)*r, cy + math.sin(ang)*r*0.8, 8)
        end

    elseif o.kind == "crack" then
        -- Grond met scheur
        love.graphics.setColor(c[1])
        love.graphics.rectangle("fill", x, y+h*0.6, w, h*0.4, 3,3)
        -- Lava in scheur
        love.graphics.setColor(c[2])
        love.graphics.polygon("fill",
            x+w*0.3, y+h*0.6,
            x+w*0.4, y+h,
            x+w*0.5, y+h*0.65,
            x+w*0.6, y+h,
            x+w*0.7, y+h*0.6)
        -- Glow
        love.graphics.setColor(1, 0.5, 0.2, 0.4)
        love.graphics.polygon("fill",
            x+w*0.25, y+h*0.5,
            x+w*0.35, y+h,
            x+w*0.65, y+h,
            x+w*0.75, y+h*0.5)

    else
        -- Fallback: basic rock
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", x, y, w, h, 6,6)
    end
end

function Obstacle.checkCollision(mgr, px,py,pw,ph)
    for _, o in ipairs(mgr.list) do
        if px < o.x+o.w and px+pw > o.x
        and py < o.y+o.h and py+ph > o.y then
            return true
        end
    end
    return false
end

function Obstacle.reset(mgr)
    mgr.list = {}; mgr.spawnTimer = 1.8
end

return Obstacle
