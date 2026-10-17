extends Node
## Autoload. Owns the only seeded RNG, the sim clock, the shared district map +
## grids, and the traffic light board. Never call the global randi()/randf().

## Collision layer bits (use in collision_layer / collision_mask).
const L_CARS := 1
const L_CITIZENS := 2
const L_OBJECTS := 4
const L_RAGDOLLS := 8
const L_WALLS := 16

## Agent counts. Spec fallback if the web build stutters: 30 citizens, 15 cars.
const CITIZEN_COUNT := 40
const CAR_COUNT := 20

## Clock: 1 real second = 2 sim minutes, so a full day takes 12 real minutes.
const SIM_MINUTES_PER_SECOND := 2.0
const DAY_START := 6 * 60
const DAY_MINUTES := 24 * 60

var seed_value: int = 2026
## Sim minutes since midnight of day 1. Engine.time_scale (pause, 1x, 3x) scales it.
var minutes: float = DAY_START
var rng := RandomNumberGenerator.new()
var city := CityMap.new()
var nav := Nav.new(city)
## Traffic light board, written by TrafficLight, read by cars.
## Vector2i intersection cell -> [from_north, from_east, from_south, from_west] colors
var lights: Dictionary = {}


func _ready() -> void:
	start_city(seed_value)


## Same seed -> same starting city. Reset calls this with the old seed.
func start_city(new_seed: int) -> void:
	seed_value = new_seed
	rng = make_rng(new_seed)
	lights.clear()
	minutes = DAY_START
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	minutes += delta * SIM_MINUTES_PER_SECOND


func minute_of_day() -> float:
	return fposmod(minutes, DAY_MINUTES)


func clock_text() -> String:
	return format_clock(minutes)


static func format_clock(m: float) -> String:
	var d := int(fposmod(m, DAY_MINUTES))
	return "%02d:%02d" % [d / 60, d % 60]


## Real seconds for a span of sim minutes (at 1x speed).
static func sim_to_seconds(sim_minutes: float) -> float:
	return sim_minutes / SIM_MINUTES_PER_SECOND


static func make_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## Light color for a car entering intersection `cell` while moving along `dir`.
func light_for(cell: Vector2i, dir: Vector2) -> int:
	if not lights.has(cell):
		return TrafficLight.Light.GREEN
	return lights[cell][TrafficLight.approach(dir)]


## Velocity of any body we touch (cars, ragdolls, static objects).
static func body_velocity(body: Object) -> Vector2:
	if body.has_method("lane_velocity"):
		return body.call("lane_velocity")
	if body is CharacterBody2D:
		return (body as CharacterBody2D).velocity
	if body is RigidBody2D:
		return (body as RigidBody2D).linear_velocity
	return Vector2.ZERO


## A random road cell (not an intersection) with no car within 2 cells.
func free_road_cell() -> Vector2i:
	for attempt in 50:
		var c := Vector2i(rng.randi_range(0, CityMap.W - 1), rng.randi_range(0, CityMap.H - 1))
		c = city.nearest_road_cell(c)
		if city.is_intersection(c):
			continue
		var p := CityMap.cell_to_world(c)
		var clear := true
		for car: Node2D in get_tree().get_nodes_in_group("cars"):
			if car.global_position.distance_to(p) < CityMap.CELL * 2.5:
				clear = false
				break
		if clear:
			return c
	return city.nearest_road_cell(Vector2i(rng.randi_range(0, CityMap.W - 1), 0))
