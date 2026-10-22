extends RefCounted


func run(t) -> bool:
	var city := CityMap.new()
	var people := CitizenData.generate_all(40, city, Sim.make_rng(7), 16)
	t.check(people.size() == 40, "40 citizens")
	var counts := {}
	var cars := 0
	for d in people:
		counts[d.profession] = counts.get(d.profession, 0) + 1
		if d.has_car:
			cars += 1
		t.check(city.destinations[d.home].type == &"home", "%s lives in a housing block" % d.name)
		if d.profession != &"retiree":
			t.check(city.destinations[d.work].type == CitizenData.WORKPLACE[d.profession], "%s works at the right place" % d.name)
	for p in CitizenData.PROFESSION_MIX:
		t.check(counts.get(p, 0) == CitizenData.PROFESSION_MIX[p], "%d %s" % [CitizenData.PROFESSION_MIX[p], p])
	t.check(cars > 5 and cars <= 16, "about 40%% own a car (got %d)" % cars)
	var again := CitizenData.generate_all(40, city, Sim.make_rng(7), 16)
	var same := true
	for i in 40:
		if people[i].summary() != again[i].summary():
			same = false
	t.check(same, "same seed gives the same citizens")
	t.check(CitizenData.generate_all(30, city, Sim.make_rng(7), 11).size() == 30, "fallback count of 30 works")
	var with_bios := CitizenData.generate_all(40, city, Sim.make_rng(7), 16, CitizenData.load_bios())
	var bios_seen := {}
	for p in with_bios:
		t.check(p.bio != "", "%s has a bio" % p.name)
		bios_seen[p.bio] = true
		var r: Array = CitizenData.TRAITS.get(p.personality, {}).get("courage", [-1.0, -1.0])
		t.check(p.courage >= r[0] and p.courage <= r[1], "%s (%s) has courage in range" % [p.name, p.personality])
	t.check(bios_seen.size() == 40, "no two citizens share a bio")
	var bios_again := CitizenData.generate_all(40, city, Sim.make_rng(7), 16, CitizenData.load_bios())
	t.check(bios_again[39].summary() == with_bios[39].summary(), "same seed gives the same traits and courage")
	var pincher := CitizenData.new()
	pincher.money = 70.0
	t.check(CitizenBrain.scores(pincher, 10 * 60)[&"bank"] == 0.0, "70 money: no bank trip by default")
	pincher.personality = &"penny_pincher"
	t.check(CitizenBrain.scores(pincher, 10 * 60)[&"bank"] > 0.0, "70 money: a penny pincher wants the bank")

	var d := CitizenData.new()
	d.profession = &"office_worker"
	d.shift_start = 480
	d.shift_end = 1020
	d.money = 70.0
	d.hunger = 10.0
	t.check(CitizenBrain.choose(d, 6 * 60 + 10) == &"home", "office worker home at 06:10")
	t.check(CitizenBrain.choose(d, 7 * 60 + 30) == &"work", "office worker commutes at 07:30")
	d.hunger = 95.0
	t.check(CitizenBrain.choose(d, 12 * 60) == &"work", "shift beats hunger")
	t.check(CitizenBrain.choose(d, 17 * 60 + 30) == &"cafe", "hungry after work -> cafe")
	d.hunger = 0.0
	d.money = 10.0
	t.check(CitizenBrain.choose(d, 17 * 60 + 30) == &"bank", "broke after work -> bank")
	t.check(CitizenBrain.choose(d, 22 * 60) == &"home", "home at night")
	d.profession = &"retiree"
	d.shift_start = -1
	d.shift_end = -1
	d.money = 40.0
	t.check(CitizenBrain.choose(d, 10 * 60) == &"park", "retiree in the park at 10:00")
	d.profession = &"delivery_driver"
	d.shift_start = 480
	d.shift_end = 960
	t.check(CitizenBrain.choose(d, 9 * 60) == &"deliver", "driver delivers during shift")
	# Fight or flight: on a road, a theft 30 px down the street.
	var at := CityMap.cell_to_world(Vector2i(CityMap.ROAD_X[0], 10))
	var danger := at + Vector2(0, 30)
	var walkers: Array[Citizen] = []
	for courage in [90.0, 10.0]:
		var c := Citizen.new()
		c.data = CitizenData.generate_all(1, city, Sim.make_rng(7), 0)[0]
		c.data.personality = &""
		c.data.courage = courage
		t.add_child(c)
		c.mode = Citizen.Mode.WALKING
		c.global_position = at
		walkers.append(c)
	EventBus.danger.emit(danger, 80.0, &"theft")
	for c in walkers:
		c._process(0.1)
	t.check(walkers[0].mode == Citizen.Mode.CONFRONTING, "courage 90: confronts the thief")
	t.check(walkers[0].global_position.distance_to(danger) < at.distance_to(danger), "and runs toward him")
	t.check(walkers[1].mode == Citizen.Mode.FLEEING, "courage 10: flees")
	t.check(walkers[1].global_position.distance_to(danger) > at.distance_to(danger), "and runs away")
	for c in walkers:
		c.remove_from_group("fleeing")
		c.free()
	return true
