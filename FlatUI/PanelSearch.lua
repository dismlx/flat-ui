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

local function Name(entry)
	local module = entry.page and entry.page.moduleLabel
	return (type(module) == "string" and (entry.label .. " " .. module) or entry.label):lower()
end

function Search.Pages(words, model)
	local list = {}
	local function Add(entry)
		if entry and HasAll(Name(entry), words) then
			list[#list + 1] = entry
		end
	end
	Add(model.home)
	for _, entry in ipairs(model.pages) do
		Add(entry)
	end
	Add(model.profiles)
	return list
end

function Search.Closest(words, model)
	local scored = {}
	local function Add(entry, at)
		local name, score = Name(entry), 0
		for _, word in ipairs(words) do
			if #word >= 3 and name:find(word:sub(1, 3), 1, true) then
				score = score + 1
			end
		end
		if score > 0 then
			scored[#scored + 1] = { entry = entry, score = score, at = at }
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
	for index = 1, math.min(3, #scored) do
		list[index] = scored[index].entry
	end
	return list
end
