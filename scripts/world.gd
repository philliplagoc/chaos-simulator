extends Node2D
## Root of the game. Draws the district and spawns everything in it.

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
const CAR_COLORS: Array[Color] = [
	Color("e74c3c"), Color("3498db"), Color("f1c40f"), Color("ecf0f1"),
	Color("2ecc71"), Color("e67e22"), Color("9b59b6"), Color("1abc9c"),
]


func _ready() -> void:
	add_child(CityCamera.new())
	add_child(DesktopBanner.new())
	_spawn_lights()
	_spawn_cars()
	queue_redraw()


func _spawn_lights() -> void:
	var i := 0
	for cell in Sim.city.intersections():
		var light := TrafficLight.new()
		light.cell = cell
		light.offset_s = i * 6.5
		add_child(light)
		i += 1


func _spawn_cars() -> void:
	for n in Sim.CAR_COUNT:
		var car := Car.new()
		car.color = CAR_COLORS[Sim.rng.randi_range(0, CAR_COLORS.size() - 1)]
		add_child(car)
		car.place(Sim.free_road_cell())


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
