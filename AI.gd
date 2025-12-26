extends RefCounted
class_name AI
## AI.gd - Bayesian posterior-based targeting AI
## ==============================================
## The CPU knows WHICH worm shapes the player selected, but not WHERE they placed them.
##
## This AI reasons over all valid (wormA_placement, wormB_placement) pairs that:
##   - Don't overlap
##   - Are consistent with revealed evidence (MISS, HIT_BODY, HIT_END)
##
## From valid pairs, it computes:
##   - p_occ[cell]: probability cell is occupied by either worm
##   - p_end[cell]: probability cell is an end (given occupied)
##
## Pattern placements are scored by expected hits + information gain.

# =============================================================================
# PLACEMENT STRUCTURE
# =============================================================================

## A placement is: { cells: Array[Vector2i], end_cells: Array[Vector2i] }
## Represents one possible position+rotation of a worm on the grid.

static func _generate_all_placements(worm_def: Dictionary) -> Array:
	## Generate all valid in-bounds placements for a worm definition
	var placements: Array = []
	var base_cells: Array = worm_def.get("cells", [])
	var rotatable: bool = worm_def.get("rotatable", true)
	var rotations: Array = [0, 90, 180, 270] if rotatable else [0]

	for rot in rotations:
		var rotated_cells := _rotate_cells(base_cells, rot)

		# Try all possible origins
		for ox in range(GameState.GRID_SIZE):
			for oy in range(GameState.GRID_SIZE):
				var origin := Vector2i(ox, oy)
				var world_cells: Array[Vector2i] = []
				var valid := true

				# Compute world positions
				for cell in rotated_cells:
					var world_cell: Vector2i = origin + cell
					# Check bounds
					if world_cell.x < 0 or world_cell.x >= GameState.GRID_SIZE:
						valid = false
						break
					if world_cell.y < 0 or world_cell.y >= GameState.GRID_SIZE:
						valid = false
						break
					world_cells.append(world_cell)

				if valid:
					var end_cells := _compute_end_cells(world_cells)
					placements.append({
						"cells": world_cells,
						"end_cells": end_cells
					})

	return placements

static func _rotate_cells(cells: Array, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(_rotate_point(cell, rotation))
	return result

static func _rotate_point(point: Vector2i, rotation: int) -> Vector2i:
	match rotation % 360:
		0: return point
		90: return Vector2i(-point.y, point.x)
		180: return Vector2i(-point.x, -point.y)
		270: return Vector2i(point.y, -point.x)
	return point

static func _compute_end_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
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
		if neighbor_count <= 1:  # Ends have 0 or 1 neighbor
			ends.append(cell)
	return ends

# =============================================================================
# EVIDENCE FILTERING
# =============================================================================

static func _placement_consistent_with_evidence(placement: Dictionary, revealed: Dictionary) -> bool:
	## Check if a placement is consistent with all revealed evidence
	## Rules:
	##   - MISS cell → cell NOT in placement
	##   - HIT_BODY cell → cell IN placement AND cell NOT an end
	##   - HIT_END cell → cell IN placement AND cell IS an end

	var cells: Array = placement["cells"]
	var end_cells: Array = placement["end_cells"]
	var cell_set := {}
	for c in cells:
		cell_set[c] = true
	var end_set := {}
	for e in end_cells:
		end_set[e] = true

	for cell in revealed:
		var state: GameState.CellState = revealed[cell]
		var in_placement: bool = cell_set.has(cell)
		var is_end: bool = end_set.has(cell)

		match state:
			GameState.CellState.MISS:
				# MISS means cell is NOT part of any worm
				if in_placement:
					return false
			GameState.CellState.HIT_BODY:
				# HIT_BODY means cell IS part of a worm AND is NOT an end
				if in_placement and is_end:
					return false  # Can't be body if it's an end in this placement
			GameState.CellState.HIT_END:
				# HIT_END means cell IS part of a worm AND IS an end
				if in_placement and not is_end:
					return false  # Must be an end if we hit an end here

	return true

static func _placement_covers_hits(placement: Dictionary, revealed: Dictionary) -> bool:
	## Check if a placement covers all HIT cells it should
	## If a cell is HIT_BODY or HIT_END, at least one worm must cover it
	var cells: Array = placement["cells"]
	var cell_set := {}
	for c in cells:
		cell_set[c] = true

	# This is checked at the pair level, not individual placement
	return true

static func _filter_placements_by_evidence(placements: Array, revealed: Dictionary) -> Array:
	## Filter placements to only those consistent with evidence
	var valid: Array = []
	for p in placements:
		if _placement_consistent_with_evidence(p, revealed):
			valid.append(p)
	return valid

# =============================================================================
# PAIR ENUMERATION
# =============================================================================

static func _placements_overlap(p1: Dictionary, p2: Dictionary) -> bool:
	## Check if two placements share any cells
	var cells1: Array = p1["cells"]
	var set1 := {}
	for c in cells1:
		set1[c] = true

	var cells2: Array = p2["cells"]
	for c in cells2:
		if set1.has(c):
			return true
	return false

static func _pair_covers_all_hits(p1: Dictionary, p2: Dictionary, revealed: Dictionary) -> bool:
	## Check if the pair together covers all HIT cells
	var combined_cells := {}
	var combined_ends := {}

	for c in p1["cells"]:
		combined_cells[c] = true
	for c in p2["cells"]:
		combined_cells[c] = true
	for e in p1["end_cells"]:
		combined_ends[e] = true
	for e in p2["end_cells"]:
		combined_ends[e] = true

	for cell in revealed:
		var state: GameState.CellState = revealed[cell]
		match state:
			GameState.CellState.HIT_BODY:
				# This cell must be covered by one of the worms, as body
				if not combined_cells.has(cell):
					return false
				if combined_ends.has(cell):
					return false  # Can't be body if it's an end
			GameState.CellState.HIT_END:
				# This cell must be covered by one of the worms, as end
				if not combined_cells.has(cell):
					return false
				if not combined_ends.has(cell):
					return false  # Must be an end

	return true

static func _enumerate_valid_pairs(placements_a: Array, placements_b: Array, revealed: Dictionary) -> Array:
	## Enumerate all valid (placementA, placementB) pairs
	## Valid means: non-overlapping AND covers all hits correctly
	var valid_pairs: Array = []

	for pa in placements_a:
		for pb in placements_b:
			# Check non-overlap
			if _placements_overlap(pa, pb):
				continue
			# Check that together they cover all hits
			if not _pair_covers_all_hits(pa, pb, revealed):
				continue
			valid_pairs.append([pa, pb])

	return valid_pairs

# =============================================================================
# PROBABILITY COMPUTATION
# =============================================================================

static func _compute_probabilities(valid_pairs: Array) -> Dictionary:
	## Compute p_occ[cell] and p_end[cell] from valid pairs
	## Returns: { p_occ: Dictionary, p_end: Dictionary, p_body: Dictionary }

	var total_pairs := valid_pairs.size()
	if total_pairs == 0:
		return {"p_occ": {}, "p_end": {}, "p_body": {}}

	var occ_count := {}  # cell -> count of pairs where cell is occupied
	var end_count := {}  # cell -> count of pairs where cell is an end
	var body_count := {} # cell -> count of pairs where cell is body (not end)

	for pair in valid_pairs:
		var combined_cells := {}
		var combined_ends := {}

		for c in pair[0]["cells"]:
			combined_cells[c] = true
		for c in pair[1]["cells"]:
			combined_cells[c] = true
		for e in pair[0]["end_cells"]:
			combined_ends[e] = true
		for e in pair[1]["end_cells"]:
			combined_ends[e] = true

		for cell in combined_cells:
			occ_count[cell] = occ_count.get(cell, 0) + 1
			if combined_ends.has(cell):
				end_count[cell] = end_count.get(cell, 0) + 1
			else:
				body_count[cell] = body_count.get(cell, 0) + 1

	# Convert counts to probabilities
	var p_occ := {}
	var p_end := {}
	var p_body := {}

	for cell in occ_count:
		p_occ[cell] = float(occ_count[cell]) / float(total_pairs)
	for cell in end_count:
		p_end[cell] = float(end_count[cell]) / float(total_pairs)
	for cell in body_count:
		p_body[cell] = float(body_count[cell]) / float(total_pairs)

	return {"p_occ": p_occ, "p_end": p_end, "p_body": p_body}

# =============================================================================
# PATTERN SCORING
# =============================================================================

static func _score_pattern_placement(
	anchor: Vector2i,
	pattern: Dictionary,
	rotation: int,
	probs: Dictionary,
	revealed: Dictionary
) -> float:
	## Score a pattern placement using expected hits + information gain
	## score = E_hits + λ * IG

	var cells := _get_pattern_cells(anchor, pattern, rotation)
	var p_occ: Dictionary = probs["p_occ"]

	var expected_hits := 0.0
	var info_gain := 0.0

	for cell in cells:
		# Skip out-of-bounds
		if cell.x < 0 or cell.x >= GameState.GRID_SIZE:
			continue
		if cell.y < 0 or cell.y >= GameState.GRID_SIZE:
			continue
		# Skip already revealed cells (no new information)
		if revealed.has(cell):
			continue

		var p: float = p_occ.get(cell, 0.0)

		# Expected hits: sum of occupation probabilities
		expected_hits += p

		# Information gain: p * (1 - p) measures uncertainty
		# High IG cells split the possibility space
		info_gain += p * (1.0 - p)

	# Weight information gain (tune λ as needed)
	var lambda := 0.5
	return expected_hits + lambda * info_gain

static func _get_pattern_cells(anchor: Vector2i, pattern: Dictionary, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cells: Array = pattern.get("cells", [])
	for cell in cells:
		var rotated := _rotate_point(cell, rotation)
		result.append(anchor + rotated)
	return result

static func _is_valid_pattern_placement(anchor: Vector2i, pattern: Dictionary, rotation: int) -> bool:
	## Returns true if at least 1 cell of the pattern is within the grid
	var cells := _get_pattern_cells(anchor, pattern, rotation)
	for cell in cells:
		if cell.x >= 0 and cell.x < GameState.GRID_SIZE and cell.y >= 0 and cell.y < GameState.GRID_SIZE:
			return true  # At least one cell is in bounds
	return false  # No cells in bounds

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

static func choose_strike(pattern: Dictionary, revealed: Dictionary, worm_names: Array) -> Dictionary:
	## Main AI entry point
	## Returns { anchor: Vector2i, rotation: int } for best strike placement
	##
	## worm_names: Array of the player's worm names (the AI knows their loadout)

	# Handle miss patterns (no cells) - shouldn't happen for CPU but just in case
	if pattern.get("is_miss", false) or pattern.get("cells", []).is_empty():
		return {"anchor": Vector2i(0, 0), "rotation": 0}

	# Handle case where no worms left (shouldn't happen, game should be over)
	if worm_names.is_empty():
		return _fallback_random_placement(pattern)

	# Get worm definitions
	var worm_defs: Array = []
	for worm_name in worm_names:
		var def = GameState.get_worm_def(worm_name)
		if not def.is_empty():
			worm_defs.append(def)

	# Handle edge cases
	if worm_defs.is_empty():
		return _fallback_random_placement(pattern)

	# Generate and filter placements for each worm
	var filtered_placements: Array = []
	for wdef in worm_defs:
		var all_placements := _generate_all_placements(wdef)
		var valid := _filter_placements_by_evidence(all_placements, revealed)
		filtered_placements.append(valid)

	# Compute valid pairs and probabilities
	var probs: Dictionary
	if worm_defs.size() == 1:
		# Single worm remaining - no pairs needed
		probs = _compute_single_worm_probabilities(filtered_placements[0])
	elif worm_defs.size() >= 2:
		# Two worms - enumerate valid pairs
		var valid_pairs := _enumerate_valid_pairs(
			filtered_placements[0],
			filtered_placements[1],
			revealed
		)
		probs = _compute_probabilities(valid_pairs)
	else:
		probs = {"p_occ": {}, "p_end": {}, "p_body": {}}

	# If no valid placements/pairs, fall back to heuristic
	if probs["p_occ"].is_empty():
		return _fallback_heuristic(pattern, revealed)

	# Score all valid pattern placements
	var rotations: Array = [0, 90, 180, 270] if pattern.get("rotatable", false) else [0]
	var candidates: Array = []

	for rot in rotations:
		for x in range(GameState.GRID_SIZE):
			for y in range(GameState.GRID_SIZE):
				var anchor := Vector2i(x, y)
				if _is_valid_pattern_placement(anchor, pattern, rot):
					var score := _score_pattern_placement(anchor, pattern, rot, probs, revealed)
					if score > 0:
						candidates.append({"anchor": anchor, "rotation": rot, "score": score})

	if candidates.is_empty():
		return _fallback_random_placement(pattern)

	# Sort by score descending and pick the best
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	return {"anchor": candidates[0]["anchor"], "rotation": candidates[0]["rotation"]}

static func _compute_single_worm_probabilities(placements: Array) -> Dictionary:
	## Compute probabilities for a single worm (simpler case)
	var total := placements.size()
	if total == 0:
		return {"p_occ": {}, "p_end": {}, "p_body": {}}

	var occ_count := {}
	var end_count := {}
	var body_count := {}

	for p in placements:
		var end_set := {}
		for e in p["end_cells"]:
			end_set[e] = true

		for c in p["cells"]:
			occ_count[c] = occ_count.get(c, 0) + 1
			if end_set.has(c):
				end_count[c] = end_count.get(c, 0) + 1
			else:
				body_count[c] = body_count.get(c, 0) + 1

	var p_occ := {}
	var p_end := {}
	var p_body := {}

	for cell in occ_count:
		p_occ[cell] = float(occ_count[cell]) / float(total)
	for cell in end_count:
		p_end[cell] = float(end_count[cell]) / float(total)
	for cell in body_count:
		p_body[cell] = float(body_count[cell]) / float(total)

	return {"p_occ": p_occ, "p_end": p_end, "p_body": p_body}

static func _fallback_random_placement(pattern: Dictionary) -> Dictionary:
	## Random valid placement as ultimate fallback
	var rotations: Array = [0, 90, 180, 270] if pattern.get("rotatable", false) else [0]
	for rot in rotations:
		for x in range(GameState.GRID_SIZE):
			for y in range(GameState.GRID_SIZE):
				var anchor := Vector2i(x, y)
				if _is_valid_pattern_placement(anchor, pattern, rot):
					return {"anchor": anchor, "rotation": rot}
	return {"anchor": Vector2i(0, 0), "rotation": 0}

static func _fallback_heuristic(pattern: Dictionary, revealed: Dictionary) -> Dictionary:
	## Fallback when Bayesian approach fails (e.g., no valid pairs)
	## Use simple heuristic: prefer unrevealed cells, avoid misses
	var rotations: Array = [0, 90, 180, 270] if pattern.get("rotatable", false) else [0]
	var best_anchor := Vector2i(0, 0)
	var best_rot := 0
	var best_score := -999.0

	for rot in rotations:
		for x in range(GameState.GRID_SIZE):
			for y in range(GameState.GRID_SIZE):
				var anchor := Vector2i(x, y)
				if not _is_valid_pattern_placement(anchor, pattern, rot):
					continue

				var cells := _get_pattern_cells(anchor, pattern, rot)
				var score := 0.0
				for cell in cells:
					if revealed.has(cell):
						var state: GameState.CellState = revealed[cell]
						if state == GameState.CellState.HIT_BODY or state == GameState.CellState.HIT_END:
							score += 2.0  # Prefer adjacent to hits
					else:
						score += 1.0  # Unrevealed is good

				if score > best_score:
					best_score = score
					best_anchor = anchor
					best_rot = rot

	return {"anchor": best_anchor, "rotation": best_rot}
