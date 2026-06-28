extends Resource
class_name ProjectileInfo

@export var name: String = ""
@export var image: String = "rect"
@export var cr: int = 255
@export var cg: int = 255
@export var cb: int = 0
@export var speed: int = 1000
@export var seeking_speed: int = 0
@export var damage: float = 1.0
@export var impulse: float = 0.0
@export var length: int = 15
@export var width: float = 1.2
@export var max_lifetime: float = 0.4
@export var death_effect: String = "standard hit"
@export var run_fx: String = "nothing"
@export var hit_fx: String = "nothing"
@export var sfx_name: String = "nothing"
@export var volume: float = 0.1

static var projectile_infos: Dictionary[String, ProjectileInfo] = {}


static func named(info_name: String) -> ProjectileInfo:
	if projectile_infos.has(info_name):
		return projectile_infos[info_name]
	var path := GameData.get_data_path(GameData.Type.PROJECTILE_INFO, info_name)
	if path == "":
		return null
	var info := ProjectileInfo.new()
	info.load_pfo_file(path)
	projectile_infos[info_name] = info
	return info


func load_pfo_file(path: String) -> ProjectileInfo:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open PFO file: " + path)
		return null
	var _hdr := file.get_line()
	name = file.get_line().strip_edges()
	image = file.get_line().strip_edges()
	_hdr = file.get_line()
	cr = int(file.get_line())
	cg = int(file.get_line())
	cb = int(file.get_line())
	_hdr = file.get_line()
	speed = int(file.get_line())
	seeking_speed = int(file.get_line())
	_hdr = file.get_line()
	damage = float(file.get_line())
	impulse = float(file.get_line())
	_hdr = file.get_line()
	length = int(file.get_line())
	width = float(file.get_line())
	_hdr = file.get_line()
	max_lifetime = float(file.get_line())
	_hdr = file.get_line()
	death_effect = file.get_line().strip_edges()
	_hdr = file.get_line()
	run_fx = file.get_line().strip_edges()
	hit_fx = file.get_line().strip_edges()
	_hdr = file.get_line()
	sfx_name = file.get_line().strip_edges()
	volume = float(file.get_line())
	file.close()
	return self
