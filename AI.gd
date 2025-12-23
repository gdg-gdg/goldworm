extends RefCounted
class_name AI
## AI.gd - CPU heatmap-based targeting logic
## ==========================================
## The CPU knows which worm SHAPES the player selected, but not positions/rotations.
## Uses placement enumeration and heatmap scoring to choose optimal strike placement.

# =============================================================================
# AI MODES
# =============================================================================

enum Mode { HUNT, TARGET }

# =============================================================================
# HEATMAP COMPUTATION
# =============================================================================

static func compute_heatmap(revealed: Dictionary, worm_shapes: Array) -> Dictionary:
	## For each remaining worm shape, enumerate all valid placements.
	## A placement is valid if:
	##   - All cells are in-bounds
	##   - No cell is a known MISS
	##   - End cells match HIT_END constraints (end at HIT_END, not body at HIT_END)
	## Add +1 to heatmap for each cell in valid placements.
	
	var heatmap := {}
	for x in range(GameState.GRID_SIZE):
		for y in range(GameState.GRID_SIZE):
			heatmap[Vector2i(x, y)] = 0
	
	for worm_def in worm_shapes:
		var rotations := [0, 90, 180, 270] if worm_def["rotatable"] else [0]
		for rot in rotations:
			for ox in range(GameState.GRID_SIZE):
				for oy in range(GameState.GRID_SIZE):
					var origin := Vector2i(ox, oy)
					if _is_valid_placement(origin, worm_def, rot, revealed):
						var cells := _get_worm_cells(origin, worm_def, rot)
						for cell in cells:
							heatmap[cell] += 1
	
	return heatmap

static func _is_valid_placement(origin: Vector2i, worm_def: Dictionary, rotation: int, revealed: Dictionary) -> bool:
	var cells := _get_worm_cells(origin, worm_def, rotation)
	var end_cells := _compute_end_cells_static(cells)
	
	for cell in cells:
		# Must be in-bounds
		if cell.x < 0 or cell.x >= GameState.GRID_SIZE:
			return false
		if cell.y < 0 or cell.y >= GameState.GRID_SIZE:
			return false
		# Cannot place on known MISS
		if revealed.has(cell) and revealed[cell] == GameState.CellState.MISS:
			return false
		# HIT_END constraint: if cell is HIT_END, it must be an end in this placement
		if revealed.has(cell) and revealed[cell] == GameState.CellState.HIT_END:
			if not (cell in end_cells):
				return false
	
	return true

static func _get_worm_cells(origin: Vector2i, worm_def: Dictionary, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in worm_def["cells"]:
		var rotated := _rotate_point(cell, rotation)
		result.append(origin + rotated)
	return result

static func _rotate_point(point: Vector2i, rotation: int) -> Vector2i:
	match rotation % 360:
		0: return point
		90: return Vector2i(-point.y, point.x)
		180: return Vector2i(-point.x, -point.y)
		270: return Vector2i(point.y, -point.x)
	return point

static func _compute_end_cells_static(cells: Array[Vector2i]) -> Array[Vector2i]:
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

# =============================================================================
# PATTERN SCORING
# =============================================================================

static func get_ai_mode(revealed: Dictionary) -> Mode:
	## TARGET mode if there are HIT cells not yet part of a destroyed worm
	for cell in revealed:
		var state: GameState.CellState = revealed[cell]
		if state == GameState.CellState.HIT_BODY or state == GameState.CellState.HIT_END:
			return Mode.TARGET
	return Mode.HUNT

static func score_pattern_placement(anchor: Vector2i, pattern: Dictionary, rotation: int, heatmap: Dictionary, revealed: Dictionary, mode: Mode) -> float:
	## Score = sum of heatmap values for unrevealed cells covered by pattern
	## In TARGET mode, add bonus for cells adjacent to hits
	
	var cells := _get_pattern_cells(anchor, pattern, rotation)
	var score := 0.0
	
	for cell in cells:
		if cell.x < 0 or cell.x >= GameState.GRID_SIZE:
			continue
		if cell.y < 0 or cell.y >= GameState.GRID_SIZE:
			continue
		# Skip already revealed cells (no value)
		if revealed.has(cell):
			continue
		# Add heatmap value
		score += heatmap.get(cell, 0)
		# In TARGET mode, bonus for adjacency to hits
		if mode == Mode.TARGET:
			score += _adjacency_bonus(cell, revealed)
	
	return score

static func _get_pattern_cells(anchor: Vector2i, pattern: Dictionary, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in pattern["cells"]:
		var rotated := _rotate_point(cell, rotation)
		result.append(anchor + rotated)
	return result

static func _adjacency_bonus(cell: Vector2i, revealed: Dictionary) -> float:
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var bonus := 0.0
	for dir in directions:
		var neighbor: Vector2i = cell + dir
		if revealed.has(neighbor):
			var state: GameState.CellState = revealed[neighbor]
			if state == GameState.CellState.HIT_BODY or state == GameState.CellState.HIT_END:
				bonus += 5.0
	return bonus

# =============================================================================
# STRIKE SELECTION
# =============================================================================

static func choose_strike(pattern: Dictionary, revealed: Dictionary, worm_shapes: Array) -> Dictionary:
	## Returns { anchor: Vector2i, rotation: int } for best strike placement
	
	var heatmap := compute_heatmap(revealed, worm_shapes)
	var mode := get_ai_mode(revealed)
	
	var rotations := [0, 90, 180, 270] if pattern.get("rotatable", false) else [0]
	var candidates: Array = []
	
	# Evaluate all valid placements
	for rot in rotations:
		for x in range(GameState.GRID_SIZE):
			for y in range(GameState.GRID_SIZE):
				var anchor := Vector2i(x, y)
				if _is_valid_pattern_placement(anchor, pattern, rot):
					var score := score_pattern_placement(anchor, pattern, rot, heatmap, revealed, mode)
					if score > 0:
						candidates.append({"anchor": anchor, "rotation": rot, "score": score})
	
	if candidates.is_empty():
		# Fallback: random valid placement
		for rot in rotations:
			for x in range(GameState.GRID_SIZE):
				for y in range(GameState.GRID_SIZE):
					var anchor := Vector2i(x, y)
					if _is_valid_pattern_placement(anchor, pattern, rot):
						return {"anchor": anchor, "rotation": rot}
		# Ultimate fallback
		return {"anchor": Vector2i(0, 0), "rotation": 0}
	
	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	
	# Pick from top 3 with slight randomness
	var top_count := mini(3, candidates.size())
	var pick := randi() % top_count
	
	return {"anchor": candidates[pick]["anchor"], "rotation": candidates[pick]["rotation"]}

static func _is_valid_pattern_placement(anchor: Vector2i, pattern: Dictionary, rotation: int) -> bool:
	var cells := _get_pattern_cells(anchor, pattern, rotation)
	for cell in cells:
		if cell.x < 0 or cell.x >= GameState.GRID_SIZE:
			return false
		if cell.y < 0 or cell.y >= GameState.GRID_SIZE:
			return false
	return true
