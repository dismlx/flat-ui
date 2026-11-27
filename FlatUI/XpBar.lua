local _, ns = ...

-- Flat UI's own experience and reputation bar. The design is research/xp-bar/design.md.
--
-- The game's two status bars stay shown and laid out in the bottom stack and are not drawn: the alpha of their parent, StatusTrackingBarManager,
-- is 0, and the mouse is off on the bars inside (StatusTrackingBar.xml:35-57, StatusTrackingBarTemplate.xml:3). Nothing of the game's is sized, moved,
-- scaled, hidden, reparented, hooked or unregistered. The bar drawn here is a frame of this addon's on UIParent, any width and height, fed by the
-- calls the game's own bar makes from insecure code (ExpBar.lua, ReputationBar.lua). Its settings are the Experience and reputation bars rows of
-- the Experience and menu bars page (module hud); this file adds its handlers to that module with ns.AddEvent.
-- The Levelling rows of that page add what XpStats.lua counts: a stretch for the experience of the quests ready to hand in, drawn as the rested
-- stretch is and above it, the levelling text after the bar text, and lines in the tooltip; on the reputation bar, Reputation text after its bar
-- text and the reputation pace in its tooltip, from the faction the bar shows (ns.XpRepNow). The bar is drawn again when those numbers change
-- (ns.XpBarRedraw), and the tooltip of a bar under the cursor is written again with each drawing.
-- Its reputation bar shows the faction the Levelling errands follow, when they follow one (ErrandsLevelling.lua); the faction the game watches
-- is not changed.
-- With Experience bar under the bar block (on by default) block 1 of the Bar block page, while it is on, places the bar right under its bars,
-- a bar gap below them and exactly as wide as the block, and keeps the bar's room in the block (BarBlock.lua, ns.XpUnder); the bar's own spot
-- and the Width row are not used then (the row is grey and says so, ns.XpBarAtBlockWidth), and its box in /flatui move says it follows the bar
-- block. Off, with the Bar block page off (as it is by default) or with block 1 empty, the bar has its own spot and width again, and the Width
-- row is live. Only Flat UI's own frames are placed and sized, so this goes on in a fight too.
-- The experience fill takes Rested colour while the player is rested (GetRestState 1), as the game's bar turns blue, only with Rested experience
-- on; with it off the fill is Experience colour.
-- The empty part of a bar is its background (Bar background), in the general Background colour at the general Background opacity, inside its
-- thin border while Bar border is on: the border is the bar's own row, so it is drawn with the Flat UI page's Borderless on too (ns.KeepOutline),
-- and a bar at low experience still reads as a bar from end to end.
-- With Clicks on the bar (on by default) a Shift-click on a bar puts its progress in the chat box ("Level 34: 12,345 / 27,000 (45%), 1h 20m to
-- level", "Stormwind: Honored 4,200 / 12,000 (35%)", ns.PutInChat), and a plain click on the reputation bar opens the Reputation tab of the
-- Character window (ToggleCharacter("ReputationFrame"), the call of the game's own key), in a fight as it ends: chat says once "Flat UI: your
-- reputations open when the fight ends." (ns.OpenAfterFight, MapText.lua). A Ctrl-click on either bar counts the levelling and reputation
-- numbers of this session from now, as /flatui xp reset does (ns.XpStatsReset, XpStats.lua): "Flat UI: the experience and reputation count
-- starts again now.". The tooltip ends with dim hints, "after the fight" in one, and "Ctrl-click: count this session from now"; none on a sample.
-- A click counts only when it is let go over the bar with the button it was pressed with, as in the options window, so a press slid off does
-- nothing. While it takes clicks or shows a tooltip, a bar under the mouse has a faint light over it (bar.lit), as a data panel's slot has.
-- The tooltip says what is left, "To level: 14,850 (55%)" on the experience bar and "4,200 / 12,000 (35%)" with "To Revered: 7,800" on the
-- reputation bar ("To the next standing" for a friendship, renown or paragon faction), as the data panels do; none at the top level or standing.
-- The tooltip's rested line is in Rested colour with the share of the level it covers ("Rested: 8,000 (30% of the level)"), and with Rested share
-- in the text (hud.xpTextRested, on by default) Percent and Value and percent end with that share, "  +30%", in Rested colour while you are rested.
-- Large numbers are grouped as the game writes them (BreakUpLargeNumbers: 12,150 / 27,000) in the bar text of Value and percent and Amount to
-- go, in the tooltip and in the chat line; As the game has it writes the game's words, with grouped numbers, on this bar (the game's own bar,
-- which Hud.lua styles, keeps the game's text).
-- With Animate gains (hud.xpSmooth, on by default) a fill that grows slides to its new value over EASE_FILL seconds, easing out, and the stretch
-- just gained lights up on the bar (a white texture of Flat UI's own, added over the fill) and fades over EASE_GLOW seconds; a new level,
-- another faction, another standing, a loss, a sample or a hidden bar sets the fill at once. A new level also lights the whole bar in soft gold,
-- and a new standing of the same faction in the fill of that standing, fading over EASE_FLASH seconds as the fill drops to its new value (F.Rose,
-- F.Flash); the first drawing after login or after the bar showed again, a sample and a bar off the screen never flash. One frame of Flat UI's
-- own per bar runs the ease, shown only while it runs, so this goes on in a fight too. A quest that becomes ready to hand in lights the part it
-- adds to the stretch of the quests ready to hand in, in Quest colour, fading over EASE_GLOW seconds (F.QuestGlow); not on the first drawing,
-- a new level or a sample.
-- With Gains over the bar (hud.xpGainText, on by default) each gain rises as "+1,240" from the end of the fill, FLOAT_RISE px over FLOAT_TIME
-- seconds as it fades, white for experience and in the fill's colour on the reputation bar (F.Float); a quick second gain starts it again with the
-- new amount. A reputation loss rises as "-250" in red. A new level rises as "Level 35" in gold over the middle of the experience bar, and a new
-- standing of the same faction as "Honored" in its colour, FLOAT_WORD times as slowly, with Animate gains off too (F.Change). A reputation change
-- is measured on the faction's own scale (rep.at), so a loss that drops a standing reads as the loss. Only a change on the same level or faction
-- counts, so the first drawing, a bar that shows again, another faction, a sample and a bar off the screen show none. Its frame is Flat UI's own
-- too, so it shows in a fight. It is drawn in the HIGH strata, over the action buttons and the other bar, and just over the bar text while that
-- shows Above the bar.
-- While test mode's Moving is on, every SAMPLE_EVERY seconds each shown bar plays a sample gain, "+1,240" or "+75" with the glow of Animate
-- gains, and every third time the experience bar plays "Level 35" with the gold flash (F.SampleGain); the numbers drawn and the session's count
-- are not touched. A gain, its glow, a flash or the glow of a quest ready holds the bar at full on the Fading page's Experience bar row while it
-- runs (ns.XpBarLively).
-- In test mode (TestMode.lua, entry "xpbar") a bar that Bars shown asks for and that has nothing to show, as at the top level or with no faction
-- watched, shows a sample (experience at 45% with rested and quest stretches, Stormwind at Honored), drawn with every row; samples are kept apart
-- from what the game gave (F.Data), are never put in chat, and give XpStats.lua nothing to count (ns.XpRepNow).

local KEY, MOVER = "hud", "FlatUIXpBar"
-- The width of the game's full bar on Camelot, which 100% of the width row is (Camelot/StatusTrackingBarConstants.lua:1-14).
local FULL = 1192
local FILE = "Interface\\Buttons\\WHITE8X8"
-- The opacity of the stretch of the quests ready to hand in; the rested stretch has 0.4.
local QUEST_ALPHA = 0.6
-- Animate gains: the seconds the fill slides, the seconds the stretch gained glows, its opacity at the start, and the least share of the bar
-- that counts as a gain.
local EASE_FILL, EASE_GLOW, GLOW_ALPHA, EASE_LEAST = 0.4, 0.8, 0.5, 0.0005
-- The flash of a new level or standing over the whole bar: the seconds it fades over, its opacity at the start, and the gold of a new level.
local EASE_FLASH, FLASH_ALPHA, FLASH_GOLD = 1.0, 0.6, { 1, 0.82, 0 }
-- Gains over the bar: the seconds the "+1,240" rises and fades over, how far it rises, and how close to an end of the bar it may stand. A word
-- ("Level 35", "Honored") lasts FLOAT_WORD times as long, and a reputation loss is in LOSS red.
local FLOAT_TIME, FLOAT_RISE, FLOAT_EDGE, FLOAT_WORD, LOSS = 1.2, 10, 16, 1.5, { 1, 0.3, 0.3 }
-- The faint light over a bar under the mouse while it takes clicks or shows a tooltip, as the data panels' slots have (DataPanels.lua).
local HOVER_LIGHT = 0.07
-- Test mode's sample gain: how often it plays, in seconds, and the share of the bar its glow lights.
local SAMPLE_EVERY, SAMPLE_STRETCH = 4, 0.04
-- The chat line of a click on the reputation bar in a fight.
local LATER_REP = "Flat UI: your reputations open when the fight ends."
local MANAGER = "StatusTrackingBarManager"
local CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
-- The reputation fills by standing, as Hud.lua colours the game's pictures (ReputationBar.lua:1-12), and the blue of a renown or paragon bar.
local RED, ORANGE, YELLOW, GREEN, BLUE = { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 }, { 0, 0.6, 0.1 }, { 0, 0.39, 0.88 }
local REACTION = { RED, RED, ORANGE, YELLOW, GREEN, GREEN, GREEN, GREEN }
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN",
	"DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_EXPANSION_LEVEL", "UNIT_LEVEL", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
	"CVAR_UPDATE", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }
local OF_PLAYER = { PLAYER_XP_UPDATE = true, UNIT_LEVEL = true }
-- The dim colour of the tooltip's hints and notes.
local DIM = "|cffa9ae9f"
-- The sample bars of test mode, shown in place of a bar that has nothing to show: experience at 45% with rested experience, the share of the
-- quests ready to hand in, reputation at Honored, and the levelling and reputation text each mode of their rows gives.
local SAMPLE_XP = { value = 12150, total = 27000, rested = 8000, state = 1 }
local SAMPLE_REP = { name = "Stormwind", standing = "Honored", reaction = 6, value = 4200, total = 12000 }
local SAMPLE_QUEST = 2700
local SAMPLE_STATS = { time = "1h 20m to level", rate = "9,800 an hour", both = "1h 20m to level, 9,800 an hour", kills = "42 kills to level" }
local SAMPLE_REP_STATS = { time = "3h 10m to next standing", rate = "2,500 an hour", both = "3h 10m to next standing, 2,500 an hour" }

-- mode: what is applied to the game's bars ("flat" parked, "game" given back, nil before the first look). frame: the bar's frame. bars: the two
-- bars by id. xp, rep: the last values read, kept while the game withholds them. mouse: the game's frames whose mouse is off here. waiting: a switch
-- that waits for the end of a fight. block: the spot the action bar block gave, if any ({ point, x, y, width }: the width only under the block).
-- put: how often the game put an alpha or a mouse back.
local S = { bars = {}, mouse = setmetatable({}, { __mode = "k" }), put = 0, queued = 0 }
local F = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Frame(name)
	local frame = _G[name]
	if frame == nil or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

-- The answer of a call that may be missing, raise or be withheld: "ok", "secret" or "none", then the values.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return "none"
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		return "none"
	elseif ns.IsSecret(a) or ns.IsSecret(b) or ns.IsSecret(c) then
		return "secret"
	end
	return "ok", a, b, c
end

-- True while the own bar is chosen and the page is on.
function ns.XpOwn()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, "xpbar") and ns.Get(KEY .. ".xpOwn") == "flat"
end

-- True while the own bar goes under block 1 of the Bar block page at its width (Experience bar under the bar block): BarBlock.lua then keeps
-- its room under the bars and gives it its spot and width (ns.XpBarBlock).
function ns.XpUnder()
	return ns.XpOwn() and Opt("xpUnder") == true
end

-- True while block 1 of the Bar block page holds the bar under its bars at its width (ns.XpBarBlock): the bar has the block's width, and the
-- Width row (Config.lua, overIf) is grey and says so. Else, with that row or page off or block 1 empty, the bar has its own Width.
function ns.XpBarAtBlockWidth()
	local block = S.block
	return block ~= nil and ns.Finite(block.width) and block.width > 0
end

-- The width of the bar: the block's under the bar block, else the Width row's share of the game's full bar.
function F.Width()
	if ns.XpBarAtBlockWidth() then
		return S.block.width
	end
	return FULL * Opt("xpWidth") / 100
end

-- Text -----------------------------------------------------------------------------------------------------------------------------------------

-- A whole number as the game writes large ones (BreakUpLargeNumbers), or plain.
local function Grouped(value)
	value = math.floor(value + 0.5)
	local ok, text = pcall(_G.BreakUpLargeNumbers, value)
	if ok and type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
		return text
	end
	return tostring(value)
end

-- The colour code of Rested colour, for the rested share in the tooltip and the bar text.
local function RestedCode()
	local r, g, b = ns.Colour(KEY .. ".xpRestedColour")
	local function Byte(value)
		return math.max(0, math.min(255, math.floor((ns.Finite(value) and value or 1) * 255 + 0.5)))
	end
	return ("|cff%02x%02x%02x"):format(Byte(r), Byte(g), Byte(b))
end

-- The share of the level the rested experience covers, in whole percent, or 0.
local function RestedShare(xp)
	if not (xp and ns.Finite(xp.rested) and ns.Finite(xp.total) and xp.total > 0 and xp.rested > 0) then
		return 0
	end
	return math.floor(xp.rested / xp.total * 100 + 0.5)
end

-- The text a Bar text mode gives for a value and a total, with the name in front for a reputation, the numbers grouped as the game writes them
-- (12,150 / 27,000). Nothing for the game's own text.
function ns.XpText(value, total, name, mode)
	local line
	if mode == "percent" then
		line = ("%d%%"):format(math.floor(value * 100 / total))
	elseif mode == "both" then
		line = ("%s / %s (%d%%)"):format(Grouped(value), Grouped(total), math.floor(value * 100 / total))
	elseif mode == "togo" then
		line = Grouped(math.max(total - value, 0)) .. " to go"
	else
		return nil
	end
	return name and (name .. " " .. line) or line
end

-- The value, the total and the name of what a bar of the game shows, from the numbers the game keeps on the bar (ExpBar.lua:29,
-- ReputationBar.lua:162-163), or nothing for a bar that shows no numbers: a withheld one, or a reputation at its top rank, which shows a name only.
function ns.XpNumbers(bar)
	local value, total, name = bar.currXP, bar.maxBar, nil
	if not ns.IsSecret(value) and value == nil then
		value, total = bar.value, bar.max
		local text = bar.name
		if ns.IsSecret(text) or type(text) ~= "string" or not text:find("%d", 1, true) then
			return nil
		end
		name = text:gsub(" %%d / %%d$", "")
	end
	if not ns.Finite(value) or not ns.Finite(total) or total <= 0 then
		return nil
	end
	return math.floor(value), math.floor(total), name
end

-- The text the setting Bar text gives a bar of the game, or nothing for the game's own text.
function ns.XpLine(bar, mode)
	local value, total, name = ns.XpNumbers(bar)
	if not value then
		return nil
	end
	return ns.XpText(value, total, name, mode)
end

-- Reads -----------------------------------------------------------------------------------------------------------------------------------------

-- Experience, rest and rest state, kept in S.xp. A withheld value leaves the last ones and asks for a read at the end of the fight.
function F.ReadXp()
	local okA, value = Ask(_G.UnitXP, "player")
	local okB, total = Ask(_G.UnitXPMax, "player")
	local okC, rested = Ask(_G.GetXPExhaustion)
	local okD, state = Ask(_G.GetRestState)
	if okA == "secret" or okB == "secret" or okC == "secret" or okD == "secret" then
		S.reread = true
		return S.xp
	end
	if okA ~= "ok" or okB ~= "ok" or not ns.Finite(value) or not ns.Finite(total) then
		return S.xp
	end
	if not ns.Finite(state) then
		state = nil
	end
	S.xp = { value = value, total = total, rested = ns.Finite(rested) and rested or 0, state = state }
	return S.xp
end

-- True while the game would show an experience bar (GameRulesUtil.lua:134-140).
function F.XpShown()
	local rules = _G.GameRulesUtil
	if type(rules) == "table" then
		local ok, shown = Ask(rules.CanShowExperienceBar)
		if ok == "ok" then
			return shown == true
		end
	end
	local _, off = Ask(_G.IsXPUserDisabled)
	return off ~= true and S.xp ~= nil and S.xp.total > 0
end

-- The watched faction as a bar: name, value, total, the colour index, blue for renown and paragon, the standing and whether it is at the top. The
-- game's order, each step only when its call exists (ReputationBar.lua:51-130). Nothing when no faction is watched; the last one while withheld.
-- With Errands' Show the reputation you gain on, the faction you last gained reputation with comes first (ErrandsLevelling.lua gives it in the shape
-- of the game's FactionData); the faction the game watches is not changed.
function F.ReadRep()
	local R = _G.C_Reputation
	local followed = ns.ErrandsRepFollowed ~= nil and ns.ErrandsRepFollowed() or nil
	local ok, data
	if type(followed) == "table" then
		ok, data = "ok", followed
	else
		followed = nil
		ok, data = Ask(type(R) == "table" and R.GetWatchedFactionData or nil)
	end
	if ok == "secret" then
		S.reread = true
		return S.rep
	elseif ok ~= "ok" then
		return nil
	end
	if type(data) ~= "table" or ns.IsSecret(data) or type(data.name) ~= "string" or data.name == "" or not ns.Finite(data.factionID) or data.factionID == 0 then
		S.rep = nil
		return nil
	end
	local id = data.factionID
	local rep = { name = data.name, reaction = ns.Finite(data.reaction) and data.reaction or 5, followed = followed ~= nil and data.isWatched ~= true }
	local low, high, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
	local level, top = rep.reaction, 8
	-- The standing on the faction's own scale, which only grows as reputation is gained: the faction's reputation, a paragon faction's whole
	-- paragon value (the bar shows it modulo the threshold), a friendship's standing. XpStats.lua takes the pace from it (rep.at).
	local at
	local function Call(table, name, ...)
		local state, a, b, c, d = Ask(type(table) == "table" and table[name] or nil, ...)
		if state == "secret" then
			S.reread = true
		end
		return a, b, c, d
	end
	local paragon = Call(R, "IsFactionParagonForCurrentPlayer", id) == true
	local major = Call(R, "IsMajorFaction", id) == true
	local friend = Call(_G.C_GossipInfo, "GetFriendshipReputation", id)
	if paragon then
		local current, threshold = Call(R, "GetFactionParagonInfo", id)
		low, high = 0, threshold
		if ns.Finite(current) and ns.Finite(threshold) and threshold > 0 then
			value, at = current % threshold, current
		end
		level, top = nil, nil
		rep.blue = major
		rep.standing = "Paragon"
	elseif major then
		local info = Call(_G.C_MajorFactions, "GetMajorFactionData", id)
		if type(info) == "table" and ns.Finite(info.renownLevelThreshold) then
			low, high = 0, info.renownLevelThreshold
			level = info.renownLevel
			rep.standing = ("Renown %s"):format(tostring(info.renownLevel or ""))
		end
		local levels = Call(_G.C_MajorFactions, "GetRenownLevels", id)
		top = type(levels) == "table" and #levels > 0 and type(levels[#levels]) == "table" and levels[#levels].level or nil
		rep.blue, rep.renown = true, true
	elseif type(friend) == "table" and ns.Finite(friend.friendshipFactionID) and friend.friendshipFactionID > 0 then
		local ranks = Call(_G.C_GossipInfo, "GetFriendshipReputationRanks", id)
		level = type(ranks) == "table" and ranks.currentLevel or nil
		top = type(ranks) == "table" and ranks.maxLevel or nil
		if ns.Finite(friend.nextThreshold) then
			low, high, value = friend.reactionThreshold, friend.nextThreshold, friend.standing
		else
			low, high, value = 0, 1, 1
		end
		at = friend.standing
		rep.reaction, rep.friend = 5, true
		rep.standing = type(friend.reaction) == "string" and friend.reaction or nil
	end
	if not (ns.Finite(low) and ns.Finite(high) and ns.Finite(value)) then
		S.rep = nil
		return nil
	end
	rep.total, rep.value = high - low, value - low
	rep.id, rep.at = id, ns.Finite(at) and at or value
	rep.capped = level ~= nil and top ~= nil and level >= top
	if rep.capped and rep.total == 0 then
		rep.total, rep.value = 1, 1
	end
	if not rep.standing then
		local label = _G["FACTION_STANDING_LABEL" .. tostring(rep.reaction)]
		rep.standing = type(label) == "string" and label or nil
	end
	S.rep = rep
	return rep
end

-- The ids of the bars to show, the top bar first. While test mode is on a bar Bars shown asks for that has nothing to show shows a sample
-- (S.sampleXp, S.sampleRep, read through F.Data), kept apart from what the game gave.
function F.List()
	local show, list = Opt("xpShow"), {}
	local xp = show ~= "rep" and F.ReadXp() ~= nil and F.XpShown()
	local rep = show ~= "xp" and F.ReadRep() ~= nil
	local testing = ns.TestMode ~= nil and ns.TestMode.IsOn()
	S.sampleXp = testing and show ~= "rep" and not xp or nil
	S.sampleRep = testing and show ~= "xp" and not rep or nil
	xp, rep = xp or S.sampleXp, rep or S.sampleRep
	local first, second = "xp", "rep"
	if Opt("xpOrder") == "rep" then
		first, second = "rep", "xp"
	end
	for _, id in ipairs({ first, second }) do
		if (id == "xp" and xp) or (id == "rep" and rep) then
			list[#list + 1] = id
		end
	end
	return list
end

-- What a bar shows: the values the game gave (S.xp, S.rep), or in test mode the sample of a bar that has none, and true for a sample.
function F.Data(bar)
	if bar.id == "xp" then
		if S.sampleXp then
			return SAMPLE_XP, true
		end
		return S.xp, false
	end
	if S.sampleRep then
		return SAMPLE_REP, true
	end
	return S.rep, false
end

-- The size the own bar has with the rows and the bars now shown: width (the Width row's, which the bar has unless it is under the block),
-- height, and whether any bar shows. The action bar block places the bar from it.
function ns.XpBarSize()
	local count = #F.List()
	local height, gap = Opt("xpHeight"), Opt("xpGap")
	return FULL * Opt("xpWidth") / 100, count * height + math.max(count - 1, 0) * gap, count > 0
end

-- Parking the game's bars ---------------------------------------------------------------------------------------------------------------------

-- True when an alpha cannot be written on the manager now: it is protected and a fight is on (unseen: whether it is).
function F.Locked(manager)
	if not InCombatLockdown() then
		return false
	end
	local ok, protected = pcall(manager.IsProtected, manager)
	return not ok or ns.IsSecret(protected) or protected == true
end

-- The alpha of the manager, which multiplies the alpha of the containers and never touches theirs (StatusTrackingBar.xml:3-31).
function F.Alpha(value)
	local manager = Frame(MANAGER)
	if not manager then
		return
	end
	local ok, alpha = pcall(manager.GetAlpha, manager)
	if ok and ns.Finite(alpha) and alpha == value then
		S.alphaWait, S.zeroed = nil, value == 0
		return
	end
	if F.Locked(manager) then
		S.alphaWait = value
		S.queued = S.queued + 1
		return
	end
	S.alphaWait = nil
	local counted = S.zeroed and value == 0
	if pcall(manager.SetAlpha, manager, value) then
		S.zeroed = value == 0
		if counted then
			S.put = S.put + 1
		end
	end
end

-- The bars of the game's containers and the pips of the experience bars, which take the mouse (StatusTrackingBarTemplate.xml:3, ExpBar.xml:20-37).
function F.GameBars()
	local list = {}
	for _, name in ipairs(CONTAINERS) do
		local container = Frame(name)
		local bars = container ~= nil and container.bars or nil
		if type(bars) == "table" and not ns.IsSecret(bars) then
			for _, bar in pairs(bars) do
				if not ns.Forbidden(bar) then
					list[#list + 1] = bar
					local tick = bar.ExhaustionTick
					if tick ~= nil and not ns.Forbidden(tick) then
						list[#list + 1] = tick
					end
				end
			end
		end
	end
	return list
end

-- The mouse on the game's bars, written out of combat only.
function F.Mouse(on)
	if InCombatLockdown() then
		S.mouseWait = true
		return
	end
	S.mouseWait = nil
	for _, frame in ipairs(F.GameBars()) do
		local ok, enabled = pcall(frame.IsMouseEnabled, frame)
		if ok and not ns.IsSecret(enabled) then
			if on and S.mouse[frame] then
				if pcall(frame.EnableMouse, frame, true) then
					S.mouse[frame] = nil
				end
			elseif not on and enabled == true then
				if S.mouse[frame] then
					S.put = S.put + 1
				end
				if pcall(frame.EnableMouse, frame, false) then
					S.mouse[frame] = true
				end
			end
		end
	end
end

function F.Park()
	F.Alpha(0)
	F.Mouse(false)
	S.parked = true
end

function F.Unpark()
	if not S.parked then
		return
	end
	S.parked = false
	F.Alpha(1)
	F.Mouse(true)
	if S.frame then
		S.frame:Hide()
	end
	-- The bar comes back with its fill set at once, and without a flash or a gain over it.
	for _, bar in pairs(S.bars) do
		bar.ratio, bar.key, bar.raw, bar.rawAt, bar.rawId = nil, nil, nil, nil, nil
		bar.level, bar.repId, bar.reaction, bar.readyWas, bar.readyKey = nil, nil, nil, nil, nil
	end
end

-- The bar -----------------------------------------------------------------------------------------------------------------------------------

function F.Hover(bar, on)
	bar.hover = on
	if bar.lit then
		bar.lit:SetShown(on == true and (Opt("xpClicks") == true or Opt("xpTooltip") == true))
	end
	if on and Opt("xpTooltip") then
		F.Tip(bar)
	elseif not on and _G.GameTooltip ~= nil then
		local ok, owner = pcall(_G.GameTooltip.GetOwner, _G.GameTooltip)
		if ok and owner == bar.frame then
			_G.GameTooltip:Hide()
		end
	end
	F.Text(bar)
end

-- The line a Shift-click puts in the chat box: "Level 34: 12,345 / 27,000 (45%), 1h 20m to level", or "Stormwind: Honored 4,200 / 12,000 (35%)".
-- Nothing for a sample.
function F.ChatLine(bar)
	local data, sample = F.Data(bar)
	if not data or sample then
		return nil
	end
	local value, total = math.floor(data.value), math.floor(data.total)
	if bar.id == "xp" then
		if total <= 0 then
			return nil
		end
		local line = ("%s / %s (%d%%)"):format(Grouped(value), Grouped(total), math.floor(value * 100 / total))
		local ok, level = Ask(_G.UnitLevel, "player")
		if ok == "ok" and ns.Finite(level) then
			line = ("Level %d: %s"):format(level, line)
		end
		local eta = ns.XpStatsText ~= nil and ns.XpStatsText("time") or nil
		if type(eta) == "string" and eta ~= "" then
			line = line .. ", " .. eta
		end
		return line
	end
	local standing = type(data.standing) == "string" and data.standing or nil
	if data.capped or total <= 0 then
		return standing and ("%s: %s"):format(data.name, standing) or data.name
	end
	local line = ("%s / %s (%d%%)"):format(Grouped(value), Grouped(total), math.floor(value * 100 / total))
	return ("%s: %s%s"):format(data.name, standing and (standing .. " ") or "", line)
end

-- Clicks on the bar, with Clicks on the bar on: Ctrl counts the levelling numbers of this session from now (ns.XpStatsReset), Shift puts the
-- bar's line in the chat box (ns.PutInChat, MapText.lua), and a plain click on the reputation bar opens the Reputation tab of the Character
-- window (ToggleCharacter, as the game's key does), in a fight as it ends (ns.OpenAfterFight, MapText.lua).
function F.Click(bar, button)
	if Opt("xpClicks") ~= true or button ~= "LeftButton" or not bar.shown then
		return
	end
	local _, ctrl = Ask(_G.IsControlKeyDown)
	local _, shift = Ask(_G.IsShiftKeyDown)
	if ctrl == true then
		-- Ctrl-click: the levelling and reputation numbers count this session from now (XpStats.lua); nothing on a sample.
		local _, sample = F.Data(bar)
		if not sample and ns.XpStatsReset ~= nil then
			print(ns.XpStatsReset() and "Flat UI: the experience and reputation count starts again now."
				or "Flat UI: the experience and reputation count starts with the next login.")
		end
	elseif shift == true then
		local line = F.ChatLine(bar)
		if line and ns.PutInChat ~= nil then
			ns.PutInChat(line)
		end
	elseif bar.id == "rep" and type(_G.ToggleCharacter) == "function" and ns.OpenAfterFight ~= nil then
		ns.OpenAfterFight(function()
			_G.ToggleCharacter("ReputationFrame")
		end, LATER_REP)
	end
end

function F.NewBar(root, id)
	local bar = { id = id }
	local frame = CreateFrame("StatusBar", nil, root)
	ns.Own[frame] = true
	bar.frame = frame
	frame:SetStatusBarTexture(FILE)
	frame:SetMinMaxValues(0, 1)
	frame:SetValue(0)
	bar.rested = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	bar.rested:SetTexture(FILE)
	-- The experience of the quests ready to hand in: over the rested stretch and under the fill.
	bar.quest = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	bar.quest:SetTexture(FILE)
	bar.quest:Hide()
	bar.ticks = {}
	bar.outline = ns.Outline(frame, frame)
	-- Bar border draws the edges whatever Borderless says; off, F.Look leaves the background alone (ns.SetOutlineBare).
	ns.KeepOutline(bar.outline)
	ns.Count(KEY)
	bar.over = CreateFrame("Frame", nil, frame)
	ns.Own[bar.over] = true
	bar.over:SetAllPoints(frame)
	bar.over:SetFrameLevel(frame:GetFrameLevel() + 3)
	bar.text = bar.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	-- The faint light under the mouse (F.Hover): over the fill and the glows, under the text.
	bar.lit = bar.over:CreateTexture(nil, "ARTWORK", nil, 3)
	bar.lit:SetAllPoints(frame)
	bar.lit:SetColorTexture(1, 1, 1, HOVER_LIGHT)
	pcall(bar.lit.SetBlendMode, bar.lit, "ADD")
	bar.lit:Hide()
	frame:SetScript("OnEnter", function()
		F.Hover(bar, true)
	end)
	frame:SetScript("OnLeave", function()
		F.Hover(bar, false)
	end)
	-- A click counts only when it is let go over the bar with the button it was pressed with, as in the options window (ns.PanelKit.Clickable):
	-- the game sends the release to the frame the press began on, wherever the cursor is. A withheld answer counts as over.
	frame:SetScript("OnMouseDown", function(_, button)
		bar.pressed = button
	end)
	frame:SetScript("OnMouseUp", function(self, button)
		local wanted = bar.pressed ~= nil and bar.pressed == button
		bar.pressed = nil
		if not wanted then
			return
		end
		local ok, over = pcall(self.IsMouseOver, self)
		if not ok or ns.IsSecret(over) or over ~= false then
			F.Click(bar, button)
		end
	end)
	frame:SetScript("OnHide", function()
		bar.pressed = nil
	end)
	return bar
end

function F.Build()
	if S.frame then
		return S.frame
	end
	local root = CreateFrame("Frame", MOVER, UIParent)
	ns.Own[root] = true
	root:SetFrameStrata("LOW")
	root:SetSize(1, 1)
	S.frame = root
	S.bars.xp, S.bars.rep = F.NewBar(root, "xp"), F.NewBar(root, "rep")
	return root
end

-- The tooltip: the game's lines for experience (ExpBarOverrides.lua:20-36), then the rested amount; the faction, the standing and the numbers.
function F.Tip(bar)
	local tip = _G.GameTooltip
	if tip == nil or ns.IsSecret(tip) then
		return
	end
	local lines = F.TipLines(bar)
	if #lines == 0 then
		return
	end
	tip:SetOwner(bar.frame, "ANCHOR_TOP")
	for index, line in ipairs(lines) do
		if index == 1 then
			tip:SetText(line)
		else
			tip:AddLine(line, 1, 1, 1)
		end
	end
	tip:Show()
end

local function Fmt(text, fallback, ...)
	local ok, line = pcall(string.format, type(text) == "string" and text or fallback, ...)
	return ok and line or ""
end

-- The lines of a bar's tooltip; a sample's say it is one, and with Clicks on the bar a dim hint ends them.
function F.TipLines(bar)
	local lines = {}
	local data, sample = F.Data(bar)
	if bar.id == "xp" and data then
		local xp = data
		local percent = xp.total > 0 and math.ceil(xp.value / xp.total * 100) or 0
		lines[1] = Fmt(_G.XP_TEXT, "Experience: %s/%s (%s%%)", Grouped(xp.value), Grouped(xp.total), tostring(percent))
		-- What is left to the level, as the data panels' Experience slot writes it.
		if xp.total > 0 and xp.value < xp.total then
			local left = xp.total - xp.value
			lines[2] = ("To level: %s (%d%%)"):format(Grouped(math.floor(left)), math.floor(left / xp.total * 100 + 0.5))
		end
		local ok, id, name, factor = "none", nil, nil, nil
		if not sample then
			ok, id, name, factor = Ask(_G.GetRestState)
		end
		if ok == "ok" and id ~= nil and type(name) == "string" and ns.Finite(factor) then
			lines[#lines + 1] = Fmt(_G.EXHAUST_TOOLTIP1, "You are %s. (%d%% of normal experience)", name, factor * 100)
			local _, resting = Ask(_G.IsResting)
			if resting ~= true and (id == 4 or id == 5) and type(_G.EXHAUST_TOOLTIP2) == "string" then
				lines[#lines + 1] = _G.EXHAUST_TOOLTIP2
			end
		end
		if xp.rested > 0 then
			-- In Rested colour, with the share of the level it covers, as the data panels' Experience slot writes it.
			local share = RestedShare(xp)
			lines[#lines + 1] = RestedCode() .. "Rested: " .. Grouped(math.floor(xp.rested))
				.. (xp.total > 0 and (" (%d%% of the level)"):format(share) or "") .. "|r"
		end
		-- The quests ready to hand in and the levelling numbers (XpStats.lua).
		local more = not sample and ns.XpStatsLines ~= nil and ns.XpStatsLines(Opt("xpQuest") == true, Opt("xpStatsTip") == true) or nil
		for _, line in ipairs(type(more) == "table" and more or {}) do
			lines[#lines + 1] = line
		end
	elseif bar.id == "rep" and data then
		local rep = data
		lines[1] = rep.name
		if rep.standing then
			lines[#lines + 1] = rep.standing
		end
		if not rep.capped then
			-- With its share and what is left to the next standing, as the data panels' Reputation slot writes them. A friendship, renown or
			-- paragon faction has no standing of the game's to name.
			local share = rep.total > 0 and math.floor(rep.value / rep.total * 100) or 0
			lines[#lines + 1] = ("%s / %s (%d%%)"):format(Grouped(math.floor(rep.value)), Grouped(math.floor(rep.total)), share)
			local following = nil
			if not (rep.blue or rep.friend or rep.standing == "Paragon") then
				local label = _G["FACTION_STANDING_LABEL" .. tostring(rep.reaction + 1)]
				following = type(label) == "string" and label ~= "" and label or nil
			end
			lines[#lines + 1] = ("%s: %s"):format(following and ("To " .. following) or "To the next standing",
				Grouped(math.max(0, math.floor(rep.total - rep.value))))
		end
		-- The reputation this session, per hour and the time to the next standing, with Levelling in the tooltip (XpStats.lua).
		local more = not sample and Opt("xpStatsTip") == true and ns.XpStatsRepLines ~= nil and ns.XpStatsRepLines() or nil
		for _, line in ipairs(type(more) == "table" and more or {}) do
			lines[#lines + 1] = line
		end
		if rep.followed then
			lines[#lines + 1] = "The last faction you gained reputation with."
		end
	end
	if #lines > 0 and sample then
		lines[#lines + 1] = DIM .. "A sample while test mode is on.|r"
	elseif #lines > 0 and Opt("xpClicks") == true then
		local hint = InCombatLockdown() and "Click: your reputations, after the fight. Shift-click: put this in chat"
			or "Click: your reputations. Shift-click: put this in chat"
		lines[#lines + 1] = DIM .. (bar.id == "rep" and hint or "Shift-click: put this in chat") .. "|r"
		lines[#lines + 1] = DIM .. "Ctrl-click: count this session from now|r"
	end
	return lines
end

-- The words on a bar by the Bar text row: nothing for Hidden, the game's words for As the game has it. On the experience bar the levelling text
-- follows them after a comma, or stands alone while Bar text is Hidden (Levelling text, XpStats.lua); on the reputation bar Reputation text does
-- the same.
function F.Line(bar)
	local mode = Opt("xpText")
	local data, sample = F.Data(bar)
	if bar.id == "xp" and data then
		local xp, line = data, nil
		local value, total = math.floor(xp.value), math.floor(xp.total)
		if mode == "game" then
			line = Fmt(_G.XP_STATUS_BAR_TEXT, "%s / %s", Grouped(value), Grouped(total))
		elseif mode ~= "hide" and total > 0 then
			line = ns.XpText(value, total, nil, mode)
			-- Rested share in the text: "  +30%" in Rested colour after Percent and Value and percent while you are rested.
			local share = (mode == "percent" or mode == "both") and Opt("xpTextRested") == true and Opt("xpRested") == true and RestedShare(xp) or 0
			if line and share > 0 then
				line = ("%s  %s+%d%%|r"):format(line, RestedCode(), share)
			end
		end
		if line == "" then
			line = nil
		end
		local extra
		if sample then
			extra = SAMPLE_STATS[Opt("xpStats")]
		else
			extra = ns.XpStatsText ~= nil and ns.XpStatsText(Opt("xpStats")) or nil
		end
		if type(extra) == "string" and extra ~= "" then
			line = line and (line .. ", " .. extra) or extra
		end
		return line
	end
	if bar.id == "rep" and data then
		local rep, line = data, nil
		local value, total = math.floor(rep.value), math.floor(rep.total)
		if mode == "game" then
			line = rep.capped and rep.name or ("%s %s / %s"):format(rep.name, Grouped(value), Grouped(total))
		elseif mode ~= "hide" then
			line = rep.capped and rep.name or (total > 0 and ns.XpText(value, total, rep.name, mode) or rep.name)
		end
		local extra
		if sample then
			extra = SAMPLE_REP_STATS[Opt("xpRepStats")]
		else
			extra = ns.XpStatsRepText ~= nil and ns.XpStatsRepText(Opt("xpRepStats")) or nil
		end
		if type(extra) == "string" and extra ~= "" then
			line = line and (line .. ", " .. extra) or extra
		end
		return line
	end
	return nil
end

-- True while the text of a bar shows, by the row Bar text shows (ShouldBarTextBeDisplayed, StatusTrackingBar.lua:41-43).
function F.TextShown(bar)
	local when = Opt("xpTextWhen")
	if when == "always" or bar.hover then
		return true
	elseif when == "hover" then
		return false
	end
	local ok, value = Ask(type(_G.C_CVar) == "table" and _G.C_CVar.GetCVar or nil, "xpBarText")
	if ok == "ok" and value == "1" then
		return true
	end
	-- The manager's lock, read from its field: IsTextLocked only returns self.textLocked (StatusTrackingManager.lua:112-114), and a Lua method
	-- of a frame of the game's is never called (Core.lua).
	local manager = Frame(MANAGER)
	if manager then
		local okLock, locked = pcall(rawget, manager, "textLocked")
		return okLock and not ns.IsSecret(locked) and locked == true
	end
	return false
end

function F.Text(bar)
	local text, line = bar.text, F.Line(bar)
	if not (line and bar.shown and F.TextShown(bar)) then
		text:Hide()
		return
	end
	local size = Opt("xpTextSize")
	if bar.fontSize ~= size then
		bar.fontSize = size
		ns.TextStyle(text, { percent = size, flags = "OUTLINE" })
	end
	local place = Opt("xpTextPlace")
	if bar.place ~= place then
		bar.place = place
		text:ClearAllPoints()
		if place == "above" then
			text:SetPoint("BOTTOM", bar.frame, "TOP", 0, 2)
		elseif place == "right" then
			text:SetPoint("LEFT", bar.frame, "RIGHT", 4, 0)
		else
			text:SetPoint("CENTER", bar.frame, "CENTER", 0, 1)
		end
	end
	text:SetText(line)
	text:Show()
end

-- The dividers: thin lines at equal steps, in the border colour.
function F.Ticks(bar, width, height)
	local count = tonumber(Opt("xpTicks")) or 0
	local r, g, b = ns.Colour("general.border")
	for index = 1, math.max(count - 1, #bar.ticks) do
		local tick = bar.ticks[index]
		if index < count then
			if not tick then
				tick = bar.over:CreateTexture(nil, "ARTWORK", nil, 2)
				bar.ticks[index] = tick
			end
			tick:ClearAllPoints()
			tick:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", width * index / count - 0.5, 0)
			tick:SetSize(1, height)
			tick:SetColorTexture(r, g, b, 1)
			tick:Show()
		elseif tick then
			tick:Hide()
		end
	end
end

-- The look and size of a bar that is shown, and its fill.
function F.Look(bar, index, width, height, gap)
	local frame = bar.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOP", S.frame, "TOP", 0, -(index - 1) * (height + gap))
	frame:SetSize(width, height)
	local file = ns.BarTexture(Opt("xpTexture")) or FILE
	if bar.file ~= file then
		bar.file = file
		frame:SetStatusBarTexture(file)
	end
	-- The background stays under the fill with the border off, and the border is drawn with Borderless on (kept in F.NewBar).
	ns.SetOutline(bar.outline, true, Opt("xpBack"))
	ns.SetOutlineBare(bar.outline, not Opt("xpFrame"))
	F.Ticks(bar, width, height)
end

-- The fill of a bar. The experience fill takes Rested colour while you are rested, as the game's bar turns blue, only with Rested experience on,
-- the row that colour belongs to; with it off the fill is always Experience colour.
function F.Colour(bar)
	local colour
	local data = F.Data(bar)
	if bar.id == "xp" then
		colour = Opt("xpRested") == true and data and data.state == 1 and "xpRestedColour" or "xpColour"
		return ns.Colour(KEY .. "." .. colour)
	end
	local rep = data
	if Opt("xpRepMode") == "one" then
		return ns.Colour(KEY .. ".xpRepColour")
	end
	local rgb = rep and (rep.blue and BLUE or REACTION[rep.reaction]) or GREEN
	return rgb[1], rgb[2], rgb[3]
end

-- Animate gains -------------------------------------------------------------------------------------------------------------------------------

-- What a bar shows, for Animate gains: the level for experience, the faction and its standing for reputation, or a sample. A fill eases only
-- while this stays, so a fall to a lower standing sets the fill at once.
function F.Key(bar, data, sample)
	if sample or not data then
		return "sample"
	elseif bar.id == "xp" then
		local ok, level = Ask(_G.UnitLevel, "player")
		return "xp:" .. tostring(ok == "ok" and ns.Finite(level) and level or "?")
	end
	return "rep:" .. tostring(data.id) .. ":" .. tostring(data.standing or data.reaction)
end

-- Ends the ease of a bar where it was going: the fill at its new value, the glow away; hide also hides the frame that runs it.
function F.EaseEnd(bar, hide)
	if not bar.easing then
		return
	end
	bar.easing, bar.at, bar.flashing = false, nil, nil
	bar.frame:SetValue(bar.to or bar.ratio or 0)
	if bar.gain then
		bar.gain:Hide()
	end
	if hide and bar.anim then
		bar.anim:Hide()
	end
end

-- The glow over the stretch gained, from bar.from to bar.to of the bar's width, or over the whole bar for the flash of a new level or standing.
function F.PlaceGain(bar, width)
	local gain, left = bar.gain, bar.from * width
	bar.easeWidth = width
	gain:ClearAllPoints()
	if bar.flashing then
		gain:SetAllPoints(bar.frame)
		return
	end
	gain:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", left, 0)
	gain:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", left, 0)
	gain:SetWidth(math.max((bar.to - bar.from) * width, 1))
end

-- One frame of the ease: the fill slides out to its value over EASE_FILL seconds, and the glow fades over EASE_GLOW seconds. A flash leaves the
-- fill where it is set and fades over EASE_FLASH seconds, easing out.
function F.EaseStep(bar, elapsed)
	if not bar.easing then
		bar.anim:Hide()
		return
	end
	bar.t = bar.t + (ns.Finite(elapsed) and elapsed or 0)
	if bar.flashing then
		local fade = math.min(bar.t / EASE_FLASH, 1)
		bar.gain:SetAlpha(FLASH_ALPHA * (1 - fade) ^ 2)
		if fade >= 1 then
			F.EaseEnd(bar, true)
		end
		return
	end
	local fill, glow = math.min(bar.t / EASE_FILL, 1), math.min(bar.t / EASE_GLOW, 1)
	bar.at = bar.from + (bar.to - bar.from) * (1 - (1 - fill) ^ 2)
	bar.frame:SetValue(bar.at)
	bar.gain:SetAlpha(GLOW_ALPHA * (1 - glow))
	if fill >= 1 and glow >= 1 then
		F.EaseEnd(bar, true)
	end
end

-- The frame that runs the ease of a bar and the glow it fades, Flat UI's own, made once.
function F.Parts(bar)
	if not bar.anim then
		local anim = CreateFrame("Frame", nil, bar.frame)
		ns.Own[anim] = true
		anim:Hide()
		anim:SetScript("OnUpdate", function(_, elapsed)
			F.EaseStep(bar, elapsed)
		end)
		-- The bar hid, its own frame or the whole bar: the fill is set where it was going.
		anim:SetScript("OnHide", function()
			F.EaseEnd(bar, false)
		end)
		bar.anim = anim
		-- Over the fill and under the dividers and the text (F.NewBar).
		bar.gain = bar.over:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.gain:SetColorTexture(1, 1, 1, 1)
		pcall(bar.gain.SetBlendMode, bar.gain, "ADD")
		bar.gain:Hide()
	end
end

-- Starts the ease of a bar from the value it shows to its new one, with the glow white again after a flash.
function F.Ease(bar, from, to, width)
	F.Parts(bar)
	bar.from, bar.to, bar.t, bar.easing, bar.at, bar.flashing = from, to, 0, true, from, nil
	bar.frame:SetValue(from)
	F.PlaceGain(bar, width)
	bar.gain:SetVertexColor(1, 1, 1, 1)
	bar.gain:SetAlpha(GLOW_ALPHA)
	bar.gain:Show()
	bar.anim:Show()
end

-- The flash of a new level or standing: the fill is set at its new value at once, and the glow lights the whole bar in rgb and fades.
function F.Flash(bar, ratio, width, rgb)
	F.Parts(bar)
	bar.from, bar.to, bar.t, bar.easing, bar.at, bar.flashing = ratio, ratio, 0, true, ratio, true
	bar.frame:SetValue(ratio)
	F.PlaceGain(bar, width)
	bar.gain:SetVertexColor(rgb[1], rgb[2], rgb[3], 1)
	bar.gain:SetAlpha(FLASH_ALPHA)
	bar.gain:Show()
	bar.anim:Show()
end

-- What a new level or standing flashes in, for Animate gains: gold for a level that rose, the fill of the new standing for a standing of the same
-- faction that rose, else nothing. bar.level, bar.repId and bar.reaction keep what was drawn last, so the first drawing after login, a bar that
-- shows again, a sample and a bar that is not on the screen never flash.
function F.Rose(bar, data, sample)
	if sample or not data then
		return nil
	end
	local okSeen, seen = pcall(bar.frame.IsVisible, bar.frame)
	seen = okSeen and seen == true
	if bar.id == "xp" then
		local ok, level = Ask(_G.UnitLevel, "player")
		if ok ~= "ok" or not ns.Finite(level) then
			return nil
		end
		local was = bar.level
		bar.level = level
		return (seen and ns.Finite(was) and level > was) and FLASH_GOLD or nil
	end
	local id, reaction = data.id, data.reaction
	local wasId, was = bar.repId, bar.reaction
	bar.repId, bar.reaction = id, reaction
	if seen and wasId ~= nil and wasId == id and ns.Finite(was) and ns.Finite(reaction) and reaction > was then
		local r, g, b = F.Colour(bar)
		return { r, g, b }
	end
	return nil
end

-- The fill of a bar at ratio: with Animate gains a fill that grows on the same level or faction eases there, and a new level or standing (flash,
-- from F.Rose) flashes the bar as the fill is set; else it is set at once. A redraw of the same value lets an ease or a flash that runs go on, as
-- F.Update draws the bar on every change of its rows and numbers.
function F.Value(bar, ratio, key, sample, width, flash)
	local smooth = Opt("xpSmooth") == true and not sample
	local before = bar.key == key and bar.ratio or nil
	if smooth and flash then
		F.EaseEnd(bar, false)
		F.Flash(bar, ratio, width, flash)
	elseif smooth and bar.easing and before ~= nil and math.abs(ratio - before) < EASE_LEAST then
		bar.to = ratio
		if bar.easeWidth ~= width then
			F.PlaceGain(bar, width)
		end
	elseif smooth and before ~= nil and ratio > before + EASE_LEAST then
		F.Ease(bar, (bar.easing and not bar.flashing and bar.at) or before, ratio, width)
	else
		F.EaseEnd(bar, true)
		bar.frame:SetValue(ratio)
	end
	bar.ratio, bar.key = ratio, key
end

-- One frame of a gain over the bar: it rises FLOAT_RISE px, easing out, and fades over FLOAT_TIME seconds, then hides.
function F.FloatStep(bar, elapsed)
	bar.floatT = bar.floatT + (ns.Finite(elapsed) and elapsed or 0)
	local done = math.min(bar.floatT / (bar.floatSpan or FLOAT_TIME), 1)
	bar.float:SetPoint("BOTTOM", bar.frame, "TOPLEFT", bar.floatX, bar.floatY + FLOAT_RISE * (1 - (1 - done) ^ 2))
	bar.float:SetAlpha(1 - done * done)
	if done >= 1 then
		bar.floatAnim:Hide()
	end
end

-- Gains over the bar (hud.xpGainText): "+1,240" rises from the end of the fill at ratio of the bar's width, white for experience and in the
-- fill's colour for reputation, in the bar text's size. A font string of Flat UI's own on a frame of Flat UI's own over the bar in the HIGH
-- strata (bar.floatHost), so it reads over the action buttons the bar sits under and over the other bar; it is a child of the bar, so Fading's
-- alpha on FlatUIXpBar still reaches it. It starts 2 px over the bar, or just over the bar text while that shows Above the bar (bar.floatY).
-- One frame of Flat UI's own per bar runs it, shown only while it runs; a second gain starts it again with the new amount. Nothing on a bar
-- that is not on the screen. word, when given, is written in place of the amount ("Level 35", "Honored", "-250") and lasts FLOAT_WORD times as
-- long; rgb, when given, is its colour.
function F.Float(bar, gained, ratio, width, word, rgb)
	local okSeen, seen = pcall(bar.frame.IsVisible, bar.frame)
	if not (okSeen and seen == true) then
		return
	end
	if not bar.float then
		local host = bar.floatHost
		if not host then
			host = CreateFrame("Frame", nil, bar.frame)
			ns.Own[host] = true
			host:SetAllPoints(bar.frame)
			host:SetFrameStrata("HIGH")
			bar.floatHost = host
		end
		bar.float = ns.OwnText(host, "OVERLAY", "GameFontHighlightSmall")
		if not bar.float then
			return
		end
		bar.float:Hide()
		local anim = CreateFrame("Frame", nil, bar.frame)
		ns.Own[anim] = true
		anim:Hide()
		anim:SetScript("OnUpdate", function(_, elapsed)
			F.FloatStep(bar, elapsed)
		end)
		-- The bar hid, or the gain ran out: the text goes with it.
		anim:SetScript("OnHide", function()
			bar.float:Hide()
		end)
		bar.floatAnim = anim
	end
	local text, size = bar.float, Opt("xpTextSize")
	if bar.floatSize ~= size then
		bar.floatSize = size
		ns.TextStyle(text, { percent = size, flags = "OUTLINE" })
	end
	if rgb then
		text:SetTextColor(rgb[1], rgb[2], rgb[3], 1)
	elseif bar.id == "xp" then
		text:SetTextColor(1, 1, 1, 1)
	else
		local r, g, b = F.Colour(bar)
		text:SetTextColor(r, g, b, 1)
	end
	text:SetText(word or ("+" .. Grouped(gained)))
	bar.floatSpan = (word and FLOAT_TIME * FLOAT_WORD) or FLOAT_TIME
	bar.floatX = math.max(math.min(ratio * width, width - FLOAT_EDGE), math.min(FLOAT_EDGE, width / 2))
	bar.floatY = 2
	if Opt("xpTextPlace") == "above" and bar.text:IsShown() then
		local okHeight, tall = pcall(bar.text.GetStringHeight, bar.text)
		bar.floatY = 2 + ((okHeight and ns.Finite(tall) and tall > 0) and tall or 10) + 1
	end
	bar.floatT = 0
	text:ClearAllPoints()
	text:SetPoint("BOTTOM", bar.frame, "TOPLEFT", bar.floatX, bar.floatY)
	text:SetAlpha(1)
	text:Show()
	bar.floatAnim:Show()
end

-- True while a frame that runs a part of Animate gains or Gains over the bar is shown.
function F.Running(anim)
	if not anim then
		return false
	end
	local ok, shown = pcall(anim.IsShown, anim)
	return ok and shown == true
end

-- True while a gain rises over a shown bar, its fill slides up, a level or standing flashes on it or the stretch of the quests ready to hand in
-- glows: the Experience bar row of Fading holds the bar at full meanwhile (Fade.lua, busy), then waits Wait before fading.
function ns.XpBarLively()
	if not ns.XpOwn() then
		return false
	end
	for _, bar in pairs(S.bars) do
		if bar.shown then
			if bar.easing then
				return true
			end
			if F.Running(bar.floatAnim) or F.Running(bar.questAnim) then
				return true
			end
		end
	end
	return false
end

-- Test mode, every SAMPLE_EVERY seconds while its Moving is on: each shown bar plays a sample gain, "+1,240" over the experience bar and "+75"
-- in the standing's colour over the reputation bar (with Gains over the bar), and the glow of Animate gains over the last stretch of the fill
-- (with Animate gains). Every third round the experience bar plays a new level in its place: "Level 35" (the next level) in gold over its
-- middle and the gold flash. Nothing is counted: the ease ends where the fill is, and bar.ratio, bar.key and bar.raw stay as drawn, so the next
-- real gain counts from what the game gave.
function F.SampleGain()
	if not ns.XpOwn() then
		return
	end
	local float, smooth, width = Opt("xpGainText") == true, Opt("xpSmooth") == true, F.Width()
	S.sampleRound = (S.sampleRound or 0) % 3 + 1
	for _, bar in pairs(S.bars) do
		if bar.shown then
			local ratio = ns.Finite(bar.ratio) and bar.ratio or 0
			local _, level = Ask(_G.UnitLevel, "player")
			local rise = bar.id == "xp" and S.sampleRound == 3 and ns.Finite(level)
			if float and rise then
				F.Float(bar, 0, 0.5, width, ("Level %d"):format(level + 1), FLASH_GOLD)
			elseif float then
				F.Float(bar, bar.id == "xp" and 1240 or 75, ratio, width)
			end
			if smooth and rise and not bar.easing then
				F.Flash(bar, ratio, width, FLASH_GOLD)
			elseif smooth and ratio > 0 and not bar.easing then
				F.Ease(bar, math.max(0, ratio - SAMPLE_STRETCH), ratio, width)
			end
		end
	end
end

-- What rises over a bar for a change the game gave, with Gains over the bar on: the new level ("Level 35", in gold over the middle of the
-- experience bar) or standing ("Honored", in its colour) that flash names, else a gain as "+1,240" and, on the reputation bar, a loss as "-250"
-- in red, both from the end of the fill. A reputation change is measured on the faction's own scale (rep.at, kept as bar.rawAt with bar.rawId),
-- so a loss across a standing reads as the loss it is; a renown level, whose scale starts again at each level, counts only within one.
function F.Change(bar, data, sameKey, ratio, width, flash)
	local delta
	if bar.id == "xp" then
		delta = (sameKey and ns.Finite(bar.raw)) and math.max(data.value - bar.raw, 0) or 0
		bar.raw = data.value
	else
		local same = bar.rawId == data.id and ns.Finite(bar.rawAt) and ns.Finite(data.at) and (sameKey or not data.renown)
		delta = same and data.at - bar.rawAt or 0
		bar.raw, bar.rawAt, bar.rawId = data.value, ns.Finite(data.at) and data.at or nil, data.id
	end
	if Opt("xpGainText") ~= true then
		return
	elseif flash and bar.id == "xp" and ns.Finite(bar.level) then
		F.Float(bar, 0, 0.5, width, ("Level %d"):format(bar.level), FLASH_GOLD)
	elseif flash and type(data.standing) == "string" and data.standing ~= "" then
		F.Float(bar, 0, ratio, width, data.standing, flash)
	elseif delta >= 1 then
		F.Float(bar, math.floor(delta), ratio, width)
	elseif delta <= -1 then
		F.Float(bar, 0, ratio, width, "-" .. Grouped(math.floor(-delta)), LOSS)
	end
end

-- The glow over the stretch of the quests ready to hand in that has just grown, from from to to of the bar's width, in Quest colour: it fades
-- from GLOW_ALPHA over EASE_GLOW seconds on a frame of Flat UI's own (bar.questAnim), shown only while it runs and hidden with the bar.
function F.QuestGlow(bar, from, to, width)
	if not bar.questAnim then
		local glow = bar.over:CreateTexture(nil, "ARTWORK", nil, 1)
		glow:SetTexture(FILE)
		pcall(glow.SetBlendMode, glow, "ADD")
		glow:Hide()
		bar.questGlow = glow
		local anim = CreateFrame("Frame", nil, bar.frame)
		ns.Own[anim] = true
		anim:Hide()
		anim:SetScript("OnUpdate", function(self, elapsed)
			bar.questT = bar.questT + (ns.Finite(elapsed) and elapsed or 0)
			local fade = math.min(bar.questT / EASE_GLOW, 1)
			glow:SetAlpha(GLOW_ALPHA * (1 - fade))
			if fade >= 1 then
				self:Hide()
			end
		end)
		-- The bar hid: the glow goes, and so does the frame, so it holds nothing for Fading (ns.XpBarLively).
		anim:SetScript("OnHide", function(self)
			glow:Hide()
			self:Hide()
		end)
		bar.questAnim = anim
	end
	local glow, left = bar.questGlow, from * width
	local qr, qg, qb = ns.Colour(KEY .. ".xpQuestColour")
	glow:ClearAllPoints()
	glow:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", left, 0)
	glow:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", left, 0)
	glow:SetWidth(math.max((to - from) * width, 1))
	glow:SetVertexColor(qr, qg, qb, 1)
	glow:SetAlpha(GLOW_ALPHA)
	glow:Show()
	bar.questT = 0
	bar.questAnim:Show()
end

-- The value of a bar, its fill colour and the stretch of rested experience. A change on the same level or faction (bar.raw keeps the value
-- drawn last; cleared with bar.ratio and bar.key) rises over the bar with Gains over the bar on (F.Change), so the first drawing after login, a
-- bar that shows again, another faction and a sample never show one; a new level or standing shows its name.
function F.Fill(bar, width)
	local data, sample = F.Data(bar)
	local ratio = 0
	if data then
		local total = bar.id == "xp" and data.total or data.total
		ratio = total > 0 and math.max(0, math.min(data.value / total, 1)) or 0
	end
	local key = F.Key(bar, data, sample)
	local real = data ~= nil and not sample and ns.Finite(data.value)
	local flash, sameKey = F.Rose(bar, data, sample), bar.key == key
	F.Value(bar, ratio, key, sample, width, flash)
	local r, g, b = F.Colour(bar)
	bar.frame:SetStatusBarColor(r, g, b, 1)
	if real then
		F.Change(bar, data, sameKey, ratio, width, flash)
	else
		bar.raw, bar.rawAt, bar.rawId = nil, nil, nil
	end
	local stretch = bar.rested
	local xp = bar.id == "xp" and data or nil
	if bar.id == "xp" and Opt("xpRested") and xp and xp.rested > 0 and xp.total > 0 then
		local reach = math.max(0, math.min((xp.value + xp.rested) / xp.total, 1))
		local rr, rg, rb = ns.Colour(KEY .. ".xpRestedColour")
		stretch:ClearAllPoints()
		stretch:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
		stretch:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
		stretch:SetWidth(math.max(reach * width, 1))
		stretch:SetVertexColor(rr, rg, rb, 0.4)
		stretch:Show()
	else
		stretch:Hide()
	end
	-- The quests ready to hand in, from the left edge as the rested stretch, so the fill covers what is already earned.
	local quest = bar.quest
	local ready, counted = 0, false
	if bar.id == "xp" and Opt("xpQuest") == true and xp ~= nil and xp.total > 0 then
		ready = sample and SAMPLE_QUEST or ns.XpQuestReady ~= nil and ns.XpQuestReady() or 0
		counted = real and ns.Finite(ready)
	end
	if ns.Finite(ready) and ready > 0 then
		local reach = math.max(0, math.min((xp.value + ready) / xp.total, 1))
		local qr, qg, qb = ns.Colour(KEY .. ".xpQuestColour")
		quest:ClearAllPoints()
		quest:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", 0, 0)
		quest:SetPoint("BOTTOMLEFT", bar.frame, "BOTTOMLEFT", 0, 0)
		quest:SetWidth(math.max(reach * width, 1))
		quest:SetVertexColor(qr, qg, qb, QUEST_ALPHA)
		quest:Show()
	else
		quest:Hide()
	end
	-- A quest that just became ready to hand in lights the stretch it adds, with Animate gains, on the same level and on a bar on the screen;
	-- nothing on the first drawing after login (bar.readyWas nil), on a new level or on a sample.
	local was = bar.readyKey == key and bar.readyWas or nil
	bar.readyWas, bar.readyKey = counted and ready or nil, counted and key or nil
	if was and ready > was and Opt("xpSmooth") == true then
		local okSeen, seen = pcall(bar.frame.IsVisible, bar.frame)
		local from = math.min((xp.value + was) / xp.total, 1)
		local to = math.min((xp.value + ready) / xp.total, 1)
		if okSeen and seen == true and to - from > EASE_LEAST then
			F.QuestGlow(bar, from, to, width)
		end
	end
end

-- Position ---------------------------------------------------------------------------------------------------------------------------------

-- The bottom middle of the bar when the profile has no spot: centred over action bar 1, and vertically in the room the game's status bars take.
function F.DefaultSpot(height)
	local first = ns.OwnOn() and ns.OwnBarFrame(1) or Frame("MainActionBar")
	local left, bottom, width, tall = nil, nil, nil, nil
	if first then
		left, bottom, width, tall = ns.MoverRect(first)
	end
	if not left then
		return nil
	end
	local low, high
	for _, name in ipairs(CONTAINERS) do
		local container = Frame(name)
		if container and ns.MoverShown(container) then
			local l, b, _, h = ns.MoverRect(container)
			if l then
				low, high = math.min(low or b, b), math.max(high or b + h, b + h)
			end
		end
	end
	local y = low and (low + high) / 2 - height / 2 or bottom + tall + 4
	return left + width / 2, y
end

function F.Place()
	local root = S.frame
	if not root then
		return
	end
	local point, x, y = "BOTTOM", ns.MoverSpot(MOVER, "BOTTOM")
	if S.block then
		point, x, y = S.block.point, S.block.x, S.block.y
	elseif not x then
		local _, height = root:GetSize()
		x, y = F.DefaultSpot(height)
	end
	if not x then
		x, y = UIParent:GetWidth() / 2, 60
	end
	local now = S.placed
	if not (now and now.point == point and math.abs(now.x - x) < 0.01 and math.abs(now.y - y) < 0.01) then
		S.placed = { point = point, x = x, y = y }
		root:ClearAllPoints()
		root:SetPoint(point, UIParent, "BOTTOMLEFT", x, y)
	end
end

-- The look, size and values of the whole bar.
function F.Update(layout)
	local root = F.Build()
	local list = F.List()
	local width, height, gap = F.Width(), Opt("xpHeight"), Opt("xpGap")
	local shown = {}
	for index, id in ipairs(list) do
		shown[id] = index
	end
	local mouse = Opt("xpTooltip") or Opt("xpTextWhen") == "hover" or Opt("xpClicks") == true
	for id, bar in pairs(S.bars) do
		bar.shown = shown[id] ~= nil
		if bar.shown then
			F.Look(bar, shown[id], width, height, gap)
			F.Fill(bar, width)
			bar.frame:EnableMouse(mouse)
			bar.frame:Show()
		else
			-- A bar that hides stops its ease, and comes back with its fill set at once.
			F.EaseEnd(bar, true)
			bar.frame:Hide()
			bar.hover, bar.pressed = false, nil
			bar.lit:Hide()
			bar.ratio, bar.key, bar.raw, bar.rawAt, bar.rawId = nil, nil, nil, nil, nil
			bar.level, bar.repId, bar.reaction, bar.readyWas, bar.readyKey = nil, nil, nil, nil, nil
		end
		F.Text(bar)
	end
	root:SetSize(width, #list * height + math.max(#list - 1, 0) * gap)
	if #list > 0 then
		root:Show()
	else
		root:Hide()
	end
	F.Place()
	-- A tooltip shown for a bar under the cursor follows the new numbers, while it is still the bar's (F.TipOwned).
	for _, bar in pairs(S.bars) do
		if bar.hover and bar.shown and Opt("xpTooltip") and F.TipOwned(bar) then
			F.Tip(bar)
		end
	end
end

-- Whether the game's tooltip is still the bar's and the cursor still over it, as Errands.TipOwned asks (Errands.lua): only then is it written
-- again, so a redraw never takes the tooltip from another frame or brings it back after the cursor left.
function F.TipOwned(bar)
	local tip = _G.GameTooltip
	if tip == nil or ns.IsSecret(tip) then
		return false
	end
	local ok, owned = pcall(tip.IsOwned, tip, bar.frame)
	if not ok or owned ~= true then
		return false
	end
	local okShown, shown = pcall(tip.IsShown, tip)
	if okShown and shown == false then
		return false
	end
	local okOver, over = pcall(bar.frame.IsMouseOver, bar.frame)
	return not okOver or ns.IsSecret(over) or over ~= false
end

-- Looking again ---------------------------------------------------------------------------------------------------------------------------

-- Applies what the row Experience bar says: parks the game's bars and draws, or gives the game's bars back. A switch in a fight waits for its end.
function F.Refresh()
	local want = ns.XpOwn() and "flat" or "game"
	if S.mode ~= want then
		if S.mode == nil and want == "game" then
			S.mode = "game"
			return
		elseif S.mode ~= nil and InCombatLockdown() then
			S.waiting = true
			return
		end
		S.mode, S.waiting = want, nil
	elseif S.waiting then
		S.waiting = nil
	end
	if want == "flat" then
		F.Park()
		F.Update()
		-- The quest log is read again for a changed row (XpStats.lua).
		if ns.XpStatsRefresh ~= nil then
			ns.XpStatsRefresh()
		end
	else
		F.Unpark()
	end
end

-- The upkeep of the parking: the game may put an alpha back at once, and the mouse is put back out of combat.
function F.Upkeep()
	local manager = Frame(MANAGER)
	if manager then
		local ok, alpha = pcall(manager.GetAlpha, manager)
		if S.alphaWait ~= nil or (ok and ns.Finite(alpha) and alpha > 0) then
			F.Alpha(0)
		end
	end
	if not InCombatLockdown() then
		F.Mouse(false)
	end
end

function F.Event(event, ...)
	if event == "CVAR_UPDATE" then
		local name = ...
		if ns.IsSecret(name) or name ~= "xpBarText" then
			return
		end
	end
	if S.waiting then
		if event == "PLAYER_REGEN_ENABLED" then
			F.Refresh()
		end
		return
	end
	if S.mode == nil then
		F.Refresh()
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		S.reread = nil
	end
	if not ns.XpOwn() then
		if S.mode == "flat" then
			F.Refresh()
		elseif event == "PLAYER_REGEN_ENABLED" then
			-- What a fight kept from being given back to the game's bars.
			if S.alphaWait ~= nil then
				F.Alpha(S.alphaWait)
			end
			if S.mouseWait then
				F.Mouse(not S.parked)
			end
		end
		return
	end
	F.Upkeep()
	F.Update()
end

for _, event in ipairs(EVENTS) do
	ns.AddEvent(KEY, event, function(...)
		F.Event(event, ...)
	end, OF_PLAYER[event] and function(unit)
		return not ns.IsSecret(unit) and unit == "player"
	end or nil)
end

-- The settings changed, or the page started: Hud.lua calls this at the end of its own refresh. The bar block lays out again, for the room it
-- keeps for the bar under its bars (BarBlock.lua); its watch would see the change within half a second anyway.
function ns.XpBarRefresh()
	F.Refresh()
	if ns.BarBlockReplan ~= nil then
		ns.BarBlockReplan()
	end
end

-- The levelling numbers changed (XpStats.lua): the bar is drawn again while it is Flat UI's.
function ns.XpBarRedraw()
	if S.mode == "flat" and not S.waiting and ns.XpOwn() then
		F.Update()
	end
end

-- Interface for the other files -------------------------------------------------------------------------------------------------------------

-- True while the game would show an experience bar: below the maximum level, experience not turned off (XpStats.lua reads the log only then).
function ns.XpBarShowsXp()
	return F.XpShown()
end

-- The faction the reputation bar showed at its last drawing, for the reputation pace of XpStats.lua: its id, its standing on the faction's own
-- scale (rep.at, F.ReadRep), the reputation still to the next standing (nil at the top) and its name. While the game withholds the faction the
-- last plain read stands, so nothing is counted until the next one. Nothing while Flat UI's bar or its reputation bar is not shown.
function ns.XpRepNow()
	local rep, bar = S.rep, S.bars.rep
	if not (rep and bar and bar.shown and not S.sampleRep and S.mode == "flat" and ns.XpOwn() and ns.Finite(rep.id) and ns.Finite(rep.at)) then
		return nil
	end
	return rep.id, rep.at, not rep.capped and math.max(rep.total - rep.value, 0) or nil, rep.name
end

function ns.XpBarFrame()
	return S.frame
end

-- The frame of the bar and the frame its handle hangs from, for Movers: nothing while the bar is off or Movers are off. While the action bar
-- block places the bar its box is there all the same, grey, and says so (ns.XpBarFollows).
function ns.XpBarRow()
	local movers = ns.MoverHoldGates()
	if S.frame and S.mode == "flat" and movers then
		return { S.frame }, S.frame
	end
	return {}
end

-- What the bar follows, for its box in /flatui move (Movers.lua, follows): the bar block while a block places it, else nothing.
function ns.XpBarFollows()
	if S.block then
		return "the bar block"
	end
	return nil
end

-- The spot was set or put back with the handle.
function ns.XpBarMoved()
	S.placed = nil
	F.Place()
end

-- The action bar block gives the bar a spot, or takes it back with nothing: { point, x, y } in the units of UIParent from its bottom left (the
-- bottom left corner over the block, the top left corner under it), and under the block the width of the block. A new width draws the bar
-- again at that width, a new spot only places it. When the block takes the bar's width or gives it back, the options panel reads its rows
-- again, so Width follows (ns.XpBarAtBlockWidth).
function ns.XpBarBlock(spot)
	local was, wide = S.block, ns.XpBarAtBlockWidth()
	S.block = type(spot) == "table" and ns.Finite(spot.x) and ns.Finite(spot.y)
		and { point = spot.point or "BOTTOMLEFT", x = spot.x, y = spot.y, width = ns.Finite(spot.width) and spot.width or nil } or nil
	local now = S.block
	local moved = (was ~= nil) ~= (now ~= nil) or (was and now and (was.point ~= now.point or was.x ~= now.x or was.y ~= now.y))
	local resized = (was and was.width) ~= (now and now.width)
	if not (moved or resized) then
		return
	end
	if ns.XpBarAtBlockWidth() ~= wide and ns.RefreshPanel ~= nil then
		ns.RefreshPanel()
	end
	S.placed = nil
	if resized and S.frame and S.mode == "flat" and not S.waiting and ns.XpOwn() then
		F.Update()
	else
		F.Place()
	end
end

ns.ClickPathReporter(function()
	if S.mode == "flat" then
		return "Experience bar: Flat UI's. The game's bar is not drawn."
	end
end)
ns.ClickPathReporter(function()
	if S.put > 0 then
		return ("Experience bar: the game made its bars visible or clickable again %d %s."):format(S.put, S.put == 1 and "time" or "times")
	end
end)
ns.ClickPathReporter(function()
	if S.waiting then
		return "Experience bar: changes after the fight."
	elseif S.queued > 0 and S.alphaWait ~= nil then
		return "Experience bar: the game's bar is hidden after the fight."
	end
end)

-- Test mode: a bar that has nothing to show, as at the top level or with no faction watched, shows a sample at its spot (F.List, F.Data), drawn
-- with every row; On and Off draw the bar again. While its Moving is on, each shown bar plays a sample gain every SAMPLE_EVERY seconds (F.SampleGain).
if ns.TestMode then
	ns.TestMode.Register("xpbar", { module = KEY, label = "Experience bar", Start = ns.XpBarRedraw, Stop = ns.XpBarRedraw,
		every = SAMPLE_EVERY, Tick = function()
			F.SampleGain()
		end })
end
