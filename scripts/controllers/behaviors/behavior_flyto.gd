class_name BehaviorFlyTo
extends AIBehavior

var target_point: Vector2

func _init(point: Vector2):
	target_point = point

func update(_delta: float, controller: AIController) -> void:
	controller.ship.speed_intent = 1.0
	controller.turn_towards_point(target_point)
