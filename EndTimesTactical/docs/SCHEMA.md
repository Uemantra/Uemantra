# Content schema reference

Every file below lives inside a campaign folder (`campaigns/<id>/`). The engine
(`scripts/autoloads/DataManager.gd`) loads them at startup. JSON is strict — no trailing
commas, no comments. Unknown fields are ignored, so it's safe to leave notes in unused keys
only if you remove them before shipping.

Folder → what loads:

| Path | Loaded as | Keyed by |
|------|-----------|----------|
| `campaign.json` | manifest | — |
| `world.json` | world map | — |
| `npcs/*.json` | NPCs | each file's `id` |
| `npcs/dialogues/*.json` | dialogue | the **filename** (must match the NPC id) |
| `locations/*.json` | locations | `id` |
| `local_maps/*.json` | hex maps | `id` |
| `factions/*.json` | factions | `id` |
| `quests/*.json` | quests | `id` |
| `items/{weapons,armor,consumables,misc}.json` | items | each entry's `id` |
| `perks/perks.json` | perks | each entry's `id` |
| `traits/traits.json` | traits | each entry's `id` |
| `endings/endings.json` | ending slides (optional) | — |

---

## campaign.json (manifest)

Defines campaign identity and the player's starting state (everything that used to be
hardcoded in the engine).

```json
{
  "id": "my_game",
  "name": "My Game",
  "version": "0.1.0",
  "author": "You",
  "description": "One-line pitch.",
  "player_start": {
    "name": "Wanderer",
    "location": "town_square",                 // must be a location id
    "stats": { "grit":5,"reflex":5,"mind":5,"body":5,"nerve":5,"presence":5 },
    "inventory": [
      { "item_id": "rusty_pistol", "quantity": 1, "equipped": true },
      { "item_id": "scrap_bandage", "quantity": 2 }   // equipped defaults to false
    ],
    "caps": 25,
    "time_hours": 8                            // 24h clock; 8 = 08:00 on Day 1
  },
  "default_unarmed_weapon": "rusty_pistol",    // weapon id used when nothing is equipped
  "karma": {                                   // OPTIONAL — overrides karma title bands
    "titles": { "-100":"Villain", "-15":"Troublemaker", "0":"Neutral", "30":"Good-Natured", "100":"Champion" }
  }
}
```

Any omitted `player_start` field falls back to an engine default, but set them all.
`player_start` may also include `"karma": <int>` for a non-zero starting karma. If `karma`
is omitted entirely the engine uses sensible default title bands.

---

## world.json (wasteland map)

```json
{
  "nodes": [
    {
      "id": "town_square",
      "display_name": "Town Square",
      "position": { "x": 400, "y": 300 },      // pixel position on the world map
      "type": "settlement",                     // settlement | hostile_zone | dungeon (cosmetic)
      "unlocked_by_default": true,
      "unlock_flag": null,                      // or a flag id that reveals this node
      "connections": [
        { "to": "other_node", "distance_km": 12, "travel_hours": 4 }
      ]
    }
  ]
}
```

A node id should match a location id of the same name so travel can load its map.

---

## locations/*.json

```json
{
  "id": "town_square",
  "name": "Town Square",
  "type": "settlement",
  "description": "Shown when you arrive.",
  "overworld_position": { "x": 400, "y": 300 },
  "connections": [],                            // location ids (legacy travel; world.json drives travel now)
  "travel_time_hours": {},
  "npcs_present": ["greeter"],                  // npc ids that appear here
  "interactables": [
    { "id": "notice_board", "label": "Notice Board", "action": "read",
      "flags_required": [], "text": "Flavor text." }
  ],
  "combat_arena": null,
  "exploration_map": "town_square_map",         // the local_map id to load
  "ambient_description": "Wind and dust."
}
```

---

## local_maps/*.json (the hex map — explore + combat happen here)

This type is best authored visually in the editor's **Maps** tab (see EDITOR.md) rather
than by hand. The map is a grid of single-char terrain rows plus actors/containers/
examine spots/exits/props placed in **axial hex coordinates** `q` (column) and `r` (row),
where the cell at `terrain[r][q]` is that hex.

```json
{
  "id": "town_square_map",
  "display_name": "Town Square",
  "width": 14, "height": 10,                    // width = row length, height = row count
  "vision_radius": 7,
  "player_start": { "q": 2, "r": 4 },
  "actors": [
    { "id": "greeter_spot", "type": "npc",  "npc_id": "greeter", "q": 7, "r": 4,
      "glyph": "G", "color": "#88bbee", "active_hours": [6, 22] },  // present 06:00–22:00
    { "id": "raider_1",     "type": "enemy","npc_id": "raider",  "q": 22,"r": 9,
      "glyph": "E", "color": "#cc3322", "dead_flag": "raider1_dead" }
  ],
  "containers": [
    { "id": "supply_crate", "q": 10, "r": 6, "glyph": "▫", "color": "#aaaa44",
      "opened_flag": "crate_opened", "locked": false,
      "loot_table": [ { "item_id": "scrap_bandage", "quantity": 1, "chance": 1.0 } ] }
  ],
  "examine_spots": [
    { "id": "fountain", "q": 7, "r": 2, "glyph": "?", "color": "#aaaaaa",
      "title": "Dry Fountain", "text": "Flavor.",
      "skill_use": {                       // OPTIONAL — use a skill on this object
        "skill": "tech", "difficulty": 40, "prompt": "Repair the valve",
        "done_flag": "fountain_fixed",     // set on success; hides the action afterward
        "success": { "text": "...", "flags_set": ["..."], "xp_reward": 40,
                     "caps_reward": 0, "karma_change": 2, "item_rewards": [] },
        "fail": { "text": "..." }          // a failed check can be retried
      } }
  ],
  "exit_zones": [
    { "id": "exit_west", "q": 0, "r": 4, "w": 1, "h": 1, "target": "world" }
  ],
  "props": [ { "prop": "campfire", "q": 5, "r": 6 } ],   // cosmetic only, no collision
  "terrain": [
    "WWWWWWWWWWWWWW",
    "W............W",
    "............W",
    "...etc..."
  ]
}
```

### Terrain characters (from `scripts/systems/TerrainDB.gd`)

| Char | Terrain | Walk | Blocks sight | Cover |
|------|---------|------|--------------|-------|
| `.` | floor | yes | no | none |
| `r` | road | yes | no | none |
| `g` | grass | yes | no | none |
| `_` | interior (building floor) | yes | no | none |
| `o` | partial cover | yes | no | partial |
| `O` | full cover | yes | no | full |
| `+` | rubble | yes | no | partial |
| `#` | obstacle | **no** | yes | none |
| `W` | wall | **no** | yes | none |
| `~` | water | **no** | no | none |
| (space) | void — no hex here | — | — | — |

**Reachability matters:** the player start, every exit, and any actor/container you expect
to interact with must be connected by walkable hexes. To add a new terrain type, edit
`TerrainDB.gd` (one place) — it's engine, not content.

### Prop kinds (cosmetic, from `local_map.gd`)

`shack`/`house`/`building`/`hut`, `wreck`/`car`/`vehicle`, `tent`, `fence`/`barricade`/
`wall_low`, `campfire`/`fire`, `generator`/`machine`/`terminal`/`console`, `tree`,
`dead_tree`, `cactus`, `barrel`, `crate`, `sign`, `chest`.

### Schedules & day/night

An actor may carry `"active_hours": [start, end]` — it is only spawned when the world clock
(0–23) is within that window, which may wrap past midnight (e.g. `[20, 6]` = night only).
The world is automatically tinted by time of day. Don't hide a quest-critical NPC behind
hours the player can't reach.

---

## npcs/*.json

```json
{
  "id": "greeter",
  "name": "Mara",
  "portrait": "res://art/portraits/placeholder.png",
  "faction": "townsfolk",
  "role": "Town greeter",
  "location_default": "town_square",
  "stats": { "grit":4,"reflex":4,"mind":5,"body":4,"nerve":4,"presence":6 },
  "skills_override": {},                 // e.g. { "medicine": 10 } to force a skill value
  "combat_profile": null,                // null = non-combatant; see below for enemies
  "relationship": 0,
  "vendor": null                         // null, or a vendor block (see below)
}
```

**Enemy `combat_profile`** (any NPC used as a map `enemy` needs one): give it `max_hp`,
`equipped_weapon` (a weapon id), `armor_dr` (int), and `ai` behavior. Look at
`campaigns/end_times_tactical/npcs/iron_grunt.json` for a working example.

**Vendor block** (makes the NPC tradeable when reached via an `open_shop` dialogue line):

```json
"vendor": { "sells": ["scrap_bandage", "rusty_pistol"], "markup": 1.0, "buys": true }
```

---

## npcs/dialogues/<npc_id>.json

The filename must equal the NPC id. A file holds multiple **conversations**; the engine
plays the first whose `trigger_conditions` match.

```json
{
  "conversations": [
    {
      "id": "greeter_intro",
      "trigger_conditions": {
        "flags_required": [],
        "flags_excluded": ["met_greeter"],
        "faction_rep": {}                       // e.g. { "townsfolk": 30 } = need rep >= 30
      },
      "entry_node": "n1",
      "nodes": {
        "n1": { "type": "npc_line", "speaker": "greeter", "text": "Hi.", "next": "n2" },
        "n2": {
          "type": "player_choice",
          "choices": [
            { "id": "c1", "text": "Plain reply.", "condition": null, "next": "n3" },
            { "id": "c2", "text": "[Speech 40] Charm them.",
              "condition": { "type": "skill_check", "skill": "speech", "difficulty": 40,
                             "on_fail": "n_fail" },
              "next": "n_pass" },
            { "id": "c3", "text": "Leave.", "condition": null, "next": null }
          ]
        }
      },
      "on_complete": { "flags_set": ["met_greeter"], "quests_started": ["first_steps"] }
    }
  ]
}
```

**Node types:** `npc_line` (one line, `next` → node id or `null` to end) and
`player_choice` (a `choices` array). A choice with `next: null` ends the conversation.

**Choice `condition` types** (from `DialogueManager._filter_visible_choices`):
- `null` — always shown.
- `{ "type": "flag_required", "flag": "x" }` — shown only if flag x is set.
- `{ "type": "flag_excluded", "flag": "x" }` — shown only if flag x is NOT set.
- `{ "type": "faction_rep_min", "faction": "f", "value": 30 }` — needs rep ≥ value.
- `{ "type": "karma_min", "value": 20 }` / `{ "type": "karma_max", "value": -20 }` — gate
  on the player's global karma.
- `{ "type": "skill_check", "skill": "speech", "difficulty": 40, "on_fail": "node" }` —
  always shown; on pick, rolls the skill. Pass → `next`; fail → `on_fail` node.

A conversation's `trigger_conditions` (which one plays) supports the general condition
keys: `flags_required`, `flags_any`, `flags_excluded`, `faction_rep` (min per faction),
`karma_min`, `karma_max`.

**Effects on any node OR on `on_complete`** (from `_apply_node_effects` / `_apply_rewards`):
- `"flags_set": ["a","b"]`
- `"relationship_change": 1` (toward the speaking NPC)
- `"faction_rep_change": { "townsfolk": 5 }` (on_complete only)
- `"quests_started": ["quest_id"]`
- `"caps_reward": 30`, `"xp_reward": 50`, `"item_rewards": [ { "item_id":"x","quantity":1 } ]`
- `"karma_change": 5` (or negative) — shifts the player's global karma.
- `"flags_cleared": ["a","b"]` — sets these flags back to false (counterpart of flags_set).
- `"recruit_companion": "<npc_id>"` / `"dismiss_companion": "<npc_id>"` — add/remove a party
  member. The NPC must have a `combat_profile`.
- `"end_game": true` (or an ending-id string) — rolls the epilogue (see endings below).
- `"open_shop": true` on an `npc_line` — ends the conversation and opens this NPC's vendor.

> **Reactivity rule (hard-won):** any flag a quest depends on must be reachable from a
> **repeatable/returning** conversation, never only from a one-shot first-meeting branch.
> Otherwise a player who misses it is permanently blocked. The template's
> `greeter_returning` conversation shows the pattern.

---

## quests/*.json

```json
{
  "id": "first_steps",
  "title": "First Steps",
  "summary": "Journal text.",
  "xp_reward": 50, "caps_reward": 0, "item_rewards": [],   // granted on full completion
  "stages": [
    {
      "id": "stage_open",
      "title": "Open the crate",
      "description": "Stage detail.",
      "objectives": [
        { "id": "o1", "text": "Open the supply crate",
          "flag_complete": "crate_opened", "optional": false }
      ],
      "completion_condition": { "flags_all": ["crate_opened"] },
      "on_complete": { "flags_set": [], "next_stage": "stage_return" }
    },
    {
      "id": "stage_return",
      "title": "Report back",
      "objectives": [ { "id": "o2", "text": "Talk to Mara",
        "flag_complete": "turned_in", "optional": false } ],
      "completion_condition": { "flags_all": ["turned_in"] },
      "on_complete": { "flags_set": ["first_steps_complete"], "next_stage": null }
    }
  ]
}
```

Quests advance reactively when their `completion_condition` flags become true (set by
dialogue, opening a container with an `opened_flag`, or killing an enemy with a `dead_flag`).
`next_stage: null` ends the quest. `on_complete` blocks (and the quest itself) can also grant
`xp_reward`/`caps_reward`/`item_rewards`/`karma_reward`. A quest with `"ends_game": true`
(top-level) rolls the epilogue when it completes — this is how a main quest ends the game.

---

## factions/*.json

```json
{
  "id": "townsfolk",
  "name": "Townsfolk",
  "description": "...",
  "rep_starting": 0,
  "rep_thresholds": { "hostile":-50,"unfriendly":-20,"neutral":0,
                      "friendly":30,"trusted":60,"exalted":90 },
  "rep_labels": { "-50":"Outcast","0":"Stranger","30":"Known","60":"Friend","90":"Hero" },
  "color": "#6fae6f"
}
```

`rep_labels` keys are threshold values (as strings); the highest threshold the player meets
supplies their displayed standing.

---

## items/*.json

Four files, each wrapping a named array: `weapons.json` → `{ "weapons": [...] }`, etc.
Common fields: `id`, `name`, `type`, `subtype`, `description`, `weight`, `value`.

**weapon:** `ap_cost`, `damage_dice` (e.g. `"1d8"`), `damage_bonus`, `range_tiles`,
`skill_used` (`guns`/`melee`), `ammo_type` (id or `null`), `ammo_per_shot`, `clip_size`,
`effects` (e.g. `[{ "type":"poison_chance","value":25 }]`). Optional **burst** fields make
a weapon automatic: `"burst": 5` (rounds sprayed per burst — adds a Burst button that costs
`"burst_ap_cost"` AP, defaults to ap_cost+3, with a per-round accuracy penalty and consuming
up to that many rounds of ammo).

**ammo** (a `misc` item referenced by a weapon's `ammo_type`) may carry damage-type
modifiers applied on every hit: `"dr_mod": -2` (negative = armor-piercing, ignores that
much target DR) and `"dmg_mult": 1.2` (hollow-point, scales damage). Omit for plain ammo.

**armor:** `defense_bonus` (int), `evasion_mod` (int), `subtype` (`light`/`medium`/`heavy`).

**consumable:** `effects` — `[{ "type":"heal_hp","value":20 }]`,
`{ "type":"remove_status","status":"bleed" }`, `{ "type":"apply_status","status":"...","duration":n }`.

**misc:** just the common fields (ammo, junk, quest items). Ammo ids referenced by a
weapon's `ammo_type` live here.

---

## perks/perks.json and traits/traits.json

Both wrap a list: `{ "perks": [...] }` / `{ "traits": [...] }`. An empty list is valid.

```json
{ "id": "gunslinger", "name": "Gunslinger", "description": "...",
  "requirements": { "level": 3, "stats": { "reflex": 6 }, "skills": { "guns": 50 } },
  "effects": [ { "type": "hit_bonus", "subtype": "guns", "value": 10 } ] }
```

Traits add a `pro`/`con` framing but use the same `effects`. **Effect types** (resolved in
`GameState`): `skill_bonus` (+`skill`), `skill_bonus_all`, `stat_bonus` (+`stat`),
`max_hp_bonus`, `max_ap_bonus`, `carry_bonus`, `hit_bonus` (+`subtype` guns/melee/all),
`crit_chance_bonus`, `crit_damage_bonus`, `damage_flat_bonus` (+`subtype`), `dr_bonus`,
`ranged_ap_reduction`, `no_aimed`, `bonus_heal_pct`. See
`campaigns/end_times_tactical/perks/perks.json` for 13 worked examples.

---

## endings/endings.json (epilogue slides — optional)

Fallout-style closer: when the game ends (a quest with `ends_game`, or a dialogue node with
`end_game`), the ending screen plays every slide whose `conditions` the final game state
satisfies, in order, then returns to the main menu.

```json
{
  "slides": [
    { "id": "intro", "always": true, "title": "...", "text": "..." },
    { "id": "council_ally", "conditions": { "faction_rep": { "the_council": 30 } },
      "title": "Haven Ridge", "text": "..." },
    { "id": "infamous", "conditions": { "karma_max": -30 }, "title": "...", "text": "..." }
  ]
}
```

A slide shows if `"always": true` **or** its `conditions` pass. **Condition keys** (the
shared `ConditionChecker` set, usable here, in dialogue `trigger_conditions`, and anywhere
the engine evaluates conditions):

- `flags_all` (or `flags_required`) — every listed flag must be set.
- `flags_any` — at least one must be set.
- `flags_excluded` — none may be set.
- `karma_min` / `karma_max` — inclusive karma bounds.
- `faction_rep` — `{ faction_id: min }`, rep must be ≥ min.
- `faction_rep_max` — `{ faction_id: max }`, rep must be ≤ max (for "you angered them" slides).

If there's no `endings/endings.json`, the engine shows one neutral default slide. The
**Karma** standing (titles configurable in the manifest) is shown on the ending screen.
