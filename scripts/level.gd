class_name Level
extends Node2D

const _BEHAVIOR_CONVOY = preload("res://scripts/controllers/behaviors/behavior_convoy.gd")

## Main level management class. Handles spawning, events, and game flow.

@export var level_name: String = "0) Tutorial"

var info: LevelInfo = null

# State
var time_elapsed: float = 0.0
var failure: bool = false
var success: bool = false
var eta: float = 0.0
## Live convoy count / ships defined in the .lvl (BlitzMax `survivalPercentage`).
var survival_percentage: float = 100.0
var _initial_convoy_spawns: int = 0

# Ship Lists
var convoy_ships: Array[Ship] = []
var escort_ships: Array[Ship] = []
var start_ships: Array[Ship] = []
var end_ships: Array[Ship] = []
var attacking_ships: Array[Ship] = []

# Internal tracking for events
var events_to_process: Array[LevelInfo.Event] = []

## Short-lived radar blips. Dict: world_pos, color, time_left.
## BlitzMax only adds these at mission start (convoy pos), enemy spawn, and escort reinforcements — not on every convoy move.
var map_radar_events: Array[Dictionary] = []
const MAP_RADAR_EVENT_LIFETIME: float = 6.0

## True until the player dismisses the mission briefing overlay.
var briefing_active: bool = true

# Constants
const DANGER_RANGE = 6500.0
const END_GAME_RANGE = 8000.0
const ENEMY_SPAWN_RANGE = 5000.0
const RADAR_RANGE = 2500.0
const END_SHIP_SPAWN_DIST = 4000.0
const END_SHIP_SPAWN_TIME = 40.0 # seconds remaining

## Seconds after the player dies before `failure` is set (explosion / death FX visible).
const PLAYER_DEATH_FAILURE_DELAY: float = 3.0

## Negative = not counting down; otherwise seconds remaining until player-death failure.
var _player_death_failure_countdown: float = -1.0

var convoy_center: Vector2 = Vector2.ZERO
var player: Ship = null
var ui: InGameUI = null
var radio_ui: RadioUI = null
var _pause_overlay: CanvasLayer = null
var _ocean: Ocean = null

## Background RGB crossfade state (matches BlitzMax `updateBGcolor`).
var _bg_fade_from: Color = Color.WHITE
var _bg_fade_to: Color = Color.WHITE
var _bg_fade_duration: float = 0.0
var _bg_fade_elapsed: float = 0.0
var _bg_fade_active: bool = false

## Fullscreen white fade at mission start (matches BlitzMax Level.bmx fadeInAlpha).
var _fade_from_white: ColorRect = null
var fade_in_alpha: float = 1.0
const FADE_IN_ALPHA_RATE: float = 0.3

func _ready():
	Engine.time_scale = 1.0
	info = RunState.pending_level_info
	if info != null:
		RunState.pending_level_info = null
		level_name = "Random"
	else:
		if RunState.pending_level_name != "":
			level_name = RunState.pending_level_name
			RunState.pending_level_name = ""

		var path = GameData.get_data_path(GameData.Type.LEVEL, level_name)
		if path == "":
			push_error("Level path not found for: " + level_name)
			return

		info = LevelInfo.load_level(path)
		if info == null:
			print("failing")
			push_error("Failed to load level info: " + path)
			return

	GameState.current_level = self

	start()

func start():
	if info == null:
		return
	print("starting")

	MusicSystem.stop_all(false)
	GameState.level_medium = info.medium if info.medium != "" else "air"
	# Setup background
	var ocean = Ocean.new()
	add_child(ocean)
	_ocean = ocean
	move_child(ocean, 0)
	ocean.configure_clouds(info.ground_cloud_cover, info.air_cloud_cover)
	ocean.configure_rgb(info.randomize_background_rgb, info.custom_rgb, info.bg_r, info.bg_g, info.bg_b)
	
	eta = float(info.success_time)
	events_to_process = info.events.duplicate()
	_initial_convoy_spawns = info.convoy_ships.size()
	survival_percentage = 100.0
	
	# Spawn Player
	# Player starts at 0,0 usually? Level.bmx: craft.create(0,0...)
	player = _create_ship(info.player_ship, Vector2.ZERO, deg_to_rad(info.convoy_heading), true)
	if player:
		# Add HumanController
		var ctrl = HumanController.new()
		ctrl.ship = player
		player.add_child(ctrl)
		escort_ships.append(player)
		
		GameState.player = player

		# Add Camera
		var cam = PlayerCamera.new()
		player.add_child(cam)
		cam.make_current()
		
		# Create HUD Layer and InGameUI
		var hud_layer = CanvasLayer.new()
		hud_layer.name = "HUD"
		add_child(hud_layer)
		
		# Instantiate InGameUI
		ui = InGameUI.new()
		# IMPORTANT: Set anchors to fill rect BEFORE adding to ensure layout works
		ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud_layer.add_child(ui)
		
		# Instantiate RadioUI separately
		radio_ui = RadioUI.new()
		# IMPORTANT: Set anchors to fill rect BEFORE adding to ensure layout works
		radio_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		hud_layer.add_child(radio_ui)
		
		print("Level Started: Player spawned at ", player.position)
	else:
		push_error("Failed to spawn player ship: " + info.player_ship)
	
	_create_convoy_and_escorts(0, -200)
	_spawn_start_ships(0, 0)
	
	_update_convoy_center()
	add_map_radar_event(convoy_center, RadarUI.COLOR_CONVOY)

	_add_fade_from_white_overlay()
	_setup_pause_overlay()
	_setup_mission_outcome_overlay()
	_setup_mission_briefing_overlay()

func dismiss_mission_outcome() -> void:
	GameState.block_player_input = false
	GameState.player = null
	GameState.current_level = null
	get_tree().paused = false
	Engine.time_scale = 1.0
	if success:
		RunState.last_survival_percent = int(survival_percentage)
		if RunState.pending_mission_index >= 0 and RunState.pending_level_name != "":
			var campaign_count := 0
			for file_name in GameData.list_data_files(GameData.LEVEL):
				if file_name.ends_with(".lvl"):
					var base := file_name.trim_suffix(".lvl")
					if base.to_lower() != "random":
						campaign_count += 1
			ProgressManager.record_mission_result(
				RunState.pending_mission_index,
				RunState.pending_level_name,
				RunState.last_survival_percent,
				campaign_count
			)
	else:
		RunState.last_survival_percent = 0
	if RunState.pending_mission_index < 0:
		RunState.return_to_random_mission = true
		RunState.return_to_mission_select = false
	else:
		RunState.return_to_random_mission = false
		RunState.return_to_mission_select = true
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _setup_mission_outcome_overlay() -> void:
	add_child((load("res://scripts/ui/mission_outcome_overlay.gd") as GDScript).new() as CanvasLayer)


func _setup_mission_briefing_overlay() -> void:
	var script: GDScript = load("res://scripts/ui/mission_briefing_overlay.gd") as GDScript
	var overlay: CanvasLayer = script.new() as CanvasLayer
	(overlay as Node).call("configure", self, info.desc)
	add_child(overlay)


func _setup_pause_overlay() -> void:
	_pause_overlay = (load("res://scripts/ui/pause_overlay.gd") as GDScript).new() as CanvasLayer
	add_child(_pause_overlay)

func _add_fade_from_white_overlay() -> void:
	fade_in_alpha = 1.0
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeFromWhite"
	fade_layer.layer = 128
	add_child(fade_layer)
	_fade_from_white = ColorRect.new()
	_fade_from_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_from_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_from_white.color = Color.WHITE
	_fade_from_white.modulate.a = fade_in_alpha
	fade_layer.add_child(_fade_from_white)


func enter_pause() -> void:
	if _pause_overlay == null or get_tree().paused:
		return
	if failure or success:
		return
	Engine.time_scale = 1.0
	get_tree().paused = true
	_pause_overlay.visible = true


func resume_from_pause() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = false
	get_tree().paused = false


func abort_mission_from_pause() -> void:
	failure = true
	print("Mission Failed: Aborted")
	resume_from_pause()


func notify_player_death() -> void:
	if failure or success or briefing_active or info == null:
		return
	if _player_death_failure_countdown < 0.0:
		_player_death_failure_countdown = PLAYER_DEATH_FAILURE_DELAY


func _unhandled_input(event: InputEvent) -> void:
	if info == null or get_tree().paused:
		return
	if briefing_active:
		return
	if failure or success:
		return
	if event.is_action_pressed("pause"):
		enter_pause()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		SoundSystem.sync_max_distances(self)

func _update_fade_from_white(delta: float) -> void:
	if _fade_from_white == null or not is_instance_valid(_fade_from_white):
		_fade_from_white = null
		return
	fade_in_alpha = maxf(0.0, fade_in_alpha - delta * FADE_IN_ALPHA_RATE)
	_fade_from_white.modulate.a = fade_in_alpha
	if fade_in_alpha <= 0.0:
		_fade_from_white.get_parent().queue_free()
		_fade_from_white = null

func _process(delta: float):
	if info == null:
		return

	if not get_tree().paused and not briefing_active:
		# Debug time controls: Shift+` (~) = 10x, Shift+Tab = 0.1x
		var debug_fast := Input.is_physical_key_pressed(KEY_SHIFT) and Input.is_physical_key_pressed(KEY_QUOTELEFT)
		var slow_mo := Input.is_physical_key_pressed(KEY_SHIFT) and Input.is_physical_key_pressed(KEY_TAB)
		if debug_fast:
			Engine.time_scale = 10.0
		elif slow_mo:
			Engine.time_scale = 0.1
		else:
			Engine.time_scale = 1.0

	_update_fade_from_white(delta)
	_update_bg_color_fade(delta)
	
	# Debug print every 5 seconds
	# if int(time_elapsed) % 5 == 0 and int(time_elapsed + delta) % 5 != 0:
	#	print("Time: ", time_elapsed, " Ships: ", GameState.ships.size())

	if briefing_active:
		return

	# Keep start ships list clean and despawn "start ships" once they are out of radar range,
	# matching the original BlitzMax `cullStartShips()` behavior.
	_cull_start_ships()

	_cull_dead_ships()

	if success:
		return

	time_elapsed += delta
	eta -= delta

	_decay_map_radar_events(delta)
	_update_convoy_center()
	var min_convoy_dist := _player_min_distance_to_convoy()
	_check_boundary(min_convoy_dist)
	if ui:
		ui.set_convoy_danger_warning(
			not failure and not success
			and min_convoy_dist > DANGER_RANGE
			and min_convoy_dist <= END_GAME_RANGE
		)
	_check_events()
	_time_spawn_end_ships()

	# Win/Loss Conditions
	if not failure and _player_death_failure_countdown >= 0.0:
		_player_death_failure_countdown -= delta
		if _player_death_failure_countdown <= 0.0:
			_player_death_failure_countdown = -1.0
			failure = true
			print("Mission Failed: Player Died")

	if not failure and eta <= 0 and _player_death_failure_countdown < 0.0:
		success = true
		print("Mission Success")

func _cull_start_ships():
	if start_ships.is_empty():
		return
	if not player or not is_instance_valid(player):
		return

	# Iterate backwards so removals are safe.
	for i in range(start_ships.size() - 1, -1, -1):
		var ship = start_ships[i]
		if not is_instance_valid(ship):
			start_ships.remove_at(i)
			continue

		if ship.position.distance_to(player.position) > RADAR_RANGE:
			start_ships.remove_at(i)
			ship.queue_free()


func _remove_dead_from_ship_list(lst: Array[Ship]) -> void:
	for i in range(lst.size() - 1, -1, -1):
		var s: Ship = lst[i]
		if not is_instance_valid(s) or s.health <= 0.0:
			lst.remove_at(i)


func _refresh_survival_percentage() -> void:
	var denom := float(_initial_convoy_spawns)
	if denom <= 0.0:
		survival_percentage = 100.0
		return
	var live := 0
	for s in convoy_ships:
		if is_instance_valid(s) and s.health > 0.0:
			live += 1
	survival_percentage = 100.0 * float(live) / denom


## Each `convoy_survivors` entry must be satisfied by a distinct live convoy hull (BlitzMax `convoyShipsSurvive`).
func _convoy_survivors_still_satisfied() -> bool:
	if info.convoy_survivors.is_empty():
		return true
	var remaining: Array[Ship] = []
	for s in convoy_ships:
		if is_instance_valid(s) and s.health > 0.0 and s.info:
			remaining.append(s)
	for req in info.convoy_survivors:
		var found := false
		for j in range(remaining.size() - 1, -1, -1):
			var s: Ship = remaining[j]
			if s.info.name == req.ship_info_name:
				remaining.remove_at(j)
				found = true
				break
		if not found:
			return false
	return true


func _cull_dead_gamestate_ships() -> void:
	for i in range(GameState.ships.size() - 1, -1, -1):
		var s: Ship = GameState.ships[i]
		if not is_instance_valid(s) or s.health <= 0.0:
			GameState.ships.remove_at(i)


func _cull_dead_ships() -> void:
	if failure or success:
		return

	var convoy_n := convoy_ships.size()
	_remove_dead_from_ship_list(convoy_ships)
	if convoy_ships.size() < convoy_n:
		_refresh_survival_percentage()
		if player and is_instance_valid(player):
			SoundSystem.play("radio_message", player.position, self, 0.0, 1.0)
		if radio_ui:
			if _convoy_survivors_still_satisfied():
				radio_ui.add_message("Mission Status - A convoy ship has been destroyed.")
			elif not failure:
				radio_ui.add_message(
					"Mission Status - Too many convoy ships have been destroyed.  Survivors return to base."
				)
				failure = true

	var escort_n := escort_ships.size()
	_remove_dead_from_ship_list(escort_ships)
	if escort_ships.size() < escort_n:
		# Avoid duplicate radio when the player died (they are listed as an escort).
		if player and is_instance_valid(player) and player.health > 0.0:
			SoundSystem.play("radio_message", player.position, self, 0.0, 1.0)
			if radio_ui:
				radio_ui.add_message("Mission Status - An escort ship has been destroyed.")

	_remove_dead_from_ship_list(attacking_ships)
	_remove_dead_from_ship_list(start_ships)
	_remove_dead_from_ship_list(end_ships)
	_cull_dead_gamestate_ships()


func _create_convoy_and_escorts(bx: float, by: float):
	var gap_max = 350
	var gap_min = 275
	var jitter_max = 50
	
	var convoy_heading_rad = deg_to_rad(info.convoy_heading)
	
	# Spawn Convoy
	for ship_spawn in info.convoy_ships:
		var x = bx + randf_range(-jitter_max, jitter_max)
		var y = by + randf_range(-jitter_max, jitter_max)
		
		var ship = _create_ship(ship_spawn.ship_info_name, Vector2(x, y), convoy_heading_rad, true)
		if ship:
			var ctrl := AIController.new()
			ctrl.current_behavior = _BEHAVIOR_CONVOY.new() as AIBehavior
			ctrl.ship = ship
			ship.add_child(ctrl)
			
			ship.set_forward_speed(ship.info.max_speed)
			
			convoy_ships.append(ship)
			
			var gap = randi_range(gap_min, gap_max)
			bx += gap * cos(convoy_heading_rad)
			by += gap * sin(convoy_heading_rad)

	# Spawn Escorts
	var num_escorts = info.escort_ships.size()
	if num_escorts > 0:
		bx = 0
		by = 0
		var rot = 0.0
		var rot_step = 360.0 / num_escorts
		
		for ship_spawn in info.escort_ships:
			var xmod = 150 * cos(deg_to_rad(rot))
			var ymod = 150 * sin(deg_to_rad(rot))
			rot += rot_step
			
			var ship = _create_ship(ship_spawn.ship_info_name, Vector2(bx + xmod, by + ymod), convoy_heading_rad, true)
			if ship:
				var ctrl = SupportAI.new() # convoySupportAI
				ctrl.ship = ship
				ship.add_child(ctrl)
				
				# Original sets speed to localplayer speed. 
				if player:
					ship.set_forward_speed(player.forward_speed())
				
				escort_ships.append(ship)

func _spawn_start_ships(x: float, y: float, jitter_max: float = 750):
	for ship_spawn in info.start_ships:
		var sx = x + randf_range(-jitter_max, jitter_max)
		var sy = y + randf_range(-jitter_max, jitter_max)
		var ship = _create_ship(ship_spawn.ship_info_name, Vector2(sx, sy), deg_to_rad(info.convoy_heading + 180))
		if ship:
			var ctrl = AIController.new()
			ctrl.ship = ship
			ship.add_child(ctrl)
			start_ships.append(ship)

func _time_spawn_end_ships():
	if eta <= END_SHIP_SPAWN_TIME and end_ships.size() == 0 and info.end_ships.size() > 0:
		var heading = deg_to_rad(info.convoy_heading)
		var spawn_pos = convoy_center + Vector2(cos(heading), sin(heading)) * END_SHIP_SPAWN_DIST
		
		for ship_spawn in info.end_ships:
			var jitter = 750
			var x = spawn_pos.x + randf_range(-jitter, jitter)
			var y = spawn_pos.y + randf_range(-jitter, jitter)
			
			var ship = _create_ship(ship_spawn.ship_info_name, Vector2(x, y), heading + PI, true)
			if ship:
				var ctrl = SupportAI.new()
				ctrl.ship = ship
				ship.add_child(ctrl)
				end_ships.append(ship)

func _check_events():
	var elapsed := int(info.success_time - eta)
	for i in range(events_to_process.size() - 1, -1, -1):
		var event = events_to_process[i]
		if LevelInfo.event_conditions_met(event, elapsed):
			_trigger_event(event)
			events_to_process.remove_at(i)

func _trigger_event(event: LevelInfo.Event):
	for action in event.actions:
		if action is LevelInfo.RadioMessageData:
			if player:
				SoundSystem.play("radio_message", player.position, self, 0.0, 1.0)
			else:
				SoundSystem.play("radio_message", Vector2.ZERO, self, 0.0, 1.0)
				
			if radio_ui:
				radio_ui.add_message(action.sender + " - " + action.message)

		elif action is LevelInfo.MusicChangeData:
			var music := action as LevelInfo.MusicChangeData
			if not music.track_name.is_empty():
				MusicSystem.play_track(music.track_name, MusicSystem.LEVEL_VOLUME)

		elif action is LevelInfo.BackgroundColorChangeData:
			_apply_background_color_change(action as LevelInfo.BackgroundColorChangeData)
			
		elif action is LevelInfo.GroupSpawn:
			var group = action as LevelInfo.GroupSpawn
			var spawn_angle = deg_to_rad(group.angle)
			
			# Logic from dealWithEvent
			if group.team != 0 and group.team != -1: # Enemy
				var x = convoy_center.x + cos(spawn_angle) * ENEMY_SPAWN_RANGE
				var y = convoy_center.y + sin(spawn_angle) * ENEMY_SPAWN_RANGE
				_spawn_enemy_ships(x, y, group.ships)
				
			if group.team == 0: # Escort Reinforcements
				var x = convoy_center.x + cos(spawn_angle) * ENEMY_SPAWN_RANGE
				var y = convoy_center.y + sin(spawn_angle) * ENEMY_SPAWN_RANGE
				_spawn_escort_reinforcements(x, y, group.ships)
				
			if group.team == -1: # Retire Escorts
				# Original (BlitzMax): enemySpawnRange * 1000 (i.e. "send them way off").
				var x = convoy_center.x + cos(spawn_angle) * ENEMY_SPAWN_RANGE * 1000.0
				var y = convoy_center.y + sin(spawn_angle) * ENEMY_SPAWN_RANGE * 1000.0
				_retire_escorts(x, y, group.ships)

func _spawn_enemy_ships(x: float, y: float, ships: Array, jitter_max: float = 300):
	for ship_spawn in ships:
		var sx = x + randf_range(-jitter_max, jitter_max)
		var sy = y + randf_range(-jitter_max, jitter_max)
		var new_ship = _create_ship(ship_spawn.ship_info_name, Vector2(sx, sy), deg_to_rad(info.convoy_heading + 180))
		if new_ship:
			new_ship.set_forward_speed(new_ship.info.max_speed)
			if convoy_ships.size() > 0 and is_instance_valid(convoy_ships[0]):
				var convoy_ship: Ship = convoy_ships[0]
				new_ship.vx = convoy_ship.vx
				new_ship.vy = convoy_ship.vy
			var ctrl = AssaultAI.new() # ConvoyAssaultAI
			ctrl.convoy_targets = convoy_ships # Pass convoy targets like original
			ctrl.ship = new_ship
			new_ship.add_child(ctrl)
			attacking_ships.append(new_ship)
	
	add_map_radar_event(Vector2(x, y), RadarUI.COLOR_ATTACK)

func _spawn_escort_reinforcements(x: float, y: float, ships: Array, jitter_max: float = 300):
	for ship_spawn in ships:
		var sx = x + randf_range(-jitter_max, jitter_max)
		var sy = y + randf_range(-jitter_max, jitter_max)
		var ship = _create_ship(ship_spawn.ship_info_name, Vector2(sx, sy), deg_to_rad(info.convoy_heading + 180), true)
		if ship:
			var ctrl = SupportAI.new()
			ctrl.ship = ship
			ship.add_child(ctrl)
			escort_ships.append(ship)
			
	add_map_radar_event(Vector2(x, y), RadarUI.COLOR_ESCORT)

func _retire_escorts(x: float, y: float, ships: Array):
	# Find matching escorts and send them away
	for ship_spawn in ships:
		var candidate: Ship = null
		
		# Find best candidate (most health? logic in original: c.health > r.health)
		for s in escort_ships:
			if s.info and s.info.name == ship_spawn.ship_info_name and s != player: # don't retire player
				if candidate == null or s.health > candidate.health:
					candidate = s
		
		if candidate:
			escort_ships.erase(candidate)
			# Switch controller to FlyTo (AIController with behavior)
			# Note: In Godot, we might just replace the controller node or reset it.
			# For now, let's remove old controller and add generic AI.
			for c in candidate.get_children():
				if c is Controller:
					c.queue_free()
			
			var new_ai = AIController.new()
			new_ai.current_behavior = BehaviorFlyTo.new(Vector2(x, y))
			candidate.add_child(new_ai)
			
			start_ships.append(candidate) # Treat as start ship (fly away/despawn logic)
			
			# In the original, retired escorts become "startships" and are culled once out of radar range.


func _apply_background_color_change(change: LevelInfo.BackgroundColorChangeData) -> void:
	if _ocean == null or not is_instance_valid(_ocean):
		return
	if change.random and change.fade_time <= 0.0:
		_ocean.random_rgb()
		return
	if not change.random and change.fade_time <= 0.0:
		_ocean.set_rgb(change.r, change.g, change.b)
		return
	if not change.random:
		_start_bg_color_fade(Color(change.r, change.g, change.b), change.fade_time)


func _start_bg_color_fade(target: Color, duration: float) -> void:
	if _ocean == null or not is_instance_valid(_ocean):
		return
	if duration <= 0.0:
		_ocean.set_rgb(target.r, target.g, target.b)
		_bg_fade_active = false
		return
	_bg_fade_from = Color(_ocean.bg_r, _ocean.bg_g, _ocean.bg_b)
	_bg_fade_to = target
	_bg_fade_duration = duration
	_bg_fade_elapsed = 0.0
	_bg_fade_active = true


func _update_bg_color_fade(delta: float) -> void:
	if not _bg_fade_active or _ocean == null or not is_instance_valid(_ocean):
		return
	_bg_fade_elapsed += delta
	var factor := clampf(_bg_fade_elapsed / _bg_fade_duration, 0.0, 1.0)
	var c := _bg_fade_from.lerp(_bg_fade_to, factor)
	_ocean.set_rgb(c.r, c.g, c.b)
	if factor >= 1.0:
		_bg_fade_active = false

func _create_ship(info_name: String, pos: Vector2, rot: float, mission_ally: bool = false) -> Ship:
	var ship = Ship.new()
	ship.info_name = info_name
	ship.position = pos
	ship.rotation = rot
	if mission_ally and info.player_team > 0:
		ship.combat_team_override = info.player_team
	add_child(ship)
	# Ship _ready will register it
	return ship

func add_map_radar_event(world_pos: Vector2, color: Color) -> void:
	map_radar_events.append({
		"world_pos": world_pos,
		"color": color,
		"time_left": MAP_RADAR_EVENT_LIFETIME,
	})


func _decay_map_radar_events(delta: float) -> void:
	for i in range(map_radar_events.size() - 1, -1, -1):
		map_radar_events[i]["time_left"] = map_radar_events[i]["time_left"] as float - delta
		if (map_radar_events[i]["time_left"] as float) <= 0.0:
			map_radar_events.remove_at(i)


func _update_convoy_center():
	var sum = Vector2.ZERO
	var count = 0
	for s in convoy_ships:
		if is_instance_valid(s):
			sum += s.position
			count += 1
	if count > 0:
		convoy_center = sum / count
	else:
		convoy_center = Vector2.ZERO # Or last known?

func _player_min_distance_to_convoy() -> float:
	if not player or not is_instance_valid(player):
		return 0.0
	# Same nearest-target idea as BlitzMax Level.bmx (center, then tighten to nearest convoy hull).
	var min_dist := player.position.distance_to(convoy_center)
	for s in convoy_ships:
		if is_instance_valid(s):
			var d := player.position.distance_to(s.position)
			if d < min_dist:
				min_dist = d
	return min_dist


func _check_boundary(min_dist: float) -> void:
	if not player or not is_instance_valid(player):
		return
	if min_dist > END_GAME_RANGE:
		failure = true
		print("Mission Failed: Abandoned Convoy")
		# TODO: UI Message
