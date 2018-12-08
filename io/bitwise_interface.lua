-- Simulating 32-bit integer bitwise operations on ??-type Lua integer variables. This simulates 
-- signed integer overflows...

-- TODO Not much here is boundary safe. Test how much overhead safety gives you.

-- TODO When receiving negative numbers, they need to be stored as positive numbers, so that all the
-- arithmetic works as usual, but once data is requested, leading 1s need to be read in and return
-- the negative value. Probably just parse through the signedNegativeToPositive.

local INT_SIZE = 32
local MAX_BIN_INDEX = INT_SIZE - 1
local MAX_ABS_NUMBER = 2^(INT_SIZE - 1) -- 2,147,483,648

-- Ping arithmetic types
local PING_SIZE = 44
local PING_COORDINATE_SIZE = 22
local PING_SPLIT = 1
local PING_COMBINE = 2

local _DEBUG = true
local _TEST = false

local curr_arithmetic_size = INT_SIZE

local mFloor = math.floor
local mMin = math.min

-- BW_modSignedNegative()		--	Takes a negative number, and mods it, safely keeping
								--	simulated bit-order. 
function BW_modSignedNumber(val, bit_length, mod_val, return_neg)
	local leading_one = false
	if(val < 0) then
		val = BW_signedNegativeToPositive(val, bit_length)
	end
	if(mod_val < 1) then
		return val -- TODO Errors?
	end
	val = val % 2^mod_val
	if(UTIL_getBitLength(val) == 2^(bit_length-mod_val)) then
		leading_one = true
	end
	if(not return_neg == nil and return_neg and leading_one) then -- TODO sneaky
		return BW_unsignedPositiveToNegative(val, bit_length-mod_val), leading_one
	end
	return val, leading_one
end

function BW_divSignedNumber(val, bit_length, div_val)
	if(div_val < 1) then
		return val -- TODO Errors?
	end	
	
	val = BW_signedNegativeToPositive(val, bit_length)
	
	val = mFloor(val / 2^div_val)
	
	return BW_unsignedPositiveToNegative(val, bit_length-div_val)
end

function BW_multiplySignedNumber(val, bit_length, mul_val)
	local was_packed = (val < 0)
	
	if(mul_val < 1) then 
		return val
	end
	if(was_packed) then
		val = BW_binFLIP(val)
	end

	val = val * 2^mul_val
	
	if(was_packed) then
		local return_val = BW_binFLIP(val)
		return return_val
	end
	
	return val
end

function BW_xBitsSignedValueOverflow(val, bit_length)
	val_length = UTIL_getBitLength(val)
	
	if(val_length == bit_length) then -- Overflowing
		return BW_unsignedPositiveToNegative(val, bit_length)
	elseif(val_length < bit_length) then 
		return val
	elseif(val < 0) then
		-- It's already simulated unsigned, or if a negative LUA integer, no way to know,
		-- and this function shouldn't've received it anyways.
		return val 
	elseif(val_length > bit_length) then 
		if(_DEBUG) then 
			print("[bitwise_interface]: Attempt to check overflow for value larger than bit length (val = "..
				val..", bit_length = "..bit_length".\n"..debug.traceback())
		end
		return val
	end
end

-- BW_signedNegativeToPositive()	--	Takes an unsigned, negative number, returns what the
									--	number would otherwise be, if it was not signed--for
									--	the purpose of interpreting trailing frames, or easy
									--	manipulation of bit-data. This is not a regular signed
									--	to unsigned operation. Those operations are below.
function BW_signedNegativeToPositive(val, bit_length)
	local highest_bit_magnitude = 2^(bit_length)
	if(val > 0) then 
		if(_DEBUG) then
			print("[bitwise_interface]: Attempt to make positive a positive number BW_signedNegativeToPositive(val = "..val..
				", bit_length = "..bit_length..".\n"..debug.traceback())
		end
		return val
	end
	return highest_bit_magnitude + val
end

-- TODO These are technically called "positiveToSignedNegative", and "negativeToUnsignedPositive", because of the range check.
function BW_unsignedPositiveToNegative(val, bit_length)
	local highest_bit_magnitude = 2^(bit_length)
	if(val < 0) then 
		if(_DEBUG) then
			print("[bitwise_interface]: Attempt to make signed negative a negative number BW_unsignedPositiveToNegative(val = "..val..
				", bit_length = "..bit_length..").\n"..debug.traceback())
		end
		return val
	end
	
	return -(highest_bit_magnitude) + val 
end

-- BW_interpretSignedInt()	--	Takes a signed integer that was stored in the buffer, and
							--	returns it as it's regular LUA integer value. All non-flag
							--	number values need to be stored as signed integers, to allow
							--	for negative numbers in the buffer (so increase your integer
							--	bit sizes in presets by 1!)
function BW_signedToUnsigned(val, bit_size_of_data)
	local unsigned_int
	local max_abs_val = 2^(bit_size_of_data)
	
	if(val < max_abs_val) then
		unsigned_int = -max_abs_val + (val % max_abs_val)
	else
		unsigned_int = val
	end
	
	return unsigned_int
end

function BW_unsignedToSigned(val, bit_size_of_data)
	local signed_int
	local max_pos_val = 2^(bit_size_of_data-1)
	
	if(val < 0) then
		if(val < -(max_pos_val + 1)) then -- Is this too large to sign?
			print("[bitwise_interface]: Attempt convert out-of-range integer unsignedToSigned(val = "..val..
				", bit_size_of_data = "..bit_size_of_data..
				") lim(-"..2^bit_size_of_data..", "..((2^bit_size_of_data)-1)..").\n"..
				debug.traceback())
			return nil
		else
			return max_abs_val + (val % max_abs_val) -- Leading signed bit (negative), plus the value
		end
	else
		if(val > max_pos_val) then -- Is this too large to sign?
			print("[bitwise_interface]: Attempt convert out-of-range integer unsignedToSigned(val = "..val..
				", bit_size_of_data = "..bit_size_of_data..
				") lim(-"..2^bit_size_of_data..", "..((2^bit_size_of_data)-1)..").\n"..
				debug.traceback())
			return nil
		else
			return val -- Positive and allowable size
		end
	end
end

-- BW_binFLIP()		--	Not actually a bit flip, it simulates it by returning what a 32-bit 
					--	signed int would evaluate to if it stored x, and was flipped. 
					--	Set arith_size if you need to check a positive number didn't overflow
					--	a negative signed "33rd bit"
function BW_binFLIP(x, arith_size)
	local new_x = -(x + 1)
	if(arith_size == nil) then
		return new_x
	end

	if(new_x < -2^arith_size) then -- Flipping gave us a "33rd bit" signed L-1, because of L-1 positive flipped in 32.
		new_x = new_x + (2^arith_size) -- Plus the "33rd bit" value. Becomes positive.
	end
	
	return new_x
end

-- binShiftL()		--	For clearSpace(), and other simple shifts of pre-set values; to
					--	perform AND operations / clear our specific bits of a INT_32.
					--	TODO This is pretty hacky shifting.
					--	TODO Wider use now
					-- 	TODO this doesn't overflow to bottom -- used in that sense in some functions below. Why not *2^n??
function BW_binShiftL(num, n, ...)
	local args = {...}
	local prev_arithmetic_size = curr_arithmetic_size
	local num_was_negative = (num < 0)
	local top_val
	local bot_val
	local new_num = num
	local highest_ord_magnitude
	local out_of_range
	
	--print("binshiftL got: "..num..". args = "..DEBUG_printableValue(args))
	if(#args > 0) then
		curr_arithmetic_size = args[1]
	end

	highest_ord_magnitude = 2^(curr_arithmetic_size)
	
	out_of_range = (new_num < -highest_ord_magnitude or new_num > (highest_ord_magnitude - 1))
	
	if(out_of_range) then
		print("[bitwise_interface] "..GetBot():GetUnitName()..
			": Number passed greater than arithmetic size. BW_binShiftL(num = "..num..", n = "..n..
			((#args > 0) and ", arith_size = "..args[1] or "")..
			").\n"..debug.traceback())
		return nil
	end
	
	if(num_was_negative) then
		new_num = BW_binFLIP(num, curr_arithmetic_size)
	end
	
	top_val = (new_num % 2^(curr_arithmetic_size - n)) * 2^n -- bot bits now high
	bot_val = mFloor(new_num / 2^(curr_arithmetic_size - n)) -- top bits now low
	
	new_num = top_val + bot_val

	if(num_was_negative) then
		new_num = BW_binFLIP(new_num, curr_arithmetic_size)
	elseif(new_num > (highest_ord_magnitude-1)) then
		new_num = BW_unsignedPosToNegative(new_num, curr_arithmetic_size)
	end
	
	curr_artithmetic_size = prev_arithmetic_size
	return new_num
end

-- binShiftR()		-- Simulates binary right by n. Simulates overflowing.
					--
local function binShiftR(num, n)
	--print("binShiftR("..num..", "..n..")")
	if ( n > 0 and n < 32 ) then
		local flipped_num = BW_binFLIP(num, curr_arithmetic_size)
		
		if ( num < 0 ) then -- 1...?
			if ( flipped_num % 2 == 1 ) then -- 1...0 (final bit of real number is 0) Going positive
				num = (flipped_num - 1) / 2
				num = 2^(curr_arithmetic_size - 1) + BW_binFLIP(num, curr_arithmetic_size)
			else -- 1...1
				num = num / 2
			end
		else -- 0...?
			if ( num % 2 == 1 ) then -- 0...1 Going negative
				if ( num == 1 ) then -- edge case
					return binShiftR(0, n-1) 
				end
				
				if ( flipped_num % 2 == 1 ) then
					flipped_num = flipped_num + 1
				end
				num = flipped_num / 2
				num = 2^(curr_arithmetic_size - 1) - BW_binFLIP(num, curr_arithmetic_size)
			else -- 0...0
				num = num / 2
			end	
		end
		
		return binShiftR(num, n-1)
	end
	
	return num
end

-- Not used, only as inspiration.
-- TODO Go look at a list of rules from discrete mathematics, you might optimize via proofs
local function binXOR(x, y) -- Cheers Arno Wagner.
   local z = 0
   for i = 0, curr_arithmetic_size-1 do
      if (x % 2 == 0) then                      -- x had a '0' in bit i
         if ( y % 2 == 1) then                  -- y had a '1' in bit i
            y = y - 1 
            z = z + 2 ^ i                       -- set bit i of z to '1' 
         end
      else                                      -- x had a '1' in bit i
         x = x - 1
         if (y % 2 == 0) then                  -- y had a '0' in bit i
            z = z + 2 ^ i                       -- set bit i of z to '1' 
         else
            y = y - 1 
         end
      end
      y = y / 2
      x = x / 2
   end
   return z
end

-- Unused.
local function binOR(x, y)
	local z = 0

	if(x < 0) then
		local x_len = UTIL_getBitLength(x)
		x = BW_signedNegativeToPositive(x, x_len)
	end
	if(y < 0) then
		local y_len = UTIL_getBitLength(y)
		y = BW_signedNegativeToPositive(y, y_len)
	end
	for i = 0, curr_arithmetic_size-1 do 
		if (x % 2 == 1)	then 
			x = x - 1
			if (y % 2 == 1) then 
				y = y - 1
			end
			z = z + 2^i
		elseif (y % 2 == 1) then
			y = y - 1
			z = z + 2^i
		end
		x = x / 2
		y = y / 2
	end
	
	if(z > 2^(curr_arithmetic_size-1)) then
		z = BW_unsignedPositiveToNegative(z, curr_arithmetic_size)
	end
	
	return z
end

-- binAND()		--	Not as bad as it looks, mainly the top 12 lines of code.
				--  TODO Will this return negative for L-1?
local function binAND(x, y) 
	local z = 0
	
	for i = 0, curr_arithmetic_size-1 do
			--print(x..".."..y..".."..z)
		if (i > 0) then -- Main iteration
			if (x % 2 == 1) then
				x = x - 1
				if (y % 2 == 1) then
					y = y - 1
					z = z + 2^i
				end
			else
				if (y % 2 == 1) then
					y = y - 1
				end
			end
			y = y / 2
			x = x / 2
		else -- Check if negative before ints are known positive (on first division)
			local x_neg = x < 0
			local y_neg = y < 0
			local flipped_x = BW_binFLIP(x)
			local flipped_y = BW_binFLIP(y)
			local flipped_x_even = flipped_x % 2 == 0
			local flipped_y_even = flipped_y % 2 == 0
				
			if ( flipped_x_even and flipped_y_even ) then
				z = 1 -- First (unflipped) bits are both 1
			end
			
			-- Prepare x and y values to be shifted right, and made positive by binShiftR()
			if ( x_neg ) then
				if ( flipped_x % 2 == 0 ) then	-- 	Make sure final bit is 0 (hacky way to 
					x = flipped_x + 1			--	use bitShiftR() to go to positive x val)
					x = BW_binFLIP(x)
				end
			elseif ( x % 2 == 1 ) then 
				x = x - 1
			end
			
			if ( y_neg ) then 
				if ( flipped_y % 2 == 0 ) then	-- 	^^ As above ^^
					y = flipped_y + 1		
					y = BW_binFLIP(y)
				end
			elseif ( y % 2 == 1 ) then 
				y = y - 1
			end
			-- Shift and make positive
			x = binShiftR(x, 1)
			y = binShiftR(y, 1)
		end	-- x & y now positive in for loop
	end
	
	return z
end

-- getFilterBin() 	-- 	Returns a binary number to be used for filtering data e.g.: 
					--	for index:0, size:10; 11111111 11000000 00000000 00000000 
					--	can be used for easily filtering the qualifier value. 
local function getFilterBin(index, size)
	local filter = (2^(size)) - 1	-- Set 1s at tail of int
	
	filter = BW_binShiftL( filter, curr_arithmetic_size-(index+size)) 	-- Shift 1s left to the space
																		-- to be cleared
	return filter
end

-- clearSpace() 	--	Returns the payload with the given bits inside bounds
					--	of INT_32[index..index+size] set to 0.
local function clearSpace(index, size, payload)
	local zeroes = BW_binFLIP(getFilterBin(index, size), curr_arithmetic_size)
	--print("zeroes:: "..zeroes.." AND "..payload.." = "..binAND(zeroes, payload) )

	return binAND(zeroes, payload) 
end

-- formatValue()	--	Puts value at index in base 2 for an INT_32
					--
local function formatValue(index, size, value)
	return BW_binShiftL(value, curr_arithmetic_size-(index+size))
end

-- insertValue()	--	Inserts the value passed to the a copy of the previous data
					--	Formats data, keeps current payload outside of given value's bounds 
					--	and returns the updated buffer.
local function insertValue(index, size, value, prev_payload)
	if(size < 1) then 
		return prev_payload
	end
	--print("insertVal(index = "..index..", size = "..size..", val = "..value..", prev_payload = "..prev_payload..").")
	local insert_val = formatValue(index, size, value)
	--print("insertVal : formated value: "..insert_val.."... clearing space and inserting...")

	return binOR(clearSpace(index, size, prev_payload), insert_val)
end

-- getValue()		--	Returns the value stored inside INT_32[index..index+size] of the
					--	given payload.
local function getValue(index, size, payload)
	local indexes_wanted = getFilterBin(index, size)
	--print("getValue(index = "..index..", size = "..size..", payload = "..payload..")")
	--print("binAND(payload = "..payload..", indexes_wanted = "..indexes_wanted..") == "..binAND(payload, indexes_wanted)..")")
		--print ("getValue(): getFilterBin() = "..indexes_wanted..". Returning value "..binShiftR( binAND(payload, indexes_wanted), curr_arithmetic_size-(size+index)).." from payload "..payload..".")
	return binShiftR( binAND(payload, indexes_wanted), curr_arithmetic_size-(size+index))
end


local function createNewPingCoordinates(index, size, value)
	local this_npc = GetBot()
	local prev_ping = this_npc:GetMostRecentPing()
	local new_ping = {0, 0}
	
	curr_arithmetic_size = 22
	if(index < PING_COORDINATE_SIZE) then 
		local value_in_vector = {0, 0}
		local bits_in_2nd_vector = index + size - PING_COORDINATE_SIZE
		
		if(index + size > PING_COORDINATE_SIZE) then -- Value split over both coordinates
			value_in_vector[1] = mFloor(value / 2^(bits_in_2nd_vector)) -- Top segment of value
			value_in_vector[2] = value % 2^(bits_in_2nd_vector) -- bottom segment of value
			value_in_vector[2] = value_in_vector[2] * 2^(PING_COORDINATE_SIZE - bits_in_2nd_vector) -- Pushed to sit in bit-order via magnitude
			new_ping[1] = insertValue(index, size - bits_in_2nd_vector, value_in_vector[1], prev_ping.location[1])
			new_ping[2] = insertValue(0, size - bits_in_2nd_vector, value_in_vector[2], prev_ping.location[2])
		else -- Value totally within first coordinate
			new_ping[1] = insertValue(index, size, value, prev_ping.location[1])
			new_ping[2] = prev_ping.location[2]
		end
	elseif(index >= PING_COORDINATE_SIZE) then -- Value totally within second coordinate
		local this_index = PING_COORDINATE_SIZE - index
		new_ping[1] = prev_ping.location[1]
		new_ping[2] = insertValue(this_index, size, value_in_vector[2], prev_ping.location[2])
	end
	if(_TEST) then print("CreateNewPingCoordinates v1: "..DEBUG_printableValue(new_ping[1])..", v2: "..DEBUG_printableValue(new_ping[2])) end
	
	return new_ping
end

-- Sets a leading 0 if a positive number is being set.
function setLeadingBit(index, value, npc)
	if(value < 0) then
		return 0
	end
	
	npc:SetNextItemPurchaseValue(clearSpace(index, 1, npc:GetNextItemPurchaseValue()))
	
	return 1
end

function set32Data() -- TODO
end

-- getMyPayload()		--	Return INT_32 buffer for LUA state's bot.
						--
function BW_get32Payload(npc)
	return npc:GetNextItemPurchaseValue()
end

function BW_getPingPayload(npc)
	return npc:GetMostRecentPing()
end

function checkPositive_Set32(index, bit_size, value, bit_lost, npc) -- TODO for abstraction (return new size, new val)
	local bits_available = INT_SIZE - index - bit_lost
	local this_write_size = mMin(bits_available, bit_size)
	local value_bits_written = this_write_size
	local this_index = index + bit_lost
	local new_payload
	local new_val = value
	--print("checkPositive_Set32(index = "..index..", bit_size = "..bit_size..", value = "..value..", bit_lost = "..bit_lost..", npc = "..npc:GetUnitName())
	
	if(bit_size > bits_available) then 
		new_val = BW_divSignedNumber(value, bit_size, bit_size - this_write_size)
	elseif(this_write_size+2 < bits_available) then
		new_val = BW_multiplySignedNumber(new_val, bit_size, 2) -- Hacky way to set double 0
		--print("checkPos-set newval = "..new_val)
		this_write_size = this_write_size + 2
	elseif(this_write_size+1 < bits_available) then -- Special case, need to put 2nd of double 0 next buffer
		local npc_ID = SWOOTY_getT32PID(npc:GetPlayerID())
		new_val = new_val * 2 -- Sets first of double 0
		this_write_size = this_write_size + 1
		if(npc_ID < 5) then -- Don't try write into "6th" bot, incase all bots included and it's 5th bot writing first frame
			local next_bot = SWOOTY_getPlayerList()[npc_ID+1]
			local prev_payload = BW_get32Payload(next_bot) 
			next_bot:SetNextItemPurchaseValue(createSpace(0, 1, prev_payload)) -- 2nd of double 0
		end
	end
	new_payload = insertValue(this_index, this_write_size, new_val, BW_get32Payload(npc))
	if(_TEST) then print("new_payload: "..new_payload) end
	npc:SetNextItemPurchaseValue(new_payload)
	
	value = BW_modSignedNumber(value, bit_size, bit_size-value_bits_written, true)

	return value, value_bits_written
end

-- public get32Value()	--	Interface for retreiving data, given bounds. This is a 
						--	low-level interface, and should only be used by another 
						--  interface with higher-level abstractions, and data_type 
						--	presets so that data can easily be interpreted. Don't edit 
						--	anything in this file unless you must be on some kind of 
						-- 	molly or powder or something.
-- TODO Automatic over-flow into next NPC's buffer for larger than allowable size.
--		Error on size greater than final buffer's bit.
function BW_get32Value(index, size, npc)
	local val = getValue(index, size, BW_get32Payload(npc))
	--print("get32 got raw val = "..val)
	local val_length = UTIL_getBitLength(val)
	--print("val = "..val)
	if ( val == nil ) then
		if (_DEBUG) then print("[bitwise_interface] "..npc:GetUnitName()..": value nil from getValue(index = "..index..", size = "..size..", npc = "..npc..".\n"..debug.traceback()) end
	end

	if(val_length == INT_SIZE) then 
		val = BW_unsignedPositiveToNegative(val, val_length)
	end
	
	return val, val_length
end

-- public tweak32Value()-- Tweaks the 32 value, doing no special checks or buffer-step-ups.
						-- No double 0s or positive checks. It takes a value and sets it at
						-- the given space. Mostly used for simple initializing calls and reads.
function BW_tweak32Value(index, size, value, npc)
	local new_val = insertValue(index, size, value, BW_get32Payload(npc))
	
	npc:SetNextItemPurchaseValue( new_val )
end

-- public set32Value()	--	Interface for setting NPC INT_32 buffer, given bounds, a
						--	value, and npc hUnit handle. Read above.
						-- 	Assumes caller has performed neccessary size / index boundary
						--	checks. Manually sets a 0 before positive packed frames, and
						-- 	for cases where the 32 runs out of frames to set, it sets a
						--	double 0, which is an impossible frame (because only qualifiers
						--	in the 2^9 - 2^10 range are passed as positive values)
						--
						--	If a frame ends, with 1 more bit available, it isn't set.
-- TODO need to make sure all negative values are correctly set in the data.
-- TODO Range and integer size checking
function BW_set32Value(index, size, value, npc)
	if(_TEST) then print("BW_set32Value(index = "..index..", size = "..size..", value = "..value..", npc = "..SWOOTY_getT32PID(npc:GetPlayerID())..":"..npc:GetUnitName()..").") end
	local split_frame_size = INT_SIZE - index
	local number32sUsed = (INT_SIZE - split_frame_size) + ((size - split_frame_size) / 2)
	local npc_ID = SWOOTY_getT32PID(npc:GetPlayerID())
	local bit_lost = setLeadingBit(index, value, npc) -- 1 if positive leading 0 set.
	
	local allies = SWOOTY_getPlayerList()
	local bit_size_after_first_frame = (size - INT_SIZE*(number32sUsed - 1)) -- Of the buffers, not the data.
	local value_bit_size = UTIL_getBitLength(value) -- bit length, plus any leading 0s for pos value.
	local after_1st_size
	local write_size
	local write_no_more_frames = false
	
	if( ( value_bit_size + (2*bit_lost) ) < (size + 2) ) then
		write_no_more_frames = true -- We have at least 2 trailing bits without data to set, so set double 0 no-frame flag.
	end
	
	-- First write (special case)
	value, after_1st_size = checkPositive_Set32(index, value_bit_size, value, bit_lost, npc)
	
	if(bit_lost == 1 and value_bit_size == size) then -- We can't post the final bit of data because positive shifts the buffer.
		value = BW_divSignedNumber(value, value_bit_size, 1)
	end
	value_bit_size = after_1st_size
	
	-- Peform overflowing write on next npc(s) buffer(s)
	if (number32sUsed > 1) then
		for i = 1, i < number32sUsed, 1 do
			value = BW_xBitsSignedValueOverflow(value, value_bit_size) -- Go negative if needed, for fitting leading 1s
			write_size = mMin(value_bit_size, INT_SIZE)
			-- Abstract the differnt types of writes, so double 0 auto-detected and set in that function.
			if(write_size == INT_SIZE) then
				allies[npc_ID + i]:SetNextItemPurchaseValue(BW_divSignedNumber(value, value_bit_size, value_bit_size - INT_SIZE))
			else
				local prev_payload = BW_get32Payload(allies[npc_ID + i])
				allies[npc_ID + i]:SetNextItemPurchaseValue(insertValue(0, value_bit_size, value, prev_payload))
				if(write_no_more_frames) then -- i.e. at least 2 bits trailing with no data to post.
					allies[npc_ID + i]:SetNextItemPurchaseValue(clearSpace(write_size, 2, BW_get32Payload(allies[npc_ID + i])))
				end
				i = 6 -- Exit
			end
			value_bit_size = value_bit_size - INT_SIZE
			value = BW_divSignedNumber(value, value_bit_size, INT_SIZE)
		end
	end
	
	return size - bit_lost
end

-- TODO hacky
-- Currently works with limit 22-bits. Need to implement a larger integer class. Adding 2 22-bit sequences together can lose precision. ?? Compiled to 32 bit? or using double?
function BW_getPingValue(index, size, npc)
	curr_arithmetic_size = PING_COORDINATE_SIZE
	
	local vector = BW_getPingPayload(npc)
	local this_22_frame
	local val
	
	if(index < PING_COORDINATE_SIZE) then
		this_22_frame = (vector.location[1] % 2^(PING_COORDINATE_SIZE - index+1)) * 2^(index) -- Take from index and shift up
		if(_TEST) then print(this_22_frame) end
		if(index > 0) then
			this_22_frame = this_22_frame + mFloor(vector.location[2] / 2^(PING_COORDINATE_SIZE - index)) -- 
		end
	elseif(index >= PING_COORDINATE_SIZE) then 
		this_22_frame = vector.location[2] % 2^((2*PING_COORDINATE_SIZE) - index)
		if(index > PING_COORDINATE_SIZE) then
			this_22_frame = this_22_frame * 2^(index - PING_COORDINATE_SIZE)
		end
	end
	
	--print("This ping 22-bit search frame: "..this_22_frame.." of v1: "..vector.location[1]..", v2: "..vector.location[2].." for i = "..index..", s = "..size..".")
	
	val = getValue(0, size, this_22_frame)
	
	--print("returning ping value: "..val)
	
	if ( val == nil ) then -- TODO Also for INT_32, what's condition where this is nil?
		if (_DEBUG) then print("[bitwise_interface] "..npc:GetUnitName()..": value nil from getValue(index = "..index..", size = "..size..", npc = "..npc..".\n"..debug.traceback()) end
	end
	
	curr_arithmetic_size = INT_SIZE
	return val
end

function BW_setPingValue(index, size, value)
	curr_arithmetic_size = PING_COORDINATE_SIZE
	
	--print("setting index: "..index..", size: "..size..", value: "..value.." for previous vector v1:"..GetBot():GetMostRecentPing().location[1]..",v2:"..GetBot():GetMostRecentPing().location[2].."...")
	local this_npc = GetBot()
	local new_vector = createNewPingCoordinates(index, size, value)
	if(_TEST) then print("new_vec - v1: "..DEBUG_printableValue(new_vector[1]).." v2:"..DEBUG_printableValue(new_vector[2])) end
	
	if(new_vector == nil) then 
		print("[bitwise_interface] "..GetBot():GetUnitName()..": Unable to form new ping vector from createNewPingCoordinates(index = "..index..", size = "..size..", value = "..value..")")
		return nil
	end
	
	this_npc:ActionImmediate_Ping(new_vector[1], new_vector[2], true)
	curr_arithmetic_size = INT_SIZE
end

-- resetNPCBuffer		--	Resets the npc's INT_32 buffer. 
						--
function BW_resetNPCBuffer(npc)
	npc:SetNextItemPurchaseValue(0)
end