local ADDON_NAME, ns = ...

-- The tabs of a module page, the breadcrumb above its title and the frame chooser of the Per frame tab. The child pages of a module are tabs: the
-- sidebar lists modules only. The eight frame pages of Unit frames are one tab, Per frame, with a chooser that remembers its last frame per account in
-- FlatUIDB.panel. Panel.lua hands the drawing of these to this file; the widgets are the ones of ns.PanelKit.

local Tabs = {}
ns.PanelTabs = Tabs

local kit = ns.PanelKit
local Look = ns.PanelLook
local Nav = ns.PanelNav
local PAD = kit.PAD

local TAB_H, CHOOSE_H, INSET, GAP, CHIP_H, CRUMB_Y = 34, 32, 10, 4, 24, 42

-- The pages of the frames of Unit frames, in the order of the chooser, and what the chooser calls them.
Tabs.FRAMES = { "unitframesPlayer", "unitframesTarget", "unitframesFocus", "unitframesPet", "unitframesTot", "unitframesParty", "unitframesBoss",
	"unitframesRaid" }
local FRAME_LABEL = { unitframesPlayer = "Player", unitframesTarget = "Target", unitframesFocus = "Focus", unitframesPet = "Pet",
	unitframesTot = "Target of target", unitframesParty = "Party", unitframesBoss = "Boss", unitframesRaid = "Raid" }
-- The pages that have a shorter name as a tab.
local NAMES = { unitframesBars = "Bars and pictures", unitframesText = "Text", unitframesIcons = "Icons and auras" }

-- The tabs of a module: { id, label, pages, frames }. The module page is General. A module with no child page has none.
function Tabs.List(model, top)
	local children = Nav.Children(model, top)
	if #children == 0 then
		return {}
	end
	local list, frames = { { id = top.key, label = "General", pages = { top } } }, nil
	for _, child in ipairs(children) do
		if FRAME_LABEL[child.key] then
			if not frames then
				frames = { id = "frames", label = "Per frame", pages = {}, frames = true }
				list[#list + 1] = frames
			end
			frames.pages[#frames.pages + 1] = child
		else
			list[#list + 1] = { id = child.key, label = NAMES[child.key] or child.label, pages = { child } }
		end
	end
	return list
end

-- The place of a page in the tabs: the number and the tab.
function Tabs.Find(list, entry)
	for number, tab in ipairs(list) do
		for _, page in ipairs(tab.pages) do
			if page == entry then
				return number, tab
			end
		end
	end
	return nil, nil
end

-- The name of the tab a page is in, or nil for a page of a module with no tabs.
local labelOf = {}
function Tabs.Label(model, entry)
	if labelOf.model ~= model then
		labelOf = { model = model }
	end
	local label = labelOf[entry]
	if label == nil then
		local _, tab = Tabs.Find(Tabs.List(model, Nav.Top(model, entry)), entry)
		label = tab and tab.label or false
		labelOf[entry] = label
	end
	return label or nil
end

-- The name of a frame page in the chooser, or nil for another page.
function Tabs.FrameName(entry)
	return FRAME_LABEL[entry.key]
end

-- The frame the chooser shows when nothing says which: the last one chosen, else the first.
function Tabs.Frame(model)
	local store = Look.Store(false)
	local kept, first = store and store.frame, nil
	for _, key in ipairs(Tabs.FRAMES) do
		local page = model.byKey[key]
		if page and key == kept then
			return page
		end
		first = first or page
	end
	return first
end

-- Keeps the frame of a page that is a frame page as the last frame.
function Tabs.Remember(entry)
	if entry and FRAME_LABEL[entry.key] then
		local store = Look.Store(true)
		if store and store.frame ~= entry.key then
			store.frame = entry.key
		end
	end
end

-- The page a click on a tab opens: the last frame for Per frame, else the page of the tab.
function Tabs.Target(model, tab)
	if tab.frames then
		local kept = Tabs.Frame(model)
		for _, page in ipairs(tab.pages) do
			if page == kept then
				return page
			end
		end
	end
	return tab.pages[1]
end

-- The width of a text, with a guess when the client gives none.
local function Measure(text)
	local ok, width = pcall(text.GetStringWidth, text)
	if ok and type(width) == "number" and not ns.IsSecret(width) and width > 0 then
		return width
	end
	return 7 * #(text:GetText() or "")
end

-- A tab or a chip of the chooser: a text between two insets, the accent line under the chosen one.
local function Button(parent, chip)
	local f = kit.Frame(parent)
	local b = { frame = f }
	b.fill = kit.Fill(f, "BACKGROUND")
	b.fill:SetAllPoints(f)
	b.text = kit.Label(f, "GameFontHighlight", "LEFT")
	b.text:SetPoint("LEFT", f, "LEFT", INSET, 0)
	b.line = kit.Fill(f, "ARTWORK")
	b.line:SetHeight(2)
	b.line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
	b.line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	local function Paint()
		local fill = (chip and b.active and "raised") or (b.hover and "hover") or nil
		b.fill:SetShown(fill ~= nil)
		if fill then
			Look.Solid(b.fill, fill)
		end
		b.line:SetShown(b.active == true)
		b.line:SetColorTexture(kit.Accent())
		kit.Tint(b.text, (b.active or b.hover) and "text" or "text-dim")
	end
	kit.Painted(Paint)
	f:SetScript("OnEnter", function()
		b.hover = true
		Paint()
	end)
	f:SetScript("OnLeave", function()
		b.hover = false
		Paint()
	end)
	kit.Clickable(f, function()
		if b.onClick then
			b.onClick()
		end
	end)
	function b.Set(text, active, onClick)
		b.text:SetText(text)
		b.active, b.onClick = active, onClick
		b.width = Measure(b.text) + 2 * INSET
		f:SetSize(b.width, chip and CHIP_H or TAB_H)
		Paint()
	end
	function b.Place(parentFrame, x, y)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", x, y)
	end
	return b
end

local function Rule(parent)
	local rule = kit.Fill(parent, "BORDER")
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	rule:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	kit.Painted(function()
		Look.Solid(rule, "line-faint")
	end)
end

-- host: Model(), Show(entry), Width() the width of the column, top the place of the bar under the top of the column. The object has Set(entry), which draws
-- the breadcrumb and the tabs of the page and gives the height they take under the header, and Hide().
function Tabs.Build(right, host)
	local self = {}
	local bar = kit.Frame(right)
	bar:SetHeight(TAB_H)
	bar:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -host.top)
	bar:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -host.top)
	Rule(bar)
	local choose = kit.Frame(right)
	choose:SetHeight(CHOOSE_H)
	choose:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -(host.top + TAB_H))
	choose:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -(host.top + TAB_H))
	Rule(choose)
	bar:Hide()
	choose:Hide()
	local tabs, chips = {}, {}
	local more = Button(bar, false)
	local owner = { frame = more.frame }
	more.frame:Hide()

	-- The breadcrumb: group, module and tab. The module and the tab are links.
	local parts, seps = {}, {}
	for index = 1, 3 do
		local f = kit.Frame(right)
		f:SetHeight(14)
		local part = { frame = f, text = kit.Dim(kit.Label(f, "GameFontHighlightSmall", "LEFT")) }
		part.text:SetPoint("LEFT", f, "LEFT", 0, 0)
		f:SetScript("OnEnter", function()
			if part.onClick then
				kit.Tint(part.text, "text")
			end
		end)
		f:SetScript("OnLeave", function()
			kit.Tint(part.text, part.last and "text" or "text-dim")
		end)
		kit.Clickable(f, function()
			if part.onClick then
				part.onClick()
			end
		end)
		f:Hide()
		parts[index] = part
		if index > 1 then
			seps[index] = kit.Dim(kit.Label(right, "GameFontHighlightSmall", "LEFT"))
			seps[index]:SetText(">")
			seps[index]:Hide()
		end
	end
	local function HideCrumbs()
		for index, part in ipairs(parts) do
			part.frame:Hide()
			if seps[index] then
				seps[index]:Hide()
			end
		end
	end
	local function Crumbs(entry, top, label)
		local model = host.Model()
		local group = Nav.GroupOf(model, entry)
		if not group then
			HideCrumbs()
			return
		end
		local names = { group, top.label, label }
		local clicks = { false, function()
			host.Show(top)
		end, function()
			host.Show(entry)
		end }
		local last = label and 3 or 2
		local x = PAD
		for index, part in ipairs(parts) do
			local name = names[index]
			part.frame:SetShown(name ~= nil)
			if seps[index] then
				seps[index]:SetShown(name ~= nil)
			end
			if name then
				if seps[index] then
					seps[index]:ClearAllPoints()
					seps[index]:SetPoint("TOPLEFT", right, "TOPLEFT", x + 6, -CRUMB_Y)
					x = x + 6 + Measure(seps[index]) + 6
				end
				part.text:SetText(name)
				part.last = index == last
				part.onClick = clicks[index] or nil
				kit.Tint(part.text, part.last and "text" or "text-dim")
				local width = Measure(part.text)
				part.frame:SetWidth(width)
				part.frame:EnableMouse(part.onClick ~= nil)
				part.frame:ClearAllPoints()
				part.frame:SetPoint("TOPLEFT", right, "TOPLEFT", x, -CRUMB_Y)
				x = x + width
			end
		end
	end

	function self.Hide()
		bar:Hide()
		choose:Hide()
		HideCrumbs()
	end

	function self.Set(entry)
		local model = host.Model()
		local top = Nav.Top(model, entry)
		local list = Tabs.List(model, top)
		local at, current = Tabs.Find(list, entry)
		Tabs.Remember(entry)
		Crumbs(entry, top, current and current.label or nil)
		if #list == 0 then
			bar:Hide()
			choose:Hide()
			return 0
		end
		local widths = {}
		for number, tab in ipairs(list) do
			tabs[number] = tabs[number] or Button(bar, false)
			tabs[number].Set(tab.label, number == at, function()
				host.Show(Tabs.Target(model, tab))
			end)
			widths[number] = tabs[number].width
		end
		more.Set("More", false)
		local room, used, fit = host.Width() - 2 * PAD, 0, #list
		for number = 1, #list do
			used = used + widths[number] + (number > 1 and GAP or 0)
		end
		if used > room then
			fit, used = 0, 0
			for number = 1, #list do
				local reach = used + (number > 1 and GAP or 0) + widths[number]
				if reach + GAP + more.width > room then
					break
				end
				used, fit = reach, number
			end
			fit = math.max(1, fit)
		end
		local x = PAD
		for number = 1, #tabs do
			local b = tabs[number]
			b.frame:SetShown(number <= fit)
			if number <= fit then
				b.Place(bar, x, 0)
				x = x + b.width + GAP
			end
		end
		more.frame:SetShown(fit < #list)
		if fit < #list then
			more.Set("More", at ~= nil and at > fit, function()
				kit.OpenList(owner, {
					right = true,
					lines = function()
						local lines = {}
						for number = fit + 1, #list do
							lines[#lines + 1] = { list[number].id, list[number].label }
						end
						return lines
					end,
					selected = function()
						return at and list[at] and list[at].id or nil
					end,
					pick = function(id)
						for _, tab in ipairs(list) do
							if tab.id == id then
								host.Show(Tabs.Target(model, tab))
							end
						end
					end,
				})
			end)
			more.Place(bar, x, 0)
		end
		bar:Show()
		local band, shown, left = TAB_H, 0, PAD
		if current and current.frames then
			for number, page in ipairs(current.pages) do
				chips[number] = chips[number] or Button(choose, true)
				local b = chips[number]
				b.Set(FRAME_LABEL[page.key], page == entry, function()
					host.Show(page)
				end)
				b.Place(choose, left, -4)
				b.frame:Show()
				left = left + b.width + GAP
				shown = number
			end
			choose:Show()
			band = band + CHOOSE_H
		else
			choose:Hide()
		end
		for number = shown + 1, #chips do
			chips[number].frame:Hide()
		end
		return band
	end
	return self
end
