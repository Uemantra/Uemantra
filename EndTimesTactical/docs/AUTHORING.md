# Authoring a campaign

This walks you through building your own game on the frame. It assumes you've read the
quick start in [README.md](README.md). For exact field-by-field details of any file, see
[SCHEMA.md](SCHEMA.md).

## 1. Create the campaign

Copy `campaigns/_template/` to `campaigns/my_game/`. The template is a tiny but complete,
playable campaign: one town (`town_square`), one NPC (Mara the greeter) with branching
dialogue and a vendor-free conversation, one two-stage quest (`first_steps`), a supply
crate, and minimal items. Use it as a reference you can edit in place rather than a blank
page.

Edit `campaigns/my_game/campaign.json`:
- Set `id` to `my_game` (must match the folder name).
- Set `name`, `author`, `description`.
- Set `player_start` — the player's name, starting `location`, `stats`, `inventory`,
  `caps`, and `time_hours`. Every `item_id` in the starting inventory must exist in your
  `items/` files.

Put `my_game` on the one line in `campaigns/active.txt`. Run the project — you're in your
campaign.

## 2. The mental model

A campaign is a graph of **flags**. Almost everything reacts to flags:

- Dialogue choices appear/branch on flags (and skills, and faction rep).
- Quests advance when their flags become true.
- World-map nodes unlock on a flag.
- Containers set a flag when opened; enemies set a flag when killed.

So designing content is mostly: *decide the flags, then decide what sets them and what
reads them.* There is no scripting — you wire behavior by naming flags consistently across
JSON files.

## 3. Add a location and its map

1. **`locations/<id>.json`** — the place: its name, description, which NPCs are present
   (`npcs_present`), and which hex map it uses (`exploration_map`).
2. **`local_maps/<map_id>.json`** — the actual playable hex grid: terrain rows, the
   player start, NPC/enemy placements, containers, examine spots, exits, and cosmetic props.
   Easiest authored in the editor's **Maps** tab (visual painter).
3. **`world.json`** — add a node so the player can travel there. Give it `connections` to
   other nodes with `distance_km`/`travel_hours`. Set `unlocked_by_default` or an
   `unlock_flag`.

**Reachability is the #1 map mistake.** Every walkable thing — player start, exits, the
NPCs and containers you want reached — must connect through walkable hexes (`.` `r` `g` `_`
`o` `O` `+`), not be fenced off by `#`/`W`/`~`. Walk your map mentally, or count on a quick
playtest. The **Maps** tab in the browser editor (see [EDITOR.md](EDITOR.md)) is a visual
painter for exactly this — paint terrain and place entities by clicking cells, instead of
hand-writing character grids.

## 4. Add an NPC with dialogue

1. **`npcs/<id>.json`** — stats, faction, role, default location, optional `vendor`. If the
   NPC is an enemy you place on a map, give it a `combat_profile`.
2. **`npcs/dialogues/<id>.json`** — the filename **must match the NPC id**. Build
   conversations out of `npc_line` and `player_choice` nodes (see SCHEMA.md for node and
   condition shapes).
3. Reference the NPC from a location's `npcs_present` and place an `actor` of `type: npc`
   on that location's map.

### The reactivity rule you must follow

> Any flag a quest depends on must be reachable from a **repeatable/returning**
> conversation, not only from a one-shot first-meeting branch.

If a quest-critical flag can only be set during a player's first conversation with someone,
a player who clicks past it is permanently stuck. The fix is the pattern the template uses:
the first-meeting conversation is excluded once `met_<npc>` is set, and a second
"returning" conversation (triggered by `met_<npc>`) always offers the critical path again.
Always provide a skill-free alternate route to any progression that's gated behind a skill
check.

## 5. Add a quest

Create `quests/<id>.json` with `stages`. Each stage has a `completion_condition`
(`flags_all`) and an `on_complete` that sets flags and names the `next_stage`
(`null` ends the quest). Start the quest from a dialogue node's `quests_started`.

Wire the completion flags to something the player does:
- A dialogue node `flags_set` (talked to someone, made a choice).
- A container `opened_flag` (looted a cache).
- An enemy `dead_flag` (killed a target).

Rewards (`xp_reward`, `caps_reward`, `item_rewards`) can sit on a stage's `on_complete`, the
whole quest, or a dialogue node — wherever the payoff belongs.

## 6. Wire a vendor (optional)

Give the NPC a `vendor` block (`sells`/`markup`/`buys`). Then add an `npc_line` node with
`"open_shop": true` to a conversation — picking Continue on that line opens the shop. Put
the open_shop line inside a **repeatable** conversation so trading works on every visit.

## 7. Items, perks, traits

- **Items** live in `items/{weapons,armor,consumables,misc}.json`. Add entries to the array
  in the relevant file. Ammo for a gun is a `misc` item whose id matches the weapon's
  `ammo_type`.
- **Perks** (`perks/perks.json`) and **traits** (`traits/traits.json`) are optional —
  empty lists are fine. They're data-driven via an effect catalog (see SCHEMA.md). The
  shipped campaign's `perks.json` has 13 worked examples to copy from.

## 8. Consequences: karma and endings

Two systems make choices *matter*:

- **Karma** — a global good/evil score. Shift it from a dialogue node or `on_complete`
  (`"karma_change": 5`) or a quest (`"karma_reward": 5`), and from killing NPCs that carry
  `"karma_on_kill": -5` (e.g. murdering townsfolk). Gate dialogue choices on it with a
  `karma_min`/`karma_max` condition. Title bands are configurable in the manifest.
- **Endings** — author `endings/endings.json` (see SCHEMA.md): a list of epilogue slides,
  each shown when its `conditions` match the final game state (flags, karma, faction rep).
  Trigger the epilogue by giving your **main quest** `"ends_game": true`, or a final
  dialogue node `"end_game": true`. The ending screen plays the matching slides in order,
  then returns to the main menu. This is the payoff that makes branching choices land —
  write a slide for each meaningful way the player could have left their mark.

## 8b. Companions, world-object skills, schedules

- **Companions** — recruit a party member from a dialogue node with
  `"recruit_companion": "<npc_id>"` (and `"dismiss_companion": "<npc_id>"` to part ways).
  The NPC **must have a `combat_profile`** (max_hp, ap_per_turn, weapon_id, armor_id) — that's
  what they fight with. Companions join your side in combat, take AI turns, and are removed
  from the party permanently if they fall. Place the recruitable NPC on a map like any other.
  See `dusty_vane` in the shipped campaign for a full example (intro → join → dismiss → rejoin,
  using `flags_cleared` to toggle their in-party conversation).
- **World-object skills** — give an `examine_spot` a `skill_use` block (skill, difficulty,
  success/fail outcomes) so the player can Repair/Hack/Treat it. Great for terminals,
  generators, traps, wounded NPCs. See the Haven Ridge water tower (Tech) for an example.
- **NPC schedules / day-night** — give a map actor `"active_hours": [start, end]` so it's
  only present during those hours (wraps past midnight, e.g. `[20, 6]`). The world is tinted
  by time of day automatically. Don't gate a quest-critical NPC behind hours the player can't
  reach.

## 9. Test

Boot headless to catch load errors:

```
godot --headless --path . res://scenes/main_menu.tscn
```

Then actually play it. Watch for: unreachable map tiles, dialogue dead-ends, quests that
never advance (usually a flag-name typo between the setter and the reader), and starting
items that don't exist. The frame is forgiving about missing optional fields but not about
mismatched ids — keep ids consistent.

## Common pitfalls

- **Flag name typos** — the setter and reader must match exactly. Flags are just strings;
  nothing warns you if they don't line up.
- **Dialogue filename ≠ NPC id** — the dialogue won't load.
- **Unreachable map content** — walled-off exits/NPCs.
- **Quest-critical flag only on a first-meeting branch** — see the reactivity rule.
- **Skill-gated progression with no alternate** — always provide a non-skill route.
- **Saves are per-campaign** — they live at `user://saves/<campaign_id>.json`. Switching the
  active campaign loads a different save; it won't clobber another campaign's.
