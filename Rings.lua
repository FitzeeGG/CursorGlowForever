-- Cursor Glow Forever: rings around the cursor. The cast ring fills up while
-- you cast and drains while you channel, the global cooldown ring fills up
-- over the global cooldown, and a click ripple spreads out where you click.
-- The rings are cooldown frames with a ring swipe, so the game animates them.
local _, ns = ...

local cursor = ns.cursor
local RING = ns.TEXTURES.."ring"
local CAST_DIAMETER, GCD_DIAMETER = 2.6, 2.1 -- in cursor sizes
local RING_ALPHA, TRACK_ALPHA = .9, .2 -- the track: the faint full ring behind a running one
local GCD_SPELL = 61304 -- the global cooldown
local GCD_LONGEST = 2 -- seconds; anything longer is a real cooldown, not the global one
local RIPPLE_TIME, RIPPLE_FROM, RIPPLE_TO, RIPPLE_ALPHA = .45, .5, 2.8, .9 -- seconds, cursor sizes
local RIPPLE_BUTTONS = {"LeftButton", "RightButton"}


local function isSecret(value)
	return issecretvalue and issecretvalue(value) or false
end


-- ring colour: the glow colour, or the rings' own
local function getRingColor()
	if ns.db.ringUseGlowColor then return ns.getColor() end
	return unpack(ns.db.ringColor)
end


-- RINGS
local function createRing(parent, diameter)
	local ring = CreateFrame("Cooldown", nil, parent)
	ring:SetPoint("CENTER", parent, "CENTER")
	ring:SetSwipeTexture(RING)
	ring:SetDrawEdge(false)
	ring:SetDrawBling(false)
	ring:SetHideCountdownNumbers(true)
	ring.diameter = diameter
	ring.track = parent:CreateTexture(nil, "OVERLAY")
	ring.track:SetTexture(RING)
	ring.track:SetPoint("CENTER", parent, "CENTER")
	ring.track:Hide()
	ring:SetScript("OnCooldownDone", function(self) self.track:Hide() end)
	return ring
end


-- drain: empty the ring over the duration (a channel) instead of filling it
local function startRing(ring, start, duration, drain)
	ring:SetReverse(not drain)
	ring:SetCooldown(start, duration)
	ring.track:Show()
	ring.start = start
end


local function stopRing(ring)
	if ring.Clear then ring:Clear() else ring:SetCooldown(0, 0) end
	ring.track:Hide()
	ring.start = nil
end


-- a cast and a global cooldown ring on a frame the size of the cursor
function ns.createRings(parent)
	return {cast = createRing(parent, CAST_DIAMETER), gcd = createRing(parent, GCD_DIAMETER)}
end


function ns.layoutRings(rings, size)
	local r, g, b = getRingColor()
	for _, ring in pairs(rings) do
		local diameter = size * ring.diameter
		ring:SetSize(diameter, diameter)
		ring:SetSwipeColor(r, g, b, RING_ALPHA)
		ring.track:SetSize(diameter, diameter)
		ring.track:SetVertexColor(r, g, b)
		ring.track:SetAlpha(TRACK_ALPHA)
	end
end
ns.startRing, ns.stopRing = startRing, stopRing


local rings = ns.createRings(cursor)
ns.rings = rings


local function getCastInfo()
	-- classic clients once had CastingInfo/ChannelInfo for the player only
	local casting = UnitCastingInfo and function() return UnitCastingInfo("player") end or CastingInfo
	local channel = UnitChannelInfo and function() return UnitChannelInfo("player") end or ChannelInfo
	if casting then
		local name, _, _, startMS, endMS = casting()
		if name then return startMS, endMS, false end
	end
	if channel then
		local name, _, _, startMS, endMS = channel()
		if name then return startMS, endMS, true end
	end
end


function ns.updateCastRing()
	if not ns.db.castRing then return stopRing(rings.cast) end
	local ok, startMS, endMS, channelling = pcall(getCastInfo)
	if ok and startMS and endMS and not isSecret(startMS) and not isSecret(endMS) and endMS > startMS then
		startRing(rings.cast, startMS / 1000, (endMS - startMS) / 1000, channelling)
	else
		stopRing(rings.cast)
	end
end


local function getGlobalCooldown()
	if C_Spell and C_Spell.GetSpellCooldown then
		local info = C_Spell.GetSpellCooldown(GCD_SPELL)
		if info then return info.startTime, info.duration end
	end
	if GetSpellCooldown then return GetSpellCooldown(GCD_SPELL) end
end


function ns.updateGCDRing()
	if not ns.db.gcdRing then return stopRing(rings.gcd) end
	local ok, start, duration = pcall(getGlobalCooldown)
	if not ok or not start or not duration or isSecret(start) or isSecret(duration) then return end
	if duration > 0 and duration <= GCD_LONGEST and start ~= rings.gcd.start then
		startRing(rings.gcd, start, duration, false)
	end
end


function ns.updateRings()
	if not ns.db or not cursor.size then return end
	ns.layoutRings(rings, cursor.size)
	ns.updateCastRing()
	if not ns.db.gcdRing then stopRing(rings.gcd) end
end


local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
	if unit and unit ~= "player" then return end
	if event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_SPELLCAST_SUCCEEDED" then
		ns.updateGCDRing()
	else
		ns.updateCastRing()
		if event == "UNIT_SPELLCAST_START" then ns.updateGCDRing() end
	end
end)
for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED"}) do
	-- only the player's casts where the client can filter them
	if not (events.RegisterUnitEvent and pcall(events.RegisterUnitEvent, events, event, "player")) then
		pcall(events.RegisterEvent, events, event)
	end
end
pcall(events.RegisterEvent, events, "SPELL_UPDATE_COOLDOWN")


-- CLICK RIPPLE
local ripples = {}


local function animateRipple(ripple)
	local t = (GetTime() - ripple.startTime) / RIPPLE_TIME
	if t >= 1 then
		ripple.playing = false
		ripple:Hide()
		return
	end
	local spread = 1 - (1 - t) * (1 - t) -- fast, then easing out
	local diameter = ripple.cursorSize * (RIPPLE_FROM + (RIPPLE_TO - RIPPLE_FROM) * spread)
	ripple:SetSize(diameter, diameter)
	ripple:SetAlpha(RIPPLE_ALPHA * (1 - t) * (1 - t))
end


local function getRipple()
	for _, ripple in ipairs(ripples) do
		if not ripple.playing then return ripple end
	end
	local ripple = CreateFrame("Frame", nil, UIParent)
	ripple:SetFrameStrata("TOOLTIP")
	ripple:SetFrameLevel(9999)
	ripple.texture = ripple:CreateTexture(nil, "OVERLAY")
	ripple.texture:SetTexture(RING)
	ripple.texture:SetAllPoints()
	ripple:SetScript("OnUpdate", animateRipple)
	table.insert(ripples, ripple)
	return ripple
end


function ns.playRipple(x, y)
	local ripple = getRipple()
	local scale = UIParent:GetEffectiveScale()
	ripple.startTime, ripple.cursorSize, ripple.playing = GetTime(), cursor.size or 32, true
	ripple.texture:SetVertexColor(ns.getColor())
	ripple:ClearAllPoints()
	ripple:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	ripple:Show()
	animateRipple(ripple)
end


-- a ripple on each press of a mouse button, wherever it lands
local wasDown = {}
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
	local db = ns.db
	local on = db and db.enabled and db.clickRipple and ns.isShowModeActive()
	for _, button in ipairs(RIPPLE_BUTTONS) do
		local down = IsMouseButtonDown(button) and true or false
		if on and down and not wasDown[button] then ns.playRipple(GetCursorPosition()) end
		wasDown[button] = down
	end
end)
