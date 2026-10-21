local ADDON_NAME, ns = ...

-- The text rows of the Unit frames pages: the font, size, outline and colour of the name, the Name switch of each frame, and the font, outline and colour of the
-- words on the health and power bars. The sizes of the bar text and of the name on small frames are in UnitFrames.lua, which asks this file for the rest of each
-- font call (ns.UnitFrameExtra.nameSpec and barSpec), so that a font is set once. This file adds its work after the steps of that file through
-- ns.UnitFrameExtra: a part that stops on errors counts as off here, and every function can run twice with the same result. A row at its default makes no call.
-- The level rows are not here: Level colour and Level size are in UnitFrames.lua. The health and power text rows are at the end of this file.

local X = ns.UnitFrameExtra
local KEY = "unitframes"
local PART = "Text style"
-- The flags of each outline row choice. "game" is not here: the game's flags stay.
local FLAGS = { none = "", thin = "OUTLINE", thick = "OUTLINE, THICK" }
-- The Name switch of each kind of frame, and the lines of /flatui status for a font call the client refused.
local SWITCH = { player = "playerName", target = "targetName", focus = "focusName", pet = "petName", tot = "totName", party = "partyName", partypet = "partyName",
	boss = "bossName" }
local NOTE = { names = "Text style: the client refused a name font or outline", bars = "Text style: the client refused a bar text font or outline",
	nameFace = "Text style: the client does not load the Name font, so names keep the game's font",
	barFace = "Text style: the client does not load the Bar text font, so bar text keeps the game's font" }
-- Per slot, the frames whose last font call was refused, each with the parts of it that were: "name", or the role of a bar.
local refusals = { names = setmetatable({}, { __mode = "k" }), bars = setmetatable({}, { __mode = "k" }) }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The font file of a face row, or nil for the game's font. The client is asked which faces it loads only when a row names one; a face it does not load
-- leaves the game's font and says so on the status.
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

-- The line for a slot is on the status while one frame has it.
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

-- Names -------------------------------------------------------------------------------------------------------

-- The colour the name asks for on this frame: red, green and blue, or nil for the game's own. Class is the class colour of a player and the reaction colour of any
-- other unit, as Health bar colour has it; the game's colour stays while the client withholds what decides it.
local function NameColour(rec)
	local mode = Opt("nameColour")
	if mode == "custom" then
		return ns.Colour(KEY .. ".nameCustom")
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
		return ns.ReactionColour(unit)
	elseif mode == "reaction" then
		return ns.ReactionColour(unit)
	end
	return nil
end

-- Adds the name rows to a font call whose size is spec.percent: the face, the outline flags, the size in percent and the colour. True when it added anything.
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

-- The name rows for the game's name text on a frame without a name row. spec is the call UnitFrames.lua makes for the size alone.
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

-- The game's name text on a frame without a name row, for the frames that UnitFrames.lua does not size: a large frame or a boss frame. A small frame has its
-- call made there, and the same call again here changes nothing.
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

-- The name of the row: the same rows, set on the row's font string, after the game's font and colour were copied. The level takes the colour of the name when
-- Level colour says so.
local function RowName(rec)
	local row = rec.row
	if row == nil or not X.rowOn(rec) then
		return
	end
	Cleared(rec, "names", "name")
	local live = not Off()
	local spec = { percent = 100 }
	local styled = live and NameLook(rec, spec)
	-- The colour is set on the string itself, after the call: the row copies the game's colour with each write, and a colour kept by the font call would put
	-- an old colour back over White names.
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

-- The Name switch: the row's name is hidden, or the game's name text is transparent. The game's name text is shown again when the switch is on.
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

-- A new unit on a frame: the colour of the name follows the unit. The frame with a name row has its name written again by the game's call.
local was = X.unitChanged
function X.unitChanged(rec)
	if was ~= nil then
		was(rec)
	end
	if rec.made and rec.kind ~= "raid" and X.active(rec) then
		X.run(PART, NameText, rec, true)
	end
end

-- The group or the standing of units changed: every frame's name colour is looked at again.
local wasAll = X.unitsChanged
function X.unitsChanged()
	if wasAll ~= nil then
		wasAll()
	end
	for _, rec in pairs(X.records) do
		if rec.made and rec.kind ~= "raid" and X.active(rec) then
			X.run(PART, NameText, rec, true)
			if rec.row ~= nil and X.rowOn(rec) then
				X.run(PART, RowName, rec)
			end
		end
	end
end

-- Bar text ----------------------------------------------------------------------------------------------------

-- The bar text rows added to the font call for one bar of a frame: the face, the outline and the colour. True when it added anything.
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

table.insert(X.after.rowText, { part = PART, fn = RowName })
-- A large frame or a boss frame whose name row came back: the game's name text goes back to the face, size and colour it had before the rows set them under the row.
local function Restore(rec, on)
	if rec.parts.nameText ~= nil and X.rowOn(rec) and (X.large[rec.kind] or rec.kind == "boss") then
		Cleared(rec, "names", "name")
		ns.TextStyle(rec.parts.nameText, {})
	end
end

table.insert(X.after.apply, { part = PART, fn = Restore })
table.insert(X.after.final, { part = PART, fn = Final })

-- Health and power text -------------------------------------------------------------------------------------------

-- A format other than the game's makes the game's words on that bar transparent and puts one font string of this file's over the bar. The game only calls
-- SetText, Show and Hide on its words (TextStatusBar.lua:101-215). Every 0.1 s, and only while a bar has a format, the values go to the string without being
-- read, compared or added: they stay withheld values from the call that gets them to the call that writes them. The part is "health and power text": three
-- calls the client refuses switch it off, and the game's words come back.
local TEXT = "health and power text"
local HEALTH_KEY = { player = "player", target = "target", focus = "focus", pet = "pet", party = "party", partypet = "party", boss = "boss" }
local POWER_KEY = { player = "player", target = "target", focus = "focus", pet = "pet", party = "party", partypet = "party" }
local ANCHOR = { left = "LEFT", centre = "CENTER", right = "RIGHT" }
local OFFSET = { left = 3, centre = 0, right = -3 }
local NOTE_MADE = "Health and power text: the client did not make the text, so the game's words stay"
-- The calls for each kind of bar: what the game's own text shows, as the documentation lists them (UnitDocumentation.lua).
local FROM = {
	health = { cur = function(unit) return UnitHealth(unit) end, max = function(unit) return UnitHealthMax(unit) end,
		pct = function(unit) return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) end, miss = function(unit) return UnitHealthMissing(unit) end },
	power = { cur = function(unit) return UnitPower(unit) end, max = function(unit) return UnitPowerMax(unit) end,
		pct = function(unit) return UnitPowerPercent(unit, nil, false, CurveConstants.ScaleTo100) end, miss = function(unit) return UnitPowerMissing(unit) end },
}
-- The bars with a format, each with its frame, and the driver that fills them.
local live, todo, ticker = {}, {}, { waited = 0 }

-- The format of one bar: "game", "hide", or the format to write. A frame that is off, a part that stopped and a kind of frame without the row give the game's.
local function Mode(rec, entry, on)
	local keys = entry.role == "health" and HEALTH_KEY or POWER_KEY
	if not on or ns.PartStopped(KEY, TEXT) or keys[rec.kind] == nil then
		return "game"
	end
	local mode = Opt(keys[rec.kind] .. (entry.role == "health" and "HealthText" or "PowerText"))
	if mode == "game" or mode == nil then
		return "game"
	elseif entry.textFaded then
		-- No text on the power bar says the words are gone, whatever the format.
		return "hide"
	end
	return mode
end

-- 12.3k or 12,345, by Number style. The value goes through as it came.
local function Num(value)
	local call = Opt("numberStyle") == "full" and BreakUpLargeNumbers or AbbreviateNumbers or BreakUpLargeNumbers
	return call(value)
end

-- The formats of the words on a bar, in one table that the drawings of the setup (SetupDrawUnits.lua) write their words with too.
X.formats = { curmax = "%s / %s", pct = "%.0f%%", curpct = "%s (%.0f%%)" }

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
		text:SetText(C_StringUtil.TruncateWhenZero(from.miss(unit)))
	end
end

-- True when the client says so plainly: a withheld answer is no.
local function Yes(ok, value)
	return ok and not ns.IsSecret(value) and value == true
end

local function Blank(own)
	if not own.blank then
		own.blank = true
		pcall(own.text.SetText, own.text, "")
	end
end

-- The game's words on a bar come back, and the string of this file is empty and hidden.
local function Release(rec, entry)
	live[entry] = nil
	local own = entry.own
	if own ~= nil then
		Blank(own)
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

-- The frame and the string over a bar, made out of combat.
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

-- One write of one bar. job is { rec, entry }, new for each call, so that each refused call counts as a failure of its own.
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
	local present = unit ~= nil and Yes(pcall(UnitExists, unit)) and not Yes(pcall(UnitIsDeadOrGhost, unit))
	if present and Opt("ownTextWhen") == "hover" then
		present = Yes(pcall(rec.frame.IsMouseOver, rec.frame))
	end
	if not present then
		Blank(own)
		return
	end
	own.blank = false
	pcall(own.frame.Show, own.frame)
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

-- The driver runs only while a bar has a format.
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

-- The format of one bar: its game words and its own string, the place and the font. Out of combat the string is made; in combat the game's words stay until it is.
local function Settle(rec, entry, on)
	local mode = Mode(rec, entry, on)
	if mode == "game" then
		Release(rec, entry)
		Drive()
		return
	end
	if mode ~= "hide" and entry.own == nil then
		if InCombatLockdown() then
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
			Blank(entry.own)
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
