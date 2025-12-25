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
	"relic": Color(0.4, 0.9, 0.6),
}

const SLOT_ICONS := {
	"hat": "👑",
	"back": "🎒",
	"hands": "🧤",
	"neck": "📿",
	"feet": "👢",
}

var current_tab := 0  # 0 = worms, 1 = patterns, 2 = relics

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
	Fonts.apply_title(title, 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(100, 40)
	back_btn.pressed.connect(_on_back)
	Fonts.apply_button(back_btn, 16)
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
	Fonts.apply_button(worms_tab, 16)
	tab_hbox.add_child(worms_tab)

	var patterns_tab := Button.new()
	patterns_tab.name = "PatternsTab"
	patterns_tab.text = "Patterns (%d)" % SaveManager.get_unlocked_patterns().size()
	patterns_tab.custom_minimum_size = Vector2(150, 40)
	patterns_tab.pressed.connect(_on_tab_patterns)
	Fonts.apply_button(patterns_tab, 16)
	tab_hbox.add_child(patterns_tab)

	var relics_tab := Button.new()
	relics_tab.name = "RelicsTab"
	relics_tab.text = "Relics (%d)" % SaveManager.get_unlocked_cosmetics().size()
	relics_tab.custom_minimum_size = Vector2(150, 40)
	relics_tab.pressed.connect(_on_tab_relics)
	Fonts.apply_button(relics_tab, 16)
	tab_hbox.add_child(relics_tab)

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

func _on_tab_relics() -> void:
	current_tab = 2
	_show_relics()

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

func _show_relics() -> void:
	var grid: GridContainer = find_child("ItemGrid", true, false)
	_clear_grid(grid)

	var unlocked := SaveManager.get_unlocked_cosmetics()
	var equipped := SaveManager.get_equipped_cosmetics()

	# Show all relics, greyed out if not unlocked
	for relic_name in CosmeticDefs.COSMETICS:
		var relic_def: Dictionary = CosmeticDefs.COSMETICS[relic_name]
		var is_unlocked: bool = relic_name in unlocked
		var is_equipped: bool = relic_name in equipped.values()
		var panel := _create_relic_panel(relic_name, relic_def, is_unlocked, is_equipped)
		grid.add_child(panel)

func _create_relic_panel(relic_name: String, relic_def: Dictionary, is_unlocked: bool, is_equipped: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)

	var rarity_color: Color = RARITY_COLORS.get("relic", Color.WHITE)

	var style := StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.12, 0.18, 0.15) if is_equipped else Color(0.15, 0.15, 0.2)
		style.border_color = rarity_color if is_equipped else rarity_color.darkened(0.3)
	else:
		style.bg_color = Color(0.1, 0.1, 0.12)
		style.border_color = Color(0.2, 0.2, 0.25)
	style.set_corner_radius_all(8)
	style.set_border_width_all(3 if is_equipped else 2)
	panel.add_theme_stylebox_override("panel", style)

	# MarginContainer for proper padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Slot icon and label
	var slot: String = relic_def.get("slot", "")
	var slot_hbox := HBoxContainer.new()
	slot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(slot_hbox)

	var slot_icon := Label.new()
	slot_icon.text = SLOT_ICONS.get(slot, "❓")
	slot_icon.add_theme_font_size_override("font_size", 20)
	slot_hbox.add_child(slot_icon)

	var slot_label := Label.new()
	slot_label.text = slot.to_upper()
	if is_unlocked:
		Fonts.apply_body(slot_label, 11, rarity_color)
	else:
		Fonts.apply_body(slot_label, 11, Color(0.3, 0.3, 0.35))
	slot_hbox.add_child(slot_label)

	# Equipped indicator
	if is_equipped:
		var equipped_label := Label.new()
		equipped_label.text = "[EQUIPPED]"
		equipped_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Fonts.apply_body(equipped_label, 10, Color(0.3, 0.9, 0.5))
		vbox.add_child(equipped_label)

	# Relic name
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 160
	if is_unlocked:
		name_label.text = relic_name
		Fonts.apply_body(name_label, 14, Color(0.9, 0.9, 0.95))
	else:
		name_label.text = "???"
		Fonts.apply_body(name_label, 14, Color(0.4, 0.4, 0.45))
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 160
	if is_unlocked:
		desc_label.text = relic_def.get("description", "")
		Fonts.apply_body(desc_label, 10, Color(0.6, 0.6, 0.65))
	else:
		desc_label.text = "Defeat NPCs to unlock relics"
		Fonts.apply_body(desc_label, 10, Color(0.35, 0.35, 0.4))
	vbox.add_child(desc_label)

	# Bonus effect
	var bonus_label := Label.new()
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_label.custom_minimum_size.x = 160
	if is_unlocked:
		bonus_label.text = relic_def.get("bonus", "")
		Fonts.apply_body(bonus_label, 11, rarity_color)
	else:
		bonus_label.text = ""
	vbox.add_child(bonus_label)

	# Equip button (only if unlocked)
	if is_unlocked:
		var btn := Button.new()
		if is_equipped:
			btn.text = "Unequip"
			btn.pressed.connect(_on_unequip_relic.bind(slot))
		else:
			btn.text = "Equip"
			btn.pressed.connect(_on_equip_relic.bind(relic_name))
		btn.custom_minimum_size = Vector2(80, 28)
		Fonts.apply_button(btn, 12)
		vbox.add_child(btn)

	return panel

func _on_equip_relic(relic_name: String) -> void:
	SaveManager.equip_cosmetic(relic_name)
	_show_relics()

func _on_unequip_relic(slot: String) -> void:
	SaveManager.unequip_cosmetic(slot)
	_show_relics()

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

	# MarginContainer for proper padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Rarity label
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_unlocked:
		Fonts.apply_body(rarity_label, 10, rarity_color)
	else:
		Fonts.apply_body(rarity_label, 10, Color(0.3, 0.3, 0.35))
	vbox.add_child(rarity_label)

	# Shape preview - centered
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(130, 80)
	shape_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(shape_container)

	if is_unlocked:
		var cells: Array = item_def.get("cells", [])
		_draw_shape_preview(shape_container, cells, rarity_color)
	else:
		var question := Label.new()
		question.text = "?"
		question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		Fonts.apply_body(question, 36, Color(0.3, 0.3, 0.35))
		question.set_anchors_preset(Control.PRESET_FULL_RECT)
		shape_container.add_child(question)

	# Name
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_unlocked:
		name_label.text = item_name
		Fonts.apply_body(name_label, 14, Color(0.9, 0.9, 0.95))
	else:
		name_label.text = "???"
		Fonts.apply_body(name_label, 14, Color(0.4, 0.4, 0.45))
	vbox.add_child(name_label)

	# Type label
	var type_label := Label.new()
	type_label.text = "Worm" if item_type == "worm" else "Pattern"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(type_label, 10, Color(0.5, 0.5, 0.55))
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
