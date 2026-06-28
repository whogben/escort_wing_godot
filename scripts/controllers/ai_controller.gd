class_name AIController
extends Controller

## Base class for AI controllers.
## Holds state (targets, current behavior) and provides low-level flight helpers.

# Context / Blackboard
var target: Ship = null
var escort_target: Ship = null
var team: int = 0

# Strategy
var current_behavior: AIBehavior = null

func _process(delta: float) -> void:
	if not ship:
		return

	# Ensure team is synced
	if ship.info:
		team = ship.combat_team()
		
	# Reset intentions (AI is stateless per frame)
	ship.turn_intent = 0.0
	ship.speed_intent = 0.0
	ship.primary_fire_intent = false
	ship.secondary_fire_intent = false
		
	# 1. Update Strategy (Subclasses can override this to switch behaviors)
	_update_strategy(delta)
	
	# 2. Execute Behavior
	if current_behavior:
		current_behavior.update(delta, self)
	else:
		# Idle
		ship.speed_intent = 0.0
		ship.turn_intent = 0.0
		ship.primary_fire_intent = false
		ship.secondary_fire_intent = false

## Override this to implement "Commander" logic (picking targets, switching modes).
func _update_strategy(_delta: float) -> void:
	pass

# --- Low Level Helpers (The "Pilot" skills) ---

## Sets speed_intent to match a target speed.
func match_speed(target_speed: float):
	var current_speed: float = ship.forward_speed()
	if current_speed < target_speed - 5.0:
		ship.speed_intent = 1.0
	elif current_speed > target_speed + 5.0:
		ship.speed_intent = -1.0
	else:
		ship.speed_intent = 0.0

## Sets turn_intent to face a point.
func turn_towards_point(point: Vector2):
	var angle_to_target = ship.global_position.angle_to_point(point)
	match_angle(angle_to_target)

## Sets turn_towards_intent to face away from a point.
func turn_away_from_point(point: Vector2):
	var angle_to_target = ship.global_position.angle_to_point(point)
	match_angle(angle_to_target + PI) # Opposite direction

## Sets turn_intent to match a specific angle (in radians).
func match_angle(target_angle_rad: float):
	var current_angle = ship.rotation
	var diff = angle_difference(current_angle, target_angle_rad)
	
	# Deadzone of ~5 degrees (0.1 rad) to prevent jitter
	if abs(diff) < 0.1:
		ship.turn_intent = 0.0
	elif diff > 0:
		ship.turn_intent = 1.0 # Turn right (positive rotation is clockwise in Godot)
	else:
		ship.turn_intent = -1.0 # Turn left
