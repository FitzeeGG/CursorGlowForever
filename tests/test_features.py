"""Features: effects, rings, profiles and the settings page."""
import io
import os
import re

from harness import ADDON


def near(a, b):
	return "math.abs((%s) - (%s)) < 1e-6" % (a, b)


def run(sim):
	sim.execute("reset() leave() idle(60)")

	print(" defaults")
	sim.check("vendor and service outlines off, 7 shakes, combat pulse off", "",
		"defaultServices == false and defaultShakes == 7 and defaultPulse == false")
	sim.check("rings and ripple off", "",
		"ns.defaults.castRing == false and ns.defaults.gcdRing == false and ns.defaults.clickRipple == false")

	print(" shake to find")
	sim.execute("stillFrames(1) baseSize, baseAlpha, baseHalo = C.glow.w, C.glow.alpha, C.halo.alpha")
	sim.check("steady movement: no halo", "for i = 1, 40 do now = now + 1/60 cx = cx + 12 driver.scripts.OnUpdate(driver) end", "C.halo.alpha == 0")
	sim.check("small wiggle: no halo", "shakeFrames(8, 2)", "C.halo.alpha == 0")
	sim.check("a real shake: halo, brighter glow, same glow size", "stillFrames(70) shakeFrames(8, 12) shakeHalo, shakeHaloW = C.halo.alpha, C.halo.w",
		"C.halo.alpha > .4 and C.glow.alpha > baseAlpha and C.glow.w == baseSize", ["C.halo.alpha", "C.glow.alpha"])
	sim.check("  spreads while fading", "stillFrames(30)", "C.halo.alpha < shakeHalo and C.halo.w > shakeHaloW")
	sim.check("  gone after a second", "stillFrames(40)", "C.halo.alpha == 0 and C.glow.alpha == baseAlpha")
	sim.check("option off: no halo", "ns.db.shakeToFind = false stillFrames(70) shakeFrames(8, 12)", "C.halo.alpha == 0")
	sim.execute("ns.db.shakeToFind = true stillFrames(70)")
	sim.check("4 direction changes aren't enough (7 needed)", "shakeFrames(4, 12)", "C.halo.alpha == 0")
	sim.check("a pause starts the count over", "stillFrames(30) shakeFrames(3, 12)", "C.halo.alpha == 0")
	sim.check("set to 3: three changes do it", "ns.db.shakeCount = 3 stillFrames(70) shakeFrames(4, 12)", "C.halo.alpha > .4")
	sim.execute("ns.db.shakeCount = 7 stillFrames(70)")

	print(" combat pulse")
	sim.check("pulses glow and halo in combat, glow size unchanged",
		"ns.db.combatPulse = true inCombat = true hmin, hmax, amin, amax = 1, 0, 1, 0 for i = 1, 72 do now = now + 1/60 driver.scripts.OnUpdate(driver) "
		"hmin, hmax = math.min(hmin, C.halo.alpha), math.max(hmax, C.halo.alpha) amin, amax = math.min(amin, C.glow.alpha), math.max(amax, C.glow.alpha) end",
		"hmax > .25 and hmin < .02 and amax > amin * 1.4 and C.glow.w == baseSize", ["hmin", "hmax", "amin", "amax"])
	sim.check("  stops after combat", "inCombat = false stillFrames(2)", "C.halo.alpha == 0 and C.glow.alpha == baseAlpha")
	sim.execute("baseVC = {unpack(C.glow.vc)}")
	sim.check("  in the glow colour: colour unchanged", "inCombat = true stillFrames(72)",
		"C.glow.vc[1] == baseVC[1] and C.glow.vc[2] == baseVC[2] and C.glow.vc[3] == baseVC[3]")
	sim.check("  in its own colour (red): the glow leans to it, the halo takes it",
		"inCombat = false stillFrames(2) ns.db.pulseUseGlowColor = false ns.db.pulseColor = {1, 0, 0} inCombat = true maxLean, peakHaloVC = 0, nil "
		"for i = 1, 72 do now = now + 1/60 driver.scripts.OnUpdate(driver) local lean = baseVC[2] - C.glow.vc[2] if lean > maxLean then maxLean, peakHaloVC = lean, {unpack(C.halo.vc)} end end",
		"maxLean > baseVC[2] * .6 and peakHaloVC[1] == 1 and peakHaloVC[2] == 0", ["maxLean"])
	sim.check("  back to the glow colour after combat", "inCombat = false stillFrames(2)",
		"C.glow.vc[1] == baseVC[1] and C.glow.vc[2] == baseVC[2] and C.glow.vc[3] == baseVC[3]")
	sim.execute("ns.db.combatPulse = false ns.db.pulseUseGlowColor = true stillFrames(2)")

	print(" idle pulse")
	sim.execute("ns.db.idlePulse = true cx = cx + 5 stillFrames(1) fullGlow, fullOutline = C.glow.alpha, C.outline.alpha")
	sim.check("full for the first seconds", "stillFrames(150)", "C.glow.alpha == fullGlow")
	sim.check("then the glow (not the outline) fades in and out",
		"imin, imax, omin, omax = 1, 0, 1, 0 for i = 1, 480 do now = now + 1/60 driver.scripts.OnUpdate(driver) "
		"imin, imax = math.min(imin, C.glow.alpha), math.max(imax, C.glow.alpha) omin, omax = math.min(omin, C.outline.alpha), math.max(omax, C.outline.alpha) end",
		"imin < .01 and imax == fullGlow and omin == fullOutline and omax == fullOutline")
	sim.check("  full again when the mouse moves", "cx = cx + 5 stillFrames(1)", "C.glow.alpha == fullGlow")
	sim.check("  turning the camera counts as moving",
		"for i = 1, 400 do now = now + 1/60 mlook = true driver.scripts.OnUpdate(driver) end turnGlow = C.glow.alpha mlook = false stillFrames(30) cx = cx + 5 stillFrames(1)",
		"turnGlow >= fullGlow")
	sim.execute("ns.db.idlePulse = false stillFrames(2)")

	print(" glow size and glove")
	sim.check("200%: its own texture, the same texture size, a wider hover soft circle",
		"gsW, gsSoft = C.glow.w, C.hover.soft.w ns.db.glowSize = 2 ns.updateLayout()",
		"C.glow.path:match('point%-glow%-200$') and C.glow.w == gsW and C.hover.soft.w > gsSoft")
	sim.check("an unknown size falls back to 100%", "ns.db.glowSize = .6 ns.updateLayout()", "C.glow.path:match('point%-glow$')")
	sim.execute("ns.db.glowSize = 1 ns.updateLayout()")
	sim.check("glove tint: glow colour, or its own", "gloveDefault = {unpack(C.glove.vc)} ns.db.gloveUseGlowColor = false ns.db.gloveColor = {0, .5, 1} ns.updateLayout()",
		near("C.glove.vc[1]", .4) + " and " + near("C.glove.vc[2]", .7) + " and C.glove.vc[3] == 1 and " + near("gloveDefault[2]", .694))
	sim.execute("ns.db.gloveUseGlowColor = true ns.updateLayout()")

	print(" profiles")
	sim.check("starts on Default", "default = ns.db", "ns.getProfileName() == 'Default' and CursorGlowForeverDB.profiles.Default == default")
	sim.check("a new profile copies the current settings", "default.glowOpacity = .5 created = ns.newProfile('Healer')",
		"created and ns.getProfileName() == 'Healer' and ns.db ~= default and ns.db.glowOpacity == .5")
	sim.check("taken or empty names are refused", "", "not ns.newProfile('Healer') and not ns.newProfile('  ')")
	sim.check("its own settings, Default untouched", "ns.db.glowOpacity = .8 ns.updateLayout()", "C.glow.alpha == .8 and default.glowOpacity == .5")
	sim.check("switch back", "ns.setProfile('Default')", "ns.db == default and C.glow.alpha == .5")
	sim.check("copy from another profile", "ns.setProfile('Healer') ns.copyProfile('Default')", "ns.db.glowOpacity == .5 and ns.db ~= default")
	sim.check("kept after logging in again", "ns.db.glowOpacity = .8 ev('ADDON_LOADED', 'CursorGlowForever')", "ns.getProfileName() == 'Healer' and ns.db.glowOpacity == .8")
	sim.check("new settings are filled in", "CursorGlowForeverDB.profiles.Healer.glowSize = nil ns.useProfile()", "ns.db.glowSize == 1")
	sim.check("Default can't be deleted", "ns.deleteProfile('Default')", "CursorGlowForeverDB.profiles.Default ~= nil")
	sim.check("deleting goes back to Default", "ns.deleteProfile('Healer')",
		"ns.getProfileName() == 'Default' and CursorGlowForeverDB.profiles.Healer == nil and ns.db == default")
	sim.execute("default.glowOpacity = .35 ns.updateLayout()")
	sim.check("1.0.2 settings move into profiles",
		"saved, savedChar = CursorGlowForeverDB, CursorGlowForeverCharDB "
		"CursorGlowForeverDB = {version = 2, glowOpacity = .6, color = {0, 1, 0}, useClassColor = false} "
		"CursorGlowForeverCharDB = {questGivers = {}, useCharacterSettings = true, settings = {glowOpacity = .9}} ev('ADDON_LOADED', 'CursorGlowForever') "
		"mgDefault = CursorGlowForeverDB.profiles.Default.glowOpacity == .6 and CursorGlowForeverDB.glowOpacity == nil "
		"mgChar = ns.getProfileName() == 'Tester - Forever' and ns.db.glowOpacity == .9 and CursorGlowForeverCharDB.settings == nil "
		"CursorGlowForeverCharDB = {questGivers = {}, useCharacterSettings = false, settings = {glowOpacity = .2}} ev('ADDON_LOADED', 'CursorGlowForever') "
		"mgOther = ns.getProfileName() == 'Default' and ns.db.glowOpacity == .6 "
		"CursorGlowForeverDB, CursorGlowForeverCharDB = saved, savedChar ev('ADDON_LOADED', 'CursorGlowForever') ns.updateLayout()",
		"mgDefault and mgChar and mgOther")

	print(" cast and global cooldown rings")
	sim.execute("cast, gcdRing = ns.rings.cast, ns.rings.gcd ns.db.castRing, ns.db.gcdRing = true, true ns.updateLayout()")
	sim.check("sizes", "", near("cast.w", "C.w * 2.6") + " and " + near("gcdRing.w", "C.w * 2.1"))
	sim.check("a cast fills", "casting = {name = 'Fireball', startMS = 100000, endMS = 103500} ns.updateCastRing()",
		"cast.cd and cast.cd[1] == 100 and cast.cd[2] == 3.5 and cast.reverse == true and cast.track.shown")
	sim.check("a channel drains", "casting, channel = nil, {name = 'Drain Life', startMS = 100000, endMS = 105000} ns.updateCastRing()",
		"cast.cd[2] == 5 and cast.reverse == false")
	sim.check("stops", "channel = nil ns.updateCastRing()", "cast.cd == nil and not cast.track.shown")
	sim.check("hidden cast times are skipped", "issecretvalue = function(v) return v == 123 end casting = {name = 'X', startMS = 123, endMS = 2000} ns.updateCastRing()",
		"cast.cd == nil")
	sim.execute("issecretvalue = nil casting = nil")
	sim.check("option off: no cast ring", "ns.db.castRing = false casting = {name = 'Fireball', startMS = 100000, endMS = 103500} ns.updateCastRing()", "cast.cd == nil")
	sim.execute("casting = nil")
	sim.check("the global cooldown spell", "gcd = {100, 1.5} ns.updateGCDRing()", "gcdRing.cd and gcdRing.cd[1] == 100 and gcdRing.cd[2] == 1.5")
	sim.check("  a long cooldown isn't the global one", "gcd = {101, 8} ns.updateGCDRing()", "gcdRing.cd[1] == 100")
	sim.execute("gcd = {0, 0} ns.stopRing(gcdRing)")
	sim.check("without that spell: from Rend", "spellCD[772] = {200, 1.5} ns.updateGCDRing(772)", "gcdRing.cd and gcdRing.cd[1] == 200")
	sim.check("  Mortal Strike (own 6 s cooldown) via Rend", "spellCD[12294], spellCD[772] = {205, 6}, {205, 1.5} ns.updateGCDRing(12294)", "gcdRing.cd[1] == 205 and gcdRing.cd[2] == 1.5")
	sim.check("  Heroic Strike starts none", "spellCD[772] = {0, 0} ns.updateGCDRing(78)", "gcdRing.cd[1] == 205")
	sim.check("  the cooldown event carries a spell, not a unit",
		"local ringEvents for _, f in ipairs(frames) do if f.events.SPELL_UPDATE_COOLDOWN then ringEvents = f end end "
		"spellCD[772] = {300, 1.5} ringEvents.scripts.OnEvent(ringEvents, 'SPELL_UPDATE_COOLDOWN', 772, 772)", "gcdRing.cd[1] == 300")
	sim.execute("spellCD = {} ns.stopRing(gcdRing)")
	sim.execute("secretStart, secretDuration = 777001, 777002 issecretvalue = function(v) return v == secretStart or v == secretDuration end "
		"C_Spell.GetSpellCooldown = function(id) if id == 1715 then return {startTime = secretStart, duration = secretDuration, isOnGCD = true} end "
		"if id == 12294 then return {startTime = secretStart, duration = secretDuration, isOnGCD = false} end end")
	sim.check("hidden cooldowns: one with its own cooldown is skipped", "ns.updateGCDRing(12294)", "gcdRing.cd == nil")
	sim.check("  on the global cooldown: timed from now", "now = 400 ns.updateGCDRing(1715)", "gcdRing.cd[1] == 400 and gcdRing.cd[2] == 1.5 and gcdRing.reverse == true")
	sim.check("  not restarted by more events", "now = 400.5 ns.updateGCDRing()", "gcdRing.cd[1] == 400")
	sim.check("  a rogue's is a second", "now = 410 UnitClass = function() return 'Rogue', 'ROGUE' end ns.updateGCDRing(1715)", "gcdRing.cd[1] == 410 and gcdRing.cd[2] == 1")
	sim.check("  through the client's duration object where it has one",
		"UnitClass = function() return 'Druid', 'DRUID' end C_Spell.GetSpellCooldownDuration = function(id) return {spell = id} end "
		"gcdRing.SetCooldownFromDurationObject = function(self, d) self.durationObject = d end now = 420 ns.updateGCDRing(1715)",
		"gcdRing.durationObject and gcdRing.durationObject.spell == 1715")
	sim.execute("gcdRing.SetCooldownFromDurationObject = nil C_Spell.GetSpellCooldownDuration = nil C_Spell.GetSpellCooldown = nil issecretvalue = nil now = 500")
	sim.check("own ring colour", "ns.db.ringUseGlowColor = false ns.db.ringColor = {0, 1, 1} ns.updateLayout()", "cast.swipe[1] == 0 and cast.swipe[3] == 1")
	sim.execute("ns.db.ringUseGlowColor = true")
	sim.check("/cg test runs both rings", "SlashCmdList.CURSORGLOWFOREVER('test')", "cast.cd[2] == 3 and gcdRing.cd[2] == 1.5")
	sim.execute("ns.stopRing(cast) ns.stopRing(gcdRing) ns.db.castRing, ns.db.gcdRing = false, false ns.updateLayout()")

	print(" ring position and size")
	sim.execute("ns.db.castRing = true ns.updateLayout()")
	sim.check("default: centred", "", "cast.pt[3] == 0 and cast.pt[4] == 0")
	sim.check("finger tip", "ns.db.ringPosition = 'fingertip' ns.updateLayout()", near("cast.pt[3]", "-C.w * .5") + " and " + near("cast.pt[4]", "C.w * .5"))
	sim.check("custom", "ns.db.ringPosition = 'custom' ns.db.ringOffset = {1, -1} ns.updateLayout()", near("cast.pt[3]", "C.w") + " and " + near("cast.pt[4]", "-C.w"))
	sim.check("kept near the cursor", "ns.setRingOffset(9, -9)", "ns.db.ringOffset[1] == 2.5 and ns.db.ringOffset[2] == -2.5")
	sim.check("large", "ns.db.ringSize = 'large' ns.updateLayout()", near("cast.w", "C.w * 2.6 * 1.6"))
	sim.check("custom size", "ns.db.ringSize = 'custom' ns.db.ringScale = 2 ns.updateLayout()", near("cast.w", "C.w * 2.6 * 2"))
	sim.execute("ns.db.ringSize, ns.db.ringScale, ns.db.ringPosition, ns.db.ringOffset, ns.db.castRing = 'default', 1, 'default', {0, 0}, false ns.updateLayout()")

	print(" click ripple")
	sim.execute("function tick(n) for i = 1, n or 1 do now = now + 1/60 watcher.scripts.OnUpdate(watcher) for _, f in ipairs(frames) do if f.playing ~= nil and f.shown then f.scripts.OnUpdate(f) end end end end "
		"function ripples() local n, playing = 0, 0 for _, f in ipairs(frames) do if f.playing ~= nil then n = n + 1 if f.playing then playing = playing + 1 end end end return n, playing end")
	sim.check("off: no ripple", "buttons.LeftButton = true tick() buttons.LeftButton = false tick()", "select(1, ripples()) == 0")
	sim.check("one per press, where the click lands",
		"ns.db.clickRipple = true cx, cy = 640, 400 buttons.LeftButton = true tick() for _, f in ipairs(frames) do if f.playing ~= nil then ripple = f end end",
		"select(1, ripples()) == 1 and ripple.pt[3] == 640 / .64 and ripple.pt[4] == 400 / .64")
	sim.check("  spreads and fades", "startW = ripple.w tick(10)", "ripple.w > startW and ripple.alpha < .9")
	sim.check("  holding adds none", "tick(5)", "select(1, ripples()) == 1")
	sim.check("  ends", "buttons.LeftButton = false tick(30)", "not ripple.playing and not ripple.shown")
	sim.check("  the next press reuses it", "buttons.RightButton = true tick()", "select(1, ripples()) == 1 and ripple.playing")
	sim.check("  follows the show mode", "buttons.RightButton = false tick(30) ns.db.showWhen = 'combat' buttons.LeftButton = true tick()", "not ripple.playing")
	sim.execute("buttons.LeftButton = false tick() ns.db.showWhen = 'always' ns.db.clickRipple = false")

	print(" settings page")
	sim.execute("panelRef:Show() for _, f in ipairs(frames) do if f.samples then previewRef = f end end")
	sim.check("tabs", "tab1 = panelRef.page == 1 findWidget('Effects').scripts.OnClick() tab2 = panelRef.page == 2 findWidget('Cursor').scripts.OnClick()",
		"tab1 and tab2 and panelRef.page == 1")
	sim.check("new profile asks for a name", "findWidget('New').scripts.OnClick()", "popupShown.which == 'CURSORGLOWFOREVER_NEW_PROFILE'")
	sim.check("  and creates it", "StaticPopupDialogs.CURSORGLOWFOREVER_NEW_PROFILE.OnAccept({editBox = {GetText = function() return 'Tank' end}})", "ns.getProfileName() == 'Tank'")
	sim.check("delete asks first", "findWidget('Delete').scripts.OnClick()", "popupShown.which == 'CURSORGLOWFOREVER_DELETE_PROFILE' and popupShown.data == 'Tank'")
	sim.check("  then deletes", "StaticPopupDialogs.CURSORGLOWFOREVER_DELETE_PROFILE.OnAccept(nil, popupShown.data)", "ns.getProfileName() == 'Default'")
	sim.check("reset asks first", "ns.db.glowOpacity = .7 popupShown = nil findWidget('Reset to defaults').scripts.OnClick()",
		"popupShown.which == 'CURSORGLOWFOREVER_RESET' and ns.db.glowOpacity == .7")
	sim.check("  then resets", "StaticPopupDialogs.CURSORGLOWFOREVER_RESET.OnAccept()", "ns.db.glowOpacity == .35")
	sim.execute("ns.db.outlineServices = true")
	sim.check("preview follows colour, glow and outline",
		"ns.db.useClassColor = false ns.db.color = {0, 1, 0} ns.db.glowOpacity = .6 ns.db.outlineOpacity = .5 ns.updateLayout() previewRef:refresh() s1 = previewRef.samples[1]",
		"s1.glow.vc[2] == 1 and s1.glow.vc[1] == 0 and s1.glow.alpha == .6 and s1.outline.alpha == .5")
	sim.execute("ns.db.useClassColor = true ns.db.glowOpacity = .35 ns.db.outlineOpacity = .75 ns.updateLayout() previewRef:refresh()")
	sim.check("preview demo ring", "ns.db.castRing = true previewRef:refresh() previewRef.scripts.OnUpdate(previewRef)", "s1.rings.cast.cd ~= nil")
	sim.check("placing the ring by dragging in the preview",
		"previewRef.GetEffectiveScale = function() return 1 end s1.GetCenter = function() return 100, 100 end ns.db.ringPosition = 'custom' previewRef:refresh() "
		"size = s1.size cx, cy = 100 + size, 100 + size * .5 previewRef.scripts.OnMouseDown(previewRef, 'LeftButton') previewRef.scripts.OnUpdate(previewRef)",
		near("ns.db.ringOffset[1]", 1) + " and " + near("ns.db.ringOffset[2]", .5) + " and previewRef.hint.shown")
	sim.check("  release; right-click centres it", "previewRef.scripts.OnMouseUp(previewRef) previewRef.scripts.OnMouseDown(previewRef, 'RightButton')",
		"not previewRef.dragging and ns.db.ringOffset[1] == 0")
	sim.check("  only when custom", "ns.db.ringPosition = 'default' previewRef:refresh() previewRef.scripts.OnMouseDown(previewRef, 'LeftButton')",
		"not previewRef.dragging and not previewRef.hint.shown")
	sim.execute("ns.db.castRing = false previewRef:refresh()")
	sim.check("custom ring size slider only when chosen", "ns.db.castRing = true ns.db.ringSize = 'custom' panelRef:Show() shownCustom = findWidget('Custom ring size').shown "
		"ns.db.ringSize = 'default' panelRef:Show()", "shownCustom and not findWidget('Custom ring size').shown")
	sim.check("dragging a slider doesn't ask for the window sizes",
		"before = windowSizeCalls local slider = findWidget('Glow opacity') for i = 1, 20 do slider.scripts.OnValueChanged(slider, i / 20, true) end",
		"windowSizeCalls == before and ns.db.glowOpacity == 1")
	sim.check("  a UI scale change does", "ev('UI_SCALE_CHANGED')", "windowSizeCalls == before + 1")
	sim.execute("ns.db.glowOpacity = .35 ns.db.castRing = false ns.updateLayout()")

	print(" greyed out with their setting")
	grey = [
		("shakes needed without shake to find", "ns.db.shakeToFind = false", "Shakes needed", .4),
		("  with it", "ns.db.shakeToFind = true", "Shakes needed", 1),
		("pulse colour in combat pulse, own colour", "ns.db.combatPulse, ns.db.pulseUseGlowColor = true, false", "Pulse colour", 1),
		("  using the glow colour", "ns.db.pulseUseGlowColor = true", "Pulse colour", .4),
		("  combat pulse off", "ns.db.combatPulse, ns.db.pulseUseGlowColor = false, false", "Pulse colour", .4),
		("pulse uses glow colour, combat pulse off", "", "Pulse uses glow colour", .4),
		("ring position with no ring", "ns.db.castRing, ns.db.gcdRing = false, false", "Ring position", .4),
		("  with a ring", "ns.db.gcdRing = true", "Ring position", 1),
		("hover outlines without hiding on hover", "ns.db.hideOnHover = false", "Outline hover cursors", .4),
		("  out of range strength too", "", "Out of range strength", .4),
		("  hiding on hover", "ns.db.hideOnHover = true", "Outline hover cursors", 1),
		("glove tint without the drawn glove", "ns.db.gloveWhileTurning = false", "Glove tint", .4),
		("  glove colour too", "", "Glove colour", .4),
	]
	for label, code, widget, alpha in grey:
		sim.check(label, code + " panelRef:Show()", "findWidget('%s').alpha == %s" % (widget, alpha))
	sim.execute("ns.db.gloveWhileTurning, ns.db.gcdRing, ns.db.combatPulse, ns.db.pulseUseGlowColor = true, false, false, true panelRef:Show()")

	print(" combat")
	sim.check("/cg in combat waits", "openedSettings = 0 inCombat = true SlashCmdList.CURSORGLOWFOREVER('')", "openedSettings == 0")
	sim.check("  and opens after it", "local waiter for _, f in ipairs(frames) do if f.events.PLAYER_REGEN_ENABLED then waiter = f end end "
		"inCombat = false waiter.scripts.OnEvent(waiter, 'PLAYER_REGEN_ENABLED')", "openedSettings == 1")
	sim.check("/cg out of combat opens straight away", "SlashCmdList.CURSORGLOWFOREVER('')", "openedSettings == 2")

	print(" translations")
	check_locales(sim)
	sim.execute('locale = "deDE" ENABLE = "Aktivieren (Spiel)"')
	sim.load("Locales.lua")
	sim.load("Options.lua")
	sim.check("the settings page on a German client",
		"panelRef:Show() deLabels = {} for _, f in ipairs(frames) do if f.label and f.label.text then deLabels[f.label.text] = true end end",
		"deLabels['Klassenfarbe verwenden'] and deLabels['Aktivieren (Spiel)'] and ns.L['Out of combat'] == 'Außerhalb des Kampfes' "
		"and ns.L['Not a translated string'] == 'Not a translated string'")
	sim.execute('locale = "enUS" ENABLE = nil')


def check_locales(sim):
	"""Every string on the settings page has a translation in every language, and none is left over."""
	with io.open(os.path.join(ADDON, "Options.lua"), encoding="utf-8") as f:
		used = set(re.findall(r'L\["([^"]*)"\]', f.read()))
	with io.open(os.path.join(ADDON, "Locales.lua"), encoding="utf-8") as f:
		source = f.read()
	blocks = re.split(r'\n(?:if|elseif) (locale == [^\n]*) then\n', source)[1:]
	problems = []
	for condition, body in zip(blocks[0::2], blocks[1::2]):
		keys = set(re.findall(r'^\t\t\["([^"]*)"\] = ', body, re.M))
		if keys != used:
			problems.append("%s: missing %d, unused %d" % (condition, len(used - keys), len(keys - used)))
	sim.record("every settings string translated in %d language groups" % (len(blocks) // 2), not problems and len(blocks) // 2 == 9,
		"; ".join(problems))
