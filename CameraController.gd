extends Camera2D

const TILE_SIZE = 32
const EDGE_SCROLL_MARGIN = 50  # Pixels from edge to start scrolling
const SCROLL_SPEED = 600  # Pixels per second
const ZOOM_SPEED = 0.1
const DEFAULT_TILES_VISIBLE = 25  # Tiles visible by default (5x5)
const MIN_TILES_VISIBLE = 9   # Most zoomed in (3x3)
const MAX_TILES_VISIBLE = 100 # Most zoomed out (10x10)

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
	
	# Apply scrolling
	if scroll_vector != Vector2.ZERO:
		global_position += scroll_vector * SCROLL_SPEED * delta / zoom.x
