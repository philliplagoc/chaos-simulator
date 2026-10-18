class_name FuelBarrel
extends StaticBody2D
## A fuel barrel (or a gas pump when is_pump). A hard hit, or an explosion that
## reaches it, lights a short fuse; then it explodes with a big "explosion"
## danger. That danger is what lights the next barrel, so chains emerge.

const FUSE_SECONDS := 0.6

var is_pump := false
var _fuse := -1.0
var exploded := false


func _ready() -> void:
	add_to_group("objects")
	collision_layer = Sim.L_OBJECTS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 20) if is_pump else Vector2(12, 12)
	shape.shape = rect
	add_child(shape)
	var hurt := Hurtbox.make(12.0, 60.0)
	hurt.hit.connect(func(_b: Node2D, _v: float) -> void: ignite())
	add_child(hurt)
	EventBus.danger.connect(_on_danger)


func blast_radius() -> float:
	return 170.0 if is_pump else 140.0


func ignite() -> void:
	if _fuse < 0.0 and not exploded:
		_fuse = FUSE_SECONDS


func _on_danger(pos: Vector2, radius: float, kind: StringName) -> void:
	if kind == &"explosion" and global_position.distance_to(pos) < radius:
		ignite()


func _process(delta: float) -> void:
	if _fuse < 0.0 or exploded:
		return
	_fuse -= delta
	queue_redraw()
	if _fuse <= 0.0:
		_explode()


func _explode() -> void:
	exploded = true
	collision_layer = 0
	remove_from_group("objects")
	FxRing.spawn(get_parent(), global_position, blast_radius(), Color.ORANGE, 0.6)
	FxRing.spawn(get_parent(), global_position, blast_radius() * 0.5, Color.YELLOW, 0.4)
	EventBus.danger.emit(global_position, blast_radius(), &"explosion")
	queue_redraw()


func _draw() -> void:
	if exploded:
		draw_circle(Vector2.ZERO, 14.0, Color(0.1, 0.1, 0.1, 0.6))  # scorch mark
		return
	var flashing := _fuse > 0.0 and fmod(_fuse, 0.2) < 0.1
	var body := Color.WHITE if flashing else (Color("7f8c8d") if is_pump else Color("d35400"))
	if is_pump:
		draw_rect(Rect2(-7, -10, 14, 20), body)
		draw_rect(Rect2(-4, -7, 8, 5), Color("2c3e50"))
	else:
		draw_rect(Rect2(-6, -6, 12, 12), body)
		draw_line(Vector2(-6, -2), Vector2(6, -2), Color.BLACK, 1.0)
		draw_line(Vector2(-6, 2), Vector2(6, 2), Color.BLACK, 1.0)
