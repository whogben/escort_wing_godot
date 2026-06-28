extends Control

# Constants based on EscortGui.bmx
const CIRCLE_CENTER = Vector2(-120, -50)
const CIRCLE_RADIUS = 700.0
const CIRCLE_WIDTH = 3.0

const SETTINGS_CIRCLE_CENTER = Vector2(190, 455)
const SETTINGS_CIRCLE_RADIUS = 250.0

# Mission Select Constants (design coords at 1024x768; anchored bottom-right at runtime)
const DESIGN_VIEWPORT_SIZE = Vector2(1024, 768)
const MS_CENTER = Vector2(1270, 330)
const MS_ANCHOR_OFFSET_RIGHT = MS_CENTER.x - DESIGN_VIEWPORT_SIZE.x
const MS_ANCHOR_OFFSET_BOTTOM = MS_CENTER.y - DESIGN_VIEWPORT_SIZE.y
const MS_LAUNCH_BTN_POS = Vector2(550, 330) - Vector2(60, 20)
const MS_LAUNCH_BTN_OFFSET = MS_LAUNCH_BTN_POS - MS_CENTER
const MS_RADIUS = 460.0
const MS_ANGLE_STEP = 15.0
const MS_BG_RADIUS = 1000.0
const MS_BACK_BTN_POS = Vector2(24, 24)
const RM_PANEL_LEFT = 280.0

const MOD_UI_MARGIN = Vector2(24, 24)
const MOD_FONT_SIZE = 20

# These coordinates in BlitzMax were Top-Left coordinates
const MENU_ITEMS = [
	{"text": "New Mission", "pos": Vector2(280, 200)},
	{"text": "Random Mission", "pos": Vector2(160, 320)},
	{"text": "Controls", "pos": Vector2(200, 430)},
	{"text": "Quit", "pos": Vector2(100, 530)}
]

func _visible_menu_items() -> Array:
	var items: Array = []
	for item in MENU_ITEMS:
		if OS.has_feature("web") and item.text == "Quit":
			continue
		items.append(item)
	return items

# Settings rows (offsets from settings circle center Y; matches EscortGui.bmx order).
const SETTINGS_ITEMS = [
	{"offset_y": -200, "kind": "action", "prefix": "Left", "action": "turn_left"},
	{"offset_y": -160, "kind": "action", "prefix": "Right", "action": "turn_right"},
	{"offset_y": -120, "kind": "action", "prefix": "Accelerate", "action": "throttle_up"},
	{"offset_y": -80, "kind": "action", "prefix": "Decelerate", "action": "throttle_down"},
	{"offset_y": -40, "kind": "action", "prefix": "Primary Fire", "action": "fire_primary"},
	{"offset_y": 0, "kind": "action", "prefix": "Secondary Fire", "action": "fire_secondary"},
	{"offset_y": 60, "kind": "pilot"},
]

# Font settings
const MENU_FONT_SIZE = 36
const SETTINGS_FONT_SIZE = 24
var menu_font: Font

# State Management
enum MenuState {
	SPLASH,
	MAIN,
	SETTINGS,
	MISSION_SELECT,
	RANDOM_MISSION,
	FIRST_RUN,
	TRANSITIONING
}
var current_state: MenuState = MenuState.SPLASH

# Scene Components
var ocean: Ocean
var camera: Camera2D
var ui_layer: CanvasLayer

# Containers
var splash_overlay: TextureRect = null
var menu_container: Control
var settings_container: Control
var settings_circle_visual: Control # Separated for animation
var settings_labels_container: Control
var mission_select_container: Control
var ms_anchor: Control
var ms_labels_container: Control
var ms_launch_btn: Label
var ms_back_btn: Label
var ms_score_labels: Array[Label] = []
var transition_overlay: Control

var random_mission_container: Control
var rm_ship_preview: TextureRect
var rm_ship_name_label: Label
var rm_human_btn: Label
var rm_telrith_btn: Label
var rm_pirate_btn: Label
var rm_convoy_slider: HSlider
var rm_escort_slider: HSlider
var rm_enemy_slider: HSlider
var rm_convoy_label: Label
var rm_escort_label: Label
var rm_enemy_label: Label
var rm_ship_caption: Label
var rm_launch_btn: Label
var rm_back_btn: Label
var rm_playable_ships: Array[String] = []
var rm_ship_index: int = 0
var rm_player_team: int = 1

var first_run_overlay: Control
var first_run_pilot_label: Label
var _editing_pilot_name: bool = false
var _rebind_action: String = ""

# Mod loading UI
var mod_container: Control
var mod_load_btn: Label
var mod_status_label: Label
var mod_unload_btn: Label
var mod_refresh_btn: Label
var mod_file_dialog: FileDialog
# On web, picks a folder off the user's disk; native uses mod_file_dialog instead.
var web_mod_loader: WebModLoader
var _is_web: bool = false

# Menu Specifics
var menu_labels: Array[Label] = []
var settings_labels: Array[Label] = []

# Mission Select Data
var levels: Array[String] = []
var level_labels: Array[Label] = []
var ms_selection: int = 0
var ms_current_angle: float = 180.0
var ripple_radius: float = 0.0 # For wipe effect
var ripple_center: Vector2 = Vector2(370, 230)
var ripple_target: Vector2 = MS_CENTER
var ripple_active: bool = false
var ripple_expanding: bool = true
var _splash_sequence_active: bool = false
var _splash_tween: Tween = null

const OCEAN_SPEED = 400.0
## Brief fade after returning from a level (original had none; softens the scene swap).
const RETURN_FROM_MISSION_FADE_SEC: float = 0.45

func _ready():
	Engine.time_scale = 1.0
	GameState.block_player_input = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 1. Setup World
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	
	ocean = Ocean.new()
	add_child(ocean)
	
	# 2. Setup UI Layer
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Load font
	if ResourceLoader.exists("res://font.otf"):
		menu_font = load("res://font.otf")

	# 3. Load Data
	_load_levels()

	# 4. Build Sub-Containers
	_build_splash_overlay()
	_build_menu_container()
	_build_settings_container()
	_build_mission_select_container()
	_build_random_mission_container()
	_build_transition_overlay()
	_build_mod_ui()
	_build_first_run_overlay()
	_refresh_settings_labels()
	_apply_mission_unlock_state()
	
	# 5. Start Sequence (skip OMG cup zoom when returning from a mission)
	var returning_from_mission := RunState.return_to_mission_select or RunState.return_to_random_mission
	MusicSystem.play_menu_music(returning_from_mission)
	if RunState.return_to_random_mission:
		RunState.return_to_random_mission = false
		_enter_random_mission_from_mission_end()
	elif RunState.return_to_mission_select:
		RunState.return_to_mission_select = false
		_enter_mission_select_from_mission_end()
	elif ProgressManager.needs_first_run_setup():
		_start_first_run()
	else:
		_start_splash_sequence()

func _process(delta: float) -> void:
	if camera:
		camera.position.y -= OCEAN_SPEED * delta
	
	# Mission Select Rotation
	if current_state == MenuState.MISSION_SELECT and ms_labels_container:
		_apply_ms_rotation()
	elif current_state == MenuState.FIRST_RUN:
		_update_first_run_pilot_label()

func _input(event: InputEvent):
	if current_state == MenuState.FIRST_RUN:
		_handle_first_run_input(event)
		return
	if _rebind_action != "" and event is InputEventKey and event.pressed and not event.echo:
		ProgressManager.rebind_action(_rebind_action, event)
		_rebind_action = ""
		_refresh_settings_labels()
		_play_ui_sound("impact_1")
		return
	if _editing_pilot_name:
		_handle_pilot_name_input(event)
		return

	if _splash_sequence_active and _is_splash_skip_input(event):
		_skip_splash()
		return

	if current_state == MenuState.SETTINGS:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = settings_circle_visual.get_local_mouse_position()
			if local_pos.length() > SETTINGS_CIRCLE_RADIUS:
				_play_ui_sound("impact_1")
				_transition_from_settings()
			else:
				_handle_settings_click(event.global_position)
	
	elif current_state == MenuState.RANDOM_MISSION:
		if event.is_action_pressed("ui_cancel"):
			_play_ui_sound("impact_1")
			_transition_from_random_mission()
	
	elif current_state == MenuState.MISSION_SELECT:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("throttle_up"):
			if ms_selection > 0:
				ms_selection -= 1
				_play_ui_sound("impact_1")
				_update_ms_rotation()
		elif event.is_action_pressed("ui_down") or event.is_action_pressed("throttle_down"):
			if ms_selection < _max_unlocked_index():
				ms_selection += 1
				_play_ui_sound("impact_1")
				_update_ms_rotation()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("fire_primary"):
			_launch_selected_mission()
		elif event.is_action_pressed("ui_cancel"):
			_play_ui_sound("impact_1")
			_transition_from_mission_select()


func _unhandled_input(event: InputEvent) -> void:
	# Dismiss-on-outside-click runs here so GUI controls consume clicks first.
	if current_state == MenuState.RANDOM_MISSION:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if rm_back_btn != null and rm_back_btn.get_global_rect().has_point(event.global_position):
				return
			if event.global_position.x < RM_PANEL_LEFT - 30.0:
				_play_ui_sound("impact_1")
				_transition_from_random_mission()
				get_viewport().set_input_as_handled()
	elif current_state == MenuState.MISSION_SELECT:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if ms_back_btn != null and ms_back_btn.get_global_rect().has_point(event.global_position):
				return
			var dist: float = event.global_position.distance_to(_ms_center_global())
			if dist > MS_BG_RADIUS:
				_play_ui_sound("impact_1")
				_transition_from_mission_select()
				get_viewport().set_input_as_handled()


func _on_mission_label_clicked(event: InputEvent, index: int):
	if current_state != MenuState.MISSION_SELECT: return
	if index > _max_unlocked_index():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ms_selection != index:
			ms_selection = index
			_play_ui_sound("impact_1")
			_update_ms_rotation()

func _on_ms_launch_clicked(event: InputEvent):
	if current_state != MenuState.MISSION_SELECT: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_launch_selected_mission()

func _on_ms_back_clicked(event: InputEvent):
	if current_state != MenuState.MISSION_SELECT:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_ui_sound("impact_1")
		_transition_from_mission_select()

func _launch_selected_mission() -> void:
	if current_state != MenuState.MISSION_SELECT:
		return
	if levels.is_empty() or ms_selection < 0 or ms_selection >= levels.size():
		return
	_play_ui_sound("impact_1")
	RunState.last_played_level_name = levels[ms_selection]
	RunState.pending_level_name = levels[ms_selection]
	RunState.pending_mission_index = ms_selection
	RunState.pending_level_info = null
	MusicSystem.stop_all(false)
	get_tree().change_scene_to_file("res://level_root.tscn")

func _max_unlocked_index() -> int:
	return mini(ProgressManager.max_mission, maxi(levels.size() - 1, 0))


func _apply_mission_unlock_state(reset_selection_to_frontier: bool = false) -> void:
	if reset_selection_to_frontier:
		ms_selection = clampi(ProgressManager.max_mission, 0, _max_unlocked_index())
	else:
		ms_selection = clampi(ms_selection, 0, _max_unlocked_index())
	for i in range(level_labels.size()):
		var unlocked := i <= _max_unlocked_index()
		level_labels[i].visible = unlocked
		if i < ms_score_labels.size():
			ms_score_labels[i].visible = unlocked
			var score := ProgressManager.get_score(levels[i])
			ms_score_labels[i].text = "Best Score: %d" % score


func _play_ui_sound(sound_name: String) -> void:
	var center = get_viewport_rect().size / 2
	SoundSystem.play(sound_name, center, self, 0.0, 1.0)

func _load_levels():
	levels.clear()
	for file_name in GameData.list_data_files(GameData.LEVEL):
		if file_name.ends_with(".lvl"):
			var base := file_name.trim_suffix(".lvl")
			# Match original: Random.lvl is procedural-only, not a normal pick.
			if base.to_lower() != "random":
				levels.append(base)
	levels.sort()
	if levels.is_empty():
		push_warning("No level files found; using Tutorial fallback")
		levels.append("0) Tutorial")

# --- Builders ---

func _build_splash_overlay():
	splash_overlay = TextureRect.new()
	splash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	splash_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	splash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var logo_path = GameData.get_data_path(GameData.Type.UI_GFX, "omgcup_banner3")
	if logo_path != "":
		splash_overlay.texture = GameData.load_texture(logo_path)
	
	splash_overlay.modulate.a = 0.0
	splash_overlay.scale = Vector2.ZERO
	splash_overlay.pivot_offset = Vector2(get_viewport_rect().size / 2)
	
	ui_layer.add_child(splash_overlay)

func _build_menu_container():
	menu_container = Control.new()
	menu_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_container.modulate.a = 0.0
	menu_container.draw.connect(_on_menu_draw)
	ui_layer.add_child(menu_container)
	
	var items := _visible_menu_items()
	for i in range(items.size()):
		var item = items[i]
		var label = Label.new()
		label.text = item.text
		label.position = item.pos
		
		if menu_font:
			label.add_theme_font_override("font", menu_font)
		label.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
		
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.gui_input.connect(_on_menu_item_clicked.bind(i))
		
		menu_container.add_child(label)
		menu_labels.append(label)

func _build_settings_container():
	settings_container = Control.new()
	settings_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_container.visible = false
	ui_layer.add_child(settings_container)
	
	# 1. Circle Visual (for animation)
	settings_circle_visual = Control.new()
	settings_circle_visual.position = SETTINGS_CIRCLE_CENTER
	settings_circle_visual.draw.connect(_on_settings_circle_draw)
	settings_container.add_child(settings_circle_visual)
	
	# 2. Labels Container
	settings_labels_container = Control.new()
	settings_labels_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_container.add_child(settings_labels_container)
	
	# Add Items
	var target_x = 190 + 250 # Original animation slide distance
	for i in range(SETTINGS_ITEMS.size()):
		var item = SETTINGS_ITEMS[i]
		var label = Label.new()
		label.text = _settings_row_text(item)
		label.position = Vector2(target_x - 80, SETTINGS_CIRCLE_CENTER.y + item.offset_y)
		
		if menu_font:
			label.add_theme_font_override("font", menu_font)
		label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
		label.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
		
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.set_meta("settings_index", i)
		
		settings_labels_container.add_child(label)
		settings_labels.append(label)

func _build_mission_select_container():
	mission_select_container = Control.new()
	mission_select_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_select_container.visible = false
	mission_select_container.draw.connect(func() -> void: _draw_mission_select_bg(mission_select_container))
	ui_layer.add_child(mission_select_container)
	
	ms_anchor = Control.new()
	ms_anchor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ms_anchor.offset_right = MS_ANCHOR_OFFSET_RIGHT
	ms_anchor.offset_bottom = MS_ANCHOR_OFFSET_BOTTOM
	ms_anchor.offset_left = MS_ANCHOR_OFFSET_RIGHT
	ms_anchor.offset_top = MS_ANCHOR_OFFSET_BOTTOM
	mission_select_container.add_child(ms_anchor)
	
	# Labels Container (Rotates)
	ms_labels_container = Control.new()
	ms_anchor.add_child(ms_labels_container)
	
	for i in range(levels.size()):
		ms_labels_container.add_child(_create_mission_label(i))
	
	_update_ms_rotation(true) # Instant update
	
	# Launch button stays fixed relative to the mission-select anchor (left of the wheel).
	ms_launch_btn = Label.new()
	ms_launch_btn.text = "Launch"
	ms_launch_btn.position = MS_LAUNCH_BTN_OFFSET
	if menu_font:
		ms_launch_btn.add_theme_font_override("font", menu_font)
	ms_launch_btn.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	ms_launch_btn.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
	ms_launch_btn.gui_input.connect(_on_ms_launch_clicked)
	ms_launch_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	ms_anchor.add_child(ms_launch_btn)

	ms_back_btn = Label.new()
	ms_back_btn.text = "Back"
	ms_back_btn.position = MS_BACK_BTN_POS
	if menu_font:
		ms_back_btn.add_theme_font_override("font", menu_font)
	ms_back_btn.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	ms_back_btn.add_theme_color_override("font_color", Color.WHITE)
	ms_back_btn.gui_input.connect(_on_ms_back_clicked)
	ms_back_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	mission_select_container.add_child(ms_back_btn)

func _create_mission_label(index: int) -> Label:
	var label = Label.new()
	label.text = levels[index]
	if menu_font:
		label.add_theme_font_override("font", menu_font)
	label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.gui_input.connect(_on_mission_label_clicked.bind(index))
	level_labels.append(label)

	var score_label = Label.new()
	score_label.text = "Best Score: 0"
	if menu_font:
		score_label.add_theme_font_override("font", menu_font)
	score_label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE - 4)
	score_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.55))
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ms_score_labels.append(score_label)
	ms_labels_container.add_child(score_label)

	return label


func _rebuild_mission_select_labels() -> void:
	if ms_labels_container == null:
		return
	for label in level_labels:
		if is_instance_valid(label):
			label.queue_free()
	for label in ms_score_labels:
		if is_instance_valid(label):
			label.queue_free()
	level_labels.clear()
	ms_score_labels.clear()
	for child in ms_labels_container.get_children():
		child.queue_free()
	for i in range(levels.size()):
		ms_labels_container.add_child(_create_mission_label(i))
	_apply_mission_unlock_state()
	_update_ms_rotation(true)


func _build_mod_ui() -> void:
	_is_web = OS.has_feature("web")
	mod_container = VBoxContainer.new()
	mod_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mod_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mod_container.offset_right = -MOD_UI_MARGIN.x
	mod_container.offset_top = MOD_UI_MARGIN.y
	mod_container.alignment = BoxContainer.ALIGNMENT_END
	mod_container.add_theme_constant_override("separation", 4)
	mod_container.modulate.a = 0.0
	mod_container.visible = false
	ui_layer.add_child(mod_container)

	mod_load_btn = Label.new()
	mod_load_btn.text = "Load Mod"
	mod_load_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if menu_font:
		mod_load_btn.add_theme_font_override("font", menu_font)
	mod_load_btn.add_theme_font_size_override("font_size", MOD_FONT_SIZE)
	mod_load_btn.add_theme_color_override("font_color", Color.WHITE)
	mod_load_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	mod_load_btn.gui_input.connect(_on_mod_load_clicked)
	mod_container.add_child(mod_load_btn)

	mod_status_label = Label.new()
	mod_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if menu_font:
		mod_status_label.add_theme_font_override("font", menu_font)
	mod_status_label.add_theme_font_size_override("font_size", MOD_FONT_SIZE - 4)
	mod_status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	mod_status_label.visible = false
	mod_container.add_child(mod_status_label)

	# Web-only: re-read the picked folder so an edited mod can be pulled in again.
	if _is_web:
		mod_refresh_btn = _make_mod_secondary_label("Refresh", _on_mod_refresh_clicked)
		mod_container.add_child(mod_refresh_btn)

	mod_unload_btn = _make_mod_secondary_label("Unload", _on_mod_unload_clicked)
	mod_container.add_child(mod_unload_btn)

	if _is_web:
		web_mod_loader = WebModLoader.new()
		web_mod_loader.mod_imported.connect(_on_web_mod_imported)
		web_mod_loader.mod_cancelled.connect(_on_web_mod_cancelled)
		add_child(web_mod_loader)
	else:
		mod_file_dialog = FileDialog.new()
		mod_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		mod_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		mod_file_dialog.title = "Select Mod Data Directory"
		mod_file_dialog.dir_selected.connect(_on_mod_dir_selected)
		add_child(mod_file_dialog)

	_update_mod_status_display()


func _make_mod_secondary_label(text: String, handler: Callable) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if menu_font:
		label.add_theme_font_override("font", menu_font)
	label.add_theme_font_size_override("font_size", MOD_FONT_SIZE - 4)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.gui_input.connect(handler)
	label.visible = false
	return label


func _hide_mod_ui() -> void:
	if mod_container != null:
		mod_container.visible = false


func _show_mod_ui() -> void:
	if mod_container != null:
		mod_container.visible = true
		mod_container.modulate.a = 1.0


func _update_mod_status_display() -> void:
	if mod_status_label == null:
		return
	var has_mod := not GameData.mod_dir.is_empty()
	mod_status_label.visible = has_mod
	mod_unload_btn.visible = has_mod
	if mod_refresh_btn != null:
		mod_refresh_btn.visible = has_mod
	if has_mod:
		mod_status_label.text = GameData.mod_name
		mod_status_label.tooltip_text = GameData.mod_dir


func _refresh_after_mod_change() -> void:
	_load_levels()
	_rebuild_mission_select_labels()
	_update_mod_status_display()


func _on_mod_load_clicked(event: InputEvent) -> void:
	if current_state != MenuState.MAIN:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# The picker must be opened from within this input callback so the browser
		# still treats it as a user gesture on web.
		if _is_web:
			web_mod_loader.begin_pick()
		else:
			mod_file_dialog.popup_centered_ratio(0.6)


func _on_mod_refresh_clicked(event: InputEvent) -> void:
	if current_state != MenuState.MAIN:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		web_mod_loader.begin_refresh()


func _on_mod_dir_selected(path: String) -> void:
	if GameData.set_mod_dir(path):
		_play_ui_sound("impact_1")
		_refresh_after_mod_change()


func _on_web_mod_imported(dir_path: String, display_name: String) -> void:
	if GameData.set_mod_dir(dir_path, display_name):
		_play_ui_sound("impact_1")
		_refresh_after_mod_change()


func _on_web_mod_cancelled() -> void:
	pass


func _on_mod_unload_clicked(event: InputEvent) -> void:
	if current_state != MenuState.MAIN:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameData.clear_mod()
		_play_ui_sound("impact_1")
		_refresh_after_mod_change()

func _build_transition_overlay():
	transition_overlay = Control.new()
	transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.draw.connect(_on_transition_draw)
	ui_layer.add_child(transition_overlay)

# --- Draw Callbacks ---

func _on_menu_draw():
	menu_container.draw_circle(CIRCLE_CENTER, CIRCLE_RADIUS, Color(1, 1, 1, 0.7))
	menu_container.draw_arc(CIRCLE_CENTER, CIRCLE_RADIUS, 0, TAU, 100, Color(1, 1, 1, 1), CIRCLE_WIDTH, true)
	menu_container.draw_rect(Rect2(-1000, -1000, 2000, 1000), Color.BLACK)
	menu_container.draw_rect(Rect2(-1000, -1000, 1000, 2000), Color.BLACK)

func _on_settings_circle_draw():
	settings_circle_visual.draw_circle(Vector2.ZERO, SETTINGS_CIRCLE_RADIUS, Color(1, 1, 1, 0.7))
	settings_circle_visual.draw_arc(Vector2.ZERO, SETTINGS_CIRCLE_RADIUS, 0, TAU, 64, Color(1, 1, 1, 1), CIRCLE_WIDTH, true)
	settings_circle_visual.draw_line(Vector2(-100, -150), Vector2(-100, 150), Color.BLACK, 1.0)

func _ms_center_global() -> Vector2:
	if ms_anchor != null and is_instance_valid(ms_anchor):
		return ms_anchor.global_position
	return MS_CENTER


func _ms_select_center() -> Vector2:
	if ms_anchor != null:
		return ms_anchor.position
	return Vector2(
		DESIGN_VIEWPORT_SIZE.x - MS_ANCHOR_OFFSET_RIGHT,
		DESIGN_VIEWPORT_SIZE.y - MS_ANCHOR_OFFSET_BOTTOM
	)


func _draw_mission_select_bg(host: Control) -> void:
	var center := _ms_select_center()
	host.draw_circle(center, MS_BG_RADIUS, Color(1, 1, 1, 0.7))
	host.draw_arc(center, MS_BG_RADIUS, 0, TAU, 128, Color(1, 1, 1, 1), CIRCLE_WIDTH, true)

func _on_transition_draw():
	if ripple_active:
		# Draw ripple
		# Center moves from ripple_center to ripple_target based on progress?
		# Or simplified: Draw a circle at ripple_center with radius ripple_radius.
		# But we want to wipe the screen.
		# Original logic:
		# For i=0 To 900 Step 40
		# x = x2 + i (Center moves linearly)
		# r = i / 1000 * 100 (Radius grows linearly)
		# This creates a "comet" shape or moving circle.
		# Let's simplify: Draw a HUGE white circle that grows.
		# If ripple_expanding: White Circle grows.
		# If ripple_contracting: White Circle shrinks (erasing the white).
		# Actually, we want to Transition from Menu -> Mission Select.
		# Menu is visible. We draw White Circle over it.
		# When fully white, we switch visibility.
		# Then shrink White Circle to reveal Mission Select.
		var col = Color(1, 1, 1, 1)
		transition_overlay.draw_circle(ripple_center, ripple_radius, col)

# --- Updates ---

func _update_ms_rotation(instant: bool = false):
	# Target angle: selection * 15 + 180
	var target = ms_selection * MS_ANGLE_STEP + 180.0
	
	if instant:
		ms_current_angle = target
		_apply_ms_rotation()
	else:
		var tween = create_tween()
		tween.tween_property(self, "ms_current_angle", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_apply_ms_rotation) # Ensure final update is exact? Or use tween_method
		tween.kill() # Actually we should just use tween_method or update in process.
		
		# Easier: Just tween property and use setget or _process?
		# Let's just set properties and update positions in _process if needed, 
		# OR just tween the positions of labels directly.
		
		# Let's tween `ms_current_angle` and use a setter or tween_method
		var t = create_tween()
		t.tween_method(func(val):
			ms_current_angle = val
			_apply_ms_rotation(),
			ms_current_angle, target, 0.3)

func _apply_ms_rotation():
	# Update label positions based on ms_current_angle
	# Label i should be at angle: (angle_origin - i*15 + 180) ?
	# Original: DrawText(s$, Cos(angleOrigin - inc*15 + 180) * 460 ...)
	# Here angleOrigin is our ms_current_angle.
	# So Label i is at: ms_current_angle - i*15 + 180 (degrees)
	for i in range(level_labels.size()):
		var label = level_labels[i]
		var angle_deg = ms_current_angle - (i * MS_ANGLE_STEP)
		var angle_rad = deg_to_rad(angle_deg)
		
		var pos = Vector2(cos(angle_rad), sin(angle_rad)) * MS_RADIUS
		
		var label_size = label.get_minimum_size()
		label.position = pos - label_size / 2
		
		label.pivot_offset = label_size / 2
		label.rotation = deg_to_rad(angle_deg + 180)
		label.modulate.a = 1.0
		
		if i < ms_score_labels.size():
			var score_label = ms_score_labels[i]
			var score_angle_rad = deg_to_rad(angle_deg - 90.0)
			var score_pos = pos + Vector2(cos(score_angle_rad), sin(score_angle_rad)) * 40.0
			var score_size = score_label.get_minimum_size()
			score_label.position = score_pos - score_size / 2
			score_label.pivot_offset = score_size / 2
			score_label.rotation = deg_to_rad(angle_deg + 180)
		
		var unlocked := i <= _max_unlocked_index()
		if i == ms_selection:
			label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			label.scale = Vector2(1.1, 1.1)
		else:
			label.add_theme_color_override("font_color", Color(0, 0, 0, 0.7))
			label.scale = Vector2(1.0, 1.0)
		
		var show_on_wheel: bool = unlocked and abs(angle_deg - 180.0) <= 90.0
		label.visible = show_on_wheel
		if i < ms_score_labels.size():
			ms_score_labels[i].visible = show_on_wheel

# --- Transitions ---

func _enter_mission_select_from_mission_end() -> void:
	if splash_overlay != null and is_instance_valid(splash_overlay):
		splash_overlay.queue_free()
	splash_overlay = null

	menu_container.visible = false
	menu_container.modulate.a = 1.0
	mission_select_container.visible = true
	ripple_active = false
	ripple_radius = 0.0
	transition_overlay.queue_redraw()

	if RunState.last_played_level_name != "":
		var idx := levels.find(RunState.last_played_level_name)
		if idx >= 0:
			ms_selection = clampi(idx, 0, _max_unlocked_index())
	_apply_mission_unlock_state()
	_update_ms_rotation(true)
	current_state = MenuState.MISSION_SELECT
	_hide_mod_ui()

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.modulate.a = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade)
	ui_layer.move_child(fade, ui_layer.get_child_count() - 1)
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, RETURN_FROM_MISSION_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(fade.queue_free)


func _enter_random_mission_from_mission_end() -> void:
	if splash_overlay != null and is_instance_valid(splash_overlay):
		splash_overlay.queue_free()
	splash_overlay = null

	menu_container.visible = false
	menu_container.modulate.a = 1.0
	mission_select_container.visible = false
	random_mission_container.visible = true
	ripple_active = false
	ripple_radius = 0.0
	transition_overlay.queue_redraw()

	rm_ship_index = RunState.random_mission_ship_index
	rm_player_team = RunState.random_mission_team
	rm_convoy_slider.value = RunState.random_mission_convoy_slider
	rm_escort_slider.value = RunState.random_mission_escort_slider
	rm_enemy_slider.value = RunState.random_mission_enemy_slider
	_refresh_random_mission_ui()
	current_state = MenuState.RANDOM_MISSION
	_hide_mod_ui()

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.modulate.a = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade)
	ui_layer.move_child(fade, ui_layer.get_child_count() - 1)
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, RETURN_FROM_MISSION_FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(fade.queue_free)


func _save_random_mission_ui_state() -> void:
	RunState.random_mission_ship_index = rm_ship_index
	RunState.random_mission_team = rm_player_team
	RunState.random_mission_convoy_slider = rm_convoy_slider.value
	RunState.random_mission_escort_slider = rm_escort_slider.value
	RunState.random_mission_enemy_slider = rm_enemy_slider.value


func _start_splash_sequence():
	current_state = MenuState.TRANSITIONING
	_splash_sequence_active = true
	_hide_mod_ui()
	menu_container.visible = true
	splash_overlay.visible = true
	splash_overlay.scale = Vector2.ZERO
	splash_overlay.modulate.a = 1.0
	
	_splash_tween = create_tween()
	_splash_tween.tween_property(splash_overlay, "scale", Vector2(10, 10), 4.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_splash_tween.parallel().tween_property(splash_overlay, "modulate:a", 0.0, 1.0).set_delay(3.0)
	_splash_tween.parallel().tween_property(menu_container, "modulate:a", 1.0, 1.5).set_delay(3.5)
	_splash_tween.parallel().tween_callback(func(): mod_container.visible = true).set_delay(3.5)
	_splash_tween.parallel().tween_property(mod_container, "modulate:a", 1.0, 1.5).set_delay(3.5)
	_splash_tween.tween_callback(_on_splash_finished)

func _is_splash_skip_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	return false

func _skip_splash() -> void:
	if not _splash_sequence_active:
		return
	if _splash_tween != null and _splash_tween.is_valid():
		_splash_tween.kill()
	_splash_tween = null
	_finish_splash()

func _on_splash_finished():
	_finish_splash()

func _finish_splash() -> void:
	if not _splash_sequence_active:
		return
	_splash_sequence_active = false
	current_state = MenuState.MAIN
	menu_container.modulate.a = 1.0
	_show_mod_ui()
	if splash_overlay != null and is_instance_valid(splash_overlay):
		splash_overlay.queue_free()
	splash_overlay = null

func _transition_to_settings():
	if current_state != MenuState.MAIN: return
	current_state = MenuState.TRANSITIONING
	_hide_mod_ui()
	
	settings_container.visible = true
	settings_circle_visual.scale = Vector2.ZERO
	settings_circle_visual.position = Vector2(190, 455)
	
	settings_circle_visual.position.x = 190
	settings_labels_container.modulate.a = 0.0
	_refresh_settings_labels()
	
	var tween = create_tween()
	tween.set_parallel(true)
	_play_ui_sound("impact_1") # Sound for transition
	tween.tween_property(menu_container, "modulate:a", 0.5, 0.5)
	tween.tween_property(settings_circle_visual, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_circle_visual, "position:x", 440.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(settings_labels_container, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tween.chain().tween_callback(func(): current_state = MenuState.SETTINGS)

func _transition_from_settings():
	if current_state != MenuState.SETTINGS: return
	current_state = MenuState.TRANSITIONING
	_editing_pilot_name = false
	_rebind_action = ""
	ProgressManager.save_preferences()
	
	var tween = create_tween()
	tween.set_parallel(true)
	_play_ui_sound("impact_1")
	tween.tween_property(settings_labels_container, "modulate:a", 0.0, 0.3)
	tween.tween_property(settings_circle_visual, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(settings_circle_visual, "position:x", 190.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(menu_container, "modulate:a", 1.0, 0.5)
	tween.chain().tween_callback(func():
		settings_container.visible = false
		current_state = MenuState.MAIN
		_show_mod_ui()
	)

func _transition_to_mission_select():
	if current_state != MenuState.MAIN: return
	current_state = MenuState.TRANSITIONING
	_hide_mod_ui()
	_apply_mission_unlock_state(true)
	
	ripple_active = true
	ripple_radius = 0.0
	ripple_center = Vector2(370, 230) # Start point
	# We want to wipe the screen white.
	# Max radius to cover screen from that point ~1200.
	
	var tween = create_tween()
	# Grow Ripple to cover screen
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		0.0, 1500.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Mid-transition: Swap scenes
	tween.tween_callback(func():
		menu_container.visible = false
		mission_select_container.visible = true
		_update_ms_rotation(true) # Reset rotation
	)
	
	# Shrink Ripple (Reveal Mission Select)
	# Original uses CompactLevels which is reverse?
	# "For i=500 To 100 Step -40" ...
	# Let's just shrink it back down or fade it out?
	# Or since the Mission Select background is white/transparent...
	# If we shrink the white circle, it will reveal the ocean/mission select behind it.
	# But we need to make sure the Mission Select UI is ready.
	
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		1500.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		ripple_active = false
		current_state = MenuState.MISSION_SELECT
	)

func _transition_from_mission_select():
	if current_state != MenuState.MISSION_SELECT: return
	current_state = MenuState.TRANSITIONING
	
	ripple_active = true
	ripple_radius = 0.0
	
	var tween = create_tween()
	# Cover screen
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		0.0, 1500.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Swap scenes
	tween.tween_callback(func():
		mission_select_container.visible = false
		menu_container.visible = true
		menu_container.modulate.a = 1.0
	)
	
	# Reveal Menu
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		1500.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(func():
		ripple_active = false
		current_state = MenuState.MAIN
		_show_mod_ui()
	)

# --- Input Handlers ---

func _on_menu_item_clicked(event: InputEvent, index: int):
	if current_state != MenuState.MAIN: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var items := _visible_menu_items()
		var item = items[index]
		print("Selected: ", item.text)
		_play_ui_sound("impact_1")
		match item.text:
			"New Mission":
				_transition_to_mission_select()
			"Random Mission":
				_transition_to_random_mission()
			"Controls":
				_transition_to_settings()
			"Quit":
				get_tree().quit()


# --- Settings ---

func _settings_row_text(item: Dictionary) -> String:
	match item.kind:
		"action":
			return "%s: %s" % [item.prefix, ProgressManager.input_action_label(item.action)]
		"pilot":
			var pilot := ProgressManager.pilot_name
			if _editing_pilot_name:
				pilot += "_"
			return "Pilot Name: %s" % pilot
	return ""


func _refresh_settings_labels() -> void:
	for i in range(mini(settings_labels.size(), SETTINGS_ITEMS.size())):
		settings_labels[i].text = _settings_row_text(SETTINGS_ITEMS[i])


func _handle_settings_click(global_pos: Vector2) -> void:
	if _rebind_action != "":
		return
	for i in range(settings_labels.size()):
		var label: Label = settings_labels[i]
		if not label.get_global_rect().has_point(global_pos):
			continue
		var item: Dictionary = SETTINGS_ITEMS[i]
		_play_ui_sound("impact_1")
		match item.kind:
			"action":
				_rebind_action = item.action
				label.text = "%s: ..." % item.prefix
			"pilot":
				_editing_pilot_name = true
				_refresh_settings_labels()
		return


func _handle_pilot_name_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_editing_pilot_name = false
			ProgressManager.save_pilot_name(ProgressManager.pilot_name)
			_refresh_settings_labels()
			return
		if event.keycode == KEY_BACKSPACE:
			ProgressManager.pilot_name = ProgressManager.pilot_name.substr(0, maxi(ProgressManager.pilot_name.length() - 1, 0))
		elif event.keycode == KEY_SPACE:
			if ProgressManager.pilot_name.length() < ProgressManager.PILOT_NAME_MAX_CHARS:
				ProgressManager.pilot_name += " "
		elif event.unicode > 0:
			var c := char(event.unicode)
			if c.is_valid_identifier() or c == " ":
				if ProgressManager.pilot_name.length() < ProgressManager.PILOT_NAME_MAX_CHARS:
					ProgressManager.pilot_name += c
		_refresh_settings_labels()
	elif event is InputEventMouseButton and event.pressed:
		_editing_pilot_name = false
		ProgressManager.save_pilot_name(ProgressManager.pilot_name)
		_refresh_settings_labels()


# --- First-run setup ---

func _build_first_run_overlay() -> void:
	first_run_overlay = Control.new()
	first_run_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	first_run_overlay.visible = false
	first_run_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	first_run_overlay.draw.connect(func() -> void:
		first_run_overlay.draw_rect(Rect2(Vector2.ZERO, first_run_overlay.size), Color.BLACK)
	)
	ui_layer.add_child(first_run_overlay)

	var center_x := DESIGN_VIEWPORT_SIZE.x * 0.5
	first_run_pilot_label = Label.new()
	first_run_pilot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first_run_pilot_label.position = Vector2(center_x - 300, DESIGN_VIEWPORT_SIZE.y * 0.5 - 20)
	first_run_pilot_label.custom_minimum_size = Vector2(600, 40)
	if menu_font:
		first_run_pilot_label.add_theme_font_override("font", menu_font)
	first_run_pilot_label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	first_run_pilot_label.add_theme_color_override("font_color", Color.WHITE)
	first_run_overlay.add_child(first_run_pilot_label)


func _start_first_run() -> void:
	current_state = MenuState.FIRST_RUN
	_hide_mod_ui()
	if splash_overlay != null and is_instance_valid(splash_overlay):
		splash_overlay.visible = false
	menu_container.visible = false
	first_run_overlay.visible = true
	_update_first_run_pilot_label()


func _update_first_run_pilot_label() -> void:
	var t := ProgressManager.pilot_name
	if int(Time.get_ticks_msec() / 500.0) % 2 == 0:
		t += "_"
	first_run_pilot_label.text = "Pilot Name:\n%s" % t


func _handle_first_run_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_ESCAPE:
			_finish_first_run()
			return
		if event.keycode == KEY_BACKSPACE:
			ProgressManager.pilot_name = ProgressManager.pilot_name.substr(0, maxi(ProgressManager.pilot_name.length() - 1, 0))
		elif event.keycode == KEY_SPACE:
			if ProgressManager.pilot_name.length() < ProgressManager.PILOT_NAME_MAX_CHARS:
				ProgressManager.pilot_name += " "
		elif event.unicode > 0:
			var c := char(event.unicode)
			if c.is_valid_identifier() or c == " ":
				if ProgressManager.pilot_name.length() < ProgressManager.PILOT_NAME_MAX_CHARS:
					ProgressManager.pilot_name += c
		_update_first_run_pilot_label()
	elif event is InputEventMouseButton and event.pressed:
		_finish_first_run()


func _finish_first_run() -> void:
	if ProgressManager.pilot_name.is_empty():
		ProgressManager.pilot_name = "Ace"
	ProgressManager.save_preferences()
	first_run_overlay.visible = false
	current_state = MenuState.SPLASH
	_start_splash_sequence()


# --- Random mission screen ---

func _load_playable_ships() -> void:
	rm_playable_ships.clear()
	for base_name in GameData.list_ship_info_base_names():
		var si := ShipInfo.named(base_name)
		if si != null and si.playable:
			rm_playable_ships.append(si.name)
	rm_ship_index = maxi(rm_playable_ships.find("Flak Interceptor"), 0)


func _build_random_mission_container() -> void:
	_load_playable_ships()
	random_mission_container = Control.new()
	random_mission_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	random_mission_container.visible = false
	random_mission_container.draw.connect(func() -> void: _draw_mission_select_bg(random_mission_container))
	ui_layer.add_child(random_mission_container)

	var panel_x1 := RM_PANEL_LEFT
	var panel_y1 := 350.0
	var panel_x2 := DESIGN_VIEWPORT_SIZE.x - 10.0
	var panel_center_x := (panel_x1 + panel_x2) * 0.5

	rm_ship_caption = _make_rm_caption("Player Ship:", Vector2(panel_center_x - 150, panel_y1 - 20), 300)
	random_mission_container.add_child(rm_ship_caption)

	rm_ship_preview = TextureRect.new()
	rm_ship_preview.position = Vector2(panel_center_x - 48, panel_y1 + 50)
	rm_ship_preview.custom_minimum_size = Vector2(96, 96)
	rm_ship_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rm_ship_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rm_ship_preview.mouse_filter = Control.MOUSE_FILTER_PASS
	rm_ship_preview.gui_input.connect(_on_rm_ship_preview_clicked)
	random_mission_container.add_child(rm_ship_preview)

	rm_ship_name_label = Label.new()
	rm_ship_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rm_ship_name_label.position = Vector2(panel_center_x - 150, panel_y1 + 150)
	rm_ship_name_label.custom_minimum_size = Vector2(300, 30)
	if menu_font:
		rm_ship_name_label.add_theme_font_override("font", menu_font)
	rm_ship_name_label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	random_mission_container.add_child(rm_ship_name_label)

	rm_human_btn = _make_rm_team_button("Human", Vector2(panel_center_x - 40, panel_y1 + 500), 1)
	rm_telrith_btn = _make_rm_team_button("Tel-Rith", Vector2(panel_center_x - 40, panel_y1 + 530), 2)
	rm_pirate_btn = _make_rm_team_button("Pirate", Vector2(panel_center_x - 40, panel_y1 + 560), 3)
	random_mission_container.add_child(rm_human_btn)
	random_mission_container.add_child(rm_telrith_btn)
	random_mission_container.add_child(rm_pirate_btn)

	var slider_width := panel_x2 - panel_x1
	rm_convoy_label = _make_rm_caption("Convoy Size:", Vector2(panel_x1, panel_y1 + 250 - 36), slider_width)
	rm_escort_label = _make_rm_caption("Escort Strength:", Vector2(panel_x1, panel_y1 + 350 - 36), slider_width)
	rm_enemy_label = _make_rm_caption("Enemy Strength:", Vector2(panel_x1, panel_y1 + 450 - 36), slider_width)
	random_mission_container.add_child(rm_convoy_label)
	random_mission_container.add_child(rm_escort_label)
	random_mission_container.add_child(rm_enemy_label)

	rm_convoy_slider = _make_rm_slider(panel_x1, panel_y1 + 250, slider_width, 0.3)
	rm_escort_slider = _make_rm_slider(panel_x1, panel_y1 + 350, slider_width, 0.2)
	rm_enemy_slider = _make_rm_slider(panel_x1, panel_y1 + 450, slider_width, 0.3)
	random_mission_container.add_child(rm_convoy_slider)
	random_mission_container.add_child(rm_escort_slider)
	random_mission_container.add_child(rm_enemy_slider)

	rm_launch_btn = Label.new()
	rm_launch_btn.text = "Launch"
	rm_launch_btn.position = Vector2(panel_x1, panel_y1 - 70)
	rm_launch_btn.custom_minimum_size = Vector2(slider_width, 40)
	rm_launch_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if menu_font:
		rm_launch_btn.add_theme_font_override("font", menu_font)
	rm_launch_btn.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	rm_launch_btn.gui_input.connect(_on_rm_launch_clicked)
	rm_launch_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	random_mission_container.add_child(rm_launch_btn)

	rm_back_btn = Label.new()
	rm_back_btn.text = "Back"
	rm_back_btn.position = MS_BACK_BTN_POS
	if menu_font:
		rm_back_btn.add_theme_font_override("font", menu_font)
	rm_back_btn.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	rm_back_btn.add_theme_color_override("font_color", Color.WHITE)
	rm_back_btn.gui_input.connect(_on_rm_back_clicked)
	rm_back_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	random_mission_container.add_child(rm_back_btn)

	_refresh_random_mission_ui()


func _make_rm_team_button(text: String, pos: Vector2, team: int) -> Label:
	var btn := Label.new()
	btn.text = text
	btn.position = pos
	if menu_font:
		btn.add_theme_font_override("font", menu_font)
	btn.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			rm_player_team = team
			_refresh_random_mission_ui()
			_play_ui_sound("impact_1")
	)
	return btn


func _make_rm_caption(text: String, pos: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.custom_minimum_size = Vector2(width, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if menu_font:
		label.add_theme_font_override("font", menu_font)
	label.add_theme_font_size_override("font_size", SETTINGS_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_rm_slider(x: float, y: float, width: float, default_val: float) -> HSlider:
	var slider := HSlider.new()
	slider.position = Vector2(x, y)
	slider.custom_minimum_size = Vector2(width, 20)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = default_val
	slider.value_changed.connect(func(_v: float) -> void: _refresh_random_mission_ui())
	return slider


func _refresh_random_mission_ui() -> void:
	if rm_playable_ships.is_empty():
		return
	rm_ship_index = clampi(rm_ship_index, 0, rm_playable_ships.size() - 1)
	var ship_name := rm_playable_ships[rm_ship_index]
	rm_ship_name_label.text = ship_name
	var si := ShipInfo.named(ship_name)
	if si != null:
		var path := GameData.get_data_path(GameData.Type.SHIP_GFX, si.img_name)
		if path != "":
			rm_ship_preview.texture = GameData.load_texture(path)
			rm_ship_preview.modulate = Color(si.r / 255.0, si.g / 255.0, si.b / 255.0)
	var team_alpha := 0.6
	rm_human_btn.modulate.a = 0.9 if rm_player_team == 1 else team_alpha
	rm_telrith_btn.modulate.a = 0.9 if rm_player_team == 2 else team_alpha
	rm_pirate_btn.modulate.a = 0.9 if rm_player_team == 3 else team_alpha
	# Captions mirror the values the original RandomMissionScreen displayed.
	if rm_convoy_label != null and rm_convoy_slider != null:
		rm_convoy_label.text = "Convoy Size: %d" % (int(14.0 * rm_convoy_slider.value) + 1)
	if rm_escort_label != null and rm_escort_slider != null:
		rm_escort_label.text = "Escort Strength: %d" % int(100.0 * rm_escort_slider.value)
	if rm_enemy_label != null and rm_enemy_slider != null:
		rm_enemy_label.text = "Enemy Strength: %d" % (int(99.0 * rm_enemy_slider.value) + 1)


func _on_rm_ship_preview_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if rm_playable_ships.is_empty():
			return
		rm_ship_index = (rm_ship_index + 1) % rm_playable_ships.size()
		var si := ShipInfo.named(rm_playable_ships[rm_ship_index])
		if si != null:
			rm_player_team = si.team
		_refresh_random_mission_ui()
		_play_ui_sound("impact_1")


func _on_rm_launch_clicked(event: InputEvent) -> void:
	if current_state != MenuState.RANDOM_MISSION:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_launch_random_mission()


func _on_rm_back_clicked(event: InputEvent) -> void:
	if current_state != MenuState.RANDOM_MISSION:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_ui_sound("impact_1")
		_transition_from_random_mission()


func _launch_random_mission() -> void:
	if rm_playable_ships.is_empty():
		return
	var ship_name := rm_playable_ships[rm_ship_index]
	var cvs := int(14.0 * rm_convoy_slider.value) + 1
	var ess := int(100.0 * rm_escort_slider.value)
	var ens := int(rm_enemy_slider.value * 750.0 + 50.0)
	var proc: LevelInfo = RandomMissionGenerator.build_random_mission(
		ship_name, rm_player_team, cvs, ess, ens
	) as LevelInfo
	if proc == null:
		push_error("Procedural random mission failed to build (Random.lvl missing?)")
		return
	_save_random_mission_ui_state()
	RunState.pending_level_info = proc
	RunState.pending_level_name = ""
	RunState.pending_mission_index = -1
	RunState.last_played_level_name = "Random"
	_play_ui_sound("impact_1")
	MusicSystem.stop_all(false)
	get_tree().change_scene_to_file("res://level_root.tscn")


func _transition_to_random_mission() -> void:
	if current_state != MenuState.MAIN:
		return
	current_state = MenuState.TRANSITIONING
	_hide_mod_ui()
	_load_playable_ships()
	rm_player_team = 1
	if not rm_playable_ships.is_empty():
		var si := ShipInfo.named(rm_playable_ships[rm_ship_index])
		if si != null:
			rm_player_team = si.team
	_refresh_random_mission_ui()

	ripple_active = true
	ripple_radius = 0.0
	ripple_center = Vector2(280, 350)

	var tween = create_tween()
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		0.0, 1500.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		menu_container.visible = false
		random_mission_container.visible = true
	)
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		1500.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		ripple_active = false
		current_state = MenuState.RANDOM_MISSION
	)


func _transition_from_random_mission() -> void:
	if current_state != MenuState.RANDOM_MISSION:
		return
	current_state = MenuState.TRANSITIONING
	ripple_active = true
	ripple_radius = 0.0
	var tween = create_tween()
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		0.0, 1500.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		random_mission_container.visible = false
		menu_container.visible = true
		menu_container.modulate.a = 1.0
	)
	tween.tween_method(func(val):
		ripple_radius = val
		transition_overlay.queue_redraw(),
		1500.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		ripple_active = false
		current_state = MenuState.MAIN
		_show_mod_ui()
	)
