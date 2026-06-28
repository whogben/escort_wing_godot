@tool
extends Node
class_name GameData
## Static methods for accessing game data.


const BUILTIN_DATA_DIR: String = "res://data/original_game"
const MOD_CONFIG_PATH: String = "user://mod.cfg"

## All of the game data directories to search for data files in reverse search order.
static var data_dirs: Array[String] = [BUILTIN_DATA_DIR]

## Absolute path to the active mod data directory, or empty when using built-in data only.
static var mod_dir: String = ""

## Human-readable name of the active mod (folder name), shown in the UI.
static var mod_name: String = ""


## Pass these enums when requesting a data path.
enum Type {
	LEVEL,
	SOUND_FX,
	MUSIC,
	PARTICLE_INFO,
	WEAPON_INFO,
	PROJECTILE_INFO,
	AMBIENT_GFX,
	PARTICLE_GFX,
	SHIP_GFX,
	UI_GFX,
	WEAPON_GFX,
	SHIP_INFO,
}

## Provides info used to map type enums to specific subpaths and file extensions.
static var type_info = {
	Type.LEVEL: {"subdir": "Levels", "ext": "lvl"},
	Type.SOUND_FX: {"subdir": "OGG Sound FX", "ext": "ogg"},
	Type.MUSIC: {"subdir": "OGG Music", "ext": "ogg"},
	Type.WEAPON_INFO: {"subdir": "Weapon Infos", "ext": "wfo"},
	Type.PROJECTILE_INFO: {"subdir": "Projectile Infos", "ext": "pfo"},
	Type.PARTICLE_INFO: {"subdir": "PFX Infos", "ext": "particle"},
	Type.AMBIENT_GFX: {"subdir": "PNG AMB Graphics", "ext": "png"},
	Type.PARTICLE_GFX: {"subdir": "PNG PFX Graphics", "ext": "png"},
	Type.SHIP_GFX: {"subdir": "PNG SHIP Graphics", "ext": "png"},
	Type.UI_GFX: {"subdir": "PNG UI Graphics", "ext": "png"},
	Type.WEAPON_GFX: {"subdir": "PNG WEAP Graphics", "ext": "png"},
	Type.SHIP_INFO: {"subdir": "Ship Infos", "ext": "sfo"},
}

## Loads a texture from a data path (`res://` imported asset or external mod PNG).
static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		return load(path) as Texture2D
	var image := Image.load_from_file(path)
	if image == null:
		push_error("GameData: failed to load texture: " + path)
		return null
	return ImageTexture.create_from_image(image)


## Loads audio from a data path (`res://` imported asset or external mod OGG).
static func load_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			var imported := load(path) as AudioStream
			if imported != null:
				return imported
		var abs_path := ProjectSettings.globalize_path(path)
		if not abs_path.is_empty():
			return AudioStreamOggVorbis.load_from_file(abs_path)
		return null
	var stream := AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		push_error("GameData: failed to load audio: " + path)
		return null
	return stream


## Sets the active mod data directory. Returns false if [param path] is invalid.
## [param display_name] overrides the UI label (defaults to the folder name); web
## imports pass the original folder name since the VFS path is just "active".
static func set_mod_dir(path: String, display_name: String = "") -> bool:
	var normalized := path.strip_edges().trim_suffix("/")
	if not DirAccess.dir_exists_absolute(normalized):
		push_error("Mod directory does not exist: " + normalized)
		return false
	mod_dir = normalized
	mod_name = display_name if not display_name.is_empty() else normalized.get_file()
	data_dirs = [BUILTIN_DATA_DIR, mod_dir]
	_invalidate_caches()
	_save_mod_config()
	return true


## Clears the active mod and reverts to built-in data only.
static func clear_mod() -> void:
	mod_dir = ""
	mod_name = ""
	data_dirs = [BUILTIN_DATA_DIR]
	_invalidate_caches()
	_delete_mod_config()


## Restores the last loaded mod from [member MOD_CONFIG_PATH], if it still exists.
static func load_persisted_mod() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(MOD_CONFIG_PATH) != OK:
		return
	var path: String = str(cfg.get_value("mod", "dir", ""))
	if path.is_empty():
		return
	if not DirAccess.dir_exists_absolute(path):
		push_warning("Saved mod directory no longer exists: " + path)
		clear_mod()
		return
	mod_dir = path
	mod_name = str(cfg.get_value("mod", "name", path.get_file()))
	data_dirs = [BUILTIN_DATA_DIR, mod_dir]


static func _invalidate_caches() -> void:
	ShipInfo.ship_infos.clear()
	ParticleInfo.particle_infos.clear()
	WeaponInfo.weapon_infos.clear()
	ProjectileInfo.projectile_infos.clear()
	SoundSystem.clear_cache()
	MusicSystem.clear_cache()


static func _save_mod_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mod", "dir", mod_dir)
	cfg.set_value("mod", "name", mod_name)
	cfg.save(MOD_CONFIG_PATH)


static func _delete_mod_config() -> void:
	if FileAccess.file_exists(MOD_CONFIG_PATH):
		DirAccess.remove_absolute(MOD_CONFIG_PATH)


## Returns the full path to the data file for the given type and filename.
## Provide the filename without the extension.
static func get_data_path(type: Type, filename: String) -> String:
	var info = type_info.get(type)
	if info == null:
		push_error("Invalid type: " + str(type))
		return ""
	var subpath = info["subdir"] + '/' + filename + '.' + info["ext"]
	return get_path_for_subpath(subpath)

## Returns true if a data file exists at [param path].
## Uses ResourceLoader for imported assets (png, ogg, …) and FileAccess for raw
## mod files (.lvl, .sfo, .particle) that ship as plain text in the export.
static func data_file_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)

## Returns the full path to the last matching subpath in any data dir, or
## an empty string if no match is found.
## Example subpath: "Ship Infos/Flak Interceptor.sfo"
static func get_path_for_subpath(subpath: String) -> String:
	var reversed = Array(data_dirs)
	reversed.reverse()
	for dir in reversed:
		var path = dir + "/" + subpath
		if data_file_exists(path):
			return path
	return ""

## Returns a list of all filenames present across all data dirs in the given subdir.
static func list_data_files(subdir: String) -> Array[String]:
	var files: Array[String] = []
	var seen: Dictionary = {}
	var ordered := Array(data_dirs)
	ordered.reverse()
	for dir in ordered:
		var path = dir + "/" + subdir
		for entry in ResourceLoader.list_directory(path):
			if entry.ends_with("/") or entry.ends_with(".import") or entry.begins_with("."):
				continue
			if not seen.has(entry):
				seen[entry] = true
				files.append(entry)
		if DirAccess.dir_exists_absolute(path):
			for entry in DirAccess.get_files_at(path):
				if entry.ends_with(".import") or entry.begins_with("."):
					continue
				if not seen.has(entry):
					seen[entry] = true
					files.append(entry)
	return files


## Unique ship internal names (`.sfo` stem) found under `Ship Infos/` in any data dir.
## Mods and extra dirs contribute names; `ShipInfo.named` + `get_data_path` resolve the winning file.
static func list_ship_info_base_names() -> Array[String]:
	var subdir: String = type_info[Type.SHIP_INFO]["subdir"]
	var ext: String = "." + type_info[Type.SHIP_INFO]["ext"]
	var seen: Dictionary = {}
	for f in list_data_files(subdir):
		if f.ends_with(ext):
			seen[f.trim_suffix(ext)] = true
	var out: Array[String] = []
	for k in seen.keys():
		out.append(str(k))
	out.sort()
	return out


# These constants should be used in place of string literals for data dir subpaths.
const LEVEL = "Levels"
const SOUND_FX = "OGG Sound FX"
const MUSIC = "OGG Music"
const WEAPON_INFO = "Weapon Infos"
const PROJECTILE_INFO = "Projectile Infos"
const PARTICLE_INFO = "PFX Infos"
const AMBIENT_GFX = "PNG AMB Graphics"
const PARTICLE_GFX = "PNG PFX Graphics"
const SHIP_GFX = "PNG SHIP Graphics"
const UI_GFX = "PNG UI Graphics"
const WEAPON_GFX = "PNG WEAP Graphics"
const SHIP_INFO = "Ship Infos"
