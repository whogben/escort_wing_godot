extends Resource
class_name WeaponInfo

class SpecialEntry:
	var tag: String = ""
	var value: int = 0
	var r: int = 255
	var g: int = 255
	var b: int = 255

@export var name: String = ""
@export var facing: String = "forwards"
@export var angular_offset: float = 0.0
@export var spread: int = 0
@export var forward_offset: float = 0.0
@export var perpendicular_offset: float = 0.0
@export var turrets_type: String = "none"
@export var num_turrets: int = 1
@export var turret_spacing: int = 0
@export var fire_sequence: String = "sequential"
@export var charges_max: int = -1
@export var recharge_wait: float = 0.0
@export var fire_wait: float = 0.1
@export var is_raking: bool = false
@export var bullet_name: String = "none"
@export var pfx_name: String = "nothing"
@export var sfx_name: String = "nothing"
@export var volume: float = 0.05
@export var sound_wait_max: float = 0.0
var specials: Array[SpecialEntry] = []

static var weapon_infos: Dictionary[String, WeaponInfo] = {}


static func named(info_name: String) -> WeaponInfo:
	if weapon_infos.has(info_name):
		return weapon_infos[info_name]
	var path := GameData.get_data_path(GameData.Type.WEAPON_INFO, info_name)
	if path == "":
		return null
	var info := WeaponInfo.new()
	info.load_wfo_file(path)
	weapon_infos[info_name] = info
	return info


func load_wfo_file(path: String) -> WeaponInfo:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open WFO file: " + path)
		return null
	var _hdr := file.get_line()
	name = file.get_line().strip_edges()
	_hdr = file.get_line()
	facing = file.get_line().strip_edges()
	angular_offset = float(file.get_line())
	spread = int(file.get_line())
	_hdr = file.get_line()
	forward_offset = float(file.get_line())
	perpendicular_offset = float(file.get_line())
	_hdr = file.get_line()
	turrets_type = file.get_line().strip_edges()
	num_turrets = int(file.get_line())
	turret_spacing = int(file.get_line())
	_hdr = file.get_line()
	fire_sequence = file.get_line().strip_edges()
	_hdr = file.get_line()
	var charges_raw := int(file.get_line())
	charges_max = 0 if charges_raw == 0 else charges_raw
	if charges_max == 0:
		charges_max = -1
	recharge_wait = float(file.get_line())
	var delay_hdr := file.get_line().strip_edges()
	is_raking = delay_hdr == "DAMAGE PER SECOND"
	fire_wait = float(file.get_line())
	_hdr = file.get_line()
	bullet_name = file.get_line().strip_edges()
	_hdr = file.get_line()
	specials.clear()
	var special_line := file.get_line().strip_edges()
	while special_line != "FIRING PFX - particle":
		if file.eof_reached():
			break
		var entry := SpecialEntry.new()
		entry.tag = special_line
		entry.value = int(file.get_line())
		entry.r = int(file.get_line())
		entry.g = int(file.get_line())
		entry.b = int(file.get_line())
		specials.append(entry)
		special_line = file.get_line().strip_edges()
	pfx_name = file.get_line().strip_edges()
	_hdr = file.get_line()
	sfx_name = file.get_line().strip_edges()
	volume = float(file.get_line())
	sound_wait_max = float(file.get_line())
	file.close()
	return self


func has_special(tag: String) -> bool:
	for s in specials:
		if s.tag == tag:
			return true
	return false


func get_special(tag: String) -> SpecialEntry:
	for s in specials:
		if s.tag == tag:
			return s
	return null
