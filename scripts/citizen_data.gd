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


## Build `count` citizens. At most `max_cars` of them own a car (~40% chance each).
static func generate_all(count: int, city: CityMap, rng: RandomNumberGenerator, max_cars: int) -> Array[CitizenData]:
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
		out.append(d)
	return out


## Fisher-Yates shuffle with our seeded RNG (Array.shuffle() uses the global one).
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## One line that captures the starting state, for determinism checks.
func summary() -> String:
	return "%d|%s|%s|%d|%d|%s|%d|%.2f|%.2f|%.2f|%s" % [id, name, profession, home, work, has_car, shift_start, money, hunger, patience, bio]


func profession_label() -> String:
	return String(profession).replace("_", " ").capitalize()
