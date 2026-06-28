class_name PlayerCamera
extends Camera2D

## Camera that follows the player, replicating the original game's camera behavior.
## Original logic:
## viewx = -localplayer.c.x + GraphicsWidth() * .5; 
## viewy = -localplayer.c.y + GraphicsHeight() * .5
##
## In Godot, a Camera2D attached to the player (or centered on them) handles this automatically
## by keeping the target (0,0 of the parent) at the screen center (defined by anchor_mode).
##
## This class is prepared for any future complex camera logic (zoom, shake, lead).

func _ready():
	# Default Godot Camera2D behavior (ANCHOR_MODE_DRAG_CENTER) centers the parent.
	# We set zoom to see more of the field, as original resolution was likely lower (1024x768)
	# but ships were small.
	zoom = Vector2(0.5, 0.5) 
	
	# Enable smoothing if we want a less rigid feel, but original was rigid.
	# position_smoothing_enabled = true
