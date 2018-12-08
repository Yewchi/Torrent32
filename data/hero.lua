POS_ONE = 1
POS_TWO = 2
POS_THREE = 3
POS_FOUR = 4
POS_FIVE = 5
POS_JUNGLE = 666
POS_FEED_MID = 7
POS_ROAM = 8

Hero = {}
Hero.__index = Hero

function Hero:new(hero_unit, lane, pos)
	local hero = {}
	setmetatable(hero, Hero)
	
	if ( hero_unit == nil ) then print ( "WTF ERROR" ) end
	hero.hero_unit = hero_unit
	hero.lane = lane
	hero.pos = pos
	hero.macro_dir = {[MACRO_DIR_MODE_INDEX] = "BOUNTY", [MACRO_DIR_LANE_INDEX] = LANE_MID}
	
	return hero
end

function Hero:updateMacroDirector(macro_director)
	if ( macro_director == nil ) then
		print ( "ERROR NIL macro director updated in updateMacroDirector():::"..debug.traceback())
		return
	end
	
	self.macro_dir = macro_director
	
	return Hero
end

function Hero:getHeroUnit()
	return self.hero_unit
end

function Hero:getMacroDirector()

	return self.macro_dir
end

function Hero:printHero()
	print("DEBUG: ")
	print("	hero_unit: "..self.hero_unit.GetUnitName())
	print("	lane: "..self.lane)
	print("	pos: "..self.pos)
	print(" macro_dir MODE: "..self

return Hero