class_name HumanController
extends Controller
## Maps player input to ship control.

func control(_delta: float) -> void:
	if not ship:
		return

	if GameState.block_player_input:
		ship.turn_intent = 0.0
		ship.speed_intent = 0.0
		ship.primary_fire_intent = false
		ship.secondary_fire_intent = false
		return
		
	# Reset intentions
	ship.turn_intent = 0.0
	ship.speed_intent = 0.0
	ship.primary_fire_intent = false
	ship.secondary_fire_intent = false
	
	# Steering
	if Input.is_action_pressed("turn_left"):
		ship.turn_intent -= 1.0
	if Input.is_action_pressed("turn_right"):
		ship.turn_intent += 1.0
		
	# Throttle
	if Input.is_action_pressed("throttle_up"):
		ship.speed_intent += 1.0
	if Input.is_action_pressed("throttle_down"):
		ship.speed_intent -= 1.0
		
	# Weapons
	if Input.is_action_pressed("fire_primary"):
		ship.primary_fire_intent = true
	if Input.is_action_pressed("fire_secondary"):
		ship.secondary_fire_intent = true
