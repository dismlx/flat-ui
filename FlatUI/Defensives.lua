local _, ns = ...

-- Defensives on you: a row of icons for the shields, wards and protections other players cast on the player, each with its time left,
-- its charges and the name of the caster. The game draws them: an aura container of the game's own lists the buffs on the player
-- that match a list of spell IDs (CooldownData.lua), also while the game hides buffs from addon code in a fight. The parts of each
-- icon are made inside the function the game calls while it builds the button, because from then on the game closes the button to
-- addon code while it hides buffs. A change to those parts, and Icon size on the buttons already shown, waits until the game says buffs
-- are open; a change to the container itself (its layout of sizes and spacing) is allowed at any time. Where the game will not make the container, the same icons show out of combat from a read of the
-- player's buffs. The helpers are in one table, D, and the lines of /flatui check are Tracking.lua's.
-- Buff tooltips (On by default, as on Your buffs) gives the game's buttons the game's own tooltip on hover and never a click, so clicks go
-- through to the world; Out of combat only has the game hide it in a fight. The samples of test mode follow Icon border, Borderless and the
-- border colour as the real icons do, and with Caster's name on carry the names of test mode's party under them. Sound when one lands (None by
-- default) has the game play a sound as a listed defensive you do not know yourself comes on you, also in a fight (D.SyncSounds).
-- Flash when one lands (on by default) gives each icon a quick white flash as its defensive lands: on the game's buttons an animation the game
-- plays itself as the button shows (AddAuraShownAnimation), so also in a fight; on the icons of a read, a flash of IconRow.lua. The time left
-- turns amber in its last 5 seconds, coloured by the game (a colour curve on the time text, D.TimeOptions). The samples of the test and of
-- test mode flash as they appear and play Sound when one lands, not a sound at the end of their sweep. Out of combat with test mode off and no
-- defensive on you (none of the game's buttons shows), a change of Place, Icon size, Spacing, Caster's name, Icon border or Flash when one
-- lands, or a pick of either sound, shows the samples for 4 seconds in the new look and place, with no line in the chat
-- (ns.DefensivesLookChanged); they flash as they come, and a further change redraws them with their sweeps running on and flashes them again
-- only for Flash when one lands or a sound. The row read out of combat is read again as a test or such a preview ends. Sound when one ends
-- (None by default) has the game play a sound as a listed defensive you do not know yourself leaves you (trigger Removed), and /flatui test
-- icons plays it once as its samples go; its line in the chat names each sound and whether the game played it. The numbers on an icon, the
-- time left and the charges, follow Icon size: today's heights at the default of 32, grown and shrunk with it (D.TextSize), on the game's
-- buttons, the icons of a read and the samples.

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
-- How long the samples a change of the look shows stay after the last change.
local PREVIEW = 4
-- The flash of a defensive that lands: from this opacity to none in FLASH seconds. The time left is amber under LOW seconds, in the amber
-- of the trackers' low.
local FLASH_FROM, FLASH = 0.8, 0.5
local LOW, AMBER = 5, { 1, 0.7, 0.2 }
-- The sound kits of Sound when one lands, for the samples: the game plays the files of these kits for a real one (TrackerSound.lua).
local KITS = { raid = 8959, alarm = 12889, whisper = 37666 }
local MOST_LISTED, MOST_EXTERNAL = 6, 4
local GROUPS = { "listed", "external", "own" }
local MOST_OWN, MOST_ADDED, MAX_ID = 4, 40, 2147483647
local BARS = { "HealthBarsContainer", "PowerBar", "AlternatePowerBar" }
local CASTER = { useClassColors = true }
local NOTE_NO_POSITION = "Defensives on you: the personal resource display has no position, so the row is above the player frame."
local NOTE_REFUSED = "Defensives on you: the game refused the %s, so icons show without it."
local NOTE_SIZE = "Defensives on you: the game refused a new icon size, so icons already shown keep their old one until you log in again."
local NOTE_MOUSE = "Defensives on you: the game refused a mouse setting of the icons, so clicks or tooltips may not work."
local NOTE_READING = "Defensives on you: Buff tooltips has no effect while the game makes no icon row."
local LINE_OUT = "Defensives on you: icons show out of combat only."
local LINE_OWN = "Defensives on you: Your own defensives is off here, since the game made no icon row."
local LINE_FRAME = "Defensives on you: the game's External Defensives frame is also on. Type /console externalDefensivesEnabled 0."
local HELP = {
	"/flatui check - what the game shows and hides where you stand",
	"/flatui check last - the lines of the last check",
	"/flatui test icons - three sample icons for Defensives on you, for 8 seconds",
	"/flatui defensives add 10060 - the spell ID of a buff, or a shift-clicked spell",
	"/flatui defensives remove 17 - a spell ID or a name",
	"/flatui defensives list",
}

local IsSecret = ns.IsSecret
local T = ns.Tracking
local TM = ns.TestMode
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

-- Buff tooltips: the game's tooltip on hover and never a click, as Your buffs does (OwnBuffs.lua's Mouse; Blizzard_CooldownViewer/
-- CooldownViewer.lua:326-328). Out of combat only keeps the hover and has the game hide the tooltip in a fight (Blizzard_AuraButton.lua:177-183);
-- Off takes the mouse away, so the row is as it was before the row came. A refused call leaves parts.tips empty, so ApplyTips tries again, and the
-- status names it.
function D.Mouse(parts)
	local button, tips = parts.button, Opt("tooltips")
	local ok = pcall(button.SetMouseClickEnabled, button, false)
	ok = pcall(button.SetMouseMotionEnabled, button, tips ~= "off") and ok
	ok = pcall(button.SetHideTooltipInCombat, button, tips ~= "on") and ok
	parts.tips = ok and tips or nil
	D.refused.tips = nil
	for _, other in ipairs(D.list) do
		if other.tips == nil then
			D.refused.tips = true
		end
	end
end

-- The options of the game's time text: white, amber in the last LOW seconds. The game colours the text by a step curve of the time left
-- (DurationTextBindingProperty.RemainingDuration), so also in a fight. Made once; nil where the game has no colour curve.
function D.TimeOptions()
	if D.timeOptions == nil then
		local ok, options = pcall(function()
			local curve = C_CurveUtil.CreateColorCurve()
			curve:SetType(Enum.LuaCurveType.Step)
			curve:AddPoint(0, CreateColor(AMBER[1], AMBER[2], AMBER[3], 1))
			curve:AddPoint(LOW, CreateColor(1, 1, 1, 1))
			return { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
		end)
		D.timeOptions = ok and type(options) == "table" and options or false
	end
	return D.timeOptions or nil
end

-- The numbers on an icon follow Icon size: the time left (NumberFontNormal) and the charges (NumberFontNormalSmall) at their own heights at
-- the default Icon size of BASE, grown and shrunk with it, 8 to 24 (IconRow.lua). Gives the two heights for size.
D.BASE = 32
function D.TextSize(size)
	return ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormal", 14), size, D.BASE),
		ns.IconNumberHeight(ns.IconFontHeight("NumberFontNormalSmall", 12), size, D.BASE)
end

-- The time left and the charges of a button at the heights of size; true when the game took them.
function D.SizeText(parts, size)
	local time, count = D.TextSize(size)
	local ok = true
	if parts.left then
		ok = pcall(parts.left.SetTextHeight, parts.left, time) and ok
	end
	if parts.count then
		ok = pcall(parts.count.SetTextHeight, parts.count, count) and ok
	end
	if ok then
		parts.textSize = size
	end
	return ok
end

-- Makes the parts of one button. Run by the game inside AddAuraGroup while the button is still open; nothing here may raise, and a
-- part the game refuses is left out and named in the status.
function D.Init(button)
	local parts = { button = button, casterOn = Opt("caster") }
	D.list[#D.list + 1] = parts
	D.Mouse(parts)
	parts.size = pcall(button.SetSize, button, Opt("size"), Opt("size")) and Opt("size") or nil
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
		D.refused.count, D.refused.time, D.refused.name, D.refused.border, D.refused.flash = true, true, true, true, true
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
		-- The game's time text, amber in its last seconds, else white; the sweep's own numbers are the way out only when it is refused.
		local options = D.TimeOptions()
		local bound = options ~= nil and pcall(button.SetDurationText, button, left, options)
		if not bound and not pcall(button.SetDurationText, button, left, nil) and parts.sweep then
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
	-- A white square over the button, at no opacity but while its fade plays: the game plays the fade as the button shows, as a defensive
	-- lands. The square is a child of the button, as the game asks of the regions of such an animation.
	Part("flash", function()
		local flash = Own(top:CreateTexture(nil, "OVERLAY", nil, 7))
		flash:SetAllPoints(button)
		flash:SetColorTexture(1, 1, 1, 1)
		flash:SetAlpha(0)
		local group = flash:CreateAnimationGroup()
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(FLASH_FROM)
		fade:SetToAlpha(0)
		fade:SetDuration(FLASH)
		group:SetToFinalAlpha(true)
		button:AddAuraShownAnimation(group)
		parts.flash = flash
		parts.flashOn = Opt("flash") ~= false
		flash:SetShown(parts.flashOn)
	end)
	pcall(D.SizeText, parts, Opt("size"))
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

-- The layout of the groups again where Icon size or Spacing has changed, from which the game places the slots, and the new size on every
-- button already made (its parts are set on all its points and follow). Run while buttons are open (D.Change); a button that refuses keeps
-- its size, is tried again at the next change and is named in the status.
function D.ApplySize()
	local size, spacing = Opt("size"), Opt("spacing")
	if D.sized ~= size .. ":" .. spacing then
		D.sized = size .. ":" .. spacing
		for _, group in ipairs(GROUPS) do
			if D.container then
				pcall(D.container.SetAuraGroupLayout, D.container, group, Layout())
			end
		end
	end
	local refused = nil
	for _, parts in ipairs(D.list) do
		if parts.size ~= size then
			if pcall(parts.button.SetSize, parts.button, size, size) then
				parts.size = size
			else
				refused = true
			end
		end
		-- The numbers on the icon grow and shrink with it; refused, they are tried again at the next change.
		if parts.textSize ~= size then
			D.SizeText(parts, size)
		end
	end
	D.refused.size = refused
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

-- Buff tooltips again where the setting has changed.
function D.ApplyTips()
	for _, parts in ipairs(D.list) do
		if parts.tips ~= Opt("tooltips") then
			D.Mouse(parts)
		end
	end
end

-- Flash when one lands again where it has changed: the square shows or hides, and the fade the game plays stays registered.
function D.ApplyFlash()
	local want = Opt("flash") ~= false
	for _, parts in ipairs(D.list) do
		if parts.flash and parts.flashOn ~= want then
			if pcall(parts.flash.SetShown, parts.flash, want) then
				parts.flashOn = want
			else
				D.refused.flash = true
			end
		end
	end
end

D.apply = { caster = D.ApplyCaster, border = D.ApplyBorder, size = D.ApplySize, tips = D.ApplyTips, flash = D.ApplyFlash }

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
	D.QueueSounds()
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
	local read = D.Read()
	local found = read or {}
	local shown = {}
	-- A defensive that was not in the last read (by its spell and its end, so a new cast counts) flashes as it lands; none at the first read,
	-- nor at the first after the game hid buffs.
	local before, now = D.landed, {}
	D.landed = read and now or nil
	for index = 1, math.min(#found, MOST_LISTED) do
		local item, icon = found[index], D.Icon(index)
		if icon then
			-- No kind: the border keeps the colour of the page and Borderless hides it, as on the game's buttons (EdgeColour).
			ns.IconSet(icon, item.file, item.expires - item.length, item.length, { border = Opt("iconBorder") })
			ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
			local landing = item.id .. ":" .. item.expires
			now[landing] = true
			if before and not before[landing] and Opt("flash") ~= false then
				ns.IconFlash(icon)
			end
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
	D.landed = nil
	for _, icon in ipairs(D.icons) do
		ns.IconClear(icon)
		icon.name:Hide()
	end
end

-- Sound when one lands ------------------------------------------------------------------------------------------------------------------

-- Sound when one lands (None by default): the game plays a sound as a listed defensive comes on the player, also in a fight, where the buff
-- cannot be read: a sound registered with the game plays even while it withholds the aura from addons (C_UnitAuras.AddAuraSound with trigger
-- Added, UnitAuraDocumentation.lua:11-27), as the trackers' sounds do (TrackerSound.lua, whose files the three sounds are). One registration for
-- each ID of the list that the player does not know as a spell (C_SpellBook.IsSpellKnown, else IsPlayerSpell), so a priest's own Power Word:
-- Shield stays silent. AddAuraSound has restrictions, so the registrations change only out of combat and while aura values are open
-- (C_Secrets.ShouldAurasBeSecret); a change that has to wait is tried again on a frame of this file's own at the end of a fight or of a
-- restriction, also while the page is off, so the registrations go once it is turned off. Sound when one ends (None by default) is one more
-- registration for each such ID, with trigger Removed, as the trackers' Sound when it drops is: the game plays it as the defensive leaves the
-- player. sounds: by spell ID and trigger ("10060:Added"), { id, file }. TRIGGERS: the row of each trigger.
D.sounds = {}
D.TRIGGERS = { Added = "sound", Removed = "endSound" }

function D.Knows(id)
	local known = nil
	if type(C_SpellBook) == "table" then
		known = T.Ask(C_SpellBook.IsSpellKnown, id)
	end
	if type(known) ~= "boolean" then
		known = T.Ask(IsPlayerSpell, id)
	end
	return known == true
end

function D.Withheld()
	local call = type(C_Secrets) == "table" and C_Secrets.ShouldAurasBeSecret or nil
	if type(call) ~= "function" then
		return false
	end
	local ok, answer = pcall(call)
	return ok and not IsSecret(answer) and answer == true
end

-- One D.SyncSounds out of combat, however often it is asked for meanwhile.
function D.QueueSounds()
	if D.soundQueued then
		return
	end
	D.soundQueued = true
	ns.OutOfCombat(function()
		D.soundQueued = false
		D.SyncSounds()
	end)
end

-- The wait for aura values to be open: the frame hears the end of a fight, of a restriction and a loading screen only while a change waits.
function D.SoundsWait(on)
	if on == (D.soundWaiting == true) then
		return
	end
	D.soundWaiting = on
	if on and not D.soundFrame then
		local frame = Own(CreateFrame("Frame"))
		frame:SetScript("OnEvent", function()
			if D.soundWaiting then
				D.QueueSounds()
			end
		end)
		D.soundFrame = frame
	end
	local frame = D.soundFrame
	for _, event in ipairs(frame and { "PLAYER_REGEN_ENABLED", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_ENTERING_WORLD" } or {}) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
end

-- Makes the registrations match the page: drops the ones not wanted now or of another sound, adds the missing ones.
function D.SyncSounds()
	local auras = type(C_UnitAuras) == "table" and C_UnitAuras or {}
	local add, remove = auras.AddAuraSound, auras.RemoveAuraSound
	if type(add) ~= "function" then
		return
	end
	if InCombatLockdown() or D.Withheld() then
		D.SoundsWait(true)
		return
	end
	D.SoundsWait(false)
	-- The file of each trigger whose row has a sound: Added for Sound when one lands, Removed for Sound when one ends.
	local triggers = type(Enum) == "table" and Enum.UnitAuraSoundTrigger or nil
	local files = {}
	if D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off" and type(ns.TrackerSoundFile) == "function" then
		for name, row in pairs(D.TRIGGERS) do
			local file = ns.TrackerSoundFile(Opt(row))
			local trigger = type(triggers) == "table" and triggers[name] or nil
			-- Removed only where the game names it, so that a missing trigger is never taken for another.
			if file and (trigger ~= nil or name == "Added") then
				files[name] = { file = file, trigger = trigger }
			end
		end
	end
	local wanted = {}
	if next(files) ~= nil then
		for id in pairs(D.Effective()) do
			if Whole(id) and not D.Knows(id) then
				for name, want in pairs(files) do
					wanted[id .. ":" .. name] = { id = id, file = want.file, trigger = want.trigger }
				end
			end
		end
	end
	for key, made in pairs(D.sounds) do
		if not wanted[key] or made.file ~= wanted[key].file then
			D.sounds[key] = nil
			if type(remove) == "function" then
				pcall(remove, made.id)
			end
		end
	end
	D.refused.sound = nil
	for key, want in pairs(wanted) do
		if not D.sounds[key] then
			local ok, handle = pcall(add, want.trigger, { unitToken = "player", spellID = want.id, soundFileID = want.file, outputChannel = "Master",
				throttleSeconds = 1 })
			if ok and Plain(handle, "number") then
				D.sounds[key] = { id = handle, file = want.file }
			else
				D.refused.sound = true
			end
		end
	end
end

-- Putting it all in place -------------------------------------------------------------------------------------------------------------

-- True when the game has the call that reads a unit's buffs. Without it the module makes nothing.
function D.Capable()
	return type(C_UnitAuras) == "table" and type(C_UnitAuras.GetUnitAuras) == "function"
end

function D.Sync()
	local on = D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off"
	D.QueueSounds()
	if not on then
		D.Held()
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
		D.Change("tips")
		D.Change("flash")
	elseif D.path == "reading" then
		D.StartReading()
	end
	D.Held()
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

-- The casters of the three samples, test mode's party (TestUnits.lua): a priest's shield, a paladin's protection and a warlock's ward.
D.CASTERS = { { "Eli", "PRIEST" }, { "Mara", "PALADIN" }, { "Ivo", "WARLOCK" } }

-- The look of a sample: the border of the page's colour, which Borderless and Icon border off take away, as on the game's buttons (EdgeColour).
function D.SampleLook()
	return { border = Opt("iconBorder") ~= false }
end

-- The caster's name under sample `index` while Caster's name is on, in the colour of the caster's class, as under the game's buttons.
function D.SampleName(icon, index)
	if not icon.name then
		local made, name = pcall(icon.frame.CreateFontString, icon.frame, nil, "OVERLAY", "GameFontNormalSmall")
		if not made or type(name) ~= "table" then
			return
		end
		Own(name)
		name:SetPoint("TOP", icon.frame, "BOTTOM", 0, -1)
		icon.name = name
	end
	local caster = D.CASTERS[index]
	if not (caster and Opt("caster") and ns.Enabled(KEY) and Opt("place") ~= "off") then
		icon.name:Hide()
		return
	end
	icon.name:SetText(caster[1])
	local colours = RAID_CLASS_COLORS
	local colour = type(colours) == "table" and colours[caster[2]] or nil
	if type(colour) == "table" and Plain(colour.r, "number") and Plain(colour.g, "number") and Plain(colour.b, "number") then
		icon.name:SetTextColor(colour.r, colour.g, colour.b)
	else
		icon.name:SetTextColor(1, 1, 1)
	end
	icon.name:Show()
end

-- Ends a test: the sweeps are cleared, the icons hidden, and what the game did is said, with Sound when one ends played once as the samples go.
-- cut: a new test takes its place, and plays its own sounds, so this one plays none.
function D.EndTest(token, cut)
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
		if icon.name then
			icon.name:Hide()
		end
	end
	if not test.quiet then
		-- Sound when one ends, once, as the samples go, as a real one leaving does.
		local ends = Opt("endSound")
		local line = ("Defensives on you: the sweep ended on %d of 3 icons. Sound when one lands: %s."):format(done,
			D.SoundWords(Opt("sound"), test.sound))
		if KITS[ends] and not cut then
			line = line .. (" Sound when one ends: %s."):format(D.SoundWords(ends, D.SampleSound(ends)))
		end
		print(line)
	end
	if D.holder and not (ns.Enabled(KEY) and Opt("place") ~= "off") then
		D.holder:Hide()
	end
	-- The read stood down while the samples showed: what is on the player now is read again.
	if D.path == "reading" then
		D.Queue()
	end
end

-- The words of a sound row in the line of the test: the sound's name and what the game did, or None.
function D.SoundWords(word, result)
	local kit = KITS[word]
	if not kit then
		return "None"
	end
	local name = word
	for _, sound in ipairs(ns.SOUNDS or {}) do
		if sound[1] == kit then
			name = sound[2]
		end
	end
	if result == "played" then
		return name .. ", played"
	end
	return name .. ", the game played no sound"
end

-- Sound when one lands (or the sound row given), once, for the samples: the kit whose file the game plays for a real defensive. Gives "none"
-- for None, else "played" or "refused".
function D.SampleSound(word)
	local kit = KITS[word or Opt("sound")]
	if not kit then
		return "none"
	end
	return type(ns.PlayKit) == "function" and ns.PlayKit(kit, KEY) and "played" or "refused"
end

-- Three samples for 8 seconds, each flashing as it appears as a defensive that lands does, with Sound when one lands once. quiet: for
-- PREVIEW seconds, with no sound and no line in the chat (ns.DefensivesLookChanged). A quiet test over one that runs keeps its start, so the
-- sweeps run on and the samples flash again only for path Flash when one lands or a sound row (D.FLASH_AGAIN): a slider drag does not strobe.
D.FLASH_AGAIN = { [KEY .. ".flash"] = true, [KEY .. ".sound"] = true, [KEY .. ".endSound"] = true }

function D.Test(quiet, path)
	quiet = quiet == true
	if not D.Capable() then
		if not quiet then
			print("Defensives on you: the game gives no buff information.")
		end
		return
	end
	if InCombatLockdown() then
		if not quiet then
			print("Defensives on you: the test shows out of combat only.")
		end
		return
	end
	local again = quiet and D.testing and D.testing.quiet and D.testing or nil
	if D.testing then
		D.EndTest(nil, true)
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
	-- The sweeps run 2, 4 and 6 seconds: once the longest has run out, a further step starts them again, still with no flash.
	local now = Now()
	if again and again.start and now - again.start < 6 then
		now = again.start
	end
	local flash = Opt("flash") ~= false and (not again or D.FLASH_AGAIN[path] == true)
	for index, icon in ipairs(list) do
		ns.IconSet(icon, ns.IconSamplePicture(index), now, 2 * index, D.SampleLook())
		ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
		D.SampleName(icon, index)
		if flash then
			ns.IconFlash(icon)
		end
	end
	ns.IconLayout(list, holder, Opt("size"), Opt("spacing"), "right")
	local test = { list = list, quiet = quiet, start = now }
	D.testing = test
	if not quiet then
		test.sound = D.SampleSound()
		print("Defensives on you: three sample icons for 8 seconds.")
	end
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		C_Timer.After(quiet and PREVIEW or TEST_TIME, function()
			D.EndTest(test)
		end)
	end
end

-- True when a defensive the row would show is on the player. Where the game draws the row, any of its buttons that shows, listed, external or
-- the player's own, and one that cannot be asked counts as shown; else one of the list from another player, or with Your own defensives on
-- one of the player's own.
function D.Up()
	if D.path == "container" then
		for _, parts in ipairs(D.list) do
			local ok, shown = pcall(parts.button.IsShown, parts.button)
			if not ok or IsSecret(shown) or shown == true then
				return true
			end
		end
		return false
	end
	if #(D.Read() or {}) > 0 then
		return true
	end
	if Opt("own") == true then
		for id in pairs(D.OwnIDs()) do
			if ns.UnitBuff("player", id) then
				return true
			end
		end
	end
	return false
end

-- A row of the look changed (Place, Icon size, Spacing, Caster's name, Icon border, Flash when one lands), or a sound picked (Sound when one
-- lands, Sound when one ends): the page is refreshed, as without a changed function of the row (Core.lua's Changed), which also registers the
-- game's sounds for the pick (D.Sync, D.QueueSounds), and out of combat with test mode off (its own samples show then), no test of /flatui
-- test icons under way and no defensive on the player (none of the game's buttons shows), the three samples show for PREVIEW seconds in the
-- new look and at the new place, flashing in as they land, with no line in the chat and no sound of their own: the panel plays a pick once
-- itself. Each change keeps them up again, so a slider dragged keeps them up until PREVIEW after its last step; they flash once as they come
-- and again only at a change of Flash when one lands or a sound (D.Test). Place at Off takes a preview away at once.
function ns.DefensivesLookChanged(path)
	ns.Try(KEY, D.Refresh)
	if D.testing and D.testing.quiet and Opt("place") == "off" then
		ns.Try(KEY, D.EndTest, nil, true)
	end
	if InCombatLockdown() or TM.IsOn() or not (D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off") then
		return
	end
	local read, up = pcall(D.Up)
	if (D.testing and not D.testing.quiet) or not read or up then
		return
	end
	ns.Try(KEY, D.Test, true, path)
end

-- Test mode (TestMode.lua): while it is on, out of combat, with the page on and Place not Off, the holder shows three sample icons of its own, apart
-- from those of /flatui test icons. Each Sync lays them out again with Icon size and Spacing, so a change of the row shows at once, and the ticker
-- of test mode starts their sweeps again (IconRow.lua: ns.IconSampleHeld, ns.IconSampleLoop). Off, a fight and the page or the row going off take
-- them away; the holder then hides as Sync says.
function D.Held()
	local list = D.held or {}
	D.held = list
	if not (TM.IsOn() and D.Capable() and ns.Enabled(KEY) and Opt("place") ~= "off" and not InCombatLockdown()) then
		D.Drop()
		return
	end
	local holder = D.Holder()
	for index = 1, 3 do
		list[index] = list[index] or ns.IconNew(holder)
		if not list[index] then
			return
		end
	end
	-- No flash and no sound at the end of a sweep: a sample that comes flashes, and the first to come since test mode came on plays Sound
	-- when one lands, as a defensive that lands does.
	local look, flash, came = D.SampleLook(), Opt("flash") ~= false, false
	look.flash, look.sound = false, false
	for index, icon in ipairs(list) do
		local fresh = not (icon.held and icon.frame:IsShown())
		ns.IconSampleHeld(icon, index, KEY, look)
		ns.IconCountdownHeight(icon, Opt("size"), D.BASE)
		D.SampleName(icon, index)
		if fresh and icon.held then
			came = true
			if flash then
				ns.IconFlash(icon)
			end
		end
	end
	if came and TM.Sound(KEY .. ".sample") then
		D.SampleSound()
	end
	ns.IconLayout(list, holder, Opt("size"), Opt("spacing"), "right")
end

-- The ticker of test mode: a sample whose sweep ended starts again, and flashes as a defensive cast again does.
function D.Tick(now)
	local again = {}
	if Opt("flash") ~= false then
		for _, icon in ipairs(D.held or {}) do
			local held = icon.held
			if held and now >= held.ends and icon.frame:IsShown() then
				again[#again + 1] = icon
			end
		end
	end
	ns.IconSampleLoop(D.held, now)
	for _, icon in ipairs(again) do
		ns.IconFlash(icon)
	end
end

function D.Drop()
	for _, icon in ipairs(D.held or {}) do
		ns.IconSampleDrop(icon)
		if icon.name then
			icon.name:Hide()
		end
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
	for _, name in ipairs({ "icon", "sweep", "count", "time", "name", "border", "flash" }) do
		if D.refused[name] then
			parts[#parts + 1] = name == "sweep" and "sweep" or (name == "name" and "caster's name" or (name == "time" and "time left" or name))
		end
	end
	for _, name in ipairs(parts) do
		lines[#lines + 1] = NOTE_REFUSED:format(name)
	end
	if D.refused.size then
		lines[#lines + 1] = NOTE_SIZE
	end
	if D.refused.tips then
		lines[#lines + 1] = NOTE_MOUSE
	end
	if D.refused.sound then
		lines[#lines + 1] = "Defensives on you: the game refused its sound for a defensive landing, so Sound when one lands is silent for some of them."
	end
	if D.path == "reading" and Opt("tooltips") ~= "off" then
		lines[#lines + 1] = NOTE_READING
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
		-- A spell learnt is left out of Sound when one lands.
		SPELLS_CHANGED = function()
			D.QueueSounds()
		end,
	},
	-- /flatui test, test on and test off are test mode's (Core.lua takes them first); test icons is the 8-second test of the icon rows.
	slash = { check = D.Check, defensives = D.Slash, test = function(rest)
		if not (rest or ""):lower():match("^%s*icons%s*$") then
			print("/flatui test - samples of your hidden frames on screen until you turn it off; test on and test off also work")
			print("/flatui test icons - three sample icons for 8 seconds on Defensives on you, Your buffs, Party and Enemy cooldowns")
			return
		end
		D.Test()
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

-- The samples of test mode go at once at Off and at the start of a fight; the Refresh after it waits for the end of a fight (D.Refresh).
TM.Register(KEY, {
	module = KEY,
	label = "Defensives on you",
	refresh = true,
	Stop = D.Drop,
	Tick = function(now)
		D.Tick(now)
	end,
})

ns.DefensivesModule = D
