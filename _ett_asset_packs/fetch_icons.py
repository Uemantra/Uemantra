import os, re, urllib.request

OUT = r"F:\Git\Uemantra\EndTimesTactical\assets\sprites\items"
os.makedirs(OUT, exist_ok=True)
RAW = "https://raw.githubusercontent.com/game-icons/icons/master/%s.svg"
TINT = "#ece3cf"   # warm parchment to match the UI

# item_id -> game-icons "author/name" (CC-BY 3.0)
MAP = {
    # weapons
    "pistol_9mm":            "john-colburn/pistol-gun",
    "pipe_rifle":            "sbed/rifle",
    "sawed_off_shotgun":     "delapouite/sawed-off-shotgun",
    "pipe_sledge":           "delapouite/stake-hammer",
    "combat_knife":          "lorc/broad-dagger",
    "bare_hands":            "lorc/fist",
    # misc
    "ammo_9mm":              "delapouite/heavy-bullets",
    "ammo_308":              "delapouite/heavy-bullets",
    "ammo_shotgun":          "delapouite/shotgun-rounds",
    "scrap_metal":           "lorc/metal-bar",
    "council_pass":          "delapouite/id-card",
    "signal_fragment":       "lorc/papers",
    # consumables
    "stimpak":               "lorc/syringe",
    "field_dressing":        "lorc/bandage-roll",
    "rad_tabs":              "delapouite/medicine-pills",
    "cram_tin":              "delapouite/canned-fish",
    "stim_shot_adrenaline":  "sbed/syringe",
    # armor
    "worn_clothes":          "delapouite/clothes",
    "scav_vest":             "lorc/armor-vest",
    "leather_jacket":        "lorc/leather-vest",
    "iron_covenant_plate":   "lorc/breastplate",
}

def process(svg: str) -> str:
    # drop the full-square background rect -> transparent
    svg = re.sub(r'<path d="M0 0h512v512H0z"\s*/>', "", svg)
    # recolor white foreground -> parchment, and give the root a fallback fill
    svg = svg.replace('fill="#fff"', f'fill="{TINT}"').replace('fill="#FFF"', f'fill="{TINT}"')
    svg = svg.replace("<svg ", f'<svg fill="{TINT}" ', 1)
    return svg

ok, fail = [], []
authors = set()
for item_id, path in MAP.items():
    try:
        req = urllib.request.Request(RAW % path, headers={"User-Agent": "claude"})
        raw = urllib.request.urlopen(req, timeout=30).read().decode("utf-8")
        with open(os.path.join(OUT, item_id + ".svg"), "w", encoding="utf-8") as f:
            f.write(process(raw))
        ok.append(item_id)
        authors.add(path.split("/")[0])
    except Exception as e:
        fail.append("%s (%s): %s" % (item_id, path, e))

print("OK:", len(ok))
print("FAIL:", fail if fail else "none")
print("authors:", sorted(authors))
