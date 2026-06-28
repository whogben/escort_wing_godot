class_name Controller
extends Node
## Base class for ship controllers.
## A controller is a child node of a Ship that sets the Ship's intent variables.

var ship: Ship

func _enter_tree():
	var parent = get_parent()
	if parent is Ship:
		ship = parent
	else:
		push_warning("Controller node must be a child of a Ship node.")

func _process(delta: float) -> void:
	if ship:
		control(delta)

## Virtual method to be overridden by subclasses.
## Called every frame to update the ship's intentions.
func control(_delta: float) -> void:
	pass
