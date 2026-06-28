extends Weapon
class_name DataWeapon

var info: WeaponInfo
var facing: String = "forwards"
var angular_offset: float = 0.0
var forward_offset: float = 0.0
var perpendicular_offset: float = 0.0
var turrets_type: String = "none"
var num_turrets: int = 1
var current_turret: int = 0
var turret_spacing: int = 0
var fire_sequence: String = "sequential"
var spread: int = 0
var charges: int = -1
var charges_max: int = -1
var recharge_wait: float = 0.0
var recharge_timer: float = 0.0
var fire_wait: float = 0.1
var fire_timer: float = 0.0
var bullet_name: String = "none"
var pfx_name: String = "nothing"
var sfx_name: String = "nothing"
var volume: float = 0.05
var sound_wait: float = 0.0
var sound_wait_max: float = 0.0
var is_raking: bool = false
var raking_active: float = 0.0
var closest_hit: Array[float] = []
var slow_turret_rot: float = 0.0
var _radar_sprite: Sprite2D = null
var _image_sprites: Array[Sprite2D] = []

static func create_from_info(w_info: WeaponInfo, overrides: Dictionary = {}) -> DataWeapon:
	var w := DataWeapon.new()
	w.info = w_info
	w.weapon_name = w_info.name
	w.facing = w_info.facing
	w.angular_offset = w_info.angular_offset
	w.forward_offset = w_info.forward_offset
	w.perpendicular_offset = w_info.perpendicular_offset
	w.turrets_type = w_info.turrets_type
	w.num_turrets = maxi(1, w_info.num_turrets)
	w.turret_spacing = w_info.turret_spacing
	w.fire_sequence = w_info.fire_sequence
	w.spread = w_info.spread
	w.charges_max = w_info.charges_max
	w.charges = w_info.charges_max
	w.recharge_wait = w_info.recharge_wait
	w.fire_wait = w_info.fire_wait
	w.is_raking = w_info.is_raking
	w.bullet_name = w_info.bullet_name
	w.pfx_name = w_info.pfx_name
	w.sfx_name = w_info.sfx_name
	w.volume = w_info.volume
	w.sound_wait_max = w_info.sound_wait_max
	w.closest_hit.resize(w.num_turrets)
	for i in w.num_turrets:
		w.closest_hit[i] = 0.0
	w._apply_overrides(overrides)
	if w_info.has_special("radar"):
		w.angular_offset = randf() * 360.0
	return w


func _apply_overrides(overrides: Dictionary) -> void:
	for key in overrides:
		match key:
			"perpendicular_offset":
				perpendicular_offset = float(overrides[key])
			"forward_offset":
				forward_offset = float(overrides[key])
			"angular_offset":
				angular_offset = float(overrides[key])
			"turretSpacing":
				turret_spacing = int(overrides[key])


func _ready() -> void:
	_setup_visual_sprites()


func _setup_visual_sprites() -> void:
	if not info:
		return
	if info.has_special("radar"):
		var spec := info.get_special("radar")
		_radar_sprite = _make_weapon_sprite("radar", Color(spec.r / 255.0, spec.g / 255.0, spec.b / 255.0))
	for s in info.specials:
		if not s.tag.begins_with("image:"):
			continue
		var gfx_name := s.tag.substr(6)
		var col := Color(s.r / 255.0, s.g / 255.0, s.b / 255.0)
		if s.value != 0:
			for _turret in num_turrets:
				_image_sprites.append(_make_weapon_sprite(gfx_name, col))
		else:
			_image_sprites.append(_make_weapon_sprite(gfx_name, col))


func _make_weapon_sprite(gfx_name: String, modulate_color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	var path := GameData.get_data_path(GameData.Type.WEAPON_GFX, gfx_name)
	sprite.texture = GameData.load_texture(path)
	sprite.modulate = modulate_color
	add_child(sprite)
	return sprite


func _base_local_pos() -> Vector2:
	return Vector2(forward_offset, perpendicular_offset)


func _turret_local_pos(turret: int) -> Vector2:
	var side := _offset_from_turret(turret)
	var local_facing := _local_angle_from_world_deg(_facing_angle_deg(turret))
	return _base_local_pos() + Vector2(cos(local_facing + PI * 0.5), sin(local_facing + PI * 0.5)) * side


func _update_visual_sprites() -> void:
	if not info:
		return
	if _radar_sprite:
		_radar_sprite.position = _base_local_pos()
		_radar_sprite.rotation = deg_to_rad(angular_offset)
	var image_idx := 0
	for s in info.specials:
		if not s.tag.begins_with("image:"):
			continue
		if s.value != 0:
			for turret in num_turrets:
				if image_idx >= _image_sprites.size():
					break
				_image_sprites[image_idx].position = _turret_local_pos(turret)
				_image_sprites[image_idx].rotation = _local_angle_from_world_deg(_facing_angle_deg(turret))
				image_idx += 1
		elif image_idx < _image_sprites.size():
			_image_sprites[image_idx].position = _base_local_pos()
			_image_sprites[image_idx].rotation = deg_to_rad(angular_offset)
			image_idx += 1


func _needs_canvas_draw() -> bool:
	if not info:
		return false
	if info.has_special("tracer") or info.has_special("mine"):
		return true
	if is_raking and raking_active > 0.0 and info.has_special("raking laser"):
		return true
	return false


func _process(delta: float) -> void:
	if not ship:
		return
	sound_wait -= delta
	_update_specials(delta)
	_update_visual_sprites()
	if is_raking and raking_active > 0.0:
		_update_raking(delta)
		raking_active -= delta
		queue_redraw()
		return
	if fire_timer > 0.0:
		fire_timer -= delta
	if charges < charges_max and charges_max > 0:
		recharge_timer -= delta
		if recharge_timer <= 0.0:
			recharge_timer += recharge_wait
			charges += 1
	elif charges_max <= 0:
		recharge_timer = recharge_wait
	if info and info.has_special("mine"):
		_check_mine_proximity()
	if _needs_canvas_draw():
		queue_redraw()


func _update_specials(delta: float) -> void:
	if not info:
		return
	var radar := info.get_special("radar")
	if radar:
		angular_offset = fmod(angular_offset + radar.value * delta, 360.0)
	var slow := info.get_special("slow turret")
	if slow and ship:
		var target_angle := _nearest_enemy_angle()
		var base_rot := rad_to_deg(ship.rotation) + angular_offset
		var turn := _turn_dir(base_rot, target_angle, slow.value * delta)
		angular_offset = fmod(angular_offset + slow.value * turn * delta, 360.0)
		slow_turret_rot = slow.value * turn


func _turn_dir(from_deg: float, to_deg: float, step: float) -> float:
	var diff := wrapf(to_deg - from_deg, -180.0, 180.0)
	if abs(diff) < step:
		return 0.0
	return 1.0 if diff > 0.0 else -1.0


func _nearest_enemy_angle() -> float:
	var tx := _x_base()
	var ty := _y_base()
	var mindist := get_range() * get_range() * 2.0
	var best := rad_to_deg(ship.rotation)
	for s in GameState.ships:
		if not is_instance_valid(s) or s.health <= 0.0:
			continue
		if s.combat_team() == ship.combat_team():
			continue
		var dist := Vector2(tx, ty).distance_squared_to(s.global_position)
		if dist < mindist:
			mindist = dist
			best = rad_to_deg((s.global_position - Vector2(tx, ty)).angle())
	return best


func _check_mine_proximity() -> void:
	var mine := info.get_special("mine")
	if not mine or not ship:
		return
	var range_val := float(mine.value)
	for s in GameState.ships:
		if not is_instance_valid(s) or s.health <= 0.0:
			continue
		if s.combat_team() == ship.combat_team():
			continue
		var dist := ship.global_position.distance_to(s.global_position)
		if dist <= range_val + s.info.radius:
			var ex := Explosion.new()
			ex.setup_explosion(ship.global_position, ship.combat_team(), range_val * 1.1, 20.0 * 400000.0, ship.health, 0.1)
			ship.get_parent().add_child(ex)
			ship.health = 0.0
			return


func get_range() -> float:
	if bullet_name != "none":
		var p_info := ProjectileInfo.named(bullet_name)
		if p_info:
			var inertia := 0.0
			if _has_inertia():
				inertia = ship.speed if ship else 0.0
			return (inertia + p_info.speed) * p_info.max_lifetime
	if info:
		if info.has_special("raking laser"):
			return float(info.get_special("raking laser").value)
		if info.has_special("mine"):
			return float(info.get_special("mine").value)
		if info.has_special("tracer"):
			return float(info.get_special("tracer").value)
	return 0.0


func get_spread() -> float:
	return float(spread)


func get_ammo_count() -> int:
	return charges


func _has_inertia() -> bool:
	if GameState.level_medium == "truespace":
		return true
	if bullet_name != "none":
		var p_info := ProjectileInfo.named(bullet_name)
		if p_info and p_info.seeking_speed != 0:
			return false
	return true


func fire() -> void:
	if not ship or ship.health <= 0.0:
		return
	if is_raking:
		var rake := info.get_special("raking laser")
		if rake:
			raking_active = 2.0
			for i in num_turrets:
				closest_hit[i] = float(rake.value)
		return
	if fire_wait > 0.0:
		while fire_timer <= 0.0:
			_fire_shot()
			fire_timer += fire_wait


func _fire_shot() -> void:
	if charges == 0:
		return
	if fire_sequence == "sequential":
		_fire_from_turret(current_turret)
		current_turret = (current_turret + 1) % num_turrets
	elif fire_sequence == "simultaneous":
		for i in num_turrets:
			_fire_from_turret(i)
	elif fire_sequence == "random":
		_fire_from_turret(randi() % num_turrets)
	if charges > 0:
		charges -= 1
	if info and info.has_special("recoil"):
		var recoil := info.get_special("recoil")
		ship.impulse(_facing_angle_deg(0), float(recoil.value), 1.0)


func _fire_from_turret(turret: int) -> void:
	var facing_angle := deg_to_rad(_facing_angle_deg(turret))
	var firing_angle := facing_angle + deg_to_rad(randf_range(-spread, spread))
	var tx := _x_from_turret(turret)
	var ty := _y_from_turret(turret)
	firing_angle -= deg_to_rad(ship.rot_speed_degrees) * fire_timer
	tx -= (cos(ship.rotation) * ship.speed + ship.vx) * fire_timer
	ty -= (sin(ship.rotation) * ship.speed + ship.vy) * fire_timer
	if info and info.has_special("slow turret"):
		firing_angle += deg_to_rad(slow_turret_rot) * fire_timer
	if pfx_name != "nothing":
		var pfx := ParticleInfo.named(pfx_name)
		if pfx:
			var p := Particles.new()
			p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
			ship.get_parent().add_child(p)
			p.burst(pfx, tx + cos(firing_angle) * 8.0, ty + sin(firing_angle) * 8.0, rad_to_deg(firing_angle))
	if sfx_name != "nothing" and sound_wait <= 0.0:
		SoundSystem.play(sfx_name, Vector2(tx, ty), ship, volume)
		sound_wait = sound_wait_max
	var bullet_speed := 0.0
	var p_info := ProjectileInfo.named(bullet_name)
	if p_info:
		bullet_speed = float(p_info.speed)
	tx -= cos(firing_angle) * fire_timer * bullet_speed
	ty -= sin(firing_angle) * fire_timer * bullet_speed
	if bullet_name != "none":
		if p_info:
			var inertia := Vector2.ZERO
			if _has_inertia():
				inertia = Vector2(cos(ship.rotation), sin(ship.rotation)) * ship.speed + Vector2(ship.vx, ship.vy)
			var proj := Projectile.create_from_info(p_info.name, ship.combat_team(), Vector2(tx, ty), firing_angle, inertia)
			ship.get_parent().add_child(proj)
		elif ShipInfo.named(bullet_name):
			_spawn_ship_projectile(bullet_name, Vector2(tx, ty), firing_angle)


func _spawn_ship_projectile(ship_name: String, pos: Vector2, angle_rad: float) -> void:
	var lvl = GameState.current_level
	if lvl and lvl.has_method("_create_ship"):
		var new_ship: Ship = lvl._create_ship(ship_name, pos, angle_rad)
		if new_ship:
			new_ship.speed = new_ship.info.max_speed


func _facing_angle_deg(turret: int) -> float:
	var facing_angle := angular_offset
	if facing == "forwards":
		facing_angle += rad_to_deg(ship.rotation)
	elif facing == "turret":
		var tx := _x_base()
		var ty := _y_base()
		var mindist := get_range() * get_range()
		var found := false
		var target_rot := rad_to_deg(ship.rotation)
		for s in GameState.ships:
			if not is_instance_valid(s) or s.health <= 0.0:
				continue
			if s.combat_team() == ship.combat_team():
				continue
			var dist := Vector2(tx, ty).distance_squared_to(s.global_position)
			if dist < mindist:
				mindist = dist
				target_rot = rad_to_deg((s.global_position - Vector2(tx, ty)).angle())
				found = true
		if found:
			facing_angle += target_rot
		else:
			facing_angle += rad_to_deg(ship.rotation)
	if turrets_type == "angular array":
		facing_angle += (turret_spacing * (turret * 2 + 1 - num_turrets)) / 2.0
	return facing_angle


func _offset_from_turret(turret: int) -> float:
	if turrets_type == "parallel array":
		return (turret_spacing * (turret * 2 + 1 - num_turrets)) / 2.0
	return 0.0


func _x_base() -> float:
	return ship.position.x + cos(ship.rotation) * forward_offset + cos(ship.rotation + PI * 0.5) * perpendicular_offset


func _y_base() -> float:
	return ship.position.y + sin(ship.rotation) * forward_offset + sin(ship.rotation + PI * 0.5) * perpendicular_offset


func _x_from_turret(turret: int) -> float:
	var ang := deg_to_rad(_facing_angle_deg(turret))
	var side := _offset_from_turret(turret)
	return _x_base() + cos(ang + PI * 0.5) * side


func _y_from_turret(turret: int) -> float:
	var ang := deg_to_rad(_facing_angle_deg(turret))
	var side := _offset_from_turret(turret)
	return _y_base() + sin(ang + PI * 0.5) * side


func _update_raking(delta: float) -> void:
	var rake := info.get_special("raking laser")
	if not rake:
		return
	var range_val := float(rake.value)
	for turret in num_turrets:
		var facing_angle := deg_to_rad(_facing_angle_deg(turret))
		var firing_angle := facing_angle + deg_to_rad(randf_range(-spread, spread))
		var tx := _x_from_turret(turret)
		var ty := _y_from_turret(turret)
		var closest: Ship = null
		var last_dist := range_val * range_val + 200.0
		for s in GameState.ships:
			if not is_instance_valid(s) or s.health <= 0.0:
				continue
			if s.combat_team() == ship.combat_team():
				continue
			var sq := Vector2(tx, ty).distance_squared_to(s.global_position)
			if sq < last_dist and Collision.segment_hits_circle(Vector2(tx, ty), Vector2(tx + cos(firing_angle) * range_val, ty + sin(firing_angle) * range_val), s.global_position, float(s.info.radius)):
				closest = s
				last_dist = sq
		if closest:
			closest_hit[turret] = sqrt(last_dist)
			closest.health -= fire_wait * delta
			if pfx_name != "nothing":
				var pfx := ParticleInfo.named(pfx_name)
				if pfx:
					var p := Particles.new()
					p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
					ship.get_parent().add_child(p)
					var hit_x := tx + cos(firing_angle) * closest_hit[turret]
					var hit_y := ty + sin(firing_angle) * closest_hit[turret]
					p.burst(pfx, hit_x, hit_y, rad_to_deg(firing_angle) + 180.0)
		if sfx_name != "nothing" and sound_wait <= 0.0:
			SoundSystem.play(sfx_name, Vector2(tx, ty), ship, volume)
			sound_wait = sound_wait_max


func _draw() -> void:
	if not ship or not info:
		return
	var off := Vector2.ZERO
	if info.has_special("tracer"):
		_draw_tracer(off, info.get_special("tracer"))
	if info.has_special("mine"):
		_draw_mine_range(off, info.get_special("mine"))
	if is_raking and raking_active > 0.0 and info.has_special("raking laser"):
		_draw_raking(off, info.get_special("raking laser"))


## Weapon draw runs on a ship child node, so world-space turret math must be converted to local space.
func _local_from_world(world_pos: Vector2) -> Vector2:
	return ship.to_local(world_pos)


func _local_angle_from_world_deg(world_deg: float) -> float:
	return deg_to_rad(world_deg) - ship.rotation


func _draw_tracer(off: Vector2, spec: WeaponInfo.SpecialEntry) -> void:
	var range_val := float(spec.value)
	var col := Color(spec.r / 255.0, spec.g / 255.0, spec.b / 255.0, 0.6)
	for turret in num_turrets:
		var world_deg := _facing_angle_deg(turret)
		var world_ang := deg_to_rad(world_deg)
		var world_from := Vector2(_x_from_turret(turret), _y_from_turret(turret))
		var line_len := range_val
		var world_dir := Vector2(cos(world_ang), sin(world_ang))
		for s in GameState.ships:
			if not is_instance_valid(s) or s.health <= 0.0:
				continue
			if s.combat_team() == ship.combat_team():
				continue
			var sq := world_from.distance_squared_to(s.global_position)
			if sq < line_len * line_len:
				if Collision.segment_hits_circle(world_from, world_from + world_dir * line_len, s.global_position, float(s.info.radius)):
					line_len = sqrt(sq)
		var local_from := _local_from_world(world_from)
		var local_to := _local_from_world(world_from + world_dir * line_len)
		draw_line(off + local_from, off + local_to, col, 2.0)


func _draw_mine_range(off: Vector2, spec: WeaponInfo.SpecialEntry) -> void:
	var range_val := float(spec.value)
	draw_arc(off, range_val, 0.0, TAU, 48, Color(spec.r / 255.0, spec.g / 255.0, spec.b / 255.0, 0.05), 1.0)


func _draw_raking(off: Vector2, spec: WeaponInfo.SpecialEntry) -> void:
	var col := Color(spec.r / 255.0, spec.g / 255.0, spec.b / 255.0, 0.8)
	for turret in num_turrets:
		var world_deg := _facing_angle_deg(turret)
		var world_ang := deg_to_rad(world_deg)
		var world_from := Vector2(_x_from_turret(turret), _y_from_turret(turret))
		var world_dir := Vector2(cos(world_ang), sin(world_ang))
		var local_from := _local_from_world(world_from)
		var local_to := _local_from_world(world_from + world_dir * closest_hit[turret])
		draw_line(off + local_from, off + local_to, col, 2.0)
