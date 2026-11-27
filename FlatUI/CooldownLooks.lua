local _, ns = ...

local R = ns.CooldownShared
if type(R) ~= "table" then
	return
end
local KEY = R.KEY
local IsSecret = ns.IsSecret
local Opt, Ask, Field, Plain, Whole = R.Get, R.Ask, R.Field, R.Plain, R.Whole

local L = {
	MAX_ROWS = 4, BACK = -1,
	SHOWS = { [2] = "cooling", [3] = "ready", [4] = "border" },
	SAID = { cooling = "only on cooldown", ready = "only when ready", border = "border on cooldown" },
	GLOW_PART = "glows", AURA_PART = "buff time",
	PROC_ATLAS = "UI-HUD-ActionBar-Proc-Loop-Flipbook", PROC_SCALE = 1.4, PROC_ROWS = 6, PROC_COLUMNS = 5, PROC_FRAMES = 30, PROC_TIME = 1,
	PULSE_TO = 0.35, PULSE_TIME = 0.5, GLOW_PX = 2, GOLD = { 1, 0.82, 0 }, SOFT_LOW = 0.25, SOFT_HIGH = 0.6, SOFT_TIME = 1.2,
	AURA_ALPHA = 0.55, UNKNOWN_ICON = 134400,
	TRAVEL = { [3] = true, [4] = true, [27] = true },
	procs = {}, rowFor = nil, showFor = nil, itemSpells = {}, pending = false, watching = false, playerOnly = false,
}

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

function R.Shows(row)
	if R.Testing() then
		return true
	end
	local rule = RULES[R.Opt(row, "show")]
	if rule == nil then
		return true
	end
	local ok, holds = pcall(rule)
	return ok and holds == true
end

local function Ruled()
	for row = 1, L.MAX_ROWS do
		if R.RowOn(row) and RULES[R.Opt(row, "show")] then
			return true
		end
	end
	return false
end

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

function R.Assigned(key)
	local list = Saved("cooldownRowOf")
	local row = list and key ~= nil and list[key] or nil
	if Plain(row, "number") and row >= 2 and row <= L.MAX_ROWS and row == math.floor(row) then
		return row
	end
	return nil
end

function R.RowOf(entry)
	return R.Assigned(R.KeyOf(entry)) or 1
end

function R.ShowOf(record)
	if R.Testing() then
		return nil
	end
	local list = Saved("cooldownShowOf")
	local mode = list and list[R.KeyOf(record)] or nil
	if mode == "cooling" or mode == "ready" or mode == "border" then
		return mode
	end
	return nil
end

function R.Forget(key)
	Put("cooldownRowOf", key, nil)
	Put("cooldownShowOf", key, nil)
end

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

local function Chosen(wanted)
	local rows, chosen = R.Entries(), nil
	for _, row in ipairs(rows) do
		if wanted ~= nil and row[3] == wanted then
			chosen = row
		end
	end
	return rows, chosen
end

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
	return true, ("%s is on row %d, which is off: until Show row %d is on (Rows 2 to 4), it is on row 1."):format(chosen[2], id, id)
end

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
				proc.game = group
			end)
			if not ok then
				proc.game = nil
			end
		end
		texture:Hide()
		proc.texture = proc.game and texture or nil
	end
	local ring = CreateFrame("Frame", nil, frame)
	ns.Own[ring] = true
	ring:SetAllPoints(deco)
	ring:Hide()
	local outline = Ring(ring, L.GLOW_PX)
	ns.SetOutlineColour(outline, L.GOLD[1], L.GOLD[2], L.GOLD[3])
	local group = ring:CreateAnimationGroup()
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(L.SOFT_LOW)
	fade:SetToAlpha(L.SOFT_HIGH)
	fade:SetDuration(L.SOFT_TIME)
	fade:SetSmoothing("IN_OUT")
	group:SetLooping("BOUNCE")
	proc.ring, proc.soft = ring, group
	return proc
end

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
	cooldown:SetScript("OnCooldownDone", function()
		aura.key = nil
		frame:Hide()
	end)
	return aura
end

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

local function Decorate(record, size)
	local level = Ask(record.top.GetFrameLevel, record.top)
	level = Plain(level, "number") and level or 0
	local wantCool = R.ShowOf(record) == "border"
	local wantReady = Opt("readyGlow") == true
	local wantProc = Opt("procGlow") == true and (record.spell ~= nil or record.sample == 3)
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
	if Opt("auraTime") == true and not record.aura and (record.sample == 2 or AuraSpell(record)) then
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

local function ProcLook(proc)
	return proc.game and ns.Get("trackers.glowStyle") == "game" and "game" or "soft"
end

local function Proc(record)
	local proc = record.proc
	if not proc then
		return
	end
	local on = Opt("procGlow") == true and ns.Enabled(KEY)
		and ((record.held ~= nil and record.sample == 3) or (record.spell ~= nil and ProcUp(record.spell)))
	local look = on and ProcLook(proc) or false
	if proc.look == look then
		return
	end
	proc.on, proc.look = on, look
	if proc.game then
		if look == "game" then
			proc.texture:Show()
			proc.game:Play()
		else
			proc.game:Stop()
			proc.texture:Hide()
		end
	end
	if look == "soft" then
		proc.ring:Show()
		proc.soft:Play()
	else
		if look == "game" then
			proc.soft:Stop()
		else
			proc.soft:Pause()
		end
		proc.ring:Hide()
	end
	proc.frame:SetShown(look ~= false)
end

local function Off(record)
	if record.cool then
		pcall(record.cool.frame.SetAlpha, record.cool.frame, 0)
	end
	if record.ready then
		pcall(record.ready.group.Stop, record.ready.group)
		pcall(record.ready.frame.SetAlpha, record.ready.frame, 0)
		record.ready.playing = nil
	end
	local proc = record.proc
	if proc then
		if proc.game then
			pcall(proc.game.Stop, proc.game)
		end
		pcall(proc.soft.Stop, proc.soft)
		pcall(proc.frame.Hide, proc.frame)
		proc.on, proc.look = false, false
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

function R.Glows(record, borderOn, cooling, secret, active)
	if ns.PartStopped(KEY, L.GLOW_PART) then
		Off(record)
		return
	end
	ns.EachPart(KEY, L.GLOW_PART, Glows, record, borderOn, cooling, secret, active)
end

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
	ns.CooldownProcLook()
end

function ns.CooldownProcLook()
	if not ns.Enabled(KEY) or ns.PartStopped(KEY, L.GLOW_PART) then
		return
	end
	for _, record in ipairs(R.Shown()) do
		if record.proc then
			ns.EachPart(KEY, L.GLOW_PART, Proc, record)
		end
	end
end

local function Readable(id)
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldSpellAuraBeSecret
	if type(call) ~= "function" then
		return Ask(InCombatLockdown) == false
	end
	local ok, secret = pcall(call, id)
	return ok and not IsSecret(secret) and secret == false
end

local function Open()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret
	if type(call) ~= "function" then
		return Ask(InCombatLockdown) == false
	end
	local ok, secret = pcall(call)
	return ok and not IsSecret(secret) and secret == false
end

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

local function Aura(record)
	local aura = record.aura
	if not aura or (record.sample and record.held) then
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

local H = { READY = 1.5, PX = 2, PREVIEW = 4, AURA = 12, AURA_LEFT = 8, interrupts = nil, preview = nil, token = 0 }

function H.Aura(record, held, now)
	local aura = record.aura
	if not aura then
		return
	end
	if record.sample ~= 2 or Opt("auraTime") ~= true or ns.PartStopped(KEY, L.AURA_PART) then
		held.aura = nil
		if aura.key ~= nil or aura.frame:IsShown() then
			aura.key = nil
			aura.cooldown:Clear()
			aura.frame:Hide()
		end
		return
	end
	if not held.aura or now >= held.aura then
		held.aura = now + H.AURA_LEFT
	end
	local key = "sample:" .. held.aura
	if aura.key == key then
		return
	end
	aura.key = key
	aura.texture:SetTexture(record.picture or L.UNKNOWN_ICON)
	aura.cooldown:SetCooldown(held.aura - H.AURA, H.AURA)
	aura.frame:Show()
	aura.cooldown:Show()
end

function H.Proc(record)
	if record.proc and not ns.PartStopped(KEY, L.GLOW_PART) then
		ns.EachPart(KEY, L.GLOW_PART, Proc, record)
	end
end

local function TestOn()
	local test = ns.TestMode
	return type(test) == "table" and test.IsOn() == true
end

local function Epoch()
	if TestOn() then
		return ns.TestMode.Epoch()
	end
	return "p" .. (H.preview and H.preview.token or 0)
end

function R.Testing()
	if not ns.Enabled(KEY) or InCombatLockdown() then
		return false
	end
	return TestOn() or (H.preview ~= nil and GetTime() < H.preview.ends)
end

local function Forget()
	for _, record in ipairs(R.Shown()) do
		if record.held then
			record.dimmed, record.readyPlayed = nil, nil
		end
	end
end

local function PreviewEnd()
	if not H.preview then
		return
	end
	Forget()
	H.preview = nil
	ns.RefreshModule(KEY)
end

function ns.CooldownLookChanged()
	if not InCombatLockdown() and ns.Enabled(KEY) and type(ns.PanelShown) == "function" and ns.PanelShown() and not TestOn()
		and C_Timer ~= nil and C_Timer.After ~= nil then
		local now = GetTime()
		if not (H.preview and now < H.preview.ends) then
			for _, record in ipairs(R.Shown()) do
				record.dimmed, record.readyPlayed = nil, nil
			end
			H.token = H.token + 1
			H.preview = { token = H.token }
		end
		H.preview.ends = now + H.PREVIEW
		C_Timer.After(H.PREVIEW + 0.05, function()
			if H.preview and GetTime() >= H.preview.ends then
				local ok, err = pcall(PreviewEnd)
				if not ok then
					geterrorhandler()(err)
				end
			end
		end)
	end
	ns.RefreshModule(KEY)
end

function R.Samples(lists)
	if not R.Testing() then
		return
	end
	for row = 1, L.MAX_ROWS do
		if lists[row] and #lists[row] == 0 and R.RowOn(row) then
			lists[row] = { { sample = 1 }, { sample = 2 }, { sample = 3 } }
		end
	end
end

local function Interrupts()
	if H.interrupts then
		return H.interrupts
	end
	local class, data, byClass, kind = Ask(UnitClassBase, "player"), ns.ABILITIES, ns.ABILITIES_BY_CLASS, nil
	for index, name in ipairs(type(ns.COOLDOWN_KINDS) == "table" and ns.COOLDOWN_KINDS or {}) do
		if name == "interrupt" then
			kind = index
		end
	end
	if not Plain(class, "string") or type(data) ~= "table" or type(byClass) ~= "table" or kind == nil then
		return nil
	end
	local set = { ids = {}, names = {} }
	for _, index in ipairs(type(byClass[class]) == "table" and byClass[class] or {}) do
		local a = data[index]
		if type(a) == "table" and a.kind == kind and type(a.casts) == "table" then
			for _, id in ipairs(a.casts) do
				set.ids[id] = true
				local name = R.SpellName(id)
				if name then
					set.names[name] = true
				end
			end
		end
	end
	H.interrupts = set
	return set
end

local function Border(record, on)
	local ring = record.heldRing
	if on and not ring then
		ring = Layer(record.frame)
		local level = Ask(record.top.GetFrameLevel, record.top)
		ring:SetFrameLevel((Plain(level, "number") and level or 0) + 1)
		local outline = Ring(ring, H.PX)
		ns.SetOutlineColour(outline, L.GOLD[1], L.GOLD[2], L.GOLD[3])
		record.heldRing = ring
	end
	if ring then
		ring:SetShown(on == true)
	end
end

local function IsInterrupt(spell)
	local set = spell and ns.Get(KEY .. ".interruptGlow") == true and Interrupts() or nil
	if not set then
		return false
	end
	local name = R.SpellName(spell)
	return set.ids[spell] == true or (name ~= nil and set.names[name] == true)
end

function R.Held(record)
	if not R.Testing() then
		if record.held then
			record.held = nil
			Border(record, false)
			if record.sample then
				H.Proc(record)
			end
		end
		return false
	end
	local index = 1
	for position, other in ipairs(R.Shown()) do
		if other == record then
			index = position
			break
		end
	end
	local epoch, now = Epoch(), GetTime()
	local held = record.held
	if not held or held.epoch ~= epoch or held.index ~= index then
		local seconds = 6 + ((index - 1) * 3) % 10
		held = { epoch = epoch, index = index, seconds = seconds, start = now - ((index - 1) * 2) % seconds, ready = index == 1 }
		record.held = held
	end
	local cooling = not held.ready and now < held.start + held.seconds
	local cooldown = record.cooldown
	if cooling and held.drawn ~= held.start then
		held.drawn = held.start
		pcall(cooldown.SetCooldown, cooldown, held.start, held.seconds)
	elseif not cooling and held.drawn ~= false then
		held.drawn = false
		pcall(cooldown.Clear, cooldown)
	end
	if record.sample then
		record.count:SetText(record.sample == 3 and Opt("useCount") == true and "5" or "")
		H.Aura(record, held, now)
		H.Proc(record)
	end
	R.Look(record, cooling, false, nil)
	Border(record, IsInterrupt(record.spell))
	return true
end

function H.Tick(now)
	if not R.Testing() then
		return
	end
	local due = false
	for _, record in ipairs(R.Shown()) do
		local held = record.held
		if held and held.aura and now >= held.aura then
			due = true
		end
		if held and not held.ready then
			local ends = held.start + held.seconds
			if now >= ends + H.READY then
				held.start = now
				due = true
			elseif now >= ends and held.drawn ~= false then
				due = true
			end
		end
	end
	if due then
		R.UpdateAll()
	end
end

ns.TestMode.Register(KEY, {
	module = KEY,
	label = "Cooldown icons",
	refresh = true,
	every = 0.5,
	Tick = H.Tick,
})
ns.TestMode.Watch(function(on)
	if on and H.preview then
		Forget()
		H.preview = nil
	end
end)
ns.AddEvent(KEY, "PLAYER_REGEN_DISABLED", PreviewEnd, function()
	return H.preview ~= nil
end)

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
