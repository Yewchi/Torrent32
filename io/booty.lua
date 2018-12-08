--[[ IMPORTANT N.B.: "IN" is meant in the sense of buffer communication with bots--the
--					communication direction of the stream to bots via SWOOTY (i.e.: not
--					to BOOTY). In other words, it is -not- in the sense of swooty/booty 
--					receiving data and sending.
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

-- TODO forward declare all required B_OUT/IN functions for simplicity of the file.

-- TODO Store data about the options the team strategizer passes-up for the sent strategy.
--		Could be used for learning. More importantly, post [_DELICIOUS} "I regret..." 
--		when BOOTY deduces a bot would've survived if he used the other strategy.
-- TODO At the start of every game, evaluate the kind of heroes a team has, and how they'll
--		farm and lane. Analyse what the win condition would look like for that team (push,
--		gank, pressure cores, pressure over-farming, stack and farm, turtle, etc.) to inform
--		instruction decisions and push bots towards taking their objective safely and intelligently
-- TODO Reset buffer frames that are read but have no responding BOOTY_IN data. Nil the packed data,
-- 		and use resetNPCBuffer() (fast)

local io_presets = require("bots.io.io_presets")
local swooty = require("bots.io.swooty")

local IS_BOOTY_CALL = true -- Nice.

local crew
local booty

function BOOTY_initialize()
	booty = {}
	crew = SWOOTY_getPlayerList()
end
 
function BOOTY_IN()
	local booty_data = {} -- Data communicated to each bot. Always n = #crew - num human players
	if(DOCK_getQueueSize(IS_BOOTY_CALL) == 0) then
	    if (GetBot():GetTeam() == 2) then
			for i = 1, #crew, 1 do
				booty[i] = II_packData("MOVE", "LANE_FRONT", "SWOOTY")
			end
		else 
			for i = 1, #crew, 1 do
				booty[i] = II_packData("MOVE", "FOUNTAIN", "SWOOTY")
			end
		end
	end
	
	DOCK_pushData(booty)
	DOCK_setSail(IS_BOOTY_CALL)
end

function BOOTY_OUT()
	
end

function initializeBooty()
	
end

function BOOTY_getOptimizeMetrics()
end