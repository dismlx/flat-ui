local _, ns = ...

local KEY = "mount"
local BUTTON = "FlatUIMountButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
local TRAVEL, AQUATIC, WOLF = 783, 1066, 2645
local FALLS = { 130, 1706 }
local STEP = 0.2
local MOVING = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }
local LINE_UNBOUND = "Mount key: no key is bound yet. Pick Press a key to set it in the row Key, or bind one to Mount or travel form under Flat UI in the game's Key Bindings."
local LINE_KEY = "Mount key: %s is Flat UI's key for it."
local LINE_KEY_REFUSED = "Mount key: the game would not bind %s to it."
local LINE_IN_FIGHT = "Flat UI: not in a fight. Pick it again after the fight."
local META = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true }
local MOVES = { MOVEFORWARD = "moves you forward", MOVEBACKWARD = "moves you back", STRAFELEFT = "strafes left", STRAFERIGHT = "strafes right",
	TURNLEFT = "turns you left", TURNRIGHT = "turns you right", JUMP = "makes you jump", TOGGLEAUTORUN = "turns on auto-run",
	MOVEANDSTEER = "moves and steers you", CAMERAZOOMIN = "zooms the camera in", CAMERAZOOMOUT = "zooms the camera out" }
local CONFIRM_GAP = 0.4
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local PROMPT = "Press the key for Mount or travel form, or a mouse button or the wheel over this box.\nEscape or a left click cancels."
local PROMPT_MOVES = "%s %s.\n%s it again to use it anyway, or press another key."
local PROMPT_NOW = "\n|cffa9ae9fNow: %s|r"
local LINE_NOTHING = "Mount key: no mount or travel form to use yet."
local LINE_UNUSABLE = "Mount key: none of your mounts can be used here and now. The tooltip of the Mount button in the mount journal says why."
local LINE_BROKEN = "Mount key: the game did not make the button of the key, so the key does nothing until /reload."
local LINE_JOURNAL = "Mount key: this client has no mount journal, so the key takes travel forms only."
local LINE_WAITS = "Mount key: a change of the key waits for the end of the fight."
local LINE_FALL = "Mount key: falling safety armed: out of a fight, pressed while you fall and are not mounted, the key casts %s on you. It takes a Light Feather."
local LINE_NO_FALL = "Mount key: falling safety on, but this character knows neither Slow Fall nor Levitate."

_G["BINDING_NAME_" .. BINDING] = "Mount or travel form"

local IsSecret = ns.IsSecret

local S = { button = nil, broken = false, text = nil, texts = nil, cast = false, mount = nil, list = nil, dirty = true, pick = nil, moving = false,
	listener = nil, hearing = false, soonMove = false, soon = false, later = false, fall = nil, fallText = nil, scripted = false, held = false,
	owner = nil, chord = nil, refused = nil, prompt = nil, confirm = nil, confirmAt = nil }
local M = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

local function Yes(value)
	return not IsSecret(value) and value == true
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return not ok or IsSecret(value) or value == true
end

local function Journal()
	local journal = C_MountJournal
	if type(journal) == "table" and not IsSecret(journal) and type(journal.GetMountIDs) == "function" and type(journal.GetMountInfoByID) == "function" then
		return journal
	end
	return nil
end

local function OwnKey()
	local db = ns.Account()
	local chord = type(db) == "table" and db.mountKey or nil
	return type(chord) == "string" and chord ~= "" and chord or nil
end

local function GameKey()
	local key = Ask(GetBindingKey, BINDING)
	return type(key) == "string" and key ~= "" and key or nil
end

local function Bound()
	return GameKey() ~= nil or OwnKey() ~= nil
end

local function KeyText(chord)
	local text = Ask(GetBindingText, chord)
	if type(text) == "string" and text ~= "" then
		return text
	end
	return (chord:gsub("(%u+)%-", function(meta)
		return meta:sub(1, 1) .. meta:sub(2):lower() .. "-"
	end))
end

local function SpellName(id)
	local spells = C_Spell
	local name = type(spells) == "table" and Ask(spells.GetSpellName, id) or nil
	return type(name) == "string" and name ~= "" and name or nil
end

local function Bank()
	local banks = type(Enum) == "table" and Enum.SpellBookSpellBank or nil
	local value = type(banks) == "table" and banks.Player or nil
	return type(value) == "number" and value or 0
end

local function Form(id)
	local book = C_SpellBook
	if type(book) ~= "table" or not Yes(Ask(book.IsSpellKnown, id, Bank())) then
		return nil
	end
	return SpellName(id)
end

local function Instant(id)
	local spells = C_Spell
	local info = type(spells) == "table" and Ask(spells.GetSpellInfo, id) or nil
	if type(info) ~= "table" then
		return false
	end
	local cast = info.castTime
	return ns.Finite(cast) and cast == 0
end

local function Fall()
	local spells = C_Spell
	if type(spells) ~= "table" then
		return nil
	end
	for _, id in ipairs(FALLS) do
		if Yes(Ask(spells.DoesSpellExist, id)) then
			local name = Form(id)
			if name then
				return name
			end
		end
	end
	return nil
end

local function Class()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, class = pcall(UnitClass, "player")
	if ok and not IsSecret(class) and type(class) == "string" then
		return class
	end
	return nil
end

local function Collected()
	if S.list and not S.dirty then
		return S.list
	end
	S.dirty = false
	local list = {}
	S.list = list
	local journal = Journal()
	if not journal then
		return list
	end
	local ok, ids = pcall(journal.GetMountIDs)
	if not ok or IsSecret(ids) or type(ids) ~= "table" then
		return list
	end
	for _, id in ipairs(ids) do
		if ns.Finite(id) then
			local got, _, spell, _, _, _, _, favourite, _, _, hidden, collected = pcall(journal.GetMountInfoByID, id)
			if got and Yes(collected) and not Yes(hidden) and ns.Finite(spell) then
				list[#list + 1] = { id = id, spell = spell, favourite = Yes(favourite) }
			end
		end
	end
	return list
end

local function Usable(entry)
	local journal = C_MountJournal
	if type(journal.GetMountUsabilityByID) == "function" then
		local ok, usable = pcall(journal.GetMountUsabilityByID, entry.id, false)
		if ok and not IsSecret(usable) and type(usable) == "boolean" then
			return usable
		end
	end
	local ok, _, _, _, _, usable = pcall(journal.GetMountInfoByID, entry.id)
	return ok and Yes(usable)
end

local function Pick()
	local all, favourites = {}, {}
	for _, entry in ipairs(Collected()) do
		local name = Usable(entry) and SpellName(entry.spell) or nil
		if name then
			all[#all + 1] = name
			if entry.favourite then
				favourites[#favourites + 1] = name
			end
		end
	end
	local pool = (Opt("favourites") == true and #favourites > 0) and favourites or all
	for _, name in ipairs(pool) do
		if name == S.pick then
			return name
		end
	end
	S.pick = #pool > 0 and pool[math.random(#pool)] or nil
	return S.pick
end

local function Plan()
	local plan, class = {}, Class()
	if class == "DRUID" then
		plan.cancel, plan.travel, plan.aquatic = true, Form(TRAVEL), Form(AQUATIC)
	elseif class == "SHAMAN" then
		plan.cancel, plan.wolf = true, Form(WOLF)
		plan.wolfInstant = plan.wolf ~= nil and Instant(WOLF)
	end
	plan.mount = Pick()
	return plan
end

local function Macro(plan, moving)
	local lines, choices = { "/dismount [mounted]", "/stopmacro [mounted]" }, {}
	if plan.aquatic then
		choices[#choices + 1] = "[swimming] " .. plan.aquatic
	end
	local form = plan.travel or plan.wolf
	local fast = plan.travel or (plan.wolfInstant and plan.wolf) or nil
	if plan.mount and not (moving and fast) then
		if form then
			choices[#choices + 1] = "[combat] " .. form
			choices[#choices + 1] = plan.mount
		else
			choices[#choices + 1] = "[nocombat] " .. plan.mount
		end
	elseif form then
		choices[#choices + 1] = form
	end
	if #choices == 0 then
		return table.concat(lines, "\n"), false
	end
	if plan.cancel then
		lines[#lines + 1] = "/cancelform [form]"
		lines[#lines + 1] = "/stopmacro [form]"
	end
	lines[#lines + 1] = "/cast " .. table.concat(choices, "; ")
	return table.concat(lines, "\n"), true
end

local function Build()
	if S.button then
		return true
	end
	if S.broken or Fighting() then
		return false
	end
	local made, button = pcall(CreateFrame, "Button", BUTTON, UIParent, "SecureActionButtonTemplate")
	if not made or IsSecret(button) or type(button) ~= "table" then
		S.broken = true
		return false
	end
	ns.Own[button] = true
	if not pcall(button.RegisterForClicks, button, "LeftButtonDown", "LeftButtonUp") then
		S.broken = true
		return false
	end
	S.button = button
	return true
end

local function Later()
	if S.later then
		return
	end
	S.later = true
	ns.OutOfCombat(function()
		S.later = false
		ns.Try(KEY, M.Update)
	end)
end

local function BindKey(want)
	if want == nil and S.chord == nil then
		S.refused = nil
		return
	end
	if want == S.chord or want == S.refused then
		return
	end
	if Fighting() then
		Later()
		return
	end
	if not S.owner then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or IsSecret(frame) or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		S.owner = frame
	end
	if type(ClearOverrideBindings) == "function" then
		pcall(ClearOverrideBindings, S.owner)
	end
	S.chord, S.refused = nil, nil
	if want and type(SetOverrideBindingClick) == "function" and pcall(SetOverrideBindingClick, S.owner, false, want, BUTTON, "LeftButton") then
		S.chord = want
	elseif want then
		S.refused = want
	end
end

local function Apply()
	if not S.button or not S.texts then
		return
	end
	local text = S.moving and S.texts.moving or S.texts.still
	if text == S.text and not S.held then
		return
	end
	if Fighting() then
		Later()
		return
	end
	local ok = pcall(function()
		S.button:SetAttribute("type", "macro")
		S.button:SetAttribute("macrotext", text)
	end)
	if ok then
		S.text, S.held = text, false
	end
end

local function PreClick(self)
	if S.fallText == nil or S.text == nil or Fighting() then
		return
	end
	if not Yes(Ask(IsFalling)) or Ask(IsMounted) ~= false then
		return
	end
	if pcall(self.SetAttribute, self, "macrotext", S.fallText) then
		S.held = true
	end
end

local function PostClick(self)
	if not S.held then
		return
	end
	if Fighting() or not pcall(self.SetAttribute, self, "macrotext", S.text) then
		Later()
		return
	end
	S.held = false
end

local function Arm(name)
	S.fall = name
	S.fallText = name and ("/cast [@player] " .. name) or nil
	local want = name ~= nil
	if not S.button or S.scripted == want then
		return
	end
	if Fighting() then
		Later()
		return
	end
	local ok = pcall(function()
		S.button:SetScript("PreClick", want and PreClick or nil)
		S.button:SetScript("PostClick", want and PostClick or nil)
	end)
	if ok then
		S.scripted = want
	end
end

function M.Moved()
	S.soonMove = false
	S.moving = Ask(IsPlayerMoving) == true
	Apply()
end

local function OnMove()
	if S.soonMove then
		return
	end
	S.soonMove = true
	if not After(0, function()
		ns.Try(KEY, M.Moved)
	end) then
		ns.Try(KEY, M.Moved)
	end
end

local function Hear(on)
	if on == S.hearing then
		return
	end
	if on and not S.listener then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or IsSecret(frame) or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		if not pcall(frame.SetScript, frame, "OnEvent", OnMove) then
			return
		end
		S.listener = frame
	end
	if not S.listener then
		return
	end
	local frame = S.listener
	for _, event in ipairs(MOVING) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	S.hearing = on
	if on then
		S.moving = Ask(IsPlayerMoving) == true
	else
		S.moving = false
	end
end

function M.Off()
	Hear(false)
	S.texts, S.cast, S.mount = nil, false, nil
	Arm(nil)
	BindKey(nil)
	if not S.button or S.text == nil then
		return
	end
	if Fighting() then
		Later()
		return
	end
	local ok = pcall(function()
		S.button:SetAttribute("type", nil)
		S.button:SetAttribute("macrotext", nil)
	end)
	if ok then
		S.text, S.held = nil, false
	end
end

function M.Update()
	S.soon = false
	if not ns.Enabled(KEY) then
		M.Off()
		return
	end
	local plan = Plan()
	local still, cast = Macro(plan, false)
	local moving = Macro(plan, true)
	S.texts, S.cast, S.mount = { still = still, moving = moving }, cast, plan.mount
	local bound = Bound()
	if not S.button and bound and not Build() and not S.broken then
		Later()
	end
	Hear(moving ~= still and S.button ~= nil and bound)
	if S.button then
		BindKey(OwnKey())
	end
	Apply()
	Arm(Opt("falling") == true and Fall() or nil)
end

function M.Soon()
	if S.soon then
		return
	end
	S.soon = true
	if not After(STEP, function()
		ns.Try(KEY, M.Update)
	end) then
		M.Update()
	end
end

local function Changed()
	S.dirty = true
	M.Soon()
end

function M.Refresh()
	S.dirty, S.pick = true, nil
	M.Update()
end

function M.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if S.broken then
		lines[#lines + 1] = LINE_BROKEN
	elseif not Bound() then
		lines[#lines + 1] = LINE_UNBOUND
	end
	if S.refused then
		lines[#lines + 1] = LINE_KEY_REFUSED:format(KeyText(S.refused))
	elseif S.chord then
		lines[#lines + 1] = LINE_KEY:format(KeyText(S.chord))
	end
	if not Journal() then
		lines[#lines + 1] = LINE_JOURNAL
	end
	if not S.cast and S.list and #S.list > 0 then
		lines[#lines + 1] = LINE_UNUSABLE
	elseif not S.cast then
		lines[#lines + 1] = LINE_NOTHING
	elseif S.mount then
		lines[#lines + 1] = ("Mount key: the next mount is %s."):format(S.mount)
	end
	if Opt("falling") == true then
		if S.fall == nil then
			lines[#lines + 1] = LINE_NO_FALL
		elseif S.scripted then
			lines[#lines + 1] = LINE_FALL:format(S.fall)
		end
	end
	if S.later then
		lines[#lines + 1] = LINE_WAITS
	end
	return lines
end

local function Chord(key)
	if type(CreateKeyChordStringUsingMetaKeyState) == "function" then
		local ok, chord = pcall(CreateKeyChordStringUsingMetaKeyState, key)
		if ok and type(chord) == "string" and not IsSecret(chord) and chord ~= "" then
			return chord
		end
	end
	local parts = {}
	for _, meta in ipairs({ { "ALT", IsAltKeyDown }, { "CTRL", IsControlKeyDown }, { "SHIFT", IsShiftKeyDown } }) do
		if Yes(Ask(meta[2])) then
			parts[#parts + 1] = meta[1]
		end
	end
	parts[#parts + 1] = key
	return table.concat(parts, "-")
end

local function WasBound(chord)
	local action = Ask(GetBindingAction, chord)
	if type(action) ~= "string" or action == "" or action == BINDING then
		return nil
	end
	local name = _G["BINDING_NAME_" .. action]
	return type(name) == "string" and not IsSecret(name) and name ~= "" and name or action
end

local function Moves(chord)
	local action = Ask(GetBindingAction, chord)
	return type(action) == "string" and MOVES[action] or nil
end

local function MouseKey(button)
	if IsSecret(button) or type(button) ~= "string" or button == "LeftButton" or button == "RightButton" then
		return nil
	end
	local key = Ask(GetConvertedKeyOrButton, button) or MOUSE_KEYS[button]
	if type(key) == "string" and key:match("^BUTTON%d+$") and key ~= "BUTTON1" and key ~= "BUTTON2" then
		return key
	end
	return nil
end

local function OnKey(key)
	if key == "ESCAPE" then
		print("Flat UI: Mount key not changed.")
		return
	end
	local chord = Chord(key)
	local db = ns.Account()
	if type(db) ~= "table" then
		return
	end
	local was = WasBound(chord)
	db.mountKey = chord
	local line = ("Flat UI: Mount key is %s."):format(KeyText(chord))
	if was then
		line = ("Flat UI: Mount key is %s (it was %s; that comes back when Mount key is off)."):format(KeyText(chord), was)
	end
	if not ns.Enabled(KEY) then
		line = line .. " It works once Mount key is on."
	end
	print(line)
	ns.Try(KEY, M.Update)
end

local function Prompt()
	if S.prompt then
		return S.prompt
	end
	local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
	if not ok or IsSecret(frame) or type(frame) ~= "table" then
		return nil
	end
	ns.Own[frame] = true
	frame:Hide()
	frame:SetFrameStrata("DIALOG")
	frame:SetSize(480, 78)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	ns.Outline(frame, frame, true)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ns.Own[text] = true
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	text:SetWidth(440)
	text:SetText(PROMPT)
	frame:EnableMouse(true)
	pcall(frame.EnableMouseWheel, frame, true)
	if not pcall(frame.EnableKeyboard, frame, true) then
		return nil
	end
	local function Now()
		local ok, line = pcall(function()
			local chord = OwnKey() or GameKey()
			return chord and PROMPT_NOW:format(KeyText(chord)) or ""
		end)
		return ok and line or ""
	end
	frame:SetScript("OnShow", function()
		S.confirm, S.confirmAt = nil, nil
		text:SetText(PROMPT .. Now())
	end)
	frame:SetScript("OnHide", function()
		S.confirm, S.confirmAt = nil, nil
	end)
	local function Take(self, key)
		if key ~= "ESCAPE" then
			local ok, chord, does = pcall(function()
				local pressed = Chord(key)
				return pressed, Moves(pressed)
			end)
			if ok and does then
				local now = GetTime()
				if S.confirm ~= chord then
					S.confirm, S.confirmAt = chord, now
					local verb = type(key) == "string" and key:find("^MOUSEWHEEL") and "Turn" or "Press"
					text:SetText(PROMPT_MOVES:format(KeyText(chord), does, verb) .. Now())
					return
				elseif ns.Finite(now) and ns.Finite(S.confirmAt) and now - S.confirmAt < CONFIRM_GAP then
					S.confirmAt = now
					return
				end
			end
		end
		self:Hide()
		ns.Try(KEY, OnKey, key)
	end
	frame:SetScript("OnKeyDown", function(self, key)
		local plain = not IsSecret(key) and type(key) == "string"
		if plain and META[key] then
			return
		end
		if not plain then
			self:Hide()
			return
		end
		Take(self, key)
	end)
	frame:SetScript("OnMouseDown", function(self, button)
		local key = MouseKey(button)
		if not key then
			self:Hide()
			print("Flat UI: Mount key not changed.")
			return
		end
		Take(self, key)
	end)
	frame:SetScript("OnMouseWheel", function(self, delta)
		if IsSecret(delta) or not ns.Finite(delta) or delta == 0 then
			return
		end
		Take(self, delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
	end)
	frame:SetScript("OnEvent", function(self)
		if self:IsShown() then
			self:Hide()
			print("Flat UI: Mount key not changed; pick it again after the fight.")
		end
	end)
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	S.prompt = frame
	return frame
end

function ns.MountKeyLines()
	local own, game = OwnKey(), GameKey()
	local now = own and KeyText(own) or game and (KeyText(game) .. ", from Key Bindings") or "none"
	local lines = { { 1, ("Press a key to set it (now: %s)"):format(now) } }
	if own then
		lines[#lines + 1] = { 2, "Clear Flat UI's key" }
	end
	return lines
end

function ns.MountKeyPick(id)
	if Fighting() then
		return false, LINE_IN_FIGHT
	end
	if id == 2 then
		local db = ns.Account()
		if type(db) == "table" then
			db.mountKey = nil
		end
		ns.Try(KEY, M.Update)
		BindKey(nil)
		return true, "Flat UI: Flat UI's Mount key is cleared. A key bound in the game's Key Bindings still works."
	elseif id ~= 1 then
		return false
	end
	local frame = Prompt()
	if not frame then
		return false, "Flat UI: the game did not make the prompt; bind the key under Flat UI in the game's Key Bindings."
	end
	frame:Show()
	pcall(frame.SetPropagateKeyboardInput, frame, false)
	return true
end

function ns.MountKeyState()
	return S
end

ns.Register(KEY, {
	label = "Mount key",
	counted = false,
	Start = M.Refresh,
	Refresh = M.Refresh,
	Status = M.Status,
	events = {
		PLAYER_ENTERING_WORLD = Changed,
		NEW_MOUNT_ADDED = Changed,
		COMPANION_LEARNED = Changed,
		COMPANION_UNLEARNED = Changed,
		MOUNT_JOURNAL_SEARCH_UPDATED = Changed,
		MOUNT_JOURNAL_USABILITY_CHANGED = function()
			M.Soon()
		end,
		SPELLS_CHANGED = function()
			M.Soon()
		end,
		UPDATE_SHAPESHIFT_FORMS = function()
			M.Soon()
		end,
		PLAYER_LEVEL_UP = function()
			M.Soon()
		end,
		UPDATE_BINDINGS = function()
			M.Soon()
		end,
		PLAYER_MOUNT_DISPLAY_CHANGED = function()
			if Yes(Ask(IsMounted)) then
				S.pick = nil
			end
			M.Soon()
		end,
	},
})
