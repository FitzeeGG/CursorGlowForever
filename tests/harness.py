"""Simulated WoW client for testing Cursor Glow Forever outside the game.

Loads the addon's files into Lua 5.1 (lupa) with stand-ins for the game API,
and gives tests helpers to move the mouse, hover targets and run frames.

    pip install lupa
    python tests/run.py            (add --debug to see the addon's debug lines)
"""
import os
import sys

from lupa import lua51

ADDON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
FILES = ["QuestGivers.lua", "NPCServices.lua", "NPCTitles.lua", "CursorGlowForever.lua", "Rings.lua", "Locales.lua", "Options.lua"]

GAME = r'''
now=0 GetTime=function() return now end
cx,cy=500,500 GetCursorPosition=function() return cx,cy end
mlook=false IsMouselooking=function() return mlook end
carrying=nil GetCursorInfo=function() return carrying end
cvars={cursorSizePreferred="-1", gxMaximize="1", gxMonitor="0", CursorFreelookStartDelta="0.002"}
GetCVar=function(k) return cvars[k] end GetCVarBool=function(k) return cvars[k]=="1" end
windowSizeCalls=0 C_VideoOptions={GetGameWindowSizes=function() windowSizeCalls=windowSizeCalls+1 return {{x=2560,y=1440}} end}
GetPhysicalScreenSize=function() return 2560,1440 end
RAID_CLASS_COLORS={DRUID={r=1,g=.49,b=.04}} UnitClass=function() return "Druid","DRUID" end
UNIT_SKINNABLE_LEATHER="Skinnable" UNIT_SKINNABLE_ROCK="Requires Mining" UNIT_SKINNABLE_HERB="Requires Herbalism" MINIMAP_TRACKING_MAILBOX="Mailbox"
C_Spell={GetSpellName=function(id) return ({[2575]="Mining",[2366]="Herbalism",[8613]="Skinning"})[id] end}
SOUNDKIT={} PlaySound=function() end CopyTable=function(t) local n={} for k,v in pairs(t) do n[k]=v end return n end GameTooltip_Hide=function() end
hooked={} hooksecurefunc=function(name,f) hooked[name]=f end
CameraOrSelectOrMoveStart=function() end CameraOrSelectOrMoveStop=function() end TurnOrActionStart=function() end TurnOrActionStop=function() end

-- widgets: every frame and texture is a table recording what was set on it
local methods={}
setmetatable(methods,{__index=function(_,k) if type(k)=="string" and k:match("^%u") then return function() end end end})
methods.SetShown=function(s,v) s.shown=v and true or false end
methods.Show=function(s) s.shown=true if s.scripts.OnShow then s.scripts.OnShow(s) end end
methods.Hide=function(s) s.shown=false end
methods.SetScript=function(s,k,v) s.scripts[k]=v end
methods.HookScript=function(s,k,v) local old=s.scripts[k] s.scripts[k]=function(...) if old then old(...) end v(...) end end
methods.SetPoint=function(s,p,rel,rp,x,y) s.pt={p,rp,x or 0,y or 0} end
methods.SetSize=function(s,w,h) s.w,s.h=w,h end
methods.SetVertexColor=function(s,r,g,b) s.vc={r,g,b} end
methods.SetColorTexture=function(s,r,g,b) s.vc={r,g,b} end
methods.SetAlpha=function(s,a) s.alpha=a end
methods.SetTexture=function(s,p) s.path=p end
methods.RegisterEvent=function(s,e) s.events[e]=true end
methods.GetStringWidth=function() return 100 end
methods.SetText=function(s,t) s.text=t end
methods.GetFontString=function(s) s.fs=s.fs or obj() return s.fs end
methods.SetCooldown=function(s,start,d) s.cd={start,d} end
methods.SetReverse=function(s,v) s.reverse=v end
methods.Clear=function(s) s.cd=nil end
methods.SetSwipeColor=function(s,r,g,b,a) s.swipe={r,g,b,a} end
local mt={__index=methods}
function obj() return setmetatable({shown=true, scripts={}, events={}}, mt) end
methods.CreateTexture=function() return obj() end
methods.CreateFontString=function() return obj() end
methods.CreateMaskTexture=function() return obj() end
widgetMethods=methods
frames={}
CreateFrame=function(kind,name) local f=obj() table.insert(frames,f) if name then _G[name]=f end return f end
UIParent=obj() UIParent.GetHeight=function() return 1200 end UIParent.GetScale=function() return .64 end UIParent.GetEffectiveScale=function() return .64 end
WorldFrame=obj() WorldFrame.GetWidth=function() return 1365.33 end

-- the tooltip and what's under the mouse
tip=false lines={}
GameTooltip=obj() GameTooltip.IsShown=function() return tip end GameTooltip.GetOwner=function() return UIParent end
GameTooltip.GetAlpha=function() return 1 end GameTooltip.NumLines=function() return #lines end
for i=1,6 do _G["GameTooltipTextLeft"..i]={GetText=function() return lines[i] end} end
unit=nil UnitExists=function() return unit~=nil end
UnitIsDead=function() return unit.dead end UnitCanAttack=function() return unit.enemy end UnitPlayerControlled=function() return unit.player end
UnitGUID=function(u) local target = (u=="npc") and talking or unit return target and target.guid or "guid" end
UnitName=function(u) if u == "player" then return "Tester" end return unit and (unit.name or lines[1]) or nil end
GetRealmName=function() return "Forever" end
strsplit=function(sep, str) local out={} for part in (str..sep):gmatch("(.-)%"..sep) do out[#out+1]=part end return unpack(out) end
talking=nil gossipAvailable={} gossipActive={}
C_GossipInfo={GetAvailableQuests=function() return gossipAvailable end, GetActiveQuests=function() return gossipActive end}
GetNumAvailableQuests=function() return greetAvailable or 0 end GetNumActiveQuests=function() return greetActive or 0 end
CanLootUnit=function() return unit.loot end
focus=nil GetMouseFoci=function() return {focus or WorldFrame} end
ShowContainerSellCursor=function() end ResetCursor=function() end ShowRepairCursor=function() end HideRepairCursor=function() end
ShowMerchantSellCursor=function() end ShowInspectCursor=function() end SetCursor=function() end
inRange=true tooFar=false blockedCalls=0
CheckInteractDistance=function(u, index) if inCombat then blockedCalls=blockedCalls+1 end if index==4 then return not tooFar end return inRange end
buttons={} IsMouseButtonDown=function(b) return buttons[b] or false end
shift=false IsShiftKeyDown=function() return shift end
speed=0 unitSpeed=0 GetUnitSpeed=function(u) if u=="player" then return speed end return unitSpeed end
inCombat=false InCombatLockdown=function() return inCombat end UnitAffectingCombat=function() return inCombat end
-- classic skill list: all three gathering professions unless a test removes one
skills={"Professions", "Skinning", "Mining", "Herbalism"}
GetNumSkillLines=function() return #skills end
GetSkillLineInfo=function(i) return skills[i], skills[i]=="Professions" end
onPlate=false C_NamePlate={GetNamePlateForUnit=function() if not unit then return nil end return {IsMouseOver=function() return onPlate end} end}
openedSettings=0
Settings={RegisterCanvasLayoutCategory=function(p) panelRef=p return {GetID=function() return 1 end} end, RegisterAddOnCategory=function() end, OpenToCategory=function() openedSettings=openedSettings+1 end}
SlashCmdList={} ns={} locale="enUS" GetLocale=function() return locale end
StaticPopupDialogs={} popupShown=nil StaticPopup_Show=function(which, a, b, data) popupShown={which=which, arg=a, data=data} end
-- casting and cooldowns
casting=nil channel=nil
UnitCastingInfo=function() if casting then return casting.name, nil, nil, casting.startMS, casting.endMS end end
UnitChannelInfo=function() if channel then return channel.name, nil, nil, channel.startMS, channel.endMS end end
gcd={0, 0} spellCD={}
GetSpellCooldown=function(id) if id == 61304 then return gcd[1], gcd[2], 1 end local c = spellCD[id] if c then return c[1], c[2], 1 end return 0, 0, 1 end
'''

HELPERS = r'''
C = CursorGlowForeverFrame
driver, watcher, events = nil, nil, nil
for _, f in ipairs(frames) do
	if f.scripts.OnUpdate then if not driver then driver = f elseif not watcher then watcher = f end end
	if f.events.ADDON_LOADED then events = f end
end
events.scripts.OnEvent(events, "ADDON_LOADED", "CursorGlowForever")
events.scripts.OnEvent(events, "PLAYER_LOGIN")
defaultServices = ns.db.outlineServices
defaultShakes, defaultPulse = ns.db.shakeCount, ns.db.combatPulse
ns.db.outlineServices = true -- most cases below cover the service outlines

function ev(e, ...) events.scripts.OnEvent(events, e, ...) end
-- a frame with the mouse moving a little, or still
function frame() now = now + 1/60 cx = cx + 1 driver.scripts.OnUpdate(driver) end
function still() now = now + 1/60 driver.scripts.OnUpdate(driver) end
function idle(n) for i = 1, (n or 60) do frame() end end
function stillFrames(n) for i = 1, (n or 60) do still() end end
-- run some code, then the frame it happened in (the mouse still: tests move it with cx when they mean to)
function inFrame(code) assert(loadstring(code))() still() end
-- reach a target: world event, cursor change (if it changes), tooltip filled in a frame later
function reach(u, tipLines, changes)
	unit = u ev("WORLD_CURSOR_TOOLTIP_UPDATE", 1) if u then ev("UPDATE_MOUSEOVER_UNIT") end
	if changes then ev("CURSOR_CHANGED", true, 0) end
	frame() tip = true lines = tipLines if GameTooltip.scripts.OnShow then GameTooltip.scripts.OnShow(GameTooltip) end
end
function leave() unit = nil lines = {} ev("WORLD_CURSOR_TOOLTIP_UPDATE", 0) ev("CURSOR_CHANGED", true, 0) end
-- what the player sees (looking doesn't move the mouse)
function view()
	still()
	if not C.shown then return "nothing" end
	local m = C.mode
	if m == "base" then return "glove glow" elseif m == "turning" then return "drawn glove + strong glow" end
	return "outline:"..m
end
function shakeFrames(swings, stepX) for k = 1, swings do for i = 1, 4 do now = now + 1/60 cx = cx + stepX * (k % 2 == 0 and 1 or -1) driver.scripts.OnUpdate(driver) end end end
function findWidget(text) for _, f in ipairs(frames) do if f.text == text or (f.label and f.label.text == text) then return f end end end
'''


class Sim:
	def __init__(self, debug=False):
		self.lua = lua51.LuaRuntime()
		self.lua.execute(GAME)
		self.run_file = self.lua.eval('function(src, name) assert(loadstring(src, "@"..name))("CursorGlowForever", ns) end')
		for name in FILES:
			self.load(name)
		self.lua.execute(HELPERS)
		self.lua.execute("ns.debug = %s" % ("true" if debug else "false"))
		self.results = []

	def load(self, name):
		with open(os.path.join(ADDON, name), encoding="utf-8") as f:
			self.run_file(f.read(), name)

	def execute(self, code):
		self.lua.execute(code)

	def eval(self, code):
		return self.lua.eval(code)

	def step(self, label, code, expect):
		"""Run code, then compare what the player sees."""
		self.execute(code)
		got = self.eval("view()")
		self.record(label, got == expect, got)

	def check(self, label, code, condition, details=None):
		"""Run code, then check a Lua condition; details: Lua expressions to print."""
		self.execute(code)
		ok = bool(self.eval(condition))
		shown = ""
		if details:
			shown = " | " + ", ".join("%s=%s" % (d, self.eval("tostring(%s)" % d)) for d in details)
		self.record(label, ok, shown)

	def record(self, label, ok, got=""):
		self.results.append((label, ok))
		print(("  PASS " if ok else "  FAIL ") + label + (" -> " + str(got) if got != "" else ""))
