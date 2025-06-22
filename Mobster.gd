extends Area2D
class_name Mobster

enum PlayerColor { RED, BLUE, GREEN, YELLOW }

var player_colors = {
	PlayerColor.RED: Color.RED,
	PlayerColor.BLUE: Color.BLUE,
	PlayerColor.GREEN: Color.GREEN,
	PlayerColor.YELLOW: Color.YELLOW
}

@export var current_tile_pos: Vector2i
@export var player_color: PlayerColor = PlayerColor.RED
@export var move_speed: float = 200.0
var is_moving: bool = false
var target_position: Vector2
var path: Array[Vector2i] = []
var current_path_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D

signal mobster_clicked(mobster: Mobster)
signal movement_finished(mobster: Mobster, new_tile_pos: Vector2i)

func _ready():
	modulate = player_colors[player_color]
	z_index = 2

func _process(delta):
	if is_moving:
		move_towards_target(delta)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mobster_clicked.emit(self)

func set_player_color(color: PlayerColor):
	player_color = color
	modulate = player_colors[color]
	if sprite:
		sprite.modulate = player_colors[color]

func set_tile_position(tile_pos: Vector2i, world_pos: Vector2):
	current_tile_pos = tile_pos
	position = world_pos
	target_position = world_pos

func move_to_tile(goal_tile: Vector2i, tilemap: TileMap, grid_width: int, grid_height: int):
	# Cancel any existing movement and calculate new path
	path = Pathfinding.find_path(current_tile_pos, goal_tile, grid_width, grid_height)
	
	if path.size() > 1:  # Path found and has more than just start position
		current_path_index = 1  # Skip current position
		is_moving = true
		# Set target to next tile in path
		var next_tile = path[current_path_index]
		target_position = tilemap.map_to_local(next_tile)
		return true
	
	return false

var tilemap_ref: TileMap  # Reference to tilemap for pathfinding

func move_towards_target(delta):
	var distance = position.distance_to(target_position)
	if distance < 2.0:
		position = target_position
		
		# Update current tile position
		current_tile_pos = path[current_path_index]
		
		# Check if we've reached the final destination
		if current_path_index >= path.size() - 1:
			is_moving = false
			movement_finished.emit(self, current_tile_pos)
		else:
			# Move to next tile in path
			current_path_index += 1
			var next_tile = path[current_path_index]
			target_position = tilemap_ref.map_to_local(next_tile)
	else:
		var direction = (target_position - position).normalized()
		position += direction * move_speed * delta
