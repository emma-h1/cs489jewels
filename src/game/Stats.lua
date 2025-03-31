local Class = require "libs.hump.class"
local Timer = require "libs.hump.timer"
local Tween = require "libs.tween" 
local Sounds = require "src.game.SoundEffects"

local statFont = love.graphics.newFont(26)
statFontSize=26

local Stats = Class{}
function Stats:init()
    self.y = 10 -- we will need it for tweening later
    self.level = 1 -- current level  
    self.levelIncrease = false -- for coin  
    self.totalScore = 0 -- total score so far
    self.targetScore = 1000
    self.maxSecs = 99 -- max seconds for the level
    self.elapsedSecs = 0 -- elapsed seconds
    self.timeOut = false -- when time is out
    self.tweenLevel = nil -- for later
    self.tweenCombo = nil

    self.yCombo = gameHeight-50
    self.combo = 1 --combo starts counting after another combo
    

    self.timer = Timer.new()
    self.timer:every(1, function() self:clock() end)
end

function Stats:draw()
    if self.y > 10 then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill",0,self.y-10,gameWidth,statFontSize*2)
    end

    if self.yCombo < gameHeight - 50 then 
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill",0,self.yCombo-10,210,statFontSize*2)

    end 
    love.graphics.setColor(1,0,1)
    love.graphics.printf("Level "..tostring(self.level), statFont, gameWidth/2-60,self.y,100,"center")
    love.graphics.printf("Chain/Combo "..tostring(self.combo), statFont,10,self.yCombo,200)


    if self.y <= 10 then
        love.graphics.printf("Time "..tostring(self.elapsedSecs).."/"..tostring(self.maxSecs), statFont,10,10,200)
        love.graphics.printf("Score "..tostring(self.totalScore), statFont,gameWidth-210,10,200,"right")
    end
    love.graphics.setColor(1,1,1)
end
    
function Stats:update(dt) -- for now, empty function
    self.timer:update(dt)

    if self.tweenLevel then -- if tween is active then tween level text
        self.tweenLevel:update(dt)
    end

    if self.tweenCombo then -- tween combo text
        self.tweenCombo:update(dt)
    end
    if self.timeOut then
        gameState = "over" -- Lost game, go to game over
    end
end

function Stats:addScore(n)
    self.totalScore = self.totalScore + n
    if self.totalScore >= self.targetScore then
        self:levelUp()
    end
end

function Stats:levelUp()
    self.levelIncrease = true
    self.level = self.level +1
    self.targetScore = self.targetScore+self.level*1000
    self.elapsedSecs = -1
    Sounds['levelUp']:play()
    self.y = gameHeight/2
    self.tweenLevel = Tween.new(1, self, {y=10}) --tween level text
end

function Stats:increaseCombo()
    self.combo = self.combo + 1
    if self.combo > 1 then
         self.yCombo = gameHeight/2
         self.tweenCombo = Tween.new(1, self, {yCombo=gameHeight-50}) -- tween combo when increase in matches
    end
end 

function Stats:clock()
    self.elapsedSecs = self.elapsedSecs + 1
    
    if self.elapsedSecs >= self.maxSecs then
        self.timeOut = true
        Sounds['timeOut']:play()
    end
end
    
return Stats
    