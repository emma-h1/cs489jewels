local Class = require "libs.hump.class"
local Anim8 = require "libs.anim8"

local spriCoin = love.graphics.newImage(
    "graphics/sprites/coin_spritesheet.png") -- Use coin spreadsheet
local gridCoin = Anim8.newGrid(16,16,spriCoin:getWidth(),spriCoin:getHeight())

local Coin = Class{}
Coin.SIZE = 16
Coin.SCALE = 2.5
function Coin:init(x,y,type)
    self.x = x
    self.y = y
    self.type = type

    self.animation = Anim8.newAnimation(gridCoin('1-5',self.type),0.25)
end

function Coin:update(dt)
    self.animation:update(dt)
end

function Coin:draw()
    self.animation:draw(spriCoin, self.x, self.y, 0, Coin.SCALE, Coin.SCALE)
end

return Coin
