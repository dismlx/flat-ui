local _, ns = ...

local KEY = "combattext"
local HEIGHT_GAME, HEIGHT_POINTS, HEIGHT_STEP = 40, 5, 0.00375
local CRIT_RISE = 0.0125
local GAME = {}
local TEXT_HEIGHT = 25
local POP = { up = 0.05, down = 0.2, peak = 1.3, crit = 1.2, critPeak = 2.4 }
local LOOK = { raster = 64, last = { thick = "CombatTextFontOutline", thin = "CombatTextFontOutline", none = "CombatTextFont" },
	shows = { thick = "a thick outline and a shadow", thin = "a thick outline and a shadow", none = "a shadow" },
	faces = { friz = { "CombatTextFont", "Fonts\\FRIZQT__.TTF", "Friz Quadrata" }, arial = { "Number12Font", "Fonts\\ARIALN.TTF", "Arial Narrow" },
		skurri = { "NumberFont_Outline_Huge", "Fonts\\skurri.ttf", "Skurri" }, morpheus = { "QuestFont_Super_Huge", "Fonts\\MORPHEUS.ttf", "Morpheus" } },
	outlines = { thick = { "CombatTextFontOutline", "OUTLINE, THICK" }, thin = { "SystemFont_Huge1_Outline", "OUTLINE" }, none = { nil, "" } } }
local look, objects = {}, {}
local OWN = { mover = "FlatUICombatSelf", screen = 768 }
local own = { reports = 0, failed = 0, last = {} }
local CLASSIC = { life = 1.9, fadeFrom = 1.3 / 1.9, line = 26 / 25, side = 80, ref = 40, kinds = { glancing = 0.75, word = 0.75, immune = 0.5 },
	game = { physical = { 1, 0.1, 0.1 }, magic = { 0.79, 0.3, 0.85 }, heal = { 0.1, 1, 0.1 } }, columns = { 0, 1, -1 } }
local LIFE, FADE_FROM = 1.5, 1.0
local RISE, GRAVITY = 100, 160
local CLIMB = 40
local LANES = { 0, 20, -20, 40, -40 }
local DRIFT = 0.75
local LANE_PITCH, LANE_REACH, REF_HEIGHT, ROW_STEP, PEAK_GROW = 20, 40, 40, 1.05, 60
local RASTER = { 64, 128 }
local DRIFT_CAP = 40 * DRIFT
local CRIT_LIFT = 10
local MAX_LIVE, MAX_LIVE_CLASSIC = 40, 60
ns.CombatShape = { heightGame = HEIGHT_GAME, text = TEXT_HEIGHT, pop = POP, life = LIFE, fade = FADE_FROM, lanes = LANES, critLift = CRIT_LIFT, classic = CLASSIC }
local STRATA = { "WORLD", "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG" }
local UNKNOWN_STRATA = "HIGH"
local SCHOOLS = { [2] = { 1, 0.9, 0.5 }, [4] = { 1, 0.5, 0 }, [8] = { 0.3, 1, 0.3 }, [16] = { 0.5, 1, 1 }, [32] = { 0.5, 0.5, 1 }, [64] = { 1, 0.5, 1 } }
local MINE = { cast = 1.5, travel = 3.0, areaMax = 10, dotKeep = 30, shots = { [75] = true, [2480] = true, [7918] = true, [2764] = true, [7919] = true, [5019] = true }, tail = 0.5, aura = 0.5, offAfter = 10, swingGap = 1.0, tick = 3.0, swingShare = 0.8, auraMax = 4, extra = 0.4, nextSwing = { 6807, 78, 845, 2973 },
	late = 0.1, swingTake = 0.3, pairTail = 0.4, nextMax = 5, spinSlack = 0.6, engaged = 10, queueMax = 200, fresh = 0.3, auraTick = 2.0, hold = 0.1,
	gather = 0.2, words = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, EVADE = true, DEFLECT = true, REFLECT = true, INTERRUPT = true },
	partyTokens = { "party1", "partypet1", "party2", "partypet2", "party3", "partypet3", "party4", "partypet4" },
	unitEvents = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" },
	plainEvents = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTERING_WORLD", "PLAYER_SWING" } }
local mine = { castUntil = -1, castAt = 0, on = false, deaf = false, chan = false, swing = false, shoot = false, aura = {}, heard = 0, blind = 0, left = 0, kept = 0,
	unheard = 0, off = false, last = nil, castSlots = {}, castTaken = -1, hand = { main = -math.huge, off = -math.huge }, shotAt = -math.huge, shotEnd = -math.huge, auraSlots = {}, swingAt = -math.huge, extraUsed = false,
	dots = setmetatable({}, { __mode = "k" }), chanTakes = false, chanArea = false, healUntil = -1, trace = false, crowd = setmetatable({}, { __mode = "k" }),
	swings = {}, swingHeard = false, rangedHeard = false, swingCount = 0, lastMain = -math.huge, due = {}, hitBy = setmetatable({}, { __mode = "k" }), queue = {},
	strikeAt = -math.huge, counter = nil, struckAt = {}, petAt = -math.huge }
MINE.crowd = 10

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Classic()
	return Opt("style") == "classic"
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function InGroup()
	if type(IsInGroup) ~= "function" then
		return false
	end
	local ok, grouped = pcall(IsInGroup)
	return ok and Plain(grouped, "boolean") and grouped
end

local function Calls()
	return type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" and type(C_CVar.SetCVar) == "function"
end

local function Read(name)
	if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" then
		return nil
	end
	local ok, value = pcall(C_CVar.GetCVar, name)
	if ok and Plain(value, "string") then
		return value
	end
	return nil
end

local function Same(a, b)
	local x, y = tonumber(a), tonumber(b)
	if x and y then
		return math.abs(x - y) < 1e-6
	end
	return a == b
end

local function Text(number)
	local text = (("%.5f"):format(number):gsub("0+$", ""))
	if text:sub(-1) == "." then
		text = text .. "0"
	end
	return text
end

local function GameDefault(var)
	if type(C_CVar) == "table" and type(C_CVar.GetCVarDefault) == "function" then
		local ok, value = pcall(C_CVar.GetCVarDefault, var.name)
		if ok and Plain(value, "string") and value ~= "" then
			return value
		end
	end
	return var.default
end

local function Records(create)
	local db = ns.Account()
	if db == nil then
		return nil
	end
	if type(db.cvars) ~= "table" then
		if not create then
			return nil
		end
		db.cvars = {}
	end
	for name, rec in pairs(db.cvars) do
		if type(rec) ~= "table" or not Plain(rec.game, "string") then
			db.cvars[name] = nil
		end
	end
	return db.cvars
end

local proven = false
local friendProven = false
local atLogin
local retry = false
local Sync

local function GroupHand()
	return Opt("source") == "front" and Opt("group") == "game" and InGroup() and Opt("where") ~= "scroll"
end

local function Switch()
	if (Opt("source") == "front" or Opt("where") == "scroll") and proven and not (mine.off and Opt("whose") ~= "all") and not GroupHand() then
		return "0"
	end
	return nil
end

local function FriendMode()
	if not ns.Enabled(KEY) then
		return "off"
	end
	return Opt("friend")
end

local function FriendHealSwitch()
	if FriendMode() ~= "off" and Opt("friendHeal") == "taken" and friendProven then
		return "0"
	end
	return nil
end

local function Height(crit)
	local number = (Opt("height") - HEIGHT_GAME) / HEIGHT_POINTS * HEIGHT_STEP + ((crit and Opt("crit") == "higher") and CRIT_RISE or 0)
	if number == 0 then
		return GAME
	end
	return Text(number)
end

local GAIN_SMALLER = 0.75
local GAIN_WORDS = { own = "Same as your text", smaller = "Smaller than your text", game = "The game's own size", enemy = "Same as numbers over enemies" }
local function Size()
	local percent = Opt("size")
	if Switch() == "0" or GroupHand() then
		local gain = Opt("gainSize")
		if gain == "game" then
			return GAME
		elseif gain == "own" then
			percent = Opt("ownSize")
		elseif gain == "smaller" then
			percent = Opt("ownSize") * GAIN_SMALLER
		end
	end
	if percent == 100 then
		return GAME
	end
	return Text(percent / 100)
end

local function Spread()
	if Opt("spread") ~= "loose" then
		return "0.0"
	end
	if Opt("spreadWidth") == 100 then
		return GAME
	end
	return Text(Opt("spreadWidth") / 100)
end

local function Movement()
	if Opt("movement") ~= "up" then
		return GAME
	end
	return "0.0"
end

local function OwnSwitch()
	if Opt("own") ~= "off" then
		return "0"
	end
	return nil
end

local HEAL_VAR = "floatingCombatTextCombatHealing_v2"

local VARS = {
	{ name = "floatingCombatTextCombatDamage_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextCombatLogPeriodicSpells_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextPetMeleeDamage_v2", default = "1", value = Switch },
	{ name = "floatingCombatTextPetSpellDamage_v2", default = "1", value = Switch },
	{ name = "WorldTextScreenY_v2", default = "0.0", value = function() return Height(false) end },
	{ name = "WorldTextCritScreenY_v2", default = "0.0", value = function() return Height(true) end },
	{ name = "WorldTextScale_v2", default = "1.000000", value = Size },
	{ name = "WorldTextStartPosRandomness_v2", default = "1.0", value = Spread },
	{ name = "WorldTextGravity_v2", default = "0.500000", value = Movement },
	{ name = HEAL_VAR, default = "1", value = FriendHealSwitch },
	{ name = "enableFloatingCombatText", default = "0", value = OwnSwitch, keep = true, setting = true },
}
local SELF_VAR = VARS[#VARS]

local function GameTextLoaded()
	if type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, "Blizzard_CombatText")
		if ok and Plain(loaded, "boolean") then
			return loaded
		end
	end
	return type(CombatText_UpdateDisplayedMessages) == "function"
end

local function TellSetting(var, text)
	if not var.setting or (text ~= "0" and text ~= "1") or not GameTextLoaded() then
		return false
	end
	if not (type(Settings) == "table" and type(Settings.GetSetting) == "function" and type(Settings.SetValue) == "function") then
		return false
	end
	local ok, setting = pcall(Settings.GetSetting, var.name)
	if not ok or setting == nil then
		return false
	end
	return pcall(Settings.SetValue, var.name, text == "1", true) and Same(Read(var.name), text)
end

local function Wanted(var)
	if not ns.Enabled(KEY) then
		return nil
	end
	local value = var.value()
	if value == GAME then
		return GameDefault(var)
	end
	return value
end

local function Write(var, text)
	local before = Read(var.name)
	if not TellSetting(var, text) then
		pcall(C_CVar.SetCVar, var.name, text)
	end
	local kept = Read(var.name)
	if var.note then
		ns.ClearNote(KEY, var.note)
		var.note = nil
	end
	if kept == nil or (Same(kept, before) and not Same(before, text) and var.clamp ~= text) then
		var.note = ("%s: the game refused %s."):format(var.name, text)
		ns.Note(KEY, var.note)
		if InCombatLockdown() and not retry then
			retry = true
			ns.OutOfCombat(function()
				retry = false
				Sync()
			end)
		end
	elseif not Same(kept, text) then
		var.clamp = text
		var.note = ("%s: the game keeps %s for %s."):format(var.name, kept, text)
		ns.Note(KEY, var.note)
	else
		var.clamp = nil
	end
	return kept
end

local function LoginState(store)
	if store == nil or next(store) == nil then
		return "nothing remembered"
	end
	local written, game = false, true
	for name, rec in pairs(store) do
		local current = Read(name)
		if current ~= nil then
			if rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
				written = true
			end
			if not Same(current, rec.game) then
				game = false
			end
		end
	end
	if written then
		return "the values written last session"
	end
	return game and "the game's own values" or "other values"
end

function Sync()
	if not Calls() then
		return
	end
	local store = Records(false)
	if not proven then
		proven = store ~= nil and store[VARS[1].name] ~= nil
	end
	friendProven = friendProven or (store ~= nil and store[HEAL_VAR] ~= nil)
	if atLogin == nil then
		atLogin = LoginState(store)
	end
	for _, var in ipairs(VARS) do
		local current = Read(var.name)
		if current ~= nil then
			local wanted = Wanted(var)
			local rec = store and store[var.name]
			local wrote = false
			if wanted ~= nil and Same(current, wanted) then
				if rec and Same(rec.game, wanted) then
					store[var.name] = nil
				elseif rec then
					rec.wrote = current
				end
			elseif wanted ~= nil then
				if not rec then
					store = Records(true)
					rec = { game = current }
					store[var.name] = rec
				elseif rec.wrote == nil or not Same(current, rec.wrote) then
					rec.game = current
				end
				wrote = true
				local kept = Write(var, wanted)
				if kept ~= nil and Same(kept, rec.game) then
					store[var.name] = nil
				elseif kept ~= nil and not Same(kept, current) then
					rec.wrote = kept
				elseif rec.wrote == nil then
					store[var.name] = nil
				end
			elseif rec then
				if rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
					wrote = true
					local kept = Write(var, rec.game)
					if kept ~= nil and Same(kept, rec.game) then
						store[var.name] = nil
					end
				else
					store[var.name] = nil
				end
			end
			if not wrote and var.note then
				ns.ClearNote(KEY, var.note)
				var.note = nil
			end
		end
	end
	if store and next(store) == nil then
		ns.Account().cvars = nil
	end
end

local function Leave()
	if not Calls() then
		return
	end
	for name, rec in pairs(Records(false) or {}) do
		local current = Read(name)
		if current ~= nil and rec.wrote ~= nil and Same(current, rec.wrote) and not Same(current, rec.game) then
			pcall(C_CVar.SetCVar, name, rec.game)
		end
	end
end

local host, ticker
local free, live = {}, {}
local hostRank = 0
local count = setmetatable({}, { __mode = "k" })
local stats = { reports = 0, target = 0, shown = 0, noPlate = 0, friendly = 0, detail = 0, amount = 0, kind = 0, unplaced = 0, unstyled = 0, kept = 0, removed = 0, columns = { [0] = 0, [1] = 0, [-1] = 0 } }
local last = {}
local FRIEND_MAX, FRIEND_PER_UNIT = 20, 4
local FRIEND_SAME = 0.02
local FRAMES_FOR = 1
local friend = { live = 0, shown = 0, reports = 0, plates = 0, group = 0, pet = 0, noAnchor = 0, unknown = 0, same = 0, forbidden = 0, self = 0,
	last = {}, recent = setmetatable({}, { __mode = "k" }) }
local frames = { at = 0, byUnit = {} }
local plateStrata, hostStrata
local fr = { free = {}, rank = 0 }

local function Plate(unit)
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then
		return nil
	end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
	if not ok or ns.Forbidden(plate) then
		return nil
	end
	return plate
end

local function Raster()
	local largest = math.max(Opt("size") or 0, Opt("friendSize") or 0, Opt("ownSize") or 0)
	if TEXT_HEIGHT * largest / 100 * POP.crit > RASTER[1] then
		return RASTER[2]
	end
	return RASTER[1]
end

local function LookKey(font, outline, shadow)
	return font .. "_" .. outline .. "_" .. (shadow and "shadow" or "plain") .. (Raster() == RASTER[1] and "" or "_r" .. Raster())
end

local function FromGame(name)
	local ok, file, height, flags = pcall(function()
		return _G[name]:GetFont()
	end)
	if not ok then
		return nil, nil, nil
	end
	return Plain(file, "string") and file ~= "" and file or nil, Plain(height, "number") and height or nil, Plain(flags, "string") and flags or nil
end

function ns.CombatFont(font, outline)
	local face, line = LOOK.faces[font], LOOK.outlines[outline]
	local file = FromGame(face[1])
	local _, _, flags = FromGame(line[1])
	return file or face[2], (flags ~= nil and flags ~= "") and flags or line[2]
end

local function MakeObject(font, outline, shadow)
	local file, flags = ns.CombatFont(font, outline)
	local name = "FlatUICombat_" .. LookKey(font, outline, shadow)
	local ok, kept, made = pcall(function()
		local object = CreateFont(name)
		object:SetFont(file, Raster(), flags)
		object:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
		object:SetShadowColor(0, 0, 0, shadow and 1 or 0)
		return (object:GetFont()), object
	end)
	if ok and Plain(kept, "string") and kept ~= "" then
		return name, made
	end
	return nil
end

local function Object(font, outline, shadow)
	local key = LookKey(font, outline, shadow)
	if objects[key] == nil then
		local name, object = MakeObject(font, outline, shadow)
		objects[key] = name and { name = name, object = object } or false
	end
	return objects[key] or nil
end

local function Look()
	local font, outline, shadow = Opt("font"), Opt("outline"), Opt("shadow")
	local key = LookKey(font, outline, shadow)
	if look.key == key then
		return look
	end
	if look.note then
		ns.ClearNote(KEY, look.note)
		look.note = nil
	end
	look.key, look.outline, look.last = key, outline, LOOK.last[outline]
	local made = Object(font, outline, shadow)
	if not made then
		local fallback = Object("friz", outline, shadow)
		made = fallback or { name = LOOK.last[outline], object = _G[LOOK.last[outline]] }
		look.note = ("%s: the game refused the font. Numbers show in %s."):format(LOOK.faces[font][3],
			fallback and LOOK.faces.friz[3] or ("the game's combat font, with " .. LOOK.shows[outline]))
		ns.Note(KEY, look.note)
	end
	look.name, look.object = made.name, made.object
	return look
end

ns.CombatLook = Look

local function Style(item)
	if not pcall(item.text.SetFontObject, item.text, look.object or look.name) then
		stats.unstyled = stats.unstyled + 1
	end
	item.style, item.height = look.key, nil
end

local function Screen(strata)
	local frame = CreateFrame("Frame", nil, UIParent)
	ns.Own[frame] = true
	frame:SetAllPoints(UIParent)
	frame:SetFrameStrata(strata)
	return frame
end

local function Host()
	if host then
		return
	end
	local frame = Screen("LOW")
	ticker = CreateFrame("Frame")
	hostRank, hostStrata = 3, "LOW"
	host = frame
end

local function RankOf(strata)
	for index, name in ipairs(STRATA) do
		if name == strata then
			return index
		end
	end
	return nil
end

local function FrameHost()
	Host()
	if not fr.host then
		fr.host = Screen("LOW")
		fr.rank = 3
	end
end

local function RaiseFrame(anchor)
	local ok, strata = pcall(anchor.GetFrameStrata, anchor)
	local index = ok and Plain(strata, "string") and RankOf(strata) or nil
	local rank = RankOf(index and STRATA[math.min(index + 1, #STRATA)] or UNKNOWN_STRATA)
	if rank > fr.rank then
		pcall(fr.host.SetFrameStrata, fr.host, STRATA[rank])
		fr.rank = rank
	end
end

local function Raise(plate)
	local ok, strata = pcall(plate.GetFrameStrata, plate)
	local index = ok and Plain(strata, "string") and RankOf(strata) or nil
	plateStrata = index and strata or "unknown"
	local wanted = index and STRATA[math.min(index + 1, #STRATA)] or UNKNOWN_STRATA
	local rank = RankOf(wanted)
	if rank > hostRank then
		pcall(host.SetFrameStrata, host, wanted)
		hostRank, hostStrata = rank, wanted
	end
end

local WORDS = { MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist", ABSORB = "Absorb", IMMUNE = "Immune",
	EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect", INTERRUPT = "Interrupt" }

local function Word(name, bare)
	local game = WORDS[name] and _G[name]
	local text = Plain(game, "string") and game ~= "" and game or WORDS[name]
	if not text or bare or Opt("missWords") == "bare" then
		return text
	end
	return "(" .. text .. ")"
end

function ns.CombatParen(text)
	return Opt("missWords") == "bare" and text or "(" .. text .. ")"
end

local function Suffix(flag)
	if Opt("partial") ~= "word" then
		return nil
	elseif flag == "GLANCING" then
		return Plain(TEXT_MODE_A_STRING_RESULT_GLANCING, "string") and TEXT_MODE_A_STRING_RESULT_GLANCING or "(Glancing)"
	elseif flag == "CRUSHING" then
		return Plain(TEXT_MODE_A_STRING_RESULT_CRUSHING, "string") and TEXT_MODE_A_STRING_RESULT_CRUSHING or "(Crushing)"
	elseif flag == "BLOCK_REDUCED" or flag == "BLOCK" then
		return "(" .. Word("BLOCK", true) .. ")"
	elseif flag == "ABSORB" then
		return "(" .. Word("ABSORB", true) .. ")"
	elseif flag == "RESIST" then
		return "(" .. Word("RESIST", true) .. ")"
	end
	return nil
end
ns.CombatSuffix = Suffix

function ns.CombatWithheld(value, before, after)
	local util = C_StringUtil
	if type(util) ~= "table" or type(util.TruncateWhenZero) ~= "function" then
		return false
	end
	local ok, digits = pcall(util.TruncateWhenZero, value)
	if not ok or not (ns.IsSecret(digits) or type(digits) == "string") then
		return false
	end
	if before == nil and after == nil then
		return true, digits
	end
	if type(util.WrapString) ~= "function" then
		return false
	end
	local wrapped
	ok, wrapped = pcall(util.WrapString, digits, before, after)
	if not ok or not (ns.IsSecret(wrapped) or type(wrapped) == "string") then
		return false
	end
	return true, wrapped
end

function ns.CombatColour(school, bySchool, palette)
	local physical = ns.IsSecret(school) or type(school) ~= "number" or school == 1
	local colour = not physical and bySchool and SCHOOLS[school]
	if colour then
		return colour[1], colour[2], colour[3]
	end
	if palette == "game" then
		colour = physical and CLASSIC.game.physical or CLASSIC.game.magic
		return colour[1], colour[2], colour[3]
	end
	if physical then
		return 1, 1, 1
	end
	return 1, 1, 0
end

local function Colour(school)
	return ns.CombatColour(school, Opt("school"), Classic() and Opt("classicColour") or nil)
end

local function KindSize(flag, name)
	local smaller = Opt("partial") == "smaller"
	if name == nil then
		return smaller and flag == "GLANCING" and CLASSIC.kinds.glancing or nil
	elseif smaller and name == "IMMUNE" then
		return CLASSIC.kinds.immune
	elseif smaller and (name == "BLOCK" or name == "ABSORB" or name == "RESIST") then
		return CLASSIC.kinds.word
	end
	return Opt("missSize") ~= "same" and CLASSIC.kinds.word or nil
end

function ns.CombatWordSize()
	return Opt("missSize") ~= "same" and CLASSIC.kinds.word or 1
end

local function DescribeOwn(level, event, flag, amount, none, school)
	local more = level == "more"
	if event == "WOUND" then
		if none then
			if not more then
				return nil
			end
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), "%s", false, 1, 1, 1, nil, KindSize(flag, name)
		end
		local crit = flag == "CRITICAL" or flag == "CRUSHING"
		if Plain(school, "number") and school ~= 1 then
			local colour = Opt("school") == true and SCHOOLS[school]
			if colour then
				return "amount", amount, "-%s", crit, colour[1], colour[2], colour[3]
			end
			return "amount", amount, "-%s", crit, 0.79, 0.3, 0.85
		end
		local r, g, b = ns.Colour(KEY .. ".ownDamageColour")
		return "amount", amount, "-%s", crit, r, g, b
	elseif event == "HEAL" then
		if none or Opt("ownHeal") ~= true then
			return nil
		end
		local r, g, b = ns.Colour(KEY .. ".ownHealColour")
		return "amount", amount, "+%s", flag == "CRITICAL", r, g, b
	elseif event == "ENERGIZE" then
		if not more or none or (Plain(amount, "number") and amount < 0) then
			return nil
		end
		return "amount", amount, "+%s", flag == "CRITICAL", 0.41, 0.8, 0.94
	elseif more and WORDS[event] then
		return "word", Word(event), "%s", false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

local function DescribeFriend(event, flag, amount, none, school)
	local crit = flag == "CRITICAL" or flag == "CRUSHING"
	if event == "WOUND" then
		if none then
			if not Opt("friendWords") then
				return nil
			end
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), nil, false, 1, 1, 1, nil, KindSize(flag, name)
		end
		if not Opt("friendDamage") then
			return nil
		end
		local r, g, b
		if Opt("school") then
			r, g, b = Colour(school)
		else
			r, g, b = ns.Colour(KEY .. ".friendDamageColour")
		end
		return "amount", amount, (flag and Suffix(flag)) or nil, crit, r, g, b, Opt("friendSigns") and "-" or nil, KindSize(flag)
	elseif event == "HEAL" then
		if none or Opt("friendHeal") ~= "taken" then
			return nil
		end
		local r, g, b = ns.Colour(KEY .. ".friendHealColour")
		return "amount", amount, nil, flag == "CRITICAL", r, g, b, Opt("friendSigns") and "+" or nil
	elseif WORDS[event] and Opt("friendWords") then
		return "word", Word(event), nil, false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

local function Describe(event, flag, amount, school, level, friendly)
	if ns.IsSecret(flag) then
		stats.kind = stats.kind + 1
		flag = nil
	elseif type(flag) ~= "string" then
		flag = nil
	end
	local withheld = ns.IsSecret(amount)
	if withheld then
		stats.amount = stats.amount + 1
	elseif type(amount) ~= "number" then
		amount = 0
	end
	local none = (not withheld and amount == 0) or (withheld and event == "WOUND" and flag == "BLOCK")
	if level then
		return DescribeOwn(level, event, flag, amount, none, school)
	end
	if friendly then
		return DescribeFriend(event, flag, amount, none, school)
	end
	if event == "WOUND" then
		if none then
			local name = (flag == "ABSORB" or flag == "BLOCK" or flag == "RESIST") and flag or "MISS"
			return "word", Word(name), nil, false, 1, 1, 1, nil, KindSize(flag, name)
		end
		local r, g, b = Colour(school)
		return "amount", amount, (flag and Suffix(flag)) or nil, flag == "CRITICAL" or flag == "CRUSHING", r, g, b,
			Classic() and Opt("classicSigns") and "-" or nil, KindSize(flag)
	elseif event == "HEAL" then
		if none then
			return nil
		end
		local heal = Classic() and Opt("classicColour") == "game" and CLASSIC.game.heal or { 0, 1, 0 }
		return "amount", amount, nil, flag == "CRITICAL", heal[1], heal[2], heal[3], Classic() and Opt("classicSigns") and "+" or nil
	elseif WORDS[event] then
		return "word", Word(event), nil, false, 1, 1, 1, nil, KindSize(flag, event)
	end
	return nil
end

local function KindOf(item)
	return item.friend and "friend" or "enemy"
end

local function Release(index)
	local item = table.remove(live, index)
	item.text:Hide()
	item.plate, item.unit = nil, nil
	if item.friend then
		friend.live = friend.live - 1
	end
	local pool = item.onFrame and fr.free or free
	pool[#pool + 1] = item
	if #live == 0 then
		ticker:SetScript("OnUpdate", nil)
	end
end

local function ReleaseKind(kind)
	for index = #live, 1, -1 do
		if KindOf(live[index]) == kind then
			Release(index)
		end
	end
end

local function Back(item)
	stats.unplaced = stats.unplaced + 1
	item.plate, item.unit = nil, nil
	item.text:Hide()
	local pool = item.onFrame and fr.free or free
	pool[#pool + 1] = item
end

local function Acquire(kind, onFrame)
	local pool = onFrame and fr.free or free
	local shown, limit = #live - friend.live, Classic() and MAX_LIVE_CLASSIC or MAX_LIVE
	if kind == "friend" then
		shown, limit = friend.live, FRIEND_MAX
	end
	if shown >= limit then
		for index, other in ipairs(live) do
			if KindOf(other) == (kind or "enemy") then
				Release(index)
				break
			end
		end
	end
	local item = table.remove(pool)
	if not item then
		local text = (onFrame and fr.host or host):CreateFontString(nil, "OVERLAY", LOOK.last[Look().outline])
		ns.Own[text] = true
		item = { text = text, onFrame = onFrame or nil }
	end
	item.friend = kind == "friend" or nil
	if item.style ~= Look().key then
		Style(item)
	end
	return item
end

function ns.CombatOffsets(item, t)
	if item.movement == "hold" then
		return 0, 0
	end
	if item.movement == "classic" then
		return 0, item.rise * t / item.life
	end
	local lift = 0
	if item.movement == "burst" then
		local burst, grow = ns.CombatBurst, item.grow or 1
		if t < burst.settle then
			return 0, grow * burst.rise * t / burst.settle
		end
		t, lift = t - burst.settle, grow * burst.rise
	end
	if item.movement == "fall" or item.movement == "burst" then
		return (item.drift or item.lane * DRIFT) * t, lift + (item.grow or 1) * (RISE * t - GRAVITY / 2 * t * t)
	end
	return 0, CLIMB * (item.grow or 1) * t
end

local Offsets = ns.CombatOffsets

function ns.CombatGrow(base)
	return math.max(1, base / REF_HEIGHT)
end

local laneLists, laneNone = {}, { 0 }
function ns.CombatLanes(width, grow)
	if not width or width <= 0 then
		return laneNone
	end
	grow = grow or 1
	laneLists[width] = laneLists[width] or {}
	local lanes = laneLists[width][grow]
	if lanes then
		return lanes
	end
	lanes = { 0 }
	local k = math.max(1, math.floor(width / 50))
	local pitch = LANE_REACH * grow * width / 100 / k
	for step = 1, k do
		lanes[#lanes + 1] = pitch * step
		lanes[#lanes + 1] = -pitch * step
	end
	laneLists[width][grow] = lanes
	return lanes
end

function ns.CombatDrift(lane, grow)
	local cap = DRIFT_CAP * (grow or 1)
	return math.max(-cap, math.min(cap, lane * DRIFT))
end
local DriftOf = ns.CombatDrift

local function Covered(ax, ay, aw, ah, bx, by, bw, bh)
	local across = math.min(ax + aw / 2, bx + bw / 2) - math.max(ax - aw / 2, bx - bw / 2)
	local up = math.min(ay + ah / 2, by + bh / 2) - math.max(ay - ah / 2, by - bh / 2)
	if across <= 0 or up <= 0 then
		return 0
	end
	return across * up / math.min(aw * ah, bw * bh)
end

local TIMES = { 0, 0.2, 0.4 }
local CHOOSING = {}
local scratch = { olds = {}, pool = {} }
function ns.CombatChoose(olds, spec)
	local lanes, turn = spec.lanes, spec.turn
	local grow, movement = spec.grow or 1, spec.movement or "fall"
	if spec.apart == false or #olds == 0 then
		return lanes[turn], 0
	end
	local best, bestLane, bestLift
	local new = CHOOSING
	new.grow, new.movement = grow, movement
	for row = 0, math.max(1, spec.rows or 1) - 1 do
		local lift = row * ROW_STEP * spec.h
		for step = 0, #lanes - 1 do
			local lane = lanes[(turn - 1 + step) % #lanes + 1]
			new.lane, new.drift = lane, DriftOf(lane, grow)
			local cost = 0
			for _, old in ipairs(olds) do
				for _, dt in ipairs(TIMES) do
					local ox, oy = Offsets(old, (old.age or 0) + dt)
					local nx, ny = Offsets(new, dt)
					cost = cost + Covered(old.x + ox, old.y + oy, old.w, old.h, lane + nx, spec.y0 + lift + ny, spec.w, spec.h)
				end
			end
			if not best or cost < best then
				best, bestLane, bestLift = cost, lane, lift
				if cost == 0 then
					return bestLane, bestLift
				end
			end
		end
	end
	return bestLane, bestLift
end

function ns.CombatPopHeight(settle, peak, t)
	local height
	local span = peak - settle
	if t >= POP.down then
		height = settle
	elseif t <= POP.up then
		height = settle + math.floor(span * t / POP.up + 1e-6)
	else
		height = settle + math.floor(span * (1 - (t - POP.up) / (POP.down - POP.up)) + 1e-6)
	end
	return height, t < POP.down
end

local function Pop(item, t)
	local height, popping
	if item.burst then
		height, popping = ns.CombatBurstHeight(item.settle, t)
	else
		height, popping = ns.CombatPopHeight(item.settle, item.peak, t)
	end
	if not popping then
		item.pop = nil
	end
	if height ~= item.height then
		item.text:SetTextHeight(height)
		item.height = height
	end
end

local function Place(item, now)
	local t = now - item.start
	local dx, dy = Offsets(item, t)
	item.text:ClearAllPoints()
	if item.plate and item.kind == "frame" then
		item.text:SetPoint("BOTTOM", item.plate, "TOP", item.x + dx, item.y + dy)
	elseif item.plate then
		item.text:SetPoint("CENTER", item.plate, "CENTER", item.x + dx, item.y + dy)
	else
		item.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", item.screenX + dx, item.screenY + dy)
	end
	item.text:SetAlpha(t <= item.fade and 1 or math.max(0, 1 - (t - item.fade) / (item.life - item.fade)))
	if item.pop then
		Pop(item, t)
	end
end

local function Step()
	local now = GetTime()
	for index = #live, 1, -1 do
		if now - live[index].start >= live[index].life then
			Release(index)
		elseif not pcall(Place, live[index], now) then
			stats.unplaced = stats.unplaced + 1
			Release(index)
		end
	end
end

local function Tick()
	ns.Try(KEY, Step)
end

local function WorldScale()
	if not WorldFrame then
		return 1
	end
	local ok, height = pcall(WorldFrame.GetHeight, WorldFrame)
	if ok and Plain(height, "number") and height > 0 then
		return height / OWN.screen, height
	end
	return 1
end

function ns.CombatWorldScale()
	return (WorldScale())
end

function ns.CombatOwnEdge(mode, gap, heights)
	local edge = 0
	for _, at in ipairs(heights) do
		if mode == "down" then
			edge = math.max(edge, at + gap)
		else
			edge = math.min(edge, at - gap)
		end
	end
	return edge
end

local function LayOut(item, plate, crit, friendly, onFrame)
	local n = (count[plate] or 0) + 1
	count[plate] = n
	local grow = item.grow
	local lanes = ns.CombatLanes(Opt("spread") == "loose" and Opt("spreadWidth") or 0, grow)
	local turn = (n - 1) % #lanes + 1
	local lift = (crit and Opt("crit") == "higher") and CRIT_LIFT or 0
	item.kind = friendly and onFrame and "frame" or "plate"
	local y0
	if friendly and onFrame then
		y0 = Opt("friendHeight") + lift
	else
		y0 = (Opt("height") - HEIGHT_GAME) + lift
	end
	local lane, up = lanes[turn], 0
	if Opt("overlap") == "apart" then
		local olds, pool, k = scratch.olds, scratch.pool, 0
		for _, other in ipairs(live) do
			if other.plate == plate and other.kind == item.kind then
				k = k + 1
				local old = pool[k]
				if not old then
					old = {}
					pool[k] = old
				end
				old.x, old.y, old.w, old.h = other.x, other.y, other.w or 3 * other.settle, other.settle
				old.age = item.start - other.start
				old.lane, old.drift, old.grow, old.movement = other.lane, other.drift, other.grow, other.movement
				olds[k] = old
			end
		end
		for index = #olds, k + 1, -1 do
			olds[index] = nil
		end
		lane, up = ns.CombatChoose(olds, { lanes = lanes, turn = turn, w = item.w, h = item.settle, rows = Opt("rows") or 1, y0 = y0, grow = grow, movement = ns.CombatMove(Opt("movement"), crit and not friendly and Opt("pop") == "pop") })
	end
	item.lane, item.drift = lane, DriftOf(lane, grow)
	item.x = lane
	item.y = y0 + up
end

function ns.CombatClassicColumn(counts, lines)
	for _, column in ipairs(CLASSIC.columns) do
		if (counts[column] or 0) < lines then
			return column
		end
	end
	return CLASSIC.columns[1]
end

function ns.CombatClassicPush(near, settle, otherSettle)
	return math.max(0, (settle + otherSettle) / 2 * CLASSIC.line - near)
end

function ns.CombatClassicStart(mates, spec)
	local counts, here = { [0] = 0, [1] = 0, [-1] = 0 }, {}
	for _, other in ipairs(mates) do
		if (other.movement == "classic" or other.movement == "hold") and other.start + other.life > spec.now then
			counts[other.classic] = counts[other.classic] + 1
			here[#here + 1] = other
		end
	end
	local column = spec.tight and 0 or ns.CombatClassicColumn(counts, spec.lines)
	local near = {}
	for _, other in ipairs(here) do
		if other.classic == column then
			local _, moved = Offsets(other, spec.now - other.start)
			near[#near + 1] = { other = other, height = other.y + moved - spec.spot }
		end
	end
	local y = spec.spot
	if spec.down then
		if not spec.crit then
			local heights = {}
			for index, entry in ipairs(near) do
				heights[index] = entry.height
			end
			y = spec.spot + math.max(ns.CombatOwnEdge("up", spec.base * CLASSIC.line, heights), -spec.base * CLASSIC.line * spec.lines)
		end
	else
		local shift = 0
		for _, entry in ipairs(near) do
			shift = math.max(shift, ns.CombatClassicPush(entry.height, spec.settle, entry.other.settle))
		end
		if shift > 0 then
			for _, entry in ipairs(near) do
				entry.other.y = entry.other.y + shift
			end
		end
	end
	return column, y
end

local function StartClassic(item, plate, crit, friendly, onFrame)
	local lift = (crit and Opt("crit") == "higher") and CRIT_LIFT or 0
	local spot = ((friendly and onFrame) and Opt("friendHeight") or (Opt("height") - HEIGHT_GAME)) + lift
	local grow = ns.CombatGrow(item.base)
	local mates = {}
	for _, other in ipairs(live) do
		if other.plate == plate then
			mates[#mates + 1] = other
		end
	end
	local column, y = ns.CombatClassicStart(mates, { spot = spot, settle = item.settle, base = item.base, lines = Opt("rows") or 4, tight = Opt("spread") ~= "loose",
		down = Opt("classicStack") == "down", crit = crit, now = item.start })
	item.kind = friendly and onFrame and "frame" or "plate"
	item.classic, item.lane = column, 0
	item.x = column * CLASSIC.side * item.base / TEXT_HEIGHT * (Opt("spreadWidth") or 100) / 100
	item.y = y
	item.rise = Opt("classicRise") * grow
	item.life = CLASSIC.life * Opt("classicTime") / 100
	item.fade = item.life * CLASSIC.fadeFrom
	item.movement = (crit and Opt("classicCrit")) and "hold" or "classic"
	item.pop = crit or nil
	stats.columns[column] = stats.columns[column] + 1
end

local function Fill(item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
	local friendly = class == "friend"
	local text = item.text
	if kind == "word" then
		text:SetText(value)
	else
		local done, withheld = false, nil
		if ns.IsSecret(value) then
			local after = name and (" " .. name) or nil
			if extra then
				after = (after or "") .. " "
			end
			done, withheld = ns.CombatWithheld(value, sign, after)
			if done then
				local other
				if ns.IsSecret(value2) then
					local joined
					joined, other = ns.CombatWithheld(value2, " " .. (sign or ""), after)
					if not joined then
						other = nil
					end
				end
				text:SetFormattedText("%s%s%s", withheld, other or "", extra or "")
			end
		end
		if not done then
			local shown = value
			if type(BreakUpLargeNumbers) == "function" then
				local ok, broken = pcall(BreakUpLargeNumbers, value)
				if ok and (ns.IsSecret(broken) or broken ~= nil) then
					shown = broken
				end
			end
			text:SetFormattedText((sign or "") .. "%s%s", shown, (name and (" " .. name) or "") .. (extra and (" " .. extra) or ""))
		end
	end
	local base = TEXT_HEIGHT * Opt(friendly and "friendSize" or "size") / 100
	base = base * (scale or 1)
	local height = base * (crit and POP.crit or 1)
	if item.height ~= height then
		text:SetTextHeight(height)
		item.height = height
	end
	item.base, item.settle, item.peak = base, height, math.min(base * (crit and POP.critPeak or POP.peak), height + PEAK_GROW, RASTER[2])
	item.grow = ns.CombatGrow(base)
	local ok, width = pcall(text.GetStringWidth, text)
	item.estimated = not (ok and Plain(width, "number") and width > 0) or nil
	item.w = not item.estimated and width or (3 + (extra and 4 or 0) + (name and 0.5 * #name or 0)) * height
	stats.width, stats.estimated, stats.drawn = item.w, item.estimated, height
	item.pop, item.burst = Opt("pop") == "pop" or nil, nil
	text:SetTextColor(r, g, b)
	item.start = GetTime()
	if not Classic() then
		LayOut(item, plate, crit, friendly, onFrame)
	end
	item.movement = ns.CombatMove(Opt("movement"), crit and not friendly and Opt("pop") == "pop")
	item.life, item.fade = LIFE, FADE_FROM
	if Classic() then
		StartClassic(item, plate, crit, friendly, onFrame)
	elseif item.movement == "burst" then
		item.life, item.fade, item.pop, item.burst = ns.CombatBurst.life, ns.CombatBurst.fade, true, true
	end
	item.plate, item.unit = plate, unit
	if not pcall(Place, item, item.start) then
		return false
	end
	return true
end

local function Spawn(plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
	if type(GetTime) ~= "function" then
		return false
	end
	class = class == "friend" and "friend" or nil
	Host()
	if class == "friend" and onFrame then
		FrameHost()
		RaiseFrame(plate)
	else
		Raise(plate)
	end
	if class == "friend" then
		local over = 0
		for _, other in ipairs(live) do
			if other.friend and other.plate == plate then
				over = over + 1
			end
		end
		while over >= FRIEND_PER_UNIT do
			for index, other in ipairs(live) do
				if other.friend and other.plate == plate then
					Release(index)
					break
				end
			end
			over = over - 1
		end
	end
	local item = Acquire(class, class == "friend" and onFrame or nil)
	local ok, shown = pcall(Fill, item, plate, unit, kind, value, extra, crit, r, g, b, class, sign, onFrame, scale, name, value2)
	if not (ok and shown) then
		Back(item)
		return false
	end
	item.text:Show()
	live[#live + 1] = item
	if #live == 1 then
		ticker:SetScript("OnUpdate", Tick)
	end
	if class == "friend" then
		friend.live, friend.shown = friend.live + 1, friend.shown + 1
	else
		stats.shown = stats.shown + 1
	end
	return true
end

function ns.CombatWordOver(unit, text, r, g, b, icon, sample)
	if not (ns.Enabled(KEY) and Opt("source") == "front") or ns.IsSecret(unit) or type(unit) ~= "string" or type(text) ~= "string" then
		return false
	end
	local plate = Plate(unit)
	if not plate then
		return false
	end
	local token = plate.unitToken
	if Plain(token, "string") and token ~= "" then
		unit = token
	end
	if Plain(icon, "number") then
		text = ("|T%d:0:0:0:0:64:64:5:59:5:59|t "):format(icon) .. text
	end
	local shown = stats.shown
	local ok, done = pcall(Spawn, plate, unit, "word", text, nil, false, r, g, b, nil, nil, nil, ns.CombatWordSize())
	if sample then
		stats.shown = shown
	end
	return ok and done == true
end

local function Shown(value)
	if ns.IsSecret(value) then
		return "withheld"
	end
	return tostring(value)
end

local function Trace(...)
	local parts = { ("Trace %.3f"):format(GetTime()) }
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if ns.IsSecret(value) then
			parts[#parts + 1] = "withheld"
		elseif value == "" then
			parts[#parts + 1] = '""'
		elseif value ~= nil then
			parts[#parts + 1] = tostring(value)
		end
	end
	print(table.concat(parts, " "))
end

local function Remember(into, unit, event, flag, amount, school)
	into[1], into[2], into[3], into[4], into[5] = unit, event, flag, amount, school
	into.set = true
end

local function Reported(into)
	if not into.set then
		return nil
	end
	return table.concat({ into[1], Shown(into[2]), Shown(into[3]), Shown(into[4]), "school " .. Shown(into[5]) }, ", ")
end

local function ActiveUnit()
	local ok, vehicle = pcall(UnitHasVehicleUI, "player")
	if ok and Plain(vehicle, "boolean") and vehicle then
		return "vehicle"
	end
	return "player"
end

local function Yourself(unit)
	if Opt("own") == "off" then
		return false
	end
	local ok, same = pcall(UnitIsUnit, unit, ActiveUnit())
	return ok and Plain(same, "boolean") and same
end

local function OnOwn(unit, event, flag, amount, school)
	if Opt("own") == "off" then
		return
	end
	own.reports = own.reports + 1
	Remember(own.last, unit, event, flag, amount, school)
	if unit ~= ActiveUnit() then
		return
	end
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local kind, value, format, crit, r, g, b, _, scale = Describe(event, flag, amount, school, Opt("own"))
	if kind then
		local icon
		if kind == "amount" and event == "HEAL" and GetTime() <= mine.healUntil then
			icon = Opt("icons") ~= "off" and mine.healIcon or nil
			mine.healUntil = -1
		end
		ns.ScrollText.Show("inc", kind, value, format, crit, r, g, b, kind == "amount" and KindSize(Plain(flag, "string") and flag or nil) or scale,
			Plain(flag, "string") and flag or nil, nil, icon)
	end
end

local function Group(unit)
	return unit:find("^party%d$") ~= nil or unit:find("^raid%d+$") ~= nil
end

local function Now()
	if type(GetTime) == "function" then
		return GetTime()
	end
	return 0
end

local function Frames()
	local now = Now()
	if frames.at > 0 and now - frames.at < FRAMES_FOR then
		return frames.byUnit
	end
	local found = {}
	pcall(function()
		for _, getter in ipairs({ ns.PartyMembers, ns.PartyStyleMembers }) do
			if type(getter) == "function" then
				for _, member in ipairs(getter()) do
					if found[member.unit] == nil then
						found[member.unit] = member.frame
					end
				end
			end
		end
		for index = 1, 40 do
			local frame = _G["CompactRaidFrame" .. index]
			if frame ~= nil and not ns.Forbidden(frame) then
				local unit = frame.unit
				local shown = frame:IsShown()
				if Plain(unit, "string") and unit:find("^raid%d+$") and not ns.IsSecret(shown) and shown == true and found[unit] == nil then
					found[unit] = frame
				end
			end
		end
		local pet = _G.PetFrame
		if pet ~= nil and not ns.Forbidden(pet) then
			local shown = pet:IsShown()
			if not ns.IsSecret(shown) and shown == true then
				found.pet = pet
			end
		end
	end)
	frames.byUnit, frames.at = found, now > 0 and now or 1e-9
	return found
end

local function FrameOfUnit(token)
	local frame = Frames()[token]
	if frame == nil then
		return nil
	end
	if token ~= "pet" then
		local ok, unit, shown = pcall(function()
			return frame.unit, frame.displayedUnit
		end)
		if not (ok and ((Plain(unit, "string") and unit == token) or (Plain(shown, "string") and shown == token))) then
			return nil
		end
	end
	return frame
end

local function PlateOfUnitRead(token)
	if type(C_NamePlate) ~= "table" or type(C_NamePlate.GetNamePlates) ~= "function" then
		return nil
	end
	local ok, found = pcall(function()
		local plates = C_NamePlate.GetNamePlates()
		if ns.IsSecret(plates) or type(plates) ~= "table" then
			return nil
		end
		for _, plate in ipairs(plates) do
			if not ns.Forbidden(plate) then
				local unit = plate.unitToken
				if Plain(unit, "string") then
					local mine = true
					if token == "pet" then
						local owned = UnitIsOwnerOrControllerOfUnit("player", unit)
						mine = Plain(owned, "boolean") and owned
					end
					if mine then
						local answer = UnitIsUnit(token, unit)
						if Plain(answer, "boolean") and answer then
							return plate
						end
					end
				end
			end
		end
		return nil
	end)
	return ok and found or nil
end

local plateOf = { at = nil, by = {} }
local function PlateOfUnit(token)
	local now = Now()
	if plateOf.at ~= now then
		plateOf.at, plateOf.by = now, {}
	end
	local kept = plateOf.by[token]
	if kept ~= nil then
		return kept or nil
	end
	local found = PlateOfUnitRead(token)
	plateOf.by[token] = found or false
	return found
end

local function ForTarget(unit, plate)
	if Opt("friendUnits") ~= "target" then
		return true
	end
	if plate then
		return plate == Plate("target")
	end
	local ok, same = pcall(UnitIsUnit, unit, "target")
	if ok and Plain(same, "boolean") then
		return same
	end
	friend.unknown = friend.unknown + 1
	return true
end

local function ShowFriend(anchor, onFrame, token, event, flag, amount, school)
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(event, flag, amount, school, nil, true)
	if not kind then
		return
	end
	local comparable = Plain(flag, "string") and Plain(school, "number")
	local now = Now()
	local before = friend.recent[anchor]
	if comparable and before and before.event == event and before.flag == flag and before.school == school and now - before.at < FRIEND_SAME then
		friend.same = friend.same + 1
		return
	end
	if Spawn(anchor, token, kind, value, suffix, crit, r, g, b, "friend", sign, onFrame, scale) then
		friend.recent[anchor] = comparable and { event = event, flag = flag, school = school, at = now } or nil
		if not friendProven then
			friendProven = true
			Sync()
		end
	end
end

local function OnFriendToken(token, event, flag, amount, school)
	local mode = FriendMode()
	if mode == "off" then
		return
	end
	local pet = token == "pet"
	friend.reports = friend.reports + 1
	Remember(friend.last, token, event, flag, amount, school)
	if pet then
		friend.pet = friend.pet + 1
		if not Opt("friendPet") then
			return
		end
	else
		friend.group = friend.group + 1
		if Yourself(token) then
			friend.self = friend.self + 1
			return
		end
	end
	if not ForTarget(token) then
		return
	end
	if mode ~= "frames" and PlateOfUnit(token) then
		friend.same = friend.same + 1
		return
	end
	if mode == "plates" then
		return
	end
	local frame = FrameOfUnit(token)
	if not frame then
		friend.noAnchor = friend.noAnchor + 1
		return
	end
	ShowFriend(frame, true, token, event, flag, amount, school)
end

local function OnFriendPlate(plate, unit, event, flag, amount, school)
	friend.reports, friend.plates = friend.reports + 1, friend.plates + 1
	Remember(friend.last, unit, event, flag, amount, school)
	if Yourself(unit) then
		friend.self = friend.self + 1
		return
	end
	if not Opt("friendPet") then
		local ok, owned = pcall(UnitIsOwnerOrControllerOfUnit, "player", unit)
		if ok and Plain(owned, "boolean") and owned then
			return
		end
	end
	if not ForTarget(unit, plate) then
		return
	end
	ShowFriend(plate, false, unit, event, flag, amount, school)
end

local function Length(list)
	return #list
end

local function AuraOfYours(unit)
	local now = GetTime()
	local held = mine.aura[unit]
	if held and now - held.at < MINE.aura then
		return held.number, held.read
	end
	local number, read = 0, false
	local ok, list
	if type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function" then
		ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL|PLAYER", MINE.auraMax)
	end
	if ok and Plain(list, "table") then
		local counted, size = pcall(Length, list)
		if counted and Plain(size, "number") then
			number, read = math.min(size, MINE.auraMax), true
		else
			mine.blind = mine.blind + 1
		end
	else
		mine.blind = mine.blind + 1
	end
	mine.aura[unit] = { at = now, number = number, read = read }
	return number, read
end

local function AuraListFree(unit)
	local number, read = AuraOfYours(unit)
	return read and number == 0
end

local function Icon(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellTexture) ~= "function" then
		return nil
	end
	local ok, file = pcall(C_Spell.GetSpellTexture, id)
	if ok and Plain(file, "number") then
		return file
	end
	return nil
end

local function NextSwing(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if not ok or not Plain(name, "string") then
		return nil
	end
	for _, base in ipairs(MINE.nextSwing) do
		local found, other = pcall(C_Spell.GetSpellName, base)
		if found and Plain(other, "string") and other == name then
			return name
		end
	end
	return nil
end

MINE.byName = {}
function MINE.SpellNames()
	if next(MINE.byName) ~= nil or type(ns.CombatSpells) ~= "table" or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return MINE.byName
	end
	for id, entry in pairs(ns.CombatSpells) do
		local ok, name = pcall(C_Spell.GetSpellName, id)
		if ok and Plain(name, "string") and name ~= "" then
			MINE.byName[name] = entry
		end
	end
	return MINE.byName
end
MINE.SpellNames()

function MINE.SpellOf(id)
	if not Plain(id, "number") or type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil, nil
	end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if not ok or not Plain(name, "string") then
		return nil, nil
	end
	return MINE.SpellNames()[name], name
end

function MINE.Harmful(id)
	if type(C_Spell) ~= "table" or type(C_Spell.IsSpellHarmful) ~= "function" then
		return false
	end
	local ok, harmful = pcall(C_Spell.IsSpellHarmful, id)
	return ok and Plain(harmful, "boolean") and harmful
end

function MINE.SchoolFits(slot, hit)
	if slot == nil then
		return true
	end
	if not Plain(hit, "number") then
		return false
	end
	if type(bit) ~= "table" or type(bit.band) ~= "function" then
		return slot == hit
	end
	return bit.band(slot, hit) ~= 0
end

MINE.schoolWords = { { 1, "physical" }, { 2, "holy" }, { 4, "fire" }, { 8, "nature" }, { 16, "frost" }, { 32, "shadow" }, { 64, "arcane" } }
function MINE.SchoolWords(mask)
	if not Plain(mask, "number") then
		return "withheld"
	end
	local words = {}
	for _, pair in ipairs(MINE.schoolWords) do
		if mask == pair[1] then
			return pair[2]
		elseif type(bit) == "table" and type(bit.band) == "function" and bit.band(mask, pair[1]) ~= 0 then
			words[#words + 1] = pair[2]
		end
	end
	return #words > 0 and table.concat(words, " and ") or ("mask " .. tostring(mask))
end

function MINE.Decision(head, why, school, spell)
	local hit = Plain(school, "number") and (MINE.SchoolWords(school) .. " hit") or "hit of a withheld school"
	return ("%s (%s%s; %s)"):format(head, why, Plain(spell, "string") and (" of " .. spell) or "", hit)
end

local function Speeds(call, hands)
	local ok, main, off = pcall(call, "player")
	if not (ok and Plain(main, "number") and main > 0) then
		mine.blind = mine.blind + 1
		return MINE.swingGap, nil
	end
	if not hands then
		return main, nil
	end
	if ns.IsSecret(off) then
		mine.blind = mine.blind + 1
		return main, nil
	end
	if Plain(off, "number") and off > 0 then
		return main, off
	end
	return main, nil
end

local function TakeWeapon(speed, last, now)
	return now - last >= speed * MINE.swingShare
end

function MINE.DropCasts(now)
	local list = mine.castSlots
	for index = #list, 1, -1 do
		if list[index].at < now then
			table.remove(list, index)
		end
	end
end

function MINE.CastOpen(now)
	for _, slot in ipairs(mine.castSlots) do
		if slot.at >= now then
			return true
		end
	end
	return false
end

function MINE.CastFor(now, school, away, onPet)
	local found, at
	for index, slot in ipairs(mine.castSlots) do
		if slot.at >= now and now >= slot.from - MINE.late and MINE.SchoolFits(slot.school, school)
			and (slot.area or (slot.pet and onPet) or (not slot.pet and not away)) then
			if not slot.travel and now <= slot.from + MINE.fresh then
				return slot, index, true
			end
			if not found then
				found, at = slot, index
			end
		end
	end
	return found, at, false
end

function MINE.OpenCast(now, entry, spellID, name, pet)
	local list = mine.castSlots
	local area = entry == nil or entry.kind == "area"
	local travel = entry ~= nil and entry.travel == true
	list[#list + 1] = { at = now + (travel and MINE.travel or MINE.cast), from = now, travel = travel, pet = pet == true, school = entry and entry.school or nil,
		icon = Icon(spellID) or false, area = area, left = area and MINE.areaMax or 1, name = name,
		damage = (entry ~= nil and pet ~= true) and entry.damage or nil }
end

local function TakeCast(now, school, away, onPet)
	MINE.DropCasts(now)
	local slot, index = MINE.CastFor(now, school, away, onPet)
	if not slot then
		return false
	end
	mine.castTaken = math.max(mine.castTaken, slot.at)
	slot.left = slot.left - 1
	if slot.left <= 0 then
		table.remove(mine.castSlots, index)
	end
	return true, slot.icon or nil, slot.name, slot.damage
end

function MINE.RecordDot(unit, now, entry, spellID, name)
	local token = unit == "pet" and "pettarget" or "target"
	local key = Plate(token) or token
	local list = mine.dots[key]
	if not list then
		list = {}
		mine.dots[key] = list
	end
	for index = #list, 1, -1 do
		if list[index].name == name then
			table.remove(list, index)
		end
	end
	list[#list + 1] = { school = entry.school, icon = Icon(spellID) or false, name = name, at = now }
end

function MINE.DotsOn(key, unit, now)
	local list = key ~= nil and mine.dots[key] or nil
	if not list then
		return nil
	end
	for index = #list, 1, -1 do
		if now - list[index].at > MINE.dotKeep then
			table.remove(list, index)
		end
	end
	if list[1] then
		local number, read = AuraOfYours(unit)
		if read and number == 0 then
			for index = #list, 1, -1 do
				if now - list[index].at > MINE.travel then
					table.remove(list, index)
				end
			end
		end
	end
	if not list[1] then
		mine.dots[key] = nil
		return nil
	end
	return list
end

function MINE.DotFor(list, school)
	local count, found = 0, nil
	if list and Plain(school, "number") then
		for _, dot in ipairs(list) do
			if MINE.SchoolFits(dot.school, school) then
				count, found = count + 1, dot
			end
		end
	end
	return count, count == 1 and found or nil
end

local function TakeAura(unit, now, key, school)
	local dots = MINE.DotsOn(key, unit, now)
	local number = AuraOfYours(unit)
	if number == 0 then
		return false, false
	end
	local dot
	if dots then
		local _
		_, dot = MINE.DotFor(dots, school)
	end
	local slots = mine.auraSlots[unit]
	if not slots or TakeWeapon(MINE.auraTick, slots.at, now) then
		slots = { at = now, used = 0 }
		mine.auraSlots[unit] = slots
	end
	if slots.used < number then
		slots.used = slots.used + 1
		return true, true, dot and dot.icon or nil, dot and dot.name or nil
	end
	return false, true
end

local function PetOut()
	if type(UnitExists) ~= "function" then
		return true
	end
	local ok, there = pcall(UnitExists, "pet")
	return not (ok and Plain(there, "boolean") and not there)
end

function MINE.PetFighting()
	if type(UnitExists) ~= "function" or type(UnitAffectingCombat) ~= "function" then
		return false
	end
	local ok, there = pcall(UnitExists, "pet")
	if not (ok and Plain(there, "boolean") and there) then
		return false
	end
	local fought, fighting = pcall(UnitAffectingCombat, "pet")
	return fought and Plain(fighting, "boolean") and fighting
end

function MINE.TakePetSwing(now)
	if not MINE.PetFighting() then
		return false
	end
	local speed = MINE.swingGap
	if type(UnitAttackSpeed) == "function" then
		local ok, main = pcall(UnitAttackSpeed, "pet")
		if ok and Plain(main, "number") and main > 0 then
			speed = main
		else
			mine.blind = mine.blind + 1
		end
	end
	if TakeWeapon(speed, mine.petAt, now) then
		mine.petAt = now
		return true
	end
	return false
end

function MINE.PetSwing(now, away)
	MINE.DropCasts(now)
	local slot, _, fresh = MINE.CastFor(now, 1, away, true)
	if slot and fresh then
		return false
	end
	return MINE.TakePetSwing(now)
end

local function Crowded(key, now)
	local at = key ~= nil and mine.crowd[key] or nil
	return at ~= nil and now - at <= MINE.crowd
end

function MINE.ExtraOpen(now, unit, key)
	return Opt("extra") == "plain" and not mine.extraUsed and now - mine.swingAt <= MINE.extra and not InGroup() and not PetOut() and not MINE.CastOpen(now)
		and not Crowded(key, now) and AuraListFree(unit)
end

local function TakeSwing(now)
	local main, off = Speeds(UnitAttackSpeed, true)
	if TakeWeapon(main, mine.hand.main, now) then
		mine.hand.main, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	elseif off and TakeWeapon(off, mine.hand.off, now) then
		mine.hand.off, mine.swingAt, mine.extraUsed = now, now, false
		return "swing slot", false
	end
	return nil, true
end

function MINE.Hand(swingType)
	if not Plain(swingType, "number") then
		return nil
	end
	local types = type(Enum) == "table" and Enum.PlayerSwingType or nil
	if swingType == (types and types.MainHand or 0) then
		return "main"
	elseif swingType == (types and types.OffHand or 1) then
		return "off"
	elseif swingType == (types and types.Ranged or 2) then
		return "ranged"
	end
	return nil
end

function MINE.OnSwing(now, duration, swingType)
	local hand = MINE.Hand(swingType)
	if hand == nil then
		return false
	end
	if Plain(duration, "number") and duration > 0 then
		mine.due[hand] = now + duration
	end
	if hand == "ranged" then
		mine.rangedHeard = true
	else
		mine.swingHeard = true
	end
	mine.swingCount = mine.swingCount + 1
	local extra = false
	if hand == "main" then
		extra = now - mine.lastMain <= MINE.extra
		mine.lastMain = now
		local pair = mine.pair
		if pair and not pair.bound and (pair.left == 2 or (pair.waits and pair.left > 0)) and now <= pair.close then
			pair.bound = now
			return true
		end
	end
	local list = mine.swings
	for index = #list, 1, -1 do
		if now - list[index].at > MINE.travel then
			table.remove(list, index)
		end
	end
	list[#list + 1] = { at = now, hand = hand, extra = extra, left = 1 }
	return true
end

function MINE.TakeToken(at, ranged)
	for _, token in ipairs(mine.swings) do
		if token.left > 0 and (token.hand == "ranged") == ranged and at >= token.at - MINE.late and at <= token.at + (ranged and MINE.cast or MINE.swingTake) then
			token.left = 0
			return token
		end
	end
	return nil
end

function MINE.TakeSwingHeard(now)
	local token = MINE.TakeToken(now, false)
	if token then
		if token.extra and Opt("extra") == "plain" then
			mine.extraUsed = true
			return "extra slot", false
		end
		mine.swingAt, mine.extraUsed = now, false
		return "swing slot", false
	end
	return nil, true
end

function MINE.OpenPair(now, spellID, name)
	local entry = MINE.SpellOf(spellID)
	local close, due = now + MINE.cast, nil
	if mine.swingHeard then
		due = math.max(now, mine.due.main or now)
		close = math.min(now + MINE.nextMax, math.max(now + MINE.cast, due + MINE.pairTail))
	end
	local targets = entry and Plain(entry.targets, "number") and entry.targets or 1
	local pair = { name = name, icon = Icon(spellID) or false, spell = spellID, opened = now, close = close, left = 2, other = math.max(0, targets - 1),
		due = due, waits = due ~= nil and due > now + MINE.pairTail }
	local list = mine.swings
	for index = #list, 1, -1 do
		local token = list[index]
		if token.hand == "main" and token.at == now and token.left > 0 then
			table.remove(list, index)
			pair.bound, pair.waits = now, false
			break
		end
	end
	mine.pair = pair
end

function MINE.PairOpen(pair, at)
	if pair == nil then
		return false
	end
	if pair.bound then
		return at >= pair.bound - MINE.late and at <= pair.bound + MINE.pairTail
	end
	if pair.waits then
		return at >= pair.due - MINE.swingTake and at <= pair.close
	end
	if at < pair.opened - MINE.late then
		return false
	end
	if mine.swingHeard then
		return at <= pair.opened + MINE.pairTail
	end
	return at <= pair.close
end

function MINE.TakePair(at, onTarget, unit)
	local pair = mine.pair
	if not MINE.PairOpen(pair, at) then
		return nil
	end
	if onTarget then
		if pair.left <= 0 then
			return nil
		end
		pair.left = pair.left - 1
		return pair
	end
	if pair.other <= 0 or not Plain(unit, "string") then
		return nil
	end
	if type(C_Spell) == "table" and type(C_Spell.IsSpellInRange) == "function" then
		local ok, near = pcall(C_Spell.IsSpellInRange, pair.spell, unit)
		if ok and Plain(near, "boolean") and not near then
			return nil
		end
	end
	pair.other = pair.other - 1
	return pair
end

function MINE.StartSpin(now, entry, spellID, name)
	local spin = mine.spin
	if spin and spin.name == name and now - spin.start <= MINE.spinSlack then
		return
	end
	mine.spin = { name = name, icon = Icon(spellID) or false, start = now, period = entry.period or MINE.tick, ticks = entry.ticks or 3, taken = {},
		trigger = Plain(entry.trigger, "number") and entry.trigger or nil }
end

function MINE.SpinTick(now, spellID)
	local spin = mine.spin
	if spin == nil or spin.trigger == nil or not Plain(spellID, "number") or spellID ~= spin.trigger then
		return false
	end
	local t = now - spin.start
	local k = math.floor(t / spin.period + 0.5)
	if k < 1 or k > spin.ticks or math.abs(t - k * spin.period) > MINE.spinSlack then
		return false
	end
	spin.start = now - k * spin.period
	return true
end

function MINE.TakeSpin(at, key)
	local spin = mine.spin
	if spin == nil or key == nil then
		return nil
	end
	local t = at - spin.start
	if t > spin.ticks * spin.period + MINE.spinSlack then
		mine.spin = nil
		return nil
	end
	local k = math.floor(t / spin.period + 0.5)
	if k < 1 or k > spin.ticks or math.abs(t - k * spin.period) > MINE.spinSlack then
		return nil
	end
	local hit = spin.taken[k]
	if not hit then
		hit = {}
		spin.taken[k] = hit
	end
	if hit[key] then
		return nil
	end
	hit[key] = true
	return spin
end

function MINE.Struck(at)
	local near = MINE.swingTake
	for _, token in ipairs(mine.swings) do
		if token.hand ~= "ranged" and math.abs(token.at - at) <= near then
			return true
		end
	end
	local pair = mine.pair
	local swing = pair and (pair.bound or (not pair.waits and pair.opened)) or nil
	if swing and math.abs(swing - at) <= near then
		return true
	end
	return math.abs(mine.strikeAt - at) <= near or math.abs(mine.swingAt - at) <= near
end

function MINE.StartSweep(now, entry, spellID, name)
	local sweep = mine.sweep
	if sweep and now <= sweep.close then
		return
	end
	mine.sweep = { name = name, icon = Icon(spellID) or false, close = now + (entry.duration or MINE.dotKeep), left = entry.charges or 5 }
end

function MINE.TakeSweep(at)
	local sweep = mine.sweep
	if sweep == nil then
		return nil
	end
	if at > sweep.close then
		mine.sweep = nil
		return nil
	end
	if sweep.left <= 0 or not MINE.Struck(at) then
		return nil
	end
	sweep.left = sweep.left - 1
	return sweep
end

function MINE.StartCounter(now, entry, name, spellID)
	local counter = mine.counter
	if counter and now <= counter.close then
		return true
	end
	mine.counter = { name = name, icon = Icon(spellID) or false, close = now + (entry.duration or MINE.dotKeep), left = entry.charges or 30 }
	mine.struckAt = {}
	return false
end

function MINE.OnStruck(now)
	local counter = mine.counter
	if counter == nil then
		return
	end
	if now > counter.close then
		mine.counter = nil
		return
	end
	local list = mine.struckAt
	for index = #list, 1, -1 do
		if now - list[index] > MINE.travel then
			table.remove(list, index)
		end
	end
	list[#list + 1] = now
end

function MINE.TakeCounter(at)
	local counter = mine.counter
	if counter == nil or counter.left <= 0 then
		return nil
	end
	if at > counter.close + MINE.swingTake then
		mine.counter = nil
		return nil
	end
	for index, struck in ipairs(mine.struckAt) do
		if at >= struck - MINE.late and at <= struck + MINE.swingTake then
			table.remove(mine.struckAt, index)
			counter.left = counter.left - 1
			return counter
		end
	end
	return nil
end

function MINE.Threat(who, unit)
	if type(UnitThreatSituation) ~= "function" then
		return nil, false
	end
	local ok, status = pcall(UnitThreatSituation, who, unit)
	if not ok or ns.IsSecret(status) then
		return nil, false
	end
	if status == nil then
		return nil, true
	end
	if type(status) ~= "number" then
		return nil, false
	end
	return status, true
end

function MINE.OthersOn(unit)
	if type(IsInRaid) ~= "function" then
		return true
	end
	local ok, raid = pcall(IsInRaid)
	if not ok or not Plain(raid, "boolean") or raid then
		return true
	end
	for _, token in ipairs(MINE.partyTokens) do
		local status, answered = MINE.Threat(token, unit)
		if not answered or status ~= nil then
			return true
		end
	end
	return false
end

function MINE.EngagedRead(unit, key, at)
	if not Plain(unit, "string") or type(UnitIsTapDenied) ~= "function" then
		return false
	end
	local ok, denied = pcall(UnitIsTapDenied, unit)
	if not (ok and Plain(denied, "boolean")) or denied then
		return false
	end
	local status, answered = MINE.Threat("player", unit)
	if not answered then
		return false
	end
	local held = status == 2 or status == 3
	if not held and PetOut() then
		local pet = MINE.Threat("pet", unit)
		held = pet == 2 or pet == 3
	end
	if not held and status == nil and type(UnitPlayerControlled) == "function" then
		local hit = key ~= nil and mine.hitBy[key] or nil
		local known, controlled = pcall(UnitPlayerControlled, unit)
		held = hit ~= nil and at - hit <= MINE.engaged and known and Plain(controlled, "boolean") and not controlled
	end
	return held and not (InGroup() and MINE.OthersOn(unit))
end

MINE.engagedAt, MINE.engagedBy = nil, {}
function MINE.Engaged(unit, key, at)
	local frame = Now()
	if MINE.engagedAt ~= frame then
		MINE.engagedAt, MINE.engagedBy = frame, {}
	end
	local index = key or unit
	if index == nil then
		return false
	end
	local kept = MINE.engagedBy[index]
	if kept == nil then
		kept = MINE.EngagedRead(unit, key, at)
		MINE.engagedBy[index] = kept
	end
	return kept
end

local function MineOne(plate, unit, school, flag, own, at, event)
	local now = at or GetTime()
	local why, taken, swingTried, auraTried, icon, spell, pair, damage
	local key = plate or unit
	local onTarget = plate == Plate("target")
	local onPet = plate ~= nil and plate == Plate("pettarget")
	local physical = Plain(school, "number") and school == 1
	local crit = Plain(flag, "string") and flag == "CRITICAL"
	local tickable = not (Plain(event, "string") and MINE.words[event])
	if (mine.chan or now <= mine.castUntil) and mine.chanTakes and (onTarget or mine.chanArea) and MINE.SchoolFits(mine.chanSchool, school) then
		why, spell = "channel", mine.chanName
	elseif physical then
		pair = MINE.TakePair(now, onTarget, unit)
		if pair then
			why, spell = "next swing", pair.name
			if onTarget and not mine.swingHeard then
				mine.hand.main = now
			end
		end
	end
	if not why and onTarget then
		local shooting = mine.shoot or now <= mine.shotEnd
		if physical and not shooting and (mine.swingHeard or mine.swing) then
			swingTried = true
			if mine.swingHeard then
				why, taken = MINE.TakeSwingHeard(now)
			else
				why, taken = TakeSwing(now)
			end
		end
		if not why and physical then
			local spin = MINE.TakeSpin(now, key)
			local counter = not spin and MINE.TakeCounter(now) or nil
			if spin then
				why, spell, icon = "spin", spin.name, spin.icon or nil
			elseif counter then
				why, spell, icon = "counter", counter.name, counter.icon or nil
			elseif swingTried and MINE.ExtraOpen(now, unit, key) then
				mine.extraUsed = true
				why, taken = "extra slot", false
			end
		end
		if not why and physical and onPet and MINE.PetSwing(now, false) then
			why = "pet swing"
		end
		if not why and tickable and Plain(flag, "string") and not crit then
			MINE.DropCasts(now)
			local slot, _, fresh = MINE.CastFor(now, school, false, onPet)
			local castFirst = slot ~= nil and (fresh or MINE.DotFor(MINE.DotsOn(key, unit, now), school) == 0)
			if not castFirst then
				auraTried = true
				local got, held, dotIcon, dotName = TakeAura(unit, now, key, school)
				if got then
					why, icon, spell = "aura slot", dotIcon, dotName
				elseif held then
					taken = true
				end
			end
		end
		local cast, castIcon, castName, castDamage
		if not why then
			cast, castIcon, castName, castDamage = TakeCast(now, school, false, onPet)
		end
		if why then
		elseif cast then
			why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
		else
			taken = taken or now <= mine.castTaken
			if shooting then
				local token = mine.rangedHeard and MINE.TakeToken(now, true) or nil
				if token or TakeWeapon(Speeds(UnitRangedDamage), mine.shotAt, now) then
					mine.shotAt, why = now, "shot slot"
					if not mine.shoot then mine.shotEnd = -math.huge end
				else
					taken = true
				end
			elseif not swingTried and (mine.swing or mine.swingHeard) and not Plain(school, "number") then
				mine.blind = mine.blind + 1
			end
		end
	end
	if not why and not onTarget and physical then
		local spin = MINE.TakeSpin(now, key)
		local sweep = not spin and MINE.TakeSweep(now) or nil
		local counter = not (spin or sweep) and MINE.TakeCounter(now) or nil
		if spin then
			why, spell, icon = "spin", spin.name, spin.icon or nil
		elseif sweep then
			why, spell, icon = "sweep", sweep.name, sweep.icon or nil
		elseif counter then
			why, spell, icon = "counter", counter.name, counter.icon or nil
		elseif onPet and MINE.PetSwing(now, true) then
			why = "pet swing"
		end
	end
	local areaFirst = false
	if not why and not onTarget then
		MINE.DropCasts(now)
		local slot, _, fresh = MINE.CastFor(now, school, true, onPet)
		areaFirst = slot ~= nil and (fresh or crit or MINE.DotFor(MINE.DotsOn(key, unit, now), school) == 0)
		if areaFirst then
			local cast, castIcon, castName, castDamage = TakeCast(now, school, true, onPet)
			if cast then
				why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
			end
		end
	end
	if not why and not auraTried and tickable then
		if Plain(flag, "string") then
			local got, held, dotIcon, dotName = TakeAura(unit, now, key, school)
			if got then
				why, icon, spell = "aura slot", dotIcon, dotName
			elseif held then
				taken = true
			end
		else
			mine.blind = mine.blind + 1
		end
	end
	if not why and not onTarget and not areaFirst then
		local cast, castIcon, castName, castDamage = TakeCast(now, school, true, onPet)
		if cast then
			why, icon, spell, damage = "cast slot", castIcon, castName, castDamage
		end
	end
	if why then
		if key ~= nil then
			mine.hitBy[key] = now
		end
		mine.kept, mine.last = mine.kept + 1, MINE.Decision("yours", why, school, spell)
		local mode = Opt("icons")
		if why == "channel" then
			icon = mine.chanIcon
		elseif why == "next swing" then
			icon = pair.icon or nil
		elseif why == "swing slot" or why == "extra slot" then
			mine.swingIcon = mine.swingIcon or Icon(6603)
			icon = mode == "all" and mine.swingIcon or nil
		elseif why == "shot slot" then
			mine.shotIcon = mine.shotIcon or Icon(75)
			icon = mode == "all" and mine.shotIcon or nil
		end
		return true, why, mode ~= "off" and icon or nil, spell, pair, damage
	end
	if own then
		return false
	end
	mine.left = mine.left + 1
	mine.last = MINE.Decision("left out", taken and "slot taken" or "no cast or swing seen", school)
	if key ~= nil and physical then
		mine.crowd[key] = now
	end
	return false
end

local function OnSignal(_, event, unit, second, spellID)
	if event == "PLAYER_ENTERING_WORLD" then
		local was = mine.off
		mine.heard, mine.unheard, mine.off = 0, 0, mine.deaf
		mine.chan, mine.swing, mine.shoot = false, false, false
		mine.castSlots, mine.castTaken, mine.auraSlots, mine.dots = {}, -1, {}, setmetatable({}, { __mode = "k" })
		mine.chanIcon, mine.chanName, mine.chanSchool, mine.chanTakes, mine.chanArea = nil, nil, nil, false, false
		mine.healIcon, mine.swingIcon, mine.shotIcon, mine.healUntil = nil, nil, nil, -1
		mine.hand, mine.shotAt, mine.shotEnd = { main = -math.huge, off = -math.huge }, -math.huge, -math.huge
		mine.swingAt, mine.extraUsed = -math.huge, false
		mine.crowd, mine.hitBy = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
		mine.pair, mine.spin, mine.swings, mine.lastMain, mine.due, mine.queue = nil, nil, {}, -math.huge, {}, {}
		mine.sweep, mine.strikeAt, mine.counter, mine.struckAt, mine.petAt = nil, -math.huge, nil, {}, -math.huge
		if was ~= mine.off then
			pcall(Sync)
		end
		return
	end
	local now = GetTime()
	if event == "PLAYER_SWING" then
		if not MINE.OnSwing(now, unit, second) then
			return
		end
	elseif event == "PLAYER_ENTER_COMBAT" then
		mine.swing = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		mine.swing = false
	elseif event == "START_AUTOREPEAT_SPELL" then
		mine.shoot = true
		local ok, class = false, nil
		if type(UnitClassBase) == "function" then
			ok, class = pcall(UnitClassBase, "player")
		end
		class = ok and class or nil
		mine.shotIcon = Icon(Plain(class, "string") and class ~= "HUNTER" and 5019 or 75)
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		mine.shoot, mine.shotEnd = false, now + MINE.tail
	elseif Plain(event, "string") and event:sub(1, 5) == "UNIT_" then
		if not Plain(unit, "string") or (unit ~= "player" and unit ~= "pet") then
			return
		end
		if event == "UNIT_SPELLCAST_CHANNEL_START" then
			local entry, spell = MINE.SpellOf(spellID)
			mine.chan, mine.chanIcon, mine.chanName = true, Icon(spellID), spell
			if entry then
				mine.chanTakes, mine.chanSchool, mine.chanArea = entry.kind == "channel", entry.school, entry.area == true
				if entry.kind == "spin" then
					MINE.StartSpin(now, entry, spellID, spell)
				end
			else
				mine.chanTakes, mine.chanSchool, mine.chanArea = MINE.Harmful(spellID), nil, false
			end
		elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
			mine.chan, mine.castUntil, mine.castAt = false, now + MINE.tail, now
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			MINE.DropCasts(now)
			local name = unit == "player" and NextSwing(spellID)
			local shot = unit == "player" and Plain(spellID, "number") and MINE.shots[spellID]
			if shot then
				mine.shotIcon = Icon(spellID)
				if not mine.shoot then
					mine.shotEnd, mine.shotAt = now + MINE.cast, -math.huge
				end
			elseif name then
				MINE.OpenPair(now, spellID, name)
			elseif MINE.SpinTick(now, spellID) then
			else
				local entry, spell = MINE.SpellOf(spellID)
				local kind = entry and entry.kind
				if kind == "hit" or kind == "both" or kind == "area" then
					MINE.OpenCast(now, entry, spellID, spell, unit == "pet")
					if unit == "player" and entry.school == 1 and not entry.travel then
						mine.strikeAt = now
					end
				elseif kind == "spin" then
					MINE.StartSpin(now, entry, spellID, spell)
				elseif kind == "sweep" and unit == "player" then
					MINE.StartSweep(now, entry, spellID, spell)
				elseif kind == "counter" and unit == "player" then
					MINE.StartCounter(now, entry, spell, spellID)
				elseif not entry and MINE.Harmful(spellID) then
					MINE.OpenCast(now, nil, spellID, spell, unit == "pet")
				end
				if kind == "dot" or kind == "both" then
					MINE.RecordDot(unit, now, entry, spellID, spell)
				end
			end
			local helpful = unit == "player" and Plain(spellID, "number") and type(C_Spell) == "table" and type(C_Spell.IsSpellHelpful) == "function"
				and select(2, pcall(C_Spell.IsSpellHelpful, spellID))
			if Plain(helpful, "boolean") and helpful then
				mine.healIcon, mine.healUntil = Icon(spellID), now + MINE.cast
			end
		end
	else
		return
	end
	if mine.trace then
		if event == "PLAYER_SWING" then
			Trace(event, MINE.Hand(second), Plain(unit, "number") and ("%.2f s"):format(unit) or nil)
		else
			local entry, name = MINE.SpellOf(spellID)
			Trace(event, unit, spellID, name, entry and ("kind " .. entry.kind) or (name and "not in the table") or nil, entry and MINE.SchoolWords(entry.school) or nil)
		end
	end
	mine.heard = mine.heard + 1
	if mine.off then
		mine.off, mine.unheard = false, 0
		pcall(Sync)
	end
end

local function MineFrame()
	local wanted = ns.Enabled(KEY) and (Opt("source") == "front" or Opt("where") ~= "over") and Opt("whose") ~= "all"
	if wanted and not mine.on then
		local f = mine.frame or CreateFrame("Frame")
		mine.frame = f
		f:SetScript("OnEvent", OnSignal)
		local casts = 0
		for _, event in ipairs(MINE.unitEvents) do
			local done = false
			if f.RegisterUnitEvent then
				local ok, result = pcall(f.RegisterUnitEvent, f, event, "player", "pet")
				done = ok and (ns.IsSecret(result) or result ~= false)
			end
			if not done then
				done = pcall(f.RegisterEvent, f, event)
			end
			casts = casts + (done and 1 or 0)
		end
		for _, event in ipairs(MINE.plainEvents) do
			pcall(f.RegisterEvent, f, event)
		end
		mine.on = true
		mine.deaf = casts == 0
		mine.off = mine.deaf
		if mine.deaf then
			pcall(Sync)
		end
	elseif not wanted and mine.on then
		for _, list in ipairs({ MINE.unitEvents, MINE.plainEvents }) do
			for _, event in ipairs(list) do
				pcall(mine.frame.UnregisterEvent, mine.frame, event)
			end
		end
		mine.on, mine.deaf = false, false
		mine.chan, mine.swing, mine.shoot = false, false, false
		mine.castSlots, mine.castTaken, mine.auraSlots, mine.dots = {}, -1, {}, setmetatable({}, { __mode = "k" })
		mine.pair, mine.spin, mine.sweep, mine.swings, mine.counter, mine.struckAt = nil, nil, nil, {}, nil, {}
	end
	if not wanted then
		if #mine.queue > 0 then
			mine.queue = {}
		end
		if mine.flusher then
			mine.flusher:SetScript("OnUpdate", nil)
		end
	end
end

local function Counts(plate, unit, school, flag, event, amount, at)
	local keep, why, icon, spell, pair, damage, decision
	if Opt("whose") ~= "all" then
		if mine.heard == 0 and InCombatLockdown() then
			mine.unheard = mine.unheard + 1
			if mine.unheard >= MINE.offAfter and not mine.off then
				mine.off = true
				Sync()
			end
		end
		if not (mine.off or (Opt("units") == "target" and plate ~= Plate("target"))) then
			local now = at or GetTime()
			local own = event ~= "HEAL" and MINE.Engaged(unit, plate or unit, now)
			keep, why, icon, spell, pair, damage = MineOne(plate, unit, school, flag, own, now, event)
			if own and not keep then
				keep = true
				mine.kept, mine.last = mine.kept + 1, MINE.Decision("yours", "an enemy only you fight", school)
			end
			decision = mine.last
		else
			decision = "left out (estimate off or not the target)"
		end
	else
		keep = not (Opt("units") == "target" and plate ~= Plate("target"))
		decision = keep and "shown (everyone's)" or "left out (not the target)"
	end
	if mine.trace then
		Trace(unit, event, flag, amount, "school", school, "->", decision, keep and (icon and "icon" or "no icon") or nil, keep and icon or nil)
	end
	if not keep then
		return false
	end
	return true, why, icon, spell, pair, damage
end

local function Ability(why, school, r, g, b, spell)
	local mode = Opt("abilityName")
	if why == "aura slot" then
		return r, g, b, mode == "every" and Plain(spell, "string") and spell or nil
	end
	local named = why == "cast slot" or why == "next swing" or why == "channel" or why == "spin" or why == "sweep" or why == "counter"
	if not (named or why == "swing slot" or why == "extra slot" or why == "shot slot" or why == "pet swing") then
		return r, g, b
	end
	local physical = ns.IsSecret(school) or type(school) ~= "number" or school == 1
	local name = Plain(spell, "string") and ((why == "next swing" and mode ~= "off") or (named and mode == "every")) and spell or nil
	if Opt("school") then
		if named and physical and Opt("abilityColour") == "spell" then
			r, g, b = Colour(0)
		end
	elseif named and not (physical and Opt("abilityColour") == "white") then
		r, g, b = Colour(0)
	else
		r, g, b = Colour(1)
	end
	return r, g, b, name
end

function MINE.IsWord(event, amount, flag)
	if WORDS[event] ~= nil then
		return true
	elseif event ~= "WOUND" then
		return false
	elseif ns.IsSecret(amount) then
		return Plain(flag, "string") and flag == "BLOCK"
	end
	return type(amount) ~= "number" or amount == 0
end

function MINE.Bare(flag)
	if ns.IsSecret(flag) then
		return false
	end
	return flag == nil or flag == "" or flag == "CRITICAL"
end

function MINE.Joinable(a, b)
	local util = C_StringUtil
	return a.event == "WOUND" and b.event == "WOUND" and not a.word and not b.word and ns.IsSecret(a.amount) and ns.IsSecret(b.amount)
		and MINE.Bare(a.flag) and MINE.Bare(b.flag) and type(util) == "table" and type(util.TruncateWhenZero) == "function" and type(util.WrapString) == "function"
end

function MINE.Draw(e, partner)
	if e.why == "next swing" and e.event == "WOUND" and e.word and not ns.IsSecret(e.amount) and MINE.Bare(e.flag) then
		return
	end
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(e.event, e.flag, e.amount, e.school)
	if not kind then
		return
	end
	local value2
	if partner then
		value2 = partner.amount
		crit = crit or (Plain(partner.flag, "string") and partner.flag == "CRITICAL")
	end
	local name, flag, extra = nil, e.flag, false
	if kind == "amount" and e.why == "extra slot" then
		r, g, b = Ability(e.why, e.school, r, g, b)
		name, flag, extra = "(Extra attack)", "EXTRA", true
	elseif kind == "amount" and e.event == "WOUND" then
		r, g, b, name = Ability(e.why, e.school, r, g, b, e.spell)
	end
	local shown = e.over and Spawn(e.plate, e.unit, kind, value, suffix, crit, r, g, b, nil, sign, nil, scale, name, value2)
	local format = (name and not extra) and ("%s " .. name:gsub("%%", "%%%%")) or "%s"
	if e.out and ns.ScrollText.Show("out", kind, value, format, crit, r, g, b, scale, Plain(flag, "string") and flag or nil, nil, e.icon, value2) then
		shown = true
	end
	if shown and not proven then
		proven = true
		Sync()
	end
end

MINE.decided = {}

function MINE.FlushTick()
	ns.Try(KEY, MINE.Flush)
end

function MINE.Flush(all, unit)
	local decided = MINE.decided
	for index = #decided, 1, -1 do
		decided[index] = nil
	end
	local list = mine.queue
	local now = GetTime()
	for _, e in ipairs(list) do
		e.due = all or now - (e.with and e.with.last or e.at) >= MINE.hold or (unit ~= nil and e.unit == unit)
	end
	local index = 1
	while index <= #list do
		local e = list[index]
		if e.due then
			table.remove(list, index)
			if e.route == "target" or Plate(e.unit) == e.plate then
				local counted, why, icon, spell, pair, damage = Counts(e.plate, e.unit, e.school, e.flag, e.event, e.amount, e.at)
				if counted then
					e.why, e.icon, e.spell, e.pair, e.damage, e.drawn = why, icon, spell, pair, damage, false
					decided[#decided + 1] = e
				end
			end
		else
			index = index + 1
		end
	end
	MINE.Rival(decided)
	for at, e in ipairs(decided) do
		if not e.drawn then
			e.drawn = true
			local partner
			if e.pair then
				for later = at + 1, #decided do
					local other = decided[later]
					if not other.drawn and other.pair == e.pair and other.route == e.route and other.plate == e.plate and MINE.Joinable(e, other) then
						other.drawn, partner = true, other
						break
					end
				end
			end
			MINE.Draw(e, partner)
		end
	end
	for at = #decided, 1, -1 do
		decided[at] = nil
	end
	if #mine.queue == 0 and mine.flusher then
		mine.flusher:SetScript("OnUpdate", nil)
	end
end

function MINE.Strike(e)
	if e.why == "next swing" then
		return not e.word, "weapon"
	end
	return e.why == "cast slot" and Plain(e.school, "number") and e.school == 1, e.damage
end

function MINE.Rival(decided)
	for _, strike in ipairs(decided) do
		local struck, damage = MINE.Strike(strike)
		if struck and not strike.ruled then
			local group, strikes, swings, pet = {}, 0, 0, false
			for _, e in ipairs(decided) do
				if not e.ruled and e.route == strike.route and e.plate == strike.plate and math.abs(e.at - strike.at) <= MINE.hold then
					if MINE.Strike(e) then
						group[#group + 1] = e
						strikes = strikes + 1
					elseif e.why == "swing slot" or e.why == "extra slot" or e.why == "pet swing" then
						group[#group + 1] = e
						swings = swings + 1
						pet = pet or e.why == "pet swing"
					end
				end
			end
			if swings > 0 then
				local plain, pick, twice = strikes == 1 and not pet and (damage == "weapon" or damage == "flat"), nil, false
				for _, e in ipairs(group) do
					e.ruled = true
					plain = plain and not e.word and Plain(e.amount, "number")
				end
				if plain then
					for _, e in ipairs(group) do
						if pick == nil or (damage == "weapon" and e.amount > pick.amount) or (damage == "flat" and e.amount < pick.amount) then
							pick, twice = e, false
						elseif e.amount == pick.amount then
							twice = true
						end
					end
				end
				if pick and not twice then
					strike.why, pick.why = pick.why, strike.why
					strike.icon, pick.icon = pick.icon, strike.icon
					strike.spell, pick.spell = pick.spell, strike.spell
					strike.pair, pick.pair = pick.pair, strike.pair
				else
					for _, e in ipairs(group) do
						e.why, e.icon, e.spell = "unnamed", nil, nil
					end
					mine.last = MINE.Decision("yours", "a swing or a strike, not sure which", strike.school)
				end
			end
		end
	end
end

function MINE.Wait(e)
	if #mine.queue >= MINE.queueMax then
		MINE.Flush(true)
	end
	local list = mine.queue
	if Plain(e.school, "number") and e.school == 1 then
		e.with, e.last = e, e.at
		for _, other in ipairs(list) do
			local first = other.with
			if first ~= nil and other.route == e.route and other.plate == e.plate and e.at - other.at <= MINE.hold and e.at - first.at <= MINE.gather then
				e.with, first.last = first, e.at
				break
			end
		end
	end
	list[#list + 1] = e
	if not mine.flusher then
		mine.flusher = CreateFrame("Frame")
	end
	if #list == 1 then
		mine.flusher:SetScript("OnUpdate", MINE.FlushTick)
	end
end

function MINE.Judge(e)
	if Opt("whose") ~= "all" then
		MINE.Wait(e)
		return
	end
	local counted, why, icon, spell, pair = Counts(e.plate, e.unit, e.school, e.flag, e.event, e.amount, e.at)
	if counted then
		e.why, e.icon, e.spell, e.pair = why, icon, spell, pair
		MINE.Draw(e)
	end
end

local function OnTarget(unit, event, flag, amount, school)
	if not Plain(event, "string") or event == "HEAL" or Yourself(unit) then
		return
	end
	local ok, attackable = pcall(UnitCanAttack, "player", unit)
	if ok and Plain(attackable, "boolean") and not attackable then
		return
	end
	MINE.Judge({ route = "target", plate = Plate("target"), unit = unit, event = event, flag = flag, amount = amount, school = school,
		word = MINE.IsWord(event, amount, flag), over = false, out = true, at = Now() })
end

local function OnCombat(unit, event, flag, amount, school)
	if Plain(unit, "string") and (unit == "player" or unit == "vehicle") then
		if mine.counter and unit == "player" and Plain(event, "string") and event == "WOUND" and Plain(school, "number") and school == 1 then
			MINE.OnStruck(Now())
		end
		local ok, err = pcall(OnOwn, unit, event, flag, amount, school)
		if not ok then
			own.failed, own.first = own.failed + 1, own.first or tostring(err)
		end
		return
	end
	local enemies = Opt("source") == "front"
	if not enemies and not ns.ScrollText.On("out") and FriendMode() == "off" then
		return
	end
	if ns.IsSecret(unit) then
		stats.detail = stats.detail + 1
		return
	end
	if type(unit) ~= "string" then
		return
	end
	if unit == "target" then
		stats.target = stats.target + 1
		local where = Opt("where")
		if (where == "scroll" or (where == "both" and not Plate("target"))) and ns.ScrollText.On("out") then
			OnTarget(unit, event, flag, amount, school)
		end
	end
	if unit == "pet" or Group(unit) then
		OnFriendToken(unit, event, flag, amount, school)
		return
	end
	if not unit:lower():find("^nameplate") then
		return
	end
	stats.reports = stats.reports + 1
	Remember(last, unit, event, flag, amount, school)
	if not Plain(event, "string") then
		stats.detail = stats.detail + 1
		return
	end
	local plate = Plate(unit)
	if not plate then
		stats.noPlate = stats.noPlate + 1
		return
	end
	local ok, attackable = pcall(UnitCanAttack, "player", unit)
	if ok and Plain(attackable, "boolean") and not attackable then
		stats.friendly = stats.friendly + 1
		local mode = FriendMode()
		if mode == "plates" or mode == "both" then
			OnFriendPlate(plate, unit, event, flag, amount, school)
		end
		return
	end
	local where = Opt("where")
	local over = enemies and where ~= "scroll" and not (GroupHand() and Read(VARS[1].name) ~= "0")
	local out = where == "both" and event ~= "HEAL"
	if not (over or out) then
		return
	end
	MINE.Judge({ route = "plate", plate = plate, unit = unit, event = event, flag = flag, amount = amount, school = school,
		word = MINE.IsWord(event, amount, flag), over = over, out = out, at = Now() })
end

local function OnAdded(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		local plate = Plate(unit)
		if plate then
			count[plate], mine.dots[plate], mine.hitBy[plate] = nil, nil, nil
			for index = #live, 1, -1 do
				if live[index].plate == plate then
					Release(index)
				end
			end
		end
	end
end

local function OnRemoved(unit)
	plateOf.at = nil
	if Plain(unit, "string") then
		if #mine.queue > 0 then
			MINE.Flush(false, unit)
		end
		mine.aura[unit], mine.auraSlots[unit] = nil, nil
	end
	if #live == 0 then
		return
	end
	local now = GetTime()
	for index = #live, 1, -1 do
		local item = live[index]
		if item.plate and item.kind ~= "frame" and (ns.IsSecret(unit) or item.unit == unit) then
			local ok, x, y = pcall(item.text.GetCenter, item.text)
			if ok and Plain(x, "number") and Plain(y, "number") then
				local dx, dy = Offsets(item, now - item.start)
				item.screenX, item.screenY = x - dx, y - dy
				item.plate = nil
				if pcall(Place, item, now) then
					stats.kept = stats.kept + 1
				else
					stats.unplaced = stats.unplaced + 1
					Release(index)
				end
			else
				Release(index)
				stats.removed = stats.removed + 1
			end
		end
	end
end

local function Refresh()
	Sync()
	if not (ns.Enabled(KEY) and Opt("source") == "front") then
		ReleaseKind("enemy")
	end
	if FriendMode() == "off" then
		ReleaseKind("friend")
	end
	for _, area in ipairs({ "out", "inc" }) do
		if not ns.ScrollText.On(area) then
			ns.ScrollText.Clear(area)
		end
	end
	MineFrame()
	if ns.CombatCuesRefresh ~= nil then
		ns.CombatCuesRefresh()
	end
	if ns.CastLandSync ~= nil then
		ns.CastLandSync()
	end
end

local function OnRoster()
	for _, frame in pairs(frames.byUnit) do
		count[frame] = nil
	end
	frames.byUnit, frames.at = {}, 0
	if Opt("group") == "game" then
		pcall(Sync)
	end
end

local function OnVariables()
	pcall(Sync)
	local wanted = Wanted(SELF_VAR)
	if wanted ~= nil and Same(Read(SELF_VAR.name), wanted) then
		pcall(TellSetting, SELF_VAR, wanted)
	end
end

local resync = false
local function OnCVar(name, value)
	if resync or not Plain(name, "string") or name:lower() ~= SELF_VAR.name:lower() then
		return
	end
	local wanted = Wanted(SELF_VAR)
	if wanted == nil or (Plain(value, "string") and Same(value, wanted)) then
		return
	end
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		pcall(Sync)
		return
	end
	resync = true
	C_Timer.After(0, function()
		resync = false
		pcall(Sync)
	end)
end

local forbiddenSeen = {}
local function OnForbidden(unit)
	if Plain(unit, "string") then
		if forbiddenSeen[unit] then
			return
		end
		local ok, attackable = pcall(UnitCanAttack, "player", unit)
		if ok and Plain(attackable, "boolean") and attackable then
			return
		end
		forbiddenSeen[unit] = true
	end
	friend.forbidden = friend.forbidden + 1
end

local function OnForbiddenGone(unit)
	if Plain(unit, "string") then
		forbiddenSeen[unit] = nil
	end
end

function ns.CombatOwnShown()
	return ns.Enabled(KEY) and Opt("own") ~= "off"
end

local function Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if Opt("source") == "front" then
		if proven then
			lines[#lines + 1] = ("Numbers in front of nameplates: %d shown."):format(stats.shown)
		else
			lines[#lines + 1] = "Numbers in front of nameplates: waiting for the first hit. The game's numbers show until then."
		end
		if Opt("whose") ~= "all" then
			if mine.off then
				lines[#lines + 1] = "Whose hits: none of your casts or swings reached Flat UI here, so the game's own numbers show."
			else
				lines[#lines + 1] = ("Whose hits: yours. Every hit on an enemy only you and your pet fight; elsewhere one for each of your casts, swings, shots, auras and pet swings. Left out as not yours: %d."):format(mine.left)
				if InGroup() and Opt("group") == "flat" then
					lines[#lines + 1] = "Whose hits: in a group, a proc that casts nothing shows only in the game's own numbers (Numbers over enemies in a group)."
				end
			end
		end
		if GroupHand() and Read(VARS[1].name) ~= "0" then
			lines[#lines + 1] = "Numbers over enemies: in a group, the game's own numbers show, at Size of experience and other gains, as the game has one size for both."
		end
	end
	for _, line in ipairs(ns.ScrollText.Lines()) do
		lines[#lines + 1] = line
	end
	local mode = FriendMode()
	if mode ~= "off" then
		if friendProven then
			lines[#lines + 1] = ("Numbers over friendly units: %d shown."):format(friend.shown)
		elseif Opt("friendHeal") == "taken" then
			lines[#lines + 1] = "Numbers over friendly units: waiting for the first hit. The game's healing numbers show until then."
		else
			lines[#lines + 1] = "Numbers over friendly units: waiting for the first hit."
		end
		if (mode == "plates" or mode == "both") and Read("nameplateShowFriendlyPlayers") == "0" then
			lines[#lines + 1] = "Friendly Player Nameplates is off in the game's options."
		end
		if friend.forbidden > 0 then
			lines[#lines + 1] = ("Friendly nameplates the game hides from interface mods: %d. %s"):format(friend.forbidden,
				mode == "plates" and "No number shows there." or "Numbers show over party and raid frames there.")
		end
		if friend.group == 0 and stats.reports + own.reports > 0 and InGroup() then
			lines[#lines + 1] = "The game sent no hit reports for party or raid units. /flatui combat has the counts."
		end
		if friend.unknown > 0 then
			lines[#lines + 1] = ("Could not tell whether %d friendly numbers were on your target. They showed anyway."):format(friend.unknown)
		end
		if Opt("friendHeal") == "taken" then
			lines[#lines + 1] = "Shields over friendly units show in the game's own numbers."
		end
	end
	if Opt("own") ~= "off" then
		lines[#lines + 1] = ("Combat text for you: %d shown."):format(ns.ScrollText.Shown("inc"))
		if own.failed > 0 then
			lines[#lines + 1] = ("Hit reports for you that raised an error: %d. The first: %s"):format(own.failed, own.first)
		end
		if Read("enableFloatingCombatText") == "1" then
			lines[#lines + 1] = "Scrolling Combat Text for Self is ticked in the game's options and the game kept it on, so your numbers may show twice. /reload unticks it."
		end
	end
	if stats.kind > 0 then
		lines[#lines + 1] = ("Hit types the game would not tell: %d."):format(stats.kind)
	end
	if stats.unplaced + ns.ScrollText.Unplaced() > 0 then
		lines[#lines + 1] = ("Numbers the game would not position: %d."):format(stats.unplaced + ns.ScrollText.Unplaced())
	end
	if stats.unstyled > 0 then
		lines[#lines + 1] = ("Numbers the game would not set the font on: %d."):format(stats.unstyled)
	end
	return lines
end

local function Report()
	for _, var in ipairs(VARS) do
		local current = Read(var.name)
		if current == nil then
			print(("%s: not in this client"):format(var.name))
		else
			print(("%s: now %s, default %s, wanted %s"):format(var.name, current, GameDefault(var), Wanted(var) or "no change"))
			if var.name == "WorldTextScale_v2" then
				print(("Size of experience and other gains: %s%s."):format(GAIN_WORDS[Opt("gainSize")] or tostring(Opt("gainSize")), (Switch() == "0" or GroupHand()) and "" or ", not in use"))
			end
		end
	end
	print(("classicStyleWorldText: %s"):format(Read("classicStyleWorldText") or "not in this client"))
	print(("At login: %s"):format(atLogin or "nothing remembered"))
	print(("Hit reports: %d for nameplates, %d for target."):format(stats.reports, stats.target))
	print(("Shown: %d. No nameplate: %d. On friendly units: %d. Report unreadable: %d."):format(stats.shown, stats.noPlate, stats.friendly, stats.detail))
	print(("Last hit report: %s"):format(Reported(last) or "none"))
	print(("Your hits: %d shown, %d left out. Casts and swings seen: %d. Swings and shots the game reported: %d. Auras the game would not tell about: %d. Last hit: %s."):format(mine.kept, mine.left, mine.heard, mine.swingCount, mine.blind, mine.last or "none"))
	local modes = { off = "Off", frames = "Party and raid frames", plates = "Friendly nameplates", both = "Both" }
	print(("Friendly numbers: %s. Hit reports: %d nameplate, %d party or raid, %d pet. Shown: %d. No frame or nameplate to show on: %d. Repeated reports skipped: %d. Yours, left to Combat text for you: %d. Target check failed: %d. Nameplates the game hides from interface mods: %d."):format(
		modes[Opt("friend")] or tostring(Opt("friend")), friend.plates, friend.group, friend.pet, friend.shown, friend.noAnchor, friend.same, friend.self, friend.unknown, friend.forbidden))
	print(("Last friendly hit report: %s"):format(Reported(friend.last) or "none"))
	print(("Friendly nameplate variables: players %s, pets %s, minions %s, NPCs %s."):format(Read("nameplateShowFriendlyPlayers") or "not known",
		Read("nameplateShowFriendlyPlayerPets") or "not known", Read("nameplateShowFriendlyPlayerMinions") or "not known", Read("nameplateShowFriendlyNpcs") or "not known"))
	if FriendMode() ~= "off" and Opt("friendHeal") == "taken" then
		print(("The game's setting %s goes to 0 with the first friendly number. Changing Where friendly numbers show or Healing over friendly units, turning the page off, logging out and /flatui combat reset put it back."):format(HEAL_VAR))
	end
	print(("Nameplate layer: %s. Numbers layer: %s."):format(plateStrata or "none", hostStrata or "none"))
	if Classic() then
		local seconds = math.floor(CLASSIC.life * Opt("classicTime") / 100 * 100 + 0.5) / 100
		print(("Style: Classic, rise %g, %g s, %s. Started in column: %d middle, %d right, %d left."):format(Opt("classicRise"), seconds,
			Opt("classicStack") == "down" and "new numbers start lower" or "older numbers move up", stats.columns[0], stats.columns[1], stats.columns[-1]))
	end
	print(("Numbers kept after their nameplate went: %d. Removed with it: %d."):format(stats.kept, stats.removed))
	local name = Look().name
	local file, height, flags = FromGame(name)
	print(("Font: %s, %s, flags %s."):format(file or "not known", height and ("%g"):format(height) or "not known", flags == nil and "not known" or (flags == "" and "none" or flags)))
	local _, _, thick = FromGame(LOOK.outlines.thick[1])
	local _, _, thin = FromGame(LOOK.outlines.thin[1])
	print(("Outline styles from the game: thick %s, thin %s."):format(
		thick ~= nil and thick ~= "" and ('"%s"'):format(thick) or "none read", thin ~= nil and thin ~= "" and ('"%s"'):format(thin) or "none read"))
	print(("Font size made at: %d."):format(Raster()))
	if stats.width then
		print(("Width of the last number: %g%s. Height drawn: %g."):format(stats.width, stats.estimated and " (3 times its height when the game gave none)" or "", stats.drawn))
	else
		print("Width of the last number: no number drawn yet.")
	end
	print(("Hit reports for you: %d. Shown: %d."):format(own.reports, ns.ScrollText.Shown("inc")))
	print(("Last hit report for you: %s"):format(Reported(own.last) or "none"))
	print(("Hits shown in the Outgoing scroll area: %d."):format(ns.ScrollText.Shown("out")))
	local x, y
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot(OWN.mover, "CENTER")
	end
	print(x and ("Start of your text: %g, %g."):format(x, y) or "Start of your text: not known.")
	x, y = nil, nil
	if type(ns.MoverSpot) == "function" then
		x, y = ns.MoverSpot("FlatUICombatOut", "CENTER")
	end
	print(x and ("Start of your hits: %g, %g."):format(x, y) or "Start of your hits: not known.")
	local scale, world = WorldScale()
	local length = ns.CombatShape.scroll.length
	print(world and ("Game world height is %g: the scroll areas are %g long."):format(world, length * scale)
		or ("Game world height is not known: the scroll areas are %g long."):format(length))
end

local SAMPLES = { { "WOUND", "", 412, 1 }, { "WOUND", "GLANCING", 412, 1 }, { "WOUND", "CRITICAL", 824, 1 }, { "DODGE", "", 0, 1 } }
local OUT_SAMPLES = { { "WOUND", "", 412, 1, "swing" }, { "WOUND", "GLANCING", 412, 1 }, { "WOUND", "CRITICAL", 824, 4, "spell" }, { "DODGE", "", 0, 1 } }

local function Sample(sample)
	local plate = Plate("target")
	if not plate then
		return
	end
	local kinds, amounts, shown = stats.kind, stats.amount, stats.shown
	local kind, value, suffix, crit, r, g, b, sign, scale = Describe(sample[1], sample[2], sample[3], sample[4])
	if kind then
		Spawn(plate, false, kind, value, suffix, crit, r, g, b, nil, sign, nil, scale)
	end
	stats.kind, stats.amount, stats.shown = kinds, amounts, shown
end

local OWN_SAMPLES = { { "WOUND", "", 412, 1 }, { "WOUND", "CRITICAL", 824, 4 }, { "HEAL", "", 300, 1 }, { "DODGE", "", 0, 1 }, { "ENERGIZE", "", 20, 1 } }

local function OwnSample(sample)
	local kinds, amounts = stats.kind, stats.amount
	local kind, value, format, crit, r, g, b, _, scale = Describe(sample[1], sample[2], sample[3], sample[4], Opt("own"))
	if kind then
		ns.ScrollText.Show("inc", kind, value, format, crit, r, g, b, scale, sample[2], true)
	end
	stats.kind, stats.amount = kinds, amounts
end

local function OutIcon(which)
	if which == nil or Opt("whose") ~= "one" then
		return nil
	end
	local mode = Opt("icons")
	if which == "swing" then
		return mode == "all" and Icon(6603) or nil
	end
	return (mode == "all" or mode == "spells") and Icon(133) or nil
end

local function OutSample(sample)
	local kinds, amounts = stats.kind, stats.amount
	local kind, value, _, crit, r, g, b, _, scale = Describe(sample[1], sample[2], sample[3], sample[4])
	if kind then
		local format = "%s"
		if kind == "amount" and sample[5] == "spell" and Opt("whose") == "one" and Opt("abilityName") == "every" then
			local ok, name = pcall(C_Spell.GetSpellName, 133)
			name = ok and Plain(name, "string") and name ~= "" and name or "Fireball"
			format = "%s " .. name:gsub("%%", "%%%%")
		end
		ns.ScrollText.Show("out", kind, value, format, crit, r, g, b, scale, sample[2], true, OutIcon(sample[5]))
	end
	stats.kind, stats.amount = kinds, amounts
end

local function Run(samples, show)
	for index, sample in ipairs(samples) do
		if index > 1 and C_Timer and C_Timer.After then
			C_Timer.After(0.25 * (index - 1), function()
				ns.Try(KEY, show, sample)
			end)
		else
			ns.Try(KEY, show, sample)
		end
	end
end

local FRIEND_SAMPLES = { { "WOUND", "", 312, 1 }, { "HEAL", "", 180, 1 }, { "HEAL", "CRITICAL", 540, 1 }, { "WOUND", "", 0, 1 } }

local function FriendAnchor()
	local mode = FriendMode()
	if mode == "plates" or mode == "both" then
		local plate = Plate("target")
		if plate then
			local ok, attackable = pcall(UnitCanAttack, "player", "target")
			if ok and Plain(attackable, "boolean") and not attackable then
				return plate, false
			end
		end
	end
	if mode == "frames" or mode == "both" then
		local frame = FrameOfUnit("party1") or FrameOfUnit("pet")
		if frame then
			return frame, true
		end
	end
	return nil
end

local function FriendSample(anchor, onFrame)
	return function(sample)
		local kinds, amounts, shown = stats.kind, stats.amount, friend.shown
		local kind, value, suffix, crit, r, g, b, sign, scale = Describe(sample[1], sample[2], sample[3], sample[4], nil, true)
		if kind then
			Spawn(anchor, false, kind, value, suffix, crit, r, g, b, "friend", sign, onFrame, scale)
		end
		stats.kind, stats.amount, friend.shown = kinds, amounts, shown
	end
end

local function Test()
	if not ns.Enabled(KEY) then
		print("Place combat numbers is off.")
		return
	end
	if Opt("own") ~= "off" then
		Run(OWN_SAMPLES, OwnSample)
	else
		print("Combat text for you is off.")
	end
	if ns.ScrollText.On("out") then
		Run(OUT_SAMPLES, OutSample)
	end
	if type(ns.CombatCuesTestRound) == "function" then
		ns.CombatCuesTestRound()
	end
	if Opt("kicks") == true and type(ns.CastLandWordSample) == "function" then
		ns.CastLandWordSample()
	end
	if Opt("where") == "scroll" then
	elseif Opt("source") ~= "front" then
		print("Numbers over enemies is set to As the game has them.")
	elseif not Plate("target") then
		print("Target an enemy with a nameplate to see numbers over it.")
	else
		Run(SAMPLES, Sample)
	end
	if FriendMode() == "off" then
		print("Where friendly numbers show is Off.")
		return
	end
	local anchor, onFrame = FriendAnchor()
	if not anchor then
		print("Target a friendly unit with a nameplate, or join a group, to see numbers over friendly units.")
		return
	end
	if Opt("friendHeal") ~= "taken" then
		print("Healing over friendly units is not Healing they take from anyone: no heal samples.")
	end
	Run(FRIEND_SAMPLES, FriendSample(anchor, onFrame))
end

function ns.CombatTextTestStep(now)
	if not ns.Enabled(KEY) or not ns.Finite(now) then
		return
	end
	local absorb = { "WOUND", "ABSORB", 0, 1 }
	local own = { OWN_SAMPLES[1], OWN_SAMPLES[2], OWN_SAMPLES[3], OWN_SAMPLES[4], absorb }
	local over = { SAMPLES[1], SAMPLES[3], SAMPLES[2], SAMPLES[4], absorb }
	local out = { OUT_SAMPLES[1], OUT_SAMPLES[3], OUT_SAMPLES[2], OUT_SAMPLES[4], absorb }
	local index = math.floor(now / 1.5) % #own + 1
	if Opt("own") ~= "off" then
		ns.Try(KEY, OwnSample, own[index])
	end
	if ns.ScrollText.On("out") then
		ns.Try(KEY, OutSample, out[index])
	end
	if Opt("where") ~= "scroll" and Opt("source") == "front" and Plate("target") then
		ns.Try(KEY, Sample, over[index])
	end
end

local function Reset()
	ns.Set(KEY .. ".enabled", false)
	if ns.NotifyOption then
		ns.NotifyOption(KEY .. ".enabled")
	end
	if type(ns.RefreshPanel) == "function" then
		pcall(ns.RefreshPanel)
	end
	local refused = 0
	if Calls() then
		for _, var in ipairs(VARS) do
			local current, default = not var.keep and Read(var.name) or nil, GameDefault(var)
			if current ~= nil and not Same(current, default) then
				local held = Write(var, default)
				if held ~= nil and Same(held, default) then
					print(("%s: %s"):format(var.name, default))
				else
					refused = refused + 1
					if held ~= nil and not Same(held, current) then
						print(("%s: the game keeps %s for %s."):format(var.name, held, default))
					else
						print(("%s: the game refused %s."):format(var.name, default))
					end
				end
			end
		end
	end
	local db = ns.Account()
	if db then
		local kept
		for _, var in ipairs(VARS) do
			local rec = var.keep and db.cvars and db.cvars[var.name]
			if rec and not Same(Read(var.name), rec.game) then
				kept = kept or {}
				kept[var.name] = rec
			end
		end
		db.cvars = kept
	end
	local owned = VARS[#VARS]
	if refused > 0 then
		print(("Place combat numbers: off. The game did not take %d of the defaults."):format(refused))
	elseif owned.keep and Calls() and Read(owned.name) ~= nil and not Same(Read(owned.name), GameDefault(owned)) then
		print("Place combat numbers: off. The game's defaults are back, except Scrolling Combat Text for Self, which stays as you have it.")
	else
		print("Place combat numbers: off. The game's defaults are back.")
	end
end

local HELP = {
	"/flatui combat - the game's combat number settings: now, default, wanted",
	"/flatui combat test - sample numbers for you, over your target and over friendly units, and one round of the combat alerts",
	"/flatui combat reset - the game's defaults, and Place combat numbers off",
	"/flatui combat trace - each hit report and signal of yours in chat, until you type it again",
}

local function Command(rest)
	local word = rest:lower()
	if word == "" then
		Report()
	elseif word == "test" then
		Test()
	elseif word == "reset" then
		Reset()
	elseif word == "trace" then
		mine.trace = not mine.trace
		print(mine.trace and "Combat trace on." or "Combat trace off.")
	else
		for _, line in ipairs(HELP) do
			print(line)
		end
	end
end

ns.Register(KEY, {
	label = "Combat text",
	counted = false,
	Start = Refresh,
	Refresh = Refresh,
	events = {
		UNIT_COMBAT = OnCombat,
		NAME_PLATE_UNIT_ADDED = OnAdded,
		NAME_PLATE_UNIT_REMOVED = OnRemoved,
		GROUP_ROSTER_UPDATE = OnRoster,
		UNIT_PET = OnRoster,
		FORBIDDEN_NAME_PLATE_UNIT_ADDED = OnForbidden,
		FORBIDDEN_NAME_PLATE_UNIT_REMOVED = OnForbiddenGone,
		VARIABLES_LOADED = OnVariables,
		CVAR_UPDATE = OnCVar,
		PLAYER_LOGOUT = Leave,
	},
	slash = { combat = Command },
	help = HELP,
	Status = Status,
})

if ns.TestMode then
	ns.TestMode.Register("combattext", {
		module = KEY,
		label = "Combat text",
		every = 1.5,
		Tick = ns.CombatTextTestStep,
		Stop = function()
			ns.ScrollText.ClearSamples()
		end,
	})
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	if ns.Account() and not ns.Enabled(KEY) then
		pcall(Sync)
	end
end)
