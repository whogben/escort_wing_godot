extends Control
class_name InGameUI

var radar: RadarUI
var eta_label: Label
var primary_ammo_label: Label
var secondary_ammo_label: Label
var eta_panel: PanelContainer
var primary_ammo_panel: PanelContainer
var secondary_ammo_panel: PanelContainer

var _danger_label: Label
var _convoy_danger_warning: bool = false

func _ready():
	print("InGameUI _ready called")
	# Make sure this control covers the whole screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_radar()
	_setup_status_display()
	_setup_convoy_danger_warning()


func set_convoy_danger_warning(on: bool) -> void:
	_convoy_danger_warning = on


func _setup_convoy_danger_warning() -> void:
	_danger_label = Label.new()
	_danger_label.text = "RETURN TO THE CONVOY"
	_danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_danger_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_danger_label.offset_top = 48.0
	_danger_label.offset_bottom = 48.0 + 28.0
	_danger_label.offset_left = -320.0
	_danger_label.offset_right = 320.0
	_danger_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.12))
	var font := load("res://font.otf") as Font
	if font:
		_danger_label.add_theme_font_override("font", font)
		_danger_label.add_theme_font_size_override("font_size", 22)
	_danger_label.visible = false
	_danger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_danger_label)


func _setup_radar():
	radar = RadarUI.new()
	add_child(radar)
	# RadarUI handles its own anchoring (Bottom-Left)

func _setup_status_display():
	# Container for the status line (ETA, Ammo)
	var status_container = HBoxContainer.new()
	add_child(status_container)
	
	# Position: Bottom Left, to the right of Radar
	# Radar is 176px + 20px margin = 196px wide space.
	# Let's start at x=210, y=Bottom-40ish
	
	status_container.anchor_left = 0.0
	status_container.anchor_top = 1.0
	status_container.anchor_right = 0.0
	status_container.anchor_bottom = 1.0
	
	# The container needs to expand to its content size, which we can rely on HBoxContainer for.
	# We just need to pin it to the bottom left.
	# But we need to make sure the Control itself has enough space.
	# InGameUI is set to FULL_RECT, so status_container children of it should be fine.
	
	status_container.position = Vector2(210, 0) # X offset. Y is handled by anchor + grow.
	status_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	status_container.offset_left = 210
	status_container.offset_bottom = -20
	status_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	status_container.add_theme_constant_override("separation", 10)
	
	# Create styles for the panels (semi-transparent black background)
	# Helper to create style
	var create_style = func():
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.5)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		sb.set_corner_radius_all(0)
		return sb
	
	# ETA Panel
	eta_panel = PanelContainer.new()
	eta_panel.add_theme_stylebox_override("panel", create_style.call())
	status_container.add_child(eta_panel)
	
	eta_label = Label.new()
	# Green color for ETA (60, 255, 90)
	eta_label.add_theme_color_override("font_color", Color(60 / 255.0, 255 / 255.0, 90 / 255.0))
	eta_label.add_theme_constant_override("shadow_offset_x", 0)
	eta_label.add_theme_constant_override("shadow_offset_y", 0)
	eta_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0)) # Disable shadow
	
	var font = load("res://font.otf")
	if font:
		eta_label.add_theme_font_override("font", font)
		
	eta_panel.add_child(eta_label)
	
	# Primary ammo panel (shown only when a limited primary weapon exists)
	primary_ammo_panel = PanelContainer.new()
	primary_ammo_panel.add_theme_stylebox_override("panel", create_style.call())
	status_container.add_child(primary_ammo_panel)

	primary_ammo_label = Label.new()
	primary_ammo_label.add_theme_color_override("font_color", Color(220 / 255.0, 180 / 255.0, 130 / 255.0))
	primary_ammo_label.add_theme_constant_override("shadow_offset_x", 0)
	primary_ammo_label.add_theme_constant_override("shadow_offset_y", 0)
	primary_ammo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	if font:
		primary_ammo_label.add_theme_font_override("font", font)

	primary_ammo_panel.add_child(primary_ammo_label)

	# Secondary ammo panel
	secondary_ammo_panel = PanelContainer.new()
	secondary_ammo_panel.add_theme_stylebox_override("panel", create_style.call())
	status_container.add_child(secondary_ammo_panel)

	secondary_ammo_label = Label.new()
	secondary_ammo_label.add_theme_color_override("font_color", Color(220 / 255.0, 180 / 255.0, 130 / 255.0))
	secondary_ammo_label.add_theme_constant_override("shadow_offset_x", 0)
	secondary_ammo_label.add_theme_constant_override("shadow_offset_y", 0)
	secondary_ammo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))

	if font:
		secondary_ammo_label.add_theme_font_override("font", font)

	secondary_ammo_panel.add_child(secondary_ammo_label)

func _process(_delta):
	_update_eta()
	_update_ammo()
	if _danger_label:
		_danger_label.visible = _convoy_danger_warning
		if _convoy_danger_warning:
			var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)
			_danger_label.modulate.a = pulse

func _update_eta():
	var level = GameState.current_level
	if not level:
		eta_label.text = "ETA: --:--"
		return
		
	var eta_seconds = int(max(0, level.eta))
	# Use float division then cast to int to avoid integer division warning
	var minutes = int(eta_seconds / 60.0)
	var seconds = eta_seconds % 60
	
	eta_label.text = "ETA: %d:%02d" % [minutes, seconds]
	
	# Change color if close to 0? Original didn't seem to, just showed "0:00".

func _update_ammo():
	var player = GameState.player
	if not player or not is_instance_valid(player):
		primary_ammo_panel.visible = false
		secondary_ammo_panel.visible = false
		return

	primary_ammo_panel.visible = _set_weapon_ammo_label(
		primary_ammo_label, player.primary_weapons, "Primary Weapon Charges"
	)
	secondary_ammo_panel.visible = _set_weapon_ammo_label(
		secondary_ammo_label, player.secondary_weapons, "Secondary Weapon Charges"
	)


func _set_weapon_ammo_label(label: Label, weapons: Array[Weapon], prefix: String) -> bool:
	for w in weapons:
		var count := w.get_ammo_count()
		if count == -1:
			continue
		label.text = "%s: %d" % [prefix, count]
		return true
	return false

# Removed radio UI from here to decouple
