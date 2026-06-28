extends Weapon
class_name MineSuicide
## A suicide mine weapon that explodes when enemies are near.

var fired: bool = false

func _init():
	weapon_name = "Mine Suicide"
	base_range = 90.0
	power = 50.0

func _process(_delta: float):
	if fired or not ship:
		return
		
	# Check for enemies in range
	var r = base_range
	for ship_entry in GameState.get_ships_by_distance(ship.position):
		var target = ship_entry["ship"]
		var dist = ship_entry["distance"]
		
		if target.info.team != ship.info.team:
			if dist < (r + target.info.radius):
				_realfire()
				break

func _realfire():
	if fired: return
	
	# Damage self to death (suicide)
	ship.health = -100.0 # Ensure death
	fired = true
	
	# Explode
	# explosion.create(g, team, x, y, range*1.1, 20*400000, power, 0.1)
	var exp_node = Explosion.new()
	exp_node.setup_explosion(ship.position, ship.info.team, base_range * 1.1, 8000000.0, power, 0.1)
	
	ship.get_parent().add_child(exp_node)
	
	# Visuals handled by ship death usually, but we can draw the trigger range
	
func _draw():
	if fired: return
	# Draw range indicator
	# Bmx: DrawOval(owner.x - range, owner.y - range, range*2, range*2)
	# AlphaBlend, Alpha rnd(.01, .06)
	var alpha = randf_range(0.01, 0.06)
	draw_circle(Vector2.ZERO, base_range, Color(1, 1, 1, alpha))
