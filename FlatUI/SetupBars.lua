local _, ns = ...

local S = ns.Setup
local E = ns.Errands
local B = { token = 0, tries = 0 }
local LINE = "Flat UI: put %d of your spells on your bars; nothing you placed was moved."
local SECOND, SECOND_FIRST, WIDTH, SCAN = "MultiBarBottomLeftButton", 61, 12, 180
local LOGIN_WAIT, PICK_WAIT, LEARN_WAIT, RETRY, MOST_TRIES = 2, 0.2, 1, 3, 20

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

local Soon

local function Fill(profile)
	local record = Record(false)
	if not record or not Usable() then
		return
	end
	if E.CursorBusy() then
		B.tries = B.tries + 1
		if B.tries <= MOST_TRIES then
			Soon(RETRY)
		end
		return
	end
	B.tries = 0
	local on, placed = OnBars(), 0
	for _, spot in ipairs(Slots(profile)) do
		if record[spot.slot] == nil then
			local kind, id = Held(spot.slot)
			if kind == "spell" and Whole(id) and Listed(spot.ids, { [id] = true }) then
				record[spot.slot] = "there"
			elseif kind then
				record[spot.slot] = "kept"
			elseif kind == false and not Listed(spot.ids, on) then
				local best = Best(spot.ids)
				if best and Put(spot.slot, best) then
					record[spot.slot] = "filled"
					on[best] = true
					placed = placed + 1
				end
			end
		end
	end
	if E.CursorBusy() then
		E.Call(ClearCursor)
	end
	if placed > 0 then
		print(LINE:format(placed))
	end
end

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
		return
	end
	if touch == profile.id then
		if profile.trackers and type(ns.TrackerAddClassNamed) == "function" then
			ns.TrackerAddClassNamed(profile.trackers)
		end
		Record(true)
	end
	Fill(profile)
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
	B.tries = 0
	if ns.Started() then
		Soon(PICK_WAIT)
	end
end

function S.Touched()
	if B.touch then
		Soon(LOGIN_WAIT)
	end
end

local function Learned()
	if B.touch == nil and ns.Started() and Record(false) and Look() then
		Soon(LEARN_WAIT)
	end
end

local frame = CreateFrame("Frame")
ns.Own[frame] = true
frame:SetScript("OnEvent", function()
	local ok, err = pcall(Learned)
	if not ok then
		geterrorhandler()(err)
	end
end)
for _, event in ipairs({ "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do
	pcall(frame.RegisterEvent, frame, event)
end
