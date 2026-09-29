# Cursor Glow Forever

**Never lose your cursor again.** Cursor Glow Forever wraps your mouse cursor in a soft glow in your class colour, outlines the game's hover cursors, and keeps your cursor on screen while you turn the camera. Built for **World of Warcraft: Forever**.

---

## Why Cursor Glow Forever?

In busy fights, crowded towns and dark dungeons, the small glove cursor is easy to lose. Cursor Glow Forever makes it stand out without changing how it looks: the game's own cursor stays exactly as it is, with a glow and outline drawn around it.

## Features

### A glow that fits your cursor
- A soft glow and a crisp outline shaped to the glove cursor itself, not a generic circle.
- Your **class colour** by default, so it changes with each character, or any **custom colour** you like.
- Adjustable glow and outline strength, and a glow size from tight to wide.

### Hover cursors outlined too
When the cursor changes as you hover something, the outline follows it:
- **Loot** bags, **ore**, **herbs** and **skinning**
- **Enemies** (the sword)
- **Mailboxes** and the **guild bank**
- **Vendors, bankers, repairers, innkeepers, flight masters, stable masters** and **trainers** (optional, off by default)
- **Selling from your bags** at a vendor, and **repair mode**

Each outline is cut from the game's own cursor art, so it always matches what you see. If it can't tell which cursor is showing, it simply shows no outline rather than a wrong one.

### Out-of-range dimming
The outline on NPCs and corpses is fainter while they're too far away to interact with, and returns to full strength as soon as you're in range, in step with the game's own "unable" cursor.

### Your cursor, even while turning the camera
Hold the left or right mouse button and the game hides your cursor. Cursor Glow Forever draws the glove where your mouse was, with a stronger glow and a tint of your colour (or its own colour), so you always know where it'll come back.

### Shake to find, and a pulse in combat
Lost it anyway? Shake the mouse quickly side to side and a bright halo bursts out around the cursor; you choose how many shakes it takes. Turn on the combat pulse and the glow gently pulses while you fight, so it's easy to keep track of, in your glow colour or a colour of its own (a tinge of red, say, to show you're in combat).

### Only when you want it
Show the glow all the time, only in combat, or only out of combat. Turn on the idle pulse and, after a few seconds without moving the mouse, the glow slowly fades out and back in (the outline stays) until you move it again.

### Keeps up with you
The glow is placed where your cursor is heading, so it stays on the cursor during fast movement. It also copes cleanly with alt-tabbing and loading screens.

## Settings

Open them with **/cg** (or **/cursorglow**), or from **Esc > Options > AddOns > Cursor Glow Forever**. A live preview at the top shows your cursor and the glove drawn while turning the camera as you change them. Settings are account-wide, or per character if you tick "Settings for this character only".

| Appearance | Behaviour |
|---|---|
| Class colour or custom colour | Show always, in combat or out of combat |
| Glow opacity and glow size | Hide the glow on hover targets |
| Outline opacity | Outline hover cursors, and vendors and services |
| Cursor size (follows the game setting) | Dim outlines out of range, and how faint |
| Movement prediction | Draw the glove while turning the camera |
| Shake to find, and shakes needed | Glove colour and tint |
| Pulse in combat, and its colour | Glow intensity while turning |
| Reset to defaults | Pulse when idle |
| Settings for this character only | |

## Commands

- `/cg` or `/cursorglow`: open the settings
- `/cg debug`: show what the addon sees, for bug reports

## Good to know

- The game doesn't tell addons which cursor it's showing, so the addon works it out from what's under your mouse. Known NPCs are recognised by their ID in any language. NPCs new to Forever are recognised by their title (Vendor, Banker, Innkeeper...): on English clients by keywords, and on German, French, Spanish, Portuguese, Russian, Korean and Chinese clients by the titles in the game's translated NPC data.
- Objects such as mailboxes and ore aren't dimmed out of range, because the game gives no way to tell whether you start in range.
- An NPC offering a quest shows the quest cursor instead of its service one, and the game doesn't tell addons which NPCs have quests. Cursor Glow Forever ships a list of the vendors, trainers, innkeepers and other service NPCs that give quests, and learns from talking to them whether they still have quests for you. NPCs new to Forever aren't in the list yet, so the first time you hover one of those that gives quests it may still show its service outline.

## Found a bug?

Please leave a comment with a screenshot of the cursor and the output of `/cg debug` while it happens. That shows exactly what the game reported.

## Credits

Inspired by [CursorMod](https://www.curseforge.com/wow/addons/cursormod) by sfmict, whose midnight glow this addon's glow is modelled on. The list of quest-giving NPCs comes from the Forever data of [QuestieDB](https://github.com/Questie/QuestieDB), with thanks to the Questie team. Cursor Glow Forever is open source under the GNU GPL v3.


[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/fitzee)
