extends Weapon
class_name RakingLaser
## A continuous beam weapon that rakes across targets.

var spread: float = 1.0
var sound_name: String = "laser_2"
var volume: float = 0.05
var sound_wait: float = 0.0
var sound_wait_max: float = 0.5

var firing_frames: int = -1
var closest_hit_dist: float = 0.0

func _init():
	weapon_name = "Raking Laser"
	power = 20.0
	base_range = 250.0
	reload_wait = 0.0 # Continuous fire logic handled in process

func get_spread() -> float:
	return 15.0

func _process(delta: float):
	sound_wait -= delta
	
	if firing_frames >= 0:
		var closest_ship: Ship = null
		var last_dist_sq = 999999999.0
		
		# Find closest ship intersected by beam
		var start = ship.global_position
		# Use global rotation to be safe
		var rot_rad = deg_to_rad(ship.global_rotation_degrees)
		var end = start + Vector2.from_angle(rot_rad) * base_range
		
		for ship_entry in GameState.get_ships_by_distance(ship.position):
			var target = ship_entry["ship"]
			
			if target.info.team == ship.info.team:
				continue
				
			# Recalculate distance using global positions for safety
			var dist_sq = start.distance_squared_to(target.global_position)
			
			if dist_sq < last_dist_sq:
				# Check collision with line
				var segment_vec = end - start
				var vec_to_target = target.global_position - start
				var t = vec_to_target.dot(segment_vec) / segment_vec.length_squared()
				
				# Ignore targets behind the ship
				if t < 0.0:
					continue
					
				var close_p = Collision.get_closest_point_on_segment(target.global_position, start, end)
				if close_p.distance_to(target.global_position) <= target.info.radius:
					closest_ship = target
					last_dist_sq = dist_sq
		
		if closest_ship:
			closest_hit_dist = sqrt(last_dist_sq)
			
			# Hit PFX
			var pfx = ParticleInfo.named("laser_fire")
			if pfx:
				var p = Particles.new()
				p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
				ship.get_parent().add_child(p)
				
				var hit_x = ship.position.x + cos(rot_rad) * closest_hit_dist
				var hit_y = ship.position.y + sin(rot_rad) * closest_hit_dist
				# Angle is opposite to ship rotation (hit normal approx)
				p.burst(pfx, hit_x, hit_y, ship.rotation_degrees + 180)
			
			# Damage
			closest_ship.health -= delta * power
			
		# Sound
		if sound_wait <= 0:
			SoundSystem.play(sound_name, ship.position, ship, volume)
			sound_wait = sound_wait_max

		queue_redraw()

	firing_frames -= 1

func fire():
	if not ship or ship.health <= 0.0:
		return
	
	firing_frames = 2 # Keep firing for a couple frames
	closest_hit_dist = base_range
	queue_redraw()

func _draw():
	if firing_frames <= 0:
		return
	
	# Draw multiple beams for effect
	for i in range(randi_range(1, 3)):
		var alpha = randf_range(0.5, 1.0)
		var line_w = randf_range(1.0, 5.0)
		var beam_rot = deg_to_rad(randf_range(-spread, spread))
		
		var rand_col_val = randi() % 200
		var col = Color(1.0, (55 + rand_col_val)/255.0, rand_col_val/255.0, alpha)
		
		# End point varies slightly
		var dist = closest_hit_dist + randf_range(-2, 2)
		var end_pos = Vector2(cos(beam_rot) * dist, sin(beam_rot) * dist)
		
		draw_line(Vector2.ZERO, end_pos, col, line_w)
