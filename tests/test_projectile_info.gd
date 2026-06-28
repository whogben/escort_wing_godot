extends SceneTree
## Headless verification for community-edition .pfo parsing (Phase B3).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_projectile_info.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_standard_laser(failures)
	_test_flak_rocket(failures)
	_test_pulsar(failures)
	_test_seeking_laser(failures)
	_test_nothing_projectile(failures)
	_test_create_from_info(failures)
	_test_all_projectiles_load(failures)
	if failures.is_empty():
		print("test_projectile_info: all checks passed")
	else:
		for msg in failures:
			push_error("test_projectile_info: " + msg)
		quit(1)
		return
	quit()


func _test_standard_laser(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var info := ProjectileInfo.named("Standard Laser Pulse")
	if info == null:
		failures.append("Standard Laser Pulse failed to load")
		return
	if info.image != "rect" or info.death_effect != "standard hit":
		failures.append("Standard Laser Pulse image/death_effect mismatch")
	if info.speed != 1000 or info.damage != 3.0 or info.length != 15:
		failures.append("Standard Laser Pulse stats mismatch")
	if info.hit_fx != "gatling_laser_hit" or info.sfx_name != "impact_1":
		failures.append("Standard Laser Pulse fx/sfx mismatch")


func _test_flak_rocket(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var info := ProjectileInfo.named("Flak Rocket")
	if info == null:
		failures.append("Flak Rocket failed to load")
		return
	if info.image != "file:flak_rocket" or info.death_effect != "explosion":
		failures.append("Flak Rocket image/death_effect mismatch")
	if info.length != 40 or info.width != 200.0:
		failures.append("Flak Rocket detonation/explosion size mismatch")
	if info.run_fx != "missile_trail" or info.hit_fx != "shrapnel_explosion":
		failures.append("Flak Rocket pfx mismatch")


func _test_pulsar(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var info := ProjectileInfo.named("Pulsar")
	if info == null:
		failures.append("Pulsar failed to load")
		return
	if info.image != "pulsar" or info.speed != 700:
		failures.append("Pulsar image/speed mismatch")


func _test_seeking_laser(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var info := ProjectileInfo.named("Seeking Laser Pulse")
	if info == null:
		failures.append("Seeking Laser Pulse failed to load")
		return
	if info.seeking_speed != 130 or info.max_lifetime != 2.0:
		failures.append("Seeking Laser Pulse seeking/lifetime mismatch")


func _test_nothing_projectile(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var info := ProjectileInfo.named("Nothing")
	if info == null:
		failures.append("Nothing failed to load")
		return
	if info.image != "nothing" or info.death_effect != "none":
		failures.append("Nothing image/death_effect mismatch")
	var proj := Projectile.create_from_info("Nothing", 1, Vector2.ZERO, 0.0)
	if proj == null:
		failures.append("Nothing create_from_info returned null")
	elif not proj is DataProjectile:
		failures.append("Nothing should spawn as DataProjectile")
	elif (proj as DataProjectile).death_effect != "none":
		failures.append("Nothing DataProjectile death_effect mismatch")


func _test_create_from_info(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	var proj := Projectile.create_from_info(
		"Standard Laser Pulse",
		1,
		Vector2(100, 200),
		0.0,
		Vector2(50, 0)
	)
	if proj == null:
		failures.append("Projectile.create_from_info returned null")
		return
	if not proj is DataProjectile:
		failures.append("Projectile.create_from_info should return DataProjectile for known .pfo")
	if proj.team != 1:
		failures.append("create_from_info team mismatch")
	if abs(proj.position.x - 100.0) > 0.01 or abs(proj.position.y - 200.0) > 0.01:
		failures.append("create_from_info position mismatch")
	if abs(proj.velocity.x - 1050.0) > 0.01:
		failures.append("create_from_info velocity expected ~1050 on x, got %s" % str(proj.velocity))


func _test_all_projectiles_load(failures: Array[String]) -> void:
	ProjectileInfo.projectile_infos.clear()
	for f in GameData.list_data_files(GameData.PROJECTILE_INFO):
		if not f.ends_with(".pfo"):
			continue
		var base := f.get_file().get_basename()
		var info := ProjectileInfo.named(base)
		if info == null:
			failures.append("Failed to load projectile info: %s" % base)
			continue
		if info.name.is_empty():
			failures.append("Projectile %s has empty name after load" % base)
