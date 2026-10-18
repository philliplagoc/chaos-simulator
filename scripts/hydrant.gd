class_name Hydrant
extends StaticBody2D
## Hit it hard and it bursts: a slippery puddle appears and a small "water"
## danger goes out. One burst per hydrant until Reset.

var burst := false


func _ready() -> void:
	add_to_group("objects")
	collision_layer = Sim.L_OBJECTS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)
	var hurt := Hurtbox.make(10.0, 60.0)
	hurt.hit.connect(func(_b: Node2D, _v: float) -> void: burst_open())
	add_child(hurt)


## A car that runs into us calls this (it can't rely on the hurtbox, because
## a spinning car vanishes into its ImpactBody on the same frame).
func take_hit(v: Vector2) -> void:
	if v.length() >= 60.0:
		burst_open()


func burst_open() -> void:
	if burst:
		return
	burst = true
	var p := Puddle.new()
	p.position = position
	get_parent().add_child.call_deferred(p)
	EventBus.danger.emit(global_position, 60.0, &"water")
	FxRing.spawn(get_parent(), global_position, 50.0, Color.DEEP_SKY_BLUE)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color("c0392b"))
	draw_circle(Vector2.ZERO, 3.0, Color("e6b0aa"))
	if burst:
		for i in 6:
			draw_line(Vector2.ZERO, Vector2.from_angle(i * TAU / 6.0) * 12.0, Color.DEEP_SKY_BLUE, 2.0)
