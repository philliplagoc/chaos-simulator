class_name CitizenBrain
extends RefCounted
## Utility scoring: every goal gets a score from the citizen's needs and the
## clock, and the highest score wins. Pure functions, no randomness.

const GOALS: Array[StringName] = [&"work", &"deliver", &"home", &"cafe", &"bank", &"shop", &"park"]


static func scores(d: CitizenData, minute: float) -> Dictionary:
	var s := {}
	for g in GOALS:
		s[g] = 0.0
	var in_shift := d.shift_start >= 0 and minute >= d.shift_start - 45 and minute < d.shift_end
	if in_shift:
		s[&"deliver" if d.profession == &"delivery_driver" else &"work"] = 100.0
	var night := minute >= 21 * 60 or minute < 6 * 60 + 30
	s[&"home"] = 90.0 if night else 15.0
	if minute >= 6 * 60 + 30 and minute < 20 * 60:
		s[&"cafe"] = d.hunger * 0.9
	if d.money < 60.0 and minute >= 8 * 60 and minute < 18 * 60:
		s[&"bank"] = (60.0 - d.money) * 1.5
	if d.money > 50.0 and minute >= 9 * 60 and minute < 20 * 60:
		s[&"shop"] = 30.0
	if minute >= 8 * 60 and minute < 19 * 60:
		s[&"park"] = 45.0 if d.profession == &"retiree" else 25.0
	return s


static func choose(d: CitizenData, minute: float) -> StringName:
	var s := scores(d, minute)
	var best: StringName = &"home"
	for g in GOALS:
		if s[g] > s[best]:
			best = g
	return best
