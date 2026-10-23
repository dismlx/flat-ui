local _, ns = ...

-- Defensives on you: a row of icons for the shields, wards and protections other players cast on the player, each with its time left,
-- its charges and the name of the caster. The game draws them: an aura container of the game's own lists the buffs on the player
-- that match a list of spell IDs (CooldownData.lua), also while the game hides buffs from addon code in a fight. The parts of each
-- icon are made inside the function the game calls while it builds the button, because from then on the game closes the button to
-- addon code while it hides buffs. A change to those parts waits until the game says buffs are open; a change to the container
-- itself is allowed at any time. Where the game will not make the container, the same icons show out of combat from a read of the
-- player's buffs. The helpers are in one table, D, and the lines of /flatui check are Tracking.lua's.

local KEY = "defensives"
-- The name of the row among the saved spots of the movers.
local MOVER = "FlatUIDefensives"
-- The row hangs from the top left corner of the player frame: this far right and up. The room for the caster's name under the
-- icons is part of the height.
local OFFSET_X, OFFSET_Y = 0, 20
local ROOM = 16
local CROP = 0.08
local REREAD = 0.2
local TEST_TIME = 8
local MOST_LISTED, MOST_EXTERNAL = 6, 4
local GROUPS = { "listed", "external", "own" }
local MOST_OWN, MOST_ADDED, MAX_ID = 4, 40, 2147483647
local BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local CASTER = { useClassColors = true }
local NOTE_NO_POSITION = "Defensives on you: the personal resource display has no position, so the row is above the player frame."
local NOTE_REFUSED = "Defensives on you: the game refused the %s, so icons show without it."
local LINE_OUT = "Defensives on you: icons show out of combat only."
local LINE_OWN = "Defensives on you: Your own defensives is off here, since the game made no icon row."
local LINE_FRAME = "Defensives on you: the game's External Defensives frame is also on. Type /console externalDefensivesEnabled 0."
local HELP = {
	"/flatui check - what the game shows and hides where you stand",
	"/flatui check last - the lines of the last check",
	"/flatui test - three sample icons for Defensives on you",
	"/flatui defensives add 10060 - the spell ID of a buff, or a shift-clicked spell",
	"/flatui defensives remove 17 - a spell ID or a name",
	"/flatui defensives list",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local D = { list = {}, pending = {}, active = {}, refused = {}, icons = {} }

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Own(object)
	ns.Own[object] = true
	return object
end

local function Plain(value, kind)
	return not IsSecret(value) and type(value) == kind
end

-- A field of a frame, or nil when it is missing, cannot be read or is withheld.
local function Field(frame, key)
	local ok, value = pcall(function()
		return frame[key]
	end)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- The row's place ------------------------------------------------------------------------------------------------------------

function D.Holder()
	if not D.holder then
		local holder = Own(CreateFrame("Frame", nil, UIParent))
		holder:SetSize(1, 1)
		D.holder = holder
	end
	return D.holder
end

-- The highest bar of the personal resource display that is shown, or the display itself.
function D.TopBar(display)
	for _, key in ipairs(BARS) do
		local bar = Field(display, key)
		if bar ~= nil and not ns.Forbidden(bar) then
			local ok, shown = pcall(bar.IsShown, bar)
			if ok and not IsSecret(shown) and shown == true then
				return bar
			end
		end
	end
	return display
end

-- True when a frame anchored to something has a rectangle. A client that cannot say is taken to have one.
function D.Anchored(frame)
	local ok, left = pcall(frame.GetLeft, frame)
	return not ok or IsSecret(left) or left ~= nil
end

-- Hangs the holder from the player frame, the personal resource display or the spot of the movers. Returns which: "player",
-- "resource", "own" or "screen" (no player frame to hang from).
function D.Place()
	local holder = D.Holder()
	local place = Opt("place")
	holder:ClearAllPoints()
	if place == "own" then
		local x, y = ns.MoverSpot(MOVER, "BOTTOMLEFT")
		if x then
			holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y + ROOM)
			return "own"
		end
	end
	if place == "resource" then
		local display = PersonalResourceDisplayFrame
		if display ~= nil and not ns.Forbidden(display) then
			-- Over the Your buffs row when that hangs over the bars.
			local over = type(ns.OwnBuffsHolder) == "function" and ns.OwnBuffsHolder("above") or nil
			if over then
				holder:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 0, ROOM + 4)
			else
				holder:SetPoint("BOTTOMLEFT", D.TopBar(display), "TOPLEFT", 0, ROOM + 4)
			end
			if D.Anchored(holder) then
				ns.ClearNote(KEY, NOTE_NO_POSITION)
				return "resource"
			end
			holder:ClearAllPoints()
		end
		ns.Note(KEY, NOTE_NO_POSITION)
	else
		ns.ClearNote(KEY, NOTE_NO_POSITION)
	end
	local frame = PlayerFrame
	if frame ~= nil and not ns.Forbidden(frame) then
		holder:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", OFFSET_X, OFFSET_Y)
		return "player"
	end
	holder:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
	return "screen"
end

-- The parts of a button --------------------------------------------------------------------------------------------------------

local function EdgeColour()
	if ns.Borderless() or not Opt("iconBorder") then
		return 0, 0, 0, 0
	end
	local r, g, b = ns.Colour("general.border")
	return r, g, b, 1
end

-- The thickness of the border follows the general border thickness. It is worked out from the holder, so that no call is made on a button
-- to find out whether the border changed.
local function Thick()
	return ns.Pixels(D.Holder(), ns.Get("general.thickness"))
end

local function EdgeKey()
	local r, g, b, a = EdgeColour()
	return ("%s,%s,%s,%s,%s"):format(Thick(), r, g, b, a)
end

-- The four edges of the thin border, just inside the button.
function D.PaintEdges(parts)
	local button, edges = parts.button, parts.edges
	local thick = Thick()
	local r, g, b, a = EdgeColour()
	edges[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	edges[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
	edges[1]:SetHeight(thick)
	edges[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
	edges[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
	edges[2]:SetHeight(thick)
	edges[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -thick)
	edges[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, thick)
	edges[3]:SetWidth(thick)
	edges[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -thick)
	edges[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, thick)
	edges[4]:SetWidth(thick)
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(r, g, b, a)
	end
	parts.borderKey = EdgeKey()
end

-- Makes the parts of one button. Run by the game inside AddAuraGroup while the button is still open; nothing here may raise, and a
-- part the game refuses is left out and named in the status.
function D.Init(button)
	local parts = { button = button, casterOn = Opt("caster") }
	D.list[#D.list + 1] = parts
	pcall(button.EnableMouse, button, false)
	pcall(button.SetHideTooltipInCombat, button, true)
	pcall(button.SetSize, button, Opt("size"), Opt("size"))
	local function Part(name, fn)
		if not pcall(fn) then
			D.refused[name] = true
		end
	end
	Part("icon", function()
		local icon = Own(button:CreateTexture(nil, "ARTWORK", nil, 0))
		icon:SetAllPoints()
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		button:SetIcon(icon)
		parts.icon = icon
	end)
	Part("sweep", function()
		local sweep = Own(CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate"))
		sweep:SetAllPoints()
		sweep:SetDrawEdge(false)
		sweep:SetDrawBling(false)
		sweep:SetSwipeColor(0, 0, 0, 0.7)
		sweep:SetHideCountdownNumbers(true)
		parts.sweep = sweep
		button:SetDurationCooldown(sweep)
	end)
	local made, top = pcall(function()
		local frame = Own(CreateFrame("Frame", nil, button))
		frame:SetAllPoints()
		frame:SetFrameLevel(button:GetFrameLevel() + 3)
		return frame
	end)
	if not made then
		D.refused.count, D.refused.time, D.refused.name, D.refused.border = true, true, true, true
		return
	end
	parts.top = top
	Part("count", function()
		local count = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall"))
		count:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -2, 2)
		button:SetApplicationCount(count, nil)
		parts.count = count
	end)
	Part("time", function()
		local left = Own(top:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
		left:SetPoint("CENTER", top, "CENTER", 0, 0)
		parts.left = left
		-- The game's time text; the sweep's own numbers are the way out only when it is refused.
		if not pcall(button.SetDurationText, button, left, nil) and parts.sweep then
			pcall(parts.sweep.SetHideCountdownNumbers, parts.sweep, false)
			error("the time text was refused", 0)
		end
	end)
	Part("name", function()
		local name = Own(top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		name:SetPoint("TOP", button, "BOTTOM", 0, -1)
		parts.name = name
		if parts.casterOn then
			button:SetCasterName(name, CASTER)
		else
			name:Hide()
		end
	end)
	Part("border", function()
		local edges = {}
		for index = 1, 4 do
			local edge = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
			if edge.SetSnapToPixelGrid then
				pcall(edge.SetSnapToPixelGrid, edge, false)
			end
			edges[index] = edge
		end
		parts.edges = edges
		D.PaintEdges(parts)
	end)
end

-- Changes that wait for the game to open its buttons ------------------------------------------------------------------------------

-- Caster's name on or off on every button: ClearCasterName and a hidden font string, or SetCasterName again.
function D.ApplyCaster()
	local want = Opt("caster")
	for _, parts in ipairs(D.list) do
		if parts.name and parts.casterOn ~= want then
			local ok
			if want then
				ok = pcall(parts.button.SetCasterName, parts.button, parts.name, CASTER)
			else
				ok = pcall(parts.button.ClearCasterName, parts.button)
				pcall(parts.name.Hide, parts.name)
			end
			if ok then
				parts.casterOn = want
			else
				D.refused.name = true
			end
		end
	end
end

local function Layout()
	return { elementSpacing = Opt("spacing"), elementWidth = Opt("size"), elementHeight = Opt("size") }
end

-- The layout of the groups again where Icon size or Spacing has changed; the game places the slots from it; buttons already shown keep their size until /reload.
function D.ApplySize()
	local size, spacing = Opt("size"), Opt("spacing")
	if D.sized == size .. ":" .. spacing then
		return
	end
	D.sized = size .. ":" .. spacing
	for _, group in ipairs(GROUPS) do
		if D.container then
			pcall(D.container.SetAuraGroupLayout, D.container, group, Layout())
		end
	end
end

-- The border again where its thickness or colour has changed.
function D.ApplyBorder()
	for _, parts in ipairs(D.list) do
		if parts.edges and parts.borderKey ~= EdgeKey() then
			if not pcall(D.PaintEdges, parts) then
				D.refused.border = true
			end
		end
	end
end

D.apply = { caster = D.ApplyCaster, border = D.ApplyBorder, size = D.ApplySize }

-- Runs what waited, once the game says buffs are open.
function D.Flush()
	if next(D.pending) == nil or not T.Open() then
		return
	end
	local todo = D.pending
	D.pending = {}
	for kind in pairs(todo) do
		pcall(D.apply[kind])
	end
end

-- Does a change to the buttons now when the game says they are open, else when it does.
function D.Change(kind)
	if T.Open() then
		pcall(D.apply[kind])
		return
	end
	D.pending[kind] = true
	if not D.flushQueued then
		D.flushQueued = true
		ns.OutOfCombat(function()
			D.flushQueued = false
			D.Flush()
		end)
	end
end

-- The game's four restrictions that hide buffs: Combat, Encounter, Challenge mode and PvP match (types 0 to 3).
function D.Restricted()
	for kind = 0, 3 do
		if D.active[kind] then
			return true
		end
	end
	return false
end

function D.OnRestriction(kind, state)
	if Plain(kind, "number") and Plain(state, "number") and kind >= 0 and kind <= 3 then
		D.active[kind] = state ~= 0
	end
	if next(D.pending) ~= nil and not D.Restricted() then
		D.Flush()
		if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
			C_Timer.After(0, D.Flush)
		end
	end
end

-- What the restrictions are when the module starts.
function D.ReadRestrictions()
	local call = type(C_RestrictedActions) == "table" and C_RestrictedActions.IsAddOnRestrictionActive or nil
	for kind = 0, 3 do
		local answer = T.Ask(call, kind)
		D.active[kind] = answer == true
	end
end

-- The lists -----------------------------------------------------------------------------------------------------------------------

local function Copy(set)
	local copy = {}
	for id in pairs(set or {}) do
		copy[id] = true
	end
	return copy
end

local function Whole(value)
	return Plain(value, "number") and value > 0 and value <= MAX_ID and value == math.floor(value)
end

local function SpellName(id)
	local name = T.Ask(C_Spell and C_Spell.GetSpellName, id)
	return Plain(name, "string") and name ~= "" and name or nil
end

local function Name(id)
	return SpellName(id) or ("Spell " .. id)
end

-- The buffs added to the list and the buffs taken off it, kept for the account: two maps by spell ID, whole numbers only.
function D.Saved()
	local account = ns.Account()
	if type(account) ~= "table" then
		return nil
	end
	if type(account.abilities) ~= "table" then
		account.abilities = {}
	end
	local saved = account.abilities.defensives
	if type(saved) ~= "table" then
		saved = {}
		account.abilities.defensives = saved
	end
	for _, key in ipairs({ "added", "removed" }) do
		local old, map = saved[key], {}
		for id, yes in pairs(type(old) == "table" and old or {}) do
			if Whole(id) and yes == true then
				map[id] = true
			end
		end
		saved[key] = map
	end
	return saved
end

-- The buff IDs the lists name now: the game's list of abilities, and what was added, less what was taken off. A map by spell ID.
function D.Effective()
	local set = Copy(T.Listed())
	local saved = D.Saved()
	if saved then
		for id in pairs(saved.added) do
			set[id] = true
		end
		for id in pairs(saved.removed) do
			set[id] = nil
		end
	end
	return set
end

-- The IDs the second group leaves out: the list, and what was taken off it, so that a removed buff shows in neither group.
function D.Excluded()
	local set = D.Effective()
	local saved = D.Saved()
	for id in pairs(saved and saved.removed or {}) do
		set[id] = true
	end
	return set
end

-- The buff IDs of the defensives and immunities of the player's class, and the racial ones of every race, that the player casts on themself.
function D.OwnIDs()
	local set = {}
	local class = T.Ask(UnitClassBase, "player")
	if not Plain(class, "string") or type(ns.ABILITIES) ~= "table" then
		return set
	end
	for _, ability in ipairs(ns.ABILITIES) do
		if (ability.kind == 2 or ability.kind == 6) and (ability.class == class or ability.class == "ALL") then
			for _, id in ipairs(ability.buffs) do
				set[id] = true
			end
		end
	end
	return set
end

-- Gives both lists of the container their new maps, once combat is over. Where the game made no container the next read has them.
function D.ApplyLists()
	if D.path == "reading" then
		D.Queue()
		return
	end
	local container = D.container
	if not container then
		return
	end
	ns.OutOfCombat(function()
		local map = D.Effective()
		pcall(container.SetAuraGroupCandidateFilters, container, "listed", { includeSpellIDs = map })
		pcall(container.SetAuraGroupCandidateFilters, container, "external", { excludeSpellIDs = D.Excluded() })
	end)
end

-- Lines with the same name get the rank or other text the game shows beside the name.
local function Distinguish(rows)
	local seen = {}
	for _, row in ipairs(rows) do
		seen[row[2]] = (seen[row[2]] or 0) + 1
	end
	for _, row in ipairs(rows) do
		if seen[row[2]] > 1 then
			local subtext = T.Ask(C_Spell and C_Spell.GetSpellSubtext, row[1])
			if Plain(subtext, "string") and subtext ~= "" then
				row[2] = row[2] .. " (" .. subtext .. ")"
			end
		end
	end
end

local function ByName(rows)
	table.sort(rows, function(a, b)
		local first, second = a[2]:lower(), b[2]:lower()
		if first ~= second then
			return first < second
		end
		return a[1] < b[1]
	end)
	Distinguish(rows)
	return rows
end

-- The buffs of the game's list of abilities that are not on the list now, by name.
function ns.DefensiveCandidates()
	local rows, set, seen = {}, D.Effective(), {}
	for _, ability in ipairs(type(ns.ABILITIES) == "table" and ns.ABILITIES or {}) do
		if ability.kind == 3 or ability.kind == 9 or ((ability.kind == 2 or ability.kind == 6) and (ability.flags or ""):find("o", 1, true)) then
			for _, id in ipairs(ability.buffs) do
				if not set[id] and not seen[id] then
					seen[id] = true
					rows[#rows + 1] = { id, Name(id) }
				end
			end
		end
	end
	return ByName(rows)
end

-- The buffs on the list, by name, so that opening the list of Remove a spell also shows what is on it.
function ns.DefensiveListed()
	local rows = {}
	for id in pairs(D.Effective()) do
		rows[#rows + 1] = { id, Name(id) }
	end
	return ByName(rows)
end

-- Both work in a fight and with the page off: they change what is saved and nothing on screen. The container hears of it after combat.
function ns.DefensiveAdd(id)
	local saved = D.Saved()
	if not (Whole(id) and SpellName(id)) then
		return false, ('No spell found for "%s".'):format(tostring(id))
	end
	if not saved then
		return false, "Nothing can be saved yet."
	end
	if D.Effective()[id] then
		return false, ("%s is already listed."):format(Name(id))
	end
	local count = 0
	for _ in pairs(saved.added) do
		count = count + 1
	end
	if not saved.removed[id] and count >= MOST_ADDED then
		return false, ("%d added spells is the most."):format(MOST_ADDED)
	end
	-- A buff the game's list names comes back by dropping its removal; any other is added.
	if saved.removed[id] then
		saved.removed[id] = nil
	else
		saved.added[id] = true
	end
	D.ApplyLists()
	return true, ("Added %s."):format(Name(id))
end

function ns.DefensiveRemove(id)
	local saved = D.Saved()
	if not (Whole(id) and saved) or not D.Effective()[id] then
		return false, ("%s is not listed."):format(Whole(id) and Name(id) or tostring(id))
	end
	if saved.added[id] then
		saved.added[id] = nil
	else
		saved.removed[id] = true
	end
	D.ApplyLists()
	return true, ("Removed %s."):format(Name(id))
end

local function ParseID(text)
	local id = tonumber(text:match("^%d+$") or text:match("spell:(%d+)"))
	return Whole(id) and id or nil
end

-- The IDs on the list whose name is the one typed, in any capitals.
local function IDsNamed(text)
	local found, wanted = {}, text:lower()
	for id in pairs(D.Effective()) do
		local name = SpellName(id)
		if name and name:lower() == wanted then
			found[#found + 1] = id
		end
	end
	table.sort(found)
	return found
end

function D.Slash(rest)
	local word, text = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	word = word:lower()
	if word == "add" and text ~= "" then
		local id = ParseID(text)
		if not id then
			print(('No spell found for "%s".'):format(text))
			return
		end
		print(select(2, ns.DefensiveAdd(id)))
	elseif word == "remove" and text ~= "" then
		local id = ParseID(text)
		local ids = id and { id } or IDsNamed(text)
		if #ids == 0 then
			print(('No spell found for "%s".'):format(text))
			return
		end
		for _, each in ipairs(ids) do
			print(select(2, ns.DefensiveRemove(each)))
		end
	elseif word == "list" then
		local names, order = {}, {}
		for _, row in ipairs(ns.DefensiveListed()) do
			local name = SpellName(row[1]) or row[2]
			if not names[name] then
				names[name] = {}
				order[#order + 1] = name
			end
			table.insert(names[name], row[1])
		end
		if #order == 0 then
			print("No buffs listed.")
		end
		for _, name in ipairs(order) do
			table.sort(names[name])
			print(("%s (%s)"):format(name, table.concat(names[name], ", ")))
		end
	else
		for index = #HELP - 2, #HELP do
			print(HELP[index])
		end
	end
end

-- The game's container --------------------------------------------------------------------------------------------------------------

-- Three groups of buttons on one container for the player: the buffs the lists name that other players cast, every external defensive
-- the game flags that the lists do not name, and the defensives the player casts on themself.
function D.Build()
	D.tried = true
	local holder = D.Holder()
	local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
	if not ok or type(container) ~= "table" then
		D.path = "reading"
		return
	end
	Own(container)
	local set = D.Effective()
	local made, err = pcall(function()
		container:SetEditModePreviewEnabled(false)
		container:SetUnit("player")
		container:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
		container:AddAuraGroup("listed", "HELPFUL|!PLAYER", { candidateFilters = { includeSpellIDs = Copy(set) }, maxFrameCount = MOST_LISTED,
			layout = Layout(), initializeFrame = D.InitCall })
		container:AddAuraGroup("external", "HELPFUL|EXTERNAL_DEFENSIVE", { candidateFilters = { excludeSpellIDs = D.Excluded() }, maxFrameCount = MOST_EXTERNAL,
			layout = Layout(), initializeFrame = D.InitCall })
	end)
	D.container = container
	D.sized = Opt("size") .. ":" .. Opt("spacing")
	if made then
		-- The buffs the player casts on themself, off until Your own defensives is on; a refusal of this group leaves the other two.
		local ownMade = pcall(function()
			container:AddAuraGroup("own", "HELPFUL|PLAYER", { candidateFilters = { includeSpellIDs = D.OwnIDs() }, maxFrameCount = MOST_OWN,
				layout = Layout(), initializeFrame = D.InitCall })
			container:SetAuraGroupEnabled("own", false)
		end)
		D.ownRefused = not ownMade
		D.path = "container"
		return
	end
	D.failure = tostring(err)
	D.Groups(false)
	D.path = "reading"
end

-- The function the game calls for each button.
function D.InitCall(button)
	local ok, err = pcall(D.Init, button)
	if not ok then
		D.refused.icon = true
		D.failure = tostring(err)
	end
end

-- Turns the groups on or off; the third is on only with Your own defensives. A container call, allowed at any time.
function D.Groups(on)
	local container = D.container
	if not container then
		return
	end
	for _, group in ipairs(GROUPS) do
		pcall(container.SetAuraGroupEnabled, container, group, on and (group ~= "own" or Opt("own") == true))
	end
end

-- The reading path -------------------------------------------------------------------------------------------------------------------

-- The colour of a class, or nil.
local function ClassColour(unit)
	local class = T.Ask(UnitClassBase, unit)
	local colours = RAID_CLASS_COLORS
	local colour = Plain(class, "string") and type(colours) == "table" and colours[class] or nil
	if type(colour) == "table" and Plain(colour.r, "number") and Plain(colour.g, "number") and Plain(colour.b, "number") then
		return colour.r, colour.g, colour.b
	end
end

-- The buffs on the player that the list names and the player did not cast, from one read: plain tables only. Nothing when the game
-- hides buffs.
function D.Read()
	if not T.Open() then
		return nil
	end
	local call = type(C_UnitAuras) == "table" and C_UnitAuras.GetUnitAuras or nil
	if type(call) ~= "function" then
		return nil
	end
	local ok, auras = pcall(call, "player", "HELPFUL")
	if not ok or IsSecret(auras) or type(auras) ~= "table" then
		return nil
	end
	local set, found = D.Effective(), {}
	for _, aura in ipairs(auras) do
		if type(aura) == "table" and not IsSecret(aura) then
			local read, id, source, expires, length, file = pcall(function()
				return aura.spellId, aura.sourceUnit, aura.expirationTime, aura.duration, aura.icon
			end)
			local from = Plain(source, "string") and source or nil
			if read and Plain(id, "number") and set[id] and from ~= "player" and ns.Finite(expires) and ns.Finite(length) then
				found[#found + 1] = { id = id, source = from, expires = expires, length = length,
					file = (Plain(file, "number") or Plain(file, "string")) and file or nil }
			end
		end
	end
	table.sort(found, function(a, b)
		return a.id < b.id
	end)
	return found
end

function D.Icon(index)
	local icon = D.icons[index]
	if not icon then
		icon = ns.IconNew(D.Holder())
		if not icon then
			return nil
		end
		local name = Own(icon.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
		name:SetPoint("TOP", icon.frame, "BOTTOM", 0, -1)
		icon.name = name
		D.icons[index] = icon
	end
	return icon
end

-- One pass of the reading path: the icons that match what was read, and none when nothing could be read.
function D.Pass()
	D.scheduled = false
	if D.path ~= "reading" or not ns.Enabled(KEY) or D.testing then
		return
	end
	local found = D.Read() or {}
	local shown = {}
	for index = 1, math.min(#found, MOST_LISTED) do
		local item, icon = found[index], D.Icon(index)
		if icon then
			ns.IconSet(icon, item.file, item.expires - item.length, item.length, { kind = 3, border = Opt("iconBorder") })
			local name = nil
			if Opt("caster") and item.source then
				name = T.Ask(UnitName, item.source)
			end
			if Plain(name, "string") then
				icon.name:SetText(name)
				icon.name:SetTextColor(1, 1, 1)
				local r, g, b = ClassColour(item.source)
				if r then
					icon.name:SetTextColor(r, g, b)
				end
				icon.name:Show()
			else
				icon.name:Hide()
			end
			shown[#shown + 1] = icon
		end
	end
	if #found > 0 then
		D.seen = "readable"
	end
	for index = #shown + 1, #D.icons do
		ns.IconClear(D.icons[index])
		D.icons[index].name:Hide()
	end
	ns.IconLayout(shown, D.Holder(), Opt("size"), Opt("spacing"), "right")
end

function D.Queue()
	if D.scheduled then
		return
	end
	D.scheduled = true
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(REREAD, D.Pass)
	else
		D.Pass()
	end
end

function D.StartReading()
	if not D.watcher then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or type(frame) ~= "table" then
			return
		end
		D.watcher = Own(frame)
		-- The payload is not read where the game sends the event for the player alone: it may be withheld.
		frame:SetScript("OnEvent", function(_, _, unit)
			if D.path == "reading" and (D.playerOnly or (Plain(unit, "string") and unit == "player")) then
				D.Queue()
			end
		end)
	end
	local frame = D.watcher
	D.playerOnly = frame.RegisterUnitEvent ~= nil and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")
	if not D.playerOnly then
		pcall(frame.RegisterEvent, frame, "UNIT_AURA")
	end
	D.Queue()
end

function D.StopReading()
	if D.watcher then
		pcall(D.watcher.UnregisterAllEvents, D.watcher)
	end
	for _, icon in ipairs(D.icons) do
		ns.IconClear(icon)
		icon.name:Hide()
	end
end

-- Putting it all in place -------------------------------------------------------------------------------------------------------------

-- True when the game has the call that reads a unit's buffs. Without it the module makes nothing.
function D.Capable()
	return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function"
end

function D.Sync()
	local on = D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off"
	if not on then
		if D.holder and not D.testing then
			D.holder:Hide()
		end
		D.Groups(false)
		D.StopReading()
		return
	end
	local holder = D.Holder()
	holder:Show()
	D.Place()
	if not D.tried then
		D.Build()
	end
	if D.path == "container" then
		D.Groups(true)
		D.Change("caster")
		D.Change("border")
		D.Change("size")
	elseif D.path == "reading" then
		D.StartReading()
	end
end

function D.Refresh()
	if D.Capable() then
		ns.OutOfCombat(D.Sync)
	end
end

-- True while the Own spot has a handle in the movers.
function ns.DefensivesOwnShown()
	return ns.Enabled(KEY) and Opt("place") == "own"
end

-- The movers set or put back the spot.
function ns.DefensivesMoved()
	if D.holder and ns.Enabled(KEY) then
		ns.OutOfCombat(D.Place)
	end
end

function D.Start()
	if not D.Capable() then
		return
	end
	D.ReadRestrictions()
	T.Listen()
	D.Sync()
end

-- The check and the test ---------------------------------------------------------------------------------------------------------------

-- What /flatui check says about this module, and about a listed buff on the player.
function ns.DefensivesPathText()
	if not D.Capable() then
		return "Defensives on you: the game gives no buff information."
	elseif not (ns.Enabled(KEY) and Opt("place") ~= "off") then
		return "Defensives on you: off."
	elseif D.path == "container" then
		return "Defensives on you: the game's own icon row."
	elseif D.path == "reading" then
		return "Defensives on you: out of combat only, the game made no icon row."
	end
	return "Defensives on you: not started."
end

function ns.DefensivesSeenText()
	if not T.Open() then
		return "hidden by the game right now"
	end
	for _, id in ipairs(T.ListedIDs()) do
		if ns.UnitBuff("player", id) then
			return "seen readable"
		end
	end
	return "not seen"
end

function D.Check(rest)
	if (rest or ""):lower():match("^%s*last%s*$") then
		local record = ns.CheckLast()
		if not record then
			print("No check yet. Type /flatui check.")
			return
		end
		if record.when then
			print("Check of " .. record.when)
		end
		for _, line in ipairs(record.lines) do
			print(line)
		end
		return
	end
	T.OnReply = function(text)
		print(text)
	end
	for _, line in ipairs(ns.CheckLines()) do
		print(line)
	end
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

-- Ends a test: the sweeps are cleared, the icons hidden, and what the game did is said.
function D.EndTest(token)
	local test = D.testing
	if not test or (token and test ~= token) then
		return
	end
	D.testing = nil
	local done = 0
	for _, icon in ipairs(test.list) do
		pcall(icon.cooldown.SetCooldown, icon.cooldown, 0, 0)
		done = done + (icon.done or 0)
		ns.IconClear(icon)
	end
	local sound = ns.IconRow.sound
	local text = sound == "played" and "played" or (sound == nil and "not tried" or "the game played no sound")
	print(("Test: the sweep ended on %d of 3 icons. Sound: %s."):format(done, text))
	if D.holder and not (ns.Enabled(KEY) and Opt("place") ~= "off") then
		D.holder:Hide()
	end
end

function D.Test()
	if not D.Capable() then
		print("Defensives on you: the game gives no buff information.")
		return
	end
	if InCombatLockdown() then
		print("Defensives on you: the test shows out of combat only.")
		return
	end
	if D.testing then
		D.EndTest()
	end
	local holder = D.Holder()
	D.Place()
	holder:Show()
	local list = {}
	for index = 1, 3 do
		D.sample = D.sample or {}
		local icon = D.sample[index] or ns.IconNew(holder)
		if not icon then
			return
		end
		D.sample[index] = icon
		icon.done = 0
		list[index] = icon
	end
	ns.IconRow.sound = nil
	local now = Now()
	for index, icon in ipairs(list) do
		ns.IconSample(icon, index, now, 2 * index, KEY)
	end
	ns.IconLayout(list, holder, Opt("size"), Opt("spacing"), "right")
	local test = { list = list }
	D.testing = test
	print("Defensives on you: three sample icons for 8 seconds.")
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(TEST_TIME, function()
			D.EndTest(test)
		end)
	end
end

function D.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if D.path == "reading" then
		lines[#lines + 1] = LINE_OUT
		if Opt("own") == true then
			lines[#lines + 1] = LINE_OWN
		end
	elseif D.ownRefused and Opt("own") == true then
		lines[#lines + 1] = LINE_OWN
	end
	local parts = {}
	for _, name in ipairs({ "icon", "sweep", "count", "time", "name", "border" }) do
		if D.refused[name] then
			parts[#parts + 1] = name == "sweep" and "sweep" or (name == "name" and "caster's name" or (name == "time" and "time left" or name))
		end
	end
	for _, name in ipairs(parts) do
		lines[#lines + 1] = NOTE_REFUSED:format(name)
	end
	local on = T.Ask(GetCVarBool, "externalDefensivesEnabled")
	if on == true then
		lines[#lines + 1] = LINE_FRAME
	end
	return lines
end

ns.Register(KEY, {
	label = "Defensives on you",
	counted = false,
	Start = D.Start,
	Refresh = D.Refresh,
	Resized = D.Refresh,
	events = {
		PLAYER_ENTERING_WORLD = function()
			D.Refresh()
		end,
		ADDON_RESTRICTION_STATE_CHANGED = function(kind, state)
			D.OnRestriction(kind, state)
		end,
		EDIT_MODE_LAYOUTS_UPDATED = function()
			D.Refresh()
		end,
	},
	slash = { check = D.Check, defensives = D.Slash, test = function(rest)
		D.Test(rest)
		if ns.OwnBuffsTest then
			ns.OwnBuffsTest()
		end
		if ns.PartyTest then
			ns.PartyTest()
		end
		if ns.EnemyTest then
			ns.EnemyTest()
		end
	end },
	help = HELP,
	Status = D.Status,
})

ns.DefensivesModule = D
