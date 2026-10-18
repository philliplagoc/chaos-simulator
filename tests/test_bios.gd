extends RefCounted

## Whole words only, so "skill" doesn't trip "kill".
const BANNED := r"(?i)\b(gta|grand theft|rockstar|vice city|liberty city|los santos|blood|bloody|kill|killed|gun|guns)\b"


func run(t) -> bool:
	var text := FileAccess.get_file_as_string("res://data/bios.json")
	t.check(text != "", "data/bios.json exists")
	var bios: Variant = JSON.parse_string(text)
	t.check(bios is Dictionary, "bios.json is a JSON object")
	if not bios is Dictionary:
		return true
	var banned := RegEx.create_from_string(BANNED)
	t.check(banned.search("big GTA fan") != null and banned.search("great skill") == null, "banned-word filter works")
	var seen := {}
	for p in CitizenData.PROFESSION_MIX:
		var list: Array = bios.get(String(p), [])
		t.check(list.size() == 50, "50 bios for %s (got %d)" % [p, list.size()])
		var traits := {}
		for entry: Dictionary in list:
			var b := String(entry.get("text", ""))
			var kind := StringName(entry.get("trait", ""))
			t.check(CitizenData.TRAITS.has(kind), "known trait '%s' for: %s" % [kind, b])
			traits[kind] = traits.get(kind, 0) + 1
			var words := b.split(" ", false).size()
			t.check(words >= 5 and words <= 30, "5-30 words: %s" % b)
			t.check(not seen.has(b), "unique: %s" % b)
			seen[b] = true
			t.check(banned.search(b) == null, "no banned words in: %s" % b)
		for kind in CitizenData.TRAITS:
			t.check(traits.get(kind, 0) >= 3, "%s has 3+ %s bios" % [p, kind])
	t.check(seen.size() == 300, "300 bios in total")
	return true
