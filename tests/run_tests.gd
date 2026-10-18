extends Node
## Headless test runner. Run: godot --headless --path . res://tests/run_tests.tscn
## It runs as a scene (not with -s) so the Sim and EventBus autoloads exist.
## Each suite is a script whose func run(t) -> bool calls t.check(condition, "what")
## and returns true at the end. A suite that crashes midway counts as a failure.

const SUITES: Array[String] = [
	"res://tests/test_sim.gd",
	"res://tests/test_city_map.gd",
	"res://tests/test_nav.gd",
	"res://tests/test_traffic_light.gd",
	"res://tests/test_citizens.gd",
	"res://tests/test_bios.gd",
	"res://tests/test_layout.gd",
]

var checks := 0
var failures := 0


func _ready() -> void:
	# Safety net: if a suite crashes the runner, still quit instead of hanging.
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		printerr("FAIL: test runner crashed (see SCRIPT ERROR above)")
		get_tree().quit(1))
	for path in SUITES:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			check(false, "could not load " + path + " (see SCRIPT ERROR above)")
			continue
		var finished: Variant = script.new().call("run", self)
		check(finished == true, path + " ran to the end")
	print("%d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
