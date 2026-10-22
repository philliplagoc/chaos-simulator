class_name Car
extends CharacterBody2D
## A lane-following car. It drives along a road path of cell centers and sits
## LANE_OFFSET px to the right of its heading, so oncoming cars never touch.
## A forward shape sensor brakes for anything ahead; Sim.lights says when to stop.
## Ambient cars drive through town, leave at a map exit and come back in at
## another. An owned car stays PARKED until its owner calls drive_to().
## A hard hit swaps it for a spinning ImpactBody; once that settles the car
## drives back to the nearest lane, or stays CRASHED if the hit was huge.
## A crashed car sits for a while, then drives on from where it stopped.
## A blast close by burns it: a charred husk that is removed for good.
## A Car Thief can steal() it: then it races for the map edge, ignoring lights.
## A Road Rager car (rager = true) gets angrier while blocked: it tailgates,
## then overtakes through the oncoming lane (or the sidewalk, if that's busy),
## then rams the car ahead.

signal arrived  # an owned car reached its goal and parked
signal driver_ejected(at: Vector2)  # a thief pulled the owner out
signal burnt(at: Vector2)  # blown up: the owner can't use it any more

enum State { DRIVING, STOPPED_AT_LIGHT, BRAKING, CRASHED, FLEEING, PARKED }

const SIZE := Vector2(20, 12)
const CRUISE := 90.0
const ACCEL := 120.0
const DECEL := 260.0
const LANE_OFFSET := 8.0
const TURN_SPEED := 40.0
const CRASH_SPEED := 75.0     # fender-bender: stop and sit there
const SPINOUT_SPEED := 130.0  # spin out, then drive on
const WRECK_SPEED := 220.0    # spin out and stay wrecked
const CRASH_SECONDS := 20.0   # 40 sim minutes, then the car drives on (a husk is removed)
const HUSK := Color(0.08, 0.08, 0.08)
const PARK_SPEED := 40.0      # rolling into a parking slot
const STUCK_SECONDS := 40.0   # longer than a full light cycle (38 s)
const FLEE_SECONDS := 3.0
const THIEF_CRUISE := 200.0
const ANGER_TAILGATE := 30.0
const ANGER_OVERTAKE := 60.0
const ANGER_RAM := 85.0
const SIDEWALK_SIDE := 4.0     # lane_side that puts us on the curb-side sidewalk (32 px)
const ONCOMING_LOOK := 150.0

var state: State = State.DRIVING
var color := Color.WHITE
var speed := 0.0
var center := Vector2.ZERO    # position on the lane centerline
var heading := Vector2.RIGHT
var path := PackedVector2Array()
var path_i := 0
var lane_side := 1.0          # +1 = right lane, -1 = oncoming lane
var patience := 100.0
var owner_id := -1            # citizen id, -1 = ambient traffic
var temporary := false        # debug and stolen cars: not regular traffic
var stolen := false
var rager := false
var anger := 0.0              # 0-100, rager only
var _overtake_left := 0.0
var _ram_left := 0.0
var parked_at := -1           # destination index while PARKED
var _goal_dest := -1          # destination index an owner asked for
var _lane_offset := Vector2.ZERO
var _state_time := 0.0
var _flee_left := 0.0
var _stuck := 0.0
var _slippery := 0            # how many puddles we're in
var _launch_left := 0.0       # seconds left flying straight (debug launch)
var _impact_velocity := Vector2.ZERO
var _since_impact := 99.0
var _spinning := false
var _spin_hard := false
var _burnt := false
var _homing := false          # driving back to our lot empty after a spin
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
	_route()


## Park in this destination's lot (slot picked by owner id). With `roll_in`
## the car rolls into the slot from where it is instead of appearing there.
func park(dest_index: int, roll_in := false) -> void:
	_set_state(State.PARKED)
	parked_at = dest_index
	_goal_dest = -1
	center = CityMap.cell_to_world(Sim.city.parking_slot(dest_index, maxi(owner_id, 0)))
	if not roll_in:
		global_position = center
		rotation = 0.0
	speed = 0.0
	velocity = Vector2.ZERO
	_lane_offset = Vector2.ZERO
	_redraw_if_changed()


## Owner asks to be driven to a destination. The car pulls out once the curb is clear.
func drive_to(dest_index: int, driver_patience: float) -> void:
	_goal_dest = dest_index
	patience = driver_patience


## Debug: fly straight along `dir`, ignoring lanes and lights, for 3 seconds.
func launch(dir: Vector2, launch_speed: float) -> void:
	heading = dir.normalized()
	speed = launch_speed
	rotation = heading.angle()
	_launch_left = 3.0
	_set_state(State.FLEEING)


## A thief touched us: kick the driver out and race for a random map exit.
func steal() -> void:
	if stolen or _spinning or state == State.CRASHED:
		return
	if owner_id >= 0 and parked_at < 0 and not _homing:
		driver_ejected.emit(global_position)
	if parked_at >= 0:
		center = CityMap.cell_to_world(Sim.city.destinations[parked_at].curb)
		parked_at = -1
	stolen = true
	temporary = true
	_goal_dest = -1
	_set_state(State.FLEEING)
	EventBus.danger.emit(global_position, 120.0, &"theft")
	_route()
	queue_redraw()


## Route to the owner's goal if there is one, otherwise wander.
func _route() -> void:
	if stolen:
		var exits := Sim.city.edge_exits()
		path = Sim.nav.road_path(CityMap.world_to_cell(center), exits[Sim.rng.randi_range(0, exits.size() - 1)])
		path_i = 1
		return
	if _goal_dest < 0:
		new_route()
		return
	path = Sim.nav.road_path(CityMap.world_to_cell(center), Sim.city.destinations[_goal_dest].curb)
	path_i = 1


## Pick a road cell and path to it: ambient traffic heads for a random map exit
## (it leaves town there), owned cars and the Road Rager wander. Prefer routes that don't start
## with a U-turn (dead ends at the map edge still need one).
func new_route() -> void:
	var from := CityMap.world_to_cell(center)
	var exits := Sim.city.edge_exits()
	for attempt in 10:
		var goal: Vector2i = exits[Sim.rng.randi_range(0, exits.size() - 1)] if owner_id < 0 and not rager else Sim.free_road_cell()
		path = Sim.nav.road_path(from, goal)
		if path.size() > 1 and (path[1] - center).normalized().dot(heading) > -0.5:
			break
	path_i = 1


func _physics_process(delta: float) -> void:
	_state_time += delta
	_since_impact += delta
	if _spinning:
		return  # the ImpactBody is doing the moving
	match state:
		State.PARKED:
			if global_position.distance_to(center) > 0.5:
				global_position = global_position.move_toward(center, PARK_SPEED * delta)  # roll into the slot
				rotation = lerp_angle(rotation, 0.0, minf(1.0, 4.0 * delta))
			if _goal_dest >= 0 and Sim.is_road_clear(Sim.city.destinations[parked_at].curb):
				parked_at = -1
				_drive_back()
			return
		State.CRASHED:
			if _state_time > CRASH_SECONDS:
				_recover()
			_redraw_if_changed()
			return
	if _launch_left > 0.0:
		_launch_left -= delta
		velocity = heading * speed
		move_and_slide()
		_check_crash()
		if _launch_left <= 0.0 and state != State.CRASHED and not _spinning:  # flew 3 s and hit nothing
			queue_free()
		return
	if path_i >= path.size():
		if stolen:
			_replace_me()
			queue_free()  # off the edge of the map with the loot
			return
		if _goal_dest >= 0:
			park(_goal_dest, true)
			if _homing:
				_homing = false  # nobody aboard to tell
			else:
				arrived.emit()
			return
		if owner_id < 0 and not rager and CityMap.world_to_cell(center) in Sim.city.edge_exits():
			if temporary:
				queue_free()  # a debug car that joined the traffic: it's extra
			else:
				enter_from_edge()  # left town; come back in somewhere else
			return
		new_route()
	_flee_left = maxf(0.0, _flee_left - delta)
	if rager or stolen:
		_update_anger(delta)
	var target := _target_speed()
	if global_position.distance_to(center + _lane_offset) > 10.0:
		target = 0.0  # body got shoved or blocked: let it catch up before moving on
	var grip := 0.25 if _slippery > 0 else 1.0  # wet road: weak brakes
	speed = move_toward(speed, target, (ACCEL if target > speed else DECEL * grip) * delta)
	_advance(speed * delta)
	var right := Vector2(-heading.y, heading.x)
	var drift := 0.0
	if _slippery > 0 and speed > 30.0:
		drift = sin(_state_time * 9.0) * 12.0  # fishtail across the lane
	_lane_offset = _lane_offset.lerp(right * (LANE_OFFSET * lane_side + drift), minf(1.0, 8.0 * delta))
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
	if stolen:
		t = THIEF_CRUISE
		_set_state(State.FLEEING)
	t = minf(t, _turn_limit() * (1.6 if stolen else 1.0))
	var reckless := _overtake_left > 0.0 or _ram_left > 0.0
	if _ram_left > 0.0:
		t = CRUISE * 1.7
	var light := INF if (stolen or reckless) else _light_limit()
	if light < t:
		t = light
		_set_state(State.STOPPED_AT_LIGHT)
	if reckless:
		return t  # eyes on nothing but the gap
	var look := 30.0 + speed * (0.25 if stolen else 0.6)  # thieves brake late
	_sensor.rotation = heading.angle() - rotation  # look where we're going, not where we point
	_sensor.target_position = Vector2(look, 0)
	_sensor.force_shapecast_update()
	if _sensor.is_colliding():
		var gap := _sensor.get_closest_collision_safe_fraction() * look - 4.0
		if rager and anger > ANGER_TAILGATE:
			gap -= 6.0  # tailgate
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
				if patience < 30.0 or _flee_left > 0.0 or dist < 12.0 or anger > ANGER_TAILGATE:
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
		var other := col.get_collider()
		var mine := lane_velocity()
		var impact := (mine - Sim.body_velocity(other)).length()
		if impact < CRASH_SPEED:
			continue
		if other.has_method("take_hit"):
			other.call("take_hit", mine)  # we're touching it, so we may tell it
		if impact >= SPINOUT_SPEED:
			spinout(mine * 0.4 + col.get_normal() * impact * 0.6, impact >= WRECK_SPEED)
		else:
			crash(impact)
		return


## Another car ran into us with velocity `v`.
func take_hit(v: Vector2) -> void:
	if _spinning or state == State.CRASHED:
		return
	var impact := (v - lane_velocity()).length()
	if impact >= SPINOUT_SPEED:
		spinout(v * 0.7, impact >= WRECK_SPEED)
	elif impact >= CRASH_SPEED:
		crash(impact)


## Velocity along the lane, ignoring the sideways slide of lane changes.
## Just after a crash it still reports the impact speed, so whatever we hit
## notices how hard it was hit even if it checks a frame late.
func lane_velocity() -> Vector2:
	if _since_impact < 0.2:
		return _impact_velocity
	return heading * speed


func crash(_impact: float) -> void:
	if state == State.CRASHED:
		return
	anger = 40.0
	_impact_velocity = heading * speed
	_since_impact = 0.0
	_set_state(State.CRASHED)
	_launch_left = 0.0
	speed = 0.0
	velocity = Vector2.ZERO
	EventBus.danger.emit(global_position, 110.0, &"crash")


## Hand the car to the physics engine: hide it and spawn a spinning body.
func spinout(impulse: Vector2, hard: bool) -> void:
	if _spinning or state == State.CRASHED:
		return
	_impact_velocity = lane_velocity()
	_since_impact = 0.0
	if not ImpactBody.can_spawn():
		crash(impulse.length())  # too many bodies flying: just stop
		return
	_spinning = true
	_spin_hard = hard
	_launch_left = 0.0
	visible = false
	collision_layer = 0
	var body := ImpactBody.new()
	body.is_car = true
	body.size = SIZE
	body.color = color
	if _burnt:
		body.color = HUSK
	body.position = global_position
	body.rotation = rotation
	body.linear_velocity = heading * speed
	body.settled.connect(_on_spin_settled)
	get_parent().add_child.call_deferred(body)
	body.kick.call_deferred(impulse, Sim.rng.randf_range(-12.0, 12.0))
	speed = 0.0
	EventBus.danger.emit.call_deferred(global_position, 110.0, &"crash")


func _on_spin_settled(at: Vector2, angle: float) -> void:
	_spinning = false
	visible = true
	collision_layer = Sim.L_CARS
	global_position = at
	rotation = angle
	velocity = Vector2.ZERO
	_lane_offset = Vector2.ZERO
	queue_redraw()
	if _spin_hard:
		_set_state(State.DRIVING)
		crash(0.0)
		return
	_recover()


## Back to normal from where we stand (no teleporting). A parked car stays
## parked wherever it ended up; a car still on its lane drives on; anything
## else drives back to the nearest road first. Husks go away.
func _recover() -> void:
	if _burnt:
		_replace_me()
		queue_free()
		return
	if parked_at >= 0:
		if _goal_dest < 0 and Sim.city.is_road(CityMap.world_to_cell(global_position)):
			_goal_dest = parked_at  # knocked into the road: drive back to the lot
			_homing = true
			parked_at = -1
			_drive_back()
		else:
			_set_state(State.PARKED)  # a waiting owner pulls out from here
		return
	_set_state(State.DRIVING)
	if global_position.distance_to(center) > 12.0 or not Sim.city.is_road(CityMap.world_to_cell(global_position)):
		_drive_back()


## Drive (not jump) to the nearest road cell, then on along a fresh route.
func _drive_back() -> void:
	center = CityMap.cell_to_world(Sim.city.nearest_road_cell(CityMap.world_to_cell(global_position)))
	_route()  # routes from the road cell...
	center = global_position  # ...but we start from where we actually are
	path_i = 0  # path[0] is that road cell
	heading = Vector2.from_angle(rotation)
	lane_side = 1.0
	_lane_offset = Vector2.ZERO
	speed = 0.0
	_set_state(State.DRIVING)


## Drive in from a random map exit with no car near it, facing into town.
func enter_from_edge() -> void:
	var exits := Sim.city.edge_exits()
	var open: Array[Vector2i] = []
	for e in exits:
		var p := CityMap.cell_to_world(e)
		var clear := true
		for c: Node2D in get_tree().get_nodes_in_group("cars"):
			if c != self and c.global_position.distance_to(p) < CityMap.CELL * 2.5:
				clear = false
		if clear:
			open.append(e)
	if open.is_empty():
		open = exits
	var cell := open[Sim.rng.randi_range(0, open.size() - 1)]
	if cell.x == 0 or cell.x == CityMap.W - 1:
		heading = Vector2(signf(CityMap.W / 2.0 - cell.x), 0.0)
	else:
		heading = Vector2(0.0, signf(CityMap.H / 2.0 - cell.y))
	center = CityMap.cell_to_world(cell)
	rotation = heading.angle()
	lane_side = 1.0
	_lane_offset = Vector2(-heading.y, heading.x) * LANE_OFFSET
	global_position = center + _lane_offset
	velocity = Vector2.ZERO
	speed = CRUISE * 0.5
	patience = 100.0
	anger = 0.0
	_flee_left = 0.0
	_stuck = 0.0
	_set_state(State.DRIVING)
	_route()
	queue_redraw()


## A regular car left for good (burnt or stolen): drive a new ambient one in
## so the district keeps Sim.CAR_COUNT cars. Debug cars are extra: no refill.
func _replace_me() -> void:
	var regular := 0
	for c: Car in get_tree().get_nodes_in_group("cars"):
		if not c.temporary and not c._burnt:
			regular += 1
	if regular >= Sim.CAR_COUNT:
		return
	var car := Car.new()
	car.color = color
	get_parent().add_child.call_deferred(car)
	car.enter_from_edge.call_deferred()


## Caught near the middle of a blast: burnt out for good.
func _burn() -> void:
	_burnt = true
	_state_time = 0.0  # a car that was already crashed smoulders for the full time
	queue_redraw()
	burnt.emit(global_position)


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
		_route()


func _on_danger(pos: Vector2, radius: float, kind: StringName) -> void:
	if _spinning or _burnt:
		return
	var d := global_position.distance_to(pos)
	if kind == &"explosion" and d < radius * 0.3:
		_burn()
	if state == State.CRASHED:
		return
	if kind == &"explosion" and d < radius * 0.6:
		spinout((global_position - pos).normalized() * 380.0, _burnt)  # caught in the blast
		return
	if state == State.PARKED or stolen:
		return
	if kind in [&"crash", &"explosion", &"theft"] and d < radius * 1.5:
		_flee_left = FLEE_SECONDS


## Road rage: blocked = angrier. Past each threshold it does something worse.
## A stolen car uses the same moves, and overtakes as soon as it's blocked.
func _update_anger(delta: float) -> void:
	_overtake_left = maxf(0.0, _overtake_left - delta)
	_ram_left = maxf(0.0, _ram_left - delta)
	var blocked := speed < 20.0 and (state == State.BRAKING or state == State.STOPPED_AT_LIGHT)
	anger = clampf(anger + (18.0 if blocked else -4.0) * delta, 0.0, 100.0)
	if _overtake_left <= 0.0:
		lane_side = 1.0
	if (anger > ANGER_OVERTAKE or stolen) and blocked and _overtake_left <= 0.0:  # a thief won't wait
		_overtake_left = 2.5
		lane_side = -1.0  # swing into the oncoming lane...
		if _oncoming_ahead() and _curb_is_sidewalk():
			lane_side = SIDEWALK_SIDE  # ...or, if that's busy, up onto the sidewalk
	if anger > ANGER_RAM and speed > 40.0 and state == State.BRAKING and _ram_left <= 0.0:
		_ram_left = 2.0  # floor it into the car ahead
	queue_redraw()


## Is a car coming the other way just ahead of us?
func _oncoming_ahead() -> bool:
	for c: Car in get_tree().get_nodes_in_group("cars"):
		var to := c.global_position - global_position
		if c != self and to.length() < ONCOMING_LOOK and to.dot(heading) > 0.0 and c.heading.dot(heading) < -0.5:
			return true
	return false


func _curb_is_sidewalk() -> bool:
	var side := CityMap.world_to_cell(center + Vector2(-heading.y, heading.x) * CityMap.CELL)
	return Sim.city.cell(side) == CityMap.Cell.SIDEWALK


## Called by a Puddle when we drive in or out of it.
## Hitting water fast spins us out.
func set_slippery(on: bool) -> void:
	_slippery = maxi(0, _slippery + (1 if on else -1))
	if on and speed > 45.0 and state != State.PARKED:
		spinout(heading.rotated(Sim.rng.randf_range(-0.8, 0.8)) * speed * 0.6, false)


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
	if stolen:
		draw_rect(Rect2(Vector2(-6, -3), Vector2(6, 6)), Color.BLACK)  # masked driver
	if rager:
		draw_line(Vector2(-3, -4), Vector2(1, -2), Color.BLACK, 1.5)  # angry eyebrows
		draw_line(Vector2(-3, 4), Vector2(1, 2), Color.BLACK, 1.5)
		draw_set_transform(Vector2.ZERO, -rotation)  # anger bar stays level
		draw_rect(Rect2(-12, -18, 24, 4), Color.BLACK)
		draw_rect(Rect2(-12, -18, 24 * anger / 100.0, 4), Color.ORANGE_RED)
		draw_set_transform(Vector2.ZERO, 0.0)
	if _burnt:
		draw_rect(Rect2(-SIZE / 2.0, SIZE), HUSK)  # charred husk with a little smoke
		draw_circle(Vector2(-3, -2), 4.0, Color(0.4, 0.4, 0.4, 0.6))
		draw_circle(Vector2(4, 2), 3.0, Color(0.4, 0.4, 0.4, 0.6))
