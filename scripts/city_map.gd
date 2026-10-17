class_name CityMap
extends RefCounted
## The fixed district layout. Pure data, no randomness, no nodes.
## Roads are 1 cell wide and run edge to edge: x=32, x=64, y=18, y=36.
## That makes a tic-tac-toe grid: 4 signalized intersections, 9 blocks.

enum Cell { BLOCK, ROAD, SIDEWALK, CROSSWALK }

const W := 96
const H := 54
const CELL := 32
const ROAD_X: Array[int] = [32, 64]
const ROAD_Y: Array[int] = [18, 36]
## Block spans between the sidewalks, inclusive [first, last].
const BLOCK_X: Array[Vector2i] = [Vector2i(0, 30), Vector2i(34, 62), Vector2i(66, 95)]
const BLOCK_Y: Array[Vector2i] = [Vector2i(0, 16), Vector2i(20, 34), Vector2i(38, 53)]
## [block col, block row, type, label, entrance side (-1 = north, 1 = south)]
const LAYOUT := [
	[0, 0, &"home", "Maple Flats", 1],
	[1, 0, &"office", "Tower One", 1],
	[2, 0, &"home", "Birch Court", 1],
	[0, 1, &"cafe", "Bean There", -1],
	[1, 1, &"park", "Central Park", -1],
	[2, 1, &"bank", "First Bank", -1],
	[0, 2, &"shop", "Corner Shop", -1],
	[1, 2, &"gas", "Gas & Go", -1],
	[2, 2, &"lot", "Parking", -1],
]

var cells := PackedByteArray()
## Each: {type, label, rect: Rect2i, entrance, curb, lot: Vector2i, side: int}
## lot = parking spot just inside the block; side = -1 entrance faces north, 1 south.
var destinations: Array[Dictionary] = []


func _init() -> void:
	cells.resize(W * H)
	for y in H:
		for x in W:
			cells[y * W + x] = Cell.ROAD if (x in ROAD_X or y in ROAD_Y) else Cell.BLOCK
	for y in H:
		for x in W:
			if cells[y * W + x] == Cell.BLOCK and _touches_road(Vector2i(x, y)):
				cells[y * W + x] = Cell.SIDEWALK
	for i in intersections():
		for d in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
			cells[(i.y + d.y) * W + i.x + d.x] = Cell.CROSSWALK
	for row in LAYOUT:
		var bx: Vector2i = BLOCK_X[row[0]]
		var by: Vector2i = BLOCK_Y[row[1]]
		var rect := Rect2i(bx.x, by.x, bx.y - bx.x + 1, by.y - by.x + 1)
		var mid_x := bx.x + (bx.y - bx.x) / 2
		var side: int = row[4]
		var edge_y := by.y if side == 1 else by.x  # last block row on the entrance side
		destinations.append({
			"type": row[2],
			"label": row[3],
			"rect": rect,
			"lot": Vector2i(mid_x, edge_y),
			"entrance": Vector2i(mid_x, edge_y + side),
			"curb": Vector2i(mid_x, edge_y + side * 2),
			"side": side,
		})


func _touches_road(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if is_road(c + Vector2i(dx, dy)):
				return true
	return false


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func cell(c: Vector2i) -> int:
	return cells[c.y * W + c.x] if in_bounds(c) else Cell.BLOCK


## Cars drive on ROAD and CROSSWALK cells.
func is_road(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	var k := cells[c.y * W + c.x]
	return k == Cell.ROAD or k == Cell.CROSSWALK


## Walkers use SIDEWALK and CROSSWALK cells.
func is_walkable(c: Vector2i) -> bool:
	var k := cell(c)
	return in_bounds(c) and (k == Cell.SIDEWALK or k == Cell.CROSSWALK)


func intersections() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in ROAD_Y:
		for x in ROAD_X:
			out.append(Vector2i(x, y))
	return out


func is_intersection(c: Vector2i) -> bool:
	return c.x in ROAD_X and c.y in ROAD_Y


## Index of the first destination of this type (-1 if none).
func index_of(type: StringName) -> int:
	for i in destinations.size():
		if destinations[i].type == type:
			return i
	return -1


## One of 16 parking slots in a destination's block (two rows of 8 near the entrance).
func parking_slot(dest_index: int, slot: int) -> Vector2i:
	var d: Dictionary = destinations[dest_index]
	var s := slot % 16
	return d.lot + Vector2i((s % 8) - 4, -(s / 8) * d.side)


func destinations_of(type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in destinations:
		if d.type == type:
			out.append(d)
	return out


## Road cells on the map border, where the Car Thief leaves the map.
func edge_exits() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in ROAD_X:
		out.append(Vector2i(x, 0))
		out.append(Vector2i(x, H - 1))
	for y in ROAD_Y:
		out.append(Vector2i(0, y))
		out.append(Vector2i(W - 1, y))
	return out


func nearest_road_cell(c: Vector2i) -> Vector2i:
	var best := Vector2i(ROAD_X[0], clampi(c.y, 0, H - 1))
	for x in ROAD_X:
		var cand := Vector2i(x, clampi(c.y, 0, H - 1))
		if absi(cand.x - c.x) < absi(best.x - c.x) + absi(best.y - c.y):
			best = cand
	for y in ROAD_Y:
		var cand := Vector2i(clampi(c.x, 0, W - 1), y)
		if absi(cand.y - c.y) < absi(best.x - c.x) + absi(best.y - c.y):
			best = cand
	return best


func nearest_walkable_cell(c: Vector2i) -> Vector2i:
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and is_walkable(c + Vector2i(dx, dy)):
					return c + Vector2i(dx, dy)
	return destinations[0].entrance


static func cell_to_world(c: Vector2i) -> Vector2:
	return Vector2(c) * CELL + Vector2(CELL, CELL) / 2.0


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i((p / CELL).floor())


static func map_rect() -> Rect2:
	return Rect2(0, 0, W * CELL, H * CELL)
