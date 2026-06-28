extends Control
class_name RadarUI

# Radar configuration
const RADAR_SIZE = 176.0
const RADAR_RADIUS = RADAR_SIZE * 0.5

# Must match Level.MAP_RADAR_EVENT_LIFETIME (BlitzMax mapevent timer/maxtimer = 6).
const MAP_RADAR_EVENT_LIFETIME: float = 6.0

# Colors from original
const COLOR_ESCORT = Color(0, 200/255.0, 0)
const COLOR_ATTACK = Color(200/255.0, 0, 0)
const COLOR_CONVOY = Color(200/255.0, 200/255.0, 0)
const COLOR_OTHER = Color(0, 200/255.0, 200/255.0) # Start/End ships

var radar_texture: Texture2D

func _ready():
	custom_minimum_size = Vector2(RADAR_SIZE, RADAR_SIZE)
	radar_texture = GameData.load_texture(GameData.get_data_path(GameData.Type.UI_GFX, "radar_big"))
	
	# Auto-position in bottom left corner
	# Anchors: Bottom Left (0, 1)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	
	# Offsets (Margin)
	var margin = 20.0
	offset_left = margin
	offset_top = -RADAR_SIZE - margin
	offset_right = margin + RADAR_SIZE
	offset_bottom = -margin

func _process(_delta):
	queue_redraw()

func _draw():
	# Background
	var center = size * 0.5
	
	# Draw semi-transparent black background
	draw_circle(center, RADAR_RADIUS, Color(0, 0, 0, 0.5))
	
	# Draw radar texture
	if radar_texture:
		var tex_pos = (size - radar_texture.get_size()) / 2.0
		draw_texture(radar_texture, tex_pos)
		
	# Get game state
	var level = GameState.current_level
	var player = GameState.player
	
	if not level or not is_instance_valid(player):
		return
		
	var radar_range = Level.RADAR_RANGE
	var dist_mod = RADAR_RADIUS / radar_range
	
	# Draw Player Orientation Crosshair
	# Original: Lines rotated by player rotation.
	# DrawLine(x, y, x+6, y) -> Line extending 6 pixels in direction of rotation
	var rot = player.rotation
	var crosshair_len = 6.0
	var crosshair_color = Color(1, 1, 1, 0.5)
	var line_width = 1.5
	
	# Forward
	draw_line(center, center + Vector2(cos(rot), sin(rot)) * crosshair_len, crosshair_color, line_width)
	# Back
	draw_line(center, center + Vector2(cos(rot + PI), sin(rot + PI)) * 3.0, crosshair_color, line_width)
	# Right
	draw_line(center, center + Vector2(cos(rot + PI/2), sin(rot + PI/2)) * 3.0, crosshair_color, line_width)
	# Left
	draw_line(center, center + Vector2(cos(rot - PI/2), sin(rot - PI/2)) * 3.0, crosshair_color, line_width)
	
	# Draw Ships
	# Helper to calculate position
	var get_radar_pos = func(ship_pos: Vector2) -> Vector2:
		var diff = ship_pos - player.position
		var dist_sq = diff.length_squared()
		
		var pos = Vector2.ZERO
		
		if dist_sq <= radar_range * radar_range:
			pos = center + diff * dist_mod
		else:
			var dist = sqrt(dist_sq)
			pos = center + (diff / dist) * RADAR_RADIUS
			
		return pos

	# Draw groups
	# Start & End Ships (Blue)
	for ship in level.start_ships:
		if is_instance_valid(ship):
			_plot_large_craft(get_radar_pos.call(ship.position), COLOR_OTHER)
			
	for ship in level.end_ships:
		if is_instance_valid(ship):
			_plot_large_craft(get_radar_pos.call(ship.position), COLOR_OTHER)
			
	# Escort Ships (Green)
	for ship in level.escort_ships:
		if is_instance_valid(ship):
			_plot_large_craft(get_radar_pos.call(ship.position), COLOR_ESCORT)
			
	# Attacking Ships (Red)
	for ship in level.attacking_ships:
		if is_instance_valid(ship):
			_plot_large_craft(get_radar_pos.call(ship.position), COLOR_ATTACK)
			
	# Convoy Ships (Yellow)
	for ship in level.convoy_ships:
		if is_instance_valid(ship):
			_plot_large_craft(get_radar_pos.call(ship.position), COLOR_CONVOY)
			
	var map_events: Array[Dictionary] = level.map_radar_events
	for ev in map_events:
		var wpos: Vector2 = ev["world_pos"] as Vector2
		var evcol: Color = ev["color"] as Color
		var tleft: float = ev["time_left"] as float
		var pos: Vector2 = get_radar_pos.call(wpos) as Vector2
		var a := clampf(tleft / MAP_RADAR_EVENT_LIFETIME, 0.0, 1.0)
		_plot_map_event_blip(pos, evcol, a)

func _plot_map_event_blip(pos: Vector2, color: Color, life_alpha: float) -> void:
	var c := Color(color.r, color.g, color.b, color.a * life_alpha * 0.9)
	draw_circle(pos, 3.0, c)
	draw_arc(pos, 5.0, 0.0, TAU, 16, c.lightened(0.15), 1.0, true)

func _plot_large_craft(pos: Vector2, color: Color):
	# Original plotLargeCraft:
	# Center: Alpha 1
	# Cross (up/down/left/right 1px): Alpha 0.5
	# Corners: Alpha 0.25
	
	# We can draw 1px rectangles.
	var blip_size = Vector2(1, 1)
	
	# Center
	draw_rect(Rect2(pos, blip_size), color)
	
	# Cross (0.5 alpha)
	var c_mid = color
	c_mid.a = 0.5
	draw_rect(Rect2(pos + Vector2(1, 0), blip_size), c_mid)
	draw_rect(Rect2(pos + Vector2(-1, 0), blip_size), c_mid)
	draw_rect(Rect2(pos + Vector2(0, 1), blip_size), c_mid)
	draw_rect(Rect2(pos + Vector2(0, -1), blip_size), c_mid)
	
	# Corners (0.25 alpha)
	var c_low = color
	c_low.a = 0.25
	draw_rect(Rect2(pos + Vector2(1, -1), blip_size), c_low)
	draw_rect(Rect2(pos + Vector2(-1, 1), blip_size), c_low)
	draw_rect(Rect2(pos + Vector2(1, 1), blip_size), c_low)
	draw_rect(Rect2(pos + Vector2(-1, -1), blip_size), c_low)
