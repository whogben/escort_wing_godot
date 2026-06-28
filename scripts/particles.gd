extends Node2D
class_name Particles
## A port of the original, hand-rolled particle system from BlitzMax.
## The Particles class is a holder for multiple Particle instances.
## The Particle class represents a single particle.
## The ParticleInfo class describes the behavior of a particle.

var particles: Array[Particle] = []
var spawn_timer: float = 0.0

# Shared textures for primitive shapes
static var white_pixel: Texture2D
static var circle_texture: Texture2D

# Shared materials for blend modes
static var mat_add: CanvasItemMaterial
static var mat_mix: CanvasItemMaterial
static var mat_mul: CanvasItemMaterial

func _ready():
	if white_pixel == null:
		var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		white_pixel = ImageTexture.create_from_image(img)
	
	if circle_texture == null:
		var size = 64
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center = Vector2(size / 2.0, size / 2.0)
		var radius = size / 2.0 - 2.0 # -2 to leave room for AA
		
		# Fill with transparent first
		img.fill(Color(0, 0, 0, 0))
		
		for y in range(size):
			for x in range(size):
				var dist = Vector2(x, y).distance_to(center)
				if dist <= radius:
					img.set_pixel(x, y, Color.WHITE)
				elif dist <= radius + 1.0:
					# Simple Anti-aliasing
					var alpha = 1.0 - (dist - radius)
					img.set_pixel(x, y, Color(1, 1, 1, alpha))
					
		circle_texture = ImageTexture.create_from_image(img)

	if mat_add == null:
		mat_add = CanvasItemMaterial.new()
		mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if mat_mix == null:
		mat_mix = CanvasItemMaterial.new()
		mat_mix.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	if mat_mul == null:
		mat_mul = CanvasItemMaterial.new()
		mat_mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL

func add_particle(info: ParticleInfo, x: float, y: float, ang_deg: float = 0.0):
	while spawn_timer <= 0:
		if info.is_collection:
			for p_name in info.collected_pfx:
				var sub_info = ParticleInfo.named(p_name)
				if sub_info:
					_create_single_particle(sub_info, x, y, ang_deg)
		else:
			spawn_timer = spawn_timer + randf_range(info.spawn_min_wait, info.spawn_max_wait)
			_create_single_particle(info, x, y, ang_deg)

func burst(info: ParticleInfo, x: float, y: float, ang_deg: float = 0.0):
	if info.is_collection:
		for p_name in info.collected_pfx:
			var sub_info = ParticleInfo.named(p_name)
			if sub_info:
				burst(sub_info, x, y, ang_deg)
	else:
		var count = randi_range(info.burst_min_particles, info.burst_max_particles)
		for i in range(count):
			_create_single_particle(info, x, y, ang_deg)

func _create_single_particle(info: ParticleInfo, x: float, y: float, ang_deg: float):
	var p = Particle.new()
	p.setup(info, x, y, ang_deg)
	
	# Set texture based on render mode
	if info.render_mode == 4:
		p.texture = info.render_graphic
	elif info.render_mode == 3:
		p.texture = circle_texture
	else:
		p.texture = white_pixel
	
	add_child(p)
	particles.append(p)

func _process(delta: float):
	if spawn_timer > 0:
		spawn_timer -= delta
		
	# Iterate backwards so we can remove items
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		
		# Update Logic ported from Bmx
		p.life_timer -= delta
		p.r += p.r_change_rate * delta
		p.g += p.g_change_rate * delta
		p.b += p.b_change_rate * delta
		p.alpha += p.alpha_change_rate * delta
		p.scale_val += p.scale_change_rate * delta
		
		p.vx += p.ax * delta + p.info.particle_x_gravity * delta
		p.vy += p.ay * delta + p.info.particle_y_gravity * delta
		
		# Drag
		p.vx = p.vx * (1.0 - p.info.particle_drag * delta)
		p.vy = p.vy * (1.0 - p.info.particle_drag * delta)
		
		p.x += p.vx * delta + p.info.particle_x_wind * delta
		p.y += p.vy * delta + p.info.particle_y_wind * delta
		
		p.v_rot += p.a_rot * delta
		p.rot += p.v_rot * delta
		
		# Sync to Node properties
		p.position = Vector2(p.x, p.y)
		p.rotation_degrees = p.rot
		p.scale = Vector2(p.scale_val, p.scale_val)
		
		var base_r = p.r / 255.0
		var base_g = p.g / 255.0
		var base_b = p.b / 255.0
		
		# Handle blend modes for correct fading behavior
		if p.info.render_blend == ParticleInfo.BLEND_LIGHT:
			# Additive: Multiply RGB by alpha to fade out
			p.modulate = Color(base_r * p.alpha, base_g * p.alpha, base_b * p.alpha, p.alpha)
		elif p.info.render_blend == ParticleInfo.BLEND_SHADE:
			# Multiplicative: Interpolate towards white as alpha decreases to fade effect
			var r = lerpf(1.0, base_r, p.alpha)
			var g = lerpf(1.0, base_g, p.alpha)
			var b = lerpf(1.0, base_b, p.alpha)
			p.modulate = Color(r, g, b, p.alpha)
		else:
			# Normal Alpha Blend
			p.modulate = Color(base_r, base_g, base_b, p.alpha)
		
		# Lifecycle check
		if p.life_timer <= 0:
			particles.remove_at(i)
			
			if p.will_burst:
				var burst_info = ParticleInfo.named(p.info.burst_particles_name)
				if burst_info:
					burst(burst_info, p.x, p.y)
			
			p.queue_free()

	if particles.is_empty() and spawn_timer <= 0:
		queue_free()


class Particle extends Sprite2D:
	var info: ParticleInfo
	var x: float
	var y: float
	var vx: float
	var vy: float
	var ax: float
	var ay: float
	var life_timer: float
	var will_burst: bool = false
	var r: float
	var g: float
	var b: float
	var r_change_rate: float
	var g_change_rate: float
	var b_change_rate: float
	var alpha: float
	var alpha_change_rate: float
	var scale_val: float # 'scale' is a property of Node2D
	var scale_change_rate: float
	var rot: float
	var v_rot: float
	var a_rot: float
	
	func _ready():
		# Disable internal processing as the manager handles it
		set_process(false)
		set_physics_process(false)

	func setup(_info: ParticleInfo, start_x: float, start_y: float, start_rot: float):
		info = _info
		
		# Position randomization
		x = start_x + randf_range(info.spawn_min_deviation, info.spawn_max_deviation)
		y = start_y + randf_range(info.spawn_min_deviation, info.spawn_max_deviation)
		
		# Angle
		var ang = start_rot + randf_range(info.spawn_low_angle, info.spawn_high_angle)
		var cos_val = cos(deg_to_rad(ang))
		var sin_val = sin(deg_to_rad(ang))
		
		# Velocity & Accel
		var vel = randf_range(info.min_initial_velocity, info.max_initial_velocity)
		var acc = randf_range(info.min_acceleration, info.max_acceleration)
		
		vx = cos_val * vel
		vy = sin_val * vel
		ax = cos_val * acc
		ay = sin_val * acc
		
		# Burst Chance
		if randf() <= info.burst_chance:
			will_burst = true
			
		# Rotation
		rot = randf_range(info.min_initial_rotation, info.max_initial_rotation) + start_rot
		v_rot = randf_range(info.min_initial_rotation_speed, info.max_initial_rotation_speed)
		a_rot = randf_range(info.min_rotational_acceleration, info.max_rotational_acceleration)
		
		# Lifetime
		life_timer = randf_range(info.min_lifetime, info.max_lifetime)
		if life_timer <= 0.0001: life_timer = 0.0001 # Prevent div by zero
		
		# Color
		r = float(info.low_r)
		g = float(info.low_g)
		b = float(info.low_b)
		
		r_change_rate = (float(info.high_r) - float(info.low_r)) / life_timer
		g_change_rate = (float(info.high_g) - float(info.low_g)) / life_timer
		b_change_rate = (float(info.high_b) - float(info.low_b)) / life_timer
		
		# Alpha
		alpha = randf_range(info.min_initial_alpha, info.max_initial_alpha)
		var target_alpha = randf_range(info.min_final_alpha, info.max_final_alpha)
		alpha_change_rate = (target_alpha - alpha) / life_timer
		
		# Scale
		var scale_modifier = 1.0
		# In BlitzMax, Modes 2 (Rect) and 3 (Oval) used scale as pixel dimensions.
		# In Godot, we use a 64x64 texture for Ovals (Mode 3), so we must normalize the scale.
		# Mode 2 (Rect) uses a 1x1 texture, so the scale value is used directly as dimensions.
		if info.render_mode == 3:
			scale_modifier = 1.0 / 64.0

		scale_val = randf_range(info.min_initial_scale, info.max_initial_scale) * scale_modifier
		var target_scale = randf_range(info.min_final_scale, info.max_final_scale) * scale_modifier
		scale_change_rate = (target_scale - scale_val) / life_timer
		
		# Setup Visuals Initial State
		if info.render_blend == ParticleInfo.BLEND_LIGHT:
			material = Particles.mat_add
		elif info.render_blend == ParticleInfo.BLEND_SHADE:
			material = Particles.mat_mul
		else:
			material = Particles.mat_mix

		# Apply initial state to Node properties immediately to prevent 0,0 flicker
		position = Vector2(x, y)
		rotation_degrees = rot
		scale = Vector2(scale_val, scale_val)
		
		var base_r = r / 255.0
		var base_g = g / 255.0
		var base_b = b / 255.0
		
		# Initial Modulate
		if info.render_blend == ParticleInfo.BLEND_LIGHT:
			modulate = Color(base_r * alpha, base_g * alpha, base_b * alpha, alpha)
		elif info.render_blend == ParticleInfo.BLEND_SHADE:
			var ir = lerpf(1.0, base_r, alpha)
			var ig = lerpf(1.0, base_g, alpha)
			var ib = lerpf(1.0, base_b, alpha)
			modulate = Color(ir, ig, ib, alpha)
		else:
			modulate = Color(base_r, base_g, base_b, alpha)
