extends Control
## NPCMenu.gd - NPC selection menu for entering battles
## =====================================================

var npc_panels: Dictionary = {}
var selected_npc: String = ""

func _ready() -> void:
	_build_ui()
	_update_npcs()

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
	main_vbox.add_child(header_hbox)

	var title := Label.new()
	title.text = "Choose Your Opponent"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	# Stats display
	var stats_panel := _create_stats_panel()
	header_hbox.add_child(stats_panel)

	# NPC Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var npc_grid := HBoxContainer.new()
	npc_grid.add_theme_constant_override("separation", 20)
	scroll.add_child(npc_grid)

	# Create NPC panels
	for npc_id in NPCDefs.NPC_ORDER:
		var panel := _create_npc_panel(npc_id)
		npc_grid.add_child(panel)
		npc_panels[npc_id] = panel

	# Bottom bar
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(bottom_hbox)

	var back_btn := Button.new()
	back_btn.text = "Back to Menu"
	back_btn.custom_minimum_size = Vector2(150, 40)
	back_btn.pressed.connect(_on_back)
	bottom_hbox.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	# Collection button
	var collection_btn := Button.new()
	collection_btn.text = "View Collection"
	collection_btn.custom_minimum_size = Vector2(150, 40)
	collection_btn.pressed.connect(_on_collection)
	bottom_hbox.add_child(collection_btn)

func _create_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	# Worms count
	var worms_vbox := VBoxContainer.new()
	hbox.add_child(worms_vbox)

	var worms_count := Label.new()
	worms_count.name = "WormsCount"
	worms_count.text = str(SaveManager.get_unlocked_worms().size())
	worms_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worms_count.add_theme_font_size_override("font_size", 24)
	worms_count.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	worms_vbox.add_child(worms_count)

	var worms_label := Label.new()
	worms_label.text = "Worms"
	worms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worms_label.add_theme_font_size_override("font_size", 12)
	worms_vbox.add_child(worms_label)

	# Patterns count
	var patterns_vbox := VBoxContainer.new()
	hbox.add_child(patterns_vbox)

	var patterns_count := Label.new()
	patterns_count.name = "PatternsCount"
	patterns_count.text = str(SaveManager.get_unlocked_patterns().size())
	patterns_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	patterns_count.add_theme_font_size_override("font_size", 24)
	patterns_count.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	patterns_vbox.add_child(patterns_count)

	var patterns_label := Label.new()
	patterns_label.text = "Patterns"
	patterns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	patterns_label.add_theme_font_size_override("font_size", 12)
	patterns_vbox.add_child(patterns_label)

	# Drops count
	var drops_vbox := VBoxContainer.new()
	hbox.add_child(drops_vbox)

	var drops_count := Label.new()
	drops_count.name = "DropsCount"
	drops_count.text = str(SaveManager.get_total_drops())
	drops_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drops_count.add_theme_font_size_override("font_size", 24)
	drops_count.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	drops_vbox.add_child(drops_count)

	var drops_label := Label.new()
	drops_label.text = "Drops"
	drops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drops_label.add_theme_font_size_override("font_size", 12)
	drops_vbox.add_child(drops_label)

	return panel

func _create_npc_panel(npc_id: String) -> Control:
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.set_corner_radius_all(10)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# NPC portrait placeholder
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(180, 120)
	portrait.color = Color(0.2, 0.2, 0.25)
	vbox.add_child(portrait)

	var portrait_label := Label.new()
	portrait_label.text = "?"
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override("font_size", 48)
	portrait_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(portrait_label)
	panel.set_meta("portrait_label", portrait_label)

	# NPC name
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = npc.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = npc.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = 180
	vbox.add_child(desc_label)

	# Unlock status
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_label)

	# Fight button
	var fight_btn := Button.new()
	fight_btn.name = "FightBtn"
	fight_btn.text = "Fight!"
	fight_btn.custom_minimum_size = Vector2(150, 35)
	fight_btn.pressed.connect(_on_fight.bind(npc_id))
	vbox.add_child(fight_btn)

	panel.set_meta("npc_id", npc_id)
	panel.set_meta("style", style)

	return panel

func _update_npcs() -> void:
	for npc_id in npc_panels:
		var panel: PanelContainer = npc_panels[npc_id]
		var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
		var unlocked := NPCDefs.is_npc_unlocked(npc_id)
		var progress := NPCDefs.get_unlock_progress(npc_id)

		var name_label: Label = panel.find_child("NameLabel", true, false)
		var desc_label: Label = panel.find_child("DescLabel", true, false)
		var status_label: Label = panel.find_child("StatusLabel", true, false)
		var fight_btn: Button = panel.find_child("FightBtn", true, false)
		var portrait_label: Label = panel.get_meta("portrait_label")
		var style: StyleBoxFlat = panel.get_meta("style")

		if unlocked:
			name_label.text = npc.get("name", "???")
			desc_label.text = npc.get("description", "")
			status_label.text = ""
			fight_btn.disabled = false
			fight_btn.text = "Fight!"
			portrait_label.text = npc.get("name", "?")[0]
			portrait_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			style.border_color = Color(0.4, 0.7, 0.4)
		else:
			name_label.text = "???"
			desc_label.text = "Locked"
			status_label.text = "%d / %d\n%s" % [progress["current"], progress["required"], progress["description"]]
			status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
			fight_btn.disabled = true
			fight_btn.text = "Locked"
			portrait_label.text = "?"
			portrait_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			style.border_color = Color(0.3, 0.3, 0.4)

func _on_fight(npc_id: String) -> void:
	# Store the NPC we're fighting for after the battle
	GameState.current_npc_id = npc_id
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://StartMenu.tscn")

func _on_collection() -> void:
	get_tree().change_scene_to_file("res://CollectionScreen.tscn")
