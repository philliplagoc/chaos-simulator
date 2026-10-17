class_name DesktopBanner
extends CanvasLayer
## "Best on desktop" note for phones, tablets and narrow windows. Click to dismiss.


func _ready() -> void:
	layer = 10
	var narrow := get_window().size.x < 900  # real pixels; the stretched viewport never drops below 1280
	if not (narrow or OS.has_feature("web_android") or OS.has_feature("web_ios")):
		queue_free()
		return
	var b := Button.new()
	b.text = "Best on desktop: open this on a laptop or PC with a mouse. (tap to hide)"
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	b.custom_minimum_size.y = 48
	b.pressed.connect(queue_free)
	add_child(b)
