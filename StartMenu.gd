extends Control
## StartMenu.gd - Main menu with save slot selection
## ==================================================

const SLOT_COUNT := 3

var slot_buttons: Array = []
var delete_buttons: Array = []
var selected_slot: int = -1

func _ready() -> void:
	_build_ui()
	_update_slots()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "GARDEN NUKES vs WORMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	main_vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Select a save file"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	main_vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	main_vbox.add_child(spacer)

	# Save slots
	for i in range(SLOT_COUNT):
		var slot_container := _create_slot_panel(i)
		main_vbox.add_child(slot_container)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 20
	main_vbox.add_child(spacer2)

	# Quit button
	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(_on_quit)
	main_vbox.add_child(quit_btn)

	# Center the container
	main_vbox.position = Vector2(
		(get_viewport().get_visible_rect().size.x - 500) / 2,
		100
	)

func _create_slot_panel(slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)

	# Slot info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var slot_label := Label.new()
	slot_label.text = "Save Slot %d" % (slot_index + 1)
	slot_label.add_theme_font_size_override("font_size", 20)
	slot_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	info_vbox.add_child(slot_label)

	var details_label := Label.new()
	details_label.name = "Details"
	details_label.text = "Empty"
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info_vbox.add_child(details_label)

	# Buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(btn_vbox)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(100, 35)
	play_btn.pressed.connect(_on_slot_play.bind(slot_index))
	btn_vbox.add_child(play_btn)
	slot_buttons.append(play_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(100, 30)
	delete_btn.pressed.connect(_on_slot_delete.bind(slot_index))
	btn_vbox.add_child(delete_btn)
	delete_buttons.append(delete_btn)

	# Store reference to details label
	panel.set_meta("details_label", details_label)
	panel.set_meta("slot_index", slot_index)

	return panel

func _update_slots() -> void:
	for i in range(SLOT_COUNT):
		var info := SaveManager.get_slot_info(i)
		var panel: PanelContainer = slot_buttons[i].get_parent().get_parent().get_parent()
		var details_label: Label = panel.get_meta("details_label")

		if info.get("exists", false):
			var worms: int = info.get("worm_count", 0)
			var patterns: int = info.get("pattern_count", 0)
			var npcs: int = info.get("npc_count", 0)
			var drops: int = info.get("total_drops", 0)
			details_label.text = "%d Worms | %d Patterns | %d Drops" % [worms, patterns, drops]
			details_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
			slot_buttons[i].text = "Continue"
			delete_buttons[i].visible = true
		else:
			details_label.text = "Empty - Click to start new game"
			details_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			slot_buttons[i].text = "New Game"
			delete_buttons[i].visible = false

func _on_slot_play(slot_index: int) -> void:
	var info := SaveManager.get_slot_info(slot_index)

	if info.get("exists", false):
		# Load existing save
		if SaveManager.load_game(slot_index):
			_go_to_npc_menu()
	else:
		# Create new save
		if SaveManager.create_new_game(slot_index):
			_go_to_npc_menu()

func _on_slot_delete(slot_index: int) -> void:
	# Show confirmation dialog
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Save"
	dialog.dialog_text = "Are you sure you want to delete Save Slot %d?\nThis cannot be undone!" % (slot_index + 1)
	dialog.confirmed.connect(_confirm_delete.bind(slot_index, dialog))
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_delete(slot_index: int, dialog: ConfirmationDialog) -> void:
	SaveManager.delete_save(slot_index)
	dialog.queue_free()
	_update_slots()

func _on_quit() -> void:
	get_tree().quit()

func _go_to_npc_menu() -> void:
	get_tree().change_scene_to_file("res://NPCMenu.tscn")
