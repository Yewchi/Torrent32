-- Mr. or Mrs. Bot Developer: You don't need to understand this file to code your bots.

-- TODO Stream optimization, hang-up detection, stream-size lock (for hang up).
-- TODO Leading bit logic. TODO setting INCL_BIT to 0 = yes, 1 = no means less bitwise
--		operations. (always positive)... Not that CPU should be a bottleneck.
-- TODO Two meanings for "stream". The system of flow of data, and the qualifier table types
-- TODO IMPORTANT Player prev frames? How will it affect freshness. e.g. don't want player to set hung flag, but want players to be counted as stale = 1 more than likely for logic.

local instruction_interpreter = require("bots.io.instruction_interpreter")

local INCL_BIT_SIZE = 5
local TEAM_OFFSET = {[TEAM_RADIANT] = 1, [TEAM_DIRE] = 6}
local NOT_FRESH = 3 -- How stale a buffer section can get before indicating hang-up.
local BOOTY_FRAMES_OLD_INDEX = 2
local INCL_BITS_ON = 0x1F -- {1,1,1,1,1}

-- Does not leave open to "LARGE_QUALIFIER" qualifier, which extends to additional bits, like qual_index = 0x3FF0
local QUALIFIER_INDEX = 0
local QUALIFIER_SIZE = 10
local INT_SIZE = 32

local FRAME_NOT_SENT_FLAG = 0xFFFFFFD1
local FRAME_HUNG_FLAG = 0xFFFFFFD2
local BUFFER_STALE_OR_BOOTED = 0xFFFFFFD3
local SIZE_NOT_AVAIL = 0xFFFFFFD4
local BOOTY_LOCKED_W = 0xFFFFFFD5
local WAIT_BOOTY_OPTIMIZE = 0xFFFFFFD6
local FRAME_FULLY_SENT = 0xFFFFFFD7

local FEEDING = 0
local READING = 1

local _TEST = false

local prev_frame_fed = 0		-- TODO Is a hashing function better for these checks?
local frames_old_fed = 0	-- How many frames my previous data hasn't been read
local prev_frame_read = 0
local frames_old_read = 0	-- How many frames BOOTY hasn't given me new data
local booty_prev_frames_fed -- always nil if not team captain, multi-dimensional, for n frames old.
local booty_prev_frames_read
local booty_frames_old_fed
local booty_frames_old_read

local pause_frame_in_buffer

local mFloor = math.floor
local mMax = math.max
local mMin = math.min
local mCeil = math.ceil

local team_captain

-- Forward-declared funcs
local flipInclBit
local checkIncluded
local numberNPCIncluded
local getSkipCount
local getNPCFirstBuffer
local setBufferQualifierID
local getInclBitArray
local removeSkippedData

local frame32_orientations = {
		[1] = {160},
		[2] = {80, 80},
		[3] = {54, 53, 53},
		[4] = {40, 40, 40, 40},
		[5] = {32, 32, 32, 32, 32}
} -- TODO Store size and first buffer with data index for each size.

-- TODO TESTING Double check player purchase item value is not overridden by player behaviour.
-- TODO IMPORTANT initialize() functions are helpful to understand local file variables--move all file init() to top
function IO_initialize(tc)
	if(tc == nil) then
		return false
	end
	
	team_captain = tc

	local allies = SWOOTY_getPlayerList()

	if(team_captain == GetBot()) then 		
		booty_prev_frames_fed = {}
		booty_prev_frames_read = {}

		-- initialize INCL_BIT
		BW_setPingValue(5, 5, INCL_BITS_ON)
		for k, v in pairs(allies) do
			local id = SWOOTY_getT32PID(v:GetPlayerID())
			if(_TEST) then print(id..":"..v:GetUnitName()) end
			--[[if(not v:IsBot()) then -- TODO Not finding players. 
				print("Human player id:"..id.." next item purchase: "..DEBUG_printableValue(v:GetNextItemPurchaseValue()))
				flipInclBit(v, true)
			end--]]
		end

		booty_frames_old_fed = {}
		booty_frames_old_read = {}
		for i = 1, #allies, 1 do
			booty_frames_old_fed[i] = 0
			booty_frames_old_read[i] = 0
		end
		booty_prev_frames_fed = {}
		booty_prev_frames_read = {}
		for i = 1, #allies, 1 do
			booty_prev_frames_fed[i] = 0
			booty_prev_frames_read[i] = 0
		end
	else
		pause_frame_in_buffer = false
	end

	return true
end


-- TODO TC_PING table all hard-coded, need name -> ID index table, need size stored in main table
-- Only called by the team captain.
local function lockSwootyWrite()
	BW_setPingValue(3, 1, IO_getQualifierFlagValue(3, "LOCK", "TC_FLAGS"))
end

-- Only called by the team captain.
local function freeSwootyWrite()
	BW_setPingValue(3, 1, IO_getQualifierFlagValue(3, "FREE", "TC_FLAGS"))
end

local function checkSwootyWriteAuthorized(is_booty_call)
	local lock_status = BW_getPingValue(3, 1, team_captain)
	if(is_booty_call) then
	else
		if(IO_confirmFlagEquals(3, lock_status, "LOCK", "TC_FLAGS")) then
			return BOOTY_LOCKED_W
		elseif(checkIncluded(GetBot())) then
			return BUFFER_STALE_OR_BOOTED
		elseif(pause_frame_in_buffer) then
			return WAIT_BOOTY_OPTIMIZE
		end
	end
	
	return true
end

-- myFreshnessGetFresher()	--	Set frames old to 0, for the purpose of freshness().
								--	If fresh array is set, we know it's booty, and it
								--  updates the fresh and the curr_frames for all booty 
								--	fed or read.
local function myFreshnessGetFresher(pipe, curr_frame, new_fresh_array)
	if(new_fresh_array == nil) then -- SWOOTY
		if (pipe == FEEDING) then
			frames_old_fed = 0
			prev_frame_fed = curr_frame
		elseif (pipe == READING) then 
			frames_old_read = 0
			prev_frame_read = curr_frame
		end
	else -- BOOTY
		if (pipe == FEEDING) then
			booty_frames_old_fed = new_fresh_array
			booty_prev_frames_fed = curr_frame
		elseif (pipe == READING) then
			booty_frames_old_read = new_fresh_array
			booty_prev_frames_read = curr_frame
		end
	end
end

-- freshness():		--	Returns 0 if data is "fresh", the previous frame was ACK(nowledged)
					--	and a new frame was set by the opposite -OOTY. Increments and 
					--	returns frames_old if data is "stale". Acts as both a hang-up 
					--	check, and safety net for team captain and any crewmate 
					--	overlapping each other's frames.
local function freshness(pipe, curr_frame, prev_frame, frames_old) -- TODO This should be is_booty_call and just access the frame data directly
	if(type(curr_frame) == "number") then -- SWOOTY
		if(curr_frame == prev_frame) then
			frames_old = frames_old + 1
		end
		return frames_old
	else -- BOOTY
		for i = 1, #prev_frame, 1 do
			if(curr_frame[i] == prev_frame[i]) then
				frames_old[i] = frames_old[i] + 1
			end
		end

		return frames_old
	end
end

-- freshCheck():	--	Did you cop that new buffer frame? Returns how stale the 
					--	frame is and if NOT_FRESH sets hang-up flag in bot's PING.
local function freshCheck(pipe, curr_frame, prev_frame, frames_old)
	if(type(curr_frame) == "number") then -- SWOOTY
		frames_old = freshness(pipe, curr_frame, prev_frame, frames_old)
	else -- BOOTY
		frames_old = freshness(pipe, curr_frame, prev_frame, frames_old)
		for i = 1, #frames_old, 1 do
		--Which player? Maybe make a getHungNPC() that checks freshness and returns bots on NOT_FRESH
			if(frames_old[i] >= NOT_FRESH) then
				BW_setPingData(4, 1, IO_getQualifierFlagValue(4, "HUNG", "TC_FLAGS")) -- TODO abstract
				if(_TEST) then print("[io_stream] "..GetBot():GetUnitName()..": Found hung flag for bot ID#"..i..".") end
				return frames_old
			end
		end
	end
	return frames_old
end

-- IO_setData()		--	Sets raw data to a specific bot's INT_32. 
--					--	This is not intended to be implemented for low-level interfacing
--					--	with the INT_32 values. Should only be used locally, but is exposed
--					--	for special cases, like Team Captain initialization.
--					-- TODO Not boundary safe. Not type safe. Of no matter yet, because IO_feed() should be used.
function IO_setData(data_type, value, npc, set_qualifier, stream)
	local raw_value = value
	
	-- Find qualifier flag value if given value as name
	if ( type(value) == "string" ) then 
		raw_value = IO_getQualifierFlagValue(data_type, value, stream)
	end
	
	-- Set buffer's qualifier to new data's type
	if ( set_qualifier ) then
		BW_resetNPCBuffer(npc)
		setBufferQualifierID(data_type, npc, stream)
	end
	
	-- Set value
	BW_tweak32Value( IO_getQualifiersIndexOfData(data_type, stream), IO_getQualifierDataSize(data_type, stream), raw_value, npc )
end

-- TODO "getQualifiedData"??
-- IO_getData()		--	Specific requests for specific parts of the 32buffer for npc. Low-level.
--					--
function IO_getData(data_type, npc, stream)
	return BW_get32Value(IO_getQualifiersIndexOfData(data_type, stream), IO_getQualifierDataSize(data_type, stream), npc)
end
	
local function getNumber32Streams()
	local stream_count = 0
	local incl_bits = getInclBitArray()
	
	for i = 1, 5, 1 do
		if(incl_bits[i] == 1) then 
			stream_count = stream_count + 1
		end
	end
	
	return stream_count
end

local function IO_tryOptimizeStream(freshness_arr)
-- TODO Bot death with no minions (INCL on buyback instruction), No frames sent / received
--		5-stale (throw error). Bot told to AFK farm / is tp-less split pusher.
	BOOTY_getOptimizeMetrics() -- TODO
end

-- TODO move up
-- IO_feed():		--	Returns new index_of_data_start or nil if feed of payload
					--	completed in the stream. So, the index_of_data_start value
					-- 	would be stored and sent with the same data in the next feed
					--	for this bot, to take more data off the queue of the IO_feed()
					--	calling file (shoulbe be io_dock).
					--	This is the function formulating data-buffer frames (unpacked
					--	inside DOCK_readData()).
function IO_feed(data, index_of_data_start, data_sizes)
	-- Formulate frames (if needed)
	local fresh
	local index_of_data_start_arr = {}

	if(#data > 1) then -- BOOTY WRITES
		local skip_count -- Indicates how many bots have been skipped via incl_bits, incrementing in order. Can deduce INCL_BIT.
		local bots_included = getInclBitArray()
		local num_bots_included = numberNPCIncluded()
		local allies = SWOOTY_getPlayerList()
		local new_prev_frames = {}
		
		lockSwootyWrite()						-- SWOOTY "LOCK"
		
		-- TODO DOCK_confirmNoOverwrite(is_booty_call) ?? What does this mean
		-- Freshness checks
		fresh = freshCheck(FEEDING, data, booty_prev_frames_fed, booty_frames_old_fed)
		--IO_tryOptimizeStream(fresh)
		if(_TEST) then print("[io_stream]: Setting data: "..DEBUG_printableValue(data)) end
		
		data, data_sizes = removeSkippedData(data, data_sizes, fresh, bots_included)
		
		skip_count = getSkipCount(fresh, bots_included)
		
		if(_TEST) then print("[io_stream]: Setting data: "..DEBUG_printableValue(data)) end
		
		-- Set32Data for included bots with fresh frames
		for i = 1, #data, 1 do
		 -- TODO can some of this be abstracted / made faster and put outside of lock?
			if(fresh[i] == 0 and bots_included[i] == 1) then -- Are we writing?
				if(_TEST) then print("NIL: "..DEBUG_printableValue(num_bots_included)) end
				this_orientation = frame32_orientations[num_bots_included][i]
				this_data = mFloor(data[i] / 2^(mMax(this_orientation - data_sizes[i], data_sizes[i], this_orientation))) -- TODO Abstract

				index_of_data_start[i] = index_of_data_start[i] + 
						BW_set32Value( (i-1) * this_orientation % INT_SIZE,
							frame32_orientations[num_bots_included][i], 
							data[i],
							allies[i])
							
				index_of_data_start_arr[i+skip_count[i]] = this_orientation
				
				if(skip_count[i] > skip_count[i - 1]) then
					for j = skip_count[i - 1]+1, skip_count[i], 1 do
						index_of_data_start_arr[j] = BUFFER_STALE_OR_BOT_BOOTED -- These bots indexes were skipped via the skip_count. 
					end
				end
				fresh[i] = 0
				new_prev_frames[i] = this_data
			else
				new_prev_frames[i] = booty_prev_frames_fed[i]
			end
		end
		freeSwootyWrite()		-- SWOOTY "FREE"
		
		myFreshnessGetFresher(FEEDING, new_prev_frames, fresh)
	else -- SWOOTY WRITE
		local swooty_auth = checkSwootyWriteAuthorization()
		if(not swooty_auth == true) then
			return swooty_auth
		end
		local this_npc = GetBot()
		-- TODO TODO TODO
	end
	
	-- Return index of the frame which would be pushed to the buffer next from the
	-- io_dock queue, or nil, if the frame has been fully pushed.
	return index_of_data_start --+ bits_pushed
end

-- IO_read():		--	Counter-part to IO_feed(). Returns all data which pertains to the
					--	calling bot's designated data frame. As indicated by the leading
					--	INCL_BITs for each bot. In the case of a BOOTY-read for BOOTY,
					--	returns an array of 5 data frames pertaining to each bot's 
					--	available, or (nil) unavailable Frame+PING pairs.
					-- 	
-- TODO Sleep-deprived. Re-eyeball this.
--		I think this needs more mathematical deduction for conciseness.
-- TODO Edge case: prev_frame_fed if BOOTY_IN sets same frame twice??
-- TODO IMPORTANT UTIL_getFrameBitSize of frame, create an offset-index so that leading zeroes are present.
function IO_read(is_booty_call) -- TODO This could be cleaner, but probably only by abstractions. More complex code local pre-defined.
	local this_npc = GetBot()
	local player_id = SWOOTY_getT32PID(this_npc:GetPlayerID())
	local allies = SWOOTY_getPlayerList()

	local first_buffer_and_index
	local frame_data
	local skip_count
	local bots_included = getInclBitArray()
	local num_bots_included = numberNPCIncluded()
	local bits_to_read
	local bits_read
	
	if(is_booty_call) then 
		local my_buffer_data = {}
	
	else
		local buffer_and_index = {0, 0} -- Abstract gets
		local this_frame32_orientation = frame32_orientations[num_bots_included]
		local included_bots_before_me = 0
		local frame_data = nil
		
		if(bots_included[player_id] == 1) then
			for i = 1, player_id-1, 1 do
				included_bots_before_me = included_bots_before_me + bots_included[i]
				if(included_bots_before_me > 0) then
					buffer_and_index[2] = buffer_and_index[2] + this_frame32_orientation[included_bots_before_me]*bots_included[i]
				end
			end
			bits_to_read = this_frame32_orientation[included_bots_before_me+1]
			buffer_and_index[1] = mMax(mCeil( buffer_and_index[2] / 32 ), 1)
			buffer_and_index[2] = buffer_and_index[2] % 32
		
			this_buffer = buffer_and_index[1]
			local this_buffer_PID = allies[this_buffer]:GetPlayerID()
			if(_TEST) then print("My data is at index "..buffer_and_index[2].." of size "..bits_to_read.." inside bot PID#"..SWOOTY_getT32PID(this_buffer_PID)) end
			frame_data, bits_read = BW_get32Value(buffer_and_index[2], bits_to_read, allies[buffer_and_index[1]])
			if(freshCheck(READING, frame_data, prev_frame_read, frames_old_read)) then -- TODO what
				prev_frame_read = frame_data
				frames_old_read = 0
			else
				if(_TEST) then print("[io_stream] Stale frame in buffer") end
				return nil
			end
		else
			bits_read = 0
		end
		
		return frame_data, bits_read
	end
end


removeSkippedData = function(data_tbl, data_sizes_tbl, fresh_array, incl_bits)
	for i = #data_tbl, 1, -1 do
		if(fresh_array[i] > 0 or incl_bits[i] == 0) then
			print("fresh "..fresh_array[i]..". incl_bits "..incl_bits[i]..".")
			table.remove(data_tbl, i)
			table.remove(data_sizes_tbl, i)
		end
	end
	
	return data_tbl, data_sizes_tbl
end

-- flipInclBit()			-- Flips the player ID's INCL_BIT
							--
							-- 
flipInclBit = function(npc)
	local player_id = SWOOTY_getT32PID(npc:GetPlayerID())
	local player_incl_index = INCL_BIT_SIZE+(player_id-1)
	local curr_incl_val = BW_getPingValue(player_incl_index, 1, GetBot()) -- TODO must be team captain
	
	BW_setPingValue(player_incl_index, 1, (curr_incl_val+1)%2)
end

checkIncluded = function(npc)
	local player_id = SWOOTY_getT32PID(npc:GetPlayerID())
	local player_incl_index = INCL_BIT_SIZE+(player_id-1)
	
	return (BW_getPingValue(player_incl_index, 1) == 1) and true or false
end

getInclBitArray = function()
	local incl_bits = {}
	local incl_bit_flags = BW_getPingValue(5, 5, team_captain)
	
	for i = INCL_BIT_SIZE, 1, -1 do
		incl_bits[i] = incl_bit_flags % 2
		incl_bit_flags = mFloor(incl_bit_flags / 2)
	end
	
	return incl_bits
end

-- getSkipCount()	-- Returns the count of bots that will have been skipped when feeding
					-- bots frames. Deduced by who was fresh.
-- TODO decreasing the number of elements in the skip count array, makes it harder to write loops? It requires more if statements to use?
getSkipCount = function(fresh_array, incl_array)
	local skip_count = {}
	local OPERATION_INDEX = 0
	
	-- E.g.: [0,0,2,0,1] -> [0,0,1,1,2]; [4,1,0,2,0] -> [2,3,3]
	table.insert(skip_count, 0) -- To complete loop logic
	for i = 1, 5, 1 do												-- [4,		  1,		  0,		  2,		  0]
		if(fresh_array[i] > 0 or incl_array[i] == 0) then			--i=1		| 2			| 3			| 4			| 5			|
			table.insert(skip_count, skip_count[#skip_count] + 1)	-- [0, 1]	| [1, 2]	|			| [2, 2, 3]	|			|
			table.remove(skip_count, #skip_count - 1)				-- [1]		| [2]		|			| [2, 3]	|			|
		else														--			|			| [2, 2]	|			| [2, 3, 3]	|
			if(#skip_count == 0) then
				table.insert(skip_count, 0)
			else
				table.insert(skip_count, skip_count[#skip_count])		
			end
		end
	end
	table.remove(skip_count, 1)
	skip_count[OPERATION_INDEX] = 0 -- This is for loop-logic purposes. This number is used in io_feed() for e.g.
	
	return skip_count
end

-- TODO two below share incl_bit_array. Optimize with args or some otherwise
getNPCFirstBufferAndIndex = function(player_id)
	local bots_included = numberNPCIncluded()
	local incl_bit_array = getInclBitArray()
	local bits_explored = 0
	local skipped = 0
	local index_of_data_in_my_buffer = 0
	local bots_included_before_me
	
	if(incl_bit_array[player_id] == i) then 
		return nil
	end
	
	for i = 1, #player_id-1, 1 do
		if(incl_bit_array[i] == 1) then 
			bits_explored = bits_explored + frame32_orientations[bots_include][i - skipped]
			index_of_data_in_my_buffer = (index_of_data_in_my_buffer + frame32_orientations[bots_included][i-skipped]) % INT_SIZE
		else
			skipped = skipped + 1
		end
	end
	
	bots_included_before_me = player_id - skipped
	
	return { bits_explored / bots_included_before_me, bits_explored % INT_SIZE }
end

numberNPCIncluded = function()
	local incl_array = getInclBitArray()
	
	return incl_array[1] + incl_array[2] + incl_array[3] + incl_array[4] + incl_array[5]
end

-- Not necessarily correct if the buffer is set at variables spaces, but I think IO_feed() would take that kind of operation anyways, these are raw, low-level sets.
setBufferQualifierID = function(data_type, npc, stream)
	BW_tweak32Value( QUALIFIER_INDEX, QUALIFIER_SIZE, IO_getQualifierIndex(data_type, stream), npc )
end

-- IO_isIncludedIn32Buffer	--	Checks leading bits, returns if npc is included in the 
							--	INT_32 buffer.
function IO_isIncludedIn32Buffer(npc)
	local incl_bits = getInclBitsArray()
	
	return IO_confirmFlagEquals(5, incl_bits[SWOOTY_getT32PID(npc:GetPlayerID())], "INCL")
end