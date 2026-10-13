"""Hover cursors: what the player sees over targets. Each scenario starts clean."""

RESET = r'''
function reset()
	leave() idle(30)
	unit, tip, lines, focus, onPlate, carrying, talking = nil, false, {}, nil, false, nil, nil
	shift, mlook, inRange, tooFar, speed, unitSpeed, inCombat, buttons = false, false, true, false, 0, 0, false, {}
	UnitClass = function() return "Druid", "DRUID" end
	skills = {"Professions", "Skinning", "Mining", "Herbalism"} ev("SKILL_LINES_CHANGED")
	ns.db.outlineServices, ns.db.showWhen, ns.db.hideOnHover, ns.db.outlineHover = true, "always", true, true
	idle(30)
end
'''

SMITH = "{guid='Creature-0-1-2-3-3165-00A1'}"  # Ghrawt: vendor + repair, no quests in the data
FARLEY = "{guid='Creature-0-1-2-3-295-00A2'}"  # Innkeeper Farley: in the quest giver list
INN = "{guid='Creature-0-1-2-3-424242-00A3'}"  # an innkeeper new to Forever

SCENARIOS = [
	("basics", [
		("open ground", "", "glove glow"),
		("lootable corpse", "reach({dead=true, loot=true}, {'Boar','Level 5'}, true) idle(10)", "outline:LootAll"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("skinnable corpse", "reach({dead=true}, {'Boar','Skinnable'}, true) idle(10)", "outline:Skin"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("ore node", "reach(nil, {'Copper Vein','Requires Mining'}, true) idle(10)", "outline:Mine"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("ore node that doesn't change the cursor", "reach(nil, {'Copper Vein','Requires Mining'}, false) idle(10)", "glove glow"),
		("  leave", "unit=nil ev('WORLD_CURSOR_TOOLTIP_UPDATE', 0) idle(30) tip=false", "glove glow"),
		("herb", "reach(nil, {'Peacebloom','Herbalism'}, true) idle(10)", "outline:GatherHerbs"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("mailbox", "reach(nil, {'Mailbox'}, true) idle(10)", "outline:Mail"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("enemy", "reach({enemy=true}, {'Boar','Level 5'}, true) idle(30)", "outline:Attack"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("vendor", "reach({}, {'Bob','General Goods'}, true) idle(10)", "outline:Buy"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("carrying an item: no glow", "carrying='item' idle(5)", "nothing"),
		("  put it down", "carrying=nil idle(5)", "glove glow"),
		("turning the camera: the drawn glove", "mlook=true idle(5)", "drawn glove + strong glow"),
		("  stop turning", "mlook=false idle(5)", "glove glow"),
	]),
	("nameplates", [
		("on the harpy's nameplate (no cursor change)", "onPlate=true unit={enemy=true} ev('WORLD_CURSOR_TOOLTIP_UPDATE', 1) ev('UPDATE_MOUSEOVER_UNIT') tip=true lines={'Witchwing Harpy','Level 14'} idle(20)", "glove glow"),
		("  onto the body (sword, same frame)", "inFrame(\"onPlate=false ev('CURSOR_CHANGED', true, 0)\") idle(20)", "outline:Attack"),
		("  back to the nameplate", "inFrame(\"onPlate=true ev('CURSOR_CHANGED', true, 0)\") idle(20)", "glove glow"),
		("  onto the body, cursor change a frame before", "inFrame(\"ev('CURSOR_CHANGED', true, 0)\") inFrame(\"onPlate=false\") idle(20)", "outline:Attack"),
		("  back, cursor change a frame before", "inFrame(\"ev('CURSOR_CHANGED', true, 0)\") inFrame(\"onPlate=true\") idle(20)", "glove glow"),
		("  onto the body, cursor change a frame after", "inFrame(\"onPlate=false\") inFrame(\"ev('CURSOR_CHANGED', true, 0)\") idle(20)", "outline:Attack"),
		("  leave", "onPlate=false leave() idle(30) tip=false", "glove glow"),
		("crossing right after reaching", "unit={enemy=true} ev('WORLD_CURSOR_TOOLTIP_UPDATE', 1) ev('UPDATE_MOUSEOVER_UNIT') idle(3) inFrame(\"cx=cx+2 ev('CURSOR_CHANGED', true, 0)\") idle(20)", "outline:Attack"),
	]),
	("quest givers", [
		("repair vendor, no quests known", "reach(" + SMITH + ", {'Ghrawt','Bowyer'}, true) idle(10)", "outline:RepairNPC"),
		("  talk to it: a quest", "talking=" + SMITH + " gossipAvailable={{title='Wanted'}} ev('GOSSIP_SHOW') idle(5)", "nothing"),
		("  hover again: quest cursor, no outline", "leave() idle(30) tip=false reach(" + SMITH + ", {'Ghrawt','Bowyer'}, true) idle(10)", "nothing"),
		("  quest done: no quests", "talking=" + SMITH + " gossipAvailable={} gossipActive={} ev('GOSSIP_SHOW') idle(5)", "outline:RepairNPC"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("Innkeeper Farley (built-in list): no outline at first", "reach(" + FARLEY + ", {'Innkeeper Farley','Innkeeper'}, true) idle(10)", "nothing"),
		("  talk: no quests for this character", "talking=" + FARLEY + " gossipAvailable={} gossipActive={} ev('GOSSIP_SHOW') idle(5)", "outline:Innkeeper"),
		("  hover again: the learned answer wins", "leave() idle(30) tip=false reach(" + FARLEY + ", {'Innkeeper Farley','Innkeeper'}, true) idle(10)", "outline:Innkeeper"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("an innkeeper not in the list", "reach(" + INN + ", {'New Innkeeper','Innkeeper'}, true) idle(10)", "outline:Innkeeper"),
	]),
	("range", [
		("lootable corpse reached out of range", "inRange=false reach({dead=true, loot=true}, {'Harpy','Level 14'}, true) idle(10)", "outline:LootAll"),
		("  walk into range (mouse still)", "stillFrames(10) inRange=true ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "outline:LootAll"),
		("  walk back out", "stillFrames(10) inRange=false ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "outline:LootAll"),
		("  walk further, beyond follow range: back to the glove", "stillFrames(5) tooFar=true ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "glove glow"),
		("  closer again: greyed cursor", "stillFrames(5) tooFar=false ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "outline:LootAll"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("vendor out of range keeps its own sheet", "inRange=false reach({}, {'Bob','General Goods'}, true) idle(10)", "outline:Buy"),
		("  leave", "leave() idle(30) tip=false inRange=true", "glove glow"),
		("ore seen from far: pickaxe as you approach", "reach(nil, {'Copper Vein','Requires Mining'}, false) stillFrames(10) ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "outline:Mine"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("enemy runs at you: greyed sword -> sword", "inRange=false unitSpeed=7 reach({enemy=true}, {'Boar','Level 5'}, true) stillFrames(20) inRange=true ev('CURSOR_CHANGED', true, 0) stillFrames(15)", "outline:Attack"),
		("  leave", "leave() idle(30) tip=false unitSpeed=0", "glove glow"),
		("innkeeper out of range while walking", "inRange=false speed=7 reach(" + INN + ", {'Innkeeper Grosk','Innkeeper'}, true) idle(10)", "outline:Innkeeper"),
		("  leave", "leave() idle(30) tip=false speed=0", "glove glow"),
	]),
	("professions", [
		("without Skinning: corpse shows a greyed knife, no outline", "skills={'Professions','Mining','Herbalism'} ev('SKILL_LINES_CHANGED') reach({dead=true}, {'Boar','Skinnable'}, true) idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("ore still outlined (has Mining)", "reach(nil, {'Copper Vein','Requires Mining'}, true) idle(10)", "outline:Mine"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("learns Skinning: corpse outlined", "skills={'Professions','Skinning'} ev('SKILL_LINES_CHANGED') reach({dead=true}, {'Boar','Skinnable'}, true) idle(10)", "outline:Skin"),
	]),
	("shift looting", [
		("lootable corpse", "reach({dead=true, loot=true}, {'Boar','Level 5'}, true) idle(10)", "outline:LootAll"),
		("  press shift: single bag", "stillFrames(5) inFrame(\"shift=true ev('MODIFIER_STATE_CHANGED', 'LSHIFT', 1) ev('CURSOR_CHANGED', true, 0)\") stillFrames(10)", "outline:Pickup"),
		("  release shift (cursor first, modifier a frame later)", "stillFrames(5) inFrame(\"shift=false ev('CURSOR_CHANGED', true, 0)\") inFrame(\"ev('MODIFIER_STATE_CHANGED', 'LSHIFT', 0)\") stillFrames(10)", "outline:LootAll"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("reach a corpse with shift held", "shift=true reach({dead=true, loot=true}, {'Enforcer','Level 17'}, true) idle(10)", "outline:Pickup"),
		("  release shift", "stillFrames(5) inFrame(\"shift=false ev('MODIFIER_STATE_CHANGED', 'LSHIFT', 0) ev('CURSOR_CHANGED', true, 0)\") stillFrames(10)", "outline:LootAll"),
	]),
	("services off", [
		("vendor: glow hidden, no outline", "ns.db.outlineServices=false reach({}, {'Bob','General Goods'}, true) idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("  guild vault", "reach(nil, {'Guild Vault'}, true) idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("  mailbox still outlined", "reach(nil, {'Mailbox'}, true) idle(10)", "outline:Mail"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("  enemy still outlined", "reach({enemy=true}, {'Boar','Level 5'}, true) idle(10)", "outline:Attack"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("  chair (unknown, changes cursor; hovered long enough to learn it)", "reach(nil, {'Table Cooker'}, true) idle(30)", "nothing"),
		("  chair -> innkeeper in the same frame", "inFrame(\"ev('CURSOR_CHANGED', true, 0) unit=" + INN + " ev('WORLD_CURSOR_TOOLTIP_UPDATE', 0) ev('WORLD_CURSOR_TOOLTIP_UPDATE', 1) ev('UPDATE_MOUSEOVER_UNIT') lines={'Innkeeper Grosk','Innkeeper'}\") idle(10)", "nothing"),
		("  innkeeper -> chair in the same frame", "inFrame(\"ev('CURSOR_CHANGED', true, 0) unit=nil ev('WORLD_CURSOR_TOOLTIP_UPDATE', 0) ev('WORLD_CURSOR_TOOLTIP_UPDATE', 1) lines={'Table Cooker'}\") idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("innkeeper out and back into range: stays hidden", "reach(" + INN + ", {'Innkeeper Grosk','Innkeeper'}, true) idle(20) stillFrames(5) inRange=false ev('CURSOR_CHANGED', true, 0) stillFrames(10) stillFrames(5) inRange=true ev('CURSOR_CHANGED', true, 0) stillFrames(10)", "nothing"),
	]),
	("trainers and titles", [
		("Ghrawt <Bowyer> (vendor + repair in the data): anvil", "reach({guid='Creature-0-1-2-3-3165-00AA'}, {'Ghrawt','Bowyer'}, true) idle(10)", "outline:RepairNPC"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("a bowyer not in the data: bag from the title", "reach({guid='Creature-0-1-2-3-999999-00AB'}, {'New Bowyer','Bowyer'}, true) idle(10)", "outline:Buy"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("Harruk <Pet Trainer> as a druid: no outline", "reach({guid='Creature-0-1-2-3-3620-00AC'}, {'Harruk','Pet Trainer'}, true) idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("Harruk as a hunter: trainer", "UnitClass=function() return 'Hunter','HUNTER' end reach({guid='Creature-0-1-2-3-3620-00AC'}, {'Harruk','Pet Trainer'}, true) idle(10)", "outline:Trainer"),
		("  leave", "leave() idle(30) tip=false UnitClass=function() return 'Druid','DRUID' end", "glove glow"),
		("Larimaine Purdue <Portal Trainer> as a druid: no outline", "reach({guid='Creature-0-1-2-3-2485-00AD'}, {'Larimaine Purdue','Portal Trainer'}, true) idle(10)", "nothing"),
		("  leave", "leave() idle(30) tip=false", "glove glow"),
		("Larimaine Purdue as a mage: trainer", "UnitClass=function() return 'Mage','MAGE' end reach({guid='Creature-0-1-2-3-2485-00AD'}, {'Larimaine Purdue','Portal Trainer'}, true) idle(10)", "outline:Trainer"),
		("  leave", "leave() idle(30) tip=false UnitClass=function() return 'Druid','DRUID' end", "glove glow"),
		("a mage trainer not in the data, as a druid: no outline", "reach({guid='Creature-0-1-2-3-999998-00AE'}, {'New Mage','Mage Trainer'}, true) idle(10)", "nothing"),
	]),
	("UI cursors", [
		("selling from bags", "focus={} hooked.ShowContainerSellCursor()", "outline:Buy"),
		("  off the bag item", "hooked.ResetCursor() focus=nil", "glove glow"),
	]),
	("show the glow", [
		("in combat only, out of combat", "ns.db.showWhen='combat' idle(5)", "nothing"),
		("  in combat", "inCombat=true idle(5)", "glove glow"),
		("out of combat only, in combat", "ns.db.showWhen='noCombat' idle(5)", "nothing"),
		("  shake to find still shows it", "shakeFrames(8, 12)", "glove glow"),
		("  hidden again after the shake", "stillFrames(70)", "nothing"),
		("  out of combat", "inCombat=false idle(5)", "glove glow"),
	]),
	("combat range", [
		("in combat: NPC out of range, walking in (no distance checks)", "blockedCalls=0 inCombat=true inRange=false unitSpeed=7 reach({guid='Creature-0-1-2-3-3165-00AA'}, {'Ghrawt','Bowyer'}, true) stillFrames(20) inRange=true ev('CURSOR_CHANGED', true, 0) stillFrames(15)", "outline:RepairNPC"),
	]),
]


def run(sim):
	sim.execute(RESET)
	for name, steps in SCENARIOS:
		print(" %s" % name)
		sim.execute("reset()")
		for label, code, expect in steps:
			sim.step(label, code, expect)
	sim.check("no distance checks were made in combat", "", "blockedCalls == 0", ["blockedCalls"])
	sim.execute("reset()")

	# translated titles on a German client
	print(" German titles")
	sim.execute('locale = "deDE"')
	sim.load("NPCTitles.lua")
	sim.execute("reset()")
	sim.step("NPC not in the data: Gastwirtin", "reach({guid='Creature-0-1-2-3-999997-00B0'}, {'Neue Wirtin','Gastwirtin'}, true) idle(10)", "outline:Innkeeper")
	sim.step("  leave", "leave() idle(30) tip=false", "glove glow")
	sim.step("Tierausbilder as a druid", "reach({guid='Creature-0-1-2-3-999996-00B1'}, {'Neuer Ausbilder','Tierausbilder'}, true) idle(10)", "nothing")
	sim.step("  leave", "leave() idle(30) tip=false", "glove glow")
	sim.step("Tierausbilder as a hunter", "UnitClass=function() return 'Hunter','HUNTER' end reach({guid='Creature-0-1-2-3-999996-00B1'}, {'Neuer Ausbilder','Tierausbilder'}, true) idle(10)", "outline:Trainer")
	sim.step("  leave", "leave() idle(30) tip=false UnitClass=function() return 'Druid','DRUID' end", "glove glow")
	sim.step("unknown title: no outline", "reach({guid='Creature-0-1-2-3-999995-00B2'}, {'Jemand','Unbekannter Titel'}, true) idle(10)", "nothing")
	sim.execute('reset() locale = "enUS" ns.TITLE_CURSORS = nil ns.TITLE_TRAINER_CLASSES = nil')
