extends CanvasLayer
## Pause / abort UI while the scene tree is frozen (matches BlitzMax Level.bmx).

func _level() -> Level:
	return get_parent() as Level

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 132
	visible = false
	set_process_input(true)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var label := Label.new()
	label.text = "<GAME PAUSED>  Abort mission?  Y or N"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(360, 0)
	label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))

	margin.add_child(label)
	panel.add_child(margin)
	center.add_child(panel)


func _input(event: InputEvent) -> void:
	var lvl := _level()
	if not visible or lvl == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				lvl.resume_from_pause()
				get_viewport().set_input_as_handled()
			KEY_Y:
				lvl.abort_mission_from_pause()
				get_viewport().set_input_as_handled()
			KEY_N:
				lvl.resume_from_pause()
				get_viewport().set_input_as_handled()
