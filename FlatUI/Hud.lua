local ADDON_NAME, ns = ...

-- The minimap with the plate of its zone name and the tracking button beside it and the text around it (MapText.lua), the bag bar, the buff and debuff icons, the experience and reputation bars and the micro menu, and the objective
-- tracker and its quest count (QuestCount.lua), the loot window and rolls, alerts, breath and countdown timers, the queue panel, the damage meter and the zone event bars,
-- and the kinds of the game's red error messages that are hidden (ErrorFilter.lua). The damage meter can be cleared as the player enters a dungeon or raid
-- (MeterClear.lua). The hit table under the player frame is HitTable.lua, with its numbers from HitTableCalc.lua.
-- A frame the game may protect has nothing made on it in combat: ns.MaybeProtected asks the client each time.
-- Each part has its own switch and puts the game's look back when it is off. The game's frame art is made
-- transparent and left in place, and thin borders and flat fills take its place. The map keeps the shape of the
-- mask the game gives it: its border is a disc cut by the same mask, laid below the map. With Close the gap under the zone name on and the ring
-- hidden, the plate of the zone name and the buttons beside it hang from the map, as close as Gap under the zone name says and no further out
-- than the game's place, and the mail icon and the addon list button move out of the room it closes (headerGap, below).
-- Inside some cities the game shows a map of the city in the minimap, and the setting Minimap in cities says what is done then.
-- Two rows add a text of Flat UI's own, on a frame of its own whose OnUpdate reads a bar's value ten times a second (no method of the game's is
-- followed): Seconds left on rolls puts the whole seconds left over the right end of each roll's timer, the number and the timer's bar red under 10
-- (SetStatusBarColor, given back as the roll ends or the row goes off; ROLL.Time), and Seconds on the timers puts the time left, as 1:12, at the
-- right under the breath, fatigue and feign death bars, red under 10 while the timer runs out (MIRROR.Time). Opacity in combat eases the objective
-- tracker down as a fight starts and back up as it ends, and Questie's the same way (ns.TrackerEase).
-- Sound before a roll ends (hud.lootRollSound, None by default) plays once as a roll still on the screen comes down to 5 seconds left, read from
-- the same seconds (ROLL.Tick, ROLL.Sound); the game takes a roll away once you roll on it, so only a roll you have not rolled on rings.

local KEY = "hud"
local LABEL = "Minimap and HUD"
local MAP_MASK = "ui-hud-minimap-frame-generic-mask"
-- The mask of a square map: a plain white picture (the game's own code passes an atlas name to Minimap:SetMaskTexture, and the documentation takes any
-- texture asset: MinimapFrameAPIDocumentation.lua:141-149).
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
-- Seconds between two looks at the minimap zoom.
local ZOOM_EVERY = 0.5
-- The buttons round the minimap that a setting can switch off: the setting, and the field of the cluster or the global name of the frame
-- and the fields of it that take the mouse, since a parent does not turn off the mouse of its children (Blizzard_Minimap/Mainline/Minimap.xml:39-43,
-- Camelot/MinimapIndicatorFrameTemplate.xml:12) (Mainline/Minimap.xml:25 and 46, Mainline/GameTime.xml:3, Camelot/AddonCompartment.xml:3,
-- Blizzard_TimeManager/Mainline/Blizzard_TimeManager.xml:178). CraftingOrderFrame is for a client before 1.60.1.70425: Forever has none since then.
local MAP_BUTTONS = { { option = "btnTracking", key = "Tracking", mouse = { "Button" } },
	{ option = "btnMail", key = "IndicatorFrame", mouse = { "MailFrame", "CraftingOrderFrame" } }, { option = "btnCalendar", name = "GameTimeFrame" },
	{ option = "btnClock", name = "TimeManagerClockButton" }, { option = "btnAddons", name = "AddonCompartmentFrame" } }
-- The setting of the colour of each debuff type. A bleed and a debuff with no type take the Other colour.
local TYPE_ROWS = { Magic = "colourMagic", Curse = "colourCurse", Disease = "colourDisease", Poison = "colourPoison", Bleed = "colourOther", None = "colourOther" }
local DIEL_BORDER = "UI-HUD-Minimap-Frame-Cycle"
-- The city map. In some cities the game loads Blizzard_HybridMinimap and shows HybridMinimap, a child of the minimap that covers its whole square
-- (Blizzard_Minimap\Mainline\Minimap.lua:236-242, Blizzard_HybridMinimap.xml:5-10). It is in the lowest strata, BACKGROUND, at level 100, and both
-- are fixed (xml:5), and the game switches the ground of the minimap off while it shows (Blizzard_HybridMinimap.lua:44). The pins of its map are at
-- levels 2000 to 9000 (Blizzard_MapCanvas\MapCanvas_PinFrameLevelsManager.lua:3-4). The cover is a child of the minimap as well, in the strata of the
-- minimap (LOW, from its cluster: Minimap.xml:3, 56-60) at the level of the minimap. That puts it over the city map and its pins, and over what
-- the minimap itself draws, and under the zoom buttons and the ring, which are children of the minimap one level up (Minimap.xml:71-125). It hides
-- with the minimap.
local CITY_ADDON = "Blizzard_HybridMinimap"
local COVER_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Cover.tga"
-- The plate of the zone name. Since 1.60.1.70425 it is the picture StateTexture of the button that holds the zone name, ZoneTextButton, 152 by 23,
-- with a second picture, AddTexture, that glows over it under the mouse (Blizzard_Minimap/Mainline/Minimap.xml:24,
-- Camelot/MinimapZoneTextButton.xml:3-38). Before, it was the nine-slice BorderTop of the cluster, with these pieces; a client that still has it
-- gets those pieces faded and the border round the nine-slice. The other nine-slices of this file have the same pieces.
local HEADER_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
	"CharacterReagentBag0Slot", "KeyRingButton" }
local AURA_FRAMES = { "BuffFrame", "DebuffFrame", "ExternalDefensivesFrame" }
-- The border of a debuff by the type the game gives it, and of a weapon enchant.
local DEBUFF_COLOURS = {
	Magic = { 0.2, 0.6, 1 },
	Curse = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison = { 0, 0.6, 0 },
	Bleed = { 0.8, 0, 0 },
	None = { 0.8, 0, 0 },
}
local ENCHANT_COLOUR = { 0.64, 0.21, 0.93 }
local BAR_CONTAINERS = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
-- The colour of each fill the game draws, by its atlas. The game draws these bars from pictures and sets no colour on them.
local FILL_COLOURS = {
	["ui-hud-experiencebar-fill-experience"] = { 0.58, 0, 0.55 },
	["ui-hud-experiencebar-fill-rested"] = { 0, 0.39, 0.88 },
	["ui-hud-experiencebar-fill-reputation-faction-red"] = { 0.8, 0.3, 0.22 },
	["ui-hud-experiencebar-fill-reputation-faction-orange"] = { 0.75, 0.27, 0 },
	["ui-hud-experiencebar-fill-reputation-faction-yellow"] = { 0.9, 0.7, 0 },
	["ui-hud-experiencebar-fill-reputation-faction-green"] = { 0, 0.6, 0.1 },
	["ui-hud-experiencebar-fill-reputation-faction-blue"] = { 0, 0.44, 0.87 },
	["ui-hud-experiencebar-fill-honor"] = { 1, 0.24, 0 },
	["ui-hud-experiencebar-fill-artifactpower"] = { 0.9, 0.8, 0.5 },
}
-- A fill that is none of those.
local NEUTRAL_FILL = { 0.5, 0.5, 0.5 }
local DIVIDER_POOLS = { "HorizontalDividersPool", "VerticalDividersPool" }
local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton", "LegacyMicroButton",
	"QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton",
	"StoreMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
-- The modules of the objective tracker, each with a header of its own.
local TRACKER_MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker", "QuestObjectiveTracker",
	"AdventureObjectiveTracker", "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker",
	"ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }
-- The frame around a tracker bar: quest and timer bars have the first three pieces, bonus and scenario bars the last two.
local TRACKER_BAR_ART = { "BorderLeft", "BorderRight", "BorderMid", "BarFrame", "IconBG" }
-- The picture the game fills the tracker bars and the countdown bars with, and the one it fills the roll timers with. The game colours both.
local BAR_FILE = "Interface\\TargetingFrame\\UI-StatusBar"
local ROLL_FILE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"
-- The flat background of a window, and the frame and art of an item button.
local PANEL_FILL = { "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }
local SLOT_ART = { "NormalTexture", "PushedTexture", "IconBorder" }
local ROLL_FRAMES, METER_WINDOWS = 4, 3
-- The roll frames (Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml:291-549). game and flat: the buttons where the game puts them, given back when
-- the row goes off, and where Flat UI puts them, a row of Need, Greed (or Transmog in its place) and Pass at the right, level with the icon, each
-- { key in the button container, point, the frame it hangs from (a key, "frame" or "container"), its point, x, y }, in an order that never
-- hangs a button from one that hangs from it. button: the side of a button, the game's and Flat UI's. timer: the game's size and spot of the timer
-- from the bottom left corner (xml:370-374), and Flat UI's inset from both bottom corners. mover: the box of the rolls in /flatui move (Movers.lua),
-- part: the part that hangs the rolls there, step: the game's room for each roll (GroupLootFrame.lua:15), moved: per roll frame hung from the box.
local ROLL = {
	game = { { "NeedButton", "TOPLEFT", "container", "TOPLEFT", 14, -7 }, { "PassButton", "LEFT", "NeedButton", "RIGHT", 6, 2 },
		{ "GreedButton", "TOP", "NeedButton", "BOTTOM", 0, 5 }, { "TransmogButton", "CENTER", "GreedButton", "CENTER", 0, 0 } },
	flat = { { "PassButton", "RIGHT", "frame", "RIGHT", -8, 5 }, { "GreedButton", "RIGHT", "PassButton", "LEFT", -2, 0 },
		{ "TransmogButton", "CENTER", "GreedButton", "CENTER", 0, 0 }, { "NeedButton", "RIGHT", "GreedButton", "LEFT", -2, 0 } },
	button = 32, flatButton = 26,
	timer = { width = 190, height = 8, x = 3, y = 2, inset = 8, lift = 6 },
	mover = "FlatUILootRolls", part = "loot roll spot", step = 100,
	moved = setmetatable({}, { __mode = "k" }),
}
local ALERT_SYSTEMS = { "LootAlertSystem", "MoneyWonAlertSystem", "HonorAwardedAlertSystem" }
-- The backgrounds of those alerts and the ring round the icon of money and honour. The game shows and hides them and never sets their alpha.
local ALERT_ART = { "Background", "PvPBackground", "RatedPvPBackground", "BGAtlas", "IconBorder" }
-- The cast colour that stands for each picture a breath or fatigue timer is filled with.
local MIRROR_FILLS = { ["ui-castingbar-filling-standard"] = "castColour", ["ui-castingbar-filling-applyingcrafting"] = "craftColour",
	["ui-castingbar-filling-channel"] = "channelColour" }
local MIRROR_BACKGROUND = "ui-castingbar-background"
-- Seconds on the timers: how often the time left is read, and the red of its last 10 seconds. The functions of that row (MIRROR.Time, below).
local MIRROR = { every = 0.1, red = { 1, 0.25, 0.25 } }
local WIDGET_CONTAINERS = { "UIWidgetTopCenterContainerFrame", "UIWidgetBelowMinimapContainerFrame", "UIWidgetCenterScreenContainerFrame",
	"UIWidgetPowerBarContainerFrame" }
local WIDGET_ART = { "BorderLeft", "BorderRight", "BorderCenter", "BGLeft", "BGRight", "BGCenter" }
-- The setting of each part of the other frames.
local OPTION = { ["tracker headers"] = "trackerHeaders", ["tracker bars"] = "trackerBars", ["tracker items"] = "trackerItems", ["tracker panel"] = "trackerPanel",
	["loot window"] = "lootWindow", ["loot rolls"] = "lootRolls", alerts = "alerts", ["mirror timers"] = "mirror",
	["countdown timers"] = "countdown", ["queue status"] = "queue", ["damage meter"] = "meter", ["zone bars"] = "zoneBars" }

local minimap = {}
local edges = setmetatable({}, { __mode = "k" })
local bags = setmetatable({}, { __mode = "k" })
local auras = setmetatable({}, { __mode = "k" })
local borders = setmetatable({}, { __mode = "k" })
local fills = setmetatable({}, { __mode = "k" })
local micro = setmetatable({}, { __mode = "k" })
local dividerFrames = setmetatable({}, { __mode = "k" })
-- Dividers whose own frame had its alpha set, so that it is given back when the part is left to the pictures.
local dividerFaded = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
-- Per frame, or per name for the minimap: true while its art is faded.
local faded = setmetatable({}, { __mode = "k" })
-- Per frame of the tracker, loot, alerts, timers and the rest: { part, apply = the function that styles it, outline, art = the frames whose art is faded }
local plates = setmetatable({}, { __mode = "k" })
local globalHooks = {}
-- Per aura button: true while the sizes of its duration and count text are set here.
local sized = setmetatable({}, { __mode = "k" })
-- Per button round the minimap: { alpha, off = true while its opacity is set to 0 here, mice = per mouse frame { mouse = what the game had, off = true while its mouse is off here } }
local mapButtons = setmetatable({}, { __mode = "k" })
-- Per experience or reputation bar: { game = the text the game set last, ours = true while the text shown is ours, line = that text }
local xpTexts = setmetatable({}, { __mode = "k" })
-- The objective tracker: alpha = the opacity the game had while a lower one is set here, sent = the one set last, and the ease of Opacity in combat
-- (ns.TrackerEase: target, from, t, span, back, driver).
local look = {}
local retry = false
local Refresh

-- True while a part is on. A part that stopped on errors counts as off.
local function On(part, option)
	return ns.Enabled(KEY) and not ns.PartStopped(KEY, part) and ns.Get(KEY .. "." .. option) == true
end

-- The value of a setting of a part, or nothing while the page is off or the part has stopped: the game's own look is wanted then.
local function Val(part, option)
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, part) then
		return ns.Get(KEY .. "." .. option)
	end
	return nil
end

-- The image file a bar texture row names: nothing for the choice of the Flat UI page, false for a solid colour.
local function RowFile(option)
	local id = ns.Get(KEY .. "." .. option)
	if id == nil or id == "default" then
		return nil
	end
	return ns.BarFile(id) or false
end

-- The share of an icon trimmed on every side.
local function Crop()
	return ns.Get(KEY .. ".crop") / 100
end

-- A text at a percent of the size the game gave it; 100 gives that size back. A refusal is said in /flatui status and the game's size stays.
local function Size(fontString, percent, what)
	if fontString == nil or ns.IsSecret(fontString) or type(fontString) ~= "table" or type(fontString.GetFont) ~= "function" then
		return
	end
	if ns.TextStyle(fontString, { percent = percent }) == false then
		ns.Note(KEY, LABEL .. ": the game refused a new size for " .. what .. ".")
	end
end

-- A frame of the game's by name, or nil when it is missing or forbidden.
local function Frame(name)
	local frame = _G[name]
	if frame == nil or ns.Forbidden(frame) then
		return nil
	end
	return frame
end

-- A frame held in a field of a frame of the game, unless it is missing, withheld or forbidden.
local function Child(frame, key)
	local value = frame[key]
	if ns.Forbidden(value) then
		return nil
	end
	return value
end

-- True in combat: nothing is made or placed now, and the whole module looks again when combat ends.
local function InFight()
	if not InCombatLockdown() then
		return false
	end
	if not retry then
		retry = true
		ns.OutOfCombat(function()
			retry = false
			ns.Try(KEY, Refresh)
		end)
	end
	return true
end

-- True when the game may protect the frame and combat has started: nothing is made on it now, and the whole
-- module looks again when combat ends.
local function Later(frame)
	return InCombatLockdown() and ns.MaybeProtected(frame) and InFight()
end

-- Runs one part for one frame. A part that stopped on errors is off, so it runs only to give back what it had styled, and
-- the failure that stops it has every part look again for that.
local looking = false
local function Run(part, fn, ...)
	if ns.PartStopped(KEY, part) then
		pcall(fn, ...)
	elseif not ns.EachPart(KEY, part, fn, ...) and ns.PartStopped(KEY, part) and not looking then
		looking = true
		pcall(Refresh)
		looking = false
	end
end

-- True when the art of a frame has to change: it is on, or it was on and has to come back. Art that was never faded is never touched.
local function Moves(key, on)
	local was = faded[key] or false
	faded[key] = on
	return on ~= was
end

-- Follows one of the game's methods in a table of methods (a mixin) that the game copies onto the frames it makes afterwards. No method of a
-- frame that exists is hooked: that hook is a field write on the game's frame (EllesmereUIChat/EllesmereUIChat.lua:4410-4417), and each place
-- that needed one follows the game's events, or a script of the frame, one frame later instead.
local function Follow(frame, method, fn)
	local done = hooked[frame]
	if done == nil then
		done = {}
		hooked[frame] = done
	end
	if done[method] or type(hooksecurefunc) ~= "function" or type(frame[method]) ~= "function" then
		return
	end
	done[method] = true
	ns.HookMethod(frame, method, fn)
end

-- Runs fn on the next frame, once for any number of calls before then. The game's own code has finished by then, so what fn sets stays.
local soon = setmetatable({}, { __mode = "k" })
local function Soon(key, fn)
	if soon[key] then
		return
	end
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		fn()
		return
	end
	soon[key] = true
	C_Timer.After(0, function()
		soon[key] = nil
		if not ns.IsStopped(KEY) then
			fn()
		end
	end)
end

-- Runs fn on the next frame after each run of a script of a frame of the game's (HookScript writes nothing on the frame), once per name.
local function OnScript(frame, script, name, fn)
	local done = hooked[frame]
	if done == nil then
		done = {}
		hooked[frame] = done
	end
	if done[name] or type(frame.HookScript) ~= "function" then
		return
	end
	done[name] = true
	pcall(frame.HookScript, frame, script, function()
		Soon(fn, fn)
	end)
end

-- Fades every picture a frame draws (its regions), and gives them back. A call on a region, never on the frame.
local function FadePictures(frame, hide)
	if frame == nil or ns.IsSecret(frame) or type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
		return
	end
	local ok, list = pcall(function() return { frame:GetRegions() } end)
	if not ok or ns.IsSecret(list) then
		return
	end
	for _, region in ipairs(list) do
		ns.SetFaded(region, hide)
	end
end

-- The dividers of a bar are pooled, and the game places them again on every layout. A divider is a frame of nine-slice pieces: with the part
-- left to the regions (pieces, a function read each time, so that a change of the row applies at once), the alpha is set on each picture and never on the
-- frame, and the alpha of a frame set earlier is given back.
local function FadeDividers(frame, part, option, pieces)
	local hide = On(part, option)
	if type(pieces) == "function" then
		pieces = pieces()
	end
	if not hide and not dividerFrames[frame] then
		return
	end
	dividerFrames[frame] = true
	for _, key in ipairs(DIVIDER_POOLS) do
		local pool = frame[key]
		if pool ~= nil and not ns.IsSecret(pool) and type(pool) == "table" and pool.EnumerateActive then
			for divider in pool:EnumerateActive() do
				if pieces then
					FadePictures(divider, hide)
					if dividerFaded[divider] then
						dividerFaded[divider] = nil
						ns.SetFaded(divider, false)
					end
				else
					ns.SetFaded(divider, hide)
					dividerFaded[divider] = hide or nil
					FadePictures(divider, false)
				end
			end
		end
	end
end

-- The game makes new dividers when a layout needs more of them, and lays out again when the size of the bar changes (BagsBar.lua:73-126,
-- StatusTrackingManagerOverrides.lua:72-78), so a bar is looked at again on the next frame after its size changes.
local function FollowDividers(frame, part, option, pieces)
	OnScript(frame, "OnSizeChanged", "dividers", function()
		Run(part, FadeDividers, frame, part, option, pieces)
	end)
end

-- Minimap -------------------------------------------------------------------------------------

-- The border around the map is a disc in the border colour, a border larger than the map and cut by the mask
-- of the map, in the lowest strata so that the map covers all but its edge. It goes with the other borders.
local function MapBorder(on, square)
	local ring = minimap.ring
	if not ring then
		local map = Frame("Minimap")
		if not on or square or not map then
			return
		end
		local ok, parent = pcall(map.GetParent, map)
		if not ok or not parent or ns.Forbidden(parent) or Later(parent) then
			return
		end
		local frame = CreateFrame("Frame", nil, parent)
		ns.Own[frame] = true
		frame:SetFrameStrata("BACKGROUND")
		frame:SetAllPoints(map)
		local disc = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
		ns.Own[disc] = true
		local mask = frame:CreateMaskTexture()
		ns.Own[mask] = true
		mask:SetAtlas(MAP_MASK)
		mask:SetAllPoints(disc)
		disc:AddMaskTexture(mask)
		ring = { frame = frame, disc = disc }
		minimap.ring = ring
		ns.Count(KEY)
	end
	local t = ns.Pixels(ring.frame, ns.Get("general.thickness"))
	ring.disc:SetPoint("TOPLEFT", ring.frame, "TOPLEFT", -t, t)
	ring.disc:SetPoint("BOTTOMRIGHT", ring.frame, "BOTTOMRIGHT", t, -t)
	local r, g, b = ns.BorderRGB()
	ring.disc:SetColorTexture(r, g, b, 1)
	ring.disc:SetShown(on and not square and not ns.Borderless())
end

-- The frame of the city map, or nothing while the game has not loaded it or does not let it be read.
local function CityMap()
	local map = _G.HybridMinimap
	if map == nil or ns.Forbidden(map) then
		return nil
	end
	return map
end

-- True while the game shows the city map, false while it does not, and nothing while the game will not say.
local function CityShown()
	local map = CityMap()
	if not map then
		return false
	end
	local ok, shown = pcall(map.IsShown, map)
	if not ok or ns.IsSecret(shown) or type(shown) ~= "boolean" then
		return nil
	end
	return shown
end

-- The level of a frame as the game reports it, or nothing when it will not say.
local function Level(frame)
	local ok, level = pcall(frame.GetFrameLevel, frame)
	if not ok or ns.IsSecret(level) or type(level) ~= "number" then
		return nil
	end
	return level
end

-- The strata and level of a frame as the game reports them, such as BACKGROUND 100, or nothing when it will not say.
local function Stack(frame)
	local ok, strata = pcall(frame.GetFrameStrata, frame)
	local level = Level(frame)
	if not ok or ns.IsSecret(strata) or type(strata) ~= "string" or level == nil then
		return nil
	end
	return ("%s %d"):format(strata, level)
end

-- The setting Minimap in cities, or nothing while the page or this part is off.
local function CityChoice()
	if ns.Enabled(KEY) and not ns.PartStopped(KEY, "minimap") then
		return ns.Get(KEY .. ".cityMap")
	end
	return nil
end

-- The cover hides the corners of the city map, which the game draws over the whole square of the minimap, and the border round the circle is
-- drawn on it. The picture is white and clear inside a circle that touches its four sides and has the colour wanted tinted on, so stretched over
-- the square of the minimap it leaves the circle clear. It is a frame of the addon's own on the minimap, at its level: the first picture is the
-- border colour, and the second, on a frame as much larger than the square as the border is thick, is the background colour with its circle that
-- much larger, so what shows of the first is a ring. That frame is a child of the cover at the same level, so it is drawn over its parent. The cover
-- clips what lies outside the square, where the city map is clipped too; the ring there, at the four points where the circle meets the square, is
-- the border disc under the map (MapBorder), which the city map does not reach. Both pictures are opaque: a cover that let the corners through
-- would not cover them.
local function CoverPicture(owner)
	local texture = owner:CreateTexture(nil, "ARTWORK", nil, 0)
	ns.Own[texture] = true
	-- Snapping would move the edge of the circle by a pixel as the minimap moves.
	pcall(texture.SetSnapToPixelGrid, texture, false)
	pcall(texture.SetTexelSnappingBias, texture, 0)
	texture:SetTexture(COVER_FILE)
	texture:SetAllPoints(owner)
	return texture
end

local function MakeCover()
	local map = Frame("Minimap")
	if not map then
		return nil
	end
	-- A frame made on the minimap is one level above it, where the zoom buttons are. Without the level of the minimap there is no cover.
	local level = Level(map)
	if level == nil then
		return nil
	end
	-- The strata is the minimap's, which a frame made on it takes, and it follows the minimap if the game moves it.
	local frame = CreateFrame("Frame", nil, map)
	ns.Own[frame] = true
	frame:SetFrameLevel(level)
	pcall(frame.SetClipsChildren, frame, true)
	frame:SetAllPoints(map)
	local rim = CreateFrame("Frame", nil, frame)
	ns.Own[rim] = true
	rim:SetFrameLevel(level)
	return { frame = frame, rim = rim, back = CoverPicture(frame), face = CoverPicture(rim) }
end

-- Shows the cover while the city map is up and the setting asks for it, and hides it otherwise. It is made and placed out of combat; its colours
-- and whether it shows are texture and frame calls of the addon's own, which combat allows.
local function CityCover(wanted, border)
	local cover = minimap.cover
	if not cover then
		if not wanted or InFight() then
			return
		end
		cover = MakeCover()
		-- A cover that the game does not let be made is said in the status.
		minimap.blocked = cover == nil
		if not cover then
			return
		end
		minimap.cover = cover
		ns.Count(KEY)
	end
	local rim = border and not ns.Borderless()
	if rim then
		local t = ns.Pixels(cover.frame, ns.Get("general.thickness"))
		if cover.t ~= t and not InFight() then
			cover.t = t
			cover.rim:SetPoint("TOPLEFT", cover.frame, "TOPLEFT", -t, t)
			cover.rim:SetPoint("BOTTOMRIGHT", cover.frame, "BOTTOMRIGHT", t, -t)
		end
		-- A border that has not been placed yet waits for the end of combat.
		rim = cover.t ~= nil
	end
	local br, bg, bb = ns.Colour("general.backdrop")
	if rim then
		local r, g, b = ns.BorderRGB()
		cover.back:SetVertexColor(r, g, b, 1)
		cover.face:SetVertexColor(br, bg, bb, 1)
	else
		cover.back:SetVertexColor(br, bg, bb, 1)
	end
	cover.rim:SetShown(rim)
	cover.frame:SetShown(wanted)
	cover.on = wanted
end

-- A thin border round the zone name, and round each button and banner beside it.
local function HeaderBorder(frame, on)
	local outline = edges[frame]
	if not outline then
		if not on or Later(frame) then
			return
		end
		outline = ns.Outline(frame, frame)
		edges[frame] = outline
		ns.Count(KEY)
	end
	ns.SetOutline(outline, on, true)
end

-- The banner under the zone name has one picture for each kind of content, and the game shows one of them. Forever has had no banner since
-- 1.60.1.70425 (Blizzard_Minimap/Camelot/MinimapInstanceDifficulty.lua:1-3), so this is for a client that still makes one, and finds none on Forever.
local function BannerModes(banner)
	local modes, list = {}, banner and banner.ContentModes
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, mode in ipairs(list) do
			if not ns.Forbidden(mode) then
				modes[#modes + 1] = mode
			end
		end
	end
	return modes
end

-- A picture held in a field of a frame of the game, unless it is missing or withheld.
local function Picture(frame, key)
	local value = frame and frame[key]
	if value == nil or ns.IsSecret(value) or type(value) ~= "table" then
		return nil
	end
	return value
end

-- The zone name: the frame that takes the border, the pictures of its plate, and the glow over the plate (see HEADER_PIECES). The button of
-- 1.60.1.70425 and later is known by its StateTexture; without one the nine-slice BorderTop is looked for.
local function Header(cluster)
	local button = cluster and Child(cluster, "ZoneTextButton")
	local plate = Picture(button, "StateTexture")
	if plate then
		return button, { plate }, Picture(button, "AddTexture")
	end
	local old = cluster and Child(cluster, "BorderTop")
	if not old then
		return nil, {}
	end
	local list = {}
	for _, piece in ipairs(HEADER_PIECES) do
		list[#list + 1] = Picture(old, piece)
	end
	return old, list
end

-- The game sets the opacity of the glow over the zone name again on each change of the state of its button, from the scripts of the mouse and
-- of enabling (Blizzard_SharedXMLBase/ButtonStateBehavior.lua:41-118, Camelot/MinimapZoneTextButton.lua:11-25), and only SetAtlas on the plate,
-- which keeps its opacity. A script hooked with HookScript runs after the game's own and writes nothing on the frame, so the glow is made
-- transparent again at once, before the frame is drawn, while Hide minimap ring and header is on. With the setting off the glow is the game's:
-- at rest it has no opacity, and the game sets the opacity again on the next change of state.
local GLOW_SCRIPTS = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnEnable", "OnDisable" }
local function FollowGlow(button, glow)
	local done = hooked[button]
	if done == nil then
		done = {}
		hooked[button] = done
	end
	if done.glow or type(button.HookScript) ~= "function" then
		return
	end
	done.glow = true
	local function Again()
		if On("minimap", "minimapArt") and not ns.IsStopped(KEY) then
			ns.SetFaded(glow, true)
		end
	end
	for _, script in ipairs(GLOW_SCRIPTS) do
		pcall(button.HookScript, button, script, Again)
	end
end

-- The tracking button. Since 1.60.1.70425 it is a 23 by 23 button over the 17 by 17 frame Tracking, and its plate, StateTexture, draws its glyph as
-- well (Blizzard_Minimap/Mainline/Minimap.xml:25-45, Camelot/MinimapTrackingButton.xml:3-28): the border goes round the button and its pictures stay.
-- Before, the button was smaller than the frame, and the border went round the frame.
local function TrackingBox(tracking)
	local button = tracking and Child(tracking, "Button")
	if button and Picture(button, "StateTexture") then
		return button
	end
	return tracking
end

-- The square map has its border drawn as an outline of the map itself, with no background behind it.
local function MapOutline(on)
	local outline = minimap.edge
	if not outline then
		local map = Frame("Minimap")
		if not on or not map or Later(map) then
			return
		end
		outline = ns.Outline(map, map)
		if not outline then
			return
		end
		minimap.edge = outline
		ns.Count(KEY)
	end
	ns.SetOutline(outline, on, false)
end

-- Puts a mask on the minimap, and says whether the game took it.
local function SetMask(map, file)
	return (pcall(map.SetMaskTexture, map, file))
end

-- The game masks the minimap again when the rotateMinimap variable changes (Blizzard_Minimap/Camelot/Minimap.lua:31-59, called from the callback of
-- the variable at :95-99), and the event of the variable comes with that call, so the square mask is put on again on the next frame after it.
local function ReMask()
	if not minimap.squared or ns.IsStopped(KEY) or Val("minimap", "shape") ~= "square" then
		return
	end
	local map = Frame("Minimap")
	if map and not SetMask(map, SQUARE_MASK) then
		ns.Note(KEY, LABEL .. ": the game refused the square mask, and the minimap has the game's mask.")
	end
end

-- The shape of the map: the square mask while the setting asks for it, and the game's own mask again when it does not. A mask the game refuses is
-- said in /flatui status and the map keeps the shape it has. Returns true while the map is square.
local function MapShape(square)
	local map = Frame("Minimap")
	if not map then
		return false
	end
	if square then
		if not minimap.squared and not Later(map) then
			if not SetMask(map, SQUARE_MASK) then
				ns.Note(KEY, LABEL .. ": the game refused the square mask, so the minimap stays round.")
				return false
			end
			minimap.squared = true
		end
	elseif minimap.squared and not Later(map) then
		if SetMask(map, MAP_MASK) then
			minimap.squared = nil
		else
			ns.Note(KEY, LABEL .. ": the game refused to put back the round mask, so the minimap stays square.")
		end
	end
	return minimap.squared == true
end

-- The zoom level of the map, or nothing when the game will not say.
local function ZoomLevel()
	local map = Frame("Minimap")
	if not map or type(map.GetZoom) ~= "function" then
		return nil
	end
	local ok, zoom = pcall(map.GetZoom, map)
	if ok and not ns.IsSecret(zoom) and type(zoom) == "number" then
		return zoom
	end
	return nil
end

local function Now()
	return type(GetTime) == "function" and GetTime() or 0
end

-- Puts the zoom back to the widest once the time has passed since it changed, with the mouse off the map. A withheld answer counts as the mouse
-- being over it. The call raises when the game refuses it.
local function ZoomBack()
	local seconds = Val("minimap", "zoomReset")
	if type(seconds) ~= "number" or seconds <= 0 or minimap.zoomAt == nil then
		if minimap.zoomer then
			minimap.zoomer:Hide()
		end
		return
	end
	if Now() - minimap.zoomAt < seconds then
		return
	end
	local map = Frame("Minimap")
	if not map then
		return
	end
	local ok, over = pcall(map.IsMouseOver, map)
	if not ok or ns.IsSecret(over) or over ~= false then
		return
	end
	minimap.zoomAt = nil
	minimap.zoomer:Hide()
	if not pcall(map.SetZoom, map, 0) then
		ns.Note(KEY, LABEL .. ": the game refused to zoom the minimap out.")
	end
end

local function ZoomStep(_, elapsed)
	minimap.zoomClock = (minimap.zoomClock or 0) + elapsed
	if minimap.zoomClock >= ZOOM_EVERY then
		minimap.zoomClock = 0
		Run("minimap", ZoomBack, minimap)
	end
end

-- Looks at the zoom: a map off its widest zoom starts the count, and the count stops with the setting at 0 or a zoom the game does not say.
-- fresh is true when the game has just changed the zoom, which starts the count again.
local function ZoomSeen(_, fresh)
	local seconds = Val("minimap", "zoomReset")
	local zoom = ZoomLevel()
	local count = type(seconds) == "number" and seconds > 0
	minimap.zoomBlind = (count and zoom == nil) or nil
	if not count or zoom == nil or zoom == 0 then
		minimap.zoomAt = nil
		if minimap.zoomer then
			minimap.zoomer:Hide()
		end
		return
	end
	minimap.zoomAt = (fresh and Now()) or minimap.zoomAt or Now()
	if not minimap.zoomer then
		minimap.zoomer = CreateFrame("Frame")
		ns.Own[minimap.zoomer] = true
		minimap.zoomer:SetScript("OnUpdate", ZoomStep)
	end
	minimap.zoomer:Show()
end

-- A button round the minimap: switched off, it has no opacity and takes no mouse; switched on, it has what the game had. What the game had is read
-- the first time it is switched off. The mouse of a frame that may be protected waits for the end of combat.
local function MapButton(entry, cluster)
	local frame = entry.name and Frame(entry.name) or (entry.key and cluster and Child(cluster, entry.key)) or nil
	if frame == nil or type(frame.SetAlpha) ~= "function" then
		return
	end
	-- The frames that take the mouse: the listed children, or the frame itself.
	local targets = {}
	if entry.mouse then
		for _, key in ipairs(entry.mouse) do
			local child = Child(frame, key)
			if child ~= nil and type(child.EnableMouse) == "function" then
				targets[#targets + 1] = child
			end
		end
	elseif type(frame.EnableMouse) == "function" then
		targets[1] = frame
	end
	local off = Val("minimap", entry.option) == false
	local rec = mapButtons[frame]
	if not rec then
		if not off then
			return
		end
		local given = ns.FadeGiven and ns.FadeGiven(frame)
		local alpha = given
		if alpha == nil then
			local okAlpha, got = pcall(frame.GetAlpha, frame)
			alpha = okAlpha and got or nil
		end
		rec = { alpha = (ns.Finite(alpha) and alpha > 0.001) and alpha or 1, mice = {} }
		mapButtons[frame] = rec
		ns.Count(KEY)
	end
	if (rec.off or false) ~= off then
		frame:SetAlpha(off and 0 or rec.alpha)
		rec.off = off
	end
	for _, target in ipairs(targets) do
		local mrec = rec.mice[target]
		if not mrec then
			local okMouse, mouse = false, nil
			if type(target.IsMouseEnabled) == "function" then
				okMouse, mouse = pcall(target.IsMouseEnabled, target)
			end
			mrec = { mouse = not (okMouse and not ns.IsSecret(mouse) and mouse == false) }
			rec.mice[target] = mrec
		end
		if (mrec.off or false) ~= off and not Later(target) then
			target:EnableMouse(not off and mrec.mouse)
			mrec.off = off
		end
	end
end

-- True while a button round the minimap is switched off by its setting, so that Fading leaves it alone.
function ns.MapButtonOff(frame)
	local rec = mapButtons[frame]
	return rec ~= nil and rec.off == true
end

-- The gap under the zone name. The game hangs the plate of the zone name, ZoneTextButton (152 by 23), from the top of the cluster, and the box of
-- the map, MinimapContainer, 30 under that top, the size of the ring's picture with the map, 198 square, in its middle
-- (Blizzard_Minimap/Camelot/MinimapZoneTextButton.xml:9-12, Mainline/Minimap.xml:47-64, Camelot/Minimap.lua:36-39): the top of the map is 7 under
-- the plate plus half of what the box has over the map at Edit Mode's size, about 21 at 100%, room that the ring fills. Hide minimap ring and
-- header and the square shape, which has no ring, leave that room empty, round or square alike. With Edit Mode's Header underneath the plate is 8
-- over the bottom of the cluster and the box 30 (Camelot/Minimap.lua:68-80), the plate about 13 under the map. With Close the gap under the zone
-- name on, and while the ring does not show, the plate hangs from the map instead (ClearAllPoints and SetPoint, on a plate the game does not
-- protect or out of combat), Gap under the zone name pixels from the map's border, or from the top line of text that MapText.lua puts above the
-- map (ns.MapTextAbove), and never further out than the game's place: lines that do not fit then go below the map, as MapText.lua does with the
-- game's place. Its left and right stay the game's. The tracking button, the clock and the calendar hang beside the plate and come with it
-- (Mainline/Minimap.xml:31, Camelot/GameTimeFrameTemplate.xml:10, Blizzard_TimeManager/Camelot/Blizzard_TimeManagerOverrides.lua:6). The mail
-- icon and the addon list button hang on the map's side of the plate and of the calendar (headerGap.Sides), in the room the plate closes: each
-- goes on the side of the plate where it overlaps less, the far side inside the plate's old place, and gets the game's points back otherwise.
-- The map, its box and the cluster stay where the game, Edit Mode and /flatui move put them: the cluster takes the size of its children
-- (ResizeLayoutFrame, Blizzard_SharedXML/LayoutFrame.lua:488-528), so a frame of Flat UI's own, a child of the cluster the size of the plate,
-- holds the plate's place at the points the game gave the plate, and nothing that moves here leaves the cluster's box. The game gives the plate,
-- the mail icon and the addon list button their points again only in SetHeaderUnderneath, from Edit Mode as it applies a layout or a change of
-- Header underneath or Size, and lays the cluster out at once (Camelot/Minimap.lua:68-92, Blizzard_EditMode/Shared/EditModeSystemTemplates.lua:
-- 1794-1809, Shared/EditModeManager.lua:1010-1035), so the plate keeps the game's place until Edit Mode has applied the layout of the login (its
-- layoutInfo, read with rawget) and while Edit Mode is open (EventRegistry's EditMode.Enter and EditMode.Exit), and is hung from the map again on
-- the next frame after them. A frame of Flat UI's own hung from the plate sees it move (OnSizeChanged): on the next frame the points are read
-- again and it hangs from the map again. Off, or while the ring shows, the plate, the mail icon and the addon list button get back the points
-- the game gave them, and the frame that held the plate's place hides.
-- game: the points the game gave the plate, while it hangs from the map; set: the point set here; holder: the frame that holds its place;
-- probe: the frame hung from it; sides[frame]: the game's points and the point set here of the mail icon and the addon list button; bare: the
-- ring does not show (ApplyMinimap); moved: true when the last pass moved the plate; listening, Look: EventRegistry is followed, and what it
-- calls.
local headerGap = { sides = {} }

-- The points of a frame, each { point, relative frame, relative point, x, y }, or nil when one of them cannot be read.
function headerGap.Points(frame)
	local ok, count = pcall(frame.GetNumPoints, frame)
	if not ok or not ns.Finite(count) or count < 1 then
		return nil
	end
	local points = {}
	for i = 1, count do
		local read, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, i)
		if not read or ns.IsSecret(point) or type(point) ~= "string" or ns.IsSecret(relativePoint) or type(relativePoint) ~= "string"
			or not ns.Finite(x) or not ns.Finite(y) then
			return nil
		end
		points[i] = { point, relativeTo, relativePoint, x, y }
	end
	return points
end

-- True while a frame has the one point set here, { point, relative frame, relative point, x, y }.
function headerGap.At(frame, set)
	local points = set and headerGap.Points(frame)
	local p = points and #points == 1 and points[1]
	return p and p[1] == set[1] and p[2] == set[2] and p[3] == set[3] and math.abs(p[4] - set[4]) < 0.01 and math.abs(p[5] - set[5]) < 0.01
		or false
end

-- Lays a frame on points, each { point, relative frame, relative point, x, y }.
function headerGap.Hang(frame, points)
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		frame:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

-- The centre of a frame on the screen and its effective scale, or nil when the client does not say.
function headerGap.Centre(frame)
	local ok, x, y = pcall(frame.GetCenter, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if not ok or not okScale or not ns.Finite(x) or not ns.Finite(y) or not ns.Finite(scale) or scale <= 0 then
		return nil
	end
	return x * scale, y * scale, scale
end

-- The top and the bottom of a frame on the screen, or nil when the client does not say.
function headerGap.Edges(frame)
	local okTop, top = pcall(frame.GetTop, frame)
	local okBottom, bottom = pcall(frame.GetBottom, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	if not okTop or not okBottom or not okScale or not ns.Finite(top) or not ns.Finite(bottom) or not ns.Finite(scale) or scale <= 0 then
		return nil
	end
	return top * scale, bottom * scale
end

-- Gives a frame of the plate's side back the points the game gave it, while it has the point set here.
function headerGap.Back(frame, rec)
	if rec.set and headerGap.At(frame, rec.set) then
		headerGap.Hang(frame, rec.game)
	end
	rec.set = nil
end

-- Gives the plate, the mail icon and the addon list button back the points the game gave them, and hides the frame that held the plate's place.
function headerGap.Release(plate)
	for frame, rec in pairs(headerGap.sides) do
		if not Later(frame) then
			headerGap.Back(frame, rec)
			headerGap.sides[frame] = nil
		end
	end
	if not headerGap.game then
		return
	end
	if headerGap.At(plate, headerGap.set) then
		if Later(plate) then
			return
		end
		headerGap.Hang(plate, headerGap.game)
		headerGap.moved = true
	end
	headerGap.game, headerGap.set = nil, nil
	headerGap.holder:Hide()
end

-- Reads the points the game gave the plate and lays the frame that holds its place on them. False when they cannot be read.
function headerGap.Take(cluster, plate)
	local points = headerGap.Points(plate)
	local okSize, width, height = pcall(plate.GetSize, plate)
	local okScale, scale = pcall(plate.GetScale, plate)
	if not points or not okSize or not okScale or not ns.Finite(width) or not ns.Finite(height) or not ns.Finite(scale) or scale <= 0 then
		ns.Note(KEY, LABEL .. ": the game does not say where the zone name is, so it stays in the game's place.")
		return false
	end
	local holder = headerGap.holder
	if not holder then
		holder = CreateFrame("Frame", nil, cluster)
		ns.Own[holder] = true
		headerGap.holder = holder
		ns.Count(KEY)
	end
	headerGap.Hang(holder, points)
	holder:SetScale(scale)
	holder:SetSize(width, height)
	holder:Show()
	headerGap.game, headerGap.set = points, nil
	return true
end

-- The frames the game hangs on the map's side of the plate, each with the frame it hangs from, the side of that frame it is level with, and how
-- far the game lays it over that frame: the mail icon (IndicatorFrame, 32 by 24) from the plate, and the addon list button
-- (AddonCompartmentFrame, 23 by 22) from the calendar, which is as high as the plate and level with it (Camelot/MinimapIndicatorFrameTemplate.xml:
-- 4-9, Camelot/AddonCompartment.xml:9-12, Camelot/GameTimeFrameTemplate.xml:8-10, Camelot/Minimap.lua:68-89).
function headerGap.Sides(cluster, plate)
	return { { frame = Child(cluster, "IndicatorFrame"), from = plate, x = "LEFT", over = 0 },
		{ frame = Frame("AddonCompartmentFrame"), from = Frame("GameTimeFrame"), x = "", over = 1 } }
end

-- Hangs a frame of the plate's side where it overlaps less: in the game's place, between the plate and the map, while it fits in the room there
-- (near) or that room is the larger, else on the other side of the plate, inside the plate's old place (far), over the plate or the calendar by
-- what that room lacks. above: the plate is over the map. near and far are in the units of the plate.
function headerGap.Side(side, plate, above, near, far)
	local frame, from = side.frame, side.from
	if not frame or not from or Later(frame) then
		return
	end
	local rec = headerGap.sides[frame]
	if not (rec and headerGap.At(frame, rec.set)) then
		local points = headerGap.Points(frame)
		if not points then
			return
		end
		rec = { game = points }
		headerGap.sides[frame] = rec
	end
	local okHeight, height = pcall(frame.GetHeight, frame)
	local okOwn, own = pcall(frame.GetEffectiveScale, frame)
	local okScale, scale = pcall(plate.GetEffectiveScale, plate)
	if not okHeight or not okOwn or not okScale or not ns.Finite(height) or not ns.Finite(own) or not ns.Finite(scale) or own <= 0 or scale <= 0 then
		return
	end
	local reach = (height - side.over) * own / scale
	if far < 1 or near >= reach or near > far then
		headerGap.Back(frame, rec)
		return
	end
	local over = math.max(side.over, height - far * scale / own)
	local set = above and { "BOTTOM" .. side.x, from, "TOP" .. side.x, 0, -over } or { "TOP" .. side.x, from, "BOTTOM" .. side.x, 0, over }
	if headerGap.At(frame, rec.set) and rec.set[1] == set[1] and math.abs(rec.set[5] - set[5]) < 0.01 then
		return
	end
	headerGap.Hang(frame, { set })
	rec.set = set
end

-- True once Edit Mode has applied the layout of the login, and on a client without Edit Mode.
function headerGap.Ready()
	local manager = _G.EditModeManagerFrame
	if manager == nil or ns.Forbidden(manager) then
		return manager == nil
	end
	local ok, info = pcall(rawget, manager, "layoutInfo")
	return ok and info ~= nil
end

-- A pass on the next frame after Edit Mode opens, closes or applies a layout. EventRegistry is followed once, the first time the row is on.
function headerGap.Listen()
	if headerGap.listening or type(EventRegistry) ~= "table" or ns.IsSecret(EventRegistry) or type(EventRegistry.RegisterCallback) ~= "function" then
		return
	end
	headerGap.listening = true
	local function Look()
		if headerGap.game or Val("minimap", "zoneGapOwn") == true then
			Soon(headerGap, headerGap.Again)
		end
	end
	pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Enter", Look, headerGap)
	pcall(EventRegistry.RegisterCallback, EventRegistry, "EditMode.Exit", Look, headerGap)
	headerGap.Look = Look
end

-- Hangs the plate of the zone name from the map while Close the gap under the zone name is on and the ring does not show (bare), and gives it
-- back its points otherwise.
function headerGap.Apply(cluster, border, bare)
	headerGap.moved = false
	headerGap.bare = bare
	local plate, map = cluster and Child(cluster, "ZoneTextButton"), Frame("Minimap")
	-- A client before 1.60.1.70425 has no button for the plate (see HEADER_PIECES), and its plate stays.
	if not plate or not map or not Picture(plate, "StateTexture") then
		return
	end
	local wanted = Val("minimap", "zoneGapOwn") == true
	if wanted then
		headerGap.Listen()
	end
	if not wanted or not bare or not headerGap.Ready() or (ns.EditModeOpen and ns.EditModeOpen()) then
		headerGap.Release(plate)
		return
	end
	if Later(plate) or Later(cluster) then
		return
	end
	if not (headerGap.game and headerGap.At(plate, headerGap.set)) and not headerGap.Take(cluster, plate) then
		return
	end
	if not headerGap.probe then
		local probe = CreateFrame("Frame", nil, UIParent)
		ns.Own[probe] = true
		probe:SetWidth(1)
		probe:SetPoint("TOP", plate, "CENTER")
		probe:SetPoint("BOTTOM", UIParent, "BOTTOM")
		probe:SetScript("OnSizeChanged", function()
			if headerGap.game then
				Soon(headerGap, headerGap.Again)
			end
		end)
		headerGap.probe = probe
	end
	local hx, hy = headerGap.Centre(headerGap.holder)
	local mx, my, mapScale = headerGap.Centre(map)
	local holderTop, holderBottom = headerGap.Edges(headerGap.holder)
	local mapTop, mapBottom = headerGap.Edges(map)
	local okScale, scale = pcall(plate.GetEffectiveScale, plate)
	if not hx or not mx or not holderTop or not mapTop or not okScale or not ns.Finite(scale) or scale <= 0 then
		return
	end
	local above = hy >= my
	-- The room between the plate's old place and the map's edge: the plate goes no further out than its old place, so the cluster keeps its box.
	local band = (above and holderBottom - mapTop or mapBottom - holderTop) / scale
	local px = Val("minimap", "zoneGap")
	px = ns.Finite(px) and math.max(px, 0) or 0
	local edge = border and not ns.Borderless() and ns.Get("general.thickness") or 0
	local base = ns.Pixels(plate, edge)
	local room = above and ns.MapTextAbove and ns.MapTextAbove()
	if ns.Finite(room) and room > 0 then
		base = math.max(base, room * mapScale / scale)
	end
	local dy = math.min(base + ns.Pixels(plate, px), band)
	local dx = (hx - mx) / scale
	local point, relativePoint, y = "BOTTOM", "TOP", dy
	if not above then
		point, relativePoint, y = "TOP", "BOTTOM", -dy
	end
	local set = headerGap.set
	if not (set and set[1] == point and math.abs(set[4] - dx) < 0.01 and math.abs(set[5] - y) < 0.01 and headerGap.At(plate, set)) then
		set = { point, map, relativePoint, dx, y }
		headerGap.Hang(plate, { set })
		headerGap.set = set
		headerGap.moved = true
	end
	for _, side in ipairs(headerGap.Sides(cluster, plate)) do
		headerGap.Side(side, plate, above, dy - base, band - dy)
	end
end

-- A pass on the next frame after the plate moved or the lines above the map changed; the lines are laid out again when the plate moved.
function headerGap.Again()
	local cluster = Frame("MinimapCluster")
	if not cluster or not ns.Enabled(KEY) then
		return
	end
	Run("minimap", headerGap.Apply, cluster, On("minimap", "minimapBorder"), headerGap.bare)
	if headerGap.moved and ns.MapTextRefresh then
		ns.MapTextRefresh()
	end
end

-- MapText.lua calls this when the room its lines above the map take changes.
function ns.MapGapRoom()
	if headerGap.game then
		Soon(headerGap, headerGap.Again)
	end
end

local function ApplyMinimap()
	local art, border = On("minimap", "minimapArt"), On("minimap", "minimapBorder")
	local choice, up = CityChoice(), CityShown() == true
	local cluster = Frame("MinimapCluster")
	local header, plates, glow = Header(cluster)
	local diel = cluster and cluster.DielFrame
	diel = diel ~= nil and not ns.Forbidden(diel) and diel or nil
	-- The frame of the tracking button has a plate of its own behind the button, and each picture of the banner has a background and a border of its own.
	local tracking = cluster and Child(cluster, "Tracking")
	local modes = BannerModes(cluster and Child(cluster, "InstanceDifficulty"))
	-- The ring comes back while the city map is up, when the setting says so.
	local ring = art and not (choice == "ring" and up)
	-- A square map has no ring and no pointer, whatever Hide minimap ring and header says.
	local square = MapShape(Val("minimap", "shape") == "square")
	ring = ring or square
	if Moves("ring", ring) then
		ns.SetFaded(_G.MinimapCompassTexture, ring)
		ns.SetFaded(_G.MinimapCompassTextureUnderlay, ring)
	end
	if Moves("minimap", art) then
		for _, plate in ipairs(plates) do
			ns.SetFaded(plate, art)
		end
		-- The glow is the game's again with the setting off (FollowGlow).
		if glow and art then
			ns.SetFaded(glow, true)
		end
		if diel then
			-- The border of the day and night medallion has no key. The sun and moon inside it stay.
			minimap.diel = minimap.diel or ns.RegionWithAtlas(diel, DIEL_BORDER)
			ns.SetFaded(minimap.diel, art)
		end
		ns.SetFaded(tracking and tracking.Background, art)
		for _, mode in ipairs(modes) do
			ns.SetFaded(mode.Background, art)
			ns.SetFaded(mode.Border, art)
		end
	end
	if glow and art then
		FollowGlow(header, glow)
	end
	if header then
		HeaderBorder(header, border)
	end
	if tracking then
		HeaderBorder(TrackingBox(tracking), border)
	end
	for _, mode in ipairs(modes) do
		HeaderBorder(mode, border)
	end
	MapBorder(border, square)
	MapOutline(border and square)
	-- The city map has a round mask of its own, which the square mask of the minimap does not reach: no round cover is drawn over a square map.
	CityCover(choice == "cover" and up and not square, border)
	-- The plate of the zone name keeps the game's place while the ring shows, which fills the room over the map.
	headerGap.Apply(cluster, border, ring)
	local night = Val("minimap", "dayNight") == false
	if diel and Moves("daynight", night) then
		ns.SetFaded(diel, night)
	end
	local zone = Frame("MinimapZoneText")
	if zone then
		local hidden = Val("minimap", "zoneText") == false
		if Moves("zonename", hidden) then
			ns.SetFaded(zone, hidden)
		end
		Size(zone, Val("minimap", "zoneSize") or 100, "the zone name")
	end
	for _, entry in ipairs(MAP_BUTTONS) do
		Run("minimap", MapButton, entry, cluster)
	end
end

-- Looks at the minimap again when the game shows or hides the city map. With the page off there is nothing to look at.
local function CityChanged()
	if ns.Enabled(KEY) then
		Run("minimap", ApplyMinimap)
		-- The ring that comes back with the city map puts the plate of the zone name back in the game's place: the lines above the map follow.
		if headerGap.moved and ns.MapTextRefresh then
			ns.MapTextRefresh()
		end
	end
end

-- Follows the showing and hiding of the city map, once. The game makes the frame when it loads Blizzard_HybridMinimap, and a client without
-- it has none.
local function FollowCity()
	local map = CityMap()
	if not map then
		return
	end
	local done = hooked[map]
	if done == nil then
		done = {}
		hooked[map] = done
	end
	-- The game hides the city map by itself when the player leaves the city, and with the minimap hidden (the key binding, Alt+Z) neither OnShow nor
	-- OnHide of the city map runs. The minimap showing again is the next look at the cover.
	local mini = Frame("Minimap")
	if mini and type(mini.HookScript) == "function" then
		local d = hooked[mini] or {}
		hooked[mini] = d
		if not d.OnShow then
			d.OnShow = true
			mini:HookScript("OnShow", CityChanged)
		end
	end
	if type(map.HookScript) ~= "function" then
		return
	end
	for _, script in ipairs({ "OnShow", "OnHide" }) do
		if not done[script] then
			done[script] = true
			map:HookScript(script, CityChanged)
		end
	end
end

-- Bag bar -------------------------------------------------------------------------------------

local BAG_MASKS = { "SquareMask", "Mask" }

-- The game gives the highlight its alpha again on every texture update, so it is read before it is faded, and the hover
-- tint is a picture of the addon's own in the layer the game shows on mouseover.
local function ApplyBag(button)
	local on = On("bags", "bags")
	local rec = bags[button]
	if not rec then
		if not on or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, button), unmasked = {} }
		bags[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(button.NormalTexture, on)
	ns.SetFaded(button.PushedTexture, on)
	ns.SetFaded(button.SlotHighlightTexture, on)
	local highlight = button.HighlightTexture
	if highlight ~= nil and not ns.IsSecret(highlight) then
		if on then
			local ok, alpha = pcall(highlight.GetAlpha, highlight)
			if ok and not ns.IsSecret(alpha) and type(alpha) == "number" and alpha > 0 then
				rec.alpha = alpha
			end
			ns.SetFaded(highlight, true)
		elseif rec.alpha then
			pcall(highlight.SetAlpha, highlight, rec.alpha)
			rec.alpha = nil
		end
	end
	if on and not rec.hover then
		rec.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 0)
		ns.Own[rec.hover] = true
		rec.hover:SetAllPoints(button)
		rec.hover:SetColorTexture(1, 1, 1, 0.2)
	end
	if rec.hover then
		rec.hover:SetShown(on)
	end
	local icon = button.icon
	if icon ~= nil and not ns.IsSecret(icon) then
		-- The rounded masks go with the rounded frame: the SquareMask of the bag template and the Mask every item button has
		-- (Shared/ItemButtonTemplate.xml:18-19, Shared/ItemButtonTemplate.lua:16-20), which rounds the corners of the icon.
		for _, key in ipairs(BAG_MASKS) do
			local mask = button[key]
			if mask ~= nil and not ns.IsSecret(mask) and (rec.unmasked[key] == true) ~= (on == true) and icon.RemoveMaskTexture and icon.AddMaskTexture then
				rec.unmasked[key] = on == true
				pcall(on and icon.RemoveMaskTexture or icon.AddMaskTexture, icon, mask)
			end
		end
		-- An icon drawn from an atlas has the coordinates of the atlas, which a crop would spoil.
		local ok, atlas = pcall(icon.GetAtlas, icon)
		if ok and not ns.IsSecret(atlas) and (atlas == nil or atlas == "") then
			if on then
				local crop = Crop()
				icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
			elseif rec.cropped then
				icon:SetTexCoord(0, 1, 0, 1)
			end
			rec.cropped = on or nil
		end
	end
end

local function BagHook(button)
	if not ns.IsStopped(KEY) and (bags[button] or On("bags", "bags")) then
		Run("bags", ApplyBag, button)
	end
end

-- The game draws the pictures of a bag button again in UpdateTextures, which the events of the bag buttons lead to: the item and the inventory
-- events (MainMenuBarBagButtons.lua:43-57, 186-193, PaperDollFrame.lua:2016-2040), so the buttons are styled again on the next frame after them.
local function BagsPass()
	for _, name in ipairs(BAG_BUTTONS) do
		local button = Frame(name)
		if button then
			BagHook(button)
		end
	end
end

local function RefreshBags()
	local on = On("bags", "bags")
	local bar = Frame("BagsBar")
	if bar then
		-- The bar frame is styled by its pictures alone (BorderArt and the pieces of the dividers), also while the game's bars are left alone: no
		-- placing, sizing, alpha or field write on the bar.
		local pieces = ns.HandsOff
		if Moves(bar, on) then
			ns.SetFaded(bar.BorderArt, on)
		end
		if on then
			FollowDividers(bar, "bags", "bags", pieces)
		end
		Run("bags", FadeDividers, bar, "bags", "bags", pieces)
	end
	for _, name in ipairs(BAG_BUTTONS) do
		local button = Frame(name)
		if button then
			Run("bags", ApplyBag, button)
		end
	end
end

-- Buffs and debuffs -----------------------------------------------------------------------------

-- Red, green and blue of the border of a debuff of one type: the colour the player chose for it, and the game's own number for a row left alone. With
-- Border colour by debuff type off every debuff takes the Other colour.
local function DebuffColour(dispel)
	local kind = ns.Get(KEY .. ".auraTypes") == true and TYPE_ROWS[dispel] and dispel or "None"
	local path = KEY .. "." .. TYPE_ROWS[kind]
	if ns.IsSet(path) then
		return ns.Colour(path)
	end
	local colour = DEBUFF_COLOURS[kind]
	return colour[1], colour[2], colour[3]
end

-- Red, green and blue of the border of an icon, or nothing for the plain border. The game sets these fields in its own
-- code; a debuff type it withholds counts as none.
local function AuraColour(button)
	local kind = button.auraType
	if ns.IsSecret(kind) then
		return
	end
	if kind == "TempEnchant" then
		return ENCHANT_COLOUR[1], ENCHANT_COLOUR[2], ENCHANT_COLOUR[3]
	end
	if kind ~= "Debuff" and kind ~= "DeadlyDebuff" then
		return
	end
	local info, dispel = button.buttonInfo, nil
	if info ~= nil and not ns.IsSecret(info) and type(info) == "table" then
		dispel = info.debuffType
	end
	if ns.IsSecret(dispel) or type(dispel) ~= "string" then
		dispel = "None"
	end
	return DebuffColour(dispel)
end

local function ApplyAura(button)
	local on = On("auras", "auras")
	local rec = auras[button]
	if not rec then
		local icon = button.Icon
		-- The anchors for private auras have a frame in place of the icon, and the game draws those itself.
		if not on or icon == nil or ns.IsSecret(icon) or type(icon.SetTexCoord) ~= "function" or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, icon), icon = icon }
		auras[button] = rec
		ns.Count(KEY)
	end
	if rec.on ~= on then
		rec.on = on
		ns.SetOutline(rec.outline, on, false)
		ns.SetFaded(button.DebuffBorder, on)
		ns.SetFaded(button.TempEnchantBorder, on)
	end
	local crop = on and Crop() or nil
	if rec.crop ~= crop then
		rec.crop = crop
		if crop then
			rec.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		else
			rec.icon:SetTexCoord(0, 1, 0, 1)
		end
	end
	if on then
		ns.SetOutlineColour(rec.outline, AuraColour(button))
	else
		ns.SetOutlineColour(rec.outline, nil, nil, nil)
	end
end

-- The sizes of the duration and the count of a button. The game sets their text and colour and not their font (BuffFrame.lua:1376-1437), but a
-- size set before is read again when the game gives the font back, so the sizes are set after every update.
local function AuraText(button)
	local duration, count = Val("auras", "durationSize") or 100, Val("auras", "countSize") or 100
	local now = duration ~= 100 or count ~= 100
	if not now and not sized[button] then
		return
	end
	sized[button] = now or nil
	Size(button.Duration, duration, "the duration of a buff")
	Size(button.Count, count, "the stack count of a buff")
end

local function StyleAuraButton(button)
	if ns.Forbidden(button) then
		return
	end
	Run("auras", ApplyAura, button)
	Run("auras", AuraText, button)
end

local function StyleAuraFrame(frame)
	local list = frame.auraFrames
	if list == nil or ns.IsSecret(list) or type(list) ~= "table" then
		return
	end
	for _, button in ipairs(list) do
		StyleAuraButton(button)
	end
end

local function RefreshAuras()
	for _, name in ipairs(AURA_FRAMES) do
		local frame = Frame(name)
		if frame then
			Run("auras", StyleAuraFrame, frame)
		end
	end
	-- The warning icon that shows the worst debuff is one more of the same buttons.
	local deadly = Frame("DeadlyDebuffFrame")
	if deadly and deadly.Debuff ~= nil then
		StyleAuraButton(deadly.Debuff)
	end
end

-- Experience and reputation bars --------------------------------------------------------------

local function XpBorder(bar, statusBar)
	local on = On("xpbars", "xpFrame")
	local rec = borders[bar]
	if not rec then
		if not on or Later(bar) then
			return
		end
		rec = { outline = ns.Outline(bar, statusBar) }
		borders[bar] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(statusBar.Background, on)
end

-- The fill is the colour of the picture the game draws, made solid. The game draws a new picture when the rest
-- state or the standing changes, and the pass after the events that change them (QueueFill) makes that one flat too.
local function XpFill(statusBar)
	local rec = fills[statusBar]
	if not On("xpbars", "xpFill") then
		if rec and ns.RestoreFill(statusBar) == false then
			ns.Note(KEY, LABEL .. ": the game refused to put back the default fill of a bar.")
		end
		return
	end
	if not rec then
		rec = {}
		fills[statusBar] = rec
	end
	local region = ns.FillRegion(statusBar)
	if not region then
		return
	end
	local ok, atlas = pcall(region.GetAtlas, region)
	if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
		rec.atlas = atlas
		rec.colour = FILL_COLOURS[atlas:lower()] or NEUTRAL_FILL
	end
	if rec.colour then
		local flat, refused = ns.FlatFill(statusBar, rec.colour[1], rec.colour[2], rec.colour[3], rec.atlas, nil, RowFile("xpTexture"))
		if flat == false and refused then
			ns.Note(KEY, LABEL .. ": the game refused a flat fill on a bar, which keeps its default fill.")
		end
	end
end

-- Sets the text of a bar after the game has set its own, and gives the game's text back when the setting goes back to As the game has it. The
-- text on the bar is the game's own unless it is the line set here last, so the game's text is read from the bar each time.
local function XpTextApply(bar)
	local overlay = bar.OverlayFrame
	local text = overlay ~= nil and not ns.IsSecret(overlay) and type(overlay) == "table" and overlay.Text or nil
	if text == nil or ns.IsSecret(text) or type(text) ~= "table" or type(text.SetText) ~= "function" then
		return
	end
	local rec = xpTexts[bar]
	local mode = Val("xpbars", "xpText")
	-- Hidden shows no text; the other modes give a line, or leave the game's own when the bar has no numbers.
	local line = mode == "hide" and "" or (mode ~= nil and mode ~= "game" and ns.XpLine(bar, mode) or nil)
	if line or (rec and rec.ours) then
		local ok, current = pcall(text.GetText, text)
		if ok and not ns.IsSecret(current) and type(current) == "string" and (current ~= (rec and rec.line)) then
			rec = rec or {}
			xpTexts[bar] = rec
			rec.game = current
		end
	end
	if line then
		rec = rec or {}
		xpTexts[bar] = rec
		rec.ours = true
		rec.line = line
		text:SetText(line)
	elseif rec and rec.ours then
		rec.ours, rec.line = nil, nil
		if rec.game ~= nil then
			text:SetText(rec.game)
		end
	end
end

local function XpTextSize(bar)
	local overlay = bar.OverlayFrame
	if overlay ~= nil and not ns.IsSecret(overlay) and type(overlay) == "table" then
		Size(overlay.Text, Val("xpbars", "xpTextSize") or 100, "the text of an experience bar")
	end
end

local function StyleXpBar(bar)
	local statusBar = bar.StatusBar
	if statusBar == nil or ns.Forbidden(statusBar) then
		return
	end
	Run("xpbars", XpBorder, bar, statusBar)
	Run("xpbars", XpFill, statusBar)
	Run("xpbars", XpTextApply, bar)
	Run("xpbars", XpTextSize, bar)
end

local function StyleXpContainer(container)
	local on = On("xpbars", "xpFrame")
	if on or On("xpbars", "xpDividers") then
		borders.xpTouched = true
	end
	if Moves(container, on) then
		ns.SetFaded(container.BarFrameTexture, on)
	end
	if On("xpbars", "xpDividers") then
		FollowDividers(container, "xpbars", "xpDividers")
	end
	Run("xpbars", FadeDividers, container, "xpbars", "xpDividers")
	local list = container.bars
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, bar in pairs(list) do
			if not ns.Forbidden(bar) then
				StyleXpBar(bar)
			end
		end
	end
end

-- The game's status bars sit in the stack its bottom bar pass lays out under the action bars. While Flat UI leaves the game's action bars alone,
-- or draws its own experience bar (XpBar.lua), it neither hooks them nor writes on them: no border, fill, divider, text or size.
local function XpBarsOff()
	return ns.HandsOff() or (ns.XpOwn ~= nil and ns.XpOwn())
end

local function RefreshXpBars()
	if XpBarsOff() then
		return
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		if container then
			Run("xpbars", StyleXpContainer, container)
		end
	end
end

-- The game draws a new fill with SetBarTexture when the experience, the rest state, the level or the standing changes (ExpBarOverrides.lua:14-16,
-- ReputationBarOverrides.lua:42-46), and the level and standing ones wait for the end of an animation (GradualAnimatedStatusBar.lua:236-240).
-- No call is followed: the events that lead to those calls queue a pass over the bars one frame later, and one more after the animation,
-- so the fill is made flat again, as EllesmereUI treats the game's data bars (EllesmereUIActionBars/EllesmereUIActionBars.lua:703-707). The
-- text of each bar, which the game sets in the same calls (ExpBarOverrides.lua:11, HonorBar.lua:22), and the dividers go in the same pass.
local FILL_EVENTS = { "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "UPDATE_FACTION",
	"MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_MAX_LEVEL_UPDATE", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN", "HONOR_XP_UPDATE", "UNIT_PET_EXPERIENCE" }
-- Seconds after an event until the second pass.
local FILL_LATE = 3
local fillQueued, fillLateQueued = false, false

-- True when a bar has a line of ours to keep or one to take back.
local function XpHasLine(bar)
	return not ns.Forbidden(bar) and ((Val("xpbars", "xpText") or "game") ~= "game" or (xpTexts[bar] ~= nil and xpTexts[bar].ours == true))
end

-- The text of every bar again. The game sets it on more events than FILL_EVENTS names (the zone changes, the variables, the equipment and the
-- level: StatusTrackingManagerOverrides.lua:2-20, StatusTrackingManager.lua:339-343), so the manager's own event script queues this as well.
local function XpTextPass()
	if ns.IsStopped(KEY) or XpBarsOff() then
		return
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		local list = container ~= nil and container.bars or nil
		if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
			for _, bar in pairs(list) do
				if XpHasLine(bar) then
					Run("xpbars", XpTextApply, bar)
				end
			end
		end
	end
end

-- True when a bar is still animating (GradualAnimatedStatusBar.lua:173), so the late pass comes again.
local function FillPass()
	local animating = false
	if ns.IsStopped(KEY) or XpBarsOff() then
		return false
	end
	for _, name in ipairs(BAR_CONTAINERS) do
		local container = Frame(name)
		local list = container ~= nil and container.bars or nil
		if container ~= nil then
			Run("xpbars", FadeDividers, container, "xpbars", "xpDividers")
		end
		if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
			for _, bar in pairs(list) do
				local statusBar = not ns.Forbidden(bar) and bar.StatusBar or nil
				if XpHasLine(bar) then
					Run("xpbars", XpTextApply, bar)
				end
				if statusBar ~= nil and not ns.Forbidden(statusBar) and (fills[statusBar] or On("xpbars", "xpFill")) then
					Run("xpbars", XpFill, statusBar)
					if type(statusBar.IsAnimating) == "function" then
						local ok, going = pcall(statusBar.IsAnimating, statusBar)
						if ok and going == true then
							animating = true
						end
					end
				end
			end
		end
	end
	return animating
end

-- later: one more pass after the animation, for the events that start one.
local function QueueFill(later)
	if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
		FillPass()
		return
	end
	if not fillQueued then
		fillQueued = true
		C_Timer.After(0, function()
			fillQueued = false
			FillPass()
		end)
	end
	if later and not fillLateQueued then
		fillLateQueued = true
		local function Late()
			fillLateQueued = false
			if FillPass() then
				fillLateQueued = true
				C_Timer.After(FILL_LATE, Late)
			end
		end
		C_Timer.After(FILL_LATE, Late)
	end
end

-- Micro menu --------------------------------------------------------------------------------------

-- Each button has a plate of its own behind the picture. The game shows and hides the plate and never sets its alpha.
local function ApplyMicro(button)
	local on = On("micro", "micro")
	local rec = micro[button]
	if not rec then
		if not on or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, button) }
		micro[button] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, true)
	ns.SetFaded(button.Background, on)
	ns.SetFaded(button.PushedBackground, on)
	-- The portrait button has a shadow and a pushed shadow of its own, which the game shows and hides.
	ns.SetFaded(button.Shadow, on)
	ns.SetFaded(button.PushedShadow, on)
end

local function RefreshMicro()
	-- The micro menu is what the game anchors its main bar to, so only pictures change here, also while the game's bars are left alone: the art of
	-- the menu (Camelot/MainMenuBarMicroMenu.xml:6-17), the plate and the pushed plate of each button (Mainline/MainMenuBarMicroButtons.xml:20-29)
	-- and Flat UI's own outline. No placing, sizing, alpha or field write on the menu, its container or a button.
	local on = On("micro", "micro")
	local menu = Frame("MicroMenu")
	if menu and Moves(menu, on) then
		ns.SetFaded(menu.BorderArt, on)
		ns.SetFaded(menu.BackgroundArt, on)
	end
	for _, name in ipairs(MICRO_BUTTONS) do
		local button = Frame(name)
		if button then
			Run("micro", ApplyMicro, button)
		end
	end
end

-- Tracker, loot, alerts, timers and the rest ----------------------------------------------------------

-- Frames the game pools or makes later are styled from a hook on the call that hands them out. A frame is styled again when a setting changes.

local function Wanted(part)
	return On(part, OPTION[part])
end

-- Follows a function of the game by name. The game calls it by name, so the hook sees every call.
local function FollowGlobal(name, fn)
	if globalHooks[name] or type(hooksecurefunc) ~= "function" or type(_G[name]) ~= "function" then
		return
	end
	globalHooks[name] = true
	hooksecurefunc(name, fn)
end

-- Follows a method in a table of methods that the game copies onto the frames it makes afterwards.
local function FollowMixin(name, method, fn)
	local mixin = _G[name]
	if mixin ~= nil and not ns.IsSecret(mixin) and type(mixin) == "table" then
		Follow(mixin, method, fn)
	end
end

-- Red, green and blue of the colour the game gives a region, or nothing.
local function Tint(region)
	if region == nil or ns.IsSecret(region) then
		return nil
	end
	local ok, r, g, b = pcall(region.GetVertexColor, region)
	if ok and not (ns.IsSecret(r) or ns.IsSecret(g) or ns.IsSecret(b)) and type(r) == "number" and type(g) == "number" and type(b) == "number" then
		return r, g, b
	end
end

-- A thin border round target and a flat background behind it, for a frame of the game. It is made the first time the part is on for the frame.
local function Plate(part, apply, frame, target, on, backdrop)
	local rec = plates[frame]
	if not rec then
		if not on or Later(frame) then
			return nil
		end
		local outline = ns.Outline(frame, target)
		if not outline then
			return nil
		end
		rec = { part = part, apply = apply, outline = outline }
		plates[frame] = rec
		ns.Count(KEY)
	end
	ns.SetOutline(rec.outline, on, backdrop)
	return rec
end

-- Fades the named pieces of a frame's art, or hides them where the game sets their alpha itself, and gives them back when the part is off.
local function Art(rec, frame, names, on, hide)
	local was = rec.art and rec.art[frame]
	if not (on or was) then
		return
	end
	rec.art = rec.art or {}
	rec.art[frame] = on or nil
	local set = hide and ns.SetHidden or ns.SetFaded
	for _, name in ipairs(names) do
		set(frame[name], on)
	end
end

-- A solid fill on a bar: white where the game colours the bar itself, so that its colour shows. The game's own fill is put back when the part is off.
local function FillOf(bar, on, fallback, r, g, b, tinted, file)
	if on then
		local flat, refused = ns.FlatFill(bar, r, g, b, fallback, tinted, file)
		if flat == false then
			ns.Note(KEY, refused and (LABEL .. ": the game refused a flat fill on a bar, which keeps its default fill.")
				or (LABEL .. ": the default fill of a bar could not be read and is still shown."))
		end
	elseif ns.RestoreFill(bar) == false then
		ns.Note(KEY, LABEL .. ": the game refused to put back the default fill of a bar.")
	end
end

-- Styles again every frame of a part that has been styled, so that a changed setting reaches it and a part that is off gives the art back.
local function Restyle(part)
	local frames = {}
	for frame, rec in pairs(plates) do
		if rec.part == part then
			frames[#frames + 1] = frame
		end
	end
	for _, frame in ipairs(frames) do
		if not ns.Forbidden(frame) then
			Run(part, plates[frame].apply, frame)
		end
	end
end

-- Styles the frames in a table of the game's that have not been styled yet.
local function Visit(part, apply, frames)
	if frames == nil or ns.IsSecret(frames) or type(frames) ~= "table" then
		return
	end
	for _, frame in pairs(frames) do
		if not ns.Forbidden(frame) and plates[frame] == nil then
			Run(part, apply, frame)
		end
	end
end

-- A hook that gets a frame of the game first. The frame is styled the first time it is seen while its part is on, and on every call with always.
local function Hook(part, apply, always)
	return function(frame)
		if ns.IsStopped(KEY) or ns.Forbidden(frame) then
			return
		end
		local known = plates[frame] ~= nil
		if (always or not known) and (known or Wanted(part)) then
			Run(part, apply, frame)
		end
	end
end

-- Objective tracker ---------------------------------------------------------------------------------

-- The heading of the tracker and of each module: a flat band with a thin border in place of the banner. The game animates the alpha
-- of a module's banner and flares, so those are hidden.
local function ApplyTrackerHeader(header)
	local on = Wanted("tracker headers")
	local rec = Plate("tracker headers", ApplyTrackerHeader, header, header, on, true)
	if not rec then
		return
	end
	if header.AddAnim ~= nil then
		Art(rec, header, { "Background", "Shine", "Glow" }, on, true)
	else
		Art(rec, header, { "Background" }, on)
	end
end

-- The progress and timer bars are pooled. The fill is white, so the colour the game gives the bar shows.
local function ApplyTrackerBar(holder)
	local on = Wanted("tracker bars")
	local bar = Child(holder, "Bar")
	if not bar then
		return
	end
	local rec = Plate("tracker bars", ApplyTrackerBar, holder, bar, on, true)
	if rec then
		Art(rec, bar, TRACKER_BAR_ART, on)
		FillOf(bar, on, BAR_FILE, 1, 1, 1, true, RowFile("trackerTexture"))
	end
end

-- The button for a quest's item. The button for finding a group is another kind and is left alone.
local function ApplyTrackerItem(button)
	if button.GlowAnim == nil then
		return
	end
	local on = Wanted("tracker items")
	local rec = Plate("tracker items", ApplyTrackerItem, button, button, on, true)
	if rec then
		Art(rec, button, { "NormalTexture" }, on)
		local ok, pushed = pcall(button.GetPushedTexture, button)
		ns.SetFaded(ok and pushed or nil, on)
	end
end

-- A flat background with a thin border behind the whole tracker, round the nine pieces the game gives it. The game's opacity from Edit Mode is on
-- those pieces and not on the tracker, and the panel is not on them.
local function ApplyTrackerPanel(container)
	local nine = Child(container, "NineSlice")
	if nine then
		Plate("tracker panel", ApplyTrackerPanel, container, nine, Wanted("tracker panel"), true)
	end
end

-- Opacity in combat eases the tracker, the game's and Questie's (QuestieSkin.lua), to its opacity: down over DOWN seconds as a fight starts and back
-- up over UP seconds as it ends, easing out, from the alpha it has now, so a fight that starts while it comes back turns it round. state is the
-- tracker's record (look here, S in QuestieSkin.lua): alpha, the opacity to put back; sent, the alpha written last, set at once so the Fading page
-- leaves the tracker alone for the whole ease (ns.TrackerFades, ns.QuestieFades); target; back, true while it goes back to alpha, which lets the
-- tracker go as it gets there (alpha and sent nil). run runs each step as the file runs its parts, so a failure counts toward stopping the part,
-- and a step that failed stops the ease. The driver is a frame of Flat UI's own, shown only while it eases. SetAlpha is no protected call.
do
	local DOWN, UP = 0.25, 0.2

	local function Step(state, elapsed)
		local frame = state.frame
		if frame == nil or state.target == nil then
			state.driver:Hide()
			return
		end
		state.t = state.t + (ns.Finite(elapsed) and elapsed or 0)
		local share = math.min(state.t / state.span, 1)
		local alpha = state.from + (state.target - state.from) * (1 - (1 - share) ^ 2)
		frame:SetAlpha(alpha)
		state.sent, state.broken = alpha, nil
		if share >= 1 then
			state.driver:Hide()
			if state.back then
				state.alpha, state.sent, state.target, state.back = nil, nil, nil, nil
			end
		end
	end

	function ns.TrackerEase(state, frame, target, back, run)
		state.run, state.back = run, back or nil
		local driver = state.driver
		local moving = driver ~= nil and driver:IsShown()
		if state.frame == frame and state.target == target and (moving or state.sent == target) then
			-- Already there: going back lets the tracker go now.
			if back and not moving then
				state.alpha, state.sent, state.target, state.back = nil, nil, nil, nil
			end
			return
		end
		if not driver then
			driver = CreateFrame("Frame")
			ns.Own[driver] = true
			driver:Hide()
			driver:SetScript("OnUpdate", function(_, elapsed)
				if state.broken then
					driver:Hide()
					return
				end
				state.broken = true
				state.run(Step, state, elapsed)
			end)
			state.driver = driver
		end
		local ok, now = pcall(frame.GetAlpha, frame)
		local from = (ok and ns.Finite(now)) and now or state.sent or target
		state.frame, state.target, state.from, state.t, state.broken = frame, target, from, 0, nil
		state.span = target < from and DOWN or UP
		state.sent = from
		driver:Show()
	end

	-- Stops an ease where it is; the caller lets the tracker go.
	function ns.TrackerEaseStop(state)
		if state.driver then
			state.driver:Hide()
		end
		state.target, state.back = nil, nil
	end
end

-- Runs a step of the tracker's ease as the tracker's part.
function look.run(fn, ...)
	Run("tracker panel", fn, ...)
end

-- The opacity of the tracker while the player is in a fight. fight is nothing when the game's own state is to be asked. The opacity the tracker had is
-- read the first time a lower one is set and eased back to when the fight is over or the setting goes back to 100 (ns.TrackerEase). Of a tracker the
-- Fading page holds it is the opacity that page read before its first write (ns.FadeGiven); that page leaves the tracker alone meanwhile, the ease back
-- included (ns.TrackerFades). While that page fades the tracker by its row of When shown, the opacity to put back goes to it in place of the ease
-- (ns.FadeTakesBack; not an opacity of 0, which that page leaves alone), and the tracker fades on from the alpha it has instead of showing at full.
local function TrackerAlpha(_, fight)
	local frame = Frame("ObjectiveTrackerFrame")
	if not frame or type(frame.SetAlpha) ~= "function" then
		return
	end
	if fight == nil then
		fight = InCombatLockdown()
	end
	local percent = Val("tracker panel", "trackerCombat") or 100
	local wanted = fight and percent < 100 and percent / 100 or nil
	if wanted ~= nil then
		if look.alpha == nil then
			local given = ns.FadeGiven and ns.FadeGiven(frame)
			local ok, alpha = pcall(frame.GetAlpha, frame)
			look.alpha = ns.Finite(given) and given or ((ok and ns.Finite(alpha)) and alpha or 1)
		end
		ns.TrackerEase(look, frame, wanted, false, look.run)
	elseif look.alpha ~= nil then
		if ns.FadeTakesBack and ns.FadeTakesBack(frame, look.alpha) then
			ns.TrackerEaseStop(look)
			look.alpha, look.sent = nil, nil
		else
			ns.TrackerEase(look, frame, look.alpha, true, look.run)
		end
	end
end

-- True for the objective tracker while Opacity in combat holds its alpha in a fight, for the Fading page, which leaves the tracker to it then.
function ns.TrackerFades(frame)
	return look.sent ~= nil and frame ~= nil and frame == _G.ObjectiveTrackerFrame
end

-- The size of the heading of the tracker and of each module.
local function HeaderSizes(headers)
	local percent = Val("tracker headers", "trackerHeaderSize") or 100
	for _, header in ipairs(headers) do
		if not ns.Forbidden(header) then
			Size(header.Text, percent, "a tracker heading")
		end
	end
end

-- A module keeps the bars it has handed out in two tables of its own (ObjectiveTrackerModule.lua:498-566). A module lays out its blocks and sets its
-- own height at the end of every layout (ObjectiveTrackerModule.lua:213-221), and a bar that is new makes the module taller, so the bars of a module
-- that are not styled yet are styled on the next frame after its size changes.
local function TrackerBarsPass()
	if ns.IsStopped(KEY) or not Wanted("tracker bars") then
		return
	end
	for _, name in ipairs(TRACKER_MODULES) do
		local module = Frame(name)
		if module then
			Visit("tracker bars", ApplyTrackerBar, module.usedProgressBars)
			Visit("tracker bars", ApplyTrackerBar, module.usedTimerBars)
		end
	end
end
local ItemHook = Hook("tracker items", ApplyTrackerItem)

local function RefreshTracker()
	Restyle("tracker headers")
	Restyle("tracker bars")
	Restyle("tracker items")
	Restyle("tracker panel")
	local container = Frame("ObjectiveTrackerFrame")
	if container then
		Visit("tracker panel", ApplyTrackerPanel, { container })
	end
	Run("tracker panel", TrackerAlpha, look)
	local headers = { container and container.Header }
	local bars = Wanted("tracker bars")
	for _, name in ipairs(TRACKER_MODULES) do
		local module = Frame(name)
		if module then
			headers[#headers + 1] = module.Header
			if bars then
				OnScript(module, "OnSizeChanged", "bars", TrackerBarsPass)
			end
			Visit("tracker bars", ApplyTrackerBar, module.usedProgressBars)
			Visit("tracker bars", ApplyTrackerBar, module.usedTimerBars)
			Visit("tracker items", ApplyTrackerItem, module.usedRightEdgeFrames)
		end
	end
	Visit("tracker headers", ApplyTrackerHeader, headers)
	Run("tracker headers", HeaderSizes, headers)
	if Wanted("tracker items") then
		FollowMixin("QuestObjectiveItemButtonMixin", "SetUp", ItemHook)
	end
	-- The quest count reads the heading's font after Heading size set it.
	if ns.QuestCountRefresh ~= nil then
		ns.QuestCountRefresh()
	end
	-- Questie's tracker takes the same rows (QuestieSkin.lua).
	if ns.QuestieSkinRefresh ~= nil then
		ns.QuestieSkinRefresh()
	end
end

-- Loot window and loot rolls ----------------------------------------------------------------------------

local function ApplyLootWindow(window)
	local on = Wanted("loot window")
	local rec = Plate("loot window", ApplyLootWindow, window, window, on, true)
	if not rec then
		return
	end
	local nine, back = Child(window, "NineSlice"), Child(window, "Bg")
	if nine then
		Art(rec, nine, HEADER_PIECES, on)
	end
	if back then
		Art(rec, back, PANEL_FILL, on)
	end
end

-- A card in the list: its outline and its item slot take the colour the game gives the card for the quality of the item. The card keeps its
-- own fill. The game starts the card again with Init every time a slot is filled.
local function ApplyLootRow(row)
	local item = Child(row, "Item")
	if not item then
		return
	end
	local on = Wanted("loot window")
	local rec = Plate("loot window", ApplyLootRow, row, row, on, false)
	if not rec then
		return
	end
	if on and not rec.slot and not Later(item) then
		rec.slot = ns.Outline(item, item)
	end
	ns.SetOutline(rec.slot, on, on)
	Art(rec, row, { "BorderFrame" }, on)
	Art(rec, item, SLOT_ART, on)
	local icon = item.icon
	if icon ~= nil and not ns.IsSecret(icon) and (on or rec.cropped) then
		rec.cropped = on or nil
		if on then
			local crop = Crop()
			icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
		else
			icon:SetTexCoord(0, 1, 0, 1)
		end
	end
	-- The game sets the word for the quality in Init and leaves whether it shows alone (LootFrame.lua:617).
	local quality = Child(row, "QualityText")
	local hide = on and ns.Get(KEY .. ".lootQualityText") ~= true
	if quality and (hide or rec.qualityHidden) then
		rec.qualityHidden = hide or nil
		ns.SetHidden(quality, hide)
	end
	local r, g, b
	if on then
		r, g, b = Tint(row.NameFrame)
	end
	ns.SetOutlineColour(rec.outline, r, g, b)
	ns.SetOutlineColour(rec.slot, r, g, b)
end

-- True for the game's four roll frames (GroupLootFrame1 to 4, MKBGroupLootFrameTemplate). The cards of the gamepad interface pass through
-- GroupLootFrame_SetupItemDisplay too (GroupLootFrame.lua:1184) but lay their buttons out otherwise (GroupLootFrame.xml:553-597), so they
-- keep the game's places for their buttons and timer and take the rest of the look.
function ROLL.Ours(frame)
	for index = 1, ROLL_FRAMES do
		if rawequal(_G["GroupLootFrame" .. index], frame) then
			return true
		end
	end
	return false
end

-- The timer of a roll: across the foot of the frame, one level above it so that the flat background does not cover it, or back where the game
-- has it, one level under the frame as the game sets it at every roll (GroupLootFrame.lua:362). A gamepad card keeps its timer's place.
function ROLL.Timer(frame, timer, on, rec)
	if not (on or rec.timerMoved) then
		return
	end
	rec.timerMoved = on or nil
	if ROLL.Ours(frame) then
		local spot = ROLL.timer
		timer:ClearAllPoints()
		if on then
			timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", spot.inset, spot.lift)
			timer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -spot.inset, spot.lift)
			timer:SetHeight(spot.height)
		else
			timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", spot.x, spot.y)
			timer:SetSize(spot.width, spot.height)
		end
	end
	local level = Level(frame)
	if level then
		timer:SetFrameLevel(math.max(0, level + (on and 1 or -1)))
	end
end

-- The Need, Greed, Transmog and Pass buttons: a row at the right, or back where the game has them. The game never places them itself. Not on
-- a gamepad card, whose buttons stand elsewhere.
function ROLL.Buttons(frame, on, rec)
	local holder = Child(frame, "LootButtonContainer")
	if not holder or not ROLL.Ours(frame) or not (on or rec.buttonsMoved) then
		return
	end
	rec.buttonsMoved = on or nil
	local side = on and ROLL.flatButton or ROLL.button
	for _, spot in ipairs(on and ROLL.flat or ROLL.game) do
		local button = Child(holder, spot[1])
		local relative = spot[3] == "frame" and frame or spot[3] == "container" and holder or Child(holder, spot[3])
		if button and relative then
			button:ClearAllPoints()
			button:SetPoint(spot[2], relative, spot[4], spot[5], spot[6])
			button:SetSize(side, side)
		end
	end
end

-- The red of the last seconds of a roll: the text, and the timer's bar, which the game colours 1, 1, 0 (GroupLootFrame.xml:381). The seconds are
-- read ten times a second.
ROLL.red, ROLL.redBar, ROLL.every = { 1, 0.25, 0.25 }, { 1, 0.2, 0.2 }, 0.1

-- The timer's bar in the red of the last seconds, or back in the colour it had, which is read before the first write. SetStatusBarColor is a widget
-- method, and the roll frames are not protected. FillOf keeps the game's colour on this bar (tinted), so the two do not fight.
function ROLL.Red(clock, red)
	if red == (clock.red == true) then
		return
	end
	local timer = clock.timer
	if red and clock.colour == nil then
		local ok, r, g, b = pcall(timer.GetStatusBarColor, timer)
		clock.colour = (ok and ns.Finite(r) and ns.Finite(g) and ns.Finite(b)) and { r, g, b } or { 1, 1, 0 }
	end
	local bar = red and ROLL.redBar or clock.colour
	if bar then
		pcall(timer.SetStatusBarColor, timer, bar[1], bar[2], bar[3])
	end
	if red then
		clock.text:SetTextColor(ROLL.red[1], ROLL.red[2], ROLL.red[3])
	else
		clock.text:SetTextColor(1, 1, 1)
	end
	clock.red = red or nil
end

-- The seconds left, from the timer's value in thousandths (the game sets it every frame to GetLootRollTimeLeft, from 0 to the roll's time:
-- GroupLootFrame.lua:162-168, 421-435). Nothing for a value of 0, which the Need animation sets (:438-439), or while the row or the part is off.
-- The text is written only when the whole second changes; under 10 it and the bar are red, and back at 10 or more, as when a new roll starts.
function ROLL.Tick(clock, value)
	local secs
	if clock.on and Wanted("loot rolls") and ns.Get(KEY .. ".lootRollTime") == true and ns.Finite(value) and value > 0 then
		secs = math.ceil(value / 1000)
	end
	if secs == clock.secs then
		return
	end
	local was = clock.secs
	clock.secs = secs
	clock.text:SetText(secs and tostring(secs) or "")
	ROLL.Red(clock, secs ~= nil and secs < 10)
	-- Sound before a roll ends: once, as a roll still on the screen (the game takes a roll away once you roll on it) comes down to ROLL.warnAt
	-- seconds from above them, so a roll that starts with less, the Need animation's 0 and a roll that ends say nothing. ns.PlayKit plays one
	-- sound a second at most, so rolls that end together ring once.
	if secs ~= nil and secs <= ROLL.warnAt and ns.Finite(was) and was > ROLL.warnAt then
		ROLL.Sound(ns.Get(KEY .. ".lootRollSound"))
	end
end

-- The sounds of Sound before a roll ends, by choice, as places in ns.SOUNDS (IconRow.lua), and the seconds left it plays at.
ROLL.kits, ROLL.warnAt = { spell = 1, chimes = 2, bell = 3, warhorn = 4, raid = 5, alarm = 6, whisper = 7 }, 5

-- Plays the sound of a choice of Sound before a roll ends; None plays nothing.
function ROLL.Sound(choice)
	local kit = ROLL.kits[choice]
	local sound = kit and type(ns.SOUNDS) == "table" and ns.SOUNDS[kit]
	if type(sound) == "table" and type(ns.PlayKit) == "function" then
		ns.PlayKit(sound[1])
	end
end

-- Picking a Sound before a roll ends plays it once, so it can be chosen by ear, only while the options window shows and out of a fight.
function ns.LootRollSoundPicked(path)
	if type(path) ~= "string" or InCombatLockdown() or not (type(ns.PanelShown) == "function" and ns.PanelShown() == true) then
		return
	end
	ROLL.Sound(ns.Get(path))
end

-- Seconds left on rolls: a text of Flat UI's own at the right end just above the timer, on a frame of its own on the roll frame one level over the
-- timer, so it hides with the roll. Its OnUpdate reads the timer's value ten times a second while the roll shows; no method of the game's is
-- followed. Only on the four roll frames: a gamepad card keeps the game's look of its timer.
function ROLL.Time(frame, timer, on, rec)
	local want = on and ROLL.Ours(frame) and ns.Get(KEY .. ".lootRollTime") == true
	local clock = rec.clock
	if want and clock == nil and not Later(frame) then
		local holder = CreateFrame("Frame", nil, frame)
		ns.Own[holder] = true
		holder:SetAllPoints(frame)
		local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
		if not text then
			rec.clock = false
			return
		end
		text:SetJustifyH("RIGHT")
		text:SetPoint("BOTTOMRIGHT", timer, "TOPRIGHT", 0, 2)
		clock = { holder = holder, text = text, timer = timer, wait = 0 }
		rec.clock = clock
		holder:SetScript("OnUpdate", function(_, elapsed)
			clock.wait = clock.wait - elapsed
			if clock.wait > 0 then
				return
			end
			clock.wait = ROLL.every
			local ok, value = pcall(timer.GetValue, timer)
			ROLL.Tick(clock, ok and value or nil)
		end)
		-- A roll that ends takes its red with it, so the next one on this frame starts in the game's colour.
		holder:SetScript("OnHide", function()
			ROLL.Tick(clock, nil)
		end)
	end
	if not clock then
		return
	end
	clock.on = want or nil
	if want then
		local level = Level(timer)
		if level then
			clock.holder:SetFrameLevel(level + 1)
		end
		clock.wait = 0
	else
		ROLL.Tick(clock, nil)
	end
	clock.holder:SetShown(want)
end

-- A roll in Flat UI's look: a flat background and a thin border round the frame in place of the game's toast, the icon cropped with a thin border
-- in the colour of the item's quality, which the game gives the frame's border, the name in that colour as the game writes it, a flat timer with a
-- thin border, and the buttons in a row. The game sets the icon, the colours and the timer's level every time a roll starts. With Seconds left on
-- rolls on, the seconds stand at the right end over the timer (ROLL.Time).
local function ApplyRoll(frame)
	local icon, timer = Child(frame, "IconFrame"), Child(frame, "Timer")
	if not icon then
		return
	end
	local on = Wanted("loot rolls")
	local rec = Plate("loot rolls", ApplyRoll, frame, frame, on, true)
	if not rec then
		return
	end
	if on and not rec.icon and not Later(icon) then
		rec.icon = ns.Outline(icon, icon)
	end
	ns.SetOutline(rec.icon, on, on)
	Art(rec, frame, { "Background", "Border" }, on)
	Art(rec, icon, { "Border" }, on)
	local r, g, b
	if on then
		r, g, b = Tint(frame.Border)
	end
	ns.SetOutlineColour(rec.icon, r, g, b)
	local art = icon.Icon
	if art ~= nil and not ns.IsSecret(art) and (on or rec.cropped) then
		rec.cropped = on or nil
		local crop = on and Crop() or 0
		art:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	if timer then
		if on and not rec.timer and not Later(timer) then
			rec.timer = ns.Outline(timer, timer)
		end
		ns.SetOutline(rec.timer, on, false)
		FillOf(timer, on, ROLL_FILE, 1, 1, 1, true)
		ROLL.Timer(frame, timer, on, rec)
		ROLL.Time(frame, timer, on, rec)
	end
	ROLL.Buttons(frame, on, rec)
end

local RowHook, RollHook = Hook("loot window", ApplyLootRow, true), Hook("loot rolls", ApplyRoll, true)

-- The cards of the open list.
local function LootRows(window)
	local box = Child(window, "ScrollBox")
	local target = box and Child(box, "ScrollTarget")
	if not target then
		return {}
	end
	local ok, rows = pcall(function() return { target:GetChildren() } end)
	return ok and rows or {}
end

-- True while the rolls hang from the box Loot rolls of /flatui move: this page and Movers are on, the profile has a spot saved for the box, and the
-- gamepad interface is off (it lists the rolls in a window of its own, and the game's container places none: GroupLootFrame.lua:114-117).
function ROLL.Moved()
	if not (ns.Enabled(KEY) and not ns.PartStopped(KEY, ROLL.part) and ns.Enabled("movers") and type(ns.MoverSaved) == "function"
		and ns.MoverSaved(ROLL.mover)) then
		return false
	end
	local input = _G.InputUtil
	if input ~= nil and not ns.IsSecret(input) and type(input) == "table" and type(input.IsGamepadUIEnabled) == "function" then
		local ok, pad = pcall(input.IsGamepadUIEnabled)
		return ok and not ns.IsSecret(pad) and pad ~= true
	end
	return true
end

-- The anchor of the rolls: a frame of Flat UI's own on UIParent over the box Loot rolls, at the spot saved for it.
function ROLL.Anchor()
	local left, bottom = ns.MoverSpot(ROLL.mover, "BOTTOMLEFT")
	local right, top = ns.MoverSpot(ROLL.mover, "TOPRIGHT")
	if not (left and right) then
		return nil
	end
	local anchor = ROLL.anchor
	if not anchor then
		anchor = CreateFrame("Frame", nil, UIParent)
		ns.Own[anchor] = true
		ROLL.anchor = anchor
	end
	anchor:ClearAllPoints()
	anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	anchor:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
	return anchor
end

-- Hangs every roll frame the game's container holds (its rollFrames, by slot) from the anchor, slot by slot with the game's room for each, up from
-- the bottom of the box or down from its top as Rolls stack says. With no spot, a frame hung here goes back to the point the container's own
-- layout gives it (GroupLootFrame.lua:124-125). Widget calls on frames that are not protected, so also in a fight.
function ROLL.Place()
	local container = Frame("GroupLootContainer")
	local list = container and container.rollFrames
	if list == nil or ns.IsSecret(list) or type(list) ~= "table" then
		return
	end
	local step = container.reservedSize
	if ns.IsSecret(step) or type(step) ~= "number" or step <= 0 then
		step = ROLL.step
	end
	local anchor = ROLL.Moved() and ROLL.Anchor() or nil
	local down = ns.Get(KEY .. ".lootRollsGrow") == "down"
	for index, frame in pairs(list) do
		if type(index) == "number" and not ns.Forbidden(frame) and (anchor or ROLL.moved[frame]) then
			frame:ClearAllPoints()
			if not anchor then
				ROLL.moved[frame] = nil
				frame:SetPoint("CENTER", container, "BOTTOM", 0, step * (index - 0.5))
			elseif down then
				ROLL.moved[frame] = true
				frame:SetPoint("TOP", anchor, "TOP", 0, -step * (index - 1))
			else
				ROLL.moved[frame] = true
				frame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, step * (index - 1))
			end
		end
	end
end

-- After each layout of the game's container: the rolls go under the anchor again.
function ROLL.Layout()
	if not ns.IsStopped(KEY) and (ROLL.Moved() or next(ROLL.moved) ~= nil) then
		Run(ROLL.part, ROLL.Place)
	end
end

-- The game's container is followed from the first time a spot is saved for the box, and the rolls are hung there or given back now.
function ROLL.Spot()
	if ROLL.Moved() then
		ns.FollowGlobal("GroupLootContainer_Update", ROLL.Layout)
	end
	Run(ROLL.part, ROLL.Place)
end

local function RefreshLoot()
	Restyle("loot window")
	Restyle("loot rolls")
	local window = Frame("LootFrame")
	Visit("loot window", ApplyLootWindow, { window })
	if window then
		Visit("loot window", ApplyLootRow, LootRows(window))
	end
	local rolls = {}
	for index = 1, ROLL_FRAMES do
		rolls[index] = Frame("GroupLootFrame" .. index)
	end
	Visit("loot rolls", ApplyRoll, rolls)
	if Wanted("loot window") then
		FollowMixin("LootFrameElementMixin", "Init", RowHook)
	end
	if Wanted("loot rolls") then
		FollowGlobal("GroupLootFrame_SetupItemDisplay", RollHook)
	end
	ROLL.Spot()
end

-- The box Loot rolls in /flatui move has a handle while this page is on.
function ns.LootRollsShown()
	return ns.Enabled(KEY)
end

-- The movers set or put back the spot of the box: the rolls shown now go there, or back to the game's layout.
function ns.LootRollsMoved()
	if not ns.IsStopped(KEY) then
		ROLL.Spot()
	end
end

-- Where the box starts while no spot is saved: where the game stacks its rolls, the bottom of the first half a frame under the middle of the first
-- slot of the game's container (GroupLootFrame.lua:125), and that container in the game's bottom stack above the action bars
-- (UIParentPanelManager.lua:807-815). Read from the container while it shows, else from the bottom of the stack; the entry's own x and y while
-- neither can be read.
function ns.LootRollsStart(x, y)
	local game = Frame("GroupLootContainer")
	local ok, shown = false, false
	if game then
		ok, shown = pcall(game.IsShown, game)
	end
	local frame = (ok and not ns.IsSecret(shown) and shown == true) and game or Frame("BottomManagedFrameContainer")
	if not frame or not UIParent then
		return x, y
	end
	local okBottom, bottom = pcall(frame.GetBottom, frame)
	local okScale, scale = pcall(frame.GetEffectiveScale, frame)
	local okParent, parentScale = pcall(UIParent.GetEffectiveScale, UIParent)
	if not (okBottom and okScale and okParent and ns.Finite(bottom) and ns.Finite(scale) and ns.Finite(parentScale) and parentScale > 0) then
		return x, y
	end
	local first = Frame("GroupLootFrame1")
	local okHeight, height = false, nil
	if first then
		okHeight, height = pcall(first.GetHeight, first)
	end
	if not (okHeight and ns.Finite(height)) then
		height = 67
	end
	return x, bottom * scale / parentScale + ROLL.step / 2 - height / 2
end

-- Alerts ------------------------------------------------------------------------------------------------

-- The toast is one picture with its fill and its frame in it. The picture goes, and a flat background and a thin border take its place;
-- the text and the item stay. A toast that holds text for a light picture, such as the achievement toast, is left alone.
local function ApplyAlert(frame)
	local on = Wanted("alerts")
	local rec = Plate("alerts", ApplyAlert, frame, frame, on, true)
	if rec then
		Art(rec, frame, ALERT_ART, on)
	end
end

-- The toasts a system of alerts shows now.
local function ActiveAlerts(system)
	local pool = system.alertFramePool
	if pool == nil or ns.IsSecret(pool) or type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then
		return
	end
	for frame in pool:EnumerateActive() do
		if not ns.Forbidden(frame) and plates[frame] == nil then
			ApplyAlert(frame)
		end
	end
end

-- A system makes a toast from its pool when the alert frame gets one of the events of AlertFrames.lua:473-496 (handled at :560-705), so the toasts of
-- the systems are looked at on the next frame after those events. A toast that has been shown before is styled already.
-- AZERITE_EMPOWERED_ITEM_LOOTED and PERKS_PROGRAM_CURRENCY_AWARDED also lead to LootAlertSystem:AddAlert (AlertFrames.lua:636, 703-705) and are not in the list.
local function RefreshAlerts()
	Restyle("alerts")
	for _, name in ipairs(ALERT_SYSTEMS) do
		local system = _G[name]
		if system ~= nil and not ns.IsSecret(system) and type(system) == "table" then
			Run("alerts", ActiveAlerts, system)
		end
	end
end

local function AlertsPass()
	if ns.IsStopped(KEY) or not Wanted("alerts") then
		return
	end
	for _, name in ipairs(ALERT_SYSTEMS) do
		local system = _G[name]
		if system ~= nil and not ns.IsSecret(system) and type(system) == "table" then
			Run("alerts", ActiveAlerts, system)
		end
	end
end

-- Breath and countdown timers --------------------------------------------------------------------------------

-- The time left on a timer goes back to nothing: no text, white, and no value to compare the next one with.
function MIRROR.Reset(clock)
	clock.last, clock.falling = nil, nil
	if clock.secs ~= nil then
		clock.secs = nil
		clock.text:SetText("")
	end
	if clock.red then
		clock.red = nil
		clock.text:SetTextColor(1, 1, 1)
	end
end

-- The time left on a breath, fatigue or feign death timer, from its bar's value, which is in seconds: the game sets it every frame to
-- GetMirrorTimerProgress / 1000 on a range of 0 to the timer's length (MirrorTimer.lua:130-136, 146-156, 174-176). It is written as 1:12 when the
-- whole second changes, red under 10 while the value falls (the timer runs out) and white while it rises (breath comes back); a paused timer
-- (MIRROR_TIMER_PAUSE) keeps its text and colour. Nothing while the timer runs none (Edit Mode shows the bars empty), or the row or the part is off.
function MIRROR.Tick(clock)
	local value
	if clock.on and Wanted("mirror timers") and ns.Get(KEY .. ".mirrorTime") == true then
		local running = clock.timer.timer
		if running ~= nil and not ns.IsSecret(running) then
			local ok, seconds = pcall(clock.bar.GetValue, clock.bar)
			if ok and ns.Finite(seconds) and seconds >= 0 then
				value = seconds
			end
		end
	end
	if value == nil then
		MIRROR.Reset(clock)
		return
	end
	if clock.last ~= nil and value ~= clock.last then
		clock.falling = value < clock.last
	end
	clock.last = value
	local secs = math.ceil(value)
	if secs ~= clock.secs then
		clock.secs = secs
		clock.text:SetText(("%d:%02d"):format(math.floor(secs / 60), secs % 60))
	end
	local red = clock.falling == true and secs < 10
	if red ~= (clock.red == true) then
		clock.red = red or nil
		if red then
			clock.text:SetTextColor(MIRROR.red[1], MIRROR.red[2], MIRROR.red[3])
		else
			clock.text:SetTextColor(1, 1, 1)
		end
	end
end

-- Seconds on the timers: a text of Flat UI's own at the right end of the label box under the bar, where the game's label stays centred
-- (MirrorTimer.xml: Text fills the 14 units under the StatusBar), on a frame of its own on the timer, so it hides with the timer. Its OnUpdate reads
-- the bar's value ten times a second while the timer shows; no method of the game's is followed.
function MIRROR.Time(timer, bar, on, rec)
	local want = on and ns.Get(KEY .. ".mirrorTime") == true
	local clock = rec.clock
	if want and clock == nil and not Later(timer) then
		local holder = CreateFrame("Frame", nil, timer)
		ns.Own[holder] = true
		holder:SetAllPoints(timer)
		local text = ns.OwnText(holder, "OVERLAY", "GameFontHighlightSmall")
		if not text then
			rec.clock = false
			return
		end
		text:SetJustifyH("RIGHT")
		text:SetPoint("RIGHT", bar, "BOTTOMRIGHT", -4, -7)
		clock = { holder = holder, text = text, timer = timer, bar = bar, wait = 0 }
		rec.clock = clock
		holder:SetScript("OnUpdate", function(_, elapsed)
			clock.wait = clock.wait - elapsed
			if clock.wait > 0 then
				return
			end
			clock.wait = MIRROR.every
			MIRROR.Tick(clock)
		end)
		holder:SetScript("OnHide", function()
			MIRROR.Reset(clock)
		end)
	end
	if not clock then
		return
	end
	clock.on = want or nil
	clock.wait = 0
	if not want then
		MIRROR.Reset(clock)
	end
	clock.holder:SetShown(want)
end

-- The three timers exist from the start. The game puts a new picture in the fill every time one starts, so the fill is made solid again then,
-- in the cast colour that stands for the picture. With Seconds on the timers on, the time left stands at the right under the bar (MIRROR.Time).
local function ApplyMirror(timer)
	local on = Wanted("mirror timers")
	local bar = Child(timer, "StatusBar")
	if not bar then
		return
	end
	local rec = Plate("mirror timers", ApplyMirror, timer, bar, on, true)
	if not rec then
		return
	end
	if rec.back == nil then
		rec.back = ns.RegionWithAtlas(timer, MIRROR_BACKGROUND) or false
		if not rec.back then
			ns.Note(KEY, LABEL .. ": the default background of a breath or fatigue timer was not found and is still shown.")
		end
	end
	Art(rec, timer, { "Border", "TextBorder" }, on)
	ns.SetFaded(rec.back or nil, on)
	local region = on and ns.FillRegion(bar)
	if region then
		local ok, atlas = pcall(region.GetAtlas, region)
		if ok and not ns.IsSecret(atlas) and type(atlas) == "string" and atlas ~= "" then
			rec.atlas = atlas
		end
	end
	local r, g, b = ns.Colour("castbars." .. (MIRROR_FILLS[(rec.atlas or ""):lower()] or "castColour"))
	FillOf(bar, on, rec.atlas, r, g, b)
	MIRROR.Time(timer, bar, on, rec)
end

-- The bar of a countdown timer has its frame as a texture with a name of its own. The game fades the bar in and out, and the border goes with it.
local function ApplyCountdown(bar)
	local on = Wanted("countdown timers")
	local rec = Plate("countdown timers", ApplyCountdown, bar, bar, on, false)
	if not rec then
		return
	end
	if rec.border == nil then
		local ok, name = pcall(bar.GetName, bar)
		local region = ok and not ns.IsSecret(name) and type(name) == "string" and _G[name .. "Border"] or nil
		rec.border = region ~= nil and not ns.IsSecret(region) and region or false
		if not rec.border then
			ns.Note(KEY, LABEL .. ": the default frame of a countdown timer was not found and is still shown.")
		end
	end
	ns.SetFaded(rec.border or nil, on)
	FillOf(bar, on, BAR_FILE, 1, 1, 1, true)
end

local MirrorHook = Hook("mirror timers", ApplyMirror, true)

-- The game puts a new picture in the fill of a timer in Setup, which its container calls when a timer starts and when the player enters the world
-- (MirrorTimer.lua:25-48, 146-158), so the fill is made solid again on the next frame after those events.
local function MirrorPass()
	local container = Frame("MirrorTimerContainer")
	local timers = container and container.mirrorTimers
	if timers == nil or ns.IsSecret(timers) or type(timers) ~= "table" then
		return
	end
	for _, timer in pairs(timers) do
		MirrorHook(timer)
	end
end

-- The bar of each timer the game has made.
local function CountdownBars(tracker)
	local bars, list = {}, tracker.timerList
	if list ~= nil and not ns.IsSecret(list) and type(list) == "table" then
		for _, timer in pairs(list) do
			if not ns.Forbidden(timer) then
				bars[#bars + 1] = timer.bar
			end
		end
	end
	return bars
end

local function CountdownHook(tracker)
	if not ns.IsStopped(KEY) and not ns.Forbidden(tracker) and Wanted("countdown timers") then
		Visit("countdown timers", ApplyCountdown, CountdownBars(tracker))
	end
end

local function RefreshTimers()
	Restyle("mirror timers")
	Restyle("countdown timers")
	local container = Frame("MirrorTimerContainer")
	local timers = container and container.mirrorTimers
	Visit("mirror timers", ApplyMirror, timers)
	local tracker = Frame("TimerTracker")
	if tracker then
		Visit("countdown timers", ApplyCountdown, CountdownBars(tracker))
	end
	if Wanted("countdown timers") then
		FollowGlobal("TimerTracker_StartTimerOfType", CountdownHook)
	end
end

-- Queue panel, damage meter and zone event bars -------------------------------------------------------------------

-- The panel is a tooltip frame: its nine pieces go, and a flat background and a thin border take their place.
local function ApplyQueue(frame)
	local on = Wanted("queue status")
	local rec = Plate("queue status", ApplyQueue, frame, frame, on, true)
	local nine = rec and Child(frame, "NineSlice")
	if nine then
		Art(rec, nine, HEADER_PIECES, on)
	end
end

-- The banner along the top of a window is a texture of its own. The body keeps the game's background.
local function ApplyMeter(window)
	local header = window.Header
	if header == nil or ns.IsSecret(header) or type(header) ~= "table" then
		return
	end
	local on = Wanted("damage meter")
	local rec = Plate("damage meter", ApplyMeter, window, header, on, true)
	if rec then
		Art(rec, window, { "Header" }, on)
	end
end

-- The border and background of a bar that shows a score or progress. The kind of widget with two bars is left alone.
local function ApplyZoneBar(widget)
	local bar = Child(widget, "Bar")
	if not bar or bar.BorderLeft == nil then
		return
	end
	local on = Wanted("zone bars")
	local rec = Plate("zone bars", ApplyZoneBar, widget, bar, on, true)
	if rec then
		Art(rec, bar, WIDGET_ART, on)
	end
end

local function MeterWindows()
	local windows = {}
	for index = 1, METER_WINDOWS do
		windows[index] = Frame("DamageMeterSessionWindow" .. index)
	end
	return windows
end

-- The windows are made by SetupSessionWindow (DamageMeter.lua:284-300) when the meter is made, when a saved window is brought back and when one is
-- added, and a window that is shown is sent the events of the meter (DamageMeterSessionWindow.lua:181-211), so the windows are looked at on the next
-- frame after those events and the events of the meter itself (DamageMeter.lua:88-92).
local function MeterPass()
	if not ns.IsStopped(KEY) and Wanted("damage meter") then
		Visit("damage meter", ApplyMeter, MeterWindows())
	end
end
local ZoneHook = Hook("zone bars", ApplyZoneBar)

local function RefreshOther()
	Restyle("queue status")
	Restyle("damage meter")
	Restyle("zone bars")
	Visit("queue status", ApplyQueue, { Frame("QueueStatusFrame") })
	Visit("damage meter", ApplyMeter, MeterWindows())
	for _, name in ipairs(WIDGET_CONTAINERS) do
		local container = Frame(name)
		if container then
			Visit("zone bars", ApplyZoneBar, container.widgetFrames)
		end
	end
	if Wanted("zone bars") then
		FollowMixin("UIWidgetTemplateStatusBarMixin", "Setup", ZoneHook)
	end
end

-- The module --------------------------------------------------------------------------------------

local function RefreshMinimap()
	Run("minimap", FollowCity)
	Run("minimap", ApplyMinimap)
	Run("minimap", ZoomSeen, minimap, false)
	-- The text around the map follows its rows, the page, the profile and a new world (MapText.lua).
	if ns.MapTextRefresh then
		ns.MapTextRefresh()
	end
end

-- Whether the game's own code has set its mask on the city map: the fields it sets on the map canvas (Blizzard_HybridMinimap.lua:11-12,
-- Blizzard_MapCanvas.lua:1175-1203). They say what the game asked for and not that the mask takes effect. Nothing when they cannot be read.
local function CityMask(map)
	local ok, canvas = pcall(Child, map, "MapCanvas")
	if not ok or canvas == nil then
		return nil
	end
	local read, use, mask = pcall(function() return canvas.useMaskTexture, canvas.maskTexture end)
	if not read or ns.IsSecret(use) or ns.IsSecret(mask) then
		return nil
	end
	return use == true and mask ~= nil
end

-- What the game says about asking for the city map in this place: yes, no, or unknown when the call is missing, raises or is withheld.
local function CityAsked()
	local api = _G.C_Minimap
	if type(api) ~= "table" or type(api.ShouldUseHybridMinimap) ~= "function" then
		return "unknown"
	end
	local ok, asked = pcall(api.ShouldUseHybridMinimap)
	if not ok or ns.IsSecret(asked) or type(asked) ~= "boolean" then
		return "unknown"
	end
	return asked and "yes" or "no"
end

-- A line for /flatui status whenever the page is on. It says what the game reports: whether it asks for the city map in this place, whether it has
-- loaded the city map and whether it is shown. While it is shown the line has what the cover depends on: where the game puts the city map in the
-- draw order, whether the game's mask is set on it, and where the cover is. When the game will not say whether the city map is shown, the setting
-- is off and the line says so.
local function CityStatus()
	if not ns.Enabled(KEY) then
		return {}
	end
	local asked = ", game asks for it: " .. CityAsked() .. "."
	local map = CityMap()
	if map == nil then
		return { "Minimap in cities: " .. (_G.HybridMinimap == nil and "city map not loaded" or "city map cannot be read") .. asked }
	end
	local shown = CityShown()
	if shown == nil then
		return { "Minimap in cities: off, the game does not say whether the city map is shown" .. asked }
	end
	if not shown then
		return { "Minimap in cities: city map not shown" .. asked }
	end
	local facts, stack, mask = {}, Stack(map), CityMask(map)
	if stack then
		facts[#facts + 1] = stack
	end
	if mask ~= nil then
		facts[#facts + 1] = mask and "game's mask set" or "game's mask not set"
	end
	local line = "city map shown" .. (#facts > 0 and (" (" .. table.concat(facts, ", ") .. ")") or "")
	local cover = minimap.cover
	if cover and cover.on then
		local at = Stack(cover.frame)
		line = line .. ", cover shown" .. (at and (" (" .. at .. ")") or "")
		-- A cover on a minimap that is hidden is not on the screen.
		local ok, seen = pcall(cover.frame.IsVisible, cover.frame)
		if ok and not ns.IsSecret(seen) and seen == false then
			line = line .. ", not visible"
		end
	else
		line = line .. ", no cover" .. (minimap.blocked and CityChoice() == "cover" and " (the game does not let the minimap be read)" or "")
	end
	return { "Minimap in cities: " .. line .. asked }
end

-- The lines of /flatui status: the city map, and the zoom reset when the game does not say the zoom level.
local function Status()
	local lines = CityStatus()
	if minimap.zoomBlind and Val("minimap", "zoomReset") ~= nil then
		lines[#lines + 1] = "Minimap zoom out: off, the game does not say the zoom level."
	end
	return lines
end

-- True when a frame of the buffs exists and there is something to style or take back.
local function AurasShown()
	if _G.BuffFrame == nil and _G.DebuffFrame == nil and _G.DeadlyDebuffFrame == nil then
		return false
	end
	return On("auras", "auras") or (Val("auras", "durationSize") or 100) ~= 100 or (Val("auras", "countSize") or 100) ~= 100 or next(auras) ~= nil
end

-- The events the game handles in its own frames, followed with HookScript on those frames (it writes nothing on them): the status bar manager
-- sets the text of the bars on the zone changes and more, and the buff frame hands out its buttons again when a weapon enchant changes
-- (BuffFrame.lua:536-540).
local function HookGameEvents()
	local manager = Frame("StatusTrackingBarManager")
	if manager ~= nil and not XpBarsOff() then
		OnScript(manager, "OnEvent", "xptext", XpTextPass)
	end
	local buff = Frame("BuffFrame")
	if buff ~= nil then
		OnScript(buff, "OnEvent", "auraevents", function()
			if AurasShown() then
				RefreshAuras()
			end
		end)
	end
end

function Refresh()
	if ns.XpBarRefresh ~= nil then
		ns.XpBarRefresh()
	end
	HookGameEvents()
	RefreshMinimap()
	RefreshBags()
	RefreshAuras()
	RefreshXpBars()
	RefreshMicro()
	RefreshTracker()
	RefreshLoot()
	RefreshAlerts()
	-- The game's red error messages: the event is taken from its frame or given back (ErrorFilter.lua).
	if ns.ErrorFilterRefresh ~= nil then
		ns.ErrorFilterRefresh()
	end
	-- The zone name and the talking head: the opacity of the zone text, the event of the talking head (ScreenText.lua).
	if ns.ScreenTextRefresh ~= nil then
		ns.ScreenTextRefresh()
	end
	-- The damage meter cleared as the player enters a dungeon or raid: a clear that waits and the popup that asks follow the rows (MeterClear.lua).
	if ns.MeterClearRefresh ~= nil then
		ns.MeterClearRefresh()
	end
	-- The hit table under the player frame: shown, heard and placed as its rows and, at For tanks and damage dealers, the player's role say, or
	-- hidden (HitTable.lua, which also hears the events that can change the role through this module).
	if ns.HitTableRefresh ~= nil then
		ns.HitTableRefresh()
	end
	RefreshTimers()
	RefreshOther()
	-- The addon buttons follow the part switch and a change of profile (MapButtons.lua).
	if ns.MapButtonsChanged then
		ns.MapButtonsChanged()
	end
end

ns.Register(KEY, {
	label = LABEL, Start = Refresh, Refresh = Refresh, Resized = RefreshMinimap, Status = Status,
	-- The game loads the city map when the player enters a city, and the hooks go on its frame then.
	-- The clock is made when the game loads its time manager, which happens at login.
	filters = { ADDON_LOADED = function(name) return not ns.IsSecret(name) and (name == CITY_ADDON or name == "Blizzard_TimeManager") end },
	events = {
		ADDON_LOADED = RefreshMinimap,
		PLAYER_ENTERING_WORLD = function()
			RefreshMinimap()
			QueueFill()
		end,
		MINIMAP_UPDATE_ZOOM = function() Run("minimap", ZoomSeen, minimap, true) end,
		PLAYER_REGEN_DISABLED = function() Run("tracker panel", TrackerAlpha, look, true) end,
		PLAYER_REGEN_ENABLED = function() Run("tracker panel", TrackerAlpha, look, false) end,
	},
})
for _, event in ipairs(FILL_EVENTS) do
	ns.AddEvent(KEY, event, function()
		QueueFill(true)
	end)
end

-- The places that followed a method of a frame of the game's follow its events instead, and look again on the next frame (Soon): the game's own
-- handler has run by then, whatever the order of the handlers. A pass is queued only when there is something for it to look at.
local function ForPlayer(unit) return not ns.IsSecret(unit) and (unit == "player" or unit == "vehicle") end
local function ForCVar(name) return not ns.IsSecret(name) and name == "rotateMinimap" end
local function SquareMap() return minimap.squared == true end
local function BagsStyled() return next(bags) ~= nil end
local function AlertsWanted() return _G.LootAlertSystem ~= nil and Wanted("alerts") end
local function MirrorsWanted() return _G.MirrorTimerContainer ~= nil and Wanted("mirror timers") end
local function MeterWanted() return _G.DamageMeter ~= nil and Wanted("damage meter") end
local function After(events, fn, present, filter)
	for _, event in ipairs(events) do
		ns.AddEvent(KEY, event, function()
			if present() then
				Soon(fn, fn)
			end
		end, filter)
	end
end
After({ "CVAR_UPDATE" }, ReMask, SquareMap, ForCVar)
-- Edit Mode applies a layout: the plate of the zone name is hung from the map again on the next frame (headerGap.Apply).
ns.AddEvent(KEY, "EDIT_MODE_LAYOUTS_UPDATED", function()
	if headerGap.Look then
		headerGap.Look()
	end
end)
After({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_ALERTS", "INVENTORY_SEARCH_UPDATE",
	"PLAYER_ENTERING_WORLD" }, BagsPass, BagsStyled)
After({ "UNIT_AURA" }, RefreshAuras, AurasShown, ForPlayer)
After({ "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_IN_COMBAT_CHANGED" }, RefreshAuras, AurasShown)
After({ "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST", "SHOW_PVP_FACTION_LOOT_TOAST", "SHOW_RATED_PVP_REWARD_TOAST", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED" },
	AlertsPass, AlertsWanted)
After({ "MIRROR_TIMER_START", "PLAYER_ENTERING_WORLD" }, MirrorPass, MirrorsWanted)
After({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET", "PLAYER_IN_COMBAT_CHANGED", "GROUP_JOINED",
	"GROUP_LEFT", "PLAYER_ENTERING_WORLD" }, MeterPass, MeterWanted)

-- /flatui status names a status bar this module restyled in this session.
ns.ClickPathReporter(function()
	if rawget(borders, "xpTouched") then
		return "Click path: Flat UI restyled the experience bar."
	end
	return nil
end)
