extends Node
class_name GameState
## Static class keeps track of the overall state of the game.

## The local player's ship.
static var player: Ship = null

## The current level ([`Level`](level.gd) at runtime; untyped to avoid pulling level.gd into every compile).
static var current_level = null

## All ships in the game
static var ships: Array[Ship] = []

## When true, HumanController ignores gameplay actions (mission outcome flashes, etc.).
static var block_player_input: bool = false

## Level physics medium from .lvl (`air` or `truespace`).
static var level_medium: String = "air"


## Matches BlitzMax draw culling: skip drawing when far from the player on the X axis.
static func is_near_player_x(world_pos: Vector2) -> bool:
	if player == null or not is_instance_valid(player):
		return true
	var viewport_width := 1920.0
	if current_level != null and is_instance_valid(current_level):
		var vp: Viewport = current_level.get_viewport()
		if vp:
			viewport_width = vp.get_visible_rect().size.x
	return abs(player.global_position.x - world_pos.x) < viewport_width


static func weapon_should_fire(w: Weapon) -> bool:
	if w == null or w.ship == null:
		return false
	var lifetime_bonus := 0.0
	if w is DataWeapon:
		var dw := w as DataWeapon
		if dw.bullet_name != "none":
			var p_info := ProjectileInfo.named(dw.bullet_name)
			if p_info:
				lifetime_bonus = p_info.max_lifetime
	var mindist := w.get_range() + lifetime_bonus * 100.0
	var mindistsqr := mindist * mindist
	var base_pos := w.ship.global_position
	if w is DataWeapon:
		base_pos = Vector2((w as DataWeapon)._x_base(), (w as DataWeapon)._y_base())
	for s in ships:
		if not is_instance_valid(s) or s.health <= 0.0:
			continue
		if s.info.team == w.ship.info.team:
			continue
		if base_pos.distance_squared_to(s.global_position) < mindistsqr:
			return true
	return false


## Returns an array of all ships sorted by distance from the given position.
## Ships with health <= 0.0 are excluded.
## Returns in format {"ship": Ship, "dist": float}
static func get_ships_by_distance(to: Vector2) -> Array[Dictionary]:
	var ships_by_distance: Array[Dictionary] = []
	for ship in ships:
		if ship.health > 0.0:
			ships_by_distance.append({
				"ship": ship,
				"distance": ship.position.distance_to(to)
				})
	ships_by_distance.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)
	return ships_by_distance

## Use these z-indexes for the different layers of the game.
enum ZLayer {
    BACKGROUND = -20,
    LOW_CLOUDS = -15,
    PFX_GROUND = -10,
    PFX_TRAILS = -5,
    SHIPS = 0,
    PROJECTILES = 1,
    PFX_EXPLOSIONS = 5,
    PFX_HIGH = 10,
    HIGH_CLOUDS = 20,
    UI = 100
}
