local _, ns = ...

-- Absorb shields: a small stack of Flat UI bars for the shields on the player, in the manner of the NanShield display: a bar for the total of
-- every absorb on the player, and a bar for each listed shield (Power Word: Shield, Ice Barrier, Mana Shield, the wards, Sacrifice, protection
-- potions and items) with its icon, the amount it has left over its size, its time left and its name, in the colour of the one school it
-- takes. Nothing here comes from the WeakAura but the idea; the spell IDs, schools and lengths are Forever's own (CooldownData.lua,
-- tools/dev/spelltips/client_spells.json, SpellData.lua).
-- The total is UnitGetTotalAbsorbs, which the game always withholds from addon code (SecretReturns, UnitDocumentation.lua:1286-1299). It is
-- never read, compared or added: it goes as it is to SetValue of status bars (SimpleStatusBarAPIDocumentation.lua:355-363) and, through
-- C_StringUtil.TruncateWhenZero (ns.CombatWithheld), to SetText, which take it. So the bar has no test for zero: its backdrop, border and
-- icon are status bars of their own set from 0 to 1 and given the total too, full for any shield and empty at none, and the text of a zero is
-- empty. Its scale is the size of the shields Flat UI knows to be up (Total bar is full at: Your shields; with none known, the player's
-- health) or the player's health, given unread to SetMinMaxValues.
-- The bar of each shield is drawn from a read of the player's buffs (C_UnitAuras.GetUnitAuras): its amount is the first value of the aura
-- (points[1], WL structures.yaml AuraData), its size the largest plain amount read for that aura, else an estimate of the player's own
-- spell (SpellData.lua through ns.SpellModel.Find, with the spell power read out of a fight). That read works only while the game shows
-- buffs. While it hides them in a fight, one aura container of the game's own (CustomAuraContainerTemplate) draws the shields instead, as
-- Defensives on you does: one group of buttons for each school, so each button knows its colour, with the icon, the time and a bar the game
-- fills by the time left; the game gives no amount of a single shield then, so only the total bar has one. The container's alpha says which
-- of the two shows, a change allowed at any time; the parts of its buttons are made inside the function the game calls while it builds a
-- button, and a later change to them waits until the game says buffs are open. A shield that goes before its time while buffs are read,
-- and is still listed, broke: a sound plays, if chosen, and the bars flash. The target's total can have a bar of its own. Out of a fight the
-- totals follow the game's events; in one, a step a few times a second. While test mode is on (TestMode.lua) the sample bars of /flatui absorbs
-- test stay, with the target's (A.Hold). Every frame is Flat UI's own, and nothing of the game is changed or hooked. The helpers are in one
-- table, A.

local KEY = "absorbs"
local MOVER, MOVER_TARGET = "FlatUIAbsorbs", "FlatUIAbsorbsTarget"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SHIELD_ICON = "Interface\\Icons\\Spell_Holy_PowerWordShield"
local FONT = "GameFontHighlightSmall"
local CROP = 0.08
-- The most bars of single shields. A read is made at most this often; the time texts step, the total step, a test and a flash last so long.
local MOST = 6
local REREAD, STEP, TOTAL_STEP, TEST_TIME, FLASH = 0.2, 0.1, 0.25, 8, 0.4
-- A shield gone this long or more before its end broke; one gone later ran out. One read this soon after it was put on is read whole.
local EARLY, FRESH = 0.3, 1
-- School masks: every school, and physical (Mana Shield).
local ALL = 127
-- One group of the game's container for each mask, in this order, and the most buttons of each.
local GROUPS = { 127, 1, 4, 16, 32, 8, 64, 2 }
local GROUP_MOST = { [127] = 4 }
-- The colour of a school by its mask, as the game colours the schools of its combat log (CombatLogColors.lua:13-22); physical, which only
-- Mana Shield takes, is grey here.
local SCHOOL_RGB = { [1] = { 0.7, 0.7, 0.7 }, [2] = { 1, 0.9, 0.5 }, [4] = { 1, 0.5, 0 }, [8] = { 0.3, 1, 0.3 }, [16] = { 0.5, 1, 1 },
	[32] = { 0.5, 0.5, 1 }, [64] = { 1, 0.5, 1 } }
-- The opacity of the bar the game fills by the time left, in a fight, where it stands for a shield whose amount is withheld.
local TIME_ALPHA = 0.6
local FLASH_RGB = { 1, 0.15, 0.1, 0.55 }
local KITS = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }
-- The events of the totals, which the player's and the target's bars hear; out of a fight they and the reads of the buffs move the totals.
local TOTAL_EVENTS = { UNIT_ABSORB_AMOUNT_CHANGED = true, UNIT_MAXHEALTH = true }
-- The shields: the row of the page that lists them, the school mask, the length in seconds of the player's own cast (self: cast on the player
-- only, so a cast in a fight counts toward the size), a family (a new cast replaces the shield of its family) and the spell IDs of the aura,
-- rank 1 first (CooldownData.lua; Contingency Plan's shield auras from client_spells.json, whose rank 4 and 5 IDs are crossed).
local LIST = {
	{ "priest", 127, 30, "pws", { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 } },
	{ "priest", 127, 15, "cp", { 1277463, 1277464, 1277465, 1277467, 1277466 } },
	{ "mage", 127, 60, "ib", { 11426, 13031, 13032, 13033, 1213278 }, true },
	{ "mage", 1, 60, "ms", { 1463, 8494, 8495, 10191, 10192, 10193 }, true },
	{ "mage", 4, 30, "fw", { 543, 8457, 8458, 10223, 10225 }, true },
	{ "mage", 16, 30, "frw", { 6143, 8461, 8462, 10177, 28609 }, true },
	{ "mage", 1, 60, "ms+", { 412116, 412118, 412120, 412121, 412122, 412123 } },
	{ "mage", 16, 30, "frw+", { 412202, 412205, 412207, 412209, 412210 } },
	{ "mage", 4, 30, "fw+", { 412214, 412218, 412230, 412231, 412232 } },
	{ "warlock", 32, 30, "sw", { 6229, 11739, 11740, 28610 }, true },
	{ "warlock", 127, 30, "sac", { 7812, 19438, 19440, 19441, 19442, 19443 } },
	{ "potions", 4, 0, "p4", { 7233, 17543 } },
	{ "potions", 16, 0, "p16", { 7239, 17544 } },
	{ "potions", 8, 0, "p8", { 7254, 17546 } },
	{ "potions", 32, 0, "p32", { 7242, 17548 } },
	{ "potions", 2, 0, "p2", { 7245, 17545 } },
	{ "potions", 64, 0, "p64", { 17549 } },
	{ "items", 127, 0, "item", { 23506, 26470, 13234, 29506 } },
}
local MOST_ADDED, MAX_ID = 40, 2147483647
local LINE_TOTAL = "Absorb shields: this client has no UnitGetTotalAbsorbs, so there is no total bar."
local LINE_READ = "Absorb shields: each shield's amount shows while the game shows your buffs; while it hides them in a fight, each shield shows its time and the total bar the amount."
local LINE_NO_CONTAINER = "Absorb shields: the game made no aura container, so in a fight, while it hides your buffs, only the total bar shows."
local NOTE_REFUSED = "Absorb shields: the game refused the %s of its rows in a fight, so they show without it."
local HELP = {
	"/flatui absorbs test - sample bars of Absorb shields for a few seconds",
	"/flatui absorbs check - the amount, time and secrecy of each shield on you",
	"/flatui absorbs add 17 - the spell ID of a shield, or a shift-clicked spell",
	"/flatui absorbs remove 17 - a spell ID or a name",
	"/flatui absorbs list",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local Ask = T.Ask
-- rows: the bars of single shields. buttons: the parts of the container's buttons. known: by aura instance, the shields last read, with their
-- size, end and mask. casts: by family, the player's own shields cast while buffs were hidden. bonus: spell power read out of a fight.
local A = { rows = {}, buttons = {}, refused = {}, known = {}, casts = {}, bonus = {}, items = {}, loose = {}, acc = 0, accTotal = 0 }
local SHIELDS = {}
for _, entry in ipairs(LIST) do
	for _, id in ipairs(entry[5]) do
		SHIELDS[id] = { row = entry[1], mask = entry[2], secs = entry[3], family = entry[4], self = entry[6] == true }
	end
end

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

local function Number(key, default)
	local value = Opt(key)
	return ns.Finite(value) and value or default
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function First(value)
	if type(value) == "table" then
		return value[1]
	end
	return value
end

local function SpellName(id)
	local name = Ask(C_Spell and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

local function SpellIcon(id)
	local file = Ask(C_Spell and C_Spell.GetSpellTexture, id)
	return (Plain(file, "number") or Plain(file, "string")) and file or nil
end

-- The lists ------------------------------------------------------------------------------------------------------------------------------

-- The spell IDs added to the list and those taken off it, kept for the account: two maps by spell ID, whole numbers only.
function A.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.absorbs
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.absorbs = saved
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

-- The shields shown now: those of the rows that are on, and what was added, less what was taken off. A map by spell ID.
function A.Effective()
	local set, saved = {}, A.Saved()
	for id, info in pairs(SHIELDS) do
		if Opt(info.row) == true then
			set[id] = true
		end
	end
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

-- The mask of a shield: its school, or every school for one added by hand.
local function MaskOf(id)
	local info = SHIELDS[id]
	return info and info.mask or ALL
end

-- The shields shown now, by mask: one map of spell IDs for each group of the container.
function A.Masks()
	local masks = {}
	for _, mask in ipairs(GROUPS) do
		masks[mask] = {}
	end
	for id in pairs(A.Effective()) do
		local map = masks[MaskOf(id)] or masks[ALL]
		map[id] = true
	end
	return masks
end

local function ByName(rows)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	for _, row in ipairs(rows) do
		local subtext = Ask(C_Spell and C_Spell.GetSpellSubtext, row[1])
		if Plain(subtext, "string") and subtext ~= "" then
			row[2] = row[2] .. " (" .. subtext .. ")"
		end
	end
	return rows
end

-- The listed shields that are not shown now (a row that is off, or one taken off), by name.
function ns.AbsorbCandidates()
	local rows, set = {}, A.Effective()
	for id in pairs(SHIELDS) do
		if not set[id] then
			rows[#rows + 1] = { id, SpellName(id) or ("Spell " .. id) }
		end
	end
	return ByName(rows)
end

function ns.AbsorbListed()
	local rows = {}
	for id in pairs(A.Effective()) do
		rows[#rows + 1] = { id, SpellName(id) or ("Spell " .. id) }
	end
	return ByName(rows)
end

-- Both work in a fight and with the page off: they change what is saved, and the bars hear of it.
function ns.AbsorbAdd(id)
	local saved = A.Saved()
	if not (Whole(id) and SpellName(id)) then
		return false, ('No spell found for "%s".'):format(tostring(id))
	end
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if A.Effective()[id] then
		return false, ("%s is already listed."):format(SpellName(id))
	end
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	if saved.removed[id] then
		saved.removed[id] = nil
	elseif not SHIELDS[id] and count >= MOST_ADDED then
		return false, ("%d added spells is the most."):format(MOST_ADDED)
	end
	-- A shield of a row that is off is added by hand.
	if not A.Effective()[id] then
		saved.added[id] = true
	end
	A.ListsChanged()
	return true, ("Added %s."):format(SpellName(id))
end

function ns.AbsorbRemove(id)
	local saved = A.Saved()
	if not (Whole(id) and saved) or not A.Effective()[id] then
		return false, ("%s is not listed."):format(Whole(id) and (SpellName(id) or ("Spell " .. id)) or tostring(id))
	end
	saved.added[id] = nil
	if A.Effective()[id] then
		saved.removed[id] = true
	end
	A.ListsChanged()
	return true, ("Removed %s."):format(SpellName(id) or ("Spell " .. id))
end

function A.ListsChanged()
	if ns.Enabled(KEY) then
		A.Groups()
		A.Queue()
	end
end

-- Colours and pieces ---------------------------------------------------------------------------------------------------------------------

-- Red, green and blue of a shield by its mask: its school's with Colour by school on, else Shield colour.
function A.Colour(mask)
	local rgb = Opt("school") == true and SCHOOL_RGB[mask] or nil
	if rgb then
		return rgb[1], rgb[2], rgb[3]
	end
	return ns.Colour(KEY .. ".colour")
end

-- The bar texture of the page, or the flat one: a bar needs a texture to take a withheld value (HealthColour.lua:90-110).
function A.File()
	return ns.BarTexture(Opt("texture")) or WHITE
end

-- A piece of a bar: a texture, or for a bar that has to vanish at zero without a test, a status bar from 0 to 1 that is given the value.
function A.Piece(owner, presence, layer, sub, level, file)
	if presence then
		local bar = Own(CreateFrame("StatusBar", nil, owner))
		bar:SetStatusBarTexture(file or WHITE)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar:SetFrameLevel(owner:GetFrameLevel() + level)
		return bar
	end
	local texture = Own(owner:CreateTexture(nil, layer, nil, sub))
	if file then
		texture:SetTexture(file)
	end
	return texture
end

local function Tint(piece, r, g, b, a)
	if piece.SetStatusBarColor then
		piece:SetStatusBarColor(r, g, b, a)
	else
		piece:SetColorTexture(r, g, b, a)
	end
end

-- The four edges of the thin border, just inside a frame, in the border colour of the Flat UI page; none while borderless.
local function Edges(edges, frame, thick)
	edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(thick)
	edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(thick)
	edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -thick)
	edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, thick)
	edges[3]:SetWidth(thick)
	edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -thick)
	edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, thick)
	edges[4]:SetWidth(thick)
	local r, g, b = ns.BorderRGB()
	local a = ns.Borderless() and 0 or 1
	for _, edge in ipairs(edges) do
		Tint(edge, r, g, b, a)
	end
end

local function Backdrop(piece)
	local r, g, b = ns.Colour("general.backdrop")
	local alpha = ns.Get("general.backdropAlpha")
	Tint(piece, r, g, b, (ns.Finite(alpha) and alpha or 100) / 100)
end

local function TextHeight(height)
	return math.max(7, math.min(14, height - 4))
end

-- The places of the parts of a bar of height h with a border of thick: the icon square on the left, the fill right of it.
local function Inner(icon, bar, frame, h, thick)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", frame, "TOPLEFT", thick, -thick)
	icon:SetSize(math.max(1, h - 2 * thick), math.max(1, h - 2 * thick))
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", h, -thick)
	bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -thick, thick)
end

-- Flat UI's bars -------------------------------------------------------------------------------------------------------------------------

function A.Holder()
	if not A.holder then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		holder:SetFrameStrata("LOW")
		holder:SetSize(1, 1)
		holder:SetScript("OnUpdate", function(_, elapsed)
			ns.Try(KEY, A.OnUpdate, elapsed)
		end)
		A.holder = holder
		-- The flash lies on a frame above the bars, over the first of them.
		local over = Own(CreateFrame("Frame", nil, holder))
		over:SetFrameLevel(holder:GetFrameLevel() + 12)
		over:SetAllPoints(holder)
		local flash = Own(over:CreateTexture(nil, "OVERLAY", nil, 7))
		flash:SetColorTexture(FLASH_RGB[1], FLASH_RGB[2], FLASH_RGB[3], FLASH_RGB[4])
		flash:Hide()
		A.flash = flash
	end
	return A.holder
end

-- A bar: a backdrop, the icon, the fill, a thin strip of the time, the border, the name, the amount and the time. With presence the backdrop,
-- the icon and the border are status bars that a withheld total fills or empties (the total bars).
function A.NewRow(parent, presence)
	local frame = Own(CreateFrame("Frame", nil, parent))
	local row = { frame = frame, presence = presence, edges = {} }
	row.back = A.Piece(frame, presence, "BACKGROUND", -8, 0)
	row.back:SetAllPoints(frame)
	row.icon = A.Piece(frame, presence, "ARTWORK", 0, 2, SHIELD_ICON)
	if not presence then
		row.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	end
	local bar = Own(CreateFrame("StatusBar", nil, frame))
	bar:SetFrameLevel(frame:GetFrameLevel() + 2)
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	row.bar = bar
	local strip = Own(CreateFrame("StatusBar", nil, bar))
	strip:SetStatusBarTexture(WHITE)
	strip:SetStatusBarColor(1, 1, 1, 0.7)
	strip:SetMinMaxValues(0, 1)
	strip:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	strip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	strip:Hide()
	row.strip = strip
	local top = Own(CreateFrame("Frame", nil, frame))
	top:SetAllPoints(frame)
	top:SetFrameLevel(frame:GetFrameLevel() + 5)
	row.top = top
	for index = 1, 4 do
		row.edges[index] = A.Piece(top, presence, "OVERLAY", 6, 0)
		if presence and index > 2 then
			row.edges[index]:SetOrientation("VERTICAL")
		end
	end
	row.pieces = presence and { row.back, row.icon, row.edges[1], row.edges[2], row.edges[3], row.edges[4] } or nil
	for _, name in ipairs({ "name", "amount", "time" }) do
		local text = ns.OwnText(top, "OVERLAY", FONT)
		text:SetWordWrap(false)
		text:SetJustifyH(name == "time" and "RIGHT" or "LEFT")
		row[name] = text
	end
	row.time:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	row.name:SetPoint("LEFT", bar, "LEFT", 3, 0)
	row.name:SetPoint("RIGHT", row.time, "LEFT", -3, 0)
	return row
end

-- The look of a bar after a change of its size, the bar texture, the border or the text: its parts placed and painted.
function A.PaintRow(row, w, h)
	local thick = ns.Pixels(row.frame, ns.Get("general.thickness"))
	row.frame:SetSize(w, h)
	Inner(row.icon, row.bar, row.frame, h, thick)
	Edges(row.edges, row.frame, thick)
	Backdrop(row.back)
	local file = A.File()
	if row.file ~= file then
		if not pcall(row.bar.SetStatusBarTexture, row.bar, file) then
			row.bar:SetStatusBarTexture(WHITE)
		end
		row.file = file
	end
	row.strip:SetHeight(math.max(2, math.floor(h / 6)))
	local text = TextHeight(h)
	for _, name in ipairs({ "name", "amount", "time" }) do
		row[name]:SetTextHeight(text)
	end
	-- The amount is on the left; while the name shows, it is on the right, left of the time, and the name ends before it.
	row.amount:ClearAllPoints()
	row.name:ClearAllPoints()
	row.name:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
	if Opt("name") == true and not row.presence then
		if Opt("time") == true then
			row.amount:SetPoint("RIGHT", row.time, "LEFT", -3, 0)
		else
			row.amount:SetPoint("RIGHT", row.bar, "RIGHT", -3, 0)
		end
		row.name:SetPoint("RIGHT", row.amount, "LEFT", -3, 0)
	else
		row.amount:SetPoint("LEFT", row.bar, "LEFT", 3, 0)
		row.name:SetPoint("RIGHT", row.time, "LEFT", -3, 0)
	end
end

-- The total bar of the player, made once.
function A.Total()
	if not A.total then
		A.total = A.NewRow(A.Holder(), true)
		A.total.name:Hide()
	end
	return A.total
end

-- The bar of shield number index, made the first time it is needed.
function A.Row(index)
	local row = A.rows[index]
	if not row then
		row = A.NewRow(A.Holder(), false)
		row.frame:Hide()
		A.rows[index] = row
		A.laid = nil
	end
	return row
end

-- The slot of a bar from the edge of the box the bars grow from.
local function Put(frame, slot)
	local h, gap = Number("barHeight", 16), Number("spacing", 2)
	frame:ClearAllPoints()
	if Opt("grow") == "up" then
		frame:SetPoint("BOTTOMLEFT", A.holder, "BOTTOMLEFT", 0, slot * (h + gap))
	else
		frame:SetPoint("TOPLEFT", A.holder, "TOPLEFT", 0, -slot * (h + gap))
	end
end

-- The number of slots before the first shield: one while the total bar shows.
local function FirstSlot()
	return (Opt("show") == "shields" or type(UnitGetTotalAbsorbs) ~= "function") and 0 or 1
end

-- Places and paints every bar; a layout already in place is left as it is.
function A.Layout()
	local w, h = Number("barWidth", 180), Number("barHeight", 16)
	local parts = { w, h, Number("spacing", 2), Opt("grow"), Opt("show"), Opt("name"), A.File(), ns.Get("general.thickness"), ns.Get("general.border"),
		ns.Get("general.borderMode"), ns.Borderless(), ns.Get("general.backdrop"), ns.Get("general.backdropAlpha"), #A.rows, A.target ~= nil, Opt("time") }
	for index = 1, 16 do
		parts[index] = tostring(parts[index])
	end
	local key = table.concat(parts, ":")
	if A.laid == key then
		return
	end
	A.laid = key
	local holder = A.Holder()
	holder:SetSize(w, h)
	local total = A.Total()
	A.PaintRow(total, w, h)
	Put(total.frame, 0)
	total.frame:SetShown(Opt("show") ~= "shields" and type(UnitGetTotalAbsorbs) == "function")
	for index, row in ipairs(A.rows) do
		A.PaintRow(row, w, h)
		Put(row.frame, FirstSlot() + index - 1)
	end
	A.flash:ClearAllPoints()
	A.flash:SetSize(w, h)
	if Opt("grow") == "up" then
		A.flash:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	else
		A.flash:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	end
	if A.target then
		A.PaintRow(A.target, w, h)
		A.target.frame:GetParent():SetSize(w, h)
		A.target.frame:SetPoint("TOPLEFT", A.target.frame:GetParent(), "TOPLEFT", 0, 0)
	end
end

-- Hangs the bars, which are as wide as the holder, from the middle of the top of the box of the movers, or of its bottom while they grow up: so
-- they stay centred on the box at any Bar width.
function A.Place()
	local holder = A.Holder()
	local up = Opt("grow") == "up"
	local point = up and "BOTTOM" or "TOP"
	local x, y = ns.MoverSpot(MOVER, point)
	holder:ClearAllPoints()
	if x then
		holder:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
	else
		holder:SetPoint(point, UIParent, "CENTER", 0, up and -231 or -179)
	end
end

-- The writing of a bar -------------------------------------------------------------------------------------------------------------------

-- The amount of a bar as Amount says: digits, or digits and the size. A withheld amount is written by the client and is empty at zero.
function A.WriteAmount(text, value, size)
	local mode = Opt("amount")
	local after = mode == "leftmax" and ns.Finite(size) and size > 0 and (" / %d"):format(math.floor(size + 0.5)) or nil
	if mode == "none" or value == nil then
		text:SetText("")
	elseif ns.Finite(value) then
		text:SetText(value >= 1 and (("%d"):format(math.floor(value + 0.5)) .. (after or "")) or "")
	else
		local ok, written = false, nil
		if type(ns.CombatWithheld) == "function" then
			ok, written = ns.CombatWithheld(value, nil, after)
		end
		if not (ok and pcall(text.SetText, text, written)) then
			text:SetText("")
		end
	end
end

local function Seconds(left)
	if left >= 60 then
		return ("%dm"):format(math.ceil(left / 60))
	elseif left >= 3 then
		return ("%d"):format(math.floor(left))
	end
	return ("%.1f"):format(math.max(0, left))
end

-- One shield on a bar: plain fields only, but the amount may be withheld, and goes to the bar and the text unread.
function A.Fill(row, item)
	row.icon:SetTexture(item.file or SHIELD_ICON)
	local r, g, b = A.Colour(item.mask)
	-- An aura with no amount at all is a full, fainter bar: it is up, by how much is not known.
	row.bar:SetStatusBarColor(r, g, b, item.amount == nil and TIME_ALPHA or 1)
	local size = item.size
	if item.amount == nil then
		row.bar:SetMinMaxValues(0, 1)
		row.bar:SetValue(1)
	elseif ns.Finite(size) and size > 0 then
		row.bar:SetMinMaxValues(0, size)
	elseif not pcall(row.bar.SetMinMaxValues, row.bar, 0, item.amount) then
		row.bar:SetMinMaxValues(0, 1)
	end
	if item.amount ~= nil and not pcall(row.bar.SetValue, row.bar, item.amount) then
		row.bar:SetValue(0)
	end
	A.WriteAmount(row.amount, item.amount, size)
	row.name:SetText(Opt("name") == true and item.name or "")
	row.name:SetShown(Opt("name") == true)
	local timed = item.expires > 0 and item.length > 0
	row.time:SetShown(Opt("time") == true and timed)
	row.strip:SetShown(Opt("timeStrip") == true and timed)
	if timed then
		row.strip:SetMinMaxValues(0, item.length)
	end
	A.Clock(row, item)
end

-- The time left on a bar, and on its strip.
function A.Clock(row, item)
	if item.expires <= 0 then
		row.time:SetText("")
		return
	end
	local left = item.expires - Now()
	row.time:SetText(Seconds(left))
	row.strip:SetValue(math.max(0, left))
	return left
end

-- The bars of the shields of a list, newest first, and the rest hidden.
function A.DrawRows(list)
	local n = 0
	if list and Opt("show") ~= "total" then
		n = math.min(#list, MOST)
		for index = 1, n do
			local row = A.Row(index)
			A.Layout()
			A.Fill(row, list[index])
			row.frame:Show()
		end
	end
	for index = n + 1, #A.rows do
		A.rows[index].frame:Hide()
	end
	A.items = list or {}
end

-- Gives a withheld total to the pieces that show the bar at all.
local function Present(row, value)
	for _, piece in ipairs(row.pieces) do
		if not pcall(piece.SetValue, piece, value) then
			piece:SetValue(0)
		end
	end
end

-- The size of the shields known to be up and their masks: those last read, and the player's own cast while buffs were hidden. A shield that
-- broke while hidden counts until its end.
function A.Known()
	local now, sum, masks, families = Now(), 0, {}, {}
	for _, item in pairs(A.known) do
		if item.expires <= 0 or item.expires > now then
			if ns.Finite(item.size) then
				sum = sum + item.size
			end
			masks[item.mask] = true
			if item.family then
				families[item.family] = true
			end
		end
	end
	for family, cast in pairs(A.casts) do
		if cast.expires > now and not families[family] then
			sum = sum + cast.size
			masks[cast.mask] = true
		end
	end
	return sum, masks
end

-- The top of the total bar: the size of the shields known to be up, or the player's health (withheld, unread). The second answer is that
-- size when it is one.
function A.Scale(unit)
	if unit == "player" and Opt("scale") ~= "health" then
		local sum = A.Known()
		if sum > 0 then
			return sum, sum
		end
	end
	local ok, most = pcall(UnitHealthMax, unit)
	if ok and (IsSecret(most) or (ns.Finite(most) and most > 0)) then
		return most, nil
	end
	return 1, nil
end

-- Writes a total bar from the game's total of a unit, never read: the presence pieces, the fill and the text.
function A.WriteTotal(row, unit)
	local ok, total = false, nil
	if type(UnitGetTotalAbsorbs) == "function" and (unit == "player" or Ask(UnitExists, unit) == true) then
		ok, total = pcall(UnitGetTotalAbsorbs, unit)
	end
	if not ok or total == nil then
		total = 0
	end
	Present(row, total)
	local most, size = A.Scale(unit)
	if not pcall(row.bar.SetMinMaxValues, row.bar, 0, most) then
		row.bar:SetMinMaxValues(0, 1)
	end
	if not pcall(row.bar.SetValue, row.bar, total) then
		row.bar:SetValue(0)
	end
	A.WriteAmount(row.amount, total, size)
	-- The colour of the one school every known shield takes, else Shield colour.
	local mask = nil
	if unit == "player" then
		local _, masks = A.Known()
		for each in pairs(masks) do
			mask = mask == nil and each or (mask == each and mask or ALL)
		end
	end
	local r, g, b = A.Colour(mask or ALL)
	row.bar:SetStatusBarColor(r, g, b, 1)
end

function A.Totals()
	if A.sample or A.held then
		return
	end
	if A.total and A.total.frame:IsShown() then
		A.WriteTotal(A.total, "player")
	end
	if A.target and Opt("target") == true then
		A.WriteTotal(A.target, "target")
	end
end

-- The bars flash red once and the sound plays, when a shield broke.
function A.Broke()
	local sound = KITS[Opt("sound")]
	local kit = sound and ns.SOUNDS and ns.SOUNDS[sound]
	if kit and type(ns.PlayKit) == "function" then
		ns.PlayKit(kit[1], KEY)
	end
	A.flash:Show()
	local token = {}
	A.flashing = token
	if not After(FLASH, function()
		if A.flashing == token then
			A.flash:Hide()
		end
	end) then
		A.flash:Hide()
	end
end

-- The target's total bar ------------------------------------------------------------------------------------------------------------------

function A.TargetBar()
	if not A.target then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		holder:SetFrameStrata("LOW")
		holder:SetSize(1, 1)
		A.target = A.NewRow(holder, true)
		A.target.name:Hide()
		A.laid = nil
	end
	return A.target
end

function A.PlaceTarget()
	if not A.target then
		return
	end
	-- The target's bar, as big as its holder, is centred on its box at any Bar width and height.
	local holder = A.target.frame:GetParent()
	local x, y = ns.MoverSpot(MOVER_TARGET, "CENTER")
	holder:ClearAllPoints()
	if x then
		holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	else
		holder:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
	end
end

-- Reading the player's buffs ---------------------------------------------------------------------------------------------------------------

-- The listed shields on the player from one read, plain tables only: nil when the game hides buffs or gives no answer.
function A.Read()
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
	local set, found = A.Effective(), {}
	for _, aura in ipairs(auras) do
		if type(aura) == "table" and not IsSecret(aura) then
			local read, id, instance, expires, length, file, name, points, source = pcall(function()
				return aura.spellId, aura.auraInstanceID, aura.expirationTime, aura.duration, aura.icon, aura.name, aura.points, aura.sourceUnit
			end)
			if read and Plain(id, "number") and set[id] and Plain(instance, "number") then
				local amount = nil
				if type(points) == "table" and not IsSecret(points) then
					local okPoint, value = pcall(function()
						return points[1]
					end)
					amount = okPoint and value or nil
				end
				found[#found + 1] = { id = id, instance = instance, amount = amount, mask = MaskOf(id),
					expires = ns.Finite(expires) and expires or 0, length = ns.Finite(length) and length or 0,
					file = (Plain(file, "number") or Plain(file, "string")) and file or SpellIcon(id),
					name = Plain(name, "string") and name or SpellName(id), mine = Plain(source, "string") and source == "player" }
			end
		end
	end
	return found
end

-- The order of the bars: by the order of the groups (every school first), then the newest first.
local ORDER = {}
for index, mask in ipairs(GROUPS) do
	ORDER[mask] = index
end

-- True when a shield was put on just now, so what is read of it is the whole of it.
local function Fresh(item, now)
	return item.expires > 0 and item.length > 0 and now - (item.expires - item.length) < FRESH
end

-- The size of a shield first read: the largest plain amount, or the estimate of the player's own cast while buffs were hidden, or, unless it
-- was put on just now, the estimate of the player's own spell, whichever is larger. So a shield cast in a fight, or first seen after a reload,
-- is not sized at what it has left.
function A.FirstSize(item, size, now)
	local info = SHIELDS[item.id]
	local cast = info and A.casts[info.family]
	local guess = cast and cast.expires > now and cast.size or nil
	if not guess and item.mine and (not ns.Finite(size) or not Fresh(item, now)) then
		guess = A.Estimate(item.id)
	end
	if ns.Finite(guess) and (not ns.Finite(size) or guess > size) then
		return guess
	end
	return size
end

-- The sizes of what was read, the shields that broke since the last read, and what is known now.
function A.Track(found)
	local now, was, seen, families, set = Now(), A.known, {}, {}, A.Effective()
	for _, item in ipairs(found) do
		local old = was[item.instance]
		local size = old and old.size or nil
		if ns.Finite(item.amount) and (not ns.Finite(size) or item.amount > size) then
			size = item.amount
		end
		if not old then
			size = A.FirstSize(item, size, now)
		end
		item.size = size
		local info = SHIELDS[item.id]
		seen[item.instance] = { id = item.id, size = size, expires = item.expires, mask = item.mask, family = info and info.family }
		if info then
			families[info.family] = true
		end
	end
	-- A shield that a new one of its family replaced did not break, nor one no longer listed.
	if A.wasRead and Ask(UnitIsDeadOrGhost, "player") ~= true then
		for instance, old in pairs(was) do
			if not seen[instance] and set[old.id] and not (old.family and families[old.family]) and (old.expires <= 0 or now < old.expires - EARLY) then
				A.Broke()
				break
			end
		end
	end
	A.known, A.casts, A.wasRead = seen, {}, true
	table.sort(found, function(a, b)
		local first, second = ORDER[a.mask] or 1, ORDER[b.mask] or 1
		if first ~= second then
			return first < second
		end
		return a.instance > b.instance
	end)
end

-- One pass: a read where the game shows buffs, and Flat UI's bars of the shields from it; else the game's rows.
function A.Pass()
	A.scheduled = false
	if not ns.Enabled(KEY) or A.sample or A.held then
		return
	end
	A.wasOpen = T.Open()
	local found = A.Read()
	A.open = found ~= nil
	if found then
		A.Track(found)
		A.Flush()
		A.ReadBonus()
	else
		A.wasRead = false
	end
	A.DrawRows(found)
	A.ShowContainer(found == nil)
	A.Totals()
end

function A.Queue()
	if A.scheduled then
		return
	end
	A.scheduled = true
	if not After(REREAD, function()
		ns.Try(KEY, A.Pass)
	end) then
		A.Pass()
	end
end

-- The step of the bars: the time texts, and a few times a second the totals and whether the game shows buffs now. Out of a fight, while the
-- game shows buffs and no cast in a fight still counts, the events say every change of the totals, and the step leaves them. A sample held by
-- test mode starts its time again when it runs out, and keeps its time left while Moving is off on the bar of test mode.
function A.OnUpdate(elapsed)
	if not Plain(elapsed, "number") then
		return
	end
	A.acc, A.accTotal = A.acc + elapsed, A.accTotal + elapsed
	if A.acc >= STEP then
		local mode = ns.TestMode
		local still = A.held and mode and not mode.Moving() and A.acc or 0
		A.acc = 0
		for index, item in ipairs(A.items) do
			local row = A.rows[index]
			if row and row.frame:IsShown() then
				if still > 0 and item.expires > 0 then
					item.expires = item.expires + still
				end
				local left = A.Clock(row, item)
				if left and left <= 0 then
					if A.held then
						item.expires = Now() + item.length
						A.Clock(row, item)
					elseif not A.sample then
						A.Queue()
					end
				end
			end
		end
	end
	if A.accTotal >= TOTAL_STEP then
		A.accTotal = 0
		if InCombatLockdown() or not A.wasOpen or next(A.casts) ~= nil then
			A.Totals()
			if not (A.sample or A.held) and T.Open() ~= A.wasOpen then
				A.Queue()
			end
		end
	end
end

-- Sizes the game does not give --------------------------------------------------------------------------------------------------------------

-- Spell healing and spell damage by school, read while the game gives them plain (out of a fight), for the estimates.
function A.ReadBonus()
	local heal = Ask(GetSpellBonusHealing)
	if ns.Finite(heal) then
		A.bonus.heal = heal
	end
	for school = 2, 7 do
		local value = Ask(GetSpellBonusDamage, school)
		if ns.Finite(value) then
			A.bonus[school] = value
		end
	end
end

-- The size of a shield of the player's own class at the player's level and spell power, from SpellData.lua: the base of the rank, its gain a
-- level up to its last level, and the share of spell power or healing. The talents that raise a shield are not in the data, so it can be low.
function A.Estimate(id)
	local model = ns.SpellModel
	if type(model) ~= "table" or type(model.Find) ~= "function" then
		return nil
	end
	local ok, entry, place = pcall(model.Find, id)
	local rank = ok and type(entry) == "table" and type(entry.ranks) == "table" and entry.ranks[place] or nil
	if type(rank) ~= "table" or not ns.Finite(First(rank.bm)) then
		return nil
	end
	local size = First(rank.bm)
	local level, gain, top, from = Ask(UnitLevel, "player"), First(rank.bl), First(rank.mx), First(rank.lv) or rank[2]
	if ns.Finite(level) and ns.Finite(gain) and ns.Finite(top) and top > 0 and ns.Finite(from) then
		size = size + gain * math.max(0, math.min(level, top) - from)
	end
	local part = type(entry.parts) == "table" and entry.parts[1] or nil
	if type(part) == "table" then
		local share = First(rank.c) or part[2]
		local bonus = nil
		if part[1] == "heal" then
			bonus = A.bonus.heal
		elseif part[1] == "sp" then
			bonus = A.bonus[part.sch or entry.school]
		end
		if ns.Finite(share) and ns.Finite(bonus) then
			size = size + share * bonus
		end
	end
	return math.floor(size + 0.5)
end

-- The player cast a shield on themself while buffs are hidden: its estimate counts toward the size of the total until its end, and replaces
-- the shield of its family.
function A.OnCast(spellID)
	local info = Plain(spellID, "number") and SHIELDS[spellID] or nil
	if not (info and info.self) or A.open then
		return
	end
	local size = A.Estimate(spellID)
	if not size then
		return
	end
	for instance, old in pairs(A.known) do
		if old.family == info.family then
			A.known[instance] = nil
		end
	end
	A.casts[info.family] = { size = size, expires = Now() + info.secs, mask = info.mask }
	A.Totals()
end

-- The game's rows in a fight -----------------------------------------------------------------------------------------------------------

-- The options of a bar filled by the time left (SimpleStatusBarConstantsDocumentation.lua), as Your buffs has them.
local function BarOptions()
	local direction = type(Enum) == "table" and type(Enum.StatusBarTimerDirection) == "table" and Enum.StatusBarTimerDirection.RemainingTime
	local interpolation = type(Enum) == "table" and type(Enum.StatusBarInterpolation) == "table" and Enum.StatusBarInterpolation.Immediate
	return { interpolation = interpolation or 0, direction = direction or 1 }
end

-- Places and paints the parts of one button of the container. Raises where the game refuses; the callers catch it.
function A.PaintButton(parts)
	local button = parts.button
	local w, h = Number("barWidth", 180), Number("barHeight", 16)
	button:SetSize(w, h)
	local thick = ns.Pixels(A.Holder(), ns.Get("general.thickness"))
	if parts.back then
		Backdrop(parts.back)
	end
	if parts.icon and parts.bar then
		Inner(parts.icon, parts.bar, button, h, thick)
	end
	if parts.bar then
		local file = A.File()
		if parts.file ~= file then
			parts.bar:SetStatusBarTexture(file)
			parts.file = file
		end
		local r, g, b = A.Colour(parts.mask)
		parts.bar:SetStatusBarColor(r, g, b, TIME_ALPHA)
	end
	if parts.edges then
		Edges(parts.edges, button, thick)
	end
	local text = TextHeight(h)
	if parts.time then
		parts.time:SetTextHeight(text)
	end
	if parts.name then
		parts.name:SetTextHeight(text)
	end
end

-- Binds the time text or the name of a button to the game, or takes it back, as Time left and Spell name say.
function A.BindText(parts, kind)
	local want, button, text = Opt(kind) == true, parts.button, parts[kind]
	if not text or parts[kind .. "On"] == want then
		return
	end
	if want then
		text:Show()
		if kind == "time" then
			button:SetDurationText(text, nil)
		else
			button:SetSpellName(text)
		end
	else
		if kind == "time" then
			button:ClearDurationText()
		else
			button:ClearSpellName()
		end
		text:SetText("")
		text:Hide()
	end
	parts[kind .. "On"] = want
end

-- The name of a button ends left of its time, or of its edge, so a long one is cut short as on Flat UI's bars.
function A.NameEnd(parts, text)
	if parts.time then
		text:SetPoint("RIGHT", parts.time, "LEFT", -3, 0)
	else
		text:SetPoint("RIGHT", parts.button, "RIGHT", -3, 0)
	end
end

-- Makes the parts of one button. Run by the game inside AddAuraGroup while the button is still open; nothing here may raise, and a part the
-- game refuses is left out and named in the status.
function A.Init(button, mask)
	local parts = { button = button, mask = mask }
	A.buttons[#A.buttons + 1] = parts
	pcall(button.EnableMouse, button, false)
	pcall(button.SetHideTooltipInCombat, button, true)
	local function Part(name, fn)
		if not pcall(fn) then
			A.refused[name] = true
		end
	end
	Part("backdrop", function()
		local back = Own(button:CreateTexture(nil, "BACKGROUND", nil, -8))
		back:SetAllPoints()
		parts.back = back
	end)
	Part("icon", function()
		local icon = Own(button:CreateTexture(nil, "ARTWORK", nil, 0))
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		button:SetIcon(icon)
		parts.icon = icon
	end)
	Part("time bar", function()
		local bar = Own(CreateFrame("StatusBar", nil, button))
		bar:SetStatusBarTexture(A.File())
		bar:SetMinMaxValues(0, 1)
		parts.bar = bar
		button:SetDurationBar(bar, BarOptions())
	end)
	local made, top = pcall(function()
		local frame = Own(CreateFrame("Frame", nil, button))
		frame:SetAllPoints()
		frame:SetFrameLevel(button:GetFrameLevel() + 5)
		return frame
	end)
	if made then
		Part("time", function()
			local text = Own(top:CreateFontString(nil, "OVERLAY", FONT))
			text:SetPoint("RIGHT", button, "RIGHT", -3, 0)
			parts.time = text
			parts.timeOn = false
			text:Hide()
			A.BindText(parts, "time")
		end)
		Part("name", function()
			local text = Own(top:CreateFontString(nil, "OVERLAY", FONT))
			text:SetWordWrap(false)
			text:SetJustifyH("LEFT")
			text:SetPoint("LEFT", button, "LEFT", Number("barHeight", 16) + 3, 0)
			A.NameEnd(parts, text)
			parts.name = text
			parts.nameOn = false
			text:Hide()
			A.BindText(parts, "name")
		end)
		Part("border", function()
			local edges = {}
			for index = 1, 4 do
				edges[index] = Own(top:CreateTexture(nil, "OVERLAY", nil, 6))
			end
			parts.edges = edges
		end)
	else
		A.refused.time, A.refused.name, A.refused.border = true, true, true
	end
	if not pcall(A.PaintButton, parts) then
		A.refused.size = true
	end
end

function A.InitCall(button, mask)
	local ok, err = pcall(A.Init, button, mask)
	if not ok then
		A.refused.icon = true
		A.failure = tostring(err)
	end
end

-- The changes to the buttons wait until the game says buffs are open, as Defensives on you has it.
function A.Flush()
	if not A.waiting or not T.Open() then
		return
	end
	A.waiting = false
	for _, parts in ipairs(A.buttons) do
		pcall(A.PaintButton, parts)
		if not pcall(A.BindText, parts, "time") then
			A.refused.time = true
		end
		if not pcall(A.BindText, parts, "name") then
			A.refused.name = true
		end
		if parts.name then
			pcall(parts.name.SetPoint, parts.name, "LEFT", parts.button, "LEFT", Number("barHeight", 16) + 3, 0)
			pcall(A.NameEnd, parts, parts.name)
		end
	end
end

-- The layout of each group: one column of bars of the size of Flat UI's, in the order of GROUPS. The spacing after a group's last bar already
-- parts it from the next group (AnchorUtil.lua:684-727), so groups add none, and the bars are as far apart as Flat UI's.
local function GroupLayout(index)
	local gap = Number("spacing", 2)
	return { elementSpacing = gap, groupSpacing = 0, elementWidth = Number("barWidth", 180), elementHeight = Number("barHeight", 16), layoutIndex = index }
end

-- The column grows down from the top left corner, or up from the bottom left corner (AnchorUtil.lua:465-477).
function A.Flow()
	local container = A.container
	local util = type(AnchorUtil) == "table" and AnchorUtil or {}
	local axis, direction = util.FlowLayoutAxis or {}, util.FlowDirection or {}
	local up = Opt("grow") == "up"
	pcall(container.SetFlowLayoutAxis, container, axis.Vertical or 1)
	pcall(container.SetFlowLayoutAnchorPoint, container, up and "BOTTOMLEFT" or "TOPLEFT")
	pcall(container.SetFlowLayoutGrowthDirection, container, direction.Right or 1, up and (direction.Up or 1) or (direction.Down or -1))
end

-- One container for the player, out of combat, with one group for each school: the newest shield first in each.
function A.Build()
	A.tried = true
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, A.Holder(), "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		return
	end
	Own(container)
	local masks = A.Masks()
	local method = type(AuraContainerSortMethod) == "table" and AuraContainerSortMethod.AuraInstanceIDOnly or nil
	local direction = type(AuraContainerSortDirection) == "table" and AuraContainerSortDirection.Reverse or nil
	local made, err = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetAlpha(0)
		for index, mask in ipairs(GROUPS) do
			local options = { candidateFilters = { includeSpellIDs = masks[mask] }, maxFrameCount = GROUP_MOST[mask] or 2, layout = GroupLayout(index),
				initializeFrame = function(button)
					A.InitCall(button, mask)
				end }
			if method and direction then
				options.sortMethod, options.sortDirection = method, direction
			end
			container:AddAuraGroup("m" .. mask, "HELPFUL", options)
		end
	end)
	if not made then
		A.failure = tostring(err)
		for _, mask in ipairs(GROUPS) do
			pcall(container.SetAuraGroupEnabled, container, "m" .. mask, false)
		end
		return
	end
	A.container = container
	A.Flow()
end

-- The container under the total bar, or over it while the bars grow up. Out of combat.
function A.PlaceContainer()
	local container = A.container
	if not container then
		return
	end
	local h, gap = Number("barHeight", 16), Number("spacing", 2)
	local offset = FirstSlot() * (h + gap)
	pcall(container.ClearAllPoints, container)
	if Opt("grow") == "up" then
		pcall(container.SetPoint, container, "BOTTOMLEFT", A.holder, "BOTTOMLEFT", 0, offset)
	else
		pcall(container.SetPoint, container, "TOPLEFT", A.holder, "TOPLEFT", 0, -offset)
	end
	A.Flow()
end

-- Each group's spell IDs and layout again, and on while it has a spell and the page shows shields. Container calls, allowed at any time.
function A.Groups()
	local container = A.container
	if not container then
		return
	end
	local on = ns.Enabled(KEY) and Opt("show") ~= "total"
	local masks = A.Masks()
	for index, mask in ipairs(GROUPS) do
		local group = "m" .. mask
		pcall(container.SetAuraGroupCandidateFilters, container, group, { includeSpellIDs = masks[mask] })
		pcall(container.SetAuraGroupLayout, container, group, GroupLayout(index))
		pcall(container.SetAuraGroupEnabled, container, group, on and next(masks[mask]) ~= nil)
	end
end

-- The game's rows show while Flat UI's cannot: its alpha, a container call allowed at any time.
function A.ShowContainer(show)
	if A.container then
		pcall(A.container.SetAlpha, A.container, show and Opt("show") ~= "total" and 1 or 0)
	end
end

-- Putting it in place --------------------------------------------------------------------------------------------------------------------

function A.Listen(on)
	if not A.watcher then
		local frame = Own(CreateFrame("Frame"))
		-- The payload of the auras and of the total is not read: the game may withhold it. A cast's spell ID is read only where it is plain.
		frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
			-- Where the game would not give the event for the player (and the target) alone, the others are left out by a plain unit.
			if A.loose[event] then
				local plain = Plain(unit, "string")
				if TOTAL_EVENTS[event] then
					if plain and unit ~= "player" and unit ~= "target" then
						return
					end
				elseif not (plain and unit == "player") then
					return
				end
			end
			if event == "UNIT_AURA" then
				A.Queue()
			elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
				ns.Try(KEY, A.OnCast, spellID)
			else
				ns.Try(KEY, A.Totals)
			end
		end)
		A.watcher = frame
	end
	local frame = A.watcher
	pcall(frame.UnregisterAllEvents, frame)
	if not on then
		return
	end
	A.loose = {}
	for _, event in ipairs({ "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" }) do
		local ok = false
		if frame.RegisterUnitEvent ~= nil then
			if TOTAL_EVENTS[event] and Opt("target") == true then
				ok = pcall(frame.RegisterUnitEvent, frame, event, "player", "target")
			else
				ok = pcall(frame.RegisterUnitEvent, frame, event, "player")
			end
		end
		if not ok then
			A.loose[event] = true
			pcall(frame.RegisterEvent, frame, event)
		end
	end
end

-- Switched off, Flat UI forgets what it read, so a shield that ends meanwhile is not taken for broken when it is on again.
function A.Off()
	A.sample, A.held, A.heldList = nil, nil, nil
	A.known, A.casts, A.wasRead = {}, {}, false
	A.Listen(false)
	if A.holder then
		A.holder:Hide()
	end
	if A.target then
		A.target.frame:GetParent():Hide()
	end
	if A.container then
		A.ShowContainer(false)
		for _, mask in ipairs(GROUPS) do
			pcall(A.container.SetAuraGroupEnabled, A.container, "m" .. mask, false)
		end
	end
end

function A.Refresh()
	if not ns.Enabled(KEY) then
		A.Off()
		return
	end
	A.laid = nil
	A.Holder():Show()
	if Opt("target") == true then
		A.TargetBar().frame:GetParent():Show()
		A.target.frame:Show()
	elseif A.target then
		A.target.frame:GetParent():Hide()
	end
	A.Layout()
	A.Place()
	A.PlaceTarget()
	A.Listen(true)
	A.waiting = true
	ns.OutOfCombat(function()
		if not ns.Enabled(KEY) then
			return
		end
		if not A.tried then
			A.Build()
		end
		A.PlaceContainer()
		A.Groups()
		A.Flush()
		A.Pass()
	end)
	if not A.Hold() then
		A.Pass()
	end
end

-- True while the bars have a handle in the movers: while the page is on; the target's while its row is on too.
function ns.AbsorbsShown()
	return ns.Enabled(KEY)
end

function ns.AbsorbsTargetShown()
	return ns.Enabled(KEY) and Opt("target") == true
end

-- The movers set or put back a spot.
function ns.AbsorbsMoved()
	if A.holder and ns.Enabled(KEY) then
		ns.Try(KEY, A.Place)
		ns.Try(KEY, A.PlaceTarget)
	end
end

-- The test, the check and the commands --------------------------------------------------------------------------------------------------

-- The sample shields: a Power Word: Shield partly used and a whole Fire Ward.
local function SampleList(now)
	return {
		{ id = 17, amount = 612, size = 942, mask = ALL, expires = now + 23, length = 30, file = SpellIcon(17), name = SpellName(17) or "Power Word: Shield" },
		{ id = 543, amount = 913, size = 913, mask = 4, expires = now + 18, length = 30, file = SpellIcon(543), name = SpellName(543) or "Fire Ward" },
	}
end

-- A sample on a total bar: amount of most, in Shield colour, its size written after it as Amount says when size is given.
local function SampleTotal(row, amount, most, size)
	Present(row, 1)
	row.bar:SetMinMaxValues(0, most)
	row.bar:SetValue(amount)
	row.bar:SetStatusBarColor(A.Colour(ALL))
	A.WriteAmount(row.amount, amount, size)
end

-- Test mode (TestMode.lua): while it is on (it pauses in a fight) with the page on, the samples of the test stay, with no end and no line in the
-- chat, and the target's bar has one too (640 of a health of 2400) while Your target's total is on. A.held keeps the reads (A.Pass) and the totals
-- off them. Each Refresh (On, resume, the page coming on, a change of most of its rows) and every change of a setting after it (TestMode.lua's
-- Changed) draws them again with the look of the page; their times run on from where they were. A.Drop forgets them at Off, at the pause for a
-- fight and when the page goes off, and the Refresh that test mode runs at Off and at the pause draws the real bars at once.
function A.Holding()
	local mode = ns.TestMode
	return mode ~= nil and mode.IsOn() == true and ns.Enabled(KEY)
end

-- Draws the samples of test mode while it holds them, else forgets them; true while they show.
function A.Hold()
	if not A.Holding() then
		A.held, A.heldList = nil, nil
		return false
	end
	A.held = true
	A.heldList = A.heldList or SampleList(Now())
	A.ShowContainer(false)
	A.Layout()
	A.DrawRows(A.heldList)
	local total = A.total
	if total and total.frame:IsShown() then
		SampleTotal(total, 1525, 1855, 1855)
	end
	if A.target and Opt("target") == true then
		SampleTotal(A.target, 640, 2400, nil)
	end
	return true
end

-- The samples of test mode go, and those of the test with them.
function A.Drop()
	A.held, A.heldList, A.sample = nil, nil, nil
end

-- Sample bars for a few seconds: the sample shields and their total.
function A.Test()
	if not ns.Enabled(KEY) then
		print("Absorb shields: turn on Absorb shields first.")
		return
	end
	A.Refresh()
	local token = {}
	A.sample = token
	A.ShowContainer(false)
	A.DrawRows(SampleList(Now()))
	local total = A.total
	if total and total.frame:IsShown() then
		SampleTotal(total, 1525, 1855, 1855)
	end
	print("Absorb shields: sample bars for 8 seconds.")
	if not After(TEST_TIME, function()
		if A.sample == token then
			A.sample = nil
			ns.Try(KEY, A.Pass)
		end
	end) then
		A.sample = nil
	end
end

-- What the game gives of each listed shield on the player: its amount, its end and whether the game hides its aura.
function A.Check()
	print(("Absorb shields: %s."):format(T.Open() and "the game shows your buffs now" or "the game hides your buffs now, so only the total bar has an amount"))
	local found = A.Read()
	if not found then
		return
	end
	if #found == 0 then
		print("No listed shield on you.")
	end
	local now = Now()
	for _, item in ipairs(found) do
		local amount = ns.Finite(item.amount) and ("%d"):format(item.amount) or (item.amount == nil and "none" or "withheld")
		local left = item.expires > 0 and ("%.1f s left"):format(item.expires - now) or "no end"
		local level = Ask(type(C_Secrets) == "table" and C_Secrets.GetSpellAuraSecrecy or nil, item.id)
		local known = A.known[item.instance]
		print(("%s (%d): amount %s, size %s, %s, secrecy %s."):format(item.name or "?", item.id, amount,
			known and ns.Finite(known.size) and ("%d"):format(known.size) or "unknown", left, Plain(level, "number") and tostring(level) or "unknown"))
	end
end

local function ParseID(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

function A.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "test" then
		A.Test()
	elseif word == "check" then
		A.Check()
	elseif word == "add" and text ~= "" then
		local id = ParseID(text)
		print(id and select(2, ns.AbsorbAdd(id)) or ('No spell found for "%s".'):format(text))
	elseif word == "remove" and text ~= "" then
		local id, wanted, done = ParseID(text), text:lower(), false
		for listed in pairs(A.Effective()) do
			local name = SpellName(listed)
			if listed == id or (not id and name and name:lower() == wanted) then
				print(select(2, ns.AbsorbRemove(listed)))
				done = true
			end
		end
		if not done then
			print(('No listed shield found for "%s".'):format(text))
		end
	elseif word == "list" then
		local names, order = {}, {}
		for _, row in ipairs(ns.AbsorbListed()) do
			local name = SpellName(row[1]) or row[2]
			if not names[name] then
				names[name] = {}
				order[#order + 1] = name
			end
			table.insert(names[name], row[1])
		end
		if #order == 0 then
			print("No shields listed.")
		end
		for _, name in ipairs(order) do
			table.sort(names[name])
			print(("%s (%s)"):format(name, table.concat(names[name], ", ")))
		end
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

function A.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if type(UnitGetTotalAbsorbs) ~= "function" then
		lines[#lines + 1] = LINE_TOTAL
	end
	if Opt("show") ~= "total" and A.container then
		lines[#lines + 1] = LINE_READ
	elseif Opt("show") ~= "total" and A.tried then
		lines[#lines + 1] = LINE_NO_CONTAINER
	end
	for _, name in ipairs({ "backdrop", "icon", "time bar", "time", "name", "border", "size" }) do
		if A.refused[name] then
			lines[#lines + 1] = NOTE_REFUSED:format(name == "size" and "size" or name)
		end
	end
	return lines
end

local function Soon()
	A.Queue()
end

ns.Register(KEY, {
	label = "Absorb shields",
	counted = false,
	Start = A.Refresh,
	Refresh = A.Refresh,
	Resized = A.Refresh,
	Status = A.Status,
	events = {
		-- After a loading screen the first read is not compared with the last, so a shield the game had not yet listed again did not break.
		PLAYER_ENTERING_WORLD = function()
			A.wasRead = false
			A.Refresh()
		end,
		PLAYER_REGEN_DISABLED = Soon,
		PLAYER_REGEN_ENABLED = function()
			A.ReadBonus()
			A.Queue()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = Soon,
		PLAYER_TARGET_CHANGED = function()
			A.Totals()
		end,
	},
	slash = { absorbs = A.Slash },
	help = HELP,
})

-- The samples of test mode (A.Hold): On, resume and the page coming on draw them through A.Refresh, every change of a setting through Changed;
-- Stop forgets them at Off, at the pause for a fight and when the page goes off.
if ns.TestMode then
	ns.TestMode.Register(KEY, {
		module = KEY,
		label = "Absorb shields",
		refresh = true,
		Stop = A.Drop,
		Changed = function()
			A.Hold()
		end,
	})
end

ns.Absorbs = A
