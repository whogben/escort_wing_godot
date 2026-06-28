class_name AssaultAI
extends AIController

## Enemy AI that attacks convoy and escort ships.
## Matches the original convoyAssaultAI behavior:
## - 40% chance to target random convoy element
## - Otherwise, 50% chance to target random escort element
## - Falls back to closest escort, then closest enemy
## - Retargets when taking damage (targets closest enemy)
## - Retargets on timer (1-7 seconds) if no damage for 3+ seconds

var timer: float = 0.0
var damage_timer: float = 0.0
var last_health: float = 0.0

# References to convoy/escort ship lists (set by Level when spawning)
var convoy_targets: Array[Ship] = []

func _ready():
	current_behavior = BehaviorAttack.new()
	
	# Initial targeting (matches original create function logic)
	if ship:
		last_health = ship.health
	
	if randi_range(0, 100) <= 40:
		_target_random_convoy_element()
	else:
		if not _target_random_escort_element():
			_target_closest_enemy_unit()

func _update_strategy(delta: float):
	timer -= delta
	damage_timer += delta
	
	# Check for retargeting conditions (matches original update method)
	var target_invalid = (target == null or not is_instance_valid(target) or target.health <= 0)
	var should_retarget = target_invalid or (timer < 0 and damage_timer > 3.0)
	
	if should_retarget:
		timer = randf_range(1.0, 7.0)
		
		if randi_range(0, 100) <= 40:
			_target_random_convoy_element()
		else:
			if randi_range(0, 100) <= 50:
				_target_random_escort_element()
			else:
				if not _target_closest_escort_element():
					_target_closest_enemy_unit()
	
	# Damage-based retargeting: when health changes, reset damage timer and target closest enemy
	if ship and last_health != ship.health:
		damage_timer = 0.0
		last_health = ship.health
		_target_closest_enemy_unit()
	
	# Ensure behavior is attack
	if not (current_behavior is BehaviorAttack):
		current_behavior = BehaviorAttack.new()

func _target_random_convoy_element() -> bool:
	target = null
	
	# Get convoy ships from level
	var level = GameState.current_level
	var candidates: Array = convoy_targets if convoy_targets.size() > 0 else (level.convoy_ships if level else [])
	
	var valid_ships: Array[Ship] = []
	for s in candidates:
		if is_instance_valid(s) and s.health > 0:
			valid_ships.append(s)
	
	if valid_ships.size() > 0:
		target = valid_ships.pick_random()
		return true
	return false

func _target_random_escort_element() -> bool:
	target = null
	
	# Get escort ships from level
	var level = GameState.current_level
	if level == null:
		return false
	
	var valid_ships: Array[Ship] = []
	for s in level.escort_ships:
		if is_instance_valid(s) and s.health > 0:
			valid_ships.append(s)
	
	if valid_ships.size() > 0:
		target = valid_ships.pick_random()
		return true
	return false

func _target_closest_escort_element() -> bool:
	target = null
	
	var level = GameState.current_level
	if level == null:
		return false
	
	var closest: Ship = null
	var closest_dist_sq: float = INF
	
	for s in level.escort_ships:
		if is_instance_valid(s) and s.health > 0:
			var dist_sq = ship.global_position.distance_squared_to(s.global_position)
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest = s
	
	if closest:
		target = closest
		return true
	return false

func _target_closest_enemy_unit():
	target = null
	
	var closest: Ship = null
	var closest_dist_sq: float = INF
	
	for s in GameState.ships:
		if s.info and s.combat_team() != team and s.health > 0:
			var dist_sq = ship.global_position.distance_squared_to(s.global_position)
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest = s
	
	if closest:
		target = closest
