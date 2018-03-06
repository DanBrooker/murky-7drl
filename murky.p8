pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- murky
-- draconis

-- mit license

-- global vars
debug=true
screenwidth = 127
screenheight = 127
speeds = { "vfast", "fast", "vfast", "fast", "vfast", "normal" }
mapsize_y = 36
mapsize_x = 108
tiles = {}
dirs = {{0,-1}, {0,1}, {1,0}, {-1,0}}

bog = {26,27}
trees = {8,9,10}
floor = {40,41,42,43,56,57,58,59}

entity = {}
entity.__index = entity

function entity.create(x,y,spr,name)
	local new_entity = {}
	setmetatable(new_entity, entity)

	new_entity.name = name
	new_entity.x = x
	new_entity.y = y
  new_entity.spr = spr
  new_entity.spd = "normal"

	return new_entity
end

function entity:draw()
	local s = self.spr
	if time > 10 then
		s += 1
	end
  spr(s, self.x * 8, self.y * 8)
end

-- game loop

function _init()
  -- title_init()
  game_init()
end

function _update()
  update()
end

function _draw()
  draw()
end

-- title scene

function title_init()
  update=title_update
  draw=title_draw
end

function title_update()
	if btnp(4) then
		game_init()
	end
end

function title_draw()
	local titletxt = "murky"
	local starttxt = "press z to start"
	rectfill(0,0,screenwidth, screenheight, 3)
	print(titletxt, hcenter(titletxt), screenheight/4, 10)
	print(starttxt, hcenter(starttxt), (screenheight/4)+(screenheight/2),7)
end

-- end scene

function end_init(text)
	reason = text
  update=end_update
  draw=end_draw
end

function end_update()
	if btnp(4) then
		game_init()
	end
end

function end_draw()
	local titletxt = "you died :( to a " .. reason
	local starttxt = "press z to restart"
	rectfill(0,0,screenwidth, screenheight, 1)
	print(titletxt, hcenter(titletxt), screenheight/4, 10)
	print(starttxt, hcenter(starttxt), (screenheight/4)+(screenheight/2),7)
end

-- game scene

function game_init()
  player = entity.create(10,10,16, "player")
  turns = 0
  shooting = false
  arrows = 3
  freeze = 5
  health = 2
  speed = 5
  monsters = {}
  projectiles = {}
	time = 0
	reason = ""
	message = { text="part i - the forest", fg=7, bg=1 }

  map_gen()

  update=game_update
  draw=game_draw
end

function game_update()
	time += 1
	if time > 32 then
		time = 0
	end
  if player_control() then
    turns += 1
    repeat
      speed += 1
      if speed > #speeds then
        speed = 1
      end
      tick()
    until should_move(player)
  end
end

-- handle button inputs
function player_control()
  local action = move
  if shooting then
    action = shoot
  end

  if (btnp(0)) then
    return action(-1,0)
  elseif (btnp(1)) then
    return action(1,0)
  elseif (btnp(2)) then
    return action(0,-1)
  elseif (btnp(3)) then
    return action(0,1)
  elseif (btnp(4)) then
    shooting = not shooting
  elseif (btnp(5)) then
    if player.spd == "normal" then
      player.spd = "vfast"
    else
      player.spd = "normal"
    end
  end
  return false
end

function should_move(entity)
  return entity.spd == speeds[speed]
end

function tick()
  foreach(monsters, function(monster)
    if should_move(monster) then
      monster_move(monster)
    end
  end)
  foreach(projectiles, function(projectile)
    if should_move(projectile) then
      projectile_move(projectile)
    end
  end)
end

function game_draw()
	rectfill(0,0,screenwidth, screenheight, 0)
  cx = player.x*8-64
  cy = player.y*8-64
  camera(cx, cy)

  map_draw()

  palt(0, false) -- make black opaque
  foreach(monsters, function(monster)
    monster:draw()
  end)
  foreach(projectiles, function(projectile)
    projectile_sprite(projectile)
    projectile:draw()
  end)
	player:draw()
  palt(0, true) -- reset black to transparent

  camera() -- reset camera

  if debug then
    minimap_draw()
  end

  -- draw ui
  rectfill(0,screenheight-6,screenwidth, screenheight, 7)

  -- health
	rectfill(0,0,11, 14, 0)
  print( health .. "\x87", 1, 1, 8)
  print( arrows .. "", 1, 9, 4)
  spr(13, 4, 7)

  if debug then
    print(player.x .. "," .. player.y .. " spd: " .. speed .. " tur: " .. turns, 2, screenheight-5, 0)
  elseif shooting then
    print("\x8b\x91\x94\x83 to fire", 2, screenheight-5, 0)
  elseif player.spd != "normal" then
    print("z to aim, x to cancel", 2, screenheight-5, 0)
  else
    print("z to aim, x for elven speed", 2, screenheight-5, 0)
  end
end

function map_draw()
  local ox = cx%8
  local oy = cy%8
  for my=cy/8,cy/8+16 do
		if my < mapsize_y and my >= 0 then
			for mx=cx/8,cx/8+16 do
				if mx < mapsize_x and mx >= 0 then
					local t = mget(mx,my)
          if t != 0 then
  					spr(t, mx*8-ox, my*8-oy)
          end
				else
					spr(8, mx*8-ox, my*8-oy)
				end
			end
		else
			for mx=cx/8,cx/8+16 do
				spr(8, mx*8-ox, my*8-oy)
			end
		end
	end
end

function projectile_move(projectile)
  if not projectile.hit then
    local x = projectile.x + projectile.dx
    local y = projectile.y + projectile.dy
    if walkable(x,y) then
      projectile.x = x
      projectile.y = y
      projectile.range -= 1
      if projectile.range <= 0 then
        projectile.hit = true
      end
    -- todo elseif entity() -- enemy / player
    --
    else
      local monster = monster_at(x,y)
      if monster then
        projectile.x = x
        projectile.y = y
        del(monsters, monster)
        sfx(3)
      end
      projectile.hit = true -- stop projectiles when they hit something
    end
  end
end

function projectile_sprite(projectile)
  if projectile.hit then
    projectile.spr = 13
  else
    if projectile.dx == 0 then
      if projectile.dy < 0 then
        projectile.spr = 5
      else
        projectile.spr = 37
      end
    else
      if projectile.dx > 0 then
        projectile.spr = 53
      else
        projectile.spr = 21
      end
    end
  end
end

function monster_move(monster)
  local distance = ent_distance(monster, player)
  local dir = nil
  if distance == 1 then

    sfx(1)
    health -= 1
    if health <= 0 and not debug then
			end_init(monster.name)
    end
  elseif distance < 6 then
    -- todo: move toward player
    local dx = player.x - monster.x
    local dy = player.y - monster.y

    if abs(dx) > abs(dy) then
      if dx > 0 then
        dir = {1, 0}
      else
        dir = {-1, 0}
      end
    else
      if dy > 0 then
        dir = {0, 1}
      else
        dir = {0, -1}
      end
    end
  else
    dir = dirs[ range(1,4) ]
  end

  if dir then
    local x = monster.x + dir[1]
    local y = monster.y + dir[2]
    if walkable(x, y) then
      monster.x = x
      monster.y = y
    end
  end
end

function minimap_draw()
  for x=0, mapsize_x-1 do
    for y=0, mapsize_y-1 do
			if mget(x,y) then
	      pset(x, y, mget(x,y) % 15 + 1)
			end
    end
  end

  pset(player.x,player.y,8)
end

function mset(x,y,t)
	tiles[flr(y)*mapsize_x+flr(x)] = t
end

function mget(x,y)
	return tiles[flr(y)*mapsize_x+flr(x)]
end

function walkable(x,y)
  return not fget(mget(x,y),0) and monster_at(x,y) == nil
end

function monster_at(x,y)
  local ent = nil
  local match = (function(e)
    if e.x == x and e.y == y then
      ent = e
    end
  end)
  foreach(monsters, match)
  -- foreach(projectiles, match)
  return ent
end

function projectile_at(x,y)
  local ent = nil
  local match = (function(e)
    if e.x == x and e.y == y then
      ent = e
    end
  end)
  -- foreach(monsters, match)
  foreach(projectiles, match)
  return ent
end

function move(dx,dy)
  local x = player.x + dx
  local y = player.y + dy
  local monster = monster_at(x,y)
  local projectile = projectile_at(x,y)
	if x < 0 or x > mapsize_x or y < 0 or y >= mapsize_y then
		return false
	elseif monster then
    -- push monster
    local mx = x + dx + dx
    local my = y + dy + dy
    if walkable(mx,my) then
      monster.x = mx
      monster.y = my
    end
    sfx(3)
    return true
  elseif(projectile) then
    del(projectiles, projectile)
    sfx(1)
    arrows += 1
    player.x = x
    player.y = y
    return true
  elseif(walkable(x,y) or debug) then
    player.x = x
    player.y = y
    return true
  else
    sfx(2)
    return false
  end
end

function shoot(dx, dy)
  if arrows <= 0 and not debug then
    shooting = false
    return
  end
  local x = player.x + dx
  local y = player.y + dy
  if(walkable(x,y) or debug) then
    local projectile = entity.create(x,y,6, "arrow")
    projectile.spd = "vfast"
    projectile.dx = dx
    projectile.dy = dy
    projectile.hit = false
    projectile.range = 10
    add(projectiles, projectile)
    shooting = false
    arrows -= 1
    return true
  else
    sfx(1)
    return false
  end
end

function map_gen()
  mapseed = rnd(1000)
  genperms()
  local x, y

	local third = flr(mapsize_x / 3)
	local a,b,c = third, third*2, mapsize_y

  for y=0, mapsize_y-1 do
	  for x=0, a do
			sector1(x,y)
		end
	end
	local first = monsters[1]
	player.x = first.x
	player.y = first.y
	del(monsters, first)

	local sector1_exit = range(5, 20)
	printh("sector1 " .. a .. "," .. sector1_exit, "debug.txt")
	local path = astar({player.x, player.y}, {a, sector1_exit}, function(x,y)
		return x > 0 and x <= sector1_exit
	end)
	for point in all(path) do
		if debug then
			mset(point[1],point[2], 2)
		else
			if not walkable(point[1],point[2]) then
				mset(point[1],point[2], floor[range(1,#floor)])
			end
		end
	end

	local sector2_exit = range(5, 20)
	printh("sector2 " .. b+1 .. "," .. sector2_exit, "debug.txt")
	for y=0, mapsize_y-1 do
		for x=a, b do
			-- sector2(x,y)
			mset(x,y,24)
		end
	end
	path = astar({a, sector1_exit}, {b+1, sector2_exit}, function(x,y)
		return x > b+1 and x <= sector2_exit
	end)
	for point in all(path) do
		if debug then
			mset(point[1],point[2], 2)
		else
			if not walkable(point[1],point[2]) then
				mset(point[1],point[2], floor[range(1,#floor)])
			end
		end
	end

	-- local sector3_exit = range(5, 20)
	-- for y=0, mapsize_y-1 do
	-- 	for x=b, mapsize_x-2 do
	-- 		sector1(x,y)
	-- 	end
	-- end
	-- path = astar({b, sector2_exit}, {c, sector3_exit}, function(x,y)
	-- 	return true
	-- end)
	-- for point in all(path) do
	-- 	if debug then
	-- 		mset(point[1],point[2], 2)
	-- 	else
	-- 		if not walkable(point[1],point[2]) then
	-- 			mset(point[1],point[2], floor[range(1,#floor)])
	-- 		end
	-- 	end
	-- end
end

function sector1(x,y)
	local n = noise(x,y)
	if n > 0.1 then
		mset(x, y, trees[range(1,#trees)])
	elseif n > 0.0 then

		if (range(1,60)) == 1 then
			local monster = entity.create(x,y, 32, "snake")
			add(monsters, monster)
		elseif (range(1,40)) == 1 then
			local monster = entity.create(x,y, 48, "bat")
			-- monster.spd= "fast"
			add(monsters, monster)
		end

		mset(x, y, floor[range(1,#floor)])
	elseif n < -0.3 then
		mset(x, y, bog[range(1,#bog)])
	else
		mset(x, y, 0)
	end
end

function sector2(x,y)

end

function sector3(x,y)

end

function hcenter(s)
	return (screenwidth / 2)-flr((#s*4)/2)
end

function vcenter(s)
	return (screenheight /2)-flr(5/2)
end

function assert(a,text)
	if not a then
		error(text or "assertion failed")
	end
end

function error(text)
	cls()
	print(text)
	_update = function() end
	_draw = function() end
end

function range(min,max)
  return flr(rnd(max)) + min
end

function push(stack,item)
	stack[#stack+1]=item
end

function pop(stack)
	local r = stack[#stack]
	stack[#stack]=nil
	return r
end

function insert(t, val, p)
	if #t >= 1 then
		add(t, {})
		for i=(#t),2,-1 do
			local next = t[i-1]
		 	if p < next[2] then
		  	t[i] = {val, p}
		  	return
		 	else
		  	t[i] = next
		 	end
		end
		t[1] = {val, p}
	else
		add(t, {val, p})
	end
end

function top(stack)
	return stack[#stack]
end

function at(array, x, y)
  local one = array[x]
  if one then
    return one[y]
  else
    return nil
  end
end

function ent_distance(a, b)
  return distance(a.x, a.y, b.x, b.y)
end

function distance(ax, ay, bx,by)
  return abs(ax - bx) + abs(ay - by)
end

-- noise from tempest.p8

function noise(x,y)
	return fractal_noise_2d(6,0.65,0.025,x+mapseed,y+mapseed)
end

function fractal_noise_2d(octaves,persistence,scale,x,y)
	local total = 0
	local freq = scale
	local amp = 1
	local maxamp = 0

	for i=1,octaves do
		total += perlin_noise_2d(x * freq, y * freq) * amp
		freq *= 2
		maxamp += amp
		amp *= persistence
	end

	return total / maxamp
end

permutation = {}

function genperms()
	local p = {}
	for i=0,255 do
		add(p,i)
	end
	for i=0,255 do
		add(p,i)
	end
	shuffle(p)
	permutation = p
end

function perlin_noise_2d(x,y)
	local xi = flr(x) % 255
	local yi = flr(y) % 255
	local xf = x-flr(x)
	local yf = y-flr(y)

	local u = fade(xf)
	local v = fade(yf)

	local p = permutation

	local aa = p[p[xi+1]+yi+1]
	local ab = p[p[xi+1]+yi+2]
	local ba = p[p[xi+2]+yi+1]
	local bb = p[p[xi+2]+yi+2]

	local x1,y1,x2,y2

	x1 = lerp(grad(aa,xf,yf),grad(ba,xf-1,yf),u)
	x2 = lerp(grad(ab,xf,yf-1),grad(bb,xf-1,yf-1),u)
	return lerp(x1,x2,v)
end

function grad(hash,x,y)
	local h = band(hash,0x7)
	local v={x+y,-x+y,x-y,-x-y,-x,-y,x,y}
	return v[hash%8+1]
end

function fade(t)
	return t*t*t*(t*(t*6-15)+10)
end

function shuffle(a)
	local n = count(a)
	for i=1,n do
		local k = -flr(-rnd(n))
		a[i],a[k] = a[k],a[i]
	end
	return a
end

function lerp(a,b,t)
	return (1-t)*a+t*b
end

function vec(point)
	return flr(point[2])*256+flr(point[1])%256
end

function vec2xy(v)
	local y = flr(v/256)
	local x = v-flr(y*256)
	return {x,y}
end

function reverse(t)
	for i=1,(#t/2) do
		local temp = t[i]
		local oppindex = #t-(i-1)
		t[i] = t[oppindex]
		t[oppindex] = temp
	end
end

function inlist(list,x)
	for v in all(list) do
		if v == x then return v end
	end
	return false
end

function inmap(tx,ty)
	return tx > 0 and ty > 0 and tx < mapsize_x and ty < mapsize_y
end

function adjacent(point)
	local x, y = point[1], point[2]

	local adj = {}
	local v = {{x-1,y},{x,y-1},{x+1,y},{x,y+1}}
	for i in all(v) do
		if inmap(i[1],i[2]) then
			add(adj,{i[1],i[2],mget(i[1],i[2])})
		end
	end
	return adj
end

function astar(start, goal, valid)
	printh("astar " .. start[1] .. "," .. start[2] .. " -> " .. goal[1] .. "," .. goal[2] ,"debug.txt")
	local frontier = {}
	insert(frontier, start, 0)
	local came_from = {}
	came_from[vec(start)] = nil
	local cost_so_far = {}
	cost_so_far[vec(start)] = 0

	while (#frontier > 0 and #frontier < 1000) do
		local popped = pop(frontier)
		local current = popped[1]

	 	if vec(current) == vec(goal) then
	 		break
	 	end

	 	local neighbours = adjacent(current)
	 	for next in all(neighbours) do
			if valid(current[1], current[2]) then
		  	local nextindex = vec(next)

			  local new_cost = cost_so_far[vec(current)] + cost(current, next)

			  if (cost_so_far[nextindex] == nil) or (new_cost < cost_so_far[nextindex]) then
					cost_so_far[nextindex] = new_cost
					local priority = new_cost + heuristic(goal, next)
					insert(frontier, next, priority)

					came_from[nextindex] = current
			  end
			end
	  end
	end

	current = came_from[vec(goal)]
	path = {}
	local cindex = vec(current)
	local sindex = vec(start)

	while cindex != sindex do
	 add(path, current)
	 current = came_from[cindex]
	 cindex = vec(current)
	end
	add(path, current)
	reverse(path)

	return path
end

function cost(a, b)
	if not walkable(b[1],b[2]) then
		return rnd(10)
	elseif mget(b[1],b[2]) == 0 then
		return 2
	end
	return 1
end

function heuristic(a, b)
	return distance(a[1], a[2], b[1], b[2])
end

function floodfill(x,y,comp,action)
	local queue = {vec(x,y)}
	local seen = {}
	while #queue > 0 do
		local v = pop(queue)
		local x,y = vec2xy(v)
		if not (x <= 0 or x >= mapsize_x or y <= 0 or y >= mapsize_y) then
			push(seen,v)
			if action(x,y) == true then break end
			for adj in all(adjacent(x,y)) do
				local ax,ay = adj[1],adj[2]
				local av = vec(ax,ay)
				if not inlist(seen,av) and comp(ax,ay) then
					push(queue,av)
				end
			end
		end
	end
end

__gfx__
00000000000000000000000000000000000000000000600000006000000000000033330000033000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000005650000056500000000000333333000333300000040000000000000000000000005600000056000000000
000000000000000000088800000000000000000000004000000040000000000033333333000330000404000000cccc0000000000000004500000045000000000
00000000000000000080008000000000000000000000400000004000000000003333333300333300004040400c8cccc000000000000040000000400000000000
000000000000000000800080000000000000000000004000000040000000000033333b3303333330000404000cccc8c000000000000400000004000000000000
0000000000000000008000800000000000000000000040000000400000000000033bb33000333b00000440000cccccc000000000074000000740000000000000
000000000000000000088800000000000000000000074700000747000000000000044000000bb00000044000000cc00000000000007000000070000000000000
0000000000000000000000000000000000000000000707000007070000000000000440000004400000044000000cc00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000077777777000000000000000000000000000000000000000000000000
0f0eee00000000000000000000000000000000000000000000000000000000000000000007007777000000000000000000000000000000000000000000000000
00f9faa00f0eee000000000000000000000000000500007705000077000000000000000007777077000005050000000000000000000000000000000000000000
008fff4000f9faa00000000000000000000000006644444066444440000000000006500077700777000000500500050000000000000000000000000000000000
000fff04008fff440000000000000000000000000500007705000077000000000065550070770707000000000055500000000000000000000000000000000000
00f3bbf4000fff040000000000000000000000000000000000000000000000000055550000077707500005000000000000000000000000000000000000000000
00f3bbf400f3bbf40000000000000000000000000000000000000000000000000000000000077777055550000000000000000000000000000000000000000000
0005054000f3bb440000000000000000000000000000000000000000000000000000000000070007000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000007070000070700000000000000500005550000000000000000000000000000000000000000000000000000
022272000222720c000000000000000000000000000747000007470000000000050005000555000000bb000000000b0000000000000000000000000000000000
02022200020222c0000000000000000000000000000040000000400000000000000000000550005000bb00000000b00000000000000000000000000000000000
020000000200000c000000000000000000000000000040000000400000000000000000000000055500b0bb000b00b00000000000000000000000000000000000
02eeee0002eeee0000000000000000000000000000004000000040000000000005000050000005550000bb0000b0b00b00000000000000000000000000000000
00002e0000002e0000000000000000000000000000004000000040000000000050000000050005500000b00000b000b000000000000000000000000000000000
0e22e2000e22e200000000000000000000000000000565000005650000000000050500500050000000000000000000b000000000000000000000000000000000
00000000000000000000000000000000000000000000600000006000000000000000050005500000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000005500000000000000000000000000000000000000000000000000000
50000050000000000000000000000000000000000000000000000000000000000505000050500500000000000000000000000000000000000000000000000000
55000550000000000000000000000000000000007700005077000050000000000000050000000000000003000000000000000000000000000000000000000000
05555500055555000000000000000000000000000444446604444466000000000000000000000000003033000000000000000000000000000000000000000000
00555000505550500000000000000000000000007700005077000050000000000500005000000050000330000000000000000000000000000000000000000000
00050000500500500000000000000000000000000000000000000000000000000000000000500550000030000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000500000000550000030000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000500000005000000000000000000000000000000000000000000000000000000
__gff__
0000000400020200010101000002020000000404000202020100000000000000040404000002020000000000000000000404040000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000808080808000000080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008282828282808000808080000032800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008282828022808000800002828280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008082828282808080800282828280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000080000002828280028280828280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000080808080828282803080828280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000800000828080808080028280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000808080000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100001a05026750257502375022750087502175008750207501f7501f7501f7501e7501e7501d7501d7501d7501d7501e7501f750207502175022750237500675022750017502675015650166501865018650
000100000c5530e5511055112541145401654016530175301752017520185301855018560195701a5701b5701e570115702357025570295602b5502d54030530315203552036511375513b5513c5523f5523f553
0001000023150211501f150236501c1501b1501915019150191501f7501915019150191501915018150181501715017150161501c750141501b7501315012150101500f1500d1500d1500c1500b1500b1500a150
00010000067500675005750057500575004750216500475004750047500575005750057500675007750087500c7500f7501175014750187501b7501e75020750227502475027750287502c7502e7503175032750
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000000000000000000100501f0501f0701d050240500000019050290502a05015050110502c0500e0502e0500a050080502e0502e0500000000000000000000000000000000000000000000000000000000
__music__
00 01424344
00 57424344
