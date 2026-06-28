extends SceneTree
## Headless verification for Phase B8 content and gameplay parity hooks.
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_b8_content.gd


const COMMUNITY_PARTICLES: Array[String] = [
	"firebomb",
	"freighter_explosion",
	"white_smoke_puff",
	"fire_explosion",
	"med_firebursts",
	"blue_debris_ring",
	"brief_large_smoke_puff",
]

const CAMPAIGN_LEVELS: Array[String] = [
	"0) Tutorial",
	"1) Homeward Bound",
	"2) Eyes and Ears",
	"3) Bramble's Choice",
	"Random",
]


func _init() -> void:
	var failures: Array[String] = []
	_test_community_ships_and_sprites(failures)
	_test_community_particles(failures)
	_test_campaign_levels(failures)
	_test_health_regen_formula(failures)
	_test_damage_fx_fields(failures)
	if failures.is_empty():
		print("test_b8_content: all checks passed")
	else:
		for msg in failures:
			push_error("test_b8_content: " + msg)
		quit(1)
		return
	quit()


func _test_community_ships_and_sprites(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var names := GameData.list_ship_info_base_names()
	if names.size() != 21:
		failures.append("Expected 21 community ships, found %d" % names.size())
	for base_name in names:
		var info := ShipInfo.named(base_name)
		if info == null:
			failures.append("Failed to load ship: %s" % base_name)
			continue
		var gfx_path := GameData.get_data_path(GameData.Type.SHIP_GFX, info.img_name)
		if gfx_path == "" or not FileAccess.file_exists(gfx_path):
			failures.append("Missing ship sprite for %s: %s" % [base_name, info.img_name])
		if info.has_engine_graphic:
			var engine_path := GameData.get_data_path(GameData.Type.SHIP_GFX, info.img_name + "_engine")
			if engine_path == "" or not FileAccess.file_exists(engine_path):
				failures.append("Missing engine sprite for %s" % base_name)


func _test_community_particles(failures: Array[String]) -> void:
	ParticleInfo.particle_infos.clear()
	for p_name in COMMUNITY_PARTICLES:
		var info := ParticleInfo.named(p_name)
		if info == null:
			failures.append("Missing community particle: %s" % p_name)


func _test_campaign_levels(failures: Array[String]) -> void:
	for level_name in CAMPAIGN_LEVELS:
		var path := GameData.get_data_path(GameData.Type.LEVEL, level_name)
		if path == "":
			failures.append("Missing level: %s" % level_name)
			continue
		var info := LevelInfo.load_level(path)
		if info == null:
			failures.append("Failed to parse level: %s" % level_name)


func _test_health_regen_formula(failures: Array[String]) -> void:
	var info := ShipInfo.named("Interceptor")
	if info == null:
		failures.append("Interceptor not found for regen test")
		return
	var rate := sqrt(float(info.max_health)) / 15.0
	if rate <= 0.0:
		failures.append("Health regen rate should be positive")


func _test_damage_fx_fields(failures: Array[String]) -> void:
	ShipInfo.ship_infos.clear()
	var freighter := ShipInfo.named("Freighter")
	if freighter == null:
		failures.append("Freighter not found for damage FX test")
		return
	if freighter.smoke_fx.is_empty() or freighter.fire_fx.is_empty():
		failures.append("Freighter should define smoke_fx and fire_fx")
	if freighter.smoke_health <= freighter.fire_health:
		failures.append("Freighter smoke_health should exceed fire_health")
