extends Resource
class_name ParticleInfo
## Stores configuration for particle effects.

const BLEND_ALPHA = 1
const BLEND_SHADE = 2
const BLEND_LIGHT = 3

@export var name = "Blank Particle"

@export var is_collection = false
@export var collected_pfx: Array[String] = []

@export var render_mode = 1
@export var render_blend = BLEND_ALPHA
@export var render_blend_name = "ALPHABLEND"
@export var render_graphic_name = "No Graphic"
# render_graphic will be loaded dynamically
var render_graphic: Texture2D = null

@export var low_r = 255
@export var low_g = 0
@export var low_b = 0
@export var high_r = 0
@export var high_g = 255
@export var high_b = 0

@export var min_initial_scale = 1.0
@export var max_initial_scale = 1.0
@export var min_final_scale = 5.0
@export var max_final_scale = 5.0

@export var min_initial_alpha = 1.0
@export var max_initial_alpha = 1.0
@export var min_final_alpha = 0.0
@export var max_final_alpha = 0.0

@export var min_lifetime = 1.0
@export var max_lifetime = 1.0

@export var min_initial_velocity = 25
@export var max_initial_velocity = 50

@export var min_acceleration = 0
@export var max_acceleration = 0

@export var min_initial_rotation = 1
@export var max_initial_rotation = 360

@export var min_initial_rotation_speed = -90
@export var max_initial_rotation_speed = 90

@export var min_rotational_acceleration = 0
@export var max_rotational_acceleration = 0

@export var spawn_low_angle = 1
@export var spawn_high_angle = 360

@export var spawn_min_deviation = 0
@export var spawn_max_deviation = 0

@export var spawn_min_wait = 0.05
@export var spawn_max_wait = 0.05

@export var burst_min_particles = 5
@export var burst_max_particles = 10

@export var particle_x_gravity = 0
@export var particle_y_gravity = 0

@export var particle_x_wind = 0
@export var particle_y_wind = 0

@export var particle_drag = 0.0

@export var burst_chance = 0.0
@export var burst_particles_name = "Nothing"


## All currently loaded ParticleInfo instances keyed by name.
static var particle_infos: Dictionary[String, ParticleInfo] = {}


## Returns a ParticleInfo instance with the given name.
## If an instance already exists, it is returned.
static func named(info_name: String) -> ParticleInfo:
	if particle_infos.has(info_name):
		return particle_infos[info_name]
	
	var path = GameData.get_data_path(GameData.Type.PARTICLE_INFO, info_name)
	if path == "":
		# Return null if not found, caller must handle
		return null
	
	var p_info = ParticleInfo.new()
	var result = p_info.load_particle_file(path)
	if result == null:
		return null
		
	particle_infos[info_name] = p_info
	return p_info


func load_particle_file(path: String) -> ParticleInfo:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open Particle file: " + path)
		return null

	var first_line := file.get_line()
	if "< Particle Name >" in first_line:
		_load_modern_format(file)
	else:
		_load_old_format(file, first_line)

	file.close()
	particle_infos[name] = self
	return self


func _set_blend_from_name() -> void:
	if render_blend_name == "ALPHABLEND":
		render_blend = BLEND_ALPHA
	elif render_blend_name == "SHADEBLEND":
		render_blend = BLEND_SHADE
	elif render_blend_name == "LIGHTBLEND":
		render_blend = BLEND_LIGHT
	else:
		render_blend = BLEND_ALPHA
		render_blend_name = "ALPHABLEND"


func _load_graphic_if_needed() -> void:
	if render_mode != 4:
		return
	var gfx_path := GameData.get_data_path(GameData.Type.PARTICLE_GFX, render_graphic_name)
	if gfx_path != "":
		render_graphic = GameData.load_texture(gfx_path)


## Header-tagged format written by the original BlitzMax editor (ParticleLib.Load).
func _load_modern_format(file: FileAccess) -> void:
	while not file.eof_reached():
		var line := file.get_line()
		if "< Particle Name >" in line:
			name = file.get_line()
		elif "< Collects PFX >" in line:
			is_collection = true
			while not file.eof_reached():
				var pfx_name := file.get_line().strip_edges()
				if pfx_name != "":
					collected_pfx.append(pfx_name)
			return
		elif "< Display Type >" in line:
			render_mode = int(file.get_line())
		elif "< Blending >" in line:
			render_blend_name = file.get_line()
			_set_blend_from_name()
		elif "< Graphic Name >" in line:
			render_graphic_name = file.get_line()
			_load_graphic_if_needed()
		elif "< Initial R, G, B >" in line:
			low_r = int(file.get_line())
			low_g = int(file.get_line())
			low_b = int(file.get_line())
		elif "< Final R, G, B >" in line:
			high_r = int(file.get_line())
			high_g = int(file.get_line())
			high_b = int(file.get_line())
		elif "< Min / Max Initial Scale >" in line:
			min_initial_scale = float(file.get_line())
			max_initial_scale = float(file.get_line())
		elif "< Min / Max Final Scale >" in line:
			min_final_scale = float(file.get_line())
			max_final_scale = float(file.get_line())
		elif "< Min / Max Initial Alpha >" in line:
			min_initial_alpha = float(file.get_line())
			max_initial_alpha = float(file.get_line())
		elif "< Min / Max Final Alpha >" in line:
			min_final_alpha = float(file.get_line())
			max_final_alpha = float(file.get_line())
		elif "< Min / Max Lifetime >" in line:
			min_lifetime = float(file.get_line())
			max_lifetime = float(file.get_line())
		elif "< Min / Max Initial Speed >" in line:
			min_initial_velocity = int(file.get_line())
			max_initial_velocity = int(file.get_line())
		elif "< Min / Max Acceleration >" in line:
			min_acceleration = int(file.get_line())
			max_acceleration = int(file.get_line())
		elif "< Min / Max Initial Rotation >" in line:
			min_initial_rotation = int(file.get_line())
			max_initial_rotation = int(file.get_line())
		elif "< Min / Max Initial Rotation Speed >" in line:
			min_initial_rotation_speed = int(file.get_line())
			max_initial_rotation_speed = int(file.get_line())
		elif "< Min / Max Rotational Acceleration >" in line:
			min_rotational_acceleration = int(file.get_line())
			max_rotational_acceleration = int(file.get_line())
		elif "< Min / Max Spawn Angle >" in line:
			spawn_low_angle = int(file.get_line())
			spawn_high_angle = int(file.get_line())
		elif "< Min / Max Spawn Location Deviation >" in line:
			spawn_min_deviation = int(file.get_line())
			spawn_max_deviation = int(file.get_line())
		elif "< Min / Max Spawn Wait >" in line:
			spawn_min_wait = float(file.get_line())
			spawn_max_wait = float(file.get_line())
		elif "< Min / Max Burst Spawn Count >" in line:
			burst_min_particles = int(file.get_line())
			burst_max_particles = int(file.get_line())
		elif "< X, Y Gravity >" in line:
			particle_x_gravity = int(file.get_line())
			particle_y_gravity = int(file.get_line())
		elif "< X, Y Wind >" in line:
			particle_x_wind = int(file.get_line())
			particle_y_wind = int(file.get_line())
		elif "< Particle Drag >" in line:
			particle_drag = float(file.get_line())
		elif "< Particle Burst Chance >" in line:
			burst_chance = float(file.get_line())
		elif "< Particle Created on Burst >" in line:
			burst_particles_name = file.get_line()


## Legacy compact format (name on first line) still used by some mods.
func _load_old_format(file: FileAccess, first_line: String) -> void:
	name = first_line

	var nothing := file.get_line()
	if nothing == "COLLECTION":
		is_collection = true
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line != "":
				collected_pfx.append(line)
		return

	render_mode = int(file.get_line())

	file.get_line() # Header "render blend..."
	render_blend_name = file.get_line()
	_set_blend_from_name()

	file.get_line() # Header "render graphic..."
	render_graphic_name = file.get_line()
	_load_graphic_if_needed()

	file.get_line() # Header RGB
	low_r = int(file.get_line())
	low_g = int(file.get_line())
	low_b = int(file.get_line())

	file.get_line() # Header Final RGB
	high_r = int(file.get_line())
	high_g = int(file.get_line())
	high_b = int(file.get_line())

	file.get_line() # Header Initial Scale
	min_initial_scale = float(file.get_line())
	max_initial_scale = float(file.get_line())

	file.get_line() # Header Final Scale
	min_final_scale = float(file.get_line())
	max_final_scale = float(file.get_line())

	file.get_line() # Header Initial Alpha
	min_initial_alpha = float(file.get_line())
	max_initial_alpha = float(file.get_line())

	file.get_line() # Header Final Alpha
	min_final_alpha = float(file.get_line())
	max_final_alpha = float(file.get_line())

	file.get_line() # Header Lifetime
	min_lifetime = float(file.get_line())
	max_lifetime = float(file.get_line())

	file.get_line() # Header Initial Speed
	min_initial_velocity = int(file.get_line())
	max_initial_velocity = int(file.get_line())

	file.get_line() # Header Accel
	min_acceleration = int(file.get_line())
	max_acceleration = int(file.get_line())

	file.get_line() # Header Init Rot
	min_initial_rotation = int(file.get_line())
	max_initial_rotation = int(file.get_line())

	file.get_line() # Header Rot Speed
	min_initial_rotation_speed = int(file.get_line())
	max_initial_rotation_speed = int(file.get_line())

	file.get_line() # Header Rot Accel
	min_rotational_acceleration = int(file.get_line())
	max_rotational_acceleration = int(file.get_line())

	file.get_line() # Header Spawn Angle
	spawn_low_angle = int(file.get_line())
	spawn_high_angle = int(file.get_line())

	file.get_line() # Header Spawn Dev
	spawn_min_deviation = int(file.get_line())
	spawn_max_deviation = int(file.get_line())

	file.get_line() # Header Spawn Wait
	spawn_min_wait = float(file.get_line())
	spawn_max_wait = float(file.get_line())

	file.get_line() # Header Burst Count
	burst_min_particles = int(file.get_line())
	burst_max_particles = int(file.get_line())

	file.get_line() # Header Gravity
	particle_x_gravity = int(file.get_line())
	particle_y_gravity = int(file.get_line())

	file.get_line() # Header Wind
	particle_x_wind = int(file.get_line())
	particle_y_wind = int(file.get_line())

	file.get_line() # Header Drag
	particle_drag = float(file.get_line())

	file.get_line() # Header Burst Chance
	burst_chance = float(file.get_line())

	file.get_line() # Header Burst Name
	burst_particles_name = file.get_line()
