local _, ns = ...

-- Error messages: the red messages the game writes in the middle of the screen, hidden by kind with their sound and voice. The rows are Hide
-- error messages and the kinds under it on the Tracker, loot and alerts tab (hud.errors, hud.errorMana and the rest), part "error messages" of the
-- module, which stops alone after a few failures. Not a module: Hud.lua calls ns.ErrorFilterRefresh in every refresh of the page.
-- The game's frame, UIErrorsFrame, hears UI_ERROR_MESSAGE (Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua:3-6) and shows each message in its
-- own Lua (OnEvent and TryDisplayMessage, :13-24 and 146-157). Its filter by kind is a Lua method that writes a global table of the game's
-- (SetMessageTypeEnabled and BLACK_LISTED_MESSAGE_TYPES, :77-107; on Forever the table holds only "Another action is in progress",
-- Camelot/UIErrorsFrameOverrides.lua:1-3), so Flat UI calls neither and writes nothing on the frame. While a kind is hidden, Flat UI reads with
-- IsEventRegistered that the frame listens, takes that one event from it with UnregisterEvent, as the game's own command that turns errors off does
-- (Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1374-1382), and hears the event on a frame of its own. A message of a hidden kind is dropped,
-- and so is its sound. Any other goes into the game's frame as the game puts it there: not while the frame holds its messages back (its field
-- messagesSuppressed, read: :174-180), not for a type the game's own table leaves out (read), a repeat of a line that still shows keeps that line
-- up and makes no sound (GetFontStringByID and ResetMessageFadeByID, :122-144), else AddMessage in the game's red with the message type as its ID,
-- then the voice or the sound GetGameMessageInfo names (C_Sound.PlayVocalErrorSound or PlaySound, which keep the game's sound settings). The flash
-- of a repeat is left out: the game's writes fields on its font strings and gives the frame an OnUpdate script (:26-50 and 109-120). The yellow
-- quest messages and the system lines stay the game's.
-- The row off, the page off, the part or the module stopped, or a message the client withholds gives the event back with RegisterEvent, after the
-- fight when the frame says it is protected; until it is back, every message is shown as the game would. A frame that does not listen when Flat UI
-- looks (another addon, or the game's command) is left so, and taken once it listens again. When it listens again while Flat UI holds the event,
-- that message is the game's and Flat UI takes the event back on the next frame. The game's own two commands (SlashCmdList.UI_ERRORS_OFF and
-- UI_ERRORS_ON, SlashCommands.lua:1374-1382; no slash word names them on Forever, so a macro or an addon calls them) and the /run lines of macros
-- (RunScript, SlashCommands.lua:1224-1236) are followed once the row has been on: after the off command, nothing shows and the event is not given
-- back; a command or a /run line that gives the frame its event back (UIErrorsFrame:RegisterEvent) has it taken again at once, before the message
-- the macro's cast queued arrives. A call of UIErrorsFrame:UnregisterEvent by a macro or an addon cannot be seen (the frame is already deaf), so
-- the kinds that are not hidden still show then. A kind is a list of the game's message types (LE_GAME_ERR_*) and
-- of the words of the spell failures that come under one type for all (SPELL_FAILED_*, matched with or without a closing full stop); a type or a
-- word this client lacks is passed over. The payload of UI_ERROR_MESSAGE is not marked secret (SystemDocumentation.lua:226-236); one that is
-- withheld is never compared or shown. Every client call is in a pcall.
-- This follows the error message filter of EnhanceQoL by Philipp Barth (R41Z0R), adapted with his permission (Submodules/UIErrors.lua). Only the
-- kinds a character of the classic classes meets are offered, and the spell failures are added to them.

local KEY, PART, ROW = "hud", "error messages", "hud.errors"
local EVENT = "UI_ERROR_MESSAGE"
-- The game's red when its colour cannot be read (RED_FONT_COLOR comes from the game's colour table: Blizzard_SharedXMLBase/Color.lua:82-86).
local RED = { 1, 0.1, 0.1 }
-- Each kind: its row, the game's message types (the names after LE_GAME_) and the words of the spell failures of that kind. Out of range
-- also takes ERR_USE_TOO_FAR, the "You are too far away." of a chest, a quest object or a mailbox clicked from too far, as EnhanceQoL's list does.
local KINDS = {
	{ row = "errorMana", types = { "ERR_OUT_OF_MANA" } },
	{ row = "errorPower", types = { "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_FOCUS", "ERR_OUT_OF_COMBO_POINTS" },
		words = { "SPELL_FAILED_NO_COMBO_POINTS" } },
	{ row = "errorRange", types = { "ERR_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE", "ERR_BADATTACKPOS", "ERR_USE_TOO_FAR", "ERR_PET_SPELL_OUT_OF_RANGE" },
		words = { "SPELL_FAILED_OUT_OF_RANGE", "SPELL_FAILED_TOO_CLOSE" } },
	{ row = "errorFacing", types = { "ERR_BADATTACKFACING", "ERR_PET_SPELL_NOT_BEHIND" },
		words = { "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_NOT_INFRONT", "SPELL_FAILED_NOT_BEHIND", "SPELL_FAILED_UNIT_NOT_BEHIND" } },
	{ row = "errorReady", types = { "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "ERR_POTION_COOLDOWN" },
		words = { "SPELL_FAILED_NOT_READY" } },
	{ row = "errorTarget", types = { "ERR_GENERIC_NO_TARGET", "ERR_NO_ATTACK_TARGET", "ERR_INVALID_ATTACK_TARGET", "ERR_GENERIC_NO_VALID_TARGETS",
		"ERR_PET_SPELL_TARGETS_DEAD" }, words = { "SPELL_FAILED_BAD_TARGETS", "SPELL_FAILED_BAD_IMPLICIT_TARGETS", "SPELL_FAILED_TARGETS_DEAD" } },
	{ row = "errorMoving", types = { "ERR_NOT_WHILE_MOVING", "ERR_NOEMOTEWHILERUNNING" }, words = { "SPELL_FAILED_MOVING" } },
}
-- The types whose repeat keeps the line that shows in place of a new one (UIErrorsFrame.lua:52-75, a local table of the game's file).
local REPEATS = { "ERR_SPELL_FAILED_TOTEMS", "ERR_SPELL_FAILED_EQUIPPED_ITEM", "ERR_SPELL_ALREADY_KNOWN_S", "ERR_SPELL_FAILED_SHAPESHIFT_FORM_S",
	"ERR_SPELL_FAILED_ALREADY_AT_FULL_MANA", "ERR_OUT_OF_MANA", "ERR_SPELL_OUT_OF_RANGE", "ERR_SPELL_FAILED_S", "ERR_SPELL_FAILED_REAGENTS",
	"ERR_SPELL_FAILED_REAGENTS_GENERIC", "ERR_SPELL_FAILED_NOTUNSHEATHED", "ERR_SPELL_UNLEARNED_S", "ERR_SPELL_FAILED_EQUIPPED_SPECIFIC_ITEM",
	"ERR_SPELL_FAILED_ALREADY_AT_FULL_POWER_S", "ERR_SPELL_FAILED_EQUIPPED_ITEM_CLASS_S", "ERR_SPELL_FAILED_ALREADY_AT_FULL_HEALTH",
	"ERR_SPELL_FAILED_CANT_FLY_HERE", "ERR_GENERIC_NO_VALID_TARGETS", "ERR_ITEM_COOLDOWN", "ERR_CANT_USE_ITEM", "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS" }

-- held: Flat UI took the event from the game's frame and owes it back. aside: the frame did not listen when Flat UI looked, so it was left.
-- refused: the frame kept the event or would not say. stuck: the frame would not take the event back. withheld: a message came withheld, so the
-- event is the game's until /reload. missing: the client has no such frame. waiting: a take or a give-back waits for the end of a fight. soon: a
-- look waits for the next frame. types and words: what the kinds that are on hide; kinds: how many are on; hidden: the messages hidden so far.
-- gameOff: the game's off command ran while Flat UI held the event. relistened: how many messages the game's frame heard itself while Flat UI held
-- the event (turned back on by something neither follow sees).
local S = { types = {}, words = {}, kinds = 0, hidden = 0, relistened = 0 }
local frame, listening, repeats = nil, false, nil
local Apply

-- A global of the game's, or nil when it is missing or withheld.
local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- A field of a table of the game's, read without its methods, or nil.
local function Field(owner, key)
	if owner == nil or ns.IsSecret(owner) or type(owner) ~= "table" then
		return nil
	end
	local ok, value = pcall(rawget, owner, key)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

-- The words of a message without a closing full stop: a spell failure has one in some of the game's string files and not in others.
local function Bare(text)
	return (text:gsub("%.$", ""))
end

local function GameFrame()
	local errors = _G.UIErrorsFrame
	if ns.Forbidden(errors) then
		return nil
	end
	return errors
end

-- True while the game's frame listens for the event, false while it does not, nil when it does not say.
local function Listens(errors)
	local ok, on = pcall(errors.IsEventRegistered, errors, EVENT)
	if not ok or ns.IsSecret(on) or type(on) ~= "boolean" then
		return nil
	end
	return on
end

local function Wanted()
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and ns.Get(ROW) == true and not S.withheld
end

-- What the kinds that are on hide. False when nothing would be hidden.
local function Build()
	local types, words, kinds = {}, {}, 0
	for _, kind in ipairs(KINDS) do
		if ns.Get(KEY .. "." .. kind.row) == true then
			kinds = kinds + 1
			for _, name in ipairs(kind.types) do
				local id = Global("LE_GAME_" .. name)
				if ns.Finite(id) then
					types[id] = true
				end
			end
			for _, name in ipairs(kind.words or {}) do
				local text = Global(name)
				if type(text) == "string" and text ~= "" then
					words[Bare(text)] = true
				end
			end
		end
	end
	S.types, S.words, S.kinds = types, words, kinds
	return next(types) ~= nil or next(words) ~= nil
end

local function Repeats()
	if repeats == nil then
		repeats = {}
		for _, name in ipairs(REPEATS) do
			local id = Global("LE_GAME_" .. name)
			if ns.Finite(id) then
				repeats[id] = true
			end
		end
	end
	return repeats
end

-- The game's red, read from the fields of its colour without a call.
local function Red()
	local colour = Global("RED_FONT_COLOR")
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return RED[1], RED[2], RED[3]
end

-- True for a type the game's own table leaves out; another addon's call of SetMessageTypeEnabled writes there too.
local function GameLeavesOut(id)
	return Field(Global("BLACK_LISTED_MESSAGE_TYPES"), id) == true
end

-- True when the line of that type still shows the same words: the game then keeps that line up and makes no sound (UIErrorsFrame.lua:122-144).
local function Repeat(errors, id, message)
	if not Repeats()[id] then
		return false
	end
	local ok, line = pcall(errors.GetFontStringByID, errors, id)
	if not ok or ns.Forbidden(line) then
		return false
	end
	local okText, text = pcall(line.GetText, line)
	if not okText or ns.IsSecret(text) or text ~= message then
		return false
	end
	pcall(errors.ResetMessageFadeByID, errors, id)
	return true
end

-- The voice or the sound the game plays with a message of that type (UIErrorsFrame.lua:150-155, GameErrorDocumentation.lua:10-26).
local function Sound(id)
	if type(GetGameMessageInfo) ~= "function" then
		return
	end
	local ok, _, kit, voice = pcall(GetGameMessageInfo, id)
	if not ok or ns.IsSecret(kit) or ns.IsSecret(voice) then
		return
	end
	if voice ~= nil then
		local sounds = Global("C_Sound")
		if ns.Finite(voice) and type(sounds) == "table" and type(sounds.PlayVocalErrorSound) == "function" then
			pcall(sounds.PlayVocalErrorSound, voice)
		end
	elseif ns.Finite(kit) and type(PlaySound) == "function" then
		pcall(PlaySound, kit)
	end
end

-- Puts a message in the game's frame as the game's own handler does (UIErrorsFrame.lua:146-157).
local function Show(errors, messageType, message)
	if type(message) ~= "string" or Field(errors, "messagesSuppressed") == true then
		return
	end
	local id = ns.Finite(messageType) and messageType or nil
	if id ~= nil and (GameLeavesOut(id) or Repeat(errors, id, message)) then
		return
	end
	local r, g, b = Red()
	if pcall(errors.AddMessage, errors, message, r, g, b, 1, id) and id ~= nil then
		Sound(id)
	end
end

local function Hides(messageType, message)
	if ns.Finite(messageType) and S.types[messageType] then
		return true
	end
	return type(message) == "string" and S.words[Bare(message)] == true
end

-- One message while the filter is on. The first argument is a table of its own for each message, so every failure counts toward stopping the part.
local function Judge(_, errors, messageType, message)
	if Hides(messageType, message) then
		S.hidden = S.hidden + 1
		return
	end
	Show(errors, messageType, message)
end

-- Looks again on the next frame, never inside the game's handling of the event.
local function Soon()
	if S.soon then
		return
	end
	S.soon = true
	local function Run()
		S.soon = false
		local ok, err = pcall(Apply)
		if not ok then
			geterrorhandler()(err)
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Run)
	else
		Run()
	end
end

local function OnEvent(_, event, messageType, message)
	if event ~= EVENT then
		return
	end
	local errors = GameFrame()
	if errors == nil then
		return
	end
	if Listens(errors) == true then
		-- The game's frame heard this one itself: it listens again, or Flat UI has not taken the event yet.
		if S.held then
			S.relistened = S.relistened + 1
		end
		Soon()
		return
	end
	-- The frame is deaf by another addon or by the game's command: it shows nothing, and Flat UI shows nothing either.
	if not S.held or S.gameOff then
		return
	end
	if ns.IsSecret(messageType) or ns.IsSecret(message) then
		-- An addon can neither judge nor show a withheld message, and the game can: the event goes back to it.
		S.withheld = true
		Soon()
		return
	end
	if Wanted() then
		if not ns.EachPart(KEY, PART, Judge, {}, errors, messageType, message) and ns.PartStopped(KEY, PART) then
			Soon()
		end
		return
	end
	-- Flat UI still holds the event while it is not wanted (the give-back waits for the end of a fight, or the frame would not take it back): the
	-- message is shown as the game would show it, and the give-back is tried again.
	pcall(Show, errors, messageType, message)
	Soon()
end

-- The event is heard on a frame of Flat UI's own while Flat UI holds it or waits to take it.
local function Listen(on)
	if on and not listening then
		if frame == nil then
			frame = CreateFrame("Frame")
			ns.Own[frame] = true
			frame:SetScript("OnEvent", OnEvent)
		end
		listening = pcall(frame.RegisterEvent, frame, EVENT)
	elseif not on and listening then
		pcall(frame.UnregisterEvent, frame, EVENT)
		listening = false
	end
end

-- In a fight a frame that says it is protected, or will not say, takes no call.
local function Blocked(errors)
	return InCombatLockdown() and (ns.MaybeProtected == nil or ns.MaybeProtected(errors))
end

local function Wait()
	if S.waiting then
		return
	end
	S.waiting = true
	ns.OutOfCombat(function()
		S.waiting = false
		Apply()
	end)
end

-- The game's off command ran (its UnregisterEvent found the frame deaf): while Flat UI holds the event, nothing shows and nothing is given back.
local function GameOff()
	if S.held then
		S.gameOff = true
	end
end

-- The game's on command gave the frame its event back: Flat UI takes it again at once, outside the handling of any message.
local function GameOn()
	S.gameOff = nil
	Apply()
end

-- After a /run line: a macro that gave the frame its event back is followed at once, before the message its cast queued reaches the frame.
local function AfterScript()
	if S.held or S.aside then
		local errors = GameFrame()
		if errors ~= nil and Listens(errors) == true then
			Apply()
		end
	end
end

-- Hooked the first time the row is on; a follow the game refused (taintLog on) is tried again at the next look.
local follows = {}
local function FollowCommands()
	local commands = Global("SlashCmdList")
	if not follows.off then
		follows.off = ns.FollowTable(commands, "UI_ERRORS_OFF", GameOff) == true
	end
	if not follows.on then
		follows.on = ns.FollowTable(commands, "UI_ERRORS_ON", GameOn) == true
	end
	if not follows.script then
		follows.script = ns.FollowGlobal("RunScript", AfterScript) == true
	end
end

-- Takes the event from the game's frame or gives it back, as the rows and the page ask.
function Apply()
	local errors = GameFrame()
	if errors == nil then
		S.missing = Wanted() or nil
		S.held, S.gameOff = false, nil
		Listen(false)
		return
	end
	S.missing = nil
	if Wanted() and Build() then
		FollowCommands()
		local on = Listens(errors)
		if on == true then
			-- The frame listens: whatever turned its error text off, it is on again.
			S.gameOff = nil
			if Blocked(errors) then
				Wait()
				Listen(S.held)
				return
			end
			-- Read first: the frame listens, so the event goes back to it when the filter goes off.
			pcall(errors.UnregisterEvent, errors, EVENT)
			local now = Listens(errors)
			if now ~= false then
				-- The frame kept the event, or will not say whether it did: it is given the event again, to be sure, and nothing is hidden.
				if now == nil then
					pcall(errors.RegisterEvent, errors, EVENT)
				end
				S.held, S.refused, S.aside = false, true, nil
				Listen(false)
				return
			end
			S.held = true
		elseif not S.held then
			if on == false then
				S.aside, S.refused = true, nil
				Listen(true)
			else
				S.refused, S.aside = true, nil
				Listen(false)
			end
			return
		end
		S.aside, S.refused, S.stuck = nil, nil, nil
		Listen(true)
		return
	end
	if S.held then
		-- After the game's off command the frame stays deaf, as the command left it.
		if not S.gameOff and Listens(errors) == false then
			if Blocked(errors) then
				Wait()
				Listen(true)
				return
			end
			pcall(errors.RegisterEvent, errors, EVENT)
			if Listens(errors) == false then
				S.stuck = true
				Listen(true)
				return
			end
		end
		S.held, S.gameOff = false, nil
	end
	S.aside, S.refused, S.stuck = nil, nil, nil
	Listen(false)
end

ns.AddStatus(KEY, function()
	if S.withheld then
		return { "Error messages: the game withheld a message, so its error text is its own again until /reload." }
	elseif S.stuck then
		return { "Error messages: the game did not take its error text back, so Flat UI shows every message until /reload." }
	elseif S.held and not Wanted() then
		return { "Error messages: off at the end of the fight. Until then Flat UI shows every message." }
	elseif not Wanted() then
		return {}
	elseif S.missing then
		return { "Error messages: this client has no error text, so nothing is hidden." }
	elseif S.waiting and not S.held then
		return { "Error messages: waiting for the end of the fight." }
	elseif S.refused then
		return { "Error messages: the game kept its error text, so nothing is hidden." }
	elseif S.aside then
		return { "Error messages: the game's error text is off already, by another addon or the game's command, so Flat UI leaves it." }
	elseif S.gameOff then
		return { "Error messages: the game's command turned its error text off, so none shows until it is turned on again." }
	elseif S.held then
		local lines = { ("Error messages: %d of %d kinds hidden, %d messages so far."):format(S.kinds, #KINDS, S.hidden) }
		if S.relistened > 0 then
			lines[2] = ("Error messages: another addon gave the game its error text back, and %d messages then showed whatever their kind.")
				:format(S.relistened)
		end
		return lines
	elseif S.kinds == 0 then
		return { "Error messages: no kind is on, so nothing is hidden." }
	end
	return { "Error messages: this client names none of these kinds, so nothing is hidden." }
end)

-- Hud.lua calls this in every refresh of the module: a changed row, the page, the profile, the module stopped.
function ns.ErrorFilterRefresh()
	Apply()
end
