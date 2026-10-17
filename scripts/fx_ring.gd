class_name FxRing
extends Node2D
## A ring that grows and fades, then frees itself. Pure decoration.
## FxRing.spawn(parent, position, radius, color)

var radius := 50.0
var color := Color.WHITE
var duration := 0.5
var _t := 0.0


static func spawn(parent: Node, at: Vector2, r: float, c: Color, seconds := 0.5) -> void:
	var ring := FxRing.new()
	ring.position = at
	ring.radius = r
	ring.color = c
	ring.duration = seconds
	parent.add_child(ring)


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	draw_arc(Vector2.ZERO, radius * k, 0.0, TAU, 32, Color(color, 1.0 - k), 3.0)
