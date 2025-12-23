extends Control
## Main.gd - UI Controller for Garden Nukes vs Worms
## ==================================================
## Handles all UI rendering, input, and game flow coordination.

const CELL_SIZE := 60
const GRID_SIZE := 6

# Colors
const COLOR_EMPTY := Color(0.15, 0.15, 0.2)
const COLOR_WORM := Color(0.2, 0.5, 0.2)
const COLOR_WORM_END := Color(0.3, 0.6, 0.3)
const COLOR_MISS := Color(0.1, 0.2, 0.4)
const COLOR_HIT := Color(0.6, 0.15, 0.15)
const COLOR_HIT_END := Color(0.9, 0.2, 0.2)
const COLOR_PREVIEW_VALID := Color(0.3, 0.7, 0.3, 0.8)
const COLOR_PREVIEW_INVALID := Color(0.8, 0.3, 0.2, 0.8)
const COLOR_FOG := Color(0.25, 0.25, 0.3)
const COLOR_INCOMING := Color(1.0, 0.8, 0.2)

# UI References
var player_grid: Control
var cpu_grid: Control
var status_label: Label
var pattern_label: Label
var worm_select_panel: Control
var player_worm_panel: Control
var cpu_worm_panel: Control
var start_button: Button
var rotate_button: Button
var restart_button: Button
var roll_panel: PanelContainer
var roll_label: Label
var incoming_label: Label

# Grid cell buttons
var player_cells: Array = []
var cpu_cells: Array = []

# Hover state
var hover_cell: Vector2i = Vector2i(-1, -1)
var is_hovering_cpu_grid := false

# Animation state
var input_locked := false
var skip_roll := false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_ui()

func _build_ui() -> void:
	# Main container
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	add_child(main_hbox)
	
	# Left panel (player info + grid)
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_panel)
	
	var player_label := Label.new()
	player_label.text = "YOUR GRID"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(player_label)
	
	player_grid = _create_grid("player")
	left_panel.add_child(player_grid)
	
	player_worm_panel = VBoxContainer.new()
	var pwp_label := Label.new()
	pwp_label.text = "Your Worms:"
	player_worm_panel.add_child(pwp_label)
	left_panel.add_child(player_worm_panel)
	
	# Center panel (controls + status)
	var center_panel := VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.custom_minimum_size.x = 200
	main_hbox.add_child(center_panel)
	
	status_label = Label.new()
	status_label.text = "PLACEMENT PHASE"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_panel.add_child(status_label)
	
	pattern_label = Label.new()
	pattern_label.text = ""
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_panel.add_child(pattern_label)
	
	# Worm selection panel
	worm_select_panel = VBoxContainer.new()
	var ws_label := Label.new()
	ws_label.text = "Select worm to place:"
	worm_select_panel.add_child(ws_label)
	center_panel.add_child(worm_select_panel)
	
	# Buttons
	rotate_button = Button.new()
	rotate_button.text = "Rotate (R)"
	rotate_button.pressed.connect(_on_rotate_pressed)
	center_panel.add_child(rotate_button)
	
	start_button = Button.new()
	start_button.text = "Start Battle"
	start_button.pressed.connect(_on_start_pressed)
	center_panel.add_child(start_button)
	
	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_on_restart_pressed)
	center_panel.add_child(restart_button)

	# Roll panel (slot machine style)
	roll_panel = PanelContainer.new()
	var roll_style := StyleBoxFlat.new()
	roll_style.bg_color = Color(0.1, 0.1, 0.15)
	roll_style.set_corner_radius_all(8)
	roll_style.border_color = Color(0.4, 0.4, 0.5)
	roll_style.set_border_width_all(2)
	roll_panel.add_theme_stylebox_override("panel", roll_style)
	roll_panel.custom_minimum_size = Vector2(180, 60)
	center_panel.add_child(roll_panel)

	var roll_vbox := VBoxContainer.new()
	roll_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_panel.add_child(roll_vbox)

	roll_label = Label.new()
	roll_label.text = "---"
	roll_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_label.add_theme_font_size_override("font_size", 24)
	roll_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	roll_vbox.add_child(roll_label)

	# Incoming strike label
	incoming_label = Label.new()
	incoming_label.text = ""
	incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	incoming_label.add_theme_font_size_override("font_size", 16)
	incoming_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	center_panel.add_child(incoming_label)

	# Right panel (cpu info + grid)
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_panel)
	
	var cpu_label := Label.new()
	cpu_label.text = "ENEMY GRID"
	cpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_panel.add_child(cpu_label)
	
	cpu_grid = _create_grid("cpu")
	right_panel.add_child(cpu_grid)
	
	cpu_worm_panel = VBoxContainer.new()
	var cwp_label := Label.new()
	cwp_label.text = "Enemy Worms:"
	cpu_worm_panel.add_child(cwp_label)
	right_panel.add_child(cpu_worm_panel)

func _create_grid(grid_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	
	var cells_array: Array = []
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.text = ""
			cell.set_meta("grid", grid_name)
			cell.set_meta("x", x)
			cell.set_meta("y", y)
			cell.mouse_entered.connect(_on_cell_hover.bind(cell))
			cell.mouse_exited.connect(_on_cell_exit.bind(cell))
			cell.pressed.connect(_on_cell_pressed.bind(cell))
			grid.add_child(cell)
			cells_array.append(cell)
	
	if grid_name == "player":
		player_cells = cells_array
	else:
		cpu_cells = cells_array
	
	return grid

func _connect_signals() -> void:
	GameState.state_changed.connect(_update_ui)
	GameState.strike_resolved.connect(_on_strike_resolved)
	GameState.worm_destroyed.connect(_on_worm_destroyed)
	GameState.game_over.connect(_on_game_over)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_on_rotate_pressed()
		elif event.keycode == KEY_ESCAPE:
			_on_restart_pressed()

func _on_rotate_pressed() -> void:
	if input_locked:
		return
	if GameState.phase == GameState.Phase.PLACEMENT:
		GameState.placement_rotation = (GameState.placement_rotation + 90) % 360
		_update_grid_display()
	elif GameState.phase == GameState.Phase.BATTLE and GameState.current_turn == GameState.Turn.PLAYER:
		GameState.rotate_pattern()
		_update_grid_display()

func _on_start_pressed() -> void:
	if GameState.worms_to_place.is_empty():
		input_locked = true
		GameState.phase = GameState.Phase.BATTLE
		GameState.current_turn = GameState.Turn.PLAYER
		_update_ui()
		await _play_roll_animation()
		input_locked = false
		_update_ui()

func _on_restart_pressed() -> void:
	input_locked = false
	GameState.reset_game()
	hover_cell = Vector2i(-1, -1)
	roll_label.text = "---"
	incoming_label.text = ""
	_update_ui()

func _on_cell_hover(cell: Button) -> void:
	var grid_name: String = cell.get_meta("grid")
	var x: int = cell.get_meta("x")
	var y: int = cell.get_meta("y")
	hover_cell = Vector2i(x, y)
	is_hovering_cpu_grid = (grid_name == "cpu")
	_update_grid_display()

func _on_cell_exit(_cell: Button) -> void:
	hover_cell = Vector2i(-1, -1)
	is_hovering_cpu_grid = false
	_update_grid_display()

func _on_cell_pressed(cell: Button) -> void:
	if input_locked:
		return
	var grid_name: String = cell.get_meta("grid")
	var x: int = cell.get_meta("x")
	var y: int = cell.get_meta("y")
	var cell_pos := Vector2i(x, y)

	if GameState.phase == GameState.Phase.PLACEMENT:
		if grid_name == "player" and not GameState.current_worm_to_place.is_empty():
			var worm_name: String = GameState.current_worm_to_place["name"]
			if GameState.place_player_worm(worm_name, cell_pos, GameState.placement_rotation):
				_update_ui()

	elif GameState.phase == GameState.Phase.BATTLE:
		if grid_name == "cpu" and GameState.current_turn == GameState.Turn.PLAYER:
			if GameState.validate_pattern_placement(cell_pos):
				_execute_player_strike(cell_pos)

# =============================================================================
# ANIMATED STRIKE EXECUTION
# =============================================================================

func _execute_player_strike(anchor: Vector2i) -> void:
	input_locked = true

	# Show incoming warning
	incoming_label.text = "LAUNCHING STRIKE!"
	_highlight_strike_preview(anchor, cpu_cells)
	await get_tree().create_timer(0.3).timeout

	# Apply strike and get impacts
	var impacts: Array = GameState.apply_strike(GameState.Owner.PLAYER, anchor)

	# Animate impacts sequentially
	await _animate_impacts(impacts, cpu_cells)

	incoming_label.text = ""
	_update_ui()

	# Check for game over
	if GameState.phase == GameState.Phase.GAME_OVER:
		input_locked = false
		return

	# CPU turn after delay
	await get_tree().create_timer(0.4).timeout
	await _do_cpu_turn()

func _do_cpu_turn() -> void:
	if GameState.phase != GameState.Phase.BATTLE or GameState.current_turn != GameState.Turn.CPU:
		input_locked = false
		return

	# Show thinking
	status_label.text = "BATTLE PHASE\nEnemy plotting..."
	await get_tree().create_timer(0.3).timeout

	# Roll animation for CPU pattern
	await _play_roll_animation()

	# AI chooses strike
	var worm_shapes := GameState.get_worm_shapes_for_ai()
	var revealed: Dictionary = GameState.player_board["revealed"]
	var pattern: Dictionary = GameState.current_pattern
	var choice := AI.choose_strike(pattern, revealed, worm_shapes)

	# Apply rotation
	GameState.current_pattern_rotation = choice["rotation"]

	# Show targeting
	var anchor: Vector2i = choice["anchor"]
	incoming_label.text = "INCOMING ENEMY STRIKE!"
	_highlight_strike_preview(anchor, player_cells)
	await get_tree().create_timer(0.5).timeout

	# Apply strike
	var impacts: Array = GameState.apply_strike(GameState.Owner.CPU, anchor)

	# Animate impacts
	await _animate_impacts(impacts, player_cells)

	incoming_label.text = ""

	# Check game over
	if GameState.phase == GameState.Phase.GAME_OVER:
		_update_ui()
		input_locked = false
		return

	# Player's turn - roll new pattern
	await get_tree().create_timer(0.3).timeout
	await _play_roll_animation()
	_update_ui()
	input_locked = false

func _play_roll_animation() -> void:
	var pattern_names: Array = []
	for p in GameState.PATTERN_DEFS:
		pattern_names.append(p["name"])

	# Roll through patterns quickly
	var cycles := 12
	var delay := 0.05
	for i in range(cycles):
		var idx := randi() % pattern_names.size()
		roll_label.text = pattern_names[idx]
		roll_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		await get_tree().create_timer(delay).timeout
		delay += 0.02

	# Land on actual pattern
	GameState._roll_pattern()
	roll_label.text = GameState.current_pattern["name"]
	roll_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	await get_tree().create_timer(0.2).timeout

func _highlight_strike_preview(anchor: Vector2i, cells: Array) -> void:
	var pattern_cells := GameState.get_pattern_cells(anchor)
	for pos in pattern_cells:
		if pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE:
			var idx: int = pos.y * GRID_SIZE + pos.x
			var cell: Button = cells[idx]
			_style_cell(cell, COLOR_INCOMING, "!")

func _animate_impacts(impacts: Array, cells: Array) -> void:
	for impact in impacts:
		if impact["already_hit"]:
			continue

		var cell_pos: Vector2i = impact["cell"]
		var idx: int = cell_pos.y * GRID_SIZE + cell_pos.x
		var cell: Button = cells[idx]
		var result: GameState.CellState = impact["result"]

		# Flash white
		_style_cell(cell, Color.WHITE, "")
		await get_tree().create_timer(0.08).timeout

		# Show result
		var color: Color
		var text: String
		match result:
			GameState.CellState.MISS:
				color = COLOR_MISS
				text = "."
			GameState.CellState.HIT_BODY:
				color = COLOR_HIT
				text = "X"
			GameState.CellState.HIT_END:
				color = COLOR_HIT_END
				text = "E"
				incoming_label.text = "END HIT!"
			_:
				color = COLOR_EMPTY
				text = ""

		_style_cell(cell, color, text)
		await get_tree().create_timer(0.12).timeout

	_update_worm_panels()

# =============================================================================
# UI UPDATE
# =============================================================================

func _update_ui() -> void:
	_update_status()
	_update_worm_select()
	_update_worm_panels()
	_update_grid_display()
	_update_buttons()

func _update_status() -> void:
	match GameState.phase:
		GameState.Phase.PLACEMENT:
			status_label.text = "PLACEMENT PHASE\nPlace your worms on your grid"
			pattern_label.text = "Rotation: " + str(GameState.placement_rotation) + "deg"
		GameState.Phase.BATTLE:
			var turn_text := "YOUR TURN" if GameState.current_turn == GameState.Turn.PLAYER else "CPU TURN"
			status_label.text = "BATTLE PHASE\n" + turn_text
			var pattern_name: String = GameState.current_pattern.get("name", "?")
			var rot_text := str(GameState.current_pattern_rotation) + "deg" if GameState.current_pattern.get("rotatable", false) else "fixed"
			pattern_label.text = "Pattern: " + pattern_name + " (" + rot_text + ")"
		GameState.Phase.GAME_OVER:
			status_label.text = "GAME OVER"
			pattern_label.text = ""

func _update_worm_select() -> void:
	# Clear old buttons
	for child in worm_select_panel.get_children():
		if child is Button:
			child.queue_free()
	
	if GameState.phase != GameState.Phase.PLACEMENT:
		return
	
	for worm_name in GameState.worms_to_place:
		var btn := Button.new()
		btn.text = worm_name
		btn.pressed.connect(_on_worm_select.bind(worm_name))
		if not GameState.current_worm_to_place.is_empty() and GameState.current_worm_to_place["name"] == worm_name:
			btn.text = "> " + worm_name + " <"
		worm_select_panel.add_child(btn)

func _on_worm_select(worm_name: String) -> void:
	GameState.current_worm_to_place = GameState.WORM_DEFS[worm_name]
	_update_ui()

func _update_worm_panels() -> void:
	_update_worm_panel(player_worm_panel, GameState.player_board, true)
	_update_worm_panel(cpu_worm_panel, GameState.cpu_board, false)

func _update_worm_panel(panel: VBoxContainer, board: Dictionary, show_all: bool) -> void:
	# Keep first label, remove rest
	while panel.get_child_count() > 1:
		var child := panel.get_child(1)
		panel.remove_child(child)
		child.queue_free()
	
	for worm in board["worms"]:
		var lbl := Label.new()
		var segments := ""
		for i in range(worm["cells"].size()):
			var cell: Vector2i = worm["cells"][i]
			var is_end: bool = cell in worm["end_cells"]
			var is_hit: bool = worm["hit_set"].has(cell)
			
			if show_all or is_hit:
				if is_hit:
					segments += "[X]"
				else:
					segments += "[O]"
			else:
				segments += "[?]"
		
		var destroyed_text := " (DESTROYED)" if worm.get("destroyed", false) else ""
		lbl.text = worm["name"] + ": " + segments + destroyed_text
		panel.add_child(lbl)

func _update_buttons() -> void:
	start_button.visible = GameState.phase == GameState.Phase.PLACEMENT and GameState.worms_to_place.is_empty()
	rotate_button.visible = GameState.phase != GameState.Phase.GAME_OVER
	worm_select_panel.visible = GameState.phase == GameState.Phase.PLACEMENT
	roll_panel.visible = GameState.phase == GameState.Phase.BATTLE or GameState.phase == GameState.Phase.GAME_OVER

func _update_grid_display() -> void:
	_update_player_grid()
	_update_cpu_grid()

func _update_player_grid() -> void:
	for i in range(player_cells.size()):
		var cell: Button = player_cells[i]
		var x: int = i % GRID_SIZE
		var y: int = i / GRID_SIZE
		var pos := Vector2i(x, y)

		var color := COLOR_EMPTY
		var text := ""

		# Check if worm is here
		var worm := GameState.get_player_worm_at(pos)
		if not worm.is_empty():
			var is_end: bool = pos in worm["end_cells"]
			color = COLOR_WORM_END if is_end else COLOR_WORM
			text = "E" if is_end else ""

		# Check revealed state (CPU strikes)
		var state := GameState.get_player_cell_state(pos)
		match state:
			GameState.CellState.MISS:
				color = COLOR_MISS
				text = "."
			GameState.CellState.HIT_BODY:
				color = COLOR_HIT
				text = "X"
			GameState.CellState.HIT_END:
				color = COLOR_HIT_END
				text = "E"

		# Preview worm placement
		if GameState.phase == GameState.Phase.PLACEMENT and not GameState.current_worm_to_place.is_empty():
			if hover_cell.x >= 0 and not is_hovering_cpu_grid:
				var preview_cells := GameState.get_worm_preview_cells(
					GameState.current_worm_to_place["name"],
					hover_cell,
					GameState.placement_rotation
				)
				if pos in preview_cells:
					var valid := GameState.validate_worm_placement(
						GameState.player_board,
						GameState.current_worm_to_place["name"],
						hover_cell,
						GameState.placement_rotation
					)
					color = COLOR_PREVIEW_VALID if valid else COLOR_PREVIEW_INVALID

		_style_cell(cell, color, text)

func _update_cpu_grid() -> void:
	for i in range(cpu_cells.size()):
		var cell: Button = cpu_cells[i]
		var x: int = i % GRID_SIZE
		var y: int = i / GRID_SIZE
		var pos := Vector2i(x, y)

		var color := COLOR_FOG
		var text := ""

		# Check revealed state (player strikes)
		var state := GameState.get_cpu_cell_state(pos)
		match state:
			GameState.CellState.MISS:
				color = COLOR_MISS
				text = "."
			GameState.CellState.HIT_BODY:
				color = COLOR_HIT
				text = "X"
			GameState.CellState.HIT_END:
				color = COLOR_HIT_END
				text = "E"

		# Preview strike pattern (ghost stencil)
		if GameState.phase == GameState.Phase.BATTLE and GameState.current_turn == GameState.Turn.PLAYER and not input_locked:
			if hover_cell.x >= 0 and is_hovering_cpu_grid:
				var pattern_cells := GameState.get_pattern_cells(hover_cell)
				if pos in pattern_cells:
					var valid := GameState.validate_pattern_placement(hover_cell)
					if valid:
						if state == GameState.CellState.UNKNOWN:
							color = COLOR_PREVIEW_VALID
							text = "+"
						else:
							color = color.lightened(0.3)
					else:
						color = COLOR_PREVIEW_INVALID

		_style_cell(cell, color, text)

func _style_cell(cell: Button, color: Color, text: String) -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.set_corner_radius_all(4)
	stylebox.border_color = color.lightened(0.15)
	stylebox.set_border_width_all(1)
	cell.add_theme_stylebox_override("normal", stylebox)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.12)
	hover_style.set_corner_radius_all(4)
	hover_style.border_color = Color(0.8, 0.8, 0.9)
	hover_style.set_border_width_all(2)
	cell.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.1)
	pressed_style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("pressed", pressed_style)

	cell.text = text
	cell.add_theme_font_size_override("font_size", 16)
	cell.add_theme_color_override("font_color", Color.WHITE)

# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_strike_resolved(_owner: GameState.Owner, impacts: Array) -> void:
	for impact in impacts:
		if impact["already_hit"]:
			continue
		var result: GameState.CellState = impact["result"]
		match result:
			GameState.CellState.MISS:
				print("Miss at ", impact["cell"])
			GameState.CellState.HIT_BODY:
				print("Hit body at ", impact["cell"], " (", impact["worm_name"], ")")
			GameState.CellState.HIT_END:
				print("END HIT at ", impact["cell"], " (", impact["worm_name"], ")")

func _on_worm_destroyed(owner: GameState.Owner, worm_name: String) -> void:
	var target := "Enemy" if owner == GameState.Owner.PLAYER else "Your"
	print(target, " ", worm_name, " destroyed!")
	status_label.text += "\n" + target + " " + worm_name + " destroyed!"

func _on_game_over(winner: GameState.Owner) -> void:
	input_locked = false
	if winner == GameState.Owner.PLAYER:
		status_label.text = "VICTORY!\nYou destroyed all enemy worms!"
		roll_label.text = "YOU WIN!"
		roll_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "DEFEAT!\nAll your worms were destroyed!"
		roll_label.text = "GAME OVER"
		roll_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	incoming_label.text = ""
