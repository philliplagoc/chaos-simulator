class_name Puddle
extends Area2D
## Slippery water from a burst hydrant. Cars inside lose grip. Dries up after
## 60 sim minutes.

const RADIUS := 44.0
const LIFETIME := 30.0  # real seconds = 60 sim minutes

var _t := 0.0


func _ready() -> void:
	add_to_group("puddles")
	collision_layer = 0
	collision_mask = Sim.L_CARS
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(b: Node2D) -> void: _set_slippery(b, true))
	body_exited.connect(func(b: Node2D) -> void: _set_slippery(b, false))


func _set_slippery(body: Node2D, on: bool) -> void:
	if body.has_method("set_slippery"):
		body.call("set_slippery", on)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		for b in get_overlapping_bodies():
			_set_slippery(b, false)
		queue_free()
	modulate.a = clampf((LIFETIME - _t) / 5.0, 0.0, 1.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(0.3, 0.55, 1.0, 0.45))
	draw_circle(Vector2(10, -8), RADIUS * 0.4, Color(0.6, 0.8, 1.0, 0.35))
