extends Node
## GameState.gd - Core game state singleton (autoload)
## HOW TO RUN: 1. Open project in Godot 4.x 2. Press F5 or click Play
## CONTROLS: Left Click: Place worm/place strike, R: Rotate
##
## Definitions are loaded from:
##   - worm_defs.gd (WormDefs class)
##   - pattern_defs.gd (PatternDefs class)

enum Phase { PLACEMENT, BATTLE, GAME_OVER }
enum Turn { PLAYER, CPU }
enum CellState { UNKNOWN, MISS, HIT_BODY, HIT_END }
enum Owner { PLAYER, CPU }

const GRID_SIZE := 6

# References to config files
var WORM_DEFS: Dictionary:
	get: return WormDefs.WORMS

var WORM_POOL: Array:
	get: return WormDefs.POOL

var PATTERN_DEFS: Array:
	get: return PatternDefs.PATTERNS

signal state_changed
signal strike_resolved(owner: Owner, impacts: Array)
signal worm_destroyed(owner: Owner, worm_name: String)
signal game_over(winner: Owner)

var phase: Phase = Phase.PLACEMENT
var current_turn: Turn = Turn.PLAYER
var current_pattern: Dictionary = {}
var current_pattern_rotation: int = 0
var player_board := {"worms": [], "revealed": {}}
var cpu_board := {"worms": [], "revealed": {}}
var worms_to_place: Array = []
var current_worm_to_place: Dictionary = {}
var placement_rotation: int = 0

# Current NPC being fought (set by NPCMenu before entering battle)
var current_npc_id: String = ""

func _ready() -> void:
	# Don't auto-reset, wait for scene to call reset_game
	pass

var worms_remaining_to_pick := 0  # How many worms player still needs to pick

func reset_game() -> void:
	phase = Phase.PLACEMENT
	current_turn = Turn.PLAYER
	current_pattern = {}
	current_pattern_rotation = 0
	placement_rotation = 0
	player_board = {"worms": [], "revealed": {}}
	cpu_board = {"worms": [], "revealed": {}}

	# Player picks 2 worms from their unlocked collection
	worms_to_place = []
	worms_remaining_to_pick = 2

	current_worm_to_place = {}
	_cpu_place_worms()
	state_changed.emit()

func get_player_available_worms() -> Array:
	## Returns worms the player can choose from (their unlocked worms)
	if SaveManager.current_slot < 0:
		# No save loaded, use starter worms for testing
		return ["Sprout", "Bean"]
	return SaveManager.get_unlocked_worms()

func get_player_available_patterns() -> Array:
	## Returns patterns the player can use (their unlocked patterns + misses)
	var patterns: Array = []

	# Always include miss patterns
	for p in PATTERN_DEFS:
		if p.get("is_miss", false):
			patterns.append(p)

	# Add player's unlocked patterns
	if SaveManager.current_slot < 0:
		# No save loaded, use starter patterns for testing
		for p in PATTERN_DEFS:
			if p.get("pool") == "starter" and not p.get("is_miss", false):
				patterns.append(p)
	else:
		var unlocked := SaveManager.get_unlocked_patterns()
		for p in PATTERN_DEFS:
			if p.get("name", "") in unlocked:
				patterns.append(p)

	return patterns

func _cpu_place_worms() -> void:
	# Randomly select 2 worms for CPU from pool
	var available_worms := WORM_POOL.duplicate()
	available_worms.shuffle()
	var cpu_worms := [available_worms[0], available_worms[1]]

	# Place worms randomly
	for worm_name in cpu_worms:
		var placed := false
		var attempts := 0
		while not placed and attempts < 100:
			var origin := Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE)
			var rotation: int = [0, 90, 180, 270][randi() % 4]
			if validate_worm_placement(cpu_board, worm_name, origin, rotation):
				var instance := _create_worm_instance(worm_name, origin, rotation)
				cpu_board["worms"].append(instance)
				placed = true
			attempts += 1

func _create_worm_instance(worm_name: String, origin: Vector2i, rotation: int) -> Dictionary:
	var worm_def = WORM_DEFS[worm_name]
	var rotated_cells := _rotate_cells(worm_def["cells"], rotation)
	var world_cells: Array[Vector2i] = []
	for cell in rotated_cells:
		world_cells.append(origin + cell)
	var end_cells := _compute_end_cells(world_cells)
	return {"name": worm_name, "origin": origin, "rotation": rotation, "cells": world_cells, "end_cells": end_cells, "hit_set": {}}

func _rotate_cells(cells: Array, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(_rotate_point(cell, rotation))
	return result

func _rotate_point(point: Vector2i, rotation: int) -> Vector2i:
	match rotation % 360:
		0: return point
		90: return Vector2i(-point.y, point.x)
		180: return Vector2i(-point.x, -point.y)
		270: return Vector2i(point.y, -point.x)
	return point

func _compute_end_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	var ends: Array[Vector2i] = []
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell in cells:
		var neighbor_count := 0
		for dir in directions:
			if cell_set.has(cell + dir):
				neighbor_count += 1
		if neighbor_count == 1:
			ends.append(cell)
	return ends

func validate_worm_placement(board: Dictionary, worm_name: String, origin: Vector2i, rotation: int) -> bool:
	var worm_def = WORM_DEFS[worm_name]
	var rotated_cells := _rotate_cells(worm_def["cells"], rotation)
	var occupied := _get_occupied_cells(board)
	for cell in rotated_cells:
		var world_cell := origin + cell
		if world_cell.x < 0 or world_cell.x >= GRID_SIZE:
			return false
		if world_cell.y < 0 or world_cell.y >= GRID_SIZE:
			return false
		if occupied.has(world_cell):
			return false
	return true

func _get_occupied_cells(board: Dictionary) -> Dictionary:
	var occupied := {}
	for worm in board["worms"]:
		for cell in worm["cells"]:
			occupied[cell] = true
	return occupied

func get_worm_preview_cells(worm_name: String, origin: Vector2i, rotation: int) -> Array[Vector2i]:
	var worm_def = WORM_DEFS[worm_name]
	var rotated_cells := _rotate_cells(worm_def["cells"], rotation)
	var result: Array[Vector2i] = []
	for cell in rotated_cells:
		result.append(origin + cell)
	return result

func place_player_worm(worm_name: String, origin: Vector2i, rotation: int) -> bool:
	if not validate_worm_placement(player_board, worm_name, origin, rotation):
		return false
	var instance := _create_worm_instance(worm_name, origin, rotation)
	player_board["worms"].append(instance)
	var idx := worms_to_place.find(worm_name)
	if idx >= 0:
		worms_to_place.remove_at(idx)
	current_worm_to_place = {}
	state_changed.emit()
	return true

func start_battle() -> bool:
	if worms_to_place.size() > 0:
		return false
	phase = Phase.BATTLE
	current_turn = Turn.PLAYER
	_roll_pattern()
	state_changed.emit()
	return true

func _roll_pattern() -> void:
	current_pattern = PATTERN_DEFS[randi() % PATTERN_DEFS.size()]
	current_pattern_rotation = 0

func rotate_pattern() -> void:
	if current_pattern.get("rotatable", false):
		current_pattern_rotation = (current_pattern_rotation + 90) % 360
		state_changed.emit()

func get_pattern_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells := current_pattern.get("cells", []) as Array
	var rotated := _rotate_cells(cells, current_pattern_rotation)
	var result: Array[Vector2i] = []
	for cell in rotated:
		result.append(anchor + cell)
	return result

func validate_pattern_placement(anchor: Vector2i) -> bool:
	var cells := get_pattern_cells(anchor)
	for cell in cells:
		if cell.x < 0 or cell.x >= GRID_SIZE:
			return false
		if cell.y < 0 or cell.y >= GRID_SIZE:
			return false
	return true

func apply_strike(owner: Owner, anchor: Vector2i) -> Array:
	var target_board: Dictionary
	if owner == Owner.PLAYER:
		target_board = cpu_board
	else:
		target_board = player_board
	var cells := get_pattern_cells(anchor)
	var impacts: Array = []
	for cell in cells:
		if cell.x < 0 or cell.x >= GRID_SIZE or cell.y < 0 or cell.y >= GRID_SIZE:
			continue
		if target_board["revealed"].has(cell):
			impacts.append({"cell": cell, "result": target_board["revealed"][cell], "worm_name": "", "already_hit": true})
			continue
		var hit_worm: Dictionary = {}
		var is_end := false
		for worm in target_board["worms"]:
			if cell in worm["cells"]:
				hit_worm = worm
				is_end = cell in worm["end_cells"]
				worm["hit_set"][cell] = true
				break
		var result: CellState
		var worm_name := ""
		if hit_worm.is_empty():
			result = CellState.MISS
		else:
			worm_name = hit_worm["name"]
			if is_end:
				result = CellState.HIT_END
			else:
				result = CellState.HIT_BODY
		target_board["revealed"][cell] = result
		impacts.append({"cell": cell, "result": result, "worm_name": worm_name, "already_hit": false})
	strike_resolved.emit(owner, impacts)
	_check_destroyed_worms(owner, target_board)
	if _check_victory(target_board):
		phase = Phase.GAME_OVER
		game_over.emit(owner)
		state_changed.emit()
		return impacts
	if current_turn == Turn.PLAYER:
		current_turn = Turn.CPU
	else:
		current_turn = Turn.PLAYER
	_roll_pattern()
	state_changed.emit()
	return impacts

func _check_destroyed_worms(attacker: Owner, target_board: Dictionary) -> void:
	for worm in target_board["worms"]:
		if worm.get("destroyed", false):
			continue
		var all_hit := true
		for cell in worm["cells"]:
			if not worm["hit_set"].has(cell):
				all_hit = false
				break
		if all_hit:
			worm["destroyed"] = true
			worm_destroyed.emit(attacker, worm["name"])

func _check_victory(target_board: Dictionary) -> bool:
	for worm in target_board["worms"]:
		if not worm.get("destroyed", false):
			return false
	return true

func get_player_worm_at(cell: Vector2i) -> Dictionary:
	for worm in player_board["worms"]:
		if cell in worm["cells"]:
			return worm
	return {}

func get_cpu_worm_at(cell: Vector2i) -> Dictionary:
	for worm in cpu_board["worms"]:
		if cell in worm["cells"]:
			return worm
	return {}

func get_player_cell_state(cell: Vector2i) -> CellState:
	return player_board["revealed"].get(cell, CellState.UNKNOWN)

func get_cpu_cell_state(cell: Vector2i) -> CellState:
	return cpu_board["revealed"].get(cell, CellState.UNKNOWN)

func get_remaining_worms(owner: Owner) -> Array:
	var board: Dictionary = player_board if owner == Owner.PLAYER else cpu_board
	var remaining: Array = []
	for worm in board["worms"]:
		if not worm.get("destroyed", false):
			remaining.append(worm)
	return remaining

func get_player_worm_names_for_ai() -> Array[String]:
	## Returns the names of the player's worms (not destroyed ones)
	## The AI knows WHICH worms the player selected, but not WHERE they placed them
	var names: Array[String] = []
	for worm in player_board["worms"]:
		if not worm.get("destroyed", false):
			names.append(worm["name"])
	return names

func get_worm_def(worm_name: String) -> Dictionary:
	## Get the base worm definition by name
	return WORM_DEFS.get(worm_name, {})
