local _, ns = ...

-- The text of the chat windows: the face and outline, the shadow, how many lines a window keeps and whether old messages fade. Runs with the
-- chat module, after each pass of it and at UPDATE_CHAT_WINDOWS and PLAYER_ENTERING_WORLD, on each window named in CHAT_FRAMES. What the game
-- gave a window is read the first time a row asks for a change and put back when the row goes back to the game's value or the module is off.
-- The size of the text stays the game's: both ways the game sets it read the face and the outline back first (FloatingChatFrame.lua:1192-1193,
-- ChatFrameOverrides.lua:121-122), so a face and an outline set here stay through a size change.
-- A size change the player makes also copies the face and flags of ChatFrame1 to GMChatFrame and CommunitiesFrame.Chat.MessageFrame
-- (FloatingChatFrame.lua:1192-1201). Those two frames are not in CHAT_FRAMES, so a face set here spreads to them and is not put back there. The game's own values are 128 lines and
-- 120 seconds (ChatFrameOverrides.lua:2-3). ScrollingMessageFrame.lua:240-276 has the four calls for lines and fading. No message text is read, so the chat lockdown does not touch this module.

local KEY = "chat"
local GAME_LINES, GAME_TIME = 128, 120

-- Per chat window: the parts that changed it, each with what the game gave: { font = { file, flags, setFile, setFlags }, shadow = { x, y },
-- lines = { base }, fading = { base }, time = { base } }
local records = setmetatable({}, { __mode = "k" })

local function Opt(key)
	return ns.Get(KEY .. "." .. key)
end

local function Plain(value, kind)
	return not ns.IsSecret(value) and type(value) == kind
end

local function Font(frame, record, restore)
	local want = not restore and (Opt("font") ~= "default" or Opt("outline") ~= "game")
	local mine = record.font
	if not want and not mine then
		return
	end
	local ok, file, size, flags = pcall(frame.GetFont, frame)
	if not ok or not Plain(file, "string") or not Plain(size, "number") or not Plain(flags, "string") then
		error("GetFont gave nothing for a chat window", 0)
	end
	if mine and mine.setFile ~= nil and (file ~= mine.setFile or flags ~= mine.setFlags) then
		-- Set again by the game or another addon: what it gave now is the one to go back to.
		mine.setFile, mine.setFlags = nil, nil
	end
	if not mine then
		mine = {}
		record.font = mine
	end
	if mine.setFile == nil then
		mine.file, mine.flags = file, flags
	end
	local targetFile, targetFlags = mine.file, mine.flags
	if want then
		targetFile = ns.FontFile(Opt("font")) or mine.file
		targetFlags = ns.OutlineFlags(Opt("outline")) or mine.flags
	end
	if file ~= targetFile or flags ~= targetFlags then
		local set, result = pcall(frame.SetFont, frame, targetFile, size, targetFlags)
		if not set or result == false then
			error("SetFont refused for a chat window", 0)
		end
	end
	if targetFile == mine.file and targetFlags == mine.flags then
		record.font = nil
	else
		mine.setFile, mine.setFlags = targetFile, targetFlags
	end
end

local function Shadow(frame, record, restore)
	local off = not restore and Opt("shadow") == false
	local mine = record.shadow
	if not off and not mine then
		return
	end
	local ok, x, y = pcall(frame.GetShadowOffset, frame)
	if not ok or not Plain(x, "number") or not Plain(y, "number") then
		error("GetShadowOffset gave nothing for a chat window", 0)
	end
	if not mine then
		mine = { x, y }
		record.shadow = mine
	end
	local targetX, targetY = 0, 0
	if not off then
		targetX, targetY = mine[1], mine[2]
	end
	if (x ~= targetX or y ~= targetY) and not pcall(frame.SetShadowOffset, frame, targetX, targetY) then
		error("SetShadowOffset refused for a chat window", 0)
	end
	if not off then
		record.shadow = nil
	end
end

-- A value of the window with a getter and a setter: set to `value` while wanted, and put back to what the game gave when not.
local function Keep(frame, record, name, get, set, wanted, value)
	local mine = record[name]
	if not wanted and not mine then
		return
	end
	local ok, current = pcall(frame[get], frame)
	if not ok or not Plain(current, type(value)) then
		error(get .. " gave nothing for a chat window", 0)
	end
	if not mine then
		mine = { base = current }
		record[name] = mine
	end
	local target = mine.base
	if wanted then
		target = value
	end
	if current ~= target and not pcall(frame[set], frame, target) then
		error(set .. " refused for a chat window", 0)
	end
	if not wanted then
		record[name] = nil
	end
end

local function Lines(frame, record, restore)
	local history = Opt("history")
	Keep(frame, record, "lines", "GetMaxLines", "SetMaxLines", not restore and history ~= GAME_LINES, history)
end

local function Fading(frame, record, restore)
	local fade, after = Opt("fade") == true, Opt("fadeAfter")
	Keep(frame, record, "fading", "GetFading", "SetFading", not restore and not fade, false)
	Keep(frame, record, "time", "GetTimeVisible", "SetTimeVisible", not restore and fade and after ~= GAME_TIME, after)
end

-- One part on one window. With the module off, or the part stopped after enough refusals, the part puts the game's value back, and a refusal
-- then is let go.
local function Run(part, fn, frame, record)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		ns.EachPart(KEY, part, fn, frame, record, false)
	else
		pcall(fn, frame, record, true)
	end
end

local function Window(frame)
	local record = records[frame]
	if not record then
		record = {}
		records[frame] = record
	end
	Run("chat font", Font, frame, record)
	Run("chat shadow", Shadow, frame, record)
	Run("chat history", Lines, frame, record)
	Run("chat fading", Fading, frame, record)
end

function ns.ChatTextPass()
	if type(CHAT_FRAMES) ~= "table" or ns.IsSecret(CHAT_FRAMES) then
		return
	end
	for _, name in ipairs(CHAT_FRAMES) do
		local frame = type(name) == "string" and _G[name]
		if type(frame) == "table" and not ns.IsSecret(frame) and not ns.Forbidden(frame) then
			Window(frame)
		end
	end
end

local function Event()
	ns.ChatTextPass()
end

ns.AddEvent(KEY, "UPDATE_CHAT_WINDOWS", Event)
ns.AddEvent(KEY, "PLAYER_ENTERING_WORLD", Event)
