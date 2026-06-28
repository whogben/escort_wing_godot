extends Projectile
class_name DataProjectile

var info: ProjectileInfo
var max_lifetime: float = 0.4
var seeking_speed: float = 0.0
var impulse: float = 0.0
var length: float = 15.0
var width: float = 1.2
var death_effect: String = "standard hit"
var run_fx: String = "nothing"
var hit_fx: String = "nothing"
var hit_sfx: String = "nothing"
var hit_volume: float = 0.1
var draw_color: Color = Color.WHITE
var image_mode: String = "rect"
var sprite_texture: Texture2D = null
var target_ship: Ship = null
var retarget_timer: float = 0.0
var _trail_accum: float = 0.0


static func spawn_from_info(
	p_info: ProjectileInfo,
	tm: int,
	pos: Vector2,
	angle_rad: float,
	inertia: Vector2
) -> DataProjectile:
	var p := DataProjectile.new()
	p.info = p_info
	p.team = tm
	p.position = pos
	p.rotation = angle_rad
	p.max_lifetime = p_info.max_lifetime
	p.lifetime = p_info.max_lifetime
	p.speed = float(p_info.speed)
	p.damage = p_info.damage
	p.impulse = p_info.impulse
	p.length = float(p_info.length)
	p.width = p_info.width
	p.death_effect = p_info.death_effect
	p.run_fx = p_info.run_fx
	p.hit_fx = p_info.hit_fx
	p.hit_sfx = p_info.sfx_name
	p.hit_volume = p_info.volume
	p.seeking_speed = float(p_info.seeking_speed)
	p.draw_color = Color(p_info.cr / 255.0, p_info.cg / 255.0, p_info.cb / 255.0)
	p.image_mode = p_info.image
	if p.image_mode.begins_with("file:"):
		var gfx_name := p.image_mode.substr(5)
		var path := GameData.get_data_path(GameData.Type.WEAPON_GFX, gfx_name)
		if path != "":
			p.sprite_texture = GameData.load_texture(path)
	p.velocity = Vector2(cos(angle_rad), sin(angle_rad)) * p.speed + inertia
	p.z_index = GameState.ZLayer.PROJECTILES
	return p


func _process(delta: float) -> void:
	if dead:
		return
	visible = GameState.is_near_player_x(global_position)
	if run_fx != "nothing" and delta > 0.0 and delta < 0.049:
		_trail_accum += delta
		if _trail_accum >= 0.02:
			_trail_accum = 0.0
			var pfx := ParticleInfo.named(run_fx)
			if pfx:
				var p := Particles.new()
				p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
				get_parent().add_child(p)
				p.burst(pfx, global_position.x, global_position.y, rad_to_deg(rotation))
	super._process(delta)
	if seeking_speed != 0.0:
		_update_seeking(delta)
	queue_redraw()


func _update_seeking(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		retarget_timer = 0.3043478
		target_ship = null
		var best_dist := 0.0
		for s in GameState.ships:
			if not is_instance_valid(s) or s.health <= 0.0:
				continue
			if s.info.team == team:
				continue
			var dist := global_position.distance_squared_to(s.global_position)
			if target_ship == null or dist < best_dist:
				target_ship = s
				best_dist = dist
	if target_ship and is_instance_valid(target_ship):
		var target_angle := global_position.angle_to_point(target_ship.global_position)
		var turn := _turn_towards(rotation, target_angle, seeking_speed * delta)
		if GameState.level_medium == "truespace":
			velocity -= Vector2(cos(rotation), sin(rotation)) * speed
			rotation += deg_to_rad(seeking_speed) * turn * delta
			velocity += Vector2(cos(rotation), sin(rotation)) * speed
		else:
			rotation += deg_to_rad(seeking_speed) * turn * delta
			velocity = Vector2(cos(rotation), sin(rotation)) * speed


static func _turn_towards(rot: float, target: float, step: float) -> float:
	var diff := wrapf(target - rot, -PI, PI)
	if abs(diff) < step:
		return 0.0
	return 1.0 if diff > 0.0 else -1.0


func _draw() -> void:
	if image_mode == "nothing":
		return
	if image_mode == "rect":
		draw_rect(Rect2(0, -width * 0.5, length, width), draw_color)
	elif image_mode == "pulsar":
		var maxdist := 40.0
		var maxsize := 3.0
		var maxalpha := (1.0 - ((max_lifetime - lifetime) / max_lifetime)) * 0.5 + 0.1
		for i in range(0, int(maxdist), 4):
			var alpha := (maxdist - i) / maxdist * maxalpha
			var size := maxsize * (maxdist - i) / maxdist
			draw_circle(Vector2(-i, 0), size, Color(draw_color, alpha))
	elif sprite_texture:
		draw_texture(
			sprite_texture,
			Vector2(-sprite_texture.get_width() * 0.5, -sprite_texture.get_height() * 0.5),
			draw_color
		)


func check_collisions(delta: float) -> void:
	if death_effect == "none":
		return
	for ship in GameState.ships:
		if ship.health <= 0.0:
			continue
		if ship.info and ship.info.team == team:
			continue
		if death_effect == "explosion":
			var det := length
			var dist := global_position.distance_to(ship.global_position)
			if dist <= det + ship.info.radius:
				_explode()
				return
		elif death_effect in ["standard hit", "no death"]:
			var hit: Vector2 = _segment_hit_point(ship, delta)
			if hit != Vector2.INF:
				if death_effect == "standard hit":
					ship.health -= damage
					_spawn_hit_fx(hit, ship.global_position)
					_spawn_hit_explosion(hit)
					kill()
					return
				else:
					ship.health -= damage * delta
		else:
			if _collide_with_ship(ship, delta):
				kill()
				return


func _segment_hit_point(ship: Ship, delta: float) -> Vector2:
	var head := global_position
	var travel := velocity * delta
	var tail_dir := Vector2(cos(rotation), sin(rotation))
	var tail := head - tail_dir * length - travel
	var closest := Collision.get_closest_point_on_segment(ship.global_position, head, tail)
	if closest.distance_to(ship.global_position) > ship.info.radius:
		return Vector2.INF
	return closest


func _spawn_hit_fx(at: Vector2, toward = null) -> void:
	var hit_angle := rad_to_deg(rotation)
	if toward is Vector2:
		hit_angle = rad_to_deg((toward - at).angle())
	var pfx := ParticleInfo.named(hit_fx)
	if pfx:
		var p := Particles.new()
		p.z_index = GameState.ZLayer.PFX_EXPLOSIONS
		get_parent().add_child(p)
		p.burst(pfx, at.x, at.y, hit_angle)
	if hit_sfx != "nothing":
		SoundSystem.play(hit_sfx, at, self, hit_volume)


func _spawn_hit_explosion(at: Vector2) -> void:
	if impulse <= 0.0:
		return
	var ex := Explosion.new()
	ex.setup_explosion(at, team, 50.0, impulse, 0.0, 0.25)
	get_parent().add_child(ex)


func _explode() -> void:
	var ex := Explosion.new()
	ex.setup_explosion(global_position, team, width, impulse, damage, 0.25)
	get_parent().add_child(ex)
	_spawn_hit_fx(global_position)
	kill()


func expire() -> void:
	if death_effect == "explosion":
		_explode()
	else:
		super.expire()
