extends Projectile
class_name LaserBurst
## Legacy segment-hit laser fallback. Prefer Projectile.create_from_info("Standard Laser Pulse", ...).

var length: float = 15.0
var width: float = 1.2
var color: Color = Color(1.0, 0.5, 0.0)

func setup(pos: Vector2, rot: float, speed_val: float, life: float, dmg: float, tm: int, col: Color = Color(1.0, 0.5, 0.0)):
	position = pos
	rotation = rot
	speed = speed_val
	lifetime = life
	damage = dmg
	team = tm
	color = col
	
	# Set velocity vector
	velocity = Vector2(cos(rot), sin(rot)) * speed
	
	# Set Z-Index
	z_index = GameState.ZLayer.PROJECTILES

func _draw():
	# Draw a line from current position backwards
	# Since we are in local space, (0,0) is head. (-length, 0) is tail.
	draw_line(Vector2.ZERO, Vector2(-length, 0), color, width)

func _collide_with_ship(ship: Ship, delta: float) -> bool:
	# Raycast/Segment collision to prevent tunneling
	# Segment goes from current position (head) backwards to where the tail was last frame
	# Head is current global_position
	# Tail is head - velocity direction * (length + distance moved this frame)
	var head = global_position
	# Calculate the vector representing the full length of the dangerous segment this frame
	# It includes the physical length of the laser AND the distance it covered
	var travel_vec = velocity * delta
	var back_vec = velocity.normalized() * length
	var tail = head - back_vec - travel_vec
	
	# We check distance from the ship center to this segment
	var closest_point = Collision.get_closest_point_on_segment(ship.global_position, head, tail)
	var dist = closest_point.distance_to(ship.global_position)
	
	if dist <= ship.info.radius:
		ship.health -= damage
		
		# Spawn hit effect
		var pfx = ParticleInfo.named("gatling_laser_hit")
		if pfx:
			# Use a new Particles instance for the hit effect
			var p = Particles.new()
			p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
			get_parent().add_child(p)
			var hit_angle = (ship.global_position - global_position).angle()
			p.burst(pfx, closest_point.x, closest_point.y, rad_to_deg(hit_angle))
		
		# Play impact sound
		SoundSystem.play("impact_1", global_position, self, 0.0, 1.0)
		
		return true
		
	return false
