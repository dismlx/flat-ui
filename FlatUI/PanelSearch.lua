local ADDON_NAME, ns = ...

local Search = {}
ns.PanelSearch = Search

Search.PROFILE_ROWS = { "Profile in use", "New profile", "Duplicate profile", "Setup", "Copy from", "Delete profile", "Rename profile", "Reset profile", "In a dungeon", "In a raid",
	"In a battleground or arena", "Everywhere else", "Export profile", "Import profile", "Export trackers", "Import trackers", "Export by module" }
Search.ALIAS = { ["Duplicate profile"] = "New profile" }
Search.ACTIONS = {
	{ id = "test", label = "Test mode", tip = "samples sample frames preview" },
	{ id = "move", label = "Move frames", tip = "movers positions drag place" },
	{ id = "welcome", label = "Welcome screen", tip = "start first" },
	{ id = "looks", label = "Ready-made looks", tip = "profiles presets layouts" },
}

function Search.Words(typed)
	local words = {}
	for word in typed:lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	return words
end

local function HasAll(text, words)
	for _, word in ipairs(words) do
		if not text:find(word, 1, true) then
			return false
		end
	end
	return true
end

function Search.Tier(words, label, tip, section, page)
	label = (label or ""):lower()
	if HasAll(label, words) then
		return label:sub(1, #words[1]) == words[1] and 1 or 2
	end
	tip = (tip or ""):lower()
	if HasAll(label .. "\n" .. tip, words) then
		return 3
	end
	if HasAll(table.concat({ label, tip, (section or ""):lower(), (page or ""):lower() }, "\n"), words) then
		return 4
	end
end

function Search.Sort(groups)
	for index, group in ipairs(groups) do
		group.at = index
		for order, hit in ipairs(group.hits) do
			hit.at = order
		end
		table.sort(group.hits, function(a, b)
			if a.tier ~= b.tier then
				return a.tier < b.tier
			elseif #a.label ~= #b.label then
				return #a.label < #b.label
			end
			return a.at < b.at
		end)
		group.best = group.hits[1] and group.hits[1].tier or 5
	end
	table.sort(groups, function(a, b)
		if a.best ~= b.best then
			return a.best < b.best
		end
		return a.at < b.at
	end)
	return groups
end

local function Named(model, entry, child)
	local module = entry.page and entry.page.moduleLabel
	local tab = child and ns.PanelTabs and ns.PanelTabs.Label(model, entry)
	return table.concat({ entry.label or "", type(module) == "string" and module or "", type(tab) == "string" and tab or "" }, " ")
end

local function Name(model, entry)
	local top = ns.PanelNav.Top(model, entry)
	if top and top ~= entry then
		return (Named(model, entry, true) .. " " .. Named(model, top, false)):lower()
	end
	return Named(model, entry, false):lower()
end

function Search.Pages(words, model)
	local list = {}
	local function Add(entry)
		if not (entry and HasAll(Name(model, entry), words)) then
			return
		end
		local top = ns.PanelNav.Top(model, entry)
		if top and top ~= entry and HasAll(Name(model, top), words) then
			return
		end
		list[#list + 1] = entry
	end
	Add(model.home)
	for _, entry in ipairs(model.pages) do
		Add(entry)
	end
	Add(model.profiles)
	return list
end

function Search.Closest(words, model)
	local scored, scoreOf = {}, {}
	local function Add(entry, at)
		local name, score = Name(model, entry), 0
		for _, word in ipairs(words) do
			if #word >= 3 and name:find(word:sub(1, 3), 1, true) then
				score = score + 1
			end
		end
		if score > 0 then
			scored[#scored + 1] = { entry = entry, score = score, at = at }
			scoreOf[entry] = score
		end
	end
	Add(model.home, 0)
	for index, entry in ipairs(model.pages) do
		Add(entry, index)
	end
	Add(model.profiles, #model.pages + 1)
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.at < b.at
	end)
	local list = {}
	for _, hit in ipairs(scored) do
		local top = ns.PanelNav.Top(model, hit.entry)
		if #list < 3 and not (top and top ~= hit.entry and (scoreOf[top] or 0) >= hit.score) then
			list[#list + 1] = hit.entry
		end
	end
	return list
end
