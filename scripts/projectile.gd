extends Node2D
class_name Projectile

## Base class for all projectiles.
## Handles movement, lifetime, and collision detection against ships.

var team: int = 0
var dead: bool = false

# Movement
var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var lifetime: float = 1.0

# Damage
var damage: float = 0.0

func _process(delta: float):
	if dead:
		return
		
	# 1. Update Lifetime
	lifetime -= delta
	if lifetime <= 0.0:
		expire()
		return

	# 2. Move
	position += velocity * delta
	
	# 3. Check Collisions
	check_collisions(delta)

## Checks for collisions against all active ships.
func check_collisions(delta: float):
	for ship in GameState.ships:
		# Skip dead ships or friendly fire
		if ship.health <= 0:
			continue
		if ship.info and ship.info.team == team:
			continue
			
		if _collide_with_ship(ship, delta):
			# If the projectile returns true, it consumed itself
			kill()
			break

## Virtual method: Return true if collision occurred and projectile should die.
func _collide_with_ship(ship: Ship, _delta: float) -> bool:
	# Default: Simple circle-circle collision
	var dist_sq = global_position.distance_squared_to(ship.global_position)
	var r = ship.info.radius
	
	if dist_sq < r * r:
		ship.health -= damage
		on_hit_ship(ship)
		return true
		
	return false

## Optional hook for effects when hitting a ship
func on_hit_ship(_ship: Ship):
	pass

## Called when lifetime ends naturally
func expire():
	dead = true
	queue_free()

## Called when projectile hits something or is destroyed
func kill():
	dead = true
	queue_free()


## Spawn a projectile from a `.pfo` name (data-driven), with legacy class fallback.
static func create_from_info(
	type_name: String,
	tm: int,
	pos: Vector2,
	angle_rad: float,
	inertia: Vector2 = Vector2.ZERO
) -> Projectile:
	var p_info := ProjectileInfo.named(type_name)
	if p_info:
		return DataProjectile.spawn_from_info(p_info, tm, pos, angle_rad, inertia)
	return _create_legacy(type_name, tm, pos, angle_rad, inertia)


static func _create_legacy(
	type_name: String,
	tm: int,
	pos: Vector2,
	angle_rad: float,
	inertia: Vector2
) -> Projectile:
	var p: Projectile = null
	var extra_speed := inertia.length()
	match type_name:
		"LaserBurst", "Standard Laser Pulse":
			p = LaserBurst.new()
			p.setup(pos, angle_rad, 1000.0 + extra_speed, 0.4, 3.0, tm)
		"Miniature Laser Pulse":
			p = LaserBurst.new()
			p.setup(pos, angle_rad, 400.0 + extra_speed, 0.3, 1.5, tm, Color(1.0, 155.0 / 255.0, 0.0))
		"Pulsar":
			p = Pulsar.new()
			p.setup(pos, angle_rad, 700.0 + extra_speed, 0.5, 3.0, tm)
		"Flak Rocket":
			p = FlakRocket.new()
			p.setup(pos, angle_rad, 350.0 + extra_speed, 1.0, 550.0, tm)
	return p
