extends Resource
class_name ShipInfo
## Stores the details that make different ships different.

class WeaponEntry:
	var weapon_name: String = ""
	var overrides: Dictionary = {}

const drag = 0.1
const rotdrag = -5.0

@export var name = ""

@export var img_name = ""
@export var has_engine_graphic = false

@export var r = 255
@export var g = 255
@export var b = 255

@export var radius = 64
@export var mass = 1000

@export var min_speed = 10
@export var max_speed = 100
@export var acceleration = 20

@export var max_rot_speed = 30
@export var rot_acceleration = 5

@export var max_health = 500

@export var primary_name = ""
@export var secondary_name = ""

var primary_weapons: Array[WeaponEntry] = []
var secondary_weapons: Array[WeaponEntry] = []
var automatic_weapons: Array[WeaponEntry] = []

@export var playable = false
@export var team = 0
@export var escort_points = 0
@export var assault_points = 0

@export var smoke_health = 200
@export var fire_health = 80
@export var smoke_fx = ""
@export var fire_fx = ""
@export var death_fx = ""
@export var explosion_sound = ""


static var ship_infos: Dictionary[String, ShipInfo] = {}


static func named(info_name: String) -> ShipInfo:
	if ship_infos.has(info_name):
		return ship_infos[info_name]
	var path = GameData.get_data_path(GameData.Type.SHIP_INFO, info_name)
	if path == "":
		return null
	var ship_info = ShipInfo.new()
	ship_info.load_sfo_file(path)
	ship_infos[info_name] = ship_info
	return ship_info


func load_sfo_file(path: String) -> ShipInfo:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open SFO file: " + path)
		return null
	var _nothing = file.get_line()
	name = file.get_line().strip_edges()
	img_name = file.get_line().strip_edges()
	_nothing = file.get_line()
	r = int(file.get_line())
	g = int(file.get_line())
	b = int(file.get_line())
	_nothing = file.get_line()
	radius = int(file.get_line())
	mass = int(file.get_line())
	_nothing = file.get_line()
	min_speed = int(file.get_line())
	max_speed = int(file.get_line())
	acceleration = int(file.get_line())
	_nothing = file.get_line()
	max_rot_speed = int(file.get_line())
	rot_acceleration = int(file.get_line())
	_nothing = file.get_line()
	max_health = int(file.get_line())
	_read_weapon_section(file)
	_nothing = file.get_line()
	smoke_health = int(file.get_line())
	fire_health = int(file.get_line())
	_nothing = file.get_line()
	smoke_fx = file.get_line().strip_edges()
	fire_fx = file.get_line().strip_edges()
	death_fx = file.get_line().strip_edges()
	_nothing = file.get_line()
	explosion_sound = file.get_line().strip_edges()
	_nothing = file.get_line()
	team = int(file.get_line())
	_nothing = file.get_line()
	playable = int(file.get_line()) != 0
	_nothing = file.get_line()
	escort_points = int(file.get_line())
	assault_points = int(file.get_line())
	file.close()
	if primary_name.is_empty() and primary_weapons.size() > 0:
		primary_name = primary_weapons[0].weapon_name
	if secondary_name.is_empty() and secondary_weapons.size() > 0:
		secondary_name = secondary_weapons[0].weapon_name
	var engine_path = GameData.get_data_path(GameData.Type.SHIP_GFX, img_name + "_engine")
	has_engine_graphic = engine_path != ""
	ship_infos[name] = self
	return self


func _read_weapon_section(file: FileAccess) -> void:
	var slot := ""
	var pending: WeaponEntry = null
	while not file.eof_reached():
		var pos := file.get_position()
		var line := file.get_line().strip_edges()
		if line == "DEATH EFFECT HEALTHS - smoking health / burning health":
			file.seek(pos)
			break
		if line == "WEAPONS - primary weapon name / secondary weapon name":
			primary_name = file.get_line().strip_edges()
			secondary_name = file.get_line().strip_edges()
			var pe := WeaponEntry.new()
			pe.weapon_name = primary_name
			primary_weapons.append(pe)
			var se := WeaponEntry.new()
			se.weapon_name = secondary_name
			secondary_weapons.append(se)
			continue
		if line == "PRIMARY WEAPONS":
			slot = "primary"
			continue
		if line == "SECONDARY WEAPONS":
			slot = "secondary"
			continue
		if line == "AUTOMATIC WEAPONS":
			slot = "automatic"
			continue
		if line.begins_with("+"):
			if pending:
				_apply_override_line(pending, line)
			continue
		if line.is_empty():
			continue
		pending = WeaponEntry.new()
		pending.weapon_name = line
		match slot:
			"primary":
				primary_weapons.append(pending)
			"secondary":
				secondary_weapons.append(pending)
			"automatic":
				automatic_weapons.append(pending)


static func _apply_override_line(entry: WeaponEntry, line: String) -> void:
	var body := line.substr(1)
	var eq := body.find("=")
	if eq == -1:
		return
	var key := body.substr(0, eq)
	var val := body.substr(eq + 1)
	entry.overrides[key] = val
