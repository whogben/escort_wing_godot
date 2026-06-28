extends SceneTree
## Headless verification for community-edition .wfo parsing (Phase B4).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_weapon_info.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_gatling_laser(failures)
	_test_raking_laser(failures)
	_test_flak_rocket_array(failures)
	_test_radar(failures)
	_test_mine_suicide(failures)
	_test_turret_specials(failures)
	_test_create_from_info_overrides(failures)
	_test_weapon_create(failures)
	_test_all_weapons_load(failures)
	if failures.is_empty():
		print("test_weapon_info: all checks passed")
	else:
		for msg in failures:
			push_error("test_weapon_info: " + msg)
		quit(1)
		return
	quit()


func _test_gatling_laser(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Gatling Laser")
	if info == null:
		failures.append("Gatling Laser failed to load")
		return
	if info.name != "Gatling Laser" or info.facing != "forwards":
		failures.append("Gatling Laser name/facing mismatch")
	if info.num_turrets != 2 or info.turret_spacing != 30:
		failures.append("Gatling Laser turret config mismatch")
	if info.fire_sequence != "sequential" or info.fire_wait != 0.1:
		failures.append("Gatling Laser fire timing mismatch")
	if info.bullet_name != "Standard Laser Pulse":
		failures.append("Gatling Laser bullet mismatch")
	if info.pfx_name != "gatling_laser_fire" or info.sfx_name != "gatling_laser":
		failures.append("Gatling Laser fx/sfx mismatch")


func _test_raking_laser(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Raking Laser")
	if info == null:
		failures.append("Raking Laser failed to load")
		return
	if not info.is_raking or info.fire_wait != 20.0:
		failures.append("Raking Laser DPS/raking flag mismatch")
	if info.bullet_name != "none":
		failures.append("Raking Laser should have no bullet")
	if not info.has_special("raking laser"):
		failures.append("Raking Laser missing raking laser special")
	var spec := info.get_special("raking laser")
	if spec.value != 250 or spec.r != 255 or spec.g != 55 or spec.b != 0:
		failures.append("Raking Laser special values mismatch")


func _test_flak_rocket_array(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Flak Rocket Array")
	if info == null:
		failures.append("Flak Rocket Array failed to load")
		return
	if info.charges_max != 2 or info.recharge_wait != 7.0:
		failures.append("Flak Rocket Array charges mismatch")
	if info.bullet_name != "Flak Rocket":
		failures.append("Flak Rocket Array bullet mismatch")


func _test_radar(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Radar")
	if info == null:
		failures.append("Radar failed to load")
		return
	if info.turrets_type != "angular array" or info.num_turrets != 21:
		failures.append("Radar turret array mismatch")
	if not info.has_special("radar") or not info.has_special("tracer"):
		failures.append("Radar missing radar/tracer specials")


func _test_mine_suicide(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Mine Suicide")
	if info == null:
		failures.append("Mine Suicide failed to load")
		return
	if info.facing != "none":
		failures.append("Mine Suicide facing should be none")
	if not info.has_special("mine"):
		failures.append("Mine Suicide missing mine special")
	if info.get_special("mine").value != 90:
		failures.append("Mine Suicide range mismatch")


func _test_turret_specials(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Retrofitted Gatling Laser Turret")
	if info == null:
		failures.append("Retrofitted Gatling Laser Turret failed to load")
		return
	if not info.has_special("slow turret"):
		failures.append("Turret missing slow turret special")
	var image_found := false
	for s in info.specials:
		if s.tag == "image:gatling_turret":
			image_found = true
			if s.g != 255 or s.b != 255:
				failures.append("Turret image special color mismatch")
	if not image_found:
		failures.append("Turret missing image:gatling_turret special")


func _test_create_from_info_overrides(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var info := WeaponInfo.named("Gatling Laser Turret")
	if info == null:
		failures.append("Gatling Laser Turret failed to load for override test")
		return
	var overrides := {
		"perpendicular_offset": -18.0,
		"forward_offset": 62.0,
		"angular_offset": -90.0,
		"turretSpacing": 4,
	}
	var w := DataWeapon.create_from_info(info, overrides)
	if w.perpendicular_offset != -18.0:
		failures.append("override perpendicular_offset mismatch")
	if w.forward_offset != 62.0:
		failures.append("override forward_offset mismatch")
	if w.angular_offset != -90.0:
		failures.append("override angular_offset mismatch")
	if w.turret_spacing != 4:
		failures.append("override turretSpacing mismatch")


func _test_weapon_create(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	var w := Weapon.create("Gatling Laser")
	if w == null:
		failures.append("Weapon.create returned null for Gatling Laser")
	elif not w is DataWeapon:
		failures.append("Weapon.create should return DataWeapon when .wfo exists")
	var legacy := Weapon.create("Super Gatling Laser Turret")
	if legacy == null:
		failures.append("Weapon.create legacy fallback returned null")
	elif not legacy is GatlingLaserTurret:
		failures.append("Super Gatling Laser Turret should use legacy GatlingLaserTurret")


func _test_all_weapons_load(failures: Array[String]) -> void:
	WeaponInfo.weapon_infos.clear()
	for f in GameData.list_data_files(GameData.WEAPON_INFO):
		if not f.ends_with(".wfo"):
			continue
		var base := f.get_file().get_basename()
		var info := WeaponInfo.named(base)
		if info == null:
			failures.append("Failed to load weapon info: %s" % base)
			continue
		if info.name.is_empty():
			failures.append("Weapon %s has empty name after load" % base)
