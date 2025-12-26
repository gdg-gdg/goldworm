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
	"relic": Color(0.4, 0.9, 0.6),
}

const ITEM_WIDTH := 120
const ITEM_HEIGHT := 140
const VISIBLE_ITEMS := 7
const STRIP_ITEMS := 50
const SPIN_DURATION := 5.0
const SPIN_SPEED_PX_PER_SEC := 1200.0  # same for single + multi
const START_EDGE_PAD := 8.0            # don't start right on a border
const END_EDGE_PAD := 8.0              # optional: keeps end away from exact borders

var npc_id: String = ""
var loot_item: Dictionary = {}
var loot_items: Array = []  # For multi-case opening
var case_opened := false
var loot_pool: Array = []
var loot_chances: Dictionary = {}
var opening_chest_mode := false
var multi_case_count := 1

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
var open_more_btn: Button
var open_another_btn: Button

# Multi-case UI
var multi_case_area: Control
var multi_strips: Array = []
var multi_pointers: Array = []

# Tick sound
var tick_player: AudioStreamPlayer
var _tick_state_single := {"last": -999999}

func _ready() -> void:
	npc_id = GameState.current_npc_id
	loot_pool = NPCDefs.get_npc_loot_pool(npc_id)
	loot_chances = NPCDefs.get_loot_chances(npc_id)

	# Check if we're opening chests from NPCMenu (read from GameState)
	opening_chest_mode = GameState.is_chest_opening
	multi_case_count = GameState.chest_open_count

	# Reset GameState variables for next time
	GameState.is_chest_opening = false
	GameState.chest_open_count = 1

	_build_ui()

	# Setup tick sound for spin animation
	tick_player = AudioStreamPlayer.new()
	tick_player.stream = preload("res://sounds/tick.wav")
	tick_player.volume_db = -10
	tick_player.max_polyphony = 8  # lets rapid ticks overlap cleanly
	add_child(tick_player)

	# Award coins only for battle victories (not chest opening)
	if not opening_chest_mode:
		var coin_reward := NPCDefs.get_npc_coin_reward(npc_id)
		SaveManager.add_coins(coin_reward)

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

	# Title and coins row
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 40)
	main_vbox.add_child(title_row)

	# Victory title
	title_label = Label.new()
	if opening_chest_mode:
		title_label.text = "OPEN CHEST"
	else:
		title_label.text = "VICTORY!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_title(title_label, 48)
	title_row.add_child(title_label)

	# Coins display (for battle victories, show reward)
	if not opening_chest_mode:
		var coin_reward := NPCDefs.get_npc_coin_reward(npc_id)
		var coins_hbox := HBoxContainer.new()
		coins_hbox.add_theme_constant_override("separation", 8)
		title_row.add_child(coins_hbox)

		var coin_icon := Label.new()
		coin_icon.text = "🪙"
		coin_icon.add_theme_font_size_override("font_size", 28)
		coins_hbox.add_child(coin_icon)

		var coin_text := Label.new()
		coin_text.text = "+%d" % coin_reward
		Fonts.apply_body(coin_text, 24, Color(0.95, 0.85, 0.3))
		coins_hbox.add_child(coin_text)

	# Defeated NPC name / Chest info
	var npc: Dictionary = NPCDefs.NPCS.get(npc_id, {})
	defeated_label = Label.new()
	if opening_chest_mode:
		if multi_case_count > 1:
			defeated_label.text = "Opening %d of %s's chests..." % [multi_case_count, npc.get("name", "???")]
		else:
			defeated_label.text = "%s's chest" % npc.get("name", "???")
	else:
		defeated_label.text = "You defeated %s!" % npc.get("name", "???")
	defeated_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(defeated_label, 20, Color(0.7, 0.8, 0.7))
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
	box_icon.text = "?"
	box_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Fonts.apply_body(box_icon, 64, Color.WHITE)
	box_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_vbox.add_child(box_icon)

	var box_label := Label.new()
	box_label.text = "CLICK TO OPEN"
	box_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Fonts.apply_body(box_label, 16, Color(0.9, 0.7, 0.3))
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
	btn_hbox.custom_minimum_size = Vector2(0, 60)  # Reserve height so nothing jumps
	main_vbox.add_child(btn_hbox)

	continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(150, 50)
	continue_btn.pressed.connect(_on_continue)
	Fonts.apply_button(continue_btn, 18)
	btn_hbox.add_child(continue_btn)

	# Open Another button (for single case, if player has more chests)
	open_another_btn = Button.new()
	open_another_btn.text = "Open Another"
	open_another_btn.custom_minimum_size = Vector2(180, 50)
	open_another_btn.pressed.connect(_on_open_another)
	Fonts.apply_button(open_another_btn, 18)
	btn_hbox.add_child(open_another_btn)

	# Open 5 More button (only shown after opening 5 chests if player has more)
	open_more_btn = Button.new()
	open_more_btn.text = "Open 5 More"
	open_more_btn.custom_minimum_size = Vector2(200, 50)
	open_more_btn.pressed.connect(_on_open_more)
	Fonts.apply_button(open_more_btn, 18)
	btn_hbox.add_child(open_more_btn)

	# Hide buttons without layout reflow
	_set_button_hidden(continue_btn, true)
	_set_button_hidden(open_another_btn, true)
	_set_button_hidden(open_more_btn, true)

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
	Fonts.apply_title(title, 18)
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
		worms_label.text = "Worms"
		Fonts.apply_body(worms_label, 14, Color(0.5, 0.8, 0.5))
		vbox.add_child(worms_label)

		for item in worms:
			var row := _create_contents_row(item)
			vbox.add_child(row)

	# Show patterns section
	if patterns.size() > 0:
		var patterns_label := Label.new()
		patterns_label.text = "Patterns"
		Fonts.apply_body(patterns_label, 14, Color(0.5, 0.6, 0.9))
		vbox.add_child(patterns_label)

		for item in patterns:
			var row := _create_contents_row(item)
			vbox.add_child(row)

	# Show relics section
	var relics := NPCDefs.get_npc_relic_info(npc_id)
	if relics.size() > 0:
		var relics_label := Label.new()
		relics_label.text = "Rare Relics"
		Fonts.apply_body(relics_label, 14, Color(0.4, 0.9, 0.6))
		vbox.add_child(relics_label)

		for relic in relics:
			var row := _create_relic_contents_row(relic)
			vbox.add_child(row)

	return panel

func _create_contents_row(item: Dictionary) -> HBoxContainer:
	var item_name: String = item.get("name", "???")
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_owned := _is_item_owned(item)
	var chance: float = loot_chances.get(item_name, 0.0)

	# Dim if owned
	var display_color := rarity_color.darkened(0.4) if is_owned else rarity_color

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	if is_owned:
		row.modulate.a = 0.5

	# Small margin/spacer at start
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 4
	row.add_child(spacer)

	# Percentage chance
	var chance_label := Label.new()
	if chance >= 10.0:
		chance_label.text = "%d%%" % int(chance)
	else:
		chance_label.text = "%.1f%%" % chance
	chance_label.custom_minimum_size.x = 40
	chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Fonts.apply_body(chance_label, 11, Color(0.7, 0.7, 0.5))
	row.add_child(chance_label)

	# Shape preview - with proper centering
	var shape_container := Control.new()
	shape_container.custom_minimum_size = Vector2(55, 24)
	row.add_child(shape_container)
	_draw_mini_shape(shape_container, item, display_color)

	# Name
	var name_label := Label.new()
	name_label.text = item_name
	name_label.custom_minimum_size.x = 75
	Fonts.apply_body(name_label, 12, display_color)
	row.add_child(name_label)

	# Rarity badge
	var rarity_label := Label.new()
	rarity_label.text = rarity.substr(0, 3).to_upper()
	Fonts.apply_body(rarity_label, 10, display_color.darkened(0.1))
	row.add_child(rarity_label)

	# Owned checkmark
	if is_owned:
		var check := Label.new()
		check.text = "Y"
		Fonts.apply_body(check, 14, Color(0.3, 0.8, 0.3))
		row.add_child(check)

	return row

func _create_relic_contents_row(relic: Dictionary) -> HBoxContainer:
	var relic_name: String = relic.get("name", "???")
	var slot: String = relic.get("slot", "")
	var odds: int = relic.get("odds", 0)
	var is_owned: bool = relic.get("owned", false)
	var rarity_color := Color(0.4, 0.9, 0.6)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	if is_owned:
		row.modulate.a = 0.5

	# Small margin/spacer at start
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 4
	row.add_child(spacer)

	# Odds display (1 in X)
	var odds_label := Label.new()
	odds_label.text = "1/%d" % odds if odds > 0 else "???"
	odds_label.custom_minimum_size.x = 40
	odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Fonts.apply_body(odds_label, 10, Color(0.6, 0.6, 0.7))
	row.add_child(odds_label)

	# Slot icon
	var slot_icons := {"hat": "👑", "back": "🎒", "hands": "🧤", "neck": "📿", "feet": "👢"}
	var slot_label := Label.new()
	slot_label.text = slot_icons.get(slot, "❓")
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.custom_minimum_size.x = 20
	row.add_child(slot_label)

	# Name (truncated if needed)
	var name_label := Label.new()
	name_label.text = relic_name
	name_label.custom_minimum_size.x = 120
	name_label.clip_text = true
	if is_owned:
		Fonts.apply_body(name_label, 11, rarity_color.darkened(0.4))
	else:
		Fonts.apply_body(name_label, 11, rarity_color)
	row.add_child(name_label)

	# Owned check
	if is_owned:
		var check := Label.new()
		check.text = "Y"
		Fonts.apply_body(check, 12, Color(0.3, 0.8, 0.3))
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

func _set_button_hidden(btn: Button, hidden: bool) -> void:
	btn.disabled = hidden
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if hidden else Control.MOUSE_FILTER_STOP
	btn.modulate.a = 0.0 if hidden else 1.0

func _create_item_panel(item: Dictionary, dim_if_owned: bool = false, custom_size: Vector2 = Vector2(ITEM_WIDTH, ITEM_HEIGHT)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = custom_size  # Use the passed size
	panel.set_meta("loot_item", item)  # Store for measuring winner later

	var item_name: String = item.get("name", "???")
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var chance: float = loot_chances.get(item_name, 0.0)
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

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Top row: emoji and percentage
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	# Emoji icon - scale based on panel size
	var icon := Label.new()
	icon.text = "🐛" if item.get("type") == "worm" else "💥"
	var icon_size := 14 if custom_size.x < 100 else 20
	icon.add_theme_font_size_override("font_size", icon_size)
	top_row.add_child(icon)

	var chance_label := Label.new()
	if chance >= 10.0:
		chance_label.text = "%d%%" % int(chance)
	else:
		chance_label.text = "%.1f%%" % chance
	var chance_font_size := 10 if custom_size.x < 100 else 12
	Fonts.apply_body(chance_label, chance_font_size, Color(0.9, 0.85, 0.5))
	top_row.add_child(chance_label)

	# Shape preview - sized based on panel
	var shape_container := Control.new()
	var shape_height := 32 if custom_size.x < 100 else 50
	shape_container.custom_minimum_size = Vector2(custom_size.x - 12, shape_height)
	shape_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(shape_container)
	_draw_shape_preview(shape_container, item, display_color)

	# Name
	var name_label := Label.new()
	name_label.text = item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = custom_size.x - 8
	var name_font_size := 9 if custom_size.x < 100 else 11
	Fonts.apply_body(name_label, name_font_size, display_color)
	vbox.add_child(name_label)

	# Green tick overlay for owned items
	if should_dim:
		var tick_label := Label.new()
		tick_label.text = "Y"
		tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var tick_size := 32 if custom_size.x < 100 else 48
		Fonts.apply_body(tick_label, tick_size, Color(0.3, 0.9, 0.3, 0.8))
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

# =============================================================================
# WEIGHTED STRIP HELPERS
# =============================================================================

func _pick_item_under_pointer(strip_node: Control, pointer_node: Control) -> Dictionary:
	# pointer center X in global space
	var pointer_center_global_x: float = pointer_node.global_position.x + (pointer_node.size.x * 0.5)

	# convert to strip_node local X by subtracting strip_node's global X
	var pointer_x_local: float = pointer_center_global_x - strip_node.global_position.x

	var best_child: Control = null
	var best_dist: float = INF

	for child in strip_node.get_children():
		if not (child is Control):
			continue
		var c := child as Control
		var left := c.position.x
		var right := c.position.x + c.size.x

		# if pointer is inside this child rect, winner
		if pointer_x_local >= left and pointer_x_local <= right:
			return c.get_meta("loot_item", {})

		# else choose nearest by center
		var center := left + c.size.x * 0.5
		var d = abs(pointer_x_local - center)
		if d < best_dist:
			best_dist = d
			best_child = c

	return best_child.get_meta("loot_item", {}) if best_child else {}


func _fill_strip_weighted(strip_node: HBoxContainer, count: int, custom_size: Vector2) -> void:
	for i in range(count):
		var item: Dictionary = NPCDefs.roll_loot(npc_id)  # weighted roll
		var panel := _create_item_panel(item, true, custom_size)
		strip_node.add_child(panel)

func _ensure_strip_has_enough_items(strip_node: HBoxContainer, viewport_width: float, item_width: float, custom_size: Vector2) -> void:
	# We need enough content width so that even after travelling SPIN_DISTANCE we still have items.
	# Add a buffer so clamping never hits "empty".
	var distance_px := SPIN_SPEED_PX_PER_SEC * SPIN_DURATION
	var needed_content_width := viewport_width + distance_px + item_width * 4.0
	var needed_items := int(ceili(needed_content_width / item_width)) + 10

	for i in range(needed_items):
		var item: Dictionary = NPCDefs.roll_loot(npc_id)
		var panel := _create_item_panel(item, true, custom_size)
		strip_node.add_child(panel)

func _target_x_to_center_child(strip_node: Control, viewport_width: float, child_index: int) -> float:
	var child := strip_node.get_child(child_index) as Control
	var clip_center := viewport_width * 0.5
	var item_center := child.position.x + child.size.x * 0.5
	return clip_center - item_center

func _on_open_case() -> void:
	if case_opened:
		return

	case_opened = true
	loot_box_btn.disabled = true

	# Consume chests now that player has clicked to open
	if opening_chest_mode:
		SaveManager.use_chest(npc_id, multi_case_count)

	if multi_case_count > 1:
		await _open_multi_case()
	else:
		await _open_single_case()

func _open_single_case() -> void:
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

	# Record NPC defeat only for battle victories
	if not opening_chest_mode:
		SaveManager.record_npc_defeat(npc_id)

	_set_button_hidden(continue_btn, false)

	# Show "Open Another" if player has more chests
	var remaining := SaveManager.get_chest_count(npc_id)
	if remaining >= 1:
		open_another_btn.text = "Open Another (%d left)" % remaining
		_set_button_hidden(open_another_btn, false)

func _open_multi_case() -> void:
	# Dramatic box opening effect
	await _play_box_open_animation()

	# Hide loot box and contents panel
	loot_box_btn.get_parent().visible = false
	contents_panel.visible = false
	defeated_label.text = "Opening %d cases..." % multi_case_count

	# STEP 2: Build strips - each strip gets its corresponding loot_items[i]
	_build_multi_case_area()

	await get_tree().create_timer(0.3).timeout

	# STEP 3: Animate - strips land on their predetermined items
	await _play_multi_spin_animation()

	# STEP 4: Show results
	_show_multi_results()

	# STEP 5: Save - read from strip_data["result"] to guarantee match
	for strip_data in multi_strips:
		loot_item = strip_data["result"]
		_save_unlock()

	# Record NPC defeat only for battle victories
	if not opening_chest_mode:
		SaveManager.record_npc_defeat(npc_id)

	_set_button_hidden(continue_btn, false)

	# Show "Open 5 More" button if in chest mode and player has 5+ more chests
	var remaining := SaveManager.get_chest_count(npc_id)
	if opening_chest_mode and remaining >= 5:
		open_more_btn.text = "Open 5 More (%d left)" % remaining
		_set_button_hidden(open_more_btn, false)

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
	# Clear strip
	for child in strip.get_children():
		child.queue_free()
	await get_tree().process_frame

	# Fill enough items for fixed-distance travel
	var viewport_width := strip_container.size.x
	_ensure_strip_has_enough_items(strip, viewport_width, ITEM_WIDTH, Vector2(ITEM_WIDTH, ITEM_HEIGHT))
	await get_tree().process_frame

	# Random START inside the first item (this is the only randomness that affects landing)
	# NOTE: keep it <= 0 so we never reveal empty space on the left.
	var start_x := -randf_range(START_EDGE_PAD, ITEM_WIDTH - START_EDGE_PAD)

	# Fixed distance + fixed duration => same speed every time
	var distance_px := SPIN_SPEED_PX_PER_SEC * SPIN_DURATION
	var target_x := start_x - distance_px

	# Optional: nudge end away from borders a touch without changing distance/speed:
	# (We do this by shifting BOTH start and target equally. Keeps distance identical.)
	var end_nudge := randf_range(-END_EDGE_PAD, END_EDGE_PAD)
	start_x += end_nudge
	target_x += end_nudge

	# Clamp to never show empty
	var content_w := strip.size.x
	var max_scroll := maxf(0.0, content_w - viewport_width)
	var max_x := -max_scroll
	start_x = clampf(start_x, max_x, 0.0)
	target_x = clampf(target_x, max_x, 0.0)

	strip.position.x = start_x

	# Drawn-out deceleration, no settle, no overshoot - EXPO has longest tail
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(strip, "position:x", target_x, SPIN_DURATION)

	_flash_pointer_during_spin(SPIN_DURATION)
	await tween.finished
	await get_tree().process_frame

	# Decide winner by measuring under gold bar
	loot_item = _pick_item_under_pointer(strip, pointer)

	# End flash
	for i in range(5):
		pointer.color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		pointer.color = Color(1.0, 0.8, 0.2)
		await get_tree().create_timer(0.1).timeout


func _tick_if_crossed_child(strip_node: Control, pointer_node: Control, state: Dictionary) -> void:
	# pointer center in strip local
	var pointer_center_global_x := pointer_node.global_position.x + pointer_node.size.x * 0.5
	var pointer_local_x := pointer_center_global_x - strip_node.global_position.x

	var winner_index := -1
	var best_dist := INF

	var kids := strip_node.get_children()
	for i in range(kids.size()):
		var c := kids[i]
		if not (c is Control):
			continue
		var cc := c as Control
		var left := cc.position.x
		var right := cc.position.x + cc.size.x

		# if pointer is inside, that's the winner immediately
		if pointer_local_x >= left and pointer_local_x <= right:
			winner_index = i
			break

		# else choose nearest
		var center := left + cc.size.x * 0.5
		var d = abs(pointer_local_x - center)
		if d < best_dist:
			best_dist = d
			winner_index = i

	if winner_index == -1:
		return

	if state.get("last", -999999) == winner_index:
		return

	state["last"] = winner_index

	if tick_player and tick_player.stream:
		tick_player.pitch_scale = randf_range(0.96, 1.04)
		tick_player.play()

func _flash_pointer_during_spin(duration: float) -> void:
	_tick_state_single["last"] = -999999
	var elapsed := 0.0
	while elapsed < duration:
		_tick_if_crossed_child(strip, pointer, _tick_state_single)

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
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(hbox)

	# Shape visual icon
	var cells: Array = loot_item.get("cells", [])
	var shape := _create_shape_visual(cells, rarity_color, 10.0)
	hbox.add_child(shape)

	# Info
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 5)
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(info_vbox)

	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	Fonts.apply_body(rarity_label, 14, rarity_color)
	info_vbox.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = loot_item.get("name", "???")
	Fonts.apply_title(name_label, 28)
	info_vbox.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "Worm" if loot_item.get("type") == "worm" else "Attack Pattern"
	Fonts.apply_body(type_label, 12, Color(0.6, 0.6, 0.7))
	info_vbox.add_child(type_label)

	# New/duplicate status
	var status_label := Label.new()
	if is_new:
		status_label.text = "NEW!"
		Fonts.apply_body(status_label, 16, Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "(Already owned)"
		Fonts.apply_body(status_label, 16, Color(0.5, 0.5, 0.5))
	info_vbox.add_child(status_label)

func _save_unlock() -> void:
	var rarity: String = loot_item.get("rarity", "common")

	if loot_item.get("type") == "worm":
		SaveManager.unlock_worm(loot_item["name"], rarity)
	else:
		SaveManager.unlock_pattern(loot_item["name"], rarity)

func _on_continue() -> void:
	# Reset fast play mode when leaving
	GameState.fast_play_mode = false
	get_tree().change_scene_to_file("res://NPCMenu.tscn")

func _on_open_another() -> void:
	if SaveManager.get_chest_count(npc_id) < 1:
		_set_button_hidden(open_another_btn, true)
		return

	SaveManager.use_chest(npc_id, 1)

	_set_button_hidden(continue_btn, true)
	_set_button_hidden(open_another_btn, true)

	# Hide result panel
	result_panel.visible = false

	defeated_label.text = "Opening another chest..."

	await get_tree().create_timer(0.3).timeout
	await _play_spin_animation()

	_show_result()
	_save_unlock()

	_set_button_hidden(continue_btn, false)

	# Show "Open Another" if player has more chests
	var remaining := SaveManager.get_chest_count(npc_id)
	if remaining >= 1:
		open_another_btn.text = "Open Another (%d left)" % remaining
		_set_button_hidden(open_another_btn, false)

func _on_open_more() -> void:
	if SaveManager.get_chest_count(npc_id) < 5:
		_set_button_hidden(open_more_btn, true)
		return

	SaveManager.use_chest(npc_id, 5)

	_set_button_hidden(continue_btn, true)
	_set_button_hidden(open_more_btn, true)

	# Clear old strips and results (all inside multi_case_area)
	if multi_case_area:
		multi_case_area.queue_free()
		multi_case_area = null
	await get_tree().process_frame

	multi_strips = []
	multi_pointers = []

	multi_case_count = 5
	defeated_label.text = "Opening 5 more chests..."

	_build_multi_case_area()
	await get_tree().create_timer(0.3).timeout
	await _play_multi_spin_animation()
	_show_multi_results()

	# Save using strip_data["result"] to guarantee match
	for strip_data in multi_strips:
		loot_item = strip_data["result"]
		_save_unlock()

	_set_button_hidden(continue_btn, false)

	var remaining := SaveManager.get_chest_count(npc_id)
	if remaining >= 5:
		open_more_btn.text = "Open 5 More (%d left)" % remaining
		_set_button_hidden(open_more_btn, false)

func _instant_loot() -> void:
	## Fast play mode - skip animation, show result immediately
	case_opened = true

	# Roll for loot
	loot_item = NPCDefs.roll_loot(npc_id)

	# Hide the loot box button and contents panel
	loot_box_btn.get_parent().visible = false
	contents_panel.visible = false

	# Update title for fast mode
	defeated_label.text = "Quick loot!"

	# Show result immediately
	_show_result()

	# Save the unlock
	_save_unlock()

	# Record NPC defeat
	SaveManager.record_npc_defeat(npc_id)

	_set_button_hidden(continue_btn, false)

func _create_shape_visual(cells: Array, color: Color, size: float = 12.0) -> Control:
	var container := Control.new()

	if cells.is_empty():
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

	container.custom_minimum_size = Vector2(width * (size + 2), height * (size + 2))

	for cell in cells:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(size, size)
		dot.color = color
		dot.position = Vector2((cell.x - min_x) * (size + 2), (cell.y - min_y) * (size + 2))
		container.add_child(dot)

	return container

# =============================================================================
# MULTI-CASE OPENING (Open 5)
# =============================================================================

const MULTI_ITEM_WIDTH := 80
const MULTI_ITEM_HEIGHT := 90
const MULTI_VISIBLE_ITEMS := 7
const MULTI_STRIP_ITEMS := 40

func _build_multi_case_area() -> void:
	# Create a container for all 5 case strips stacked vertically
	multi_case_area = VBoxContainer.new()
	multi_case_area.add_theme_constant_override("separation", 4)
	multi_case_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(multi_case_area)

	multi_strips = []
	multi_pointers = []

	for i in range(multi_case_count):
		var strip_row := _create_multi_strip_row(i)
		multi_case_area.add_child(strip_row)

func _create_multi_strip_row(index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)

	# 1. LEFT SIDE: Empty spacer (same width as right side for symmetry)
	var left_info := Control.new()
	left_info.custom_minimum_size = Vector2(180, MULTI_ITEM_HEIGHT)
	row.add_child(left_info)

	# 2. CENTER: The Strip Viewport
	var strip_area := Control.new()
	strip_area.custom_minimum_size = Vector2(MULTI_ITEM_WIDTH * MULTI_VISIBLE_ITEMS, MULTI_ITEM_HEIGHT)
	strip_area.clip_contents = true
	row.add_child(strip_area)

	# Add background to strip area
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip_area.add_child(bg)

	# Border around strip
	var border := ColorRect.new()
	border.color = Color(0.35, 0.3, 0.2)
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.offset_left = -3
	border.offset_top = -3
	border.offset_right = 3
	border.offset_bottom = 3
	border.z_index = -1
	strip_area.add_child(border)

	# The scrolling strip
	var strip_node := HBoxContainer.new()
	strip_node.add_theme_constant_override("separation", 0)
	strip_area.add_child(strip_node)

	# Center pointer
	var pointer := ColorRect.new()
	pointer.color = Color(1.0, 0.8, 0.2)
	pointer.anchor_left = 0.5
	pointer.anchor_right = 0.5
	pointer.anchor_top = 0.0
	pointer.anchor_bottom = 1.0
	pointer.offset_left = -1.5
	pointer.offset_right = 1.5
	pointer.offset_top = -5
	pointer.offset_bottom = 5
	strip_area.add_child(pointer)
	multi_pointers.append(pointer)

	# 3. RIGHT SIDE: Result label (same width as left for symmetry)
	var right_label := Label.new()
	right_label.custom_minimum_size = Vector2(180, MULTI_ITEM_HEIGHT)
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_label.pivot_offset = Vector2(0, MULTI_ITEM_HEIGHT / 2)
	Fonts.apply_body(right_label, 14, Color.WHITE)
	row.add_child(right_label)

	# Store references for the animation
	multi_strips.append({
		"node": strip_node,
		"label": right_label,
		"viewport": strip_area,
		"pointer": pointer,
		"result": {},
		"tick_state": {"last": -999999}
	})

	return row

func _play_multi_spin_animation() -> void:
	var tweens: Array[Tween] = []
	var multi_size := Vector2(MULTI_ITEM_WIDTH, MULTI_ITEM_HEIGHT)

	# Fill all strips with enough items for fixed-distance travel
	for i in range(multi_strips.size()):
		var strip_data: Dictionary = multi_strips[i]
		var strip_node: HBoxContainer = strip_data["node"]
		var viewport: Control = strip_data["viewport"]

		for child in strip_node.get_children():
			child.queue_free()

		var viewport_width := viewport.size.x
		_ensure_strip_has_enough_items(strip_node, viewport_width, MULTI_ITEM_WIDTH, multi_size)

	# Let layout happen
	await get_tree().process_frame

	# Create tweens for each strip - all same speed/duration, different random start
	for i in range(multi_strips.size()):
		var strip_data: Dictionary = multi_strips[i]
		var strip_node: HBoxContainer = strip_data["node"]
		var viewport: Control = strip_data["viewport"]
		var viewport_width := viewport.size.x

		# Random START inside first item (unique per strip - this is the only randomness)
		var start_x := -randf_range(START_EDGE_PAD, MULTI_ITEM_WIDTH - START_EDGE_PAD)

		# Fixed distance, fixed duration
		var distance_px := SPIN_SPEED_PX_PER_SEC * SPIN_DURATION
		var target_x := start_x - distance_px

		# Optional tiny end nudge but keep distance identical
		var end_nudge := randf_range(-END_EDGE_PAD, END_EDGE_PAD)
		start_x += end_nudge
		target_x += end_nudge

		# Clamp to never expose empty
		var content_w := strip_node.size.x
		var max_scroll := maxf(0.0, content_w - viewport_width)
		var max_x := -max_scroll
		start_x = clampf(start_x, max_x, 0.0)
		target_x = clampf(target_x, max_x, 0.0)

		strip_node.position.x = start_x

		# Drawn-out deceleration, no settle, no overshoot - EXPO has longest tail
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_EXPO)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(strip_node, "position:x", target_x, SPIN_DURATION)
		tweens.append(tween)

	# Flash pointers during spin (all same duration now)
	_flash_multi_pointers_during_spin(SPIN_DURATION)

	# Wait for all tweens (they all finish at the same time now)
	await tweens.back().finished
	await get_tree().process_frame

	# Measure winners
	for strip_data in multi_strips:
		var strip_node2 := strip_data["node"] as Control
		var ptr := strip_data["pointer"] as Control
		strip_data["result"] = _pick_item_under_pointer(strip_node2, ptr)

	# End flash
	for j in range(4):
		for p in multi_pointers:
			p.color = Color(1.0, 1.0, 1.0)
		await get_tree().create_timer(0.08).timeout
		for p in multi_pointers:
			p.color = Color(1.0, 0.8, 0.2)
		await get_tree().create_timer(0.08).timeout


func _flash_multi_pointers_during_spin(duration: float) -> void:
	# Reset tick states
	for strip_data in multi_strips:
		(strip_data["tick_state"] as Dictionary)["last"] = -999999

	var elapsed := 0.0
	while elapsed < duration:
		for strip_data in multi_strips:
			_tick_if_crossed_child(strip_data["node"], strip_data["pointer"], strip_data["tick_state"])

		var flash := fmod(elapsed, 0.08) < 0.02
		for ptr in multi_pointers:
			ptr.color = Color(1.0, 1.0, 1.0) if flash else Color(1.0, 0.8, 0.2)

		await get_tree().create_timer(0.02).timeout
		elapsed += 0.02

func _show_multi_results() -> void:
	for i in range(multi_strips.size()):
		var strip_data: Dictionary = multi_strips[i]
		var result_label: Label = strip_data["label"]
		var item: Dictionary = strip_data["result"]

		var is_new: bool = item.get("is_new", false)
		var rarity: String = item.get("rarity", "common")
		var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

		result_label.text = "→ %s %s" % [item.get("name", "???"), "(NEW!)" if is_new else "(owned)"]
		result_label.modulate = rarity_color if is_new else rarity_color.darkened(0.3)

		# Add a little "pop" animation to the text
		var t := create_tween()
		t.tween_property(result_label, "scale", Vector2(1.2, 1.2), 0.1)
		t.tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.1)

	defeated_label.text = "%d items unlocked!" % multi_strips.size()

func _create_inline_result(item: Dictionary) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_new: bool = item.get("is_new", false)

	# Arrow
	var arrow := Label.new()
	arrow.text = "→"
	Fonts.apply_body(arrow, 20, Color(1, 0.8, 0.2))
	hbox.add_child(arrow)

	# Name
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	Fonts.apply_body(name_label, 14, rarity_color)
	hbox.add_child(name_label)

	# Status
	var status := Label.new()
	if is_new:
		status.text = "NEW!"
		Fonts.apply_body(status, 12, Color(0.3, 1.0, 0.3))
	else:
		status.text = "(owned)"
		Fonts.apply_body(status, 12, Color(0.5, 0.5, 0.5))
	hbox.add_child(status)

	return hbox

func _create_mini_result_card(item: Dictionary) -> PanelContainer:
	## Compact result card shown next to each strip
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, MULTI_ITEM_HEIGHT)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_new: bool = item.get("is_new", false)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# Shape preview
	var cells: Array = []
	if item.get("type") == "worm":
		var worm_def: Dictionary = WormDefs.WORMS.get(item.get("name", ""), {})
		cells = worm_def.get("cells", [])
	else:
		var pattern: Dictionary = PatternDefs.get_pattern(item.get("name", ""))
		cells = pattern.get("cells", [])

	var shape := _create_shape_visual(cells, rarity_color, 6.0)
	hbox.add_child(shape)

	# Info column
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	Fonts.apply_body(name_label, 12, Color.WHITE)
	info.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = rarity.substr(0, 4).to_upper()
	Fonts.apply_body(rarity_label, 10, rarity_color)
	info.add_child(rarity_label)

	# New/owned indicator
	var status := Label.new()
	if is_new:
		status.text = "NEW!"
		Fonts.apply_body(status, 11, Color(0.3, 1.0, 0.3))
	else:
		status.text = "Owned"
		Fonts.apply_body(status, 11, Color(0.5, 0.5, 0.5))
	info.add_child(status)

	return panel

func _create_result_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 160)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var is_new: bool = item.get("is_new", false)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = rarity_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Rarity
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(rarity_label, 11, rarity_color)
	vbox.add_child(rarity_label)

	# Shape preview
	var cells: Array = item.get("cells", [])
	if item.get("type") == "worm":
		var worm_def: Dictionary = WormDefs.WORMS.get(item.get("name", ""), {})
		cells = worm_def.get("cells", [])
	else:
		var pattern: Dictionary = PatternDefs.get_pattern(item.get("name", ""))
		cells = pattern.get("cells", [])

	var shape := _create_shape_visual(cells, rarity_color, 8.0)
	shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(shape)

	# Name
	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(name_label, 13, Color.WHITE)
	vbox.add_child(name_label)

	# Type
	var type_label := Label.new()
	type_label.text = "Worm" if item.get("type") == "worm" else "Pattern"
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Fonts.apply_body(type_label, 10, Color(0.6, 0.6, 0.7))
	vbox.add_child(type_label)

	# New/duplicate
	var status_label := Label.new()
	if is_new:
		status_label.text = "NEW!"
		Fonts.apply_body(status_label, 12, Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "(Owned)"
		Fonts.apply_body(status_label, 12, Color(0.5, 0.5, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	return panel
