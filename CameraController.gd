extends Camera2D

const TILE_SIZE = 32
const EDGE_SCROLL_MARGIN = 5  # Pixels from edge to start scrolling
const SCROLL_SPEED = 600  # Pixels per second
const ZOOM_SPEED = 0.1
const DEFAULT_TILES_VISIBLE = 25  # Tiles visible by default (5x5)
const MIN_TILES_VISIBLE = 9   # Most zoomed in (3x3)
const MAX_TILES_VISIBLE = 100 # Most zoomed out (10x10)

# Tilemap bounds (set by Main scene)
var tilemap_bounds: Rect2i
var tilemap_world_bounds: Rect2

var min_zoom: float
var max_zoom: float
var default_zoom: float

func _ready():
	calculate_zoom_levels()
	zoom = Vector2(default_zoom, default_zoom)
	enabled = true

func calculate_zoom_levels():
	var viewport_size = get_viewport().get_visible_rect().size
	var smaller_dimension = min(viewport_size.x, viewport_size.y)
	
	# Calculate zoom to show desired number of tiles
	# For a square grid of N tiles, we show sqrt(N) tiles per side
	default_zoom = smaller_dimension / (sqrt(DEFAULT_TILES_VISIBLE) * TILE_SIZE)
	min_zoom = smaller_dimension / (sqrt(MAX_TILES_VISIBLE) * TILE_SIZE)
	max_zoom = smaller_dimension / (sqrt(MIN_TILES_VISIBLE) * TILE_SIZE)

func _process(delta):
	handle_edge_scrolling(delta)

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
	elif event is InputEventPanGesture:
		if event.delta.y > 0:
			zoom_out()
		elif event.delta.y < 0:
			zoom_in()
	elif event is InputEventMagnifyGesture:
		if event.factor > 1.0:
			zoom_in()
		elif event.factor < 1.0:
			zoom_out()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
			zoom_in()
		elif event.keycode == KEY_MINUS:
			zoom_out()

func zoom_in():
	var new_zoom = zoom.x + ZOOM_SPEED
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func zoom_out():
	var new_zoom = zoom.x - ZOOM_SPEED
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)

func handle_edge_scrolling(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var scroll_vector = Vector2.ZERO
	
	# Check edges
	if mouse_pos.x < EDGE_SCROLL_MARGIN:
		scroll_vector.x = -1
	elif mouse_pos.x > viewport_size.x - EDGE_SCROLL_MARGIN:
		scroll_vector.x = 1
		
	if mouse_pos.y < EDGE_SCROLL_MARGIN:
		scroll_vector.y = -1
	elif mouse_pos.y > viewport_size.y - EDGE_SCROLL_MARGIN:
		scroll_vector.y = 1
	
	# Apply scrolling with bounds checking
	if scroll_vector != Vector2.ZERO:
		var new_position = global_position + scroll_vector * SCROLL_SPEED * delta / zoom.x
		global_position = clamp_camera_position(new_position)

func set_tilemap_bounds(grid_width: int, grid_height: int, tilemap: TileMap):
	tilemap_bounds = Rect2i(0, 0, grid_width, grid_height)
	
	# Convert to world coordinates
	var top_left = tilemap.map_to_local(Vector2i(0, 0))
	var bottom_right = tilemap.map_to_local(Vector2i(grid_width - 1, grid_height - 1))
	
	# Add tile size to bottom_right to get the actual boundary
	bottom_right += Vector2(TILE_SIZE, TILE_SIZE)
	
	tilemap_world_bounds = Rect2(top_left, bottom_right - top_left)

func clamp_camera_position(target_pos: Vector2) -> Vector2:
	if tilemap_world_bounds.size == Vector2.ZERO:
		return target_pos  # No bounds set yet
	
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_half_size = viewport_size / (2.0 * zoom.x)
	
	# Calculate bounds with one tile margin
	var margin = TILE_SIZE
	var min_x = tilemap_world_bounds.position.x - camera_half_size.x + margin
	var max_x = tilemap_world_bounds.end.x + camera_half_size.x - margin
	var min_y = tilemap_world_bounds.position.y - camera_half_size.y + margin  
	var max_y = tilemap_world_bounds.end.y + camera_half_size.y - margin
	
	return Vector2(
		clamp(target_pos.x, min_x, max_x),
		clamp(target_pos.y, min_y, max_y)
	)
