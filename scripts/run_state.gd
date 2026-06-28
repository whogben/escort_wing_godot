extends Node
## Holds data that must survive a scene change (e.g. mission chosen in the menu).

func _ready() -> void:
	ProgressManager.load_all()
	# Always windowed on desktop; skip on web where the browser controls the canvas size.
	if not OS.has_feature("web"):
		ProgressManager.apply_display_settings()
	GameData.load_persisted_mod()

## When set, [`Level`](../level.gd) uses this instead of loading from disk (procedural `Random.lvl` pipeline).
var pending_level_info: LevelInfo = null

var pending_level_name: String = ""
## Set when leaving a campaign level so main menu opens mission select instead of the intro splash.
var return_to_mission_select: bool = false
## Set when leaving a random mission so main menu reopens the random-mission screen.
var return_to_random_mission: bool = false
## Last level launched from the menu (used to restore selection when returning).
var last_played_level_name: String = ""
## Random-mission UI state preserved across scene changes.
var random_mission_ship_index: int = 0
var random_mission_team: int = 1
var random_mission_convoy_slider: float = 0.3
var random_mission_escort_slider: float = 0.2
var random_mission_enemy_slider: float = 0.3
## Campaign mission wheel index at launch; -1 for random / procedural missions.
var pending_mission_index: int = -1
## Survival percentage from the last completed mission (campaign score / unlock).
var last_survival_percent: int = 0
