io_presets_data = {}

io_presets_in_data = {}

-- Stores the Captain's Booty (The team's data structure)
local captains_booty = {}
local io_presets = {}


local TRY_SETTING_CAPTAIN = 0xFFFFFFF1
local CAPTAIN_EDITING_BUFFER = 0xFFFFFFF2


local crew = {} -- The captain's lesser bots

local function setTeamCaptainFlags(captain)	
	captains_booty = require("bots.io.booty")
	io_stream = require("bots.io.io_stream")
	io_presets = require("bots.io.io_presets")
	
	local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
	
	for k, v in pairs(allies) do
		if ( v:GetPlayerID() == captain:GetPlayerID() ) then
			IO_setData("CAPTAIN", "MINE", v, true, "SWOOTY")
		else
			IO_setData("CAPTAIN", "TAKEN", v, true, "SWOOTY")
		end
	end
end

local function getTeamCaptain(npc)	
	local temp_io_stream = require("bots.io.io_stream")
	local allies = GetUnitList(UNIT_LIST_ALLIED_HEROES)
	local avail_found = false
	local taken_found = false
	
	for k, npc_val in pairs(allies) do
		local captain_status = IO_getData("CAPTAIN", npc_val, "SWOOTY")

		if ( IO_confirmFlagEquals("CAPTAIN", captain_status, "AVIL", "SWOOTY") and taken_found) then 
			return CAPTAIN_EDITING_BUFFER
		elseif ( IO_confirmFlagEquals("CAPTAIN", captain_status, "TAKEN", "SWOOTY") and avail_found) then
			return CAPTAIN_EDITING_BUFFER
		elseif ( IO_confirmFlagEquals("CAPTAIN", captain_status, "MINE", "SWOOTY") ) then
			return npc_val
		end
	end
	if(taken_found or avail_found) then
		return CAPTAIN_EDITING_BUFFER
	end
	return TRY_SETTING_CAPTAIN
end

-- Call for each bot before TC_initialize()
function TC_initializeNomination(npc)
	local my_captain_flag = IO_getData("CAPTAIN", npc, "SWOOTY")
	if (not (IO_confirmFlagEquals("CAPTAIN", my_captain_flag, "MINE", "SWOOTY") or IO_confirmFlagEquals("CAPTAIN", my_captain_flag, "TAKEN", "SWOOTY"))) then 
		IO_setData("CAPTAIN", "AVAIL", npc, true, "SWOOTY")
	end
end

function TC_initialize()
	local this_npc = GetBot()
	
	TC_initializeNomination(this_npc)
	
	local team_captain = getTeamCaptain(this_npc)
	
	if ( team_captain == CAPTAIN_EDITING_BUFFER ) then
		return false -- come back and check later, and you're not captain
	elseif( team_captain == TRY_SETTING_CAPTAIN ) then 
		setTeamCaptainFlags(this_npc)
		
		crew = GetUnitList(UNIT_LIST_ALLIED_HEROES)
		
		for i = #crew, 1, -1 do
			if (not crew[i]:IsBot()) then
				table.remove(crew, i)
			end
		end
		
		this_npc:ActionImmediate_Ping(0, 2^16-1, true) 
		-- ^^^^ Prevents spurious ping sounds (~32,000 units off map is inaudible). This is
		--		probably not needed, (we need any one of 28 high bits set to 1 for signed, or 
		--		28 at low bits for unsigned to never hear a ping - This should only mess up if
		--		you decide to change TC_FLAGS majorly, and even then is highly unlikely
		--		.....0.00000037% of a 28 bit-set set to 0
		
		print( this_npc:GetUnitName().." promoted to captain!" )
		
		return this_npc -- init completed, and you're the captain
	end
	
	return team_captain
end

function TC_captainThink()
	BOOTY_IN()
	
	BOOTY_OUT()
	
	-- TODO Call SWOOTY_IN with a reference to data which would have sent in BOOTY for TC, optimizing the
	--		buffer by 1, always, and would give the TC a faster stream loop for high-CPU/throughput bots.
end

function ioInterpret()
	
end