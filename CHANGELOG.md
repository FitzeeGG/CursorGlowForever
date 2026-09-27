# Cursor Glow Forever

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
