extends Node
## Autoload. Owns the only seeded RNG. Never call the global randi()/randf().

var seed_value: int = 2026
var rng := RandomNumberGenerator.new()


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
