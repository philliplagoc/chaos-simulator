class_name Art
extends RefCounted
## Where the Kenney sprites live. Everything falls back to simple shapes when a
## file is missing, so the game never breaks over art.

const CARS: Array[String] = [
	"res://art/sprites/car_0.png",
	"res://art/sprites/car_1.png",
	"res://art/sprites/car_2.png",
	"res://art/sprites/car_3.png",
	"res://art/sprites/car_4.png",
]
const PEOPLE := {
	&"office_worker": "res://art/sprites/office_worker.png",
	&"bank_teller": "res://art/sprites/bank_teller.png",
	&"barista": "res://art/sprites/barista.png",
	&"shop_clerk": "res://art/sprites/shop_clerk.png",
	&"delivery_driver": "res://art/sprites/delivery_driver.png",
	&"retiree": "res://art/sprites/retiree.png",
}
const THIEF := "res://art/sprites/thief.png"
const CAR_LENGTH := 24.0     # px on screen, nose to tail
const PERSON_SIZE := 16.0    # px on screen, shoulder to shoulder


static func texture(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


## A Sprite2D for a Kenney car (they point up; our cars point along +x).
static func car_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.rotation = PI / 2.0
	s.scale = Vector2.ONE * CAR_LENGTH / tex.get_height()
	s.show_behind_parent = true  # brake lights etc. draw on top
	return s


## A Sprite2D for a Kenney person (they face right, like our +x).
static func person_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * PERSON_SIZE / tex.get_height()
	s.show_behind_parent = true
	return s
