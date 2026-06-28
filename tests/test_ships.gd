extends Node2D


func _ready():
	# create one of each type of ship starting at 50, 50
	# with a 50 pixel vertical offset between each ship
	var ship_files = GameData.list_data_files("Ship Infos")
	var y_offset = 0.0
	var y_spacing = 50.0
	var start_x = 50.0
	var start_y = 50.0
	
	for file in ship_files:
		# Extract ship name from filename (remove .sfo extension)
		var ship_name = file.get_basename().get_file()
		
		# Create a new Ship node
		var ship = Ship.new()
		ship.info_name = ship_name
		ship.position = Vector2(start_x, start_y + y_offset)
		
		add_child(ship)
		
		# Increment vertical offset for next ship
		y_offset += y_spacing


func _process(_delta: float):
	# make all ships in the game wrap around if they cross the viewport
	var viewport_rect = get_viewport_rect()
	var viewport_width = viewport_rect.size.x
	var viewport_height = viewport_rect.size.y
	
	for ship in GameState.ships:
		if ship == null or not is_instance_valid(ship):
			continue
		
		var pos = ship.position
		
		# Wrap horizontally (left/right)
		if pos.x < 0:
			ship.position.x = viewport_width
		elif pos.x > viewport_width:
			ship.position.x = 0
		
		# Wrap vertically (top/bottom)
		if pos.y < 0:
			ship.position.y = viewport_height
		elif pos.y > viewport_height:
			ship.position.y = 0
