local ADDON_NAME, ns = ...

-- The search of the options window: the words of the field, which of the four tiers a row falls in, the order of the results, the pages whose names match,
-- and the index of Profiles and Flat UI setup. The window draws the results (Panel.lua).

local Search = {}
ns.PanelSearch = Search

-- The rows of the Profiles page, which have no rows in ns.PAGES.
Search.PROFILE_ROWS = { "Profile in use", "New profile", "Setup", "Copy from", "Delete profile", "Rename profile", "Reset profile", "In a dungeon", "In a raid",
	"In a battleground or arena", "Everywhere else", "Export profile", "Import profile", "Export trackers", "Import trackers", "Export by module" }

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

-- 1 the label starts with the words and holds them all, 2 the label holds them, 3 the label and the tip hold them, 4 the label, tip, section and page
-- name hold them. Nil when a word is in none.
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

-- Groups are { label, hits = { { tier, label, ... } } } in the order they were found. Orders the hits of each group by tier, then by the shorter label,
-- and the groups by their best tier. What ties keeps its place.
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

-- The pages whose names hold every word, in the order of the model: Home, the pages, Profiles.
function Search.Pages(words, model)
	local list = {}
	local function Add(entry)
		if entry and HasAll(entry.label:lower(), words) then
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

-- Up to three pages with the names closest to the words: a name that has the first three letters of a word. Best first.
function Search.Closest(words, model)
	local scored = {}
	local function Add(entry, at)
		local name, score = entry.label:lower(), 0
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
