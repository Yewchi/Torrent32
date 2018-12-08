-- TODO "Proceed no further" disclaimer. Let library users know their own application is
-- best coded in only in SWOOTY/BOOTY, io_presets, instruction_interperet, etc.. Everything
-- else should be too low-level, or else Torrent32 isn't finished, and is not well modulated.

-- TODO Currently bypassing queuing system for simple IN/OUT of less than 32 bits.

local instruction_interpreter = require("bots.io.instruction_interpreter")
local bitwise_interface = require("bots.io.bitwise_interface")
local io_stream = require("bots.io.io_stream")

-- TODO io_dock needs to know when booty is calling it's functions.
local _DEBUG = true
local _TEST = false

local mMax = math.max
local mFloor = math.floor
local mMin = math.min

-- BOOTY Queues --
-- BOT #:
--	OF:
-- INSTRUCTION #:
--		OF:
local DATA_INDEX = 1
local INDEX_INDEX = 2 
local BIT_LENGTH = 3
-- BOOTY Queues --

-- Feed/Read Queue --
-- INSTRUCTION #:
-- 	OF:
local FRAMES_INDEX = 1
-- 		OF:
-- FRAME #
--			OF:
local DATA_INDEX = 1
local DATA_SIZE_INDEX = 2
--	AND:
local INSTRUCTION_SIZE_INDEX = 2
-- Feed/Read Queue --

local SEP_INSTRUCTION_SIZE_INDEX = 3

local FRAMES_READ_BUT_NOT_COMPLETED = 0xFFFFFFE1
local FRAMES_READ_AND_RETURNED = 0xFFFFFFE2
local FRAMES_NOT_AVAIL = 0xFFFFFFE3

local FRAME_AWAITING_QUALIFIER = 0xFFFFFFE4

local FEEDING = 0
local READING = 1

local feed_queue = {}	-- [instruction#][frames][frame][data/size], [instruction#][instruction_size]
local prev_feed_frame_index
local read_queue = {}
local prev_read_frame_index
local booty_feed_queues	-- [bot][queue][frame][data/size], [bot][queue][instruction_size]
local booty_read_queues 

local instruction_bits_read
local qualifier_found

-- functions
local concatFrames
local separateInstructions
local initializeQueueInstruction


function DOCK_initialize(is_booty_call)
	if(is_booty_call) then
		booty_feed_queues = {}
		booty_read_queues = {}
		for i = 1, 5, 1 do
			booty_feed_queues[i] = {}
			booty_read_queues[i] = {}
		end
	else
		read_queue = {}
		feed_queue = {}
	end
end


-- Regular DOCK_pushData() calls:
--						SWOOTY: DOCK_pushData(data, data_type, size, stream)
--						SWOOTY: DOCK_pushData(packed_data)
--						BOOTY: 	DOCK_pushData(packed_data[;n=5])
-- DOCK_pushData()		--	Puts data on the etc etc. TODO
						--
function DOCK_pushData(data, ...)
	-- TODO Not sure how this will look when working, may need table of qualifier table
	-- 		types (having sub-stream-type SWOOTY or BOOTY). 
	local new_feed_frame_index
	local args = {...}
	
	if(data == nil) then
		return nil
	end
	
	-- Check valid args TODO automate via io_presets table of streams
	if(not stream == "SWOOTY" or not stream == "BOOTY") then 
		if(_DEBUG) then 
			print("[io_dock] "..GetBot():GetUnitName()..": DOCK_pushData(data_type = "..DEBUG_printableValue(data_type)..
					", value = "..DEBUG_printableValue(value)..", stream = "..DEBUG_printableValue(stream)..
					")... Invalid push data.\n"..debug.traceback()) 
		end
	end
	
	if (#args == 0) then
		if(#data > 1) then 
			--BOOTY
			for i = 1, #data, 1 do -- Insert each bot's feed data
				table.insert(booty_feed_queues[i], {data[i], 0, UTIL_getBitLength(data[i])})
			end
		else
			local payload, data_type, size, stream
			--SWOOTY
		end
	elseif(#args == 4) then
		--SWOOTY
	end
end


-- DOCK_setSail()		--	Pushes off top queue items into the buffer, (optimization and
						--	fresh-buffer checks allowing). Index of the data which would next
						--	be read for that (or all) datapacks are stored with the data, in
						--	queue. Receives 'nil' if buffer stale/bot booted.
function DOCK_setSail(is_booty_call)
	local new_indexes
	
	if(_TEST) then print(DEBUG_printableValue(booty_feed_queues)) end
	
	--TODO Not final impl. Actual queues will be separated for bots.
	if(is_booty_call) then 
		local data = {}
		local data_sizes = {}
		local index_of_data_start = {}
		for i = 1, 5, 1 do -- TODO Example of logic not required when cargo.lua impl.
			local q_length = #booty_feed_queues[i]
			data[i] = booty_feed_queues[i][q_length][DATA_INDEX]
			data_sizes[i] = booty_feed_queues[i][q_length][BIT_LENGTH]
			index_of_data_start[i] = booty_feed_queues[i][q_length][INDEX_INDEX]
		end
		-- TODO Run a IO_checkFrameSizes() that returns an array of 5, giving 0 for not included
		-- or the frame32_orientation for that bot. If pause_frame_in_buffer is true, return flag,
		-- don't feed data at all.
		if(data == nil) then 
			return nil
		end
		
		new_indexes = IO_feed(data, data_sizes, index_of_data_start)
		
		for i = 1, #new_indexes, 1 do
			if(new_indexes[i] == BUFFER_STALE_OR_BOT_BOOTED and new_indexes[i] == FRAME_NOT_SENT_FLAG) then
				
			else
				local q_length = #booty_feed_queues[i]
				if(getDataLengthInBits == new_indexes[i] and false) then -- TODO Test hack
					booty_feed_queues[i][q_length][INDEX_INDEX] = new_indexes[i]
					if(booty_feed_queues[i][q_length][INDEX_INDEX] == booty_feed_queues[i][q_length][BIT_LENGTH]) then
						table.remove(booty_feed_queues, q_length)
					end
				end
			end
		end
	else -- SWOOTY
	end
end

function DOCK_pullData(is_booty_call)
	local this_npc = GetBot()
	local reading_data = true
	local data
	local bits_read
	local this_frame
	local this_frame_size
	local completed_instructions = {}
	local stream = (is_booty_call) and "BOOTY" or "SWOOTY" -- TODO 2-stream only.
	
	data, bits_read = IO_read(false) -- TODO Hard-coded temp for test
	
	if(is_booty_call) then
	
	else -- SWOOTY
		local this_frame_needed_bits = 0
		local this_instruction_bits_total = 0
		
		if(#read_queue == 0) then
			initializeQueueInstruction(READING, 1)
		end

		-- Confirm qualifier size if able
		if(read_queue[1][INSTRUCTION_SIZE_INDEX] == nil) then -- No qualifier found for this frame yet, as new or from prev segment.
			if(#read_queue[1][FRAMES_INDEX] == 0) then -- First frame of this instruction?
				read_queue[1][INSTRUCTION_SIZE_INDEX] = II_getPackedDataSize(data, bits_read, stream)
				this_frame_needed_bits = read_queue[1][INSTRUCTION_SIZE_INDEX]
			else -- else we have segmented qualifier frame from previous read
				if(_TEST) then print("instruction segmnt found") end
				local qualifier_check_data
				qualifier_check_data = (read_queue[1][FRAMES_INDEX][1][DATA_INDEX] * 2^(bits_read)) + data
				bits_read = bits_read + read_queue[1][FRAMES_INDEX][1][DATA_SIZE_INDEX]
				read_queue[1][INSTRUCTION_SIZE_INDEX] = II_getPackedDataSize(qualifier_check_data, bits_read, stream)
				this_frame_needed_bits = read_queue[1][INSTRUCTION_SIZE_INDEX] - getQueueBitLengthRead(1)
			end
		else -- We have previous instruction segment, with qualifier found.
			this_frame_needed_bits = read_queue[1][INSTRUCTION_SIZE_INDEX] - getQueueBitLengthRead(1)
		end
		--
		
		-- Separate the instructions from buffer, and find completed instructions.
		local separated_instructions = separateInstructions(data, bits_read, this_frame_needed_bits, getQueueBitLengthRead(1), stream)
		if(_TEST) then print("tbl returned from sep_instn() is "..DEBUG_printableValue(separated_instructions).." with #separated_instructions = "..#separated_instructions..".") end
		for i = 1, #separated_instructions, 1 do
			-- Initialize new frame
			local num_frames = #read_queue[i][FRAMES_INDEX] + 1
			read_queue[i][FRAMES_INDEX][num_frames] = {}
			-- Insert
			read_queue[i][FRAMES_INDEX][num_frames] = {[DATA_INDEX] = separated_instructions[i][DATA_INDEX], [DATA_SIZE_INDEX] = separated_instructions[i][DATA_SIZE_INDEX]}
			--print("data_size_index from thingo: "..read_queue[i][FRAMES_INDEX][1][DATA_SIZE_INDEX])
			read_queue[i][INSTRUCTION_SIZE_INDEX] = separated_instructions[i][SEP_INSTRUCTION_SIZE_INDEX]
			if(getQueueBitLengthRead(i) == read_queue[i][INSTRUCTION_SIZE_INDEX]) then
				---print("Found completed instruction")
				local magnitude = read_queue[1][INSTRUCTION_SIZE_INDEX]
				completed_instructions[i] = 0
				for j = 1, #read_queue[i][FRAMES_INDEX], 1 do -- Add the value of the instruction together, frame by frame, dropping 2^magnitude by data size.
					magnitude = magnitude - read_queue[i][FRAMES_INDEX][j][DATA_SIZE_INDEX]
					completed_instructions[i] = completed_instructions[i] + 
							BW_multiplySignedNumber(read_queue[i][FRAMES_INDEX][j][DATA_INDEX], read_queue[i][FRAMES_INDEX][j][DATA_SIZE_INDEX], magnitude)
				end
			end
		end
		--
		
		-- Clear queue of completed frames
		for i = 1, #completed_instructions, 1 do
			table.remove(read_queue, i)
		end
		if(_TEST) then print("Completed instructions: "..DEBUG_printableValue(completed_instructions)) end
	end

	
	return completed_instructions
end

function DOCK_getQueueSize(is_booty_call)
	if(is_booty_call) then
		local total_in_queues = 0
		for i = 1, #booty_feed_queues, 1 do
			total_in_queues = total_in_queues + #booty_feed_queues[i]
		end
		
		return total_in_queues
	else
	end
end

-- Returns array of separated instructions from the frame. They may be just two segments, but split where required.
-- TODO: Post-frame double 0 detection. Post frame 1-bit cut.
separateInstructions = function(data, size_of_read, this_frame_needed_bits, curr_in_queue_size, stream)
	local data_and_size_array = {} -- Data for that frame and the size that was read
	local reading_data = true
	local bits_to_be_cut = size_of_read -- Size of bits we're working with
	local bit_size_of_remaining_val
	local instruction_size = this_frame_needed_bits + curr_in_queue_size
	local this_data_split
	local size_of_this_frame = mMin(size_of_read, this_frame_needed_bits)
	
	while(reading_data) do
		this_data_split = mMax(0, bits_to_be_cut - this_frame_needed_bits)
		if(bits_to_be_cut < this_frame_needed_bits) then -- Is this a split frame? More data after this frame?
			--print("new separated isntruction data = "..BW_divSignedNumber(data, bits_to_be_cut, this_data_split)..
			--	" size of this frame = "..size_of_this_frame..", instruction size = "..instruction_size)
			table.insert(data_and_size_array, 
					{BW_divSignedNumber(data, bits_to_be_cut, this_data_split),
					size_of_this_frame,
					instruction_size})
			curr_in_queue_size = 0 -- No longer needed.
		else -- It's not split
			table.insert(data_and_size_array, 
					{BW_divSignedNumber(data, bits_to_be_cut, this_data_split), 
					size_of_this_frame,
					instruction_size})
			return data_and_size_array
		end
		
		-- Same simulated bits, positive number.
		data = BW_modSignedNumber(data, bits_to_be_cut, bits_to_be_cut - size_of_this_frame)
		
		bits_to_be_cut = bits_to_be_cut - this_frame_needed_bits -- Take the previous read size from size of bits we're working with
		bit_size_of_remaining_val = UTIL_getBitLength(data)
		if(bits_to_be_cut == bit_size_of_remaining_val) then -- Would this have been a negative number?
			data = BW_unsignedPositiveToNegative(data, bits_to_be_cut)
		elseif(bits_to_be_cut > bit_size_of_remaining_val+1) then -- We found a double 0 at end of last frame. No further instructions -- TODO 2-bit start of next instruction?
			reading_data = false
		elseif(bits_to_be_cut == 1) then -- Unable to determine if a new frame start. set32Data wouldn't have written.
			reading_data = false
		end
		-- The above works for positive values at the end of frame, because they start with '01', meaning the bit_size_of_remaining can't be 2 over bits_to_be_cut
		
		if(bits_to_be_cut > QUALIFIER_SIZE) then
			instruction_size = II_getPackedDataSize(data, bits_to_be_cut, stream)
		elseif(bits_to_be_cut > 0) then 
			insturction_size = nil
		else
			reading_data = false
		end
		size_of_this_frame = mMin(bits_to_be_cut, instruction_size)
	end
	return data_and_size_array
end

-- TODO Optimize opportunity
-- concatFrames()		--	Returns the full value of an instruction, given the 
concatFrames = function(frame_and_size, is_booty_call)
	local concat = 0
	local bits_concated = 0
	
	if(is_booty_call) then
		for bot = 1, #frame_and_size, 1 do
			for frame = #frame_and_size[bot], 1, -1 do
				if(frame == #frame_and_size[bot]) then 
					concat = frame_and_size[frame][DATA_INDEX]
					bits_concated = frame_and_size[frame][DATA_SIZE_INDEX]
				else
					concat = concat + frame_and_size[frame][DATA_INDEX] * 2^bits_concated
					bits_concated = bits_concated + frame_and_size[frame][DATA_SIZE_INDEX]
				end
			end
		end
	else
		for i = #frames_and_size, 1, -1 do
			if(i == #frame_and_size) then
				concat = frame_and_size[i][DATA_INDEX]
				bits_concated = frame_and_size[i][DATA_SIZE_INDEX]
			else
				concat = concat + frame_and_size[i][DATA_INDEX] * 2^bits_concated
				bits_concated = bits_concated + frame_and_size[i][DATA_SIZE_INDEX]
			end
		end
	end
	
	return concat
end

initializeQueueInstruction = function(queue, instruction_index)
	if(queue == READING) then 
		read_queue[instruction_index] = {[FRAMES_INDEX] = {}, [INSTRUCTION_SIZE_INDEX] = nil}
	elseif(queue == FEEDING) then
		feed_queue[instruction_index] = {[FRAMES_INDEX] = {}, [INSTRUCTION_SIZE_INDEX] = nil}
	else
		if(_DEBUG) then 
			print("[io_dock] "..GetBot():GetUnitName().." Invalid queue given in initializeQueueInstruction(queue = "..queue..", index = "..instruction_index..
				").\n"..debug.traceback())
		end
	end
end

-- getQueueBitLengthRead()	--	Returns the full length of bits read for the instruction, 
							--	by adding DATA_SIZE_INDEX for each frame.
getQueueBitLengthRead = function(instruction_index)
	local total = 0
	local frames = read_queue[instruction_index][FRAMES_INDEX]
	
	if(#frames == 0) then -- There is no queue
		return 0
	end
	if(_TEST) then print(GetBot():GetUnitName()..": frames table: "..DEBUG_printableValue(frames)) end
	for frame = 1, #frames, 1 do
		if(#frames[frame] > 0) then
			total = total + frames[frame][DATA_SIZE_INDEX]
		end
	end
	
	
	if(_TEST) then print("getQueueBitLengthRead returning "..total) end
	return total
end