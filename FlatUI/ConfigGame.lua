local _, ns = ...

-- The game's own settings that Flat UI shows beside its own (the rows with cvar in Config.lua), and what to ask when one does not change.
-- The rows are in Config.lua: this file holds /flatui cvar, /flatui cvar check and the line of /flatui status.
-- Source: C_CVar.GetCVarInfo returns the value, the default and isSecure (CVarDocumentation.lua:82-100). C_CVar.SetCVar is documented as
-- RequiresNonSecureCVar and returns success (CVarDocumentation.lua:129-147), and the nameplate CVars are flagged secure (CVars.lua:1087-1128).

-- Every row that holds a game setting, in page order.
local function Rows()
	local rows = {}
	for _, page in ipairs(ns.PAGES) do
		for _, item in ipairs(page) do
			if item.key and item.cvar then
				rows[#rows + 1] = item
			end
		end
	end
	return rows
end

-- The text a call of C_CVar answers, or nil when the client lacks the call, withholds the answer or the CVar is not in this client.
local function Ask(call, name)
	if type(C_CVar) ~= "table" or type(C_CVar[call]) ~= "function" then
		return nil
	end
	local ok, first, second, third, fourth, fifth, sixth = pcall(C_CVar[call], name)
	if not ok or ns.IsSecret(first) then
		return nil
	end
	return first, second, third, fourth, fifth, sixth
end

-- The lines of /flatui cvar: the CVar of each row, its value, the client's default, and whether the client flags it secure.
local function List()
	local lines = {}
	for _, item in ipairs(Rows()) do
		local value, default, _, _, _, secure = Ask("GetCVarInfo", item.cvar)
		if value == nil then
			value = Ask("GetCVar", item.cvar)
			default = Ask("GetCVarDefault", item.cvar)
		end
		if value == nil then
			lines[#lines + 1] = ("%s: not in this client"):format(item.cvar)
		else
			local flag = secure == true and "secure" or (secure == false and "not secure" or "secure unknown")
			lines[#lines + 1] = ("%s: %s, default %s, %s"):format(item.cvar, tostring(value), default ~= nil and tostring(default) or "unknown", flag)
		end
	end
	return lines
end

-- Writes each CVar its own current text and says whether the game took the call. Out of combat only.
local function Check()
	if InCombatLockdown() then
		return { "/flatui cvar check works out of combat." }
	end
	local lines = {}
	for _, item in ipairs(Rows()) do
		local text = Ask("GetCVar", item.cvar)
		if text == nil then
			lines[#lines + 1] = ("%s: not in this client"):format(item.cvar)
		elseif type(C_CVar.SetCVar) ~= "function" then
			ns.CVarMarkRefused(item.cvar, true)
			lines[#lines + 1] = ("%s: refused (this client has no SetCVar)"):format(item.cvar)
		else
			local ok, result = pcall(C_CVar.SetCVar, item.cvar, text)
			if ok and result == true then
				ns.CVarMarkRefused(item.cvar, false)
				lines[#lines + 1] = ("%s: accepted"):format(item.cvar)
			else
				ns.CVarMarkRefused(item.cvar, true)
				lines[#lines + 1] = ("%s: refused (%s)"):format(item.cvar, ok and "the game answered no" or tostring(result))
			end
		end
	end
	return lines
end

-- /flatui cvar and /flatui cvar check.
function ns.CVarCommand(rest)
	local word = (rest or ""):lower()
	local lines
	if word == "" then
		lines = List()
	elseif word == "check" then
		lines = Check()
	else
		lines = { "/flatui cvar lists each game setting row. /flatui cvar check tries each one out of combat." }
	end
	for _, line in ipairs(lines) do
		print(line)
	end
end

-- The lines of /flatui status: how many game setting rows the game has not turned down, and the ones the game kept.
function ns.GameSettingsStatus()
	local rows = Rows()
	if #rows == 0 then
		return nil
	end
	if type(C_CVar) ~= "table" or type(C_CVar.SetCVar) ~= "function" then
		return { "Game settings: off, this client has no SetCVar" }
	end
	local open, kept = 0, {}
	for _, item in ipairs(rows) do
		if ns.RowShown(item.path) then
			if ns.CVarRefused(item.cvar) then
				kept[#kept + 1] = item.label
			else
				open = open + 1
			end
		end
	end
	local lines = { ("Game settings: %d of %d rows not turned down so far"):format(open, open + #kept) }
	if #kept > 0 then
		lines[#lines + 1] = "Game settings: the game kept " .. table.concat(kept, ", ")
	end
	return lines
end
