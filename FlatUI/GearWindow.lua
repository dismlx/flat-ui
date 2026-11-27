local _, ns = ...

local KEY, PART = "chat", "gear window"
local OWNER, NAME = "gear window", "FlatUIGear"
local BOX = { width = 460, height = 420, x = 680, y = -120 }
local SIZE = { MIN_W = 380, MIN_H = 220, W = 460, H = 420 }
local L = { PAD = 8, CLOSE = 18, WORD_ROOM = 10, WORD_GAP = 9, ICON_GAP = 8, GAP = 6, LINE_GAP = 2, CELL_GAP = 6, GRIP = 14, THUMB = 2,
	THUMB_LEAST = 8 }
local function Units(size)
	L.SIZE = size
	L.BAR, L.WORD, L.ICON, L.SMALL_ICON = size + 14, size + 6, math.floor(size * 2.5 + 0.5), size + 8
	L.HEAD, L.ROW, L.LINE, L.NAME = size + 4, size + 6, size, size * 6
end
Units(12)
local FONT_SIZE = { MIN = 10, MAX = 16, FIRST = 12 }
local COLUMNS = {
	none = { { "name", "Spell" }, { "now", "Now" } },
	one = { { "name", "Spell" }, { "now", "Now" }, { "with", "With" }, { "change", "Change", 1 } },
	two = { { "name", "Spell" }, { "now", "Now" }, { "change", "Change %s", 1 }, { "change", "Change %s", 2 } },
}
local WEIGHT_COLUMN = { "weight", "Weight" }
local WEIGHT = { MIN = 0, MAX = 5, STEP = 0.5, FIRST = 1 }
local FIGURES = { { "damage", "Damage", 1 }, { "healing", "Healing", 1 }, { "threat", "Threat", 1 }, { "taken", "Damage taken", -1 } }
local GROUPS = {
	INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_BODY = "shirt", INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest",
	INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs", INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_FINGER = "finger",
	INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = "back", INVTYPE_WEAPON = "hand", INVTYPE_2HWEAPON = "hand", INVTYPE_WEAPONMAINHAND = "hand",
	INVTYPE_WEAPONOFFHAND = "hand", INVTYPE_SHIELD = "hand", INVTYPE_HOLDABLE = "hand", INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged",
	INVTYPE_THROWN = "ranged", INVTYPE_RELIC = "ranged", INVTYPE_AMMO = "ammo", INVTYPE_TABARD = "tabard",
}
local MODES = { { "cast", "A cast" }, { "second", "A second" }, { "threat", "Threat" }, { "avoid", "Avoidance" } }
local WORD_TIPS = {
	cast = "What one cast does: its expected damage or healing, or its threat for a line that does no damage. Your auto attack, Auto Shot, wand and seals count a second of your swings or shots, so a slower weapon is not set against a faster one swing for swing.",
	second = "What a second does: a cast over its cast time (at least the global cooldown), a spell over time over its duration, your swings and shots over their speed. A strike that takes the place of your next swing has none.",
	threat = "The threat of one cast, and of a second of what rides on your swings and shots (your auto attack, Auto Shot, wand and seals), with your stance, form, Righteous Fury and talents.",
	avoid = "How often an enemy's swing misses you, is dodged, parried or blocked, crits or crushes, and what your armor and block value take off: now, and with the item in each slot it can take. Avoidance on the Gear comparison page chooses when it shows.",
}
local MAX_LEVEL = 60
local CAPS = { classic = "9% melee, 16% spells", game = "8% melee, 17% spells" }
local SLOTS = { [0] = "Ammo", "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist", "Hands", "Finger 1", "Finger 2",
	"Trinket 1", "Trinket 2", "Back", "Main hand", "Off hand", "Ranged", "Tabard" }
local CASTS = { proc = "a proc" }
local FORMS = { [1] = "cat", [5] = "bear", [8] = "bear" }
local HANDS = { main = 16, off = 17, both = 16, ranged = 18 }
local NORM, SWING = { one = 2.4, dagger = 1.7, two = 3.3, ranged = 2.8 }, { cat = 1.0, bear = 2.5 }
local TICK, LOOK, DROP_AGAIN, FADE_IN = 0.5, 0.1, 0.3, 0.1
local NOTES, FOOT, OVERALL, MOST_ROWS, LEAST_ROWS = 10, 7, 4, 80, 3
local SEPARATOR = 0.07
local FONT, TITLE_FONT = "GameFontHighlightSmall", "GameFontHighlight"
local DIM, FAINT, PLAIN = { 0.66, 0.68, 0.62 }, { 0.48, 0.50, 0.45 }, { 1, 1, 1 }
local TONES = { gain = { 0.1, 1, 0.1 }, loss = { 1, 0.1, 0.1 }, none = { 0.8, 0.8, 0.8 } }
local LABEL = { 0.82, 0.82, 0.82 }
local T = {
	TITLE = "Gear comparison",
	DROP = "Drop an item here, find one with Find, or Alt-click an item link in chat.",
	EMPTY = "Drag a spell from your spell book onto this window.",
	NO_MODEL = "The spell data of Chat and tooltips is not running, so there is nothing to work out. /flatui status says why.",
	NO_LIST = "The list of spells of Chat and tooltips is not running, so there is nothing to show. /flatui status says why.",
	NO_ADD = "Gear comparison: the list of spells is not running, so the spell was not added.",
	LOADING = "The game has not loaded this item yet.",
	NOT_COMPARED = "This item is not compared with what you wear.",
	NEVER = "You cannot wear this item.",
	NOT_YET = "Not wearable yet.",
	NOT_YET_LINE = "Not wearable yet: ",
	NOT_YET_LEVEL = " (the numbers are for you now, at level %d)",
	NOT_COUNTED_LINE = "Not counted: ",
	NO_CHANGE = "No change to your chosen spells; armor, avoidance and mana are not counted.",
	RANDOM = "Random stats not known.",
	IN_PLACE = "instead of %s (%s)",
	IN_PLACE_OFF = "instead of %s, off hand empty",
	IN_EMPTY = "in your empty %s slot",
	EMPTY_HANDS = "in your empty hands",
	BOTH = "both hands",
	SLOT = "its slot",
	AGAINST_BOSS = "Enemy: a boss three levels above you, %s, hit cap %s.",
	AGAINST_LEVEL = "Enemy: one of your level, %s.",
	FRONT = "from the front",
	BEHIND = "from behind",
	BEFORE = "Before the enemy's armor and resistances (a spell counts only the damage your Spell Piercing adds), and without talents and buffs your stats do not show, such as one that turns a stat into another or adds crit to one school.",
	NOT_COUNTED = "Not counted: procs, use effects and set bonuses.",
	ENCHANTS = "Enchants count as the game's item stats give them.",
	SKILLS = "Each weapon counts at the full skill of its line for your level, now and with the item.",
	ESTIMATE = "~ marks an estimate.",
	OLD = "Your stats from before the fight.",
	NO_STATS = "The game has not given your stats yet, so the numbers wait for them.",
	SCROLLED = "%d to %d of %d",
	MORE = "And %d more.",
	RANK = "%s Rank %d",
	NOT_KNOWN = "not known",
	SWING_NONE = "takes a swing's place",
	SPEED_FORM = "%s at %s's %.1f sec swing.",
	SPEED_NORM = "%s as a %.1f sec %s.",
	SPEED_OWN = "%s at your weapon's own speed, %.2f sec.",
	SPEED_ANY = "%s at your weapon's own speed.",
	CAT = "Cat Form",
	BEAR = "Bear Form",
	POWER = "Attack power",
	RANGED_POWER = "Ranged attack power",
	MEASURED = "Measured in the game.",
	ESTIMATED = "~ An estimate.",
	NEXT_SWING = "It takes the place of your next swing, so it has no second of its own.",
	ROW_SKILL = "Now and With count your weapon at the full skill of its line for your level; the spell's own lines above count your skill as it is.",
	UNKNOWN = "You do not know this spell now.",
	REMOVE = "Right-click to take it off the comparison.",
	CLEAR = { "Shift-click: link it in chat. Ctrl-click: try it on.", "Right-click to take the item out of the window." },
	TRY_FIGHT = "Gear comparison: trying items on waits for the end of the fight.",
	OFF = "Gear comparison: turn on Restyle chat and tooltips first (Chat page).",
	MODULE_STOPPED = "Gear comparison: Chat and tooltips stopped after an error. /flatui status says why.",
	STOPPED = "Gear comparison: the window stopped after an error. /flatui status says why.",
	AFTER_FIGHT = "Gear comparison: the window opens when the fight ends.",
	STATUS = "Gear comparison window: open, comparing %s.",
	STATUS_AGAINST = "Gear comparison window: open, comparing %s against %s.",
	FIND = "Find",
	FIND_LINES = { "Opens and closes the item finder beside this window: every item by name, slot, armor and weapon type, or what is in your bags, your bank and on your other characters.",
		"Click an item there to compare it here; right-click it to compare against it." },
	NO_FIND = "Gear comparison: the item finder is not there.",
	AGAINST = "Against",
	AGAINST_LABEL = "Against: ",
	AGAINST_HINT = "what you wear. Drop an item here to compare with that one instead.",
	AGAINST_OTHER = "not for this slot, so compared with what you wear",
	AGAINST_UNUSED = "The item of Against was not used; the numbers are against what you wear.",
	AGAINST_TIP = { "Empty, the item is compared with what you wear in its slot.",
		"Drop an item here, or right-click one in the item finder, to compare with that one instead." },
	AGAINST_CLEAR = { "Shift-click: link it in chat. Ctrl-click: try it on.", "Right-click to compare with what you wear again." },
	OVERALL = "Overall",
	OVERALL_SLOT = "Overall, %s",
	OVERALL_ROTATION = "Damage, Healing and Threat: what your lines do in a minute of WoWSims' rotation for your class (%s) with the item against now. Your auto attack, Auto Shot, wand and seals count the whole minute; each other line counts as often as that rotation uses it a minute, whichever lines you chose, and Heroic Strike and Maul count what they add over the swing they take the place of, on the share of your swings the rotation gives them, so a strike it queues on most swings counts about as much as the swings it replaces. A line the rotation never uses counts nothing; a kind with no line it uses, as healing, shares the minute's 40 global cooldowns evenly. Then each line counts times its weight (the Weight column; 0 leaves it out, 2 counts it twice). Damage and healing are those of A cast whatever the switch says; threat is that of Threat, for a tank or while the switch says Threat.",
	STAND = ", standing in for your talents",
	BEST = "Best",
	WORST = "Worst",
	OVERALL_LINES = {
		"Damage, Healing and Threat: what your lines do in a minute with the item against now. Your auto attack, Auto Shot, wand and seals count the whole minute; the other lines of each kind share the minute's 40 global cooldowns evenly (Flat UI has no WoWSims rotation for your class and spec), and Heroic Strike, Cleave, Maul and Raptor Strike count what they add over the swing they take the place of, once a swing at most. Then each line counts times its weight (the Weight column; 0 leaves it out, 2 counts it twice). Damage and healing are those of A cast whatever the switch says; threat is that of Threat, for a tank or while the switch says Threat.",
		"Best and Worst: the lines on show with the largest gain and loss in percent, as their Change says, weight 0 too; none under Avoidance.",
		"Damage taken: what an enemy's swing does to you after misses, dodges, parries, blocks, crits, crushing blows and armor, as a share of a plain hit, so less is better. Block value counts against an enemy hit of %s before armor (Enemy hit for block value, an estimate).",
		"Green is better for you and red worse; ~ marks an estimate.",
	},
	WEIGHT_TIP = "Weight %s",
	WEIGHT_LINES = { "How much this line counts in the Overall line against the others: its minute, of swings and shots or of its casts in WoWSims' rotation for your class (else an even share of the casts), times this; 0 leaves it out, 5 counts it five times.",
		"Left-click: +0.5. Right-click: -0.5. Shift-click: back to 1." },
	NO_WEIGHT = "Gear comparison: the list of spells is not running, so the weight was not changed.",
	GRIP = "Size",
	GRIP_LINES = { "Drag to size the window; its size is kept for this character.",
		"Reset the window on the Window and finder tab of Gear comparison puts its size and place back." },
	RESET_LINE = "Put its size and place back",
	RESET_DONE = "Gear comparison: the window is back at its first size and place.",
	RESET_FAILED = "Gear comparison: the window could not be put back. /flatui status says why.",
	REPORT = "Flat UI, Gear comparison window, %s: %s",
}
local WEAPONS = { one = "one-hand weapon", dagger = "dagger", two = "two-hand weapon", ranged = "ranged weapon" }

local IsSecret = ns.IsSecret

local W = { mode = "cast", chosen = false, offset = 0, shown = 0, runs = 0, faults = {}, requested = {}, elapsed = 0, looked = 0, words = {},
	rows = {}, notes = {}, foot = {}, overall = {}, rules = {}, owners = {}, texts = {} }

local Refresh, Paint, PaintLook, Close, Drop, Place, Dropped, MakeRow

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Finite(value)
	return ns.Finite(value)
end

local function Text(value)
	if not IsSecret(value) and type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function Byte(value)
	return math.max(0, math.min(255, math.floor(value * 255 + 0.5)))
end

local function Hex(r, g, b)
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

local DIM_HEX, FAINT_HEX = Hex(DIM[1], DIM[2], DIM[3]), Hex(FAINT[1], FAINT[2], FAINT[3])

local function Now()
	if type(GetTime) ~= "function" then
		return 0
	end
	local ok, now = pcall(GetTime)
	return ok and Finite(now) and now or 0
end

local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, fighting = pcall(InCombatLockdown)
	return ok and (IsSecret(fighting) or fighting == true)
end

local function Report(what, err)
	if W.faults[what] then
		return
	end
	W.faults[what] = true
	local handler = type(geterrorhandler) == "function" and geterrorhandler() or nil
	if type(handler) == "function" then
		pcall(handler, T.REPORT:format(tostring(what), tostring(err)))
	end
end

local function Step(_, fn, ...)
	return fn(...)
end

local function Run(fn, ...)
	W.runs = W.runs + 1
	local ok, err = ns.EachPart(KEY, PART, Step, W.runs, fn, ...)
	if not ok and err ~= nil then
		Report("window", err)
		if ns.PartStopped(KEY, PART) then
			Close(true)
		end
	end
	return ok == true
end

local function Allowed()
	return type(ns.modules) == "table" and ns.modules[KEY] ~= nil and ns.Enabled(KEY) and not ns.PartStopped(KEY, PART)
end

local function Refusal()
	if type(ns.modules) == "table" and ns.modules[KEY] ~= nil then
		if ns.IsStopped(KEY) then
			return T.MODULE_STOPPED
		elseif ns.PartStopped(KEY, PART) then
			return T.STOPPED
		end
	end
	return T.OFF
end

local function Fn(tbl, name)
	if type(tbl) ~= "table" or IsSecret(tbl) then
		return nil
	end
	local fn = tbl[name]
	if type(fn) == "function" then
		return fn
	end
	return nil
end

local function Ask(tbl, name, ...)
	local fn = Fn(tbl, name)
	if not fn then
		return nil
	end
	local ok, answer = pcall(fn, ...)
	if ok then
		return answer
	end
	Report(name, answer)
	return nil
end

local function Want(on)
	on = on == true
	if (W.wanted == true) == on then
		return
	end
	local want = Fn(ns.SpellModel, "Want")
	if want and pcall(want, OWNER, on) then
		W.wanted = on
	elseif not on then
		W.wanted = false
	end
end

local function Touch()
	local model = ns.SpellModel
	return Ask(model, "State"), Ask(model, "Stats")
end

local function RGB(path, r, g, b)
	local ok, cr, cg, cb = pcall(ns.Colour, path)
	if ok and Finite(cr) and Finite(cg) and Finite(cb) then
		return cr, cg, cb
	end
	return r, g, b
end

local function Opacity()
	local value = ns.Get("windows.opacity")
	return Finite(value) and math.max(0, math.min(1, value / 100)) or 0.8
end

local function Crop()
	local value = ns.Get("windows.crop")
	return (Finite(value) and math.max(0, math.min(15, value)) or 8) / 100
end

local function FontSize()
	local size = Opt("gearWinFont")
	if not Finite(size) then
		return FONT_SIZE.FIRST
	end
	return math.max(FONT_SIZE.MIN, math.min(FONT_SIZE.MAX, math.floor(size + 0.5)))
end

local function Face(object)
	local font = _G[object]
	if type(font) ~= "table" or IsSecret(font) then
		return nil
	end
	local ok, file, _, flags = pcall(font.GetFont, font)
	if not (ok and Text(file)) then
		return nil
	end
	return file, (not IsSecret(flags) and type(flags) == "string") and flags or ""
end

local function Sized(text, big)
	local file, flags = Face(big and TITLE_FONT or FONT)
	if file then
		pcall(text.SetFont, text, file, (W.fontSize or FONT_SIZE.FIRST) + (big and 1 or 0), flags)
	end
end

local function Label(parent, font, wrap)
	local text = ns.OwnText(parent, "OVERLAY", font or FONT)
	if not text then
		error("no font string", 0)
	end
	text:SetJustifyH("LEFT")
	text:SetWordWrap(wrap == true)
	local big = font == TITLE_FONT
	W.texts[#W.texts + 1] = { text, big }
	Sized(text, big)
	return text
end

local function Texture(parent, layer, sub)
	return Own(parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0))
end

local function Stroke(button, layer, x1, y1, x2, y2)
	local line = Own(button:CreateLine(nil, layer, nil, 2))
	line:SetThickness(1.5)
	line:SetStartPoint("TOPLEFT", button, x1, -y1)
	line:SetEndPoint("TOPLEFT", button, x2, -y2)
	return line
end

local function TextWidth(text, words)
	local ok, width = pcall(text.GetUnboundedStringWidth, text)
	if not (ok and Finite(width) and width > 0) then
		ok, width = pcall(text.GetStringWidth, text)
	end
	if ok and Finite(width) and width > 0 then
		return width
	end
	return #(words or "") * L.SIZE / 2
end

local function Height(text)
	local ok, height = pcall(text.GetStringHeight, text)
	if ok and Finite(height) and height > 0 and height < 2000 then
		return math.ceil(height)
	end
	return L.LINE
end

local function Colour(text, colour)
	text:SetTextColor(colour[1], colour[2], colour[3], 1)
end

local function Styled(name, fallback)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt or nil
	local style = type(fmt) == "table" and not IsSecret(fmt) and fmt.Style or nil
	local colour = type(style) == "table" and style[name] or nil
	if type(colour) == "table" and Finite(colour[1]) and Finite(colour[2]) and Finite(colour[3]) then
		return colour
	end
	return fallback
end

local function ToneColour(tone)
	if tone == "gain" then
		return Styled("good", TONES.gain)
	elseif tone == "loss" then
		return Styled("bad", TONES.loss)
	end
	return TONES.none
end

local function HexOf(colour)
	return Hex(colour[1], colour[2], colour[3])
end

local function Searching()
	return Ask(ns, "GearSearchShown") == true
end

local function PaintWords()
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	local words = { W.find }
	for _, word in ipairs(W.words) do
		words[#words + 1] = word
	end
	for _, word in ipairs(words) do
		local chosen = word.mode == nil and Searching() or (word.mode ~= nil and word.mode == W.mode)
		if chosen then
			word.text:SetTextColor(ar, ag, ab, 1)
		elseif word.over then
			Colour(word.text, PLAIN)
		else
			Colour(word.text, DIM)
		end
	end
end

local function Avoiding()
	return Ask(ns.GearAvoid, "Wanted") == true
end

local function SizeWord(word)
	word.width = math.ceil(TextWidth(word.text, word.label)) + L.WORD_ROOM
	word.button:SetSize(word.width, L.WORD)
end

local function PlaceBar(width)
	local x, bar = -(4 + L.CLOSE + L.WORD_GAP), W.bar
	for index = #W.words, 1, -1 do
		local word = W.words[index]
		local shown = word.mode ~= "avoid" or Avoiding()
		word.button:SetShown(shown)
		if word.sep then
			word.sep:SetShown(shown)
		end
		if shown then
			word.button:ClearAllPoints()
			word.button:SetPoint("RIGHT", bar, "RIGHT", x, 0)
			x = x - word.width
			if word.sep then
				word.sep:ClearAllPoints()
				word.sep:SetPoint("CENTER", bar, "RIGHT", x - L.WORD_GAP / 2, 0)
				x = x - L.WORD_GAP
			end
		end
	end
	local find, title = W.find, W.title
	local room = width + x - L.WORD_GAP - L.PAD - find.width - L.WORD_GAP
	local titled = room >= 3 * L.SIZE
	local titleWidth = titled and math.min(math.ceil(TextWidth(title, T.TITLE)), room) or 0
	title:SetShown(titled)
	title:SetWidth(math.max(1, titleWidth))
	find.button:ClearAllPoints()
	find.button:SetPoint("LEFT", bar, "LEFT", L.PAD + (titled and titleWidth + L.WORD_GAP or 0), 0)
end

local function SizeParts()
	W.bar:SetHeight(L.BAR)
	local need = L.PAD + L.WORD_GAP + L.WORD_GAP + 4 + L.CLOSE + L.WORD_GAP
	for index, word in ipairs(W.words) do
		SizeWord(word)
		need = need + word.width + (index > 1 and L.WORD_GAP or 0)
	end
	SizeWord(W.find)
	W.barNeed = math.ceil(need + W.find.width)
	W.item.box:SetSize(L.ICON, L.ICON)
	W.against.box:SetSize(L.SMALL_ICON, L.SMALL_ICON)
end

local function RowLook(slot, ar, ag, ab)
	slot.hover:SetColorTexture(ar, ag, ab, 0.12)
	slot.weight.hover:SetColorTexture(ar, ag, ab, 0.18)
end

function PaintLook()
	if not W.frame then
		return
	end
	local r, g, b = RGB("general.backdrop", 0.06, 0.06, 0.06)
	ns.SetOutlineFill(W.outline, r, g, b, Opacity())
	ns.SetOutline(W.outline, true, true)
	local pr, pg, pb = RGB("windows.panel", 0.12, 0.12, 0.12)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	for _, area in ipairs({ W.item, W.against }) do
		ns.SetOutlineFill(area.outline, pr, pg, pb, 1)
		ns.SetOutline(area.outline, true, true)
		area.hover:SetColorTexture(ar, ag, ab, 0.08)
		area.light:SetColorTexture(ar, ag, ab, 0.14)
	end
	W.tableLight:SetColorTexture(ar, ag, ab, 0.08)
	W.thumb:SetColorTexture(ar, ag, ab, 0.5)
	for _, rule in ipairs(W.rules) do
		rule:SetColorTexture(1, 1, 1, SEPARATOR)
	end
	for _, sep in ipairs(W.seps) do
		sep:SetColorTexture(1, 1, 1, 0.2)
	end
	for _, group in ipairs({ W.close, W.grip }) do
		for _, line in ipairs(group.lines) do
			line:SetColorTexture(1, 1, 1, group == W.grip and 0.35 or 0.6)
		end
		for _, line in ipairs(group.hover) do
			line:SetColorTexture(ar, ag, ab, 1)
		end
	end
	for _, slot in ipairs(W.rows) do
		RowLook(slot, ar, ag, ab)
	end
	Colour(W.title, PLAIN)
	for _, text in ipairs({ W.item.place, W.item.hint, W.message }) do
		Colour(text, DIM)
	end
	Colour(W.against.text, PLAIN)
	for _, text in ipairs(W.heads) do
		Colour(text, DIM)
	end
	for _, pool in ipairs({ W.notes, W.foot }) do
		for _, text in ipairs(pool) do
			Colour(text, DIM)
		end
	end
	for _, text in ipairs(W.overall) do
		Colour(text, PLAIN)
	end
	PaintWords()
end

local function Tooltip()
	local tip = GameTooltip
	if type(tip) == "table" and not IsSecret(tip) and not ns.Forbidden(tip) then
		return tip
	end
	return nil
end

local function Untip(owner)
	local tip = Tooltip()
	if not tip then
		return
	end
	local ok, owned = pcall(tip.IsOwned, tip, owner)
	if ok and not IsSecret(owned) and owned == true then
		pcall(tip.Hide, tip)
	end
end

local function Built(ok, answer)
	return ok and not IsSecret(answer) and answer == true
end

local function AddDim(tip, lines)
	for _, line in ipairs(lines) do
		pcall(tip.AddLine, tip, line, DIM[1], DIM[2], DIM[3], true)
	end
end

local function Say(owner, title, lines)
	if Fighting() then
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, owner, "ANCHOR_BOTTOM") then
		return
	end
	pcall(tip.AddLine, tip, title, PLAIN[1], PLAIN[2], PLAIN[3])
	AddDim(tip, lines)
	pcall(tip.Show, tip)
end

local function Fmt(name)
	local fmt = type(ns.SpellModel) == "table" and ns.SpellModel.Fmt or nil
	return Fn(fmt, name)
end

local function Value(value, second, estimate)
	if not Finite(value) then
		return "-"
	end
	local figure = Fmt("Figure")
	return (estimate and "~" or "") .. (figure and figure(value, second) or ("%.1f"):format(value))
end

local function Change(now, with, second, estimate)
	if not (Finite(now) and Finite(with)) then
		return "-", "none"
	end
	local delta = with - now
	local change, percent = Fmt("Change"), Fmt("Percent")
	local text = change and change(delta, second) or ("%+.1f"):format(delta)
	local tone = "none"
	if math.abs(delta) >= 0.05 then
		tone = delta > 0 and "gain" or "loss"
	end
	if now ~= 0 then
		local share = delta / math.abs(now)
		text = text .. " (" .. (percent and percent(share) or ("%+.1f%%"):format(share * 100)) .. ")"
	end
	return (estimate and "~" or "") .. text, tone
end

local function Share(share)
	local percent = Fmt("Percent")
	return percent and percent(share) or ("%+.1f%%"):format(share * 100)
end

local function ShareTone(share, better)
	if math.abs(share) < 0.0005 then
		return "none"
	end
	return share * (better or 1) > 0 and "gain" or "loss"
end

local function WeightOf(line)
	local weight = type(line) == "table" and line.weight or nil
	if Finite(weight) then
		return math.max(WEIGHT.MIN, math.min(WEIGHT.MAX, weight))
	end
	return WEIGHT.FIRST
end

local function WeightText(weight)
	return (("%.1f"):format(weight):gsub("%.0$", ""))
end

local function ItemID(link)
	local id = Text(link) and link:match("item:(%d+)") or nil
	return id and tonumber(id) or nil
end

local function AsItem(value)
	if Finite(value) and value > 0 then
		return ("item:%d"):format(math.floor(value))
	end
	local text = Text(value)
	if text and text:find("item:%d") then
		return text
	end
	return nil
end

local function LinkParts(link)
	local text = Text(link)
	if not text then
		return nil, nil
	end
	local colour, name = text:match("^(|c.-)|H.-|h%[(.-)%]|h")
	if not name then
		name = text:match("|h%[(.-)%]|h")
	end
	return colour, Text(name)
end

local function QualityHex(quality)
	if not Finite(quality) then
		return nil
	end
	local get = Fn(_G.ColorManager, "GetColorDataForItemQuality")
	if get then
		local ok, colour = pcall(get, quality)
		if ok and type(colour) == "table" and not IsSecret(colour) and Finite(colour.r) and Finite(colour.g) and Finite(colour.b) then
			return Hex(colour.r, colour.g, colour.b)
		end
	end
	local quality2 = Fn(C_Item, "GetItemQualityColor")
	if quality2 then
		local ok, r, g, b = pcall(quality2, quality)
		if ok and Finite(r) and Finite(g) and Finite(b) then
			return Hex(r, g, b)
		end
	end
	return nil
end

local function ItemLook(link)
	local colour, name = LinkParts(link)
	local look = { id = ItemID(link) }
	local info = Fn(C_Item, "GetItemInfo")
	if info then
		local ok, itemName, _, quality = pcall(info, link)
		if ok and Text(itemName) then
			look.loaded = true
			name = name or itemName
			colour = colour or QualityHex(quality)
		end
	end
	local instant = Fn(C_Item, "GetItemInfoInstant")
	if instant then
		local ok, _, _, _, equip, icon = pcall(instant, link)
		if ok and not IsSecret(icon) and (Finite(icon) or Text(icon)) then
			look.icon = icon
		end
		look.equip = ok and Text(equip) or nil
	end
	if not look.loaded and look.id and not W.requested[look.id] then
		W.requested[look.id] = true
		local request = Fn(C_Item, "RequestLoadItemDataByID")
		if request then
			pcall(request, look.id)
		end
	end
	look.name = name or (look.id and ("item %d"):format(look.id)) or "an item"
	look.text = (colour or Hex(PLAIN[1], PLAIN[2], PLAIN[3])) .. look.name .. "|r"
	return look
end

local function Worn(state, slot)
	local links = type(state) == "table" and state.links or nil
	local link = type(links) == "table" and Text(links[slot]) or nil
	if link then
		return link
	end
	if type(GetInventoryItemLink) == "function" then
		local ok, worn = pcall(GetInventoryItemLink, "player", slot)
		if ok then
			return Text(worn)
		end
	end
	return nil
end

local function Has(list, value)
	for _, held in ipairs(list) do
		if Finite(held) and held == value then
			return true
		end
	end
	return false
end

local function Where(candidate)
	local slots = type(candidate) == "table" and type(candidate.slots) == "table" and candidate.slots or {}
	if Has(slots, 16) and Has(slots, 17) then
		return T.BOTH
	end
	local first = slots[1]
	return (Finite(first) and SLOTS[first]) or (type(candidate) == "table" and Text(candidate.label)) or T.SLOT
end

local function SameSlot(link, base)
	local one, other = ItemLook(link).equip, ItemLook(base).equip
	local a, b = one and GROUPS[one], other and GROUPS[other]
	if not (a and b) then
		return nil
	end
	return a == b
end

local function PlaceLine(cands, state, base)
	local phrases = {}
	for _, c in ipairs(cands) do
		local where, names = Where(c), {}
		if base then
			names[1] = ItemLook(base).text
		elseif not c.empty then
			for _, slot in ipairs(type(c.slots) == "table" and c.slots or {}) do
				local link = Finite(slot) and Worn(state, slot) or nil
				if link then
					names[#names + 1] = ItemLook(link).text
				end
			end
		end
		if #names > 0 and c.offEmpty == true and not base then
			phrases[#phrases + 1] = T.IN_PLACE_OFF:format(table.concat(names, " and "))
		elseif #names > 0 then
			phrases[#phrases + 1] = T.IN_PLACE:format(table.concat(names, " and "), where)
		elseif where == T.BOTH then
			phrases[#phrases + 1] = T.EMPTY_HANDS
		else
			phrases[#phrases + 1] = T.IN_EMPTY:format(where)
		end
	end
	if #phrases == 0 then
		return nil
	end
	local line = table.concat(phrases, ", or ")
	return line:sub(1, 1):upper() .. line:sub(2)
end

local function Chosen()
	local list = Ask(ns, "GearChosen")
	if type(list) ~= "table" or IsSecret(list) then
		return nil
	end
	return list
end

local function EntryOf(line)
	local entry = type(line) == "table" and line.entry or nil
	return type(entry) == "table" and entry or nil
end

local function RankOf(line)
	local rank, entry = line.rank, EntryOf(line)
	if Finite(rank) then
		return math.floor(rank)
	end
	if entry and type(entry.ranks) == "table" and type(rank) == "table" then
		for index, held in ipairs(entry.ranks) do
			if rawequal(held, rank) then
				return index
			end
		end
	end
	return nil
end

local function SpellOf(line)
	if type(line) ~= "table" then
		return nil
	end
	if Finite(line.id) and line.id > 0 then
		return line.id
	end
	local entry = EntryOf(line)
	local ranks = entry and type(entry.ranks) == "table" and entry.ranks or nil
	local last = ranks and ranks[#ranks] or nil
	if type(last) == "table" and Finite(last[1]) then
		return last[1]
	end
	return nil
end

local function NameOf(line)
	local name = Text(line.name)
	if not name then
		local id, get = SpellOf(line), Fn(C_Spell, "GetSpellName")
		if id and get then
			local ok, got = pcall(get, id)
			name = ok and Text(got) or nil
		end
	end
	local entry = EntryOf(line)
	if not name and entry and Text(entry.key) then
		name = entry.key:gsub("(%a)(%w*)", function(first, rest)
			return first:upper() .. rest
		end)
	end
	return name or "?"
end

local function Pick(e, figure)
	if type(e) ~= "table" or not figure then
		return nil
	end
	if figure == "cast" then
		return e.cast
	elseif figure == "second" or figure == "dps" then
		return e.second
	elseif figure == "threat" then
		return e.threat
	end
	return nil
end

local function Counts(mode, row)
	local entry = EntryOf(row.line)
	local cmp, figure = entry and entry.cmp or nil, row.figure
	if not figure then
		return entry and entry.nx and mode == "second" and T.SWING_NONE or nil
	elseif figure == "threat" then
		if row.perSecond then
			return mode == "threat" and "a second" or "threat a second"
		end
		return mode ~= "threat" and "threat" or nil
	elseif figure == "cast" and CASTS[cmp] then
		return CASTS[cmp]
	elseif row.perSecond and mode ~= "second" then
		return "a second"
	end
	return nil
end

local function Role(state)
	local role = type(state) == "table" and Text(state.role) or nil
	if role then
		return role
	end
	if type(ns.PlayerRole) == "function" then
		local ok, answer = pcall(ns.PlayerRole)
		if ok then
			return Text(answer)
		end
	end
	return nil
end

local function Level(state)
	if type(state) == "table" and Finite(state.level) then
		return state.level
	end
	if type(UnitLevel) == "function" then
		local ok, level = pcall(UnitLevel, "player")
		if ok and Finite(level) then
			return level
		end
	end
	return nil
end

local function Options(mode)
	return {
		mode = mode, listVersion = Ask(ns, "GearListVersion"), against = Opt("gearAgainst"), facing = Opt("gearFacing"), rules = Opt("gearRules"),
		lowRank = Opt("spellLowRank") ~= false, inputs = Ask(ns.GearModel, "Inputs"), base = W.used, full = true,
	}
end

local function Profile(view, lines, state, stats)
	local model = ns.GearModel
	local opts = Options(view.mode)
	for _, line in ipairs(lines) do
		if type(line) == "table" then
			local row = { line = line, figure = Text(Ask(model, "Figure", line, view.role, view.mode)) }
			if row.figure then
				local e = Ask(model, "Expect", line, state, stats, opts)
				if type(e) == "table" then
					local threat = row.figure == "threat"
					row.now = Pick(e, row.figure)
					row.basis = Text(threat and e.threatBasis or e.basis)
					row.why = Text(e.why) or (threat and Text(e.threatWhy)) or nil
					row.estimate = row.basis == "e"
					row.nowEstimate = row.estimate
					row.perSecond = row.figure == "second" or row.figure == "dps" or (threat and e.perSecond == true)
				end
			end
			view.rows[#view.rows + 1] = row
		end
	end
end

local function RowOf(rows, line, index)
	local at = rows[index]
	if type(at) == "table" and rawequal(at.line, line) then
		return at
	end
	for _, row in ipairs(rows) do
		if type(row) == "table" and rawequal(row.line, line) then
			return row
		end
	end
	local id = SpellOf(line)
	for _, row in ipairs(rows) do
		if type(row) == "table" and id and SpellOf(row.line) == id then
			return row
		end
	end
	return nil
end

local function Compared(view, result, lines, state)
	local cands = {}
	for _, c in ipairs(type(result.candidates) == "table" and result.candidates or {}) do
		if type(c) == "table" and type(c.rows) == "table" and #cands < 2 then
			cands[#cands + 1] = c
		end
	end
	view.cands = cands
	if #cands == 0 then
		return false
	end
	view.layout = #cands == 2 and "two" or "one"
	for index, line in ipairs(lines) do
		if type(line) == "table" then
			local row = { line = line, with = {} }
			for which, c in ipairs(cands) do
				local found = RowOf(c.rows, line, index)
				if found then
					if row.now == nil then
						row.now = found.now
					end
					row.figure = row.figure or Text(found.figure)
					row.estimate = row.estimate or found.estimate == true
					row.nowEstimate = row.nowEstimate or found.nowEstimate == true
					if which == 1 then
						row.withEstimate = found.withEstimate == true
					end
					row.perSecond = row.perSecond or found.perSecond == true
					row.basis = row.basis or Text(found.basis)
					row.why = row.why or Text(found.why)
					row.with[which] = found.with
				end
			end
			view.rows[#view.rows + 1] = row
		end
	end
	view.place = PlaceLine(cands, state, W.used and Text(result.base) or nil)
	return true
end

local function Note(notes, text, prefix)
	text = Text(text)
	if text then
		if prefix and text:sub(1, #prefix) ~= prefix then
			text = prefix .. text
		end
		notes[#notes + 1] = text
	end
end

local function Notes(view, result, later)
	local notes = view.notes
	if result.notYet == true then
		Note(notes, T.NOT_YET)
	else
		local yet = Text(result.notYet) or later
		Note(notes, yet and Finite(view.level) and (yet .. T.NOT_YET_LEVEL:format(view.level)) or yet, T.NOT_YET_LINE)
	end
	for _, text in ipairs(type(result.skills) == "table" and result.skills or {}) do
		Note(notes, text)
	end
	if result.noChange == true then
		Note(notes, T.NO_CHANGE)
	end
	for _, text in ipairs(type(result.notCounted) == "table" and result.notCounted or {}) do
		Note(notes, text, T.NOT_COUNTED_LINE)
	end
	for _, text in ipairs(type(result.vs) == "table" and result.vs or {}) do
		Note(notes, text)
	end
	if result.random == true then
		Note(notes, T.RANDOM)
	else
		Note(notes, result.random)
	end
	local why = Text(result.why)
	if why and why ~= view.place then
		Note(notes, why)
	end
	if W.used and #view.cands > 0 and not Text(result.base) then
		Note(notes, T.AGAINST_UNUSED)
	end
end

local function Wearing(link)
	local wearable = Fn(ns, "GearWearable")
	if not wearable then
		return false, nil
	end
	local ok, never, later = pcall(wearable, link)
	if not ok then
		Report("GearWearable", never)
		return false, nil
	end
	return not IsSecret(never) and never == true, Text(later)
end

local function AvoidView()
	if not Avoiding() then
		return nil
	end
	local never = W.link ~= nil and (Wearing(W.link)) == true
	local got = Ask(ns.GearAvoid, "Window", not never and W.link or nil, W.used)
	if type(got) ~= "table" or type(got.rows) ~= "table" or not COLUMNS[got.layout] then
		return nil
	end
	local state, stats = Touch()
	local view = { mode = "avoid", layout = got.layout, rows = got.rows, notes = got.notes or {}, cands = got.cands or {}, heads = got.heads,
		foot = got.foot, noStats = type(stats) ~= "table", old = type(stats) == "table" and stats.old == true, never = never, role = Role(state) }
	if W.link then
		view.item = ItemLook(W.link)
		local first = view.cands[1]
		local base = W.used and (Text(got.base) or (type(first) == "table" and Text(first.base))) or nil
		if never then
			view.place = T.NEVER
		elseif #view.cands > 0 then
			view.place = PlaceLine(view.cands, state, base)
			if W.used and not base then
				Note(view.notes, T.AGAINST_UNUSED)
			end
		else
			view.place = Text(got.why)
			if not view.place then
				Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
			end
		end
	elseif #view.rows == 0 then
		view.message = Text(got.why) or T.NO_STATS
	end
	return view
end

local O = {}
O.STILL = 0.0005

function O.Firsts(result)
	local list = {}
	for _, c in ipairs(type(result) == "table" and type(result.candidates) == "table" and result.candidates or {}) do
		if type(c) == "table" and #list < 2 then
			list[#list + 1] = c
		end
	end
	return list
end

function O.Matching(result, c)
	local slots = type(c.slots) == "table" and c.slots or {}
	local slot = slots[1]
	for _, other in ipairs(O.Firsts(result)) do
		local theirs = type(other.slots) == "table" and other.slots or {}
		if Finite(slot) and theirs[1] == slot then
			return other
		end
	end
	return nil
end

function O.Totals(result, c, lines, mode)
	local own = result and O.Matching(result, c)
	if not own then
		return nil
	end
	local got = Ask(ns.GearModel, "Totals", own, lines, Options(mode))
	return type(got) == "table" and not IsSecret(got) and got or nil
end

function O.Taken(result, c)
	local own = result and O.Matching(result, c)
	if not own then
		return nil
	end
	local got = Ask(ns.GearAvoid, "Totals", own)
	local taken = type(got) == "table" and got.taken or own.taken
	if type(taken) == "table" and Finite(taken.pct) then
		return taken
	end
	return nil
end

function O.FigureText(word, pct, estimate, better)
	local guess = estimate and math.abs(pct) >= O.STILL and "~" or ""
	return HexOf(Styled("label", LABEL)) .. word .. "|r " .. HexOf(ToneColour(ShareTone(pct, better))) .. guess .. Share(pct) .. "|r"
end

function O.Extremes(acc, figures, where)
	for _, key in ipairs({ "damage", "healing", "threat" }) do
		local figure = figures[key]
		if type(figure) == "table" then
			local best, worst = figure.best, figure.worst
			if type(best) == "table" and Text(best.name) and Finite(best.pct) and best.pct >= O.STILL
				and (not acc.best or best.pct > acc.best.pct) then
				acc.best = { name = best.name, pct = best.pct, where = where }
			end
			if type(worst) == "table" and Text(worst.name) and Finite(worst.pct) and worst.pct <= -O.STILL
				and (not acc.worst or worst.pct < acc.worst.pct) then
				acc.worst = { name = worst.name, pct = worst.pct, where = where }
			end
		end
	end
end

function O.Extreme(word, held)
	local name = held.name .. (held.where and (" (" .. held.where .. ")") or "")
	return HexOf(Styled("label", LABEL)) .. word .. "|r " .. name .. " " .. HexOf(ToneColour(ShareTone(held.pct, 1))) .. Share(held.pct) .. "|r"
end

function O.Overall(view, lines)
	if not W.link or view.never or Opt("gearTotals") == "off" then
		return nil
	end
	local gear = ns.GearModel
	local main, threat, avoid, shown
	if Fn(gear, "Totals") and lines then
		main = (view.mode == "cast" and view.result) or Ask(gear, "Compare", W.link, lines, Options("cast"))
		if view.role == "tank" or W.mode == "threat" then
			threat = (view.mode == "threat" and view.result) or Ask(gear, "Compare", W.link, lines, Options("threat"))
		end
		if view.mode ~= "avoid" then
			shown = (view.mode == "threat" and threat) or (view.mode == "second" and view.result) or main
		end
	end
	if Avoiding() then
		avoid = Ask(ns.GearAvoid, "Compare", W.link, { base = W.used })
	end
	local cands = O.Firsts(main)
	if #cands == 0 then
		cands = O.Firsts(avoid)
	end
	local texts, acc, sep = {}, {}, "  " .. FAINT_HEX .. "\194\183|r  "
	for _, c in ipairs(cands) do
		local where = #cands > 1 and Where(c) or nil
		local totals = O.Totals(main, c, lines, "cast") or {}
		local threatTotals = threat and O.Totals(threat, c, lines, "threat") or {}
		local figures = { damage = totals.damage, healing = totals.healing, threat = threatTotals.threat,
			taken = avoid and O.Taken(avoid, c) or nil }
		local onShow = (shown == main and totals) or (shown == threat and threatTotals) or (shown and O.Totals(shown, c, lines, view.mode)) or {}
		local parts = {}
		for _, figure in ipairs(FIGURES) do
			local held = figures[figure[1]]
			if type(held) == "table" and Finite(held.pct) and not (Finite(held.n) and held.n <= 0) then
				parts[#parts + 1] = O.FigureText(figure[2], held.pct, held.estimate == true, figure[3])
			end
		end
		if #parts > 0 then
			local head = where and T.OVERALL_SLOT:format(where) or T.OVERALL
			texts[#texts + 1] = HexOf(Styled("label", LABEL)) .. head .. "|r  " .. table.concat(parts, sep)
			O.Extremes(acc, onShow, where)
		end
	end
	local extremes = {}
	if acc.best then
		extremes[#extremes + 1] = O.Extreme(T.BEST, acc.best)
	end
	if acc.worst then
		extremes[#extremes + 1] = O.Extreme(T.WORST, acc.worst)
	end
	if #extremes > 0 then
		texts[#texts + 1] = table.concat(extremes, sep)
	end
	return #texts > 0 and texts or nil
end

local function SpellView()
	local view = { mode = W.mode, layout = "none", rows = {}, notes = {}, cands = {} }
	local model, gear = ns.SpellModel, ns.GearModel
	if not (Fn(model, "State") and Fn(gear, "Expect") and Fn(gear, "Figure")) then
		view.message = T.NO_MODEL
		return view
	end
	local lines = Chosen()
	if not lines then
		view.message = T.NO_LIST
		return view
	end
	view.lines = lines
	local state, stats = Touch()
	view.role, view.level = Role(state), Level(state)
	view.noStats = type(stats) ~= "table"
	view.old = type(stats) == "table" and stats.old == true
	if W.link then
		view.item = ItemLook(W.link)
		local never, later = Wearing(W.link)
		view.never = never
		local result = not never and Ask(gear, "Compare", W.link, lines, Options(view.mode)) or nil
		if never then
			view.place = T.NEVER
		elseif type(result) == "table" then
			view.result = result
			if not Compared(view, result, lines, state) then
				view.place = Text(result.why)
				if not view.place then
					Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
				end
			end
			Notes(view, result, later)
		else
			Note(view.notes, view.item.loaded and T.NOT_COMPARED or T.LOADING)
		end
	end
	if view.layout == "none" then
		Profile(view, lines, state, stats)
	end
	if #view.rows == 0 then
		view.message = T.EMPTY
	end
	view.weights = #view.rows > 0 and Opt("gearTotals") ~= "off" and Fn(ns, "GearSetWeight") ~= nil
	return view
end

local function Compute()
	W.used = nil
	if W.link and W.base and SameSlot(W.link, W.base) ~= false then
		W.used = W.base
	end
	local view
	if W.mode == "avoid" then
		view = AvoidView()
		if not view then
			W.mode = Role((Touch())) == "tank" and "threat" or "cast"
		end
	end
	view = view or SpellView()
	view.overall = O.Overall(view, view.lines or Chosen())
	view.baseOther = W.link ~= nil and W.base ~= nil and not W.used
	return view
end

local function Key()
	local look = W.link and ItemLook(W.link) or nil
	local base = W.base and ItemLook(W.base) or nil
	return table.concat({ tostring(Ask(ns.SpellModel, "Version")), tostring(Ask(ns, "GearListVersion")), W.mode, W.link or "",
		look and look.loaded and "loaded" or "", W.base or "", base and base.loaded and "loaded" or "", tostring(Ask(ns.GearAvoid, "Stamp")) }, "\n")
end

function Refresh(key)
	if not W.frame then
		return
	end
	if not key then
		Touch()
		key = Key()
	end
	W.drawn = key
	W.fight = Fighting()
	W.dirty = false
	W.view = Compute()
	Paint(W.view)
end

local function Dims()
	local frame = W.frame
	local okW, width = pcall(frame.GetWidth, frame)
	local okH, height = pcall(frame.GetHeight, frame)
	width = okW and Finite(width) and width > 0 and width or SIZE.W
	height = okH and Finite(height) and height > 0 and height or SIZE.H
	return width, height
end

local function SetCell(text, line, column)
	text:ClearAllPoints()
	if column.justify == "LEFT" then
		text:SetPoint("LEFT", line, "LEFT", column.x, 0)
	else
		text:SetPoint("RIGHT", line, "LEFT", column.x + column.width, 0)
	end
	text:SetWidth(math.max(1, column.width - L.CELL_GAP))
	text:SetJustifyH(column.justify)
end

local function Hang(region, y, height)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
	region:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -L.PAD, -y)
	if height then
		region:SetHeight(height)
	end
end

local function HangText(text, y, inner)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
	text:SetWidth(inner)
end

local function PaintRule(rule, y)
	Hang(rule, y, ns.Pixels(W.frame, 1))
	rule:Show()
end

local function PaintItem(view, y, inner)
	local item, look = W.item, view.item
	local room = inner - L.ICON - L.ICON_GAP
	for _, text in ipairs({ item.name, item.place, item.hint }) do
		text:SetWidth(room)
	end
	local height = L.ICON
	if look then
		if look.icon and pcall(item.icon.SetTexture, item.icon, look.icon) then
			local cut = Crop()
			item.icon:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
			item.icon:Show()
		else
			item.icon:Hide()
		end
		item.name:SetText(look.text)
		item.name:Show()
		item.hint:Hide()
		local need = Height(item.name)
		if view.place then
			item.place:SetText(view.place)
			item.place:Show()
			need = need + L.LINE_GAP + Height(item.place)
		else
			item.place:Hide()
		end
		height = math.max(L.ICON, need)
	else
		item.icon:Hide()
		item.name:Hide()
		item.place:Hide()
		local need = Height(item.hint)
		item.hint:ClearAllPoints()
		item.hint:SetPoint("TOPLEFT", item.box, "TOPRIGHT", L.ICON_GAP, -math.max(0, math.floor((L.ICON - need) / 2)))
		item.hint:Show()
		height = math.max(L.ICON, need)
	end
	Hang(item.button, y, height)
	return y + height + L.GAP
end

local function PaintAgainst(view, y, inner)
	local area = W.against
	local look = W.base and ItemLook(W.base) or nil
	local label = HexOf(Styled("label", LABEL)) .. T.AGAINST_LABEL .. "|r"
	local text
	if look then
		if look.icon and pcall(area.icon.SetTexture, area.icon, look.icon) then
			local cut = Crop()
			area.icon:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
			area.icon:Show()
		else
			area.icon:Hide()
		end
		text = label .. look.text
		if view.baseOther then
			text = text .. DIM_HEX .. ", " .. T.AGAINST_OTHER .. "|r"
		end
	else
		area.icon:Hide()
		text = label .. DIM_HEX .. T.AGAINST_HINT .. "|r"
	end
	area.text:SetWidth(inner - L.SMALL_ICON - L.ICON_GAP)
	area.text:SetText(text)
	local need = Height(area.text)
	area.text:ClearAllPoints()
	area.text:SetPoint("TOPLEFT", area.box, "TOPRIGHT", L.ICON_GAP, -math.max(0, math.floor((L.SMALL_ICON - need) / 2)))
	local height = math.max(L.SMALL_ICON, need)
	Hang(area.button, y, height)
	return y + height + L.GAP
end

local function PaintOverall(view, y, inner)
	local texts, box = view.overall or {}, W.overallBox
	if #texts == 0 then
		box:Hide()
		return y
	end
	local at = 0
	for index, label in ipairs(W.overall) do
		local text = texts[index]
		if text then
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -at)
			label:SetWidth(inner)
			label:SetText(text)
			label:Show()
			at = at + Height(label) + L.LINE_GAP
		else
			label:Hide()
		end
	end
	Hang(box, y, at)
	box:Show()
	return y + at - L.LINE_GAP + L.GAP
end

local function RowName(row, mode)
	local line, entry = row.line, EntryOf(row.line)
	local name = NameOf(line)
	if line.kept then
		local rank = RankOf(line)
		if rank and not name:find("Rank %d") then
			name = T.RANK:format(name, rank)
		end
	end
	local counts = Counts(mode, row)
	if counts then
		name = name .. "  " .. DIM_HEX .. counts .. "|r"
	end
	if line.known == false then
		name = name .. "  " .. FAINT_HEX .. T.NOT_KNOWN .. "|r"
	end
	return name
end

local function CellText(view, row, column)
	if type(row.texts) == "table" then
		local key = column.slot and ("change" .. column.slot) or column.key
		local text = Text(row.texts[key]) or "-"
		local tones = type(row.tones) == "table" and row.tones or {}
		return text, text == "-" and FAINT or (column.slot and ToneColour(tones[key])) or PLAIN
	end
	local key, second = column.key, row.perSecond == true
	if key == "name" then
		return RowName(row, view.mode), row.line.known == false and FAINT or PLAIN
	elseif key == "now" then
		return Value(row.now, second, row.nowEstimate == true), Finite(row.now) and PLAIN or FAINT
	elseif key == "with" then
		local with = row.with and row.with[1]
		return Value(with, second, row.withEstimate == true), Finite(with) and PLAIN or FAINT
	elseif key == "weight" then
		local weight = WeightOf(row.line)
		return WeightText(weight), weight == 0 and FAINT or (weight == WEIGHT.FIRST and DIM) or PLAIN
	end
	local text, tone = Change(row.now, row.with and row.with[column.slot], second, row.estimate)
	return text, text == "-" and FAINT or ToneColour(tone)
end

local function Widest(view, column)
	view.widest = view.widest or {}
	local key = column.key .. ":" .. tostring(column.slot) .. ":" .. tostring(W.fontSize)
	if view.widest[key] then
		return view.widest[key]
	end
	local measure = W.measure
	measure:SetText(column.head)
	local widest = TextWidth(measure, column.head)
	for _, row in ipairs(view.rows) do
		local text = CellText(view, row, column)
		measure:SetText(text)
		widest = math.max(widest, TextWidth(measure, text))
	end
	widest = math.ceil(widest)
	view.widest[key] = widest
	return widest
end

local function Layout(view, inner)
	local list = {}
	for _, def in ipairs(COLUMNS[view.layout] or COLUMNS.none) do
		list[#list + 1] = def
	end
	if view.weights then
		list[#list + 1] = WEIGHT_COLUMN
	end
	local columns, numbers = {}, 0
	for index, def in ipairs(list) do
		local column = { key = def[1], slot = def[3], justify = index == 1 and "LEFT" or "RIGHT" }
		local head = type(view.heads) == "table" and Text(view.heads[column.key]) or def[2]
		column.head = column.slot and head:format(Where(view.cands[column.slot])) or head
		if index > 1 then
			column.width = Widest(view, column) + L.CELL_GAP
			numbers = numbers + column.width
		end
		columns[index] = column
	end
	local name = inner - numbers
	if name < L.NAME and numbers > 0 then
		local share = math.max(0, inner - L.NAME) / numbers
		for index = 2, #columns do
			columns[index].width = math.floor(columns[index].width * share)
		end
		name = math.min(inner, L.NAME)
	end
	columns[1].width = math.max(1, name)
	local x = 0
	for _, column in ipairs(columns) do
		column.x = x
		x = x + column.width
	end
	return columns
end

local function PaintHeads(view, columns, y, count)
	local total, shown = #view.rows, #view.rows > 0
	Hang(W.headRow, y, L.HEAD)
	for index, head in ipairs(W.heads) do
		local column = shown and columns[index] or nil
		if column then
			local text = column.head
			if index == 1 and total > count then
				text = text .. "  " .. FAINT_HEX .. T.SCROLLED:format(W.offset + 1, W.offset + count, total) .. "|r"
			end
			SetCell(head, W.headRow, column)
			head:SetText(text)
			head:Show()
		else
			head:Hide()
		end
	end
	if not shown then
		W.headRule:Hide()
		return
	end
	PaintRule(W.headRule, y + L.HEAD)
end

local function PaintRow(slot, row, view, columns, y)
	local cell, weight = 0, slot.weight
	weight.button:Hide()
	for _, column in ipairs(columns) do
		local text, colour = CellText(view, row, column)
		if column.key == "weight" then
			weight.button:ClearAllPoints()
			weight.button:SetPoint("TOPLEFT", slot.button, "TOPLEFT", column.x, 0)
			weight.button:SetSize(math.max(1, column.width), L.ROW)
			weight.text:SetWidth(math.max(1, column.width - L.CELL_GAP))
			weight.text:SetText(text)
			Colour(weight.text, colour)
			weight.button:Show()
		else
			cell = cell + 1
			local label = slot.cells[cell]
			SetCell(label, slot.button, column)
			label:SetText(text)
			Colour(label, colour)
			label:Show()
		end
	end
	for index = cell + 1, #slot.cells do
		slot.cells[index]:Hide()
	end
	slot.row = row
	Hang(slot.button, y, L.ROW)
	slot.button:Show()
end

local function Pool(count)
	local ar, ag, ab = RGB("windows.accent", 0.85, 0.85, 0.85)
	while #W.rows < math.min(count, MOST_ROWS) do
		local slot = MakeRow(W.frame)
		RowLook(slot, ar, ag, ab)
		W.rows[#W.rows + 1] = slot
	end
end

local function PaintRows(view, columns, y, count)
	local total = #view.rows
	count = math.min(count, MOST_ROWS)
	W.offset = math.max(0, math.min(W.offset, total - count))
	W.shown = count
	Pool(count)
	for index, slot in ipairs(W.rows) do
		local row = index <= count and view.rows[W.offset + index] or nil
		if row then
			PaintRow(slot, row, view, columns, y)
			y = y + L.ROW
		else
			slot.row = nil
			slot.button:Hide()
		end
	end
	return y
end

local function PaintThumb(top, count, total)
	local thumb = W.thumb
	if count <= 0 or total <= count then
		thumb:Hide()
		return
	end
	local track = count * L.ROW
	local height = math.max(L.THUMB_LEAST, math.floor(track * count / total))
	local y = top + math.floor((track - height) * W.offset / (total - count))
	thumb:ClearAllPoints()
	thumb:SetPoint("TOPRIGHT", W.frame, "TOPRIGHT", -math.floor((L.PAD - L.THUMB) / 2), -y)
	thumb:SetSize(L.THUMB, height)
	thumb:Show()
end

local function Against(view)
	local against = Opt("gearAgainst") or "auto"
	local boss = against == "boss" or (against == "auto" and Finite(view.level) and view.level >= MAX_LEVEL)
	local facing = Opt("gearFacing") or "role"
	local front = facing == "front" or (facing == "role" and view.role == "tank")
	local where = front and T.FRONT or T.BEHIND
	if not boss then
		return T.AGAINST_LEVEL:format(where)
	end
	local rules = Opt("gearRules") or "hittable"
	if rules == "hittable" then
		rules = ns.Get("hud.hitTableRules")
	end
	return T.AGAINST_BOSS:format(where, CAPS[rules] or CAPS.classic)
end

local function FootLines(view)
	local texts = {}
	for _, text in ipairs(type(view.foot) == "table" and view.foot or { Against(view), T.BEFORE, T.SKILLS, T.NOT_COUNTED, T.ENCHANTS, T.ESTIMATE }) do
		texts[#texts + 1] = text
	end
	if view.noStats then
		texts[#texts + 1] = T.NO_STATS
	elseif view.old or Fighting() then
		texts[#texts + 1] = T.OLD
	end
	return texts
end

local B = {}

function B.Joined(texts, full)
	if full or #texts < 2 then
		return texts
	end
	local parts = {}
	for _, text in ipairs(texts) do
		text = text:gsub("%s+$", "")
		if text:sub(-3) ~= "..." then
			text = text:gsub("%.$", "")
		end
		parts[#parts + 1] = text
	end
	local joined = table.concat(parts, "; ")
	return { joined:sub(-3) == "..." and joined or (joined .. ".") }
end

function B.Fill(pool, texts, inner)
	local heights, total, count = {}, 0, #texts
	for index, label in ipairs(pool) do
		local text = texts[index]
		if text and index == #pool and count > #pool then
			text = T.MORE:format(count - #pool + 1)
		end
		if text then
			label:SetWidth(inner)
			label:SetText(text)
			heights[index] = Height(label)
			total = total + heights[index] + L.LINE_GAP
		else
			label:Hide()
		end
	end
	return total, heights
end

function B.Lay(pool, heights, y)
	for index, label in ipairs(pool) do
		if heights[index] then
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", W.frame, "TOPLEFT", L.PAD, -y)
			label:Show()
			y = y + heights[index] + L.LINE_GAP
		end
	end
	return y
end

function B.FitBottom(view, inner, room, want)
	local tries = Opt("tipDetail") == "full" and { "full", "compact", "notes", "none" } or { "compact", "notes", "none" }
	local notesH, notesHeights, footH, footHeights, below
	for _, try in ipairs(tries) do
		local full = try == "full"
		notesH, notesHeights = B.Fill(W.notes, try ~= "none" and B.Joined(view.notes, full) or {}, inner)
		footH, footHeights = B.Fill(W.foot, (full or try == "compact") and B.Joined(FootLines(view), full) or {}, inner)
		below = (notesH > 0 and L.GAP + notesH or 0) + (footH > 0 and 2 * L.GAP + footH or 0)
		if room - below >= want then
			break
		end
	end
	return below, notesH, notesHeights, footH, footHeights
end

function Paint(view)
	local frame = W.frame
	if not frame or type(view) ~= "table" then
		return
	end
	PaintLook()
	local width, height = Dims()
	local inner = width - 2 * L.PAD
	PlaceBar(width)
	PaintRule(W.barRule, L.BAR)
	local y = PaintItem(view, L.BAR + L.GAP, inner)
	y = PaintAgainst(view, y, inner)
	y = PaintOverall(view, y, inner)
	local top, total = y, #view.rows
	local columns = Layout(view, inner)
	local headH = total > 0 and L.HEAD + 3 or 0
	local messageH = 0
	if view.message then
		HangText(W.message, 0, inner)
		W.message:SetText(view.message)
		messageH = Height(W.message) + L.LINE_GAP
	end
	local bottom = height - L.PAD + L.LINE_GAP
	local room = bottom - (y + headH + messageH)
	local below, notesH, notesHeights, footH, footHeights = B.FitBottom(view, inner, room, math.min(total, LEAST_ROWS) * L.ROW)
	local count = math.max(0, math.floor((room - below) / L.ROW))
	if total > 0 then
		count = math.max(1, math.min(total, count))
	end
	local rowsTop = y + headH
	y = PaintRows(view, columns, rowsTop, count)
	PaintHeads(view, columns, top, W.shown)
	PaintThumb(rowsTop, W.shown, total)
	if view.message then
		HangText(W.message, y, inner)
		W.message:Show()
		y = y + messageH
	else
		W.message:Hide()
	end
	W.tableLight:ClearAllPoints()
	W.tableLight:SetPoint("TOPLEFT", frame, "TOPLEFT", L.PAD - 3, -top + 2)
	W.tableLight:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -L.PAD + 3, -math.max(y, top + L.ROW))
	local at = bottom - below
	if notesH > 0 then
		at = B.Lay(W.notes, notesHeights, at + L.GAP)
	end
	if footH > 0 then
		PaintRule(W.footRule, at + L.GAP)
		B.Lay(W.foot, footHeights, at + 2 * L.GAP)
	else
		W.footRule:Hide()
	end
end

local function RectOf(frame)
	local ok, left, bottom, width, height = pcall(frame.GetRect, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okBase, base = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (ok and okScale and okBase and Finite(left) and Finite(bottom) and Finite(width) and Finite(height) and Finite(scale) and Finite(base))
		or base <= 0 then
		return nil
	end
	local k = scale / base
	return left * k, bottom * k, width * k, height * k
end

function Place()
	local frame = W.frame
	if not frame or W.moving or W.sizing then
		return
	end
	local x, y, anchor
	if type(ns.MoverSpot) == "function" then
		local ok, sx, sy = pcall(ns.MoverSpot, NAME, "TOPLEFT")
		if ok and Finite(sx) and Finite(sy) then
			x, y, anchor = sx, sy, "BOTTOMLEFT"
		end
	end
	if not x and W.dropped then
		x, y, anchor = W.dropped[1], W.dropped[2], "BOTTOMLEFT"
	end
	if not x then
		x, y, anchor = BOX.x, BOX.y, "TOPLEFT"
	end
	local key = ("%s:%.2f:%.2f"):format(anchor, x, y)
	if W.placed == key then
		return
	end
	W.placed = key
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, anchor, x, y)
end

local function DragStart()
	W.frame:StartMoving()
	W.moving = true
end

function Dropped()
	if not W.moving then
		return
	end
	W.moving = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	W.placed = nil
	local left, bottom, width, height = RectOf(frame)
	if not left then
		Place()
		return
	end
	local top = bottom + height
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local saved = false
	if info and type(kit.Commit) == "function" then
		saved = kit.Commit(NAME, info, left, bottom, width, height) == true
	end
	W.dropped = not saved and { left, top } or nil
	W.placed = nil
	Place()
end

local Z = {}

function Z.SavedSize()
	local char = ns.Character()
	local saved = type(char) == "table" and char.gearWindow or nil
	if type(saved) == "table" and Finite(saved.w) and Finite(saved.h) then
		return saved.w, saved.h
	end
	return nil
end

function Z.Screen()
	local okW, width = pcall(UIParent.GetWidth, UIParent)
	local okH, height = pcall(UIParent.GetHeight, UIParent)
	if okW and okH and Finite(width) and Finite(height) and width > 0 and height > 0 then
		return width, height
	end
	return nil
end

function Z.Clamp(width, height)
	local least = math.max(SIZE.MIN_W, W.barNeed or 0)
	width, height = math.max(least, width), math.max(SIZE.MIN_H, height)
	local sw, sh = Z.Screen()
	if sw then
		width, height = math.min(width, math.max(least, sw)), math.min(height, math.max(SIZE.MIN_H, sh))
	end
	return math.floor(width + 0.5), math.floor(height + 0.5)
end

function Z.Handle()
	local kit = ns.MoverKit
	local show = type(kit) == "table" and kit.ShowHandle or nil
	if type(show) == "function" then
		pcall(show, NAME)
	end
end

function Z.ApplySize()
	local frame = W.frame
	if not frame then
		return
	end
	local width, height = Z.SavedSize()
	width, height = Z.Clamp(width or SIZE.W, height or SIZE.H)
	local maxW, maxH = Z.Clamp(100000, 100000)
	pcall(frame.SetResizeBounds, frame, math.max(SIZE.MIN_W, W.barNeed or 0), SIZE.MIN_H, maxW, maxH)
	frame:SetSize(width, height)
end

function Z.SizeStart()
	if W.moving or W.sizing then
		return
	end
	W.frame:StartSizing("BOTTOMRIGHT")
	W.sizing = true
end

function Z.SizeStop()
	if not W.sizing then
		return
	end
	W.sizing = false
	local frame = W.frame
	frame:StopMovingOrSizing()
	pcall(frame.SetUserPlaced, frame, false)
	local width, height = Z.Clamp(Dims())
	local char = ns.Character()
	if type(char) == "table" then
		char.gearWindow = { w = width, h = height }
	end
	frame:SetSize(width, height)
	W.placed = nil
	Place()
	Z.Handle()
	Paint(W.view)
end

function Z.Reset()
	local char = ns.Character()
	if type(char) == "table" then
		char.gearWindow = nil
	end
	W.dropped = nil
	local kit = ns.MoverKit
	local info = type(kit) == "table" and type(kit.BY_NAME) == "table" and kit.BY_NAME[NAME] or nil
	local _, screenH = Z.Screen()
	if info and type(kit.Commit) == "function" and screenH then
		local width, height = Z.Clamp(SIZE.W, SIZE.H)
		local x = Finite(info.x) and info.x or BOX.x
		local y = Finite(info.y) and info.y or BOX.y
		kit.Commit(NAME, info, x, screenH + y - height, width, height)
	end
	if W.frame then
		Z.ApplySize()
		W.placed = nil
		Place()
		Z.Handle()
		Paint(W.view)
	end
	return true, T.RESET_DONE
end

local function Held()
	if type(GetCursorInfo) ~= "function" then
		return nil
	end
	local ok, kind, id, link, spell = pcall(GetCursorInfo)
	if not ok or IsSecret(kind) then
		return nil
	end
	if kind == "item" then
		local item = AsItem(Text(link)) or AsItem(id)
		return item and "item" or nil, item
	elseif kind == "spell" then
		return Finite(spell) and spell > 0 and "spell" or nil, spell
	elseif kind == "macro" and Finite(id) and type(GetMacroSpell) == "function" then
		local okSpell, cast = pcall(GetMacroSpell, id)
		return okSpell and Finite(cast) and cast > 0 and "spell" or nil, cast
	end
	return nil
end

local function Add(spell)
	local add = Fn(ns, "GearAdd")
	if not add then
		print(T.NO_ADD)
		return
	end
	local ok, done, message = pcall(add, spell)
	if not ok then
		Report("GearAdd", done)
		return
	end
	if Text(message) then
		print(message)
	end
	if done then
		Refresh()
	end
end

local function Lifted()
	local get = Fn(_G.C_Cursor, "GetCursorItem")
	local locked = Fn(C_Item, "IsLocked")
	if not (get and locked) then
		return false
	end
	local ok, place = pcall(get)
	if not ok or IsSecret(place) or type(place) ~= "table" then
		return false
	end
	local slotted = false
	for _, name in ipairs({ "IsBagAndSlot", "IsEquipmentSlot" }) do
		local is = Fn(place, name)
		local okIs, answer = false, nil
		if is then
			okIs, answer = pcall(is, place)
		end
		if okIs and not IsSecret(answer) and answer == true then
			slotted = true
		end
	end
	if not slotted then
		return false
	end
	local okLocked, held = pcall(locked, place)
	return okLocked and not IsSecret(held) and held == true
end

function Drop(target)
	local kind, value = Held()
	if not kind then
		return false
	end
	local now = Now()
	if W.held == value and now - (W.heldAt or 0) < DROP_AGAIN then
		return true
	end
	W.held, W.heldAt = value, now
	if kind == "item" then
		if Lifted() then
			pcall(ClearCursor)
		end
		if target == "against" then
			W.base = value
		else
			W.link, W.offset = value, 0
		end
		Refresh()
	else
		Add(value)
	end
	return true
end

local function Remove(row)
	local remove, id = Fn(ns, "GearRemove"), row and SpellOf(row.line)
	if not (remove and id) then
		return
	end
	local ok, done, message = pcall(remove, id)
	if not ok then
		Report("GearRemove", done)
		return
	end
	if Text(message) then
		print(message)
	end
	Refresh()
end

local function Lights()
	local kind = Held()
	W.item.light:SetShown(kind == "item")
	W.against.light:SetShown(kind == "item")
	W.tableLight:SetShown(kind == "spell")
	local searching = Searching()
	if searching ~= W.searching then
		W.searching = searching
		PaintWords()
	end
end

local function Tick()
	if Fighting() then
		if not W.fight then
			W.fight = true
			Paint(W.view)
		end
		return
	end
	Touch()
	local key = Key()
	if W.dirty or W.fight or key ~= W.drawn then
		Refresh(key)
	end
end

local function Scroll(delta)
	local view = W.view
	if type(view) ~= "table" or not Finite(delta) or delta == 0 then
		return
	end
	local most = math.max(0, #view.rows - W.shown)
	local offset = math.max(0, math.min(most, W.offset + (delta > 0 and -1 or 1)))
	if offset ~= W.offset then
		W.offset = offset
		Paint(view)
	end
end

local function Speed(entry, state)
	if entry.cmp == "wand" then
		return nil
	end
	local part
	for _, held in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(held) == "table" and held[1] == "wpn" then
			part = held
			break
		end
	end
	if not part then
		return nil
	end
	local data = type(ns.SpellData) == "table" and ns.SpellData.MODEL or nil
	local norm = type(data) == "table" and type(data.norm) == "table" and data.norm or NORM
	local swing = type(data) == "table" and type(data.form) == "table" and data.form or SWING
	local power = part.h == "ranged" and T.RANGED_POWER or T.POWER
	local form = type(state) == "table" and Finite(state.form) and FORMS[state.form] or nil
	local kind = (part.spd == "cat" or part.spd == "bear") and part.spd or form
	if kind and Finite(swing[kind]) then
		return T.SPEED_FORM:format(power, kind == "cat" and T.CAT or T.BEAR, swing[kind])
	end
	local weapons = type(state) == "table" and type(state.weapons) == "table" and state.weapons or {}
	local hand = HANDS[part.h] or 16
	local weapon = type(weapons[hand]) == "table" and weapons[hand] or {}
	if part.spd == "norm" or part.spd == "nranged" then
		local which = "one"
		if part.spd == "nranged" or hand == 18 then
			which = "ranged"
		elseif weapon.dagger == true then
			which = "dagger"
		elseif weapon.twoHand == true then
			which = "two"
		end
		return Finite(norm[which]) and T.SPEED_NORM:format(power, norm[which], WEAPONS[which]) or nil
	end
	if Finite(weapon.speed) and weapon.speed > 0 then
		return T.SPEED_OWN:format(power, weapon.speed)
	end
	return T.SPEED_ANY:format(power)
end

local function Measured(entry, line, figure)
	local threat = entry.threat
	local b = type(threat) == "table" and Text(threat.b) or nil
	if figure == "threat" and b then
		local letter = b
		if #b > 1 then
			local at = RankOf(line) or #b
			letter = b:sub(at, at)
		end
		return letter == "m" or threat.apb == "m"
	end
	for _, part in ipairs(type(entry.parts) == "table" and entry.parts or {}) do
		if type(part) == "table" and part.b == "m" then
			return true
		end
	end
	return false
end

local function RowLines(row)
	local lines, line = {}, row.line
	local entry = EntryOf(line)
	local state, stats = Touch()
	local speed = entry and Speed(entry, state) or nil
	if speed then
		lines[#lines + 1] = speed
	end
	local basis, why = row.basis, row.why
	if basis == nil then
		local e = Ask(ns.GearModel, "Expect", line, state, stats, Options(W.mode))
		if type(e) == "table" then
			local threat = row.figure == "threat"
			basis = Text(threat and e.threatBasis or e.basis)
			why = Text(e.why) or (threat and Text(e.threatWhy)) or nil
		end
	end
	if basis == "m" or (basis == nil and entry and Measured(entry, line, row.figure)) then
		lines[#lines + 1] = T.MEASURED
	end
	if row.estimate or basis == "e" then
		lines[#lines + 1] = T.ESTIMATED
	end
	if why then
		lines[#lines + 1] = why
	end
	if entry and entry.nx and W.mode == "second" then
		lines[#lines + 1] = T.NEXT_SWING
	end
	if entry and entry.roll and entry.roll ~= "spell" then
		lines[#lines + 1] = T.ROW_SKILL
	end
	if line.known == false then
		lines[#lines + 1] = T.UNKNOWN
	end
	lines[#lines + 1] = T.REMOVE
	return lines
end

local function RowTip(slot)
	local row = slot.row
	if not row or row.texts or Fighting() then
		return
	end
	local tip, button = Tooltip(), slot.button
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	local id = SpellOf(row.line)
	if not (id and Built(pcall(tip.SetSpellByID, tip, id))) then
		if not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
			return
		end
		pcall(tip.AddLine, tip, NameOf(row.line), PLAIN[1], PLAIN[2], PLAIN[3])
	end
	AddDim(tip, RowLines(row))
	pcall(tip.Show, tip)
end

local function ItemTip()
	local button = W.item.button
	if not W.link or Fighting() then
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	if not Built(pcall(tip.SetHyperlink, tip, W.link)) then
		Untip(button)
		return
	end
	AddDim(tip, T.CLEAR)
	pcall(tip.Show, tip)
end

local U = {}

function U.AgainstTip()
	local button = W.against.button
	if Fighting() then
		return
	end
	if not W.base then
		Say(button, T.AGAINST, T.AGAINST_TIP)
		return
	end
	local tip = Tooltip()
	if not tip or not pcall(tip.SetOwner, tip, button, "ANCHOR_RIGHT") then
		return
	end
	if not Built(pcall(tip.SetHyperlink, tip, W.base)) then
		Untip(button)
		return
	end
	local lines = {}
	if type(W.view) == "table" and W.view.baseOther then
		lines[1] = T.AGAINST_OTHER:sub(1, 1):upper() .. T.AGAINST_OTHER:sub(2) .. "."
	end
	for _, line in ipairs(T.AGAINST_CLEAR) do
		lines[#lines + 1] = line
	end
	AddDim(tip, lines)
	pcall(tip.Show, tip)
end

function U.WeightTip(slot)
	local row = slot.row
	if not row or row.texts then
		return
	end
	Say(slot.weight.button, T.WEIGHT_TIP:format(WeightText(WeightOf(row.line))), T.WEIGHT_LINES)
end

function U.OverallTip()
	local rotation = Ask(ns.GearModel, "Rotation")
	local label = type(rotation) == "table" and Text(rotation.label)
	local first = T.OVERALL_LINES[1]
	if label then
		first = T.OVERALL_ROTATION:format(label .. (rotation.stand == true and T.STAND or ""))
	end
	local lines = { first, T.OVERALL_LINES[2] }
	if Avoiding() then
		local swing, figure = Opt("gearSwing"), Fmt("Figure")
		swing = Finite(swing) and swing or 1500
		lines[#lines + 1] = T.OVERALL_LINES[3]:format(figure and figure(swing) or tostring(math.floor(swing)))
	end
	lines[#lines + 1] = T.OVERALL_LINES[4]
	Say(W.overallBox, T.OVERALL, lines)
end

function U.Modified(kind)
	local fn = Fn(_G, "IsModifiedClick")
	if not fn then
		return false
	end
	local ok, held = pcall(fn, kind)
	return ok and not IsSecret(held) and held == true
end

function U.WholeLink(link)
	local text = Text(link)
	if not text then
		return nil
	end
	if text:find("|H", 1, true) then
		return text
	end
	local info = Fn(C_Item, "GetItemInfo")
	if info then
		local ok, _, whole = pcall(info, text)
		if ok and Text(whole) and whole:find("|H", 1, true) then
			return whole
		end
	end
	return nil
end

function U.ItemModified(link)
	if not link then
		return false
	end
	if U.Modified("CHATLINK") then
		local whole = U.WholeLink(link)
		local insert = Fn(_G.ChatFrameUtil, "InsertLink") or Fn(_G, "ChatEdit_InsertLink")
		if whole and insert then
			pcall(insert, whole)
		end
		return true
	end
	if U.Modified("DRESSUP") then
		if Fighting() then
			print(T.TRY_FIGHT)
			return true
		end
		local dress = Fn(_G, "DressUpItemLink")
		if dress then
			pcall(dress, U.WholeLink(link) or link)
		end
		return true
	end
	return false
end

local function ItemClick(mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	if mouse == "LeftButton" and U.ItemModified(W.link) then
		return
	end
	if mouse == "RightButton" and W.link then
		W.link, W.offset = nil, 0
		Untip(W.item.button)
		Refresh()
	end
end

local function RowClick(slot, mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	if mouse == "RightButton" and slot.row and not slot.row.texts then
		Untip(slot.button)
		Remove(slot.row)
	end
end

function U.AgainstClick(mouse)
	if mouse == "LeftButton" and Drop("against") then
		return
	end
	if mouse == "LeftButton" and U.ItemModified(W.base) then
		return
	end
	if mouse == "RightButton" and W.base then
		W.base = nil
		Untip(W.against.button)
		Refresh()
	end
end

function U.Shift()
	if type(IsShiftKeyDown) ~= "function" then
		return false
	end
	local ok, down = pcall(IsShiftKeyDown)
	return ok and not IsSecret(down) and down == true
end

function U.SetWeight(row, weight)
	local set, id = Fn(ns, "GearSetWeight"), SpellOf(row.line)
	if not set then
		print(T.NO_WEIGHT)
		return
	end
	if not id then
		return
	end
	local ok, done, message = pcall(set, id, weight)
	if not ok then
		Report("GearSetWeight", done)
		return
	end
	if done ~= true and Text(message) then
		print(message)
	end
	Refresh()
end

function U.WeightClick(slot, mouse)
	if mouse == "LeftButton" and Drop() then
		return
	end
	local row = slot.row
	if not row or row.texts then
		return
	end
	local now, weight = WeightOf(row.line), nil
	if U.Shift() then
		weight = WEIGHT.FIRST
	elseif mouse == "RightButton" then
		weight = math.max(WEIGHT.MIN, now - WEIGHT.STEP)
	else
		weight = math.min(WEIGHT.MAX, now + WEIGHT.STEP)
	end
	if weight ~= now then
		U.SetWeight(row, weight)
		U.WeightTip(slot)
	end
end

function U.FindClick()
	if Drop() then
		return
	end
	local toggle = Fn(ns, "GearSearchToggle")
	if not toggle then
		print(T.NO_FIND)
		return
	end
	local ok, err = pcall(toggle)
	if not ok then
		Report("GearSearchToggle", err)
	end
	W.searching = Searching()
	PaintWords()
end

local function Choose(word)
	if Drop() then
		return
	end
	W.chosen = true
	if W.mode ~= word.mode then
		W.mode, W.offset = word.mode, 0
		Refresh()
	end
end

local function Drops(frame, clicks, target)
	frame:SetScript("OnReceiveDrag", function()
		Run(Drop, target)
	end)
	if clicks then
		frame:SetScript("OnMouseUp", function()
			Run(Drop, target)
		end)
	end
end

local function Hover(word, title, lines)
	word.button:SetScript("OnEnter", function()
		word.over = true
		Run(PaintWords)
		Run(Say, word.button, title, lines)
	end)
	word.button:SetScript("OnLeave", function()
		word.over = false
		Run(PaintWords)
		Untip(word.button)
	end)
end

local function MakeSwitch(bar)
	W.seps = {}
	for index = #MODES, 1, -1 do
		local mode = MODES[index]
		local button = Own(CreateFrame("Button", nil, bar))
		button:RegisterForClicks("LeftButtonUp")
		local text = Label(button)
		text:SetPoint("CENTER", button, "CENTER", 0, 0)
		text:SetText(mode[2])
		local word = { mode = mode[1], label = mode[2], button = button, text = text, width = 0 }
		button:SetScript("OnClick", function()
			Run(Choose, word)
		end)
		Hover(word, word.label, { WORD_TIPS[word.mode] })
		Drops(button)
		W.words[index] = word
		W.owners[#W.owners + 1] = button
		if index > 1 then
			local sep = Texture(bar, "ARTWORK")
			sep:SetSize(1, 10)
			W.seps[#W.seps + 1] = sep
			word.sep = sep
		end
	end
end

function U.MakeFind(bar)
	local button = Own(CreateFrame("Button", nil, bar))
	button:RegisterForClicks("LeftButtonUp")
	local text = Label(button)
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetText(T.FIND)
	local find = { label = T.FIND, button = button, text = text, width = 0 }
	button:SetScript("OnClick", function()
		Run(U.FindClick)
	end)
	Hover(find, T.FIND, T.FIND_LINES)
	Drops(button)
	W.find = find
	W.owners[#W.owners + 1] = button
end

local function MakeBar(frame)
	local bar = Own(CreateFrame("Frame", nil, frame))
	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	bar:SetHeight(L.BAR)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		Run(DragStart)
	end)
	bar:SetScript("OnDragStop", function()
		Run(Dropped)
	end)
	bar:SetScript("OnHide", function()
		if W.moving then
			pcall(Dropped)
		end
	end)
	Drops(bar, true)
	W.bar = bar
	W.title = Label(bar, TITLE_FONT)
	W.title:SetPoint("LEFT", bar, "LEFT", L.PAD, 0)
	W.title:SetText(T.TITLE)
	local close = Own(CreateFrame("Button", nil, bar))
	close:SetSize(L.CLOSE, L.CLOSE)
	close:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	close:RegisterForClicks("LeftButtonUp")
	W.close = { button = close,
		lines = { Stroke(close, "OVERLAY", 5, 5, 13, 13), Stroke(close, "OVERLAY", 5, 13, 13, 5) },
		hover = { Stroke(close, "HIGHLIGHT", 5, 5, 13, 13), Stroke(close, "HIGHLIGHT", 5, 13, 13, 5) } }
	close:SetScript("OnClick", function()
		Close()
	end)
	Drops(close)
	U.MakeFind(bar)
	MakeSwitch(bar)
	W.barRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.barRule
end

local function MakeItem(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local item = { button = button }
	item.hover = Texture(button, "HIGHLIGHT")
	item.hover:SetAllPoints(button)
	item.light = Texture(button, "BACKGROUND", 1)
	item.light:SetAllPoints(button)
	item.light:Hide()
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	item.box = box
	item.outline = ns.SetOutlineArea(ns.Outline(box, box), "windows")
	item.icon = Texture(box, "ARTWORK")
	item.icon:SetAllPoints(box)
	item.icon:Hide()
	item.name = Label(button, TITLE_FONT)
	item.name:SetPoint("TOPLEFT", box, "TOPRIGHT", L.ICON_GAP, -1)
	item.place = Label(button, FONT, true)
	item.place:SetPoint("TOPLEFT", item.name, "BOTTOMLEFT", 0, -L.LINE_GAP)
	pcall(item.place.SetMaxLines, item.place, 2)
	item.hint = Label(button, FONT, true)
	item.hint:SetText(T.DROP)
	button:SetScript("OnClick", function(_, mouse)
		Run(ItemClick, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(ItemTip)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	Drops(button)
	W.item = item
	W.owners[#W.owners + 1] = button
end

function U.MakeAgainst(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local area = { button = button }
	area.hover = Texture(button, "HIGHLIGHT")
	area.hover:SetAllPoints(button)
	area.light = Texture(button, "BACKGROUND", 1)
	area.light:SetAllPoints(button)
	area.light:Hide()
	local box = Own(CreateFrame("Frame", nil, button))
	box:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	area.box = box
	area.outline = ns.SetOutlineArea(ns.Outline(box, box), "windows")
	area.icon = Texture(box, "ARTWORK")
	area.icon:SetAllPoints(box)
	area.icon:Hide()
	area.text = Label(button, FONT, true)
	pcall(area.text.SetMaxLines, area.text, 2)
	button:SetScript("OnClick", function(_, mouse)
		Run(U.AgainstClick, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(U.AgainstTip)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	Drops(button, false, "against")
	W.against = area
	W.owners[#W.owners + 1] = button
end

function U.MakeOverall(frame)
	local box = Own(CreateFrame("Frame", nil, frame))
	box:EnableMouse(true)
	for index = 1, OVERALL do
		W.overall[index] = Label(box, FONT, true)
	end
	box:SetScript("OnEnter", function()
		Run(U.OverallTip)
	end)
	box:SetScript("OnLeave", function()
		Untip(box)
	end)
	Drops(box, true)
	box:Hide()
	W.overallBox = box
	W.owners[#W.owners + 1] = box
end

function MakeRow(frame)
	local button = Own(CreateFrame("Button", nil, frame))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:EnableMouseWheel(true)
	local slot = { button = button, cells = {} }
	slot.hover = Texture(button, "HIGHLIGHT")
	slot.hover:SetAllPoints(button)
	for index = 1, 4 do
		slot.cells[index] = Label(button)
	end
	local weight = Own(CreateFrame("Button", nil, button))
	weight:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	weight:EnableMouseWheel(true)
	local hover = Texture(weight, "HIGHLIGHT")
	hover:SetAllPoints(weight)
	local text = Label(weight)
	text:SetPoint("RIGHT", weight, "RIGHT", 0, 0)
	text:SetJustifyH("RIGHT")
	slot.weight = { button = weight, text = text, hover = hover }
	button:SetScript("OnClick", function(_, mouse)
		Run(RowClick, slot, mouse)
	end)
	button:SetScript("OnEnter", function()
		Run(RowTip, slot)
	end)
	button:SetScript("OnLeave", function()
		Untip(button)
	end)
	weight:SetScript("OnClick", function(_, mouse)
		Run(U.WeightClick, slot, mouse)
	end)
	weight:SetScript("OnEnter", function()
		Run(U.WeightTip, slot)
	end)
	weight:SetScript("OnLeave", function()
		Untip(weight)
	end)
	for _, region in ipairs({ button, weight }) do
		region:SetScript("OnMouseWheel", function(_, delta)
			Run(Scroll, delta)
		end)
		Drops(region)
	end
	weight:Hide()
	button:Hide()
	W.owners[#W.owners + 1] = button
	W.owners[#W.owners + 1] = weight
	return slot
end

local function MakeTable(frame)
	W.tableLight = Texture(frame, "BACKGROUND", 1)
	W.tableLight:Hide()
	W.headRow = Own(CreateFrame("Frame", nil, frame))
	W.heads = {}
	for index = 1, 5 do
		W.heads[index] = Label(W.headRow)
	end
	W.headRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.headRule
	W.message = Label(frame, FONT, true)
	for index = 1, NOTES do
		W.notes[index] = Label(frame, FONT, true)
	end
	W.footRule = Texture(frame, "ARTWORK")
	W.rules[#W.rules + 1] = W.footRule
	for index = 1, FOOT do
		W.foot[index] = Label(frame, FONT, true)
	end
	W.thumb = Texture(frame, "OVERLAY")
	W.thumb:Hide()
	W.measure = Label(frame)
	W.measure:Hide()
end

function U.MakeGrip(frame)
	local grip = Own(CreateFrame("Button", nil, frame))
	grip:SetSize(L.GRIP, L.GRIP)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(frame:GetFrameLevel() + 5)
	local lines, hover = {}, {}
	for index, at in ipairs({ 3, 7, 11 }) do
		lines[index] = Stroke(grip, "OVERLAY", L.GRIP - 1, at, at, L.GRIP - 1)
		hover[index] = Stroke(grip, "HIGHLIGHT", L.GRIP - 1, at, at, L.GRIP - 1)
	end
	grip:SetScript("OnMouseDown", function(_, mouse)
		if mouse == "LeftButton" then
			Untip(grip)
			Run(Z.SizeStart)
		end
	end)
	grip:SetScript("OnMouseUp", function()
		Run(Z.SizeStop)
	end)
	grip:SetScript("OnHide", function()
		if W.sizing then
			pcall(Z.SizeStop)
		end
	end)
	grip:SetScript("OnEnter", function()
		if not W.sizing then
			Run(Say, grip, T.GRIP, T.GRIP_LINES)
		end
	end)
	grip:SetScript("OnLeave", function()
		Untip(grip)
	end)
	W.grip = { button = grip, lines = lines, hover = hover }
	W.owners[#W.owners + 1] = grip
end

function U.ApplyFont()
	local size = FontSize()
	if not W.frame or W.fontSize == size then
		return
	end
	W.fontSize = size
	Units(size)
	for _, held in ipairs(W.texts) do
		Sized(held[1], held[2])
	end
	SizeParts()
	Z.ApplySize()
	W.relayout = true
end

local function Special()
	local list = UISpecialFrames
	if type(list) ~= "table" or IsSecret(list) then
		return
	end
	for _, listed in ipairs(list) do
		if listed == NAME then
			return
		end
	end
	table.insert(list, NAME)
end

local function Raise()
	local over = false
	if type(ns.PanelShown) == "function" then
		local ok, shown = pcall(ns.PanelShown)
		over = ok and shown == true
	end
	W.frame:SetFrameStrata(over and "DIALOG" or "MEDIUM")
	pcall(W.frame.Raise, W.frame)
end

local function Showing()
	Want(true)
	Raise()
	if not W.chosen then
		W.mode = Role((Touch())) == "tank" and (Avoiding() and "avoid" or "threat") or "cast"
	end
	W.elapsed, W.looked = 0, 0
	U.ApplyFont()
	Z.ApplySize()
	Place()
	Refresh()
end

local function Hiding()
	Want(false)
	if W.moving then
		pcall(Dropped)
	end
	if W.sizing then
		pcall(Z.SizeStop)
	end
	for _, owner in ipairs(W.owners) do
		Untip(owner)
	end
	if W.item then
		W.item.light:Hide()
		W.against.light:Hide()
		W.tableLight:Hide()
	end
	local shown, toggle = Fn(ns, "GearSearchShown"), Fn(ns, "GearSearchToggle")
	if shown and toggle then
		local ok, open = pcall(shown)
		if ok and open == true then
			local done, err = pcall(toggle)
			if not done then
				Report("GearSearchToggle", err)
			end
		end
	end
end

local function Make()
	W.fontSize = FontSize()
	Units(W.fontSize)
	local frame = Own(CreateFrame("Frame", NAME, UIParent))
	frame:SetFrameStrata("MEDIUM")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:EnableMouse(true)
	frame:EnableMouseWheel(true)
	pcall(frame.SetDontSavePosition, frame, true)
	frame:SetSize(SIZE.W, SIZE.H)
	frame:Hide()
	W.frame = frame
	W.outline = ns.SetOutlineArea(ns.Outline(frame, frame), "windows")
	MakeBar(frame)
	MakeItem(frame)
	U.MakeAgainst(frame)
	U.MakeOverall(frame)
	MakeTable(frame)
	U.MakeGrip(frame)
	Drops(frame, true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		Run(Scroll, delta)
	end)
	frame:SetScript("OnShow", function()
		W.fade = 0
		frame:SetAlpha(0)
		if W.held then
			W.held = nil
		elseif type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_OPEN then
			pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		end
		Run(Showing)
	end)
	frame:SetScript("OnHide", function()
		local holding = type(ns.MoversMode) == "table" and type(ns.MoversMode.Holding) == "function" and ns.MoversMode.Holding() == true
		W.held, W.fade = holding or nil, nil
		if not holding and not W.quiet and type(PlaySound) == "function" and type(SOUNDKIT) == "table" and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then
			pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
		end
		Hiding()
	end)
	frame:SetScript("OnSizeChanged", function()
		W.relayout = true
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		local step = Finite(elapsed) and elapsed or 0
		W.elapsed, W.looked = W.elapsed + step, W.looked + step
		if W.fade then
			W.fade = W.fade + step
			if W.fade >= FADE_IN then
				W.fade = nil
				frame:SetAlpha(1)
			else
				frame:SetAlpha(W.fade / FADE_IN)
			end
		end
		if W.relayout then
			W.relayout = false
			Run(Paint, W.view)
		end
		if W.looked >= LOOK then
			W.looked = 0
			Run(Lights)
		end
		if W.elapsed >= TICK then
			W.elapsed = 0
			if Allowed() then
				Run(Tick)
			else
				Close(true)
			end
		end
	end)
	SizeParts()
	Z.ApplySize()
	Special()
	PaintLook()
	Place()
end

local function Open(link, base)
	if link then
		W.link, W.offset = link, 0
	end
	if base == false then
		W.base = nil
	elseif base then
		W.base = base
	end
	if not W.frame then
		if Fighting() then
			W.opening = true
			if not W.queued then
				W.queued = true
				print(T.AFTER_FIGHT)
				ns.OutOfCombat(function()
					W.queued = false
					if W.opening and Allowed() then
						W.opening = false
						Run(function()
							Open()
						end)
					end
				end)
			end
			return
		end
		Make()
	end
	if W.frame:IsShown() then
		Raise()
		Refresh()
	else
		Place()
		W.frame:Show()
	end
end

function Close(quiet)
	W.opening = false
	if W.frame then
		W.quiet = quiet == true or nil
		pcall(W.frame.Hide, W.frame)
		W.quiet = nil
	end
	Want(false)
end

function ns.GearWindowToggle()
	if W.opening then
		W.opening = false
		return true
	end
	if W.frame and W.frame:IsShown() then
		Close()
		return true
	end
	if not Allowed() then
		print(Refusal())
		return false
	end
	return Run(Open)
end

function ns.GearWindowShow(link, base)
	if not Allowed() then
		print(Refusal())
		return false
	end
	if base ~= false then
		base = AsItem(base)
	end
	return Run(Open, AsItem(link), base)
end

function U.Key(name)
	local fn = Fn(_G, name)
	if not fn then
		return false
	end
	local ok, down = pcall(fn)
	return ok and not IsSecret(down) and down == true
end

function U.ChatClick(_, _, link, text, button)
	if IsSecret(button) or button ~= "LeftButton" or not Text(link) or link:sub(1, 5) ~= "item:" then
		return
	end
	if not U.Key("IsAltKeyDown") or U.Key("IsShiftKeyDown") or U.Key("IsControlKeyDown") then
		return
	end
	if U.Modified("CHATLINK") or U.Modified("DRESSUP") or not Allowed() then
		return
	end
	local whole = Text(text)
	ns.GearWindowShow(whole and whole:find("|H", 1, true) and whole or link)
end

if type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function" then
	pcall(EventRegistry.RegisterCallback, EventRegistry, "ChatFrame.OnHyperlinkClick", U.ChatClick, "FlatUI.chat.gearLink")
end

function ns.GearWindowAgainst(link)
	if not Allowed() then
		print(Refusal())
		return false
	end
	local base = AsItem(link)
	if base then
		return Run(Open, nil, base)
	end
	W.base = nil
	if ns.GearWindowOpen() then
		return Run(Refresh)
	end
	return true
end

function ns.GearWindowResetLines()
	return { { 1, T.RESET_LINE } }
end

function ns.GearWindowResetPick(id)
	if id ~= 1 then
		return false, nil
	end
	local ok, done, message = pcall(Z.Reset)
	if not ok then
		Report("reset", done)
		return false, T.RESET_FAILED
	end
	return done, message
end

function ns.GearWindowShown()
	return Allowed()
end

function ns.GearWindowOpen()
	local frame = W.frame
	if not frame then
		return false
	end
	local ok, shown = pcall(frame.IsShown, frame)
	return ok and shown == true
end

function ns.GearWindowMoved()
	W.placed, W.dropped = nil, nil
	if W.frame then
		Run(Place)
	end
end

function ns.GearWindowSync()
	if not Allowed() then
		Close(true)
		return
	end
	if W.frame then
		W.dirty = true
		Run(U.ApplyFont)
		Run(PaintLook)
	end
end

if type(ns.AddStatus) == "function" then
	ns.AddStatus(KEY, function()
		local frame = W.frame
		if not (frame and W.link and Allowed()) then
			return {}
		end
		local ok, shown = pcall(frame.IsShown, frame)
		if not ok or shown ~= true then
			return {}
		end
		local _, name = LinkParts(W.link)
		local look = W.view and W.view.item or nil
		name = name or (look and look.name) or "an item"
		if W.used then
			local _, base = LinkParts(W.used)
			return { T.STATUS_AGAINST:format(name, base or ItemLook(W.used).name) }
		end
		return { T.STATUS:format(name) }
	end)
end

do
	local name = "FlatUIGearKey"
	_G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = "Gear comparison window"
	local ok, button = pcall(CreateFrame, "Button", name, UIParent)
	if ok and type(button) == "table" then
		ns.Own[button] = true
		pcall(button.RegisterForClicks, button, "LeftButtonUp")
		button:SetScript("OnClick", function()
			local okRun, err = pcall(ns.GearWindowToggle)
			if not okRun then
				geterrorhandler()(err)
			end
		end)
	end
end
