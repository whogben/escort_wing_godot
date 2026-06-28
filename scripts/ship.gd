@tool
extends Node2D
class_name Ship
## A ship in the game. Replaces the class "craft" from the BlitzMax original.


## Ship info name. Set this in the editor to assign the ship info.
@export var info_name: String = ""

## Ship info. Uses the info name to get the info.
var info: ShipInfo = null

## Flight speed in pixels per second.
var speed: float = 0.0

## Turning speed in degrees per second.
var rot_speed_degrees: float = 0.0

## Blast velocity in pixels per second.
var vx: float = 0.0
var vy: float = 0.0

## Health in points.
var health: float = 0.0


## 1.0 = full accelerate, -1.0 = full decelerate, 0.0 = no change.
var speed_intent: float = 0.0

## 1.0 = full turn left, -1.0 = full turn right, 0.0 = no change.
var turn_intent: float = 0.0

## True = fire.
var primary_fire_intent: bool = false
var secondary_fire_intent: bool = false

var primary_weapons: Array[Weapon] = []
var secondary_weapons: Array[Weapon] = []
var automatic_weapons: Array[Weapon] = []

## First mounted primary/secondary (back-compat for UI and simple AI checks).
var primary_weapon: Weapon = null
var secondary_weapon: Weapon = null


var _engine_sprite: Sprite2D = null
var _ship_sprite: Sprite2D = null


func _process(delta: float):
	if Engine.is_editor_hint():
		return

	var lvl = GameState.current_level
	if lvl and lvl.briefing_active:
		return
	
	if health <= 0.0:
		_die()
		return

	_fly(delta)
	_blast(delta)
	_combat(delta)
	_update_damage_fx()
	_update_viewport_cull()

	# Health regeneration (sqrt(maxHealth) / 15 per second).
	health += sqrt(float(info.max_health)) / 15.0 * delta
	if health > info.max_health:
		health = info.max_health
	
	# Update engine alpha
	if info.has_engine_graphic:
		if _is_truespace():
			# In truespace, `speed` is a one-frame thrust flag (1 = accelerating).
			_engine_sprite.modulate.a = 1.0 if speed == 1.0 else 0.0
			speed = 0.0
		else:
			var engine_alpha = (speed - info.min_speed) / (info.max_speed - info.min_speed) - 0.1 + randf_range(0.0, 0.1)
			_engine_sprite.modulate.a = engine_alpha
	

func _is_truespace() -> bool:
	return GameState.level_medium == "truespace"


## Forward speed along the ship's nose. In air this is `speed`; in truespace it is the velocity projection.
func forward_speed() -> float:
	if _is_truespace():
		var forward := Vector2(cos(rotation), sin(rotation))
		return Vector2(vx, vy).dot(forward)
	return speed


## Sets forward speed, preserving lateral velocity in truespace.
func set_forward_speed(value: float) -> void:
	if _is_truespace():
		var forward := Vector2(cos(rotation), sin(rotation))
		var lateral := Vector2(-forward.y, forward.x)
		var lateral_speed := Vector2(vx, vy).dot(lateral)
		vx = forward.x * value + lateral.x * lateral_speed
		vy = forward.y * value + lateral.y * lateral_speed
		speed = 0.0
	else:
		speed = clamp(value, info.min_speed, info.max_speed)


func _fly(delta: float):
	if _is_truespace():
		_fly_truespace(delta)
	else:
		_fly_air(delta)


func _fly_air(delta: float):
	if speed_intent != 0.0:
		speed += info.acceleration * speed_intent * delta
		speed = clamp(speed, info.min_speed, info.max_speed)

	_apply_turn(delta)
	position += Vector2(cos(rotation), sin(rotation)) * speed * delta


func _fly_truespace(delta: float):
	if speed_intent != 0.0:
		var thrust: Vector2 = Vector2(cos(rotation), sin(rotation)) * info.acceleration * speed_intent * delta
		vx += thrust.x
		vy += thrust.y
		speed = 1.0 if speed_intent > 0.0 else -1.0

	_apply_turn(delta)


func _apply_turn(delta: float) -> void:
	if turn_intent != 0.0:
		rot_speed_degrees += info.rot_acceleration * turn_intent * delta
		rot_speed_degrees = clamp(rot_speed_degrees, -info.max_rot_speed, info.max_rot_speed)
	elif turn_intent == 0.0:
		rot_speed_degrees *= (1.0 - ((1.0 - info.rotdrag) * delta))

	rotation += deg_to_rad(rot_speed_degrees) * delta


func _blast(delta: float):
	if _is_truespace():
		position += Vector2(vx, vy) * delta
		return

	if vx == 0.0 and vy == 0.0:
		return

	position += Vector2(vx, vy) * delta
	vx *= (1.0 - ((1.0 - info.drag) * delta))
	vy *= (1.0 - ((1.0 - info.drag) * delta))
	if abs(vx) < 3.0:
		vx = 0.0
	if abs(vy) < 3.0:
		vy = 0.0

func _init() -> void:
	# Create sprites
	_engine_sprite = Sprite2D.new()
	var engine_material = CanvasItemMaterial.new()
	engine_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_engine_sprite.material = engine_material
	_engine_sprite.modulate.a = 0.0
	add_child(_engine_sprite)

	_ship_sprite = Sprite2D.new()
	add_child(_ship_sprite)

func _ready():
	# attempt to determine ship info from the name (unless it was already set)
	if info == null:
		info = ShipInfo.named(info_name)
		if info == null:
			push_error("Ship info " + info_name + " not found")
			return
	
	# apply the graphics
	_ship_sprite.texture = GameData.load_texture(GameData.get_data_path(GameData.Type.SHIP_GFX, info.img_name))
	_ship_sprite.modulate.r = info.r / 255.0
	_ship_sprite.modulate.g = info.g / 255.0
	_ship_sprite.modulate.b = info.b / 255.0
	if info.has_engine_graphic:
		_engine_sprite.texture = GameData.load_texture(GameData.get_data_path(GameData.Type.SHIP_GFX, info.img_name + "_engine"))
	
	# Set the initial variables
	health = info.max_health
	speed = info.min_speed

	if Engine.is_editor_hint():
		return
	
	# Register with GameState
	GameState.ships.append(self)

	# Add weapons (Runtime only)
	for entry in info.primary_weapons:
		_mount_weapon(entry, primary_weapons)
	if primary_weapons.size() > 0:
		primary_weapon = primary_weapons[0]
	for entry in info.secondary_weapons:
		_mount_weapon(entry, secondary_weapons)
	if secondary_weapons.size() > 0:
		secondary_weapon = secondary_weapons[0]
	for entry in info.automatic_weapons:
		_mount_weapon(entry, automatic_weapons)


func _exit_tree():
	# Unregister from GameState
	if not Engine.is_editor_hint():
		if self in GameState.ships:
			GameState.ships.erase(self)

## Applies an impulse to the ship, such as from an explosion.
func impulse(angle_degrees: float, force: float, delta: float):
	var fval = (force / float(info.mass)) * delta
	vx += cos(deg_to_rad(angle_degrees)) * fval
	vy += sin(deg_to_rad(angle_degrees)) * fval


func _mount_weapon(entry: ShipInfo.WeaponEntry, weapon_list: Array[Weapon]) -> void:
	if entry.weapon_name.is_empty():
		return
	var w := Weapon.create(entry.weapon_name, entry.overrides)
	if w:
		add_child(w)
		weapon_list.append(w)


func fire_primary() -> void:
	for w in primary_weapons:
		w.fire()


func fire_secondary() -> void:
	for w in secondary_weapons:
		w.fire()


func fire_automatic() -> void:
	for w in automatic_weapons:
		if GameState.weapon_should_fire(w):
			w.fire()


func get_primary_range() -> float:
	var best := 0.0
	for w in primary_weapons:
		best = maxf(best, w.get_range())
	return best


func _combat(_delta: float):
	if primary_fire_intent:
		fire_primary()
	if secondary_fire_intent:
		fire_secondary()
	fire_automatic()


func _update_damage_fx() -> void:
	if health >= info.fire_health and health < info.smoke_health and info.smoke_fx != "":
		_burst_damage_fx(info.smoke_fx)
	if health < info.fire_health and info.fire_fx != "":
		_burst_damage_fx(info.fire_fx)


func _burst_damage_fx(fx_name: String) -> void:
	var pfx := ParticleInfo.named(fx_name)
	if pfx == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	var burst_count := int(info.radius / 16.0) + 1
	for i in burst_count:
		var offset_dist := randf_range(info.radius / -3.0 * 2.0 + 7.0, info.radius / 3.0 * 2.0 - 10.0)
		var offset_dir := deg_to_rad(randf_range(0.0, 355.0))
		var px := position.x + cos(offset_dir) * offset_dist
		var py := position.y + sin(offset_dir) * offset_dist
		var p := Particles.new()
		p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
		parent.add_child(p)
		p.burst(pfx, px, py, rad_to_deg(rotation))


func _update_viewport_cull() -> void:
	visible = GameState.is_near_player_x(global_position)

func _die():
	if not Engine.is_editor_hint():
		var lvl = GameState.current_level
		if lvl and self == GameState.player:
			lvl.notify_player_death()
			_reparent_player_camera_to_level(lvl)
	# Simple death handling
	if info.death_fx != "":
		var pfx = ParticleInfo.named(info.death_fx)
		if pfx:
			var p = Particles.new()
			p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
			get_parent().add_child(p)
			p.burst(pfx, position.x, position.y)
	
	if info.explosion_sound != "":
		SoundSystem.play(info.explosion_sound, position, self)
		
	queue_free()


## Keep the view on the death site: `PlayerCamera` is normally parented to the player and would be freed with them.
func _reparent_player_camera_to_level(lvl: Node2D) -> void:
	for child in get_children():
		if child is PlayerCamera:
			var cam := child as PlayerCamera
			cam.reparent(lvl, true)
			cam.make_current()
			return
