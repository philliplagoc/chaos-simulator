class_name Hurtbox
extends Area2D
## Reports bodies that touch it faster than `min_speed`. Objects use it to
## notice hard hits from cars and tumbling bodies. Keep it only a few px bigger
## than the object, so cars passing in their lane never touch it.

signal hit(body: Node2D, speed: float)

var min_speed := 60.0


static func make(radius: float, speed: float) -> Hurtbox:
	var h := Hurtbox.new()
	h.min_speed = speed
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	h.add_child(shape)
	return h


func _ready() -> void:
	collision_layer = 0
	collision_mask = Sim.L_CARS | Sim.L_RAGDOLLS
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var v := Sim.body_velocity(body).length()
	if v >= min_speed:
		hit.emit(body, v)
