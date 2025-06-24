extends CanvasLayer

var debug_console: Control
var console_input: LineEdit
var console_output: RichTextLabel
var console_visible: bool = false
var main_node: Node

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
				var camera = main_node.get_node("Camera2D")
				if camera:
					camera.toggle_edge_scrolling()
					var status = "enabled" if camera.edge_scrolling_enabled else "disabled"
					console_log("Camera edge scrolling " + status)
				else:
					console_log("[color=red]Error: Camera not found[/color]")
			else:
				console_log("[color=red]Error: Main node not found[/color]")
		
		"clear":
			console_output.clear()
		
		_:
			console_log("[color=red]Unknown command: " + command + "[/color]")
	
	console_input.clear()
