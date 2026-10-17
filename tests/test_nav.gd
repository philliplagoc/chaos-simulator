extends RefCounted


func run(t) -> bool:
	var m := CityMap.new()
	var nav := Nav.new(m)
	for a in m.destinations:
		for b in m.destinations:
			if a == b:
				continue
			t.check(nav.road_path(a.curb, b.curb).size() > 0, "road path %s -> %s" % [a.label, b.label])
			var wp := nav.walk_path(a.entrance, b.entrance)
			t.check(wp.size() > 0, "walk path %s -> %s" % [a.label, b.label])
			var ok := true
			for p in wp:
				var c := CityMap.world_to_cell(p)
				if m.is_road(c) and m.cell(c) != CityMap.Cell.CROSSWALK:
					ok = false
			t.check(ok, "walk path %s -> %s only crosses roads at crosswalks" % [a.label, b.label])
	var home: Dictionary = m.destinations_of(&"home")[0]
	var cafe: Dictionary = m.destinations_of(&"cafe")[0]
	t.check(nav.walk_path(home.entrance, cafe.entrance, true).size() <= nav.walk_path(home.entrance, cafe.entrance).size(), "jaywalking is never longer")
	var p := nav.road_path(Vector2i(32, 0), Vector2i(32, 5))
	t.check(p.size() == 6 and p[0] == CityMap.cell_to_world(Vector2i(32, 0)), "road path returns cell centers")
	return true
