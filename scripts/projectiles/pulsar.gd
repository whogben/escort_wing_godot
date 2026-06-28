extends Projectile
class_name Pulsar
## Legacy pulsar draw/collision fallback. Prefer Projectile.create_from_info("Pulsar", ...).

var max_lifetime: float
var length: float = 15
var color: Color = Color(1.0, 0.5, 0.0)

func setup(pos: Vector2, rot: float, speed_val: float, life: float, dmg: float, tm: int, col: Color = Color(1.0, 0.5, 0.0)):
	position = pos
	rotation = rot
	speed = speed_val
	lifetime = life
	max_lifetime = life
	damage = dmg
	team = tm
	color = col
	velocity = Vector2(cos(rot), sin(rot)) * speed
	
	z_index = GameState.ZLayer.PROJECTILES

func _collide_with_ship(ship: Ship, delta: float) -> bool:
	# Use same segment logic as LaserBurst to prevent tunneling
	var head = global_position
	var travel_vec = velocity * delta
	var back_vec = velocity.normalized() * length
	var tail = head - back_vec - travel_vec
	
	var closest = Collision.get_closest_point_on_segment(ship.global_position, head, tail)
	
	if closest.distance_to(ship.global_position) <= ship.info.radius:
		ship.health -= damage
		
		# Hit effect
		var pfx = ParticleInfo.named("gatling_laser_hit") # Reusing generic hit
		if pfx:
			var p = Particles.new()
			p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
			get_parent().add_child(p)
			var hit_angle = (ship.global_position - global_position).angle()
			p.burst(pfx, closest.x, closest.y, rad_to_deg(hit_angle))
			
		SoundSystem.play("impact_1", global_position, self, 0.0, 1.0)
		return true
		
	return false

func _process(delta: float):
	super._process(delta)
	queue_redraw() # Force redraw for the pulsating effect

func _draw():
	# Draw pulsating trail
	# Ported from pulsar.draw() in Bmx
	var max_dist = 40
	var max_size = 3.0
	
	if max_lifetime <= 0: return
	
	var life_ratio = (max_lifetime - lifetime) / max_lifetime
	var max_alpha = (1.0 - life_ratio) * 0.5 + 0.1
	
	# We draw a series of circles trailing behind
	# Since we are in local coordinates, the trail goes along the negative X axis
	
	for i in range(0, max_dist, 4):
		var factor = (max_dist - i) / float(max_dist)
		var alpha = factor * max_alpha
		var size = max_size * factor
		var c = color
		c.a = alpha
		
		# Draw circles trailing behind (-x direction)
		draw_circle(Vector2(-i, 0), size, c)
