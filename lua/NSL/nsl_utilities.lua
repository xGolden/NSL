-- Natural Selection League Plugin
-- Source located at - https://github.com/xToken/NSL
-- lua/NSL/nsl_utilities.lua
-- - Dragon

-- Utility Funcs
function GetNSLUpValue(origfunc, name)

	local index = 1
	local foundValue = nil
	while true do
	
		local n, v = debug.getupvalue(origfunc, index)
		if not n then
			break
		end
		
		-- Find the highest index matching the name.
		if n == name then
			foundValue = v
		end
		
		index = index + 1
		
	end
	
	return foundValue
	
end

local function ReplaceMethodInDerivedClasses(className, methodName, method, original)

	-- only replace the method when it matches with super class (has not been implemented by the derrived class)
	if _G[className][methodName] ~= original then
		return
	end
	
	_G[className][methodName] = method

	local classes = Script.GetDerivedClasses(className)
	
	if classes then
		for i, c in ipairs(classes) do
			ReplaceMethodInDerivedClasses(c, methodName, method, original)
		end
	end
	
end

function Class_ReplaceMethod(className, methodName, method)

	if _G[className] == nil then 
		return nil
	end
	
	local original = _G[className][methodName]
	
	if original then
		ReplaceMethodInDerivedClasses(className, methodName, method, original)
	end
	
	return original

end