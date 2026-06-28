extends Weapon
class_name FlakRocketArray
## A weapon that fires volleys of flak rockets.

var spread: float = 2.0
var speed: float = 350.0
var lifetime: float = 1.0
var rval: int = 255
var gval: int = 255
var bval: int = 255
var sound_name: String = "missile_launch" # Original says "missile_launch"
var volume: float = 0.05
var sound_wait: float = 0.5
var sound_wait_max: float = 0.0

var rockets: int = 2
var max_rockets: int = 2
var fire_timer: float = 0.0
var fire_wait: float = 0.2
var left_right_offset: float = 15.0
var left_right: int = 1

func _init():
	weapon_name = "Flak Rocket Array"
	power = 3.0
	base_range = 400.0
	reload_wait = 7.0 # Long reload for the array

func get_range() -> float:
	if not ship: return base_range
	return (ship.speed + speed) * lifetime

func get_spread() -> float:
	return 25.0

func get_ammo_count() -> int:
	return rockets

func _process(delta: float):
	sound_wait -= delta
	reload_timer -= delta # Logic override: this weapon reloads ammo over time
	
	if reload_timer <= 0.0:
		reload_timer = reload_wait
		rockets += 1
		if rockets > max_rockets:
			rockets = max_rockets
			
	fire_timer -= delta

# Override fire to handle the volley logic
func fire():
	if not ship or ship.health <= 0.0:
		return

	if rockets > 0 and fire_timer <= 0.0:
		_fireshot()
		rockets -= 1
		fire_timer = fire_wait
		
		# Reset reload timer if we still have rockets to fire? 
		# Original: If rockets > 0 Then reloadTimer = reloadWait
		# This means you can't reload while firing the volley?
		if rockets > 0:
			reload_timer = reload_wait

func _fireshot():
	left_right = left_right * -1
	
	var rot = ship.rotation_degrees
	var rot_rad = deg_to_rad(rot)
	
	var dx = cos(deg_to_rad(rot + 90)) * left_right_offset * left_right
	var dy = sin(deg_to_rad(rot + 90)) * left_right_offset * left_right
	
	# PFX
	var pfx = ParticleInfo.named("rocket_launch")
	if pfx:
		var p = Particles.new()
		p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
		ship.get_parent().add_child(p)
		
		var fire_x = ship.position.x + dx + 8 * cos(rot_rad)
		var fire_y = ship.position.y + dy + 8 * sin(rot_rad)
		p.burst(pfx, fire_x, fire_y, rot)
	
	# Projectile
	var spawn_pos := Vector2(ship.position.x + dx, ship.position.y + dy)
	var spread_val := randf_range(-spread, spread)
	var final_rot := deg_to_rad(rot + spread_val)
	var inertia := Vector2(cos(rot_rad), sin(rot_rad)) * ship.speed + Vector2(ship.vx, ship.vy)
	var proj := Projectile.create_from_info("Flak Rocket", ship.combat_team(), spawn_pos, final_rot, inertia)
	if proj:
		ship.get_parent().add_child(proj)
	
	# Sound
	if sound_wait <= 0:
		SoundSystem.play("rocket_launch", ship.position, ship, volume)
		sound_wait = sound_wait_max
