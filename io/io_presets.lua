--[[ 	This stores the table of SWOOTY/BOOTY data types which can be sent through the 32-bit
		ItemPurchaseValue ints--a group of up to 10 under-the-hood intergers which are 
		accessable and concurrent for any one bot's Lua states (see interpreter_interface.lua)
		
		Magic numbers suck, so this is going to get very large, very quickly, as data_type
		values are defined.
		
		There is no way to load a data file into these lua states, so every table must be
		hard-coded. You had to design your table of qualifiers anyways so, enjoy.
		
		TODO Now that we're using stream name "SWOOTY" or "BOOTY" to dictate which tables to work 
		with, we can use infinitely many different qualifier tables.I think special cases 
		like setting up captain roles should be indicated by a separate stream name, which 
		can allow high-level lua files to operate on them in a way they've defined for 
		themselves (e.g.: Don't allow SWOOTY to overwrite stream, don't allow captain to set
		next SWOOTY, force wait until crew sets flags). 
		
		TODO File can be much more terse and abstract itself.
		
		TODO This file being in IO is disconcerting. I think the presets tables, and the 
		interpreter both need to be in the same folder, separated from IO. Easier for devs
		to comprehend what they can best do to code their bots.
		
		TODO Explain somewhere "The stream is where the data is going to be read, or some other
		custom value defined by the developer, and caught somwhere in their opposite -OOTY &
		instruction_interpreter code"
		
		TODO The TC ping data could be used to store 4 or 5 bit "stream flags", allowing a bot
		to access which stream the data that is stored for a bot or booty is to be read as.
		
		TODO Want to change all function argument orders to (stream, data_type, value)
		
		TODO Disclaimer unsigned value for all non-flagged values, requires extra leading bit 
		for limits
		
		TODO Old functions still present, BOOTY/SWOOTY is now a stream, make it a generic 
		function
		
		TODO This is the worst file. It works, but good lord dude. Clean and boundary check
		literally every function.
--]]

local util = require("bots.util.util")

local _DEBUG = true
local _TEST = false

local BUFFER_SIZE = 32
local QUALIFIER_BITS = 10
local MIN_INDX = BUFFER_SIZE - QUALIFIER_BITS 	-- = 22. BOOTY only
local IO_MAX_QUALIFIER_INDEXES = 2^10 - 1 	-- 	= 1023 N.B.: If we run out of qualifiers, the leading bit of the qualifier 
											--	can act as a sign, giving us up to, e.g.:, 65536 qualifiers with 6 more bits.
											-- 	For efficiency, we would then designate the first 1023 qualifiers to the 
											-- 	largest and most commonly used data types.
local PING_MAX_SIZE = BUFFER_SIZE - QUALIFIER_BITS -- 22
local PING_MIN_INDEX = BUFFER_SIZE - PING_MAX_SIZE -- 10, the minimum data index (22nd bit)
local PING_MAX_BITS = (2^QUALIFIER_BITS) * (2^PING_MAX_SIZE)-- 2^(10) = 22528 bits for defining qualifer table values

local MAX_QUALIFIER_ID = 2^QUALIFIER_BITS

local NAME_INDEX = 1
local SIZE_INDEX = 2
local INDEX_INDEX = 3 -- BOOTY only
local ID_INDEX = 4 -- BOOTY only

local SWOOTY = "SWOOTY"
local BOOTY = "BOOTY"
local TC_FLAGS = "TC_FLAGS"

-- Team Captain's ping flag type indexes
TC_PING_3_BIT_BUFFER = 0
TC_PING_SWOOTY_LOCK = 3

local NAME_INDEX = 1
local SIZE_INDEX = 2

-- function
local reverseFlagsTable

-- SWOOTY_qualifiers[][2]: 	-- Main qualifier data. Types of data, their name, and their size in 
						-- the buffer. 
local SWOOTY_qualifiers = {
--	[i] = 	{"NAME" 		SIZE 		
	[1] = 	{"MISC", 		127},
	[2] = 	{"CAPTAIN",		2},
	[3] = 	{"ROLE", 		3},
	[128] = {"MOVE", 		6},
	[1023]= {"STREAM",		2}	
}

-- TODO Should be automatically generated from the main qualifier
-- table. Much easier to maintain and less prone to data entry errors.
-- SWOOTY_qualifier_identifiers[]: --
					-- An index storing the ID for each qualifier. Basically a large
					-- table of constants. ID's retreivable by 
					-- getQualifierIndexByName(string)
local SWOOTY_qualifier_identifiers = {
	["MISC"] = 1,
	["CAPTAIN"] = 2,
	["ROLE"] = 3,
	["MOVE"] = 128
}

-- SWOOTY_qualifier_flags[][2]: --
					-- A table of constants for certain data types. Not all possible data 
					-- is represented here, some data is undefined as such (like vector 
					-- coodinates, qualifiers which pertain to variable scales or metric 
					-- ratings, etc)
local SWOOTY_qualifier_flags = {
--	indx =	{	{"identifier", 						value}
	[2]	=	{	["AVAIL"] =							0,
				["TAKEN"] =							1,
				["MINE"] =							2	},
	[3] =	{	["THE_GUY_YA_WANNA_BE"] =			1,
				["THE_GUY_THAT_WANNA_BE_THE_GUY"] =	2,
				["THE_GUY_THAT_DONT_MIND"] =		3,
				["STOP_FARMING_JUNGLE"] =			4,
				["THE_GUY_THAT_LOST_US_THE_GAME"] =	5,
				["ORB_OF_VENOM_NO_MATTER_WHAT"] =	6,
				["DOUBLE_STOUT_SHIELD"] =			7},
	[128] =	{	["FOUNTAIN"] =						0,
				["LANE_FRONT"] =					10},
	[1023]= {	["END_OF_DATA"] =					0,
				["EMPTY_QUEUE"] =					1,
				["OVERBOARD_REQUEST"] = 			2}
}

local SWOOTY_qualifier_flags_index

-- BOOTY_qualifiers[][4]: -- Main qualifier data. Types of data, their name, where they are 
						-- stored in the buffer, and the qualifier ID which indicates it is 
						-- that data in the buffer. i in qualifiers[i] represents the
						-- data_type_index. This is the index of the type of the qualifier.
local BOOTY_qualifiers = {
--	[i] = 	{"NAME" 		SIZE			INDEX 			QUAL_ID}
	[1] = 	{"MISC", 		MAX_SIZE, 		MIN_INDX, 		0},
	[2] = 	{"CAPTAIN", 	2, 				MIN_INDX, 		1},
	[3] = 	{"ROLE", 		3,				MIN_INDX + 2, 	1}	-- Notice 'carried' + 2 for same QUAL_ID
}

-- SWOOTY_qualifier_identifiers[]: --
					-- An index storing the ID for each qualifier. Basically a large
					-- table of constants. ID's retreivable by 
					-- getQualifierIndexByName(string)
local BOOTY_qualifier_identifiers = {
	["MISC"] = 1,
	["CAPTAIN"] = 2,
	["ROLE"] = 3,
	["MOVE"] = 128
}

-- BOOTY_qualifier_flags[][2]: --
					-- A table of constants for certain SWOOTY data types. Not all possible
					-- data is represented here, some data is undefined as such (like 
					-- vector coodinates, qualifiers which pertain to variable scales or
					--  metric ratings, etc)
local BOOTY_qualifier_flags = {
--	indx =	{	{"identifier" =						value} }
	[2]	=	{	["AVAIL"] =							0,
				["TAKEN"] =							1,
				["MINE"] =							2	},
	[3] =	{	["THE_GUY_YA_WANNA_BE"] =			1,
				["THE_GUY_THAT_WANNA_BE_THE_GUY"] =	2,
				["THE_GUY_THAT_DONT_MIND"] =		3,
				["STOP_FARMING_JUNGLE"] =			4,
				["THE_GUY_THAT_LOST_US_THE_GAME"] =	5,
				["ORB_OF_VENOM_NO_MATTER_WHAT"] =	6,
				["DOUBLE_STOUT_SHIELD"] =			7},
	[128] =	{	["FOUTAIN"] =						0,
				["LANE_FRONT"] =					10	}
}

local BOOTY_qualifier_flags_index

-- Don't override these unless you intend to mess with the stream system.
-- indexes of ping flags are the offset in the buffer, not an ID. i.e. 
-- their size could be decuded by the next index with a value.
local TC_PING_flags = {
-- indx(actual) = {"identifier", 				value}
	[0]	=	{									}, -- 3-bit buffer flag
	[3] =	{	["FREE"] = 						0, -- 1-bit SWOOTY_OUT lock
				["LOCK"] = 						1},
	[4] =	{	["CLEAR"] =						0,
				["HUNG"] =						1},
	[5] = 	{	["XCLD"] =						0,
				["INCL"] =						1}
}

local TC_PING_flags_index

-- TODO Index and name the TC_PING flag types

-- quick_flags[]:	-- Sometimes you know exactly what you want SWOOTY the buffer, and you
					-- perform that action often. These are pre-made qualifier+value 
					-- payloads which can be set without any use of binary manipulation.
local quick_flags = {
	[1] = 0x00000000
}

function IO_initializePresets()
	SWOOTY_qualifier_flags_index = reverseFlagsTable(SWOOTY_qualifier_flags)
	BOOTY_qualifier_flags_index = reverseFlagsTable(BOOTY_qualifier_flags)
	TC_PING_flags_index = reverseFlagsTable(TC_PING_flags)
end

-- TODO throw err
local function getQualifierIndexByName(name, stream)
	if(stream == SWOOTY) then
		return SWOOTY_qualifier_identifiers[name]
	elseif(stream == BOOTY) then
		return BOOTY_qualifier_identifiers[name]
	end
	return nil
end

-- Exposing this would allow for storing local data_type_index numbers, cuts down redundant
-- calls to this function, but increases high-level code / less flexability.
local function getQualifierIndex(qualifier, stream)
	local data_type_index
	local qualifier_tbl

	if(type(qualifier) == "number") then 	
		-- It was already raw index value, not name
		data_type_index = qualifier
	elseif ( type(qualifier) == "string" ) then
		if (stream == SWOOTY or stream == BOOTY) then
			data_type_index = getQualifierIndexByName(qualifier, stream)
		elseif (stream == TC_FLAG) then
			-- TODO Not safe, not fully implemented (See table structure)
			return qualifier
		end	
	elseif ( data_type_index == nil ) then 
		if (_DEBUG) then print("[io_presets]: data_type "..(type(data_type) == "string" and "\""..data_type.."\"" or data_type).." not found qualifier_tbl.\n"..debug.traceback()) end
		
		return nil
	end
	
	if (stream == SWOOTY) then
		qualifier_tbl = SWOOTY_qualifiers -- hack
	elseif (stream == BOOTY) then
		qualifier_tbl = BOOTY_qualifiers
	elseif (stream == TC_FLAGS) then
		return qualifier
	else
		print("[io_presets] No valid stream given. getQualifierIndex(qualifier = "..qualifier..", stream = "..stream..").\n"..debug.traceback()) -- TODO
		return nil
	end

	local try, err = pcall(function() local exists = qualifier_tbl[data_type_index] end)
	if(err ~= nil) then 
		if(_DEBUG) then
			print("[io_presets] "..GetBot():GetUnitName()..": No such qualifier_ID found in qualifier table getQualifierIndex(qualifier = "..qualifier..
				", stream = "..stream..")"..debug.traceback())
		end
		return nil
	end
	
	return data_type_index
end

function IO_getQualifierIndex(data_type, stream)
	return getQualifierIndex(data_type, stream)
end

-- TODO ?
function IO_getQualifiersIndexOfData(data_type, stream)
	local tables_index = getQualifierIndex(data_type, stream)
	local qualifiers_tbl

	if (stream == SWOOTY) then
		return QUALIFIER_BITS -- hack
	elseif (stream == BOOTY) then
		qualifiers_tbl = BOOTY_qualifiers
	elseif (stream == TC_FLAGS) then
		return tables_index
	else
		print(debug.traceback()) -- TODO
		return nil
	end
	
	local index_of_data
	local try, err = pcall(function() index_of_data = qualifiers_tbl[tables_index][INDEX_INDEX] end)
	if (err ~= nil and _DEBUG) then print("[io_presets] "..GetBot():GetUnitName()..": No element at "..stream..":*qualifiers_tbl*["..tables_index.."]["..INDEX_INDEX.."] found.\n"..debug.traceback()) end
	return index_of_data
end

function IO_getQualifierID(data_type, stream)
	local qualifiers_tbl
	local data_type_index = -1
	
	if (stream == SWOOTY) then
		qualifiers_tbl = SWOOTY_qualifiers
	elseif (stream == BOOTY) then
		qualifiers_tbl = BOOTY_qualifiers
	elseif (stream == TC_FLAGS) then
		qualifiers_tbl = TC_PING_flags
	else
		print(debug.traceback()) -- TODO
		return nil
	end
	
	data_type_index = getQualifierIndex(data_type, stream)

	return data_type_index
end

function IO_getQualifierName(data_type_index, stream)
	if(type(data_type_index) == "string") then return data_type_index end  --TODO Incredibly lazy. Is this a real qualifier?
	local qualifiers_tbl
	
	if (stream == SWOOTY) then
		qualifiers_tbl = SWOOTY_qualifiers
	elseif (stream == BOOTY) then
		qualifiers_tbl = BOOTY_qualifiers
	elseif (stream == TC_FLAGS) then
		qualifiers_tbl = TC_PING_flags
	else
		return nil
	end
	
	if (data_type_index < 1 or data_type_index > MAX_QUALIFIER_ID) then return nil end
	local qualifier = qualifiers_tbl[data_type_index]
	if (qualifier == nil) then 
		if (_DEBUG) then print("[io_presets] "..GetBot():GetUnitName()..": No qualifier with index "..data_type_index.." found.\n"..debug.traceback()) end
		return nil
	end

	return qualifiers_tbl[data_type_index][NAME_INDEX]
end

function IO_getQualifierDataSize(data_type, stream)
	local data_type_index = getQualifierIndex(data_type, stream)
	local qualifier_tbl
	if ( data_type_index == nil ) then return nil end
	
	if (stream == SWOOTY) then
		qualifier_tbl = SWOOTY_qualifiers
	elseif (stream == BOOTY) then
		qualifier_tbl = BOOTY_qualifiers
	elseif (stream == TC_FLAGS) then
		qualifier_tbl = TC_PING_flags
		--TEMP:
		return 1
	else
		print(debug.traceback()) -- TODO
		return nil
	end

	return qualifier_tbl[data_type_index][SIZE_INDEX]
end

-- TODO Invalid args / Not found
function IO_getQualifierFlagValue(data_type, flag_name, stream)
	local flags_tbl
	local data_type_index = -1
	
	if (stream == SWOOTY) then
		flags_tbl = SWOOTY_qualifier_flags
	elseif (stream == BOOTY) then
		flags_tbl = BOOTY_qualifier_flags
	elseif (stream == TC_FLAGS) then
		flags_tbl = TC_PING_flags
	else
		print("[io_presets] "..GetBot():GetUnitName()..": No stream \""..DEBUG_printableValue(stream).."\" found.\n"..debug.traceback()) -- TODO put this EVERYWHERE
		return nil
	end
	
	data_type_index = getQualifierIndex(data_type, stream)
	if ( data_type_index == nil ) then return nil end
	
	local flag_value = 0
	local try, err = pcall(function() flag_value = flags_tbl[data_type_index][flag_name] end)
	if (err ~= nil and _DEBUG) then print("[io_presets] "..GetBot():GetUnitName()..": No element at *flags_tbl*["..data_type_index.."]["..flag_name.."] found.\n"..debug.traceback()) end
	
	return flag_value
end

function IO_getQualifierValueFlag(data_type, value, stream)
	local flags_tbl
	local data_type_index = -1
	
	if (stream == SWOOTY) then
		flags_tbl = SWOOTY_qualifier_flags_index
	elseif (stream == BOOTY) then
		flags_tbl = BOOTY_qualifier_flags_index
	elseif (stream == TC_FLAGS) then
		flags_tbl = TC_PING_flags_index
	else
		print("[io_presets] "..GetBot():GetUnitName()..": No stream \""..DEBUG_printableValue(stream).."\" found.\n"..debug.traceback()) -- TODO put this EVERYWHERE
		return nil
	end
	
	data_type_index = getQualifierIndex(data_type, stream)
	if ( data_type_index == nil ) then return nil end
	
	local flag_value = 0
	local try, err = pcall(function() flag_value = flags_tbl[data_type_index][value] end)
	if (err ~= nil) then 
		if(_DEBUG) then 
			print("[io_presets] "..GetBot():GetUnitName()..": No element at *flags_tbl*["..
				data_type_index.."]["..DEBUG_printableValue(flag_value).."] found.\n"..debug.traceback())
		end
		return nil
	end
	
	return flag_value
end

-- TODO make generic
function IO_SWOOTY_confirmQualifierIndexEquals(data_type, name, stream)
	data_type_index = getQualifierIndex(data_type, stream)
	-- TODO confirmIsQualifierName

	return IO_getQualifierName(data_type_index, "SWOOTY") == name
end

-- TODO make generic
function IO_BOOTY_getQualifierIndexesForID(data_type_ID)
	if (data_type_ID == nil) then return nil end
	local indexes = qualifier_ID_indexes[data_type_ID]
	if ( indexes == nil ) then 
		print("[io_presets]: No such qualifier ID#-"..data_type_ID..".") 
		if (_DEBUG) then print(debug.traceback()) end
		
		return nil 
	end
	
	return indexes
end

-- TODO make generic
function IO_BOOTY_getQualifierNamesByID(data_type_ID)
	local names = {}
	local indexes = getQualifierIndexesForID(data_type_ID)
	
	if (indexes == nil) then return nil end
	
	for i = 1, #indexes, 1 do
		names[i] = IO_BOOTY_getQualifierName(indexes[i])
	end
	return names
end

-- TODO Boundary / Not found errors
function IO_confirmFlagEquals(data_type, value, flag_name, stream)
	local flags_tbl
	local data_type_index = -1
	
	if(stream == SWOOTY) then 
		flags_tbl = SWOOTY_qualifier_flags
		data_type_index = getQualifierIndex(data_type, stream)
	elseif(stream == BOOTY) then
		flags_tbl = BOOTY_qualifier_flags
		data_type_index = getQualifierIndex(data_type, stream)
	elseif(stream == TC_FLAG) then
		return TC_PING_flags[data_type][flag_name] == value
	elseif(flags_tbl == nil or data_type_index == nil) then
		return nil
	end
	
	local result = false
	local try, err = pcall(function() result = (flags_tbl[data_type_index][flag_name] == value) end)
	if (err ~= nill) then 
		if(_DEBUG) then print("[io_presets] "..GetBot():GetUnitName()..": Unable to access flags_tbl["..data_type_index.."]["..flag_name.."].\n"..debug.traceback()) end
		
		return nil
	end

	return result
end

reverseFlagsTable = function(tbl)
	local new_tbl = {}
	for k,v in pairs(tbl) do
		new_tbl[k] = {}
		for k2, v2 in pairs(v) do
			new_tbl[k][v2] = k2
		end
	end

	return new_tbl
end