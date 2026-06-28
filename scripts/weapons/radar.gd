extends Weapon
class_name Radar
## A passive radar component.

var rot: float = 0.0
var rot_speed: float = 10.0
var ang_offset: float = 0.0
var dist_offset: float = 0.0

func setup(dist: float, ang: float):
	dist_offset = dist
	ang_offset = ang
	rot = randi() % 360

var texture: Texture2D

func _ready():
	var path = GameData.get_data_path(GameData.Type.WEAPON_GFX, "radar")
	texture = GameData.load_texture(path)

func _process(delta: float):
	rot += rot_speed * delta
	queue_redraw()

func _draw():
	if texture:
		# Position logic from Bmx:
		# DrawImage(..., owner.x + Cos(owner.rot + ang) * dist, ...)
		# We are drawing in local space of the Weapon, which is child of Ship.
		# However, `draw_texture` draws relative to THIS node's 0,0.
		# If this node is at (0,0) of the ship, we need to calculate offset.
		# Bmx: owner.rot + ang.
		# In Godot, the Ship rotates. The Weapon node rotates with it.
		# So if we place the weapon at (0,0), the local coord system is already rotated by owner.rot.
		# So we just need to account for ang_offset.
		var rad = deg_to_rad(ang_offset)
		var pos_x = cos(rad) * dist_offset
		var pos_y = sin(rad) * dist_offset
		
		# Rotation: owner.rot + rot
		# Local rotation is just 'rot' because parent rotation is inherited.
		
		draw_set_transform(Vector2(pos_x, pos_y), deg_to_rad(rot), Vector2.ONE)
		draw_texture(texture, -texture.get_size() / 2.0)
