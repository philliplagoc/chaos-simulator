class_name Nav
extends RefCounted
## Three AStarGrid2D grids over the CityMap. Paths come back as world positions
## (cell centers). Orthogonal moves only.
##   road:     cars (road + crosswalk cells)
##   walk:     citizens (sidewalk + crosswalk cells)
##   jaywalk:  impatient citizens (sidewalk + crosswalk + road cells)

var city: CityMap
var road := AStarGrid2D.new()
var walk := AStarGrid2D.new()
var jaywalk := AStarGrid2D.new()


func _init(c: CityMap) -> void:
	city = c
	for g: AStarGrid2D in [road, walk, jaywalk]:
		g.region = Rect2i(0, 0, CityMap.W, CityMap.H)
		g.cell_size = Vector2(CityMap.CELL, CityMap.CELL)
		g.offset = Vector2(CityMap.CELL, CityMap.CELL) / 2.0
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		g.update()
	for y in CityMap.H:
		for x in CityMap.W:
			var p := Vector2i(x, y)
			road.set_point_solid(p, not city.is_road(p))
			walk.set_point_solid(p, not city.is_walkable(p))
			jaywalk.set_point_solid(p, not (city.is_walkable(p) or city.is_road(p)))


func road_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return road.get_point_path(from, to)


func walk_path(from: Vector2i, to: Vector2i, impatient := false) -> PackedVector2Array:
	return (jaywalk if impatient else walk).get_point_path(from, to)
