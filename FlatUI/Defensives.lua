local _, ns = ...

local KEY = "defensives"
local MOVER = "FlatUIDefensives"
local OFFSET_X, OFFSET_Y = 0, 20
local ROOM = 16
local CROP = 0.08
local REREAD = 0.2
local TEST_TIME = 8
local PREVIEW = 4
local FLASH_FROM, FLASH = 0.8, 0.5
local LOW, AMBER = 5, { 1, 0.7, 0.2 }
local KITS = { raid = 8959, alarm = 12889, whisper = 37666 }
local MOST_LISTED, MOST_EXTERNAL = 6, 4
local GROUPS = { "listed", "external", "own" }
local MOST_OWN, MOST_ADDED, MAX_ID = 4, 40, 2147483647
local BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local CASTER = { useClassColors = true }
local NOTE_NO_POSITION = "Defensives on you: the personal resource display has no position, so the row is above the player frame."
local NOTE_REFUSED = "Defensives on you: the game refused the %s, so icons show without it."
local NOTE_SIZE = "Defensives on you: the game refused a new icon size, so icons already shown keep their old one until you log in again."
local NOTE_MOUSE = "Defensives on you: the game refused a mouse setting of the icons, so clicks or tooltips may not work."
local NOTE_READING = "Defensives on you: Buff tooltips has no effect while the game makes no icon row."
local LINE_OUT = "Defensives on you: icons show out of combat only."
local LINE_OWN = "Defensives on you: Your own defensives is off here, since the game made no icon row."
local LINE_FRAME = "Defensives on you: the game's External Defensives frame is also on. Type /console externalDefensivesEnabled 0."
local HELP = {
	"/flatui check - what the game shows and hides where you stand",
	"/flatui check last - the lines of the last check",
	"/flatui test icons - three sample icons for Defensives on you, for 8 seconds",
	"/flatui defensives add 10060 - the spell ID of a buff, or a shift-clicked spell",
	"/flatui defensives remove 17 - a spell ID or a name",
	"/flatui defensives list",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local TM = ns.TestMode
local D = { list = {}, pending = {}, active = {}, refused = {}, icons = {} }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

function D.Holder()
	if not D.holder then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		holder:SetSize(1, 1)
		D.holder = holder
	end
	return D.holder
end

function D.TopBar(display)
	for _, key in ipairs(BARS) do
		local bar = Field(display, key)
		if bar ~= nil and not ns.Forbidden(bar) then
			local ok, shown = pcall(bar.IsShown, bar)
			if ok and not IsSecret(shown) and shown == true then
				return bar
			end
		end
	end
	return display
end

function D.Anchored(frame)
	local ok, left = pcall(frame.GetLeft, frame)
	return not ok or IsSecret(left) or left ~= nil
end

function D.Place()
	local holder = D.Holder()
	local place = Opt("place")
	holder:ClearAllPoints()
	if place == "own" then
		local x, y = ns.MoverSpot(MOVER, "BOTTOMLEFT")
		if x then
			holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y + ROOM)
			return "own"
		end
	end
	if place == "resource" then
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			local over = type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder("above") or nil
			if over then
				holder:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 0, ROOM + 4)
			else
				holder:SetPoint("BOTTOMLEFT", D.TopBar(display), "TOPLEFT", 0, ROOM + 4)
			end
			if D.Anchored(holder) then
				ns.ClearNote(KEY, NOTE_NO_POSITION)
				return "resource"
			end
			holder:ClearAllPoints()
		end
		ns.Note(KEY, NOTE_NO_POSITION)
	else
		ns.ClearNote(KEY, NOTE_NO_POSITION)
	end
	local frame = PlayerFrame
	if frame ~= nil and not ns.Forbidden(frame) then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", OFFSET_X, OFFSET_Y)
		return "player"
	end
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
	return "screen"
end

local function EdgeColour()
	if ns.Borderless() or not Opt("iconBorder") then
		return 0, 0, 0, 0
	end
	local r, g, b = ns.Colour("general.border")
	return r, g, b, 1
end

local function Thick()
	return ns.Pixels(D.Holder(), ns.Get("general.thickness"))
end

local function EdgeKey()
	local r, g, b, a = EdgeColour()
	return ("%s,%s,%s,%s,%s"):format(Thick(), r, g, b, a)
end

function D.PaintEdges(parts)
	local button, edges = parts.button, parts.edges
	local thick = Thick()
	local r, g, b, a = EdgeColour()
	edges[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(thick)
	edges[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(thick)
	edges[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -thick)
	edges[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, thick)
	edges[3]:SetWidth(thick)
	edges[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -thick)
	edges[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, thick)
	edges[4]:SetWidth(thick)
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(r, g, b, a)
	end
	parts.borderKey = EdgeKey()
end

function D.Mouse(parts)
	local button, tips = parts.button, Opt("tooltips")
	local ok = pcall(button.SetMouseClickEnabled, button, false)
	ok = pcall(button.SetMouseMotionEnabled, button, tips ~= "off") and ok
	ok = pcall(button.SetHideTooltipInCombat, button, tips ~= "on") and ok
	parts.tips = ok and tips or nil
	D.refused.tips = nil
	for _, other in ipairs(D.list) do
		if other.tips == nil then
			D.refused.tips = true
		end
	end
end

function D.TimeOptions()
	if D.timeOptions == nil then
		local ok, options = pcall(function()
			local curve = C_CurveUtil.CreateColorCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, CreateColor(AMBER[1], AMBER[2], AMBER[3], 1))
			curve:AddPoint(LOW, CreateColor(1, 1, 1, 1))
			return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
		end)
		D.timeOptions = ok and type(options) == "table" and options or false
	end
	return D.timeOptions or nil
end

D.BASE = 32
function D.TextSize(size)
	return ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormal", 14), size, D.BASE),
		ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormalSmall", 12), size, D.BASE)
end

function D.SizeText(parts, size)
	local time, count = D.TextSize(size)
	local ok = true
	if parts.left then
		ok = pcall(parts.left.SetTextHeight, parts.left, time) and ok
	end
	if parts.count then
		ok = pcall(parts.count.SetTextHeight, parts.count, count) and ok
	end
	if ok then
		parts.textSize = size
	end
	return ok
end

function D.Init(button)
	local parts = { button = button, casterOn = Opt("caster") }
	D.list[#D.list + 1] = parts
	D.Mouse(parts)
	parts.size = pcall(button.SetSize, button, Opt("size"), Opt("size")) and Opt("size") or nil
	local function Part(name, fn)
		if not pcall(fn) then
			D.refused[name] = true
		end
	end
	Part("icon", function()
		local icon = Own(button:CreateTexture(nil, "ARTWORK", nil, 0))
		icon:SetAllPoints()
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		button:SetIcon(icon)
		parts.icon = icon
	end)
	Part("sweep", function()
		local sweep = Own(CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate"))
		sweep:SetAllPoints()
		sweep:SetDrawEdge(false)
		sweep:SetDrawBling(false)
		sweep:SetSwipeColor(0, 0, 0, 0.7)
		sweep:SetHideCountdownNumbers(true)
		parts.sweep = sweep
		button:SetDurationCooldown(sweep)
	end)
	local made, top = pcall(function()
		local frame = Own(CreateFrame("Frame", nil, button))
		frame:SetAllPoints()
		frame:SetFrameLevel(button:GetFrameLevel() + 3)
		return frame
	end)
	if not made then
		D.refused.count, D.refused.time, D.refused.name, D.refused.border, D.refused.flash = true, true, true, true, true
		return
	end
	parts.top = top
	Part("count", function()
		local count = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"))
		count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(count, nil)
		parts.count = count
	end)
	Part("time", function()
		local left = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
		left:SetPoint("CENTER", top, "CENTER", 0, 0)
		parts.left = left
		local options = D.TimeOptions()
		local bound = options ~= nil and pcall(button.SetDurationText, button, left, options)
		if not bound and not pcall(button.SetDurationText, button, left, nil) and parts.sweep then
			pcall(parts.sweep.SetHideCountdownNumbers, parts.sweep, false)
			error("the time text was refused", 0)
		end
	end)
	Part("name", function()
		local name = Own(top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		name:SetPoint("TOP", button, "BOTTOM", 0, -1)
		parts.name = name
		if parts.casterOn then
			button:SetCasterName(name, CASTER)
		else
			name:Hide()
		end
	end)
	Part("border", function()
		local edges = {}
		for index = 1, 4 do
			local edge = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
			if edge.SetSnapToPixelGrid then
				pcall(edge.SetSnapToPixelGrid, edge, false)
			end
			edges[index] = edge
		end
		parts.edges = edges
		D.PaintEdges(parts)
	end)
	Part("flash", function()
		local flash = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
		flash:SetAllPoints(button)
		flash:SetColorTexture(1, 1, 1, 1)
		flash:SetAlpha(0)
		local group = flash:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(FLASH_FROM)
		fade:SetToAlpha(0)
		fade:SetDuration(FLASH)
		group:SetToFinalAlpha(true)
		button:AddAuraShownAnimation(group)
		parts.flash = flash
		parts.flashOn = Opt("flash") ~= false
		flash:SetShown(parts.flashOn)
	end)
	pcall(D.SizeText, parts, Opt("size"))
end

function D.ApplyCaster()
	local want = Opt("caster")
	for _, parts in ipairs(D.list) do
		if parts.name and parts.casterOn ~= want then
			local ok
			if want then
				ok = pcall(parts.button.SetCasterName, parts.button, parts.name, CASTER)
			else
				ok = pcall(parts.button.ClearCasterName, parts.button)
				pcall(parts.name.Hide, parts.name)
			end
			if ok then
				parts.casterOn = want
			else
				D.refused.name = true
			end
		end
	end
end

local function Layout()
	return { elementSpacing = Opt("spacing"), elementWidth = Opt("size"), elementHeight = Opt("size") }
end

function D.ApplySize()
	local size, spacing = Opt("size"), Opt("spacing")
	if D.sized ~= size .. ":" .. spacing then
		D.sized = size .. ":" .. spacing
		for _, group in ipairs(GROUPS) do
			if D.container then
				pcall(D.container.SetAuraGroupLayout, D.container, group, Layout())
			end
		end
	end
	local refused = nil
	for _, parts in ipairs(D.list) do
		if parts.size ~= size then
			if pcall(parts.button.SetSize, parts.button, size, size) then
				parts.size = size
			else
				refused = true
			end
		end
		if parts.textSize ~= size then
			D.SizeText(parts, size)
		end
	end
	D.refused.size = refused
end

function D.ApplyBorder()
	for _, parts in ipairs(D.list) do
		if parts.edges and parts.borderKey ~= EdgeKey() then
			if not pcall(D.PaintEdges, parts) then
				D.refused.border = true
			end
		end
	end
end

function D.ApplyTips()
	for _, parts in ipairs(D.list) do
		if parts.tips ~= Opt("tooltips") then
			D.Mouse(parts)
		end
	end
end

function D.ApplyFlash()
	local want = Opt("flash") ~= false
	for _, parts in ipairs(D.list) do
		if parts.flash and parts.flashOn ~= want then
			if pcall(parts.flash.SetShown, parts.flash, want) then
				parts.flashOn = want
			else
				D.refused.flash = true
			end
		end
	end
end

D.apply = { caster = D.ApplyCaster, border = D.ApplyBorder, size = D.ApplySize, tips = D.ApplyTips, flash = D.ApplyFlash }

function D.Flush()
	if next(D.pending) == nil or not T.Open() then
		return
	end
	local todo = D.pending
	D.pending = {}
	for kind in pairs(todo) do
		pcall(D.apply[kind])
	end
end

function D.Change(kind)
	if T.Open() then
		pcall(D.apply[kind])
		return
	end
	D.pending[kind] = true
	if not D.flushQueued then
		D.flushQueued = true
		ns.OutOfCombat(function()
			D.flushQueued = false
			D.Flush()
		end)
	end
end

function D.Restricted()
	for kind = 0, 3 do
		if D.active[kind] then
			return true
		end
	end
	return false
end

function D.OnRestriction(kind, state)
	if Plain(kind, "number") and Plain(state, "number") and kind >= 0 and kind <= 3 then
		D.active[kind] = state ~= 0
	end
	if next(D.pending) ~= nil and not D.Restricted() then
		D.Flush()
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0, D.Flush)
		end
	end
end

function D.ReadRestrictions()
	local call = type(C_RestrictedActions) == "table" and C_RestrictedActions.IsAddOnRestrictionActive or nil
	for kind = 0, 3 do
		local answer = T.Ask(call, kind)
		D.active[kind] = answer == true
	end
end

local function Copy(set)
	local copy = {}
	for id in pairs(set or {}) do
		copy[id] = true
	end
	return copy
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function SpellName(id)
	local name = T.Ask(C_Spell and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

local function Name(id)
	return SpellName(id) or ("Spell " .. id)
end

function D.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.defensives
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.defensives = saved
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
	return saved
end

function D.Effective()
	local set = Copy(T.Listed())
	local saved = D.Saved()
	if saved then
		for id in pairs(saved.added) do
			set[id] = true
		end
		for id in pairs(saved.removed) do
			set[id] = nil
		end
	end
	return set
end

function D.Excluded()
	local set = D.Effective()
	local saved = D.Saved()
	for id in pairs(saved and saved.removed or {}) do
		set[id] = true
	end
	return set
end

function D.OwnIDs()
	local set = {}
	local class = T.Ask(UnitClassBase, "player")
	if not Plain(class, "string") or type(ns.ABILITIES) ~= "table" then
		return set
	end
	for _, ability in ipairs(ns.ABILITIES) do
		if (ability.kind == 2 or ability.kind == 6) and (ability.class == class or ability.class == "ALL") then
			for _, id in ipairs(ability.buffs) do
				set[id] = true
			end
		end
	end
	return set
end

function D.ApplyLists()
	D.QueueSounds()
	if D.path == "reading" then
		D.Queue()
		return
	end
	local container = D.container
	if not container then
		return
	end
	ns.OutOfCombat(function()
		local map = D.Effective()
		pcall(container.SetAuraGroupCandidateFilters, container, "listed", { includeSpellIDs = map })
		pcall(container.SetAuraGroupCandidateFilters, container, "external", { excludeSpellIDs = D.Excluded() })
	end)
end

local function Distinguish(rows)
	local seen = {}
	for _, row in ipairs(rows) do
		seen[row[2]] = (seen[row[2]] or 0) + 1
	end
	for _, row in ipairs(rows) do
		if seen[row[2]] > 1 then
			local subtext = T.Ask(C_Spell and C_Spell.GetSpellSubtext, row[1])
			if Plain(subtext, "string") and subtext ~= "" then
				row[2] = row[2] .. " (" .. subtext .. ")"
			end
		end
	end
end

local function ByName(rows)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	Distinguish(rows)
	return rows
end

function ns.DefensiveCandidates()
	local rows, set, seen = {}, D.Effective(), {}
	for _, ability in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		if ability.kind == 3 or ability.kind == 9 or ((ability.kind == 2 or ability.kind == 6) and (ability.flags or ""):find("o", 1, true)) then
			for _, id in ipairs(ability.buffs) do
				if not set[id] and not seen[id] then
					seen[id] = true
					rows[#rows + 1] = { id, Name(id) }
				end
			end
		end
	end
	return ByName(rows)
end

function ns.DefensiveListed()
	local rows = {}
	for id in pairs(D.Effective()) do
		rows[#rows + 1] = { id, Name(id) }
	end
	return ByName(rows)
end

function ns.DefensiveAdd(id)
	local saved = D.Saved()
	if not (Whole(id) and SpellName(id)) then
		return false, ('No spell found for "%s".'):format(tostring(id))
	end
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if D.Effective()[id] then
		return false, ("%s is already listed."):format(Name(id))
	end
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	if not saved.removed[id] and count >= MOST_ADDED then
		return false, ("%d added spells is the most."):format(MOST_ADDED)
	end
	if saved.removed[id] then
		saved.removed[id] = nil
	else
		saved.added[id] = true
	end
	D.ApplyLists()
	return true, ("Added %s."):format(Name(id))
end

function ns.DefensiveRemove(id)
	local saved = D.Saved()
	if not (Whole(id) and saved) or not D.Effective()[id] then
		return false, ("%s is not listed."):format(Whole(id) and Name(id) or tostring(id))
	end
	if saved.added[id] then
		saved.added[id] = nil
	else
		saved.removed[id] = true
	end
	D.ApplyLists()
	return true, ("Removed %s."):format(Name(id))
end

local function ParseID(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

local function IDsNamed(text)
	local found, wanted = {}, text:lower()
	for id in pairs(D.Effective()) do
		local name = SpellName(id)
		if name and name:lower() == wanted then
			found[#found + 1] = id
		end
	end
	table.sort(found)
	return found
end

function D.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "add" and text ~= "" then
		local id = ParseID(text)
		if not id then
			print(('No spell found for "%s".'):format(text))
			return
		end
		print(select(2, ns.DefensiveAdd(id)))
	elseif word == "remove" and text ~= "" then
		local id = ParseID(text)
		local ids = id and { id } or IDsNamed(text)
		if #ids == 0 then
			print(('No spell found for "%s".'):format(text))
			return
		end
		for _, each in ipairs(ids) do
			print(select(2, ns.DefensiveRemove(each)))
		end
	elseif word == "list" then
		local names, order = {}, {}
		for _, row in ipairs(ns.DefensiveListed()) do
			local name = SpellName(row[1]) or row[2]
			if not names[name] then
				names[name] = {}
				order[#order + 1] = name
			end
			table.insert(names[name], row[1])
		end
		if #order == 0 then
			print("No buffs listed.")
		end
		for _, name in ipairs(order) do
			table.sort(names[name])
			print(("%s (%s)"):format(name, table.concat(names[name], ", ")))
		end
	else
		for index = #HELP - 2, #HELP do
			print(HELP[index])
		end
	end
end

function D.Build()
	D.tried = true
	local holder = D.Holder()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		D.path = "reading"
		return
	end
	Own(container)
	local set = D.Effective()
	local made, err = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
		container:AddAuraGroup("listed", "HELPFUL|!PLAYER", { candidateFilters = { includeSpellIDs = Copy(set) }, maxFrameCount = MOST_LISTED,
			layout = Layout(), initializeFrame = D.InitCall })
		container:AddAuraGroup("external", "HELPFUL|EXTERNAL_DEFENSIVE", { candidateFilters = { excludeSpellIDs = D.Excluded() }, maxFrameCount = MOST_EXTERNAL,
			layout = Layout(), initializeFrame = D.InitCall })
	end)
	D.container = container
	D.sized = Opt("size") .. ":" .. Opt("spacing")
	if made then
		local ownMade = pcall(function()
			container:AddAuraGroup("own", "HELPFUL|PLAYER", { candidateFilters = { includeSpellIDs = D.OwnIDs() }, maxFrameCount = MOST_OWN,
				layout = Layout(), initializeFrame = D.InitCall })
			container:SetAuraGroupEnabled("own", false)
		end)
		D.ownRefused = not ownMade
		D.path = "container"
		return
	end
	D.failure = tostring(err)
	D.Groups(false)
	D.path = "reading"
end

function D.InitCall(button)
	local ok, err = pcall(D.Init, button)
	if not ok then
		D.refused.icon = true
		D.failure = tostring(err)
	end
end

function D.Groups(on)
	local container = D.container
	if not container then
		return
	end
	for _, group in ipairs(GROUPS) do
		pcall(container.SetAuraGroupEnabled, container, group, on and (group ~= "own" or Opt("own") == true))
	end
end

local function ClassColour(unit)
	local class = T.Ask(UnitClassBase, unit)
	local colours = RAID_CLASS_COLORS
	local colour = Plain(class, "string") and type(colours) == "table" and colours[class] or nil
	if type(colour) == "table" and Plain(colour.r, "number") and Plain(colour.g, "number") and Plain(colour.b, "number") then
		return colour.r, colour.g, colour.b
	end
end

function D.Read()
	if not T.Open() then
		return nil
	end
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuras or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, auras = pcall(call, "player", "HELPFUL")
	if not ok or IsSecret(auras) or type(auras) ~= "table" then
		return nil
	end
	local set, found = D.Effective(), {}
	for _, aura in ipairs(auras) do
		if type(aura) == "table" and not IsSecret(aura) then
			local read, id, source, expires, length, file = pcall(function()
				return aura.spellId, aura.sourceUnit, aura.expirationTime, aura.duration, aura.icon
			end)
			local from = Plain(source, "string") and source or nil
			if read and Plain(id, "number") and set[id] and from ~= "player" and ns.Finite(expires) and ns.Finite(length) then
				found[#found + 1] = { id = id, source = from, expires = expires, length = length,
					file = (Plain(file, "number") or Plain(file, "string")) and file or nil }
			end
		end
	end
	table.sort(found, function(a, b)
		return a.id < b.id
	end)
	return found
end

function D.Icon(index)
	local icon = D.icons[index]
	if not icon then
		icon = ns.IconNew(D.Holder())
		if not icon then
			return nil
		end
		local name = Own(icon.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		name:SetPoint("TOP", icon.frame, "BOTTOM", 0, -1)
		icon.name = name
		D.icons[index] = icon
	end
	return icon
end

function D.Pass()
	D.scheduled = false
	if D.path ~= "reading" or not ns.Enabled(KEY) or D.testing then
		return
	end
	local read = D.Read()
	local found = read or {}
	local shown = {}
	local before, now = D.landed, {}
	D.landed = read and now or nil
	for index = 1, math.min(#found, MOST_LISTED) do
		local item, icon = found[index], D.Icon(index)
		if icon then
			ns.IconSet(icon, item.file, item.expires - item.length, item.length, { border = Opt("iconBorder") })
			ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
			local landing = item.id .. ":" .. item.expires
			now[landing] = true
			if before and not before[landing] and Opt("flash") ~= false then
				ns.IconFlash(icon)
			end
			local name = nil
			if Opt("caster") and item.source then
				name = T.Ask(UnitName, item.source)
			end
			if Plain(name, "string") then
				icon.name:SetText(name)
				icon.name:SetTextColor(1, 1, 1)
				local r, g, b = ClassColour(item.source)
				if r then
					icon.name:SetTextColor(r, g, b)
				end
				icon.name:Show()
			else
				icon.name:Hide()
			end
			shown[#shown + 1] = icon
		end
	end
	if #found > 0 then
		D.seen = "readable"
	end
	for index = #shown + 1, #D.icons do
		ns.IconClear(D.icons[index])
		D.icons[index].name:Hide()
	end
	ns.IconLayout(shown, D.Holder(), Opt("size"), Opt("spacing"), "right")
end

function D.Queue()
	if D.scheduled then
		return
	end
	D.scheduled = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(REREAD, D.Pass)
	else
		D.Pass()
	end
end

function D.StartReading()
	if not D.watcher then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return
		end
		D.watcher = Own(frame)
		frame:SetScript("OnEvent", function(_, _, unit)
			if D.path == "reading" and (D.playerOnly or (Plain(unit, "string") and unit == "player")) then
				D.Queue()
			end
		end)
	end
	local frame = D.watcher
	D.playerOnly = frame.RegisterUnitEvent ~= nil and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
	if not D.playerOnly then
		pcall(frame.RegisterEvent, frame, "UNIT_AURA")
	end
	D.Queue()
end

function D.StopReading()
	if D.watcher then
		pcall(D.watcher.UnregisterAllEvents, D.watcher)
	end
	D.landed = nil
	for _, icon in ipairs(D.icons) do
		ns.IconClear(icon)
		icon.name:Hide()
	end
end

D.sounds = {}
D.TRIGGERS = { Added = "sound", Removed = "endSound" }

function D.Knows(id)
	local known = nil
	if type(C_SpellBook) == "table" then
		known = T.Ask(C_SpellBook.IsSpellKnown, id)
	end
	if type(known) ~= "boolean" then
		known = T.Ask(IsPlayerSpell, id)
	end
	return known == true
end

function D.Withheld()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret or nil
	if type(call) ~= "function" then
		return false
	end
	local ok, answer = pcall(call)
	return ok and not IsSecret(answer) and answer == true
end

function D.QueueSounds()
	if D.soundQueued then
		return
	end
	D.soundQueued = true
	ns.OutOfCombat(function()
		D.soundQueued = false
		D.SyncSounds()
	end)
end

function D.SoundsWait(on)
	if on == (D.soundWaiting == true) then
		return
	end
	D.soundWaiting = on
	if on and not D.soundFrame then
		local frame = Own(CreateFrame("Frame"))
		frame:SetScript("OnEvent", function()
			if D.soundWaiting then
				D.QueueSounds()
			end
		end)
		D.soundFrame = frame
	end
	local frame = D.soundFrame
	for _, event in ipairs(frame and { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_ENTERING_WORLD" } or {}) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
end

function D.SyncSounds()
	local auras = type(C_UnitAuras) == "table" and C_UnitAuras or {}
	local add, remove = auras.AddAuraSound, auras.RemoveAuraSound
	if type(add) ~= "function" then
		return
	end
	if InCombatLockdown() or D.Withheld() then
		D.SoundsWait(true)
		return
	end
	D.SoundsWait(false)
	local triggers = type(Enum) == "table" and Enum.UnitAuraSoundTrigger or nil
	local files = {}
	if D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off" and type(ns.TrackerSoundFile) == "function" then
		for name, row in pairs(D.TRIGGERS) do
			local file = ns.TrackerSoundFile(Opt(row))
			local trigger = type(triggers) == "table" and triggers[name] or nil
			if file and (trigger ~= nil or name == "Added") then
				files[name] = { file = file, trigger = trigger }
			end
		end
	end
	local wanted = {}
	if next(files) ~= nil then
		for id in pairs(D.Effective()) do
			if Whole(id) and not D.Knows(id) then
				for name, want in pairs(files) do
					wanted[id .. ":" .. name] = { id = id, file = want.file, trigger = want.trigger }
				end
			end
		end
	end
	for key, made in pairs(D.sounds) do
		if not wanted[key] or made.file ~= wanted[key].file then
			D.sounds[key] = nil
			if type(remove) == "function" then
				pcall(remove, made.id)
			end
		end
	end
	D.refused.sound = nil
	for key, want in pairs(wanted) do
		if not D.sounds[key] then
			local ok, handle = pcall(add, want.trigger, { unitToken = "player", spellID = want.id, soundFileID = want.file, outputChannel = "Master",
				throttleSeconds = 1 })
			if ok and Plain(handle, "number") then
				D.sounds[key] = { id = handle, file = want.file }
			else
				D.refused.sound = true
			end
		end
	end
end

function D.Capable()
	return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function"
end

function D.Sync()
	local on = D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off"
	D.QueueSounds()
	if not on then
		D.Held()
		if D.holder and not D.testing then
			D.holder:Hide()
		end
		D.Groups(false)
		D.StopReading()
		return
	end
	local holder = D.Holder()
	holder:Show()
	D.Place()
	if not D.tried then
		D.Build()
	end
	if D.path == "container" then
		D.Groups(true)
		D.Change("caster")
		D.Change("border")
		D.Change("size")
		D.Change("tips")
		D.Change("flash")
	elseif D.path == "reading" then
		D.StartReading()
	end
	D.Held()
end

function D.Refresh()
	if D.Capable() then
		ns.OutOfCombat(D.Sync)
	end
end

function ns.DefensivesOwnShown()
	return ns.Enabled(KEY) and Opt("place") == "own"
end

function ns.DefensivesMoved()
	if D.holder and ns.Enabled(KEY) then
		ns.OutOfCombat(D.Place)
	end
end

function D.Start()
	if not D.Capable() then
		return
	end
	D.ReadRestrictions()
	T.Listen()
	D.Sync()
end

function ns.DefensivesPathText()
	if not D.Capable() then
		return "Defensives on you: the game gives no buff information."
	elseif not (ns.Enabled(KEY) and Opt("place") ~= "off") then
		return "Defensives on you: off."
	elseif D.path == "container" then
		return "Defensives on you: the game's own icon row."
	elseif D.path == "reading" then
		return "Defensives on you: out of combat only, the game made no icon row."
	end
	return "Defensives on you: not started."
end

function ns.DefensivesSeenText()
	if not T.Open() then
		return "hidden by the game right now"
	end
	for _, id in ipairs(T.ListedIDs()) do
		if ns.UnitBuff("player", id) then
			return "seen readable"
		end
	end
	return "not seen"
end

function D.Check(rest)
	if (rest or ""):lower():match("^%s*last%s*$") then
		local record = ns.CheckLast()
		if not record then
			print("No check yet. Type /flatui check.")
			return
		end
		if record.when then
			print("Check of " .. record.when)
		end
		for _, line in ipairs(record.lines) do
			print(line)
		end
		return
	end
	T.OnReply = function(text)
		print(text)
	end
	for _, line in ipairs(ns.CheckLines()) do
		print(line)
	end
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

D.CASTERS = { { "Eli", "PRIEST" }, { "Mara", "PALADIN" }, { "Ivo", "WARLOCK" } }

function D.SampleLook()
	return { border = Opt("iconBorder") ~= false }
end

function D.SampleName(icon, index)
	if not icon.name then
		local made, name = pcall(icon.frame.CreateFontString, icon.frame, nil, "OVERLAY", "GameFontNormalSmall")
		if not made or type(name) ~= "table" then
			return
		end
		Own(name)
		name:SetPoint("TOP", icon.frame, "BOTTOM", 0, -1)
		icon.name = name
	end
	local caster = D.CASTERS[index]
	if not (caster and Opt("caster") and ns.Enabled(KEY) and Opt("place") ~= "off") then
		icon.name:Hide()
		return
	end
	icon.name:SetText(caster[1])
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and colours[caster[2]] or nil
	if type(colour) == "table" and Plain(colour.r, "number") and Plain(colour.g, "number") and Plain(colour.b, "number") then
		icon.name:SetTextColor(colour.r, colour.g, colour.b)
	else
		icon.name:SetTextColor(1, 1, 1)
	end
	icon.name:Show()
end

function D.EndTest(token, cut)
	local test = D.testing
	if not test or (token and test ~= token) then
		return
	end
	D.testing = nil
	local done = 0
	for _, icon in ipairs(test.list) do
		pcall(icon.cooldown.SetCooldown, icon.cooldown, 0, 0)
		done = done + (icon.done or 0)
		ns.IconClear(icon)
		if icon.name then
			icon.name:Hide()
		end
	end
	if not test.quiet then
		local ends = Opt("endSound")
		local line = ("Defensives on you: the sweep ended on %d of 3 icons. Sound when one lands: %s."):format(done,
			D.SoundWords(Opt("sound"), test.sound))
		if KITS[ends] and not cut then
			line = line .. (" Sound when one ends: %s."):format(D.SoundWords(ends, D.SampleSound(ends)))
		end
		print(line)
	end
	if D.holder and not (ns.Enabled(KEY) and Opt("place") ~= "off") then
		D.holder:Hide()
	end
	if D.path == "reading" then
		D.Queue()
	end
end

function D.SoundWords(word, result)
	local kit = KITS[word]
	if not kit then
		return "None"
	end
	local name = word
	for _, sound in ipairs(ns.SOUNDS or {}) do
		if sound[1] == kit then
			name = sound[2]
		end
	end
	if result == "played" then
		return name .. ", played"
	end
	return name .. ", the game played no sound"
end

function D.SampleSound(word)
	local kit = KITS[word or Opt("sound")]
	if not kit then
		return "none"
	end
	return type(ns.PlayKit) == "function" and ns.PlayKit(kit, KEY) and "played" or "refused"
end

D.FLASH_AGAIN = { [KEY .. ".flash"] = true, [KEY .. ".sound"] = true, [KEY .. ".endSound"] = true }

function D.Test(quiet, path)
	quiet = quiet == true
	if not D.Capable() then
		if not quiet then
			print("Defensives on you: the game gives no buff information.")
		end
		return
	end
	if InCombatLockdown() then
		if not quiet then
			print("Defensives on you: the test shows out of combat only.")
		end
		return
	end
	local again = quiet and D.testing and D.testing.quiet and D.testing or nil
	if D.testing then
		D.EndTest(nil, true)
	end
	local holder = D.Holder()
	D.Place()
	holder:Show()
	local list = {}
	for index = 1, 3 do
		D.sample = D.sample or {}
		local icon = D.sample[index] or ns.IconNew(holder)
		if not icon then
			return
		end
		D.sample[index] = icon
		icon.done = 0
		list[index] = icon
	end
	local now = Now()
	if again and again.start and now - again.start < 6 then
		now = again.start
	end
	local flash = Opt("flash") ~= false and (not again or D.FLASH_AGAIN[path] == true)
	for index, icon in ipairs(list) do
		ns.IconSet(icon, ns.IconSamplePicture(index), now, 2 * index, D.SampleLook())
		ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
		D.SampleName(icon, index)
		if flash then
			ns.IconFlash(icon)
		end
	end
	ns.IconLayout(list, holder, Opt("size"), Opt("spacing"), "right")
	local test = { list = list, quiet = quiet, start = now }
	D.testing = test
	if not quiet then
		test.sound = D.SampleSound()
		print("Defensives on you: three sample icons for 8 seconds.")
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(quiet and PREVIEW or TEST_TIME, function()
			D.EndTest(test)
		end)
	end
end

function D.Up()
	if D.path == "container" then
		for _, parts in ipairs(D.list) do
			local ok, shown = pcall(parts.button.IsShown, parts.button)
			if not ok or IsSecret(shown) or shown == true then
				return true
			end
		end
		return false
	end
	if #(D.Read() or {}) > 0 then
		return true
	end
	if Opt("own") == true then
		for id in pairs(D.OwnIDs()) do
			if ns.UnitBuff("player", id) then
				return true
			end
		end
	end
	return false
end

function ns.DefensivesLookChanged(path)
	ns.Try(KEY, D.Refresh)
	if D.testing and D.testing.quiet and Opt("place") == "off" then
		ns.Try(KEY, D.EndTest, nil, true)
	end
	if InCombatLockdown() or TM.IsOn() or not (D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off") then
		return
	end
	local read, up = pcall(D.Up)
	if (D.testing and not D.testing.quiet) or not read or up then
		return
	end
	ns.Try(KEY, D.Test, true, path)
end

function D.Held()
	local list = D.held or {}
	D.held = list
	if not (TM.IsOn() and D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off" and not InCombatLockdown()) then
		D.Drop()
		return
	end
	local holder = D.Holder()
	for index = 1, 3 do
		list[index] = list[index] or ns.IconNew(holder)
		if not list[index] then
			return
		end
	end
	local look, flash, came = D.SampleLook(), Opt("flash") ~= false, false
	look.flash, look.sound = false, false
	for index, icon in ipairs(list) do
		local fresh = not (icon.held and icon.frame:IsShown())
		ns.IconSampleHeld(icon, index, KEY, look)
		ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
		D.SampleName(icon, index)
		if fresh and icon.held then
			came = true
			if flash then
				ns.IconFlash(icon)
			end
		end
	end
	if came and TM.Sound(KEY .. ".sample") then
		D.SampleSound()
	end
	ns.IconLayout(list, holder, Opt("size"), Opt("spacing"), "right")
end

function D.Tick(now)
	local again = {}
	if Opt("flash") ~= false then
		for _, icon in ipairs(D.held or {}) do
			local held = icon.held
			if held and now >= held.ends and icon.frame:IsShown() then
				again[#again + 1] = icon
			end
		end
	end
	ns.IconSampleLoop(D.held, now)
	for _, icon in ipairs(again) do
		ns.IconFlash(icon)
	end
end

function D.Drop()
	for _, icon in ipairs(D.held or {}) do
		ns.IconSampleDrop(icon)
		if icon.name then
			icon.name:Hide()
		end
	end
end

function D.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if D.path == "reading" then
		lines[#lines + 1] = LINE_OUT
		if Opt("own") == true then
			lines[#lines + 1] = LINE_OWN
		end
	elseif D.ownRefused and Opt("own") == true then
		lines[#lines + 1] = LINE_OWN
	end
	local parts = {}
	for _, name in ipairs({ "icon", "sweep", "count", "time", "name", "border", "flash" }) do
		if D.refused[name] then
			parts[#parts + 1] = name == "sweep" and "sweep" or (name == "name" and "caster's name" or (name == "time" and "time left" or name))
		end
	end
	for _, name in ipairs(parts) do
		lines[#lines + 1] = NOTE_REFUSED:format(name)
	end
	if D.refused.size then
		lines[#lines + 1] = NOTE_SIZE
	end
	if D.refused.tips then
		lines[#lines + 1] = NOTE_MOUSE
	end
	if D.refused.sound then
		lines[#lines + 1] = "Defensives on you: the game refused its sound for a defensive landing, so Sound when one lands is silent for some of them."
	end
	if D.path == "reading" and Opt("tooltips") ~= "off" then
		lines[#lines + 1] = NOTE_READING
	end
	local on = T.Ask(GetCVarBool, "externalDefensivesEnabled")
	if on == true then
		lines[#lines + 1] = LINE_FRAME
	end
	return lines
end

ns.Register(KEY, {
	label = "Defensives on you",
	counted = false,
	Start = D.Start,
	Refresh = D.Refresh,
	Resized = D.Refresh,
	events = {
		PLAYER_ENTERING_WORLD = function()
			D.Refresh()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = function(kind, state)
			D.OnRestriction(kind, state)
		end,
		EDIT_MODE_LAYOUTS_UPDATED = function()
			D.Refresh()
		end,
		SPELLS_CHANGED = function()
			D.QueueSounds()
		end,
	},
	slash = { check = D.Check, defensives = D.Slash, test = function(rest)
		if not (rest or ""):lower():match("^%s*icons%s*$") then
			print("/flatui test - samples of your hidden frames on screen until you turn it off; test on and test off also work")
			print("/flatui test icons - three sample icons for 8 seconds on Defensives on you, Your buffs, Party and Enemy cooldowns")
			return
		end
		D.Test()
		if ns.OwnBuffsTest then
			ns.OwnBuffsTest()
		end
		if ns.PartyTest then
			ns.PartyTest()
		end
		if ns.EnemyTest then
			ns.EnemyTest()
		end
	end },
	help = HELP,
	Status = D.Status,
})

TM.Register(KEY, {
	module = KEY,
	label = "Defensives on you",
	refresh = true,
	Stop = D.Drop,
	Tick = function(now)
		D.Tick(now)
	end,
})

ns.DefensivesModule = D
