class_name Collision

# Returns the closest point on the line segment (segment_start to segment_end) to the given point.
# Equivalent to Geometry2D.get_closest_point_on_segment but manually implemented
# to avoid physics engine dependencies if desired, or for porting consistency.
static func get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment_vec = segment_end - segment_start
	
	# Handle the case where the segment is a point (length is zero)
	if segment_vec.is_zero_approx():
		return segment_start
		
	# Project point onto the line (dot product) and normalize by segment length squared
	# t represents the position along the segment (0.0 at start, 1.0 at end)
	var t = (point - segment_start).dot(segment_vec) / segment_vec.length_squared()
	
	# Clamp t to the segment range [0, 1]
	t = clampf(t, 0.0, 1.0)
	
	return segment_start + segment_vec * t


static func segment_hits_circle(seg_a: Vector2, seg_b: Vector2, center: Vector2, radius: float) -> bool:
	var closest := get_closest_point_on_segment(center, seg_a, seg_b)
	return closest.distance_squared_to(center) <= radius * radius
