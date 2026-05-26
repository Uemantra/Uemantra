extends RefCounted

# Ordered best to worst — base probability of useful yield from a media type.
const CONDITION_RATINGS: Dictionary = {
	"paper":         0.95,
	"optical":       0.82,
	"magnetic_tape": 0.65,
	"flash":         0.35,
	"ssd":           0.12,
}

const FLOOR: float = 0.05
const AGE_PENALTY_PER_DECADE: float = 0.03


func calculate_yield_probability(media_type: String, age_years: int) -> float:
	if media_type not in CONDITION_RATINGS:
		return FLOOR
	var base: float = CONDITION_RATINGS[media_type]
	# Paper is archival if kept dry. Age does not degrade it further in practice.
	if media_type == "paper":
		return base
	var penalty: float = (age_years / 10) * AGE_PENALTY_PER_DECADE
	return maxf(base - penalty, FLOOR)


func get_condition_description(media_type: String) -> String:
	match media_type:
		"paper":
			return "Paper holds. It always held, if you kept it dry."
		"optical":
			return "Disc rot is real but slow. If the case kept the moisture out, there's still something here."
		"magnetic_tape":
			return "Fragile. The coating flakes if it was stored warm. You won't know until you run it."
		"flash":
			return "Flash degrades without power. Years of sitting dark eat the charge. Odds are poor."
		"ssd":
			return "Consumer SSDs weren't built for this. The cells bleed off. What's left is fragments, if anything."
		_:
			return "Condition unknown."
