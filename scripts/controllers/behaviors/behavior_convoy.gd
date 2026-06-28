class_name BehaviorConvoy
extends AIBehavior

## BlitzMax `convoyAI`: full throttle, primary and secondary fire always on (no turn intent).


func update(_delta: float, controller: AIController) -> void:
	if not controller.ship:
		return
	controller.ship.speed_intent = 1.0
	controller.ship.turn_intent = 0.0
	controller.ship.primary_fire_intent = true
	controller.ship.secondary_fire_intent = true
