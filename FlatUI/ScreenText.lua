local _, ns = ...

local KEY, PART = "hud", "zone name and talking head"
local EVENT = "TALKINGHEAD_REQUESTED"
local ROWS = { "zoneTitle", "subzoneTitle" }
local STRINGS = { zoneTitle = { "ZoneTextString", "PVPInfoTextString" }, subzoneTitle = { "SubZoneTextString", "PVPArenaTextString" } }
local LABELS = { zoneTitle = "Zone name", subzoneTitle = "Subzone name" }
local SMALL = "SubZoneTextString"

local kept, hides = {}, { zoneTitle = {}, subzoneTitle = {} }
local refused, missing = {}, {}
local followed = false
local sizeRefused = false
local T = {}
local Talk

local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and type(value) == "table" and not ns.IsSecret(value) then
		return value
	end
	return nil
end

local function Wanted(row)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(KEY .. "." .. row) == true
end

local function Drop(row, text)
	hides[row][text] = nil
	for _, other in ipairs(ROWS) do
		if hides[other][text] then
			return
		end
	end
	local alpha = kept[text]
	kept[text] = nil
	if alpha ~= nil then
		pcall(text.SetAlpha, text, alpha)
	end
end

local function Release(row)
	for text in pairs(hides[row]) do
		Drop(row, text)
	end
end

local function Take(row, text)
	if kept[text] == nil then
		local ok, alpha = pcall(text.GetAlpha, text)
		kept[text] = ok and ns.Finite(alpha) and alpha >= 0 and alpha <= 1 and alpha or 1
	end
	hides[row][text] = true
	return (pcall(text.SetAlpha, text, 0))
end

local function HoldsZone(text)
	local okText, shown = pcall(text.GetText, text)
	local okZone, zone = pcall(GetZoneText)
	return okText and okZone and not ns.IsSecret(shown) and not ns.IsSecret(zone) and type(shown) == "string" and shown ~= "" and shown == zone
end

local function Small()
	local text = Global(SMALL)
	if text == nil or type(text.SetAlpha) ~= "function" then
		return
	end
	if Wanted("zoneTitle") and not refused.zoneTitle and HoldsZone(text) then
		if not Take("zoneTitle", text) then
			refused.zoneTitle = true
			Release("zoneTitle")
		end
	elseif hides.zoneTitle[text] then
		Drop("zoneTitle", text)
	end
end

local function OnZoneText()
	if Wanted("zoneTitle") then
		ns.EachPart(KEY, PART, Small, {})
	end
end

local function Strings(row)
	if not Wanted(row) or refused[row] then
		missing[row] = nil
		Release(row)
		return
	end
	local found = 0
	for _, name in ipairs(STRINGS[row]) do
		local text = Global(name)
		if text ~= nil and type(text.SetAlpha) == "function" then
			found = found + 1
			if not Take(row, text) then
				refused[row] = true
				Release(row)
				return
			end
		end
	end
	missing[row] = found == 0 or nil
	if row == "zoneTitle" then
		if not followed then
			followed = ns.FollowGlobal("SetZoneText", OnZoneText) == true
		end
		Small()
	end
end

local function Head()
	local head = Global("TalkingHeadFrame")
	if head == nil or ns.Forbidden(head) then
		return nil
	end
	return head
end

local function Listens(head)
	local ok, on = pcall(head.IsEventRegistered, head, EVENT)
	if not ok or ns.IsSecret(on) or type(on) ~= "boolean" then
		return nil
	end
	return on
end

local function Blocked(head)
	return InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(head))
end

local function Wait()
	if T.waiting then
		return
	end
	T.waiting = true
	ns.OutOfCombat(function()
		T.waiting = false
		local ok, err = pcall(Talk)
		if not ok then
			geterrorhandler()(err)
		end
	end)
end

function Talk()
	local head = Head()
	if head == nil then
		T.absent = Wanted("talkingHead") or nil
		T.held, T.stuck = false, nil
		return
	end
	T.absent = nil
	if Wanted("talkingHead") then
		local on = Listens(head)
		if on == true then
			if Blocked(head) then
				Wait()
				return
			end
			pcall(head.UnregisterEvent, head, EVENT)
			local now = Listens(head)
			if now ~= false then
				if now == nil then
					pcall(head.RegisterEvent, head, EVENT)
				end
				T.held, T.refused, T.aside = false, true, nil
				return
			end
			T.held = true
		elseif not T.held then
			T.aside, T.refused = on == false or nil, on == nil or nil
			return
		end
		T.aside, T.refused, T.stuck = nil, nil, nil
		return
	end
	if T.held then
		if Listens(head) == false then
			if Blocked(head) then
				Wait()
				return
			end
			pcall(head.RegisterEvent, head, EVENT)
			if Listens(head) == false then
				T.stuck = true
				return
			end
		end
		T.held = false
	end
	T.aside, T.refused, T.stuck = nil, nil, nil
end

local function Sizes()
	local size = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and tonumber(ns.Get(KEY .. ".zoneTitleSize")) or 100
	size = math.max(50, math.min(150, size))
	sizeRefused = false
	for _, row in ipairs(ROWS) do
		for _, name in ipairs(STRINGS[row]) do
			local text = Global(name)
			if text ~= nil and type(text.SetFont) == "function" and ns.TextStyle(text, { percent = size }) == false then
				sizeRefused = size ~= 100
			end
		end
	end
end

local function Apply()
	for _, row in ipairs(ROWS) do
		Strings(row)
	end
	Sizes()
	Talk()
end

ns.AddStatus(KEY, function()
	local lines = {}
	for _, row in ipairs(ROWS) do
		if ns.Get(KEY .. "." .. row) == true and refused[row] then
			lines[#lines + 1] = ("%s: the game refused a change of opacity, so it shows until /reload."):format(LABELS[row])
		elseif Wanted(row) and missing[row] then
			lines[#lines + 1] = ("%s: this client has no such text, so nothing is hidden."):format(LABELS[row])
		end
	end
	if sizeRefused then
		lines[#lines + 1] = "Zone title size: the game refused a size, so the zone names keep the game's."
	end
	if T.stuck then
		lines[#lines + 1] = "Talking head: the game did not take its talking head back, so none shows until /reload."
	elseif T.held and not Wanted("talkingHead") then
		lines[#lines + 1] = "Talking head: shown again at the end of the fight."
	elseif not Wanted("talkingHead") then
		return lines
	elseif T.absent then
		lines[#lines + 1] = "Talking head: this client has none, so nothing is hidden."
	elseif T.waiting and not T.held then
		lines[#lines + 1] = "Talking head: hidden at the end of the fight."
	elseif T.refused then
		lines[#lines + 1] = "Talking head: the game kept it, so it shows as usual."
	elseif T.aside then
		lines[#lines + 1] = "Talking head: another addon has taken it off already, so Flat UI leaves it."
	end
	return lines
end)

function ns.ScreenTextRefresh()
	if not ns.PartStopped(KEY, PART) then
		ns.EachPart(KEY, PART, Apply, {})
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Apply)
	end
end
