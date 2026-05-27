class_name SkillCheck
extends RefCounted

# Returns { passed, roll, difficulty, skill, player_value }
static func resolve(skill: String, difficulty: int) -> Dictionary:
	var player_skill: int = GameState.skills.get(skill, 0)
	var roll := player_skill + randi_range(-5, 10)
	var passed := roll >= difficulty
	return {
		"passed":       passed,
		"roll":         roll,
		"difficulty":   difficulty,
		"skill":        skill,
		"player_value": player_skill,
	}
