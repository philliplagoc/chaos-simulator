class_name CityCamera
extends Camera2D
## Drag (left or middle mouse) to pan, wheel to zoom toward the mouse.
## The view never leaves the map.

const MIN_ZOOM := 0.42
const MAX_ZOOM := 2.0

var _dragging := false


func _ready() -> void:
	zoom = Vector2(0.6, 0.6)
	position = CityMap.map_rect().get_center()
	_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			var f := 1.1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			zoom = (zoom * f).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
			position += before - get_global_mouse_position()
			_clamp()
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom
		_clamp()


func _clamp() -> void:
	var half := get_viewport_rect().size / zoom / 2.0
	var m := CityMap.map_rect()
	position.x = clampf(position.x, m.position.x + half.x, maxf(m.end.x - half.x, m.position.x + half.x))
	position.y = clampf(position.y, m.position.y + half.y, maxf(m.end.y - half.y, m.position.y + half.y))
