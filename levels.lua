-- =============================================================
-- levels.lua  –  Level definitie met thema's en obstakels
-- Elk level heeft een unieke achtergrond, kleuren en obstakels
-- =============================================================

local Levels = {}

-- Level configuraties met thema's
Levels.data = {
    -- LEVEL 1: Stad (origineel thema)
    {
        name = "STAD",
        distance = 5000,
        theme = {
            skyTop    = { 0.06, 0.10, 0.22 },
            skyBottom = { 0.13, 0.24, 0.45 },
            hillFar   = { 0.10, 0.18, 0.34 },
            hillNear  = { 0.08, 0.14, 0.27 },
            road      = { 0.21, 0.21, 0.23 },
            stripe    = { 1, 1, 1, 0.40 },
        },
        obstacles = { "rock", "barrel", "barrier" },
        spawnMin = 1.4,
        spawnMax = 3.0,
    },

    -- LEVEL 2: Woestijn
    {
        name = "WOESTIJN",
        distance = 6000,
        theme = {
            skyTop    = { 0.95, 0.65, 0.35 },
            skyBottom = { 0.85, 0.45, 0.25 },
            hillFar   = { 0.85, 0.55, 0.30 },
            hillNear  = { 0.75, 0.45, 0.20 },
            road      = { 0.60, 0.50, 0.35 },
            stripe    = { 1, 0.95, 0.85, 0.50 },
        },
        obstacles = { "cactus", "tumbleweed", "rock" },
        spawnMin = 1.2,
        spawnMax = 2.5,
    },

    -- LEVEL 3: Bos
    {
        name = "BOS",
        distance = 6500,
        theme = {
            skyTop    = { 0.15, 0.30, 0.15 },
            skyBottom = { 0.10, 0.22, 0.12 },
            hillFar   = { 0.12, 0.35, 0.15 },
            hillNear  = { 0.08, 0.28, 0.10 },
            road      = { 0.25, 0.20, 0.15 },
            stripe    = { 0.9, 0.9, 0.7, 0.45 },
        },
        obstacles = { "tree", "log", "mushroom" },
        spawnMin = 1.0,
        spawnMax = 2.2,
    },

    -- LEVEL 4: Sneeuw
    {
        name = "SNEEUW",
        distance = 7000,
        theme = {
            skyTop    = { 0.70, 0.80, 0.90 },
            skyBottom = { 0.85, 0.90, 0.95 },
            hillFar   = { 0.90, 0.92, 0.95 },
            hillNear  = { 0.85, 0.88, 0.92 },
            road      = { 0.75, 0.78, 0.82 },
            stripe    = { 0.3, 0.4, 0.5, 0.60 },
        },
        obstacles = { "snowman", "iceberg", "penguin" },
        spawnMin = 1.1,
        spawnMax = 2.0,
    },

    -- LEVEL 5: Nacht / Space
    {
        name = "RUIMTE",
        distance = 8000,
        theme = {
            skyTop    = { 0.02, 0.02, 0.08 },
            skyBottom = { 0.05, 0.05, 0.15 },
            hillFar   = { 0.08, 0.06, 0.18 },
            hillNear  = { 0.12, 0.08, 0.22 },
            road      = { 0.15, 0.12, 0.25 },
            stripe    = { 0.6, 0.4, 1, 0.55 },
        },
        obstacles = { "meteor", "alien", "crater" },
        spawnMin = 0.9,
        spawnMax = 1.8,
    },

    -- LEVEL 6: Lava / Vulkaan
    {
        name = "VULKAAN",
        distance = 9000,
        theme = {
            skyTop    = { 0.15, 0.05, 0.02 },
            skyBottom = { 0.35, 0.12, 0.05 },
            hillFar   = { 0.25, 0.08, 0.05 },
            hillNear  = { 0.40, 0.15, 0.08 },
            road      = { 0.18, 0.12, 0.10 },
            stripe    = { 1, 0.5, 0.2, 0.60 },
        },
        obstacles = { "lavarock", "fireball", "crack" },
        spawnMin = 0.8,
        spawnMax = 1.6,
    },
}

function Levels.getLevel(levelNum)
    local idx = math.min(levelNum, #Levels.data)
    return Levels.data[idx]
end

function Levels.getTotalLevels()
    return #Levels.data
end

function Levels.getTotalDistance()
    local total = 0
    for _, lvl in ipairs(Levels.data) do
        total = total + lvl.distance
    end
    return total
end

-- Huidige speelvolgorde (level indices)
Levels.playOrder = nil

-- Maak een random volgorde van levels, beginnend met startLevel
function Levels.createRandomOrder(startLevel)
    startLevel = startLevel or 1
    local order = { startLevel }
    
    -- Verzamel overige levels
    local remaining = {}
    for i = 1, #Levels.data do
        if i ~= startLevel then
            table.insert(remaining, i)
        end
    end
    
    -- Fisher-Yates shuffle
    for i = #remaining, 2, -1 do
        local j = math.random(1, i)
        remaining[i], remaining[j] = remaining[j], remaining[i]
    end
    
    -- Voeg geshuffelde levels toe aan order
    for _, idx in ipairs(remaining) do
        table.insert(order, idx)
    end
    
    Levels.playOrder = order
    return order
end

-- Haal level data op basis van positie in playOrder
function Levels.getPlayLevel(orderPosition)
    if not Levels.playOrder then
        Levels.createRandomOrder(1)
    end
    local idx = orderPosition
    if idx < 1 then idx = 1 end
    if idx > #Levels.playOrder then idx = #Levels.playOrder end
    local levelIdx = Levels.playOrder[idx]
    return Levels.data[levelIdx]
end

-- Bepaal welk level actief is op basis van afgelegde afstand (gebruikt playOrder)
function Levels.getLevelAtDistance(distance)
    if not Levels.playOrder then
        Levels.createRandomOrder(1)
    end
    
    local accum = 0
    for i, levelIdx in ipairs(Levels.playOrder) do
        local lvl = Levels.data[levelIdx]
        accum = accum + lvl.distance
        if distance < accum then
            return i, lvl, distance - (accum - lvl.distance)
        end
    end
    -- Laatste level blijft actief na voltooien
    local lastIdx = Levels.playOrder[#Levels.playOrder]
    return #Levels.playOrder, Levels.data[lastIdx], distance
end

return Levels
