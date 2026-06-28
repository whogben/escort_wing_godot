extends Projectile
class_name FlakRocket
## Legacy proximity-detonation rocket fallback. Prefer Projectile.create_from_info("Flak Rocket", ...).

var explosion_radius: float = 200.0
var explosion_force: float = 300000.0
var explosion_damage: float = 9.0
var detonation_range: float = 40.0

func setup(pos: Vector2, rot: float, speed_val: float, life: float, dmg: float, tm: int):
	position = pos
	rotation = rot
	speed = speed_val
	lifetime = life
	damage = dmg # Direct hit damage
	team = tm
	velocity = Vector2(cos(rot), sin(rot)) * speed
	
	# Set Z-Index
	z_index = GameState.ZLayer.PROJECTILES

func _draw():
	# Simple rocket drawing
	# We can use draw primitives for now to keep it dependency-free vs assets
	var c = Color(0.8, 0.8, 0.8)
	
	# Draw body
	draw_rect(Rect2(-10, -3, 20, 6), c)
	
	# Draw engine flare (simple orange rect)
	draw_rect(Rect2(-14, -2, 4, 4), Color(1, 0.5, 0))

func _process(delta: float):
	super._process(delta)
	
	# Trail Effect
	# We can spawn a small smoke puff occasionally
	# For simplicity/performance in this port, we might just rely on the existing particle system
	# if we had a reference to it.
	if randf() < delta * 60.0: # ~Every frame at 60fps, but regulated
		var pfx = ParticleInfo.named("missile_trail")
		if pfx:
			# We need to spawn this in the world, not as a child of the rocket (so it doesn't move with it)
			var p = Particles.new()
			p.z_index = GameState.ZLayer.PFX_TRAILS
			get_parent().add_child(p)
			p.burst(pfx, global_position.x, global_position.y, rotation_degrees + 180)

func _collide_with_ship(ship: Ship, _delta: float) -> bool:
	# Proximity detonation check
	var dist_sq = global_position.distance_squared_to(ship.global_position)
	var det_dist = detonation_range + ship.info.radius
	
	if dist_sq <= det_dist * det_dist:
		# We don't apply direct damage here, we explode!
		# The explosion will handle the damage.
		# Returning true here kills the rocket.
		return true
		
	return false

func kill():
	_explode()
	super.kill()

func expire():
	_explode()
	super.expire()

func _explode():
	# Create Explosion
	var exp_node = Explosion.new()
	exp_node.setup_explosion(global_position, team, explosion_radius, explosion_force, explosion_damage)
	
	# Add to scene
	get_parent().add_child(exp_node)
	
	# PFX
	var pfx = ParticleInfo.named("shrapnel_explosion")
	if pfx:
		var p = Particles.new()
		p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
		get_parent().add_child(p)
		p.burst(pfx, global_position.x, global_position.y)
	
	# Sound
	SoundSystem.play("flak_explosion", global_position, self)
