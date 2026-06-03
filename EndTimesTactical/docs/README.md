# End Times Tactical — a Fallout-style game frame

This is a **game frame**, not just one game. The engine (built in Godot 4.6) provides the
parts that make a Fallout-1/2-style RPG work — turn-based AP hex combat, branching
dialogue with skill checks, a SPECIAL-style stat/skill system, perks & traits, flag-driven
quests, faction reputation, a wasteland world map, vendors, and saves — and **all the
content lives in plain JSON** so you can build an entirely different game without touching
the engine code.

The game that ships with it ("End Times Tactical") is just the **first campaign**. Yours
sits right next to it.

## Repository layout

```
campaigns/
  active.txt                 # one line: the id of the campaign to load
  end_times_tactical/        # the shipped game (a campaign)
  _template/                 # a blank starter — copy this to begin your own
scripts/                     # engine code (GDScript autoloads + systems) — campaign-agnostic
scenes/                      # engine scenes (menus, world map, local map, UI) — campaign-agnostic
assets/                      # shared art, fonts, audio, UI theme
editor/editor.html           # browser tool for authoring content (see docs/EDITOR.md)
docs/                        # you are here
```

## 60-second quick start (make your own game)

1. Copy `campaigns/_template/` to `campaigns/my_game/`.
2. Open `campaigns/my_game/campaign.json` and set the `id` to `my_game`, plus name/author.
3. Put `my_game` on the single line of `campaigns/active.txt`.
4. Run the project in Godot (or the packaged build). You now boot into **your** campaign.
5. Start editing the JSON in `campaigns/my_game/` — see **[AUTHORING.md](AUTHORING.md)**.

To switch back to the shipped game, put `end_times_tactical` in `active.txt`.

## Documentation

- **[AUTHORING.md](AUTHORING.md)** — how to build a campaign: the manifest, adding a
  location + map + NPC + dialogue + quest, how flags drive reactivity, common pitfalls.
- **[SCHEMA.md](SCHEMA.md)** — exact JSON schema for every content type.
- **[EDITOR.md](EDITOR.md)** — the browser editor: what it covers today and what still
  needs hand-editing.

## Verifying changes

The project is validated headless with the Godot 4.6.3 executable. From the project root:

```
godot --headless --path . res://scenes/main_menu.tscn
```

A clean boot with no script errors means your content loaded. For a real check, run the
game and play through your content — nothing is "done" until it's been played.
