local _, ns = ...

local KEY = "actionbars"
local POINTS = {
	topright = "TOPRIGHT", topleft = "TOPLEFT", top = "TOP", center = "CENTER", bottomleft = "BOTTOMLEFT", bottom = "BOTTOM", bottomright = "BOTTOMRIGHT",
}
local JUSTIFY = { topleft = "LEFT", bottomleft = "LEFT", top = "CENTER", center = "CENTER", bottom = "CENTER", topright = "RIGHT", bottomright = "RIGHT" }
local TEXT_HEIGHT = 10
local LINE_RANGE = "Hotkey colour: the game withholds the range, so those hotkeys keep the game's colour."
local LINE_WAIT = "Hotkey, macro name and count position: wait for the end of the fight."
local CHAT_WAIT = "Flat UI: hotkeys, macro names and counts move when the fight ends."

local weak = { __mode = "k" }
local records = setmetatable({}, weak)
local out = setmetatable({}, weak)
local withheld = setmetatable({}, weak)
local state = { hooked = false, queued = false, place = false, waiting = false, idle = false, dirty = true, noted = false, lightQueued = false }
local pending = {}
local DEFAULTS = {
	hotkeyText = "game", hotkeyShow = "all", hotkeyEmpty = true, hotkeySize = 100, hotkeyOwn = false, hotkeyPoint = "topright", hotkeyX = 0, hotkeyY = 0,
	nameShow = "all", nameSize = 100, nameColour = "ffffffff", namePoint = "bottom", countSize = 100, countColour = "ffffffff", countPoint = "bottomright",
	textOutline = "game",
}
local COUNT_SPOTS = {
	bottomright = { "BOTTOMRIGHT", -1, 1, "RIGHT" }, bottomleft = { "BOTTOMLEFT", 1, 1, "LEFT" }, topleft = { "TOPLEFT", 1, -1, "LEFT" },
	topright = { "TOPRIGHT", -1, -1, "RIGHT" }, bottom = { "BOTTOM", 0, 1, "CENTER" },
}
local NAME_SPOTS = { bottom = { "BOTTOM", 1 }, top = { "TOP", -1 }, center = { "CENTER", 0 } }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value)
	return not ns.IsSecret(value)
end

local function IsOwn(button)
	return type(ns.ButtonIsOwn) == "function" and ns.ButtonIsOwn(button) == true
end

local function Holding()
	if type(GetCursorInfo) ~= "function" then
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	return ok and (ns.IsSecret(kind) or kind ~= nil)
end

local function Blank(button, group, o, holding)
	if o.hotkeyEmpty == true or holding or IsOwn(button) or (group ~= "main" and group ~= "side") or type(ns.GameButtonEmpty) ~= "function" then
		return false
	end
	local ok, empty = pcall(ns.GameButtonEmpty, button)
	return ok and empty == true
end

local function Record(button)
	local record = records[button]
	if record == nil then
		record = {}
		records[button] = record
	end
	return record
end

local function GroupOf(button)
	if type(ns.ActionButtonGroup) == "function" then
		local ok, group = pcall(ns.ActionButtonGroup, button)
		if ok and Plain(group) and type(group) == "string" then
			if group == "main" then
				return "main"
			elseif group == "extra" then
				return "side"
			end
			return "other"
		end
	end
	local ok, name = pcall(button.GetName, button)
	if ok and Plain(name) and type(name) == "string" then
		if name:find("^ActionButton%d+$") then
			return "main"
		elseif name:find("^MultiBar%w*Button%d+$") then
			return "side"
		end
	end
	return "other"
end

local function On(choice, group)
	if choice == "none" then
		return false
	elseif choice == "side" or choice == "main" then
		return choice == group
	end
	return true
end

local function IsDot(hotkey)
	local ok, text = pcall(hotkey.GetText, hotkey)
	if not ok or not Plain(text) then
		return true
	end
	return text == (RANGE_INDICATOR or "\226\151\143")
end

local MODS = { "ALT", "CTRL", "META", "SHIFT" }
local shortWords
local function Words()
	if shortWords ~= nil then
		return shortWords
	end
	local map = {}
	local function Add(name, to)
		local word = _G[name]
		if type(word) == "string" and Plain(word) and word ~= "" then
			map[word] = to
		end
	end
	for n = 1, 31 do
		Add("KEY_BUTTON" .. n, "M" .. n)
	end
	for n = 0, 9 do
		Add("KEY_NUMPAD" .. n, "N" .. n)
	end
	Add("KEY_MOUSEWHEELUP", "WU")
	Add("KEY_MOUSEWHEELDOWN", "WD")
	Add("KEY_NUMPADPLUS", "N+")
	Add("KEY_NUMPADMINUS", "N-")
	Add("KEY_NUMPADMULTIPLY", "N*")
	Add("KEY_NUMPADDIVIDE", "N/")
	Add("KEY_NUMPADDECIMAL", "N.")
	Add("KEY_PAGEUP", "PU")
	Add("KEY_PAGEDOWN", "PD")
	Add("KEY_SPACE", "Sp")
	Add("KEY_BACKSPACE", "Bs")
	Add("KEY_DELETE", "Del")
	Add("KEY_INSERT", "Ins")
	Add("KEY_HOME", "Hm")
	Add("KEY_UP", "Up")
	Add("KEY_DOWN", "Dn")
	Add("KEY_LEFT", "Lt")
	Add("KEY_RIGHT", "Rt")
	Add("KEY_NUMLOCK", "NL")
	Add("KEY_ESCAPE", "Esc")
	Add("KEY_ENTER", "Ent")
	if next(map) ~= nil then
		shortWords = map
	end
	return map
end

function ns.HotkeyText(text, button)
	if type(text) ~= "string" or not Plain(text) then
		return text
	end
	if button ~= nil and not (ns.Enabled(KEY) == true and Opt("hotkeyText") == "short" and ns.ButtonIsOn(button) == true) then
		return text
	end
	local words = Words()
	local prefix, rest = "", text
	local found = true
	while found do
		found = false
		for _, mod in ipairs(MODS) do
			local abbr = _G[mod .. "_KEY_TEXT_ABBR"]
			if type(abbr) == "string" and Plain(abbr) and abbr ~= "" then
				local head = abbr .. "-"
				if rest:sub(1, #head) == head and #rest > #head then
					prefix, rest, found = prefix .. head, rest:sub(#head + 1), true
					break
				end
			end
		end
	end
	return prefix .. (words[rest] or rest)
end

local function Text(fontString)
	if fontString ~= nil and Plain(fontString) and type(fontString) == "table" then
		return fontString
	end
	return nil
end

local function Fade(record, key, fontString, faded)
	if (record[key] or false) ~= faded then
		ns.SetFaded(fontString, faded)
		record[key] = faded
	end
end

local function Short(record, hotkey, on)
	local ok, now = pcall(hotkey.GetText, hotkey)
	if not ok or not Plain(now) or type(now) ~= "string" then
		return
	end
	local long = now
	if record.hotShort ~= nil and now == record.hotShort then
		long = record.hotLong
	end
	local want = on and ns.HotkeyText(long) or long
	if want ~= now then
		pcall(hotkey.SetText, hotkey, want)
	end
	if want ~= long then
		record.hotLong, record.hotShort = long, want
	else
		record.hotLong, record.hotShort = nil, nil
	end
end

local function Flags(o)
	return type(ns.OutlineFlags) == "function" and ns.OutlineFlags(o.textOutline) or nil
end

local function Style(fontString, on, percent, flags)
	ns.TextStyle(fontString, on and { percent = percent, flags = flags } or nil)
end

local function Colour(record, button, hotkey, on, o)
	if IsOwn(button) then
		return
	end
	if withheld[button] then
		if on and o.hotkeyOwn then
			ns.Note(KEY, LINE_RANGE)
			state.noted = true
		end
		return
	end
	if on and o.hotkeyOwn then
		if out[button] then
			return
		end
		local r, g, b = ns.Colour(KEY .. ".hotkeyColour")
		pcall(hotkey.SetVertexColor, hotkey, r, g, b)
		record.coloured = true
	elseif record.coloured then
		record.coloured = nil
		if not out[button] and type(ACTIONBAR_HOTKEY_FONT_COLOR) == "table" and type(ACTIONBAR_HOTKEY_FONT_COLOR.GetRGB) == "function" then
			pcall(function()
				hotkey:SetVertexColor(ACTIONBAR_HOTKEY_FONT_COLOR:GetRGB())
			end)
		end
	end
end

local painterOn = false

local function Painter(button, shown)
	if ns.Enabled(KEY) ~= true or type(ns.ButtonIsOn) ~= "function" or ns.ButtonIsOn(button) ~= true or Opt("hotkeyOwn") ~= true then
		return nil
	end
	if not On(Opt("hotkeyShow"), GroupOf(button)) then
		return nil
	end
	if type(shown) == "table" and shown.checksRange == true and shown.inRange == false then
		return nil
	end
	return ns.Colour(KEY .. ".hotkeyColour")
end

local function Attach()
	if not painterOn and type(ns.OwnPainter) == "function" then
		painterOn = pcall(ns.OwnPainter, "hotkey", Painter)
	end
end

local function GamePadBinding(button)
	if type(IsBindingForGamePad) ~= "function" or type(GetBindingKey) ~= "function" then
		return false
	end
	local ok, answer = pcall(function()
		local action = button.bindingAction
		local key = Plain(action) and type(action) == "string" and GetBindingKey(action) or nil
		return key ~= nil and Plain(key) and IsBindingForGamePad(key) == true
	end)
	return ok and answer == true
end

local function Place(record, button, hotkey, custom, o)
	if custom then
		local point = POINTS[o.hotkeyPoint] or "TOPRIGHT"
		if record.placed == nil and IsOwn(button) then
			local ok, p1, rel, p2, x, y = pcall(hotkey.GetPoint, hotkey, 1)
			if ok and Plain(p1) and type(p1) == "string" then
				record.orig = { p1, rel, p2, x, y }
			end
		elseif record.placed == nil then
			local x, y = button.hotkeyTextKeyboardX, button.hotkeyTextKeyboardY
			record.gx = Plain(x) and type(x) == "number" and x or 0
			record.gy = Plain(y) and type(y) == "number" and y or 0
			x, y = button.hotkeyTextGamepadX, button.hotkeyTextGamepadY
			record.px = Plain(x) and type(x) == "number" and x or 0
			record.py = Plain(y) and type(y) == "number" and y or 0
		end
		hotkey:ClearAllPoints()
		hotkey:SetPoint(point, button, point, o.hotkeyX, o.hotkeyY)
		pcall(hotkey.SetJustifyH, hotkey, JUSTIFY[o.hotkeyPoint] or "RIGHT")
		record.placed = true
	elseif record.placed then
		hotkey:ClearAllPoints()
		if record.orig then
			local o1 = record.orig
			hotkey:SetPoint(o1[1], o1[2] or button, o1[3] or o1[1], o1[4] or 0, o1[5] or 0)
		elseif GamePadBinding(button) then
			hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", record.px or 0, record.py or 0)
		else
			hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", record.gx or 0, record.gy or 0)
		end
		pcall(hotkey.SetJustifyH, hotkey, "RIGHT")
		record.placed = nil
	end
end

local function PlaceCount(record, button, count, custom, o)
	if custom then
		if record.countOrig == nil then
			local ok, p1, rel, p2, x, y = pcall(count.GetPoint, count, 1)
			if ok and Plain(p1) and type(p1) == "string" and Plain(rel) and Plain(p2) and Plain(x) and Plain(y) then
				record.countOrig = { p1, rel, p2, x, y }
			else
				record.countOrig = false
			end
			local okJustify, justify = pcall(count.GetJustifyH, count)
			record.countJustify = okJustify and Plain(justify) and type(justify) == "string" and justify or "RIGHT"
		end
		local orig = record.countOrig
		local ix, iy = 5, 5
		if orig and orig[1] == "BOTTOMRIGHT" and ns.Finite(orig[4]) and ns.Finite(orig[5]) then
			ix, iy = math.abs(orig[4]), math.abs(orig[5])
		end
		local spot = COUNT_SPOTS[o.countPoint] or COUNT_SPOTS.bottomright
		count:ClearAllPoints()
		count:SetPoint(spot[1], button, spot[1], spot[2] * ix, spot[3] * iy)
		pcall(count.SetJustifyH, count, spot[4])
		record.countPlaced = true
	elseif record.countPlaced then
		local orig = record.countOrig
		count:ClearAllPoints()
		if orig then
			count:SetPoint(orig[1], orig[2] or button, orig[3] or orig[1], orig[4] or 0, orig[5] or 0)
		else
			count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
		end
		pcall(count.SetJustifyH, count, record.countJustify or "RIGHT")
		record.countPlaced = nil
	end
end

local function PlaceName(record, button, name, custom, o)
	if custom then
		if record.nameOrig == nil then
			local ok, p1, rel, p2, x, y = pcall(name.GetPoint, name, 1)
			if ok and Plain(p1) and type(p1) == "string" and Plain(rel) and Plain(p2) and Plain(x) and Plain(y) then
				record.nameOrig = { p1, rel, p2, x, y }
			else
				record.nameOrig = false
			end
		end
		local orig, iy = record.nameOrig, 2
		if orig and orig[1] == "BOTTOM" and ns.Finite(orig[5]) then
			iy = math.abs(orig[5])
		end
		local spot = NAME_SPOTS[o.namePoint] or NAME_SPOTS.bottom
		name:ClearAllPoints()
		name:SetPoint(spot[1], button, spot[1], 0, spot[2] * iy)
		record.namePlaced = true
	elseif record.namePlaced then
		local orig = record.nameOrig
		name:ClearAllPoints()
		if orig then
			name:SetPoint(orig[1], orig[2] or button, orig[3] or orig[1], orig[4] or 0, orig[5] or 0)
		else
			name:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
		end
		record.namePlaced = nil
	end
end

local function Tall(record, key, fontString, percent)
	if Plain(percent) and type(percent) == "number" and percent > 100 then
		if record[key] == nil then
			local ok, height = pcall(fontString.GetHeight, fontString)
			record[key] = ok and ns.Finite(height) and height > 0 and height or TEXT_HEIGHT
		end
		pcall(fontString.SetHeight, fontString, math.ceil(TEXT_HEIGHT * percent / 100) + 2)
	elseif record[key] ~= nil then
		pcall(fontString.SetHeight, fontString, record[key])
		record[key] = nil
	end
end

local function Big(on, percent)
	return on and Plain(percent) and type(percent) == "number" and percent > 100
end

local Later, Ranged, Signature, PageChanged

local function Pass()
	state.queued = false
	Attach()
	local only = type(ns.OwnLookOnly) == "function" and ns.OwnLookOnly() == true
	if not state.hooked and not (ns.HandsOff() and not ns.Enabled("actionbars")) then
		if not only then
			state.hooked = ns.FollowGlobal("ActionButton_UpdateRangeIndicator", Ranged) == true
		end
	end
	if not state.pageHooked and not (ns.HandsOff() and not ns.Enabled("actionbars")) then
		state.pageHooked = ns.FollowGlobal("ChangeMultiCastActionPage", PageChanged) == true
	end
	if state.idle and not state.dirty then
		return
	end
	state.dirty = false
	local o, defaults = {}, true
	local ownMain = (type(ns.OwnOn) == "function" and ns.OwnOn() == true) or (type(ns.OwnWanted) == "function" and ns.OwnWanted() == true)
	for key, default in pairs(DEFAULTS) do
		o[key] = Opt(key)
		defaults = defaults and (key == "hotkeyText" or (key == "hotkeyEmpty" and ownMain) or o[key] == default)
	end
	local holding = Holding()
	local flags = Flags(o)
	local custom = o.hotkeyPoint ~= "topright" or o.hotkeyX ~= 0 or o.hotkeyY ~= 0
	local countCustom, nameCustom = o.countPoint ~= DEFAULTS.countPoint, o.namePoint ~= DEFAULTS.namePoint
	local countTint, nameTint = nil, nil
	if o.countColour ~= DEFAULTS.countColour then
		local r, g, b = ns.Colour(KEY .. ".countColour")
		countTint = { r, g, b }
	end
	if o.nameColour ~= DEFAULTS.nameColour then
		local r, g, b = ns.Colour(KEY .. ".nameColour")
		nameTint = { r, g, b }
	end
	local moduleOn = ns.Enabled(KEY) == true
	pending = {}
	state.noted = false
	local placing = state.place
	local fight = InCombatLockdown ~= nil and InCombatLockdown()
	local waits = false
	local ownSeen = false
	for _, button in ipairs(ns.ActionButtons()) do
		ownSeen = ownSeen or IsOwn(button)
		if not ns.Forbidden(button) then
			local record = Record(button)
			local group = GroupOf(button)
			local styled = moduleOn and ns.ButtonIsOn(button) == true
			local hotShown, nameShown = not styled or On(o.hotkeyShow, group), not styled or On(o.nameShow, group)
			local hotOn, nameOn = styled and hotShown, styled and nameShown
			local hotkey, name, count = Text(button.HotKey), Text(button.Name), Text(button.Count)
			if hotkey ~= nil then
				if IsDot(hotkey) then
					if record.hotFaded then
						Fade(record, "hotFaded", hotkey, false)
					end
				else
					Fade(record, "hotFaded", hotkey, not hotShown or (hotOn and Blank(button, group, o, holding)))
					if not IsOwn(button) then
						Short(record, hotkey, hotOn and o.hotkeyText == "short")
					end
					Style(hotkey, hotOn, o.hotkeySize, flags)
					Colour(record, button, hotkey, hotOn, o)
					local put, tall = styled and custom, Big(hotOn, o.hotkeySize)
					if placing and (put or record.placed or tall or record.hotHeight ~= nil) then
						if fight then
							waits = true
						else
							Place(record, button, hotkey, put, o)
							Tall(record, "hotHeight", hotkey, tall and o.hotkeySize or 100)
						end
					end
				end
			end
			if name ~= nil then
				Fade(record, "nameFaded", name, not nameShown)
				local look = nil
				if nameOn then
					look = { percent = o.nameSize, flags = flags }
					if nameTint then
						look.r, look.g, look.b = nameTint[1], nameTint[2], nameTint[3]
					end
				end
				ns.TextStyle(name, look)
				local tall, put = Big(nameOn, o.nameSize), styled and nameCustom
				if placing and (tall or record.nameHeight ~= nil or put or record.namePlaced) then
					if fight then
						waits = true
					else
						Tall(record, "nameHeight", name, tall and o.nameSize or 100)
						PlaceName(record, button, name, put, o)
					end
				end
			end
			if count ~= nil then
				local look = nil
				if styled then
					look = { percent = o.countSize, flags = flags }
					if countTint then
						look.r, look.g, look.b = countTint[1], countTint[2], countTint[3]
					end
				end
				ns.TextStyle(count, look)
				local put = styled and countCustom
				if placing and (put or record.countPlaced) then
					if fight then
						waits = true
					else
						PlaceCount(record, button, count, put, o)
					end
				end
			end
		end
	end
	if placing then
		if waits then
			ns.Note(KEY, LINE_WAIT)
			if not state.waiting then
				state.waiting = true
				ns.OutOfCombat(function()
					state.waiting, state.told = false, false
					ns.ClearNote(KEY, LINE_WAIT)
					Later()
				end)
			end
		else
			state.place = false
			ns.ClearNote(KEY, LINE_WAIT)
		end
	end
	if not state.noted then
		ns.ClearNote(KEY, LINE_RANGE)
	end
	state.sig = Signature()
	state.idle = defaults and not state.place
	if ownSeen and type(ns.OwnRepaint) == "function" then
		local colour = tostring(Opt("hotkeyText")) .. tostring(Opt("hotkeyOwn")) .. tostring(Opt("hotkeyColour")) .. tostring(Opt("hotkeyShow")) .. tostring(Opt("hotkeyEmpty"))
			.. tostring(moduleOn)
		if state.paintSig ~= colour then
			state.paintSig = colour
			pcall(ns.OwnRepaint)
		end
	end
end

local function LightPass()
	state.lightQueued = false
	local list = pending
	pending = {}
	if state.idle and not state.dirty then
		return
	end
	local o = { hotkeyShow = Opt("hotkeyShow"), hotkeyOwn = Opt("hotkeyOwn") }
	local moduleOn = ns.Enabled(KEY) == true
	for button in pairs(list) do
		local record, hotkey = records[button], Text(button.HotKey)
		if record ~= nil and hotkey ~= nil and not ns.Forbidden(button) and not IsDot(hotkey) then
			Colour(record, button, hotkey, moduleOn and ns.ButtonIsOn(button) == true and On(o.hotkeyShow, GroupOf(button)), o)
		end
	end
end

function Later()
	if state.queued or (state.idle and not state.dirty) then
		return
	end
	state.queued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Pass)
	else
		Pass()
	end
end

function PageChanged()
	state.place = true
	state.dirty = true
	Later()
end

function Ranged(button, checksRange, inRange)
	if type(button) ~= "table" or not Plain(button) then
		return
	end
	if Plain(checksRange) and Plain(inRange) then
		out[button] = checksRange and not inRange and true or false
		withheld[button] = nil
	else
		out[button] = nil
		withheld[button] = true
	end
	if state.idle and not state.dirty then
		return
	end
	local record, hotkey = records[button], Text(button.HotKey)
	if record == nil or hotkey == nil then
		return
	end
	if state.dirty or state.queued then
		Later()
	elseif GroupOf(button) == "other" then
		if ns.Forbidden(button) or IsDot(hotkey) then
			return
		end
		local o = { hotkeyShow = Opt("hotkeyShow"), hotkeyOwn = Opt("hotkeyOwn") }
		Colour(record, button, hotkey, ns.Enabled(KEY) == true and ns.ButtonIsOn(button) == true and On(o.hotkeyShow, "other"), o)
	else
		pending[button] = true
		if not state.lightQueued then
			state.lightQueued = true
			if C_Timer and C_Timer.After then
				C_Timer.After(0, LightPass)
			else
				LightPass()
			end
		end
	end
end

function Signature()
	local parts = { tostring(ns.Enabled(KEY)), tostring(Opt("main")), tostring(Opt("extra")), tostring(Opt("pet")), tostring(Opt("stance")), tostring(Opt("totem")), tostring(Opt("ability")), tostring(Opt("hotkeyColour")) }
	for key in pairs(DEFAULTS) do
		parts[#parts + 1] = key .. "=" .. tostring(Opt(key))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function ns.EmptyKeyHidden(button)
	return ns.Enabled(KEY) == true and Opt("hotkeyEmpty") ~= true and type(ns.ButtonIsOn) == "function" and ns.ButtonIsOn(button) == true
end

function ns.ButtonTextRefresh()
	Attach()
	local sig = Signature()
	if sig ~= state.sig then
		state.dirty = true
		state.place = true
		Later()
	end
end

function ns.ButtonTextChanged(path)
	local places = type(path) == "string" and (path:find("^" .. KEY .. "%.hotkey[PXY]") or path == KEY .. ".hotkeySize" or path == KEY .. ".nameSize"
		or path == KEY .. ".hotkeyShow" or path == KEY .. ".nameShow" or path == KEY .. ".countPoint" or path == KEY .. ".namePoint")
	if places then
		state.place = true
	end
	state.dirty = true
	Pass()
	if places and state.waiting and not state.told and InCombatLockdown() and type(ns.PanelShown) == "function" and ns.PanelShown() == true then
		state.told = true
		print(CHAT_WAIT)
	end
	if path == KEY .. ".hotkeyText" and type(ns.CooldownBindsChanged) == "function" then
		ns.CooldownBindsChanged()
	end
end

local events = CreateFrame("Frame")
ns.Own[events] = true
local QUIET = { ACTIONBAR_SLOT_CHANGED = true, ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, ACTIONBAR_SHOWGRID = true, ACTIONBAR_HIDEGRID = true }
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "GAME_PAD_ACTIVE_CHANGED", "UPDATE_MULTI_CAST_ACTIONBAR", "PLAYER_REGEN_ENABLED", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
	if not QUIET[event] then
		state.place = true
		state.dirty = true
	end
	Later()
end)

if type(ns.OnButtonsChanged) == "function" then
	ns.OnButtonsChanged(Later)
end
