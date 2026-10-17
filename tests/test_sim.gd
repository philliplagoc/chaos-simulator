extends RefCounted

const SimScript := preload("res://scripts/sim.gd")


func run(t) -> bool:
	var a := SimScript.make_rng(42)
	var b := SimScript.make_rng(42)
	var c := SimScript.make_rng(43)
	var da: Array[int] = []
	var db: Array[int] = []
	var dc: Array[int] = []
	for i in 10:
		da.append(a.randi())
		db.append(b.randi())
		dc.append(c.randi())
	t.check(da == db, "same seed gives same draws")
	t.check(da != dc, "different seed gives different draws")
	t.check(SimScript.format_clock(SimScript.DAY_START) == "06:00", "day starts at 06:00")
	t.check(SimScript.format_clock(6 * 60 + 125) == "08:05", "06:00 + 125 min = 08:05")
	t.check(SimScript.format_clock(SimScript.DAY_MINUTES + 30) == "00:30", "clock wraps after midnight")
	t.check(is_equal_approx(SimScript.sim_to_seconds(SimScript.DAY_MINUTES), 720.0), "a full day is 12 real minutes")
	t.check(is_equal_approx(SimScript.sim_to_seconds(60.0), 30.0), "60 sim minutes = 30 real seconds")
	return true
