extends Node
## Autoload. Owns the only seeded RNG and the shared district map + grids.
## Never call the global randi()/randf().

var seed_value: int = 2026
var rng := RandomNumberGenerator.new()
var city := CityMap.new()
var nav := Nav.new(city)


func _ready() -> void:
	start_city(seed_value)


## Same seed -> same starting city. Reset calls this with the old seed.
func start_city(new_seed: int) -> void:
	seed_value = new_seed
	rng = make_rng(new_seed)


static func make_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r
