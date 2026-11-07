local _, ns = ...

-- Mount key (off by default): one key of the game's Key Bindings, Mount or travel form in the section Flat UI (Bindings.xml binds a click of the
-- button, CLICK FlatUIMountButton:LeftButton, as the game reads the keys of its own action buttons, Blizzard_ActionBar/Shared/ActionButton.lua:498-499,
-- and names the section after the category, Blizzard_SettingsDefinitions_Frame/Keybindings.lua:220-227 and 248). Pressed, it mounts a random mount
-- the character can ride; a druid takes Aquatic Form in water and Travel Form where a mount cannot be summoned, and a shaman Ghost Wolf. Pressed
-- again, it dismounts or leaves the form.
-- Mounts on Forever are spells of the mount journal, not items: the Collections window loads there with its Mounts tab (Blizzard_Collections.toc:13
-- and 25, Camelot/Blizzard_CollectionsTabs.xml:20), it summons a mount by its journal ID (Mainline/Blizzard_MountCollection.lua:818-834), and a
-- shift-click on a mount while the macro window is open writes the mount's spell name (Mainline/Blizzard_MountCollection.lua:873-875), which /cast
-- casts (Blizzard_ChatFrameBase/Shared/SlashCommands.lua:365-376). The key picks among the mounts the journal counts as the character's, collected
-- and not hidden on this character (Mainline/Blizzard_MountCollection.lua:632-638), that the game says can be used here: GetMountUsabilityByID
-- without its indoor check (MountJournalDocumentation.lua:340-357), so the macro does not change at every door and the game itself says when a
-- mount cannot be used indoors. With Favourite mounts first it picks among the favourites while one of them can be used. Forever hides the
-- journal's own Summon Random Favorite button (Camelot/Blizzard_CollectionsConstants.lua:1, Mainline/Blizzard_MountCollection.lua:1031-1033) but
-- keeps Favorite in the right-click menu of a mount (Mainline/Blizzard_MountCollection.lua:222-233). The pick is kept until the player mounts
-- (PLAYER_MOUNT_DISPLAY_CHANGED, UnitDocumentation.lua:3859-3863) or it can no longer be used, so each mount-up takes a new one.
-- The macro: /dismount [mounted] and /stopmacro [mounted] first, so the key dismounts when pressed again; the game takes the mount away when the
-- server answers, so the next lines still see it, as EnhanceQoL's own macro has it (MountActions.lua:304-307). For a druid or a shaman,
-- /cancelform [form] and /stopmacro [form] next: a form is left the same way, and a druid in Cat or Bear Form leaves it with the first press.
-- Another class is never given /cancelform, since a warrior's stance and a rogue's Stealth are forms as well (Blizzard_FrameXMLBase/Constants.lua:
-- 326-337). Then one /cast with its choices in order: Aquatic Form in water ([swimming]); Travel Form or Ghost Wolf in a fight ([combat]), where
-- no mount can be summoned; the mount (only out of a fight for a class with no form); else the form. While the player moves a mount's cast would
-- break, so a druid takes Travel Form instead, and a shaman Ghost Wolf if it is instant (castTime of C_Spell.GetSpellInfo,
-- SpellDocumentation.lua:416-431 and 1183-1194). The forms are those the spell book knows (C_SpellBook.IsSpellKnown, SpellBookDocumentation.lua:
-- 738-753), by the IDs EnhanceQoL uses (MountActions.lua:24, 27) and the game's Mainline tutorial names (Blizzard_NewPlayerExperience/Mainline/
-- Blizzard_TutorialData.lua:275, 341; Forever does not load it), and Aquatic Form, 1066; a form the book does not know by its ID is left out. The
-- macro casts them by their names (C_Spell.GetSpellName, SpellDocumentation.lua:518-533), the highest rank as /cast does.
-- The button: a secure button of Flat UI's own (SecureActionButtonTemplate), named FlatUIMountButton for the binding, made once, out of combat, the
-- first time the module is on while a key is bound to it (GetBindingKey, as ActionButton.lua:498-499 asks it). It is a child of UIParent with no
-- size and no point, so it shows nothing and takes no mouse. It hears the press and the release of the left button, and the game's
-- ActionButtonUseKeyDown decides which acts, as for its own action buttons (Blizzard_FrameXML/SecureTemplates.lua:792-811, ActionButton.lua:468).
-- Its type and macrotext (SecureTemplates.lua:450-463) are written only out of combat, after a fight for a change heard in one (ns.OutOfCombat),
-- and only when the macro changes: when the mounts, the forms, the bindings, the moving or the rows change. Nothing of Flat UI's runs in its click
-- (no PreClick, no PostClick): the moving is heard (PLAYER_STARTED_MOVING and PLAYER_STOPPED_MOVING, UnitDocumentation.lua:3944-3966) by a frame of
-- the addon's own, only while the button is made, a key is bound to it and the macro on the move differs, and read a frame later (IsPlayerMoving,
-- PlayerScriptDocumentation.lua:1453-1460). The game sends UPDATE_BINDINGS when a key is set or cleared, as the rows of its Key Bindings window read
-- their keys again on it (KeyBindingsDocumentation.lua:175-179, Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:107, 153-154 and 975-977,
-- Blizzard_Keybindings.lua:453), so the moving is read when a key is bound, and no longer heard once none is.
-- With the module off its type and macro are taken away, so the key does nothing; the binding is the player's and stays. It writes no binding, no
-- macro of the game's macro list and no field of a frame, and no global but the button's name and BINDING_NAME_CLICK FlatUIMountButton:LeftButton,
-- the name of the binding.
-- This follows the random mount key of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (EnhanceQoL/Submodules/MountActions.lua:
-- 106-132, 261-336, 376-424, 426-499, 553-569, 580-602; EnhanceQoL/Bindings.xml:12-15): the button the binding clicks, the usable mounts of the
-- journal and its favourites, the random pick, the combat lines and the druid and shaman forms while moving. Left out on Forever, as its own Forever
-- build leaves out Dracthyr Visage (MountActions.lua:245): the G-99 Breakneck, flying and swimming mounts, the target's mount, Slow Fall and
-- Levitate while falling, Cat Form indoors (a cat is no faster on classic content) and /leavevehicle. Its macro is written in a PreClick before each
-- press; here it is written when what it depends on changes, so no code of Flat UI's runs in the click.

local KEY = "mount"
local BUTTON = "FlatUIMountButton"
local BINDING = "CLICK " .. BUTTON .. ":LeftButton"
-- Travel Form, Aquatic Form and Ghost Wolf.
local TRAVEL, AQUATIC, WOLF = 783, 1066, 2645
-- A burst of events writes the macro once, this long after the first.
local STEP = 0.2
local MOVING = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING" }
local LINE_UNBOUND = "Mount key: no key is bound yet. Bind one to Mount or travel form, under Flat UI in the game's Key Bindings."
local LINE_NOTHING = "Mount key: no mount or travel form to use yet."
-- The character has mounts in the journal, but the game lets none of them be used now: GetMountUsabilityByID answers false with the reason as
-- useError (MountJournalDocumentation.lua:340-357), and the journal shows that reason on the tooltip of its Mount button, also while the button
-- is disabled (Mainline/Blizzard_MountCollection.lua:853-859, Mainline/Blizzard_MountCollection.xml:568 and 575).
local LINE_UNUSABLE = "Mount key: none of your mounts can be used here and now. The tooltip of the Mount button in the mount journal says why."
local LINE_BROKEN = "Mount key: the game did not make the button of the key, so the key does nothing until /reload."
local LINE_JOURNAL = "Mount key: this client has no mount journal, so the key takes travel forms only."
local LINE_WAITS = "Mount key: a change of the key waits for the end of the fight."

-- The name of the binding in the game's Key Bindings.
_G["BINDING_NAME_" .. BINDING] = "Mount or travel form"

local IsSecret = ns.IsSecret

-- button: the secure button once made, broken: it could not be made and is not tried again. text: the macro on it, nil while it has none.
-- texts: the macro standing (still) and on the move (moving). cast: the macro casts something. mount: the spell name of the mount it casts.
-- list: the character's mounts of the journal, read again when dirty. pick: the name of the mount picked. moving: the player moves, as last read.
-- listener: the frame that hears the moving, hearing: it does, soonMove: a read of the moving waits for the next frame. soon: a write waits a
-- moment; later: one waits for the end of the fight.
local S = { button = nil, broken = false, text = nil, texts = nil, cast = false, mount = nil, list = nil, dirty = true, pick = nil, moving = false,
	listener = nil, hearing = false, soonMove = false, soon = false, later = false }
local M = {}

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

-- The first answer of a call of the client, or nil when the call is missing, raises or the answer is withheld.
local function Ask(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok and not IsSecret(value) then
		return value
	end
	return nil
end

-- True for a plain true of the game; a withheld answer is none.
local function Yes(value)
	return not IsSecret(value) and value == true
end

-- A timer of the client, false when there is none or it raises.
local function After(seconds, fn)
	return type(C_Timer) == "table" and type(C_Timer.After) == "function" and pcall(C_Timer.After, seconds, fn)
end

-- True in combat lockdown (RestrictedActionsDocumentation.lua:45-52), when nothing may change on a secure button. A withheld answer counts as a
-- fight, so nothing is written then.
local function Fighting()
	if type(InCombatLockdown) ~= "function" then
		return false
	end
	local ok, value = pcall(InCombatLockdown)
	return not ok or IsSecret(value) or value == true
end

-- The journal, when the client has the calls the key reads.
local function Journal()
	local journal = C_MountJournal
	if type(journal) == "table" and not IsSecret(journal) and type(journal.GetMountIDs) == "function" and type(journal.GetMountInfoByID) == "function" then
		return journal
	end
	return nil
end

-- True while a key of the game's Key Bindings clicks the button.
local function Bound()
	local key = Ask(GetBindingKey, BINDING)
	return type(key) == "string" and key ~= ""
end

local function SpellName(id)
	local spells = C_Spell
	local name = type(spells) == "table" and Ask(spells.GetSpellName, id) or nil
	return type(name) == "string" and name ~= "" and name or nil
end

-- The player's book (SpellBookConstantsDocumentation.lua:35-45), 0 where the client gives no enum.
local function Bank()
	local banks = type(Enum) == "table" and Enum.SpellBookSpellBank or nil
	local value = type(banks) == "table" and banks.Player or nil
	return type(value) == "number" and value or 0
end

-- The name of a form the spell book knows, or nil.
local function Form(id)
	local book = C_SpellBook
	if type(book) ~= "table" or not Yes(Ask(book.IsSpellKnown, id, Bank())) then
		return nil
	end
	return SpellName(id)
end

-- True when a spell has no cast time, so it can be cast on the move.
local function Instant(id)
	local spells = C_Spell
	local info = type(spells) == "table" and Ask(spells.GetSpellInfo, id) or nil
	if type(info) ~= "table" then
		return false
	end
	local cast = info.castTime
	return ns.Finite(cast) and cast == 0
end

-- The class file of the player (UnitDocumentation.lua:911-928).
local function Class()
	if type(UnitClass) ~= "function" then
		return nil
	end
	local ok, _, class = pcall(UnitClass, "player")
	if ok and not IsSecret(class) and type(class) == "string" then
		return class
	end
	return nil
end

-- The mounts ---------------------------------------------------------------------------------------------------------------------------------

-- The character's mounts of the journal, { id, spell, favourite } each, read again only after the journal changed.
local function Collected()
	if S.list and not S.dirty then
		return S.list
	end
	S.dirty = false
	local list = {}
	S.list = list
	local journal = Journal()
	if not journal then
		return list
	end
	local ok, ids = pcall(journal.GetMountIDs)
	if not ok or IsSecret(ids) or type(ids) ~= "table" then
		return list
	end
	for _, id in ipairs(ids) do
		if ns.Finite(id) then
			local got, _, spell, _, _, _, _, favourite, _, _, hidden, collected = pcall(journal.GetMountInfoByID, id)
			if got and Yes(collected) and not Yes(hidden) and ns.Finite(spell) then
				list[#list + 1] = { id = id, spell = spell, favourite = Yes(favourite) }
			end
		end
	end
	return list
end

-- Whether the game lets the character use a mount here, leaving indoors to the game's own answer at the press.
local function Usable(entry)
	local journal = C_MountJournal
	if type(journal.GetMountUsabilityByID) == "function" then
		local ok, usable = pcall(journal.GetMountUsabilityByID, entry.id, false)
		if ok and not IsSecret(usable) and type(usable) == "boolean" then
			return usable
		end
	end
	local ok, _, _, _, _, usable = pcall(journal.GetMountInfoByID, entry.id)
	return ok and Yes(usable)
end

-- The spell name of the mount the key casts, or nil when the character has none to use: the one picked before while it can still be used, else a
-- new one at random.
local function Pick()
	local all, favourites = {}, {}
	for _, entry in ipairs(Collected()) do
		local name = Usable(entry) and SpellName(entry.spell) or nil
		if name then
			all[#all + 1] = name
			if entry.favourite then
				favourites[#favourites + 1] = name
			end
		end
	end
	local pool = (Opt("favourites") == true and #favourites > 0) and favourites or all
	for _, name in ipairs(pool) do
		if name == S.pick then
			return name
		end
	end
	S.pick = #pool > 0 and pool[math.random(#pool)] or nil
	return S.pick
end

-- The macro ----------------------------------------------------------------------------------------------------------------------------------

-- What the key can cast now: the forms of the class and the mount.
local function Plan()
	local plan, class = {}, Class()
	if class == "DRUID" then
		plan.cancel, plan.travel, plan.aquatic = true, Form(TRAVEL), Form(AQUATIC)
	elseif class == "SHAMAN" then
		plan.cancel, plan.wolf = true, Form(WOLF)
		plan.wolfInstant = plan.wolf ~= nil and Instant(WOLF)
	end
	plan.mount = Pick()
	return plan
end

-- The macro of the key, standing or on the move, and whether it casts anything.
local function Macro(plan, moving)
	local lines, choices = { "/dismount [mounted]", "/stopmacro [mounted]" }, {}
	if plan.aquatic then
		choices[#choices + 1] = "[swimming] " .. plan.aquatic
	end
	local form = plan.travel or plan.wolf
	local fast = plan.travel or (plan.wolfInstant and plan.wolf) or nil
	if plan.mount and not (moving and fast) then
		if form then
			choices[#choices + 1] = "[combat] " .. form
			choices[#choices + 1] = plan.mount
		else
			choices[#choices + 1] = "[nocombat] " .. plan.mount
		end
	elseif form then
		choices[#choices + 1] = form
	end
	if #choices == 0 then
		return table.concat(lines, "\n"), false
	end
	if plan.cancel then
		lines[#lines + 1] = "/cancelform [form]"
		lines[#lines + 1] = "/stopmacro [form]"
	end
	lines[#lines + 1] = "/cast " .. table.concat(choices, "; ")
	return table.concat(lines, "\n"), true
end

-- The button ---------------------------------------------------------------------------------------------------------------------------------

-- Made once, out of combat. Its type is set with its first macro.
local function Build()
	if S.button then
		return true
	end
	if S.broken or Fighting() then
		return false
	end
	local made, button = pcall(CreateFrame, "Button", BUTTON, UIParent, "SecureActionButtonTemplate")
	if not made or IsSecret(button) or type(button) ~= "table" then
		S.broken = true
		return false
	end
	ns.Own[button] = true
	if not pcall(button.RegisterForClicks, button, "LeftButtonDown", "LeftButtonUp") then
		S.broken = true
		return false
	end
	S.button = button
	return true
end

-- A write asked for in a fight waits for its end, once.
local function Later()
	if S.later then
		return
	end
	S.later = true
	ns.OutOfCombat(function()
		S.later = false
		ns.Try(KEY, M.Update)
	end)
end

-- Puts the macro of now on the button, if it is not there yet.
local function Apply()
	if not S.button or not S.texts then
		return
	end
	local text = S.moving and S.texts.moving or S.texts.still
	if text == S.text then
		return
	end
	if Fighting() then
		Later()
		return
	end
	local ok = pcall(function()
		S.button:SetAttribute("type", "macro")
		S.button:SetAttribute("macrotext", text)
	end)
	if ok then
		S.text = text
	end
end

-- The moving, read a frame after the game said it changed.
function M.Moved()
	S.soonMove = false
	S.moving = Ask(IsPlayerMoving) == true
	Apply()
end

local function OnMove()
	if S.soonMove then
		return
	end
	S.soonMove = true
	if not After(0, function()
		ns.Try(KEY, M.Moved)
	end) then
		ns.Try(KEY, M.Moved)
	end
end

-- Hears the moving, or stops: M.Update asks it only while a key can press the button and the macro on the move is another.
local function Hear(on)
	if on == S.hearing then
		return
	end
	if on and not S.listener then
		local ok, frame = pcall(CreateFrame, "Frame")
		if not ok or IsSecret(frame) or type(frame) ~= "table" then
			return
		end
		ns.Own[frame] = true
		if not pcall(frame.SetScript, frame, "OnEvent", OnMove) then
			return
		end
		S.listener = frame
	end
	if not S.listener then
		return
	end
	local frame = S.listener
	for _, event in ipairs(MOVING) do
		pcall(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
	end
	S.hearing = on
	if on then
		S.moving = Ask(IsPlayerMoving) == true
	else
		S.moving = false
	end
end

-- Takes the type and the macro off the button, so the key does nothing.
function M.Off()
	Hear(false)
	S.texts, S.cast, S.mount = nil, false, nil
	if not S.button or S.text == nil then
		return
	end
	if Fighting() then
		Later()
		return
	end
	local ok = pcall(function()
		S.button:SetAttribute("type", nil)
		S.button:SetAttribute("macrotext", nil)
	end)
	if ok then
		S.text = nil
	end
end

function M.Update()
	S.soon = false
	if not ns.Enabled(KEY) then
		M.Off()
		return
	end
	local plan = Plan()
	local still, cast = Macro(plan, false)
	local moving = Macro(plan, true)
	S.texts, S.cast, S.mount = { still = still, moving = moving }, cast, plan.mount
	local bound = Bound()
	if not S.button and bound and not Build() and not S.broken then
		Later()
	end
	-- No key presses the button while none is bound or the button is not made, so the moving is not heard then. Setting or clearing the key runs
	-- this again (UPDATE_BINDINGS, KeyBindingsDocumentation.lua:175-179), and the hearing reads the moving as it starts.
	Hear(moving ~= still and S.button ~= nil and bound)
	Apply()
end

-- Writes again a moment later, once for a burst of events.
function M.Soon()
	if S.soon then
		return
	end
	S.soon = true
	if not After(STEP, function()
		ns.Try(KEY, M.Update)
	end) then
		M.Update()
	end
end

-- The journal changed: its mounts are read again.
local function Changed()
	S.dirty = true
	M.Soon()
end

-- Turned on, a row changed or the module stopped: the mounts are read and picked again.
function M.Refresh()
	S.dirty, S.pick = true, nil
	M.Update()
end

function M.Status()
	local lines = {}
	if not ns.Enabled(KEY) then
		return lines
	end
	if S.broken then
		lines[#lines + 1] = LINE_BROKEN
	elseif not Bound() then
		lines[#lines + 1] = LINE_UNBOUND
	end
	if not Journal() then
		lines[#lines + 1] = LINE_JOURNAL
	end
	-- The mounts as the last update read them for the macro, so the line matches the macro and the status reads nothing of the journal.
	if not S.cast and S.list and #S.list > 0 then
		lines[#lines + 1] = LINE_UNUSABLE
	elseif not S.cast then
		lines[#lines + 1] = LINE_NOTHING
	elseif S.mount then
		lines[#lines + 1] = ("Mount key: the next mount is %s."):format(S.mount)
	end
	if S.later then
		lines[#lines + 1] = LINE_WAITS
	end
	return lines
end

-- The button and the macro, for the test.
function ns.MountKeyState()
	return S
end

ns.Register(KEY, {
	label = "Mount key",
	counted = false,
	Start = M.Refresh,
	Refresh = M.Refresh,
	Status = M.Status,
	events = {
		-- The mounts of the journal (MountJournalDocumentation.lua:642-662, PetJournalInfoDocumentation.lua:342-349); a favourite marked or
		-- unmarked updates the search of the journal, as EnhanceQoL hears it (MountActions.lua:594-599).
		PLAYER_ENTERING_WORLD = Changed,
		NEW_MOUNT_ADDED = Changed,
		COMPANION_LEARNED = Changed,
		COMPANION_UNLEARNED = Changed,
		MOUNT_JOURNAL_SEARCH_UPDATED = Changed,
		-- Where a mount can be used, the forms of the book, riding at a new level and the keys of the Key Bindings (MountJournalDocumentation.lua:
		-- 648-651, SpellBookDocumentation.lua:968, 996-1000, UnitDocumentation.lua:3832, KeyBindingsDocumentation.lua:175-179).
		MOUNT_JOURNAL_USABILITY_CHANGED = function()
			M.Soon()
		end,
		SPELLS_CHANGED = function()
			M.Soon()
		end,
		UPDATE_SHAPESHIFT_FORMS = function()
			M.Soon()
		end,
		PLAYER_LEVEL_UP = function()
			M.Soon()
		end,
		UPDATE_BINDINGS = function()
			M.Soon()
		end,
		-- Mounted: the next press takes another mount.
		PLAYER_MOUNT_DISPLAY_CHANGED = function()
			if Yes(Ask(IsMounted)) then
				S.pick = nil
			end
			M.Soon()
		end,
	},
})
