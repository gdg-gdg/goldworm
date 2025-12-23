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

# Case opening UI
var case_overlay: ColorRect
var case_container: Control
var case_strip: HBoxContainer
var case_marker: ColorRect
var case_items: Array = []
const CASE_ITEM_WIDTH := 120
const CASE_ITEM_COUNT := 40  # Total items in strip

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

	# CS:GO style case opening overlay
	_build_case_overlay()

func _build_case_overlay() -> void:
	# Dark overlay background
	case_overlay = ColorRect.new()
	case_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	case_overlay.color = Color(0, 0, 0, 0.85)
	case_overlay.visible = false
	case_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(case_overlay)

	# Container for the case opening elements
	case_container = Control.new()
	case_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	case_overlay.add_child(case_container)

	# Title label
	var title := Label.new()
	title.text = "ROLLING STRIKE PATTERN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 80
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	case_container.add_child(title)

	# Strip container with clip (masks overflow)
	var strip_clip := Control.new()
	strip_clip.clip_contents = true
	strip_clip.custom_minimum_size = Vector2(600, 100)
	strip_clip.set_anchors_preset(Control.PRESET_CENTER)
	strip_clip.position = Vector2(-300, -50)
	case_container.add_child(strip_clip)

	# The scrolling strip
	case_strip = HBoxContainer.new()
	case_strip.add_theme_constant_override("separation", 8)
	strip_clip.add_child(case_strip)

	# Center marker (arrow/line indicator)
	case_marker = ColorRect.new()
	case_marker.custom_minimum_size = Vector2(4, 120)
	case_marker.color = Color(1, 0.8, 0.2)
	case_marker.set_anchors_preset(Control.PRESET_CENTER)
	case_marker.position = Vector2(-2, -60)
	case_container.add_child(case_marker)

	# Top marker triangle
	var marker_top := ColorRect.new()
	marker_top.custom_minimum_size = Vector2(20, 20)
	marker_top.color = Color(1, 0.8, 0.2)
	marker_top.rotation = PI / 4
	marker_top.position = Vector2(-10, -75)
	case_marker.add_child(marker_top)

	# Bottom marker triangle
	var marker_bot := ColorRect.new()
	marker_bot.custom_minimum_size = Vector2(20, 20)
	marker_bot.color = Color(1, 0.8, 0.2)
	marker_bot.rotation = PI / 4
	marker_bot.position = Vector2(-10, 115)
	case_marker.add_child(marker_bot)

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

	# Roll pattern instantly (no animation for CPU)
	GameState._roll_pattern()
	var pattern: Dictionary = GameState.current_pattern

	# Show what pattern they're using
	status_label.text = "ENEMY TURN"
	roll_label.text = pattern["name"]
	roll_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	incoming_label.text = "Enemy using: " + pattern["name"]

	# AI chooses strike
	var worm_shapes := GameState.get_worm_shapes_for_ai()
	var revealed: Dictionary = GameState.player_board["revealed"]
	var choice := AI.choose_strike(pattern, revealed, worm_shapes)

	# Apply rotation
	GameState.current_pattern_rotation = choice["rotation"]
	var anchor: Vector2i = choice["anchor"]

	# Play targeting scan animation on player grid
	await _play_targeting_animation(anchor)

	# Show final target
	incoming_label.text = "INCOMING!"
	_highlight_strike_preview(anchor, player_cells)
	await get_tree().create_timer(0.3).timeout

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

	# Player's turn - roll new pattern with case animation
	await get_tree().create_timer(0.3).timeout
	await _play_roll_animation()
	_update_ui()
	input_locked = false

func _play_targeting_animation(final_anchor: Vector2i) -> void:
	# Scan across grid with fake targets before landing on real one
	var scan_positions: Array = []

	# Generate 4-6 random positions to "consider"
	var num_scans := randi_range(4, 6)
	for i in range(num_scans):
		scan_positions.append(Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE))

	# Scan through fake positions
	for pos in scan_positions:
		_highlight_strike_preview(pos, player_cells)
		await get_tree().create_timer(0.12).timeout
		_update_player_grid()  # Reset to normal

	# Brief pause before final target
	await get_tree().create_timer(0.1).timeout

func _play_roll_animation() -> void:
	# Decide the winning pattern first
	GameState._roll_pattern()
	var winning_pattern: Dictionary = GameState.current_pattern

	# Build the strip with random patterns, placing winner near the end
	_populate_case_strip(winning_pattern)

	# Show overlay
	case_overlay.visible = true
	roll_label.text = "..."

	# Calculate target position (winner should land under marker)
	# Winner is at index CASE_ITEM_COUNT - 5 (near end but not last)
	var winner_index := CASE_ITEM_COUNT - 5
	var item_total_width := CASE_ITEM_WIDTH + 8  # width + separation
	var strip_center := 300.0  # half of clip width
	var target_x := -(winner_index * item_total_width) + strip_center - (CASE_ITEM_WIDTH / 2.0)

	# Add some randomness to final position (within the winning item)
	target_x += randf_range(-30, 30)

	# Starting position (off to the right)
	var start_x := 200.0
	case_strip.position.x = start_x

	# Animate over 2 seconds with easing
	var duration := 2.0
	var elapsed := 0.0
	var tick := 0.016  # ~60fps

	while elapsed < duration:
		elapsed += tick
		var t := elapsed / duration

		# Cubic ease out: 1 - (1-t)^3
		var eased_t := 1.0 - pow(1.0 - t, 3.0)

		case_strip.position.x = lerp(start_x, target_x, eased_t)
		await get_tree().create_timer(tick).timeout

	# Ensure final position
	case_strip.position.x = target_x

	# Flash the winning item
	await _flash_winning_item(winner_index)

	# Update roll label with result
	roll_label.text = winning_pattern["name"]
	roll_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))

	# Brief pause to show result
	await get_tree().create_timer(0.5).timeout

	# Hide overlay
	case_overlay.visible = false

func _populate_case_strip(winning_pattern: Dictionary) -> void:
	# Clear existing items
	for child in case_strip.get_children():
		child.queue_free()
	case_items.clear()

	var pattern_names: Array = []
	for p in GameState.PATTERN_DEFS:
		pattern_names.append(p["name"])

	# Create items - winner at position CASE_ITEM_COUNT - 5
	var winner_index := CASE_ITEM_COUNT - 5

	for i in range(CASE_ITEM_COUNT):
		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(CASE_ITEM_WIDTH, 80)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.set_corner_radius_all(8)
		style.border_color = Color(0.3, 0.3, 0.4)
		style.set_border_width_all(2)
		item.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)

		if i == winner_index:
			label.text = winning_pattern["name"]
			label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		else:
			var random_idx := randi() % pattern_names.size()
			label.text = pattern_names[random_idx]
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		item.add_child(label)
		case_strip.add_child(item)
		case_items.append(item)

func _flash_winning_item(winner_index: int) -> void:
	if winner_index < 0 or winner_index >= case_items.size():
		return

	var item: PanelContainer = case_items[winner_index]

	# Flash effect
	for j in range(3):
		var flash_style := StyleBoxFlat.new()
		flash_style.bg_color = Color(0.4, 0.35, 0.1)
		flash_style.set_corner_radius_all(8)
		flash_style.border_color = Color(1.0, 0.8, 0.2)
		flash_style.set_border_width_all(3)
		item.add_theme_stylebox_override("panel", flash_style)
		await get_tree().create_timer(0.1).timeout

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.2, 0.15)
		normal_style.set_corner_radius_all(8)
		normal_style.border_color = Color(0.8, 0.7, 0.2)
		normal_style.set_border_width_all(2)
		item.add_theme_stylebox_override("panel", normal_style)
		await get_tree().create_timer(0.1).timeout

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
