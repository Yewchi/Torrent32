--[[ IMPORTANT N.B.: "SWOOTY" is meant in the sense of buffer communication with bots--it's the
--					communication direction of the stream to bots via SWOOTY (i.e.: not
--					to BOOTY). In other words, it is -not- in the sense of swooty/booty 
--					receiving and sending data.
--
--					(Monospaced ascii:)					   *
--											 Think() entry:|
--														   |    <------------------------------<,
--														 \*|*/								   /|\
--				/---------------------------------------- \*/ -------------------------\		|
--				|										   |							|		|
--				|			   /=#LOCK#==#FREE#=IN PIPE=====\===========\				|		|
--			   /|	,-------, --- BOOTY_OUT ->#,--------,#--- SWOOTY_IN --> ,--------,  |		|
-- the 'stream':|	| BOOTY | 				  #| BUFFER |#				    | SWOOTY |  |		|
--			   \|	'-------' <-- BOOTY_IN ---#'--------'#<-- SWOOTY_OUT -- '--------'  |		|
--				|			    \==========\===OUT PIPE================/				|		|
--				|						 	|											|		|
--				\------------------------- /*\ -----------------------------------------/		|
--									   	  /*|*\													|
--										 	|												 	|
--										 	| * >--- after BOOTY, SWOOTY. They're a bot too. -->'
--				   TC_captainThink() entry: |
--										 	*
---]]

local interpreter_interface = require("bots.io.io_stream")
local io_dock = require("bots.io.io_dock")

local _DEBUG = true
local _TEST = false

local IS_SWOOTY_CALL = false -- All functions asking for stream type ask "is_booty_call"

local HUNIT_INDEX = 1
local T32_PID_INDEX = 2

local SWOOTY_data

local team_captain
local initialized = false

local frames = 0
local frame_num = 0


local allies_T32PID

local previous_payload = nil

local game_time = GameTime()
local function printFramesPerSecond()
	frames = frames + 1
	local rug = math.floor
	if ( rug(game_time) < rug(GameTime()) ) then 
		print ( frames.." frames/sec.")
		frames = 0
	end
	game_time = GameTime()
end


-- TODO Make an initialization qualifier, SWOOTY and BOOTY, so BOOTY can answer with a payload of all required SWOOTY storage data from it's database.
--		That will make it easy for developers to code information they've set up to need to have consistent for all bots.
function SWOOTY_getTeamCaptain()
	return team_captain
end

function SWOOTY_setData(data)
	SWOOTY_data = data
end

function SWOOTY_initialize(tc)
	if(not tc == nil) then 
		team_captain = tc
	end
	local allies_list = GetUnitList(UNIT_LIST_ALLIED_HEROES)
	allies = {}
	
	for i = 1, #allies_list, 1 do
		allies[allies_list[i]:GetPlayerID()] = {allies_list[i], i}
	end
	
	initialized = true
end

-- TODO Save BOOTY_IN frame on read, if we get to setting SWOOTY_OUT data and the frame has changed, pause the write 1 frame, and read the BOOTY data next Think() call. No frame dropped
function SWOOTY_IN()
	local data_type_index
	local data_type 
	local value
	local my_lane = LANE_MID
	local this_npc = GetBot()
	local shrine
	
	printFramesPerSecond()
	
	-- TEMPORTARY TEST 
	if(GetBot():GetTeam() == 2) then 
		shrine = {-4200, 380}
	else
		shrine = {-150, 4000}
	end
	
	local unpacked_instructions = II_unpackData(DOCK_pullData(IS_SWOOTY_CALL)[1], IS_SWOOTY_CALL)
	
	for i = 1, 200, 1 do
		f = i * i
	end
	
	local qualifier_ID = unpacked_instructions[1]
	local this_data = unpacked_instructions[2]
	-- TEMPORARY TEST
	if ( IO_SWOOTY_confirmQualifierIndexEquals(qualifier_ID, "MOVE", "SWOOTY") ) then
		if(_TEST) then print("Got \"MOVE\"") end
		if ( IO_confirmFlagEquals(qualifier_ID, this_data, "LANE_FRONT", "SWOOTY") ) then
			if(_TEST) then print("Got \"LANE_FRONT\"") end
			this_npc:Action_MoveDirectly(
				LaneRandomizeLocation(
					GetLaneFrontLocation(
							GetTeam(), 
							my_lane, 
							-(this_npc:GetAttackRange() + 300) 
						), 350))
		elseif( IO_confirmFlagEquals(qualifier_ID, this_data, "FOUNTAIN", "SWOOTY") ) then
			if(_TEST) then print("Got \"FOUNTAIN\"") end
			this_npc:Action_MoveDirectly(
				LaneRandomizeLocation(
					shrine, 350) )
		end
	end
	-- TODO Set a random move offset of the lane front for the test instruction, bots should receive first read, then freshness will block more reads of the 1 frame that was set for them, and not run circles.
end

function SWOOTY_READ(read_index)
	
end

function SWOOTY_OUT(this_npc, payload)
	local data_type_index
	local data_type
end

-- SWOOTY_getT32PID()	--	Returns the ID allocated to a player in initialization.
							--	Torrent32PID is for-team, ranges from 1 to 5. Used for
							--	easy array indexing. (Human players start at dota
							--	player id 0, meaning bots range from 1-9)
function SWOOTY_getT32PID(dota_PID)
	return allies[dota_PID][T32_PID_INDEX]
end

-- SWOOTY_getPlayerhUnit()	--	Returns a handle to the player unit given the T32_PID arg.
							--
function SWOOTY_getPlayerhUnit(T32_PID)
	for k, v in pairs(allies) do
		if(v[T32_PID_INDEX] == T32_PID) then
			return v[HUNIT_INDEX]
		end
	end
	print("[swooty] No such ally found SWOOTY_getPlayerhUnit(T32_PID = "..T32_PID..").\n"..debug.trackeback())
	return nil
end

function SWOOTY_getPlayerList()
	local T32_indexed = {}
	for k, v in pairs(allies) do
		T32_indexed[v[T32_PID_INDEX]] = v[HUNIT_INDEX]
	end
	return T32_indexed
end