extends Node
class_name MusicSystem

static var _player_a: AudioStreamPlayer
static var _player_b: AudioStreamPlayer
static var _active: AudioStreamPlayer
static var _fade_tween: Tween
static var _stream_cache: Dictionary = {}
static var _setup_pending: bool = false
static var _ready_callbacks: Array[Callable] = []
const FADE_SEC: float = 2.0
## Effectively silent; avoid `linear_to_db(0.0)` which is -INF and breaks tweens.
const SILENCE_DB: float = -80.0
const MENU_TRACK: String = "Duty Calls"
const MENU_VOLUME_INTRO: float = 0.35
const MENU_VOLUME_RETURN: float = 0.5
const LEVEL_VOLUME: float = 0.3


static func _players_ready() -> bool:
	return (
		_player_a != null
		and is_instance_valid(_player_a)
		and _player_a.is_inside_tree()
		and _player_b != null
		and is_instance_valid(_player_b)
		and _player_b.is_inside_tree()
	)


static func _ensure_players() -> void:
	if _players_ready():
		_flush_ready_callbacks()
		return
	if _setup_pending:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_setup_pending = true
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()
	_player_a.bus = &"Master"
	_player_b.bus = &"Master"
	_active = _player_a
	tree.root.add_child.call_deferred(_player_a)
	tree.root.add_child.call_deferred(_player_b)
	tree.process_frame.connect(_on_players_ready, CONNECT_ONE_SHOT)


static func _on_players_ready() -> void:
	if not _players_ready():
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.process_frame.connect(_on_players_ready, CONNECT_ONE_SHOT)
		return
	_setup_pending = false
	_flush_ready_callbacks()


static func _flush_ready_callbacks() -> void:
	if _ready_callbacks.is_empty():
		return
	var pending := _ready_callbacks.duplicate()
	_ready_callbacks.clear()
	for cb in pending:
		cb.call()


static func _when_ready(callback: Callable) -> void:
	if _players_ready():
		callback.call()
		return
	_ready_callbacks.append(callback)
	_ensure_players()


static func _vol_db(linear: float) -> float:
	if linear <= 0.0:
		return SILENCE_DB
	return linear_to_db(linear)


static func play_menu_music(returning_from_mission: bool = false) -> void:
	var volume := MENU_VOLUME_RETURN if returning_from_mission else MENU_VOLUME_INTRO
	play_track(MENU_TRACK, volume)


static func play_track(track_name: String, volume: float = LEVEL_VOLUME, loop: bool = true) -> void:
	_when_ready(_play_track_impl.bind(track_name, volume, loop))


static func _play_track_impl(track_name: String, volume: float, loop: bool) -> void:
	if track_name.is_empty():
		return
	var stream := _get_music_stream(track_name)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	var inactive := _player_b if _active == _player_a else _player_a
	inactive.stream = stream
	inactive.volume_db = SILENCE_DB
	inactive.play()
	_crossfade_to(inactive, volume)


static func stop_all(fade: bool = true) -> void:
	if not _players_ready():
		if fade:
			_when_ready(_fade_out_active)
		return
	if fade:
		_fade_out_active()
	else:
		_player_a.stop()
		_player_b.stop()


static func _crossfade_to(new_active: AudioStreamPlayer, volume: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var old := _active
	_active = new_active
	var tree := old.get_tree()
	if tree == null:
		new_active.volume_db = _vol_db(volume)
		return
	_fade_tween = tree.create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(old, "volume_db", SILENCE_DB, FADE_SEC)
	_fade_tween.tween_property(new_active, "volume_db", _vol_db(volume), FADE_SEC)
	_fade_tween.chain().tween_callback(func(): old.stop())


static func _fade_out_active() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _active or not _active.is_inside_tree():
		return
	_fade_tween = _active.get_tree().create_tween()
	_fade_tween.tween_property(_active, "volume_db", SILENCE_DB, FADE_SEC)
	_fade_tween.chain().tween_callback(func(): _active.stop())


static func clear_cache() -> void:
	_stream_cache.clear()


static func _get_music_stream(track_name: String) -> AudioStream:
	if _stream_cache.has(track_name):
		return _stream_cache[track_name]
	var path := GameData.get_data_path(GameData.Type.MUSIC, track_name)
	if path == "":
		push_warning("Music track not found: " + track_name)
		return null
	var stream := GameData.load_audio(path)
	if stream:
		_stream_cache[track_name] = stream
	return stream
