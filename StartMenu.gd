extends Control
## StartMenu.gd - Main menu with save slot selection
## ==================================================

const SLOT_COUNT := 3

var slot_buttons: Array = []
var delete_buttons: Array = []
var rename_buttons: Array = []
var slot_name_labels: Array = []
var selected_slot: int = -1
var name_input_popup: Control
var name_input_line: LineEdit
var pending_slot: int = -1
var is_rename: bool = false

func _ready() -> void:
	_build_ui()
	_update_slots()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Fullscreen centering root
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Safe margins so it looks good at any res
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	center.add_child(margin)

	# Content column
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(main_vbox)

	# Optional: constrain width without hardcoding position
	# (Keeps it from going ultra-wide on big screens)
	var width_guard := PanelContainer.new()
	width_guard.visible = false # purely for sizing if you want; set true if you want a panel behind everything
	width_guard.custom_minimum_size = Vector2(520, 0) # minimum
	width_guard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(width_guard)

	# Title
	var title := Label.new()
	title.text = "GARDEN NUKES vs WORMS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 48)
	main_vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Select a save file"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Fonts.apply_body(subtitle, 20, Color(0.6, 0.6, 0.7))
	main_vbox.add_child(subtitle)

	# Slots container (centered)
	var slots_vbox := VBoxContainer.new()
	slots_vbox.add_theme_constant_override("separation", 12)
	slots_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(slots_vbox)

	for i in range(SLOT_COUNT):
		var slot_panel := _create_slot_panel(i)
		# let it fill available width but keep a sensible minimum
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_panel.custom_minimum_size = Vector2(520, 96)
		slots_vbox.add_child(slot_panel)

	# Bottom row with debug checkbox and quit button
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 30)
	main_vbox.add_child(bottom_row)

	# Debug mode checkbox
	var debug_check := CheckBox.new()
	debug_check.name = "DebugCheck"
	debug_check.text = "Debug Mode"
	debug_check.button_pressed = SaveManager.debug_mode
	debug_check.toggled.connect(_on_debug_toggled)
	Fonts.apply_button(debug_check, 14)
	bottom_row.add_child(debug_check)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(200, 40)
	quit_btn.pressed.connect(_on_quit)
	Fonts.apply_button(quit_btn, 16)
	bottom_row.add_child(quit_btn)


func _create_slot_panel(slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 100)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	# Add margin for padding inside the panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Slot info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var slot_label := Label.new()
	slot_label.name = "SlotName"
	slot_label.text = "Save Slot %d" % (slot_index + 1)
	Fonts.apply_body(slot_label, 20, Color(0.8, 0.8, 0.9))
	info_vbox.add_child(slot_label)
	slot_name_labels.append(slot_label)

	var details_label := Label.new()
	details_label.name = "Details"
	details_label.text = "Empty"
	Fonts.apply_body(details_label, 14, Color(0.5, 0.5, 0.6))
	info_vbox.add_child(details_label)

	# Buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(btn_vbox)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(100, 35)
	play_btn.pressed.connect(_on_slot_play.bind(slot_index))
	Fonts.apply_button(play_btn, 16)
	btn_vbox.add_child(play_btn)
	slot_buttons.append(play_btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 5)
	btn_vbox.add_child(btn_row)

	var rename_btn := Button.new()
	rename_btn.text = "Rename"
	rename_btn.custom_minimum_size = Vector2(70, 30)
	rename_btn.pressed.connect(_on_slot_rename.bind(slot_index))
	Fonts.apply_button(rename_btn, 12)
	btn_row.add_child(rename_btn)
	rename_buttons.append(rename_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(70, 30)
	delete_btn.pressed.connect(_on_slot_delete.bind(slot_index))
	Fonts.apply_button(delete_btn, 12)
	btn_row.add_child(delete_btn)
	delete_buttons.append(delete_btn)

	# Store reference to details label
	panel.set_meta("details_label", details_label)
	panel.set_meta("slot_index", slot_index)

	return panel

func _update_slots() -> void:
	for i in range(SLOT_COUNT):
		var info := SaveManager.get_slot_info(i)
		var panel: PanelContainer = slot_buttons[i].get_parent().get_parent().get_parent().get_parent()
		var details_label: Label = panel.get_meta("details_label")

		if info.get("exists", false):
			var save_name: String = info.get("save_name", "Save %d" % (i + 1))
			var worms: int = info.get("worm_count", 0)
			var patterns: int = info.get("pattern_count", 0)
			var drops: int = info.get("total_drops", 0)
			slot_name_labels[i].text = save_name
			Fonts.apply_body(slot_name_labels[i], 20, Color(0.9, 0.85, 0.7))
			details_label.text = "%d Worms | %d Patterns | %d Drops" % [worms, patterns, drops]
			Fonts.apply_body(details_label, 14, Color(0.7, 0.8, 0.7))
			slot_buttons[i].text = "Continue"
			rename_buttons[i].visible = true
			delete_buttons[i].visible = true
		else:
			slot_name_labels[i].text = "Empty Slot"
			Fonts.apply_body(slot_name_labels[i], 20, Color(0.5, 0.5, 0.6))
			details_label.text = "Click New Game to start"
			Fonts.apply_body(details_label, 14, Color(0.5, 0.5, 0.6))
			slot_buttons[i].text = "New Game"
			rename_buttons[i].visible = false
			delete_buttons[i].visible = false

func _on_slot_play(slot_index: int) -> void:
	var info := SaveManager.get_slot_info(slot_index)

	if info.get("exists", false):
		# Load existing save
		if SaveManager.load_game(slot_index):
			_go_to_npc_menu()
	else:
		# Show name input popup for new game
		pending_slot = slot_index
		is_rename = false
		_show_name_popup("Enter Save Name", "New Save")

func _on_slot_rename(slot_index: int) -> void:
	var info := SaveManager.get_slot_info(slot_index)
	if not info.get("exists", false):
		return

	pending_slot = slot_index
	is_rename = true
	var current_name: String = info.get("save_name", "Save %d" % (slot_index + 1))
	_show_name_popup("Rename Save", current_name)

func _show_name_popup(title_text: String, default_name: String) -> void:
	# Create overlay
	name_input_popup = ColorRect.new()
	name_input_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_input_popup.color = Color(0, 0, 0, 0.7)
	add_child(name_input_popup)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_input_popup.add_child(center)

	# Popup panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 200)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 24)
	vbox.add_child(title)

	# Input field
	name_input_line = LineEdit.new()
	name_input_line.text = default_name
	name_input_line.placeholder_text = "Enter name..."
	name_input_line.custom_minimum_size = Vector2(300, 40)
	name_input_line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input_line.select_all_on_focus = true
	Fonts.apply_line_edit(name_input_line, 18)
	name_input_line.text_submitted.connect(_on_name_submitted)
	vbox.add_child(name_input_line)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(120, 40)
	confirm_btn.pressed.connect(_on_name_confirmed)
	Fonts.apply_button(confirm_btn, 16)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_on_name_cancelled)
	Fonts.apply_button(cancel_btn, 16)
	btn_row.add_child(cancel_btn)

	# Focus the input
	name_input_line.grab_focus()

func _on_name_submitted(_text: String) -> void:
	_on_name_confirmed()

func _on_name_confirmed() -> void:
	var save_name := name_input_line.text.strip_edges()
	if save_name.is_empty():
		save_name = "New Save"

	name_input_popup.queue_free()
	name_input_popup = null

	if is_rename:
		if SaveManager.rename_save(pending_slot, save_name):
			_update_slots()
	else:
		if SaveManager.create_new_game(pending_slot, save_name):
			_go_to_npc_menu()

	pending_slot = -1

func _on_name_cancelled() -> void:
	name_input_popup.queue_free()
	name_input_popup = null
	pending_slot = -1

var delete_popup: Control
var delete_slot_pending: int = -1

func _on_slot_delete(slot_index: int) -> void:
	delete_slot_pending = slot_index
	_show_delete_popup(slot_index)

func _show_delete_popup(slot_index: int) -> void:
	# Create overlay
	delete_popup = ColorRect.new()
	delete_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_popup.color = Color(0, 0, 0, 0.7)
	add_child(delete_popup)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_popup.add_child(center)

	# Popup panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 180)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.6, 0.3, 0.3)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Delete Save"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 24)
	vbox.add_child(title)

	# Warning text
	var warning := Label.new()
	warning.text = "Are you sure you want to delete Save Slot %d?\nThis cannot be undone!" % (slot_index + 1)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(warning, 16, Color(0.9, 0.7, 0.7))
	vbox.add_child(warning)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(120, 40)
	delete_btn.pressed.connect(_confirm_delete)
	Fonts.apply_button(delete_btn, 16)
	btn_row.add_child(delete_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_cancel_delete)
	Fonts.apply_button(cancel_btn, 16)
	btn_row.add_child(cancel_btn)

func _confirm_delete() -> void:
	SaveManager.delete_save(delete_slot_pending)
	delete_popup.queue_free()
	delete_popup = null
	delete_slot_pending = -1
	_update_slots()

func _cancel_delete() -> void:
	delete_popup.queue_free()
	delete_popup = null
	delete_slot_pending = -1

func _on_quit() -> void:
	get_tree().quit()

func _on_debug_toggled(pressed: bool) -> void:
	SaveManager.debug_mode = pressed

func _go_to_npc_menu() -> void:
	get_tree().change_scene_to_file("res://NPCMenu.tscn")
