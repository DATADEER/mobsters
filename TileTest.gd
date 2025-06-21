extends Node2D

const TILE_SIZE = 32
const GRID_WIDTH = 7
const GRID_HEIGHT = 7

func _ready():
	create_tile_grid()

func create_tile_grid():
	var center_x = GRID_WIDTH / 2
	var center_y = GRID_HEIGHT / 2
	
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile_sprite = Sprite2D.new()
			
			# Position the tile
			tile_sprite.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			
			# Determine tile type and texture
			if x == center_x and y == center_y:
				# HQ tile in center
				tile_sprite.texture = load("res://assets/tiles/hq_base.png")
				tile_sprite.modulate = Color.RED  # Tint red for player
			elif (x == center_x - 1 and y == center_y) or (x == center_x + 1 and y == center_y) or (x == center_x and y == center_y - 1) or (x == center_x and y == center_y + 1):
				# Store tiles adjacent to HQ
				tile_sprite.texture = load("res://assets/tiles/store_generic.png")
				# Tint one store tile red (the one to the right of HQ)
				if x == center_x + 1 and y == center_y:
					tile_sprite.modulate = Color.RED
			else:
				# Store tiles everywhere else
				tile_sprite.texture = load("res://assets/tiles/store_generic.png")
			
			add_child(tile_sprite)

# Center the camera on the grid
func _process(_delta):
	if get_viewport():
		var camera = get_viewport().get_camera_2d()
		if camera:
			camera.global_position = Vector2(GRID_WIDTH * TILE_SIZE / 2, GRID_HEIGHT * TILE_SIZE / 2)