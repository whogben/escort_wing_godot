extends Projectile
class_name Explosion

var radius: float
var force: float
var max_time: float

func setup_explosion(pos: Vector2, tm: int, rad: float, frc: float, dmg: float, life: float = 0.25):
	position = pos
	team = tm
	radius = rad
	force = frc
	damage = dmg
	lifetime = life
	max_time = life
	velocity = Vector2.ZERO # Explosions don't move
	
	z_index = GameState.ZLayer.PFX_EXPLOSIONS

func _collide_with_ship(ship: Ship, delta: float) -> bool:
	# Check distance
	var dist = global_position.distance_to(ship.global_position) - ship.info.radius
	
	if dist < radius:
		if dist < 0: dist = 0
		
		# Calculate falloff
		# ratio goes from 1.0 (center/start) to 0.0 (edge/end)
		var dist_factor = 1.0 - (dist / radius)
		var time_factor = lifetime / max_time
		var ratio = dist_factor * time_factor
		
		if ratio > 0:
			# Apply Damage
			# We multiply by delta effectively? 
			# In Bmx: c.damage(ratio*damage) happens every frame of collision.
			# But 'damage' passed to explosion.create was "9" for flak.
			# If we apply 9 damage every frame for 0.25s, that's massive.
			# Let's check Bmx logic:
			# Bmx: "c.damage(ratio*damage)" inside update loop.
			# The Bmx loop was fixed timestep likely, or it didn't use delta for damage.
			# Wait, "ratio" includes "lifetime/maxtime".
			# As lifetime decreases, damage decreases.
			# It seems this is "damage per frame" in the original.
			# To normalize for Godot's variable timestep, we should probably multiply by something,
			# OR we assume damage is "per second" and multiply by delta.
			# However, if the original damage was e.g. 50, and it runs for 15 frames, that's 750 damage.
			# In Bmx: explosion.create(..., damage=50, ...)
			# If we look at FlakRocket in Bmx: damage=9. 
			# Let's assume we should scale by delta to be framerate independent.
			# But if the original value was designed for "per frame", we need to know the target FPS (usually 60).
			# So `damage * ratio * delta * 60` might be the faithful port.
			
			var damage_amount = damage * ratio
			
			# If the input damage is meant to be "total damage potential", we distribute it.
			# If it's "instant damage", we only do it once. 
			# But explosions last over time.
			# Let's trust the "per update" nature but scale by delta to be safe.
			# Let's apply a factor of 60 * delta to match 60FPS expectations.
			ship.health -= damage_amount * delta * 60.0
			
			# Apply Impulse
			var angle = global_position.angle_to_point(ship.global_position)
			ship.impulse(rad_to_deg(angle), force * ratio, delta)
		
	# Explosion never dies from hitting a ship; it dies when lifetime expires
	return false
