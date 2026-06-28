class_name SupportAI
extends AIController

const ENGAGEMENT_RANGE = 1000.0

var scan_timer: float = 0.0

func _init():
	pass

func _ready():
	if current_behavior == null:
		current_behavior = BehaviorEscort.new()
	scan_timer = 0.0
	_find_new_escort_target()

func _update_strategy(delta: float):
	scan_timer -= delta
	if scan_timer <= 0:
		scan_timer = randf_range(1.0, 2.0)
		_scan_for_targets()
		
	if target and (not is_instance_valid(target) or target.health <= 0):
		target = null
		
	if escort_target and (not is_instance_valid(escort_target) or escort_target.health <= 0):
		escort_target = null
		_find_new_escort_target()
		
	if target:
		if not (current_behavior is BehaviorAttack):
			current_behavior = BehaviorAttack.new()
	else:
		if not (current_behavior is BehaviorEscort):
			current_behavior = BehaviorEscort.new()
		if not escort_target or not is_instance_valid(escort_target):
			_find_new_escort_target()

func _scan_for_targets():
	var nearest = null
	var min_dist_sq = ENGAGEMENT_RANGE * ENGAGEMENT_RANGE
	
	for potential in GameState.ships:
		if potential.info and potential.info.team != team and potential.health > 0:
			var d = ship.global_position.distance_squared_to(potential.global_position)
			if d < min_dist_sq:
				min_dist_sq = d
				nearest = potential
	
	if nearest:
		target = nearest

func _find_new_escort_target():
	var nearest: Ship = null
	var min_dist_sq := INF

	# Match original BlitzMax behavior: escorts pick a craft to escort from the convoy ships list,
	# not "any friendly ship in the world" (which includes start ships, etc).
	var candidates: Array = []
	var level = GameState.current_level
	if level != null and level.convoy_ships.size() > 0:
		candidates = level.convoy_ships
	else:
		# Fallback (should be rare / only before the level fully initializes)
		candidates = GameState.ships

	for potential in candidates:
		if potential == ship:
			continue
		if not is_instance_valid(potential) or potential.health <= 0:
			continue
		if potential.info and potential.info.team != team:
			continue

		var d = ship.global_position.distance_squared_to(potential.global_position)
		if d < min_dist_sq:
			min_dist_sq = d
			nearest = potential

	escort_target = nearest
