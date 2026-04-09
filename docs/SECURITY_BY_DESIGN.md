# Security by Design - AutoDash

## Inleiding
Dit document beschrijft de beveiligingsmaatregelen die zijn toegepast in AutoDash volgens het "Security by Design" principe. Hoewel dit een offline game is, zijn beveiligingsprincipes toegepast om robuustheid en integriteit te waarborgen.

---

## 1. Input Validatie

### 1.1 Type Checking
```lua
-- Voorbeeld uit player.lua
function Player.new(groundY, carType)
    assert(type(groundY) == "number")  -- ✓ Validatie
    -- ...
end

-- Voorbeeld uit obstacle.lua  
function Obstacle.newManager(screenWidth, groundY)
    assert(type(screenWidth)=="number" and screenWidth>0)
    assert(type(groundY)=="number")
    -- ...
end
```

**Principe**: Alle externe parameters worden gevalideerd op type en waardebereik voordat ze worden gebruikt.

### 1.2 Naam Invoer Sanitatie
```lua
-- Uit score.lua
function Score:saveWithName(name)
    if not self.finalScore then return end
    name = name or "???"
    if #name == 0 then name = "???" end
    -- Voorkomt lege of nil namen
end
```

**Principe**: Gebruikersinvoer wordt genormaliseerd naar veilige standaardwaarden.

### 1.3 Key Event Filtering
```lua
-- Uit main.lua
function love.keypressed(key)
    if type(key) ~= "string" then return end  -- ✓ Type check
    -- Alleen string keys worden verwerkt
end
```

---

## 2. Bounds Checking

### 2.1 Array Index Validatie
```lua
-- Uit levels.lua
function Levels.getPlayLevel(orderPosition)
    local idx = orderPosition
    if idx < 1 then idx = 1 end              -- ✓ Minimum bound
    if idx > #Levels.playOrder then 
        idx = #Levels.playOrder              -- ✓ Maximum bound
    end
    return Levels.data[levelIdx]
end
```

### 2.2 Leaderboard Limiet
```lua
-- Uit score.lua
function Score.addEntry(list, value, name)
    table.insert(list, { name = name, score = math.floor(value) })
    table.sort(list, function(a,b) return a.score > b.score end)
    while #list > C.MAX_LB do 
        table.remove(list)  -- ✓ Voorkomt onbeperkte groei
    end
end
```

**Principe**: Lijsten en arrays worden begrensd om geheugenuitputting te voorkomen.

---

## 3. Defensief Programmeren

### 3.1 Null/Nil Checks
```lua
-- Uit player.lua
local carData = Player.CAR_TYPES[self.carType] or Player.CAR_TYPES[1]

-- Uit obstacle.lua
local types = obstacleTypes or { "rock", "barrel", "barrier" }

-- Uit levels.lua
if not Levels.playOrder then
    Levels.createRandomOrder(1)
end
```

**Principe**: Altijd fallback waarden gebruiken bij ontbrekende data.

### 3.2 Dood-Speler Checks
```lua
-- Uit player.lua
function Player:jump()
    if self.isDead or self.isJumping then return end
    -- Voorkomt acties op dode speler
end

function Player:update(dt)
    if self.isDead then return end
    -- Stopt updates wanneer speler dood is
end
```

---

## 4. Veilige Bestandsoperaties

### 4.1 Robuust Bestand Laden
```lua
-- Uit score.lua
function Score.loadLeaderboard()
    local data = love.filesystem.read(C.LB_FILE)
    local list = {}
    if data then  -- ✓ Check of bestand bestaat
        for line in data:gmatch("[^\n]+") do
            local name, scoreStr = line:match("^([^:]+):(%d+)$")
            if name and scoreStr then  -- ✓ Valideer formaat
                local v = tonumber(scoreStr)
                if v and v >= 0 then   -- ✓ Valideer waarde
                    table.insert(list, { 
                        name = name, 
                        score = math.floor(v) 
                    })
                end
            end
        end
    end
    return list
end
```

**Principes toegepast**:
- Graceful degradation bij ontbrekende bestanden
- Strict parsing met regex validatie
- Negatieve scores worden genegeerd
- Backward compatibility met oude formaten

### 4.2 Sandbox Bestandssysteem
LÖVE2D gebruikt automatisch een sandbox voor bestandsoperaties:
- Bestanden worden opgeslagen in `%APPDATA%/autodash/` (Windows)
- Geen toegang tot systeembestanden
- Alleen lezen/schrijven binnen game directory

---

## 5. State Machine Integriteit

### 5.1 Gedefinieerde Staten
```lua
local STATE = { 
    MENU = "menu", 
    PLAYING = "playing", 
    GAMEOVER = "gameover", 
    ENTER_NAME = "enter_name" 
}
```

### 5.2 State-Specifieke Input Handling
```lua
local function handlePress(sx, sy)
    if gameState == STATE.MENU then
        -- Alleen menu acties toegestaan
    end
    if gameState == STATE.GAMEOVER then
        -- Alleen gameover acties toegestaan
    end
    if gameState == STATE.PLAYING then
        -- Alleen game acties toegestaan
    end
end
```

**Principe**: Input wordt alleen verwerkt als relevant voor huidige state.

---

## 6. Memory Safety

### 6.1 Obstakel Cleanup
```lua
-- Uit obstacle.lua
for i = #mgr.list, 1, -1 do
    if mgr.list[i].x + mgr.list[i].w < C.CLEANUP_X then
        table.remove(mgr.list, i)  -- ✓ Verwijder off-screen obstakels
    end
end
```

### 6.2 Timer Clamping
```lua
-- Uit player.lua
if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
end
```

**Principe**: Numerieke waarden worden begrensd om overflow te voorkomen.

---

## 7. Coördinaten Transformatie

### 7.1 Veilige Scherm-naar-Game Conversie
```lua
local function screenToGame(sx, sy)
    local gx = (sx - offsetX) / scale
    local gy = (sy - offsetY) / scale
    return gx, gy
end
```

**Principe**: Input coördinaten worden correct getransformeerd ongeacht schermresolutie.

---

## 8. Configuratie Isolatie

### 8.1 Constanten in Lokale Scope
```lua
-- Alle constanten zijn lokaal gedeclareerd
local C = {
    BASE_SPEED     = 480,
    BOOST_SPEED    = 860,
    -- ...
}
```

**Principe**: Constanten zijn niet globaal toegankelijk, voorkomt onbedoelde modificatie.

---

## 9. Samenvatting Beveiligingsprincipes

| Principe | Implementatie | Status |
|----------|---------------|--------|
| Input Validatie | `assert()`, type checks | ✅ |
| Bounds Checking | Array limits, min/max | ✅ |
| Null Safety | or-fallbacks, if-checks | ✅ |
| State Isolation | State machine | ✅ |
| Memory Management | Cleanup routines | ✅ |
| File Sandboxing | LÖVE2D sandbox | ✅ |
| Data Sanitization | Regex parsing | ✅ |
| Error Handling | Graceful degradation | ✅ |

---

## 10. Aanbevelingen voor Verbetering

### Hoge Prioriteit
1. **Score Encryptie**: Leaderboard scores kunnen lokaal worden gemanipuleerd
   ```lua
   -- Suggestie: Hash toevoegen voor integriteit
   local function hashScore(name, score)
       return md5(name .. score .. SECRET_KEY)
   end
   ```

2. **Naam Lengte Limiet**: Voeg maximale lengte toe
   ```lua
   if #name > 20 then name = name:sub(1, 20) end
   ```

### Gemiddelde Prioriteit
3. **Logging**: Voeg error logging toe voor debugging
4. **Rate Limiting**: Beperk bestandsschrijfoperaties

### Lage Prioriteit
5. **Obfuscatie**: Lua bytecode compilatie voor distributie
6. **Checksums**: Valideer game assets bij laden

---

## Conclusie
AutoDash implementeert fundamentele Security by Design principes ondanks zijn status als offline game. De code is defensief geschreven met input validatie, bounds checking, en graceful error handling. Voor een productie-release met online leaderboards zouden aanvullende maatregelen nodig zijn.
