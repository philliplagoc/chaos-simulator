class_name Hud
extends CanvasLayer
## Bottom bar: pick a criminal, then click the map to drop it there.

var placing: StringName = &""   # &"thief", &"rager" or &"" when not placing
var _buttons := {}
var _hint := Label.new()


func _ready() -> void:
	layer = 4
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	for kind: StringName in [&"thief", &"rager"]:
		var b := Button.new()
		b.text = "Car Thief" if kind == &"thief" else "Road Rager"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 40)
		b.toggled.connect(func(on: bool) -> void: _select(kind if on else &""))
		row.add_child(b)
		_buttons[kind] = b
	_hint.text = "Pick a criminal"
	_hint.custom_minimum_size.x = 260
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_hint)


func _select(kind: StringName) -> void:
	placing = kind
	for k: StringName in _buttons:
		_buttons[k].set_pressed_no_signal(k == kind)
	_hint.text = "Click the map to drop them" if kind != &"" else "Pick a criminal"


## Called by World after a criminal is dropped.
func done_placing() -> void:
	_select(&"")
