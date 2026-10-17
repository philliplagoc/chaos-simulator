extends Node2D
## Throwaway performance spike (T006): dots path-finding on a road grid.
## Press D to double the dot count. Delete scenes/spike/ once Phase 2 works.

const W := 64
const H := 40
const CELL := 32
const SPEED := 90.0

var grid := AStarGrid2D.new()
var road_cells: Array[Vector2i] = []
var dots: Array[Dot] = []
var label := Label.new()


class Dot extends Node2D:
	var path := PackedVector2Array()
	var i := 0
	var color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6.0, color)


func _ready() -> void:
	grid.region = Rect2i(0, 0, W, H)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if x % 6 == 0 or y % 6 == 0:
				road_cells.append(c)
			else:
				grid.set_point_solid(c)
	var cam := Camera2D.new()
	cam.position = Vector2(W, H) * CELL / 2.0
	cam.zoom = Vector2(0.55, 0.55)
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 24)
	ui.add_child(label)
	spawn(60)


func spawn(count: int) -> void:
	for n in count:
		var d := Dot.new()
		d.color = Color.from_hsv(Sim.rng.randf(), 0.7, 1.0)
		d.position = grid.get_point_position(random_road_cell())
		add_child(d)
		dots.append(d)
		new_path(d)


func random_road_cell() -> Vector2i:
	return road_cells[Sim.rng.randi_range(0, road_cells.size() - 1)]


func new_path(d: Dot) -> void:
	var from := Vector2i((d.position / CELL).floor())
	d.path = grid.get_point_path(from, random_road_cell())
	d.i = 0


func _process(delta: float) -> void:
	for d in dots:
		if d.i >= d.path.size():
			new_path(d)
			continue
		d.position = d.position.move_toward(d.path[d.i], SPEED * delta)
		if d.position.distance_to(d.path[d.i]) < 0.5:
			d.i += 1
	label.text = "FPS: %d   agents: %d   (press D to double)" % [Engine.get_frames_per_second(), dots.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_D:
		spawn(dots.size())


func _draw() -> void:
	draw_rect(Rect2(0, 0, W * CELL, H * CELL), Color("2d4a2d"))
	for c in road_cells:
		draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color("3a3a3a"))
