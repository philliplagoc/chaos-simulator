extends RefCounted
## Builds the real world scene three times and compares the starting city.


func run(t) -> bool:
	var a := _snapshot(t, 42)
	var b := _snapshot(t, 42)
	var c := _snapshot(t, 43)
	t.check(a.length() > 0, "snapshot isn't empty")
	t.check(a == b, "same seed rebuilds the same starting city")
	t.check(a != c, "a new seed builds a different city")
	return true


func _snapshot(t: Node, s: int) -> String:
	Sim.start_city(s)
	var w: Node = load("res://scenes/world/world.tscn").instantiate()
	t.add_child(w)
	var lines: Array[String] = []
	for n in w.get_children():
		if n is Citizen:
			lines.append(n.data.summary())
		elif n is Car:
			lines.append("car %d %s %s" % [n.owner_id, n.global_position.round(), n.color])
	w.free()
	return "\n".join(lines)
