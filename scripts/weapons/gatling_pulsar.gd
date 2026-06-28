extends Weapon
class_name GatlingPulsar
## A pulsating energy weapon.

var spread: float = 0.0
var speed: float = 700.0
var lifetime: float = 0.5
var length: float = 15.0
var width: float = 1.2
var rval: int = 255
var gval: int = 255
var bval: int = 0
var sound_name: String = "gatling_laser"
var volume: float = 0.05
var sound_wait: float = 0.5
var sound_wait_max: float = 0.0

var left_right_offset: float = 8.0
var left_right: int = 1

func _init():
	weapon_name = "Gatling Pulsar"
	power = 6.0
	base_range = 400.0
	reload_wait = 0.5

func get_range() -> float:
	if not ship: return base_range
	return (ship.speed + speed) * lifetime * 0.7

func get_spread() -> float:
	return 3.0

func _process(delta: float):
	sound_wait -= delta
	super._process(delta)

func fire():
	if not ship or ship.health <= 0.0:
		return

	while reload_timer <= 0.0:
		# Pulsar fires a burst of 4 shots in a pattern
		_fireshot()
		_fireshot()
		left_right_offset *= 2.0
		_fireshot()
		_fireshot()
		left_right_offset *= 0.5
		
		reload_timer += reload_wait

func _fireshot():
	left_right = left_right * -1
	
	var rot = ship.rotation_degrees
	var rot_rad = deg_to_rad(rot)
	
	var dx = cos(deg_to_rad(rot + 90)) * left_right_offset * left_right
	var dy = sin(deg_to_rad(rot + 90)) * left_right_offset * left_right
	
	# PFX
	var pfx = ParticleInfo.named("gatling_laser_fire")
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
	var proj := Projectile.create_from_info("Pulsar", ship.info.team, spawn_pos, final_rot, inertia)
	if proj:
		ship.get_parent().add_child(proj)
	
	# Sound
	if sound_wait <= 0:
		SoundSystem.play(sound_name, ship.position, ship, volume)
		sound_wait = sound_wait_max
