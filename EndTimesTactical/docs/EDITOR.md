# The browser editor

`editor/editor.html` is a single-file, offline browser tool for authoring an entire
campaign without hand-writing JSON. Open it directly in any browser — no server, no build
step.

## Workflow

1. Set the **Campaign id** field in the toolbar (e.g. `my_game`). This is the folder your
   export targets and the id you put in `campaigns/active.txt`. (Importing a folder sets it
   for you from the manifest.)
2. **Import Campaign Folder** — pick a campaign folder (the one containing `campaign.json`)
   and the editor loads the whole thing at once: it auto-detects every file's type and
   replaces the editor's current contents. This is the easiest way to edit an existing
   campaign — e.g. point it at `campaigns/end_times_tactical/`. (Supported in Chromium,
   Edge, and Firefox.) Use **Import File(s)** instead to merge in one or more individual
   JSON files without clearing what's loaded.
3. Edit via the tabs (below). Click or hover any field to see help text in the bottom bar.
4. **Save to LocalStorage / Load Saved** — keep work-in-progress in the browser.
5. **Export Campaign** — downloads a bundle JSON. Each key under `files` is a path like
   `campaigns/<id>/npcs/foo.json`; write each entry's string to that path in your project,
   then set `campaigns/active.txt` to your campaign id and run the game.

## Tabs — full campaign coverage

- **Campaign** — the `campaign.json` manifest: identity and the player's starting state
  (name, location, stats, starting inventory, caps, time, default weapon).
- **World** — `world.json` nodes: the wasteland-map stops and the roads between them.
- **Factions** — rep thresholds and labels.
- **Items** — weapons, armor, consumables (effect editor), misc.
- **Locations** — description, overworld position, NPCs present, interactables.
- **Maps** — a visual **hex-map painter**: pick a terrain or entity brush and click cells.
  Paints all terrain types (floor/road/grass/interior/cover/rubble/obstacle/wall/water/void),
  places the player start, NPCs, enemies (with auto `dead_flag`), containers (with
  `opened_flag` + a loot editor), examine spots, exit zones, and cosmetic props. Resize the
  grid live; painted content is preserved. This is the one content type that was previously
  impossible to author without hand-writing character grids.
- **NPCs** — stats, combat profile, and a Vendor/Shop section.
- **Quests** — stages, objectives, completion flags, on_complete next-stage/flags.
- **Dialogue** — conversations, `npc_line`/`player_choice` nodes, choices with conditions,
  and the "Opens trade/shop" toggle.
- **Perks** — requirements (level/stats/skills) and a typed effect editor.
- **Traits** — the same effect editor (chosen at character creation).

## Known gaps / things to still mind

- **Reachability** — the painter doesn't yet flag an unreachable exit or NPC. Walk your map
  mentally or playtest after authoring (the engine's only hard rule for maps).
- **Newer dialogue/quest reward hooks** — `quests_started`, `item_rewards`, `caps_reward`,
  `xp_reward`, and `faction_rep_change` on nodes are not all surfaced in the dialogue form
  yet; add them by hand in JSON if needed (see SCHEMA.md).
- The editor edits content; it doesn't write files to disk (browsers can't). Use the export
  bundle to move content into your campaign folder.
