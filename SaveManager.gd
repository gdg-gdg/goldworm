extends Node
## SaveManager.gd - Handles save/load functionality
## ================================================
## Autoload singleton for managing 3 save slots.

const SAVE_PATH := "user://saves/"
const SAVE_FILE_TEMPLATE := "save_%d.json"
const MAX_SLOTS := 3

# Current loaded save data
var current_slot: int = -1
var save_data: Dictionary = {}

# Debug mode (not saved, runtime only)
var debug_mode: bool = true

# Starting loadout for new games
const STARTING_WORMS := ["Sprout", "Bean"]
const STARTING_PATTERNS := ["Pebble", "Twins", "Stack", "Spike", "Corner"]

signal save_loaded(slot: int)
signal save_created(slot: int)
signal save_deleted(slot: int)

func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)

# =============================================================================
# SAVE DATA STRUCTURE
# =============================================================================

func _create_new_save(save_name: String = "New Save") -> Dictionary:
	return {
		"version": 1,
		"save_name": save_name,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": Time.get_datetime_string_from_system(),
		"unlocked_worms": STARTING_WORMS.duplicate(),
		"unlocked_patterns": STARTING_PATTERNS.duplicate(),
		"defeated_npcs": [],
		"total_drops": 0,
		"common_drops": 0,
		"uncommon_drops": 0,
		"rare_drops": 0,
		"epic_drops": 0,
	}

# =============================================================================
# SLOT MANAGEMENT
# =============================================================================

func get_save_path(slot: int) -> String:
	return SAVE_PATH + SAVE_FILE_TEMPLATE % slot

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func get_slot_info(slot: int) -> Dictionary:
	## Returns summary info for a slot (for menu display)
	if not slot_exists(slot):
		return {"exists": false}

	var data := load_slot_data(slot)
	if data.is_empty():
		return {"exists": false}

	return {
		"exists": true,
		"save_name": data.get("save_name", "Save %d" % (slot + 1)),
		"last_played": data.get("last_played", "Unknown"),
		"worm_count": data.get("unlocked_worms", []).size(),
		"pattern_count": data.get("unlocked_patterns", []).size(),
		"npc_count": data.get("defeated_npcs", []).size(),
		"total_drops": data.get("total_drops", 0),
	}

func load_slot_data(slot: int) -> Dictionary:
	## Load raw data from a slot without setting it as current
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file: " + path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("Failed to parse save file: " + path)
		return {}

	return json.data

# =============================================================================
# SAVE/LOAD OPERATIONS
# =============================================================================

func create_new_game(slot: int, save_name: String = "New Save") -> bool:
	## Create a new save in the specified slot
	save_data = _create_new_save(save_name)
	current_slot = slot

	if _write_save():
		save_created.emit(slot)
		return true
	return false

func rename_save(slot: int, new_name: String) -> bool:
	## Rename an existing save
	var data := load_slot_data(slot)
	if data.is_empty():
		return false

	data["save_name"] = new_name

	var path := get_save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# If this is the current slot, update save_data too
	if current_slot == slot:
		save_data["save_name"] = new_name

	return true

func load_game(slot: int) -> bool:
	## Load an existing save
	var data := load_slot_data(slot)
	if data.is_empty():
		return false

	save_data = data
	current_slot = slot

	# Update last played
	save_data["last_played"] = Time.get_datetime_string_from_system()
	_write_save()

	save_loaded.emit(slot)
	return true

func save_game() -> bool:
	## Save current game state
	if current_slot < 0:
		push_error("No save slot selected")
		return false

	save_data["last_played"] = Time.get_datetime_string_from_system()
	return _write_save()

func delete_save(slot: int) -> bool:
	## Delete a save file
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var error := DirAccess.remove_absolute(path)
	if error == OK:
		if current_slot == slot:
			current_slot = -1
			save_data = {}
		save_deleted.emit(slot)
		return true
	return false

func _write_save() -> bool:
	var path := get_save_path(current_slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write save file: " + path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

# =============================================================================
# PROGRESSION QUERIES
# =============================================================================

func has_worm(worm_name: String) -> bool:
	return worm_name in save_data.get("unlocked_worms", [])

func has_pattern(pattern_name: String) -> bool:
	return pattern_name in save_data.get("unlocked_patterns", [])

func has_defeated_npc(npc_id: String) -> bool:
	return npc_id in save_data.get("defeated_npcs", [])

func get_unlocked_worms() -> Array:
	return save_data.get("unlocked_worms", [])

func get_unlocked_patterns() -> Array:
	return save_data.get("unlocked_patterns", [])

func get_total_drops() -> int:
	return save_data.get("total_drops", 0)

func get_rarity_drops(rarity: String) -> int:
	return save_data.get(rarity + "_drops", 0)

func get_total_unlocks() -> int:
	return get_unlocked_worms().size() + get_unlocked_patterns().size()

# =============================================================================
# PROGRESSION UPDATES
# =============================================================================

func unlock_worm(worm_name: String, rarity: String) -> bool:
	## Unlock a new worm. Returns true if it was newly unlocked.
	var worms: Array = save_data.get("unlocked_worms", [])
	if worm_name in worms:
		return false

	worms.append(worm_name)
	save_data["unlocked_worms"] = worms
	_record_drop(rarity)
	save_game()
	return true

func unlock_pattern(pattern_name: String, rarity: String) -> bool:
	## Unlock a new pattern. Returns true if it was newly unlocked.
	var patterns: Array = save_data.get("unlocked_patterns", [])
	if pattern_name in patterns:
		return false

	patterns.append(pattern_name)
	save_data["unlocked_patterns"] = patterns
	_record_drop(rarity)
	save_game()
	return true

func record_npc_defeat(npc_id: String) -> void:
	## Record that an NPC has been defeated
	var defeated: Array = save_data.get("defeated_npcs", [])
	if npc_id not in defeated:
		defeated.append(npc_id)
		save_data["defeated_npcs"] = defeated
		save_game()

func _record_drop(rarity: String) -> void:
	save_data["total_drops"] = save_data.get("total_drops", 0) + 1
	var key := rarity.to_lower() + "_drops"
	save_data[key] = save_data.get(key, 0) + 1
