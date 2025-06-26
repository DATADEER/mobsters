extends CanvasLayer
class_name CameraController

var debug_console: Control
var console_input: LineEdit
var console_output: RichTextLabel
var console_visible: bool = false
var main_node: Node

# Paint mode variables
var paint_mode_active: bool = false
var paint_mode_player: int = 1
var paint_mode_label: Label
var original_cursor: Resource

func _ready():
	layer = 100  # High layer to be on top
	process_mode = Node.PROCESS_MODE_ALWAYS
	create_debug_console()
	
	# Wait a frame to ensure Main is ready, then get reference
	await get_tree().process_frame
	main_node = get_node("/root/Main")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT:  # ` key (tilde)
			toggle_debug_console()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and paint_mode_active:
			exit_paint_mode()
			get_viewport().set_input_as_handled()
	
	# Handle mouse clicks in paint mode
	if paint_mode_active and event is InputEventMouseButton and event.pressed:
		handle_paint_mode_click(event)
		get_viewport().set_input_as_handled()

func create_debug_console():
	debug_console = Control.new()
	debug_console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_console.visible = false
	add_child(debug_console)
	
	# Semi-transparent background
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.8)
	bg.add_theme_stylebox_override("panel", bg_style)
	debug_console.add_child(bg)
	
	# Console panel
	var console_panel = Panel.new()
	console_panel.size = Vector2(800, 400)
	console_panel.position = Vector2(50, 50)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color.WHITE
	console_panel.add_theme_stylebox_override("panel", panel_style)
	debug_console.add_child(console_panel)
	
	# Title
	var title = Label.new()
	title.text = "Debug Console (` to close)"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	console_panel.add_child(title)
	
	# Output area
	console_output = RichTextLabel.new()
	console_output.position = Vector2(10, 40)
	console_output.size = Vector2(780, 320)
	console_output.bbcode_enabled = true
	console_output.add_theme_color_override("default_color", Color.WHITE)
	console_output.add_theme_color_override("font_shadow_color", Color.BLACK)
	console_panel.add_child(console_output)
	
	# Input field
	console_input = LineEdit.new()
	console_input.position = Vector2(10, 370)
	console_input.size = Vector2(780, 25)
	console_input.placeholder_text = "Enter debug command..."
	console_input.text_submitted.connect(_on_console_command_entered)
	console_panel.add_child(console_input)
	
	console_log("Debug console initialized. Available commands:")
	console_log("  help - Show available commands")
	console_log("  money <amount> - Set money amount")
	console_log("  coords - Toggle tile coordinates display")
	console_log("  pan - Toggle camera edge scrolling")
	console_log("  assign_stores <player> - Enter paint mode to assign stores to player (1-4)")

func toggle_debug_console():
	console_visible = !console_visible
	debug_console.visible = console_visible
	if console_visible:
		console_input.grab_focus()

func console_log(text: String):
	if console_output:
		console_output.append_text(text + "\n")

func _on_console_command_entered(command: String):
	console_log("[color=yellow]> " + command + "[/color]")
	
	var parts = command.split(" ")
	var cmd = parts[0].to_lower()
	
	match cmd:
		"help":
			console_log("Available commands:")
			console_log("  help - Show this help")
			console_log("  money <amount> - Set money amount")
			console_log("  coords - Toggle tile coordinates display")
			console_log("  pan - Toggle camera edge scrolling")
			console_log("  assign_stores <player> - Enter paint mode to assign stores to player (1-4)")
			console_log("  clear - Clear console output")
		
		"money":
			if main_node:
				if parts.size() > 1:
					var amount = parts[1].to_int()
					main_node.money = amount
					main_node.update_money_display()
					console_log("Money set to: $" + str(amount))
				else:
					console_log("Current money: $" + str(main_node.money))
		
		"coords":
			if main_node:
				main_node.toggle_coordinate_display()
				console_log("Toggled coordinate display")
			else:
				console_log("[color=red]Error: Main node not found[/color]")
		
		"pan":
			if main_node:
				var camera: CameraController = main_node.get_node("Camera2D")
				if camera:
					camera.toggle_edge_scrolling()
					var status = "enabled" if camera.edge_scrolling_enabled else "disabled"
					console_log("Camera edge scrolling " + status)
				else:
					console_log("[color=red]Error: Camera not found[/color]")
			else:
				console_log("[color=red]Error: Main node not found[/color]")
		
		"assign_stores":
			if main_node and parts.size() >= 2:
				var player_str = parts[1]
				var player_num = player_str.to_int()
				if player_num >= 1 and player_num <= 4:
					enter_paint_mode(player_num)
				else:
					console_log("[color=red]Invalid player number. Use 1-4[/color]")
			else:
				console_log("[color=red]Usage: assign_stores <player>[/color]")
				console_log("Example: assign_stores 2")
		
		"clear":
			console_output.clear()
		
		_:
			console_log("[color=red]Unknown command: " + command + "[/color]")
	
	console_input.clear()

func enter_paint_mode(player_num: int):
	paint_mode_active = true
	paint_mode_player = player_num
	
	# Hide debug console
	console_visible = false
	debug_console.visible = false
	
	# Create paint mode UI label
	create_paint_mode_label()
	
	# Change cursor to colored brush
	print("DEBUG: Attempting to set colored cursor for player ", player_num)
	
	# Try the colored approach first
	var colored_brush_texture = create_colored_brush_texture(player_num)
	if colored_brush_texture:
		print("DEBUG: Setting custom cursor with colored brush texture")
		# Set cursor with appropriate hotspot for 32x32 size (center or tip of brush)
		var hotspot = Vector2(16, 16)  # Center of 32x32 cursor
		Input.set_custom_mouse_cursor(colored_brush_texture, Input.CURSOR_ARROW, hotspot)
		
		# Verify cursor was set by checking if we can set it again
		await get_tree().process_frame
		print("DEBUG: Custom cursor set successfully")
	else:
		print("ERROR: Failed to create colored brush texture, trying alternative approach")
		# Alternative: Try using the original brush (at least this should work)
		try_alternative_cursor_approach(player_num)
	
	console_log("[color=green]Entered paint mode for Player " + str(player_num) + "[/color]")

func create_colored_brush_texture(player_num: int) -> ImageTexture:
	print("DEBUG: Creating colored brush texture for player ", player_num)
	
	# Load the original brush texture
	var brush_texture = load("res://assets/tools/brush.png") as Texture2D
	if not brush_texture:
		print("ERROR: Failed to load brush texture")
		return null
		
	var brush_image = brush_texture.get_image()
	if not brush_image:
		print("ERROR: Failed to get image from brush texture")
		return null
	
	print("DEBUG: Brush image size: ", brush_image.get_width(), "x", brush_image.get_height())
	print("DEBUG: Brush image format: ", brush_image.get_format())
	
	# Get player color from main node
	var player_color = main_node.player_colors[player_num - 1]
	print("DEBUG: Player color: ", player_color)
	
	# Create a copy of the image to modify
	var colored_image = brush_image.duplicate()
	
	# Ensure image is in RGBA8 format for pixel manipulation
	if colored_image.get_format() != Image.FORMAT_RGBA8:
		print("DEBUG: Converting image to RGBA8 format")
		colored_image.convert(Image.FORMAT_RGBA8)
	
	# Resize image to appropriate cursor size (32x32 is standard)
	var target_size = 32
	if colored_image.get_width() > target_size or colored_image.get_height() > target_size:
		print("DEBUG: Resizing cursor from ", colored_image.get_width(), "x", colored_image.get_height(), " to ", target_size, "x", target_size)
		colored_image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	
	# Apply color modulation to the image
	var width = colored_image.get_width()
	var height = colored_image.get_height()
	
	for x in range(width):
		for y in range(height):
			var pixel = colored_image.get_pixel(x, y)
			# Only colorize non-transparent pixels
			if pixel.a > 0:
				# For better coloring, use a blend approach instead of pure multiplication
				var new_pixel = Color(
					pixel.r * player_color.r,
					pixel.g * player_color.g,
					pixel.b * player_color.b,
					pixel.a
				)
				colored_image.set_pixel(x, y, new_pixel)
	
	# Create ImageTexture from the modified image
	var image_texture = ImageTexture.new()
	image_texture.set_image(colored_image)
	
	print("DEBUG: Created colored brush ImageTexture successfully")
	return image_texture

func try_alternative_cursor_approach(player_num: int):
	print("DEBUG: Trying alternative cursor approach")
	
	# Try the original brush first, but resize it too
	var brush_texture = load("res://assets/tools/brush.png")
	if brush_texture:
		print("DEBUG: Setting original brush cursor")
		
		# Create a resized version of the original brush
		var brush_image = brush_texture.get_image()
		var target_size = 32
		if brush_image.get_width() > target_size or brush_image.get_height() > target_size:
			brush_image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
			var resized_texture = ImageTexture.new()
			resized_texture.set_image(brush_image)
			brush_texture = resized_texture
		
		var hotspot = Vector2(16, 16)  # Center of 32x32 cursor
		Input.set_custom_mouse_cursor(brush_texture, Input.CURSOR_ARROW, hotspot)
		print("DEBUG: Original brush cursor set")
		
		# Since we can't color the cursor, update the paint mode label to show player color
		update_paint_mode_label_with_color(player_num)
	else:
		print("ERROR: Could not load original brush texture")
		# Fall back to a built-in cursor shape
		print("DEBUG: Falling back to built-in cursor")
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		update_paint_mode_label_with_color(player_num)

func update_paint_mode_label_with_color(player_num: int):
	if paint_mode_label and main_node:
		var player_color = main_node.player_colors[player_num - 1]
		paint_mode_label.add_theme_color_override("font_color", player_color)
		paint_mode_label.text = "Paint Mode (Player " + str(player_num) + ") - CURSOR COLOR: " + str(player_color).to_upper() + " - Press ESC to exit"

func exit_paint_mode():
	paint_mode_active = false
	
	# Remove paint mode label
	if paint_mode_label:
		paint_mode_label.queue_free()
		paint_mode_label = null
	
	# Restore original cursor
	print("DEBUG: Restoring original cursor")
	Input.set_custom_mouse_cursor(null)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	console_log("[color=yellow]Exited paint mode[/color]")

func create_paint_mode_label():
	if paint_mode_label:
		paint_mode_label.queue_free()
	
	paint_mode_label = Label.new()
	paint_mode_label.text = "Paint Mode (Player " + str(paint_mode_player) + ") - Press ESC to exit"
	paint_mode_label.add_theme_font_size_override("font_size", 16)
	paint_mode_label.add_theme_color_override("font_color", Color.WHITE)
	paint_mode_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	paint_mode_label.add_theme_constant_override("shadow_offset_x", 2)
	paint_mode_label.add_theme_constant_override("shadow_offset_y", 2)
	
	# Position in upper right corner
	paint_mode_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	paint_mode_label.position.x -= 300  # Offset from right edge
	paint_mode_label.position.y += 10   # Offset from top edge
	
	add_child(paint_mode_label)

func handle_paint_mode_click(event: InputEventMouseButton):
	if not main_node:
		return
	
	# Get tile position from mouse click
	var camera = main_node.get_node("Camera2D")
	var world_pos = event.global_position
	if camera:
		world_pos = camera.get_global_mouse_position()
	
	var tile_pos = main_node.tilemap.local_to_map(world_pos)
	
	# Check if tile position is valid
	if tile_pos.x < 0 or tile_pos.x >= main_node.GRID_WIDTH or tile_pos.y < 0 or tile_pos.y >= main_node.GRID_HEIGHT:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		handle_left_click_paint(tile_pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		handle_right_click_paint(tile_pos)

func handle_left_click_paint(tile_pos: Vector2i):
	var tile_type = main_node.get_tile_type_at(tile_pos)
	var player_id = main_node.PlayerID.values()[paint_mode_player - 1]
	
	match tile_type:
		main_node.TileType.EMPTY:
			# Convert empty tile to store, then capture it
			main_node.tilemap.set_cell(0, tile_pos, main_node.TileType.STORE, Vector2i(0, 0))
			capture_tile_for_player(tile_pos, player_id)
		
		main_node.TileType.STORE:
			var store_state = main_node.store_states.get(tile_pos, main_node.StoreState.NEUTRAL)
			if store_state == main_node.StoreState.NEUTRAL:
				# Capture neutral store
				capture_tile_for_player(tile_pos, player_id)
			elif is_tile_owned_by_player(tile_pos, player_id):
				# Upgrade owned store
				upgrade_store_for_player(tile_pos)
			else:
				# Reassign store to current player
				reassign_store_to_player(tile_pos, player_id)
		
		main_node.TileType.HQ:
			# Cannot modify HQ tiles
			pass

func handle_right_click_paint(tile_pos: Vector2i):
	var tile_type = main_node.get_tile_type_at(tile_pos)
	var player_id = main_node.PlayerID.values()[paint_mode_player - 1]
	
	match tile_type:
		main_node.TileType.STORE:
			var store_state = main_node.store_states.get(tile_pos, main_node.StoreState.NEUTRAL)
			if store_state == main_node.StoreState.OWNED:
				if is_tile_owned_by_player(tile_pos, player_id):
					# Downgrade or uncapture owned store
					downgrade_or_uncapture_store(tile_pos, player_id)
				else:
					# Uncapture store owned by different player
					uncapture_store(tile_pos)
		
		main_node.TileType.HQ:
			# Cannot modify HQ tiles
			pass

func capture_tile_for_player(tile_pos: Vector2i, player_id):
	# Use existing capture logic but bypass normal restrictions
	main_node.store_states[tile_pos] = main_node.StoreState.OWNED
	main_node.player_owned_tiles[player_id].append(tile_pos)
	main_node.create_colored_tile(tile_pos, main_node.TileType.STORE, main_node.player_colors[paint_mode_player - 1])
	main_node.store_upgrade_levels[tile_pos] = 1
	main_node.create_upgrade_level_indicator(tile_pos, 1)
	main_node.update_capturable_visual_feedback()
	# Territory changed, mark connectivity as dirty
	main_node.mark_connectivity_dirty(player_id)

func reassign_store_to_player(tile_pos: Vector2i, player_id):
	# Remove from previous owner and mark their connectivity as dirty
	for pid in main_node.PlayerID.values():
		if tile_pos in main_node.player_owned_tiles[pid]:
			main_node.player_owned_tiles[pid].erase(tile_pos)
			main_node.mark_connectivity_dirty(pid)  # Territory changed for this player
			break
	
	# Remove existing visuals
	if tile_pos in main_node.colored_tiles:
		main_node.colored_tiles[tile_pos].queue_free()
		main_node.colored_tiles.erase(tile_pos)
	
	if tile_pos in main_node.store_upgrade_indicators:
		main_node.store_upgrade_indicators[tile_pos].queue_free()
		main_node.store_upgrade_indicators.erase(tile_pos)
	
	# Assign to new player
	capture_tile_for_player(tile_pos, player_id)

func upgrade_store_for_player(tile_pos: Vector2i):
	var current_level = main_node.store_upgrade_levels.get(tile_pos, 1)
	if current_level < main_node.MAX_UPGRADE_LEVEL:
		var new_level = current_level + 1
		main_node.store_upgrade_levels[tile_pos] = new_level
		main_node.update_upgrade_level_indicator(tile_pos, new_level)

func downgrade_or_uncapture_store(tile_pos: Vector2i, _player_id):
	var current_level = main_node.store_upgrade_levels.get(tile_pos, 1)
	if current_level > 1:
		# Downgrade
		var new_level = current_level - 1
		main_node.store_upgrade_levels[tile_pos] = new_level
		main_node.update_upgrade_level_indicator(tile_pos, new_level)
	else:
		# Uncapture (set to neutral)
		uncapture_store(tile_pos)

func uncapture_store(tile_pos: Vector2i):
	# Remove from any owner and mark their connectivity as dirty
	for pid in main_node.PlayerID.values():
		if tile_pos in main_node.player_owned_tiles[pid]:
			main_node.player_owned_tiles[pid].erase(tile_pos)
			main_node.mark_connectivity_dirty(pid)  # Territory changed for this player
			break
	
	# Set to neutral state
	main_node.store_states[tile_pos] = main_node.StoreState.NEUTRAL
	
	# Remove visuals
	if tile_pos in main_node.colored_tiles:
		main_node.colored_tiles[tile_pos].queue_free()
		main_node.colored_tiles.erase(tile_pos)
	
	if tile_pos in main_node.store_upgrade_indicators:
		main_node.store_upgrade_indicators[tile_pos].queue_free()
		main_node.store_upgrade_indicators.erase(tile_pos)
	
	# Remove upgrade level
	main_node.store_upgrade_levels.erase(tile_pos)
	
	# Update visual feedback
	main_node.update_capturable_visual_feedback()

func is_tile_owned_by_player(tile_pos: Vector2i, player_id) -> bool:
	return tile_pos in main_node.player_owned_tiles[player_id]
