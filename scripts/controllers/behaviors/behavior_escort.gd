class_name BehaviorEscort
extends AIBehavior

# Constants matching original game
const MIN_SHUFFLE_TIME = 7.0
const MAX_SHUFFLE_TIME = 16.0
const MIN_DIST = 70.0
const MAX_DIST = 140.0
const ALIGN_DIST = 100.0

var passive_mode: String = "inflight"
var shuffle_timer: float = 0.0
var aligning: bool = false

# World-space offset from escorted ship (fixed when slot is picked, like original)
var offset_x: float = 0.0
var offset_y: float = 0.0

# Reference to escorting ship needed for _pick_new_slot
var _cached_escorting: Ship = null

func _init():
	shuffle_timer = randf_range(MIN_SHUFFLE_TIME, MAX_SHUFFLE_TIME)

func update(delta: float, controller: AIController) -> void:
	var escorting = controller.escort_target
	if not is_instance_valid(escorting) or escorting.health <= 0:
		controller.ship.speed_intent = 0.0
		_cached_escorting = null
		return

	# Pick initial slot on first valid update (needs escorting reference)
	if _cached_escorting != escorting:
		_cached_escorting = escorting
		_pick_new_slot(escorting)
		passive_mode = "inflight"
		aligning = false

	if passive_mode == "holding_position":
		# Actively maintain formation to prevent drift
		controller.match_speed(escorting.forward_speed())
		controller.match_angle(escorting.rotation)
		
		shuffle_timer -= delta
		if shuffle_timer < 0:
			passive_mode = "inflight"
			_pick_new_slot(escorting)
			shuffle_timer = randf_range(MIN_SHUFFLE_TIME, MAX_SHUFFLE_TIME)
			aligning = false
			
	if passive_mode == "inflight":
		# Target position uses fixed world-space offset (like original)
		var target_pos = escorting.global_position + Vector2(offset_x, offset_y)
		
		var dist_sq = controller.ship.global_position.distance_squared_to(target_pos)
		
		if dist_sq < ALIGN_DIST * ALIGN_DIST:
			aligning = true
			
		if aligning:
			controller.match_speed(escorting.forward_speed())
			controller.match_angle(escorting.rotation)
			
			var speed_diff = abs(controller.ship.forward_speed() - escorting.forward_speed())
			var rot_diff = abs(angle_difference(controller.ship.rotation, escorting.rotation))
			
			# Original used tight tolerances: speed < 0.1, angle < 0.2 degrees
			if speed_diff < 10.0 and rot_diff < 0.2:
				passive_mode = "holding_position"
		else:
			controller.turn_towards_point(target_pos)
			# Original: escorting.speed + Sqr(sqrdist) * .2 + 30
			var catchup_speed = escorting.forward_speed() + sqrt(dist_sq) * 0.2 + 30.0
			controller.match_speed(catchup_speed)

func _pick_new_slot(escorting: Ship):
	# Original logic:
	# dist = Rand(pMinDist, pMaxDist)
	# ang = i.rot + Rand(15, 90) + Rand(0, 1) * 180
	# ptx = Cos(ang) * dist; pty = Sin(ang) * dist
	
	var dist = randf_range(MIN_DIST, MAX_DIST)
	# Pick angle: escorted ship's current rotation + (15-90 degrees) + (0 or 180)
	# This places the escort in the forward-side or rear-side quadrants
	var side_offset = 180.0 if randf() > 0.5 else 0.0
	var ang_deg = rad_to_deg(escorting.rotation) + randf_range(15.0, 90.0) + side_offset
	var ang_rad = deg_to_rad(ang_deg)
	
	# Store as fixed world-space offset
	offset_x = cos(ang_rad) * dist
	offset_y = sin(ang_rad) * dist
