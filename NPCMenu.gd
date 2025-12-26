extends Control
## NPCMenu.gd - NPC selection menu for entering battles
## =====================================================

const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"uncommon": Color(0.3, 0.5, 0.9),
	"rare": Color(0.6, 0.3, 0.8),
	"epic": Color(0.9, 0.4, 0.6),
	"legendary": Color(0.9, 0.3, 0.3),
	"mythic": Color(1.0, 0.8, 0.2),
	"relic": Color(0.4, 0.9, 0.6),
}

var npc_panels: Dictionary = {}
var selected_npc: String = ""
var drops_popup: Control = null
var loadout_popup: Control = null
var chest_popup: Control = null
var coins_label: Label = null

# Hold-to-buy state
var _buying_held := false
var _buying_npc_id := ""
var _buy_hold_time := 0.0
var _buy_repeat_delay := 0.3  # Start buying every 0.3s when held
var _buy_initial_delay := 0.4  # Wait this long before rapid buying starts
var _time_since_last_buy := 0.0

func _ready() -> void:
	_build_ui()
	_update_npcs()

func _process(delta: float) -> void:
	if not _buying_held:
		return

	_buy_hold_time += delta
	_time_since_last_buy += delta

	# Wait for initial delay before rapid buying
	if _buy_hold_time < _buy_initial_delay:
		return

	# Buy repeatedly while held
	if _time_since_last_buy >= _buy_repeat_delay:
		_time_since_last_buy = 0.0
		_do_buy_chest(_buying_npc_id)

		# Speed up as you hold longer (min 0.08s between buys)
		_buy_repeat_delay = maxf(0.08, _buy_repeat_delay * 0.85)

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
	title.text = "Choose Your Opponent"
	Fonts.apply_title(title, 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)

	# Coins display (center)
	var coins_panel := _create_coins_panel()
	header_hbox.add_child(coins_panel)

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
	Fonts.apply_button(back_btn, 16)
	bottom_hbox.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	# Collection button
	var collection_btn := Button.new()
	collection_btn.text = "View Collection"
	collection_btn.custom_minimum_size = Vector2(150, 40)
	collection_btn.pressed.connect(_on_collection)
	Fonts.apply_button(collection_btn, 16)
	bottom_hbox.add_child(collection_btn)

func _create_coins_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.08)
	style.set_corner_radius_all(6)
	style.border_color = Color(0.8, 0.65, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var coin_icon := Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 28)
	hbox.add_child(coin_icon)

	coins_label = Label.new()
	coins_label.text = str(SaveManager.get_coins())
	Fonts.apply_body(coins_label, 26, Color(0.95, 0.85, 0.3))
	hbox.add_child(coins_label)

	return panel

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
	worms_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worms_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(worms_vbox)

	var worms_count := Label.new()
	worms_count.name = "WormsCount"
	worms_count.text = str(SaveManager.get_unlocked_worms().size())
	worms_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(worms_count, 24, Color(0.4, 0.8, 0.4))
	worms_vbox.add_child(worms_count)

	var worms_label := Label.new()
	worms_label.text = "Worms"
	worms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(worms_label, 12, Color.WHITE)
	worms_vbox.add_child(worms_label)

	# Patterns count
	var patterns_vbox := VBoxContainer.new()
	patterns_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patterns_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(patterns_vbox)

	var patterns_count := Label.new()
	patterns_count.name = "PatternsCount"
	patterns_count.text = str(SaveManager.get_unlocked_patterns().size())
	patterns_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(patterns_count, 24, Color(0.4, 0.6, 0.9))
	patterns_vbox.add_child(patterns_count)

	var patterns_label := Label.new()
	patterns_label.text = "Patterns"
	patterns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(patterns_label, 12, Color.WHITE)
	patterns_vbox.add_child(patterns_label)

	# Drops count
	var drops_vbox := VBoxContainer.new()
	drops_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drops_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(drops_vbox)

	var drops_count := Label.new()
	drops_count.name = "DropsCount"
	drops_count.text = str(SaveManager.get_total_drops())
	drops_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(drops_count, 24, Color(0.9, 0.7, 0.3))
	drops_vbox.add_child(drops_count)

	var drops_label := Label.new()
	drops_label.text = "Drops"
	drops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(drops_label, 12, Color.WHITE)
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
	Fonts.apply_body(portrait_label, 48, Color(0.4, 0.4, 0.5))
	portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(portrait_label)
	panel.set_meta("portrait_label", portrait_label)

	# NPC name
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = npc.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(name_label, 18, Color(0.9, 0.9, 0.95))
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = npc.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(desc_label, 12, Color(0.6, 0.6, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = 180
	vbox.add_child(desc_label)

	# Unlock status
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(status_label, 11, Color.WHITE)
	vbox.add_child(status_label)

	# Button container
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(btn_hbox)

	# Fight button
	var fight_btn := Button.new()
	fight_btn.name = "FightBtn"
	fight_btn.text = "Fight!"
	fight_btn.custom_minimum_size = Vector2(70, 35)
	fight_btn.pressed.connect(_on_fight.bind(npc_id))
	Fonts.apply_button(fight_btn, 14)
	btn_hbox.add_child(fight_btn)

	# Fast Play button (only for defeated NPCs)
	var fast_btn := Button.new()
	fast_btn.name = "FastBtn"
	fast_btn.text = "Fast"
	fast_btn.custom_minimum_size = Vector2(45, 35)
	fast_btn.pressed.connect(_on_fast_play.bind(npc_id))
	fast_btn.visible = false  # Hidden until NPC is defeated
	Fonts.apply_button(fast_btn, 12)
	btn_hbox.add_child(fast_btn)

	# View Drops button
	var drops_btn := Button.new()
	drops_btn.name = "DropsBtn"
	drops_btn.text = "Drops"
	drops_btn.custom_minimum_size = Vector2(50, 35)
	drops_btn.pressed.connect(_on_view_drops.bind(npc_id))
	Fonts.apply_button(drops_btn, 12)
	btn_hbox.add_child(drops_btn)

	# View Loadout button (enemy worm + pattern pool)
	var loadout_btn := Button.new()
	loadout_btn.name = "LoadoutBtn"
	loadout_btn.text = "Loadout"
	loadout_btn.custom_minimum_size = Vector2(55, 35)
	loadout_btn.pressed.connect(_on_view_loadout.bind(npc_id))
	Fonts.apply_button(loadout_btn, 12)
	btn_hbox.add_child(loadout_btn)

	# Chest button (only for defeated NPCs)
	var chest_btn := Button.new()
	chest_btn.name = "ChestBtn"
	chest_btn.text = "📦"
	chest_btn.custom_minimum_size = Vector2(40, 35)
	chest_btn.pressed.connect(_on_chest.bind(npc_id))
	chest_btn.visible = false  # Hidden until NPC is defeated
	Fonts.apply_button(chest_btn, 14)
	btn_hbox.add_child(chest_btn)

	panel.set_meta("npc_id", npc_id)
	panel.set_meta("style", style)

	return panel

func _update_npcs() -> void:
	# Update coins display
	if coins_label:
		coins_label.text = str(SaveManager.get_coins())

	for npc_id in npc_panels:
		var panel: PanelContainer = npc_panels[npc_id]
		var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
		var unlocked := NPCDefs.is_npc_unlocked(npc_id)
		var defeated := SaveManager.has_defeated_npc(npc_id)
		var progress := NPCDefs.get_unlock_progress(npc_id)

		var name_label: Label = panel.find_child("NameLabel", true, false)
		var desc_label: Label = panel.find_child("DescLabel", true, false)
		var status_label: Label = panel.find_child("StatusLabel", true, false)
		var fight_btn: Button = panel.find_child("FightBtn", true, false)
		var fast_btn: Button = panel.find_child("FastBtn", true, false)
		var drops_btn: Button = panel.find_child("DropsBtn", true, false)
		var loadout_btn: Button = panel.find_child("LoadoutBtn", true, false)
		var chest_btn: Button = panel.find_child("ChestBtn", true, false)
		var portrait_label: Label = panel.get_meta("portrait_label")
		var style: StyleBoxFlat = panel.get_meta("style")

		if unlocked:
			name_label.text = npc.get("name", "???")
			desc_label.text = npc.get("description", "")
			status_label.text = ""
			fight_btn.disabled = false
			fight_btn.text = "Fight!"
			drops_btn.disabled = false
			loadout_btn.disabled = false
			portrait_label.text = npc.get("name", "?")[0]
			Fonts.apply_body(portrait_label, 48, Color(0.4, 0.9, 0.4))
			style.border_color = Color(0.4, 0.7, 0.4)

			# Show Fast and Chest buttons only if defeated at least once
			fast_btn.visible = defeated
			chest_btn.visible = defeated

			# Update chest button text to show owned count
			if defeated:
				var chest_count := SaveManager.get_chest_count(npc_id)
				if chest_count > 0:
					chest_btn.text = "📦%d" % chest_count
				else:
					chest_btn.text = "📦"
		else:
			name_label.text = "???"
			desc_label.text = "Locked"
			status_label.text = "%d / %d\n%s" % [progress["current"], progress["required"], progress["description"]]
			Fonts.apply_body(status_label, 11, Color(0.8, 0.5, 0.3))
			fight_btn.disabled = true
			fight_btn.text = "Locked"
			fast_btn.visible = false
			chest_btn.visible = false
			drops_btn.disabled = true
			loadout_btn.disabled = true
			portrait_label.text = "?"
			Fonts.apply_body(portrait_label, 48, Color(0.4, 0.4, 0.5))
			style.border_color = Color(0.3, 0.3, 0.4)

func _on_fight(npc_id: String) -> void:
	# Store the NPC we're fighting for after the battle
	GameState.current_npc_id = npc_id
	GameState.fast_play_mode = false
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_fast_play(npc_id: String) -> void:
	# Fast play mode - auto-place worms, random patterns, skip case opening
	GameState.current_npc_id = npc_id
	GameState.fast_play_mode = true
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://StartMenu.tscn")

func _on_collection() -> void:
	get_tree().change_scene_to_file("res://CollectionScreen.tscn")

func _on_chest(npc_id: String) -> void:
	_show_chest_popup(npc_id)

var current_chest_npc_id: String = ""

func _show_chest_popup(npc_id: String) -> void:
	# Close existing popup if any
	if chest_popup != null:
		chest_popup.queue_free()
		chest_popup = null

	current_chest_npc_id = npc_id
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	var chest_cost := NPCDefs.get_npc_chest_cost(npc_id)
	var chest_count := SaveManager.get_chest_count(npc_id)
	var coins := SaveManager.get_coins()

	# Create popup overlay
	chest_popup = ColorRect.new()
	chest_popup.color = Color(0, 0, 0, 0.85)
	chest_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	chest_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(chest_popup)

	# CenterContainer wrapper
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	chest_popup.add_child(center)

	# Main container
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 320)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.8, 0.65, 0.2)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	var npc_name: String = npc.get("name", "???")
	title.text = "%s's Chests" % npc_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 24)
	vbox.add_child(title)

	# Chest icon and count
	var chest_hbox := HBoxContainer.new()
	chest_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(chest_hbox)

	var chest_icon := Label.new()
	chest_icon.text = "📦"
	chest_icon.add_theme_font_size_override("font_size", 48)
	chest_hbox.add_child(chest_icon)

	var owned_label := Label.new()
	owned_label.name = "ChestOwnedLabel"
	owned_label.text = "%d owned" % chest_count
	Fonts.apply_body(owned_label, 20, Color(0.8, 0.8, 0.9))
	chest_hbox.add_child(owned_label)

	# Buttons container
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_vbox)

	# Buy button (supports hold-to-buy)
	var buy_btn := Button.new()
	buy_btn.name = "BuyChestBtn"
	var can_buy := coins >= chest_cost
	buy_btn.text = "Buy Chest (🪙%d)" % chest_cost
	buy_btn.disabled = not can_buy
	buy_btn.custom_minimum_size = Vector2(200, 45)
	buy_btn.button_down.connect(_on_buy_button_down.bind(npc_id))
	buy_btn.button_up.connect(_on_buy_button_up)
	Fonts.apply_button(buy_btn, 16)
	btn_vbox.add_child(buy_btn)

	# Open 1 button
	var open_btn := Button.new()
	open_btn.name = "OpenChestBtn"
	open_btn.text = "Open 1"
	open_btn.disabled = chest_count < 1
	open_btn.custom_minimum_size = Vector2(200, 45)
	open_btn.pressed.connect(_on_open_chest.bind(npc_id, 1))
	Fonts.apply_button(open_btn, 16)
	btn_vbox.add_child(open_btn)

	# Open 5 button
	var open5_btn := Button.new()
	open5_btn.name = "Open5ChestBtn"
	open5_btn.text = "Open 5"
	open5_btn.disabled = chest_count < 5
	open5_btn.custom_minimum_size = Vector2(200, 45)
	open5_btn.pressed.connect(_on_open_chest.bind(npc_id, 5))
	Fonts.apply_button(open5_btn, 16)
	btn_vbox.add_child(open5_btn)

	# Coins display
	var coins_hbox := HBoxContainer.new()
	coins_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(coins_hbox)

	var coins_icon := Label.new()
	coins_icon.text = "🪙"
	coins_icon.add_theme_font_size_override("font_size", 20)
	coins_hbox.add_child(coins_icon)

	var coins_lbl := Label.new()
	coins_lbl.name = "PopupCoinsLabel"
	coins_lbl.text = str(coins)
	Fonts.apply_body(coins_lbl, 18, Color(0.95, 0.85, 0.3))
	coins_hbox.add_child(coins_lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(_close_chest_popup)
	Fonts.apply_button(close_btn, 16)
	vbox.add_child(close_btn)

func _on_buy_button_down(npc_id: String) -> void:
	# Buy one immediately on click
	_do_buy_chest(npc_id)

	# Start hold-to-buy tracking
	_buying_held = true
	_buying_npc_id = npc_id
	_buy_hold_time = 0.0
	_time_since_last_buy = 0.0
	_buy_repeat_delay = 0.3  # Reset to initial delay

func _on_buy_button_up() -> void:
	_buying_held = false
	_buying_npc_id = ""

func _do_buy_chest(npc_id: String) -> void:
	var cost := NPCDefs.get_npc_chest_cost(npc_id)
	if SaveManager.buy_chest(npc_id, cost):
		_update_chest_popup_display(npc_id)
		_update_npcs()
	else:
		# Can't afford, stop rapid buying
		_buying_held = false

func _update_chest_popup_display(npc_id: String) -> void:
	if chest_popup == null:
		return

	var chest_count := SaveManager.get_chest_count(npc_id)
	var coins := SaveManager.get_coins()
	var chest_cost := NPCDefs.get_npc_chest_cost(npc_id)

	var owned_label: Label = chest_popup.find_child("ChestOwnedLabel", true, false)
	if owned_label:
		owned_label.text = "%d owned" % chest_count

	var buy_btn: Button = chest_popup.find_child("BuyChestBtn", true, false)
	if buy_btn:
		buy_btn.disabled = coins < chest_cost

	var open_btn: Button = chest_popup.find_child("OpenChestBtn", true, false)
	if open_btn:
		open_btn.disabled = chest_count < 1

	var open5_btn: Button = chest_popup.find_child("Open5ChestBtn", true, false)
	if open5_btn:
		open5_btn.disabled = chest_count < 5

	var coins_lbl: Label = chest_popup.find_child("PopupCoinsLabel", true, false)
	if coins_lbl:
		coins_lbl.text = str(coins)

func _on_open_chest(npc_id: String, count: int) -> void:
	# Check if player has enough chests (don't consume yet - wait for click)
	if SaveManager.get_chest_count(npc_id) < count:
		return

	_close_chest_popup()

	# Set up GameState for chest opening (VictoryScreen will consume on click)
	GameState.current_npc_id = npc_id
	GameState.chest_open_count = count
	GameState.is_chest_opening = true

	get_tree().change_scene_to_file("res://VictoryScreen.tscn")

func _close_chest_popup() -> void:
	if chest_popup != null:
		chest_popup.queue_free()
		chest_popup = null

var current_drops_chances: Dictionary = {}

func _on_view_drops(npc_id: String) -> void:
	# Close existing popup if any
	if drops_popup != null:
		drops_popup.queue_free()
		drops_popup = null

	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	var loot_pool := NPCDefs.get_npc_loot_pool(npc_id)
	current_drops_chances = NPCDefs.get_loot_chances(npc_id)

	# Create popup overlay
	drops_popup = ColorRect.new()
	drops_popup.color = Color(0, 0, 0, 0.85)
	drops_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	drops_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(drops_popup)

	# CenterContainer wrapper for proper centering
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	drops_popup.add_child(center)

	# Main container - no manual position offset needed
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "%s - Possible Drops" % npc.get("name", "???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 24)
	vbox.add_child(title)

	# Scroll container for items
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 280)
	vbox.add_child(scroll)

	var items_vbox := VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(items_vbox)

	# Group items by type
	var worms: Array = []
	var patterns: Array = []
	for item in loot_pool:
		if item["type"] == "worm":
			worms.append(item)
		else:
			patterns.append(item)

	# Show worms
	if worms.size() > 0:
		var worms_label := Label.new()
		worms_label.text = "Worms"
		Fonts.apply_body(worms_label, 16, Color(0.5, 0.8, 0.5))
		items_vbox.add_child(worms_label)

		for item in worms:
			var item_row := _create_drop_item_row(item)
			items_vbox.add_child(item_row)

	# Show patterns
	if patterns.size() > 0:
		var patterns_label := Label.new()
		patterns_label.text = "Attack Patterns"
		Fonts.apply_body(patterns_label, 16, Color(0.5, 0.6, 0.9))
		items_vbox.add_child(patterns_label)

		for item in patterns:
			var item_row := _create_drop_item_row(item)
			items_vbox.add_child(item_row)

	# Show relics
	var relics := NPCDefs.get_npc_relic_info(npc_id)
	if relics.size() > 0:
		var relics_label := Label.new()
		relics_label.text = "Rare Relics"
		Fonts.apply_body(relics_label, 16, Color(0.4, 0.9, 0.6))
		items_vbox.add_child(relics_label)

		for relic in relics:
			var item_row := _create_relic_row(relic)
			items_vbox.add_child(item_row)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(_close_drops_popup)
	Fonts.apply_button(close_btn, 16)
	vbox.add_child(close_btn)

func _create_drop_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var item_name: String = item.get("name", "???")
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var chance: float = current_drops_chances.get(item_name, 0.0)
	var is_owned := false

	if item["type"] == "worm":
		is_owned = SaveManager.has_worm(item["name"])
	else:
		is_owned = SaveManager.has_pattern(item["name"])

	# Left margin spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	row.add_child(spacer)

	# Percentage chance
	var chance_label := Label.new()
	if chance >= 10.0:
		chance_label.text = "%d%%" % int(chance)
	else:
		chance_label.text = "%.1f%%" % chance
	chance_label.custom_minimum_size.x = 45
	chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Fonts.apply_body(chance_label, 12, Color(0.7, 0.7, 0.5))
	row.add_child(chance_label)

	# Shape preview
	var cells: Array = []
	if item["type"] == "worm":
		var worm_def: Dictionary = WormDefs.WORMS.get(item["name"], {})
		cells = worm_def.get("cells", [])
	else:
		var pattern: Dictionary = PatternDefs.get_pattern(item["name"])
		cells = pattern.get("cells", [])

	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(80, 30)
	row.add_child(shape_container)
	_draw_shape(shape_container, cells, rarity_color)

	# Name
	var name_label := Label.new()
	name_label.text = item["name"]
	name_label.custom_minimum_size.x = 100
	Fonts.apply_body(name_label, 14, rarity_color)
	row.add_child(name_label)

	# Rarity
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.custom_minimum_size.x = 70
	Fonts.apply_body(rarity_label, 12, rarity_color.darkened(0.2))
	row.add_child(rarity_label)

	# Owned status
	var owned_label := Label.new()
	if is_owned:
		owned_label.text = "Owned"
		Fonts.apply_body(owned_label, 12, Color(0.4, 0.8, 0.4))
	else:
		owned_label.text = "Not owned"
		Fonts.apply_body(owned_label, 12, Color(0.5, 0.5, 0.5))
	row.add_child(owned_label)

	return row

func _create_relic_row(relic: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var relic_name: String = relic.get("name", "???")
	var slot: String = relic.get("slot", "")
	var bonus: String = relic.get("bonus", "")
	var odds: int = relic.get("odds", 0)
	var is_owned: bool = relic.get("owned", false)
	var rarity_color := Color(0.4, 0.9, 0.6)

	# Left margin spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	row.add_child(spacer)

	# Odds display (1 in X)
	var odds_label := Label.new()
	odds_label.text = "1/%d" % odds if odds > 0 else "???"
	odds_label.custom_minimum_size.x = 50
	odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Fonts.apply_body(odds_label, 12, Color(0.6, 0.6, 0.7))
	row.add_child(odds_label)

	# Slot icon
	var slot_icons := {"hat": "👑", "back": "🎒", "hands": "🧤", "neck": "📿", "feet": "👢"}
	var slot_label := Label.new()
	slot_label.text = slot_icons.get(slot, "❓")
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.custom_minimum_size.x = 24
	row.add_child(slot_label)

	# Name
	var name_label := Label.new()
	name_label.text = relic_name
	name_label.custom_minimum_size.x = 160
	if is_owned:
		Fonts.apply_body(name_label, 14, rarity_color)
	else:
		Fonts.apply_body(name_label, 14, Color(0.8, 0.8, 0.85))
	row.add_child(name_label)

	# Owned status
	var owned_label := Label.new()
	if is_owned:
		owned_label.text = "Owned"
		Fonts.apply_body(owned_label, 12, Color(0.4, 0.8, 0.4))
	else:
		owned_label.text = ""
		Fonts.apply_body(owned_label, 12, Color(0.5, 0.5, 0.5))
	row.add_child(owned_label)

	return row

func _close_drops_popup() -> void:
	if drops_popup != null:
		drops_popup.queue_free()
		drops_popup = null

func _on_view_loadout(npc_id: String) -> void:
	# Close existing popup if any
	if loadout_popup != null:
		loadout_popup.queue_free()
		loadout_popup = null

	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})

	# Get NPC's loadout
	var loadout_worms := NPCDefs.get_npc_loadout_worms(npc_id)
	var loadout_patterns := NPCDefs.get_npc_loadout_patterns(npc_id)

	# Create popup overlay
	loadout_popup = ColorRect.new()
	loadout_popup.color = Color(0, 0, 0, 0.85)
	loadout_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	loadout_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(loadout_popup)

	# CenterContainer wrapper for proper centering
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	loadout_popup.add_child(center)

	# Main container - no manual position offset needed
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(550, 500)
	center.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(12)
	style.border_color = Color(0.5, 0.4, 0.6)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "%s - Battle Loadout" % npc.get("name", "???")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title, 24)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Worms and attack patterns this enemy uses in battle:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(desc, 14, Color(0.6, 0.6, 0.7))
	vbox.add_child(desc)

	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 350)
	vbox.add_child(scroll)

	var items_vbox := VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(items_vbox)

	# Show worms section
	var worms_header := Label.new()
	worms_header.text = "Worms (picks 2 for battle)"
	Fonts.apply_body(worms_header, 16, Color(0.5, 0.8, 0.5))
	items_vbox.add_child(worms_header)

	for worm_name in loadout_worms:
		var worm_def: Dictionary = WormDefs.WORMS.get(worm_name, {})
		var worm_row := _create_loadout_item_row(worm_name, worm_def, "worm")
		items_vbox.add_child(worm_row)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	items_vbox.add_child(spacer)

	# Show patterns section
	var patterns_header := Label.new()
	patterns_header.text = "Attack Patterns"
	Fonts.apply_body(patterns_header, 16, Color(0.5, 0.6, 0.9))
	items_vbox.add_child(patterns_header)

	for pattern_name in loadout_patterns:
		var pattern: Dictionary = PatternDefs.get_pattern(pattern_name)
		var pattern_row := _create_loadout_item_row(pattern_name, pattern, "pattern")
		items_vbox.add_child(pattern_row)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.pressed.connect(_close_loadout_popup)
	Fonts.apply_button(close_btn, 16)
	vbox.add_child(close_btn)

func _create_loadout_item_row(item_name: String, item_def: Dictionary, item_type: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var rarity: String = item_def.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	# Left margin spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 8
	row.add_child(spacer)

	# Icon
	var icon := Label.new()
	icon.text = "🐛" if item_type == "worm" else "💥"
	Fonts.apply_body(icon, 16, Color.WHITE)
	row.add_child(icon)

	# Shape preview
	var cells: Array = item_def.get("cells", [])
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(80, 30)
	row.add_child(shape_container)
	_draw_shape(shape_container, cells, rarity_color)

	# Name
	var name_label := Label.new()
	name_label.text = item_name
	name_label.custom_minimum_size.x = 110
	Fonts.apply_body(name_label, 14, rarity_color)
	row.add_child(name_label)

	# Rarity
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.custom_minimum_size.x = 70
	Fonts.apply_body(rarity_label, 12, rarity_color.darkened(0.2))
	row.add_child(rarity_label)

	# Cell count
	var size_label := Label.new()
	size_label.text = "%d cells" % cells.size()
	Fonts.apply_body(size_label, 12, Color(0.5, 0.5, 0.6))
	row.add_child(size_label)

	return row

func _draw_shape(container: Control, cells: Array, color: Color) -> void:
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

	var cell_size := mini(int(70.0 / width), int(24.0 / height))
	cell_size = clampi(cell_size, 5, 10)

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

func _close_loadout_popup() -> void:
	if loadout_popup != null:
		loadout_popup.queue_free()
		loadout_popup = null
