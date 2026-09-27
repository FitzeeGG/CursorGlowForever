# Cursor Glow Forever

## 1.0.2

- Fixed: hovering an enemy's nameplate (or any other UI frame showing a unit) drew a sword outline around the normal cursor. Over UI frames the cursor is now treated as the normal one, unless the UI sets its own (selling, repair).

## 1.0.1

- Fixed: hovering a skinnable corpse, ore or herb without the matching profession drew a skinning, mining or herb outline around the normal cursor. Gathering outlines now only show when the game really shows the gathering cursor.

## 1.0.0

First release, for World of Warcraft: Forever.

- Glow around the base cursor, in your class colour or a custom colour.
- Outlines on hover cursors (loot, ore, herbs, skinning, enemies, mailboxes, bankers, vendors, repairers, innkeepers, flight masters, stable masters, trainers), cut from the game's own cursor art.
- Out-of-range dimming of hover outlines on NPCs and corpses.
- Glove drawn with a stronger, tinted glow while the camera is turned with the mouse, with its own colour option.
- Movement prediction so the glow keeps up with the cursor.
- Handles vendor selling, repair mode and alt-tabbing.
- Settings panel (/cg, /cursorglow or /cursorglowforever) and a debug mode (/cg debug).
