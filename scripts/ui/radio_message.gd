extends PanelContainer
class_name RadioMessage

var text_content: String = ""
var text_color: Color = Color.WHITE

var timer: float = 12.0
const FADE_TIME: float = 6.0

var char_timer: float = 0.0
const CHAR_TIME: float = 0.009
var visible_chars: int = 0

var label: Label

func _ready():
	# Style
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	# BlitzMax: width+6, height+6. Text at x+3, y+3.
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", sb)
	
	label = Label.new()
	label.add_theme_color_override("font_color", text_color)
	
	# Load font
	var font = load("res://font.otf")
	if font:
		label.add_theme_font_override("font", font)
		
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text_content
	label.visible_characters = 0
	
	add_child(label)
	
	modulate.a = 1.0

func _process(delta):
	# Typing effect
	if visible_chars < text_content.length():
		char_timer -= delta
		while char_timer <= 0:
			char_timer += CHAR_TIME
			visible_chars += 1
			label.visible_characters = visible_chars
			if visible_chars >= text_content.length():
				break
	
	# Fading
	timer -= delta
	if timer <= 0:
		queue_free()
	elif timer < FADE_TIME:
		modulate.a = timer / FADE_TIME
	else:
		modulate.a = 1.0
