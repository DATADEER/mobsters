extends Node2D

const GRID_WIDTH = 32
const GRID_HEIGHT = 32

# Tile type constants
enum TileType { EMPTY, HQ, STORE }

# Store state constants
enum StoreState { NEUTRAL, OWNED, CAPTURING }

# Player constants
enum PlayerID { PLAYER_1, PLAYER_2, PLAYER_3, PLAYER_4 }

# Seed system
var map_seed: int = 0
var rng: RandomNumberGenerator

var tilemap: TileMap
var tile_set: TileSet
var colored_tiles: Dictionary = {}  # For player-owned tiles

# Player system
var players: Array[Dictionary] = []
var player_mobsters: Array[Mobster] = []
var player_mobster: Mobster  # Legacy reference to Player 1's mobster for compatibility
var player_colors: Array[Color] = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
var player_owned_tiles: Dictionary = {}  # PlayerID -> Array[Vector2i]
var player_money: Dictionary = {}  # PlayerID -> int

var store_states: Dictionary = {}  # Vector2i -> StoreState
var capturing_stores: Dictionary = {}  # Vector2i -> capture_timer
var capture_duration: float = 10.0
var capturable_indicators: Dictionary = {}  # Vector2i -> Sprite2D for visual feedback
var capture_progress_indicators: Dictionary = {}  # Vector2i -> Sprite2D for capture progress

# Money system (legacy - kept for compatibility, will use player_money)
var money: int = 100
var money_per_store_per_cycle: int = 10
var income_cycle_duration: float = 30.0
var income_timer: float = 0.0

# Store upgrade system
var store_upgrade_levels: Dictionary = {}  # Vector2i -> int (1-5)
const MAX_UPGRADE_LEVEL: int  = 5
const BASE_UPGRADE_COST: int = 50
var upgrade_cost_multiplier: float = 2.0
var upgrade_income_multiplier: float = 1.5

# UI elements
var money_label: Label
var money_container: Control
var upgrade_ui_panel: Control
var store_upgrade_indicators: Dictionary = {}  # Vector2i -> Label for upgrade level display

# Debug coordinate display
var coordinate_labels: Dictionary = {}  # Vector2i -> Label for coordinate display
var coordinates_visible: bool = false


func _ready():
	setup_seed()
	initialize_players()
	create_tileset()
	create_tilemap()
	create_tile_grid()
	initialize_store_states()
	add_colored_tiles()
	create_all_mobsters()
	center_camera_on_hq()
	update_capturable_visual_feedback()
	create_money_ui()

func _process(delta):
	update_capturing_stores(delta)
	update_capture_progress_visuals()
	check_capture_interruptions()
	update_income_timer(delta)

func setup_seed(seed_value: int = 0):
	if seed_value == 0:
		map_seed = randi()
	else:
		map_seed = seed_value
	
	rng = RandomNumberGenerator.new()
	rng.seed = map_seed
	print("Map seed: ", map_seed)

func initialize_players():
	# Initialize player data structures
	for i in range(4):
		var player_id = PlayerID.values()[i]
		player_owned_tiles[player_id] = []
		player_money[player_id] = 100
	
	# Set Player 1's money to legacy money variable for compatibility
	money = player_money[PlayerID.PLAYER_1]

func get_hq_positions() -> Array[Vector2i]:
	return [
		Vector2i(8, 8),   # Player 1 - top-left quadrant
		Vector2i(24, 8),  # Player 2 - top-right quadrant
		Vector2i(8, 24),  # Player 3 - bottom-left quadrant
		Vector2i(24, 24)  # Player 4 - bottom-right quadrant
	]

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
	var occupied_positions: Dictionary = {}
	var hq_positions = get_hq_positions()
	
	# 1. Place 4 HQs in quadrants
	for i in range(4):
		var hq_pos = hq_positions[i]
		tilemap.set_cell(0, hq_pos, TileType.HQ, Vector2i(0, 0))
		occupied_positions[hq_pos] = true
	
	# 2. Ensure each HQ has at least 2 adjacent stores
	for hq_pos in hq_positions:
		ensure_hq_adjacent_stores(hq_pos, occupied_positions)
	
	# 3. Fill remaining tiles with procedural generation
	fill_remaining_tiles_procedurally(occupied_positions)
	
	# 4. Validate connectivity
	ensure_store_connectivity()

func ensure_hq_adjacent_stores(hq_pos: Vector2i, occupied_positions: Dictionary):
	var adjacent_positions = get_orthogonal_neighbors(hq_pos)
	
	# Place stores at ALL adjacent positions for proper gameplay
	for adj_pos in adjacent_positions:
		if is_valid_position(adj_pos) and not occupied_positions.has(adj_pos):
			tilemap.set_cell(0, adj_pos, TileType.STORE, Vector2i(0, 0))
			occupied_positions[adj_pos] = true

func fill_remaining_tiles_procedurally(occupied_positions: Dictionary):
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			if not occupied_positions.has(pos):
				# 70% stores, 30% empty (seeded)
				if rng.randf() < 0.7:
					tilemap.set_cell(0, pos, TileType.STORE, Vector2i(0, 0))
				else:
					tilemap.set_cell(0, pos, TileType.EMPTY, Vector2i(0, 0))

func get_orthogonal_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(pos.x - 1, pos.y),  # Left
		Vector2i(pos.x + 1, pos.y),  # Right
		Vector2i(pos.x, pos.y - 1),  # Up
		Vector2i(pos.x, pos.y + 1)   # Down
	]

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

func ensure_store_connectivity():
	# Validate each store has at least 1 orthogonal neighbor
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			var tile_type = tilemap.get_cell_source_id(0, pos)
			
			if tile_type == TileType.STORE:
				var has_neighbor = false
				for neighbor_pos in get_orthogonal_neighbors(pos):
					if is_valid_position(neighbor_pos):
						var neighbor_type = tilemap.get_cell_source_id(0, neighbor_pos)
						if neighbor_type == TileType.STORE or neighbor_type == TileType.HQ:
							has_neighbor = true
							break
				
				# If isolated, convert a nearby empty tile to store
				if not has_neighbor:
					fix_isolated_store(pos)

func fix_isolated_store(store_pos: Vector2i):
	# Find a nearby empty tile and convert it to store
	for neighbor_pos in get_orthogonal_neighbors(store_pos):
		if is_valid_position(neighbor_pos):
			var neighbor_type = tilemap.get_cell_source_id(0, neighbor_pos)
			if neighbor_type == TileType.EMPTY:
				tilemap.set_cell(0, neighbor_pos, TileType.STORE, Vector2i(0, 0))
				break

func add_colored_tiles():
	var hq_positions = get_hq_positions()
	
	# Add colored HQs for all 4 players
	for i in range(4):
		var player_id = PlayerID.values()[i]
		var hq_pos = hq_positions[i]
		var color = player_colors[i]
		
		create_colored_tile(hq_pos, TileType.HQ, color)
		player_owned_tiles[player_id].append(hq_pos)

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

func create_all_mobsters():
	var mobster_scene = preload("res://Mobster.tscn")
	var hq_positions = get_hq_positions()
	var mobster_colors = [
		Mobster.PlayerColor.RED,
		Mobster.PlayerColor.BLUE, 
		Mobster.PlayerColor.GREEN,
		Mobster.PlayerColor.YELLOW
	]
	
	player_mobsters.resize(4)
	
	for i in range(4):
		var mobster = mobster_scene.instantiate()
		var hq_pos = hq_positions[i]
		var hq_world_pos = tilemap.map_to_local(hq_pos)
		
		mobster.tilemap_ref = tilemap
		mobster.set_tile_position(hq_pos, hq_world_pos)
		mobster.set_player_color(mobster_colors[i])
		
		# Only Player 1 (index 0) gets input handling
		if i == 0:
			mobster.mobster_clicked.connect(_on_mobster_clicked)
			mobster.movement_finished.connect(_on_mobster_movement_finished)
		
		add_child(mobster)
		player_mobsters[i] = mobster
	
	# Keep legacy reference to Player 1's mobster for compatibility
	player_mobster = player_mobsters[0]

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_tile_left_click(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			handle_tile_right_click(event.global_position)

func handle_tile_left_click(screen_pos: Vector2):
	# Convert screen position to world position using camera
	var camera = get_node("Camera2D")
	var world_pos = screen_pos
	if camera:
		world_pos = camera.get_global_mouse_position()
	
	var tile_pos = tilemap.local_to_map(world_pos)
	
	print("Left-clicked tile: ", tile_pos)
	print("Is owned: ", is_tile_owned(tile_pos))
	
	# Check if clicking on an owned store to show upgrade UI
	if is_tile_owned(tile_pos) and get_tile_type_at(tile_pos) == TileType.STORE:
		show_upgrade_ui(tile_pos)
		return

func handle_tile_right_click(screen_pos: Vector2):
	# Convert screen position to world position using camera
	var camera = get_node("Camera2D")
	var world_pos = screen_pos
	if camera:
		world_pos = camera.get_global_mouse_position()
	
	var tile_pos = tilemap.local_to_map(world_pos)
	
	print("Right-clicked tile: ", tile_pos)
	print("Moving mobster to: ", tile_pos)
	player_mobster.move_to_tile(tile_pos, tilemap, GRID_WIDTH, GRID_HEIGHT)

func is_adjacent_to_mobster(tile_pos: Vector2i) -> bool:
	var mobster_pos = player_mobster.current_tile_pos
	var diff = tile_pos - mobster_pos
	return abs(diff.x) <= 1 and abs(diff.y) <= 1 and (diff.x != 0 or diff.y != 0)

func is_tile_owned(tile_pos: Vector2i) -> bool:
	return tile_pos in player_owned_tiles[PlayerID.PLAYER_1]

func _on_mobster_clicked(_mobster: Mobster):
	print("Mobster clicked!")

func _on_mobster_movement_finished(_mobster: Mobster, new_tile_pos: Vector2i):
	print("Mobster moved to: ", new_tile_pos)
	
	# Auto-start capture if mobster moved onto a capturable store
	if is_store_capturable(new_tile_pos):
		print("Auto-starting capture of store at: ", new_tile_pos)
		start_store_capture(new_tile_pos)

func center_camera_on_hq():
	var camera = get_node("Camera2D")
	if camera:
		# Center camera on Player 1's HQ
		var player1_hq_pos = get_hq_positions()[0]  # Player 1's HQ at (8, 8)
		var hq_world_pos = tilemap.map_to_local(player1_hq_pos)
		
		# Set up camera bounds before positioning
		camera.set_tilemap_bounds(GRID_WIDTH, GRID_HEIGHT, tilemap)
		camera.global_position = hq_world_pos

func initialize_store_states():
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_pos = Vector2i(x, y)
			var tile_type = get_tile_type_at(cell_pos)
			if tile_type == TileType.STORE:
				store_states[cell_pos] = StoreState.NEUTRAL

func get_tile_type_at(cell_pos: Vector2i) -> TileType:
	# Use tilemap to determine actual tile type
	var tile_source_id = tilemap.get_cell_source_id(0, cell_pos)
	if tile_source_id == TileType.HQ:
		return TileType.HQ
	elif tile_source_id == TileType.STORE:
		return TileType.STORE
	elif tile_source_id == TileType.EMPTY:
		return TileType.EMPTY
	else:
		return TileType.EMPTY  # Default fallback

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
	player_owned_tiles[PlayerID.PLAYER_1].append(store_pos)
	create_colored_tile(store_pos, TileType.STORE, Color.RED)
	store_upgrade_levels[store_pos] = 1  # Initialize with level 1
	create_upgrade_level_indicator(store_pos, 1)
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
		if adjacent_pos in player_owned_tiles[PlayerID.PLAYER_1]:
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

func update_income_timer(delta):
	income_timer += delta
	if income_timer >= income_cycle_duration:
		generate_income()
		income_timer = 0.0

func generate_income():
	var owned_stores = get_owned_stores()
	var total_income = 0
	
	for store_pos in owned_stores:
		var store_level = store_upgrade_levels.get(store_pos, 1)
		var store_income = get_store_income(store_level)
		total_income += store_income
	
	money += total_income
	update_money_display()
	print("Generated income: $", total_income, " from ", owned_stores.size(), " stores. Total money: $", money)

func get_owned_stores() -> Array[Vector2i]:
	var owned_stores: Array[Vector2i] = []
	for store_pos in store_states.keys():
		if store_states[store_pos] == StoreState.OWNED:
			owned_stores.append(store_pos)
	return owned_stores


func get_income_per_cycle() -> int:
	var owned_stores = get_owned_stores()
	var total_income = 0
	
	for store_pos in owned_stores:
		var store_level = store_upgrade_levels.get(store_pos, 1)
		var store_income = get_store_income(store_level)
		total_income += store_income
	
	return total_income

func create_money_ui():
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	money_container = Control.new()
	money_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	money_container.offset_bottom = 50  # Set height to 50px
	money_container.mouse_entered.connect(_on_money_hover_enter)
	money_container.mouse_exited.connect(_on_money_hover_exit)
	canvas_layer.add_child(money_container)
	
	# Add solid background to money container
	var money_bg = Panel.new()
	money_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var money_style_box = StyleBoxFlat.new()
	money_style_box.bg_color = Color(0.1, 0.1, 0.1, 1.0)  # Solid dark gray
	money_bg.add_theme_stylebox_override("panel", money_style_box)
	money_bg.z_index = -1
	money_container.add_child(money_bg)
	
	money_label = Label.new()
	money_label.text = "Money: $" + str(money)
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color.WHITE)
	money_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	money_label.add_theme_constant_override("shadow_offset_x", 2)
	money_label.add_theme_constant_override("shadow_offset_y", 2)
	money_label.position = Vector2(20, 15)  # Position within the header
	money_container.add_child(money_label)
	
	create_upgrade_ui(canvas_layer)

func update_money_display():
	if money_label:
		money_label.text = "Money: $" + str(money)

var tooltip_label: Label = null

func _on_money_hover_enter():
	if tooltip_label == null:
		tooltip_label = Label.new()
		tooltip_label.add_theme_font_size_override("font_size", 14)
		tooltip_label.add_theme_color_override("font_color", Color.YELLOW)
		tooltip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		tooltip_label.add_theme_constant_override("shadow_offset_x", 1)
		tooltip_label.add_theme_constant_override("shadow_offset_y", 1)
		tooltip_label.position = Vector2(20, 30)
		money_container.add_child(tooltip_label)
	
	tooltip_label.text = "Earning $" + str(get_income_per_cycle()) + " per cycle"

func _on_money_hover_exit():
	if tooltip_label:
		tooltip_label.queue_free()
		tooltip_label = null

func create_upgrade_ui(canvas_layer: CanvasLayer):
	upgrade_ui_panel = Control.new()
	upgrade_ui_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	upgrade_ui_panel.size = Vector2(300, 200)
	upgrade_ui_panel.position = Vector2(-150, -100)
	upgrade_ui_panel.visible = false
	canvas_layer.add_child(upgrade_ui_panel)
	
	# Background panel with border
	var background = Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_color_override("bg_color", Color.BLACK)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.WHITE
	background.add_theme_stylebox_override("panel", style_box)
	upgrade_ui_panel.add_child(background)
	
	# Title label
	var title_label = Label.new()
	title_label.text = "Store Upgrade"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.position = Vector2(20, 20)
	upgrade_ui_panel.add_child(title_label)
	
	# Info label
	var info_label = Label.new()
	info_label.name = "InfoLabel"
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_label.position = Vector2(20, 50)
	info_label.size = Vector2(260, 60)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_ui_panel.add_child(info_label)
	
	# Upgrade button
	var upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.text = "UPGRADE"
	upgrade_button.position = Vector2(20, 120)
	upgrade_button.size = Vector2(120, 40)
	upgrade_button.add_theme_font_size_override("font_size", 16)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	upgrade_ui_panel.add_child(upgrade_button)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.position = Vector2(160, 120)
	close_button.size = Vector2(120, 40)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(_on_close_upgrade_ui)
	upgrade_ui_panel.add_child(close_button)

var current_upgrade_store_pos: Vector2i

func show_upgrade_ui(store_pos: Vector2i):
	current_upgrade_store_pos = store_pos
	var current_level = store_upgrade_levels.get(store_pos, 1)
	var upgrade_cost = get_upgrade_cost(current_level)
	var current_income = get_store_income(current_level)
	var next_income = get_store_income(current_level + 1)
	
	var info_label = upgrade_ui_panel.get_node("InfoLabel")
	var upgrade_button = upgrade_ui_panel.get_node("UpgradeButton")
	
	if current_level >= MAX_UPGRADE_LEVEL:
		info_label.text = "Store Level: " + str(current_level) + " (MAX)\nIncome: $" + str(current_income) + " per cycle\n\nThis store is fully upgraded!"
		upgrade_button.disabled = true
		upgrade_button.text = "MAX LEVEL"
	else:
		info_label.text = "Store Level: " + str(current_level) + "\nCurrent Income: $" + str(current_income) + " per cycle\nNext Level Income: $" + str(next_income) + " per cycle\n\nUpgrade Cost: $" + str(upgrade_cost)
		upgrade_button.disabled = money < upgrade_cost
		upgrade_button.text = "UPGRADE ($" + str(upgrade_cost) + ")"
	
	upgrade_ui_panel.visible = true

func _on_upgrade_button_pressed():
	upgrade_store(current_upgrade_store_pos)
	_on_close_upgrade_ui()

func _on_close_upgrade_ui():
	upgrade_ui_panel.visible = false

func get_upgrade_cost(current_level: int) -> int:
	return int(BASE_UPGRADE_COST * pow(upgrade_cost_multiplier, current_level - 1))

func get_store_income(level: int) -> int:
	return int(money_per_store_per_cycle * pow(upgrade_income_multiplier, level - 1))

func create_upgrade_level_indicator(store_pos: Vector2i, level: int):
	var indicator = Label.new()
	indicator.text = str(level)
	indicator.add_theme_font_size_override("font_size", 12)
	indicator.add_theme_color_override("font_color", Color.YELLOW)
	indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	indicator.add_theme_constant_override("shadow_offset_x", 1)
	indicator.add_theme_constant_override("shadow_offset_y", 1)
	
	var store_world_pos = tilemap.map_to_local(store_pos)
	indicator.position = store_world_pos + Vector2(10, -20)  # Top-right corner of tile
	indicator.z_index = 3
	
	add_child(indicator)
	store_upgrade_indicators[store_pos] = indicator

func update_upgrade_level_indicator(store_pos: Vector2i, new_level: int):
	if store_pos in store_upgrade_indicators:
		store_upgrade_indicators[store_pos].text = str(new_level)

func remove_upgrade_level_indicator(store_pos: Vector2i):
	if store_pos in store_upgrade_indicators:
		store_upgrade_indicators[store_pos].queue_free()
		store_upgrade_indicators.erase(store_pos)

func upgrade_store(store_pos: Vector2i) -> bool:
	var current_level = store_upgrade_levels.get(store_pos, 1)
	
	if current_level >= MAX_UPGRADE_LEVEL:
		print("Store already at max level: ", current_level)
		return false
	
	var upgrade_cost = get_upgrade_cost(current_level)
	if money < upgrade_cost:
		print("Not enough money for upgrade. Need: ", upgrade_cost, " Have: ", money)
		return false
	
	# Perform upgrade
	money -= upgrade_cost
	var new_level = current_level + 1
	store_upgrade_levels[store_pos] = new_level
	
	# Update visuals
	update_upgrade_level_indicator(store_pos, new_level)
	update_money_display()
	
	print("Store upgraded to level ", new_level, " at position ", store_pos, " for $", upgrade_cost)
	return true

func toggle_coordinate_display():
	coordinates_visible = !coordinates_visible
	
	if coordinates_visible:
		create_coordinate_labels()
	else:
		clear_coordinate_labels()

func create_coordinate_labels():
	# Create labels directly in the scene
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			var label = Label.new()
			label.text = str(pos.x) + "," + str(pos.y)
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color.CYAN)
			label.add_theme_color_override("font_shadow_color", Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			
			# Position label at tile center in world coordinates
			var world_pos = tilemap.map_to_local(pos)
			label.position = world_pos - Vector2(12, 8)  # Offset to center text on tile
			label.z_index = 100  # High z-index to be on top
			
			add_child(label)
			coordinate_labels[pos] = label

func clear_coordinate_labels():
	for label in coordinate_labels.values():
		label.queue_free()
	coordinate_labels.clear()
