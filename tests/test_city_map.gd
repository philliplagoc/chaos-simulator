extends RefCounted


func run(t) -> bool:
	var m := CityMap.new()
	t.check(m.intersections().size() == 4, "4 intersections")
	t.check(m.destinations.size() == 9, "9 blocks")
	t.check(m.destinations_of(&"home").size() == 2, "2 housing blocks")
	for type in [&"office", &"bank", &"cafe", &"shop", &"gas", &"park"]:
		t.check(m.destinations_of(type).size() == 1, "one %s" % type)
	for d in m.destinations:
		t.check(m.is_walkable(d.entrance), "%s entrance is on a sidewalk" % d.label)
		t.check(m.is_road(d.curb), "%s curb is on a road" % d.label)
		t.check(m.cell(d.lot) == CityMap.Cell.BLOCK, "%s lot is inside its block" % d.label)
		t.check(d.rect.has_point(d.lot), "%s lot is inside its rect" % d.label)
	t.check(m.cell(Vector2i(32, 16)) == CityMap.Cell.CROSSWALK, "crosswalk north of (32,18)")
	t.check(m.cell(Vector2i(31, 17)) == CityMap.Cell.SIDEWALK, "corner is sidewalk")
	t.check(m.cell(Vector2i(5, 5)) == CityMap.Cell.BLOCK, "block interior")
	t.check(m.edge_exits().size() == 8, "8 edge exits")
	for e in m.edge_exits():
		t.check(m.is_road(e), "exit %s is road" % e)
	t.check(m.nearest_road_cell(Vector2i(30, 5)) == Vector2i(32, 5), "nearest road to (30,5)")
	t.check(m.nearest_road_cell(Vector2i(50, 20)) == Vector2i(50, 18), "nearest road to (50,20)")
	t.check(m.is_walkable(m.nearest_walkable_cell(Vector2i(5, 5))), "nearest walkable is walkable")
	t.check(CityMap.world_to_cell(CityMap.cell_to_world(Vector2i(7, 9))) == Vector2i(7, 9), "cell<->world round trip")
	t.check(m.index_of(&"bank") >= 0 and m.destinations[m.index_of(&"bank")].type == &"bank", "index_of finds the bank")
	for i in m.destinations.size():
		var seen := {}
		for slot in 16:
			var p := m.parking_slot(i, slot)
			seen[p] = true
			t.check(m.cell(p) == CityMap.Cell.BLOCK, "parking slot %d of %s is inside the block" % [slot, m.destinations[i].label])
		t.check(seen.size() == 16, "16 distinct parking slots at %s" % m.destinations[i].label)
	return true
