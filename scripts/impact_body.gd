class_name ImpactBody
extends RigidBody2D
## The physics stand-in for a hard hit: a citizen tumble (small circle) or a
## car spinout (rectangle). No gravity, damped, bouncy. It emits `settled` once
## it stops (or after 4 s) and frees itself; the agent takes over again.

signal settled(at: Vector2, angle: float)

const MAX_ACTIVE := 5        # spec: at most about 5 ragdolls at once
const FORCE_SETTLE := 4.0
const MAX_IMPULSE := 450.0

static var active := 0

var is_car := false
var size := Vector2(10, 10)
var color := Color.WHITE
var texture: Texture2D        # Kenney art if we have it
var _t := 0.0
var _still := 0.0
var _done := false


static func can_spawn() -> bool:
	return active < MAX_ACTIVE


func _enter_tree() -> void:
	active += 1


func _exit_tree() -> void:
	active -= 1


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = 1.5 if is_car else 2.5
	angular_damp = 2.0 if is_car else 3.0
	mass = 4.0 if is_car else 1.0
	collision_layer = Sim.L_RAGDOLLS
	collision_mask = Sim.L_CARS | Sim.L_OBJECTS | Sim.L_RAGDOLLS | Sim.L_WALLS
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	mat.friction = 0.3
	physics_material_override = mat
	var shape := CollisionShape2D.new()
	if is_car:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
	else:
		var circle := CircleShape2D.new()
		circle.radius = size.x / 2.0
		shape.shape = circle
	add_child(shape)


## Launch it: a capped impulse plus a spin.
func kick(impulse: Vector2, spin: float) -> void:
	apply_central_impulse(impulse.limit_length(MAX_IMPULSE) * mass)
	apply_torque_impulse(spin * mass * 40.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if linear_velocity.length() < 8.0 and absf(angular_velocity) < 0.5:
		_still += delta
	else:
		_still = 0.0
	if not _done and (_still > 0.3 or _t > FORCE_SETTLE):
		_done = true
		settled.emit(global_position, rotation)
		queue_free()


func _draw() -> void:
	if texture:
		# Same framing as Art.car_sprite / Art.person_sprite.
		var h := Art.CAR_LENGTH if is_car else Art.PERSON_SIZE
		draw_set_transform(Vector2.ZERO, PI / 2.0 if is_car else 0.0, Vector2.ONE * h / texture.get_height())
		draw_texture(texture, -texture.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
	elif is_car:
		draw_rect(Rect2(-size / 2.0, size), color)
		draw_rect(Rect2(Vector2(2, -5), Vector2(5, 10)), Color(0.75, 0.9, 1.0))
	else:
		# A little starfish of limbs so the spin is easy to see.
		for i in 4:
			draw_line(Vector2.ZERO, Vector2.from_angle(i * TAU / 4.0 + 0.4) * 8.0, Color.BLACK, 2.0)
		draw_circle(Vector2.ZERO, 5.0, Color.BLACK)
		draw_circle(Vector2.ZERO, 4.0, color)
