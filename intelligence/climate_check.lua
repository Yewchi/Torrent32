--[[ 	'Climate' is used to assess how a space is changing for the heros within that 
		climate-zone. The things which effect a climate are: abilities coming off 
		cooldown, creeps dying in lane, creeps not appearing on-time (pull), lane-enemies
		beggining to push, heroes taking heavy damage, or abilities being used. The 
		climate check difference will determine if risk assessment needs to be performed, 
		with high-level (Team God and Macro) risk-assessments triggered if a climate zone 
		becomes 'hot' (quickly changing) or the safety metric creeps up to a dangerous 
		level.
--]]

lane_eq_assessor = require("bots.intelligence.lane_equalibrium")

local climates = {}

for i = 1, 11, 1 do
	climates[i] = {0.0, 0.0} -- {Heat, Safety}
end

function checkClimate(this_npc)
	local lane_eq = lane_eq_assessor.checkEqualibrium(this_npc)
end

-- Checks if additional enemy heroes have entered my space
function prelimClimateCheck()
	local this_npc = GetBot()
	
	local nearby_npcs = this_npc:GetNearbyHeroes(1599, true, BOT_MODE_NONE)
	local num_nearby_npcs = #nearby_npcs
	
	print ( this_npc:GetPlayerID()..": nearby "..#nearby_npcs.." heroes.")
	if ( num_nearby_npcs > getNPCStatus(STATUS_FCKD, this_npc) ) then
		setNPCStatus(STATUS_FCKD, Clamp(num_nearby_npcs, 0, 3), this_npc)
		setNPCStatus(STATUS_FCNT, 3, this_npc)
		setNPCStatus(STATUS_ASMN, 1, this_npc)
		
		this_npc:ActionImmediate_Chat( "DEBUG: I'm fucked!", true )
		
		return true
	end
	
	return false
end
	