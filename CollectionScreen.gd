extends Control
## CollectionScreen.gd - View unlocked worms and patterns
## =======================================================

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.5, 0.9),
	"rare": Color(0.6, 0.3, 0.8),
	"epic": Color(0.9, 0.4, 0.6),
	"legendary": Color(0.9, 0.3, 0.3),
	"mythic": Color(1.0, 0.8, 0.2),
}

var current_tab := 0  # 0 = worms, 1 = patterns

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	main_vbox.offset_left = 50
	main_vbox.offset_right = -50
	main_vbox.offset_top = 30
	main_vbox.offset_bottom = -30
	add_child(main_vbox)

	# Header
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "Collection"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 40)
	back_btn.pressed.connect(_on_back)
	header_hbox.add_child(back_btn)

	# Tab buttons
	var tab_hbox := HBoxContainer.new()
	tab_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_hbox)

	var worms_tab := Button.new()
	worms_tab.name = "WormsTab"
	worms_tab.text = "Worms (%d)" % SaveManager.get_unlocked_worms().size()
	worms_tab.custom_minimum_size = Vector2(150, 40)
	worms_tab.pressed.connect(_on_tab_worms)
	tab_hbox.add_child(worms_tab)

	var patterns_tab := Button.new()
	patterns_tab.name = "PatternsTab"
	patterns_tab.text = "Patterns (%d)" % SaveManager.get_unlocked_patterns().size()
	patterns_tab.custom_minimum_size = Vector2(150, 40)
	patterns_tab.pressed.connect(_on_tab_patterns)
	tab_hbox.add_child(patterns_tab)

	# Scroll container for items
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "ItemGrid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid)

	_show_worms()

func _on_tab_worms() -> void:
	current_tab = 0
	_show_worms()

func _on_tab_patterns() -> void:
	current_tab = 1
	_show_patterns()

func _show_worms() -> void:
	var grid: GridContainer = find_child("ItemGrid", true, false)
	_clear_grid(grid)

	var unlocked := SaveManager.get_unlocked_worms()

	# Show all worms, greyed out if not unlocked
	for worm_name in WormDefs.WORMS:
		var worm_def: Dictionary = WormDefs.WORMS[worm_name]
		var is_unlocked: bool = worm_name in unlocked
		var panel := _create_item_panel(worm_name, worm_def, "worm", is_unlocked)
		grid.add_child(panel)

func _show_patterns() -> void:
	var grid: GridContainer = find_child("ItemGrid", true, false)
	_clear_grid(grid)

	var unlocked := SaveManager.get_unlocked_patterns()

	# Show all patterns (except misses), greyed out if not unlocked
	for pattern in PatternDefs.PATTERNS:
		if pattern.get("is_miss", false):
			continue
		var pattern_name: String = pattern.get("name", "")
		var is_unlocked: bool = pattern_name in unlocked
		var panel := _create_item_panel(pattern_name, pattern, "pattern", is_unlocked)
		grid.add_child(panel)

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

func _create_item_panel(item_name: String, item_def: Dictionary, item_type: String, is_unlocked: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 180)

	var rarity: String = item_def.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	var style := StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_color = rarity_color
	else:
		style.bg_color = Color(0.1, 0.1, 0.12)
		style.border_color = Color(0.2, 0.2, 0.25)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Rarity label
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 10)
	if is_unlocked:
		rarity_label.add_theme_color_override("font_color", rarity_color)
	else:
		rarity_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	vbox.add_child(rarity_label)

	# Shape preview
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(130, 80)
	vbox.add_child(shape_container)

	if is_unlocked:
		var cells: Array = item_def.get("cells", [])
		_draw_shape_preview(shape_container, cells, rarity_color)
	else:
		var question := Label.new()
		question.text = "?"
		question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		question.add_theme_font_size_override("font_size", 36)
		question.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
		question.set_anchors_preset(Control.PRESET_FULL_RECT)
		shape_container.add_child(question)

	# Name
	var name_label := Label.new()
	if is_unlocked:
		name_label.text = item_name
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	else:
		name_label.text = "???"
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# Type label
	var type_label := Label.new()
	type_label.text = "Worm" if item_type == "worm" else "Pattern"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(type_label)

	return panel

func _draw_shape_preview(container: Control, cells: Array, color: Color) -> void:
	if cells.is_empty():
		return

	# Find bounds
	var min_x := 999
	var max_x := -999
	var min_y := 999
	var max_y := -999

	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)

	var width := max_x - min_x + 1
	var height := max_y - min_y + 1

	var cell_size := mini(int(120.0 / width), int(70.0 / height))
	cell_size = clampi(cell_size, 8, 20)

	var total_width := width * cell_size
	var total_height := height * cell_size
	var offset_x := (container.custom_minimum_size.x - total_width) / 2
	var offset_y := (container.custom_minimum_size.y - total_height) / 2

	for cell in cells:
		var rect := ColorRect.new()
		rect.color = color
		rect.position = Vector2(
			offset_x + (cell.x - min_x) * cell_size,
			offset_y + (cell.y - min_y) * cell_size
		)
		rect.size = Vector2(cell_size - 2, cell_size - 2)
		container.add_child(rect)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://NPCMenu.tscn")
