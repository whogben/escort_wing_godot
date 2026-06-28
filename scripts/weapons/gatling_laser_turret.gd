extends Weapon
class_name GatlingLaserTurret
## A gatling laser turret weapon.


var spread: float = 15.0
var speed: float = 400.0
var lifetime: float = 0.3
var length: float = 10.0
var width: float = 4.0
var rval: int = 255
var gval: int = 155
var bval: int = 0
var sound_name: String = "gatling_laser"
var volume: float = 0.05
var sound_wait: float = 0.0
var sound_wait_max: float = 0.0

var left_right_offset: float = 5
var left_right: int = 1

func _init():
	weapon_name = "Gatling Laser Turret"
	power = 1.5
	base_range = 400.0
	reload_wait = 0.1


func get_range(direction_degrees = null) -> float:
	if not ship: return base_range
	if direction_degrees == null:
		direction_degrees = ship.rotation_degrees
	# Project ship's velocity onto the firing direction
	var ship_speed_component = ship.speed * cos(deg_to_rad(direction_degrees - ship.rotation_degrees))
	# Total speed is projectile launch speed + ship's contribution
	return (speed + ship_speed_component) * lifetime

func get_spread() -> float:
	return 180.0

func _process(delta: float):
	sound_wait -= delta
	super._process(delta)

func fire():
	if not ship or ship.health <= 0.0:
		return

	while reload_timer <= 0.0:
		_fireshot()
		reload_timer += reload_wait


func _fireshot():
	# aim forward by default
	var target_rot = ship.rotation_degrees
	var target_ship = null

	# locate target ship if one is within range
	for ship_by_distance in GameState.get_ships_by_distance(ship.position):
		var _ship = ship_by_distance["ship"]
		var target_distance = ship_by_distance["distance"]

		# skip ships on our team
		if _ship.info.team == ship.info.team:
			continue
		
		# calculate the angle to target
		var angle_to = rad_to_deg(_ship.position.angle_to_point(ship.position))
		# calculate effective range in that direction
		var effective_range = get_range(angle_to)

		# Check distance
		if target_distance <= effective_range:
			target_ship = _ship
			target_rot = rad_to_deg(ship.position.angle_to_point(target_ship.position))
			break
		
		# Optimization: Since get_ships_by_distance is sorted, if we assume 
		# range is roughly uniform, we could break early, but range varies by angle relative to ship velocity.
		# However, if target_distance is WAY out of max possible range, we could break.
		if target_distance > base_range * 2: # heuristic
			break
	
	# Only auto-target if we found a target. Otherwise fire straight.
	# Original code: If humancontroller... then Return.
	# We'll just fire forward if no target for now (or maybe we shouldn't fire? 
	# Original says: If humancontroller(owner.control) = Null And targetrot = owner.rot Then Return
	# This implies turrets on AI ships don't fire unless they have a target.
	if target_ship == null and target_rot == ship.rotation_degrees:
		# Assuming we are AI for now if we are using this auto-turret logic?
		# Or maybe the player uses this?
		# If this is a passive turret, it shouldn't fire if no target.
		return
	
	left_right = left_right * -1

	# Calculate offset for "dual barrel" effect relative to firing angle
	# qCos(targetrot + 90) is basically cos(targetrot + 90)
	var dx = cos(deg_to_rad(target_rot + 90)) * left_right_offset * left_right
	var dy = sin(deg_to_rad(target_rot + 90)) * left_right_offset * left_right

	# Muzzle Flash PFX
	# burst(particleinfo.named("gatling_laser_fire"), owner.x + dx + 8*Cos(targetrot), owner.y + dy + 8*Sin(targetrot), targetrot)
	var pfx = ParticleInfo.named("gatling_laser_fire")
	if pfx:
		var p = Particles.new()
		p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
		ship.get_parent().add_child(p) # Add to world
		
		# Position: ship center + offset + barrel length (8)
		var fire_x = ship.position.x + dx + 8 * cos(deg_to_rad(target_rot))
		var fire_y = ship.position.y + dy + 8 * sin(deg_to_rad(target_rot))
		p.burst(pfx, fire_x, fire_y, target_rot)

	# Create Projectile
	var spawn_pos := Vector2(ship.position.x + dx, ship.position.y + dy)
	var spread_val := randf_range(-spread, spread)
	var final_rot := deg_to_rad(target_rot + spread_val)
	var inertia := Vector2(cos(ship.rotation), sin(ship.rotation)) * ship.speed + Vector2(ship.vx, ship.vy)
	var proj := Projectile.create_from_info("Miniature Laser Pulse", ship.info.team, spawn_pos, final_rot, inertia)
	if proj:
		ship.get_parent().add_child(proj)

	# Sound
	if sound_wait <= 0:
		SoundSystem.play(sound_name, ship.position, ship, volume)
		sound_wait = sound_wait_max
