class_name Citizen
extends CharacterBody2D
## A citizen with a job, needs and a schedule. Every couple of sim minutes it
## asks CitizenBrain what to do next, then walks (or drives its own car) there.
## It reacts to EventBus.danger by fleeing; nothing else tells it what to do.
## A fast car or a blast sends it tumbling (an ImpactBody); then it lies dazed,
## fades out, and reappears at home 60 sim minutes later.

enum Mode { INSIDE, WALKING, DRIVING, FLEEING, TUMBLING, DAZED, DOWN }

const WALK_SPEED := 45.0
const FLEE_SPEED := 95.0
const FLEE_SECONDS := 2.5
const THINK_SECONDS := 1.0    # 2 sim minutes between decisions
const DWELL_SECONDS := 10.0   # stay at least 20 sim minutes after arriving
const HUNGER_PER_SIM_MINUTE := 100.0 / 480.0  # starving after 8 sim hours
const HIT_SPEED := 40.0       # a car this fast knocks us over
const DAZED_SECONDS := 3.0
const FADE_SECONDS := 1.0
const RESPAWN_SECONDS := 30.0  # 60 sim minutes
const PROFESSION_COLORS := {
	&"office_worker": Color("5dade2"),
	&"bank_teller": Color("f4d03f"),
	&"barista": Color("dc7633"),
	&"shop_clerk": Color("af7ac5"),
	&"delivery_driver": Color("58d68d"),
	&"retiree": Color("f5f5f5"),
}

## F3 toggles goal labels on every citizen.
static var show_debug := false
## Id of the citizen open in the inspector (-1 = none). It gets a ring.
static var selected_id := -1

var data: CitizenData
var car: Car                  # this citizen's own car, or null
var goal: StringName = &"home"
var mode: Mode = Mode.INSIDE
var at_dest := -1             # destination index while INSIDE
var target_dest := -1         # destination index while travelling
var path := PackedVector2Array()
var path_i := 0
var _think := 0.0
var _dwell := 0.0
var _flee_left := 0.0
var _flee_dir := Vector2.ZERO
var _deliver_i := 0
var _drawn := ""
var _down_left := 0.0
var _lying_angle := 0.0
var _hurt := Hurtbox.make(7.0, HIT_SPEED)


func _ready() -> void:
	add_to_group("citizens")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Sim.L_CITIZENS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_hurt.hit.connect(func(body: Node2D, _v: float) -> void: tumble(Sim.body_velocity(body) * 1.3))
	add_child(_hurt)
	EventBus.danger.connect(_on_danger)
	if car:
		car.arrived.connect(_on_car_arrived)
	_enter(data.home)
	_think = Sim.rng.randf() * THINK_SECONDS  # don't all think on the same frame


func _process(delta: float) -> void:
	data.hunger = minf(100.0, data.hunger + delta * Sim.SIM_MINUTES_PER_SECOND * HUNGER_PER_SIM_MINUTE * data.trait_value("hunger_rate", 1.0))
	data.patience = minf(100.0, data.patience + delta * 0.5 * data.trait_value("patience_regen", 1.0))
	match mode:
		Mode.INSIDE:
			_dwell -= delta
			_think -= delta
			if _think <= 0.0:
				_think = THINK_SECONDS
				_decide()
		Mode.WALKING:
			_walk(delta)
		Mode.FLEEING:
			_flee(delta)
		Mode.DRIVING:
			if is_instance_valid(car):
				global_position = car.global_position  # so the camera can follow
		Mode.DAZED, Mode.DOWN:
			_recover(delta)
	_redraw_if_changed()


func _decide() -> void:
	var g := CitizenBrain.choose(data, Sim.minute_of_day())
	var dest := _dest_for(g)
	if dest == at_dest or dest < 0:
		goal = g
		return
	if _dwell > 0.0 and g != &"work" and g != &"deliver":
		return  # finish the coffee first
	goal = g
	_travel(dest)


func _dest_for(g: StringName) -> int:
	match g:
		&"work":
			return data.work
		&"home":
			return data.home
		&"deliver":
			var stops: Array[StringName] = [&"shop", &"cafe", &"office", &"bank"]
			if _deliver_i % 5 == 4:
				return data.home  # drop a parcel at their own block
			return Sim.city.index_of(stops[_deliver_i % 5])
	return Sim.city.index_of(g)


## Leave the current place for `dest`: drive if our car is parked right here.
func _travel(dest: int) -> void:
	target_dest = dest
	if car and is_instance_valid(car) and car.parked_at == at_dest and at_dest >= 0:
		mode = Mode.DRIVING
		at_dest = -1
		car.drive_to(dest, data.patience)
		return
	var from: Vector2i
	if at_dest >= 0:
		from = Sim.city.destinations[at_dest].entrance
	else:
		from = Sim.city.nearest_walkable_cell(CityMap.world_to_cell(global_position))
	global_position = CityMap.cell_to_world(from)
	at_dest = -1
	path = Sim.nav.walk_path(from, Sim.city.destinations[dest].entrance, data.patience < 30.0)
	path_i = 1
	mode = Mode.WALKING
	_show(true)


func _walk(delta: float) -> void:
	if path_i >= path.size():
		_enter(target_dest)
		return
	global_position = global_position.move_toward(path[path_i], WALK_SPEED * delta)
	if global_position.distance_to(path[path_i]) < 0.5:
		path_i += 1


## Arrive somewhere: go inside and apply what the place does for our needs.
func _enter(dest: int) -> void:
	mode = Mode.INSIDE
	at_dest = dest
	target_dest = -1
	global_position = CityMap.cell_to_world(Sim.city.destinations[dest].entrance)
	_dwell = DWELL_SECONDS
	_show(false)
	match Sim.city.destinations[dest].type:
		&"cafe":
			data.hunger = 0.0
			data.money = maxf(0.0, data.money - 8.0)
		&"shop":
			data.money = maxf(0.0, data.money - 12.0)
		&"bank":
			data.money = 90.0
		&"park":
			data.patience = minf(100.0, data.patience + 30.0)
	if goal == &"deliver":
		_deliver_i += 1
		_dwell = 3.0


func _on_car_arrived() -> void:
	data.patience = car.patience
	_enter(target_dest)


func _on_danger(pos: Vector2, radius: float, kind: StringName) -> void:
	if mode != Mode.WALKING and mode != Mode.FLEEING:
		return
	var away := global_position - pos
	if away.length() > radius:
		return
	if kind == &"explosion" and away.length() < radius * 0.6:
		tumble(away.normalized() * 420.0)  # knocked flat by the blast
		return
	_flee_dir = away.normalized() if away.length() > 1.0 else Vector2.from_angle(Sim.rng.randf() * TAU)
	_flee_left = FLEE_SECONDS
	if mode != Mode.FLEEING:
		mode = Mode.FLEEING
		add_to_group("fleeing")
		data.patience = maxf(0.0, data.patience - 15.0 * data.trait_value("scare_loss", 1.0))
		if kind != &"panic":
			# Panic spreads one step: bystanders who see us run also run.
			EventBus.danger.emit.call_deferred(global_position, 50.0, &"panic")


## Knocked over: hand our body to the physics engine for a tumble.
func tumble(impulse: Vector2) -> void:
	if mode != Mode.WALKING and mode != Mode.FLEEING:
		return
	remove_from_group("fleeing")
	_show(false)
	EventBus.danger.emit.call_deferred(global_position, 70.0, &"ragdoll")
	if not ImpactBody.can_spawn():
		_on_settled(global_position, 0.0)  # too many ragdolls: just fall over
		return
	mode = Mode.TUMBLING
	var body := ImpactBody.new()
	body.color = PROFESSION_COLORS[data.profession]
	body.position = global_position
	body.settled.connect(_on_settled)
	get_parent().add_child.call_deferred(body)
	body.kick.call_deferred(impulse, Sim.rng.randf_range(-8.0, 8.0))


func _on_settled(at: Vector2, angle: float) -> void:
	global_position = at.clamp(Vector2.ZERO, CityMap.map_rect().end)
	_lying_angle = angle
	mode = Mode.DAZED
	_down_left = DAZED_SECONDS + FADE_SECONDS
	visible = true
	modulate.a = 1.0


## Dazed stars, fade out, wait, then reappear at home.
func _recover(delta: float) -> void:
	_down_left -= delta
	if mode == Mode.DAZED:
		modulate.a = clampf(_down_left / FADE_SECONDS, 0.0, 1.0)
		queue_redraw()  # spin the stars
		if _down_left <= 0.0:
			mode = Mode.DOWN
			visible = false
			_down_left = RESPAWN_SECONDS
	elif _down_left <= 0.0:
		modulate.a = 1.0
		goal = &"home"
		_enter(data.home)


func _flee(delta: float) -> void:
	# Stop at building edges (off-map counts as a building) instead of running through.
	var next := global_position + _flee_dir * FLEE_SPEED * delta
	if Sim.city.cell(CityMap.world_to_cell(next)) != CityMap.Cell.BLOCK:
		global_position = next
	_flee_left -= delta
	if _flee_left <= 0.0:
		remove_from_group("fleeing")
		mode = Mode.WALKING
		_travel(target_dest if target_dest >= 0 else data.home)


## Short status for the inspector card.
func where_text() -> String:
	match mode:
		Mode.INSIDE:
			return "at " + Sim.city.destinations[at_dest].label
		Mode.DRIVING:
			return "driving to " + Sim.city.destinations[target_dest].label
		Mode.FLEEING:
			return "running away!"
		Mode.TUMBLING:
			return "tumbling!"
		Mode.DAZED:
			return "seeing stars"
		Mode.DOWN:
			return "recovering, back home soon"
	return "walking to " + Sim.city.destinations[target_dest].label


func _show(on: bool) -> void:
	visible = on
	collision_layer = Sim.L_CITIZENS if on else 0
	_hurt.set_deferred("monitoring", on)


func _redraw_if_changed() -> void:
	var key := "%s%s%s%s" % [mode, goal, show_debug, selected_id == data.id]
	if key != _drawn:
		_drawn = key
		queue_redraw()


func _draw() -> void:
	if mode == Mode.DAZED:
		_draw_dazed()
		return
	draw_circle(Vector2.ZERO, 5.0, Color.BLACK)
	draw_circle(Vector2.ZERO, 4.0, PROFESSION_COLORS[data.profession])
	if mode == Mode.FLEEING:
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 12, Color.RED, 1.5)
	if selected_id == data.id:
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, Color.YELLOW, 2.0)
	if show_debug:
		draw_string(ThemeDB.fallback_font, Vector2(-20, -10), "%s %s" % [goal, Mode.keys()[mode].to_lower()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


## Lying flat (a stretched body at the angle it landed) with stars circling.
func _draw_dazed() -> void:
	var along := Vector2.from_angle(_lying_angle)
	draw_line(-along * 7.0, along * 7.0, Color.BLACK, 6.0)
	draw_line(-along * 6.0, along * 6.0, PROFESSION_COLORS[data.profession], 4.0)
	var spin := Time.get_ticks_msec() / 300.0
	for i in 3:
		var p := Vector2.from_angle(spin + i * TAU / 3.0) * Vector2(10, 4) + Vector2(0, -10)
		_draw_star(p)


func _draw_star(p: Vector2) -> void:
	draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Color.YELLOW, 1.5)
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color.YELLOW, 1.5)
