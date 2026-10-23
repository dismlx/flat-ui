local _, ns = ...

-- Cards and the controls that sit on them: the card of a section (a header that folds, a count of changed rows, the rows on a panel), the
-- segmented choice and the chip set. Panel.lua hands the drawing of these to this file; the widgets are the ones of ns.PanelKit. The Sections
-- setting (Cards or Lines) picks between a card and the heading with a line under it.

local Cards = {}
ns.PanelCards = Cards

local kit = ns.PanelKit
local Look = ns.PanelLook

local HEAD, GAP, TOP = 32, 12, 8
local SEG = 26
local CHIP, CHIP_GAP, CHIP_PAD = 24, 6, 8
local DIM = 0.4

function Cards.On()
	return Look.Get("sections") == "cards"
end

-- The saved paths that setup tiers as rare (a row of tier r in SetupSteps.lua).
local rare
function Cards.IsRare(path)
	if not rare then
		rare = {}
		for _, step in ipairs(ns.SETUP_STEPS or {}) do
			for _, entry in ipairs(step.rows) do
				if entry[2] == "r" then
					rare[entry[1]] = true
				end
			end
		end
	end
	return path ~= nil and rare[path] == true
end

-- Four short bars that make a triangle: pointing down for a card that is open, to the right for a card that is folded.
local function Arrow(parent)
	local bars = {}
	for index = 1, 4 do
		bars[index] = kit.Fill(parent, "ARTWORK")
		kit.Painted(function()
			bars[index]:SetColorTexture(Look.Colour("text-dim"))
		end)
	end
	return function(folded)
		for index, bar in ipairs(bars) do
			bar:ClearAllPoints()
			if folded then
				bar:SetSize(2, 10 - 2 * index)
				bar:SetPoint("LEFT", parent, "RIGHT", -24 + (index - 1) * 2, 0)
			else
				bar:SetSize(10 - 2 * index, 2)
				bar:SetPoint("TOP", parent, "TOPRIGHT", -20, -(12 + (index - 1) * 2))
			end
		end
	end
end

-- Segmented choice ----------------------------------------------------------------------------------

-- A row of segments in place of a dropdown, for a choice that has a few short lines. The chosen segment is in the accent. Returns the function
-- that shows the saved value.
function Cards.Segments(row, item)
	local box = kit.Frame(row.frame)
	box:SetHeight(SEG)
	box:SetPoint("LEFT", row.frame, "LEFT", kit.CONTROL, 0)
	local outline = ns.Outline(box, box, true)
	kit.Painted(function()
		kit.Backing(outline, "card", 1, "line")
	end)
	local segments, x = {}, 0
	local function Paint(segment)
		if segment.on then
			kit.Backing(segment.outline, "accent", 0.18, "accent")
		elseif segment.hover then
			kit.Backing(segment.outline, "hover", 1, "line")
		else
			kit.Backing(segment.outline, "raised", 0, "line")
		end
		kit.Tint(segment.label, (segment.on or segment.hover) and "text" or "text-dim")
	end
	for _, line in ipairs(ns.Choices(item)) do
		local text = tostring(line[2])
		local width = math.max(56, 24 + 7 * #text)
		local frame = kit.Frame(box)
		frame:SetSize(width, SEG)
		frame:SetPoint("LEFT", box, "LEFT", x, 0)
		x = x + width
		local label = kit.Label(frame, "GameFontHighlightSmall", "CENTER", width)
		label:SetPoint("CENTER", frame, "CENTER", 0, 0)
		label:SetText(text)
		local segment = { value = line[1], outline = ns.Outline(frame, frame, true), label = label, on = false, hover = false }
		segments[#segments + 1] = segment
		kit.Painted(function()
			Paint(segment)
		end)
		kit.Clickable(frame, function()
			if row.active then
				kit.Write(item, segment.value)
				row.Changed()
			end
		end)
		row.Hover(frame, function()
			segment.hover = true
			Paint(segment)
		end, function()
			segment.hover = false
			Paint(segment)
		end)
	end
	box:SetWidth(math.max(1, x))
	return function()
		local value = kit.Read(item)
		for _, segment in ipairs(segments) do
			local on = segment.value == value
			if segment.on ~= on then
				segment.on = on
				Paint(segment)
			end
		end
	end
end

-- Chip set ---------------------------------------------------------------------------------------------

-- The switches of items (bool settings of page) as chips that wrap inside width. Returns the block: its height h, Place(top), Show and Update().
local function Chips(parent, page, items, width)
	local block = kit.Frame(parent)
	local chips, x, line = {}, 0, 0
	for _, item in ipairs(items) do
		local text = tostring(item.label)
		local frame = kit.Frame(block)
		local label = kit.Label(frame, "GameFontHighlight", "LEFT")
		label:SetPoint("LEFT", frame, "LEFT", 10, 0)
		label:SetText(text)
		-- The width of the text as the game draws it, or a guess when the game gives none.
		local ok, measured = pcall(label.GetStringWidth, label)
		if not (ok and type(measured) == "number" and not ns.IsSecret(measured) and measured > 0) then
			measured = 7.2 * #text
		end
		local chipWidth = 32 + math.ceil(measured)
		if x > 0 and x + chipWidth > width then
			x, line = 0, line + 1
		end
		label:SetWidth(chipWidth - 32)
		frame:SetSize(chipWidth, CHIP)
		frame:SetPoint("TOPLEFT", block, "TOPLEFT", x, -(CHIP_PAD + line * (CHIP + CHIP_GAP)))
		x = x + chipWidth + CHIP_GAP
		local check = kit.Fill(frame, "ARTWORK")
		check:SetSize(6, 6)
		check:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
		local chip = { item = item, frame = frame, label = label, outline = ns.Outline(frame, frame, true), on = false, hover = false, open = true }
		chips[#chips + 1] = chip
		function chip.Paint()
			if chip.on then
				kit.Backing(chip.outline, "accent", 0.18, "accent")
			else
				kit.Backing(chip.outline, "raised", 0, chip.hover and "line-strong" or "line")
			end
			kit.Tint(chip.label, chip.on and "text" or "text-dim")
			check:SetColorTexture(kit.Accent())
			check:SetShown(chip.on)
		end
		kit.Painted(chip.Paint)
		kit.Clickable(frame, function()
			if chip.open then
				kit.Write(item, kit.Read(item) ~= true)
				kit.Refresh()
			end
		end)
		frame:SetScript("OnEnter", function()
			chip.hover = true
			chip.Paint()
			kit.Tip(item.tip)
		end)
		frame:SetScript("OnLeave", function()
			chip.hover = false
			chip.Paint()
			kit.Tip("")
		end)
	end
	local object = { frame = block, h = (line + 1) * CHIP + line * CHIP_GAP + 2 * CHIP_PAD }
	block:SetHeight(object.h)
	function object.Place(top)
		block:ClearAllPoints()
		block:SetPoint("TOPLEFT", parent, "TOPLEFT", kit.PAD + 16, -top)
		block:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -(kit.PAD + 16), -top)
	end
	function object.Show(shown)
		block:SetShown(shown)
	end
	function object.Update()
		for _, chip in ipairs(chips) do
			local on = kit.Read(chip.item) == true
			local open = kit.IsOpen(page, chip.item)
			if chip.on ~= on then
				chip.on = on
				chip.Paint()
			end
			if chip.open ~= open then
				chip.open = open
				chip.frame:SetAlpha(open and 1 or DIM)
			end
		end
	end
	return object
end

-- Cards ------------------------------------------------------------------------------------------------

-- The cards of a page. Section(item, y, page, index) is called for each heading, Row(row, item, y) for each row built, and Finish(y) at the end.
-- A page with a block of its own (the Trackers editor) is laid out as it is built and its cards do not fold, since the block cannot move.
function Cards.New(entry, view, scroller, width)
	local parent = scroller.child
	local cards = { list = {}, chipped = {}, seen = {}, static = false }
	for _, item in ipairs(entry.page) do
		if item.kind == "entries" then
			cards.static = true
		end
	end
	kit.Inset(parent, kit.PAD + 16)

	local function Open(top)
		local pending = cards.pending
		cards.pending = nil
		local card = { items = {}, paths = {}, name = pending and pending.name, number = pending and pending.number }
		if pending then
			top = pending.top
		end
		cards.list[#cards.list + 1] = card
		cards.card = card
		card.back = kit.Frame(parent)
		card.back:SetHeight(1)
		card.outline = ns.Outline(parent, card.back, true)
		kit.Painted(function()
			kit.Backing(card.outline, "card", 1, "line")
		end)
		if card.name then
			-- Two sections of a page with one name fold apart: the second has its place in the id.
			cards.seen[card.name] = (cards.seen[card.name] or 0) + 1
			card.id = "card:" .. entry.key .. ":" .. card.name .. (cards.seen[card.name] > 1 and (":" .. cards.seen[card.name]) or "")
			card.folded = not cards.static and Look.Folded(card.id)
			card.click = kit.Frame(parent)
			card.click:SetHeight(HEAD)
			card.hover = kit.Fill(card.click, "BACKGROUND")
			card.hover:SetAllPoints(card.click)
			card.hover:Hide()
			kit.Painted(function()
				kit.Solid(card.hover, "hover")
			end)
			card.label = kit.Label(parent, "GameFontNormal", "LEFT", 400)
			card.label:SetText(card.name)
			card.count = kit.Tint(kit.Label(card.click, "GameFontHighlightSmall", "RIGHT", 120), "accent")
			card.count:SetPoint("RIGHT", card.click, "RIGHT", -44, 0)
			card.shown = 0
			if not cards.static then
				card.arrow = Arrow(card.click)
				card.arrow(card.folded)
				kit.Clickable(card.click, function()
					card.folded = not card.folded
					Look.Fold(card.id, card.folded)
					card.arrow(card.folded)
					cards.Relayout()
				end)
				card.click:SetScript("OnEnter", function()
					card.hover:Show()
				end)
				card.click:SetScript("OnLeave", function()
					card.hover:Hide()
				end)
			end
		end
		function card.Move(at)
			card.top = at
			card.back:ClearAllPoints()
			card.back:SetPoint("TOPLEFT", parent, "TOPLEFT", kit.PAD, -at)
			card.back:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -kit.PAD, -at)
			if card.click then
				card.click:ClearAllPoints()
				card.click:SetPoint("TOPLEFT", parent, "TOPLEFT", kit.PAD, -at)
				card.click:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -kit.PAD, -at)
				card.label:ClearAllPoints()
				card.label:SetPoint("LEFT", parent, "TOPLEFT", kit.PAD + 16, -(at + HEAD / 2))
			end
		end
		function card.Bottom(bottom)
			card.back:SetHeight(math.max(1, bottom - card.top))
		end
		card.Move(top)
		return card
	end

	function cards.Close(y)
		if cards.card and cards.static then
			cards.card.Bottom(y)
		end
		cards.card = nil
	end

	-- A heading: the card starts here. Returns the y under its header, and under its chips when the section is a chip set.
	function cards.Section(item, y, page, index)
		cards.Close(y)
		local top = y + (#cards.list > 0 and GAP or 0)
		cards.pending = { name = item.section, number = #view.sections, top = top }
		local card = Open(top)
		y = top + HEAD
		if item.chips then
			local chips = {}
			for at = index + 1, #page do
				local each = page[at]
				if each.section then
					break
				elseif each.key and each.kind == "bool" and ns.RowShown(each.path) then
					chips[#chips + 1] = each
					cards.chipped[each] = true
				end
			end
			if #chips > 0 then
				local block = Chips(parent, page, chips, width - 2 * (kit.PAD + 16))
				block.Place(y)
				card.items[#card.items + 1] = block
				for _, each in ipairs(chips) do
					card.paths[#card.paths + 1] = each
				end
				view.rows[#view.rows + 1] = block
				y = y + block.h
			end
		end
		return y
	end

	-- The link at the end of a card's plain rows. The rare rows of the card sit under it while it is open.
	local function MoreLink(card)
		local frame = kit.Frame(parent)
		frame:SetHeight(kit.ROW)
		local label = kit.Tint(kit.Label(frame, "GameFontHighlightSmall", "LEFT", 240), "accent")
		label:SetPoint("LEFT", frame, "LEFT", 16, 0)
		card.opened = card.id ~= nil and Look.Folded("more:" .. card.id)
		-- A rare row that is not at its default has its dot and reset hidden while the link is shut, so the link says so.
		local function Text()
			if card.opened then
				return "Fewer choices"
			end
			local changed = 0
			for _, each in ipairs(card.rare) do
				if kit.Read(each.item) ~= each.item.default then
					changed = changed + 1
				end
			end
			return "More choices (" .. #card.rare .. (changed > 0 and (", " .. changed .. " changed") or "") .. ")"
		end
		kit.Clickable(frame, function()
			card.opened = not card.opened
			if card.id then
				Look.Fold("more:" .. card.id, card.opened)
			end
			cards.Relayout()
		end)
		card.link = {
			Refresh = function()
				label:SetText(Text())
			end,
			h = kit.ROW,
			Show = function(shown)
				frame:SetShown(shown)
			end,
			Place = function(top)
				frame:ClearAllPoints()
				frame:SetPoint("TOPLEFT", parent, "TOPLEFT", kit.PAD, -top)
				frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -kit.PAD, -top)
				label:SetText(Text())
			end,
		}
	end

	function cards.Row(row, item, y)
		local card = cards.card or Open(y)
		local entry = { h = kit.ROW, Place = row.Place, item = item, Show = function(shown) row.frame:SetShown(shown) end }
		if not cards.static and Cards.IsRare(item.path) then
			card.rare = card.rare or {}
			card.rare[#card.rare + 1] = entry
			if not card.link then
				MoreLink(card)
			end
		else
			card.items[#card.items + 1] = entry
		end
		if item.path and item.kind ~= "list" and not ns.RowLive(item) then
			card.paths[#card.paths + 1] = item
		end
	end

	-- A block of the page was built: a card with no heading holds it when no heading came before.
	function cards.Static()
		if not cards.card then
			Open(TOP)
		end
	end

	function cards.Layout()
		local y = TOP
		for index, card in ipairs(cards.list) do
			if card.number then
				view.sections[card.number] = y
			end
			if index > 1 then
				y = y + GAP
			end
			card.Move(y)
			y = y + (card.click and HEAD or 0)
			for _, each in ipairs(card.items) do
				each.Show(not card.folded)
				if not card.folded then
					each.Place(y)
					y = y + each.h
				end
			end
			if card.link then
				card.link.Show(not card.folded)
				if not card.folded then
					card.link.Place(y)
					y = y + card.link.h
				end
				for _, each in ipairs(card.rare) do
					each.Show(not card.folded and card.opened == true)
					if not card.folded and card.opened then
						each.Place(y)
						y = y + each.h
					end
				end
			end
			card.Bottom(y)
		end
		return y
	end

	function cards.Relayout()
		scroller.SetContent(cards.Layout() + kit.PAD)
	end

	function cards.Finish(y)
		cards.Close(y)
		if cards.static then
			return y
		end
		return cards.Layout()
	end

	-- The count at the right of a header: the rows of the card that are not at their default, as Reset page counts them.
	function cards.Update()
		-- A page with a block of its own: the last card follows the height of the block.
		local last = cards.list[#cards.list]
		if cards.static and last then
			last.Bottom(scroller.content - kit.PAD)
		end
		for _, card in ipairs(cards.list) do
			if card.count then
				local changed = 0
				for _, item in ipairs(card.paths) do
					if kit.Read(item) ~= item.default then
						changed = changed + 1
					end
				end
				if changed ~= card.shown then
					card.shown = changed
					card.count:SetText(changed > 0 and (changed .. " changed") or "")
				end
			end
			if card.link then
				card.link.Refresh()
			end
		end
	end

	-- A jump from the sidebar to a card that is folded opens it.
	local function Unfold(card)
		if card.folded then
			card.folded = false
			Look.Fold(card.id, false)
			card.arrow(false)
			cards.Relayout()
		end
	end

	function view.Reveal(number)
		for _, card in ipairs(cards.list) do
			if card.number == number then
				Unfold(card)
			end
		end
	end

	-- A jump from the search to a row in a folded card opens the card.
	function view.RevealItem(item)
		for _, card in ipairs(cards.list) do
			for _, each in ipairs(card.items) do
				if each.item == item then
					Unfold(card)
				end
			end
			-- A rare row found by the search opens the rows behind More choices.
			for _, each in ipairs(card.rare or {}) do
				if each.item == item and not card.opened then
					card.opened = true
					if card.folded then
						Unfold(card)
					else
						cards.Relayout()
					end
				end
			end
			for _, each in ipairs(card.paths) do
				if each == item then
					Unfold(card)
				end
			end
		end
	end

	view.rows[#view.rows + 1] = cards
	return cards
end
