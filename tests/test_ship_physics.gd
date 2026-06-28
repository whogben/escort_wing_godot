extends SceneTree
## Headless verification for air vs truespace ship physics (Phase B7).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_ship_physics.gd


func _init() -> void:
	var failures: Array[String] = []
	_test_air_physics(failures)
	_test_truespace_physics(failures)
	_test_forward_speed_helpers(failures)
	if failures.is_empty():
		print("test_ship_physics: all checks passed")
	else:
		for msg in failures:
			push_error("test_ship_physics: " + msg)
		quit(1)
		return
	quit()


func _make_ship() -> Ship:
	var info := ShipInfo.named("Interceptor")
	if info == null:
		return null
	var ship := Ship.new()
	ship.info = info
	return ship


func _test_air_physics(failures: Array[String]) -> void:
	GameState.level_medium = "air"
	var ship := _make_ship()
	if ship == null:
		failures.append("Interceptor ship info not found")
		return
	ship.rotation = 0.0
	ship.speed = 100.0
	ship.speed_intent = 1.0
	var start_pos := ship.position
	ship._fly(0.5)
	if ship.position.x <= start_pos.x:
		failures.append("air _fly should move along forward axis")
	if ship.speed <= 100.0:
		failures.append("air accelerate should increase speed")
	ship.vx = 50.0
	var before_drag := ship.vx
	ship._blast(0.5)
	if ship.vx >= before_drag:
		failures.append("air _blast should apply drag to blast velocity")


func _test_truespace_physics(failures: Array[String]) -> void:
	GameState.level_medium = "truespace"
	var ship := _make_ship()
	if ship == null:
		failures.append("Interceptor ship info not found for truespace")
		return
	ship.rotation = 0.0
	ship.speed_intent = 1.0
	var start_pos := ship.position
	ship._fly(0.2)
	if ship.vx <= 0.0:
		failures.append("truespace accelerate should increase vx")
	if ship.position != start_pos:
		failures.append("truespace _fly should not move position directly")
	var pos_before_blast := ship.position
	ship._blast(0.2)
	if ship.position.x <= pos_before_blast.x:
		failures.append("truespace _blast should move by velocity without drag")
	var vx_before := ship.vx
	ship._blast(0.2)
	if not is_equal_approx(ship.vx, vx_before):
		failures.append("truespace _blast should not damp velocity")


func _test_forward_speed_helpers(failures: Array[String]) -> void:
	GameState.level_medium = "truespace"
	var ship := _make_ship()
	if ship == null:
		failures.append("Interceptor ship info not found for forward_speed")
		return
	ship.rotation = 0.0
	ship.vx = 120.0
	ship.vy = 40.0
	if not is_equal_approx(ship.forward_speed(), 120.0):
		failures.append("forward_speed should project velocity onto nose")
	ship.set_forward_speed(200.0)
	if not is_equal_approx(ship.forward_speed(), 200.0):
		failures.append("set_forward_speed should set forward component")
	if not is_equal_approx(ship.vy, 40.0):
		failures.append("set_forward_speed should preserve lateral velocity")
