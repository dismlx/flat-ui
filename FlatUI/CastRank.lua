local _, ns = ...

-- Spell rank on the player bar: the rank of the spell you cast after its name, as Fireball (Rank 5), on the player's two cast bars (the game's own
-- and the one it lays over a window that casts for you, CastingBarFrame.lua:1347-1446). The game writes the name of a cast in the Text of a bar when
-- the cast starts (HandleCastStart, CastingBarFrame.lua:342-388) and never reads it back. On the next frame this file reads the cast (UnitCastingInfo,
-- or UnitChannelInfo for a channel; the player's are plain, SecretPredicatesDocumentation.lua:110-113 on live), asks C_Spell.GetSpellSubtext for the
-- rank of that spell ID, the one cast and not the highest known, and writes the name and the rank in the same font string with SetText, only while the
-- game's text is still the name of that cast: Failed, Interrupted (CastingBarFrame.lua:531-537), a text the client withholds and the name of another
-- cast are left as the game has them. The font, size, colour, place and alpha of the text stay as the game and the rows of the Cast bars page set them.
-- A rank text with no number in it (Racial, Apprentice, Summon) is not shown, as ErrandsRanks.lua reads ranks. In a fight a bar that says it is
-- protected, or will not say, is not written. Off puts back the name the game wrote while the bar still shows the rank. This follows the cast bar of
-- EnhanceQoL by Philipp Barth (UF_Helper.lua:2855-2866), adapted with his permission. Not a module: the cast bars module calls ns.CastRankSync
-- whenever it applies its settings.

local KEY, PART, ROW = "castbars", "spell rank", "castbars.rank"
local BARS = { "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame" }
-- The three starts in which the game writes the name (CastingBarFrame.lua:118-119, 342-388).
local STARTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START" }
local MAX_RANK = 1000

-- Per bar, { name = the name the game wrote, text = what was written here }.
local written = setmetatable({}, { __mode = "k" })
-- What /flatui status says: the last text written, and what kept a rank away. waiting is the spell whose rank text the game had not loaded yet.
local state = { shown = nil, noCall = false, refused = false, protected = false, cut = nil, waiting = nil }
local frame, listening, queued = nil, false, false
local Listen

local function Wanted()
	return ns.Enabled(KEY) and ns.Get(ROW) == true and ns.Get("castbars.textShow") ~= false and not ns.PartStopped(KEY, PART)
end

-- The rank text of a spell: "Rank 5", "Rang 5", "Ранг 5". Nil for none, for a text with no number and for a withheld one; "" while the game has not
-- loaded the text of the spell (SpellDocumentation.lua:341-355, SPELL_TEXT_UPDATE).
local function RankText(id)
	local spells = C_Spell
	local call = type(spells) == "table" and not ns.IsSecret(spells) and spells.GetSpellSubtext or nil
	if type(call) ~= "function" then
		state.noCall = true
		return nil
	end
	local ok, text = pcall(call, id)
	if not ok or ns.IsSecret(text) or type(text) ~= "string" then
		return nil
	elseif text == "" then
		return ""
	end
	local number = tonumber(text:match("(%d+)"))
	return number and number >= 1 and number < MAX_RANK and text or nil
end

-- The player's cast now: the name the game writes (the display name, else the name; CastingBarFrame.lua:350, 387) and the spell ID. Nil while there
-- is none, and when any of them is withheld or not of its type.
local function Cast()
	local ok, name, display, _, _, _, _, _, _, id = pcall(UnitCastingInfo, "player")
	if ok and not ns.IsSecret(name) and name == nil then
		ok, name, display, _, _, _, _, _, id = pcall(UnitChannelInfo, "player")
	end
	if not ok or ns.IsSecret(name) or ns.IsSecret(display) or ns.IsSecret(id) then
		return nil
	end
	-- The game writes the display name, whatever it holds (CastingBarFrame.lua:364-369, 404-406 on Forever).
	local shown = display
	if type(shown) ~= "string" or shown == "" or type(id) ~= "number" or id <= 0 then
		return nil
	end
	return shown, id
end

local function Text(bar)
	local ok, text = pcall(function()
		return bar.Text
	end)
	if ok and not ns.IsSecret(text) and type(text) == "table" then
		return text
	end
	return nil
end

-- The text of a font string, or nil when it raises, is withheld (RequiresFontStringTextAccess, SecretPredicatesDocumentation.lua:20-25 on
-- classic_era) or is no string.
local function Current(text)
	local ok, current = pcall(text.GetText, text)
	if ok and not ns.IsSecret(current) and type(current) == "string" then
		return current
	end
	return nil
end

-- In a fight a bar that is protected, or will not say, is left alone; so is every bar while Movers.lua, which asks, is not there.
local function Blocked(bar)
	return InCombatLockdown() and (type(ns.MaybeProtected) ~= "function" or ns.MaybeProtected(bar))
end

local function Write(bar, shown, rank)
	local text = Text(bar)
	if not text then
		return
	end
	local suffix = " (" .. rank .. ")"
	-- A name that ends with its rank already is left as it is (EnhanceQoL's check, UF_Helper.lua:2864).
	if shown:sub(-#suffix) == suffix then
		return
	end
	local want = shown .. suffix
	local current = Current(text)
	if current ~= shown then
		return
	end
	if Blocked(bar) then
		state.protected = true
		return
	end
	if pcall(text.SetText, text, want) then
		-- A name the bar cannot show whole with its rank keeps the game's text (IsTruncated, SimpleFontStringAPIDocumentation.lua:442-454
		-- on Forever): "Lesser Healing Wave (Ra..." says less than the name. No such call, a raise or a withheld answer is not cut.
		local ok, cut = pcall(text.IsTruncated, text)
		if ok and not ns.IsSecret(cut) and cut == true then
			pcall(text.SetText, text, shown)
			state.cut = want
			return
		end
		written[bar] = { name = shown, text = want }
		state.shown = want
	else
		state.refused = true
	end
end

-- The name the game wrote goes back, while the bar still shows what was written here.
local function Restore(bar)
	local mine = written[bar]
	written[bar] = nil
	local text = mine and Text(bar)
	if text and Current(text) == mine.text and not Blocked(bar) then
		pcall(text.SetText, text, mine.name)
	end
end

local function RestoreAll()
	for bar in pairs(written) do
		pcall(Restore, bar)
	end
	state.waiting = nil
end

-- One look at the player's bars. Its first value is the fresh key of ns.EachPart, so that each failure counts and three stop the part.
local function Step()
	if not Wanted() then
		return
	end
	local shown, id = Cast()
	if not shown then
		return
	end
	local rank = RankText(id)
	if rank == "" then
		state.waiting = id
		return
	end
	state.waiting = nil
	if not rank then
		return
	end
	for _, name in ipairs(BARS) do
		local bar = _G[name]
		if bar ~= nil and not ns.IsSecret(bar) and not ns.Forbidden(bar) then
			Write(bar, shown, rank)
		end
	end
end

-- One look, inside the part. A look that is no longer wanted, or the part that has just stopped, ends the events and puts the names back: the
-- module may have stopped in a refresh that never reached ns.CastRankSync.
local function Run()
	queued = false
	if not Wanted() or (not ns.EachPart(KEY, PART, Step, {}) and ns.PartStopped(KEY, PART)) then
		Listen(false)
		RestoreAll()
	end
end

-- The game writes the name in its own handler of the event; the look waits for the next frame, once however many starts come in a frame.
local function Queue()
	if queued then
		return
	end
	queued = true
	if not (type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, Run)) then
		Run()
	end
end

-- The first value of an event: the unit of a start, which the code tests itself, and the spell ID of SPELL_TEXT_UPDATE.
local function OnEvent(_, event, first)
	if event == "SPELL_TEXT_UPDATE" then
		if state.waiting ~= nil and not ns.IsSecret(first) and first == state.waiting then
			Queue()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or (not ns.IsSecret(first) and first == "player") then
		Queue()
	end
end

-- A start heard for the player alone when the client can (ProcTriggers.lua:313-322, Trackers.lua:2566-2575), else for every unit: OnEvent
-- keeps the player's.
local function Hear(event)
	if frame.RegisterUnitEvent then
		local ok, registered = pcall(frame.RegisterUnitEvent, frame, event, "player")
		if ok and (ns.IsSecret(registered) or registered ~= false) then
			return
		end
	end
	pcall(frame.RegisterEvent, frame, event)
end

-- The events are heard only while the rank is wanted; at the default no frame is made.
function Listen(on)
	if on and not listening then
		if frame == nil then
			frame = CreateFrame("Frame")
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnEvent)
		end
		for _, event in ipairs(STARTS) do
			Hear(event)
		end
		pcall(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
		pcall(frame.RegisterEvent, frame, "SPELL_TEXT_UPDATE")
		listening = true
	elseif not on and listening then
		pcall(frame.UnregisterAllEvents, frame)
		listening = false
	end
end

-- Called by Bars.lua at the end of a refresh of the cast bars: the events start or stop with the row, a cast on its way gets its rank at once, and
-- off puts the names back.
function ns.CastRankSync()
	local on = Wanted()
	Listen(on)
	if on then
		Run()
	else
		RestoreAll()
	end
end

ns.AddStatus(KEY, function()
	if not Wanted() then
		return {}
	end
	local lines = { state.shown and ("Spell rank: last shown %s."):format(state.shown) or "Spell rank: no ranked cast seen yet." }
	if state.noCall then
		lines[#lines + 1] = "Spell rank: this client gives no rank text, so none is shown."
	end
	if state.refused then
		lines[#lines + 1] = "Spell rank: the game would not take the text of a cast bar, so a rank was not shown."
	end
	if state.cut then
		lines[#lines + 1] = ("Spell rank: %s did not fit the bar, so the name was left as the game wrote it."):format(state.cut)
	end
	if state.protected then
		lines[#lines + 1] = "Spell rank: the player bar is protected here in a fight, so a rank cast in a fight is not shown."
	end
	return lines
end)
