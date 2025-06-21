extends RefCounted
class_name Pathfinding

# A* pathfinding with 4-directional movement (no diagonals)
static func find_path(start: Vector2i, goal: Vector2i, grid_width: int, grid_height: int) -> Array[Vector2i]:
	if start == goal:
		return [start]
	
	# 4-directional movement (no diagonals)
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0)    # Right
	]
	
	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: heuristic(start, goal)}
	
	while open_set.size() > 0:
		# Find node in open_set with lowest f_score
		var current = get_lowest_f_score(open_set, f_score)
		
		if current == goal:
			return reconstruct_path(came_from, current)
		
		open_set.erase(current)
		
		for direction in directions:
			var neighbor = current + direction
			
			# Check bounds
			if neighbor.x < 0 or neighbor.x >= grid_width or neighbor.y < 0 or neighbor.y >= grid_height:
				continue
			
			var tentative_g_score = g_score[current] + 1
			
			if not g_score.has(neighbor) or tentative_g_score < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + heuristic(neighbor, goal)
				
				if neighbor not in open_set:
					open_set.append(neighbor)
	
	# No path found
	return []

static func heuristic(a: Vector2i, b: Vector2i) -> int:
	# Manhattan distance for 4-directional movement
	return abs(a.x - b.x) + abs(a.y - b.y)

static func get_lowest_f_score(open_set: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var lowest = open_set[0]
	var lowest_score = f_score.get(lowest, INF)
	
	for node in open_set:
		var score = f_score.get(node, INF)
		if score < lowest_score:
			lowest = node
			lowest_score = score
	
	return lowest

static func reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path
