class_name CombatCalc
extends RefCounted

const AP_MOVE := 1  # AP cost to enter one hex

# ─── Shot modes ───────────────────────────────────────────────────────────────
const QUICK_SHOT_AP_COST  := 2
const QUICK_SHOT_PEN      := 25   # subtracted from hit chance
const AIMED_SHOT_AP_COST  := 4
const AIMED_SHOT_BONUS    := 20   # added to hit chance (passed as negative penalty)
const MELEE_AP_COST       := 3
const RELOAD_AP_COST      := 2
const USE_ITEM_AP_COST    := 2
const BLEED_DAMAGE        := 2    # HP lost per bleed tick


# ─── Dice ─────────────────────────────────────────────────────────────────────

static func parse_dice(dice_str: String) -> Dictionary:
	var bonus := 0
	var s := dice_str
	if "+" in s:
		var parts := s.split("+", false, 1)
		s     = parts[0]
		bonus = int(parts[1])
	var d_parts := s.split("d", false, 1)
	return {
		"count": int(d_parts[0]),
		"sides": int(d_parts[1]) if d_parts.size() > 1 else 1,
		"bonus": bonus,
	}


static func roll_dice(parsed: Dictionary) -> int:
	var total: int = parsed["bonus"]
	for _i in parsed["count"]:
		total += randi_range(1, parsed["sides"])
	return total


# ─── Weapon helpers ───────────────────────────────────────────────────────────

static func weapon_ap_cost(weapon: Dictionary) -> int:
	return weapon.get("ap_cost", 3) if not weapon.is_empty() else 3

static func weapon_range(weapon: Dictionary) -> int:
	return weapon.get("range_tiles", 1) if not weapon.is_empty() else 1

static func weapon_skill_id(weapon: Dictionary) -> String:
	return weapon.get("skill_used", "melee") if not weapon.is_empty() else "melee"

static func weapon_clip_size(weapon: Dictionary) -> int:
	return weapon.get("clip_size", 0) if not weapon.is_empty() else 0

static func weapon_needs_ammo(weapon: Dictionary) -> bool:
	return weapon.get("ammo_per_shot", 0) > 0 if not weapon.is_empty() else false


# ─── Hit resolution (Fallout-inspired) ───────────────────────────────────────

static func hit_chance(base_skill: int, dist: int, w_range: int,
		aimed_penalty: int, cover_penalty: int) -> int:
	var range_pen: int = maxi(0, (dist - w_range) * 4)
	return clampi(base_skill - range_pen - aimed_penalty - cover_penalty, 5, 95)


static func roll_hit(chance: int) -> bool:
	return randi_range(1, 100) <= chance


static func is_critical(crit_chance: int) -> bool:
	return randi_range(1, 100) <= crit_chance


static func roll_effect(chance: float) -> bool:
	return randf() <= chance


# ─── Damage ───────────────────────────────────────────────────────────────────

static func roll_damage(weapon: Dictionary, body_stat: int) -> int:
	@warning_ignore("integer_division")
	var body_bonus: int = body_stat / 3
	if weapon.is_empty():
		return randi_range(1, 2) + body_bonus
	var dice_str: String = weapon.get("damage_dice", "1d3")
	var rolled: int      = roll_dice(parse_dice(dice_str))
	var dmg_bonus: int   = weapon.get("damage_bonus", 0)
	return rolled + dmg_bonus + body_bonus


static func apply_dr(raw: int, dr: int) -> int:
	return max(1, raw - dr)


# ─── Initiative ───────────────────────────────────────────────────────────────

static func roll_initiative(stats: Dictionary) -> int:
	return 2 * stats.get("mind", 5) + stats.get("reflex", 5) + randi_range(0, 5)


# ─── Rewards ─────────────────────────────────────────────────────────────────

static func kill_xp(npc_data: Dictionary) -> int:
	return npc_data.get("xp_value", 50)
