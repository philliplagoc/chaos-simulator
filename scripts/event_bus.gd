extends Node
## Autoload. The only way agents and objects talk to each other.
## Emit:   EventBus.danger.emit(global_position, 96.0, &"crash")
## React:  EventBus.danger.connect(_on_danger)
## Kinds: &"crash", &"explosion", &"theft", &"ragdoll", &"water", &"panic", &"test"

signal danger(position: Vector2, radius: float, kind: StringName)
