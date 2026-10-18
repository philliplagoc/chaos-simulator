class_name CitizenData
extends RefCounted
## Everything that makes one citizen who they are, generated from the seed.
## Pure data (no nodes) so it can be tested and compared between runs.

const PROFESSION_MIX := {
	&"office_worker": 12,
	&"bank_teller": 5,
	&"barista": 5,
	&"shop_clerk": 5,
	&"delivery_driver": 5,
	&"retiree": 8,
}
const WORKPLACE := {
	&"office_worker": &"office",
	&"bank_teller": &"bank",
	&"barista": &"cafe",
	&"shop_clerk": &"shop",
	&"delivery_driver": &"shop",
	&"retiree": &"",
}
## Shift [start, end] in minutes after midnight. Retirees have none.
const SHIFTS := {
	&"office_worker": [480, 1020],
	&"bank_teller": [510, 990],
	&"barista": [390, 870],
	&"shop_clerk": [540, 1080],
	&"delivery_driver": [480, 960],
	&"retiree": [-1, -1],
}
## Each bio carries one of these. Courage is 0 (flight) to 100 (fight), drawn
## from the range. The other keys scale existing needs knobs (see trait_value()).
const TRAITS := {
	&"hothead": {"label": "Hothead: short fuse", "courage": [70.0, 95.0], "patience_regen": 0.4, "scare_loss": 2.0},
	&"hero": {"label": "Hero: runs toward trouble", "courage": [80.0, 100.0]},
	&"nervous": {"label": "Nervous: first to run", "courage": [0.0, 15.0]},
	&"snacker": {"label": "Snacker: always hungry", "courage": [20.0, 60.0], "hunger_rate": 1.5},
	&"penny_pincher": {"label": "Penny pincher: hates spending", "courage": [20.0, 60.0], "bank_below": 80.0, "shop_score": 15.0},
	&"chill": {"label": "Chill: hard to rattle", "courage": [30.0, 70.0], "patience_regen": 2.0},
}
const FIRST_NAMES: Array[String] = [
	"Ada", "Bo", "Cleo", "Dev", "Eli", "Fern", "Gus", "Hana", "Ira", "Jun",
	"Kit", "Lena", "Milo", "Nia", "Otto", "Pia", "Quinn", "Rosa", "Sol", "Tess",
	"Uma", "Vic", "Wren", "Xavi", "Yara", "Zed", "Abe", "Bea", "Cyd", "Dot",
]
const LAST_NAMES: Array[String] = [
	"Applebaum", "Birch", "Cobble", "Dimsdale", "Eckles", "Fiddler", "Gumm",
	"Hollow", "Inkwell", "Jumble", "Kettle", "Lumpkin", "Muddle", "Nettles",
	"Oddsworth", "Puddle", "Quill", "Rumble", "Snickett", "Thimble", "Umber",
	"Varnish", "Wobble", "Yarrow", "Zing", "Bramble", "Crumb", "Dabble",
	"Fumble", "Grizzle",
]

var id := 0
var name := ""
var profession: StringName = &"retiree"
var home := 0          # destination index in Sim.city.destinations
var work := -1         # destination index, -1 for retirees
var has_car := false
var shift_start := -1  # minutes after midnight, -1 = no shift
var shift_end := -1
var money := 50.0      # 0-100, spent at the cafe and shop, refilled at the bank
var hunger := 0.0      # 0-100, rises over time, reset at the cafe
var patience := 100.0  # 0-100, drains when stuck, low = jaywalk / run yellows
var bio := ""
var personality: StringName = &""  # a TRAITS key, from the bio ("" = no trait)
var courage := 50.0    # 0-100, flight to fight


## Build `count` citizens. At most `max_cars` of them own a car (~40% chance each).
## `bios` maps profession name -> Array of {trait, text} (see load_bios()).
static func generate_all(count: int, city: CityMap, rng: RandomNumberGenerator, max_cars: int, bios := {}) -> Array[CitizenData]:
	var jobs: Array[StringName] = []
	for p: StringName in PROFESSION_MIX:
		for n in roundi(PROFESSION_MIX[p] * count / 40.0):
			jobs.append(p)
	while jobs.size() < count:
		jobs.append(&"office_worker")
	jobs.resize(count)
	shuffle(jobs, rng)
	var homes := [city.index_of(&"home")]
	for i in city.destinations.size():
		if city.destinations[i].type == &"home" and i != homes[0]:
			homes.append(i)
	var pools := {}
	for p in bios:
		pools[p] = (bios[p] as Array).duplicate()
	var out: Array[CitizenData] = []
	var cars := 0
	for i in count:
		var d := CitizenData.new()
		d.id = i
		d.name = "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)], LAST_NAMES[rng.randi_range(0, LAST_NAMES.size() - 1)]]
		d.profession = jobs[i]
		d.home = homes[rng.randi_range(0, homes.size() - 1)]
		var wp: StringName = WORKPLACE[d.profession]
		d.work = city.index_of(wp) if wp != &"" else -1
		d.has_car = rng.randf() < 0.4 and cars < max_cars
		if d.has_car:
			cars += 1
		var shift: Array = SHIFTS[d.profession]
		if shift[0] >= 0:
			var jitter := rng.randi_range(-20, 20)
			d.shift_start = shift[0] + jitter
			d.shift_end = shift[1] + jitter
		d.money = rng.randf_range(30.0, 90.0)
		d.hunger = rng.randf_range(0.0, 40.0)
		d.patience = rng.randf_range(70.0, 100.0)
		var pool: Array = pools.get(String(d.profession), [])
		if not pool.is_empty():
			var b: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))  # no repeats
			d.bio = b.text
			d.personality = StringName(b.trait)
			var r: Array = TRAITS[d.personality].courage
			d.courage = rng.randf_range(r[0], r[1])
		out.append(d)
	return out


## {"office_worker": [{"trait": "chill", "text": "..."}, ...], ...} from data/bios.json, or {} if missing.
static func load_bios(path := "res://data/bios.json") -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Fisher-Yates shuffle with our seeded RNG (Array.shuffle() uses the global one).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## One line that captures the starting state, for determinism checks.
func summary() -> String:
	return "%d|%s|%s|%d|%d|%s|%d|%.2f|%.2f|%.2f|%s|%s|%.2f" % [id, name, profession, home, work, has_car, shift_start, money, hunger, patience, bio, personality, courage]


func profession_label() -> String:
	return String(profession).replace("_", " ").capitalize()


## A trait's tuning value, or `default` if this citizen's trait doesn't set it.
func trait_value(key: String, default: float) -> float:
	return TRAITS.get(personality, {}).get(key, default)
