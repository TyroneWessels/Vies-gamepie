-- =============================================================
-- player.lua
-- GROUND_Y = bovenkant asfalt.
-- Auto staat OP het asfalt:
--   - wielmiddelpunt  Y = GROUND_Y - WHEEL_RADIUS
--   - carrosserie top Y = wielmiddelpunt - WHEEL_RADIUS - CAR_HEIGHT
-- Alle draw-coördinaten zijn afgeleid van self.y (top carrosserie).
-- =============================================================

local Player = {}
Player.__index = Player

local C = {
    START_X        = 160,
    BASE_SPEED     = 480,
    BOOST_SPEED    = 860,
    BOOST_DURATION = 1.2,
    BOOST_COOLDOWN = 2.5,
    JUMP_VELOCITY  = -980,
    GRAVITY        = 2400,
    CAR_W          = 130,
    CAR_H          = 58,
    WHEEL_R        = 20,
}

-- Auto types met kleuren en stijlen
Player.CAR_TYPES = {
    {
        name = "BLAUW",
        bodyColor = { 0.14, 0.52, 1 },
        boostColor = { 1, 0.48, 0.05 },
        style = "sedan"
    },
    {
        name = "ROOD",
        bodyColor = { 0.85, 0.15, 0.12 },
        boostColor = { 1, 0.65, 0.15 },
        style = "sports"
    },
    {
        name = "GROEN",
        bodyColor = { 0.18, 0.65, 0.25 },
        boostColor = { 0.85, 1, 0.25 },
        style = "sedan"
    },
    {
        name = "PAARS",
        bodyColor = { 0.55, 0.20, 0.75 },
        boostColor = { 1, 0.45, 0.85 },
        style = "sports"
    },
    {
        name = "GOUD",
        bodyColor = { 0.85, 0.68, 0.15 },
        boostColor = { 1, 0.90, 0.40 },
        style = "sports"
    },
    {
        name = "ZWART",
        bodyColor = { 0.12, 0.12, 0.15 },
        boostColor = { 0.75, 0.25, 0.10 },
        style = "sedan"
    },
}

-- Geselecteerde auto (index)
Player.selectedCar = 1

-- ---------------------------------------------------------------
-- Player.new
-- @param groundY  bovenkant asfalt (pixels)
-- ---------------------------------------------------------------
function Player.new(groundY, carType)
    assert(type(groundY) == "number")
    local self = setmetatable({}, Player)

    local wr = C.WHEEL_R
    -- Wiel-middelpunt zodat onderkant wiel precies op groundY raakt
    self.wheelY = groundY - wr          -- wiel-middelpunt Y (constant bij rijden)
    -- Top van carrosserie
    self.baseY  = self.wheelY - wr - C.CAR_H

    self.x          = C.START_X
    self.y          = self.baseY        -- huidige Y carrosserie-top
    self.groundY    = groundY
    self.velocityY  = 0
    self.isJumping  = false
    self.isBoosting = false
    self.isDead     = false
    self.boostTimer    = 0
    self.cooldownTimer = 0
    self.wheelAngle    = 0
    self.carType    = carType or Player.selectedCar
    return self
end

function Player:getSpeed()
    return self.isBoosting and C.BOOST_SPEED or C.BASE_SPEED
end

function Player:jump()
    if self.isDead or self.isJumping then return end
    self.velocityY = C.JUMP_VELOCITY
    self.isJumping = true
end

function Player:boost()
    if self.isDead then return end
    if not self.isBoosting and self.cooldownTimer <= 0 then
        self.isBoosting = true
        self.boostTimer = C.BOOST_DURATION
    end
end

function Player:update(dt)
    if self.isDead then return end

    if self.isJumping then
        self.velocityY = self.velocityY + C.GRAVITY * dt
        self.y         = self.y + self.velocityY * dt
        -- Wielmiddelpunt volgt carrosserie tijdens sprong
        self.wheelY    = self.y + C.CAR_H + C.WHEEL_R

        if self.y >= self.baseY then
            self.y      = self.baseY
            self.wheelY = self.groundY - C.WHEEL_R
            self.velocityY = 0
            self.isJumping = false
        end
    end

    if self.isBoosting then
        self.boostTimer = self.boostTimer - dt
        if self.boostTimer <= 0 then
            self.isBoosting    = false
            self.boostTimer    = 0
            self.cooldownTimer = C.BOOST_COOLDOWN
        end
    end
    if self.cooldownTimer > 0 then
        self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
    end

    self.wheelAngle = self.wheelAngle + (self:getSpeed() / 55) * dt
end

-- Hitbox iets kleiner dan sprite
function Player:getBoundingBox()
    local m = 8
    return self.x+m, self.y+m, C.CAR_W-m*2, C.CAR_H-m*2
end

-- ---------------------------------------------------------------
-- Player:draw
-- ---------------------------------------------------------------
function Player:draw()
    local x  = math.floor(self.x)
    local y  = math.floor(self.y)
    local w  = C.CAR_W
    local h  = C.CAR_H
    local wr = C.WHEEL_R
    local wy = math.floor(self.wheelY)
    
    -- Haal auto kleuren op
    local carData = Player.CAR_TYPES[self.carType] or Player.CAR_TYPES[1]
    local bodyColor = carData.bodyColor
    local boostColor = carData.boostColor
    local style = carData.style

    -- Schaduw op grond (alleen als niet te hoog in de lucht)
    if self.wheelY > self.groundY - wr * 3 then
        local alpha = math.max(0, 1 - (self.groundY - self.wheelY - wr) / 60)
        love.graphics.setColor(0, 0, 0, 0.22 * alpha)
        love.graphics.ellipse("fill", x + w/2, self.groundY + 3, w*0.42, 7)
    end

    -- Carrosserie kleur
    if self.isBoosting then
        love.graphics.setColor(boostColor[1], boostColor[2], boostColor[3])
    else
        love.graphics.setColor(bodyColor[1], bodyColor[2], bodyColor[3])
    end
    
    if style == "sports" then
        -- Sportauto: lager dak, schuiner
        love.graphics.rectangle("fill", x+24, y+h*0.15, w-36, h*0.40, 8,8)
        love.graphics.rectangle("fill", x, y+h*0.38, w, h*0.62, 6,6)
        -- Spoiler
        love.graphics.rectangle("fill", x-5, y+h*0.20, 8, h*0.25, 2,2)
    else
        -- Sedan: normaal dak
        love.graphics.rectangle("fill", x+16, y, w-32, h*0.50, 10,10)
        love.graphics.rectangle("fill", x, y+h*0.38, w, h*0.62, 6,6)
    end

    -- Highlight
    love.graphics.setColor(1,1,1,0.12)
    love.graphics.rectangle("fill", x+4, y+h*0.40, w-8, 5, 2,2)

    -- Ramen
    love.graphics.setColor(0.62, 0.88, 1, 0.88)
    if style == "sports" then
        love.graphics.rectangle("fill", x+28, y+h*0.18, 24, 14, 3,3)
        love.graphics.rectangle("fill", x+60, y+h*0.18, 24, 14, 3,3)
    else
        love.graphics.rectangle("fill", x+20, y+4, 28, 18, 4,4)
        love.graphics.rectangle("fill", x+58, y+4, 28, 18, 4,4)
    end

    -- Koplamp
    love.graphics.setColor(1, 1, 0.5, 1)
    love.graphics.rectangle("fill", x+w-7, y+h*0.50, 7, 12, 2,2)

    -- Wielen (middelpunt = wy)
    self:drawWheel(x+24,    wy, wr)
    self:drawWheel(x+w-24,  wy, wr)

    -- Vlam bij boost
    if self.isBoosting then
        self:drawFlame(x, y + h*0.60)
    end
end

function Player:drawWheel(cx, cy, r)
    love.graphics.setColor(0.10, 0.10, 0.10)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0.68, 0.68, 0.78)
    love.graphics.circle("fill", cx, cy, r*0.50)
    love.graphics.setColor(0.32, 0.32, 0.42)
    love.graphics.setLineWidth(2)
    love.graphics.line(cx, cy,
        cx + math.cos(self.wheelAngle)*r*0.40,
        cy + math.sin(self.wheelAngle)*r*0.40)
    love.graphics.setLineWidth(1)
end

function Player:drawFlame(x, y)
    local f = math.sin(love.timer.getTime()*42) * 9
    love.graphics.setColor(1, 0.82, 0, 0.92)
    love.graphics.polygon("fill", x,y, x-30-f,y-12, x-46,y, x-30+f,y+12)
    love.graphics.setColor(1, 0.30, 0, 0.75)
    love.graphics.polygon("fill", x,y, x-20,y-7, x-32-f*0.5,y, x-20,y+7)
end

-- ---------------------------------------------------------------
-- Player:drawHUD  –  boost-balk
-- ---------------------------------------------------------------
function Player:drawHUD(x, y)
    local bw, bh = 280, 20
    love.graphics.setColor(1,1,1,0.9)
    love.graphics.print("BOOST", x, y-22)
    love.graphics.setColor(0.13,0.13,0.13,0.88)
    love.graphics.rectangle("fill", x, y, bw, bh, 4,4)

    if self.isBoosting then
        local f = math.max(0, self.boostTimer / C.BOOST_DURATION)
        love.graphics.setColor(1, 0.52, 0.05)
        love.graphics.rectangle("fill", x, y, bw*f, bh, 4,4)
    elseif self.cooldownTimer > 0 then
        local f = 1 - self.cooldownTimer / C.BOOST_COOLDOWN
        love.graphics.setColor(0.22, 0.52, 1, 0.8)
        love.graphics.rectangle("fill", x, y, bw*f, bh, 4,4)
    else
        love.graphics.setColor(0.12, 0.96, 0.38)
        love.graphics.rectangle("fill", x, y, bw, bh, 4,4)
    end
    love.graphics.setColor(1,1,1,0.28)
    love.graphics.rectangle("line", x, y, bw, bh, 4,4)
end

Player.CONSTANTS = C
return Player
