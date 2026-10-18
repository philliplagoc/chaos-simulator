class_name Inspector
extends CanvasLayer
## Click-to-inspect card: name, profession, trait, goal, needs and courage bars, bio.
## It updates live while open; the camera follows the citizen until it's closed.

signal closed

var citizen: Citizen
var _panel := PanelContainer.new()
var _title := Label.new()
var _job := Label.new()
var _trait := Label.new()
var _goal := Label.new()
var _bars := {}
var _bio := Label.new()


func _ready() -> void:
	layer = 5
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-330, 60)
	_panel.custom_minimum_size = Vector2(310, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_title.add_theme_font_size_override("font_size", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(hide_card)
	head.add_child(close)
	box.add_child(_job)
	box.add_child(_goal)
	box.add_child(_trait)
	for need in ["money", "hunger", "patience", "courage"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = need.capitalize()
		l.custom_minimum_size.x = 80
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.custom_minimum_size.y = 16
		row.add_child(bar)
		box.add_child(row)
		_bars[need] = bar
	_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio.custom_minimum_size.x = 290
	box.add_child(_bio)
	hide_card()


func show_citizen(c: Citizen) -> void:
	citizen = c
	Citizen.selected_id = c.data.id
	_title.text = c.data.name
	_job.text = c.data.profession_label() + (" (has a car)" if c.data.has_car else "")
	_trait.text = CitizenData.TRAITS.get(c.data.personality, {}).get("label", "")
	_bars["courage"].value = c.data.courage
	_bio.text = "\"%s\"" % c.data.bio
	_panel.visible = true


func hide_card() -> void:
	citizen = null
	Citizen.selected_id = -1
	_panel.visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if citizen == null:
		return
	if not is_instance_valid(citizen):
		hide_card()
		return
	var where := citizen.where_text()
	_goal.text = "Goal: %s  (%s)" % [citizen.goal, where]
	_bars["money"].value = citizen.data.money
	_bars["hunger"].value = citizen.data.hunger
	_bars["patience"].value = citizen.data.patience
