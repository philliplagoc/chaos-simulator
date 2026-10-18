extends RefCounted

const World := preload("res://scripts/world.gd")


func run(t) -> bool:
	var m := CityMap.new()
	for c in World.HYDRANT_CELLS + World.BARREL_CELLS:
		t.check(m.cell(c) == CityMap.Cell.SIDEWALK, "object at %s is on a sidewalk" % c)
	var gas: Dictionary = m.destinations_of(&"gas")[0]
	for c in World.PUMP_CELLS:
		t.check(gas.rect.has_point(c), "pump at %s is inside the gas station" % c)
	t.check(Vector2(World.BARREL_CELLS[1]).distance_to(Vector2(World.BARREL_CELLS[2])) * CityMap.CELL < 140.0, "the barrel pair is close enough to chain")
	return true
