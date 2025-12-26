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

# Rarity colors by block count (0=miss, 1-7)
const RARITY_COLORS := {
	0: Color(0.3, 0.1, 0.1),      # Miss - Dark red
	1: Color(0.5, 0.5, 0.5),      # Grey
	2: Color(0.6, 0.85, 1.0),     # Light blue
	3: Color(0.3, 0.5, 1.0),      # Blue
	4: Color(0.6, 0.3, 0.9),      # Purple
	5: Color(1.0, 0.4, 0.7),      # Pink
	6: Color(1.0, 0.2, 0.2),      # Red
	7: Color(1.0, 0.85, 0.2)      # Gold
}

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
var debug_win_button: Button
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
var case_strip_clip: Control  # The clipping container for the strip
var case_marker: ColorRect
var case_items: Array = []
const CASE_ITEM_WIDTH := 120
const CASE_ITEM_COUNT := 40  # Total items in strip

# Pool selection UI (for attack patterns)
var pool_overlay: ColorRect
var pool_container: VBoxContainer
var pool_center: CenterContainer  # CenterContainer wrapper
var pool_options: Array = []  # The two pool buttons
var selected_pool: Array = []  # The chosen pool of patterns
var pool_selected := false

# StyleBox cache system (avoids per-cell allocation)
var _cell_styles: Dictionary = {}  # key: color.to_html() -> { normal, hover, pressed }
var _cell_last_state: Dictionary = {}  # key: cell instance ID -> last color hash

# Worm pool selection UI
var worm_pool_overlay: ColorRect
var worm_pool_container: VBoxContainer
var worm_pool_center: CenterContainer  # CenterContainer wrapper
var worm_pool_options: Array = []
var selected_worm_pool: Array = []
var worm_pool_selected := false
var pending_worm_def: Dictionary = {}  # The worm won from case opening (with rotatable flag)
var won_worm_instances: Dictionary = {}  # Stores won worm defs by name (with rotatable flags)

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	GameState.reset_game()
	_build_ui()
	await get_tree().process_frame  # Let containers compute sizes
	_balance_side_panels()
	_connect_signals()
	_update_ui()

	# In fast play mode, skip to first turn (pattern already rolled in GameState)
	if GameState.fast_play_mode:
		await get_tree().process_frame
		# Just display the already-rolled pattern
		var pattern: Dictionary = GameState.current_pattern
		var cell_count: int = pattern.get("cells", []).size()
		var is_miss: bool = pattern.get("is_miss", false)

		if is_miss:
			roll_label.text = pattern["name"] + " - SKIP!"
			roll_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
			incoming_label.text = "You got a " + pattern["name"] + "! Turn skipped..."
			await get_tree().create_timer(0.5).timeout
			incoming_label.text = ""
			GameState.current_turn = GameState.Turn.CPU
			_update_ui()
			await _do_cpu_turn()
		else:
			roll_label.text = pattern["name"]
			roll_label.add_theme_color_override("font_color", _get_rarity_color(cell_count))
			input_locked = false
			_update_ui()

func _balance_side_panels() -> void:
	var left := get_node_or_null("RootMargin/MainHBox/LeftPanel")
	var right := get_node_or_null("RootMargin/MainHBox/RightPanel")
	if left == null or right == null:
		return

	var w := maxi(int(left.get_combined_minimum_size().x), int(right.get_combined_minimum_size().x))
	left.custom_minimum_size.x = w
	right.custom_minimum_size.x = w

func _build_ui() -> void:
	# Root MarginContainer for consistent padding at any resolution
	var margin := MarginContainer.new()
	margin.name = "RootMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	# Main container inside the margin
	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_hbox)

	# Left panel (player info + grid)
	var left_panel := VBoxContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(left_panel)

	var player_label := Label.new()
	player_label.text = "YOUR GRID"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Fonts.apply_title(player_label, 20)
	left_panel.add_child(player_label)

	player_grid = _create_grid("player")
	player_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_panel.add_child(player_grid)

	player_worm_panel = VBoxContainer.new()
	player_worm_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pwp_label := Label.new()
	pwp_label.text = "Your Worms:"
	Fonts.apply_body(pwp_label, 14, Color(0.7, 0.8, 0.7))
	player_worm_panel.add_child(pwp_label)
	left_panel.add_child(player_worm_panel)
	
	# Center panel (controls + status)
	var center_panel := VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	center_panel.custom_minimum_size.x = 200
	main_hbox.add_child(center_panel)

	# Coins display at top
	var coins_hbox := HBoxContainer.new()
	coins_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_hbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(coins_hbox)

	var coin_icon := Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 22)
	coins_hbox.add_child(coin_icon)

	var coins_lbl := Label.new()
	coins_lbl.text = str(SaveManager.get_coins())
	Fonts.apply_body(coins_lbl, 20, Color(0.95, 0.85, 0.3))
	coins_hbox.add_child(coins_lbl)

	status_label = Label.new()
	status_label.text = "PLACEMENT PHASE"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(status_label, 16, Color(0.8, 0.9, 0.8))
	center_panel.add_child(status_label)

	pattern_label = Label.new()
	pattern_label.text = ""
	pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(pattern_label, 14, Color(0.6, 0.6, 0.7))
	center_panel.add_child(pattern_label)

	# Worm selection panel
	worm_select_panel = VBoxContainer.new()
	var ws_label := Label.new()
	ws_label.text = "Select worm to place:"
	Fonts.apply_body(ws_label, 14, Color(0.7, 0.7, 0.8))
	worm_select_panel.add_child(ws_label)
	center_panel.add_child(worm_select_panel)
	
	# Buttons
	rotate_button = Button.new()
	rotate_button.text = "Rotate (R)"
	rotate_button.pressed.connect(_on_rotate_pressed)
	Fonts.apply_button(rotate_button, 14)
	center_panel.add_child(rotate_button)

	start_button = Button.new()
	start_button.text = "Start Battle"
	start_button.pressed.connect(_on_start_pressed)
	Fonts.apply_button(start_button, 16)
	center_panel.add_child(start_button)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.pressed.connect(_on_restart_pressed)
	Fonts.apply_button(restart_button, 14)
	center_panel.add_child(restart_button)

	# Debug WIN button (only visible in debug mode)
	debug_win_button = Button.new()
	debug_win_button.text = "[DEBUG] WIN"
	Fonts.apply_button(debug_win_button, 14)
	debug_win_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	debug_win_button.pressed.connect(_on_debug_win_pressed)
	debug_win_button.visible = SaveManager.debug_mode
	center_panel.add_child(debug_win_button)

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
	Fonts.apply_body(roll_label, 24, Color(0.9, 0.7, 0.2))
	roll_vbox.add_child(roll_label)

	# Incoming strike label
	incoming_label = Label.new()
	incoming_label.text = ""
	incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(incoming_label, 16, Color(1.0, 0.6, 0.2))
	center_panel.add_child(incoming_label)

	# Right panel (cpu info + grid)
	var right_panel := VBoxContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(right_panel)

	var cpu_label := Label.new()
	cpu_label.text = "ENEMY GRID"
	cpu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cpu_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Fonts.apply_title(cpu_label, 20)
	right_panel.add_child(cpu_label)

	cpu_grid = _create_grid("cpu")
	cpu_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_panel.add_child(cpu_grid)

	cpu_worm_panel = VBoxContainer.new()
	cpu_worm_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cwp_label := Label.new()
	cwp_label.text = "Enemy Worms:"
	Fonts.apply_body(cwp_label, 14, Color(0.8, 0.7, 0.7))
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

	# Main VBox for vertical layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 20)
	case_container.add_child(main_vbox)

	# Spacer at top
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.y = 60
	main_vbox.add_child(top_spacer)

	# Title label
	var title := Label.new()
	title.text = "ROLLING STRIKE PATTERN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 28)
	main_vbox.add_child(title)

	# Strip area with marker overlay
	var strip_area := Control.new()
	strip_area.custom_minimum_size = Vector2(600, 120)
	strip_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(strip_area)

	# Strip container with clip (masks overflow) - centered in strip_area
	case_strip_clip = Control.new()
	case_strip_clip.clip_contents = true
	case_strip_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	case_strip_clip.offset_top = 10
	case_strip_clip.offset_bottom = -10
	strip_area.add_child(case_strip_clip)

	# The scrolling strip
	case_strip = HBoxContainer.new()
	case_strip.add_theme_constant_override("separation", 8)
	case_strip_clip.add_child(case_strip)

	# Center marker (arrow/line indicator) - positioned relative to strip_area
	case_marker = ColorRect.new()
	case_marker.custom_minimum_size = Vector2(4, 120)
	case_marker.color = Color(1, 0.8, 0.2)
	case_marker.anchor_left = 0.5
	case_marker.anchor_right = 0.5
	case_marker.anchor_top = 0.5
	case_marker.anchor_bottom = 0.5
	case_marker.offset_left = -2
	case_marker.offset_right = 2
	case_marker.offset_top = -60
	case_marker.offset_bottom = 60
	strip_area.add_child(case_marker)

	# Build pool selection overlay
	_build_pool_overlay()
	_build_worm_pool_overlay()

func _build_worm_pool_overlay() -> void:
	# Dark overlay for worm selection
	worm_pool_overlay = ColorRect.new()
	worm_pool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	worm_pool_overlay.color = Color(0, 0, 0, 0.9)
	worm_pool_overlay.visible = false
	worm_pool_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(worm_pool_overlay)

	# CenterContainer wrapper for proper centering
	worm_pool_center = CenterContainer.new()
	worm_pool_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	worm_pool_overlay.add_child(worm_pool_center)

	# Main container - no manual position offset needed
	worm_pool_container = VBoxContainer.new()
	worm_pool_container.custom_minimum_size = Vector2(600, 400)
	worm_pool_container.add_theme_constant_override("separation", 30)
	worm_pool_center.add_child(worm_pool_container)

	# Title
	var title := Label.new()
	title.text = "CHOOSE YOUR WORM CASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 32)
	worm_pool_container.add_child(title)

	# Options container (horizontal)
	var options_hbox := HBoxContainer.new()
	options_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	options_hbox.add_theme_constant_override("separation", 40)
	worm_pool_container.add_child(options_hbox)

	# Create two worm pool option buttons
	for i in range(2):
		var option := _create_worm_pool_option(i)
		options_hbox.add_child(option)
		worm_pool_options.append(option)

func _create_worm_pool_option(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 320)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.1)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.3, 0.5, 0.3)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	# Add margin for padding inside panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Case label
	var case_label := Label.new()
	case_label.text = "Worm Case " + str(index + 1)
	case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(case_label, 20, Color(0.7, 0.9, 0.7))
	vbox.add_child(case_label)

	# Worm preview container
	var preview_container := VBoxContainer.new()
	preview_container.add_theme_constant_override("separation", 6)
	preview_container.set_meta("preview_container", true)
	preview_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(preview_container)

	# Make it clickable
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_worm_pool_selected.bind(index))
	panel.add_child(button)

	return panel

func _build_pool_overlay() -> void:
	# Dark overlay
	pool_overlay = ColorRect.new()
	pool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pool_overlay.color = Color(0, 0, 0, 0.9)
	pool_overlay.visible = false
	pool_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pool_overlay)

	# CenterContainer wrapper for proper centering
	pool_center = CenterContainer.new()
	pool_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pool_overlay.add_child(pool_center)

	# Main container - no manual position offset needed
	pool_container = VBoxContainer.new()
	pool_container.custom_minimum_size = Vector2(600, 400)
	pool_container.add_theme_constant_override("separation", 30)
	pool_center.add_child(pool_container)

	# Title
	var title := Label.new()
	title.text = "CHOOSE YOUR CASE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 32)
	pool_container.add_child(title)

	# Options container (horizontal)
	var options_hbox := HBoxContainer.new()
	options_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	options_hbox.add_theme_constant_override("separation", 40)
	pool_container.add_child(options_hbox)

	# Create two pool option buttons
	for i in range(2):
		var option := _create_pool_option(i)
		options_hbox.add_child(option)
		pool_options.append(option)

func _create_pool_option(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 320)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	# Add margin for padding inside panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Case label
	var case_label := Label.new()
	case_label.text = "Case " + str(index + 1)
	case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(case_label, 20, Color(0.8, 0.8, 0.8))
	vbox.add_child(case_label)

	# Pattern preview container
	var preview_container := VBoxContainer.new()
	preview_container.add_theme_constant_override("separation", 6)
	preview_container.set_meta("preview_container", true)
	preview_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(preview_container)

	# Make it clickable
	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.pressed.connect(_on_pool_selected.bind(index))
	panel.add_child(button)

	return panel

func _get_rarity_color(cell_count: int) -> Color:
	var count := clampi(cell_count, 1, 7)
	return RARITY_COLORS.get(count, Color.WHITE)

func _create_shape_visual(pattern: Dictionary, size: float = 10.0) -> Control:
	# Create a visual grid showing the pattern shape
	var container := Control.new()
	var cells: Array = pattern.get("cells", [])
	var is_miss: bool = pattern.get("is_miss", false)

	# Handle miss patterns (no cells)
	if is_miss or cells.is_empty():
		var miss_label := Label.new()
		miss_label.text = "MISS"
		Fonts.apply_body(miss_label, int(size * 1.2), Color(0.8, 0.2, 0.2))
		container.add_child(miss_label)
		container.custom_minimum_size = Vector2(size * 4, size * 1.5)
		return container

	# Find bounds
	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	var width := max_x - min_x + 1
	var height := max_y - min_y + 1
	var rarity_color := _get_rarity_color(cells.size())

	container.custom_minimum_size = Vector2(width * (size + 2), height * (size + 2))

	for cell in cells:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(size, size)
		dot.color = rarity_color
		dot.position = Vector2((cell.x - min_x) * (size + 2), (cell.y - min_y) * (size + 2))
		container.add_child(dot)

	return container

func _generate_random_pool() -> Array:
	# Generate a random pool of 3-8 patterns using weighted selection
	# Each pattern has a 1/5 (20%) chance to be rotatable
	var pool: Array = []
	var pool_size := randi_range(3, 8)

	for i in range(pool_size):
		var pattern := _pick_weighted_pattern().duplicate()
		# 1/5 chance to be rotatable
		pattern["rotatable"] = (randi() % 5 == 0)
		pool.append(pattern)

	return pool

func _pick_weighted_pattern() -> Dictionary:
	# Use player's available patterns (unlocked ones + misses)
	var available_patterns := GameState.get_player_available_patterns()

	# Calculate total weight
	var total_weight := 0.0
	for pattern in available_patterns:
		total_weight += pattern.get("weight", 1.0)

	# Pick random value
	var roll := randf() * total_weight
	var cumulative := 0.0

	for pattern in available_patterns:
		cumulative += pattern.get("weight", 1.0)
		if roll <= cumulative:
			return pattern

	# Fallback
	if available_patterns.size() > 0:
		return available_patterns[0]
	return GameState.PATTERN_DEFS[0]

func _show_pool_selection() -> void:
	pool_selected = false

	# Generate two random pools
	var pools: Array = [_generate_random_pool(), _generate_random_pool()]

	# Update pool option displays
	for i in range(2):
		var panel: PanelContainer = pool_options[i]
		panel.set_meta("pool", pools[i])

		# Find the preview container (panel -> margin -> vbox -> preview_container)
		var margin: MarginContainer = panel.get_child(0)
		var vbox: VBoxContainer = margin.get_child(0)
		var preview_container: VBoxContainer = null
		for child in vbox.get_children():
			if child.has_meta("preview_container"):
				preview_container = child
				break

		if preview_container:
			# Clear old previews
			for child in preview_container.get_children():
				child.queue_free()

			# Calculate percentage (equal chance for each item)
			var pool_size: int = pools[i].size()
			var chance: float = 100.0 / float(pool_size) if pool_size > 0 else 0.0

			# Add pattern previews
			for pattern in pools[i]:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)

				# Percentage chance - fixed width column
				var chance_label := Label.new()
				if chance >= 10.0:
					chance_label.text = "%d%%" % int(chance)
				else:
					chance_label.text = "%.1f%%" % chance
				chance_label.custom_minimum_size.x = 38
				chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				Fonts.apply_body(chance_label, 11, Color(0.7, 0.7, 0.5))
				row.add_child(chance_label)

				# Shape visual - fixed width container for alignment
				var shape_wrapper := Control.new()
				shape_wrapper.custom_minimum_size = Vector2(60, 24)
				row.add_child(shape_wrapper)
				var shape := _create_shape_visual(pattern, 7.0)
				shape_wrapper.add_child(shape)

				# Pattern name with rarity color - fixed width
				var name_label := Label.new()
				name_label.text = pattern["name"]
				name_label.custom_minimum_size.x = 90
				Fonts.apply_body(name_label, 13, _get_rarity_color(pattern["cells"].size()))
				row.add_child(name_label)

				# Rotatable indicator - fixed width
				var rot_label := Label.new()
				rot_label.custom_minimum_size.x = 16
				if pattern.get("rotatable", false):
					rot_label.text = "R"
					Fonts.apply_body(rot_label, 11, Color(1.0, 0.85, 0.2))
				else:
					rot_label.text = ""
				row.add_child(rot_label)

				preview_container.add_child(row)

	pool_overlay.visible = true

func _on_pool_selected(index: int) -> void:
	var panel: PanelContainer = pool_options[index]
	selected_pool = panel.get_meta("pool")
	pool_selected = true
	pool_overlay.visible = false

# =============================================================================
# WORM POOL SELECTION (Case Opening for Worms)
# =============================================================================

func _generate_random_worm_pool() -> Array:
	# Generate a random pool of 3-6 worms using weighted selection
	# Each worm has a 1/5 (20%) chance to be rotatable
	var pool: Array = []
	var pool_size := randi_range(3, 6)

	for i in range(pool_size):
		var worm := _pick_weighted_worm().duplicate()
		# 1/5 chance to be rotatable
		worm["rotatable"] = (randi() % 5 == 0)
		pool.append(worm)

	return pool

func _pick_weighted_worm() -> Dictionary:
	# Use player's available worms (their unlocked collection)
	var available_worms := GameState.get_player_available_worms()

	# Calculate total weight
	var total_weight := 0.0
	for worm_name in available_worms:
		var worm_def: Dictionary = GameState.WORM_DEFS[worm_name]
		total_weight += worm_def.get("weight", 1.0)

	# Pick random value
	var roll := randf() * total_weight
	var cumulative := 0.0

	for worm_name in available_worms:
		var worm_def: Dictionary = GameState.WORM_DEFS[worm_name]
		cumulative += worm_def.get("weight", 1.0)
		if roll <= cumulative:
			return worm_def

	# Fallback
	if available_worms.size() > 0:
		return GameState.WORM_DEFS[available_worms[0]]
	return GameState.WORM_DEFS[GameState.WORM_POOL[0]]

func _show_worm_pool_selection() -> void:
	worm_pool_selected = false

	# Generate two random worm pools
	var pools: Array = [_generate_random_worm_pool(), _generate_random_worm_pool()]

	# Update worm pool option displays
	for i in range(2):
		var panel: PanelContainer = worm_pool_options[i]
		panel.set_meta("pool", pools[i])

		# Find the preview container (panel -> margin -> vbox -> preview_container)
		var margin: MarginContainer = panel.get_child(0)
		var vbox: VBoxContainer = margin.get_child(0)
		var preview_container: VBoxContainer = null
		for child in vbox.get_children():
			if child.has_meta("preview_container"):
				preview_container = child
				break

		if preview_container:
			# Clear old previews
			for child in preview_container.get_children():
				child.queue_free()

			# Calculate percentage (equal chance for each item)
			var pool_size: int = pools[i].size()
			var chance: float = 100.0 / float(pool_size) if pool_size > 0 else 0.0

			# Add worm previews
			for worm_def in pools[i]:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)

				# Percentage chance - fixed width column
				var chance_label := Label.new()
				if chance >= 10.0:
					chance_label.text = "%d%%" % int(chance)
				else:
					chance_label.text = "%.1f%%" % chance
				chance_label.custom_minimum_size.x = 38
				chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				Fonts.apply_body(chance_label, 11, Color(0.7, 0.7, 0.5))
				row.add_child(chance_label)

				# Shape visual - fixed width container for alignment
				var shape_wrapper := Control.new()
				shape_wrapper.custom_minimum_size = Vector2(60, 24)
				row.add_child(shape_wrapper)
				var shape := _create_shape_visual(worm_def, 7.0)
				shape_wrapper.add_child(shape)

				# Worm name with rarity color - fixed width
				var name_label := Label.new()
				name_label.text = worm_def["name"]
				name_label.custom_minimum_size.x = 90
				Fonts.apply_body(name_label, 13, _get_rarity_color(worm_def["cells"].size()))
				row.add_child(name_label)

				# Rotatable indicator - fixed width
				var rot_label := Label.new()
				rot_label.custom_minimum_size.x = 16
				if worm_def.get("rotatable", false):
					rot_label.text = "R"
					Fonts.apply_body(rot_label, 11, Color(1.0, 0.85, 0.2))
				else:
					rot_label.text = ""
				row.add_child(rot_label)

				preview_container.add_child(row)

	worm_pool_overlay.visible = true

func _on_worm_pool_selected(index: int) -> void:
	var panel: PanelContainer = worm_pool_options[index]
	selected_worm_pool = panel.get_meta("pool")
	worm_pool_selected = true
	worm_pool_overlay.visible = false

func _play_worm_roll_animation() -> void:
	# Wait for user to select a worm pool
	_show_worm_pool_selection()

	while not worm_pool_selected:
		await get_tree().create_timer(0.05).timeout

	# Pick a random worm from the selected pool
	var winning_worm: Dictionary = selected_worm_pool[randi() % selected_worm_pool.size()]
	pending_worm_def = winning_worm  # Store the full definition with rotatable flag

	# Build the strip with worms from the pool
	_populate_worm_case_strip(winning_worm)

	# Show overlay
	case_overlay.visible = true

	# Update title (find it in the VBox structure)
	var main_vbox: VBoxContainer = case_container.get_child(0)
	var title_label: Label = main_vbox.get_child(1)  # After spacer
	title_label.text = "ROLLING WORM"
	title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	roll_label.text = "..."

	# Wait a frame for sizes to be calculated
	await get_tree().process_frame

	# Calculate target position using actual clip size
	var winner_index := CASE_ITEM_COUNT - 5
	var item_total_width := CASE_ITEM_WIDTH + 8
	var clip_center := case_strip_clip.size.x * 0.5
	var item_center := float(winner_index) * item_total_width + CASE_ITEM_WIDTH * 0.5
	var target_x := clip_center - item_center + randf_range(-30, 30)

	# Starting position (off to the right)
	var start_x := case_strip_clip.size.x * 0.3
	case_strip.position.x = start_x

	# Animate using Tween (frame-rate independent)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(case_strip, "position:x", target_x, 3.5)
	await tween.finished

	# Flash the winning item
	var worm_rarity := _get_rarity_color(winning_worm["cells"].size())
	await _flash_winning_item(winner_index, worm_rarity)

	# Update roll label with result
	roll_label.text = winning_worm["name"]
	roll_label.add_theme_color_override("font_color", worm_rarity)

	await get_tree().create_timer(0.5).timeout

	# Reset title color and hide overlay
	title_label.text = "ROLLING STRIKE PATTERN"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	case_overlay.visible = false

func _populate_worm_case_strip(winning_worm: Dictionary) -> void:
	# Clear existing items
	for child in case_strip.get_children():
		child.queue_free()
	case_items.clear()

	var winner_index := CASE_ITEM_COUNT - 5

	for i in range(CASE_ITEM_COUNT):
		var worm_def: Dictionary
		if i == winner_index:
			worm_def = winning_worm
		else:
			worm_def = selected_worm_pool[randi() % selected_worm_pool.size()]

		var rarity_color := _get_rarity_color(worm_def["cells"].size())
		var is_rotatable: bool = worm_def.get("rotatable", false)

		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(CASE_ITEM_WIDTH, 90 if is_rotatable else 80)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.15, 0.1)
		style.set_corner_radius_all(8)
		style.border_color = rarity_color.darkened(0.3)
		style.set_border_width_all(2)
		item.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		item.add_child(vbox)

		# Rotatable label at top if applicable
		if is_rotatable:
			var rot_label := Label.new()
			rot_label.text = "Rotatable"
			rot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Fonts.apply_body(rot_label, 10, Color(1.0, 0.85, 0.2))
			vbox.add_child(rot_label)

		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(CASE_ITEM_WIDTH - 10, 40)
		vbox.add_child(center)

		var shape := _create_shape_visual(worm_def, 10.0)
		center.add_child(shape)

		var label := Label.new()
		label.text = worm_def["name"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Fonts.apply_body(label, 12, rarity_color)
		vbox.add_child(label)

		case_strip.add_child(item)
		case_items.append(item)

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

		# Check if player got a miss
		if GameState.current_pattern.get("is_miss", false):
			incoming_label.text = "You got a " + GameState.current_pattern["name"] + "! Turn skipped..."
			await get_tree().create_timer(1.0).timeout
			incoming_label.text = ""
			# Skip to CPU turn
			GameState.current_turn = GameState.Turn.CPU
			_update_ui()
			await _do_cpu_turn()
		else:
			input_locked = false
			_update_ui()

func _on_restart_pressed() -> void:
	input_locked = false
	GameState.reset_game()
	hover_cell = Vector2i(-1, -1)
	roll_label.text = "---"
	incoming_label.text = ""
	won_worm_instances.clear()
	pending_worm_def = {}
	_update_ui()

func _on_debug_win_pressed() -> void:
	if not SaveManager.debug_mode:
		return
	if GameState.phase == GameState.Phase.GAME_OVER:
		return

	# Destroy all CPU worms instantly
	for worm in GameState.cpu_board["worms"]:
		if not worm.get("destroyed", false):
			# Mark all cells as hit
			for cell in worm["cells"]:
				worm["hit_set"][cell] = true
				GameState.cpu_board["revealed"][cell] = GameState.CellState.HIT_BODY
			worm["destroyed"] = true
			GameState.worm_destroyed.emit(GameState.Owner.PLAYER, worm["name"])

	# Trigger game over
	GameState.phase = GameState.Phase.GAME_OVER
	GameState.game_over.emit(GameState.Owner.PLAYER)
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

	# Check if CPU got a miss
	if pattern.get("is_miss", false):
		status_label.text = "ENEMY TURN"
		roll_label.text = pattern["name"] + " - SKIP!"
		roll_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
		incoming_label.text = "Enemy got a " + pattern["name"] + "! Their turn skipped!"
		await get_tree().create_timer(1.2).timeout
		incoming_label.text = ""

		# Skip to player's turn
		GameState.current_turn = GameState.Turn.PLAYER
		await get_tree().create_timer(0.3).timeout
		await _play_roll_animation()
		_update_ui()

		# Check if player also got a miss (recursive handling)
		if GameState.current_pattern.get("is_miss", false):
			incoming_label.text = "You got a " + GameState.current_pattern["name"] + "! Turn skipped..."
			await get_tree().create_timer(1.0).timeout
			incoming_label.text = ""
			GameState.current_turn = GameState.Turn.CPU
			_update_ui()
			await _do_cpu_turn()
		else:
			input_locked = false
		return

	# Show what pattern they're using
	status_label.text = "ENEMY TURN"
	roll_label.text = pattern["name"]
	roll_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

	# AI chooses strike - pass worm names (AI knows WHICH worms, not WHERE)
	var worm_names := GameState.get_player_worm_names_for_ai()
	var revealed: Dictionary = GameState.player_board["revealed"]
	var choice := AI.choose_strike(pattern, revealed, worm_names)

	# Apply rotation
	GameState.current_pattern_rotation = choice["rotation"]
	var anchor: Vector2i = choice["anchor"]

	if GameState.fast_play_mode:
		# Fast mode: instant attack, no animations
		_highlight_strike_preview(anchor, player_cells)
		await get_tree().create_timer(0.15).timeout
	else:
		# Normal mode: show targeting animation
		incoming_label.text = "Enemy using: " + pattern["name"]
		await get_tree().create_timer(0.8).timeout
		await _play_targeting_animation(anchor)
		incoming_label.text = "INCOMING!"
		_highlight_strike_preview(anchor, player_cells)
		await get_tree().create_timer(0.6).timeout

	# Apply strike
	var impacts: Array = GameState.apply_strike(GameState.Owner.CPU, anchor)

	# Animate impacts (faster in fast mode)
	if GameState.fast_play_mode:
		await _animate_impacts_fast(impacts, player_cells)
	else:
		await _animate_impacts(impacts, player_cells)

	incoming_label.text = ""

	# Check game over
	if GameState.phase == GameState.Phase.GAME_OVER:
		_update_ui()
		input_locked = false
		return

	# Player's turn - roll new pattern (fast or with animation)
	await get_tree().create_timer(0.3).timeout
	if GameState.fast_play_mode:
		await _fast_roll_pattern()
		input_locked = false
		_update_ui()
	else:
		await _play_roll_animation()
		_update_ui()

		# Check if player got a miss
		if GameState.current_pattern.get("is_miss", false):
			incoming_label.text = "You got a " + GameState.current_pattern["name"] + "! Turn skipped..."
			await get_tree().create_timer(1.0).timeout
			incoming_label.text = ""
			# Skip back to CPU turn
			GameState.current_turn = GameState.Turn.CPU
			_update_ui()
			await _do_cpu_turn()
		else:
			input_locked = false

func _play_targeting_animation(final_anchor: Vector2i) -> void:
	# Scan across grid with fake targets before landing on real one
	var scan_positions: Array = []

	# Generate 5-8 random positions to "consider"
	var num_scans := randi_range(5, 8)
	for i in range(num_scans):
		scan_positions.append(Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE))

	incoming_label.text = "Targeting..."

	# Scan through fake positions with increasing delay
	var scan_delay := 0.15
	for pos in scan_positions:
		_highlight_strike_preview(pos, player_cells)
		await get_tree().create_timer(scan_delay).timeout
		_update_player_grid()  # Reset to normal
		scan_delay += 0.03  # Slow down as we get closer

	# Pause before final target
	await get_tree().create_timer(0.25).timeout

func _play_roll_animation() -> void:
	# First, show pool selection
	_show_pool_selection()

	# Wait for user to select a pool
	while not pool_selected:
		await get_tree().create_timer(0.05).timeout

	# Pick a random pattern from the selected pool
	var winning_pattern: Dictionary = selected_pool[randi() % selected_pool.size()]
	GameState.current_pattern = winning_pattern
	GameState.current_pattern_rotation = 0

	# Build the strip with patterns from the pool
	_populate_case_strip(winning_pattern)

	# Show overlay
	case_overlay.visible = true
	roll_label.text = "..."

	# Wait a frame for sizes to be calculated
	await get_tree().process_frame

	# Calculate target position using actual clip size
	var winner_index := CASE_ITEM_COUNT - 5
	var item_total_width := CASE_ITEM_WIDTH + 8  # width + separation
	var clip_center := case_strip_clip.size.x * 0.5
	var item_center := float(winner_index) * item_total_width + CASE_ITEM_WIDTH * 0.5
	var target_x := clip_center - item_center + randf_range(-30, 30)

	# Starting position (off to the right)
	var start_x := case_strip_clip.size.x * 0.3
	case_strip.position.x = start_x

	# Animate using Tween (frame-rate independent)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(case_strip, "position:x", target_x, 3.5)
	await tween.finished

	# Flash the winning item
	var cell_count: int = winning_pattern.get("cells", []).size()
	var is_miss: bool = winning_pattern.get("is_miss", false)
	var pattern_rarity := _get_rarity_color(cell_count) if not is_miss else RARITY_COLORS[0]
	await _flash_winning_item(winner_index, pattern_rarity)

	# Update roll label with result
	if is_miss:
		roll_label.text = winning_pattern["name"] + " - SKIP!"
		roll_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		roll_label.text = winning_pattern["name"]
		roll_label.add_theme_color_override("font_color", _get_rarity_color(cell_count))

	# Brief pause to show result
	await get_tree().create_timer(0.5).timeout

	# Hide overlay
	case_overlay.visible = false

func _populate_case_strip(winning_pattern: Dictionary) -> void:
	# Clear existing items
	for child in case_strip.get_children():
		child.queue_free()
	case_items.clear()

	# Create items - winner at position CASE_ITEM_COUNT - 5
	var winner_index := CASE_ITEM_COUNT - 5

	for i in range(CASE_ITEM_COUNT):
		var pattern: Dictionary
		if i == winner_index:
			pattern = winning_pattern
		else:
			# Pick random pattern from selected pool
			pattern = selected_pool[randi() % selected_pool.size()]

		var pattern_cells: Array = pattern.get("cells", [])
		var is_miss: bool = pattern.get("is_miss", false)
		var rarity_color := _get_rarity_color(pattern_cells.size()) if not is_miss else RARITY_COLORS[0]
		var is_rotatable: bool = pattern.get("rotatable", false) and not is_miss

		var item := PanelContainer.new()
		item.custom_minimum_size = Vector2(CASE_ITEM_WIDTH, 90 if is_rotatable else 80)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.18)
		style.set_corner_radius_all(8)
		# Border color based on rarity
		style.border_color = rarity_color.darkened(0.3)
		style.set_border_width_all(2)
		item.add_theme_stylebox_override("panel", style)

		# VBox to hold shape and name
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		item.add_child(vbox)

		# Rotatable label at top if applicable
		if is_rotatable:
			var rot_label := Label.new()
			rot_label.text = "Rotatable"
			rot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Fonts.apply_body(rot_label, 10, Color(1.0, 0.85, 0.2))
			vbox.add_child(rot_label)

		# Center container for shape
		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(CASE_ITEM_WIDTH - 10, 40)
		vbox.add_child(center)

		# Visual shape
		var shape := _create_shape_visual(pattern, 10.0)
		center.add_child(shape)

		# Pattern name
		var label := Label.new()
		label.text = pattern["name"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Fonts.apply_body(label, 12, rarity_color)
		vbox.add_child(label)

		case_strip.add_child(item)
		case_items.append(item)

func _flash_winning_item(winner_index: int, rarity_color: Color = Color.WHITE) -> void:
	if winner_index < 0 or winner_index >= case_items.size():
		return

	var item: PanelContainer = case_items[winner_index]

	# Flash effect with rarity color
	for j in range(3):
		var flash_style := StyleBoxFlat.new()
		flash_style.bg_color = rarity_color.darkened(0.6)
		flash_style.set_corner_radius_all(8)
		flash_style.border_color = rarity_color
		flash_style.set_border_width_all(3)
		item.add_theme_stylebox_override("panel", flash_style)
		await get_tree().create_timer(0.1).timeout

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = rarity_color.darkened(0.7)
		normal_style.set_corner_radius_all(8)
		normal_style.border_color = rarity_color.darkened(0.2)
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
		await get_tree().create_timer(0.12).timeout

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
		await get_tree().create_timer(0.18).timeout

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
			if GameState.worms_remaining_to_pick > 0:
				status_label.text = "PLACEMENT PHASE\nOpen a worm case to get your worm!"
			elif not GameState.worms_to_place.is_empty():
				status_label.text = "PLACEMENT PHASE\nPlace " + GameState.worms_to_place[0] + " on your grid"
			else:
				status_label.text = "PLACEMENT PHASE\nReady for battle!"
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
	# Clear old buttons/rows (keep the label at index 0)
	while worm_select_panel.get_child_count() > 1:
		var child := worm_select_panel.get_child(1)
		worm_select_panel.remove_child(child)
		child.queue_free()

	if GameState.phase != GameState.Phase.PLACEMENT:
		return

	# Show worms awaiting placement
	for worm_name in GameState.worms_to_place:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var btn := Button.new()
		btn.text = worm_name
		btn.pressed.connect(_on_worm_select.bind(worm_name))
		Fonts.apply_button(btn, 14)
		if not GameState.current_worm_to_place.is_empty() and GameState.current_worm_to_place["name"] == worm_name:
			btn.text = "> " + worm_name + " <"
		row.add_child(btn)

		# Show rotatable status if applicable
		if won_worm_instances.has(worm_name) and won_worm_instances[worm_name].get("rotatable", false):
			var rot_label := Label.new()
			rot_label.text = "Rotatable"
			Fonts.apply_body(rot_label, 12, Color(1.0, 0.85, 0.2))
			row.add_child(rot_label)

		worm_select_panel.add_child(row)

	# Show "Pick Worm" buttons if player still needs to pick worms
	if GameState.worms_remaining_to_pick > 0:
		var worm_num := 3 - GameState.worms_remaining_to_pick  # 1 or 2
		var pick_btn := Button.new()
		pick_btn.text = "Open Worm Case " + str(worm_num)
		Fonts.apply_button(pick_btn, 16)
		pick_btn.pressed.connect(_on_pick_worm_pressed)
		worm_select_panel.add_child(pick_btn)

func _on_worm_select(worm_name: String) -> void:
	if input_locked:
		return
	# Use the won instance if available (preserves rotatable flag), otherwise use default
	if won_worm_instances.has(worm_name):
		GameState.current_worm_to_place = won_worm_instances[worm_name].duplicate()
	else:
		GameState.current_worm_to_place = GameState.WORM_DEFS[worm_name]
	_update_ui()

func _on_pick_worm_pressed() -> void:
	if input_locked:
		return
	input_locked = true

	# Run worm case opening animation
	await _play_worm_roll_animation()

	# Add the won worm to placement queue (store by name for display)
	var worm_name: String = pending_worm_def["name"]
	GameState.worms_to_place.append(worm_name)
	GameState.worms_remaining_to_pick -= 1

	# Store the won worm instance (with rotatable flag) in our tracking dictionary
	won_worm_instances[worm_name] = pending_worm_def.duplicate()

	# Auto-select the worm for immediate placement (use the won instance)
	GameState.current_worm_to_place = pending_worm_def.duplicate()
	pending_worm_def = {}

	input_locked = false
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
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		# Worm name
		var name_label := Label.new()
		var destroyed: bool = worm.get("destroyed", false)
		name_label.text = worm["name"] + ":"
		name_label.custom_minimum_size.x = 55
		if destroyed:
			Fonts.apply_body(name_label, 14, Color(0.5, 0.3, 0.3))
		else:
			Fonts.apply_body(name_label, 14, Color(0.8, 0.8, 0.8))
		row.add_child(name_label)

		# Visual worm shape
		var shape_container := _create_worm_visual(worm, show_all)
		row.add_child(shape_container)

		# Status
		if destroyed:
			var status := Label.new()
			status.text = "SUNK"
			Fonts.apply_body(status, 11, Color(0.8, 0.3, 0.3))
			row.add_child(status)

func _create_worm_visual(worm: Dictionary, show_all: bool) -> Control:
	var container := Control.new()
	var worm_name: String = worm["name"]
	var hit_set: Dictionary = worm["hit_set"]
	var destroyed: bool = worm.get("destroyed", false)

	# Use the BASE definition cells (not rotated) so rotation isn't revealed
	var worm_def = GameState.WORM_DEFS[worm_name]
	var base_cells: Array = worm_def["cells"]

	# Calculate which segments are hit (by index)
	var placed_cells: Array = worm["cells"]
	var hits_by_index: Array = []
	for i in range(placed_cells.size()):
		hits_by_index.append(hit_set.has(placed_cells[i]))

	# Find bounds of base shape
	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0
	for cell in base_cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	var dot_size := 12.0
	var spacing := 2.0
	var width := max_x - min_x + 1
	var height := max_y - min_y + 1

	container.custom_minimum_size = Vector2(width * (dot_size + spacing), height * (dot_size + spacing))

	# Compute end cells for base shape
	var base_end_cells := _compute_end_cells_for_visual(base_cells)

	for i in range(base_cells.size()):
		var cell: Vector2i = base_cells[i]
		var is_end: bool = cell in base_end_cells
		var is_hit: bool = hits_by_index[i] if i < hits_by_index.size() else false

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(dot_size, dot_size)
		dot.position = Vector2(
			(cell.x - min_x) * (dot_size + spacing),
			(cell.y - min_y) * (dot_size + spacing)
		)

		# Color based on state
		if is_hit:
			dot.color = COLOR_HIT_END if is_end else COLOR_HIT
		elif show_all:
			if destroyed:
				dot.color = Color(0.3, 0.3, 0.3)
			else:
				dot.color = COLOR_WORM_END if is_end else COLOR_WORM
		else:
			dot.color = Color(0.4, 0.4, 0.45)  # Unknown/fog

		container.add_child(dot)

	return container

func _compute_end_cells_for_visual(cells: Array) -> Array:
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	var ends: Array = []
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell in cells:
		var neighbor_count := 0
		for dir in directions:
			if cell_set.has(cell + dir):
				neighbor_count += 1
		if neighbor_count == 1:
			ends.append(cell)
	return ends

func _update_buttons() -> void:
	# Start button visible when all worms picked AND placed
	start_button.visible = GameState.phase == GameState.Phase.PLACEMENT and GameState.worms_remaining_to_pick == 0 and GameState.worms_to_place.is_empty()
	rotate_button.visible = GameState.phase != GameState.Phase.GAME_OVER
	worm_select_panel.visible = GameState.phase == GameState.Phase.PLACEMENT
	roll_panel.visible = GameState.phase == GameState.Phase.BATTLE or GameState.phase == GameState.Phase.GAME_OVER
	# Debug WIN button only visible in debug mode and not during game over
	debug_win_button.visible = SaveManager.debug_mode and GameState.phase != GameState.Phase.GAME_OVER

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

func _get_or_create_cell_styles(color: Color) -> Dictionary:
	## Returns cached StyleBoxes for a color, creating them if needed
	var key := color.to_html()
	if _cell_styles.has(key):
		return _cell_styles[key]

	# Create new StyleBoxes for this color
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(4)
	normal.border_color = color.lightened(0.15)
	normal.set_border_width_all(1)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.12)
	hover.set_corner_radius_all(4)
	hover.border_color = Color(0.8, 0.8, 0.9)
	hover.set_border_width_all(2)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.1)
	pressed.set_corner_radius_all(4)

	var styles := { "normal": normal, "hover": hover, "pressed": pressed }
	_cell_styles[key] = styles
	return styles

func _style_cell(cell: Button, color: Color, text: String) -> void:
	var key := color.to_html()
	var cell_id := cell.get_instance_id()
	var last_key: String = _cell_last_state.get(cell_id, "")

	# Only update StyleBoxes if color changed
	if key != last_key:
		var styles := _get_or_create_cell_styles(color)
		cell.add_theme_stylebox_override("normal", styles["normal"])
		cell.add_theme_stylebox_override("hover", styles["hover"])
		cell.add_theme_stylebox_override("pressed", styles["pressed"])
		_cell_last_state[cell_id] = key

	# Always update text (cheap operation)
	if cell.text != text:
		cell.text = text

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
		# Transition to victory screen after a delay (shorter in fast mode)
		var delay := 0.5 if GameState.fast_play_mode else 2.0
		await get_tree().create_timer(delay).timeout
		get_tree().change_scene_to_file("res://VictoryScreen.tscn")
	else:
		status_label.text = "DEFEAT!\nAll your worms were destroyed!"
		roll_label.text = "GAME OVER"
		roll_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		# Return to NPC menu after a delay (shorter in fast mode)
		var delay := 0.5 if GameState.fast_play_mode else 2.0
		await get_tree().create_timer(delay).timeout
		GameState.fast_play_mode = false
		get_tree().change_scene_to_file("res://NPCMenu.tscn")
	incoming_label.text = ""

# =============================================================================
# FAST PLAY MODE (Skip case animations)
# =============================================================================

func _fast_roll_pattern() -> void:
	## Instantly roll a pattern without case opening animation
	GameState._roll_pattern()
	var pattern: Dictionary = GameState.current_pattern

	# Update display
	var cell_count: int = pattern.get("cells", []).size()
	var is_miss: bool = pattern.get("is_miss", false)

	if is_miss:
		roll_label.text = pattern["name"] + " - SKIP!"
		roll_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		roll_label.text = pattern["name"]
		roll_label.add_theme_color_override("font_color", _get_rarity_color(cell_count))

	# Handle miss - skip turn
	if is_miss:
		incoming_label.text = "You got a " + pattern["name"] + "! Turn skipped..."
		await get_tree().create_timer(0.5).timeout
		incoming_label.text = ""
		GameState.current_turn = GameState.Turn.CPU
		_update_ui()
		await _do_cpu_turn()

func _animate_impacts_fast(impacts: Array, cells: Array) -> void:
	## Quick impact animation for fast play mode (no per-cell delays)
	for impact in impacts:
		if impact["already_hit"]:
			continue

		var cell_pos: Vector2i = impact["cell"]
		var idx: int = cell_pos.y * GRID_SIZE + cell_pos.x
		var cell: Button = cells[idx]
		var result: GameState.CellState = impact["result"]

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
			_:
				color = COLOR_EMPTY
				text = ""

		_style_cell(cell, color, text)

	_update_worm_panels()
