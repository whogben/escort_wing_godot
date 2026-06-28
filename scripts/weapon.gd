extends Node2D
class_name Weapon
## A weapon that can be equipped to a ship.

var weapon_name: String = ""

var power: float = 0.0
var base_range: float = 0.0
var reload_wait: float = 0.0
var reload_timer: float = 0.0

var ship: Ship = null:
	get:
		if is_inside_tree() and get_parent() is Ship:
			return get_parent()
		return null


func _process(delta: float) -> void:
	if reload_timer > 0.0:
		reload_timer -= delta


func get_range() -> float:
	return base_range


func get_spread() -> float:
	return 0.5


func fire() -> void:
	pass


func get_ammo_count() -> int:
	return -1


## Factory method to create weapons by name (data-driven first, legacy fallback).
static func create(type_name: String, overrides: Dictionary = {}) -> Weapon:
	var w_info := WeaponInfo.named(type_name)
	if w_info:
		return DataWeapon.create_from_info(w_info, overrides)
	return _create_legacy(type_name)


static func _create_legacy(type_name: String) -> Weapon:
	var w: Weapon = null
	match type_name:
		"Gatling Laser Turret":
			w = GatlingLaserTurret.new()
		"Super Gatling Laser Turret":
			w = GatlingLaserTurret.new()
			w.reload_wait = 0.1
			w.weapon_name = type_name
		"Gatling Laser":
			w = GatlingLaser.new()
		"Super Gatling Laser":
			w = GatlingLaser.new()
			w.reload_wait = 0.05
			w.weapon_name = type_name
		"Sniper Laser":
			w = GatlingLaser.new()
			w.reload_wait = 10.0
			w.weapon_name = type_name
		"Gatling Pulsar":
			w = GatlingPulsar.new()
		"Flak Rocket Array":
			w = FlakRocketArray.new()
		"Super Flak Rocket Array":
			w = FlakRocketArray.new()
			w.weapon_name = type_name
		"Raking Laser":
			w = RakingLaser.new()
		"Forward Radar":
			w = Radar.new()
			w.setup(62, 0)
			w.weapon_name = type_name
		"Rear Radar":
			w = Radar.new()
			w.setup(-55, 0)
			w.weapon_name = type_name
		"Radar":
			w = Radar.new()
			w.setup(0, 0)
			w.weapon_name = type_name
		"Mine Suicide":
			w = MineSuicide.new()
		_:
			return null
	if w and w.weapon_name == "":
		w.weapon_name = type_name
	return w
