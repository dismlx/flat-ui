local _, ns = ...

-- Quest count: how many quests the quest log holds and the most it can, as 12/20, at the right of the Quests heading of the objective tracker
-- (QuestObjectiveTracker.Header, a heading of the modern tracker that Hud.lua styles). The numbers are the game's: the quests of
-- C_QuestLog.GetNumQuestLogEntries (its second answer, the count the game itself compares with MAX_QUESTS before an escort's question) and
-- C_QuestLog.GetMaxNumQuestsCanAccept, else MAX_QUESTLOG_QUESTS or MAX_QUESTS; with no most known, the count alone. The text is a font string
-- of the addon's own on the heading, in the font of the heading's text and its colour, red while the log is full. With Warn as the log fills
-- (hud.trackerCountWarn, on by default) the count is amber with one free slot, and when the log becomes full in play (from the second read after
-- login or a reload) it pulses twice and chat says once "Flat UI: your quest log is full (20/20).". A jump of more than two quests between two
-- reads never warns, nor does a first read of 0 quests just after entering the world, so a log that loads late stays quiet. Nothing of the heading is
-- changed: its Text is read for the font and the colour (GetFont and GetTextColor), and its MinimizeButton for the place. The text is made and
-- placed out of combat, or on a heading the game does not protect; in a fight only its text, colour and font are set, and it is shown or hidden.
-- It is redrawn on the next frame after the quest log changes, and only while a count can be shown, so a client without the quest log calls
-- has no text and nothing waiting. It hides with the heading, so there is no count while no quest is tracked. Its row is Quest count on the
-- Quests and loot page (hud.trackerCount), part "quest count" of the module, which stops alone after a few failures.
-- Over the count lies a button of the addon's own, a child of the heading the size of the count's text, made with the text (out of combat, or
-- on a heading the game does not protect) and shown and hidden with it; the heading itself takes no mouse (ObjectiveTrackerModuleHeaderTemplate,
-- Blizzard_ObjectiveTrackerModule.xml:13-19), so no click of the game's is taken. Pointing at the count, also in a fight, shows the tooltip of
-- the Quest log data panel (ns.DataPanels.TipAt with its stream "quests": the quests of the most, "Your quest log is full.", those ready to hand
-- in and their experience) with a dim "Click: open the quest log"; GameTooltip is hidden on leave only while IsOwned says the button owns it. A
-- click opens the quest log (ToggleQuestLog), in a fight as it ends: chat says once "Flat UI: the quest log opens when the fight ends."
-- (ns.OpenAfterFight, MapText.lua), and the hint says "after the fight".
-- It follows EnhanceQoL's quest count on the tracker, adapted with the permission of its author.

local KEY, PART = "hud", "quest count"
-- Between the count and the heading's minimize button; from the heading's right edge when it has none (the button is 16 wide at x 1:
-- Blizzard_ObjectiveTrackerModule.xml:46-53).
local GAP, EDGE = 4, -22
local FULL = { 1, 0.3, 0.3 }
local GOLD = { 1, 0.82, 0 }
-- Warn as the log fills: the count with one free slot, the pulse as the log becomes full (its seconds, its pulses and the lowest opacity), and
-- the chat line then.
local AMBER = { 1, 0.6, 0.15 }
local PULSE = { time = 0.6, count = 2, low = 0.35 }
local FILLED = "Flat UI: your quest log is full (%d/%d)."
-- The most quests one read may add and still count as the log filling (an accept adds one, a shared chain two), and the seconds after entering
-- the world in which a read of 0 quests is taken as a log that loads.
local FILL_STEP, LOAD_WAIT = 2, 2
local NOTE = "Quest count: the objective tracker has no Quests heading here, so there is no count."
local ANCHOR = "ANCHOR_LEFT"
local HINT, FIGHT_HINT = { "Click: open the quest log" }, { "Click: open the quest log, after the fight" }
local LATER = "Flat UI: the quest log opens when the fight ends."

-- text: the font string; button: the button over it; header: the heading it is on; queued: a redraw waits for the next frame; waiting: a make
-- waits for the end of a fight; last: the quests of the last read, nil before the first after login or a reload and while the row is off;
-- pulse: the frame of Flat UI's own that runs the pulse, shown only while it runs, and pulsed: its seconds so far; entered: when the player last
-- entered the world (PLAYER_ENTERING_WORLD); seen: a read has seen a quest since login or a reload.
local S = {}

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. ".trackerCount") == true
end

-- The client's quest log calls, or nil on a client without them.
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

-- The quests of the log by walking it, as EnhanceQoL counts them: each entry that is no header, not hidden and has a quest ID above 0.
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

-- The quests in the log and the most it holds (nil when the game does not say), or nil when the count is not known. The count is the second
-- answer of GetNumQuestLogEntries, which leaves the headers out, else the walk.
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
	return math.floor(quests), most and math.floor(most) or nil
end

local Queue

-- True while GameTooltip is the button's.
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

-- The tooltip of the Quest log data panel on the button, and its hint; fresh is false when a tooltip that shows is written again.
local function Tip(_, button, fresh)
	local panels = ns.DataPanels
	if type(panels) == "table" and type(panels.TipAt) == "function" then
		panels.TipAt(button, ANCHOR, "quests", fresh, InCombatLockdown() and FIGHT_HINT or HINT)
	end
end

local function Open()
	if type(_G.ToggleQuestLog) == "function" and ns.OpenAfterFight ~= nil then
		ns.OpenAfterFight(function()
			_G.ToggleQuestLog()
		end, LATER)
	end
end

-- The button over the count's text, made with it; nil when the client refuses it.
local function MakeButton(header, text)
	local ok, button = pcall(CreateFrame, "Button", nil, header)
	if not ok or type(button) ~= "table" then
		return nil
	end
	ns.Own[button] = true
	button:SetAllPoints(text)
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonUp")
	button:SetScript("OnClick", function()
		ns.EachPart(KEY, PART, Open, {})
	end)
	button:SetScript("OnEnter", function(self)
		ns.EachPart(KEY, PART, Tip, {}, self, true)
	end)
	button:SetScript("OnLeave", Unowned)
	button:SetScript("OnHide", Unowned)
	button:Hide()
	return button
end

-- Makes the font string on the heading, once. False while it cannot be made now: in a fight on a heading the game may protect, the make
-- waits for the end of the fight.
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

-- The font and the colour of the heading's text, as Flat UI's Heading size and the game left them. The text is the game's: only its two widget
-- getters are called, each in a pcall, and an answer the game withholds is not used.
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

-- The count dips to PULSE.low and back PULSE.count times over PULSE.time seconds, from a frame of Flat UI's own. Only Flat UI's own font string
-- changes, so it goes on in a fight too.
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

-- True when the log became full since the last read, with Warn as the log fills on: the first read after login or a reload never warns, and
-- neither does a log that grows by more than FILL_STEP quests in one read, which is a log that loads, not quests accepted.
local function Filled(quests, most)
	local last = S.last
	S.last = quests
	return ns.Get(KEY .. ".trackerCountWarn") == true and last ~= nil and most ~= nil and last < most and quests >= most
		and quests - last <= FILL_STEP
end

local function Update()
	-- Nothing is made, and nothing noted, while the game gives no count: a client without the quest log calls has no text at all.
	local quests, most
	if Wanted() then
		quests, most = Numbers()
	end
	if not quests then
		S.last = nil
		Hide()
		ns.ClearNote(KEY, NOTE)
		return
	end
	-- Warn as the log fills: one line in chat as the log becomes full, also while the heading is not there, and a pulse of the count below. A read
	-- of 0 quests within LOAD_WAIT seconds of entering the world, before any read has seen a quest, may be a log still loading: it is not taken
	-- as the first read (S.last stays nil).
	local loading = quests == 0 and S.last == nil and not S.seen and ns.Finite(S.entered) and GetTime() - S.entered < LOAD_WAIT
	if quests > 0 then
		S.seen = true
	end
	local filled = not loading and Filled(quests, most)
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
	S.text:SetText(most and ("%d/%d"):format(quests, most) or tostring(quests))
	S.text:Show()
	if filled then
		Pulse()
	end
	if S.button then
		S.button:Show()
		-- A tooltip that shows follows the new count, while it is still the button's.
		if Owns(S.button) then
			ns.EachPart(KEY, PART, Tip, {}, S.button, false)
		end
	end
end

-- Runs the part. Each run has a key of its own, so every failure counts toward stopping the part; a stopped part takes its text away.
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

-- A change of the quest log is looked at on the next frame, only while a count can be shown or the text is there to hide.
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

-- Hud.lua calls this at the end of RefreshTracker: a changed row, Heading size, the page or the profile.
function ns.QuestCountRefresh()
	Draw()
end
