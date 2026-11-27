local ADDON_NAME, ns = ...

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Text style"
local FLAGS = { none = "", thin = "OUTLINE", thick = "OUTLINE, THICK" }
local SWITCH = { player = "playerName", target = "targetName", focus = "focusName", pet = "petName", tot = "totName", party = "partyName", partypet = "partyName",
	boss = "bossName" }
local NOTE = { names = "Text style: the client refused a name font or outline", bars = "Text style: the client refused a bar text font or outline",
	nameFace = "Text style: the client does not load the Name font, so names keep the game's font",
	barFace = "Text style: the client does not load the Bar text font, so bar text keeps the game's font" }
local refusals = { names = setmetatable({}, { __mode = "k" }), bars = setmetatable({}, { __mode = "k" }) }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Face(id, slot)
	local file = id ~= "default" and ns.FontFile(id) or nil
	if id ~= "default" and file == nil then
		ns.Note(KEY, NOTE[slot])
	else
		ns.ClearNote(KEY, NOTE[slot])
	end
	return file
end

local function Off()
	return ns.PartStopped(KEY, PART)
end

local function Sync(slot)
	if next(refusals[slot]) ~= nil then
		ns.Note(KEY, NOTE[slot])
	else
		ns.ClearNote(KEY, NOTE[slot])
	end
end

function X.refused(rec, slot, part)
	local list = refusals[slot][rec] or {}
	list[part] = true
	refusals[slot][rec] = list
	Sync(slot)
end

local function Cleared(rec, slot, part)
	local list = refusals[slot][rec]
	if list and list[part] then
		list[part] = nil
		if next(list) == nil then
			refusals[slot][rec] = nil
		end
		Sync(slot)
	end
end

local function NameColour(rec)
	local mode = Opt("nameColour")
	if mode == "custom" then
		return ns.Colour(KEY .. ".nameCustom")
	elseif mode == "white" then
		if X.rowOn(rec) or rec.kind == "raid" then
			return 1, 1, 1
		end
		return nil
	end
	local unit = X.unitOf(rec)
	if unit == nil then
		return nil
	end
	if mode == "class" then
		local ok, player = pcall(UnitIsPlayer, unit)
		if not ok or ns.IsSecret(player) or type(player) ~= "boolean" then
			return nil
		end
		if player then
			return ns.ClassColourOf(unit)
		end
		return X.reaction(unit)
	elseif mode == "reaction" then
		return X.reaction(unit)
	end
	return nil
end

local function NameLook(rec, spec)
	local face = Face(Opt("nameFace"), "nameFace")
	local flags = FLAGS[Opt("nameOutline")]
	local size = Opt("nameSize")
	local r, g, b = NameColour(rec)
	spec.face = face
	if flags ~= nil then
		spec.flags = flags
	end
	spec.percent = spec.percent * size / 100
	if r ~= nil then
		spec.r, spec.g, spec.b = r, g, b
	end
	return face ~= nil or flags ~= nil or size ~= 100 or r ~= nil
end

local function BuildName(rec, on, spec)
	Cleared(rec, "names", "name")
	if on and not X.rowOn(rec) then
		return NameLook(rec, spec)
	end
	return false
end

local function AskName(rec, on, spec, answer)
	answer.styled = BuildName(rec, on and not Off(), spec)
end

function X.nameSpec(rec, on, spec)
	local answer = {}
	ns.EachPart(KEY, PART, AskName, rec, on, spec, answer)
	return answer.styled == true
end

local function NameText(rec, on)
	local from = rec.parts.nameText
	if from == nil or X.rowOn(rec) then
		return
	end
	local spec = { percent = 100 }
	if not X.large[rec.kind] and rec.kind ~= "boss" then
		spec.percent = on and Opt("smallTextSize") or 100
	end
	local styled = BuildName(rec, on and not Off(), spec)
	if ns.TextStyle(from, spec) == false and styled then
		X.refused(rec, "names", "name")
	end
end

local function RowName(rec)
	local row = rec.row
	if row == nil or not X.rowOn(rec) then
		return
	end
	Cleared(rec, "names", "name")
	local live = not Off()
	local spec = { percent = 100 }
	local styled = live and NameLook(rec, spec)
	local r, g, b = spec.r, spec.g, spec.b
	spec.r, spec.g, spec.b = nil, nil, nil
	if ns.TextStyle(row.name, spec) == false and styled then
		X.refused(rec, "names", "name")
	end
	if live and r ~= nil then
		pcall(row.name.SetTextColor, row.name, r, g, b, 1)
		if Opt("levelColour") == "name" and row.levelOn then
			pcall(row.level.SetTextColor, row.level, r, g, b, 1)
		end
	end
end

local function Visible(rec, on)
	local off = on and not Off() and SWITCH[rec.kind] ~= nil and Opt(SWITCH[rec.kind]) == false
	if rec.row ~= nil and X.rowOn(rec) then
		if off then
			pcall(rec.row.name.Hide, rec.row.name)
			rec.nameHidden = true
		elseif rec.nameHidden then
			pcall(rec.row.name.Show, rec.row.name)
			rec.nameHidden = nil
		end
		rec.nameFaded = nil
	else
		rec.nameHidden = nil
		if off or rec.nameFaded then
			ns.SetFaded(rec.parts.nameText, off)
			rec.nameFaded = off or nil
		end
	end
end

local function Final(rec, on)
	Visible(rec, on)
	NameText(rec, on)
end

local raidFollowed = false
local RaidName

local function OnRaidName(frame)
	if frame == nil or ns.IsSecret(frame) then
		return
	end
	local rec = X.known(frame)
	if rec ~= nil and rec.kind == "raid" and rec.made and X.active(rec) then
		X.run(PART, RaidName, rec, true, true)
	end
end

local function RaidVertex(rec, name, coloured, fresh)
	if coloured then
		if rec.raidVertexWas == nil or fresh then
			local ok, r, g, b = pcall(name.GetVertexColor, name)
			if ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
				rec.raidVertexWas = { r, g, b }
			elseif fresh then
				rec.raidVertexWas = nil
			end
		end
		rec.raidWhite = pcall(name.SetVertexColor, name, 1, 1, 1) or rec.raidWhite
	elseif rec.raidWhite then
		local was = rec.raidVertexWas
		if was ~= nil then
			pcall(name.SetVertexColor, name, was[1], was[2], was[3])
		end
		rec.raidVertexWas, rec.raidWhite = nil, nil
	end
end

function RaidName(rec, on, fresh)
	if rec.kind ~= "raid" then
		return
	end
	local live = on and not Off()
	Cleared(rec, "names", "name")
	Cleared(rec, "bars", "status")
	local name = X.path(rec.frame, "name")
	if name ~= nil then
		local spec = { percent = 100 }
		local styled = live and NameLook(rec, spec)
		local set = ns.TextStyle(name, spec)
		if set == false and styled then
			X.refused(rec, "names", "name")
		end
		RaidVertex(rec, name, live and spec.r ~= nil and set ~= false, fresh)
	end
	local status = X.path(rec.frame, "statusText")
	if status ~= nil then
		local spec = {}
		if live then
			spec.face = Face(Opt("barTextFace"), "barFace")
			spec.flags = FLAGS[Opt("barTextOutline")]
		end
		if ns.TextStyle(status, spec) == false and (spec.face ~= nil or spec.flags ~= nil) then
			X.refused(rec, "bars", "status")
		end
	end
	if live and not raidFollowed then
		raidFollowed = ns.FollowGlobal("CompactUnitFrame_UpdateName", OnRaidName) == true
	end
end

local was = X.unitChanged
function X.unitChanged(rec)
	if was ~= nil then
		was(rec)
	end
	if rec.made and X.active(rec) then
		X.run(PART, rec.kind == "raid" and RaidName or NameText, rec, true)
	end
end

local wasAll = X.unitsChanged
function X.unitsChanged()
	if wasAll ~= nil then
		wasAll()
	end
	for _, rec in pairs(X.records) do
		if rec.made and rec.kind == "raid" and X.active(rec) then
			X.run(PART, RaidName, rec, true)
		elseif rec.made and X.active(rec) then
			X.run(PART, NameText, rec, true)
			if rec.row ~= nil and X.rowOn(rec) then
				X.run(PART, RowName, rec)
			end
		end
	end
end

local function BuildBar(rec, entry, on, spec)
	Cleared(rec, "bars", entry.role)
	if not on or Off() or rec.kind == "raid" then
		return false
	end
	local face = Face(Opt("barTextFace"), "barFace")
	local flags = FLAGS[Opt("barTextOutline")]
	local own = Opt("barTextColourOwn") == true
	spec.face = face
	if flags ~= nil then
		spec.flags = flags
	end
	if own then
		spec.r, spec.g, spec.b = ns.Colour(KEY .. ".barTextColour")
	end
	return face ~= nil or flags ~= nil or own
end

local function AskBar(rec, entry, on, spec, answer)
	answer.styled = BuildBar(rec, entry, on, spec)
end

function X.barSpec(rec, entry, on, spec)
	local answer = {}
	ns.EachPart(KEY, PART, AskBar, rec, entry, on, spec, answer)
	return answer.styled == true
end

function X.ownSpec(slot, spec)
	if Off() then
		return spec
	end
	if slot == "name" then
		spec.face = Face(Opt("nameFace"), "nameFace")
		spec.flags = FLAGS[Opt("nameOutline")]
		spec.percent = (spec.percent or 100) * Opt("nameSize") / 100
	else
		spec.face = Face(Opt("barTextFace"), "barFace")
		spec.flags = FLAGS[Opt("barTextOutline")]
		if Opt("barTextColourOwn") == true then
			spec.r, spec.g, spec.b = ns.Colour(KEY .. ".barTextColour")
		end
	end
	return spec
end

table.insert(X.after.rowText, { part = PART, fn = RowName })
local function Restore(rec, on)
	if rec.parts.nameText ~= nil and X.rowOn(rec) and (X.large[rec.kind] or rec.kind == "boss") then
		Cleared(rec, "names", "name")
		ns.TextStyle(rec.parts.nameText, {})
	end
end

table.insert(X.after.apply, { part = PART, fn = Restore })
table.insert(X.after.apply, { part = PART, fn = RaidName })
table.insert(X.after.raid, { part = PART, fn = RaidName })
table.insert(X.after.final, { part = PART, fn = Final })

local TEXT = "health and power text"
local HEALTH_KEY = { player = "player", target = "target", focus = "focus", pet = "pet", tot = "tot", party = "party", partypet = "party", boss = "boss" }
local POWER_KEY = { player = "player", target = "target", focus = "focus", pet = "pet", party = "party", partypet = "party", boss = "boss" }
local ANCHOR = { left = "LEFT", centre = "CENTER", right = "RIGHT" }
local OFFSET = { left = 3, centre = 0, right = -3 }
local OWN_DEAD = { target = true, focus = true, boss = true, tot = true }
local GHOST = "Ghost"
local NOTE_MADE = "Health and power text: the client did not make the text, so the game's words stay"
local FROM = {
	health = { cur = function(unit) return UnitHealth(unit) end, max = function(unit) return UnitHealthMax(unit) end,
		pct = function(unit) return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) end, miss = function(unit) return UnitHealthMissing(unit) end },
	power = { cur = function(unit) return UnitPower(unit) end, max = function(unit) return UnitPowerMax(unit) end,
		pct = function(unit) return UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100) end, miss = function(unit) return UnitPowerMissing(unit) end },
}
local live, todo, ticker = {}, {}, { waited = 0 }
local HOVER_IN, HOVER_OUT = 0.1, 0.15
local full = {}
local CURVES = { full = { 0, 1, 1, 0 }, empty = { 0, 0, 0.005, 1 }, both = { 0, 0, 0.005, 1, 1, 0 } }
local RAGE = 1

local function Mode(rec, entry, on)
	local keys = entry.role == "health" and HEALTH_KEY or POWER_KEY
	if not on or ns.PartStopped(KEY, TEXT) or keys[rec.kind] == nil then
		return "game"
	end
	local mode = Opt(keys[rec.kind] .. (entry.role == "health" and "HealthText" or "PowerText"))
	if mode == "game" or mode == nil then
		return "game"
	elseif entry.textFaded then
		return "hide"
	end
	return mode
end

X.textMode = Mode

local function Num(value)
	local call = Opt("numberStyle") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or BreakUpLargeNumbers
	return call(value)
end

X.formats = { curmax = "%s / %s", pct = "%.0f%%", curpct = "%s (%.0f%%)", miss = "-%s" }

local function Write(text, mode, unit, role)
	local from = FROM[role]
	if mode == "cur" then
		text:SetText(Num(from.cur(unit)))
	elseif mode == "curmax" then
		text:SetFormattedText(X.formats.curmax, Num(from.cur(unit)), Num(from.max(unit)))
	elseif mode == "pct" then
		text:SetFormattedText(X.formats.pct, from.pct(unit))
	elseif mode == "curpct" then
		text:SetFormattedText(X.formats.curpct, Num(from.cur(unit)), from.pct(unit))
	else
		local miss = from.miss(unit)
		if ns.IsSecret(miss) or (ns.Finite(miss) and miss >= 1) then
			text:SetFormattedText(X.formats.miss, Num(miss))
		else
			text:SetText("")
		end
	end
end

local function Yes(ok, value)
	return ok and not ns.IsSecret(value) and value == true
end

local function Blank(own)
	if not own.blank then
		own.blank = true
		pcall(own.text.SetText, own.text, "")
	end
end

local function Curve(name)
	if full[name] == nil then
		local ok, curve = pcall(function()
			local made = C_CurveUtil.CreateCurve()
			made:SetType(Enum.LuaCurveType.Step)
			local points = CURVES[name]
			for index = 1, #points, 2 do
				made:AddPoint(points[index], points[index + 1])
			end
			return made
		end)
		full[name] = ok and curve or false
	end
	return full[name] or nil
end

local function Rage(unit)
	local ok, kind = pcall(UnitPowerType, unit)
	return ok and ns.Finite(kind) and kind == RAGE
end

local function Shade(own, unit, role, mode)
	local notfull = Opt("ownTextWhen") == "notfull"
	if (notfull or mode == "miss") and unit ~= nil then
		local name = "full"
		if notfull and role == "power" and Rage(unit) then
			name = mode == "miss" and "both" or "empty"
		end
		local curve = Curve(name)
		if curve ~= nil then
			local ok, value
			if role == "health" then
				ok, value = pcall(UnitHealthPercent, unit, true, curve)
			else
				ok, value = pcall(UnitPowerPercent, unit, nil, false, curve)
			end
			if ok and pcall(own.frame.SetAlpha, own.frame, value) then
				return
			end
		end
	end
	pcall(own.frame.SetAlpha, own.frame, 1)
end

local function HoverFades(own)
	if own.fades == nil then
		local text = own.text
		local ok, come, go = pcall(function()
			local rise = text:CreateAnimationGroup()
			local up = rise:CreateAnimation("Alpha")
			up:SetFromAlpha(0)
			up:SetToAlpha(1)
			up:SetDuration(HOVER_IN)
			local fall = text:CreateAnimationGroup()
			local down = fall:CreateAnimation("Alpha")
			down:SetFromAlpha(1)
			down:SetToAlpha(0)
			down:SetDuration(HOVER_OUT)
			pcall(fall.SetToFinalAlpha, fall, true)
			fall:SetScript("OnFinished", function()
				Blank(own)
				pcall(text.SetAlpha, text, 1)
			end)
			return rise, fall
		end)
		own.fades = ok and { come = come, go = go } or false
	end
	return own.fades or nil
end

local function StopFade(group)
	if group ~= nil and group:IsPlaying() then
		pcall(group.Stop, group)
	end
end

local function Steady(own)
	own.hoverOn = nil
	local fades = own.fades
	if fades then
		StopFade(fades.come)
		StopFade(fades.go)
		pcall(own.text.SetAlpha, own.text, 1)
	end
end

local function Quiet(own)
	Steady(own)
	Blank(own)
end

local function Enter(own)
	if own.hoverOn == true then
		return
	end
	own.hoverOn = true
	local fades = HoverFades(own)
	if fades then
		StopFade(fades.go)
		pcall(own.text.SetAlpha, own.text, 1)
		if own.blank then
			pcall(fades.come.Play, fades.come)
		end
	end
end

local function Leave(own)
	local fades = own.fades
	if own.hoverOn == true then
		own.hoverOn = false
		if fades then
			StopFade(fades.come)
			if not own.blank and pcall(fades.go.Play, fades.go) then
				return
			end
		end
	elseif fades and fades.go:IsPlaying() then
		return
	end
	Blank(own)
end

local function Release(rec, entry)
	live[entry] = nil
	local own = entry.own
	if own ~= nil then
		Quiet(own)
		pcall(own.frame.Hide, own.frame)
	end
	if entry.ownFaded then
		entry.ownFaded = nil
		if not entry.textFaded then
			for _, text in ipairs(X.barTexts(rec.parts, entry)) do
				ns.SetFaded(text, false)
			end
		end
	end
end

local function Make(entry)
	local ok, level = pcall(entry.bar.GetFrameLevel, entry.bar)
	local frame = X.frame(entry.bar, ok and type(level) == "number" and level + 4 or nil)
	frame:SetAllPoints(entry.bar)
	local text = ns.OwnText(frame, "OVERLAY", "TextStatusBarText")
	if text ~= nil then
		entry.own = { frame = frame, text = text, blank = true }
	end
end

local function Place(entry)
	local own = entry.own
	local pos = Opt(entry.role == "health" and "healthTextPos" or "powerTextPos")
	if ANCHOR[pos] == nil then
		pos = "centre"
	end
	if own.pos ~= pos then
		own.pos = pos
		own.text:ClearAllPoints()
		own.text:SetPoint(ANCHOR[pos], own.frame, ANCHOR[pos], OFFSET[pos], 0)
		own.text:SetJustifyH(ANCHOR[pos])
	end
end

local function Status(rec, unit)
	local ok, connected = pcall(UnitIsConnected, unit)
	if ok and not ns.IsSecret(connected) and connected == false then
		return PLAYER_OFFLINE or "Offline"
	elseif Yes(pcall(UnitIsGhost, unit)) then
		return GHOST
	elseif Yes(pcall(UnitIsDeadOrGhost, unit)) then
		return OWN_DEAD[rec.kind] and "" or DEAD or "Dead"
	end
	return nil
end

local function Say(entry, word)
	local own = entry.own
	Steady(own)
	pcall(own.frame.SetAlpha, own.frame, 1)
	if own.pos ~= "word" then
		own.pos = "word"
		own.text:ClearAllPoints()
		own.text:SetPoint("CENTER", own.frame, "CENTER", 0, 0)
		own.text:SetJustifyH("CENTER")
	end
	own.blank = false
	pcall(own.frame.Show, own.frame)
	own.text:SetText(word)
end

local function Fill(job)
	local rec, entry = job.rec, job.entry
	local own = entry.own
	local mode = Mode(rec, entry, X.active(rec))
	if own == nil then
		return
	elseif mode == "game" or mode == "hide" then
		Release(rec, entry)
		return
	end
	local unit = X.unitOf(rec)
	if unit == nil or not Yes(pcall(UnitExists, unit)) then
		Quiet(own)
		return
	end
	if entry.role == "health" then
		local word = Status(rec, unit)
		if word == "" then
			Quiet(own)
			return
		elseif word ~= nil then
			Say(entry, word)
			return
		end
	elseif Yes(pcall(UnitIsDeadOrGhost, unit)) then
		Quiet(own)
		return
	end
	local hover = Opt("ownTextWhen") == "hover"
	if hover and not Yes(pcall(rec.frame.IsMouseOver, rec.frame)) then
		Leave(own)
		return
	end
	Place(entry)
	if hover then
		Enter(own)
	else
		Steady(own)
	end
	own.blank = false
	pcall(own.frame.Show, own.frame)
	Shade(own, unit, entry.role, mode)
	Write(own.text, mode, unit, entry.role)
end

local function Tick(_, elapsed)
	ticker.waited = ticker.waited + elapsed
	if ticker.waited < 0.1 then
		return
	end
	ticker.waited = 0
	for entry, rec in pairs(live) do
		todo[#todo + 1] = { rec = rec, entry = entry }
	end
	for index = #todo, 1, -1 do
		local job = table.remove(todo, index)
		if live[job.entry] ~= nil then
			X.run(TEXT, Fill, job)
		end
	end
end

local function Drive()
	local wanted = next(live) ~= nil
	if wanted == (ticker.on == true) then
		return
	end
	ticker.on = wanted
	if wanted and ticker.frame == nil then
		ticker.frame = X.frame(nil)
	end
	if ticker.frame ~= nil then
		ticker.frame:SetScript("OnUpdate", wanted and Tick or nil)
	end
end

local function Settle(rec, entry, on)
	local mode = Mode(rec, entry, on)
	if mode == "game" then
		Release(rec, entry)
		Drive()
		return
	end
	if mode ~= "hide" and entry.own == nil then
		if InCombatLockdown() then
			X.tell("Flat UI: the new health and power text shows when the fight ends.")
			if not entry.queued then
				entry.queued = true
				ns.OutOfCombat(function()
					entry.queued = nil
					X.run(TEXT, Settle, rec, entry, X.active(rec))
				end)
			end
			return
		end
		Make(entry)
		if entry.own == nil then
			ns.Note(KEY, NOTE_MADE)
			return
		end
	end
	ns.ClearNote(KEY, NOTE_MADE)
	for _, text in ipairs(X.barTexts(rec.parts, entry)) do
		ns.SetFaded(text, true)
	end
	entry.ownFaded = true
	if mode == "hide" then
		live[entry] = nil
		if entry.own ~= nil then
			Quiet(entry.own)
			pcall(entry.own.frame.Hide, entry.own.frame)
		end
	else
		live[entry] = rec
		Place(entry)
		ns.TextStyle(entry.own.text, entry.textSpec)
		Fill({ rec = rec, entry = entry })
	end
	Drive()
end

local function BarTexts(rec, on)
	for _, entry in ipairs(rec.bars) do
		Settle(rec, entry, on)
	end
end

table.insert(X.after.final, { part = TEXT, fn = BarTexts })
