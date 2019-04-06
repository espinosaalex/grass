
-- @see http://www.sciencedirect.com/science/article/pii/016727898990081X#
-- This typically goes through several stages:
-- first a mass pulsing, more or less synchronized with a textured brain-like pattern
-- then circular pulsing pockets begin to appear and grow, with waves pushing to larger regions at different phases
-- then spiral patterns begin to appear and overcome the still growing pulsations
-- the spirals break down under their own advection into smaller spirals while the bigger waves consume the remaining space

-- the crucial parameter to vary these behaviors is sickness_rate

local scales = {
  {{1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1}, "lydian"},
  {{1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1}, "ionian"},
  {{1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0}, "mixolydian"},
  {{1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0}, "dorian"},
  {{1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0}, "aeolian"},
  {{1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0}, "phrygian"}
}

local intervals = {1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8}

local tab = require 'tabutil'
local cs = require 'controlspec'


engine.name = 'PolyPerc'

local base = 64
local transpose = 1
local scale_select = 1
local show_change = 0

function getHzJust(note)
  if scales[scale_select][1][(note % 12) + 1] == 0 then 
    note = note + 1 
  end
  ratio = intervals[(note % 12) + 1]
  oct = math.floor(note / 12) + 1
  return(base * 2^oct * ratio * intervals[transpose])
end  
  

function earthsea_init()
  params:add{type="number",id="scale_mode",name="scale mode",
    min=1,max=6,default=1,
    action=function(n) scale_select=n end}
  params:add{type="number",id="transpose",name="transpose",
    min=1,max=12,default=1,
    action=function(n) transpose=n end}

  cs.AMP = cs.new(0,1,'lin',0,0.5,'')
  params:add_control("amp", "amp", cs.AMP)
  params:set_action("amp",
  function(x) engine.amp(x) end)

  cs.PW = cs.new(0,100,'lin',0,80,'%')
  params:add_control("pw", "pw", cs.PW)
  params:set_action("pw",
  function(x) engine.pw(x/100) end)

  cs.REL = cs.new(0.1,3.2,'lin',0,0.95,'s')
  params:add_control("release", "release", cs.REL)
  params:set_action("release",
  function(x) engine.release(x) end)

  cs.CUT = cs.new(50,5000,'exp',0,555,'hz')
  params:add_control("cutoff", "cutoff", cs.CUT)
  params:set_action("cutoff",
  function(x) engine.cutoff(x) end)

  cs.GAIN = cs.new(0,4,'lin',0,1,'')
  params:add_control("gain", "gain", cs.GAIN)
  params:set_action("gain",
  function(x) engine.gain(x) end)

  params:bang()

  engine.amp(0.5)


end









local bpm = .5

local visualize = 0.19

local field2D = {}
for x=1,128 do
  field2D[x] = {}
  for y=1,64 do
    field2D[x][y] = 0
  end
end

math.randomseed(os.time())
local floor = math.floor
local min = math.min


-- allocate the field
local field = field2D

-- create a second field, to store the previous states of the cells:
local field_old = field2D

local sickness_rate = 0.21
local infection_rate_infected = 1/3
local infection_rate_ill = 1
local initial_infection = 1/255

local sum_infected = 0
local sum_ill = 0

local function round(n)
  n = n * 16
  return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

local function initialize()
	return 1 - math.random() * math.random()
end

local function wrap(val, maxnum)
  if val + 1 > maxnum then
    return 1
  elseif (val - 1 == -1) then
    return maxnum
  else
    return val
  end
end

function init()
  --earthsea init code 
  earthsea_init()
  
  
  for x=1,128 do
    for y=1,64 do
      field[x][y] = initialize(x,y)
    end
  end
  
  m = metro.init(update, bpm, -1)
  m:start()
end

-- use this to initialize the field:
-- field:set(initialize)

-- how to render the scene (toggle fullscreen with the Esc key):
function redraw()
	-- draw the field:
	screen.clear()
	 if show_change > 0 then
    show_change = show_change - 1
    screen.level(12)
    screen.move(20,10)
    screen.text(bpm)
    screen.move(0,10)
    screen.text(sickness_rate)
	elseif bpm > visualize then
	  
	  for x=1,128 do
     for y=1,64 do
        screen.pixel(x,y)
        screen.level(round(field[x][y]))
      
        screen.fill()
      end
    end
  end

  screen.update()
end


-- a cell is infected if the value is greater than zero:
local isinfected = math.ceil
-- a cell is ill if the value is equal or greater than 1:
local isill = math.floor


-- the rule for an individual cell (at position x, y) in the field:
function hodgepodge(x, y)

	-- check my own previous state:
	local C = field_old[x][y]

	-- check out the neighbors' previous states:
	local N  = field_old[x][wrap(y+1,64)]
	local NE = field_old[wrap(x+1, 128)][wrap(y+1,64)]
	local E  = field_old[wrap(x+1, 128)][y]
	local SE = field_old[wrap(x+1, 128)][wrap(y-1,64)]
	local S  = field_old[x][wrap(y-1,64)]
	local SW = field_old[wrap(x-1,128)][wrap(y-1,64)]
	local W  = field_old[wrap(x-1,128)][y ]
	local NW = field_old[wrap(x-1,128)][wrap(y+1,64)]


	if C >= 1 then
	  sum_ill = sum_ill + 1
		-- all ill cells are healed automatically:
		C = 0
	elseif C > 0 then
	  sum_infected = sum_infected + 1
		-- infected
		local nearbyinfection = C + N + NE + E + SE + S + SW + W + NW
		local nearbyinfected =   1
							 + 	 isinfected(N) + isinfected(NE)
							 + 	 isinfected(E) + isinfected(SE)
							 +   isinfected(S) + isinfected(SW)
							 +   isinfected(W) + isinfected(NW)
		local averageinfection = nearbyinfection / nearbyinfected
		C = sickness_rate + averageinfection
		C = min(1, C)
	else
		-- healthy cell:


		-- number of local infected:
		local nearbyinfected = (
							 isinfected(N) + isinfected(NE)
						 + 	 isinfected(E) + isinfected(SE)
						 +   isinfected(S) + isinfected(SW)
						 +   isinfected(W) + isinfected(NW)
						 )
		-- calculate number of local ill:
		local nearbyill  = (
							 isill(N) + isill(NE)
						 + 	 isill(E) + isill(SE)
						 +   isill(S) + isill(SW)
						 +   isill(W) + isill(NW)
						 )

		local influence = floor(nearbyinfected * infection_rate_infected)
						+ floor(nearbyill * infection_rate_ill)

		C = initial_infection * influence
	end
	-- a sick cell gets sicker by a fixed amount, plus extra sickness due to infected neighbours. It cannot get sicker than the limit.
	-- An uninfected cell may catch infection, depending on its neighbours.
	-- At the next 'tick' any ill cells are healed!

	-- return the new state:
	return C
end

-- update the state of the scene (toggle this on and off with spacebar):
function update()
	-- swap field and field_old:
	-- (field now becomes old, and the new field is ready to be written)
	field, field_old = field_old, field

	-- apply the game_of_life function to each cell of the field:
-- 	field:set(hodgepodge)
	for x=1,128 do
    for y=1,64 do
      field[x][y] = hodgepodge(x,y)

    end
  end
  engine.hz(getHzJust(math.floor(util.linlin (0, 8192, 1, 36, sum_infected))))
  
  -- print(sum_infected, "infected")
  -- params:set("release", sum_ill / 1000)
  -- m.time = (util.linlin (0, 8192, .18, 1.0, sum_infected))
  sum_ill = 0
  sum_infected = 0
  
  redraw()
end




function key(n,z)

  if n==2 then
    if z == 1 then
      for x=1,128 do
        for y=1,64 do
          field[x][y] = initialize(x,y)
        end
      end
    end
  elseif n==3 then
    if z==1 then visualize = not(visualize) end
  end
end

function enc(n,d)
  if n==1 then
    bpm = util.clamp(bpm + d/100, 0.13, 100)
    m.time = bpm
    show_change = 3
    redraw()
  elseif n==2 then 
    sickness_rate = util.clamp(sickness_rate + d/100, 0.03, 1)
    show_change = 3
    redraw()
  end
end
