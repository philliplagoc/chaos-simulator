class_name CarThief
extends CharacterBody2D
## Walks (jaywalking, straight line) to the nearest stopped car and steals it.
## The car does the rest. A fast car can knock the thief flat first, and so can
## a brave citizen who runs into him (a tackle).

const SPEED := 70.0
const RETARGET_SECONDS := 0.5
const GRAB_DISTANCE := 16.0
const SHIFTY_SECONDS := 1.0
const TACKLE_SPEED := 150.0

var _target: Car
var _retarget := 0.0
var _shifty := 0.0
var _hurt := Hurtbox.make(7.0, 40.0)
var _touch := Area2D.new()


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Sim.L_CITIZENS  # so drivers brake for him
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_hurt.hit.connect(_knocked_over)
	add_child(_hurt)
	_touch.collision_layer = 0
	_touch.collision_mask = Sim.L_CITIZENS
	_touch.monitorable = false
	var reach := CollisionShape2D.new()
	reach.shape = CircleShape2D.new()
	(reach.shape as CircleShape2D).radius = 7.0
	_touch.add_child(reach)
	add_child(_touch)


func _process(delta: float) -> void:
	for b in _touch.get_overlapping_bodies():
		if b is Citizen and (b as Citizen).mode == Citizen.Mode.CONFRONTING:
			_fall((global_position - b.global_position).normalized() * TACKLE_SPEED)  # tackled!
			return
	_retarget -= delta
	if _retarget <= 0.0 or not is_instance_valid(_target):
		_retarget = RETARGET_SECONDS
		_target = _pick_target()
	if _target == null:
		return
	_shifty -= delta
	if _shifty <= 0.0:
		_shifty = SHIFTY_SECONDS
		EventBus.danger.emit(global_position, 80.0, &"theft")  # looks shifty
	global_position = global_position.move_toward(_target.global_position, SPEED * delta)
	if global_position.distance_to(_target.global_position) < GRAB_DISTANCE:
		_target.steal()  # we're touching it
		FxRing.spawn(get_parent(), global_position, 60.0, Color.BLACK)
		queue_free()


## Nearest stealable car, strongly preferring ones that are standing still.
func _pick_target() -> Car:
	var best: Car = null
	var best_score := INF
	for c: Car in get_tree().get_nodes_in_group("cars"):
		if c.stolen or c.state == Car.State.CRASHED or c.visible == false:
			continue
		var score := global_position.distance_to(c.global_position) + (0.0 if c.speed < 5.0 else 400.0)
		if score < best_score:
			best = c
			best_score = score
	return best


func _knocked_over(body: Node2D, _v: float) -> void:
	_fall(Sim.body_velocity(body) * 1.3)


func _fall(impulse: Vector2) -> void:
	if is_queued_for_deletion():
		return  # already down
	if ImpactBody.can_spawn():
		var b := ImpactBody.new()
		b.color = Color("2c3e50")
		b.position = global_position
		get_parent().add_child.call_deferred(b)
		b.kick.call_deferred(impulse, Sim.rng.randf_range(-8.0, 8.0))
	EventBus.danger.emit.call_deferred(global_position, 70.0, &"ragdoll")
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color.BLACK)
	draw_circle(Vector2.ZERO, 5.0, Color("2c3e50"))
	draw_rect(Rect2(-5, -2, 10, 3), Color.BLACK)  # eye mask
	draw_circle(Vector2(-2, -0.5), 1.0, Color.WHITE)
	draw_circle(Vector2(2, -0.5), 1.0, Color.WHITE)
