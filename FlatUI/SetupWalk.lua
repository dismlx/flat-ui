local _, ns = ...

-- Flat UI setup as a walk round the player's own screen: the stops of ns.SETUP_STOPS (SetupStops.lua), one screen each, then Your screen, which shows
-- every stop as it will be before Finish. Setup.lua gives this file the right column of the setup window (S.right), lists the stops with what each
-- has picked (Walk.Stops, Walk.Summary, Walk.Changed) and calls the functions of the table Walk (ns.SetupWalk), each only when it is a function.
-- The draft is read through S.Value, S.StartValue and S.view, and written only through S.Set, S.Queue and S.Unqueue and in its own fields seen,
-- name and saveNew, so nothing reaches a profile, a game setting or a list before Finish, which Setup.lua runs.
-- A stop has parts: cards (one of them, each a drawing of that part of the screen under a view of its own: the card's values over the draft, in the
-- player's name and class), chips (one of them, a small button each, shown on the cards while pointed at) and ticks (each on or off). A part owns
-- its paths and every card sets each of them, so cards never fight. The table is checked the first time it is read, as Setup.lua checks the
-- ready-made profiles (Walk.Stops). Every frame, texture and text here is Flat UI's own (ns.PanelKit, ns.Outline): no frame of the game is
-- touched, no hook is set and nothing here is protected, so it all works in a fight. Every question to the game goes through S.Ask or pcall, with
-- a withheld (secret) answer dropped and never compared. Everything is in the table Walk, so that the file keeps few locals.

local kit = ns.PanelKit
local S = ns.Setup
local Walk = { screens = {} }
ns.SetupWalk = Walk

-- The measures of the walk, in units of the options window: the margin, the gap between cards, the room a part's heading takes and the room left
-- under a part, the tallest card, and how many levels above a card the frame that takes its mouse and holds its tag sits: over the frames of its
-- drawing, and under the shade and the questions of the window (Panel.lua), 40 levels above the window.
Walk.PAD, Walk.GAP, Walk.HEAD, Walk.AFTER, Walk.TALL, Walk.OVER = 16, 12, 22, 12, 220, 30
-- The ground behind every drawing while SetupDraw.lua does not give one: the sand of the world, so that a backdrop at 85% reads as it does there.
Walk.GROUND = { 0.32, 0.27, 0.20 }
Walk.MIX = "Your own mix from More settings. Pick one to replace it."

local function IsText(value)
	return not ns.IsSecret(value) and type(value) == "string"
end

-- Labels in a sentence, each once: "A", "A and B", "A, B and C", "A, B, C and 2 more". Nil when there is none.
function Walk.Join(labels)
	local list, seen = {}, {}
	for _, label in ipairs(labels) do
		if IsText(label) and label ~= "" and not seen[label] then
			seen[label] = true
			list[#list + 1] = label
		end
	end
	local count = #list
	if count == 0 then
		return nil
	elseif count == 1 then
		return list[1]
	elseif count <= 3 then
		return table.concat(list, ", ", 1, count - 1) .. " and " .. list[count]
	end
	return ("%s, %s, %s and %d more"):format(list[1], list[2], list[3], count - 3)
end

-- The check ------------------------------------------------------------------------------------------------------------------------------------

-- Why a value cannot be in the walk, or nil when it can: the tests the ready-made profiles pass (Setup.lua, S.Presets).
function Walk.Refused(path, value)
	local def = IsText(path) and S.Defs()[path] or nil
	if not def then
		return "no such setting"
	elseif ns.RowUnsaved(def) then
		return "the game holds it"
	elseif path:find("^setup%.") or path:find("^barblock%.") or (type(S.NEVER) == "table" and S.NEVER[path]) then
		return "a profile never sets it"
	elseif type(S.where) ~= "table" or not S.where[path] then
		return "no step has it"
	elseif ns.Normalised(path, value) ~= value then
		return "not a value it takes"
	end
	return nil
end

-- The order of a part's paths: the order the steps list them in, which is the order the options show them.
function Walk.Before(a, b)
	local x, y = S.where[a], S.where[b]
	local xs, ys = x and tonumber(x.step) or 0, y and tonumber(y.step) or 0
	if xs ~= ys then
		return xs < ys
	end
	local xi, yi = x and tonumber(x.index) or 0, y and tonumber(y.index) or 0
	if xi ~= yi then
		return xi < yi
	end
	return a < b
end

-- A card of the table, checked: the values that no earlier part claimed and that pass (each is then the part's), and its action while ns has the
-- function it names. A claimed path is left out without a word: that part is meant to give way.
function Walk.CheckCard(raw, owned, claimed, say)
	local card = { id = raw.id, label = IsText(raw.label) and raw.label or tostring(raw.id), line = IsText(raw.line) and raw.line or "",
		suggest = type(raw.suggest) == "table" and raw.suggest or {}, icon = raw.icon, values = {} }
	for path, value in pairs(type(raw.values) == "table" and raw.values or {}) do
		if not claimed[path] then
			local why = Walk.Refused(path, value)
			if why then
				say(path, why)
			else
				card.values[path] = value
				owned[path] = true
			end
		end
	end
	local action = raw.action
	if type(action) == "table" and IsText(action.pick) and type(ns[action.pick]) == "function" then
		card.action = { pick = action.pick, id = action.id, text = IsText(action.text) and action.text or action.pick }
	end
	return card
end

-- A part of the table, checked (see Walk.Stops), or nil when it keeps too few cards. A part that stays claims its paths from the parts after it.
function Walk.CheckPart(raw, claimed, say)
	local kind = raw.kind
	if kind ~= "cards" and kind ~= "chips" and kind ~= "ticks" then
		return nil
	end
	local defs = S.Defs()
	local owned = {}
	for _, path in ipairs(type(raw.owns) == "table" and raw.owns or {}) do
		if not claimed[path] then
			local def = IsText(path) and defs[path] or nil
			local why = Walk.Refused(path, def and def.default)
			if why then
				say(path, why)
			else
				owned[path] = true
			end
		end
	end
	-- With styles, the cards are copies of the frame styles of Config.lua while it has any; the first is the one a new character is offered.
	local source = type(raw.cards) == "table" and raw.cards or {}
	local styles = ns.SETUP_FRAME_STYLES
	if raw.styles and type(styles) == "table" and #styles > 0 then
		source = {}
		for _, style in ipairs(styles) do
			if type(style) == "table" then
				source[#source + 1] = { id = style.id, label = style.label, line = style.line, values = style.values, suggest = #source == 0 and { "else" } or nil }
			end
		end
	end
	local cards = {}
	for _, rawCard in ipairs(source) do
		if type(rawCard) == "table" then
			cards[#cards + 1] = Walk.CheckCard(rawCard, owned, claimed, say)
		end
	end
	local list = {}
	for path in pairs(owned) do
		list[#list + 1] = path
	end
	table.sort(list, Walk.Before)
	local part = { id = raw.id, label = IsText(raw.label) and raw.label or "", note = IsText(raw.note) and raw.note or nil, kind = kind, cards = {},
		owned = owned, list = list }
	-- Each card gives every path of the part a value: its own, else the setting's default. A card that would give the same values as one before it is
	-- left out; a tick needs a value or an action.
	local seen = {}
	for _, card in ipairs(cards) do
		local expect, parts = {}, {}
		for _, path in ipairs(list) do
			local value = card.values[path]
			if value == nil then
				value = defs[path].default
			end
			expect[path] = value
			parts[#parts + 1] = path .. "=" .. tostring(value)
		end
		card.expect = expect
		local key = table.concat(parts, ";")
		if kind == "ticks" then
			if next(card.values) ~= nil or card.action then
				part.cards[#part.cards + 1] = card
			end
		elseif not seen[key] then
			seen[key] = true
			part.cards[#part.cards + 1] = card
		end
	end
	if #part.cards < (kind == "ticks" and 1 or 2) then
		return nil
	end
	for path in pairs(owned) do
		claimed[path] = true
	end
	-- As it is now: what the profile in use has on the part's paths. It is offered while no card of the part has that.
	part.nowCard = { id = "now", label = "As it is now", line = "What you have now.", now = true, suggest = {}, values = {}, expect = {} }
	return part
end

-- The stops as the walk shows them, in order: each { id, title, line, draw, spot, more, pages, parts }, a part { id, label, note, kind, cards, owned,
-- list, nowCard } (owned the set of its paths, list the same in step order) and a card { id, label, line, values, expect, suggest, icon, action }.
-- A value stays when its setting exists, a profile holds it and may set it, a step lists it and the setting takes it as it is; a path an earlier part
-- claimed is left out of a later one (Picture under the frame styles); a part stays with two cards (ticks: one) and then claims its paths; a stop
-- stays with one part. pages are the built steps of more, which More settings opens. Each value left out for another reason is said once. The
-- lists of the choice rows are complete once the modules have started: the stops are checked and kept from then; before, they are checked each time
-- they are read and nothing is said.
function Walk.Stops()
	if Walk.stops then
		return Walk.stops
	end
	local said, heard, claimed, list = {}, {}, {}, {}
	local steps = type(ns.SETUP_STEPS) == "table" and ns.SETUP_STEPS or {}
	for _, raw in ipairs(type(ns.SETUP_STOPS) == "table" and ns.SETUP_STOPS or {}) do
		if type(raw) == "table" and IsText(raw.id) then
			local title = IsText(raw.title) and raw.title or raw.id
			local function Say(path, why)
				local line = ("Flat UI: setup leaves out %s on %s: %s."):format(tostring(path), title, why)
				if not heard[line] then
					heard[line] = true
					said[#said + 1] = line
				end
			end
			local stop = { id = raw.id, title = title, line = IsText(raw.line) and raw.line or "", draw = IsText(raw.draw) and raw.draw or nil,
				spot = type(raw.spot) == "table" and raw.spot or nil, more = type(raw.more) == "table" and raw.more or {}, pages = {}, parts = {} }
			for _, rawPart in ipairs(type(raw.parts) == "table" and raw.parts or {}) do
				local part = type(rawPart) == "table" and Walk.CheckPart(rawPart, claimed, Say) or nil
				if part then
					stop.parts[#stop.parts + 1] = part
				end
			end
			if #stop.parts > 0 then
				for _, id in ipairs(stop.more) do
					for number, step in ipairs(steps) do
						if step.id == id then
							if step.built then
								stop.pages[#stop.pages + 1] = number
							end
							break
						end
					end
				end
				list[#list + 1] = stop
			end
		end
	end
	if type(ns.Started) == "function" and not ns.Started() then
		return list
	end
	Walk.stops = list
	table.sort(said)
	for _, line in ipairs(said) do
		geterrorhandler()(line)
	end
	return list
end

-- One stop by id, or nil.
function Walk.Stop(id)
	for _, stop in ipairs(Walk.Stops()) do
		if stop.id == id then
			return stop
		end
	end
	return nil
end

-- Facts about the character -------------------------------------------------------------------------------------------------------------------

-- The role of each talent tree of a class, in the game's order of its trees.
Walk.TREES = {
	WARRIOR = { "damage", "damage", "tank" }, PALADIN = { "healer", "tank", "damage" }, PRIEST = { "healer", "healer", "damage" },
	SHAMAN = { "damage", "damage", "healer" }, DRUID = { "damage", "damage", "healer" }, HUNTER = { "damage", "damage", "damage" },
	ROGUE = { "damage", "damage", "damage" }, MAGE = { "damage", "damage", "damage" }, WARLOCK = { "damage", "damage", "damage" },
}
Walk.GIVEN = { TANK = "tank", HEALER = "healer", DAMAGER = "damage" }

-- The role setup suggests for ("tank", "healer" or "damage") and the sentence that says why, from the first that answers: the role the group gave,
-- a tank stance, form or aura as nameplate threat reads it (PlateThreat.lua), the talent tree with the most points, the class.
function Walk.Role()
	local given = S.Ask(UnitGroupRolesAssigned, "player")
	if IsText(given) and Walk.GIVEN[given] then
		return Walk.GIVEN[given], "Suggested from your group role."
	end
	local threat = ns.PlateThreat
	if type(threat) == "table" and type(threat.Role) == "function" then
		local ok, kind, reason = pcall(threat.Role)
		if ok and IsText(kind) and kind == "tank" and IsText(reason) and reason ~= "your group role" then
			return "tank", reason == "your choice" and "Suggested from your role." or ("Suggested from %s."):format(reason)
		end
	end
	local class = S.Ask(UnitClassBase, "player")
	class = IsText(class) and class or nil
	local trees = class and Walk.TREES[class]
	local info = type(C_SpecializationInfo) == "table" and C_SpecializationInfo.GetSpecializationInfo or nil
	local count = S.Ask(GetNumSpecializations)
	if trees and type(info) == "function" and ns.Finite(count) then
		local best, most, name = nil, 0, nil
		for index = 1, math.min(math.floor(count), #trees) do
			-- After pcall's own answer: the tree's id, name, description, icon, role, main stat, and the points spent in it.
			local ok, _, tree, _, _, _, _, points = pcall(info, index)
			if ok and ns.Finite(points) and points > most and IsText(tree) then
				best, most, name = index, points, tree
			end
		end
		if best then
			return trees[best], ("Suggested from your talents: most points in %s."):format(name)
		end
	end
	if class then
		return class == "PRIEST" and "healer" or "damage", ("Suggested for a %s."):format(class:lower())
	end
	return "damage", nil
end

-- What the walk knows of the character, read once each time the window opens (Walk.Begin): role and why, and the role itself as a fact (tank,
-- healer or damage); small, a screen under 900 pixels tall or the Classic experience; large, text or interface made larger; levelling, under level
-- 60; notrackers, no tracker yet; and else, which is always true. Each is false when the client does not say.
function Walk.Facts()
	if Walk.facts then
		return Walk.facts
	end
	local facts = { ["else"] = true }
	local role, why = Walk.Role()
	facts.role, facts.why = role, why
	facts[role] = true
	local rules = type(C_GameRules) == "table" and C_GameRules or nil
	local classic = type(Enum) == "table" and type(Enum.ForeverExperiencePreset) == "table" and Enum.ForeverExperiencePreset.Classic or 0
	local preset = rules and S.Ask(rules.GetForeverExperiencePreset)
	local ok, _, height = false, nil, nil
	if type(GetPhysicalScreenSize) == "function" then
		ok, _, height = pcall(GetPhysicalScreenSize)
	end
	facts.small = (ns.Finite(preset) and preset == classic) or (ok and ns.Finite(height) and height > 0 and height < 900) or false
	local cvar = type(C_CVar) == "table" and C_CVar.GetCVar or nil
	local fontScale, useScale = tonumber(S.Ask(cvar, "userFontScale")), S.Ask(cvar, "useUiScale")
	local uiScale = tonumber(S.Ask(cvar, "uiScale")) or tonumber(S.Ask(cvar, "uiscale"))
	facts.large = (fontScale ~= nil and fontScale >= 1.1) or (useScale == "1" and uiScale ~= nil and uiScale >= 1) or false
	local level = S.Ask(UnitLevel, "player")
	facts.levelling = (ns.Finite(level) and level > 0 and level < 60) or false
	local picked = type(ns.TrackerPicked) == "function" and S.Ask(ns.TrackerPicked) or nil
	facts.notrackers = type(picked) == "table" and next(picked) == nil
	Walk.facts = facts
	return facts
end

-- The card a part of cards or chips suggests for this character: the first whose suggest names a fact that is true, else the first that names
-- else, else none.
function Walk.Suggested(part)
	local facts = Walk.Facts()
	local fallback
	for _, card in ipairs(part.cards) do
		for _, key in ipairs(card.suggest or {}) do
			if key == "else" then
				fallback = fallback or card
			elseif facts[key] == true then
				return card
			end
		end
	end
	return fallback
end

-- True for a tick that suits this character: its suggest names a fact that is true. Any number of ticks can be.
function Walk.TickSuggested(card)
	local facts = Walk.Facts()
	for _, key in ipairs(card.suggest or {}) do
		if facts[key] == true then
			return true
		end
	end
	return false
end

-- Values ---------------------------------------------------------------------------------------------------------------------------------------

-- The value a card gives a path of its part: its own, else the setting's default. As it is now gives what the profile in use has.
function Walk.Expected(card, path)
	if card.now then
		return S.StartValue(path)
	end
	return card.expect[path]
end

-- What the profile in use has on a path, else the setting's default, read from the profile itself: the drawing of As it is now reads it while ns.Get
-- reads the card's view.
function Walk.Start(path)
	local start = S.StartProfile()
	local value
	if type(start) == "table" and type(start.options) == "table" then
		value = start.options[path]
	end
	if value == nil then
		local def = S.Defs()[path]
		if def then
			value = def.default
		end
	end
	return value
end

-- True when every path of the part reads the card's value: in the draft, or with read = S.StartValue in the profile in use.
function Walk.Holds(part, card, read)
	read = read or S.Value
	for _, path in ipairs(part.list) do
		if read(path) ~= Walk.Expected(card, path) then
			return false
		end
	end
	return true
end

-- The card of a part the draft has: one of its cards, else As it is now while the draft leaves the part as the profile in use has it, else nil (a
-- mix made in More settings).
function Walk.Picked(part)
	for _, card in ipairs(part.cards) do
		if Walk.Holds(part, card) then
			return card
		end
	end
	if Walk.Holds(part, part.nowCard) then
		return part.nowCard
	end
	return nil
end

-- True while no card of a part of cards or chips is what the profile in use has: As it is now is offered then, first and tagged Now.
function Walk.NowShown(part)
	if part.kind == "ticks" then
		return false
	end
	for _, card in ipairs(part.cards) do
		if Walk.Holds(part, card, S.StartValue) then
			return false
		end
	end
	return true
end

-- True for a tick that is on: the draft has its values (so a module already on is ticked), or its action is queued for Finish.
function Walk.Ticked(card)
	if card.action then
		return type(S.Queued) == "function" and S.Queued(card.action.pick, card.action.id) and true or false
	end
	if next(card.values) == nil then
		return false
	end
	for path, value in pairs(card.values) do
		if S.Value(path) ~= value then
			return false
		end
	end
	return true
end

-- Gives each path of a part the card's value in the draft. As it is now gives each the profile in use's value, which takes the draft's value away.
function Walk.Apply(part, card)
	for _, path in ipairs(part.list) do
		S.Set(path, Walk.Expected(card, path))
	end
end

-- The sentence of the strip for a card pointed at: the settings it would change in the draft, or nothing when it changes none.
function Walk.ChangesLine(part, card)
	local defs = S.Defs()
	local labels = {}
	for _, path in ipairs(part.list) do
		if S.Value(path) ~= Walk.Expected(card, path) then
			local def = defs[path]
			labels[#labels + 1] = def and def.label
		end
	end
	local joined = Walk.Join(labels)
	return joined and ("Changes: %s."):format(joined) or ""
end

-- A click on a card or a chip, or an arrow key: the card is picked, and everything shown follows.
function Walk.Pick(part, card)
	if not S.draft then
		return
	end
	Walk.Apply(part, card)
	S.dirty = true
	Walk.Update()
	kit.Refresh()
	local hovered = Walk.hovered
	if hovered then
		kit.Tip(Walk.ChangesLine(hovered.part, hovered.card))
	end
end

-- A click on a tick: its values go into the draft or come out of it, or its action is queued for Finish or taken off.
function Walk.Toggle(card)
	if not S.draft then
		return
	end
	local on = Walk.Ticked(card)
	local action = card.action
	if action then
		local call = S.Queue
		if on then
			call = S.Unqueue
		end
		if type(call) == "function" then
			call(action.pick, action.id, action.text)
		end
	else
		for path, value in pairs(card.values) do
			if not on then
				S.Set(path, value)
			elseif type(value) == "boolean" then
				S.Set(path, not value)
			else
				S.Set(path, S.StartValue(path))
			end
		end
	end
	S.dirty = true
	Walk.Update()
	kit.Refresh()
end

-- The parts of a screen ------------------------------------------------------------------------------------------------------------------------

-- The ground behind a drawing: SetupDraw.lua's, else the same sand.
function Walk.Ground(frame)
	local D = ns.SetupDraw
	local colour = type(D) == "table" and type(D.GROUND) == "table" and D.GROUND or Walk.GROUND
	local ground = kit.Fill(frame, "BACKGROUND")
	ground:SetAllPoints(frame)
	ground:SetColorTexture(colour[1], colour[2], colour[3], 1)
	return ground
end

-- A context of the drawings (SetupDraw.lua, D.Context) on a box, reading `view`, or nil without the drawings.
function Walk.Context(box, view)
	local D = ns.SetupDraw
	if type(D) == "table" and type(D.Context) == "function" then
		return D.Context(box, view)
	end
	return nil
end

-- Paints drawing `id` into a box of w by h units with D.PaintIn (SetupDraw.lua), at most `most` times its size. False when it could not, so that a
-- drawing that is missing or fails is not tried again; true while SetupDraw.lua has no D.PaintIn, and the box keeps its ground.
function Walk.PaintIn(context, id, w, h, most)
	local D = ns.SetupDraw
	if not context or not IsText(id) or type(D) ~= "table" or type(D.PaintIn) ~= "function" then
		return true
	end
	local ok, painted = pcall(D.PaintIn, context, id, w, h, most)
	if not ok then
		geterrorhandler()(painted)
		return false
	end
	return painted == true
end

-- A tag (Now, Suggested) on a frame of its own, in the window colour.
function Walk.NewTag(parent)
	local frame = kit.Frame(parent)
	frame:SetHeight(16)
	local back = kit.Fill(frame, "BACKGROUND")
	back:SetAllPoints(frame)
	kit.Painted(function()
		kit.Solid(back, "window", 0.9)
	end)
	local text = kit.Label(frame, "GameFontHighlightSmall", "CENTER")
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame:Hide()
	return { frame = frame, text = text }
end

-- Shows a tag with its text, as wide as the text and 12 more, or hides it for nil.
function Walk.SetTag(tag, text)
	tag.frame:SetShown(text ~= nil)
	if text then
		tag.text:SetText(text)
		local ok, width = pcall(tag.text.GetStringWidth, tag.text)
		tag.frame:SetWidth((ok and ns.Finite(width) and width > 0 and width or 40) + 12)
	end
end

-- The view a card's drawing reads (ns.Viewing). In order: while a chip of the card's stop is pointed at, that chip's value on each path the chip's
-- part owns; the card's value on each path its own part owns (As it is now: the profile in use's); the draft, then the profile in use, on every other
-- path (S.view). A card keeps its view for life, since an outline follows the view it was made under.
function Walk.CardView(stop, part, card)
	return setmetatable({ spots = S.noSpots or {} }, { __index = function(_, path)
		local preview = Walk.preview
		if preview and preview.stop == stop.id and preview.part ~= part and preview.part.owned[path] then
			if preview.card.now then
				return Walk.Start(path)
			end
			return preview.card.expect[path]
		end
		if part.owned[path] then
			if card.now then
				return Walk.Start(path)
			end
			return card.expect[path]
		end
		return S.view[path]
	end })
end

-- The edge of a card: raised, lighter while pointed at, and in the accent while it is the card picked.
function Walk.PaintEdge(tile)
	local tone = tile.hover and "hover" or "raised"
	if tile.selected then
		kit.Backing(tile.edge, tone, 1, "accent")
	else
		kit.Backing(tile.edge, tone)
	end
end

-- A card of a cards part: its stop's drawing in a box of the ground colour, under the card's view; its name and line under the box; the tag (Now,
-- else Suggested) and the tick of the card picked over the box. Above it all is the frame that takes the mouse: pointing says in the strip what the
-- card would change, and a click picks it.
function Walk.NewCard(view, part, card)
	local frame = kit.Frame(view.frame)
	local tile = { card = card, part = part, frame = frame, edge = ns.Outline(frame, frame, true) }
	local box = kit.Frame(frame)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
	box:SetClipsChildren(true)
	Walk.Ground(box)
	tile.box = box
	tile.ctx = Walk.Context(box, Walk.CardView(view.stop, part, card))
	tile.name = kit.Label(frame, "GameFontNormal", "LEFT")
	tile.name:SetText(card.label)
	tile.line = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", nil, true))
	tile.line:SetJustifyV("TOP")
	pcall(tile.line.SetMaxLines, tile.line, 2)
	tile.line:SetText(card.line)
	local over = kit.Frame(frame)
	over:SetAllPoints(frame)
	over:SetFrameLevel(frame:GetFrameLevel() + Walk.OVER)
	tile.tag = Walk.NewTag(over)
	tile.tag.frame:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -4)
	tile.check = kit.Fill(over, "OVERLAY")
	tile.check:SetSize(14, 14)
	tile.check:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	if type(ns.PanelNav) == "table" and type(ns.PanelNav.Cell) == "function" then
		ns.PanelNav.Cell(tile.check, "check")
	end
	tile.check:Hide()
	kit.Painted(function()
		tile.check:SetVertexColor(kit.Accent())
		Walk.PaintEdge(tile)
	end)
	kit.Clickable(over, function()
		Walk.Pick(part, card)
	end)
	over:SetScript("OnEnter", function()
		tile.hover = true
		Walk.hovered = tile
		Walk.PaintEdge(tile)
		kit.Tip(Walk.ChangesLine(part, card))
	end)
	over:SetScript("OnLeave", function()
		tile.hover = false
		if Walk.hovered == tile then
			Walk.hovered = nil
		end
		Walk.PaintEdge(tile)
		kit.Tip("")
	end)
	return tile
end

-- Puts a card at x, y of its screen, w by h units: the box over all but the last 50 units, which hold the name and two lines of text.
function Walk.PlaceCard(tile, parent, x, y, w, h)
	local frame = tile.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	frame:SetSize(w, h)
	tile.box:SetSize(w - 8, h - 54)
	tile.name:SetWidth(w - 20)
	tile.name:ClearAllPoints()
	tile.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(h - 46))
	tile.line:SetWidth(w - 20)
	tile.line:ClearAllPoints()
	tile.line:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(h - 28))
	tile.w, tile.h = w, h
	frame:Show()
end

-- A chip: raised, in the accent with the text on it while it is the one picked.
function Walk.PaintChip(chip)
	local tone
	if chip.selected then
		tone = chip.hover and "accent-hover" or "accent"
	else
		tone = chip.hover and "hover" or "raised"
	end
	kit.Backing(chip.edge, tone, 1, "line-strong")
	kit.Tint(chip.text, chip.selected and "on-accent" or "text")
end

-- A chip of a chips part: a small button with its label. While it is pointed at, every card of its stop shows it.
function Walk.NewChip(view, part, card)
	local frame = kit.Frame(view.frame)
	frame:SetHeight(26)
	local chip = { card = card, part = part, frame = frame, edge = ns.Outline(frame, frame, true) }
	chip.text = kit.Label(frame, "GameFontHighlight", "CENTER")
	chip.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	chip.text:SetText(card.label)
	kit.Painted(function()
		Walk.PaintChip(chip)
	end)
	kit.Clickable(frame, function()
		Walk.Pick(part, card)
	end)
	frame:SetScript("OnEnter", function()
		chip.hover = true
		Walk.PaintChip(chip)
		Walk.Preview(view.stop, part, card)
	end)
	frame:SetScript("OnLeave", function()
		chip.hover = false
		Walk.PaintChip(chip)
		Walk.Preview(nil)
	end)
	return chip
end

-- The width of a chip: its text and 28 more, at least 90.
function Walk.ChipWidth(chip)
	local ok, width = pcall(chip.text.GetStringWidth, chip.text)
	return math.max(90, math.ceil((ok and ns.Finite(width) and width or 0) + 28))
end

-- Shows a chip on every card of its stop while it is pointed at, or takes it off for nil. The cards are drawn again on the next frame (S.dirty).
function Walk.Preview(stop, part, card)
	Walk.preview = stop and { stop = stop.id, part = part, card = card } or nil
	S.dirty = true
end

function Walk.PaintTick(tick)
	kit.Backing(tick.edge, tick.hover and "hover" or "raised")
end

-- A tick of a ticks part: a row with the icon of its page in the sidebar, its name with the Suggested tag after it, its line and the box. The whole
-- row toggles.
function Walk.NewTick(view, part, card)
	local frame = kit.Frame(view.frame)
	frame:SetSize(393, 64)
	local tick = { card = card, part = part, frame = frame, edge = ns.Outline(frame, frame, true) }
	local icon = kit.Fill(frame, "ARTWORK")
	icon:SetSize(32, 32)
	icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -16)
	if type(ns.PanelNav) == "table" and type(ns.PanelNav.Cell) == "function" then
		ns.PanelNav.Cell(icon, card.icon)
	end
	tick.name = kit.Label(frame, "GameFontNormal", "LEFT")
	tick.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 56, -12)
	tick.name:SetText(card.label)
	tick.tag = Walk.NewTag(frame)
	tick.tag.frame:SetPoint("LEFT", tick.name, "RIGHT", 8, 0)
	tick.line = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 280, true))
	tick.line:SetPoint("TOPLEFT", frame, "TOPLEFT", 56, -30)
	tick.line:SetText(card.line)
	local box = kit.Frame(frame)
	box:SetSize(18, 18)
	box:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
	local boxEdge = ns.Outline(box, box, true)
	tick.mark = kit.Fill(box, "ARTWORK")
	tick.mark:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	tick.mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	tick.mark:Hide()
	kit.Painted(function()
		icon:SetVertexColor(kit.Shade("text"))
		kit.Backing(boxEdge, "window", 1, "line-strong")
		tick.mark:SetColorTexture(kit.Accent())
		Walk.PaintTick(tick)
	end)
	kit.Clickable(frame, function()
		Walk.Toggle(card)
	end)
	frame:SetScript("OnEnter", function()
		tick.hover = true
		Walk.PaintTick(tick)
	end)
	frame:SetScript("OnLeave", function()
		tick.hover = false
		Walk.PaintTick(tick)
	end)
	return tick
end

-- A stop ---------------------------------------------------------------------------------------------------------------------------------------

-- The screen of a stop, made the first time the stop shows: a heading for each part (its label, then its note 12 units on). Its cards, chips and
-- ticks are made when they first show.
function Walk.StopView(stop)
	local view = Walk.screens[stop.id]
	-- A stop read before the modules started is the same stop once they have; a screen is made again only for the stops kept then.
	if view and (view.stop == stop or not Walk.stops) then
		return view
	end
	if view then
		view.frame:Hide()
	end
	view = { stop = stop, frame = kit.Frame(Walk.stopFrame), parts = {} }
	view.frame:SetAllPoints(Walk.stopFrame)
	for _, part in ipairs(stop.parts) do
		local entry = { part = part, tiles = {}, shown = {} }
		entry.head = kit.Label(view.frame, "GameFontHighlightSmall", "LEFT")
		entry.head:SetText(part.label)
		entry.note = kit.Dim(kit.Label(view.frame, "GameFontHighlightSmall", "LEFT", 560))
		entry.note:SetPoint("LEFT", entry.head, "RIGHT", 12, 0)
		view.parts[#view.parts + 1] = entry
	end
	Walk.screens[stop.id] = view
	return view
end

-- Which parts of a stop offer As it is now: the screen is laid out again when that changes (the profile in use changed).
function Walk.Signature(view)
	local marks = {}
	for index, entry in ipairs(view.parts) do
		marks[index] = Walk.NowShown(entry.part) and "1" or "0"
	end
	return table.concat(marks)
end

-- Lays a stop's screen out from the top, each part under its heading. Chips take a row and ticks two columns of rows; a cards part takes the height
-- the others leave, in two columns for two or four cards and three for any other number, the width shared out, at most 220 units tall. As it is now
-- comes first while the part offers it.
function Walk.Layout(view)
	local height = Walk.Height()
	local used, shares = 16, 0
	local marks = {}
	for index, entry in ipairs(view.parts) do
		local part = entry.part
		entry.now = Walk.NowShown(part)
		marks[index] = entry.now and "1" or "0"
		entry.shown = {}
		if entry.now then
			entry.shown[1] = part.nowCard
		end
		for _, card in ipairs(part.cards) do
			entry.shown[#entry.shown + 1] = card
		end
		if part.kind == "cards" then
			shares = shares + 1
			used = used + Walk.HEAD + Walk.AFTER
		elseif part.kind == "chips" then
			used = used + Walk.HEAD + 26 + Walk.AFTER
		else
			local rows = math.ceil(#entry.shown / 2)
			used = used + Walk.HEAD + rows * 64 + (rows - 1) * 10 + Walk.AFTER
		end
	end
	local free = shares > 0 and math.floor((height - used) / shares) or 0
	local width = kit.RIGHT_W - 2 * Walk.PAD
	local y = 8
	for _, entry in ipairs(view.parts) do
		local part = entry.part
		entry.head:ClearAllPoints()
		entry.head:SetPoint("LEFT", view.frame, "TOPLEFT", Walk.PAD, -(y + 9))
		y = y + Walk.HEAD
		local on = {}
		if part.kind == "cards" then
			local count = #entry.shown
			local cols = (count <= 2 or count == 4) and 2 or 3
			local w = math.floor((width - (cols - 1) * Walk.GAP) / cols)
			local rows = math.ceil(count / cols)
			local h = math.max(80, math.min(Walk.TALL, math.floor((free - (rows - 1) * Walk.GAP) / rows)))
			for index, card in ipairs(entry.shown) do
				local tile = entry.tiles[card] or Walk.NewCard(view, part, card)
				entry.tiles[card] = tile
				on[tile] = true
				Walk.PlaceCard(tile, view.frame, Walk.PAD + ((index - 1) % cols) * (w + Walk.GAP), y + math.floor((index - 1) / cols) * (h + Walk.GAP), w, h)
			end
			y = y + rows * h + (rows - 1) * Walk.GAP + Walk.AFTER
		elseif part.kind == "chips" then
			local x = Walk.PAD
			for _, card in ipairs(entry.shown) do
				local chip = entry.tiles[card] or Walk.NewChip(view, part, card)
				entry.tiles[card] = chip
				on[chip] = true
				local wide = Walk.ChipWidth(chip)
				chip.frame:SetWidth(wide)
				chip.frame:ClearAllPoints()
				chip.frame:SetPoint("TOPLEFT", view.frame, "TOPLEFT", x, -y)
				chip.frame:Show()
				x = x + wide + 8
			end
			y = y + 26 + Walk.AFTER
		else
			for index, card in ipairs(entry.shown) do
				local tick = entry.tiles[card] or Walk.NewTick(view, part, card)
				entry.tiles[card] = tick
				on[tick] = true
				tick.frame:ClearAllPoints()
				tick.frame:SetPoint("TOPLEFT", view.frame, "TOPLEFT", Walk.PAD + ((index - 1) % 2) * 405, -(y + math.floor((index - 1) / 2) * 74))
				tick.frame:Show()
			end
			local rows = math.ceil(#entry.shown / 2)
			y = y + rows * 64 + (rows - 1) * 10 + Walk.AFTER
		end
		for _, tile in pairs(entry.tiles) do
			if not on[tile] then
				tile.frame:Hide()
			end
		end
	end
	view.sig = table.concat(marks)
end

-- Reads a stop's screen again: the card or chip picked, the tags, the ticks and the notes of the headings.
function Walk.UpdateStop(view)
	for _, entry in ipairs(view.parts) do
		local part = entry.part
		if part.kind == "ticks" then
			for _, card in ipairs(entry.shown) do
				local tick = entry.tiles[card]
				if tick then
					tick.mark:SetShown(Walk.Ticked(card))
					Walk.SetTag(tick.tag, Walk.TickSuggested(card) and "Suggested" or nil)
				end
			end
			entry.note:SetText(part.note or "")
		else
			local picked, suggested = Walk.Picked(part), Walk.Suggested(part)
			for _, card in ipairs(entry.shown) do
				local tile = entry.tiles[card]
				if tile then
					tile.selected = card == picked
					if part.kind == "cards" then
						tile.check:SetShown(tile.selected)
						local now = card.now or Walk.Holds(part, card, S.StartValue)
						Walk.SetTag(tile.tag, now and "Now" or (card == suggested and "Suggested" or nil))
						Walk.PaintEdge(tile)
					else
						Walk.PaintChip(tile)
					end
				end
			end
			entry.note:SetText((part.kind == "cards" and not picked) and Walk.MIX or (part.note or ""))
		end
	end
end

-- Draws every card of a stop's screen again, each under its own view.
function Walk.PaintStop(view)
	for _, entry in ipairs(view.parts) do
		if entry.part.kind == "cards" then
			for _, card in ipairs(entry.shown) do
				local tile = entry.tiles[card]
				if tile and tile.w and not tile.failed then
					tile.failed = not Walk.PaintIn(tile.ctx, view.stop.draw, tile.w - 8, tile.h - 54, 2.2)
				end
			end
		end
	end
end

-- The first visit of a stop: it is marked seen, and each part of cards or chips takes the card it suggests while the profile in use has every path of
-- the part at its default (a new character on Default, or a part never changed). Only the draft is written. Ticks are only tagged.
function Walk.FirstVisit(stop)
	local draft = S.draft
	if type(draft) ~= "table" then
		return
	end
	if type(draft.seen) ~= "table" then
		draft.seen = {}
	end
	if draft.seen[stop.id] then
		return
	end
	draft.seen[stop.id] = true
	local defs = S.Defs()
	for _, part in ipairs(stop.parts) do
		local card = part.kind ~= "ticks" and Walk.Suggested(part) or nil
		if card then
			local plain = true
			for _, path in ipairs(part.list) do
				if S.StartValue(path) ~= defs[path].default then
					plain = false
					break
				end
			end
			if plain then
				Walk.Apply(part, card)
			end
		end
	end
end

-- Your screen ----------------------------------------------------------------------------------------------------------------------------------

-- A picture of a stop on Your screen: its drawing under the draft (S.view) in a box of the ground colour, or for a stop with no drawing the names of
-- what is ticked; its title, what is picked, and an accent dot while the draft changes the stop. A click opens the stop.
function Walk.NewPicture(view, stop, index)
	local frame = kit.Frame(view.frame)
	frame:SetSize(258, 128)
	frame:SetPoint("TOPLEFT", view.frame, "TOPLEFT", Walk.PAD + ((index - 1) % 3) * 270, -(8 + math.floor((index - 1) / 3) * 138))
	local tile = { stop = stop, frame = frame }
	local box = kit.Frame(frame)
	box:SetSize(258, 92)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	box:SetClipsChildren(true)
	Walk.Ground(box)
	if stop.draw then
		tile.ctx = Walk.Context(box, S.view)
	end
	local over = kit.Frame(frame)
	over:SetAllPoints(frame)
	over:SetFrameLevel(frame:GetFrameLevel() + Walk.OVER)
	if not stop.draw then
		tile.names = kit.Label(over, "GameFontHighlightSmall", "CENTER", 242, true)
		tile.names:SetPoint("CENTER", box, "CENTER", 0, 0)
	end
	tile.title = kit.Label(frame, "GameFontHighlightSmall", "LEFT", 250)
	tile.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -96)
	tile.title:SetText(stop.title)
	tile.summary = kit.Dim(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 240))
	tile.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -112)
	tile.dot = kit.Fill(over, "OVERLAY")
	tile.dot:SetSize(6, 6)
	tile.dot:SetPoint("TOPRIGHT", box, "TOPRIGHT", -6, -6)
	tile.dot:Hide()
	kit.Painted(function()
		tile.dot:SetColorTexture(kit.Accent())
	end)
	kit.Clickable(over, function()
		if type(S.Go) == "function" then
			S.Go({ kind = "stop", id = stop.id })
		end
	end)
	over:SetScript("OnEnter", function()
		kit.Tint(tile.title, "accent")
	end)
	over:SetScript("OnLeave", function()
		kit.Tint(tile.title, "text")
	end)
	return tile
end

-- The two rows of the save, over the bar: where Finish saves, with the tick Save as a new profile off Default; and the name of the new profile with
-- why it cannot be used, shown while Finish makes a new profile.
function Walk.BuildSave(view)
	local frame = view.frame
	view.saveLine = kit.Label(frame, "GameFontHighlight", "LEFT", 490, true)
	view.saveLine:SetPoint("LEFT", frame, "TOPLEFT", Walk.PAD, -(432 + 18))
	local toggle = kit.Frame(frame)
	toggle:SetSize(260, 24)
	toggle:SetPoint("LEFT", frame, "TOPLEFT", 520, -(432 + 18))
	local box = kit.Frame(toggle)
	box:SetSize(18, 18)
	box:SetPoint("LEFT", toggle, "LEFT", 0, 0)
	local edge = ns.Outline(box, box, true)
	view.newMark = kit.Fill(box, "ARTWORK")
	view.newMark:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
	view.newMark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
	view.newMark:Hide()
	local label = kit.Label(toggle, "GameFontHighlight", "LEFT")
	label:SetPoint("LEFT", box, "RIGHT", 8, 0)
	label:SetText("Save as a new profile")
	kit.Painted(function()
		kit.Backing(edge, "raised", 1, "line-strong")
		view.newMark:SetColorTexture(kit.Accent())
	end)
	kit.Clickable(toggle, function()
		if S.draft then
			S.draft.saveNew = not S.draft.saveNew
			Walk.Update()
			kit.Refresh()
		end
	end)
	view.toggle = toggle
	view.nameLabel = kit.Label(frame, "GameFontHighlight", "LEFT", 110)
	view.nameLabel:SetPoint("LEFT", frame, "TOPLEFT", Walk.PAD, -(472 + 18))
	view.nameLabel:SetText("Profile name")
	local field = kit.Field(frame, 230, 32)
	field:SetPoint("LEFT", frame, "TOPLEFT", 130, -(472 + 18))
	field:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	field:SetScript("OnTextChanged", function(self)
		if not Walk.quiet and S.draft then
			local typed = self:GetText()
			S.draft.name = IsText(typed) and typed or ""
			Walk.UpdateSave(view)
			if type(S.Buttons) == "function" then
				S.Buttons()
			end
		end
	end)
	view.field = field
	view.why = kit.Tint(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 440), "danger")
	view.why:SetPoint("LEFT", frame, "TOPLEFT", 372, -(472 + 18))
end

-- Your screen, made the first time it shows: a picture of each stop, three to a row, the notes in a scroller under them, and the two rows of the save.
function Walk.YoursView()
	local view = Walk.yours
	if not view then
		view = { frame = Walk.yoursFrame, tiles = {}, lines = {}, undos = {} }
		view.scroller = kit.Scroller(view.frame, kit.RIGHT_W, 128)
		view.scroller.frame:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, -284)
		Walk.BuildSave(view)
		Walk.yours = view
	end
	local stops = Walk.Stops()
	if view.source ~= stops and (view.source == nil or Walk.stops == stops) then
		for _, tile in ipairs(view.tiles) do
			tile.frame:Hide()
		end
		view.tiles = {}
		for index, stop in ipairs(stops) do
			view.tiles[index] = Walk.NewPicture(view, stop, index)
		end
		view.source = stops
	end
	return view
end

-- The notes of Your screen: the settings changed in More settings that no stop shows, each list action waiting for Finish (with Undo), the game
-- settings in the draft, and each reload Finish will need.
function Walk.Notes()
	local notes = {}
	local owned = {}
	for _, stop in ipairs(Walk.Stops()) do
		for _, part in ipairs(stop.parts) do
			for path in pairs(part.owned) do
				owned[path] = true
			end
		end
	end
	local defs = S.Defs()
	local more, game = {}, {}
	for _, change in ipairs(type(S.Changes) == "function" and S.Changes() or {}) do
		local def = defs[change.path]
		if def and not owned[change.path] then
			local list = ns.RowUnsaved(def) and game or more
			list[#list + 1] = def.label
		end
	end
	local joined = Walk.Join(more)
	if joined then
		notes[#notes + 1] = { text = ("Also changed in More settings: %s."):format(joined) }
	end
	local actions = S.draft and S.draft.actions
	for _, action in ipairs(type(actions) == "table" and actions or {}) do
		if type(action) == "table" then
			notes[#notes + 1] = { text = ("At Finish: %s."):format(tostring(action.text or action[3] or action.pick or action[1])), action = action }
		end
	end
	joined = Walk.Join(game)
	if joined then
		notes[#notes + 1] = { text = ("Game settings, the same in every profile: %s."):format(joined) }
	end
	if type(S.ReloadLines) == "function" and type(S.ReloadText) == "function" then
		for _, entry in ipairs(S.ReloadLines()) do
			notes[#notes + 1] = { text = S.ReloadText(entry) }
		end
	end
	return notes
end

-- Writes the notes into their scroller, one line each (wrapped at 700 units), with Undo at the right of each action.
function Walk.LayoutNotes(view, notes)
	local child = view.scroller.child
	local y = 4
	for index, note in ipairs(notes) do
		local line = view.lines[index]
		if not line then
			line = kit.Label(child, "GameFontHighlight", "LEFT", 700, true)
			view.lines[index] = line
		end
		line:SetText(note.text)
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", child, "TOPLEFT", Walk.PAD, -y)
		line:Show()
		local undo = view.undos[index]
		if note.action and not undo then
			undo = {}
			undo.button = kit.Button(child, "Undo", 70, function()
				local action = undo.action
				if type(action) == "table" and type(S.Unqueue) == "function" then
					S.Unqueue(action.pick or action[1], action.id or action[2])
					Walk.Update()
					kit.Refresh()
				end
			end)
			view.undos[index] = undo
		end
		if undo then
			undo.action = note.action
			undo.button:SetShown(note.action ~= nil)
			undo.button:ClearAllPoints()
			undo.button:SetPoint("TOPLEFT", child, "TOPLEFT", kit.RIGHT_W - Walk.PAD - 70, -y)
		end
		local ok, tall = pcall(line.GetStringHeight, line)
		tall = ok and ns.Finite(tall) and tall > 0 and tall or 14
		y = y + math.max(tall, note.action and 24 or 0) + 8
	end
	for index = #notes + 1, #view.lines do
		view.lines[index]:Hide()
		if view.undos[index] then
			view.undos[index].action = nil
			view.undos[index].button:Hide()
		end
	end
	view.scroller.SetContent(y)
end

-- Reads the save rows again: where Finish saves, the tick, the name and why it cannot be used.
function Walk.UpdateSave(view)
	local draft = S.draft
	local using = ns.Profile()
	local default = using == "Default"
	if default then
		view.saveLine:SetWidth(kit.RIGHT_W - 2 * Walk.PAD)
		view.saveLine:SetText("Finish makes a profile of your own: Default stays as it is for other characters.")
	else
		view.saveLine:SetWidth(490)
		local users = type(S.Users) == "function" and S.Users(using) or 0
		local text = ("Finish saves into %s."):format(tostring(using))
		if ns.Finite(users) and users > 1 then
			text = text .. (" %d characters use it."):format(users)
		end
		view.saveLine:SetText(text)
	end
	view.toggle:SetShown(not default)
	view.newMark:SetShown(draft.saveNew == true)
	local named = default or draft.saveNew == true
	view.nameLabel:SetShown(named)
	view.field:SetShown(named)
	view.why:SetShown(named)
	if not view.field:HasFocus() then
		local name = IsText(draft.name) and draft.name or ""
		if view.field:GetText() ~= name then
			Walk.quiet = true
			view.field:SetText(name)
			Walk.quiet = false
		end
	end
	local why
	if named and type(S.NameCheck) == "function" then
		why = select(2, S.NameCheck())
	end
	view.why:SetText(IsText(why) and why or "")
end

-- Reads Your screen again: the line under its title, what each stop has picked and its dot, the notes, the save rows, and Finish (S.Buttons dims it
-- in a fight and while the name is refused).
function Walk.UpdateYours(view)
	local draft = S.draft
	local chosen = (type(draft.values) == "table" and next(draft.values) ~= nil) or (type(draft.actions) == "table" and #draft.actions > 0)
	if S.sub then
		S.sub:SetText(chosen and "Nothing has changed yet. Finish puts this on your screen." or "Nothing is chosen yet. Finish closes setup.")
	end
	for _, tile in ipairs(view.tiles) do
		local summary = Walk.Summary(tile.stop.id)
		tile.summary:SetText(summary)
		tile.dot:SetShown(Walk.Changed(tile.stop.id))
		if tile.names then
			tile.names:SetText(summary)
		end
	end
	local notes = Walk.Notes()
	local texts = {}
	for index, note in ipairs(notes) do
		texts[index] = note.text
	end
	local sig = table.concat(texts, "\n")
	if sig ~= view.notesSig then
		view.notesSig = sig
		Walk.LayoutNotes(view, notes)
	else
		for index, note in ipairs(notes) do
			if view.undos[index] then
				view.undos[index].action = note.action
			end
		end
	end
	Walk.UpdateSave(view)
	if type(S.Buttons) == "function" then
		S.Buttons()
	end
end

-- Draws every picture of Your screen again under the draft.
function Walk.PaintYours(view)
	for _, tile in ipairs(view.tiles) do
		if tile.ctx and not tile.failed then
			tile.failed = not Walk.PaintIn(tile.ctx, tile.stop.draw, 250, 88, 1.2)
		end
	end
end

-- What Setup.lua calls -------------------------------------------------------------------------------------------------------------------------

-- The height of the body of the setup window, between its header and its bar.
function Walk.Height()
	return ns.Finite(S.BODY_H) and S.BODY_H or 512
end

-- Forgets what the walk read of the character and the chip pointed at. Setup.lua calls it each time the window opens and on Start over.
function Walk.Begin()
	Walk.facts, Walk.preview = nil, nil
end

-- Makes the frame of the stops and the frame of Your screen under the header of the right column, both hidden. Once.
function Walk.Build(parent)
	if Walk.stopFrame then
		return
	end
	local top = ns.Finite(S.TOP) and S.TOP or kit.HEADER
	for _, key in ipairs({ "stopFrame", "yoursFrame" }) do
		local frame = kit.Frame(parent)
		frame:SetSize(kit.RIGHT_W, Walk.Height())
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top)
		frame:Hide()
		Walk[key] = frame
	end
end

-- Shows a screen: { kind = "stop", id = <stop id> } or { kind = "yours" }. Its title and line go in S.title and S.sub (Your target and party says on a
-- second line why its card is suggested); a stop seen for the first time takes its suggestions; then it is laid out, read and drawn. True when shown.
function Walk.Show(screen)
	if type(screen) ~= "table" or not Walk.stopFrame then
		return false
	end
	Walk.preview, Walk.hovered = nil, nil
	if screen.kind == "yours" then
		local view = Walk.YoursView()
		Walk.stopFrame:Hide()
		Walk.yoursFrame:Show()
		Walk.shown = { kind = "yours" }
		if S.title then
			S.title:SetText("Your screen")
		end
		if S.draft then
			Walk.UpdateYours(view)
		end
		Walk.PaintYours(view)
		return true
	end
	local stop = screen.kind == "stop" and Walk.Stop(screen.id) or nil
	if not stop then
		Walk.Hide()
		return false
	end
	local view = Walk.StopView(stop)
	for _, other in pairs(Walk.screens) do
		other.frame:SetShown(other == view)
	end
	Walk.yoursFrame:Hide()
	Walk.stopFrame:Show()
	Walk.shown = { kind = "stop", id = stop.id }
	if S.title then
		S.title:SetText(stop.title)
	end
	if S.sub then
		local why = stop.id == "group" and Walk.Facts().why or nil
		S.sub:SetText(IsText(why) and (stop.line .. "\n" .. why) or stop.line)
	end
	Walk.FirstVisit(stop)
	Walk.Layout(view)
	if S.draft then
		Walk.UpdateStop(view)
	end
	Walk.PaintStop(view)
	return true
end

-- Hides the stops and Your screen and clears the strip: a page or nothing shows now.
function Walk.Hide()
	Walk.shown, Walk.preview, Walk.hovered = nil, nil, nil
	if Walk.stopFrame then
		Walk.stopFrame:Hide()
		Walk.yoursFrame:Hide()
	end
	kit.Tip("")
end

-- Reads the screen shown again: the picked cards, chips and ticks, the tags, and on Your screen the notes, the save rows and Finish. Setup.lua calls it
-- every half second and after a change.
function Walk.Update()
	local screen = Walk.shown
	if not screen or not S.draft or not Walk.stopFrame then
		return
	end
	if screen.kind == "yours" then
		if Walk.yours then
			Walk.UpdateYours(Walk.yours)
		end
		return
	end
	local view = Walk.screens[screen.id]
	if not view then
		return
	end
	if Walk.Signature(view) ~= view.sig then
		Walk.Layout(view)
		Walk.PaintStop(view)
	end
	Walk.UpdateStop(view)
end

-- Draws the cards of the stop shown, or the pictures of Your screen, again. Setup.lua calls it on the frame after S.dirty is set.
function Walk.Paint()
	local screen = Walk.shown
	if not screen then
		return
	end
	if screen.kind == "yours" then
		if Walk.yours then
			Walk.PaintYours(Walk.yours)
		end
		return
	end
	local view = Walk.screens[screen.id]
	if view then
		Walk.PaintStop(view)
	end
end

-- Left and Right on a stop: the card before or after the one picked in its cards part, from the far end when none is picked. True when the key was the
-- walk's, so that Setup.lua keeps it from the game.
function Walk.Key(key)
	local screen = Walk.shown
	if (key ~= "LEFT" and key ~= "RIGHT") or not screen or screen.kind ~= "stop" or not S.draft then
		return false
	end
	local view = Walk.screens[screen.id]
	for _, entry in ipairs(view and view.parts or {}) do
		if entry.part.kind == "cards" then
			local shown, picked = entry.shown, Walk.Picked(entry.part)
			local at
			for index, card in ipairs(shown) do
				if card == picked then
					at = index
				end
			end
			local to
			if key == "LEFT" then
				to = at and at - 1 or #shown
			else
				to = at and at + 1 or 1
			end
			if shown[to] then
				Walk.Pick(entry.part, shown[to])
			end
			return true
		end
	end
	return false
end

-- What a stop has picked, for the list and Your screen: the card or chip of each part ("As it is now", or "Your own mix" when none is), and for ticks
-- the names of those that are on, or "None"; joined with commas.
function Walk.Summary(id)
	local stop = Walk.Stop(id)
	if not stop then
		return ""
	end
	local texts = {}
	for _, part in ipairs(stop.parts) do
		if part.kind == "ticks" then
			local names = {}
			for _, card in ipairs(part.cards) do
				if Walk.Ticked(card) then
					names[#names + 1] = card.label
				end
			end
			texts[#texts + 1] = #names > 0 and table.concat(names, ", ") or "None"
		else
			local card = Walk.Picked(part)
			texts[#texts + 1] = card and card.label or "Your own mix"
		end
	end
	return table.concat(texts, ", ")
end

-- True when the draft holds a value on a path the stop owns, or an action of its ticks waits for Finish.
function Walk.Changed(id)
	local stop = Walk.Stop(id)
	local draft = S.draft
	if not stop or type(draft) ~= "table" then
		return false
	end
	local values = type(draft.values) == "table" and draft.values or {}
	for _, part in ipairs(stop.parts) do
		for path in pairs(part.owned) do
			if values[path] ~= nil then
				return true
			end
		end
		if part.kind == "ticks" and type(S.Queued) == "function" then
			for _, card in ipairs(part.cards) do
				if card.action and S.Queued(card.action.pick, card.action.id) then
					return true
				end
			end
		end
	end
	return false
end

-- Puts the cursor in the profile name of Your screen, when it shows: Finish refused the name.
function Walk.FocusName()
	local view = Walk.yours
	if view and view.field:IsVisible() then
		view.field:SetFocus()
	end
end
