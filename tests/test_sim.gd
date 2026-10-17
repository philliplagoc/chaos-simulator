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
	return true
