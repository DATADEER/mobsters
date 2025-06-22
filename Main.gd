extends Node2D

const GRID_WIDTH = 32
const GRID_HEIGHT = 32

# Tile type constants
enum TileType { EMPTY, HQ, STORE }

# Store state constants
enum StoreState { NEUTRAL, OWNED, CAPTURING }

var tilemap: TileMap
var tile_set: TileSet
var colored_tiles: Dictionary = {}  # For player-owned tiles
var player_mobster: Mobster
var owned_tiles: Array[Vector2i] = []  # Tiles owned by player
var store_states: Dictionary = {}  # Vector2i -> StoreState
var capturing_stores: Dictionary = {}  # Vector2i -> capture_timer
var capture_duration: float = 10.0
var capturable_indicators: Dictionary = {}  # Vector2i -> Sprite2D for visual feedback
var capture_progress_indicators: Dictionary = {}  # Vector2i -> Sprite2D for capture progress

func _ready():
	create_tileset()
	create_tilemap()
	create_tile_grid()
	initialize_store_states()
	add_colored_tiles()
	create_player_mobster()
	center_camera_on_hq()
	update_capturable_visual_feedback()

func _process(delta):
	update_capturing_stores(delta)
	update_capture_progress_visuals()
	check_capture_interruptions()

func create_tileset():
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	
	# Create atlas sources for each tile type
	var empty_source = TileSetAtlasSource.new()
	empty_source.texture = load("res://assets/tiles/tile_empty.png")
	empty_source.texture_region_size = Vector2i(32, 32)
	empty_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(empty_source, TileType.EMPTY)
	
	var hq_source = TileSetAtlasSource.new()
	hq_source.texture = load("res://assets/tiles/hq_base.png")
	hq_source.texture_region_size = Vector2i(32, 32)
	hq_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(hq_source, TileType.HQ)
	
	var store_source = TileSetAtlasSource.new()
	store_source.texture = load("res://assets/tiles/store_generic.png")
	store_source.texture_region_size = Vector2i(32, 32)
	store_source.create_tile(Vector2i(0, 0))
	tile_set.add_source(store_source, TileType.STORE)

func create_tilemap():
	tilemap = TileMap.new()
	tilemap.tile_set = tile_set
	add_child(tilemap)

func create_tile_grid():
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_pos = Vector2i(x, y)
			
			# Determine tile type
			if x == center_x and y == center_y:
				# HQ tile in center
				tilemap.set_cell(0, cell_pos, TileType.HQ, Vector2i(0, 0))
			elif (x == center_x - 1 and y == center_y) or (x == center_x + 1 and y == center_y) or (x == center_x and y == center_y - 1) or (x == center_x and y == center_y + 1):
				# Store tiles adjacent to HQ
				tilemap.set_cell(0, cell_pos, TileType.STORE, Vector2i(0, 0))
			elif (x + y) % 3 == 0:  # Mix in some empty tiles
				# Empty tiles scattered throughout
				tilemap.set_cell(0, cell_pos, TileType.EMPTY, Vector2i(0, 0))
			else:
				# Store tiles everywhere else
				tilemap.set_cell(0, cell_pos, TileType.STORE, Vector2i(0, 0))

func add_colored_tiles():
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	
	# Add red-tinted HQ
	var hq_pos = Vector2i(center_x, center_y)
	create_colored_tile(hq_pos, TileType.HQ, Color.RED)
	owned_tiles.append(hq_pos)

func create_colored_tile(cell_pos: Vector2i, tile_type: TileType, color: Color):
	var sprite = Sprite2D.new()
	
	# Set texture based on tile type
	match tile_type:
		TileType.HQ:
			sprite.texture = load("res://assets/tiles/hq_base.png")
		TileType.STORE:
			sprite.texture = load("res://assets/tiles/store_generic.png")
		TileType.EMPTY:
			sprite.texture = load("res://assets/tiles/tile_empty.png")
	
	# Position and color the sprite
	sprite.position = tilemap.map_to_local(cell_pos)
	sprite.modulate = color
	sprite.z_index = 1  # Above the tilemap
	
	add_child(sprite)
	colored_tiles[cell_pos] = sprite

func create_player_mobster():
	var mobster_scene = preload("res://Mobster.tscn")
	player_mobster = mobster_scene.instantiate()
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	var hq_pos = Vector2i(center_x, center_y)
	var hq_world_pos = tilemap.map_to_local(hq_pos)
	
	player_mobster.tilemap_ref = tilemap
	player_mobster.set_tile_position(hq_pos, hq_world_pos)
	player_mobster.set_player_color(Mobster.PlayerColor.RED)
	player_mobster.mobster_clicked.connect(_on_mobster_clicked)
	player_mobster.movement_finished.connect(_on_mobster_movement_finished)
	
	add_child(player_mobster)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_tile_click(event.global_position)

func handle_tile_click(screen_pos: Vector2):
	# Convert screen position to world position using camera
	var camera = get_node("Camera2D")
	var world_pos = screen_pos
	if camera:
		world_pos = camera.get_global_mouse_position()
	
	var tile_pos = tilemap.local_to_map(world_pos)
	var mobster_pos = player_mobster.current_tile_pos
	
	print("Clicked tile: ", tile_pos)
	print("Mobster position: ", mobster_pos)
	print("Is adjacent: ", is_adjacent_to_mobster(tile_pos))
	print("Is owned: ", is_tile_owned(tile_pos))
	print("Is capturable: ", is_store_capturable(tile_pos))
	
	# Check if mobster is on a capturable store and try to capture
	if mobster_pos == tile_pos and is_store_capturable(tile_pos):
		start_store_capture(tile_pos)
		return
	
	# Otherwise, move mobster to clicked tile
	print("Moving mobster to: ", tile_pos)
	player_mobster.move_to_tile(tile_pos, tilemap, GRID_WIDTH, GRID_HEIGHT)

func is_adjacent_to_mobster(tile_pos: Vector2i) -> bool:
	var mobster_pos = player_mobster.current_tile_pos
	var diff = tile_pos - mobster_pos
	return abs(diff.x) <= 1 and abs(diff.y) <= 1 and (diff.x != 0 or diff.y != 0)

func is_tile_owned(tile_pos: Vector2i) -> bool:
	return tile_pos in owned_tiles

func _on_mobster_clicked(mobster: Mobster):
	print("Mobster clicked!")

func _on_mobster_movement_finished(mobster: Mobster, new_tile_pos: Vector2i):
	print("Mobster moved to: ", new_tile_pos)

func center_camera_on_hq():
	var camera = get_node("Camera2D")
	if camera:
		var center_x = GRID_WIDTH / 2
		var center_y = GRID_HEIGHT / 2
		var hq_world_pos = tilemap.map_to_local(Vector2i(center_x, center_y))
		camera.global_position = hq_world_pos

func initialize_store_states():
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_pos = Vector2i(x, y)
			var tile_type = get_tile_type_at(cell_pos)
			if tile_type == TileType.STORE:
				store_states[cell_pos] = StoreState.NEUTRAL

func get_tile_type_at(cell_pos: Vector2i) -> TileType:
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	
	if cell_pos.x == center_x and cell_pos.y == center_y:
		return TileType.HQ
	elif (cell_pos.x == center_x - 1 and cell_pos.y == center_y) or (cell_pos.x == center_x + 1 and cell_pos.y == center_y) or (cell_pos.x == center_x and cell_pos.y == center_y - 1) or (cell_pos.x == center_x and cell_pos.y == center_y + 1):
		return TileType.STORE
	elif (cell_pos.x + cell_pos.y) % 3 == 0:
		return TileType.EMPTY
	else:
		return TileType.STORE

func update_capturing_stores(delta):
	for store_pos in capturing_stores.keys():
		capturing_stores[store_pos] -= delta
		if capturing_stores[store_pos] <= 0:
			complete_store_capture(store_pos)
			capturing_stores.erase(store_pos)

func start_store_capture(store_pos: Vector2i):
	if not is_store_capturable(store_pos):
		print("Store not capturable: ", store_pos)
		return false
	
	if player_mobster.current_tile_pos != store_pos:
		print("Mobster must be on store to capture it")
		return false
	
	store_states[store_pos] = StoreState.CAPTURING
	capturing_stores[store_pos] = capture_duration
	print("Starting capture of store at: ", store_pos, " (", capture_duration, " seconds)")
	update_capturable_visual_feedback()
	create_capture_progress_indicator(store_pos)
	return true

func complete_store_capture(store_pos: Vector2i):
	store_states[store_pos] = StoreState.OWNED
	owned_tiles.append(store_pos)
	create_colored_tile(store_pos, TileType.STORE, Color.RED)
	print("Store captured at: ", store_pos)
	update_capturable_visual_feedback()
	remove_capture_progress_indicator(store_pos)

func is_store_capturable(store_pos: Vector2i) -> bool:
	var tile_type = get_tile_type_at(store_pos)
	if tile_type != TileType.STORE:
		return false
	
	var store_state = store_states.get(store_pos, StoreState.NEUTRAL)
	if store_state == StoreState.OWNED:
		return false
	
	return is_adjacent_to_owned_territory(store_pos)

func is_adjacent_to_owned_territory(store_pos: Vector2i) -> bool:
	var directions = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)
	]
	
	for direction in directions:
		var adjacent_pos = store_pos + direction
		if adjacent_pos in owned_tiles:
			return true
	
	return false

func update_capturable_visual_feedback():
	clear_capturable_indicators()
	
	for store_pos in store_states.keys():
		if is_store_capturable(store_pos):
			create_capturable_indicator(store_pos)

func clear_capturable_indicators():
	for indicator in capturable_indicators.values():
		indicator.queue_free()
	capturable_indicators.clear()

func create_capturable_indicator(store_pos: Vector2i):
	var indicator = Sprite2D.new()
	indicator.texture = load("res://assets/tiles/tile_adjacent.png")
	indicator.position = tilemap.map_to_local(store_pos)
	indicator.modulate = Color.RED
	indicator.z_index = 1
	
	add_child(indicator)
	capturable_indicators[store_pos] = indicator

func create_capture_progress_indicator(store_pos: Vector2i):
	var progress_bar = Sprite2D.new()
	progress_bar.texture = load("res://assets/tiles/store_generic.png")
	progress_bar.position = tilemap.map_to_local(store_pos)
	progress_bar.modulate = Color.YELLOW
	progress_bar.modulate.a = 0.8
	progress_bar.z_index = 2
	
	add_child(progress_bar)
	capture_progress_indicators[store_pos] = progress_bar

func remove_capture_progress_indicator(store_pos: Vector2i):
	if store_pos in capture_progress_indicators:
		capture_progress_indicators[store_pos].queue_free()
		capture_progress_indicators.erase(store_pos)

func update_capture_progress_visuals():
	for store_pos in capturing_stores.keys():
		if store_pos in capture_progress_indicators:
			var progress = 1.0 - (capturing_stores[store_pos] / capture_duration)
			var indicator = capture_progress_indicators[store_pos]
			indicator.scale.x = progress

func check_capture_interruptions():
	var mobster_pos = player_mobster.current_tile_pos
	var stores_to_interrupt = []
	
	for store_pos in capturing_stores.keys():
		if mobster_pos != store_pos:
			stores_to_interrupt.append(store_pos)
	
	for store_pos in stores_to_interrupt:
		interrupt_store_capture(store_pos)

func interrupt_store_capture(store_pos: Vector2i):
	print("Capture interrupted at: ", store_pos, " - mobster left the store")
	store_states[store_pos] = StoreState.NEUTRAL
	capturing_stores.erase(store_pos)
	remove_capture_progress_indicator(store_pos)
	update_capturable_visual_feedback()
