extends Node2D
## Root of the game. Draws the district and spawns everything in it.
## Left-click a citizen to inspect them. F3 toggles goal labels.
## Right-click drops a test danger. F launches a speeding debug car from the
## mouse at the nearest object.

const COLORS := {
	CityMap.Cell.BLOCK: Color("3f6b3a"),
	CityMap.Cell.ROAD: Color("3b3b40"),
	CityMap.Cell.SIDEWALK: Color("a9a9a2"),
	CityMap.Cell.CROSSWALK: Color("3b3b40"),
}
const BLOCK_COLORS := {
	&"home": Color("b5835a"),
	&"office": Color("6c7a89"),
	&"bank": Color("c9b458"),
	&"cafe": Color("a0522d"),
	&"shop": Color("7b68ae"),
	&"gas": Color("c0392b"),
	&"park": Color("4e9a3f"),
	&"lot": Color("55555c"),
}
const HYDRANT_CELLS: Array[Vector2i] = [
	Vector2i(31, 15), Vector2i(65, 21), Vector2i(33, 39),
	Vector2i(63, 33), Vector2i(20, 19), Vector2i(80, 35),
]
const BARREL_CELLS: Array[Vector2i] = [
	Vector2i(41, 37), Vector2i(56, 37), Vector2i(58, 37), Vector2i(31, 25), Vector2i(65, 10),
]
const PUMP_CELLS: Array[Vector2i] = [Vector2i(44, 40), Vector2i(48, 40), Vector2i(52, 40)]
const CAR_COLORS: Array[Color] = [
	Color("e74c3c"), Color("3498db"), Color("f1c40f"), Color("ecf0f1"),
	Color("2ecc71"), Color("e67e22"), Color("9b59b6"), Color("1abc9c"),
]


var camera := CityCamera.new()
var inspector := Inspector.new()


func _ready() -> void:
	add_child(camera)
	add_child(DesktopBanner.new())
	add_child(inspector)
	inspector.closed.connect(func() -> void: camera.follow = null)
	_spawn_walls()
	_spawn_lights()
	_spawn_objects()
	_spawn_people_and_cars()
	queue_redraw()


## Invisible walls around the map so tumbling bodies bounce back in.
func _spawn_walls() -> void:
	var m := CityMap.map_rect()
	var t := 64.0
	for r: Rect2 in [
		Rect2(m.position.x - t, m.position.y - t, m.size.x + 2 * t, t),
		Rect2(m.position.x - t, m.end.y, m.size.x + 2 * t, t),
		Rect2(m.position.x - t, m.position.y, t, m.size.y),
		Rect2(m.end.x, m.position.y, t, m.size.y),
	]:
		var wall := StaticBody2D.new()
		wall.collision_layer = Sim.L_WALLS
		wall.collision_mask = 0
		wall.position = r.get_center()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		wall.add_child(shape)
		add_child(wall)


func _spawn_lights() -> void:
	var i := 0
	for cell in Sim.city.intersections():
		var light := TrafficLight.new()
		light.cell = cell
		light.offset_s = i * 6.5
		add_child(light)
		i += 1


func _spawn_objects() -> void:
	for cell in HYDRANT_CELLS:
		var h := Hydrant.new()
		h.position = CityMap.cell_to_world(cell)
		add_child(h)
	for cell in BARREL_CELLS + PUMP_CELLS:
		var b := FuelBarrel.new()
		b.is_pump = cell in PUMP_CELLS
		b.position = CityMap.cell_to_world(cell)
		add_child(b)


## Citizens first (so the seed decides who owns a car), then their cars parked
## at home, then ambient traffic to make up Sim.CAR_COUNT.
func _spawn_people_and_cars() -> void:
	var people := CitizenData.generate_all(Sim.CITIZEN_COUNT, Sim.city, Sim.rng, Sim.CAR_COUNT - 4, CitizenData.load_bios())
	var cars := 0
	for d in people:
		var c := Citizen.new()
		c.data = d
		if d.has_car:
			var car := _new_car()
			car.owner_id = d.id
			car.park(d.home)
			c.car = car
			cars += 1
		add_child(c)
	for n in Sim.CAR_COUNT - cars:
		_new_car().place(Sim.free_road_cell())


func _new_car() -> Car:
	var car := Car.new()
	car.color = CAR_COLORS[Sim.rng.randi_range(0, CAR_COLORS.size() - 1)]
	add_child(car)
	return car


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		Citizen.show_debug = not Citizen.show_debug
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_launch_debug_car(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _citizen_at(get_global_mouse_position())
		if c:
			inspector.show_citizen(c)
			camera.follow = c
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var at := get_global_mouse_position()
		EventBus.danger.emit(at, 150.0, &"test")
		FxRing.spawn(self, at, 150.0, Color.ORANGE_RED)


## Debug: a speeding car from `at` aimed at the nearest object.
func _launch_debug_car(at: Vector2) -> void:
	var target: Node2D = null
	for o: Node2D in get_tree().get_nodes_in_group("objects"):
		if target == null or o.global_position.distance_to(at) < target.global_position.distance_to(at):
			target = o
	if target == null:
		return
	var car := _new_car()
	car.temporary = true
	car.global_position = at
	car.center = at
	car.launch(target.global_position - at, 220.0)


## Nearest visible citizen within a few screen pixels of `at`.
func _citizen_at(at: Vector2) -> Citizen:
	var best: Citizen = null
	var best_d := 14.0 / camera.zoom.x
	for c: Citizen in get_tree().get_nodes_in_group("citizens"):
		var d := c.global_position.distance_to(at)
		if c.visible and d < best_d:
			best = c
			best_d = d
	return best


func _draw() -> void:
	var city := Sim.city
	var cs := Vector2(CityMap.CELL, CityMap.CELL)
	for y in CityMap.H:
		for x in CityMap.W:
			var c := Vector2i(x, y)
			draw_rect(Rect2(Vector2(c) * cs, cs), COLORS[city.cell(c)])
			if city.cell(c) == CityMap.Cell.CROSSWALK:
				_draw_crosswalk(c)
	_draw_lane_lines()
	var font := ThemeDB.fallback_font
	for d in city.destinations:
		var r: Rect2i = d.rect
		var px := Rect2(Vector2(r.position) * cs, Vector2(r.size) * cs).grow(-12)
		draw_rect(px, BLOCK_COLORS[d.type])
		draw_string(font, px.position + Vector2(12, 34), d.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		# Entrance marker (debug): yellow door on the sidewalk, curb dot on the road.
		draw_rect(Rect2(Vector2(d.entrance) * cs + Vector2(6, 6), cs - Vector2(12, 12)), Color.YELLOW)
		draw_circle(CityMap.cell_to_world(d.curb), 4.0, Color.YELLOW)


func _draw_crosswalk(c: Vector2i) -> void:
	var o := Vector2(c) * CityMap.CELL
	var vertical_road := c.x in CityMap.ROAD_X
	for i in 4:
		var k := 2.0 + i * 8.0
		if vertical_road:
			draw_rect(Rect2(o + Vector2(k, 4), Vector2(4, 24)), Color.WHITE)
		else:
			draw_rect(Rect2(o + Vector2(4, k), Vector2(24, 4)), Color.WHITE)


func _draw_lane_lines() -> void:
	var half := CityMap.CELL / 2.0
	for x in CityMap.ROAD_X:
		for y in range(0, CityMap.H * CityMap.CELL, 24):
			draw_line(Vector2(x * CityMap.CELL + half, y), Vector2(x * CityMap.CELL + half, y + 10), Color("e0c050"), 1.5)
	for y in CityMap.ROAD_Y:
		for x in range(0, CityMap.W * CityMap.CELL, 24):
			draw_line(Vector2(x, y * CityMap.CELL + half), Vector2(x + 10, y * CityMap.CELL + half), Color("e0c050"), 1.5)
