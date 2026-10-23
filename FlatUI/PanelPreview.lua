local _, ns = ...

-- The preview band of the options window: a drawing of Flat UI setup above the settings of a page (SetupDraw.lua), read through ns.LiveView, so it follows
-- the profile in use. It is made of textures, font strings and frames of the addon's own: no nameplate, unit frame or other protected frame of the game is
-- touched, and every number in it is a fixed sample. Pointing at a part outlines it and fills its row; a click opens the tab of the row, scrolls to it and flashes
-- it. Pointing at a row brackets its part. Previews (Config.lua, panel.preview) is On, Collapsed or Off.

local Preview = {}
ns.PanelPreview = Preview

local kit = ns.PanelKit
local Look = ns.PanelLook

local STAGE_W, STAGE_H = 760, 160
local GAP, BAR = 12, 28
local BAND = STAGE_H + 2 * GAP
local HIT_LEVEL, OVER_LEVEL = 300, 900
local HINT = "Point at a part to find its setting."
-- The setting that stands for a whole part, where a region has many.
local PRIMARY = { enabled = 1, show = 2, style = 3, health = 4 }

-- The drawing of each page that has a band.
local NAMEPLATE = "mock-nameplate"
local DRAWINGS = {
	nameplates = NAMEPLATE, nameplatesHealth = NAMEPLATE, nameplatesColours = NAMEPLATE, nameplatesText = NAMEPLATE,
	nameplatesCast = "mock-nameplate-cast", nameplatesMarks = "mock-nameplate-marks", nameplatesAuras = "mock-nameplate-auras", nameplatesGame = "mock-nameplate-stack",
	unitframes = "mock-unit-frames", unitframesParty = "mock-party-frames", unitframesBoss = "mock-raid-cells", unitframesRaid = "mock-raid-cells",
	unitframesPlayer = "mock-unit-frame", unitframesTarget = "mock-unit-frame", unitframesFocus = "mock-unit-frame", unitframesPet = "mock-unit-frame",
	unitframesTot = "mock-unit-frame", unitframesBars = "mock-unit-frame", unitframesText = "mock-unit-frame", unitframesIcons = "mock-unit-frame",
	castbars = "mock-cast-bar", castbarsSize = "mock-cast-bar", castbarsText = "mock-cast-bar",
	actionbars = "mock-action-row", actionbarsText = "mock-action-row", actionbarsColours = "mock-action-row", actionbarsEffects = "mock-action-row",
	swing = "mock-swing",
}

-- The page of each frame of the Unit frames drawings, which the Per frame chooser shows.
local FRAME_PAGE = { player = "unitframesPlayer", target = "unitframesTarget", focus = "unitframesFocus", pet = "unitframesPet", tot = "unitframesTot",
	party1 = "unitframesParty", party2 = "unitframesParty", party3 = "unitframesParty", party4 = "unitframesParty", party5 = "unitframesParty",
	partypet1 = "unitframesParty", partypet2 = "unitframesParty", totem = "unitframes", boss = "unitframesBoss", boss2 = "unitframesBoss", raid = "unitframesRaid" }
Preview.FRAME_PAGE = FRAME_PAGE

-- The id of the drawing a page shows, or nil for a page with none (or when the drawings are not loaded).
function Preview.Drawing(key)
	local id = DRAWINGS[key]
	if id and ns.SetupDrawings and ns.SetupDrawings[id] then
		return id
	end
	return nil
end

local function Visible(region)
	local call = region.IsVisible or region.IsShown
	return call == nil or call(region) == true
end

local function Size(region)
	local w, h = region:GetWidth(), region:GetHeight()
	return (type(w) == "number" and w or 0) * (type(h) == "number" and h or 0)
end

-- host: Model(), Arrive(entry, item), Show(entry), Fill(path, on) and Relayout().
function Preview.Build(right, host)
	local self = { opened = false }
	local D = ns.SetupDraw
	local frame, bar, barText, holder, over, hint, ctx
	local edges = {}
	local hitOf = setmetatable({}, { __mode = "k" })
	local active, failed = {}, {}
	local byPath

	-- Runs fn(...) in the context of the band with the profile in use as the view. Returns pcall's answer.
	local function Under(fn, ...)
		return pcall(D.In, ctx, function(...)
			local done, result = ns.Viewing(ns.LiveView, fn, ...)
			if not done then
				error(result, 0)
			end
			return result
		end, ...)
	end

	-- The entry and the row item of a setting, from the pages of the window.
	local function Find(path)
		local model = host.Model()
		if not byPath or byPath.model ~= model then
			byPath = { model = model }
			for _, entry in ipairs(model.pages) do
				for _, item in ipairs(entry.page) do
					if item.path and not byPath[item.path] then
						byPath[item.path] = { entry, item }
					end
				end
			end
		end
		return byPath[path]
	end

	local function Outline(region)
		local r, g, b = kit.Accent()
		for _, edge in ipairs(edges) do
			edge:ClearAllPoints()
			edge:SetColorTexture(r, g, b, 1)
			edge:Show()
		end
		edges[1]:SetPoint("BOTTOMLEFT", region, "TOPLEFT", 0, 0)
		edges[1]:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", 0, 0)
		edges[1]:SetHeight(1)
		edges[2]:SetPoint("TOPLEFT", region, "BOTTOMLEFT", 0, 0)
		edges[2]:SetPoint("TOPRIGHT", region, "BOTTOMRIGHT", 0, 0)
		edges[2]:SetHeight(1)
		edges[3]:SetPoint("TOPRIGHT", region, "TOPLEFT", 0, 1)
		edges[3]:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", 0, -1)
		edges[3]:SetWidth(1)
		edges[4]:SetPoint("TOPLEFT", region, "TOPRIGHT", 0, 1)
		edges[4]:SetPoint("BOTTOMLEFT", region, "BOTTOMRIGHT", 0, -1)
		edges[4]:SetWidth(1)
	end

	-- Takes the outline and the fill of the row off the part that was pointed at.
	function self.Leave()
		local hit = self.over
		self.over = nil
		for _, edge in ipairs(edges) do
			edge:Hide()
		end
		if hit and hit.path then
			host.Fill(hit.path, false, hit.filled)
		end
	end

	local function Enter(hit)
		self.Leave()
		self.over = hit
		Outline(hit.region)
		if hit.path then
			hit.filled = host.View()
			host.Fill(hit.path, true, hit.filled)
		end
	end

	-- A click on a part: the first one ends the hint. A part of a frame picks that frame in the Per frame chooser; a part with a setting opens its row.
	local function Click(hit)
		if not Look.Hinted() then
			Look.SetHinted()
			hint:Hide()
		end
		local model = host.Model()
		local page = hit.frame and model.byKey[FRAME_PAGE[hit.frame]]
		if page and ns.PanelTabs then
			ns.PanelTabs.Remember(page)
		end
		local target = hit.path and Find(hit.path)
		if target then
			host.Arrive(target[1], target[2])
		elseif page then
			host.Show(page)
		end
	end

	local function HitFor(region)
		local hit = hitOf[region]
		if not hit then
			hit = kit.Frame(ctx.stage)
			hit:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
			hit:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
			hit.region = region
			kit.Clickable(hit, function()
				Click(hit)
			end)
			hit:SetScript("OnEnter", function()
				Enter(hit)
			end)
			hit:SetScript("OnLeave", function()
				if self.over == hit then
					self.Leave()
				end
			end)
			hitOf[region] = hit
		end
		return hit
	end

	-- The frame of a drawing a region is part of: the id whose root is the region or one of its parents.
	local function Owner(region, byRoot)
		local node = region
		for _ = 1, 24 do
			if node == nil then
				return nil
			end
			if byRoot[node] then
				return byRoot[node]
			end
			node = node.GetParent and node:GetParent() or nil
		end
		return nil
	end

	-- One frame that takes the mouse over each part, the smaller on top. A frame of a unit frame drawing has one over its whole root.
	local function Hits(id, drawing)
		local roots, byRoot, ids = {}, {}, {}
		local registered = ns.SetupDrawings[id]
		local items = registered and registered.itemsOf and registered.itemsOf(drawing.frame)
		if type(items) == "table" then
			for frameId, item in pairs(items) do
				if type(frameId) == "string" and type(item) == "table" and item.root then
					roots[frameId], byRoot[item.root] = item.root, frameId
					ids[#ids + 1] = frameId
				end
			end
			table.sort(ids)
		end
		local list, seen, paths = {}, {}, {}
		for path, region in pairs(drawing.parts or {}) do
			if type(path) == "string" and type(region) == "table" and region.SetPoint then
				paths[#paths + 1] = path
			end
		end
		-- Several settings share a region: the one that names the whole part comes first, then the others by name.
		table.sort(paths, function(a, b)
			local ra, rb = PRIMARY[a:match("[^.]+$")] or 99, PRIMARY[b:match("[^.]+$")] or 99
			if ra ~= rb then
				return ra < rb
			end
			return a < b
		end)
		for _, path in ipairs(paths) do
			local region = drawing.parts[path]
			if not seen[region] then
				seen[region] = true
				-- The unit frame drawings key a part by the bare name of its setting.
				local full = registered and registered.itemsOf and not path:find(".", 1, true) and "unitframes." .. path or path
				list[#list + 1] = { region = region, path = full, frame = Owner(region, byRoot), area = Size(region) }
			end
		end
		for _, frameId in ipairs(ids) do
			local root = roots[frameId]
			if not seen[root] then
				seen[root] = true
				list[#list + 1] = { region = root, frame = frameId, area = Size(root) }
			end
		end
		table.sort(list, function(a, b)
			return a.area > b.area
		end)
		for _, hit in ipairs(active) do
			hit:Hide()
		end
		active = {}
		local base = ctx.stage:GetFrameLevel() + HIT_LEVEL
		for rank, entry in ipairs(list) do
			local hit = HitFor(entry.region)
			hit.path, hit.frame = entry.path, entry.frame
			hit:SetFrameLevel(base + rank)
			hit:SetShown(Visible(entry.region))
			active[#active + 1] = hit
		end
		if self.over and not self.over:IsShown() then
			self.Leave()
		end
	end

	local function Ensure()
		if frame then
			return
		end
		frame = kit.Frame(right)
		frame:Hide()
		bar = kit.Frame(frame)
		bar:SetHeight(BAR)
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		barText = kit.Dim(kit.Label(bar, "GameFontHighlightSmall", "LEFT"))
		barText:SetPoint("LEFT", bar, "LEFT", kit.PAD, 0)
		kit.Clickable(bar, function()
			self.opened = not self.opened
			host.Relayout()
		end)
		holder = kit.Frame(frame)
		holder:SetSize(STAGE_W, STAGE_H)
		holder:SetClipsChildren(true)
		local back = kit.Fill(holder, "BACKGROUND")
		back:SetAllPoints(holder)
		kit.Painted(function()
			kit.Solid(back, "stage")
		end)
		ctx = D.Context(holder, ns.LiveView)
		ctx.stage:SetSize(D.STAGE_W, D.STAGE_H)
		ctx.stage:SetScale(math.min(STAGE_W / D.STAGE_W, STAGE_H / D.STAGE_H))
		ctx.stage:SetPoint("CENTER", holder, "CENTER", 0, 0)
		over = kit.Frame(holder)
		over:SetAllPoints(holder)
		over:SetFrameLevel(holder:GetFrameLevel() + OVER_LEVEL)
		for index = 1, 4 do
			edges[index] = kit.Fill(over, "OVERLAY")
			edges[index]:Hide()
		end
		hint = kit.Dim(kit.Label(over, "GameFontHighlightSmall", "LEFT"))
		hint:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 8, 6)
		hint:SetText(HINT)
	end

	-- Brackets the part that the setting `path` changes, or clears the bracket for nil.
	function self.Mark(path)
		if ctx and frame:IsShown() and holder:IsShown() then
			pcall(D.In, ctx, function()
				local parts = D.current and D.current.parts or {}
				return D.MarkRegion(path and (parts[path] or parts[path:match("^unitframes%.(.+)$") or ""]))
			end)
		end
	end

	function self.Hide()
		if not frame then
			return
		end
		self.Leave()
		pcall(D.In, ctx, D.MarkRegion, nil)
		frame:Hide()
	end

	-- Paints the drawing again from the profile in use and puts a frame over each of its parts.
	function self.Update()
		local id = self.id
		if not (frame and id and frame:IsShown() and holder:IsShown()) or failed[id] then
			return
		end
		local ok, drawing = Under(function()
			local shown = D.Show(id)
			if shown then
				D.Paint()
			end
			return shown
		end)
		if not ok then
			failed[id] = true
			geterrorhandler()(drawing)
			return
		end
		if drawing then
			local done, err = pcall(Hits, id, drawing)
			if not done then
				failed[id] = true
				geterrorhandler()(err)
			end
		end
	end

	-- The frames over the parts of the drawing shown, and whether a bracket is on it (the checks read these).
	function self.Hits()
		return active
	end

	function self.Marked()
		local drawing = ctx and ctx.current
		return drawing ~= nil and drawing.mark ~= nil and drawing.mark:IsShown() == true
	end

	-- Shows the band for a page `top` units from the top of the right side, or hides it. Returns its height: 0 when the page has none or Previews is Off.
	function self.Set(entry, top)
		local id = entry and not entry.home and not entry.profiles and Preview.Drawing(entry.key) or nil
		local mode = Look.Get("preview")
		if not id or mode == "off" or not (D and D.Context) then
			self.id = nil
			self.Hide()
			return 0
		end
		Ensure()
		self.id = id
		local collapsed = mode == "collapsed"
		local open = not collapsed or self.opened
		local head = collapsed and BAR or 0
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -top)
		frame:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -top)
		frame:SetHeight(head + (open and BAND or 0))
		bar:SetShown(collapsed)
		barText:SetText(open and "Hide preview" or "Show preview")
		holder:ClearAllPoints()
		holder:SetPoint("TOP", frame, "TOP", 0, -(head + GAP))
		holder:SetShown(open)
		hint:SetShown(not Look.Hinted())
		frame:Show()
		if open then
			self.Update()
		else
			self.Leave()
		end
		return head + (open and BAND or 0)
	end

	Preview.band = self
	return self
end
