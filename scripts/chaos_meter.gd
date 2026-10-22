class_name ChaosMeter
extends RefCounted
## 0-100. Jumps on dangerous events, climbs while people are fleeing, and
## decays toward zero. Pure logic so it can be tested.

const WEIGHTS := {
	&"crash": 12.0,
	&"explosion": 20.0,
	&"theft": 10.0,
	&"ragdoll": 8.0,
	&"water": 5.0,
	&"panic": 1.0,
}
const DECAY_PER_SECOND := 3.0
const PER_FLEEING_PER_SECOND := 0.6

var value := 0.0


func add_event(kind: StringName) -> void:
	value = minf(100.0, value + WEIGHTS.get(kind, 0.0))


func tick(delta: float, fleeing: int) -> void:
	value = clampf(value + (fleeing * PER_FLEEING_PER_SECOND - DECAY_PER_SECOND) * delta, 0.0, 100.0)


func label() -> String:
	if value < 20.0:
		return "Calm"
	if value < 50.0:
		return "Rowdy"
	if value < 80.0:
		return "Chaotic"
	return "MAYHEM"
