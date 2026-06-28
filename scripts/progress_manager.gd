extends Node
class_name ProgressManager

const MISSION_PATH := "user://player_settings.cfg"
const SCORES_PATH := "user://scores.cfg"
const PREFS_PATH := "user://preferences.cfg"

const INPUT_ACTIONS: Array[String] = [
	"turn_left",
	"turn_right",
	"throttle_up",
	"throttle_down",
	"fire_primary",
	"fire_secondary",
]

const WINDOW_SIZE := Vector2i(1024, 768)

const PILOT_NAME_MAX_CHARS := 16

static var max_mission: int = 1
static var mission_scores: Dictionary = {}
static var pilot_name: String = ""
static var windowed: bool = true
static var prefs_exist: bool = false


static func load_all() -> void:
	prefs_exist = FileAccess.file_exists(PREFS_PATH)
	var misn := ConfigFile.new()
	if misn.load(MISSION_PATH) == OK:
		max_mission = int(misn.get_value("progress", "max_mission", 1))
	else:
		max_mission = 1
		save_max_mission(1)

	var prefs := ConfigFile.new()
	if prefs.load(PREFS_PATH) == OK:
		pilot_name = str(prefs.get_value("player", "name", ""))
		windowed = true
		_load_input_bindings(prefs)
	else:
		pilot_name = ""
		windowed = true

	var scores := ConfigFile.new()
	if scores.load(SCORES_PATH) == OK:
		mission_scores.clear()
		for key in scores.get_section_keys("scores"):
			mission_scores[key] = int(scores.get_value("scores", key, 0))


static func needs_first_run_setup() -> bool:
	return not prefs_exist or pilot_name.is_empty()


static func save_max_mission(mission_index: int) -> void:
	max_mission = maxi(mission_index, 1)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "max_mission", max_mission)
	cfg.save(MISSION_PATH)


static func save_score(level_name: String, percent: int) -> void:
	var prev: int = int(mission_scores.get(level_name, 0))
	if percent <= prev:
		return
	mission_scores[level_name] = percent
	var cfg := ConfigFile.new()
	cfg.load(SCORES_PATH)
	for key in mission_scores:
		cfg.set_value("scores", str(key), mission_scores[key])
	cfg.save(SCORES_PATH)


static func get_score(level_name: String) -> int:
	return int(mission_scores.get(level_name, 0))


static func record_mission_result(mission_index: int, level_name: String, survival_percent: int, campaign_count: int) -> void:
	if mission_index < 0:
		return
	save_score(level_name, survival_percent)
	if survival_percent <= 0:
		return
	if mission_index != max_mission:
		return
	var max_possible := maxi(campaign_count - 1, 0)
	if max_mission < max_possible:
		save_max_mission(max_mission + 1)


static func save_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value("player", "name", pilot_name)
	cfg.set_value("display", "windowed", windowed)
	_save_input_bindings(cfg)
	cfg.save(PREFS_PATH)
	prefs_exist = true


static func save_pilot_name(pilot: String) -> void:
	pilot_name = pilot.strip_edges()
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value("player", "name", pilot_name)
	cfg.save(PREFS_PATH)
	prefs_exist = true


static func apply_display_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(WINDOW_SIZE)


static func input_action_label(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return action


static func rebind_action(action: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = event.physical_keycode
	key_event.keycode = event.keycode
	InputMap.action_add_event(action, key_event)


static func _load_input_bindings(prefs: ConfigFile) -> void:
	for action in INPUT_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var keycode := int(prefs.get_value("input", action, 0))
		if keycode == 0:
			continue
		InputMap.action_erase_events(action)
		var key_event := InputEventKey.new()
		key_event.physical_keycode = keycode as Key
		InputMap.action_add_event(action, key_event)


static func _save_input_bindings(cfg: ConfigFile) -> void:
	for action in INPUT_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				cfg.set_value("input", action, (ev as InputEventKey).physical_keycode)
				break
