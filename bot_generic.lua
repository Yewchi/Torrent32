--[[ 
	TODO - Clean up notes. Make it an easy-to-extend and understand, modular, professional library.
	TODO - 19/04/18, Only just realized I've used "frames" in the sense a frame of a
			payload being sent to the buffer, this could be confused in the Dota 2 game-
			frame sense. Already a huge refactor, so I'm leaving it till later.
--]]

local team_offset = {[TEAM_RADIANT] = 0, [TEAM_DIRE] = 5}

swooty = require("bots.io.swooty")
captain_interface = {}

-- TODO Make script in main folder that switches all "local _DEBUG = true/false" on exec.
local _DEBUG = true
local _TEST = false
local _FLAV = true

local NOT_INITIALIZED_TOLERANCE = 2

local initialized = false
local npc_data_buffer_cleared = false
local im_team_captain = false -- setting to 'true' is when we acheive concurrency ( top lvl call is init() ) 
local frames = 0
local frames_not_initialized = 0
local reset_buffer_grace_frames = 2
local curr_grace_frames = 0





local function concurrencyCheck()
	if(frames_not_initialized == NOT_INITIALIZED_TOLLERANCE) then
		print("[bot_generic] "..this_npc:GetUnitName()..": init() - No concurrency! See example bots for base initializion code in bot_generic.lua:init().")
	end
	frames_not_initialized = frames_not_initialized + 1
end

local test = 0
-- INITIALIZE!
local function init()
-- TODO separate file: See if the HTTPRequest calls can somehow query dotabuff to deduce 
--		meta / form intelligence over where heroes are best to lane. Or just create a
--		batch file to create that table in a .lua file
	local this_npc = GetBot()

	if(_DEBUG) then
		concurrencyCheck()
	end

	print ("Initializing "..this_npc:GetUnitName().."...")
	
	local temp_captain_interface = require("bots.team_captain_interface")
	local temp_interpreter = require("bots.io.io_stream")
	
	-- Team captain set-up
	local team_captain = TC_initialize() -- true: LUA states now share concurrent data via this_npc for this team.
	if(team_captain == nil) then
		return false
	end
	
	SWOOTY_initialize(team_captain)
	-- io set-up
	IO_initialize(team_captain)
	IO_initializePresets()
	
	if ( team_captain == this_npc ) then
		captain_interface = temp_captain_interface
		im_team_captain = true
		
		BOOTY_initialize()
		DOCK_initialize(true)
		
		if (_FLAV) then 
			print("\\o/ [FLAVOUR] \\o/ Admiral "..this_npc:GetUnitName().." reporting in!") 
			if (_DEBUG) then 
				print("\\o/ [_DELICIOUS] \\o/ Concurrency acheived for "..((this_npc:GetTeam() == TEAM_RADIANT) and "Team Radiant" or "Team Dire!").."!") 
			end
		end
	end
	
	return true
end

--[[TODO something somwhere should prioritize which data is most important for the team 
	captain to have up-to-date. Based on current team strategy / fight / farm statuses --]]
function Think() 
	-- init()
	
	
	if ( not initialized ) then
		if ( curr_grace_frames >= reset_buffer_grace_frames ) then 
			initialized = init()
		elseif(not npc_data_buffer_cleared == true) then
			resetBotBuffer()
			npc_data_buffer_cleared = true
		else
			curr_grace_frames = curr_grace_frames + 1
		end
		return
	end
	
	
	local this_npc = GetBot()
	
	if ( im_team_captain ) then 
		TC_captainThink()
	end

	SWOOTY_IN()

	SWOOTY_OUT()
end

resetBotBuffer = function()
	GetBot():SetNextItemPurchaseValue(0)
end