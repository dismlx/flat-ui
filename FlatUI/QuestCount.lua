local _, ns = ...

local KEY, PART = "hud", "quest count"
local GAP, EDGE = 4, -22
local FULL = { 1, 0.3, 0.3 }
local GOLD = { 1, 0.82, 0 }
local AMBER = { 1, 0.6, 0.15 }
local READY = { 0.3, 0.9, 0.3 }
local PULSE = { time = 0.6, count = 2, low = 0.35 }
local FILLED = "Flat UI: your quest log is full (%d/%d)."
local FILL_STEP, LOAD_WAIT = 2, 2
local NOTE = "Quest count: the objective tracker has no Quests heading here, so there is no count."
local ANCHOR = "ANCHOR_LEFT"
local HINT, FIGHT_HINT = { "Click: open the quest log" }, { "Click: open the quest log, after the fight" }
local LATER = "Flat UI: the quest log opens when the fight ends."
local HOVER_LIGHT, LIGHT_OUT = { 1, 1, 1, 0.07 }, 2

local S = {}

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. ".trackerCount") == true
end

local function QuestLog()
	local log = C_QuestLog
	if type(log) ~= "table" or ns.IsSecret(log) or type(log.GetNumQuestLogEntries) ~= "function" then
		return nil
	end
	return log
end

local function Read(t, key)
	if t == nil or ns.IsSecret(t) or type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if not ok or ns.IsSecret(value) then
		return nil
	end
	return value
end

local function Header()
	local module = _G.QuestObjectiveTracker
	if ns.Forbidden(module) then
		return nil
	end
	local header = Read(module, "Header")
	return not ns.Forbidden(header) and header or nil
end

local function Walk(log, entries)
	if type(log.GetInfo) ~= "function" or not ns.Finite(entries) then
		return nil
	end
	local count = 0
	for index = 1, math.min(math.floor(entries), 100) do
		local ok, info = pcall(log.GetInfo, index)
		local id = ok and Read(info, "questID") or nil
		if ns.Finite(id) and id > 0 and Read(info, "isHeader") ~= true and Read(info, "isHidden") ~= true then
			count = count + 1
		end
	end
	return count
end

local function Ready(log, entries)
	if type(log.GetInfo) ~= "function" or type(log.IsComplete) ~= "function" or not ns.Finite(entries) then
		return nil
	end
	local ready = 0
	for index = 1, math.min(math.floor(entries), 100) do
		local ok, info = pcall(log.GetInfo, index)
		local id = ok and Read(info, "questID") or nil
		if ns.Finite(id) and id > 0 and Read(info, "isHeader") ~= true and Read(info, "isHidden") ~= true then
			local okDone, done = pcall(log.IsComplete, id)
			if okDone and not ns.IsSecret(done) and done == true then
				ready = ready + 1
			end
		end
	end
	return ready
end

local function ReadyNames()
	local log = QuestLog()
	if ns.Get(KEY .. ".trackerCountReady") ~= true or not log or type(log.GetInfo) ~= "function" or type(log.IsComplete) ~= "function" then
		return nil
	end
	local ok, entries = pcall(log.GetNumQuestLogEntries)
	if not ok or not ns.Finite(entries) then
		return nil
	end
	local names, rest = {}, 0
	for index = 1, math.min(math.floor(entries), 100) do
		local okInfo, info = pcall(log.GetInfo, index)
		local id = okInfo and Read(info, "questID") or nil
		if ns.Finite(id) and id > 0 and Read(info, "isHeader") ~= true and Read(info, "isHidden") ~= true then
			local okDone, done = pcall(log.IsComplete, id)
			if okDone and not ns.IsSecret(done) and done == true then
				local title = Read(info, "title")
				if type(title) == "string" and title ~= "" and #names < 5 then
					names[#names + 1] = title
				else
					rest = rest + 1
				end
			end
		end
	end
	return names, rest
end

local function ReadyCode()
	local ok, r, g, b = pcall(ns.Colour, KEY .. ".xpQuestColour")
	if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
		r, g, b = READY[1], READY[2], READY[3]
	end
	return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Numbers()
	local log = QuestLog()
	if not log then
		return nil
	end
	local ok, entries, quests = pcall(log.GetNumQuestLogEntries)
	if not ok or ns.IsSecret(entries) then
		return nil
	end
	if not ns.Finite(quests) then
		quests = Walk(log, entries)
	end
	if not ns.Finite(quests) or quests < 0 then
		return nil
	end
	local most
	if type(log.GetMaxNumQuestsCanAccept) == "function" then
		local okMost, value = pcall(log.GetMaxNumQuestsCanAccept)
		most = okMost and ns.Finite(value) and value > 0 and value or nil
	end
	most = most or (ns.Finite(_G.MAX_QUESTLOG_QUESTS) and _G.MAX_QUESTLOG_QUESTS > 0 and _G.MAX_QUESTLOG_QUESTS)
		or (ns.Finite(_G.MAX_QUESTS) and _G.MAX_QUESTS > 0 and _G.MAX_QUESTS) or nil
	local ready = ns.Get(KEY .. ".trackerCountReady") == true and Ready(log, entries) or nil
	return math.floor(quests), most and math.floor(most) or nil, ready
end

local Queue

local function Owns(button)
	local tip = _G.GameTooltip
	if tip == nil or ns.Forbidden(tip) or not button then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, button)
	return ok and not ns.IsSecret(owned) and owned == true
end

local function Unowned(button)
	if Owns(button) then
		pcall(_G.GameTooltip.Hide, _G.GameTooltip)
	end
end

local function Tip(_, button, fresh)
	local panels = ns.DataPanels
	if type(panels) == "table" and type(panels.TipAt) == "function" then
		local hints, names, rest = {}, ReadyNames()
		if names then
			local code = ReadyCode()
			for _, title in ipairs(names) do
				hints[#hints + 1] = code .. title .. "|r"
			end
			if rest > 0 then
				hints[#hints + 1] = ("and %d more"):format(rest)
			end
		end
		for _, hint in ipairs(InCombatLockdown() and FIGHT_HINT or HINT) do
			hints[#hints + 1] = hint
		end
		panels.TipAt(button, ANCHOR, "quests", fresh, hints)
	end
end

local function Open()
	if type(_G.ToggleQuestLog) == "function" and ns.OpenAfterFight ~= nil then
		ns.OpenAfterFight(function()
			_G.ToggleQuestLog()
		end, LATER)
	end
end

local function MakeButton(header, text)
	local ok, button = pcall(CreateFrame, "Button", nil, header)
	if not ok or type(button) ~= "table" then
		return nil
	end
	ns.Own[button] = true
	button:SetAllPoints(text)
	button:EnableMouse(true)
	local light = button:CreateTexture(nil, "BACKGROUND")
	ns.Own[light] = true
	light:SetPoint("TOPLEFT", button, "TOPLEFT", -LIGHT_OUT, LIGHT_OUT)
	light:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", LIGHT_OUT, -LIGHT_OUT)
	light:SetColorTexture(HOVER_LIGHT[1], HOVER_LIGHT[2], HOVER_LIGHT[3], HOVER_LIGHT[4])
	light:Hide()
	local function Away(self)
		light:Hide()
		Unowned(self)
	end
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function()
		ns.EachPart(KEY, PART, Open, {})
	end)
	button:SetScript("OnEnter", function(self)
		light:Show()
		ns.EachPart(KEY, PART, Tip, {}, self, true)
	end)
	button:SetScript("OnLeave", Away)
	button:SetScript("OnHide", Away)
	button:Hide()
	return button
end

local function Make(header)
	if S.text then
		return true
	end
	if InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(header)) then
		if not S.waiting then
			S.waiting = true
			ns.OutOfCombat(function()
				S.waiting = false
				Queue()
			end)
		end
		return false
	end
	local text = ns.OwnText(header, "OVERLAY", "GameFontNormal")
	if not text then
		return false
	end
	local button = Read(header, "MinimizeButton")
	if not ns.Forbidden(button) then
		text:SetPoint("RIGHT", button, "LEFT", -GAP, 0)
	else
		text:SetPoint("RIGHT", header, "RIGHT", EDGE, 0)
	end
	text:SetJustifyH("RIGHT")
	S.text, S.header = text, header
	S.button = MakeButton(header, text)
	return true
end

local function Look(text, header)
	local label = Read(header, "Text")
	if type(label) ~= "table" then
		return GOLD[1], GOLD[2], GOLD[3]
	end
	local okFont, file, size, flags = pcall(function()
		return label:GetFont()
	end)
	if okFont and not ns.IsSecret(file) and type(file) == "string" and ns.Finite(size) and size > 0 and not ns.IsSecret(flags)
		and (flags == nil or type(flags) == "string") then
		pcall(text.SetFont, text, file, size, flags or "")
	end
	local okColour, r, g, b = pcall(function()
		return label:GetTextColor()
	end)
	if okColour and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return GOLD[1], GOLD[2], GOLD[3]
end

local function Hide()
	if S.text then
		S.text:Hide()
	end
	if S.button then
		S.button:Hide()
	end
end

local function Pulse()
	if not S.text then
		return
	end
	if not S.pulse then
		local frame = CreateFrame("Frame")
		ns.Own[frame] = true
		frame:Hide()
		frame:SetScript("OnUpdate", function(self, elapsed)
			S.pulsed = S.pulsed + (ns.Finite(elapsed) and elapsed or 0)
			local share = math.min(S.pulsed / PULSE.time, 1)
			local dip = math.abs(math.sin(math.pi * PULSE.count * share))
			S.text:SetAlpha(1 - (1 - PULSE.low) * dip)
			if share >= 1 then
				S.text:SetAlpha(1)
				self:Hide()
			end
		end)
		S.pulse = frame
	end
	S.pulsed = 0
	S.pulse:Show()
end

local function Filled(quests, most)
	local last = S.last
	S.last = quests
	return ns.Get(KEY .. ".trackerCountWarn") == true and last ~= nil and most ~= nil and last < most and quests >= most
		and quests - last <= FILL_STEP
end

local function ReadyRose(ready, quests, before, loading)
	local last = S.lastReady
	if loading then
		return false
	end
	S.lastReady = ready
	return last ~= nil and ready ~= nil and ready > last and ready - last <= FILL_STEP and before ~= nil and before > 0
		and math.abs(quests - before) <= FILL_STEP
end

local function Update()
	local quests, most, ready
	if Wanted() then
		quests, most, ready = Numbers()
	end
	if not quests then
		S.last, S.lastReady = nil, nil
		Hide()
		ns.ClearNote(KEY, NOTE)
		return
	end
	local loading = quests == 0 and S.last == nil and not S.seen and ns.Finite(S.entered) and GetTime() - S.entered < LOAD_WAIT
	if quests > 0 then
		S.seen = true
	end
	local before = S.last
	local filled = not loading and Filled(quests, most)
	local rose = ReadyRose(ready, quests, before, loading)
	if filled then
		print(FILLED:format(quests, most))
	end
	local header = Header()
	if not header then
		Hide()
		if _G.ObjectiveTrackerFrame ~= nil then
			ns.Note(KEY, NOTE)
		end
		return
	end
	ns.ClearNote(KEY, NOTE)
	if not Make(header) then
		return
	end
	local r, g, b = Look(S.text, S.header)
	if most and quests >= most then
		r, g, b = FULL[1], FULL[2], FULL[3]
	elseif most and quests == most - 1 and ns.Get(KEY .. ".trackerCountWarn") == true then
		r, g, b = AMBER[1], AMBER[2], AMBER[3]
	end
	S.text:SetTextColor(r, g, b)
	local shown = most and ("%d/%d"):format(quests, most) or tostring(quests)
	if ready and ready > 0 then
		shown = shown .. "  " .. ReadyCode() .. ready .. " ready|r"
	end
	S.text:SetText(shown)
	S.text:Show()
	if filled or rose then
		Pulse()
	end
	if S.button then
		S.button:Show()
		if Owns(S.button) then
			ns.EachPart(KEY, PART, Tip, {}, S.button, false)
		end
	end
end

local function Draw()
	if not ns.PartStopped(KEY, PART) and ns.EachPart(KEY, PART, Update, {}) then
		return
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Hide)
	end
end

Queue = function()
	if S.queued then
		return
	end
	S.queued = true
	C_Timer.After(0, function()
		S.queued = false
		if not ns.IsStopped(KEY) then
			Draw()
		end
	end)
end

local function Changed()
	if S.text ~= nil or (Wanted() and QuestLog() ~= nil) then
		Queue()
	end
end

ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", function()
	S.entered = GetTime()
end)
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_ENTERING_WORLD" }) do
	ns.AddEvent(KEY, event, Changed)
end
ns.AddEvent(KEY, "ADDON_LOADED", Changed, function(name)
	return not ns.IsSecret(name) and name == "Blizzard_ObjectiveTracker"
end)

function ns.QuestCountRefresh()
	Draw()
end
