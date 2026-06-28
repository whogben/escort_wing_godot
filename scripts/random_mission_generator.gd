class_name RandomMissionGenerator
extends RefCounted
## Procedural missions from `Random.lvl` + community `EscortWing.bmx` `launchRandomMission` / `setupRandom*`.
##
## UI slider values are scaled in `build_random_mission` (`strength / 5 + 0.5`) like BlitzMax. Escort/end
## ships consume 1 budget point per hull (pool weighted by escort points). Enemy waves use `es / 10` per
## step 0..240, final wave at 250s with `es * 0.7`. Each attack picks a random enemy team (1 or 2, or 3
## if that matches the player) and spends 1 point per spawned hull.


## Use from menus via `preload(".../random_mission_generator.gd").new().build_default()` if static calls are awkward.
func build_default() -> LevelInfo:
	return RandomMissionGenerator.build_random_mission()

## Default UI parameters match `EscortGui.bmx` `RandomMissionScreen` defaults (0.3 / 0.2 / 0.3 sliders).
const DEFAULT_PLAYER_SHIP: String = "Flak Interceptor"
const DEFAULT_PLAYERTEAM: int = 1
const DEFAULT_CONVOY_SIZE: int = 5
const DEFAULT_ESCORT_STRENGTH: int = 40
const DEFAULT_ENEMY_STRENGTH: int = 250


## Loads `Random.lvl` via GameData, mutates like BlitzMax `launchRandomMission`.
## If [param append_template] is false, clears convoy, convoy_survivors, escort, end, and event lists first.
static func build_random_mission(
	player_ship: String = DEFAULT_PLAYER_SHIP,
	playerteam: int = DEFAULT_PLAYERTEAM,
	convoysize: int = DEFAULT_CONVOY_SIZE,
	escort_strength: int = DEFAULT_ESCORT_STRENGTH,
	enemy_strength: int = DEFAULT_ENEMY_STRENGTH,
	append_template: bool = true
) -> LevelInfo:
	randomize()
	var path := GameData.get_data_path(GameData.Type.LEVEL, "Random")
	if path == "":
		push_error("RandomMissionGenerator: Random.lvl not found")
		return null
	var info := LevelInfo.load_level(path)
	if info == null:
		return null
	if not append_template:
		info.convoy_ships.clear()
		info.convoy_survivors.clear()
		info.escort_ships.clear()
		info.end_ships.clear()
		info.events.clear()
	info.player_ship = player_ship
	var scaled_escort := float(escort_strength) / 5.0 + 0.5
	var scaled_enemy := float(enemy_strength) / 5.0 + 0.5
	setup_random_convoy(info, convoysize)
	setup_random_escorts(info, playerteam, scaled_escort)
	setup_random_enemies(info, playerteam, scaled_enemy)
	setup_random_end_ships(info, playerteam, scaled_escort + 10.0)
	info.events.sort_custom(func(a: LevelInfo.Event, b: LevelInfo.Event) -> bool: return a.event_time < b.event_time)
	return info


## BlitzMax `setupRandomConvoy`: random heading; `For i = 0 To convoysize` ⇒ convoysize+1 Freighters;
## `For i = 0 To (convoysize+1)*0.5` ⇒ int((convoysize+1)*0.5)+1 survivor entries (inclusive To).
static func setup_random_convoy(info: LevelInfo, convoysize: int) -> void:
	info.convoy_heading = randi_range(0, 359)
	for _i in range(convoysize + 1):
		info.convoy_ships.append(LevelInfo.ShipSpawn.new("Freighter", 0))
	var survivor_hi: int = int((convoysize + 1) * 0.5)
	for _i in range(survivor_hi + 1):
		info.convoy_survivors.append(LevelInfo.ShipSpawn.new("Freighter", 0))


static func _build_ally_pool(playerteam: int) -> Array[String]:
	var out: Array[String] = []
	for base_name in GameData.list_ship_info_base_names():
		var si := ShipInfo.named(base_name)
		if si == null or si.team != playerteam:
			continue
		for _r in si.escort_points:
			out.append(si.name)
	return out


static func _build_enemy_team_pool(playerteam: int) -> Array[String]:
	var enemy_team := randi_range(1, 2)
	if enemy_team == playerteam:
		enemy_team = 3
	var out: Array[String] = []
	for base_name in GameData.list_ship_info_base_names():
		var si := ShipInfo.named(base_name)
		if si == null or si.team != enemy_team:
			continue
		for _r in si.escort_points:
			out.append(si.name)
	return out


## BlitzMax `setupRandomEscorts` — one budget point per ship added.
static func setup_random_escorts(info: LevelInfo, playerteam: int, escort_strength: float) -> void:
	var pool := _build_ally_pool(playerteam)
	var budget := escort_strength
	while budget > 0.0:
		if pool.is_empty():
			break
		var randval := randi_range(0, pool.size() - 1)
		info.escort_ships.append(LevelInfo.ShipSpawn.new(pool[randval], 0))
		budget -= 1.0


## BlitzMax `setupRandomEndShips` — same as escorts but appended to end ships.
static func setup_random_end_ships(info: LevelInfo, playerteam: int, escort_strength: float) -> void:
	var pool := _build_ally_pool(playerteam)
	var budget := escort_strength
	while budget > 0.0:
		if pool.is_empty():
			break
		var randval := randi_range(0, pool.size() - 1)
		info.end_ships.append(LevelInfo.ShipSpawn.new(pool[randval], 0))
		budget -= 1.0


## BlitzMax `setupRandomEnemies`.
static func setup_random_enemies(info: LevelInfo, playerteam: int, enemy_strength: float) -> void:
	var es := enemy_strength
	for r in range(0, 4 * 60 + 1, 30):
		var points := es / 10.0
		es -= points
		add_random_enemy_attack(info, playerteam, r + randi_range(-10, 10), points)
	add_random_enemy_attack(info, playerteam, 4 * 60 + 10, es * 0.7)


## BlitzMax `addRandomEnemyAttack` — random enemy team per wave, one point per hull.
static func add_random_enemy_attack(info: LevelInfo, playerteam: int, time_sec: int, points: float) -> void:
	if points <= 0.0:
		return
	var enemies := _build_enemy_team_pool(playerteam)
	if enemies.is_empty():
		return
	var ev := LevelInfo.Event.new()
	ev.event_time = time_sec
	var group := LevelInfo.GroupSpawn.new()
	group.team = 1
	group.angle = randi_range(0, 359)
	group.ships = []
	var pts := points
	while pts > 0.0:
		var randval := randi_range(0, enemies.size() - 1)
		group.ships.append(LevelInfo.ShipSpawn.new(enemies[randval], 1))
		pts -= 1.0
	if group.ships.is_empty():
		return
	ev.actions.append(group)
	info.events.append(ev)
