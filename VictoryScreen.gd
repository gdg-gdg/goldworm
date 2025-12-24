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
var open_btn: Button

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

	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.position = Vector2(-400, -250)
	main_vbox.custom_minimum_size = Vector2(800, 500)
	add_child(main_vbox)

	# Victory title
	title_label = Label.new()
	title_label.text = "VICTORY!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	main_vbox.add_child(title_label)

	# Defeated NPC name
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	var defeated_label := Label.new()
	defeated_label.text = "You defeated %s! Open your reward case!" % npc.get("name", "???")
	defeated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeated_label.add_theme_font_size_override("font_size", 20)
	defeated_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	main_vbox.add_child(defeated_label)

	# Case opening area
	var case_area := Control.new()
	case_area.custom_minimum_size = Vector2(800, 180)
	main_vbox.add_child(case_area)

	# Strip container with clipping
	strip_container = Control.new()
	strip_container.custom_minimum_size = Vector2(ITEM_WIDTH * VISIBLE_ITEMS, ITEM_HEIGHT)
	strip_container.position = Vector2((800 - ITEM_WIDTH * VISIBLE_ITEMS) / 2, 20)
	strip_container.clip_contents = true
	case_area.add_child(strip_container)

	# Border around strip
	var border := ColorRect.new()
	border.color = Color(0.4, 0.35, 0.2)
	border.position = Vector2(-4, -4)
	border.size = Vector2(ITEM_WIDTH * VISIBLE_ITEMS + 8, ITEM_HEIGHT + 8)
	strip_container.add_child(border)

	var inner_bg := ColorRect.new()
	inner_bg.color = Color(0.1, 0.1, 0.12)
	inner_bg.position = Vector2(0, 0)
	inner_bg.size = Vector2(ITEM_WIDTH * VISIBLE_ITEMS, ITEM_HEIGHT)
	strip_container.add_child(inner_bg)

	# The scrolling strip
	strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip_container.add_child(strip)

	# Center pointer/marker
	pointer = ColorRect.new()
	pointer.color = Color(1.0, 0.8, 0.2)
	pointer.size = Vector2(4, ITEM_HEIGHT + 20)
	pointer.position = Vector2((800 - 4) / 2, 10)
	case_area.add_child(pointer)

	# Pointer arrow top
	var arrow_top := Label.new()
	arrow_top.text = "▼"
	arrow_top.position = Vector2((800 - 20) / 2, 0)
	arrow_top.add_theme_font_size_override("font_size", 20)
	arrow_top.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	case_area.add_child(arrow_top)

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

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_hbox)

	open_btn = Button.new()
	open_btn.text = "🎰 Open Case!"
	open_btn.custom_minimum_size = Vector2(200, 50)
	open_btn.add_theme_font_size_override("font_size", 20)
	open_btn.pressed.connect(_on_open_case)
	btn_hbox.add_child(open_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(150, 50)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	btn_hbox.add_child(continue_btn)

	# Pre-populate strip with items for preview
	_populate_strip_preview()

func _populate_strip_preview() -> void:
	# Show a static preview of items
	for child in strip.get_children():
		child.queue_free()

	for i in range(VISIBLE_ITEMS):
		var item: Dictionary = loot_pool[randi() % loot_pool.size()]
		var item_panel := _create_item_panel(item)
		strip.add_child(item_panel)

func _create_item_panel(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ITEM_WIDTH, ITEM_HEIGHT)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	var style := StyleBoxFlat.new()
	style.bg_color = rarity_color.darkened(0.7)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

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
	_draw_shape_preview(shape_container, item, rarity_color)

	# Name
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", rarity_color)
	vbox.add_child(name_label)

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
	open_btn.disabled = true
	open_btn.text = "Opening..."

	# Roll for loot first
	loot_item = NPCDefs.roll_loot(npc_id)

	# Play the spinning animation
	await _play_spin_animation()

	# Show result
	_show_result()

	# Save the unlock
	_save_unlock()

	# Record NPC defeat
	SaveManager.record_npc_defeat(npc_id)

	open_btn.visible = false
	continue_btn.visible = true

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
		var item_panel := _create_item_panel(item)
		strip.add_child(item_panel)

	# Calculate target position (center the winning item under pointer)
	var target_x := -(winning_index * ITEM_WIDTH) + (VISIBLE_ITEMS / 2 * ITEM_WIDTH)

	# Start position
	strip.position.x = 0

	# Animate with easing (fast start, slow end)
	var elapsed := 0.0
	var start_x := 0.0

	while elapsed < SPIN_DURATION:
		elapsed += get_process_delta_time()
		var t := elapsed / SPIN_DURATION

		# Cubic ease out for smooth deceleration
		var eased_t := 1.0 - pow(1.0 - t, 3)

		strip.position.x = lerp(start_x, float(target_x), eased_t)

		# Add tick sound effect feel with color flash
		if fmod(elapsed, 0.08) < get_process_delta_time() and t < 0.8:
			pointer.color = Color(1.0, 1.0, 1.0)
		else:
			pointer.color = Color(1.0, 0.8, 0.2)

		await get_tree().process_frame

	# Final position
	strip.position.x = target_x
	pointer.color = Color(1.0, 0.8, 0.2)

	# Flash effect
	for i in range(5):
		pointer.color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		pointer.color = Color(1.0, 0.8, 0.2)
		await get_tree().create_timer(0.1).timeout

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
