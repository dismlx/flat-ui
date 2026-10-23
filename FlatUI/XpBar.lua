local _, ns = ...

-- Flat UI's own experience and reputation bar. The design is research/xp-bar/design.md.
--
-- The game's two status bars stay shown and laid out in the bottom stack and are not drawn: the alpha of their parent, StatusTrackingBarManager,
-- is 0, and the mouse is off on the bars inside (StatusTrackingBar.xml:35-57, StatusTrackingBarTemplate.xml:3). Nothing of the game's is sized, moved,
-- scaled, hidden, reparented, hooked or unregistered. The bar drawn here is a frame of this addon's on UIParent, any width and height, fed by the
-- calls the game's own bar makes from insecure code (ExpBar.lua, ReputationBar.lua). Its settings are the Experience and reputation bars rows of
-- the Bars, bags and micro menu page (module hud); this file adds its handlers to that module with ns.AddEvent.

local KEY, MOVER = "hud", "FlatUIXpBar"
-- The width of the game's full bar on Camelot, which 100% of the width row is (Camelot/StatusTrackingBarConstants.lua:1-14).
local FULL = 1192
local FILE = "Interface\\Buttons\\WHITE8X8"
local MANAGER = "StatusTrackingBarManager"
local CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
-- The reputation fills by standing, as Hud.lua colours the game's pictures (ReputationBar.lua:1-12), and the blue of a renown or paragon bar.
local RED, ORANGE, YELLOW, GREEN, BLUE = { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 }, { 0, 0.6, 0.1 }, { 0, 0.39, 0.88 }
local REACTION = { RED, RED, ORANGE, YELLOW, GREEN, GREEN, GREEN, GREEN }
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "ENABLE_XP_GAIN",
	"DISABLE_XP_GAIN", "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_EXPANSION_LEVEL", "UNIT_LEVEL", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
	"CVAR_UPDATE", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }
local OF_PLAYER = { PLAYER_XP_UPDATE = true, UNIT_LEVEL = true }

-- mode: what is applied to the game's bars ("flat" parked, "game" given back, nil before the first look). frame: the bar's frame. bars: the two
-- bars by id. xp, rep: the last values read, kept while the game withholds them. mouse: the game's frames whose mouse is off here. waiting: a switch
-- that waits for the end of a fight. block: the spot the action bar block gave, if any. put: how often the game put an alpha or a mouse back.
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

-- Text -----------------------------------------------------------------------------------------------------------------------------------------

-- The text a Bar text mode gives for a value and a total, with the name in front for a reputation. Nothing for the game's own text.
function ns.XpText(value, total, name, mode)
	local line
	if mode == "percent" then
		line = ("%d%%"):format(math.floor(value * 100 / total))
	elseif mode == "both" then
		line = ("%d / %d (%d%%)"):format(value, total, math.floor(value * 100 / total))
	elseif mode == "togo" then
		line = ("%d to go"):format(math.max(total - value, 0))
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
function F.ReadRep()
	local R = _G.C_Reputation
	local ok, data = Ask(type(R) == "table" and R.GetWatchedFactionData or nil)
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
	local rep = { name = data.name, reaction = ns.Finite(data.reaction) and data.reaction or 5 }
	local low, high, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
	local level, top = rep.reaction, 8
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
			value = current % threshold
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
		rep.blue = true
	elseif type(friend) == "table" and ns.Finite(friend.friendshipFactionID) and friend.friendshipFactionID > 0 then
		local ranks = Call(_G.C_GossipInfo, "GetFriendshipReputationRanks", id)
		level = type(ranks) == "table" and ranks.currentLevel or nil
		top = type(ranks) == "table" and ranks.maxLevel or nil
		if ns.Finite(friend.nextThreshold) then
			low, high, value = friend.reactionThreshold, friend.nextThreshold, friend.standing
		else
			low, high, value = 0, 1, 1
		end
		rep.reaction = 5
		rep.standing = type(friend.reaction) == "string" and friend.reaction or nil
	end
	if not (ns.Finite(low) and ns.Finite(high) and ns.Finite(value)) then
		S.rep = nil
		return nil
	end
	rep.total, rep.value = high - low, value - low
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

-- The ids of the bars to show, the top bar first.
function F.List()
	local show, list = Opt("xpShow"), {}
	local xp = show ~= "rep" and F.ReadXp() ~= nil and F.XpShown()
	local rep = show ~= "xp" and F.ReadRep() ~= nil
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

-- The size the own bar has with the rows and the bars now shown: width, height, and whether any bar shows. The action bar block places the bar from it.
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
end

-- The bar -----------------------------------------------------------------------------------------------------------------------------------

function F.Hover(bar, on)
	bar.hover = on
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
	bar.ticks = {}
	bar.outline = ns.Outline(frame, frame)
	ns.Count(KEY)
	bar.over = CreateFrame("Frame", nil, frame)
	ns.Own[bar.over] = true
	bar.over:SetAllPoints(frame)
	bar.over:SetFrameLevel(frame:GetFrameLevel() + 3)
	bar.text = bar.over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame:SetScript("OnEnter", function()
		F.Hover(bar, true)
	end)
	frame:SetScript("OnLeave", function()
		F.Hover(bar, false)
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

function F.TipLines(bar)
	local lines = {}
	if bar.id == "xp" and S.xp then
		local xp = S.xp
		local percent = xp.total > 0 and math.ceil(xp.value / xp.total * 100) or 0
		lines[1] = Fmt(_G.XP_TEXT, "Experience: %s/%s (%s%%)", tostring(xp.value), tostring(xp.total), tostring(percent))
		local ok, id, name, factor = Ask(_G.GetRestState)
		if ok == "ok" and id ~= nil and type(name) == "string" and ns.Finite(factor) then
			lines[#lines + 1] = Fmt(_G.EXHAUST_TOOLTIP1, "You are %s. (%d%% of normal experience)", name, factor * 100)
			local _, resting = Ask(_G.IsResting)
			if resting ~= true and (id == 4 or id == 5) and type(_G.EXHAUST_TOOLTIP2) == "string" then
				lines[#lines + 1] = _G.EXHAUST_TOOLTIP2
			end
		end
		if xp.rested > 0 then
			lines[#lines + 1] = ("Rested: %d"):format(math.floor(xp.rested))
		end
	elseif bar.id == "rep" and S.rep then
		local rep = S.rep
		lines[1] = rep.name
		if rep.standing then
			lines[#lines + 1] = rep.standing
		end
		if not rep.capped then
			lines[#lines + 1] = ("%d / %d"):format(math.floor(rep.value), math.floor(rep.total))
		end
	end
	return lines
end

-- The words on a bar by the Bar text row: nothing for Hidden, the game's words for As the game has it.
function F.Line(bar)
	local mode = Opt("xpText")
	if mode == "hide" then
		return nil
	end
	if bar.id == "xp" and S.xp then
		local xp = S.xp
		local value, total = math.floor(xp.value), math.floor(xp.total)
		if mode == "game" then
			return Fmt(_G.XP_STATUS_BAR_TEXT, "%s / %s", tostring(value), tostring(total))
		end
		return total > 0 and ns.XpText(value, total, nil, mode) or nil
	elseif bar.id == "rep" and S.rep then
		local rep = S.rep
		local value, total = math.floor(rep.value), math.floor(rep.total)
		if mode == "game" then
			return rep.capped and rep.name or ("%s %d / %d"):format(rep.name, value, total)
		end
		return rep.capped and rep.name or (total > 0 and ns.XpText(value, total, rep.name, mode) or rep.name)
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
	local manager = Frame(MANAGER)
	if manager and type(manager.IsTextLocked) == "function" then
		local okLock, locked = pcall(manager.IsTextLocked, manager)
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
	-- The background stays under the fill with the border off.
	ns.SetOutline(bar.outline, true, Opt("xpBack"))
	ns.SetOutlineBare(bar.outline, not Opt("xpFrame"))
	F.Ticks(bar, width, height)
end

function F.Colour(bar)
	local colour
	if bar.id == "xp" then
		colour = S.xp and S.xp.state == 1 and "xpRestedColour" or "xpColour"
		return ns.Colour(KEY .. "." .. colour)
	end
	local rep = S.rep
	if Opt("xpRepMode") == "one" then
		return ns.Colour(KEY .. ".xpRepColour")
	end
	local rgb = rep and (rep.blue and BLUE or REACTION[rep.reaction]) or GREEN
	return rgb[1], rgb[2], rgb[3]
end

-- The value of a bar, its fill colour and the stretch of rested experience.
function F.Fill(bar, width)
	local data = bar.id == "xp" and S.xp or S.rep
	local ratio = 0
	if data then
		local total = bar.id == "xp" and data.total or data.total
		ratio = total > 0 and math.max(0, math.min(data.value / total, 1)) or 0
	end
	bar.frame:SetValue(ratio)
	local r, g, b = F.Colour(bar)
	bar.frame:SetStatusBarColor(r, g, b, 1)
	local stretch = bar.rested
	local xp = S.xp
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
		point, x, y = "BOTTOMLEFT", S.block.x, S.block.y
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
	local width, height, gap = FULL * Opt("xpWidth") / 100, Opt("xpHeight"), Opt("xpGap")
	local shown = {}
	for index, id in ipairs(list) do
		shown[id] = index
	end
	local mouse = Opt("xpTooltip") or Opt("xpTextWhen") == "hover"
	for id, bar in pairs(S.bars) do
		bar.shown = shown[id] ~= nil
		if bar.shown then
			F.Look(bar, shown[id], width, height, gap)
			F.Fill(bar, width)
			bar.frame:EnableMouse(mouse)
			bar.frame:Show()
		else
			bar.frame:Hide()
			bar.hover = false
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

-- The settings changed, or the page started: Hud.lua calls this at the end of its own refresh.
function ns.XpBarRefresh()
	F.Refresh()
end

-- Interface for the other files -------------------------------------------------------------------------------------------------------------

function ns.XpBarFrame()
	return S.frame
end

-- The frame of the bar and the frame its handle hangs from, for Movers: nothing while the bar is off, held by the action bar block, or Movers are off.
function ns.XpBarRow()
	local movers = ns.MoverHoldGates()
	if S.frame and S.mode == "flat" and movers and not S.block then
		return { S.frame }, S.frame
	end
	return {}
end

-- The spot was set or put back with the handle.
function ns.XpBarMoved()
	S.placed = nil
	F.Place()
end

-- The action bar block gives the bar a spot (the bottom left corner, in the units of UIParent), or takes it back with nothing.
function ns.XpBarBlock(x, y)
	local was = S.block
	S.block = x and { x = x, y = y } or nil
	if (was ~= nil) ~= (S.block ~= nil) or (was and S.block and (was.x ~= x or was.y ~= y)) then
		S.placed = nil
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
