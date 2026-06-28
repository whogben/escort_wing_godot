extends SceneTree
## Headless verification for .particle parsing (modern header format).
## Run: Godot --headless --path escort_wing_godot -s res://tests/test_particle_info.gd


func _init() -> void:
	var failures: Array[String] = []

	ParticleInfo.particle_infos.clear()

	var collection := ParticleInfo.named("gatling_laser_fire")
	if collection == null:
		failures.append("gatling_laser_fire not found")
	elif not collection.is_collection:
		failures.append("gatling_laser_fire should be a collection")
	elif collection.collected_pfx.size() != 2:
		failures.append("gatling_laser_fire should collect 2 sub-effects")

	var sparks := ParticleInfo.named("gatling_laser_fire_sparks")
	if sparks == null:
		failures.append("gatling_laser_fire_sparks not found")
	elif sparks.render_mode != 1:
		failures.append("gatling_laser_fire_sparks render_mode expected 1, got %d" % sparks.render_mode)
	elif sparks.burst_min_particles < 1 or sparks.burst_max_particles < 1:
		failures.append("gatling_laser_fire_sparks burst counts should be positive")

	var shrapnel := ParticleInfo.named("shrapnel_explosion")
	if shrapnel == null:
		failures.append("shrapnel_explosion not found")
	elif not shrapnel.is_collection:
		failures.append("shrapnel_explosion should be a collection")
	elif shrapnel.collected_pfx != ["shrapnel_smoke", "shrapnel_ring"]:
		failures.append("shrapnel_explosion sub-effects mismatch: %s" % str(shrapnel.collected_pfx))

	var ring := ParticleInfo.named("shrapnel_ring")
	if ring == null:
		failures.append("shrapnel_ring not found")
	elif ring.low_r != 255 or ring.low_g != 255 or ring.low_b != 255:
		failures.append("shrapnel_ring should start white")
	elif ring.burst_min_particles != 50 or ring.burst_max_particles != 40:
		failures.append(
			"shrapnel_ring burst counts expected 50/40, got %d/%d"
			% [ring.burst_min_particles, ring.burst_max_particles]
		)

	if failures.is_empty():
		print("test_particle_info: all checks passed")
	else:
		for f in failures:
			push_error(f)
		quit(1)
		return

	quit()
