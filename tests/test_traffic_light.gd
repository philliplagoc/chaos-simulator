extends RefCounted


func run(t) -> bool:
	var G := TrafficLight.Light.GREEN
	var Y := TrafficLight.Light.YELLOW
	var R := TrafficLight.Light.RED
	t.check(TrafficLight.approach(Vector2.DOWN) == 0, "moving south = from north")
	t.check(TrafficLight.approach(Vector2.LEFT) == 1, "moving west = from east")
	t.check(TrafficLight.approach(Vector2.UP) == 2, "moving north = from south")
	t.check(TrafficLight.approach(Vector2.RIGHT) == 3, "moving east = from west")
	t.check(TrafficLight.color_at(0.0, 0) == G, "north green at t=0")
	t.check(TrafficLight.color_at(0.0, 1) == R, "east red at t=0")
	t.check(TrafficLight.color_at(6.5, 0) == Y, "north yellow at t=6.5")
	t.check(TrafficLight.color_at(8.0, 0) == R, "north all-red at t=8")
	t.check(TrafficLight.color_at(8.0, 1) == R, "east still red during all-red")
	t.check(TrafficLight.color_at(9.6, 1) == G, "east green at t=9.6")
	var one_at_a_time := true
	for i in 800:
		var s := i * 0.05
		var moving := 0
		for a in 4:
			if TrafficLight.color_at(s, a) != R:
				moving += 1
		if moving > 1:
			one_at_a_time = false
	t.check(one_at_a_time, "only one approach is ever non-red")
	return true
