local _, ns = ...

local IsSecret = ns.IsSecret

local K = { PREFIX = "FlatUIT1:", PROFILE = "FlatUI1:", MAX = 40, CHUNK = 232, ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789" }

local function Escape(text)
	return (text:gsub("[%%|,=\r\n]", function(char)
		return ("%%%02X"):format(char:byte())
	end))
end

local function Unescape(text)
	return (text:gsub("%%(%x%x)", function(code)
		return string.char(tonumber(code, 16))
	end))
end

local function Finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function Item(value)
	if IsSecret(value) then
		return nil
	elseif Finite(value) then
		return "n" .. ("%.14g"):format(value)
	elseif type(value) == "string" then
		return "s" .. Escape(value)
	end
	return nil
end

local function Value(value)
	if IsSecret(value) then
		return nil
	elseif type(value) == "boolean" then
		return value and "t" or "f"
	elseif type(value) == "table" then
		local items = {}
		for _ in pairs(value) do
			items[#items + 1] = false
		end
		if #items ~= #value then
			return nil
		end
		for index, item in ipairs(value) do
			items[index] = Item(item)
			if not items[index] then
				return nil
			end
		end
		return "l" .. table.concat(items, ",")
	end
	return Item(value)
end

local function Line(entry)
	if type(entry) ~= "table" or type(entry.kind) ~= "string" or entry.kind == "" then
		return nil
	end
	local own, other = {}, {}
	for key in pairs(entry) do
		if type(key) == "string" and key ~= "id" and key ~= "kind" then
			if ns.TrackerOwnKeys and ns.TrackerOwnKeys[key] then
				own[#own + 1] = key
			else
				other[#other + 1] = key
			end
		end
	end
	table.sort(own)
	table.sort(other)
	local fields = { Escape(entry.kind) }
	for _, group in ipairs({ own, other }) do
		for _, key in ipairs(group) do
			local text = Value(entry[key])
			if text then
				fields[#fields + 1] = Escape(key) .. "=" .. text
			end
		end
	end
	return table.concat(fields, "|")
end

local function Plain(text)
	local letter, rest = text:sub(1, 1), text:sub(2)
	if letter == "t" and rest == "" then
		return true
	elseif letter == "f" and rest == "" then
		return false
	elseif letter == "n" then
		local number = tonumber(rest)
		return Finite(number) and number or nil
	elseif letter == "s" then
		return Unescape(rest)
	end
	return nil
end

local function ReadValue(text)
	if text:sub(1, 1) ~= "l" then
		return Plain(text)
	end
	local list = {}
	if text == "l" then
		return list
	end
	for part in (text:sub(2) .. ","):gmatch("([^,]*),") do
		local item = part ~= "" and part:sub(1, 1) ~= "t" and part:sub(1, 1) ~= "f" and Plain(part)
		if item == nil or item == false then
			return nil
		end
		list[#list + 1] = item
	end
	return list
end

local function Read(line)
	local fields = {}
	for field in (line .. "|"):gmatch("([^|]*)|") do
		fields[#fields + 1] = field
	end
	local kind = Unescape(fields[1])
	if kind == "" then
		return nil
	end
	local entry = { kind = kind }
	for index = 2, #fields do
		local key, text = fields[index]:match("^([^=]*)=(.*)$")
		key = key and Unescape(key)
		if key and key ~= "" and key ~= "id" and key ~= "kind" then
			local value = ReadValue(text)
			if value ~= nil then
				entry[key] = value
			end
		end
	end
	return entry
end

local function Pack(entries)
	local lines = {}
	for _, entry in ipairs(entries) do
		lines[#lines + 1] = Line(entry)
	end
	if #lines == 0 then
		return ""
	end
	return ns.PackText(K.PREFIX, lines)
end

function ns.TrackerExportText()
	local text = Pack(ns.TrackerEntries and ns.TrackerEntries() or {})
	if text == "" then
		return false, "No trackers."
	end
	return text
end

function ns.TrackerExport(number)
	local entries = ns.TrackerEntries and ns.TrackerEntries() or {}
	if number ~= nil then
		local entry = type(number) == "number" and entries[number]
		if not entry then
			return false, { ("No tracker numbered %s."):format(tostring(number)) }
		end
		entries = { entry }
	end
	local text = Pack(entries)
	if text == "" then
		return false, { "No trackers." }
	end
	local lines = {}
	for at = 1, #text, K.CHUNK do
		lines[#lines + 1] = text:sub(at, at + K.CHUNK - 1)
	end
	return true, lines
end

local function NewId(taken)
	local id
	repeat
		id = ""
		for _ = 1, 6 do
			local at = math.random(1, #K.ID_CHARS)
			id = id .. K.ID_CHARS:sub(at, at)
		end
	until not taken[id]
	return id
end

function ns.TrackerImport(text)
	if InCombatLockdown() then
		return false, "Import after the fight."
	end
	local saved = ns.Character()
	if not saved or not ns.TrackerEntries then
		return false, "Trackers are not ready yet."
	end
	if type(text) ~= "string" or IsSecret(text) then
		text = ""
	end
	text = text:gsub("%s+", "")
	if text:sub(1, #K.PROFILE) == K.PROFILE then
		return false, "That is a profile text. Paste it in Import profile."
	end
	local lines, why = ns.UnpackText(K.PREFIX, text)
	if not lines then
		return false, why == "prefix" and "That is not a tracker text." or "The text is incomplete."
	end
	ns.TrackerEntries()
	local list = saved.trackers
	if type(list) ~= "table" then
		list = {}
		saved.trackers = list
	end
	local taken = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and type(entry.id) == "string" then
			taken[entry.id] = true
		end
	end
	local before, full = #list, false
	for _, line in ipairs(lines) do
		local entry = line ~= "" and Read(line)
		if entry then
			if #list >= K.MAX then
				full = true
				break
			end
			entry.id = NewId(taken)
			taken[entry.id] = true
			list[#list + 1] = entry
			ns.TrackerEntries()
			list = saved.trackers
		end
	end
	ns.TrackerEntries()
	local added = #saved.trackers - before
	if ns.TrackerLayout then
		ns.TrackerLayout()
	end
	if added > 0 and ns.TrackerPreviewRow then
		ns.TrackerPreviewRow()
	end
	if full and added == 0 then
		return false, ("The list is full at %d trackers."):format(K.MAX)
	elseif full then
		return true, ("Imported %d %s. The limit is %d."):format(added, added == 1 and "tracker" or "trackers", K.MAX)
	elseif added == 0 then
		return false, "No trackers in that text."
	end
	return true, ("Imported %d %s."):format(added, added == 1 and "tracker" or "trackers")
end

ns.TrackerShare = { Pack = Pack, Read = Read, PREFIX = K.PREFIX }
