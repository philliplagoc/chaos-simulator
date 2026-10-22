class_name Hud
extends CanvasLayer
## Top bar: chaos meter, clock, speed (pause / 1x / 3x), Reset, New Seed, seed.
## Bottom bar: pick a criminal, then click the map to drop it there.

var placing: StringName = &""   # &"thief", &"rager" or &"" when not placing
var meter := ChaosMeter.new()
var _buttons := {}
var _hint := Label.new()
var _chaos_bar := ProgressBar.new()
var _chaos_label := Label.new()
var _clock := Label.new()
var _seed := Label.new()


func _ready() -> void:
	layer = 4
	_build_top_bar()
	_build_criminal_bar()
	EventBus.danger.connect(func(_p: Vector2, _r: float, kind: StringName) -> void: meter.add_event(kind))


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	_chaos_label.custom_minimum_size.x = 130
	row.add_child(_chaos_label)
	_chaos_bar.custom_minimum_size = Vector2(200, 22)
	_chaos_bar.show_percentage = false
	_chaos_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_chaos_bar)
	_clock.custom_minimum_size.x = 60
	row.add_child(_clock)
	for s: Array in [["Pause", 0.0], ["1x", 1.0], ["3x", 3.0]]:
		var b := Button.new()
		b.text = s[0]
		var speed: float = s[1]
		b.pressed.connect(func() -> void: Engine.time_scale = speed)
		row.add_child(b)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func() -> void: _restart(Sim.seed_value))
	row.add_child(reset)
	var new_seed := Button.new()
	new_seed.text = "New Seed"
	new_seed.pressed.connect(func() -> void: _restart(int(Time.get_unix_time_from_system() * 1000.0) % 1000000))
	row.add_child(new_seed)
	row.add_child(_seed)


func _build_criminal_bar() -> void:
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


## Rebuild the whole city from a seed (same seed = same starting city).
func _restart(new_seed: int) -> void:
	Sim.start_city(new_seed)
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	meter.tick(delta, get_tree().get_nodes_in_group("fleeing").size())
	_chaos_bar.value = meter.value
	_chaos_label.text = "Chaos: " + meter.label()
	_clock.text = Sim.clock_text()
	_seed.text = "Seed %d%s" % [Sim.seed_value, "   (paused)" if Engine.time_scale == 0.0 else ""]


func _select(kind: StringName) -> void:
	placing = kind
	for k: StringName in _buttons:
		_buttons[k].set_pressed_no_signal(k == kind)
	_hint.text = "Click the map to drop them" if kind != &"" else "Pick a criminal"


## Called by World after a criminal is dropped.
func done_placing() -> void:
	_select(&"")
