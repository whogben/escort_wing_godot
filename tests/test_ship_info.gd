extends SceneTree
## Headless verification for community-edition .sfo parsing (Phase B2).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_ship_info.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_legacy_two_slot(failures)
	_test_multi_weapon_lists(failures)
	_test_weapon_overrides(failures)
	_test_escort_assault_frequency(failures)
	_test_all_community_ships_load(failures)
	if failures.is_empty():
		print("test_ship_info: all checks passed")
	else:
		for msg in failures:
			push_error("test_ship_info: " + msg)
		quit(1)
		return
	quit()


func _test_legacy_two_slot(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var info := ShipInfo.named("Destroyer")
	if info == null:
		failures.append("Destroyer failed to load")
		return
	if info.primary_name != "Javelin Rocket Array":
		failures.append("Destroyer primary_name expected 'Javelin Rocket Array', got '%s'" % info.primary_name)
	if info.secondary_name != "Flak Rocket Array":
		failures.append("Destroyer secondary_name expected 'Flak Rocket Array', got '%s'" % info.secondary_name)
	if info.primary_weapons.size() != 1 or info.primary_weapons[0].weapon_name != "Javelin Rocket Array":
		failures.append("Destroyer primary_weapons back-compat mismatch")
	if info.secondary_weapons.size() != 1 or info.secondary_weapons[0].weapon_name != "Flak Rocket Array":
		failures.append("Destroyer secondary_weapons back-compat mismatch")


func _test_multi_weapon_lists(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var info := ShipInfo.named("Interceptor")
	if info == null:
		failures.append("Interceptor failed to load")
		return
	if info.primary_weapons.size() != 1 or info.primary_weapons[0].weapon_name != "Gatling Laser":
		failures.append("Interceptor primary weapon list mismatch")
	if info.secondary_weapons.size() != 1 or info.secondary_weapons[0].weapon_name != "Raking Laser":
		failures.append("Interceptor secondary weapon list mismatch")
	if info.automatic_weapons.size() != 0:
		failures.append("Interceptor should have no automatic weapons")

	ShipInfo.ship_infos.clear()
	var big := ShipInfo.named("BIGSHIP")
	if big == null:
		failures.append("BIGSHIP failed to load")
		return
	if big.primary_weapons.size() != 3:
		failures.append("BIGSHIP expected 3 primary weapons, got %d" % big.primary_weapons.size())
	if big.secondary_weapons.size() != 2:
		failures.append("BIGSHIP expected 2 secondary weapons, got %d" % big.secondary_weapons.size())
	if big.automatic_weapons.size() != 4:
		failures.append("BIGSHIP expected 4 automatic weapons, got %d" % big.automatic_weapons.size())


func _test_weapon_overrides(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var big := ShipInfo.named("BIGSHIP")
	if big == null:
		failures.append("BIGSHIP failed to load for override test")
		return
	var first: ShipInfo.WeaponEntry = big.primary_weapons[0]
	if first.overrides.get("perpendicular_offset") != "-18":
		failures.append("BIGSHIP first primary perpendicular_offset expected -18")
	if first.overrides.get("turretSpacing") != "-4":
		failures.append("BIGSHIP first primary turretSpacing expected -4")
	var dup: ShipInfo.WeaponEntry = big.primary_weapons[1]
	if dup.overrides.get("perpendicular_offset") != "18":
		failures.append("BIGSHIP second primary perpendicular_offset expected 18")

	ShipInfo.ship_infos.clear()
	var pf := ShipInfo.named("Pirate Freighter")
	if pf == null:
		failures.append("Pirate Freighter failed to load for override test")
		return
	if pf.automatic_weapons.size() != 6:
		failures.append("Pirate Freighter expected 6 automatic weapons, got %d" % pf.automatic_weapons.size())
	var turret: ShipInfo.WeaponEntry = pf.automatic_weapons[2]
	if turret.overrides.get("forward_offset") != "-30":
		failures.append("Pirate Freighter third turret forward_offset expected -30")


func _test_escort_assault_frequency(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var info := ShipInfo.named("Interceptor")
	if info == null:
		failures.append("Interceptor failed to load for escort/assault test")
		return
	if info.escort_points != 60 or info.assault_points != 30:
		failures.append("Interceptor escort/assault expected 60/30, got %d/%d" % [info.escort_points, info.assault_points])

	# example_mod still uses the old header label; values should parse the same way.
	var mod_path := ProjectSettings.globalize_path("res://").path_join("../example_mod/Ship Infos/Interceptor.sfo")
	if FileAccess.file_exists(mod_path):
		ShipInfo.ship_infos.clear()
		var mod_info := ShipInfo.new()
		mod_info.load_sfo_file(mod_path)
		if mod_info.escort_points != 4 or mod_info.assault_points != 4:
			failures.append("example_mod Interceptor escort/assault expected 4/4, got %d/%d" % [mod_info.escort_points, mod_info.assault_points])


func _test_all_community_ships_load(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	for base_name in GameData.list_ship_info_base_names():
		var info := ShipInfo.named(base_name)
		if info == null:
			failures.append("Failed to load ship info: %s" % base_name)
			continue
		if info.name.is_empty():
			failures.append("Ship %s has empty name after load" % base_name)
