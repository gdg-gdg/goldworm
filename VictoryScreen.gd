extends Control
## VictoryScreen.gd - Post-battle case opening for rewards
## ========================================================

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.5, 0.9),
	"rare": Color(0.6, 0.3, 0.8),
	"epic": Color(0.9, 0.4, 0.6),
	"legendary": Color(0.9, 0.3, 0.3),
	"mythic": Color(1.0, 0.8, 0.2),
}

var npc_id: String = ""
var loot_item: Dictionary = {}
var case_opened := false

# UI references
var title_label: Label
var case_panel: PanelContainer
var item_container: Control
var continue_btn: Button
var open_btn: Button

func _ready() -> void:
	npc_id = GameState.current_npc_id
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
	main_vbox.add_theme_constant_override("separation", 30)
	add_child(main_vbox)

	# Victory title
	title_label = Label.new()
	title_label.text = "VICTORY!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	main_vbox.add_child(title_label)

	# Defeated NPC name
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	var defeated_label := Label.new()
	defeated_label.text = "You defeated %s!" % npc.get("name", "???")
	defeated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defeated_label.add_theme_font_size_override("font_size", 24)
	defeated_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	main_vbox.add_child(defeated_label)

	# Case container
	case_panel = PanelContainer.new()
	case_panel.custom_minimum_size = Vector2(350, 250)

	var case_style := StyleBoxFlat.new()
	case_style.bg_color = Color(0.12, 0.12, 0.18)
	case_style.set_corner_radius_all(12)
	case_style.border_color = Color(0.5, 0.4, 0.2)
	case_style.set_border_width_all(3)
	case_panel.add_theme_stylebox_override("panel", case_style)
	main_vbox.add_child(case_panel)

	# Item container (hidden until opened)
	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 15)
	item_container.visible = false
	case_panel.add_child(item_container)

	# Case preview (shown before opening)
	var case_preview := VBoxContainer.new()
	case_preview.name = "CasePreview"
	case_preview.add_theme_constant_override("separation", 10)
	case_panel.add_child(case_preview)

	var case_icon := Label.new()
	case_icon.text = "📦"
	case_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_icon.add_theme_font_size_override("font_size", 72)
	case_preview.add_child(case_icon)

	var case_text := Label.new()
	case_text.text = "Loot Case"
	case_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_text.add_theme_font_size_override("font_size", 24)
	case_text.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	case_preview.add_child(case_text)

	var case_hint := Label.new()
	case_hint.text = "Click to open!"
	case_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	case_hint.add_theme_font_size_override("font_size", 14)
	case_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	case_preview.add_child(case_hint)

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(btn_hbox)

	open_btn = Button.new()
	open_btn.text = "Open Case"
	open_btn.custom_minimum_size = Vector2(180, 50)
	open_btn.pressed.connect(_on_open_case)
	btn_hbox.add_child(open_btn)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(180, 50)
	continue_btn.pressed.connect(_on_continue)
	continue_btn.visible = false
	btn_hbox.add_child(continue_btn)

	# Center the container
	main_vbox.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 400) / 2,
		80
	)

func _on_open_case() -> void:
	if case_opened:
		return

	case_opened = true
	open_btn.visible = false

	# Roll for loot
	loot_item = NPCDefs.roll_loot(npc_id)

	# Play opening animation
	await _play_case_opening()

	# Show the item
	_display_item()

	# Save the unlock
	_save_unlock()

	# Record NPC defeat
	SaveManager.record_npc_defeat(npc_id)

	continue_btn.visible = true

func _play_case_opening() -> void:
	var case_preview: Control = case_panel.find_child("CasePreview", true, false)

	# Shake animation
	var original_pos := case_panel.position
	for i in range(10):
		case_panel.position.x = original_pos.x + randf_range(-5, 5)
		case_panel.position.y = original_pos.y + randf_range(-3, 3)
		await get_tree().create_timer(0.05).timeout

	case_panel.position = original_pos

	# Flash white
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.modulate.a = 0.8
	case_panel.add_child(flash)

	await get_tree().create_timer(0.1).timeout
	flash.queue_free()

	# Hide preview, show item
	case_preview.visible = false
	item_container.visible = true

func _display_item() -> void:
	# Clear previous
	for child in item_container.get_children():
		child.queue_free()

	var rarity: String = loot_item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_new: bool = loot_item.get("is_new", false)

	# Rarity label
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 16)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	item_container.add_child(rarity_label)

	# Item type icon
	var type_label := Label.new()
	if loot_item.get("type") == "worm":
		type_label.text = "🐛"
	else:
		type_label.text = "💥"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 56)
	item_container.add_child(type_label)

	# Item name
	var name_label := Label.new()
	name_label.text = loot_item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", rarity_color)
	item_container.add_child(name_label)

	# Item type
	var type_desc := Label.new()
	type_desc.text = "Worm" if loot_item.get("type") == "worm" else "Attack Pattern"
	type_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_desc.add_theme_font_size_override("font_size", 14)
	type_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	item_container.add_child(type_desc)

	# New or duplicate
	var status_label := Label.new()
	if is_new:
		status_label.text = "NEW!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "(Already owned)"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	item_container.add_child(status_label)

	# Update case panel border to match rarity
	var style: StyleBoxFlat = case_panel.get_theme_stylebox("panel").duplicate()
	style.border_color = rarity_color
	case_panel.add_theme_stylebox_override("panel", style)

func _save_unlock() -> void:
	var rarity: String = loot_item.get("rarity", "common")

	if loot_item.get("type") == "worm":
		SaveManager.unlock_worm(loot_item["name"], rarity)
	else:
		SaveManager.unlock_pattern(loot_item["name"], rarity)

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://NPCMenu.tscn")
