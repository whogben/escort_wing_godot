class_name Ocean
extends Node2D

## Tiling ocean background that covers the viewport.

var texture: Texture2D
var low_clouds: CloudLayer
var high_clouds: CloudLayer

## Ocean tint (0–1), applied when drawing the tiled background.
var bg_r: float = 1.0
var bg_g: float = 1.0
var bg_b: float = 1.0

func _ready() -> void:
	z_index = GameState.ZLayer.BACKGROUND
	
	var path = GameData.get_data_path(GameData.Type.AMBIENT_GFX, "ocean")
	if path != "":
		texture = GameData.load_texture(path)
		if texture:
			# Enable repeat on this node so the texture tiles correctly when drawn with tile=true
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			
	# Create cloud layers
	# Z-Index:
	# BACKGROUND = -20
	# LOW_CLOUDS = -15
	# SHIPS = 0
	# HIGH_CLOUDS = 20
	
	low_clouds = CloudLayer.new()
	low_clouds.name = "LowClouds"
	low_clouds.z_index = GameState.ZLayer.LOW_CLOUDS # -15 (Below ships)
	
	# BlitzMax: create(groundCloudCover, 1, 2, 4, .3, .7, 100, 155)
	# Brightness 100-155 is approx 0.4 - 0.6.
	# Note: Original BlitzMax create() call in oceanBG used:
	# lowclouds = cloudlayer.create(groundCloudCover, 1, 2, 4, .3, .7, 100, 155)
	# But cloudlayer.create defaults for scale were 4, 12. Here explicit 2, 4 passed.
	# So Low Clouds are smaller (2-4).
	low_clouds.setup(10, 1.0, 2.0, 4.0, 0.3, 0.7, 100.0 / 255.0, 155.0 / 255.0)
	add_child(low_clouds)
	
	high_clouds = CloudLayer.new()
	high_clouds.name = "HighClouds"
	high_clouds.z_index = GameState.ZLayer.HIGH_CLOUDS # 20 (Above ships)
	
	# BlitzMax: create(airCloudCover) -> uses defaults:
	# num=20 (but oceanBG passes airCloudCover=3 usually)
	# scale=4-12
	# alpha=0.3-1.0 (Wait, create defaults to 0.4-1.0 in create:cloud but .3-1 in create:cloudlayer param default? 
	# CloudLayer.create default minAlpha=.3. Cloud.create default .4. 
	# OceanBG uses CloudLayer.create(airCover). So it gets .3-1.0 alpha.
	# Brightness 155-200 (.6-.78).
	high_clouds.setup(3, 1.15, 4.0, 12.0, 0.3, 1.0, 155.0 / 255.0, 200.0 / 255.0)
	add_child(high_clouds)

func configure_clouds(ground_cover: int, air_cover: int) -> void:
	if low_clouds:
		low_clouds.cloud_count = ground_cover
	if high_clouds:
		high_clouds.cloud_count = air_cover


func configure_rgb(do_randomize: bool, custom_rgb: bool, r: float, g: float, b: float) -> void:
	if do_randomize:
		random_rgb()
	if custom_rgb:
		set_rgb(r, g, b)


func set_rgb(r: float, g: float, b: float) -> void:
	bg_r = clampf(r, 0.0, 1.0)
	bg_g = clampf(g, 0.0, 1.0)
	bg_b = clampf(b, 0.0, 1.0)
	_update_cloud_brightness()


func random_rgb() -> void:
	var light := randf_range(0.1, 1.0)
	var bias := randi_range(1, 5)
	if bias <= 2:
		light *= 1.5
	elif bias >= 4:
		light /= 1.5
	var nr := clampf(light * randf_range(1.0, 1.2), 0.0, 1.0)
	var ng := clampf(light * randf_range(1.0, 1.2), 0.0, 1.0)
	var nb := clampf(light * randf_range(1.0, 1.2), 0.0, 1.0)
	set_rgb(nr, ng, nb)


func _update_cloud_brightness() -> void:
	var avg := (bg_r + bg_g + bg_b) / 2.0 + 0.1
	var min_b := 100.0 * avg / 255.0
	var max_b := 155.0 * avg / 255.0
	if low_clouds:
		low_clouds.min_brightness = min_b
		low_clouds.max_brightness = max_b
	if high_clouds:
		high_clouds.min_brightness = min_b
		high_clouds.max_brightness = max_b

func _process(_delta: float) -> void:
	# Redraw every frame to handle camera movement
	queue_redraw()

func _draw() -> void:
	if not texture:
		return

	# Get viewport global rect
	var viewport_trans = get_canvas_transform()
	var viewport_rect_screen = get_viewport_rect()
	
	# Transform screen rect to global coordinates
	var screen_min = viewport_rect_screen.position
	var screen_max = viewport_rect_screen.end
	
	var global_min = viewport_trans.affine_inverse() * screen_min
	var global_max = viewport_trans.affine_inverse() * screen_max
	
	# Handle rotation if necessary (though simpler to treat as AABB for coverage)
	# We create an AABB in global space that covers the visible area
	var global_rect_min = Vector2(
		min(global_min.x, global_max.x),
		min(global_min.y, global_max.y)
	)
	var global_rect_max = Vector2(
		max(global_min.x, global_max.x),
		max(global_min.y, global_max.y)
	)
	
	# Also check other corners if there is rotation
	var c2 = viewport_trans.affine_inverse() * Vector2(screen_max.x, screen_min.y)
	var c3 = viewport_trans.affine_inverse() * Vector2(screen_min.x, screen_max.y)
	
	global_rect_min.x = min(global_rect_min.x, c2.x, c3.x)
	global_rect_min.y = min(global_rect_min.y, c2.y, c3.y)
	global_rect_max.x = max(global_rect_max.x, c2.x, c3.x)
	global_rect_max.y = max(global_rect_max.y, c2.y, c3.y)

	# Transform global AABB to local space of this Ocean node
	var global_to_local = get_global_transform().affine_inverse()
	
	# We want to cover the area in local space.
	# Simplest is to map the global AABB corners to local space and AABB that.
	var corners = [
		global_to_local * global_rect_min,
		global_to_local * Vector2(global_rect_max.x, global_rect_min.y),
		global_to_local * Vector2(global_rect_min.x, global_rect_max.y),
		global_to_local * global_rect_max
	]
	
	var local_min = corners[0]
	var local_max = corners[0]
	
	for c in corners:
		local_min.x = min(local_min.x, c.x)
		local_min.y = min(local_min.y, c.y)
		local_max.x = max(local_max.x, c.x)
		local_max.y = max(local_max.y, c.y)
	
	# Align to texture grid
	var tex_size = texture.get_size()
	
	var aligned_min_x = floor(local_min.x / tex_size.x) * tex_size.x
	var aligned_min_y = floor(local_min.y / tex_size.y) * tex_size.y
	
	var needed_width = local_max.x - aligned_min_x
	var needed_height = local_max.y - aligned_min_y
	
	var aligned_width = ceil(needed_width / tex_size.x) * tex_size.x
	var aligned_height = ceil(needed_height / tex_size.y) * tex_size.y
	
	# Draw the tiled texture
	var tint := Color(bg_r, bg_g, bg_b)
	draw_texture_rect(texture, Rect2(aligned_min_x, aligned_min_y, aligned_width, aligned_height), true, tint)
