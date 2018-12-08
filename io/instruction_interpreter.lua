--[[ instruction_interpreter.lua

This interface is used by the team captain to set data to the IN direction of each bot's
data buffer. Each bot (including captains) is able to set data to the OUT side
of the buffer (abstracted by swooty.lua). A team captain is responsible for storing and sending 
the data that bots need to make important decisions, as well as interpreting and receiving the 
data that each bot has placed in it's OUT buffer, to be processed and stored in the captain's
booty, or used for some other computation, based on the OUT buffer's bot's stated needs.

The captain's booty (booty.lua) is accessible only by the team captain, and is the main 
intelligence data structure for each team. Based on the processing they've performed on this data,
Team captains dole out high-level instructions to inform teammates where they are most needed, 
and may even assume direct control.

Bots use their Think() calls every 33ms, or so, (30 frames / sec). This means the buffer is
capable of 5 * 30 * 31 bits = 4.65 kb/s of data transfer via both in and out pipes for a team. 
Not much! But you can work with it via data and instruction abstractions. 

The pipeline is split evenly, amoungst all bots that are to be given instructions (for the IN pipe).
If bots are known not to need a message, a stream-pause value is set, and once all IN buffers have
been read, those bots have their INCL_BIT set to 0, and the data buffer now uses 1 less stream.
Compared to a fixed-split system, variable stream number will have (ignoring pause calls) throughput
of 5: 96%, 4: 109%, 3: 159%, 2: 225% or 1: 484% speed)

The only other (obvious) data storage exposed by the Dota 2 Bot API are the 
hUnit:GetMostRecentPing().location[1] and [2] values set via hUnit:ActionImmediate_Ping(). Note: out-
of-bounds pings are not visible or audible. But they do set the values passed to 32-bit floating point 
numbers, and as such degrade to precision innaccuracies past (2^22) = 8388607... These will always be 
used for OUT pipe, (giving INCL_BIT * (155/#INCL_BITS_ON) + 2*22) OUT stream speed (INCL_OFF: 1.3 kb/s,
INCL_ON: [min: 2.2kb/s max: 5.95kb/s]). The Team Captain ping buffer could be used for emergency IN data 
transfer speeds, signifying emergency instructions ("Retreat!", "Kill supernova!", (out of vision with 
fresh BKB): "Check Gyros items!"), or general team-wide alerts. The only limitation is that pings can 
only be sent by the Lua states pertaining to the bot pinging (as far as I've found). If any ping was 
allowable from any bot's state, I would probably just use the ping bits for one, constant increased 
buffer size (11.4 kb/s io/team).

TODO consider teamfight mode switching, so that bots can concurrently access an IN-only, 
Chinese-whipser style constantly updating fight-plan, allowing a constant stream of data.
(bots would ping the stream frame received, if the team_captain 'overlaps' a bot (somehow),
bots would check the ping locations of each bot for the missing frame. Bots would be round-up 
by the team-captain, making calls to a fight_strategy interface, making team-level decisions.

TODO Set-up a separate data_type which specifies a list of instructions or data_types to follow 
(stored by receiving bot), then send a MISC payload in 32-bit packets.



TODO instruction to function calls:
======================
==https://stackoverflow.com/questions/1791234/lua-call-function-from-a-string-with-function-name
==functions = {
==       f1 = function(arg) print("function one: "..arg) end,
==       f2 = function(arg) print("function two: "..arg..arg) end,
==       ...,
==       fn = function(arg) print("function N: argh") end,
==}
==Then you can use a string as an table index and run your function like this
==
==print(functions["f1"]("blabla"))
==print(functions["f2"]("blabla"))
==This is the result:
==
==function one: blabla
==function two: blablablabla
==I find this to be cleaner than using loadstring(). If you don't want to create a special function table you can use _G['foo'].
======================


-- TODO This file needs to be completely autonomous, requiring no developer edits. Set up the table of instructions, and everything
		would work in SWOOTY.
-- TODO The whole pack system is to remove complexity from io_dock queues, and allow immediately passable data. Is this correct or 
		should io_dock queues store qualifiers and payloads as an array.
--]]

local bitwise_interface = require("bots.io.bitwise_interface")
local io_presets = require("bots.io.io_presets")
local util = require("bots.util.util")

local mLog = math.log
local mCeil = math.ceil
local mAbs = math.abs
local mFloor = math.floor
local LOG_2 = mLog(2)

local _TEST = false

local QUALIFIER_SIZE = 10 -- TODO making this adjustable means max payload size flag needs to be turned into data-size flag, for the whole value.
local MAX_PAYLOAD_SIZE_FLAG = 16 -- TODO This new system necessitates putting this file in the 'untouchable' group. Either drop it low, or go all out on this file's complexity, and if needed, moving simpler, adjustable functions higher.
local MAX_SIZE_OF_PAYLOAD_SIZE_FLAG = 4 -- (2^4 = 16 bits for the size flag)
local LEADING_BIT = 1


local _DEBUG = true

-- II_packData()	--	Checks io_presets data tables to pack a value which represents a
					--	full, any-bit-size, queue-ready SWOOTY or BOOTY message for the
					--	passed stream-data_type. It gives the raw data.
-- TODO Args check
-- TODO this should be (stream, data_type, ...) for a list of all values which are stored for that qualifier, setting each to signed ints
function II_packData(data_type, payload, stream) 
	local qualifier_ID = IO_getQualifierID(data_type, stream)
	local payload_size = IO_getQualifierDataSize(data_type, stream)
	local data
	local packed_value
	
	if ( type(payload) == "string" ) then -- We know what this value means
		data = IO_getQualifierFlagValue(data_type, payload, stream)
	elseif ( type(payload) == "number" ) then -- We are setting a integer value
		data = BW_unsignedToSigned(payload_size)
		if(data == nil) then
			return nil -- Value too high/low to sign
		end
	else
		return nil -- malformed payload
	end
	if(qualifier_ID < 2^(QUALIFIER_SIZE - 1)) then
		packed_value = 2^(QUALIFIER_SIZE+payload_size-1) -- If the top Qualifier bit is 0, it's packed as negative. Setting it to 1 here lets us get a correctly sized negative.
	end
	-- ^That's a one flipped to zero right? No. It's a simulated signed integer. 
	-- We need to make it a higher number and flip it, because it represents what 
	-- would be stored in data if it WAS REALLY SIGNED. because techically it's not...
	packed_value = packed_value + qualifier_ID * 2^(payload_size) -- qualifier
	packed_value = packed_value + data -- payload
	if(qualifier_ID < 2^(QUALIFIER_SIZE - 1)) then
	-- If the leading bit of the value is already 1, the bitwise interface will set the leading bit to 0, by design
	-- This indicates that the following qualifier and payload are NOT to be flipped. They're immediately unpackable.
		packed_value = BW_binFLIP(packed_value)
	end
	
	return packed_value
end

function II_unpackData(data, is_booty_call)
	local qualifier_ID
	local payload_size
	local unpacked_value
	local payload
	local data_bit_length = UTIL_getBitLength(data)
	local stream

	if(is_booty_call) then
		stream = "BOOTY"
	else
		stream = "SWOOTY"
	end
	
	if(data < 0) then
		unpacked_value = BW_binFLIP(data)
		qualifier_ID = BW_modSignedNumber(BW_binShiftL(unpacked_value, QUALIFIER_SIZE+1, data_bit_length), data_bit_length, QUALIFIER_SIZE-1) -- the 10th qualifier bit is only used for flip (-ve)
		if(_TEST) then print(data.." of size "..data_bit_length.." gives "..qualifier_ID) end
		payload_size = IO_getQualifierDataSize(qualifier_ID, stream)
		unpacked_value = BW_modSignedNumber(unpacked_value, data_bit_length, QUALIFIER_SIZE+1) -- Take off qualifier and leading 1
	else
		unpacked_value = data
		qualifier_ID = unpacked_value / 2^(data_bit_length - QUALIFIER_SIZE)
		qualifier_ID = IO_getQualifierID(qualifier_ID, stream)
		payload_size = IO_getQualifierDataSize(qualifier_ID, stream)
	end

	payload = unpacked_value
	if(type(IO_getQualifierValueFlag(qualifier_ID, payload, stream)) == "nil") then
		payload = BW_signedToUnsigned(payload, data_bit_length)
	end
	
	return {qualifier_ID, payload}
end


function II_getPackedDataSize(packed_data_segment, bit_size_of_segment, stream)
	local qualifier_ID
	local unpacked_segment
	
	if(packed_data_segment < 0) then -- Negatives
		unpacked_segment = BW_binFLIP(packed_data_segment)
		qualifier_ID = BW_binShiftL(unpacked_segment, QUALIFIER_SIZE + 1, data_bit_length) % 2^(QUALIFIER_SIZE-1) -- The top bit is a 1 for flip/pack purposes
	else -- Positives
		qualifier_ID = mFloor(packed_data_segment / 2^(bit_size_of_segment - QUALIFIER_SIZE))
	end
	
	in_buffer_size = IO_getQualifierDataSize(qualifier_ID, stream)
	in_buffer_size = LEADING_BIT + QUALIFIER_SIZE + in_buffer_size
	
	return in_buffer_size
end

function resetBufferValue(npc)
	BW_resetNPCBuffer(npc)
end