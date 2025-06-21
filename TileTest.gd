extends Node2D

const GRID_WIDTH = 32
const GRID_HEIGHT = 32

# Tile type constants
enum TileType { EMPTY, HQ, STORE }

var tilemap: TileMap
var tile_set: TileSet
var colored_tiles: Dictionary = {}  # For player-owned tiles

func _ready():
	create_tileset()
	create_tilemap()
	create_tile_grid()
	add_colored_tiles()
	center_camera_on_hq()

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
	create_colored_tile(Vector2i(center_x, center_y), TileType.HQ, Color.RED)
	
	# Add red-tinted store to the right of HQ
	create_colored_tile(Vector2i(center_x + 1, center_y), TileType.STORE, Color.RED)

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

func center_camera_on_hq():
	var camera = get_node("Camera2D")
	if camera:
		var center_x = GRID_WIDTH / 2
		var center_y = GRID_HEIGHT / 2
		var hq_world_pos = tilemap.map_to_local(Vector2i(center_x, center_y))
		camera.global_position = hq_world_pos
