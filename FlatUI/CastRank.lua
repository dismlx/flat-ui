local _, ns = ...

local KEY, PART, ROW = "castbars", "spell rank", "castbars.rank"
local BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
local STARTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START" }
local MAX_RANK = 1000

local written = setmetatable({}, { __mode = "k" })
local state = { shown = nil, noCall = false, refused = false, cut = nil, waiting = nil }
local frame, listening, queued = nil, false, false
local Listen

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and ns.Get("castbars.textShow") ~= false and not ns.PartStopped(KEY, PART)
end

local function RankText(id)
	local spells = C_Spell
	local call = type(spells) == "table" and not ns.IsSecret(spells) and spells.GetSpellSubtext or nil
	if type(call) ~= "function" then
		state.noCall = true
		return nil
	end
	local ok, text = pcall(call, id)
	if not ok or ns.IsSecret(text) or type(text) ~= "string" then
		return nil
	elseif text == "" then
		return ""
	end
	local number = tonumber(text:match("(%d+)"))
	return number and number >= 1 and number < MAX_RANK and text or nil
end

local function Cast()
	local ok, name, display, _, _, _, _, _, _, id = pcall(UnitCastingInfo, "player")
	if ok and not ns.IsSecret(name) and name == nil then
		ok, name, display, _, _, _, _, _, id = pcall(UnitChannelInfo, "player")
	end
	if not ok or ns.IsSecret(name) or ns.IsSecret(display) or ns.IsSecret(id) then
		return nil
	end
	local shown = display
	if type(shown) ~= "string" or shown == "" or type(id) ~= "number" or id <= 0 then
		return nil
	end
	return shown, id
end

local function Text(bar)
	local ok, text = pcall(function()
		return bar.Text
	end)
	if ok and not ns.IsSecret(text) and type(text) == "table" then
		return text
	end
	return nil
end

local function Current(text)
	local ok, current = pcall(text.GetText, text)
	if ok and not ns.IsSecret(current) and type(current) == "string" then
		return current
	end
	return nil
end

local function Write(bar, shown, rank)
	local text = Text(bar)
	if not text then
		return
	end
	local suffix = " (" .. rank .. ")"
	if shown:sub(-#suffix) == suffix then
		return
	end
	local want = shown .. suffix
	local current = Current(text)
	if current ~= shown then
		return
	end
	if pcall(text.SetText, text, want) then
		local ok, cut = pcall(text.IsTruncated, text)
		if ok and not ns.IsSecret(cut) and cut == true then
			pcall(text.SetText, text, shown)
			state.cut = want
			return
		end
		written[bar] = { name = shown, text = want }
		state.shown = want
	else
		state.refused = true
	end
end

local function Restore(bar)
	local mine = written[bar]
	written[bar] = nil
	local text = mine and Text(bar)
	if text and Current(text) == mine.text then
		pcall(text.SetText, text, mine.name)
	end
end

local function RestoreAll()
	for bar in pairs(written) do
		pcall(Restore, bar)
	end
	state.waiting = nil
end

local function Step()
	if not Wanted() then
		return
	end
	local shown, id = Cast()
	if not shown then
		return
	end
	local rank = RankText(id)
	if rank == "" then
		state.waiting = id
		return
	end
	state.waiting = nil
	if not rank then
		return
	end
	for _, name in ipairs(BARS) do
		local bar = _G[name]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
			Write(bar, shown, rank)
		end
	end
end

local function Run()
	queued = false
	if not Wanted() or (not ns.EachPart(KEY, PART, Step, {}) and ns.PartStopped(KEY, PART)) then
		Listen(false)
		RestoreAll()
	end
end

local function Queue()
	if queued then
		return
	end
	queued = true
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, Run)) then
		Run()
	end
end

local function OnEvent(_, event, first)
	if event == "SPELL_TEXT_UPDATE" then
		if state.waiting ~= nil and not ns.IsSecret(first) and first == state.waiting then
			Queue()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or (not ns.IsSecret(first) and first == "player") then
		Queue()
	end
end

local function Hear(event)
	if frame.RegisterUnitEvent then
		local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, "player")
		if ok and (ns.IsSecret(registered) or registered ~= false) then
			return
		end
	end
	pcall(frame.RegisterEvent, frame, event)
end

function Listen(on)
	if on and not listening then
		if frame == nil then
			frame = CreateFrame("Frame")
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnEvent)
		end
		for _, event in ipairs(STARTS) do
			Hear(event)
		end
		pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
		pcall(frame.RegisterEvent, frame, "SPELL_TEXT_UPDATE")
		listening = true
	elseif not on and listening then
		pcall(frame.UnregisterAllEvents, frame)
		listening = false
	end
end

function ns.CastRankSync()
	local on = Wanted()
	Listen(on)
	if on then
		Run()
	else
		RestoreAll()
	end
end

ns.AddStatus(KEY, function()
	if not Wanted() then
		return {}
	end
	local lines = { state.shown and ("Spell rank: last shown %s."):format(state.shown) or "Spell rank: no ranked cast seen yet." }
	if state.noCall then
		lines[#lines + 1] = "Spell rank: this client gives no rank text, so none is shown."
	end
	if state.refused then
		lines[#lines + 1] = "Spell rank: the game would not take the text of a cast bar, so a rank was not shown."
	end
	if state.cut then
		lines[#lines + 1] = ("Spell rank: %s did not fit the bar, so the name was left as the game wrote it."):format(state.cut)
	end
	return lines
end)
