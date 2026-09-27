# Cursor Glow Forever

## 1.0.1

- Fixed: hovering a skinnable corpse, ore or herb without the matching profession drew a skinning, mining or herb outline around the normal cursor. Gathering outlines now only show when the game really shows the gathering cursor.
- Fixed: hovering an enemy's nameplate (or any other UI frame showing a unit) drew a sword outline around the normal cursor, and moving between a nameplate and its enemy left the glow a step behind. The nameplate is now recognised directly and treated like the UI: normal cursor there, the sword on the enemy itself.
- Fixed: an NPC offering or taking in a quest shows the quest cursor over its service one, but got the vendor/repair/... outline. The game doesn't tell addons which NPCs have quests, so they are learned when you talk to them (per character) and get no outline until they have no quests left.
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
