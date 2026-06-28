class_name CloudLayer
extends Node2D

## Handles a layer of clouds with drift and draw-time parallax (like BlitzMax offx scaling).

# Settings
var cloud_count: int = 10
## 1.0 = scroll with background; >1.0 = foreground layer scrolls faster across the screen.
var parallax_factor: float = 1.0

# Visual Settings (Defaults for Low Clouds)
var min_scale: float = 4.0
var max_scale: float = 12.0
var min_alpha: float = 0.3
var max_alpha: float = 1.0
var min_brightness: float = 0.6
var max_brightness: float = 0.8
var textures: Array[Texture2D] = []

# Drift Speed
var min_drift: float = -50.0
var max_drift: float = 50.0

# State
class CloudData:
	var sprite: Sprite2D
	var virtual_position: Vector2 # World position; drift only — never camera-coupled
	var velocity: Vector2
	var rotation_speed: float
	var radius: float

var clouds: Array[CloudData] = []
var target_cloud_count: int = 0
var reference_area: float = 1024.0 * 768.0

const CULL_MARGIN: float = 200.0

func _ready() -> void:
	# z_index should be set by the parent (Ocean) or the instantiator
	
	# Load cloud textures if not provided
	if textures.is_empty():
		var path = GameData.get_data_path(GameData.Type.AMBIENT_GFX, "cloud_1")
		if path != "":
			var tex = GameData.load_texture(path)
			if tex:
				textures.append(tex)
	
	_recalculate_target_count()
	
	# Initial spawn - fill the screen without edge forcing.
	# Bail out if textures failed to load; otherwise this loop never terminates.
	while clouds.size() < target_cloud_count:
		var count_before := clouds.size()
		_spawn_cloud(false)
		if clouds.size() == count_before:
			push_warning("CloudLayer: no cloud textures available; skipping spawn")
			break

func _process(delta: float) -> void:
	var level = GameState.current_level
	if level and level.briefing_active:
		return
	# Recalculate target count in case resolution changed
	_recalculate_target_count()
	
	var canvas_trans = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	var camera_center = canvas_trans.affine_inverse() * (viewport_rect.size / 2.0)
	var visible_rect_global = Rect2(
		canvas_trans.affine_inverse() * Vector2.ZERO,
		canvas_trans.affine_inverse().basis_xform(viewport_rect.size)
	)
	
	for i in range(clouds.size() - 1, -1, -1):
		var cloud = clouds[i]
		
		cloud.virtual_position += cloud.velocity * delta
		cloud.sprite.rotation += cloud.rotation_speed * delta
		var render_pos = _render_position(cloud.virtual_position, camera_center)
		cloud.sprite.global_position = render_pos
		
		var safe_cull_rect = visible_rect_global.grow(cloud.radius + 50.0)
		
		if not safe_cull_rect.has_point(render_pos):
			_remove_cloud(i)
	
	# Respawn
	if clouds.size() < target_cloud_count:
		_spawn_cloud(true)

func _recalculate_target_count():
	var viewport_size = get_viewport_rect().size
	var current_area = viewport_size.x * viewport_size.y
	# Scale target count based on area ratio
	var ratio = current_area / reference_area
	target_cloud_count = int(cloud_count * ratio)
	# Ensure at least minimal clouds if count > 0
	if cloud_count > 0 and target_cloud_count == 0:
		target_cloud_count = 1

func _spawn_cloud(force_edge: bool):
	if textures.is_empty():
		return
		
	var cloud = CloudData.new()
	
	# Visuals
	var tex = textures.pick_random()
	cloud.sprite = Sprite2D.new()
	cloud.sprite.texture = tex
	# Ensure the sprite inherits the Z-index of the CloudLayer node
	# Or manually set it if needed, but CloudLayer.z_index is already set.
	# Sprite2D is a child of CloudLayer, so it inherits z_index relative to parent if z_as_relative is true (default).
	# However, if CloudLayer z_index is set, and children have z_index 0, they render at CloudLayer's z_index.
	add_child(cloud.sprite)
	
	# Properties
	var scale_val = randf_range(min_scale, max_scale)
	cloud.sprite.scale = Vector2(scale_val, scale_val)
	
	var alpha = randf_range(min_alpha, max_alpha)
	var bright = randf_range(min_brightness, max_brightness)
	cloud.sprite.modulate = Color(bright, bright, bright, alpha)
	
	cloud.sprite.rotation = randf() * TAU
	cloud.rotation_speed = 0.0 # BlitzMax had vrot but initialized to 0 in create function?
	# BlitzMax Cloud: Field vrot... create() doesn't set vrot. It defaults to 0. 
	# Cloud.update() uses vrot. So clouds don't rotate? 
	# "rot = Rand(0, 359)". "vrot" is never set in create(). So it's 0.
	# I'll stick to 0 rotation speed.
	
	cloud.velocity = Vector2(
		randf_range(min_drift, max_drift),
		randf_range(min_drift, max_drift)
	)
	
	# Radius for culling
	var tex_size = tex.get_size()
	cloud.radius = (sqrt(pow(tex_size.x/2.0, 2) + pow(tex_size.y/2.0, 2))) * scale_val
	
	# Positioning
	var viewport_rect = get_viewport_rect()
	var canvas_trans = get_canvas_transform()
	# Viewport bounds in Global Space
	var visible_rect_global = Rect2(
		canvas_trans.affine_inverse() * Vector2.ZERO,
		canvas_trans.affine_inverse().basis_xform(viewport_rect.size)
	)
	
	# Determine safe spawn bounds based on this specific cloud's radius
	# We want the cloud to be completely off-screen.
	# The closest the center can be is visible_edge + radius.
	var safe_margin = cloud.radius + 10.0 # 10px extra buffer
	
	var spawn_pos = Vector2.ZERO
	
	if force_edge:
		# Pick a random point on the edge of the spawn box
		# Logic: Pick a side (0=Top, 1=Right, 2=Bottom, 3=Left)
		var side = randi() % 4
		match side:
			0: # Top
				spawn_pos.x = randf_range(visible_rect_global.position.x - safe_margin, visible_rect_global.end.x + safe_margin)
				spawn_pos.y = visible_rect_global.position.y - safe_margin
			1: # Right
				spawn_pos.x = visible_rect_global.end.x + safe_margin
				spawn_pos.y = randf_range(visible_rect_global.position.y - safe_margin, visible_rect_global.end.y + safe_margin)
			2: # Bottom
				spawn_pos.x = randf_range(visible_rect_global.position.x - safe_margin, visible_rect_global.end.x + safe_margin)
				spawn_pos.y = visible_rect_global.end.y + safe_margin
			3: # Left
				spawn_pos.x = visible_rect_global.position.x - safe_margin
				spawn_pos.y = randf_range(visible_rect_global.position.y - safe_margin, visible_rect_global.end.y + safe_margin)
		
		# Add a bit of extra margin randomly so they don't all line up perfectly
		var offset = Vector2.ZERO
		match side:
			0: offset.y = -randf_range(0, 100)
			1: offset.x = randf_range(0, 100)
			2: offset.y = randf_range(0, 100)
			3: offset.x = -randf_range(0, 100)
		spawn_pos += offset
		
	else:
		# Initial spawn: Random anywhere in box
		# We use the standard margin here just to have a bounds, but effectively they can be on screen.
		# But since this is only called during setup/ready, pop-in isn't an issue.
		# To avoid them clumping too far out, we use the visible rect extended by a reasonable amount.
		var init_box = visible_rect_global.grow(safe_margin)
		spawn_pos = Vector2(
			randf_range(init_box.position.x, init_box.end.x),
			randf_range(init_box.position.y, init_box.end.y)
		)

	var camera_center = canvas_trans.affine_inverse() * (viewport_rect.size / 2.0)
	
	cloud.virtual_position = spawn_pos + _parallax_offset(camera_center)
	cloud.sprite.global_position = spawn_pos
	# And update the z_index
	cloud.sprite.z_index = z_index
	cloud.sprite.z_as_relative = false
	
	clouds.append(cloud)

func _remove_cloud(index: int):
	var cloud = clouds[index]
	cloud.sprite.queue_free()
	clouds.remove_at(index)

func _parallax_offset(camera_center: Vector2) -> Vector2:
	return camera_center * (parallax_factor - 1.0)

func _render_position(virtual: Vector2, camera_center: Vector2) -> Vector2:
	# Matches BlitzMax draw at x + offx * factor: screen scrolls at factor × camera speed.
	return virtual - _parallax_offset(camera_center)

func setup(count: int, p_factor: float, scale_min: float, scale_max: float, alpha_min: float, alpha_max: float, bright_min: float, bright_max: float):
	cloud_count = count
	parallax_factor = p_factor
	min_scale = scale_min
	max_scale = scale_max
	min_alpha = alpha_min
	max_alpha = alpha_max
	min_brightness = bright_min
	max_brightness = bright_max
