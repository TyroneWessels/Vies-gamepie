-- =============================================================
-- score.lua  –  tijd, score, leaderboard top-10 met namen
-- =============================================================

local Score = {}
Score.__index = Score

local C = {
    POINTS_PER_SEC = 100,  -- Score gaat nu OMHOOG met tijd!
    MAX_LB         = 10,
    LB_FILE        = "leaderboard.txt",
}

function Score.new()
    local self = setmetatable({}, Score)
    self.elapsed     = 0
    self.finalScore  = nil
    self.leaderboard = Score.loadLeaderboard()
    self.pendingName = nil  -- Naam die nog ingevuld moet worden
    return self
end

function Score:update(dt)
    self.elapsed = self.elapsed + dt
end

function Score:getCurrentScore()
    return math.floor(self.elapsed * C.POINTS_PER_SEC)
end

function Score:finalize()
    if self.finalScore then return end
    self.finalScore = self:getCurrentScore()
    -- Sla score nog niet op - wacht op naam
end

-- Voeg score toe met naam
function Score:saveWithName(name)
    if not self.finalScore then return end
    name = name or "???"
    if #name == 0 then name = "???" end
    Score.addEntry(self.leaderboard, self.finalScore, name)
    Score.saveLeaderboard(self.leaderboard)
end

function Score:reset()
    self.elapsed    = 0
    self.finalScore = nil
    self.leaderboard = Score.loadLeaderboard()
end

function Score:getRank()
    if not self.finalScore then return nil end
    for i, entry in ipairs(self.leaderboard) do
        if entry.score == self.finalScore then return i end
    end
    return nil
end

-- Laad leaderboard met namen (formaat: "NAAM:SCORE" per regel)
function Score.loadLeaderboard()
    local data = love.filesystem.read(C.LB_FILE)
    local list = {}
    if data then
        for line in data:gmatch("[^\n]+") do
            -- Probeer naam:score formaat
            local name, scoreStr = line:match("^([^:]+):(%d+)$")
            if name and scoreStr then
                local v = tonumber(scoreStr)
                if v and v >= 0 then 
                    table.insert(list, { name = name, score = math.floor(v) }) 
                end
            else
                -- Fallback voor oude formaat (alleen score)
                local v = tonumber(line)
                if v and v >= 0 then 
                    table.insert(list, { name = "???", score = math.floor(v) }) 
                end
            end
        end
    end
    table.sort(list, function(a,b) return a.score > b.score end)
    return list
end

function Score.addEntry(list, value, name)
    table.insert(list, { name = name or "???", score = math.floor(value) })
    table.sort(list, function(a,b) return a.score > b.score end)
    while #list > C.MAX_LB do table.remove(list) end
end

function Score.saveLeaderboard(list)
    local lines = {}
    for _, entry in ipairs(list) do 
        table.insert(lines, entry.name .. ":" .. tostring(entry.score)) 
    end
    love.filesystem.write(C.LB_FILE, table.concat(lines, "\n"))
end

-- Wis alle scores
function Score.clearLeaderboard()
    love.filesystem.write(C.LB_FILE, "")
    return {}
end

return Score
