extends CanvasLayer
## Mission start: level description until the player presses a key or clicks (see BlitzMax briefing).

var _level: Level = null


func _ready() -> void:
	set_process_unhandled_input(true)


func configure(level: Level, description: String) -> void:
	_level = level
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 129

	GameState.block_player_input = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Let clicks pass through to `root` (only `root` has gui_input connected).
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 120)
	root.add_child(margin)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.set_corner_radius_all(4)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var body := Label.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(520, 0)
	var font := load("res://font.otf") as Font
	if font:
		body.add_theme_font_override("font", font)
		body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	vbox.add_child(body)

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "Press Space or Click to begin"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font:
		hint.add_theme_font_override("font", font)
		hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	vbox.add_child(hint)

	root.gui_input.connect(_on_root_gui_input)


func _unhandled_input(event: InputEvent) -> void:
	if _should_dismiss(event):
		get_viewport().set_input_as_handled()
		_dismiss()


func _on_root_gui_input(event: InputEvent) -> void:
	if _should_dismiss(event):
		get_viewport().set_input_as_handled()
		_dismiss()


func _should_dismiss(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _dismiss() -> void:
	if is_queued_for_deletion():
		return
	if _level:
		_level.briefing_active = false
	GameState.block_player_input = false
	queue_free()
