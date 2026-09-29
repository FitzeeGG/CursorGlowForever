# Cursor Glow Forever

## 1.0.2

- New option "Shake to find" (on by default): shake the mouse quickly side to side and a bright halo bursts out around the cursor, fading over a second. A "Shakes needed" slider sets how many direction changes in a row it takes (5 by default, 2 to 10).
- New option "Pulse in combat" (on by default): while you're in combat the glow gently pulses brighter, with a soft halo. Untick "Pulse uses glow colour" to pick a pulse colour, such as red, that the glow takes on as it pulses.
- Fixed: faint square lines at the edges of the glow. The glow texture now fades out completely before its edges.
- Fixed: hovering a target from too far away and then walking into range kept the normal glow instead of the hover outline. The outline now appears when the target's cursor does as you approach, and goes away again if you walk far away (beyond follow range), without mistaking an NPC's longer interaction range for that.
- Fixed: walking in or out of range of a target while following it with the mouse flipped the glow (the normal glow showed around the target's cursor). While you or the target are moving, a cursor change on the same target is now read as a range change.
- Fixed: vendors who also repair (a Bowyer, for example) got the vendor bag outline instead of the repair anvil. Service NPCs are now recognised from built-in data of their services (from QuestieDB's Forever data), with the title as a fallback for NPCs new to Forever.
- Fixed: a Lua taint warning from checking nameplates (some are restricted and can't be measured). Nameplates are no longer measured.
- Fixed: moving straight from one hover target to another (an innkeeper to a chair, for example) could show the normal glow. NPC titles are recognised for this even with "Outline vendors and services" off, and the addon learns which objects have their own cursor when you hover them from open ground.

## 1.0.1

- New option "Outline vendors and services" (off by default): outlines on vendors, repairers, bankers, innkeepers, flight masters, stable masters and trainers are now optional, since an NPC with a quest for you shows the quest cursor instead and that can't always be told in advance.
- Fixed: hovering a skinnable corpse without Skinning drew a skinning outline around the normal cursor. The addon now reads your professions and only shows the skinning outline if you have Skinning. Ore and herbs show their cursor with or without Mining and Herbalism, so they keep their outline; gathering outlines only show when the game really shows the gathering cursor.
- Fixed: hovering an enemy's nameplate (or any other UI frame showing a unit) drew a sword outline around the normal cursor, and moving between a nameplate and its enemy left the glow a step behind. The nameplate is now recognised directly and treated like the UI: normal cursor there, the sword on the enemy itself.
- Fixed: an NPC offering or taking in a quest shows the quest cursor over its service one, but got the vendor/repair/... outline. The game doesn't tell addons which NPCs have quests, so the addon ships a list of the 321 vendors, trainers, innkeepers and other service NPCs that give quests (from QuestieDB's Forever data), and learns when you talk to an NPC whether it has quests for you (per character). Quest givers get no outline until they have no quests left.
- Fixed: the loot cursor (a pair of bags) got the outline of a single bag. Hover outlines now also switch to the greyed version of their cursor while out of range.
- Fixed: holding Shift over a corpse swaps the pair of loot bags for a single bag, but the outline kept the pair's shape. The outline now follows the single bag while Shift is held, and cursor changes from other modifier keys are recognised too.
- Fixed: hovering an enemy that doesn't change the cursor drew a sword outline around the normal one. Outlines now only appear when the game actually changes the cursor; recognising the target just picks the outline's shape.

## 1.0.0

First release, for World of Warcraft: Forever.

- Glow around the base cursor, in your class colour or a custom colour.
- Outlines on hover cursors (loot, ore, herbs, skinning, enemies, mailboxes, bankers, vendors, repairers, innkeepers, flight masters, stable masters, trainers), cut from the game's own cursor art.
- Out-of-range dimming of hover outlines on NPCs and corpses.
- Glove drawn with a stronger, tinted glow while the camera is turned with the mouse, with its own colour option.
- Movement prediction so the glow keeps up with the cursor.
- Handles vendor selling, repair mode and alt-tabbing.
- Settings panel (/cg, /cursorglow or /cursorglowforever) and a debug mode (/cg debug).
