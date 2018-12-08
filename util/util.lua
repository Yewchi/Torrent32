local mLog = math.log
local mAbs = math.abs
local mCeil = math.ceil
local LOG_2 = mLog(2)

-- TODO Think this should be used instead of II_dataLength() everywhere
-- Includes a simulated leading 1 for negative numbers
-- Note: for values passed from 
function UTIL_getBitLength(data)
	if(data < 0) then 
		return mCeil(mLog(mAbs(data)) / LOG_2) + 1 -- leading bit
	end
	return mCeil(mLog(data) / LOG_2) -- leading 0 interpreted but not in data?
end

function DEBUG_printableValue(value) -- TODO Fix this later
	local t = type(value)
	if (t == nil) then
		return "nil"
	elseif (t == "number" or t == "string") then
		return value
	elseif (t == "boolean") then
		return (value) and "true" or "false"
	elseif (t == "table") then
		local str = "tbl{"
		local i = 1
		for k, v in pairs(value) do
			str = str.."["..k.."] = "..DEBUG_printableValue(v)
			if (i < #value) then -- ?? what. no.
				str = str..", "
				i = i + 1
			else
				str = str.."}"
			end
		end
		if(#value == 0) then
			str = str.."}"
		end
		return str
	end
	return "[unknown value of type: "..type(value)
end