extends RefCounted


func run(t) -> bool:
	var exits := Sim.city.edge_exits()
	var car := Car.new()
	t.add_child(car)
	var before: int =t.get_tree().get_nodes_in_group("cars").size()
	car.place(exits[0])
	car.path_i = car.path.size()  # pretend it just reached the exit
	car.center = CityMap.cell_to_world(exits[0])
	car._physics_process(0.016)
	t.check(is_instance_valid(car) and not car.is_queued_for_deletion(), "an ambient car at an exit is reused, not freed")
	t.check(CityMap.world_to_cell(car.center) in exits, "it re-enters at an edge exit")
	t.check(car.path.size() > 1 and car.path[-1] in exits.map(CityMap.cell_to_world), "and heads for another exit")
	t.check(t.get_tree().get_nodes_in_group("cars").size() == before, "the car count stays the same")
	car.free()
	# A blocked getaway car overtakes: oncoming lane if it's free, sidewalk if not.
	var down := CityMap.cell_to_world(Vector2i(CityMap.ROAD_X[0], 10))
	var thief := Car.new()
	t.add_child(thief)
	thief.place(Vector2i(CityMap.ROAD_X[0], 10))
	thief.stolen = true
	thief.heading = Vector2.DOWN  # curb side (its right) is the x = 31 sidewalk
	thief.state = Car.State.BRAKING
	thief.speed = 0.0
	thief._update_anger(0.1)
	t.check(thief.lane_side == -1.0, "no oncoming car: overtakes in the oncoming lane")
	var oncoming := Car.new()
	t.add_child(oncoming)
	oncoming.global_position = down + Vector2(0, 80)
	oncoming.heading = Vector2.UP
	thief._overtake_left = 0.0
	thief._update_anger(0.1)
	t.check(thief.lane_side == Car.SIDEWALK_SIDE, "oncoming car ahead: mounts the sidewalk")
	thief.free()
	oncoming.free()
	return true
