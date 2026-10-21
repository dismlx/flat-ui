local ADDON_NAME, ns = ...

-- The minimap with the tracking button and the difficulty banner beside its zone name, the bag bar, the buff and debuff icons, the experience and reputation bars and the micro menu, and the objective
-- tracker, the loot window and rolls, alerts, breath and countdown timers, the queue panel, the damage meter and the zone event bars.
-- A frame the game may protect has nothing made on it in combat: ns.MaybeProtected asks the client each time.
-- Each part has its own switch and puts the game's look back when it is off. The game's frame art is made
-- transparent and left in place, and thin borders and flat fills take its place. The map keeps the shape of the
-- mask the game gives it: its border is a disc cut by the same mask, laid below the map.
-- Inside some cities the game shows a map of the city in the minimap, and the setting Minimap in cities says what is done then.

local KEY = "hud"
local LABEL = "Minimap and buffs"
local MAP_MASK = "ui-hud-minimap-frame-generic-mask"
-- The mask of a square map: a plain white picture (the game's own code passes an atlas name to Minimap:SetMaskTexture, and the documentation takes any
-- texture asset: MinimapFrameAPIDocumentation.lua:141-149).
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
-- Seconds between two looks at the minimap zoom.
local ZOOM_EVERY = 0.5
-- The buttons round the minimap that a setting can switch off: the setting, and the field of the cluster or the global name of the frame
-- and the fields of it that take the mouse, since a parent does not turn off the mouse of its children (Minimap.xml:74-93, 105 and 160)
-- (Blizzard_Minimap/Mainline/Minimap.xml:60 and 96, GameTime.xml:3, AddonCompartment.xml:3, Blizzard_TimeManager.xml:178).
local MAP_BUTTONS = { { option = "btnTracking", key = "Tracking", mouse = { "Button" } },
	{ option = "btnMail", key = "IndicatorFrame", mouse = { "MailFrame", "CraftingOrderFrame" } }, { option = "btnCalendar", name = "GameTimeFrame" },
	{ option = "btnClock", name = "TimeManagerClockButton" }, { option = "btnAddons", name = "AddonCompartmentFrame" } }
-- The setting of the colour of each debuff type. A bleed and a debuff with no type take the Other colour.
local TYPE_ROWS = { Magic = "colourMagic", Curse = "colourCurse", Disease = "colourDisease", Poison = "colourPoison", Bleed = "colourOther", None = "colourOther" }
local DIEL_BORDER = "UI-HUD-Minimap-Frame-Cycle"
-- The city map. In some cities the game loads Blizzard_HybridMinimap and shows HybridMinimap, a child of the minimap that covers its whole square
-- (Blizzard_Minimap\Mainline\Minimap.lua:226-232, Blizzard_HybridMinimap.xml:5-10). It is in the lowest strata, BACKGROUND, at level 100, and both
-- are fixed (xml:5), and the game switches the ground of the minimap off while it shows (Blizzard_HybridMinimap.lua:44). The pins of its map are at
-- levels 2000 to 9000 (Blizzard_MapCanvas\MapCanvas_PinFrameLevelsManager.lua:3-4). The cover is a child of the minimap as well, in the strata of the
-- minimap (LOW, from its cluster: Minimap.xml:3, 195-199) at the level of the minimap. That puts it over the city map and its pins, and over what
-- the minimap itself draws, and under the zoom buttons and the ring, which are children of the minimap one level up (Minimap.xml:210-262). It hides
-- with the minimap.
local CITY_ADDON = "Blizzard_HybridMinimap"
local COVER_FILE = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Cover.tga"
-- The pieces of the nine-slice behind the zone name.
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
local ALERT_SYSTEMS = { "LootAlertSystem", "MoneyWonAlertSystem", "HonorAwardedAlertSystem" }
-- The backgrounds of those alerts and the ring round the icon of money and honour. The game shows and hides them and never sets their alpha.
local ALERT_ART = { "Background", "PvPBackground", "RatedPvPBackground", "BGAtlas", "IconBorder" }
-- The cast colour that stands for each picture a breath or fatigue timer is filled with.
local MIRROR_FILLS = { ["ui-castingbar-filling-standard"] = "castColour", ["ui-castingbar-filling-applyingcrafting"] = "craftColour",
	["ui-castingbar-filling-channel"] = "channelColour" }
local MIRROR_BACKGROUND = "ui-castingbar-background"
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
-- The objective tracker: alpha = the opacity the game had while a lower one is set here, sent = the one set.
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

-- The banner under the zone name has one picture for each kind of content, and the game shows one of them.
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

-- The game masks the minimap again when the rotateMinimap variable changes (Blizzard_Minimap/Camelot/Skin.lua:19-37, called from the callback of
-- the variable at :48-50), and the event of the variable comes with that call, so the square mask is put on again on the next frame after it.
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

local function ApplyMinimap()
	local art, border = On("minimap", "minimapArt"), On("minimap", "minimapBorder")
	local choice, up = CityChoice(), CityShown() == true
	local cluster = Frame("MinimapCluster")
	local header, diel = cluster and cluster.BorderTop, cluster and cluster.DielFrame
	header = header ~= nil and not ns.Forbidden(header) and header or nil
	diel = diel ~= nil and not ns.Forbidden(diel) and diel or nil
	-- The tracking button has a plate of its own behind its glyph, and each picture of the banner has a background and a border of its own.
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
		for _, piece in ipairs(HEADER_PIECES) do
			ns.SetFaded(header and header[piece], art)
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
	if header then
		HeaderBorder(header, border)
	end
	if tracking then
		HeaderBorder(tracking, border)
	end
	for _, mode in ipairs(modes) do
		HeaderBorder(mode, border)
	end
	MapBorder(border, square)
	MapOutline(border and square)
	-- The city map has a round mask of its own, which the square mask of the minimap does not reach: no round cover is drawn over a square map.
	CityCover(choice == "cover" and up and not square, border)
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

-- The game gives the highlight its alpha again on every texture update, so it is read before it is faded, and the hover
-- tint is a picture of the addon's own in the layer the game shows on mouseover.
local function ApplyBag(button)
	local on = On("bags", "bags")
	local rec = bags[button]
	if not rec then
		if not on or Later(button) then
			return
		end
		rec = { outline = ns.Outline(button, button), masked = true }
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
	local icon, mask = button.icon, button.SquareMask
	if icon ~= nil and not ns.IsSecret(icon) then
		-- The rounded mask goes with the rounded frame.
		if mask ~= nil and not ns.IsSecret(mask) and rec.masked ~= not on and icon.RemoveMaskTexture and icon.AddMaskTexture then
			rec.masked = not on
			pcall(on and icon.RemoveMaskTexture or icon.AddMaskTexture, icon, mask)
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

-- The sizes of the duration and the count of a button. The game sets their text and colour and not their font (BuffFrame.lua:1338-1399), but a
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

-- The opacity of the tracker while the player is in a fight. fight is nothing when the game's own state is to be asked. The opacity the tracker had is
-- read the first time a lower one is set and put back when the fight is over or the setting goes back to 100.
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
			local ok, alpha = pcall(frame.GetAlpha, frame)
			look.alpha = (ok and ns.Finite(alpha)) and alpha or 1
		end
		if look.sent ~= wanted then
			frame:SetAlpha(wanted)
			look.sent = wanted
		end
	elseif look.alpha ~= nil then
		frame:SetAlpha(look.alpha)
		look.alpha, look.sent = nil, nil
	end
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

-- The game sets the colour of the frame, its name and the ring round the icon for the quality of the item every time a roll starts.
local function ApplyRoll(frame)
	local icon, timer = Child(frame, "IconFrame"), Child(frame, "Timer")
	if not icon then
		return
	end
	local on = Wanted("loot rolls")
	local rec = Plate("loot rolls", ApplyRoll, frame, frame, on, false)
	if not rec then
		return
	end
	if on and not rec.icon and not Later(icon) then
		rec.icon = ns.Outline(icon, icon)
	end
	ns.SetOutline(rec.icon, on, on)
	Art(rec, frame, { "Border" }, on)
	Art(rec, icon, { "Border" }, on)
	local r, g, b
	if on then
		r, g, b = Tint(frame.Border)
	end
	ns.SetOutlineColour(rec.outline, r, g, b)
	ns.SetOutlineColour(rec.icon, r, g, b)
	if timer then
		FillOf(timer, on, ROLL_FILE, 1, 1, 1, true)
	end
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

-- The three timers exist from the start. The game puts a new picture in the fill every time one starts, so the fill is made solid again then,
-- in the cast colour that stands for the picture.
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
	RefreshTimers()
	RefreshOther()
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
