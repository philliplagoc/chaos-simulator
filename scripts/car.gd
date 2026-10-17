class_name Car
extends CharacterBody2D
## A lane-following car. It drives along a road path of cell centers and sits
## LANE_OFFSET px to the right of its heading, so oncoming cars never touch.
## A forward shape sensor brakes for anything ahead; Sim.lights says when to stop.

enum State { DRIVING, STOPPED_AT_LIGHT, BRAKING, CRASHED, FLEEING, PARKED }

const SIZE := Vector2(20, 12)
const CRUISE := 90.0
const ACCEL := 120.0
const DECEL := 260.0
const LANE_OFFSET := 8.0
const TURN_SPEED := 40.0
const CRASH_SPEED := 75.0
const CRASH_SECONDS := 20.0   # 40 sim minutes, then the car is towed
const STUCK_SECONDS := 40.0   # longer than a full light cycle (38 s)
const FLEE_SECONDS := 3.0

var state: State = State.DRIVING
var color := Color.WHITE
var speed := 0.0
var center := Vector2.ZERO    # position on the lane centerline
var heading := Vector2.RIGHT
var path := PackedVector2Array()
var path_i := 0
var lane_side := 1.0          # +1 = right lane, -1 = oncoming lane
var patience := 100.0
var _lane_offset := Vector2.ZERO
var _state_time := 0.0
var _flee_left := 0.0
var _stuck := 0.0
var _drawn_state := -1
var _sensor := ShapeCast2D.new()


func _ready() -> void:
	add_to_group("cars")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Sim.L_CARS
	collision_mask = Sim.L_CARS | Sim.L_OBJECTS | Sim.L_RAGDOLLS
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	var probe := RectangleShape2D.new()
	probe.size = Vector2(4, SIZE.y + 2)
	_sensor.shape = probe
	_sensor.position = Vector2(SIZE.x / 2.0 + 3.0, 0)
	_sensor.collision_mask = Sim.L_CARS | Sim.L_CITIZENS | Sim.L_RAGDOLLS
	_sensor.add_exception(self)
	add_child(_sensor)
	EventBus.danger.connect(_on_danger)


## Put the car on a road cell and give it a route.
func place(cell: Vector2i) -> void:
	center = CityMap.cell_to_world(cell)
	global_position = center
	new_route()


## Pick a random road cell and path to it. Prefer routes that don't start
## with a U-turn (dead ends at the map edge still need one).
func new_route() -> void:
	var from := CityMap.world_to_cell(center)
	for attempt in 10:
		var goal := Sim.free_road_cell()
		path = Sim.nav.road_path(from, goal)
		if path.size() > 1 and (path[1] - center).normalized().dot(heading) > -0.5:
			break
	path_i = 1


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.PARKED:
			return
		State.CRASHED:
			if _state_time > CRASH_SECONDS:
				_tow()
			_redraw_if_changed()
			return
	if path_i >= path.size():
		new_route()
	_flee_left = maxf(0.0, _flee_left - delta)
	var target := _target_speed()
	if global_position.distance_to(center + _lane_offset) > 10.0:
		target = 0.0  # body got shoved or blocked: let it catch up before moving on
	speed = move_toward(speed, target, (ACCEL if target > speed else DECEL) * delta)
	_advance(speed * delta)
	var right := Vector2(-heading.y, heading.x)
	_lane_offset = _lane_offset.lerp(right * LANE_OFFSET * lane_side, minf(1.0, 8.0 * delta))
	# Capped so a shove from a collision doesn't snap back at crazy speed.
	velocity = ((center + _lane_offset - global_position) / delta).limit_length(250.0)
	move_and_slide()
	rotation = lerp_angle(rotation, heading.angle(), minf(1.0, 10.0 * delta))
	_check_crash()
	_update_patience(delta)
	_redraw_if_changed()


## Lowest of: cruise speed, the light limit, the obstacle limit. Sets the state.
func _target_speed() -> float:
	var t := CRUISE * (1.5 if _flee_left > 0.0 else 1.0)
	_set_state(State.FLEEING if _flee_left > 0.0 else State.DRIVING)
	t = minf(t, _turn_limit())
	var light := _light_limit()
	if light < t:
		t = light
		_set_state(State.STOPPED_AT_LIGHT)
	var look := 30.0 + speed * 0.6
	_sensor.rotation = heading.angle() - rotation  # look where we're going, not where we point
	_sensor.target_position = Vector2(look, 0)
	_sensor.force_shapecast_update()
	if _sensor.is_colliding():
		var gap := _sensor.get_closest_collision_safe_fraction() * look - 4.0
		var obstacle := maxf(0.0, gap) * 3.0
		if obstacle < t:
			t = obstacle
			_set_state(State.BRAKING)
	return t


## Slow down for corners and U-turns coming up on the path.
func _turn_limit() -> float:
	if path_i >= path.size():
		return INF
	if Vector2.from_angle(rotation).dot(heading) < 0.3:
		return 15.0  # still swinging round a U-turn or tight corner
	var to_next := path[path_i] - center
	if path_i + 1 < path.size() and to_next.length() < 40.0:
		var after := (path[path_i + 1] - path[path_i]).normalized()
		if after.dot(heading) < 0.9:
			return TURN_SPEED
	return INF


## Speed limit from the next traffic light. INF when there is nothing to obey.
func _light_limit() -> float:
	if Sim.city.is_intersection(CityMap.world_to_cell(center)):
		return INF  # already inside: keep going
	for k in range(path_i, mini(path_i + 6, path.size())):
		var cell := CityMap.world_to_cell(path[k])
		if not Sim.city.is_intersection(cell):
			continue
		var to_light := path[k] - center
		var dir := to_light.normalized()
		# Stop line is before the crosswalk (2 cells before the intersection center).
		var dist := to_light.length() - CityMap.CELL * 2.5
		if dist < -8.0:
			return INF  # already over the stop line: clear the junction
		match Sim.light_for(cell, dir):
			TrafficLight.Light.RED:
				return _stop_speed(dist) if _flee_left <= 0.0 else INF
			TrafficLight.Light.YELLOW:
				if patience < 30.0 or _flee_left > 0.0 or dist < 12.0:
					return INF  # run the yellow
				return _stop_speed(dist)
			TrafficLight.Light.FLASHING:
				return 40.0
		return INF
	return INF


func _stop_speed(dist: float) -> float:
	return sqrt(maxf(0.0, 2.0 * DECEL * 0.6 * maxf(0.0, dist)))


func _advance(dist: float) -> void:
	while dist > 0.0 and path_i < path.size():
		var to := path[path_i] - center
		var l := to.length()
		if l < 0.001:
			path_i += 1
			continue
		heading = to / l
		if l <= dist:
			center = path[path_i]
			dist -= l
			path_i += 1
		else:
			center += heading * dist
			dist = 0.0


## Impact uses speed along the lane (not the sideways lane-change slide),
## so a U-turn that brushes a queued car doesn't count as a crash.
func _check_crash() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var impact := (lane_velocity() - Sim.body_velocity(col.get_collider())).length()
		if impact >= CRASH_SPEED:
			crash(impact)
			return


## Velocity along the lane, ignoring the sideways slide of lane changes.
func lane_velocity() -> Vector2:
	return heading * speed


func crash(_impact: float) -> void:
	if state == State.CRASHED:
		return
	_set_state(State.CRASHED)
	speed = 0.0
	velocity = Vector2.ZERO
	EventBus.danger.emit(global_position, 110.0, &"crash")


## Clear a crashed car: it reappears on a free road cell and drives on.
func _tow() -> void:
	_set_state(State.DRIVING)
	lane_side = 1.0
	_lane_offset = Vector2.ZERO
	rotation = 0.0
	place(Sim.free_road_cell())


## Patience drains while stuck and recovers while moving. When it has been
## stuck too long it gives up and reroutes (often a U-turn).
func _update_patience(delta: float) -> void:
	if speed < 5.0:
		patience = maxf(0.0, patience - 4.0 * delta)
		if state == State.BRAKING:
			_stuck += delta
	else:
		patience = minf(100.0, patience + 1.0 * delta)
		_stuck = 0.0
	if _stuck > STUCK_SECONDS:
		_stuck = 0.0
		new_route()


func _on_danger(pos: Vector2, radius: float, kind: StringName) -> void:
	if state in [State.CRASHED, State.PARKED]:
		return
	if kind in [&"crash", &"explosion", &"theft"] and global_position.distance_to(pos) < radius * 1.5:
		_flee_left = FLEE_SECONDS


func _set_state(s: State) -> void:
	if s != state:
		state = s
		_state_time = 0.0


func _redraw_if_changed() -> void:
	if _drawn_state != state:
		_drawn_state = state
		queue_redraw()


func _draw() -> void:
	var body := color.darkened(0.55) if state == State.CRASHED else color
	draw_rect(Rect2(-SIZE / 2.0, SIZE), body)
	draw_rect(Rect2(Vector2(2, -5), Vector2(5, 10)), Color(0.75, 0.9, 1.0))
	if state == State.BRAKING or state == State.STOPPED_AT_LIGHT:
		draw_rect(Rect2(Vector2(-10, -6), Vector2(2, 3)), Color.RED)
		draw_rect(Rect2(Vector2(-10, 3), Vector2(2, 3)), Color.RED)
	if state == State.CRASHED:
		draw_circle(Vector2(0, 0), 7.0, Color(0.3, 0.3, 0.3, 0.7))
