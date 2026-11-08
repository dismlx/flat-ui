local _, ns = ...

-- The rows and the per-icon looks of Cooldown icons, beside Cooldowns.lua, which lays the rows out and reads this file through ns.CooldownShared.
-- Show rules: each row has When it shows, Always (the default), In combat, Out of combat, In a group, In a dungeon or raid or Not mounted, asked as
-- Fading asks its When shown rules (Fade.lua:183-253) and as EnhanceQoL's panels ask their visibility rules (EnhanceQoL/EnhanceQoL.lua:880-884,
-- 904-928, 1290-1345; CooldownPanels.lua:26942-27267). A row the rule hides has no opacity and takes no mouse; Row opacity out of combat, Hide while
-- mounted and Hide in cities and inns still apply to every row.
-- Row of one icon puts an icon on row 2, 3 or 4, and When one icon shows makes one icon show As its row, Only on cooldown, Only when ready, or always
-- with a border in Border on cooldown colour while it cools down: two lists of one icon, as Sound of one icon is, saved per character in
-- FlatUICharDB.cooldownRowOf and FlatUICharDB.cooldownShowOf by the key of the icon's sound. They follow the per-entry hide on cooldown, show on
-- cooldown and border visibility of EnhanceQoL's Cooldown Panels (CooldownPanels.lua:8932-8941, 13490-13497, 29559-29576).
-- Glow when ready: a pulsing border of Flat UI's own round an icon from the end of its cooldown until it is used, as EnhanceQoL's ready glow stays
-- on until the cooldown runs again (CooldownPanels.lua:10679-10703, 26692-26760; its glow time is always 0, 28202-28203), in its gold
-- (CooldownPanels_Helper.lua:272-276). Glow on procs: while a proc alert of Trackers is up (Procs.lua starts and stops it through ns.ProcGlowStart and
-- ns.ProcGlowStop, which call ns.CooldownProcs), the icons of the spells it is for, every rank by name, show the game's proc loop art on a frame of
-- Flat UI's own over the icon, as EnhanceQoL glows an icon while its spell's proc is up (CooldownPanels.lua:8752-8756, 32945-32991); Forever has no
-- spell activation overlay of the game's (Procs.lua:5-7), so Flat UI's own proc alerts say when. Buff time on icons: while the buff a spell or a
-- trinket, gear or item gives is on you, a picture of the icon and a Cooldown of Flat UI's own over it show the time the buff has left with a
-- reverse sweep in Buff time colour at 55%, as EnhanceQoL's spell aura overlay covers its icon (CooldownPanels_AuraContainers.lua:1743-1926;
-- CooldownPanels.lua:10953-11075; CooldownPanels_Helper.lua:25, 340-341). It is read only while the game says the aura of that spell is not secret
-- (C_Secrets.ShouldSpellAuraBeSecret, SecretPredicateAPIDocumentation.lua:139-153): a buff the game hides shows nothing extra, and no value of an
-- aura is read that the game withholds (C_UnitAuras.GetPlayerAuraBySpellID and GetAuraDataBySpellName are SecretWhenUnitAuraRestricted:
-- UnitAuraDocumentation.lua:245-262, 397-412). A frame of this file hears UNIT_AURA for the player only while Buff time on icons is on and an icon has
-- a spell with a buff. These follow the Cooldown Panels of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission.
-- Every frame here is Flat UI's own, made, sized and levelled out of combat when the rows are laid out; in a fight only their alpha, their
-- animations, their Cooldown and Show and Hide change, which the game allows on frames that are not protected, as Cooldowns.lua's sweep and flash do.

local R = ns.CooldownShared
if type(R) ~= "table" then
	return
end
local KEY = R.KEY
local IsSecret = ns.IsSecret
local Opt, Ask, Field, Plain, Whole = R.Get, R.Ask, R.Field, R.Plain, R.Whole

-- MAX_ROWS: the rows. SHOWS: the choices of When one icon shows by their line, and what each is called. BACK: the line back to the icons.
-- GLOW_PART, AURA_PART: the parts of the module for /flatui status. PROC: the game's proc loop, a flipbook of 6 rows and 5 columns, 30 pictures in
-- a second, on a frame 1.4 times the size of its button (Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml:13 and 24,
-- ActionButtonSpellAlerts.lua:19-20). PULSE: the ready glow from full to 35% and back in half a second, 2 pixels wide. AURA_ALPHA: the opacity
-- of the buff time's sweep, EnhanceQoL's (CooldownPanels_Helper.lua:25). TRAVEL: a druid's travel, aquatic and flight form by GetShapeshiftFormID,
-- which count as mounted (Fade.lua:108-109). procs: by the id of a proc alert that is up, the IDs and the names of its spells. rowFor, showFor: the
-- icon whose row or show the list offers next. itemSpells: by item ID, its use spell and the spell's name, or false for an item without one.
local L = {
	MAX_ROWS = 4, BACK = -1,
	SHOWS = { [2] = "cooling", [3] = "ready", [4] = "border" },
	SAID = { cooling = "only on cooldown", ready = "only when ready", border = "border on cooldown" },
	GLOW_PART = "glows", AURA_PART = "buff time",
	PROC_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook", PROC_SCALE = 1.4, PROC_ROWS = 6, PROC_COLUMNS = 5, PROC_FRAMES = 30, PROC_TIME = 1,
	PULSE_TO = 0.35, PULSE_TIME = 0.5, GLOW_PX = 2, GOLD = { 1, 0.82, 0 },
	AURA_ALPHA = 0.55, UNKNOWN_ICON = 134400,
	TRAVEL = { [3] = true, [4] = true, [27] = true },
	procs = {}, rowFor = nil, showFor = nil, itemSpells = {}, pending = false, watching = false, playerOnly = false,
}

-- Show rules -------------------------------------------------------------------------------------------------------------------------

-- Each rule is true while its row is to show; Always is none. A withheld answer counts as the rule holding, so the row shows, and a call that
-- fails as the rule not holding, as in Fade.lua. In combat is the row's own (PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED, R.Fighting), so the
-- row shows before the lockdown, when its icons can still take the mouse (Cooldowns.lua, Tip.Mouse). In a group is IsInGroup, as the game's
-- group headers ask (Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua:268). In a dungeon or raid is IsInInstance and its kind, "party"
-- or "raid" (InstanceDocumentation.lua:170-178), as Chat.lua and MeterClear.lua ask it. Not mounted is IsMounted (PlayerScriptDocumentation.lua:
-- 1399-1406) and no travel form (GetShapeshiftFormID, Blizzard_SharedXMLBase/ModelSceneUtil.lua:23), as EnhanceQoL counts the travel form as a
-- mount (EnhanceQoL/EnhanceQoL.lua:880-884). None of these calls marks a return secret.
local RULES = {}

function RULES.combat()
	return R.Fighting() == true
end

function RULES.nocombat()
	return R.Fighting() ~= true
end

function RULES.group()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and (IsSecret(grouped) or grouped == true)
end

function RULES.dungeon()
	if type(IsInInstance) ~= "function" then
		return false
	end
	local ok, inside, kind = pcall(IsInInstance)
	if not ok then
		return false
	end
	if IsSecret(inside) or IsSecret(kind) then
		return true
	end
	return inside == true and (kind == "party" or kind == "raid")
end

function RULES.unmounted()
	if type(IsMounted) == "function" then
		local ok, mounted = pcall(IsMounted)
		if ok and not IsSecret(mounted) and mounted == true then
			return false
		end
	end
	if type(GetShapeshiftFormID) == "function" then
		local ok, form = pcall(GetShapeshiftFormID)
		if ok and ns.Finite(form) and L.TRAVEL[form] then
			return false
		end
	end
	return true
end

-- False while the Show rule of a row hides it (Idle in Cooldowns.lua writes the alpha).
function R.Shows(row)
	local rule = RULES[R.Opt(row, "show")]
	if rule == nil then
		return true
	end
	local ok, holds = pcall(rule)
	return ok and holds == true
end

-- True while a row that is on has a rule that an event of this file can change.
local function Ruled()
	for row = 1, L.MAX_ROWS do
		if R.RowOn(row) and RULES[R.Opt(row, "show")] then
			return true
		end
	end
	return false
end

-- Row of one icon and When one icon shows -------------------------------------------------------------------------------------------

-- A list of one icon per character (FlatUICharDB.cooldownRowOf, FlatUICharDB.cooldownShowOf), by the key of the icon's sound (Cooldowns.lua,
-- SoundKey: its spell, its kind, slot:N for a trinket or gear, item:ID). Nothing is saved for an icon on row 1 or shown as its row, and a table
-- goes with its last entry, as the sounds do.
local function Saved(name)
	local saved = ns.Character()
	local list = saved and saved[name]
	return type(list) == "table" and list or nil
end

local function Put(name, key, value)
	local saved = ns.Character()
	if not saved or key == nil then
		return
	end
	local list = saved[name]
	if type(list) ~= "table" then
		if value == nil then
			return
		end
		list = {}
		saved[name] = list
	end
	list[key] = value
	if next(list) == nil then
		saved[name] = nil
	end
end

-- The row Row of one icon gives an icon (2 to 4), or nil for row 1.
function R.Assigned(key)
	local list = Saved("cooldownRowOf")
	local row = list and key ~= nil and list[key] or nil
	if Plain(row, "number") and row >= 2 and row <= L.MAX_ROWS and row == math.floor(row) then
		return row
	end
	return nil
end

-- The row an entry of the list is laid out on; Layout puts it on row 1 while its own row is off.
function R.RowOf(entry)
	return R.Assigned(R.KeyOf(entry)) or 1
end

-- What When one icon shows gives an icon: "cooling", "ready", "border", or nil for As its row.
function R.ShowOf(record)
	local list = Saved("cooldownShowOf")
	local mode = list and list[R.KeyOf(record)] or nil
	if mode == "cooling" or mode == "ready" or mode == "border" then
		return mode
	end
	return nil
end

-- An icon taken off the list takes its row and its show with it.
function R.Forget(key)
	Put("cooldownRowOf", key, nil)
	Put("cooldownShowOf", key, nil)
end

-- ", row 2, only on cooldown" for an icon in /flatui cooldown list.
function R.Said(key)
	local text, row = "", R.Assigned(key)
	if row then
		text = (", row %d%s"):format(row, R.RowOn(row) and "" or " (off)")
	end
	local list = Saved("cooldownShowOf")
	local mode = list and list[key] or nil
	if L.SAID[mode] then
		text = text .. ", " .. L.SAID[mode]
	end
	return text
end

-- The icons of the list, and the one chosen first when it is still on the list.
local function Chosen(wanted)
	local rows, chosen = R.Entries(), nil
	for _, row in ipairs(rows) do
		if wanted ~= nil and row[3] == wanted then
			chosen = row
		end
	end
	return rows, chosen
end

-- Row of one icon is one list for two choices, made again each time it opens: the icons, each with its row when it is not row 1, and once one is
-- chosen, the four rows for it.
function ns.CooldownRowLines()
	local rows, chosen = Chosen(L.rowFor)
	local lines = {}
	if not chosen then
		L.rowFor = nil
		for _, row in ipairs(rows) do
			local at = R.Assigned(row[3])
			lines[#lines + 1] = { row[1], at and ("%s (row %d)"):format(row[2], at) or row[2] }
		end
		return lines
	end
	for row = 1, L.MAX_ROWS do
		lines[#lines + 1] = { row, ("%s: row %d%s"):format(chosen[2], row, R.RowOn(row) and "" or " (off)") }
	end
	lines[#lines + 1] = { L.BACK, "Another icon" }
	return lines
end

-- Works in combat and with the page off, as Sound of one icon does; the row changes at the next layout, when combat allows.
function ns.CooldownRowPick(id)
	local rows, chosen = Chosen(L.rowFor)
	if not chosen then
		L.rowFor = nil
		for _, row in ipairs(rows) do
			if row[1] == id then
				L.rowFor = row[3]
				return true, ("%s: open the list again to choose its row."):format(row[2])
			end
		end
		return false, "That icon is not on the row."
	end
	L.rowFor = nil
	if not (Plain(id, "number") and id >= 1 and id <= L.MAX_ROWS and id == math.floor(id)) then
		return true, nil
	end
	Put("cooldownRowOf", chosen[3], id > 1 and id or nil)
	R.QueueLayout()
	if R.RowOn(id) then
		return true, ("%s is on row %d."):format(chosen[2], id)
	end
	return true, ("%s is on row %d, which is off: until Show row %d is on (More rows), it is on row 1."):format(chosen[2], id, id)
end

-- When one icon shows is the same kind of list: the icons, each with its choice when it has one, and once one is chosen, the four choices.
function ns.CooldownShowLines()
	local rows, chosen = Chosen(L.showFor)
	local lines = {}
	local list = Saved("cooldownShowOf")
	if not chosen then
		L.showFor = nil
		for _, row in ipairs(rows) do
			local mode = list and list[row[3]] or nil
			lines[#lines + 1] = { row[1], L.SAID[mode] and ("%s (%s)"):format(row[2], L.SAID[mode]) or row[2] }
		end
		return lines
	end
	lines[1] = { 1, chosen[2] .. ": as its row" }
	for line = 2, 4 do
		lines[line] = { line, chosen[2] .. ": " .. L.SAID[L.SHOWS[line]] }
	end
	lines[#lines + 1] = { L.BACK, "Another icon" }
	return lines
end

-- The opacity changes at once, also in combat (Look in Cooldowns.lua); the frame of the border is made at the next layout.
function ns.CooldownShowPick(id)
	local rows, chosen = Chosen(L.showFor)
	if not chosen then
		L.showFor = nil
		for _, row in ipairs(rows) do
			if row[1] == id then
				L.showFor = row[3]
				return true, ("%s: open the list again to choose when it shows."):format(row[2])
			end
		end
		return false, "That icon is not on the row."
	end
	L.showFor = nil
	if id ~= 1 and not L.SHOWS[id] then
		return true, nil
	end
	local mode = L.SHOWS[id]
	Put("cooldownShowOf", chosen[3], mode)
	R.QueueLayout()
	if ns.Enabled(KEY) then
		R.UpdateAll()
	end
	if mode == nil then
		return true, ("%s shows as its row."):format(chosen[2])
	elseif mode == "border" then
		return true, ("%s has a border in Border on cooldown colour while it cools down."):format(chosen[2])
	end
	return true, ("%s shows %s."):format(chosen[2], L.SAID[mode])
end

-- The frames of an icon ---------------------------------------------------------------------------------------------------------------

-- An outline of Flat UI's own round a frame, its edges only (Core.lua, ns.Outline); a colour of its own keeps it drawn when Borderless is on.
local function Ring(frame, px)
	local outline = ns.Outline(frame, frame)
	ns.SetOutline(outline, true, false)
	if px then
		ns.SetOutlineThickness(outline, px)
	end
	return outline
end

local function Layer(parent)
	local frame = CreateFrame("Frame", nil, parent)
	ns.Own[frame] = true
	frame:SetAllPoints(parent)
	return frame
end

-- A ring that pulses: its frame's alpha goes from full to PULSE_TO and back, an animation of Flat UI's own frame (Cooldowns.lua's flash is one).
local function Pulse(parent)
	local holder = Layer(parent)
	holder:SetAlpha(0)
	local pulse = Layer(holder)
	local outline = Ring(pulse, L.GLOW_PX)
	local group = pulse:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(L.PULSE_TO)
	fade:SetDuration(L.PULSE_TIME)
	group:SetLooping("BOUNCE")
	return { frame = holder, outline = outline, group = group }
end

local function HasAtlas()
	if L.atlas == nil then
		local call = C_Texture and C_Texture.GetAtlasInfo
		local ok, info = false, nil
		if type(call) == "function" then
			ok, info = pcall(call, L.PROC_ATLAS)
		end
		L.atlas = ok and info ~= nil and not IsSecret(info)
	end
	return L.atlas
end

-- The proc glow: the game's proc loop on a frame of Flat UI's own 1.4 times the icon, played by a FlipBook animation of its own texture
-- (SimpleAnimFlipBookAPIDocumentation.lua; the game plays the same atlas so, ActionButtonSpellAlerts.xml:13 and 24). A client that has not the
-- atlas or the animation gets a gold ring that pulses in its place.
local function MakeProc(deco)
	local frame = CreateFrame("Frame", nil, deco)
	ns.Own[frame] = true
	frame:SetPoint("CENTER", deco, "CENTER", 0, 0)
	frame:Hide()
	local proc = { frame = frame, on = false }
	if HasAtlas() then
		local texture = frame:CreateTexture(nil, "ARTWORK")
		ns.Own[texture] = true
		texture:SetAllPoints(frame)
		if pcall(texture.SetAtlas, texture, L.PROC_ATLAS) then
			local ok = pcall(function()
				local group = texture:CreateAnimationGroup()
				local flip = group:CreateAnimation("FlipBook")
				flip:SetFlipBookRows(L.PROC_ROWS)
				flip:SetFlipBookColumns(L.PROC_COLUMNS)
				flip:SetFlipBookFrames(L.PROC_FRAMES)
				flip:SetFlipBookFrameWidth(0)
				flip:SetFlipBookFrameHeight(0)
				flip:SetDuration(L.PROC_TIME)
				group:SetLooping("REPEAT")
				proc.group = group
			end)
			if not ok then
				proc.group = nil
			end
		end
		if not proc.group then
			texture:Hide()
		end
	end
	if not proc.group then
		local ring = CreateFrame("Frame", nil, frame)
		ns.Own[ring] = true
		ring:SetAllPoints(deco)
		local outline = Ring(ring, L.GLOW_PX)
		ns.SetOutlineColour(outline, L.GOLD[1], L.GOLD[2], L.GOLD[3])
		local group = ring:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(L.PULSE_TO)
		fade:SetDuration(L.PULSE_TIME)
		group:SetLooping("BOUNCE")
		proc.group = group
	end
	return proc
end

-- The buff time: a picture of the icon, opaque over the icon and its sweep, and a Cooldown of Flat UI's own over the picture with a reverse sweep.
-- Its countdown has the size, colour, place and tenths of the row's (Cooldowns.lua, NumbersFont and Looks.Numbers, run on its own record look).
local function MakeAura(record)
	local frame = CreateFrame("Frame", nil, record.frame)
	ns.Own[frame] = true
	frame:SetAllPoints(record.frame)
	frame:Hide()
	local texture = frame:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	texture:SetAllPoints(frame)
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	ns.Own[cooldown] = true
	cooldown:SetAllPoints(frame)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetReverse(true)
	local aura = { frame = frame, texture = texture, cooldown = cooldown, look = { cooldown = cooldown } }
	-- The buff ran out between two readings.
	cooldown:SetScript("OnCooldownDone", function()
		aura.key = nil
		frame:Hide()
	end)
	return aura
end

-- The spell whose buff an icon shows: a spell icon's own, and an item's use (C_Item.GetItemSpell, ItemDocumentation.lua:970-985: its name, then
-- its ID), kept once the game has said; nothing for a potion or a healthstone, whose kinds give no buff. The name finds another rank.
local function AuraSpell(record)
	if record.kind then
		return nil
	end
	if record.spell then
		return record.spell, R.SpellName(record.spell)
	end
	local item = record.item
	if not Whole(item) then
		return nil
	end
	local known = L.itemSpells[item]
	if known == nil then
		local call = C_Item and C_Item.GetItemSpell
		if type(call) ~= "function" then
			return nil
		end
		local ok, name, id = pcall(call, item)
		if ok and Whole(id) then
			known = { id, Plain(name, "string") and name ~= "" and name or R.SpellName(id) }
			L.itemSpells[item] = known
		elseif ok and not IsSecret(id) and C_Item.IsItemDataCachedByID and Ask(C_Item.IsItemDataCachedByID, item) == true then
			known = false
			L.itemSpells[item] = false
		end
	end
	if known then
		return known[1], known[2]
	end
	return nil
end

-- The frames an icon needs now, made the first time and kept, then sized and levelled: Layout calls these out of combat for each icon of a row.
-- Over the icon's texts (record.top, at level t) the buff time at t + 1 and its Cooldown at t + 2, then the glows at t + 3: the interrupt border
-- of Interrupt.lua is at t + 1, outside the icon, and stays under the glows.
local function Decorate(record, size)
	local level = Ask(record.top.GetFrameLevel, record.top)
	level = Plain(level, "number") and level or 0
	local wantCool = R.ShowOf(record) == "border"
	local wantReady = Opt("readyGlow") == true
	local wantProc = Opt("procGlow") == true and record.spell ~= nil
	if (wantCool or wantReady or wantProc) and not record.deco then
		record.deco = Layer(record.frame)
	end
	local deco = record.deco
	if deco then
		deco:SetFrameLevel(level + 3)
	end
	if wantCool and not record.cool then
		local cool = Layer(deco)
		cool:SetAlpha(0)
		record.cool = { frame = cool, outline = Ring(cool) }
	end
	if record.cool then
		ns.SetOutlineColour(record.cool.outline, ns.Colour(KEY .. ".coolBorderColour"))
	end
	if wantReady and not record.ready then
		record.ready = Pulse(deco)
	end
	if record.ready then
		ns.SetOutlineColour(record.ready.outline, ns.Colour(KEY .. ".readyGlowColour"))
	end
	if wantProc and not record.proc then
		record.proc = MakeProc(deco)
	end
	if record.proc then
		record.proc.frame:SetSize(size * L.PROC_SCALE, size * L.PROC_SCALE)
	end
end

local function DecorateAura(record)
	local level = Ask(record.top.GetFrameLevel, record.top)
	level = Plain(level, "number") and level or 0
	if Opt("auraTime") == true and not record.aura and AuraSpell(record) then
		record.aura = MakeAura(record)
	end
	local aura = record.aura
	if aura then
		aura.frame:SetFrameLevel(level + 1)
		aura.cooldown:SetFrameLevel(level + 2)
		local r, g, b = ns.Colour(KEY .. ".auraColour")
		aura.cooldown:SetSwipeColor(r, g, b, L.AURA_ALPHA)
		aura.cooldown:SetHideCountdownNumbers(not Opt("numbers"))
		ns.EachPart(KEY, R.FONT_PART, R.NumbersFont, aura.look)
		ns.EachPart(KEY, R.NUMBERS_PART, R.Numbers, aura.look)
		local crop = R.Crop()
		aura.texture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		-- The icon may show another spell or item now: the next reading sets the buff again.
		aura.key = nil
	end
end

function R.Decorate(record, size)
	if not ns.PartStopped(KEY, L.GLOW_PART) then
		ns.EachPart(KEY, L.GLOW_PART, Decorate, record, size)
	end
	if not ns.PartStopped(KEY, L.AURA_PART) then
		ns.EachPart(KEY, L.AURA_PART, DecorateAura, record)
	end
end

-- The glows ---------------------------------------------------------------------------------------------------------------------------

-- Shows a frame of the glows while it is wanted and the icon is in its state: cooling for Border on cooldown, ready for the ready glow. A state the
-- game withholds goes to SetAlphaFromBoolean unread (SimpleFrameAPIDocumentation.lua:1145-1155), as the opacity of the icon does (Look). True while
-- the frame may show.
local function ByState(frame, wanted, onCooldown, cooling, secret, active)
	if not wanted then
		frame:SetAlpha(0)
		return false
	end
	if secret and frame.SetAlphaFromBoolean then
		if onCooldown then
			frame:SetAlphaFromBoolean(active, 1, 0)
		else
			frame:SetAlphaFromBoolean(active, 0, 1)
		end
		return true
	end
	local on = (cooling == true) == onCooldown
	frame:SetAlpha(on and 1 or 0)
	return on
end

-- A proc alert that is up and lights the spell of an icon: by the spell's ID or by its name, so every rank glows.
local function ProcUp(spellID)
	if next(L.procs) == nil then
		return false
	end
	local name = R.SpellName(spellID)
	for _, up in pairs(L.procs) do
		if up.ids[spellID] or (name and up.names[name]) then
			return true
		end
	end
	return false
end

local function Proc(record)
	local proc = record.proc
	if not proc then
		return
	end
	local on = Opt("procGlow") == true and ns.Enabled(KEY) and record.spell ~= nil and ProcUp(record.spell)
	if proc.on == on then
		return
	end
	proc.on = on
	if on then
		proc.frame:Show()
		proc.group:Play()
	else
		proc.group:Stop()
		proc.frame:Hide()
	end
end

-- Takes every glow of an icon away, for a part that stopped on errors.
local function Off(record)
	if record.cool then
		pcall(record.cool.frame.SetAlpha, record.cool.frame, 0)
	end
	if record.ready then
		pcall(record.ready.group.Stop, record.ready.group)
		pcall(record.ready.frame.SetAlpha, record.ready.frame, 0)
		record.ready.playing = nil
	end
	if record.proc then
		pcall(record.proc.group.Stop, record.proc.group)
		pcall(record.proc.frame.Hide, record.proc.frame)
		record.proc.on = false
	end
end

local function Glows(record, borderOn, cooling, secret, active)
	if record.cool then
		ByState(record.cool.frame, borderOn, true, cooling, secret, active)
	end
	local ready = record.ready
	if ready then
		local on = ByState(ready.frame, Opt("readyGlow") == true and not record.empty, false, cooling, secret, active)
		if ready.playing ~= on then
			ready.playing = on
			if on then
				ready.group:Play()
			else
				ready.group:Stop()
			end
		end
	end
end

-- Look in Cooldowns.lua runs this for every icon each time its state is drawn, also in a fight.
function R.Glows(record, borderOn, cooling, secret, active)
	if ns.PartStopped(KEY, L.GLOW_PART) then
		Off(record)
		return
	end
	ns.EachPart(KEY, L.GLOW_PART, Glows, record, borderOn, cooling, secret, active)
end

-- Procs.lua's alerts, through ProcGlow.lua: on is true when one starts and false when it ends. The alerts are kept whatever the page says, so the
-- glow is right as soon as the rows show; the icons on the screen take it now, in a fight too.
function ns.CooldownProcs(entry, on)
	if type(entry) ~= "table" or entry.id == nil then
		return
	end
	if on then
		local ids, names = {}, {}
		local lights = type(entry.lights) == "table" and entry.lights or {}
		for index = 1, math.min(#lights, 40) do
			local id = lights[index]
			if Whole(id) then
				ids[id] = true
				local name = R.SpellName(id)
				if name then
					names[name] = true
				end
			end
		end
		L.procs[entry.id] = { ids = ids, names = names }
	else
		L.procs[entry.id] = nil
	end
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, L.GLOW_PART) then
		return
	end
	for _, record in ipairs(R.Shown()) do
		if record.proc then
			ns.EachPart(KEY, L.GLOW_PART, Proc, record)
		end
	end
end

-- The buff time ------------------------------------------------------------------------------------------------------------------------

-- True while the game says an aura of the spell would not be secret (C_Secrets.ShouldSpellAuraBeSecret); without the call, out of combat, as
-- Trackers.lua asks (IsHidden).
local function Readable(id)
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldSpellAuraBeSecret
	if type(call) ~= "function" then
		return Ask(InCombatLockdown) == false
	end
	local ok, secret = pcall(call, id)
	return ok and not IsSecret(secret) and secret == false
end

-- True while auras are not secret in general (C_Secrets.ShouldAurasBeSecret, SecretPredicateAPIDocumentation.lua:119-127), for the reading by name.
local function Open()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) ~= "function" then
		return Ask(InCombatLockdown) == false
	end
	local ok, secret = pcall(call)
	return ok and not IsSecret(secret) and secret == false
end

-- When an aura ends, how long it lasts and how fast its time runs, from plain numbers alone; nothing for a buff with no end.
local function Times(aura)
	if IsSecret(aura) or type(aura) ~= "table" then
		return nil
	end
	local expires, length, rate = Field(aura, "expirationTime"), Field(aura, "duration"), Field(aura, "timeMod")
	if Plain(expires, "number") and Plain(length, "number") and expires > 0 and length > 0 then
		return expires, length, Plain(rate, "number") and rate > 0 and rate or 1
	end
	return nil
end

-- The buff of an icon's spell on the player: by the spell's ID (C_UnitAuras.GetPlayerAuraBySpellID), else by its name among the player's buffs
-- (GetAuraDataBySpellName with HELPFUL), as Trackers.lua reads a buff (ns.AuraReading).
local function Read(record)
	local id, name = AuraSpell(record)
	local units = C_UnitAuras
	if not id or type(units) ~= "table" or not Readable(id) then
		return nil
	end
	if type(units.GetPlayerAuraBySpellID) == "function" then
		local ok, aura = pcall(units.GetPlayerAuraBySpellID, id)
		if ok then
			local expires, length, rate = Times(aura)
			if expires then
				return expires, length, rate
			end
		end
	end
	if name and type(units.GetAuraDataBySpellName) == "function" and Open() then
		local ok, aura = pcall(units.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if ok then
			return Times(aura)
		end
	end
	return nil
end

-- The buff time of one icon: shown with the time left while its buff can be read, hidden otherwise. The Cooldown is set only when the buff changed.
local function Aura(record)
	local aura = record.aura
	if not aura then
		return
	end
	local expires, length, rate
	if Opt("auraTime") == true and ns.Enabled(KEY) and not record.empty then
		expires, length, rate = Read(record)
	end
	if not expires then
		if aura.key ~= nil or aura.frame:IsShown() then
			aura.key = nil
			aura.cooldown:Clear()
			aura.frame:Hide()
		end
		return
	end
	local key = ("%.3f:%.3f:%.3f"):format(expires, length, rate)
	if aura.key == key then
		return
	end
	aura.key = key
	aura.texture:SetTexture(record.picture or L.UNKNOWN_ICON)
	local cooldown = aura.cooldown
	if cooldown.SetCooldownFromExpirationTime then
		cooldown:SetCooldownFromExpirationTime(expires, length, rate)
	else
		cooldown:SetCooldown(expires - length, length, rate)
	end
	aura.frame:Show()
	cooldown:Show()
end

local function AuraAll()
	if ns.PartStopped(KEY, L.AURA_PART) then
		for _, record in ipairs(R.Shown()) do
			if record.aura then
				pcall(record.aura.frame.Hide, record.aura.frame)
			end
		end
		return
	end
	for _, record in ipairs(R.Shown()) do
		if record.aura then
			ns.EachPart(KEY, L.AURA_PART, Aura, record)
		end
	end
end

-- UNIT_AURA comes often in a fight: the icons are read once on the next frame however many come.
local function Soon()
	if L.pending then
		return
	end
	L.pending = true
	local function Run()
		L.pending = false
		if ns.Enabled(KEY) and not ns.IsStopped(KEY) then
			ns.Try(KEY, AuraAll)
		end
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(0, Run)
	else
		Run()
	end
end

-- The frame that hears the player's UNIT_AURA, only while an icon shows buff time (RegisterUnitEvent for the player, as Defensives.lua hears it;
-- every unit's, read for the player alone, on a client without it).
local function Watch()
	local want = false
	if ns.Enabled(KEY) and Opt("auraTime") == true and not ns.PartStopped(KEY, L.AURA_PART) then
		for _, record in ipairs(R.Shown()) do
			want = want or record.aura ~= nil
		end
	end
	if want == L.watching then
		return
	end
	if not L.listener then
		local frame = CreateFrame("Frame")
		ns.Own[frame] = true
		frame:SetScript("OnEvent", function(_, _, unit)
			if L.playerOnly or (not IsSecret(unit) and unit == "player") then
				Soon()
			end
		end)
		L.listener = frame
	end
	local frame = L.listener
	if want then
		L.playerOnly = frame.RegisterUnitEvent ~= nil and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
		if not L.playerOnly then
			pcall(frame.RegisterEvent, frame, "UNIT_AURA")
		end
	else
		pcall(frame.UnregisterEvent, frame, "UNIT_AURA")
	end
	L.watching = want
end

-- After each layout of the rows: the proc glow and the buff time of the icons as they are now.
function R.AfterLayout()
	if not ns.PartStopped(KEY, L.GLOW_PART) then
		for _, record in ipairs(R.Shown()) do
			if record.proc then
				ns.EachPart(KEY, L.GLOW_PART, Proc, record)
			end
		end
	end
	Watch()
	AuraAll()
end

-- The events: the rules of a group, an instance and a travel form change with these, and a fight can make a buff secret or plain again.
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "ZONE_CHANGED_NEW_AREA", "UPDATE_SHAPESHIFT_FORM" }) do
	ns.AddEvent(KEY, event, function()
		R.Idle()
	end, Ruled)
end
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	ns.AddEvent(KEY, event, Soon, function()
		return Opt("auraTime") == true
	end)
end

-- /flatui status: the rows that are on, a row its rule hides now, and how many proc alerts and buffs show.
ns.AddStatus(KEY, function()
	local lines = {}
	if R.hidden[1] then
		lines[#lines + 1] = "Row 1: hidden now by When the row shows."
	end
	for row = 2, L.MAX_ROWS do
		if R.RowOn(row) then
			local count = #(R.shownOf[row] or {})
			lines[#lines + 1] = ("Row %d: %d %s%s."):format(row, count, count == 1 and "icon" or "icons", R.hidden[row] and ", hidden now by When it shows" or "")
		end
	end
	if Opt("procGlow") == true then
		local count = 0
		for _ in pairs(L.procs) do
			count = count + 1
		end
		lines[#lines + 1] = ("Glow on procs: %d proc %s up."):format(count, count == 1 and "alert" or "alerts")
	end
	if Opt("auraTime") == true then
		local count = 0
		for _, record in ipairs(R.Shown()) do
			if record.aura and record.aura.key ~= nil then
				count = count + 1
			end
		end
		lines[#lines + 1] = ("Buff time on icons: %d %s now."):format(count, count == 1 and "buff" or "buffs")
	end
	return lines
end)
