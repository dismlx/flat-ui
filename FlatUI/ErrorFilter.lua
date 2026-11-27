local _, ns = ...

local KEY, PART, ROW = "hud", "error messages", "hud.errors"
local EVENT = "UI_ERROR_MESSAGE"
local RED = { 1, 0.1, 0.1 }
local YELLOW = { 1, 0.82, 0 }
local SAMPLE_QUEST, SAMPLE_MANA, SAMPLE_EVERY, SAMPLE_WIDTH = "Kobold Vermin slain: 3/8", "Not enough mana", 1, 512
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
	{ row = "errorSight", types = {}, words = { "SPELL_FAILED_LINE_OF_SIGHT" } },
	{ row = "errorControl", types = { "ERR_ATTACK_STUNNED", "ERR_ATTACK_PACIFIED", "ERR_ATTACK_FLEEING", "ERR_ATTACK_CONFUSED", "ERR_ATTACK_CHARMED" },
		words = { "SPELL_FAILED_STUNNED", "SPELL_FAILED_SILENCED", "SPELL_FAILED_PACIFIED", "SPELL_FAILED_FLEEING", "SPELL_FAILED_CONFUSED",
			"SPELL_FAILED_CHARMED", "SPELL_FAILED_POSSESSED" } },
	{ row = "errorForm", types = { "ERR_SPELL_FAILED_SHAPESHIFT_FORM_S", "ERR_NOT_WHILE_SHAPESHIFTED", "ERR_NO_ITEMS_WHILE_SHAPESHIFTED" },
		words = { "SPELL_FAILED_NOT_SHAPESHIFT", "SPELL_FAILED_ONLY_SHAPESHIFT" } },
}
local REPEATS = { "ERR_SPELL_FAILED_TOTEMS", "ERR_SPELL_FAILED_EQUIPPED_ITEM", "ERR_SPELL_ALREADY_KNOWN_S", "ERR_SPELL_FAILED_SHAPESHIFT_FORM_S",
	"ERR_SPELL_FAILED_ALREADY_AT_FULL_MANA", "ERR_OUT_OF_MANA", "ERR_SPELL_OUT_OF_RANGE", "ERR_SPELL_FAILED_S", "ERR_SPELL_FAILED_REAGENTS",
	"ERR_SPELL_FAILED_REAGENTS_GENERIC", "ERR_SPELL_FAILED_NOTUNSHEATHED", "ERR_SPELL_UNLEARNED_S", "ERR_SPELL_FAILED_EQUIPPED_SPECIFIC_ITEM",
	"ERR_SPELL_FAILED_ALREADY_AT_FULL_POWER_S", "ERR_SPELL_FAILED_EQUIPPED_ITEM_CLASS_S", "ERR_SPELL_FAILED_ALREADY_AT_FULL_HEALTH",
	"ERR_SPELL_FAILED_CANT_FLY_HERE", "ERR_GENERIC_NO_VALID_TARGETS", "ERR_ITEM_COOLDOWN", "ERR_CANT_USE_ITEM", "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS" }

local S = { types = {}, words = {}, kinds = 0, hidden = 0, relistened = 0 }
local frame, listening, repeats = nil, false, nil
local Apply

local function Global(name)
	local ok, value = pcall(function()
		return _G[name]
	end)
	if ok and not ns.IsSecret(value) then
		return value
	end
	return nil
end

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

local function Red()
	local colour = Global("RED_FONT_COLOR")
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return RED[1], RED[2], RED[3]
end

local function GameLeavesOut(id)
	return Field(Global("BLACK_LISTED_MESSAGE_TYPES"), id) == true
end

local FL = { time = 0.2, lift = 0.4, lines = setmetatable({}, { __mode = "k" }) }

function FL.Wanted()
	local cvar = Global("C_CVar")
	if type(cvar) ~= "table" or type(cvar.GetCVar) ~= "function" then
		return false
	end
	local ok, value = pcall(cvar.GetCVar, "flashErrorMessageRepeats")
	return ok and not ns.IsSecret(value) and value == "1"
end

function FL.Step(self)
	local now = GetTime()
	for line, at in pairs(FL.lines) do
		local okText, text = pcall(line.GetText, line)
		if not okText or ns.IsSecret(text) or text ~= at.text then
			FL.lines[line] = nil
		else
			local share = (now - at.at) / FL.time
			local okShown, shown = pcall(line.IsShown, line)
			if share >= 1 or share < 0 or not okShown or ns.IsSecret(shown) or shown ~= true then
				pcall(line.SetTextColor, line, at.r, at.g, at.b)
				FL.lines[line] = nil
			else
				local lift = (share > 0.5 and (1 - share) / 0.5 or share / 0.5) * FL.lift
				pcall(line.SetTextColor, line, math.min(at.r + lift, 1), math.min(at.g + lift, 1), math.min(at.b + lift, 1))
			end
		end
	end
	if next(FL.lines) == nil then
		self:Hide()
	end
end

function FL.Flash(line, message)
	if not FL.Wanted() then
		return
	end
	local at = FL.lines[line]
	if not at then
		local ok, r, g, b = pcall(line.GetTextColor, line)
		if not (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) then
			return
		end
		at = { r = r, g = g, b = b, text = message }
		FL.lines[line] = at
	end
	at.at = GetTime()
	if not FL.frame then
		local ok, made = pcall(CreateFrame, "Frame")
		if not ok or type(made) ~= "table" then
			FL.lines[line] = nil
			return
		end
		ns.Own[made] = true
		made:Hide()
		made:SetScript("OnUpdate", FL.Step)
		FL.frame = made
	end
	FL.frame:Show()
end

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
	pcall(FL.Flash, line, message)
	pcall(errors.ResetMessageFadeByID, errors, id)
	return true
end

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

local function Now()
	return ns.Get(KEY .. ".errorsWhen") ~= "combat" or InCombatLockdown()
end

local function Judge(_, errors, messageType, message)
	if Hides(messageType, message) and Now() then
		S.hidden = S.hidden + 1
		return
	end
	Show(errors, messageType, message)
end

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
		if S.held then
			S.relistened = S.relistened + 1
		end
		Soon()
		return
	end
	if not S.held or S.gameOff then
		return
	end
	if ns.IsSecret(messageType) or ns.IsSecret(message) then
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
	pcall(Show, errors, messageType, message)
	Soon()
end

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

local function GameOff()
	if S.held then
		S.gameOff = true
	end
end

local function GameOn()
	S.gameOff = nil
	Apply()
end

local function AfterScript()
	if S.held or S.aside then
		local errors = GameFrame()
		if errors ~= nil and Listens(errors) == true then
			Apply()
		end
	end
end

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

local function Size()
	local errors = GameFrame()
	if errors == nil or type(errors.SetFont) ~= "function" then
		return
	end
	local size = ns.Enabled(KEY) and not ns.PartStopped(KEY, PART) and tonumber(ns.Get(KEY .. ".errorTextSize")) or 100
	size = math.max(50, math.min(150, size))
	if size ~= 100 and S.object == nil and type(errors.GetFontObject) == "function" then
		local ok, object = pcall(errors.GetFontObject, errors)
		S.object = ok and type(object) == "table" and not ns.IsSecret(object) and object or false
	end
	S.sizeRefused = ns.TextStyle(errors, { percent = size }) == false and size ~= 100 or nil
end

function ns.ErrorTextRefont()
	local errors = GameFrame()
	if errors == nil or not S.object or type(errors.SetFontObject) ~= "function" then
		return
	end
	if pcall(errors.SetFontObject, errors, S.object) then
		ns.TextStyleForget(errors)
		Size()
	end
end

function Apply()
	Size()
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
			S.gameOff = nil
			if Blocked(errors) then
				Wait()
				Listen(S.held)
				return
			end
			pcall(errors.UnregisterEvent, errors, EVENT)
			local now = Listens(errors)
			if now ~= false then
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

local function Status()
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
		local lines = { ("Error messages: %d of %d kinds hidden%s, %d messages so far."):format(S.kinds, #KINDS,
			ns.Get(KEY .. ".errorsWhen") == "combat" and " in fights only" or "", S.hidden) }
		if S.relistened > 0 then
			lines[2] = ("Error messages: another addon gave the game its error text back, and %d messages then showed whatever their kind.")
				:format(S.relistened)
		end
		return lines
	elseif S.kinds == 0 then
		return { "Error messages: no kind is on, so nothing is hidden." }
	end
	return { "Error messages: this client names none of these kinds, so nothing is hidden." }
end

ns.AddStatus(KEY, function()
	local lines = Status()
	if S.sizeRefused then
		lines[#lines + 1] = "Error text size: the game refused a size, so the error text keeps the game's."
	end
	return lines
end)

local function Yellow()
	local colour = Global("YELLOW_FONT_COLOR")
	local r, g, b = Field(colour, "r"), Field(colour, "g"), Field(colour, "b")
	if ns.Finite(r) and ns.Finite(g) and ns.Finite(b) then
		return r, g, b
	end
	return YELLOW[1], YELLOW[2], YELLOW[3]
end

local function ManaWords()
	local text = Global("ERR_OUT_OF_MANA")
	return type(text) == "string" and text ~= "" and text or SAMPLE_MANA
end

local function CopyFont(text, errors)
	local ok, file, size, flags = pcall(errors.GetFont, errors)
	if ok and not (ns.IsSecret(file) or ns.IsSecret(flags)) and type(file) == "string" and ns.Finite(size) and size > 0 then
		pcall(text.SetFont, text, file, size, type(flags) == "string" and flags or "")
	end
	local okOffset, x, y = pcall(errors.GetShadowOffset, errors)
	if okOffset and ns.Finite(x) and ns.Finite(y) then
		pcall(text.SetShadowOffset, text, x, y)
	end
end

local function SampleHeight(text)
	local ok, height = pcall(text.GetStringHeight, text)
	return ok and ns.Finite(height) and height > 0 and height or 0
end

if ns.TestMode and ns.TestMode.StandIn then
	ns.TestMode.StandIn({ id = "errortext", module = KEY, game = "UIErrorsFrame", label = "Error text", corner = "TOP",
		real = function()
			return false
		end,
		Build = function(holder)
			holder.mana = ns.OwnText(holder, "OVERLAY", "GameFontNormalLarge")
			holder.quest = ns.OwnText(holder, "OVERLAY", "GameFontNormalLarge")
			if not (holder.mana and holder.quest) then
				error("no text for the error sample", 0)
			end
			for _, text in ipairs({ holder.mana, holder.quest }) do
				text:SetWidth(SAMPLE_WIDTH)
				text:SetJustifyH("CENTER")
			end
			holder.mana:SetPoint("TOP", holder, "TOP", 0, 0)
			holder.quest:SetPoint("TOP", holder.mana, "BOTTOM", 0, 0)
		end,
		Paint = function(holder)
			local errors = GameFrame()
			for _, text in ipairs({ holder.mana, holder.quest }) do
				if errors ~= nil then
					CopyFont(text, errors)
				end
			end
			holder.mana:SetText(ManaWords())
			holder.mana:SetTextColor(Red())
			holder.quest:SetText(SAMPLE_QUEST)
			holder.quest:SetTextColor(Yellow())
			return SAMPLE_WIDTH, math.max(1, SampleHeight(holder.mana) + SampleHeight(holder.quest))
		end })
end

function ns.ErrorTextSized()
	pcall(Size)
	local errors = GameFrame()
	if errors == nil or not (ns.PanelShown ~= nil and ns.PanelShown()) or (ns.TestMode ~= nil and ns.TestMode.IsOn()) then
		return
	end
	local now = GetTime()
	if S.sampleAt ~= nil and now - S.sampleAt < SAMPLE_EVERY then
		return
	end
	S.sampleAt = now
	local r, g, b = Red()
	pcall(errors.AddMessage, errors, ManaWords(), r, g, b, 1)
end

function ns.ErrorFilterRefresh()
	Apply()
end
