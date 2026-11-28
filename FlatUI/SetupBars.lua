local _, ns = ...

local S = ns.Setup
local E = ns.Errands
local B = { token = 0, placed = 0 }
local LINE = "Flat UI: put %d of your spells on your bars; nothing you placed was moved."
local ONE, MANY = "1 of your spells is ready for an empty bar button.", "%d of your spells are ready for empty bar buttons."
local MACRO = "/stopmacro [combat]\n/reload"
local SECOND, SECOND_FIRST, WIDTH, SCAN = "MultiBarBottomLeftButton", 61, 12, 180
local LOGIN_WAIT, PICK_WAIT, LEARN_WAIT = 2, 0.2, 1
local NOTICE_WIDTH, NOTICE_HEIGHT, NOTICE_Y, PLACE_WIDTH, LATER_WIDTH, GAP = 380, 30, -222, 124, 60, 4

local function Whole(value)
	return ns.Finite(value) and value > 0 and value % 1 == 0
end

local function Using(profile)
	local name = ns.Profile()
	return type(profile) == "table" and type(profile.label) == "string" and type(name) == "string" and not ns.IsSecret(name)
		and name:lower() == profile.label:lower()
end

local function Look()
	for _, profile in ipairs(S.Presets()) do
		if profile.only ~= nil and profile.bars and S.ForYou(profile) and Using(profile) then
			return profile
		end
	end
	return nil
end

local function Record(create)
	local char = ns.Character()
	if type(char) ~= "table" then
		return nil
	end
	if type(char.readyBars) ~= "table" then
		if not create then
			return nil
		end
		char.readyBars = {}
	end
	return char.readyBars
end

local function SecondSlot(index)
	local button = _G[SECOND .. index]
	local ok, action = false, nil
	if type(button) == "table" then
		ok, action = pcall(function()
			return button.action
		end)
	end
	if ok and Whole(action) and action <= SCAN then
		return action
	end
	return SECOND_FIRST + index - 1
end

local function Slots(profile)
	local list = {}
	local bars = profile.bars
	for index = 1, WIDTH do
		local ids = type(bars.main) == "table" and bars.main[index]
		if type(ids) == "table" then
			list[#list + 1] = { slot = index, ids = ids }
		end
	end
	for index = 1, WIDTH do
		local ids = type(bars.bar2) == "table" and bars.bar2[index]
		if type(ids) == "table" then
			list[#list + 1] = { slot = SecondSlot(index), ids = ids }
		end
	end
	return list
end

local function Held(slot)
	if type(GetActionInfo) ~= "function" then
		return nil
	end
	local ok, kind, id = pcall(GetActionInfo, slot)
	if not ok or ns.IsSecret(kind) or ns.IsSecret(id) then
		return nil
	end
	if kind ~= nil then
		return kind, id
	end
	if type(HasAction) == "function" then
		local fine, has = pcall(HasAction, slot)
		if not fine or ns.IsSecret(has) then
			return nil
		elseif has then
			return "other", nil
		end
	end
	return false, nil
end

local function OnBars()
	local on = {}
	for slot = 1, SCAN do
		local kind, id = Held(slot)
		if kind == "spell" and Whole(id) then
			on[id] = true
		end
	end
	return on
end

local function Known(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or nil
	if book and E.Ask(book.IsSpellKnown, id) == true then
		return true
	end
	return E.Ask(IsPlayerSpell, id) == true
end

local function Best(ids)
	for index = #ids, 1, -1 do
		local id = ids[index]
		if Whole(id) and Known(id) then
			return id
		end
	end
	return nil
end

local function Listed(ids, on)
	for _, id in ipairs(ids) do
		if on[id] then
			return true
		end
	end
	return false
end

local function BookSlot(id)
	local book = type(C_SpellBook) == "table" and C_SpellBook or nil
	local slot = book and E.Ask(book.FindSpellBookSlotForSpell, id)
	return Whole(slot) and slot or nil
end

local function Put(slot, id)
	if not E.PickupSpell({ new = id, base = id, bookSlot = BookSlot(id) }) then
		E.Call(ClearCursor)
		return false
	end
	local ok, kind = pcall(GetCursorInfo)
	if not ok or ns.IsSecret(kind) or kind ~= "spell" then
		E.Call(ClearCursor)
		return false
	end
	E.Call(E.Placer(), slot)
	E.Call(ClearCursor)
	return Held(slot) == "spell"
end

local function Usable()
	return type(GetActionInfo) == "function" and type(GetCursorInfo) == "function" and type(ClearCursor) == "function"
		and type(E.PickupSpell) == "function" and type(E.Placer) == "function" and E.Placer() ~= nil
end

local function Scan(profile, record)
	local on, list = OnBars(), {}
	for _, spot in ipairs(Slots(profile)) do
		if record[spot.slot] == nil then
			local kind, id = Held(spot.slot)
			if kind == "spell" and Whole(id) and Listed(spot.ids, { [id] = true }) then
				record[spot.slot] = "there"
			elseif kind then
				record[spot.slot] = "kept"
			elseif kind == false and Listed(spot.ids, on) then
				record[spot.slot] = "elsewhere"
			elseif kind == false then
				local best = Best(spot.ids)
				if best then
					list[#list + 1] = { slot = spot.slot, id = best }
				end
			end
		end
	end
	return list
end

local function Signature(list)
	local parts = {}
	for _, item in ipairs(list) do
		parts[#parts + 1] = item.slot .. ":" .. item.id
	end
	return table.concat(parts, ",")
end

local function Fill()
	B.placed = 0
	local profile, record = Look(), Record(false)
	if not profile or not record or not Usable() or E.Fighting() or E.CursorBusy() then
		return
	end
	for _, item in ipairs(Scan(profile, record)) do
		if Put(item.slot, item.id) then
			record[item.slot] = "filled"
			B.placed = B.placed + 1
		end
	end
	if E.CursorBusy() then
		E.Call(ClearCursor)
	end
end

local function Detach()
	local notice = B.notice
	if not notice or E.InCombat() then
		return
	end
	pcall(function()
		notice.overlay:Hide()
		notice.overlay:ClearAllPoints()
		notice.overlay:SetParent(UIParent)
	end)
end

local function Attach()
	local notice = B.notice
	if not notice or E.InCombat() then
		return
	end
	pcall(function()
		notice.overlay:SetParent(notice.place)
		notice.overlay:SetAllPoints(notice.place)
		notice.overlay:Show()
	end)
	pcall(function()
		local level = notice.place:GetFrameLevel()
		if ns.Finite(level) then
			notice.overlay:SetFrameLevel(level + 2)
		end
	end)
end

local function Hide()
	if not B.notice then
		return
	end
	if E.InCombat() then
		ns.OutOfCombat(Hide)
		return
	end
	Detach()
	B.notice.frame:Hide()
end

local function Later()
	local record = Record(false)
	if record and B.mark then
		record.later = B.mark
	end
	Hide()
end

local function Why()
	if E.Fighting() then
		return "Flat UI: not in a fight. The offer comes back after it."
	elseif E.CursorBusy() then
		return "Flat UI: put down what the cursor holds first."
	end
	return "Flat UI: no empty bar button needs a spell now."
end

local function PreClick(self)
	B.keep = E.CursorBusy()
	local ok, err = pcall(Fill)
	if not ok then
		geterrorhandler()(err)
	end
	if B.placed > 0 then
		local char = ns.Character()
		if type(char) == "table" then
			char.readyBarsSaid = B.placed
		end
		return
	end
	print(Why())
	if not E.InCombat() then
		pcall(self.SetAttribute, self, "type", nil)
	end
end

local function PostClick(self)
	if not E.InCombat() then
		pcall(self.SetAttribute, self, "type", "macro")
	end
	if not B.keep then
		Hide()
	end
end

local function Forward(overlay, button, script)
	overlay:SetScript(script, function(_, ...)
		local got, fn = pcall(button.GetScript, button, script)
		if got and type(fn) == "function" then
			fn(button, ...)
		end
	end)
end

local function Build()
	if B.notice then
		return true
	end
	if B.broken or E.InCombat() then
		return false
	end
	local ok, made = pcall(function()
		local frame = CreateFrame("Frame", nil, UIParent)
		ns.Own[frame] = true
		frame:SetSize(NOTICE_WIDTH, NOTICE_HEIGHT)
		frame:SetPoint("TOP", UIParent, "TOP", 0, NOTICE_Y)
		frame:SetFrameStrata("DIALOG")
		pcall(frame.SetClampedToScreen, frame, true)
		local outline = ns.Outline(frame, frame, true)
		if outline then
			ns.SetOutlineFill(outline, 0.09, 0.09, 0.09, 0.95)
		end
		local text = ns.OwnText(frame, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", frame, "LEFT", 10, 0)
		local place = E.Button(frame, "Place and reload", PLACE_WIDTH, function()
			print("Flat UI: the Place button is not ready. Try again in a moment.")
		end)
		place:SetPoint("RIGHT", frame, "RIGHT", -GAP, 0)
		local later = E.Button(frame, "Later", LATER_WIDTH, function()
			local fine, err = pcall(Later)
			if not fine then
				geterrorhandler()(err)
			end
		end)
		later:SetPoint("RIGHT", place, "LEFT", -GAP, 0)
		local overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
		ns.Own[overlay] = true
		overlay:Hide()
		overlay:SetFrameStrata("DIALOG")
		overlay:RegisterForClicks("LeftButtonUp")
		overlay:SetAttribute("type", "macro")
		overlay:SetAttribute("macrotext", MACRO)
		overlay:SetAttribute("useOnKeyDown", false)
		overlay:SetScript("PreClick", PreClick)
		overlay:SetScript("PostClick", PostClick)
		Forward(overlay, place, "OnEnter")
		Forward(overlay, place, "OnLeave")
		frame:Hide()
		return { frame = frame, text = text, place = place, overlay = overlay }
	end)
	if not ok or type(made) ~= "table" then
		B.broken = true
		return false
	end
	B.notice = made
	return true
end

local function Show(count)
	if E.InCombat() or not Build() then
		return
	end
	local notice = B.notice
	notice.text:SetText(count == 1 and ONE or MANY:format(count))
	local fine, width = pcall(notice.text.GetStringWidth, notice.text)
	if fine and ns.Finite(width) then
		notice.frame:SetWidth(math.max(NOTICE_WIDTH, math.ceil(width) + PLACE_WIDTH + LATER_WIDTH + 30))
	end
	Attach()
	notice.frame:Show()
end

local function Offer(profile, fresh)
	local record = Record(false)
	if not record or not Usable() or E.Gamepad() then
		Hide()
		return
	end
	local list = Scan(profile, record)
	if #list == 0 then
		Hide()
		return
	end
	local mark = Signature(list)
	if not fresh and record.later == mark then
		return
	end
	B.mark = mark
	Show(#list)
end

local Soon

local function Run()
	if E.Fighting() then
		ns.OutOfCombat(function()
			Soon(LEARN_WAIT)
		end)
		return
	end
	local touch = B.touch
	B.touch = nil
	local profile = Look()
	if not profile then
		Hide()
		return
	end
	local fresh = touch == profile.id
	if fresh then
		if profile.trackers and type(ns.TrackerAddClassNamed) == "function" then
			ns.TrackerAddClassNamed(profile.trackers)
		end
		Record(true)
	end
	Offer(profile, fresh)
end

Soon = function(wait)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		return
	end
	B.token = B.token + 1
	local token = B.token
	C_Timer.After(wait, function()
		if token == B.token then
			ns.OutOfCombat(function()
				local ok, err = pcall(Run)
				if not ok then
					geterrorhandler()(err)
				end
			end)
		end
	end)
end

function S.Touch(profile)
	if type(profile) ~= "table" or profile.only == nil or not (profile.bars or profile.trackers) then
		return
	end
	B.touch = profile.id
	if ns.Started() then
		Soon(PICK_WAIT)
	end
end

function S.Touched()
	local char = ns.Character()
	if type(char) == "table" and char.readyBarsSaid ~= nil then
		local count = char.readyBarsSaid
		char.readyBarsSaid = nil
		if Whole(count) then
			print(LINE:format(count))
		end
	end
	if B.touch then
		Soon(LOGIN_WAIT)
	end
end

local function Shown()
	return B.notice ~= nil and E.Shown(B.notice.frame)
end

local function Heard(event)
	if event == "PLAYER_REGEN_DISABLED" then
		if Shown() then
			B.again = true
			Hide()
		end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		if B.again then
			B.again = nil
			Soon(LEARN_WAIT)
		end
		return
	end
	if B.touch == nil and ns.Started() and Record(false) and Look() then
		Soon(LEARN_WAIT)
	end
end

local frame = CreateFrame("Frame")
ns.Own[frame] = true
frame:SetScript("OnEvent", function(_, event)
	local ok, err = pcall(Heard, event)
	if not ok then
		geterrorhandler()(err)
	end
end)
for _, event in ipairs({ "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	pcall(frame.RegisterEvent, frame, event)
end
