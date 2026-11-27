local _, ns = ...

local KEY = "charges"
local MOVER = "FlatUICharges"
local SPOT_Y = -100
local REREAD, EARLY, FRESH = 0.05, 0.3, 0.5
local TEST_TIME, PREVIEW = 8, 7
local DEFAULT_TOP, MOST_TOP = 3, 99
local MOST_ADDED, MAX_ID = 40, 2147483647
local SAMPLE_ID, SAMPLE_ICON = 324, "Interface\\Icons\\Spell_Nature_LightningShield"
local SAMPLE_STEPS = { { 2, 3 }, { 4, 2 }, { 6, 1 }, { 6.6, 0 } }
local SAMPLE_LENGTH = 600
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
local FAMILIES = {
	{ key = "lightning", class = "SHAMAN", rgb = { 0.35, 0.72, 1 }, ids = { 324, 325, 905, 945, 8134, 10431, 10432 }, name = "Lightning Shield" },
	{ key = "water", class = "SHAMAN", rgb = { 0.2, 0.84, 0.7 }, ids = { 408510 }, name = "Water Shield" },
	{ key = "earth", rgb = { 0.56, 0.72, 0.3 }, ids = { 974, 408514 }, name = "Earth Shield" },
	{ key = "innerfire", class = "PRIEST", rgb = { 1, 0.8, 0.28 }, ids = { 588, 7128, 602, 1006, 10951, 10952 }, name = "Inner Fire" },
	{ key = "shadowguard", class = "PRIEST", rgb = { 0.68, 0.42, 1 }, ids = { 18137, 19308, 19309, 19310, 19311, 19312 }, name = "Shadowguard" },
	{ key = "holyshield", class = "PALADIN", rgb = { 1, 0.93, 0.72 }, ids = { 20925, 20927, 20928, 1239570 }, name = "Holy Shield" },
}
local HELP = {
	"/flatui charges - a sample of Charges for a few seconds, out of combat",
	"/flatui charges add Lightning Shield - a buff on you with charges, by name, spell ID or shift-clicked spell",
	"/flatui charges remove Lightning Shield - takes a spell off Charges",
	"/flatui charges list",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local Ask = T.Ask
local L = ns.ChargesLook
local Opt = L.Opt
local C = { displays = {}, shown = {}, top = {} }
local BUILT = {}
for index, family in ipairs(FAMILIES) do
	family.order = index
	BUILT[family.key] = family
	for _, id in ipairs(family.ids) do
		BUILT[id] = family
	end
end
C.BUILT, C.FAMILIES = BUILT, FAMILIES

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function SpellName(id)
	local name = Ask(C_Spell and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

local function SpellIcon(id)
	local file = Ask(C_Spell and C_Spell.GetSpellTexture, id)
	return (Plain(file, "number") or Plain(file, "string")) and file or nil
end

local function Name(id)
	local family = BUILT[id]
	return SpellName(id) or (family and family.name) or ("Spell " .. id)
end

function C.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.charges
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.charges = saved
	end
	for _, key in ipairs({ "added", "removed" }) do
		local old, map = saved[key], {}
		for id, yes in pairs(type(old) == "table" and old or {}) do
			if Whole(id) and yes == true then
				map[id] = true
			end
		end
		saved[key] = map
	end
	if type(saved.top) ~= "table" then
		saved.top = {}
	end
	return saved
end

function C.Class()
	local class = Ask(UnitClassBase, "player")
	return Plain(class, "string") and class or nil
end

function C.Mine(family)
	return family.class == nil or family.class == C.Class()
end

function C.Families()
	if C.list then
		return C.list
	end
	local list, byId, saved = {}, {}, C.Saved()
	local removed, added = saved and saved.removed or {}, saved and saved.added or {}
	for _, family in ipairs(FAMILIES) do
		if C.Mine(family) and not removed[family.ids[1]] then
			list[#list + 1] = family
		end
	end
	local extra = {}
	for id in pairs(added) do
		if not BUILT[id] then
			extra[#extra + 1] = id
		end
	end
	table.sort(extra)
	for index, id in ipairs(extra) do
		list[#list + 1] = { key = "a" .. id, ids = { id }, order = #FAMILIES + index, name = Name(id) }
	end
	for _, family in ipairs(list) do
		for _, id in ipairs(family.ids) do
			byId[id] = family
		end
	end
	C.byId = byId
	C.list = C.Class() and list or nil
	return list
end

function C.ListsChanged()
	C.list, C.byId = nil, nil
	ns.Try(KEY, C.Refresh)
end

local function Rows(add)
	local rows = {}
	for _, family in ipairs(FAMILIES) do
		local listed = C.Families() and C.byId[family.ids[1]] ~= nil
		if C.Mine(family) and listed ~= add then
			local id = family.ids[#family.ids]
			rows[#rows + 1] = { id, SpellName(id) or family.name }
		end
	end
	return rows
end

local function ByName(rows)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	return rows
end

function C.OnYou()
	local found = {}
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuras or nil
	if type(call) ~= "function" or not T.Open() then
		return found
	end
	local ok, auras = pcall(call, "player", "HELPFUL")
	if not ok or IsSecret(auras) or type(auras) ~= "table" then
		return found
	end
	for _, aura in ipairs(auras) do
		if type(aura) == "table" and not IsSecret(aura) then
			local read, id, count, name = pcall(function()
				return aura.spellId, aura.applications, aura.name
			end)
			if read and Whole(id) and Plain(count, "number") and count > 1 then
				found[#found + 1] = { id, Plain(name, "string") and name or Name(id) }
			end
		end
	end
	return found
end

function ns.ChargesCandidates()
	local rows = Rows(true)
	C.Families()
	for _, row in ipairs(C.OnYou()) do
		if not C.byId[row[1]] and not BUILT[row[1]] then
			rows[#rows + 1] = row
		end
	end
	return ByName(rows)
end

function ns.ChargesListed()
	local rows = Rows(false)
	for _, family in ipairs(C.Families()) do
		if not BUILT[family.key] then
			rows[#rows + 1] = { family.ids[1], Name(family.ids[1]) }
		end
	end
	return ByName(rows)
end

function ns.ChargesAdd(id)
	local saved = C.Saved()
	if not (Whole(id) and (SpellName(id) or BUILT[id])) then
		return false, ('No spell found for "%s".'):format(tostring(id))
	elseif not saved then
		return false, "Nothing can be saved yet."
	end
	C.Families()
	if C.byId[id] then
		return false, ("%s is already on Charges."):format(Name(id))
	end
	local family = BUILT[id]
	if family then
		if not C.Mine(family) then
			return false, ("%s is not a spell of your class."):format(Name(id))
		end
		saved.removed[family.ids[1]] = nil
	else
		local count = 0
		for _ in pairs(saved.added) do
			count = count + 1
		end
		if count >= MOST_ADDED then
			return false, ("%d added spells is the most."):format(MOST_ADDED)
		end
		saved.added[id] = true
	end
	C.ListsChanged()
	return true, ("Charges: added %s."):format(Name(id))
end

function ns.ChargesRemove(id)
	local saved = C.Saved()
	C.Families()
	local family = Whole(id) and saved and C.byId[id] or nil
	if not family then
		return false, ("%s is not on Charges."):format(Whole(id) and Name(id) or tostring(id))
	end
	if BUILT[family.key] then
		saved.removed[family.ids[1]] = true
	else
		saved.added[id] = nil
	end
	C.ListsChanged()
	return true, ("Charges: took %s off."):format(Name(id))
end

function C.Hidden(id)
	local secrets = type(C_Secrets) == "table" and C_Secrets or nil
	local call = secrets and secrets.ShouldSpellAuraBeSecret or nil
	if type(call) ~= "function" then
		return secrets ~= nil and type(secrets.ShouldAurasBeSecret) == "function" and not T.Open()
	end
	local ok, answer = pcall(call, id)
	return not ok or IsSecret(answer) or answer ~= false
end

local function Count(applications, charges)
	if Plain(applications, "number") and applications > 0 then
		return applications, nil
	elseif Plain(charges, "number") and charges > 0 then
		return charges, nil
	elseif IsSecret(applications) then
		return nil, applications
	elseif IsSecret(charges) then
		return nil, charges
	end
	return 1, nil
end

function C.Fields(aura, id)
	local ok, applications, charges, expires, length, file, instance = pcall(function()
		return aura.applications, aura.charges, aura.expirationTime, aura.duration, aura.icon, aura.auraInstanceID
	end)
	if not ok then
		return "hidden"
	end
	local count, secret = Count(applications, charges)
	return { id = id, count = count, secret = secret, expires = ns.Finite(expires) and expires > 0 and expires or nil,
		length = ns.Finite(length) and length or nil, file = (Plain(file, "number") or Plain(file, "string")) and file or SpellIcon(id),
		instance = Plain(instance, "number") and instance or nil }
end

function C.Read(family)
	local get = type(C_UnitAuras) == "table" and C_UnitAuras.GetPlayerAuraBySpellID or nil
	if type(get) ~= "function" then
		return nil
	end
	local hidden = false
	for _, id in ipairs(family.ids) do
		if C.Hidden(id) then
			hidden = true
		else
			local ok, aura = pcall(get, id)
			if not ok or IsSecret(aura) then
				hidden = true
			elseif type(aura) == "table" then
				return C.Fields(aura, id)
			end
		end
	end
	return hidden and "hidden" or nil
end

function C.Holder()
	if not C.holder then
		local holder = L.Own(CreateFrame("Frame", nil, UIParent))
		holder:SetFrameStrata("LOW")
		holder:SetSize(1, 1)
		C.holder = holder
	end
	return C.holder
end

function C.Place()
	local holder = C.Holder()
	local x, y = ns.MoverSpot(MOVER, "CENTER")
	holder:ClearAllPoints()
	if x then
		holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, SPOT_Y)
	end
end

function C.Display(family)
	local d = C.displays[family.key]
	if not d then
		d = L.New(C.Holder())
		d.family, d.rgb = family, family.rgb
		local saved = C.Saved()
		local top = saved and saved.top[family.key]
		d.memory = ns.Finite(top) and top >= 1 and math.min(top, MOST_TOP) or nil
		C.displays[family.key] = d
		L.Paint(d, d.memory or DEFAULT_TOP)
	end
	return d
end

function C.Remember(d, top)
	d.memory = top
	local saved = C.Saved()
	if saved then
		saved.top[d.family.key] = top
	end
end

local function NewCast(d, st)
	if not d.up then
		return true
	elseif st.instance and d.instance and st.instance ~= d.instance then
		return true
	end
	return st.expires ~= nil and d.expires ~= nil and st.expires > d.expires + FRESH
end

function C.Up(d, st, now)
	local fresh = NewCast(d, st)
	local top = d.top or d.memory or DEFAULT_TOP
	if st.count then
		top = fresh and st.count or math.max(top, st.count)
		top = math.min(top, MOST_TOP)
		if top ~= d.memory then
			C.Remember(d, top)
		end
	end
	local was = d.mode
	if top ~= d.top or not d.painted then
		d.top = top
		L.Paint(d, top)
	end
	L.SetIcon(d, st.file)
	d.expires, d.length = st.expires, st.length
	C.SetMode(d, "read")
	local animate = was ~= "hidden" and not C.quiet
	if not d.up or not d.shown or d.fading then
		d.lit = 0
		d.secret = nil
		L.Show(d, now)
	end
	if st.count then
		L.Count(d, st.count, animate and not d.secret, now)
	else
		L.Secret(d, st.secret)
	end
	d.up, d.instance = true, st.instance
	d.left = L.Clock(d, now)
	d.lastCount = st.count
end

function C.Down(d, now, silent)
	if d.up and d.mode == "read" then
		local left = d.expires and d.expires - now or nil
		if not (silent or C.quiet) and d.lastCount and (left == nil or left > EARLY) then
			C.Sound()
		end
		L.Gone(d, now, not (silent or C.quiet))
	elseif d.mode == "hidden" then
		L.Gone(d, now, false)
	end
	d.up, d.instance, d.expires = false, nil, nil
	C.SetMode(d, "none")
end

function C.SetMode(d, mode)
	if d.mode == mode then
		return
	end
	d.mode = mode
	d.own:SetAlpha(mode == "hidden" and 0 or 1)
	local game = ns.ChargesGame
	if game then
		game.Show(d, mode == "hidden")
	end
	if mode == "hidden" then
		L.Still(d)
		d.fading, d.fadeIn, d.shown = nil, nil, true
		d.frame:SetAlpha(1)
		d.expires, d.left = nil, nil
		if d.time then
			d.time:SetText("")
		end
	end
end

function C.Known(family)
	for _, id in ipairs(family.ids) do
		if Ask(IsPlayerSpell, id) == true then
			return true
		end
	end
	return false
end

function C.Hide(d, now)
	if d.up then
		C.Down(d, now, true)
	end
	L.Gone(d, now, false)
	C.SetMode(d, "none")
	d.held = nil
end

function C.Apply(family, st, now)
	local d = C.displays[family.key]
	if st == "hidden" then
		d = d or ((C.Known(family) or false) and C.Display(family))
		if d then
			d.held = d.up or d.held or C.Known(family)
			if d.held then
				C.SetMode(d, "hidden")
			end
		end
		return
	end
	if type(st) == "table" then
		d = d or C.Display(family)
		d.held = nil
		C.Up(d, st, now)
	elseif d then
		d.held = nil
		C.Down(d, now)
	end
end

function C.Gate()
	if not ns.Enabled(KEY) then
		return false
	end
	if Opt("combat") == true and not (InCombatLockdown() or C.fighting) then
		return false
	end
	if Opt("mounted") == true and Ask(IsMounted) == true then
		return false
	end
	return true
end

function C.Pass()
	C.scheduled = false
	if not ns.Enabled(KEY) then
		return
	end
	local now = Now()
	C.Holder():SetAlpha((C.Gate() or C.sample ~= nil) and 1 or 0)
	local real = false
	for _, family in ipairs(C.Families()) do
		local st = C.Read(family)
		real = real or type(st) == "table"
		if not C.sample then
			C.Apply(family, st, now)
		end
	end
	for key, d in pairs(C.displays) do
		if C.sample and key ~= "lightning" or not (C.sample or C.byId[d.family.ids[1]]) then
			C.Hide(d, now)
		end
	end
	if C.sample and C.sample.held and real then
		C.EndSample()
		return
	end
	C.Layout()
	C.Wake()
end

function C.Queue()
	if C.scheduled then
		return
	end
	C.scheduled = true
	if not After(REREAD, function()
		ns.Try(KEY, C.Pass)
	end) then
		C.Pass()
	end
end

local function Visible(d)
	return d.shown or d.fading ~= nil or (d.mode == "hidden" and d.held)
end

function C.Layout()
	local list = C.shown
	for index = #list, 1, -1 do
		list[index] = nil
	end
	for _, d in pairs(C.displays) do
		if Visible(d) then
			list[#list + 1] = d
		end
	end
	table.sort(list, function(a, b)
		return a.family.order < b.family.order
	end)
	local gap = L.Number("orbSize", 12) * 0.6 + 6
	local total = -gap
	for _, d in ipairs(list) do
		total = total + d.w + gap
	end
	local x = -total / 2
	for _, d in ipairs(list) do
		pcall(d.frame.ClearAllPoints, d.frame)
		pcall(d.frame.SetPoint, d.frame, "CENTER", C.holder, "CENTER", x + d.w / 2, -d.cy)
		x = x + d.w + gap
	end
end

function C.Step(_, elapsed)
	if not Plain(elapsed, "number") then
		return
	end
	local now = Now()
	if C.sample then
		C.SampleStep(now, elapsed)
		if C.sample and C.sample.frozen then
			return
		end
	elseif C.holder:GetAlpha() <= 0 then
		C.holder:SetScript("OnUpdate", nil)
		C.ticking = false
		return
	end
	local busy, relayout = false, false
	for _, d in ipairs(C.shown) do
		if d.mode ~= "hidden" or d.gameUp then
			local wasShown = d.shown
			local on = L.Tick(d, now, elapsed)
			busy = busy or on
			if wasShown and not d.shown then
				relayout = true
			end
			if d.mode == "read" and d.left and d.left <= 0 and not C.sample then
				C.Queue()
			end
		end
	end
	if relayout then
		C.Layout()
	end
	if not busy and not C.sample then
		C.Holder():SetScript("OnUpdate", nil)
		C.ticking = false
	end
end

function C.Wake()
	if C.ticking or not C.holder or C.holder:GetAlpha() <= 0 then
		return
	end
	C.ticking = true
	C.holder:SetScript("OnUpdate", function(frame, elapsed)
		ns.Try(KEY, C.Step, frame, elapsed)
	end)
end

function C.Sound()
	local sound = KITS[Opt("sound")]
	local kit = sound and ns.SOUNDS and ns.SOUNDS[sound]
	if kit and type(ns.PlayKit) == "function" then
		ns.PlayKit(kit[1], KEY)
	end
end

function C.Listen(on)
	if not C.watcher then
		local frame = L.Own(CreateFrame("Frame"))
		frame:SetScript("OnEvent", function(_, event, unit)
			if event == "UNIT_AURA" and C.loose and not (Plain(unit, "string") and unit == "player") then
				return
			end
			C.Queue()
		end)
		C.watcher = frame
	end
	local frame = C.watcher
	pcall(frame.UnregisterAllEvents, frame)
	if not on then
		return
	end
	C.loose = not (frame.RegisterUnitEvent ~= nil and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player"))
	if C.loose then
		pcall(frame.RegisterEvent, frame, "UNIT_AURA")
	end
	for _, event in ipairs({ "PLAYER_MOUNT_DISPLAY_CHANGED", "SPELLS_CHANGED" }) do
		pcall(frame.RegisterEvent, frame, event)
	end
end

function C.Repaint()
	for _, d in pairs(C.displays) do
		d.rgb = d.family.rgb
		L.Paint(d, d.top or d.memory or DEFAULT_TOP)
		if d.mode == "read" and d.lastCount then
			L.Count(d, d.lastCount, false, Now())
		end
	end
end

function C.Off()
	C.EndSample(true)
	C.Listen(false)
	for _, d in pairs(C.displays) do
		C.Hide(d, Now())
	end
	C.Layout()
	if C.holder then
		C.holder:SetScript("OnUpdate", nil)
		C.ticking = false
		C.holder:SetAlpha(0)
		C.Shown(false)
	end
	local game = ns.ChargesGame
	if game then
		game.Off()
	end
end

function C.Shown(on)
	C.wantShown = on
	if not InCombatLockdown() then
		C.holder:SetShown(on)
		return
	end
	if C.showQueued then
		return
	end
	C.showQueued = true
	ns.OutOfCombat(function()
		C.showQueued = false
		if C.holder then
			C.holder:SetShown(C.wantShown == true)
		end
	end)
end

function C.Refresh()
	if not ns.Enabled(KEY) then
		C.Off()
		return
	end
	C.Holder()
	C.Shown(true)
	C.Place()
	C.Repaint()
	C.Listen(true)
	local game = ns.ChargesGame
	if game then
		game.Sync()
	end
	C.Hold()
	C.Pass()
end

function ns.ChargesShown()
	return ns.Enabled(KEY)
end

function ns.ChargesMoved()
	if C.holder and ns.Enabled(KEY) then
		ns.Try(KEY, C.Place)
	end
end

function ns.ChargesLookChanged()
	ns.Try(KEY, C.Refresh)
	ns.Try(KEY, C.Preview)
end

function ns.ChargesSoundChanged()
	ns.Try(KEY, C.Refresh)
	if not InCombatLockdown() and ns.Enabled(KEY) then
		C.Sound()
	end
end

function C.AnyUp()
	for _, family in ipairs(C.Families()) do
		if type(C.Read(family)) == "table" then
			return true
		end
	end
	return false
end

local function SampleCount(t)
	for _, step in ipairs(SAMPLE_STEPS) do
		if t < step[1] then
			return step[2]
		end
	end
	return 0
end

function C.SampleApply(now)
	local sample, d = C.sample, C.displays.lightning
	local cycle = SAMPLE_STEPS[#SAMPLE_STEPS][1]
	local passed = now - sample.start
	local round = math.floor(passed / cycle)
	local count = SampleCount(passed - round * cycle)
	if round == sample.round and count == sample.count then
		return
	end
	sample.round, sample.count = round, count
	local st = { id = SAMPLE_ID, count = count, expires = sample.start + round * cycle + SAMPLE_LENGTH, length = SAMPLE_LENGTH,
		file = SpellIcon(SAMPLE_ID) or SAMPLE_ICON, instance = round + 1 }
	C.Up(d, st, now)
end

function C.SampleStep(now, elapsed)
	local sample = C.sample
	local mode = ns.TestMode
	sample.frozen = sample.held and mode ~= nil and not mode.Moving()
	if sample.frozen then
		sample.start = sample.start + elapsed
		local d = C.displays.lightning
		if d and d.expires then
			d.expires = d.expires + elapsed
		end
		return
	end
	if sample.ends and now >= sample.ends then
		C.EndSample()
		return
	end
	C.SampleApply(now)
end

function C.StartSample(why, seconds, held)
	if InCombatLockdown() or not ns.Enabled(KEY) then
		return false
	end
	local now = Now()
	local old = C.sample
	C.sample = { start = old and old.start or now, ends = seconds and now + seconds or nil, held = held == true, why = why }
	local family = BUILT.lightning
	local d = C.Display(family)
	d.rgb = family.rgb
	for key, other in pairs(C.displays) do
		if key ~= "lightning" then
			C.Hide(other, now)
		end
	end
	if not old then
		if d.up or d.mode == "hidden" then
			C.Hide(d, now)
		end
		d.top = nil
	end
	C.SetMode(d, "read")
	C.Holder():SetAlpha(1)
	C.SampleApply(now)
	C.Layout()
	C.Wake()
	return true
end

function C.EndSample(quiet)
	if not C.sample then
		return
	end
	C.sample = nil
	local d = C.displays.lightning
	if d then
		C.Hide(d, Now())
		d.top = nil
	end
	if quiet == true then
		return
	end
	C.quiet = true
	ns.Try(KEY, C.Pass)
	C.quiet = false
end

function C.Hold()
	local mode = ns.TestMode
	local on = mode ~= nil and mode.IsOn() == true and ns.Enabled(KEY) and not InCombatLockdown()
	if on and not C.AnyUp() then
		if not (C.sample and C.sample.held) then
			C.StartSample("test", nil, true)
		end
	elseif C.sample and C.sample.held then
		C.EndSample()
	end
end

function C.Drop()
	if C.sample and C.sample.held then
		C.EndSample()
	end
end

function C.Preview()
	if InCombatLockdown() or not ns.Enabled(KEY) or (C.sample and C.sample.held) or C.AnyUp() then
		return
	end
	C.StartSample("preview", PREVIEW)
end

function C.Test()
	if not ns.Enabled(KEY) then
		print("Charges: turn on Charges first.")
		return
	end
	if InCombatLockdown() or C.fighting then
		print("Charges: the sample shows out of combat.")
		return
	end
	C.Refresh()
	if C.StartSample("slash", TEST_TIME) then
		print(("Charges: a sample of Lightning Shield for %d seconds, a charge used every 2 seconds."):format(TEST_TIME))
	end
end

local function ParseID(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

function C.Named(text, rows)
	local wanted = text:lower()
	for _, row in ipairs(rows) do
		local name = SpellName(row[1]) or row[2]
		if name:lower() == wanted or row[2]:lower() == wanted then
			return row[1]
		end
	end
	return nil
end

function C.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "" or word == "test" then
		C.Test()
	elseif word == "add" and text ~= "" then
		local id = ParseID(text) or C.Named(text, ns.ChargesCandidates()) or C.Named(text, ns.ChargesListed())
		print(id and select(2, ns.ChargesAdd(id)) or ('Charges: no buff with charges named "%s" is on you. Type its spell ID.'):format(text))
	elseif (word == "remove" or word == "off") and text ~= "" then
		local id = ParseID(text) or C.Named(text, ns.ChargesListed())
		print(id and select(2, ns.ChargesRemove(id)) or ('Charges: "%s" is not on Charges.'):format(text))
	elseif word == "list" then
		local rows = ns.ChargesListed()
		if #rows == 0 then
			print("Charges: no spells listed.")
		end
		for _, row in ipairs(rows) do
			print(("%s (%d)"):format(row[2], row[1]))
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

function C.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	local game = ns.ChargesGame
	if game and game.refused then
		lines[#lines + 1] = "Charges: the game refused its own icons, so in a fight, while it hides your buffs, the charges do not show."
	end
	if type(C_UnitAuras) ~= "table" or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function" then
		lines[#lines + 1] = "Charges: the game gives no buff information."
	end
	return lines
end

ns.Register(KEY, {
	label = "Charges",
	counted = false,
	Start = C.Refresh,
	Refresh = C.Refresh,
	Status = C.Status,
	events = {
		PLAYER_ENTERING_WORLD = function()
			C.Refresh()
		end,
		PLAYER_REGEN_DISABLED = function()
			C.fighting = true
			if C.sample then
				C.EndSample()
			end
			C.Queue()
		end,
		PLAYER_REGEN_ENABLED = function()
			C.fighting = false
			local game = ns.ChargesGame
			if game then
				game.Sync()
			end
			C.Queue()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = function()
			C.Queue()
		end,
	},
	slash = { charges = C.Slash },
	help = HELP,
})

if ns.TestMode then
	ns.TestMode.Register(KEY, {
		module = KEY,
		label = "Charges",
		refresh = true,
		Stop = C.Drop,
		Changed = function()
			C.Hold()
		end,
	})
end

ns.Charges = C
