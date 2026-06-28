class_name AIBehavior
extends RefCounted

## Base class for AI behaviors (The "Strategy").
## Behaviors are stateless logic blocks, or hold very little state.
## They dictate the ship's intentions based on the context provided by the controller.

func update(_delta: float, _controller: AIController) -> void:
	pass
