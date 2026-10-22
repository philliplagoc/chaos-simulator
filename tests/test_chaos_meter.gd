extends RefCounted


func run(t) -> bool:
	var m := ChaosMeter.new()
	t.check(m.value == 0.0 and m.label() == "Calm", "starts calm")
	m.add_event(&"crash")
	t.check(is_equal_approx(m.value, 12.0), "a crash adds 12")
	m.add_event(&"explosion")
	t.check(is_equal_approx(m.value, 32.0) and m.label() == "Rowdy", "an explosion adds 20 -> Rowdy")
	m.add_event(&"test")
	t.check(is_equal_approx(m.value, 32.0), "test dangers don't count")
	m.tick(1.0, 0)
	t.check(is_equal_approx(m.value, 29.0), "decays 3 per second")
	m.tick(1.0, 10)
	t.check(is_equal_approx(m.value, 32.0), "10 people fleeing outweigh the decay")
	for i in 20:
		m.add_event(&"explosion")
	t.check(m.value == 100.0 and m.label() == "MAYHEM", "caps at 100")
	m.tick(1000.0, 0)
	t.check(m.value == 0.0, "decays back to zero, never below")
	return true
