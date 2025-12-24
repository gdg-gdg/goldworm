extends Control
## VictoryScreen.gd - Post-battle CS:GO style case opening
## ========================================================

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.5, 0.9),
	"rare": Color(0.6, 0.3, 0.8),
	"epic": Color(0.9, 0.4, 0.6),
	"legendary": Color(0.9, 0.3, 0.3),
	"mythic": Color(1.0, 0.8, 0.2),
}

const ITEM_WIDTH := 120
const ITEM_HEIGHT := 140
const VISIBLE_ITEMS := 7
const STRIP_ITEMS := 50
const SPIN_DURATION := 5.0

var npc_id: String = ""
var loot_item: Dictionary = {}
var case_opened := false
var loot_pool: Array = []

# UI references
var title_label: Label
var strip_container: Control
var strip: HBoxContainer
var pointer: ColorRect
var result_panel: PanelContainer
var continue_btn: Button
var loot_box_btn: Button
var case_area: Control
var defeated_label: Label
var contents_panel: PanelContainer
var root_hbox: HBoxContainer
var main_vbox: VBoxContainer

func _ready() -> void:
	npc_id = GameState.current_npc_id
	loot_pool = NPCDefs.get_npc_loot_pool(npc_id)
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# CenterContainer wrapper for proper centering
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Root HBox: main content on left, possible contents on right
	root_hbox = HBoxContainer.new()
	root_hbox.add_theme_constant_override("separation", 30)
	center.add_child(root_hbox)

	# Main container (left side)
	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.custom_minimum_size = Vector2(880, 500)
	root_hbox.add_child(main_vbox)

	# Possible contents panel (right side)
	contents_panel = _build_contents_panel()
	root_hbox.add_child(contents_panel)

	# Victory title
	title_label = Label.new()
	title_label.text = "VICTORY!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	main_vbox.add_child(title_label)

	# Defeated NPC name
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	defeated_label = Label.new()
	defeated_label.text = "You defeated %s!" % npc.get("name", "???")
	defeated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeated_label.add_theme_font_size_override("font_size", 20)
	defeated_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	main_vbox.add_child(defeated_label)

	# Loot box button (shown initially, hidden after click)
	var loot_box_container := CenterContainer.new()
	loot_box_container.custom_minimum_size = Vector2(0, 200)
	main_vbox.add_child(loot_box_container)

	loot_box_btn = Button.new()
	loot_box_btn.custom_minimum_size = Vector2(200, 180)
	loot_box_btn.flat = true
	loot_box_btn.pressed.connect(_on_open_case)
	loot_box_container.add_child(loot_box_btn)

	# Loot box visual
	var box_panel := PanelContainer.new()
	box_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_box_btn.add_child(box_panel)

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.15, 0.12, 0.08)
	box_style.set_corner_radius_all(12)
	box_style.border_color = Color(0.8, 0.6, 0.2)
	box_style.set_border_width_all(4)
	box_panel.add_theme_stylebox_override("panel", box_style)

	var box_vbox := VBoxContainer.new()
	box_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	box_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_panel.add_child(box_vbox)

	var box_icon := Label.new()
	box_icon.text = "🎁"
	box_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_icon.add_theme_font_size_override("font_size", 64)
	box_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_vbox.add_child(box_icon)

	var box_label := Label.new()
	box_label.text = "CLICK TO OPEN"
	box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_label.add_theme_font_size_override("font_size", 16)
	box_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	box_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_vbox.add_child(box_label)

	# Case opening area (hidden initially) - using anchors for centering
	case_area = Control.new()
	case_area.custom_minimum_size = Vector2(ITEM_WIDTH * VISIBLE_ITEMS + 40, 180)
	case_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	case_area.visible = false
	main_vbox.add_child(case_area)

	# Strip container with clipping - centered with anchors
	strip_container = Control.new()
	strip_container.custom_minimum_size = Vector2(ITEM_WIDTH * VISIBLE_ITEMS, ITEM_HEIGHT)
	strip_container.clip_contents = true
	strip_container.anchor_left = 0.5
	strip_container.anchor_right = 0.5
	strip_container.anchor_top = 0.0
	strip_container.offset_left = -(ITEM_WIDTH * VISIBLE_ITEMS) / 2
	strip_container.offset_right = (ITEM_WIDTH * VISIBLE_ITEMS) / 2
	strip_container.offset_top = 20
	strip_container.offset_bottom = 20 + ITEM_HEIGHT
	case_area.add_child(strip_container)

	# Border around strip
	var border := ColorRect.new()
	border.color = Color(0.4, 0.35, 0.2)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -4
	border.offset_top = -4
	border.offset_right = 4
	border.offset_bottom = 4
	strip_container.add_child(border)

	var inner_bg := ColorRect.new()
	inner_bg.color = Color(0.1, 0.1, 0.12)
	inner_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip_container.add_child(inner_bg)

	# The scrolling strip
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip_container.add_child(strip)

	# Center pointer/marker (simple line)
	pointer = ColorRect.new()
	pointer.color = Color(1.0, 0.8, 0.2)
	pointer.custom_minimum_size = Vector2(4, ITEM_HEIGHT + 20)
	pointer.anchor_left = 0.5
	pointer.anchor_right = 0.5
	pointer.offset_left = -2
	pointer.offset_right = 2
	pointer.offset_top = 10
	pointer.offset_bottom = 10 + ITEM_HEIGHT + 20
	case_area.add_child(pointer)

	# Result panel (hidden until reveal)
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(400, 120)
	result_panel.visible = false
	main_vbox.add_child(result_panel)

	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.12, 0.12, 0.18)
	result_style.set_corner_radius_all(10)
	result_style.set_border_width_all(3)
	result_panel.add_theme_stylebox_override("panel", result_style)

	# Continue button (hidden until case opened)
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_hbox)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(150, 50)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	btn_hbox.add_child(continue_btn)

func _build_contents_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Possible Drops"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	vbox.add_child(title)

	# Group items by type
	var worms: Array = []
	var patterns: Array = []
	for item in loot_pool:
		if item["type"] == "worm":
			worms.append(item)
		else:
			patterns.append(item)

	# Show worms section
	if worms.size() > 0:
		var worms_label := Label.new()
		worms_label.text = "🐛 Worms"
		worms_label.add_theme_font_size_override("font_size", 14)
		worms_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		vbox.add_child(worms_label)

		for item in worms:
			var row := _create_contents_row(item)
			vbox.add_child(row)

	# Show patterns section
	if patterns.size() > 0:
		var patterns_label := Label.new()
		patterns_label.text = "💥 Patterns"
		patterns_label.add_theme_font_size_override("font_size", 14)
		patterns_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
		vbox.add_child(patterns_label)

		for item in patterns:
			var row := _create_contents_row(item)
			vbox.add_child(row)

	return panel

func _create_contents_row(item: Dictionary) -> HBoxContainer:
	var item_name: String = item.get("name", "???")
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_owned := _is_item_owned(item)

	# Dim if owned
	var display_color := rarity_color.darkened(0.4) if is_owned else rarity_color

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	if is_owned:
		row.modulate.a = 0.5

	# Shape preview
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(60, 24)
	row.add_child(shape_container)
	_draw_mini_shape(shape_container, item, display_color)

	# Name
	var name_label := Label.new()
	name_label.text = item_name
	name_label.custom_minimum_size.x = 90
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", display_color)
	row.add_child(name_label)

	# Rarity badge
	var rarity_label := Label.new()
	rarity_label.text = rarity.substr(0, 3).to_upper()
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.add_theme_color_override("font_color", display_color.darkened(0.1))
	row.add_child(rarity_label)

	# Owned checkmark
	if is_owned:
		var check := Label.new()
		check.text = "✓"
		check.add_theme_font_size_override("font_size", 14)
		check.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		row.add_child(check)

	return row

func _draw_mini_shape(container: Control, item: Dictionary, color: Color) -> void:
	var cells: Array = []

	if item.get("type") == "worm":
		var worm_def: Dictionary = WormDefs.WORMS.get(item.get("name", ""), {})
		cells = worm_def.get("cells", [])
	else:
		var pattern: Dictionary = PatternDefs.get_pattern(item.get("name", ""))
		cells = pattern.get("cells", [])

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

	var cell_size := mini(int(55.0 / width), int(20.0 / height))
	cell_size = clampi(cell_size, 4, 7)

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
		rect.size = Vector2(cell_size - 1, cell_size - 1)
		container.add_child(rect)

func _is_item_owned(item: Dictionary) -> bool:
	if item.get("type") == "worm":
		return SaveManager.has_worm(item.get("name", ""))
	else:
		return SaveManager.has_pattern(item.get("name", ""))

func _create_item_panel(item: Dictionary, dim_if_owned: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ITEM_WIDTH, ITEM_HEIGHT)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_owned := _is_item_owned(item)
	var should_dim := dim_if_owned and is_owned

	# Dim colors more for owned items
	var display_color := rarity_color.darkened(0.5) if should_dim else rarity_color

	var style := StyleBoxFlat.new()
	style.bg_color = display_color.darkened(0.7)
	style.border_color = display_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	# Apply overall dim to panel
	if should_dim:
		panel.modulate = Color(0.6, 0.6, 0.6, 0.8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# Emoji icon
	var icon := Label.new()
	icon.text = "🐛" if item.get("type") == "worm" else "💥"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon)

	# Shape preview
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(ITEM_WIDTH - 10, 50)
	vbox.add_child(shape_container)
	_draw_shape_preview(shape_container, item, display_color)

	# Name
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", display_color)
	vbox.add_child(name_label)

	# Green tick overlay for owned items
	if should_dim:
		var tick_label := Label.new()
		tick_label.text = "✓"
		tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tick_label.add_theme_font_size_override("font_size", 48)
		tick_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.8))
		tick_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		tick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tick_label)

	return panel

func _draw_shape_preview(container: Control, item: Dictionary, color: Color) -> void:
	var cells: Array = []

	if item.get("type") == "worm":
		var worm_def: Dictionary = WormDefs.WORMS.get(item.get("name", ""), {})
		cells = worm_def.get("cells", [])
	else:
		var pattern: Dictionary = PatternDefs.get_pattern(item.get("name", ""))
		cells = pattern.get("cells", [])

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

	var cell_size := mini(int(100.0 / width), int(40.0 / height))
	cell_size = clampi(cell_size, 6, 12)

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
		rect.size = Vector2(cell_size - 1, cell_size - 1)
		container.add_child(rect)

func _on_open_case() -> void:
	if case_opened:
		return

	case_opened = true
	loot_box_btn.disabled = true

	# Roll for loot first
	loot_item = NPCDefs.roll_loot(npc_id)

	# Dramatic box opening effect
	await _play_box_open_animation()

	# Hide loot box and contents panel, show case area (now centered)
	loot_box_btn.get_parent().visible = false
	contents_panel.visible = false
	case_area.visible = true
	defeated_label.text = "Opening case..."

	# Wait a moment for dramatic effect
	await get_tree().create_timer(0.3).timeout

	# Play the spinning animation
	await _play_spin_animation()

	# Show result
	_show_result()

	# Save the unlock
	_save_unlock()

	# Record NPC defeat
	SaveManager.record_npc_defeat(npc_id)

	continue_btn.visible = true

func _play_box_open_animation() -> void:
	# Shake and flash the box before opening
	var original_pos := loot_box_btn.position
	var box_panel: PanelContainer = loot_box_btn.get_child(0)
	var box_style: StyleBoxFlat = box_panel.get_theme_stylebox("panel")

	# Shake effect
	for i in range(10):
		loot_box_btn.position.x = original_pos.x + randf_range(-8, 8)
		loot_box_btn.position.y = original_pos.y + randf_range(-4, 4)

		# Flash border color
		var flash_style := box_style.duplicate()
		flash_style.border_color = Color(1, 1, 1) if i % 2 == 0 else Color(0.8, 0.6, 0.2)
		box_panel.add_theme_stylebox_override("panel", flash_style)

		await get_tree().create_timer(0.05).timeout

	loot_box_btn.position = original_pos

	# Final bright flash
	var flash_style := box_style.duplicate()
	flash_style.bg_color = Color(1, 0.9, 0.7)
	flash_style.border_color = Color(1, 1, 1)
	box_panel.add_theme_stylebox_override("panel", flash_style)

	await get_tree().create_timer(0.15).timeout

func _play_spin_animation() -> void:
	# Clear and rebuild strip with many items
	for child in strip.get_children():
		child.queue_free()

	# Build a long strip with the winning item near the end
	var winning_index := STRIP_ITEMS - VISIBLE_ITEMS / 2 - 2 + randi() % 3

	for i in range(STRIP_ITEMS):
		var item: Dictionary
		if i == winning_index:
			item = loot_item
		else:
			item = loot_pool[randi() % loot_pool.size()]
		# Always dim owned items (including winning item if it's a duplicate)
		var item_panel := _create_item_panel(item, true)
		strip.add_child(item_panel)

	# Wait a frame for sizes to be valid
	await get_tree().process_frame

	# Calculate target position using actual strip_container size
	var clip_center := strip_container.size.x * 0.5
	var item_center := float(winning_index) * ITEM_WIDTH + ITEM_WIDTH * 0.5
	var target_x := clip_center - item_center

	# Start position
	strip.position.x = 0

	# Animate using Tween (frame-rate independent)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(strip, "position:x", target_x, SPIN_DURATION)

	# Run pointer flash in parallel with the tween (fire and forget)
	_flash_pointer_during_spin(SPIN_DURATION)

	await tween.finished
	pointer.color = Color(1.0, 0.8, 0.2)

	# Flash effect at end
	for i in range(5):
		pointer.color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		pointer.color = Color(1.0, 0.8, 0.2)
		await get_tree().create_timer(0.1).timeout

func _flash_pointer_during_spin(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration * 0.8:
		if fmod(elapsed, 0.08) < 0.02:
			pointer.color = Color(1.0, 1.0, 1.0)
		else:
			pointer.color = Color(1.0, 0.8, 0.2)
		await get_tree().create_timer(0.02).timeout
		elapsed += 0.02

func _show_result() -> void:
	result_panel.visible = true

	var rarity: String = loot_item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_new: bool = loot_item.get("is_new", false)

	# Update border color
	var style: StyleBoxFlat = result_panel.get_theme_stylebox("panel").duplicate()
	style.border_color = rarity_color
	result_panel.add_theme_stylebox_override("panel", style)

	# Clear and rebuild content
	for child in result_panel.get_children():
		child.queue_free()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	result_panel.add_child(hbox)

	# Icon
	var icon := Label.new()
	icon.text = "🐛" if loot_item.get("type") == "worm" else "💥"
	icon.add_theme_font_size_override("font_size", 48)
	hbox.add_child(icon)

	# Info
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(info_vbox)

	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	info_vbox.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = loot_item.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", rarity_color)
	info_vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "Worm" if loot_item.get("type") == "worm" else "Attack Pattern"
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	info_vbox.add_child(type_label)

	# New/duplicate status
	var status_label := Label.new()
	if is_new:
		status_label.text = "✨ NEW! ✨"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "(Already owned)"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(status_label)

func _save_unlock() -> void:
	var rarity: String = loot_item.get("rarity", "common")

	if loot_item.get("type") == "worm":
		SaveManager.unlock_worm(loot_item["name"], rarity)
	else:
		SaveManager.unlock_pattern(loot_item["name"], rarity)

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://NPCMenu.tscn")
