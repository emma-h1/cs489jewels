local Class = require "libs.hump.class"
local Matrix = require "libs.matrix"
local Tween = require "libs.tween"

local Gem = require "src.game.Gem"
local Cursor = require "src.game.Cursor"
local Explosion = require "src.game.Explosion"
local Sounds = require "src.game.SoundEffects"
local Coin = require "src.game.Coin"

local Board = Class{}
Board.MAXROWS = 8
Board.MAXCOLS = 8
Board.TILESIZE = Gem.SIZE*Gem.SCALE 
function Board:init(x,y, stats)
    self.x = x
    self.y = y
    self.stats = stats
    self.cursor = Cursor(self.x,self.y,Board.TILESIZE+1)

    self.tiles = Matrix:new(Board.MAXROWS,Board.MAXCOLS)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            self.tiles[i][j] = self:createGem(i,j)
        end -- end for j
    end -- end for i
    self:createCoin()
    self:fixInitialMatrix()

    self.tweenGem1 = nil
    self.tweenGem2 = nil
    self.color = nil
    self.explosions = {}
    self.arrayFallTweens = {}
    self.matchCount = nil
end

-- Put a coin on a random space in the grid
function Board:createCoin()
    local rowCoin = math.random(1,Board.MAXROWS)
    local colCoin = math.random(1,Board.MAXCOLS)
    self.tiles[rowCoin][colCoin] = Coin(self.x + (colCoin-1)*Board.TILESIZE,
                                        self.y+(rowCoin-1)*Board.TILESIZE, 1)
end

function Board:createGem(row,col)
    return Gem(self.x+(col-1)*Board.TILESIZE,
               self.y+(row-1)*Board.TILESIZE,
               math.random(4,8) )
end

function Board:fixInitialMatrix()
    -- First we check horizontally
    for i = 1, Board.MAXROWS do
        local same = 1 
        for j = 2, Board.MAXCOLS do -- pay attention: starts as j=2
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    

    -- Second we check vertically
    for j = 1, Board.MAXCOLS do -- pay attention: first loop is j
        local same = 1 
        for i = 2, Board.MAXROWS do -- second loop is i
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    
end    

function Board:update(dt)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:update(dt)
            end -- end if
        end -- end for j
    end -- end for i

    for k=#self.explosions, 1, -1 do
        if self.explosions[k]:isActive() then
            self.explosions[k]:update(dt)
        else
            table.remove(self.explosions, k)
        end -- end if
    end -- end for explosions

    for k=#self.arrayFallTweens, 1, -1 do
        if self.arrayFallTweens[k]:update(dt) then
            -- the tween has completed its job
            table.remove(self.arrayFallTweens, k)
        end
    end -- end for tween Falls

    if #self.arrayFallTweens == 0 then
        self:matches()
        if self.matchCount > 1 then -- matches called more than once
            self.stats:increaseCombo()
        else
            self.stats.combo = 1
            self.matchCount = 0 --reset count
        end

    end

    if self.tweenGem1 ~= nil and self.tweenGem2~=nil then
        local completed1 = self.tweenGem1:update(dt)
        local completed2 = self.tweenGem2:update(dt)
        if completed1 and completed2 then
            self.tweenGem1 = nil
            self.tweenGem2 = nil
            local temp = self.tiles[mouseRow][mouseCol]
            self.tiles[mouseRow][mouseCol] = self.tiles[self.cursor.row][self.cursor.col]
            self.tiles[self.cursor.row][self.cursor.col] = temp
            self.cursor:clear()
            self:matches()
        end
    end

    -- Put a new coin on the grid when a new level is reached
    if self.stats.levelIncrease then
        self:createCoin()
        self.stats.levelIncrease = false
    end
end

function Board:draw()
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:draw()
            end -- end if
        end -- end for j
    end -- end for i

    self.cursor:draw()

    for k=1, #self.explosions do
        self.explosions[k]:draw()
    end
end

function Board:cheatGem(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        local cheatRow,cheatCol = self:convertPixelToMatrix(x,y)
        self.tiles[cheatRow][cheatCol]:nextType()
    end
end

function Board:mousepressed(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        mouseRow, mouseCol = self:convertPixelToMatrix(x,y)

        if self.cursor.row == mouseRow and self.cursor.col == mouseCol then
            self.cursor:clear()
        elseif self:isAdjacentToCursor(mouseRow,mouseCol) then
            -- adjacent click, swap gems
            self:tweenStartSwap(mouseRow,mouseCol,self.cursor.row,self.cursor.col)
        else -- sets cursor to clicked place
            self.cursor:setCoords(self.x+(mouseCol-1)*Board.TILESIZE,
                    self.y+(mouseRow-1)*Board.TILESIZE)
            self.cursor:setMatrixCoords(mouseRow,mouseCol)
        end
    
    end -- end if

end

function Board:isAdjacentToCursor(row,col)
    local adjCol = self.cursor.row == row 
       and (self.cursor.col == col+1 or self.cursor.col == col-1)
    local adjRow = self.cursor.col == col 
       and (self.cursor.row == row+1 or self.cursor.row == row-1)
    return adjCol or adjRow
end

function Board:convertPixelToMatrix(x,y)
    local col = 1+math.floor((x-self.x)/Board.TILESIZE)
    local row = 1+math.floor((y-self.y)/Board.TILESIZE)
    return row,col 
end

function Board:tweenStartSwap(row1,col1,row2,col2)
    local x1 = self.tiles[row1][col1].x
    local y1 = self.tiles[row1][col1].y

    local x2 = self.tiles[row2][col2].x
    local y2 = self.tiles[row2][col2].y

    self.tweenGem1 = Tween.new(0.3,self.tiles[row1][col1],{x = x2, y = y2})
    self.tweenGem2 = Tween.new(0.3,self.tiles[row2][col2],{x = x1, y = y1})
end

function Board:findHorizontalMatches()
    local matches = {}
    for i = 1, Board.MAXROWS do 
        local same = 1
        for j = 2, Board.MAXCOLS do
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=i, col=(j-same), size=same})
                self.color = self.tiles[i][j-1].type -- check color of Gem included in match
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=i, col=(Board.MAXCOLS-same+1), size=same})
            self.color = self.tiles[i][Board.MAXCOLS-same+1].type
            same = 1
        end
    end -- end for i

    return matches
end

function Board:findVerticalMatches()
    -- Almost the same func as findHorizontalMatches, bascially changing i for j
    local matches = {}
    for j = 1, Board.MAXCOLS do 
        local same = 1
        for i = 2, Board.MAXROWS do
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=(i-same), col=j, size=same})
                self.color = self.tiles[i-1][j].type -- check color of Gem included in match
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=(Board.MAXROWS+1-same), col=j, size=same})
            self.color = self.tiles[Board.MAXROWS+1-same][j].type
            same = 1
        end
    end -- end for i

    return matches
end

function Board:matches()
    local horMatches = self:findHorizontalMatches()
    local verMatches = self:findVerticalMatches() 
    local score = 0
    self.matchCount = 0 -- tracks number of times function is called
    if #horMatches > 0 or #verMatches > 0 then -- if there are matches
        for k, match in pairs(horMatches) do
            self:adjacentToCoinHorizontal(match.row, match.col, match.size)
            score = score + 2^match.size * 10   
            for j=0, match.size-1 do
                self.tiles[match.row][match.col+j] = nil
                self:createExplosion(match.row,match.col+j)
                self.matchCount = self.matchCount + 1
            end -- end for j 
        end -- end for each horMatch 

        for k, match in pairs(verMatches) do
            self:adjacentToCoinVertical(match.row, match.col, match.size)
            score = score + 2^match.size * 10   
            for i=0, match.size-1 do
                self.tiles[match.row+i][match.col] = nil
                self:createExplosion(match.row+i,match.col)
                self.matchCount = self.matchCount + 1
            end -- end for i 
        end -- end for each verMatch

        if Sounds["breakGems"]:isPlaying() then
            Sounds["breakGems"]:stop()
        end
        Sounds["breakGems"]:play()

        self.stats:addScore(score)

        self:shiftGems()
        self:generateNewGems()
    end -- end if (has matches)
end

-- Check adjacent spaces in a horizontal match for coins
function Board:adjacentToCoinHorizontal(matchRow, matchCol, size)
    local coins = {} -- store coins, can have multiple if coin from prev level not collected

    if matchRow > 1 then --row is not at edge
        -- check row above match for coins
        for j = 0, size-1 do
            if (self.tiles[matchRow-1][matchCol+j])  -- prevent nil error
            and (self.tiles[matchRow-1][matchCol+j].type == 1) then -- coin check
                table.insert(coins, {row = matchRow-1, col = matchCol+j})
            end
        end
    end

    if matchRow < Board.MAXROWS then -- row is not at edge
        -- check row below match for coins
        for j = 0, size -1 do
            if (self.tiles[matchRow+1][matchCol+j])  -- prevent nil error
            and (self.tiles[matchRow+1][matchCol+j].type == 1) then -- coin check
                table.insert(coins, {row = matchRow+1, col = matchCol+j})
            end
        end
    end

    -- check col to right of match
    if (matchCol + size <=Board.MAXCOLS)  -- right side is not at edge
    and (self.tiles[matchRow][matchCol+size])  -- prevent nil error
    and (self.tiles[matchRow][matchCol+size].type == 1) then -- is coin?
        table.insert(coins, {row = matchRow, col = matchCol+size})
    end

    -- check col to left of match
    if (matchCol > 1)  -- not at edge
    and (self.tiles[matchRow][matchCol-1])  -- no nil
    and (self.tiles[matchRow][matchCol-1].type == 1) then -- is coin
        table.insert(coins, {row = matchRow, col = matchCol-1})
    end

    -- for each coin, make the space nil, explode animation, play sound, and give bonus to score
    for k, coin in pairs(coins) do
        self.tiles[coin.row][coin.col] = nil
        self:createExplosion(coin.row,coin.col)
        Sounds['coin']:play()
        self.stats:addScore(100)
    end
end

-- check adjacent spaces in vertical match for coins
function Board:adjacentToCoinVertical(matchRow, matchCol, size)
    local coins = {}

    if matchCol > 1 then -- Not at edge
        -- check to left of match for coins
        for i = 0, size -1 do
            if (self.tiles[matchRow+i][matchCol-1])  -- prevent nil
            and (self.tiles[matchRow+i][matchCol-1].type == 1) then -- is coin
                table.insert(coins, {row = matchRow+i, col = matchCol-1})
            end
        end
    end

    if matchCol < Board.MAXCOLS then -- not at edge
        -- check to right of match for coins
        for i = 0, size -1 do
            if (self.tiles[matchRow+i][matchCol+1])  -- no nil
            and (self.tiles[matchRow+i][matchCol+1].type == 1) then -- is coin
                table.insert(coins, {row = matchRow+i, col = matchCol+1})
            end
        end
    end

    -- check below of match
    if (matchRow + size <= Board.MAXROWS)  -- not at edge
    and (self.tiles[matchRow+size][matchCol])  -- not nil
    and (self.tiles[matchRow+size][matchCol].type == 1) then -- is coin
        table.insert(coins, {row = matchRow+size, col = matchCol})
    end

    -- check above of match
    if (matchRow > 1)  -- not at edge
    and (self.tiles[matchRow-1][matchCol])  -- not nil
    and (self.tiles[matchRow-1][matchCol].type == 1) then -- is coin
        table.insert(coins, {row = matchRow-1, col = matchCol})
    end

    -- for each coin, set space to nil, explode animation, play sound effect, add bonus to score
    for k, coin in pairs(coins) do
        self.tiles[coin.row][coin.col] = nil
        self:createExplosion(coin.row,coin.col)
        Sounds['coin']:play()
        self.stats:addScore(100)
    end
end

function Board:createExplosion(row,col)
    local exp = Explosion()
    if(self.color == 4) then
        exp:setColor(255,255,0) -- yellow 
    elseif(self.color == 5) then
        exp:setColor(0,150,250)  -- blue
    elseif(self.color == 6) then 
        exp:setColor(255, 255, 255)  -- grey
    elseif(self.color == 7) then
        exp:setColor(255, 0, 0)  -- red
    elseif(self.color == 8) then 
        exp:setColor(0, 255, 0)  -- green
    end 
    exp:trigger(self.x+(col-1)*Board.TILESIZE+Board.TILESIZE/2,
               self.y+(row-1)*Board.TILESIZE+Board.TILESIZE/2)  
    table.insert(self.explosions, exp) -- add exp to our array
end

function Board:shiftGems() 
    for j = 1, Board.MAXCOLS do
        for i = Board.MAXROWS, 2, -1 do -- find an empty space
            if self.tiles[i][j] == nil then -- current pos is empty
            -- seek a gem on top to move here
                for k = i-1, 1, -1 do 
                    if self.tiles[k][j] ~= nil then -- found a gem
                        self.tiles[i][j] = self.tiles[k][j]
                        self.tiles[k][j] = nil
                        self:tweenGemFall(i,j) -- tween fall animation 
                        break -- ends for k loop earlier
                    end -- end if found gem
                end -- end for k
            end -- end if empty pos
        end -- end for i
    end -- end for j
end -- end function

function Board:tweenGemFall(row,col)
    local tweenFall = Tween.new(0.5,self.tiles[row][col],
            {y = self.y+(row-1)*Board.TILESIZE})
    table.insert(self.arrayFallTweens, tweenFall)
end

function Board:generateNewGems()
    for j = 1, Board.MAXCOLS do
        local topY = self.y-1*Board.TILESIZE -- y pos above the first gem 
        for i = Board.MAXROWS, 1, -1  do -- find an empty space
            if self.tiles[i][j] == nil then -- empty, create new gem & tween 
                self.tiles[i][j] = Gem(self.x+(j-1)*Board.TILESIZE,topY, math.random(4,8))
                self:tweenGemFall(i,j)
                topY = topY - Board.TILESIZE -- move y further up 
            end -- end if empty space
        end -- end for i
    end -- end for j        
end -- end function generateNewGems()

return Board