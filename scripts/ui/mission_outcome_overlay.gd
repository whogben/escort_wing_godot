extends CanvasLayer
## Mission failure / success presentation (matches BlitzMax ingameUI drawFailure/drawSuccess + Level debrief).

const FLASH_DURATION: float = 2.0
const DEBRIEF_FADE_RATE: float = 0.25

var _failure_time: float = 0.0
var _success_time: float = 0.0
var _debrief_alpha: float = 0.0
var _failure_started: bool = false
var _success_started: bool = false

var _bg: ColorRect = null
var _banner: TextureRect = null
var _debrief_panel: PanelContainer = null
var _debrief_label: Label = null


func _level() -> Level:
	return get_parent() as Level


func _ready() -> void:
	layer = 140
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bg)

	_banner = TextureRect.new()
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var debrief_margin := MarginContainer.new()
	debrief_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	debrief_margin.add_theme_constant_override("margin_left", int(vp_size.x * 0.2))
	debrief_margin.add_theme_constant_override("margin_right", int(vp_size.x * 0.2))
	debrief_margin.add_theme_constant_override("margin_top", int(vp_size.y * 0.4))
	debrief_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(debrief_margin)

	_debrief_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_debrief_panel.add_theme_stylebox_override("panel", sb)
	_debrief_panel.visible = false
	debrief_margin.add_child(_debrief_panel)

	_debrief_label = Label.new()
	_debrief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debrief_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debrief_label.add_theme_color_override("font_color", Color.WHITE)
	var font := load("res://font.otf") as Font
	if font:
		_debrief_label.add_theme_font_override("font", font)
	_debrief_panel.add_child(_debrief_label)

	set_process_input(true)


func _process(delta: float) -> void:
	var lvl := _level()
	if lvl == null or lvl.info == null:
		GameState.block_player_input = false
		return

	if lvl.failure and not lvl.success:
		_enter_failure_if_needed()
		_failure_time = maxf(0.0, _failure_time - delta)
		_apply_failure_visuals()
		_layout_banner_failure()
		visible = true
		GameState.block_player_input = _failure_time > 0.0
	elif lvl.success:
		_enter_success_if_needed(lvl)
		_success_time = maxf(0.0, _success_time - delta)
		_debrief_alpha = minf(1.0, _debrief_alpha + delta * DEBRIEF_FADE_RATE)
		_apply_success_visuals(lvl)
		_layout_banner_success()
		visible = true
		GameState.block_player_input = _debrief_alpha < 1.0
	else:
		_reset_outcome_state()
		visible = false
		GameState.block_player_input = false


func _enter_failure_if_needed() -> void:
	if _failure_started:
		return
	_failure_started = true
	_failure_time = FLASH_DURATION
	var path := GameData.get_data_path(GameData.Type.UI_GFX, "ui_mission_failure")
	if path != "":
		_banner.texture = GameData.load_texture(path)


func _enter_success_if_needed(lvl: Level) -> void:
	if _success_started:
		return
	_success_started = true
	_success_time = FLASH_DURATION
	_debrief_alpha = 0.0
	_debrief_label.text = lvl.info.win_desc
	var path := GameData.get_data_path(GameData.Type.UI_GFX, "ui_mission_success")
	if path != "":
		_banner.texture = GameData.load_texture(path)


func _reset_outcome_state() -> void:
	_failure_started = false
	_success_started = false
	_failure_time = 0.0
	_success_time = 0.0
	_debrief_alpha = 0.0
	_debrief_panel.visible = false


func _layout_banner_failure() -> void:
	if _banner.texture == null:
		return
	var sz: Vector2 = _banner.texture.get_size()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -sz.x * 0.5
	_banner.offset_right = sz.x * 0.5
	var y_off := -100.0
	_banner.offset_top = -sz.y * 0.5 + y_off
	_banner.offset_bottom = sz.y * 0.5 + y_off


func _layout_banner_success() -> void:
	if _banner.texture == null:
		return
	var sz: Vector2 = _banner.texture.get_size()
	var h: float = get_viewport().get_visible_rect().size.y
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_left = -sz.x * 0.5
	_banner.offset_right = sz.x * 0.5
	var top := int(h * 0.2)
	_banner.offset_top = top
	_banner.offset_bottom = top + int(sz.y)


func _apply_failure_visuals() -> void:
	_bg.color = Color.BLACK
	# Blitz: SetAlpha(.75 - (failuretime / failureMaxTime))
	_bg.modulate.a = clampf(0.75 - (_failure_time / FLASH_DURATION), 0.0, 1.0)
	_banner.modulate = Color(1, 1, 1, clampf(1.0 - (_failure_time / FLASH_DURATION), 0.0, 1.0))
	_debrief_panel.visible = false


func _apply_success_visuals(lvl: Level) -> void:
	_bg.color = Color(216.0 / 255.0, 198.0 / 255.0, 2.0 / 255.0)
	_bg.modulate.a = clampf(0.75 - (_success_time / FLASH_DURATION), 0.0, 1.0)
	_banner.modulate = Color(1, 1, 1, clampf(1.0 - (_success_time / FLASH_DURATION), 0.0, 1.0))

	_debrief_panel.visible = lvl.info.win_desc.strip_edges() != ""
	_debrief_panel.modulate.a = _debrief_alpha
	_debrief_label.modulate.a = 1.0


func _consume_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	return false


func _input(event: InputEvent) -> void:
	var lvl := _level()
	if lvl == null or not visible:
		return
	if not _consume_dismiss_input(event):
		return

	var vp := get_viewport()
	if vp == null:
		return

	if lvl.failure and not lvl.success:
		if _failure_time > 0.0:
			vp.set_input_as_handled()
			return
		vp.set_input_as_handled()
		lvl.dismiss_mission_outcome()
	elif lvl.success:
		if _debrief_alpha < 1.0:
			vp.set_input_as_handled()
			return
		vp.set_input_as_handled()
		lvl.dismiss_mission_outcome()
