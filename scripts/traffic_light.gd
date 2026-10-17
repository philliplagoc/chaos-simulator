class_name TrafficLight
extends Node2D
## One per intersection. Each approach (from north, east, south, west) gets its
## own green in turn, so turning cars never cross a moving stream. Each frame it
## writes its colors to Sim.lights so cars never need a reference to it.

enum Light { GREEN, YELLOW, RED, FLASHING }

const GREEN_S := 6.0
const YELLOW_S := 1.5
const ALL_RED_S := 2.0  # slow turning cars need time to clear the junction
const PHASE := GREEN_S + YELLOW_S + ALL_RED_S
const CYCLE := 4.0 * PHASE
const LAMP_COLORS := [Color.GREEN, Color.YELLOW, Color.RED, Color.YELLOW]

var cell := Vector2i.ZERO
var offset_s := 0.0
var knocked_out := false
var _t := 0.0


## Approach index for a car moving along dir: 0 = from north (moving south),
## 1 = from east (moving west), 2 = from south (moving north), 3 = from west.
static func approach(dir: Vector2) -> int:
	if absf(dir.y) > absf(dir.x):
		return 0 if dir.y > 0.0 else 2
	return 1 if dir.x < 0.0 else 3


## Color for one approach at time t (seconds).
static func color_at(t: float, approach_i: int) -> int:
	var p := fposmod(t - approach_i * PHASE, CYCLE)
	if p < GREEN_S:
		return Light.GREEN
	if p < GREEN_S + YELLOW_S:
		return Light.YELLOW
	return Light.RED


func _ready() -> void:
	position = CityMap.cell_to_world(cell)


func _process(delta: float) -> void:
	_t += delta
	var colors: Array[int] = []
	for i in 4:
		colors.append(Light.FLASHING if knocked_out else color_at(_t + offset_s, i))
	Sim.lights[cell] = colors
	queue_redraw()


func _draw() -> void:
	var colors: Array = Sim.lights.get(cell, [Light.GREEN, Light.GREEN, Light.GREEN, Light.GREEN])
	var blink_off := knocked_out and fmod(_t, 1.0) > 0.5
	var k := CityMap.CELL * 1.0
	# Lamp i sits where approach i's drivers wait: north, east, south, west.
	var at: Array[Vector2] = [Vector2(0, -k), Vector2(k, 0), Vector2(0, k), Vector2(-k, 0)]
	for i in 4:
		draw_circle(at[i], 5.0, Color.BLACK)
		if not blink_off:
			draw_circle(at[i], 4.0, LAMP_COLORS[colors[i]])
