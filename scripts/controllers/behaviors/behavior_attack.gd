class_name BehaviorAttack
extends AIBehavior

const TURN_AWAY_RANGE = 200.0

const BURST_MIN = 1.0
const BURST_MAX = 2.0
const WAIT_MIN = 0.5
const WAIT_MAX = 1.0

var mode: int = 1 # 1=Attack (Fly To), 2=Retreat (Fly Away)

# Weapon Timers
var prim_timer: float = 1.0
var prim_wait: float = 0.0
var sec_timer: float = 1.0
var sec_wait: float = 0.0

func update(delta: float, controller: AIController) -> void:
	var target = controller.target
	if not is_instance_valid(target) or target.health <= 0:
		controller.target = null
		controller.ship.speed_intent = 0.0
		controller.ship.primary_fire_intent = false
		controller.ship.secondary_fire_intent = false
		return
		
	var dist_sq = controller.ship.global_position.distance_squared_to(target.global_position)
	var angle_to = controller.ship.global_position.angle_to_point(target.global_position)
	var angle_diff = abs(angle_difference(controller.ship.rotation, angle_to))
	
	# --- Firing Logic ---
	_update_weapons(delta, controller, dist_sq, angle_diff)
	
	# --- Movement Logic ---
	# Check if in primary weapon range (used for speed control)
	var in_primary_range = false
	var prim_range := controller.ship.get_primary_range()
	if prim_range > 0.0:
		in_primary_range = dist_sq <= (prim_range * prim_range * 0.8 * 0.8)
	
	if mode == 1: # Attack (flying at target)
		controller.turn_towards_point(target.global_position)
		
		# Original: decelerate when in primary weapon range, accelerate otherwise
		if in_primary_range:
			controller.ship.speed_intent = -1.0
		else:
			controller.ship.speed_intent = 1.0
			
		if dist_sq <= TURN_AWAY_RANGE * TURN_AWAY_RANGE:
			mode = 2
			
	elif mode == 2: # Retreat (flying away from target)
		controller.turn_away_from_point(target.global_position)
		controller.ship.speed_intent = 1.0
		
		# Original uses turnAwayRange for both switching to retreat AND returning to attack
		if dist_sq >= TURN_AWAY_RANGE * TURN_AWAY_RANGE:
			mode = 1

func _update_weapons(delta: float, controller: AIController, dist_sq: float, angle_diff: float):
	if controller.ship.primary_weapons.is_empty():
		controller.ship.primary_fire_intent = false
	else:
		_process_weapon_group(delta, controller, controller.ship.primary_weapons, true, dist_sq, angle_diff)

	if controller.ship.secondary_weapons.is_empty():
		controller.ship.secondary_fire_intent = false
	else:
		_process_weapon_group(delta, controller, controller.ship.secondary_weapons, false, dist_sq, angle_diff)

func _process_weapon_group(delta: float, controller: AIController, weapons: Array[Weapon], is_primary: bool, dist_sq: float, angle_diff: float):
	var range_val := 0.0
	var spread_rad := 0.0
	for weapon in weapons:
		range_val = maxf(range_val, weapon.get_range())
		spread_rad = maxf(spread_rad, deg_to_rad(weapon.get_spread()))
	_process_weapon(delta, controller, range_val, spread_rad, is_primary, dist_sq, angle_diff)


func _process_weapon(delta: float, controller: AIController, range_val: float, spread_rad: float, is_primary: bool, dist_sq: float, angle_diff: float):
	# Check if roughly in range (0.8 factor from original code to be safe)
	var in_range = dist_sq <= (range_val * range_val * 0.8 * 0.8)
	var aimed = angle_diff <= spread_rad
	
	# Update timers (using separate timers for prim/sec would require duplicating vars or passing them by ref)
	# Since GDScript doesn't support pass-by-ref for floats, I have to duplicate logic or use an object.
	# I'll just use the instance variables directly based on is_primary.
	
	var timer_ref = 0.0
	var wait_ref = 0.0
	
	if is_primary:
		timer_ref = prim_timer
		wait_ref = prim_wait
	else:
		timer_ref = sec_timer
		wait_ref = sec_wait
		
	# Timer Logic
	if wait_ref <= 0:
		timer_ref -= delta
		if timer_ref <= 0:
			wait_ref = randf_range(WAIT_MIN, WAIT_MAX)
	
	if wait_ref >= 0:
		wait_ref -= delta
		if wait_ref <= 0:
			timer_ref = randf_range(BURST_MIN, BURST_MAX)
			
	# Commit back variables
	if is_primary:
		prim_timer = timer_ref
		prim_wait = wait_ref
	else:
		sec_timer = timer_ref
		sec_wait = wait_ref
		
	# Set Intent
	var fire = in_range and timer_ref > 0 and aimed
	
	if is_primary:
		controller.ship.primary_fire_intent = fire
	else:
		controller.ship.secondary_fire_intent = fire
