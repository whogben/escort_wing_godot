extends Node2D

var timer: float = 0.0
var burst_interval: float = 5.0 # Reduced interval since they auto-delete now
var pfx_names: Array[String] = []

# Configuration for the grid
var start_x: float = 100.0
var start_y: float = 100.0
var x_spacing: float = 150.0
var y_spacing: float = 150.0
var max_cols: int = 8  # Adjusted to fit screen width roughly

func _ready():
	# Load all particle names
	var files = GameData.list_data_files(GameData.PARTICLE_INFO)
	for f in files:
		if f.ends_with(".particle"):
			pfx_names.append(f.get_basename())
	
	# Sort for consistent order
	pfx_names.sort()
	
	# Initial burst
	trigger_bursts()

func _process(delta: float):
	timer += delta
	if timer >= burst_interval:
		timer = 0.0
		trigger_bursts()

func trigger_bursts():
	print("Triggering bursts for ", pfx_names.size(), " particles")
	var col = 0
	var row = 0
	
	for p_name in pfx_names:
		var info = ParticleInfo.named(p_name)
		if info:
			var x = start_x + col * x_spacing
			var y = start_y + row * y_spacing
			
			# New Approach: Spawn a transient Particles node for each effect
			var p = Particles.new()
			add_child(p)
			# We keep the Particles node at (0,0) and pass the target position to burst()
			# This matches the previous logic where particles move in the coordinate space of the parent.
			p.burst(info, x, y)
			
			col += 1
			if col >= max_cols:
				col = 0
				row += 1
