-- Cursor Glow Forever: a glow around the cursor.
--
-- Around the base (glove) cursor it uses the glow textures; around hover
-- cursors (loot bag, pickaxe, sword...) it cuts an outline from the game's own
-- cursor art when it can tell which cursor is showing, and shows nothing when
-- it cannot. While turning the camera the game hides its cursor, so the glove
-- is drawn with a stronger glow where the mouse was.
local addonName, ns = ...
ns.TITLE = "Cursor Glow Forever"

local GetCursorPosition, GetTime, UnitExists, IsMouselooking = GetCursorPosition, GetTime, UnitExists, IsMouselooking
local GameTooltip, UIParent, WorldFrame = GameTooltip, UIParent, WorldFrame

local TEXTURES = "Interface/AddOns/"..addonName.."/textures/"
local CURSORS = "Interface/Cursor/"
local CURSOR_SIZES = {[0] = 32, 48, 64, 96, 128} -- by cursorSizePreferred
-- The hover cursors come from the UI*Cursor2x sheets (the base glove is the
-- classic Interface/Cursor/Point). Every sheet has the same layout: the cell
-- for each cursor size (left, top, size in pixels), by cursor size index.
local SHEET_WIDTH, SHEET_HEIGHT = 512, 256
local SHEET_CELLS = {
	[0] = {261, 67, 32},
	{393, 1, 48},
	{261, 1, 64},
	{1, 131, 96},
	{1, 1, 128},
}
-- the greyed "unable" (out of range) version of each cursor, next to it
local UNABLE_CELLS = {
	[0] = {261, 101, 32},
	{443, 1, 48},
	{327, 1, 64},
	{131, 131, 96},
	{131, 1, 128},
}
local HOVER_SHEETS = {
	Attack = "UIAttackCursor2x",
	LootAll = "UILootAllCursor2x",
	Pickup = "UIPickupCursor2x", -- looting with shift held: a single bag
	Skin = "UICursorSkin2x",
	Mine = "UICursorMine2x",
	GatherHerbs = "UICursorGather2x",
	Mail = "UIMailCursor2x",
	Buy = "UIBuyCursor2x",
	RepairNPC = "UIRepairNPCCursor2x",
	Taxi = "UITaxiCursor2x",
	Innkeeper = "UIInnkeeperCursor2x",
	Trainer = "UITrainerCursor2x",
	StableMaster = "UIStableMasterCursor2x",
	Repair = "UIRepairCursor2x", -- repair mode, set by the UI
}
-- The game sends CURSOR_CHANGED in the same frame as the
-- WORLD_CURSOR_TOOLTIP_UPDATE for the target that caused it (GetTime is the
-- same within a frame), so only a change in that frame belongs to the target.
-- Without that event the target is noticed from the tooltip a little later,
-- so a wider window is used, minus changes that belong to leaving the last one.
local SAME_FRAME = .001
local UI_HANDOVER = .1
local CHANGE_WINDOW = .25
local LEAVE_GRACE = .05
-- hover outline: rings of cursor silhouettes plus a soft circle, positions in
-- units of a 32 unit cursor; alphas fitted to the glow textures at the
-- default opacities (outline .75, glow .35)
local OUTLINE_RINGS = {{radius = 1.25, alpha = .26}, {radius = 2.5, alpha = .26}}
local OUTLINE_COPIES = 12
local SOFT_DIAMETER, SOFT_ALPHA = 64, .95

ns.defaults = {
	enabled = true,
	useClassColor = true,
	color = {1, .6, 0},
	glowOpacity = .35,
	outlineOpacity = .75,
	cursorSize = -1, -- -1 = game setting, otherwise an index of CURSOR_SIZES
	hideOnHover = true,
	outlineHover = true,
	outlineServices = false, -- vendors, bankers... (quest givers can't always be told apart)
	dimOutOfRange = true,
	outOfRangeStrength = .4,
	gloveWhileTurning = true,
	gloveTint = .6,
	gloveUseGlowColor = true,
	gloveColor = {1, 1, 1},
	turningIntensity = 1.4,
	shakeToFind = true,
	shakeCount = 5, -- direction changes in a row
	combatPulse = true,
	pulseUseGlowColor = true,
	pulseColor = {1, .1, .05},
	prediction = 1,
}
ns.CURSOR_SIZES = CURSOR_SIZES


-- LAYERS
-- The frame's top left is the cursor hotspot and its size the cursor size.
-- The base cursor is the classic Interface/Cursor/Point; its glow textures
-- are shaped to it and centred on it.
local cursor = CreateFrame("Frame", "CursorGlowForeverFrame", UIParent)
cursor:SetFrameStrata("TOOLTIP")
cursor:SetFrameLevel(10000)
cursor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT")
cursor:Hide()

-- soft round halo for shake to find and the combat pulse (no hole, unlike the
-- shaped glow, so it can grow)
cursor.halo = cursor:CreateTexture(nil, "BACKGROUND", nil, -1)
cursor.halo:SetTexture(TEXTURES.."soft")
cursor.halo:SetPoint("CENTER", cursor, "CENTER")
cursor.halo:SetAlpha(0)
cursor.glow = cursor:CreateTexture(nil, "BACKGROUND")
cursor.glow:SetTexture(TEXTURES.."point-glow")
cursor.outline = cursor:CreateTexture(nil, "BORDER")
cursor.outline:SetTexture(TEXTURES.."point-outline")
-- stands in for the game cursor while it is hidden (turning the camera)
cursor.glove = cursor:CreateTexture(nil, "ARTWORK")
cursor.glove:SetTexture(CURSORS.."Point")
cursor.glove:SetAllPoints(cursor)

-- hover outline: solid colour masked by the hover cursor's own art
cursor.hover = CreateFrame("Frame", nil, cursor)
cursor.hover:SetAllPoints(cursor)
cursor.hover.soft = cursor.hover:CreateTexture(nil, "BACKGROUND")
cursor.hover.soft:SetTexture(TEXTURES.."soft")
cursor.hover.copies = {}
for _, ring in ipairs(OUTLINE_RINGS) do
	for copy = 0, OUTLINE_COPIES - 1 do
		local texture = cursor.hover:CreateTexture(nil, "BORDER")
		local mask = cursor.hover:CreateMaskTexture()
		texture:AddMaskTexture(mask)
		texture.mask = mask
		texture.ring = ring
		texture.angle = 2 * math.pi * copy / OUTLINE_COPIES
		table.insert(cursor.hover.copies, texture)
	end
end
ns.cursor = cursor


-- mode: "base", "turning" (drawn glove, stronger glow) or a HOVER_SHEETS key
-- Cuts the hover outline from the art of the current hover cursor, its greyed
-- version while out of range: each mask is the whole sheet, placed so the
-- cursor's cell lines up with its texture.
function ns.refreshHoverArt(force)
	local mode = cursor.mode
	if not HOVER_SHEETS[mode] or not cursor.sizeIndex then return end
	local sheet = HOVER_SHEETS[mode]
	local cells = ns.hoverInRange == false and UNABLE_CELLS or SHEET_CELLS
	local left, top, cellSize = unpack(cells[cursor.sizeIndex])
	local art = sheet..left..":"..top..":"..cursor.size
	if art == cursor.hoverArt and not force then return end
	cursor.hoverArt = art
	local texel = cursor.size / cellSize
	for _, texture in ipairs(cursor.hover.copies) do
		texture.mask:SetTexture(CURSORS..sheet, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		texture.mask:SetSize(SHEET_WIDTH * texel, SHEET_HEIGHT * texel)
		texture.mask:ClearAllPoints()
		texture.mask:SetPoint("TOPLEFT", texture, "TOPLEFT", -left * texel, top * texel)
	end
end


local function setMode(mode)
	if cursor.mode == mode then return end
	cursor.mode = mode
	local base = mode == "base" or mode == "turning"
	cursor.glow:SetShown(base)
	cursor.outline:SetShown(base)
	cursor.glove:SetShown(mode == "turning")
	cursor.hover:SetShown(not base)
	ns.refreshHoverArt()
	ns.updateOpacity()
end


-- UI units per physical screen pixel
local function getPixelScale()
	local width
	if GetCVarBool("gxMaximize") and C_VideoOptions and C_VideoOptions.GetGameWindowSizes then
		local sizes = C_VideoOptions.GetGameWindowSizes(GetCVar("gxMonitor"), true)
		width = sizes and sizes[1] and sizes[1].x
	end
	width = width or GetPhysicalScreenSize()
	return WorldFrame:GetWidth() / width / UIParent:GetScale()
end


local function getCursorSizeIndex()
	local db = ns.db
	if CURSOR_SIZES[db.cursorSize] then return db.cursorSize end
	local preferred = tonumber(GetCVar("cursorSizePreferred")) or -1
	return CURSOR_SIZES[preferred] and preferred or 0
end


function ns.getColor()
	local db = ns.db
	if db.useClassColor then
		local color = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
		if color then return color.r, color.g, color.b end
	end
	return unpack(db.color)
end


-- the glow around the drawn glove is a little stronger
-- effect: brightness multiplier from shake to find and the combat pulse
function ns.updateOpacity(effect)
	local db = ns.db
	if not db then return end
	effect = effect or cursor.effectAlpha or 1
	cursor.effectAlpha = effect
	local intensity = (cursor.mode == "turning" and db.turningIntensity or 1) * effect
	cursor.glow:SetAlpha(math.min(db.glowOpacity * intensity, 1))
	cursor.outline:SetAlpha(math.min(db.outlineOpacity * intensity, 1))
	-- the hover outline follows the same opacity settings, and is weaker while
	-- the target is out of interaction range
	local range = db.dimOutOfRange and ns.hoverInRange == false and db.outOfRangeStrength or 1
	cursor.hover.soft:SetAlpha(math.min(SOFT_ALPHA * db.glowOpacity / .35 * effect, 1) * range)
	for _, texture in ipairs(cursor.hover.copies) do
		texture:SetAlpha(math.min(texture.ring.alpha * db.outlineOpacity / .75 * effect, 1) * range)
	end
end


-- The glow colour, moved toward the combat pulse colour by pulseTint (0 to 1).
-- The halo blends to the pulse colour by haloTint.
function ns.updateColor(pulseTint, haloTint)
	local db = ns.db
	if not db then return end
	pulseTint = pulseTint or cursor.pulseTint or 0
	haloTint = haloTint or cursor.haloTint or 0
	cursor.pulseTint, cursor.haloTint = pulseTint, haloTint
	local r, g, b = ns.getColor()
	local pr, pg, pb = r, g, b
	if not db.pulseUseGlowColor then pr, pg, pb = unpack(db.pulseColor) end
	local function mix(t) return r + (pr - r) * t, g + (pg - g) * t, b + (pb - b) * t end
	cursor.halo:SetVertexColor(mix(haloTint))
	r, g, b = mix(pulseTint)
	cursor.glow:SetVertexColor(r, g, b)
	cursor.outline:SetVertexColor(r, g, b)
	cursor.hover.soft:SetVertexColor(r, g, b)
	for _, texture in ipairs(cursor.hover.copies) do texture:SetColorTexture(r, g, b) end
end


-- halo: diameter in cursor sizes and alpha, from shake to find and the combat pulse
function ns.updateHalo(diameter, alpha)
	if not cursor.size then return end
	cursor.haloDiameter, cursor.haloAlpha = diameter, alpha
	cursor.halo:SetSize(cursor.size * diameter, cursor.size * diameter)
	cursor.halo:SetAlpha(alpha)
end


function ns.updateLayout()
	local db = ns.db
	local sizeIndex = getCursorSizeIndex()
	local size = CURSOR_SIZES[sizeIndex] * getPixelScale()
	local unit = size / 32
	local r, g, b = ns.getColor()
	cursor:SetSize(size, size)
	cursor.sizeIndex, cursor.size = sizeIndex, size

	-- the outline texture covers twice the cursor; the glow reaches further and
	-- covers four times it, so it fades out before its edges
	cursor.outline:SetSize(size * 2, size * 2)
	cursor.glow:SetSize(size * 4, size * 4)
	ns.updateHalo(cursor.haloDiameter or 3, cursor.haloAlpha or 0)
	for _, texture in ipairs({cursor.glow, cursor.outline}) do
		texture:ClearAllPoints()
		texture:SetPoint("CENTER", cursor, "CENTER")
	end

	cursor.hover.soft:SetSize(SOFT_DIAMETER * unit, SOFT_DIAMETER * unit)
	cursor.hover.soft:SetPoint("CENTER", cursor, "CENTER")
	for _, texture in ipairs(cursor.hover.copies) do
		texture:SetSize(size, size)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", cursor, "TOPLEFT",
			math.cos(texture.angle) * texture.ring.radius * unit, -math.sin(texture.angle) * texture.ring.radius * unit)
	end

	-- a tinge of the glow colour, or of the glove's own colour
	local tint = db.gloveTint
	local gr, gg, gb = r, g, b
	if not db.gloveUseGlowColor then gr, gg, gb = unpack(db.gloveColor) end
	cursor.glove:SetVertexColor(1 - (1 - gr) * tint, 1 - (1 - gg) * tint, 1 - (1 - gb) * tint)
	ns.updateColor()
	ns.refreshHoverArt(true)
	ns.updateOpacity()
end


-- HOVER CURSOR
-- The game does not report which cursor it shows, so it is worked out from
-- what is under the mouse; answers are HOVER_SHEETS keys. Only confident answers count; anything else gets
-- no outline rather than a wrong one. NPC titles are matched in English.
local NPC_TITLES = {
	{"Stable Master", "StableMaster"},
	{"Flight Master", "Taxi"},
	{"Gryphon Master", "Taxi"},
	{"Hippogryph Master", "Taxi"},
	{"Wind Rider Master", "Taxi"},
	{"Bat Handler", "Taxi"},
	{"Innkeeper", "Innkeeper"},
	{"Trainer", "Trainer"},
	{"Repair", "RepairNPC"},
	{"Armorer", "RepairNPC"},
	{"Armorsmith", "RepairNPC"},
	{"Weaponsmith", "RepairNPC"},
	{"Blacksmith", "RepairNPC"},
	{"Vendor", "Buy"},
	{"Merchant", "Buy"},
	{"Supplies", "Buy"},
	{"Goods", "Buy"},
	{"Quartermaster", "Buy"},
	{"Provisioner", "Buy"},
	{"Food", "Buy"},
	{"Drink", "Buy"},
	{"Reagent", "Buy"},
	{"Bowyer", "Buy"},
	{"Gunsmith", "Buy"},
	{"Poison", "Buy"},
	{"Baker", "Buy"},
	{"Butcher", "Buy"},
	{"Tabard", "Buy"},
	{"Bank", "Buy"}, -- Banker, Guild Banker: bankers show the bag too
}
-- class trainers (titles, for NPCs not in NPC_SERVICES): only their class gets
-- the trainer cursor, others the speech bubble
local TRAINER_TITLE_CLASSES = {
	["Warrior Trainer"] = "WARRIOR", ["Paladin Trainer"] = "PALADIN", ["Hunter Trainer"] = "HUNTER",
	["Rogue Trainer"] = "ROGUE", ["Priest Trainer"] = "PRIEST", ["Shaman Trainer"] = "SHAMAN",
	["Mage Trainer"] = "MAGE", ["Warlock Trainer"] = "WARLOCK", ["Druid Trainer"] = "DRUID",
	["Pet Trainer"] = "HUNTER", ["Portal Trainer"] = "MAGE",
}
-- world objects recognised by name (tooltip first line)
local OBJECT_NAMES = {
	{"Mailbox", "Mail"},
}
-- NPC service cursors: always recognised (they tell a switch between two hover
-- cursors from one back to the base cursor), only outlined with the option
local SERVICE_LOOKS = {Buy = true, RepairNPC = true, Taxi = true, Innkeeper = true, Trainer = true, StableMaster = true}
-- service objects, outlined with the NPC services
local SERVICE_OBJECT_NAMES = {
	{"Guild Vault", "Buy"},
	{"Guild Bank", "Buy"},
}
local gatherTexts


local function getSpellName(spellID, fallback)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	if not name and GetSpellInfo then name = GetSpellInfo(spellID) end
	return name or fallback
end


-- tooltip texts naming a gathering cursor, on nodes and on corpses
local function getGatherTexts()
	if gatherTexts then return gatherTexts end
	gatherTexts = {}
	local function add(cursorFile, ...)
		for i = 1, select("#", ...) do
			local text = select(i, ...)
			if type(text) == "string" and text ~= "" then table.insert(gatherTexts, {text, cursorFile}) end
		end
	end
	add("Mine", UNIT_SKINNABLE_ROCK, getSpellName(2575, "Mining"))
	add("GatherHerbs", UNIT_SKINNABLE_HERB, getSpellName(2366, "Herbalism"))
	add("Skin", UNIT_SKINNABLE_LEATHER, getSpellName(8613, "Skinning"))
	return gatherTexts
end


-- GATHERING PROFESSIONS
-- Ore and herbs show their (greyed) cursor without the profession too, but a
-- skinnable corpse keeps the base cursor without Skinning, so the skinning
-- outline needs the profession. Known from the profession list
-- (GetProfessions), the classic skill list (GetSkillLineInfo) or the
-- profession's spells (any rank), cached until the skills change.
local GATHERING = {
	Skin = {skillLine = 393, spells = {8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216, 158756}},
}
local knownGathering


local function isSpellKnown(spellID)
	if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
	return IsSpellKnown and IsSpellKnown(spellID) or false
end


-- nil when the client offers no way to read professions at all
local function readGathering()
	if not (GetProfessions or GetSkillLineInfo or IsPlayerSpell or IsSpellKnown) then return nil end
	local known = {}
	local names = {}
	for look, profession in pairs(GATHERING) do
		names[getSpellName(profession.spells[1], "")] = look
		for _, spellID in ipairs(profession.spells) do
			if isSpellKnown(spellID) then known[look] = true end
		end
	end
	if GetProfessions and GetProfessionInfo then
		for _, index in pairs({GetProfessions()}) do
			local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
			for look, profession in pairs(GATHERING) do
				if skillLine == profession.skillLine then known[look] = true end
			end
			if names[name] then known[names[name]] = true end
		end
	end
	if GetNumSkillLines and GetSkillLineInfo then
		for i = 1, GetNumSkillLines() do
			local name, isHeader = GetSkillLineInfo(i)
			if not isHeader and names[name] then known[names[name]] = true end
		end
	end
	return known
end


function ns.hasGatheringProfession(look)
	if not knownGathering then
		local ok, known = pcall(readGathering)
		-- unreadable: assume the profession rather than hide a real cursor
		if not ok or not known then return true end
		knownGathering = known
	end
	return knownGathering[look] or false
end


function ns.resetGatheringProfessions()
	knownGathering = nil
end


local function getLineText(i)
	local line = _G["GameTooltipTextLeft"..i]
	local text = line and line:GetText()
	if text and not (issecretvalue and issecretvalue(text)) then return text end
end


local function findText(first, last, matches)
	for i = first, last or GameTooltip:NumLines() do
		local text = getLineText(i)
		if text then
			for _, match in ipairs(matches) do
				if text:find(match[1], 1, true) then return match[2] end
			end
		end
	end
end


-- The answer only picks the outline shape: whether the cursor has a hover look
-- at all is left to the cursor events, since recognising a target proves
-- nothing (no gathering cursor without the profession, and in the log an
-- attackable enemy did not change the cursor). The "unable" versions have the
-- same shape. Tooltip text is only read while the tooltip is up.
-- NPC ID from a unit's GUID (Creature-0-server-instance-zone-npcID-spawn);
-- the GUID can be secret, hence the pcall
local function getNPCID(unit)
	local ok, npcID = pcall(function()
		local guid = UnitGUID(unit)
		if not guid then return end
		local kind, _, _, _, _, id = strsplit("-", guid)
		if kind == "Creature" or kind == "Vehicle" then return id end
	end)
	return ok and npcID or nil
end


-- A quest giver shows the quest cursor over its service one (the vendor bag,
-- the repair anvil...), and the game does not tell addons which NPCs have
-- quests. What talking to an NPC showed (per character) comes first; else the
-- built-in list of service NPCs with quests (QuestGivers.lua) counts.
local function isKnownQuestGiver(unit)
	local npcID = getNPCID(unit)
	if not npcID then return false end
	local learned = ns.charDB and ns.charDB.questGivers[npcID]
	if learned ~= nil then return learned end
	return ns.QUEST_GIVER_NPCS and ns.QUEST_GIVER_NPCS[tonumber(npcID)] or false
end


-- the skinning cursor only with the profession
local function findGathering(first)
	local look = findText(first, nil, getGatherTexts())
	if look and GATHERING[look] and not ns.hasGatheringProfession(look) then return nil end
	return look
end


-- A class trainer (a pet trainer: hunters) shows the trainer cursor only to
-- its class. Returns whether this NPC is one for another class, and the cursor
-- it shows other classes instead, if any.
local function isOtherClassTrainer(npcID, tooltipShown)
	local playerClass = select(2, UnitClass("player"))
	local trainer = npcID and ns.TRAINER_CLASSES and ns.TRAINER_CLASSES[npcID]
	if trainer then return trainer[1] ~= playerClass, trainer[2] end
	local class = tooltipShown and TRAINER_TITLE_CLASSES[getLineText(2) or ""]
	return class and class ~= playerClass or false
end


local function getHoverCursor()
	local tooltipShown = GameTooltip:IsShown()
	if UnitExists("mouseover") then
		if UnitIsDead("mouseover") then
			if CanLootUnit then
				local ok, hasLoot = pcall(CanLootUnit, UnitGUID("mouseover"))
				-- shift held (loot one item at a time) swaps the pair of bags for one
				if ok and hasLoot then return IsShiftKeyDown() and "Pickup" or "LootAll" end
			end
			return tooltipShown and findGathering(2) or nil
		end
		if UnitCanAttack("player", "mouseover") then return "Attack" end
		if not UnitPlayerControlled("mouseover") and not isKnownQuestGiver("mouseover") then
			-- the NPC's services from the built-in data, else its title
			local npcID = tonumber(getNPCID("mouseover") or "")
			local otherClass, otherCursor = isOtherClassTrainer(npcID, tooltipShown)
			if otherClass then return otherCursor end
			local service = npcID and ns.NPC_SERVICES and ns.NPC_SERVICES[npcID]
			if service then return service end
			return tooltipShown and findText(2, 2, NPC_TITLES) or nil
		end
		return
	end
	if not tooltipShown then return end
	local name = getLineText(1)
	if name == MINIMAP_TRACKING_MAILBOX then return "Mail" end
	return findText(1, 1, OBJECT_NAMES) or findText(1, 1, SERVICE_OBJECT_NAMES) or findGathering(1)
end


-- HOVER DETECTION
-- The game has no API that reports its cursor image, so two game events are
-- used instead:
--  * WORLD_CURSOR_TOOLTIP_UPDATE fires the moment the mouse reaches or leaves
--    something in the world (object or unit); anchor type 0 means it left.
--  * CURSOR_CHANGED fires whenever the cursor image changes.
-- Leaving to open ground brings the base cursor back. Reaching a target
-- flips the cursor look if the image changed at that moment and keeps it
-- otherwise: a mailbox changes the base cursor, a First Aid Kit does not,
-- and going from one NPC straight to another keeps the speech bubble.
local state = {
	cursorChanged = false,
	worldEvent = false, -- WORLD_CURSOR_TOOLTIP_UPDATE is available
	worldTarget = false, -- set by WORLD_CURSOR_TOOLTIP_UPDATE
	wasOnTarget = false,
	targetTime = -1, -- when the current target was reached
	changedBefore = false, -- the cursor look before reaching it
	leaveTime = -1,
	leaveEventTime = -1, -- last WORLD_CURSOR_TOOLTIP_UPDATE leave
	changedAtLeave = false, -- the hover look at that leave
	changeTimes = {}, -- recent CURSOR_CHANGED times
	staleTooltip = false, -- fallback: the shown tooltip belongs to a target already left
	looking = false,
	turning = false,
	pressed = {},
	wasHidden = false,
	hiddenTime = 0, -- when the cursor was hidden for turning the camera
	changedWhenHidden = false, -- the hover look at that moment
	hoverCursor = nil, -- cursor file of the current hover look, if known
	hoverCheckTime = 0,
	tooltipChanged = false,
	uiCursor = nil, -- cursor set by the UI: {look = HOVER_SHEETS key or false, focus = frame}
	lookByName = {}, -- per target name: whether it has its own cursor (this session)
	lastX = 0,
	lastY = 0,
	lastMoveTime = 0,
	lastFrameTime = 0,
}


local function debug(...)
	if ns.debug then print(("|cff66ccffCursor Glow Forever|r %.3f"):format(GetTime()), ...) end
end
ns.debugPrint = debug


-- fallback when WORLD_CURSOR_TOOLTIP_UPDATE is missing: world objects show a
-- UIParent-owned tooltip (its owner can be secret, hence the pcall)
local function isWorldTooltipShown()
	local ok, shown = pcall(function()
		return GameTooltip:IsShown() and GameTooltip:GetOwner() == UIParent and GameTooltip:GetAlpha() >= 1
	end)
	return ok and shown or false
end


-- Over UI frames (unit frames, bars, nameplates that take the mouse) the game
-- keeps the base cursor unless the UI sets one. Nameplates are not measured:
-- many are restricted, and measuring those taints. Crossing between a
-- nameplate and its unit is read from the cursor changes instead.
local function isOverWorld()
	local focus
	if GetMouseFoci then
		focus = GetMouseFoci()[1]
	elseif GetMouseFocus then
		focus = GetMouseFocus()
	end
	return focus == nil or focus == WorldFrame
end


-- the unit's name, or the object's from its tooltip (names can be secret)
local function getTargetName()
	if UnitExists("mouseover") then
		local ok, name = pcall(function()
			local unitName = UnitName("mouseover")
			if issecretvalue and issecretvalue(unitName) then return nil end
			return unitName
		end)
		return ok and name or nil
	end
	return getLineText(1)
end


local function isOnTarget()
	if UnitExists("mouseover") then return true end
	if state.worldEvent then return state.worldTarget end
	return not state.staleTooltip and isWorldTooltipShown()
end


-- A target can be reported more than once (world event, mouseover unit);
-- reaching it again without a cursor change keeps its look, so repeats are
-- harmless. Without WORLD_CURSOR_TOOLTIP_UPDATE the signals are spread over a
-- few frames, so only the first one counts there.
local function reachTarget(signal)
	local now = GetTime()
	if not state.worldEvent and not state.leftSinceReach and now - state.targetTime <= CHANGE_WINDOW then return end
	state.leftSinceReach = false
	state.lookSettled = false
	state.arriving = true
	-- Moving straight from one target to the next, the game sends the leave
	-- and the reach in the same frame: the look carries over from the target
	-- just left (two chairs keep the cog, no cursor change comes).
	if now - state.leaveEventTime < SAME_FRAME then
		state.changedBefore = state.changedAtLeave
	else
		state.changedBefore = state.cursorChanged
	end
	state.targetTime = now
	state.hoverCursor = nil -- a new target may show another cursor
	-- Interaction range: the game shows the "unable" version of the cursor out
	-- of range. For units the starting state comes from CheckInteractDistance;
	-- after that every cursor change on the same target is the game swapping
	-- between the two versions (see state.pendingChange). Objects give no
	-- starting state, so they are never dimmed.
	ns.hoverInRange = nil
	if UnitExists("mouseover") and CheckInteractDistance then
		local ok, inRange = pcall(function() return CheckInteractDistance("mouseover", 3) and true or false end)
		if ok then ns.hoverInRange = inRange end
	end
	ns.refreshHoverArt()
	ns.updateOpacity()
	state.reportedUnknown = false
	debug("reached target via", signal, "- hover look before:", state.changedBefore)
end


local function leaveTarget()
	state.leaveTime = GetTime()
	state.leftSinceReach = true
	state.cursorChanged = false
	debug("left target")
end


local function cursorChangedNear(time)
	for _, changeTime in ipairs(state.changeTimes) do
		-- coming back from a UI frame (a nameplate onto its unit) sends no target
		-- signal, so allow the cursor change a frame either side of the handover
		if time == state.uiLeaveTime then
			if math.abs(changeTime - time) <= UI_HANDOVER then return true end
		elseif state.worldEvent then
			-- the target's own change comes in the same frame; one shortly after
			-- also belongs to it (crossing from a unit's nameplate onto the unit
			-- right away), while one before it belongs to what was left
			local after = changeTime - time
			if after > -SAME_FRAME and after <= UI_HANDOVER then return true end
		elseif changeTime > state.leaveTime + LEAVE_GRACE and math.abs(changeTime - time) <= CHANGE_WINDOW then
			return true
		end
	end
	return false
end


-- the player or the mouseover unit is moving (unit speeds can be secret)
local function isDistanceChanging()
	if not GetUnitSpeed then return false end
	local ok, moving = pcall(function()
		if (GetUnitSpeed("player") or 0) > 0 then return true end
		return UnitExists("mouseover") and (GetUnitSpeed("mouseover") or 0) > 0
	end)
	return ok and moving or false
end


-- The game's distance checks for the mouseover unit: 3 is duel range (about
-- 10 yards), 4 follow range (about 28). NPCs can be interacted with further
-- than duel range, so only beyond follow range is the target "too far" for its
-- cursor. True when it can't be told, so a change is then read as a range swap.
local function checkDistance(index)
	if not (UnitExists("mouseover") and CheckInteractDistance) then return nil end
	local ok, within = pcall(function() return CheckInteractDistance("mouseover", index) and true or false end)
	if ok then return within end
end


local function isNearEnoughForCursor()
	local within = checkDistance(4)
	return within == nil or within
end


-- true while the game cursor is hidden for turning the camera. With a camera
-- button held, only the press rule counts: the mouselook state is already set
-- on the press, while the game still shows its cursor until the mouse moves
-- (right-clicking an NPC keeps the NPC's cursor).
local function isCursorHidden()
	-- A button released outside the game window (alt-tab) never reaches the
	-- Stop hooks or the STOPPED events, so drop what the buttons no longer back.
	if IsMouseButtonDown then
		local left, right = IsMouseButtonDown("LeftButton"), IsMouseButtonDown("RightButton")
		if not left then state.pressed.camera = nil end
		if not right then state.pressed.turn = nil end
		if not left and not right and not IsMouselooking() then
			state.pressed.steer, state.looking, state.turning = nil, false, false
		end
	end
	if next(state.pressed) then return state.isPressHidden() end
	return state.looking or state.turning or IsMouselooking()
end


local function updateCursorChanged()
	local onTarget = isOnTarget()
	if not onTarget then
		if state.wasOnTarget then leaveTarget() end
		state.cursorChanged = false
	elseif not state.wasOnTarget and not state.worldEvent then
		reachTarget("tooltip")
	end
	state.wasOnTarget = onTarget

	-- (a look change on the same target has already settled it)
	local inWindow = GetTime() - state.targetTime <= CHANGE_WINDOW
	if onTarget and not state.lookSettled and inWindow then
		local cursorChanged = cursorChangedNear(state.targetTime)
		local changed = state.changedBefore ~= cursorChanged
		-- Straight from one hover target to another with a cursor change is
		-- either back to the base cursor or on to another hover cursor (sword to
		-- vendor bag, innkeeper to chair); a recognised target, or what was
		-- learned about it, settles it. The tooltip can arrive a few frames
		-- late, hence the whole window.
		if state.changedBefore and cursorChanged
			and (state.hoverCursor or state.lookByName[getTargetName() or ""]) then
			changed = true
		end
		if changed ~= state.cursorChanged then
			state.cursorChanged = changed
			debug("hover look", changed and "on" or "off")
		end
	elseif state.arriving and not inWindow then
		-- Reached from the base cursor the answer is certain: learn whether this
		-- target has its own cursor, for later direct switches onto it.
		state.arriving = false
		local name = onTarget and not state.lookSettled and not state.changedBefore and getTargetName()
		if name then state.lookByName[name] = state.cursorChanged end
	end
end


-- EFFECTS
-- Shake to find: quick side to side swings of the mouse (the shakeCount
-- setting's direction changes in a row, each after a swing over a few percent
-- of the screen and soon after the last) brighten the glow and send a halo out
-- around the cursor, easing back over a second. Combat pulse: while in combat
-- the glow and a faint halo slowly pulse brighter, tinted with the pulse
-- colour. The shaped glow keeps its size (scaling it would widen its
-- cursor-shaped middle).
local SHAKE_GAP, SHAKE_SWING = .35, .03 -- most seconds between direction changes; swing: fraction of screen height
local FIND_TIME, FIND_BRIGHTNESS = 1, 1 -- extra brightness at the start
local FIND_HALO_FROM, FIND_HALO_TO, FIND_HALO_ALPHA = 4, 10, 1 -- halo diameter (cursor sizes) and alpha
local PULSE_PERIOD, PULSE_BRIGHTNESS, PULSE_HALO, PULSE_HALO_ALPHA = 1.2, .6, 5, .55
local PULSE_TINT = .7 -- how far the glow moves to the pulse colour at the peak
local shake = {direction = 0, swing = 0, count = 0, lastReversal = -10, lastX = nil, findTime = -10}


local function detectShake(x, now)
	if shake.lastX == nil then shake.lastX = x return end
	local dx = x - shake.lastX
	shake.lastX = x
	if dx == 0 then return end
	local direction = dx > 0 and 1 or -1
	if direction == shake.direction then
		shake.swing = shake.swing + math.abs(dx)
		return
	end
	local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	-- a direction change after a long enough swing counts, and a pause between
	-- them starts the count over
	if shake.direction ~= 0 and shake.swing >= screenHeight * SHAKE_SWING then
		if now - shake.lastReversal > SHAKE_GAP then shake.count = 0 end
		shake.count, shake.lastReversal = shake.count + 1, now
	end
	shake.direction, shake.swing = direction, math.abs(dx)
	if shake.count >= ns.db.shakeCount and now - shake.findTime > FIND_TIME then
		shake.findTime, shake.count = now, 0
		ns.debugPrint("shake to find")
	end
end


function ns.updateEffects(x)
	local db = ns.db
	local now = GetTime()
	local brightness, haloDiameter, haloAlpha = 1, FIND_HALO_FROM, 0
	local pulseTint, pulseAlpha = 0, 0
	if db.combatPulse and (InCombatLockdown() or UnitAffectingCombat("player")) then
		local wave = .5 + .5 * math.sin(now * 2 * math.pi / PULSE_PERIOD)
		brightness = 1 + PULSE_BRIGHTNESS * wave
		pulseTint, pulseAlpha = PULSE_TINT * wave, PULSE_HALO_ALPHA * wave
		haloDiameter, haloAlpha = PULSE_HALO, pulseAlpha
	end
	if db.shakeToFind then
		detectShake(x, now)
		local t = (now - shake.findTime) / FIND_TIME
		if t < 1 then
			-- the halo spreads out while it fades
			local fade = (1 - t) ^ 1.5
			brightness = brightness + FIND_BRIGHTNESS * fade
			haloDiameter = FIND_HALO_FROM + (FIND_HALO_TO - FIND_HALO_FROM) * math.sqrt(t)
			haloAlpha = math.max(haloAlpha, FIND_HALO_ALPHA * fade)
		end
	end
	-- the halo takes the pulse colour as far as the pulse makes it
	local haloTint = haloAlpha > 0 and pulseAlpha / haloAlpha or 0
	if db.pulseUseGlowColor then pulseTint, haloTint = 0, 0 end
	if pulseTint ~= cursor.pulseTint or haloTint ~= cursor.haloTint then ns.updateColor(pulseTint, haloTint) end
	if haloDiameter ~= cursor.haloDiameter or haloAlpha ~= cursor.haloAlpha then
		ns.updateHalo(haloDiameter, haloAlpha)
	end
	if brightness ~= cursor.effectAlpha then ns.updateOpacity(brightness) end
end


-- EVERY FRAME
-- Anything drawn in game trails the game cursor by about a frame, so the
-- cursor frame is placed where the cursor is heading: its position plus its
-- movement over the last frame, scaled by the prediction option.
local driver = CreateFrame("Frame")
driver:Hide() -- until the saved settings are loaded
driver:SetScript("OnUpdate", function()
	local db = ns.db
	local now = GetTime()
	local x, y = GetCursorPosition()
	local dx, dy = x - state.lastX, y - state.lastY
	if dx ~= 0 or dy ~= 0 then state.lastMoveTime = now end
	if isDistanceChanging() then state.lastWalkTime = now end
	-- No prediction after a pause (the game in the background, a loading
	-- screen) or across a jump no mouse makes in one frame (the cursor coming
	-- back in from outside the window): it would throw the glow off the cursor.
	local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	if now - state.lastFrameTime > .1 or math.sqrt(dx * dx + dy * dy) > screenHeight * .1 then
		dx, dy = 0, 0
	end
	state.lastX, state.lastY, state.lastFrameTime = x, y, now

	local hidden = isCursorHidden()
	local show, mode = true, "base"
	local uiLook = ns.getUICursor()
	if hidden and not state.wasHidden then
		state.hiddenTime, state.changedWhenHidden = GetTime(), state.cursorChanged
	end
	if hidden then
		mode = db.gloveWhileTurning and "turning" or "base"
	elseif GetCursorInfo() then
		show = false
	elseif uiLook ~= nil and db.hideOnHover then
		-- the UI has set the cursor (selling from the bags, repair mode...)
		if uiLook and db.outlineHover then
			mode = uiLook
		else
			show = false
		end
	elseif db.hideOnHover and not isOverWorld() then
		if not state.overUI then state.uiEnterTime = GetTime() end
		state.cursorChanged, state.hoverCursor, state.overUI = false, nil, true
	elseif db.hideOnHover then
		if state.overUI then
			-- back onto the world from a UI frame: judge what is under the
			-- mouse afresh; a cursor change in this frame belongs to it
			state.overUI = false
			state.cursorChanged, state.changedBefore, state.targetTime = false, false, GetTime()
			state.uiLeaveTime = state.targetTime
			state.hoverCheckTime, state.lookSettled = 0, false
		end
		if state.wasHidden then
			-- The cursor reappears after turning the camera. Still on the same
			-- target it has the look it had before; otherwise judge it afresh.
			-- Either way identify the target straight away.
			local sameTarget = state.targetTime < state.hiddenTime and isOnTarget()
			local changed = sameTarget and state.changedWhenHidden
			state.cursorChanged, state.changedBefore, state.targetTime = changed, changed, GetTime()
			state.hoverCheckTime, state.lookSettled = 0, false
		end
		updateCursorChanged()

		-- Identify the target to pick the outline shape. The tooltip can lag
		-- behind the target, so check again whenever it changes and every tenth
		-- of a second.
		local now = GetTime()
		if not state.wasOnTarget then
			state.hoverCursor = nil
		elseif state.tooltipChanged or now - state.hoverCheckTime > .1 then
			state.tooltipChanged, state.hoverCheckTime = false, now
			local ok, hoverCursor = pcall(getHoverCursor)
			hoverCursor = ok and hoverCursor or nil
			if hoverCursor ~= state.hoverCursor or ns.debug and not hoverCursor and not state.reportedUnknown then
				state.reportedUnknown = not hoverCursor
				-- the tooltip lines show which title or text was not recognised
				debug("hover cursor", hoverCursor or "unknown", "| cursor changed:", state.cursorChanged,
					"| tooltip:", tostring((getLineText(1))), "/", tostring((getLineText(2))))
			end
			state.hoverCursor = hoverCursor
		end

		if state.cursorChanged then
			if state.hoverCursor and db.outlineHover and (db.outlineServices or not SERVICE_LOOKS[state.hoverCursor]) then
				mode = state.hoverCursor
			else
				show = false
			end
		end
	else
		state.cursorChanged, state.hoverCursor = false, nil
	end
	state.wasHidden = hidden

	-- a cursor change on the same target (no reach or leave in its frame) is the
	-- game swapping between the normal and "unable" versions: range changed
	-- A cursor change on the same target (no reach or leave in its frame) is
	-- either the game swapping between the normal and "unable" versions (range)
	-- or the look changing on the same unit: its nameplate keeps the base
	-- cursor, the unit itself shows its own. With a modifier key pressed or
	-- released it is a look change (shift over a corpse). While the player or
	-- the target moves, the distance is changing: a range change, even with
	-- the mouse following the target. Standing still, a moving mouse means a
	-- look change (crossing a nameplate), as does any change on an enemy.
	-- Range changes are decided a little later, so a nameplate handover
	-- noticed a frame late is not taken for one.
	local change = state.pendingChange
	if change then
		local now = GetTime()
		local sameTarget = state.wasOnTarget and not hidden and not state.overUI
			and math.abs(change.time - (state.uiEnterTime or -1)) > UI_HANDOVER
			and math.abs(change.time - (state.uiLeaveTime or -1)) > UI_HANDOVER
			-- a change around reaching the target belongs to the arrival (its
			-- signals can be spread over a couple of frames)
			and math.abs(change.time - state.targetTime) > UI_HANDOVER
			and math.abs(change.time - state.leaveEventTime) >= SAME_FRAME
		if not sameTarget then
			if now - change.time > UI_HANDOVER then state.pendingChange = nil end
		elseif change.modifier and (state.hoverCursor == "LootAll" or state.hoverCursor == "Pickup") then
			-- shift over a corpse swaps between two loot cursors: identify it again
			state.pendingChange, state.lookSettled, state.hoverCheckTime = nil, true, 0
			state.cursorChanged = true
			debug("loot cursor swapped by", "modifier key")
		elseif change.modifier or not change.walking and (change.moving or state.hoverCursor == "Attack") then
			state.pendingChange = nil
			state.cursorChanged, state.lookSettled, state.hoverCheckTime = not state.cursorChanged, true, 0
			debug("hover look", state.cursorChanged and "on" or "off", "(same target)")
		elseif now - change.time > UI_HANDOVER then
			-- With the mouse still, the change comes from the distance to the
			-- target: far away it shows the base cursor, closer its greyed
			-- "unable" cursor, in range the normal one.
			state.pendingChange = nil
			debug("cursor change on the same target | distance changing:", tostring(change.walking),
				"| within duel range:", tostring(checkDistance(3)), "| within follow range:", tostring(checkDistance(4)))
			if not state.cursorChanged then
				-- walked close enough for the target's cursor to appear
				state.cursorChanged, state.lookSettled, state.hoverCheckTime = true, true, 0
				if ns.hoverInRange ~= nil then ns.hoverInRange = false end
				debug("hover look on (came into view range)")
			elseif ns.hoverInRange == false and not isNearEnoughForCursor() then
				-- from the greyed cursor further away: back to the base cursor
				state.cursorChanged, state.lookSettled = false, true
				debug("hover look off (too far away)")
			elseif ns.hoverInRange ~= nil then
				ns.hoverInRange = not ns.hoverInRange
				debug("interaction range", ns.hoverInRange and "in" or "out")
			end
			ns.refreshHoverArt()
			ns.updateOpacity()
		end
	end

	setMode(mode)
	cursor:SetShown(show)
	ns.updateEffects(x)
	if show then
		local lead = hidden and 0 or db.prediction
		local scale = UIParent:GetEffectiveScale()
		cursor:ClearAllPoints()
		cursor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x + dx * lead) / scale, (y + dy * lead) / scale)
	end
end)


function ns.setEnabled(enabled)
	driver:SetShown(enabled)
	if not enabled then cursor:Hide() end
end


-- EVENTS
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")


function events:ADDON_LOADED(name)
	if name ~= addonName then return end
	self:UnregisterEvent("ADDON_LOADED")
	CursorGlowForeverDB = CursorGlowForeverDB or {}
	-- version 2: the glove tint default went from .3 to .6
	if not CursorGlowForeverDB.version and CursorGlowForeverDB.gloveTint == .3 then
		CursorGlowForeverDB.gloveTint = nil
	end
	CursorGlowForeverDB.version = 2
	for key, value in pairs(ns.defaults) do
		if CursorGlowForeverDB[key] == nil then
			CursorGlowForeverDB[key] = type(value) == "table" and CopyTable(value) or value
		end
	end
	ns.db = CursorGlowForeverDB
	CursorGlowForeverCharDB = CursorGlowForeverCharDB or {}
	CursorGlowForeverCharDB.questGivers = CursorGlowForeverCharDB.questGivers or {}
	ns.charDB = CursorGlowForeverCharDB
	state.lastX, state.lastY = GetCursorPosition()
	ns.setEnabled(ns.db.enabled)
end


function events:PLAYER_LOGIN()
	ns.updateLayout()
	for _, event in ipairs({"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE", "CURSOR_CHANGED",
		"UPDATE_MOUSEOVER_UNIT", "PLAYER_STARTED_LOOKING", "PLAYER_STOPPED_LOOKING", "PLAYER_STARTED_TURNING",
		"PLAYER_STOPPED_TURNING"}) do
		self:RegisterEvent(event)
	end
	-- registering an event the client does not have raises an error
	state.worldEvent = pcall(self.RegisterEvent, self, "WORLD_CURSOR_TOOLTIP_UPDATE")
	ns.worldEvent = state.worldEvent
	for _, event in ipairs({"GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
		"SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED", "MODIFIER_STATE_CHANGED"}) do
		pcall(self.RegisterEvent, self, event)
	end
end


-- a modifier key can change the cursor on the same target (see state.pendingChange)
function events:MODIFIER_STATE_CHANGED(key, down)
	state.modifierTime = GetTime()
	-- the cursor change may arrive just before the modifier event
	if state.pendingChange and state.modifierTime - state.pendingChange.time < UI_HANDOVER then
		state.pendingChange.modifier = true
	end
	debug("MODIFIER_STATE_CHANGED", key, down)
end


-- professions learned or unlearned
function events:SKILL_LINES_CHANGED() ns.resetGatheringProfessions() end
events.LEARNED_SPELL_IN_TAB = events.SKILL_LINES_CHANGED
events.SPELLS_CHANGED = events.SKILL_LINES_CHANGED


-- QUEST GIVERS (see isKnownQuestGiver)
local function setQuestGiver(hasQuests)
	local npcID = getNPCID("npc")
	if not npcID or not ns.charDB then return end
	-- kept for both answers: "no quests" overrides the built-in list
	local questGivers = ns.charDB.questGivers
	hasQuests = hasQuests and true or false
	if questGivers[npcID] ~= hasQuests then
		questGivers[npcID] = hasQuests
		debug("NPC", npcID, hasQuests and "has quests" or "has no quests")
	end
end


local function countList(getter)
	if not getter then return 0 end
	local ok, list = pcall(getter)
	return ok and type(list) == "table" and #list or 0
end


local function countNumber(getter)
	if not getter then return 0 end
	local ok, count = pcall(getter)
	return ok and tonumber(count) or 0
end


-- the gossip window lists the NPC's quests next to its other options
function events:GOSSIP_SHOW()
	local gossip = C_GossipInfo or {}
	local quests = countList(gossip.GetAvailableQuests) + countList(gossip.GetActiveQuests)
	if not gossip.GetAvailableQuests then
		quests = countNumber(GetNumGossipAvailableQuests) + countNumber(GetNumGossipActiveQuests)
	end
	setQuestGiver(quests > 0)
end


-- quest-only NPCs open these instead
function events:QUEST_GREETING()
	setQuestGiver(countNumber(GetNumAvailableQuests) + countNumber(GetNumActiveQuests) > 0)
end
function events:QUEST_DETAIL() setQuestGiver(true) end
events.QUEST_PROGRESS = events.QUEST_DETAIL
events.QUEST_COMPLETE = events.QUEST_DETAIL


function events:UI_SCALE_CHANGED() ns.updateLayout() end
events.DISPLAY_SIZE_CHANGED = events.UI_SCALE_CHANGED
events.CVAR_UPDATE = events.UI_SCALE_CHANGED
function events:PLAYER_STARTED_LOOKING() state.looking = true end
function events:PLAYER_STOPPED_LOOKING() state.looking = false end
function events:PLAYER_STARTED_TURNING() state.turning = true end
function events:PLAYER_STOPPED_TURNING() state.turning = false end


function events:CURSOR_CHANGED(isDefault, newCursorType)
	if newCursorType and newCursorType ~= 0 then return end -- carrying something
	local now = GetTime()
	table.insert(state.changeTimes, now)
	if #state.changeTimes > 8 then table.remove(state.changeTimes, 1) end
	debug("CURSOR_CHANGED")
	-- decided at the end of the frame, once any target signals of this frame are in
	state.pendingChange = {time = now, moving = now - state.lastMoveTime < .1,
		modifier = now - (state.modifierTime or -1) < UI_HANDOVER,
		walking = now - (state.lastWalkTime or -1) < .25}
	-- fallback: an object tooltip lingers after leaving the object, so a
	-- cursor change after reaching it, with the mouse moving (not a range
	-- change), means the mouse left it
	if not state.worldEvent and not UnitExists("mouseover") and now - state.targetTime > CHANGE_WINDOW
		and now - state.lastMoveTime < .1 and isWorldTooltipShown() then
		state.staleTooltip = true
	end
end


function events:WORLD_CURSOR_TOOLTIP_UPDATE(anchorType)
	debug("WORLD_CURSOR_TOOLTIP_UPDATE", anchorType)
	if anchorType and anchorType ~= 0 then
		state.worldTarget = true
		reachTarget("WORLD_CURSOR_TOOLTIP_UPDATE")
	else
		-- leaving to open ground always brings the base cursor back
		state.worldTarget = false
		state.leaveEventTime, state.changedAtLeave = GetTime(), state.cursorChanged
		if not UnitExists("mouseover") then leaveTarget() end
	end
end


function events:UPDATE_MOUSEOVER_UNIT()
	if UnitExists("mouseover") then reachTarget("UPDATE_MOUSEOVER_UNIT") end
end


-- fallback target signals when WORLD_CURSOR_TOOLTIP_UPDATE is missing
GameTooltip:HookScript("OnShow", function()
	if state.worldEvent then return end
	state.staleTooltip = false
	if isWorldTooltipShown() then reachTarget("tooltip") end
end)
GameTooltip:HookScript("OnHide", function()
	state.staleTooltip = false
end)
GameTooltip:HookScript("OnTooltipCleared", function() state.tooltipChanged = true end)
GameTooltip:HookScript("OnSizeChanged", function() state.tooltipChanged = true end)


-- CURSORS SET BY THE UI
-- Buttons set the cursor themselves (the sell bag over bag items while a
-- vendor is open, the hammer in repair mode). The look lasts until the UI
-- resets the cursor; for a button's cursor also only while the mouse is still
-- over that button.
local function getFocus()
	if GetMouseFoci then return GetMouseFoci()[1] end
	if GetMouseFocus then return GetMouseFocus() end
end


-- nil: no UI cursor; false: one that cannot be outlined; else a HOVER_SHEETS key
function ns.getUICursor()
	local uiCursor = state.uiCursor
	if not uiCursor then return nil end
	if uiCursor.focus and getFocus() ~= uiCursor.focus then
		state.uiCursor = nil
		return nil
	end
	return uiCursor.look
end


-- buttons can set their cursor every frame while hovered
local function setUICursor(look, followsFocus)
	local focus = followsFocus and getFocus() or nil
	local current = state.uiCursor
	if current and current.look == look and current.focus == focus then return end
	state.uiCursor = {look = look, focus = focus}
	debug("UI cursor", look or "unknown")
end


local function resetUICursor()
	if state.uiCursor then debug("UI cursor reset") end
	state.uiCursor = nil
end


-- SetCursor tokens and paths the UI uses, mapped to HOVER_SHEETS keys
local SET_CURSOR_LOOKS = {
	BUY_CURSOR = "Buy",
	REPAIR_CURSOR = "Repair",
	REPAIRNPC_CURSOR = "RepairNPC",
	ATTACK_CURSOR = "Attack",
	MAIL_CURSOR = "Mail",
}


local function hookFunction(owner, name, handler)
	if owner and type(owner[name]) == "function" then
		if owner == _G then
			hooksecurefunc(name, handler)
		else
			hooksecurefunc(owner, name, handler)
		end
	end
end


for _, name in ipairs({"ShowContainerSellCursor", "ShowMerchantSellCursor", "ShowBuybackSellCursor"}) do
	hookFunction(_G, name, function() setUICursor("Buy", true) end)
end
hookFunction(C_Container, "ShowContainerSellCursor", function() setUICursor("Buy", true) end)
hookFunction(_G, "ShowRepairCursor", function() setUICursor("Repair", false) end)
hookFunction(_G, "ShowInspectCursor", function() setUICursor(false, true) end)
hookFunction(_G, "SetCursor", function(cursorName)
	if cursorName == nil then
		resetUICursor()
	elseif type(cursorName) == "string" then
		local token = cursorName:upper():gsub("^.*[/\\]", "")
		setUICursor(SET_CURSOR_LOOKS[cursorName:upper()] or SET_CURSOR_LOOKS[token.."_CURSOR"] or false, true)
	end
end)
hookFunction(_G, "ResetCursor", resetUICursor)
hookFunction(_G, "HideRepairCursor", resetUICursor)


-- With a camera button held, the game hides its cursor once the mouse moves
-- more than CursorFreelookStartDelta (a fraction of the screen height) from
-- where it was pressed, before PLAYER_STARTED_LOOKING/TURNING arrive. The
-- same rule is applied here so the glove replaces the cursor on that frame,
-- and not while the game cursor is still showing.
function state.isPressHidden()
	-- both buttons held (running with the mouse, or the steer binding): the
	-- game hides its cursor straight away, and keeps it hidden until every
	-- button is released
	local held = 0
	for _ in pairs(state.pressed) do held = held + 1 end
	if held > 1 or state.pressed.steer then
		for _, press in pairs(state.pressed) do press.hidden = true end
		return true
	end

	local startDelta = tonumber(GetCVar("CursorFreelookStartDelta")) or 0
	local x, y = GetCursorPosition()
	local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	for _, press in pairs(state.pressed) do
		if not press.hidden then
			local moved = math.sqrt((x - press.x) ^ 2 + (y - press.y) ^ 2) / screenHeight
			press.hidden = moved > startDelta
		end
		if press.hidden then return true end
	end
	return false
end


for button, functions in pairs({
	camera = {"CameraOrSelectOrMoveStart", "CameraOrSelectOrMoveStop"},
	turn = {"TurnOrActionStart", "TurnOrActionStop"},
	steer = {"MoveAndSteerStart", "MoveAndSteerStop"},
}) do
	local start, stop = functions[1], functions[2]
	if _G[start] and _G[stop] then
		hooksecurefunc(start, function()
			local x, y = GetCursorPosition()
			state.pressed[button] = {x = x, y = y}
		end)
		hooksecurefunc(stop, function() state.pressed[button] = nil end)
	end
end
