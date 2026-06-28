class_name LevelInfo
extends RefCounted

## Data container for Level information loaded from .lvl files.

var name: String = ""
var desc: String = ""
var win_desc: String = ""
var background: String = ""
var ground_cloud_cover: int = 0
var air_cloud_cover: int = 0
var success_time: int = 0 # in seconds

## Custom ocean tint from `LEVEL RGB:` (0–1 floats).
var bg_r: float = 1.0
var bg_g: float = 1.0
var bg_b: float = 1.0
var custom_rgb: bool = false
## When true, pick a random tint at level start ( `<RANDOMIZE LEVEL BACKGROUND RGB>` ).
var randomize_background_rgb: bool = false
## Physics medium from `LEVEL MEDIUM:` (`air` or `truespace`; default `air`).
var medium: String = "air"

var player_ship: String = ""
## Random / procedural missions: allies (player, convoy, escorts, end ships) fight as this faction.
## 0 = use each ship's `.sfo` team (campaign levels).
var player_team: int = 0
var convoy_heading: int = 0

# Lists of ShipSpawn objects
var convoy_ships: Array[ShipSpawn] = []
var escort_ships: Array[ShipSpawn] = []
var convoy_survivors: Array[ShipSpawn] = []
var start_ships: Array[ShipSpawn] = []
var end_ships: Array[ShipSpawn] = []

# List of Event objects
var events: Array[Event] = []

# --- Inner Classes / Data Structures ---

class ShipSpawn:
	var ship_info_name: String
	## Matches BlitzMax `shipSpawn.shipteam`: the third argument to `readAndCreateShips`
	## (0 for convoy / escort / start / end lists; wave ships use the group’s team).
	var team: int
	
	func _init(p_name: String, p_team: int):
		ship_info_name = p_name
		team = p_team

class GroupSpawn:
	var team: int # 0=escort, 1=enemy, -1=retire
	var angle: int
	var ships: Array = [] # Can't strict type as Array[ShipSpawn] due to recursion/circular ref issues in GDScript sometimes, or just untyped init


class RadioMessageData:
	# Data container for radio messages
	var sender: String
	var message: String

class MusicChangeData:
	var track_name: String = ""

class BackgroundColorChangeData:
	var random: bool = false
	var r: float = 1.0
	var g: float = 1.0
	var b: float = 1.0
	var fade_time: float = 0.0

class TimerCondition:
	var event_time: int = 0

class Event:
	var event_time: int = 0 ## Legacy field; mirrors first timer condition when present.
	var conditions: Array = [] ## TimerCondition entries (community `EVENT:` format).
	var actions: Array = [] ## Can contain RadioMessageData, GroupSpawn, MusicChangeData, BackgroundColorChangeData.

# --- Loading Logic ---

static func load_level(path: String) -> LevelInfo:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open Level file: " + path)
		return null
	
	var level = LevelInfo.new()
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
			
		if line == "LEVEL NAME:":
			level.name = file.get_line().strip_edges()
		elif line == "LEVEL DESC:":
			level.desc = file.get_line().strip_edges()
			level.desc = _replace_radio_tags(level.desc)
		elif line == "LEVEL WIN DESC:":
			level.win_desc = file.get_line().strip_edges()
			level.win_desc = _replace_radio_tags(level.win_desc)
		elif line == "LEVEL BACKGROUND:":
			level.background = file.get_line().strip_edges()
		elif line == "LEVEL RGB:":
			level.bg_r = float(file.get_line())
			level.bg_g = float(file.get_line())
			level.bg_b = float(file.get_line())
			level.custom_rgb = true
		elif line == "<RANDOMIZE LEVEL BACKGROUND RGB>":
			level.randomize_background_rgb = true
		elif line == "LEVEL MEDIUM:":
			level.medium = file.get_line().strip_edges()
		elif line == "LEVEL GROUND CLOUD COVER:":
			level.ground_cloud_cover = int(file.get_line())
		elif line == "LEVEL AIR CLOUD COVER:":
			level.air_cloud_cover = int(file.get_line())
		elif line == "LEVEL SUCCESS MINUTES AND SECONDS:":
			var m = int(file.get_line())
			var s = int(file.get_line())
			level.success_time = m * 60 + s
		elif line == "PLAYER SHIP:":
			level.player_ship = file.get_line().strip_edges()
		elif line == "CONVOY HEADING DEGREES:":
			level.convoy_heading = int(file.get_line())
		elif line == "LEVEL CONVOY SHIPS:":
			_read_and_create_ships(file, level.convoy_ships, 0)
		elif line == "CONVOY ESCORT SHIPS:":
			_read_and_create_ships(file, level.escort_ships, 0)
		elif line == "CONVOY SHIPS MUST SURVIVE:":
			_read_and_create_ships(file, level.convoy_survivors, 0)
		elif line == "LEVEL START SHIPS:":
			_read_and_create_ships(file, level.start_ships, 0)
		elif line == "LEVEL END SHIPS:":
			_read_and_create_ships(file, level.end_ships, 0)
		elif line == "EVENT MINUTES AND SECONDS:":
			_read_legacy_event(file, level.events)
		elif line == "EVENT:":
			_read_conditional_event(file, level.events)

	return level

static func _read_and_create_ships(file: FileAccess, list: Array, team: int):
	var line = file.get_line().strip_edges()
	while line != "}":
		if file.eof_reached():
			break
			
		line = file.get_line().strip_edges()
		if line == "}":
			break
			
		var count = int(line)
		var ship_name = file.get_line().strip_edges()
		
		for i in range(count):
			list.append(ShipSpawn.new(ship_name, team))

static func _add_timer_condition(event: Event, event_time: int) -> void:
	event.event_time = event_time
	var timer := TimerCondition.new()
	timer.event_time = event_time
	event.conditions.append(timer)

static func _read_legacy_event(file: FileAccess, list: Array):
	var m = int(file.get_line())
	var s = int(file.get_line())
	
	var event = Event.new()
	_add_timer_condition(event, m * 60 + s)
	
	var line = file.get_line().strip_edges()
	while line != "}":
		if file.eof_reached():
			break
		_parse_event_action(file, line, event)
		line = file.get_line().strip_edges()
		
	list.append(event)

static func _read_conditional_event(file: FileAccess, list: Array):
	var event = Event.new()
	var line = file.get_line().strip_edges()
	while line != "{":
		if file.eof_reached():
			return
		if line == "MINUTES AND SECONDS:":
			var m = int(file.get_line())
			var s = int(file.get_line())
			_add_timer_condition(event, m * 60 + s)
		line = file.get_line().strip_edges()
	
	line = file.get_line().strip_edges()
	while line != "}":
		if file.eof_reached():
			break
		_parse_event_action(file, line, event)
		line = file.get_line().strip_edges()
	
	list.append(event)

static func _parse_event_action(file: FileAccess, line: String, event: Event) -> void:
	if line == "RADIO SENDER:":
		var msg = RadioMessageData.new()
		msg.sender = file.get_line().strip_edges()
		
		while line != "RADIO MESSAGE:" and not file.eof_reached():
			line = file.get_line().strip_edges()
			
		msg.message = file.get_line().strip_edges()
		msg.message = _replace_radio_tags(msg.message)
		event.actions.append(msg)

	elif line == "SET MUSIC:":
		var music := MusicChangeData.new()
		music.track_name = file.get_line().strip_edges()
		event.actions.append(music)

	elif line == "FADE BACKGROUND RGB:":
		var bg := BackgroundColorChangeData.new()
		bg.r = float(file.get_line())
		bg.g = float(file.get_line())
		bg.b = float(file.get_line())
		while line != "OVER TIME:" and not file.eof_reached():
			line = file.get_line().strip_edges()
		bg.fade_time = float(file.get_line())
		event.actions.append(bg)

	elif line == "RANDOM BACKGROUND RGB:":
		var bg := BackgroundColorChangeData.new()
		bg.random = true
		while line != "OVER TIME:" and not file.eof_reached():
			line = file.get_line().strip_edges()
		bg.fade_time = float(file.get_line())
		event.actions.append(bg)
		
	elif line == "SPAWN ENEMY SHIPS:":
		var group = GroupSpawn.new()
		group.team = 1
		group.ships = []
		_read_and_create_ships(file, group.ships, 1)
		
		while line != "SPAWN ANGLE:" and not file.eof_reached():
			line = file.get_line().strip_edges()
		
		group.angle = int(file.get_line())
		event.actions.append(group)

	elif line == "SPAWN ESCORT SHIPS:":
		var group = GroupSpawn.new()
		group.team = 0
		group.ships = []
		_read_and_create_ships(file, group.ships, 0)
		
		while line != "SPAWN ANGLE:" and not file.eof_reached():
			line = file.get_line().strip_edges()
		
		group.angle = int(file.get_line())
		event.actions.append(group)
		
	elif line == "RETIRE ESCORT SHIPS:":
		var group = GroupSpawn.new()
		group.team = -1
		group.ships = []
		_read_and_create_ships(file, group.ships, -1)
		
		while line != "SPAWN ANGLE:" and line != "ANGLE:" and not file.eof_reached():
			line = file.get_line().strip_edges()
		
		group.angle = int(file.get_line())
		event.actions.append(group)

static func event_conditions_met(event: Event, elapsed_seconds: int) -> bool:
	if event.conditions.is_empty():
		return event.event_time <= elapsed_seconds
	for cond in event.conditions:
		if cond is TimerCondition and (cond as TimerCondition).event_time > elapsed_seconds:
			return false
	return true

static func _replace_radio_tags(text: String) -> String:
	var player_name := ProgressManager.pilot_name
	if player_name.is_empty():
		player_name = "Pilot"
	var fire1 := _input_action_display("fire_primary")
	var fire2 := _input_action_display("fire_secondary")
	text = text.replace("%N", player_name)
	text = text.replace("%KEY-FIRE1", fire1)
	text = text.replace("%KEY-FIRE2", fire2)
	return text


static func _input_action_display(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	var input_events := InputMap.action_get_events(action)
	for ev in input_events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			return OS.get_keycode_string(k.physical_keycode)
	return input_events[0].as_text() if input_events.size() > 0 else action
