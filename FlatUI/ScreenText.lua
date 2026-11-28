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
local Z = { hold = 3, out = 0.5, width = 512, box = 128, zone = "Elwynn Forest", sub = "Goldshire", pvp = "(Contested Territory)",
	colour = { 1, 0.93, 0.76 }, pvpColour = { 1, 0.7, 0 } }
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
	Z.objects = Z.objects or {}
	for _, row in ipairs(ROWS) do
		for _, name in ipairs(STRINGS[row]) do
			local text = Global(name)
			if text ~= nil and size ~= 100 and Z.objects[name] == nil and type(text.GetFontObject) == "function" then
				local ok, object = pcall(text.GetFontObject, text)
				Z.objects[name] = ok and type(object) == "table" and not ns.IsSecret(object) and object or false
			end
			if text ~= nil and type(text.SetFont) == "function" and ns.TextStyle(text, { percent = size }) == false then
				sizeRefused = size ~= 100
			end
		end
	end
	return size
end

function ns.ZoneTitleRefont()
	local again = false
	for name, object in pairs(Z.objects or {}) do
		local text = object and Global(name) or nil
		if text ~= nil and type(text.SetFontObject) == "function" and pcall(text.SetFontObject, text, object) then
			ns.TextStyleForget(text)
			again = true
		end
	end
	if again then
		Sizes()
	end
end

function Z.Copy(text, name)
	local source = Global(name)
	if source == nil or ns.Forbidden(source) then
		return
	end
	local ok, file, size, flags = pcall(source.GetFont, source)
	if ok and not (ns.IsSecret(file) or ns.IsSecret(flags)) and type(file) == "string" and ns.Finite(size) and size > 0 then
		pcall(text.SetFont, text, file, size, type(flags) == "string" and flags or "")
	end
	local okOffset, x, y = pcall(source.GetShadowOffset, source)
	if okOffset and ns.Finite(x) and ns.Finite(y) then
		pcall(text.SetShadowOffset, text, x, y)
	end
	local okShadow, r, g, b, a = pcall(source.GetShadowColor, source)
	if okShadow and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		pcall(text.SetShadowColor, text, r, g, b, ns.Finite(a) and a or 1)
	end
end

function Z.Build(holder)
	holder.lines = {}
	for index, name in ipairs({ "ZoneTextString", "PVPInfoTextString", "SubZoneTextString" }) do
		local text = ns.OwnText(holder, "ARTWORK", "GameFontNormalLarge")
		if not text then
			error("no text for the zone sample", 0)
		end
		text:SetWidth(Z.width)
		text:SetJustifyH("CENTER")
		holder.lines[index] = { text = text, from = name }
	end
end

local function Tall(text)
	local ok, height = pcall(text.GetStringHeight, text)
	return ok and ns.Finite(height) and height > 0 and height or 0
end

function Z.Paint(holder)
	local zone, pvp, sub = holder.lines[1], holder.lines[2], holder.lines[3]
	local pvpText = Global("CONTESTED_TERRITORY")
	local words = { Z.zone, type(pvpText) == "string" and pvpText ~= "" and pvpText or Z.pvp, Z.sub }
	for index, line in ipairs(holder.lines) do
		Z.Copy(line.text, line.from)
		line.text:SetText(words[index])
		local colour = index == 2 and Z.pvpColour or Z.colour
		line.text:SetTextColor(colour[1], colour[2], colour[3])
	end
	zone.text:ClearAllPoints()
	zone.text:SetPoint("CENTER", holder, "TOP", 0, -Z.box / 2)
	pvp.text:ClearAllPoints()
	pvp.text:SetPoint("TOP", zone.text, "BOTTOM", 0, 0)
	sub.text:ClearAllPoints()
	sub.text:SetPoint("TOP", pvp.text, "BOTTOM", 0, 0)
	local hideZone, hideSub = Wanted("zoneTitle"), Wanted("subzoneTitle")
	zone.text:SetShown(not hideZone)
	pvp.text:SetShown(not hideZone)
	sub.text:SetShown(not hideSub)
	return Z.width, math.max(Z.box, Z.box / 2 + Tall(zone.text) / 2 + Tall(pvp.text) + Tall(sub.text))
end

function Z.Showing(name)
	local frame = Global(name)
	if frame == nil or ns.Forbidden(frame) then
		return false
	end
	local ok, shown = pcall(frame.IsVisible, frame)
	local okAlpha, alpha = pcall(frame.GetAlpha, frame)
	return ok and not ns.IsSecret(shown) and shown == true and okAlpha and ns.Finite(alpha) and alpha > 0.01
end

function Z.Real()
	return Z.Showing("ZoneTextFrame") or Z.Showing("SubZoneTextFrame")
end

function Z.Gate()
	return not (Wanted("zoneTitle") and Wanted("subzoneTitle"))
end

function Z.Step(holder, elapsed)
	Z.at = (Z.at or 0) + (ns.Finite(elapsed) and elapsed or 0)
	if Z.at <= Z.hold then
		return
	end
	local fade = (Z.at - Z.hold) / Z.out
	if fade >= 1 then
		holder:Hide()
	else
		holder:SetAlpha(1 - fade)
	end
end

function Z.Preview()
	local game = Global("ZoneTextFrame")
	if Z.broken or game == nil or ns.Forbidden(game) or type(ns.MoverRect) ~= "function" or not Z.Gate() then
		return
	end
	local left, bottom, width, height = ns.MoverRect(game)
	if not (ns.Finite(left) and ns.Finite(bottom) and ns.Finite(width) and ns.Finite(height)) then
		return
	end
	if not Z.holder then
		local ok, holder = pcall(CreateFrame, "Frame", nil, UIParent)
		if not ok or type(holder) ~= "table" then
			return
		end
		ns.Own[holder] = true
		holder:EnableMouse(false)
		holder:SetFrameStrata("DIALOG")
		holder:Hide()
		if not pcall(Z.Build, holder) then
			Z.broken = true
			return
		end
		holder:SetScript("OnUpdate", Z.Step)
		Z.holder = holder
	end
	local holder = Z.holder
	local okMine, mine = pcall(game.GetEffectiveScale, game)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	local k = okMine and okBase and ns.Finite(mine) and ns.Finite(base) and mine > 0 and base > 0 and mine / base or 1
	holder:SetScale(k)
	holder:ClearAllPoints()
	holder:SetPoint("TOP", UIParent, "BOTTOMLEFT", (left + width / 2) / k, (bottom + height) / k)
	local wide, tall = Z.Paint(holder)
	holder:SetSize(wide, tall)
	Z.at = 0
	holder:SetAlpha(1)
	holder:Show()
end

local function Apply()
	for _, row in ipairs(ROWS) do
		Strings(row)
	end
	local size = Sizes()
	local testing = ns.TestMode ~= nil and ns.TestMode.IsOn()
	if Z.last ~= nil and Z.last ~= size and ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and not testing and ns.PanelShown ~= nil
		and ns.PanelShown() then
		Z.Preview()
	end
	Z.last = size
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

if ns.TestMode and ns.TestMode.StandIn then
	ns.TestMode.StandIn({ id = "zonetext", module = KEY, game = "ZoneTextFrame", label = "Zone text", corner = "TOP", gate = Z.Gate, real = Z.Real,
		Build = Z.Build, Paint = Z.Paint })
end

function ns.ScreenTextRefresh()
	if not ns.PartStopped(KEY, PART) then
		ns.EachPart(KEY, PART, Apply, {})
	end
	if ns.PartStopped(KEY, PART) then
		pcall(Apply)
	end
end
