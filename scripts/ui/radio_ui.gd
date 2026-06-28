extends Control
class_name RadioUI

var message_container: VBoxContainer

func _ready():
	# Position: Top Left-ish
	# BlitzMax: x = GraphicsWidth() * 0.125
	# Width: GraphicsWidth() * 0.75
	# y = 6
	
	# Set anchors to place this Control
	# Ensure this control is full rect for positioning logic but rely on margins for placement?
	# Or better, just anchor relative to viewport.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Override specific anchors to match original layout
	# We want it anchored to the top, taking up 75% width centered-ish (from 12.5% to 87.5%)
	# Use set_anchors_and_offsets_preset to reset and then apply custom.
	# Actually, just setting anchor_* properties directly after FULL_RECT preset might be conflicting if not careful.
	# Let's be explicit.
	
	anchor_left = 0.125
	anchor_right = 0.875
	anchor_top = 0.0
	anchor_bottom = 0.5 # Give it some height for the VBox to grow into, but not full screen blocking clicks
	
	offset_left = 0
	offset_right = 0
	offset_top = 6
	offset_bottom = 0
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	message_container = VBoxContainer.new()
	# Separation between messages
	# BlitzMax logic implies 9 pixels of space between the rect of one and the start of the next
	message_container.add_theme_constant_override("separation", 9)
	
	# Make container fill the width
	# Use set_anchors_preset which handles the layout mode internally
	message_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	# But only height as needed
	message_container.size_flags_vertical = Control.SIZE_EXPAND_FILL # actually we just want it to flow down
	
	# Actually, VBoxContainer inside this Control:
	message_container.anchor_right = 1.0
	message_container.anchor_bottom = 0.0 # Don't stretch bottom
	message_container.grow_vertical = Control.GROW_DIRECTION_END
	
	add_child(message_container)

func add_message(text: String, color: Color = Color.WHITE):
	var msg = RadioMessage.new()
	msg.text_content = text
	msg.text_color = color
	# Set sizing flags to expand horizontally
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_container.add_child(msg)
