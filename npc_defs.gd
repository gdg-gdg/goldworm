extends RefCounted
class_name NPCDefs
## npc_defs.gd - NPC definitions with loot pools and unlock requirements
## ======================================================================
## Each NPC has:
##   - id: Unique identifier
##   - name: Display name
##   - folder: Folder name under npcs/ containing loadout.gd and loot.gd
##   - unlock_requirement: Condition to unlock this NPC
##   - difficulty: AI skill level (for future use)
##
## Loadouts and loot pools are defined in:
##   - npcs/{folder}/loadout.gd - Worms and patterns NPC uses in battle
##   - npcs/{folder}/loot.gd - Items dropped when defeating NPC
##
## Unlock Requirements:
##   - NPC 1: Always unlocked (starting opponent)
##   - NPC 2: After getting any 1 drop
##   - NPC 3: After getting 3 drops
##   - NPC 4: After getting 4 rare drops
##   - NPC 5: After collecting all items from earlier pools

static var NPCS: Dictionary = {
	"npc1": {
		"id": "npc1",
		"name": "Farmer Joe",
		"description": "A simple farmer who dabbles in worm warfare.",
		"folder": "farmer_joe",
		"unlock_requirement": {"type": "start"},
		"difficulty": 1,
		"coin_reward": 50,
		"chest_cost": 20,
	},
	"npc2": {
		"id": "npc2",
		"name": "Garden Gnome Gary",
		"description": "Don't let his size fool you - he's ruthless.",
		"folder": "garden_gnome_gary",
		"unlock_requirement": {"type": "total_drops", "count": 1},
		"difficulty": 2,
		"coin_reward": 100,
		"chest_cost": 40,
	},
	"npc3": {
		"id": "npc3",
		"name": "Mole King",
		"description": "Rules the underground with an iron claw.",
		"folder": "mole_king",
		"unlock_requirement": {"type": "total_drops", "count": 3},
		"difficulty": 3,
		"coin_reward": 200,
		"chest_cost": 80,
	},
	"npc4": {
		"id": "npc4",
		"name": "The Compost Queen",
		"description": "Her decay is your defeat.",
		"folder": "compost_queen",
		"unlock_requirement": {"type": "rare_drops", "count": 4},
		"difficulty": 4,
		"coin_reward": 500,
		"chest_cost": 200,
	},
	"npc5": {
		"id": "npc5",
		"name": "Worm God",
		"description": "The ultimate challenge. Collect everything to face him.",
		"folder": "worm_god",
		"unlock_requirement": {"type": "collect_all_before"},
		"difficulty": 5,
		"coin_reward": 1000,
		"chest_cost": 500,
	},
}

static var NPC_ORDER: Array = ["npc1", "npc2", "npc3", "npc4", "npc5"]

# Cache for loaded scripts
static var _loadout_cache: Dictionary = {}
static var _loot_cache: Dictionary = {}

# =============================================================================
# COIN & CHEST HELPERS
# =============================================================================

static func get_npc_coin_reward(npc_id: String) -> int:
	## Returns the coin reward for defeating this NPC
	var npc = NPCS.get(npc_id, {})
	return npc.get("coin_reward", 50)

static func get_npc_chest_cost(npc_id: String) -> int:
	## Returns the cost to buy a chest from this NPC
	var npc = NPCS.get(npc_id, {})
	return npc.get("chest_cost", 20)

# =============================================================================
# LOADOUT HELPERS (What NPC uses in battle)
# =============================================================================

static func get_npc_loadout_worms(npc_id: String) -> Array[String]:
	## Returns worm names this NPC can use in battle
	var npc = NPCS.get(npc_id, {})
	var folder: String = npc.get("folder", "")
	if folder.is_empty():
		return []

	var script_path := "res://npcs/%s/loadout.gd" % folder
	var script = load(script_path)
	if script == null:
		push_error("Failed to load loadout for NPC: " + npc_id)
		return []

	return script.WORMS

static func get_npc_loadout_patterns(npc_id: String) -> Array[String]:
	## Returns pattern names this NPC can use in battle
	var npc = NPCS.get(npc_id, {})
	var folder: String = npc.get("folder", "")
	if folder.is_empty():
		return []

	var script_path := "res://npcs/%s/loadout.gd" % folder
	var script = load(script_path)
	if script == null:
		push_error("Failed to load loadout for NPC: " + npc_id)
		return []

	return script.PATTERNS

# =============================================================================
# LOOT POOL HELPERS (What drops when defeating NPC)
# =============================================================================

static func get_npc_loot_pool(npc_id: String) -> Array:
	## Returns all items in an NPC's loot pool
	## Each item: { type: "worm"|"pattern", name: String, rarity: String }
	var npc = NPCS.get(npc_id, {})
	var folder: String = npc.get("folder", "")
	if folder.is_empty():
		return []

	var script_path := "res://npcs/%s/loot.gd" % folder
	var script = load(script_path)
	if script == null:
		push_error("Failed to load loot for NPC: " + npc_id)
		return []

	var items: Array = []

	# Add worms from loot file
	for worm_name in script.WORMS:
		var worm_def = WormDefs.WORMS.get(worm_name, {})
		items.append({
			"type": "worm",
			"name": worm_name,
			"rarity": worm_def.get("rarity", "common")
		})

	# Add patterns from loot file
	for pattern_name in script.PATTERNS:
		var pattern = PatternDefs.get_pattern(pattern_name)
		if not pattern.is_empty():
			items.append({
				"type": "pattern",
				"name": pattern_name,
				"rarity": pattern.get("rarity", "common")
			})

	# Add relics from this NPC
	var relics := CosmeticDefs.get_npc_relics(npc_id)
	for relic in relics:
		items.append({
			"type": "cosmetic",
			"name": relic["name"],
			"rarity": "relic"
		})

	return items

static func get_all_items_before_npc(npc_id: String) -> Array:
	## Returns all items from NPCs before this one (for "collect_all_before" check)
	var items: Array = []
	for id in NPC_ORDER:
		if id == npc_id:
			break
		items.append_array(get_npc_loot_pool(id))
	return items

# =============================================================================
# UNLOCK CHECKS
# =============================================================================

static func is_npc_unlocked(npc_id: String) -> bool:
	## Check if an NPC is unlocked based on SaveManager data
	var npc = NPCS.get(npc_id, {})
	var req: Dictionary = npc.get("unlock_requirement", {})
	var req_type: String = req.get("type", "start")

	match req_type:
		"start":
			return true

		"total_drops":
			var count: int = req.get("count", 0)
			return SaveManager.get_total_drops() >= count

		"rare_drops":
			var count: int = req.get("count", 0)
			var rare := SaveManager.get_rarity_drops("rare")
			var epic := SaveManager.get_rarity_drops("epic")
			var legendary := SaveManager.get_rarity_drops("legendary")
			var mythic := SaveManager.get_rarity_drops("mythic")
			return (rare + epic + legendary + mythic) >= count

		"collect_all_before":
			var required_items := get_all_items_before_npc(npc_id)
			for item in required_items:
				if item["type"] == "worm":
					if not SaveManager.has_worm(item["name"]):
						return false
				elif item["type"] == "pattern":
					if not SaveManager.has_pattern(item["name"]):
						return false
			return true

	return false

static func get_unlock_progress(npc_id: String) -> Dictionary:
	## Returns progress toward unlocking an NPC
	## { current: int, required: int, description: String }
	var npc = NPCS.get(npc_id, {})
	var req: Dictionary = npc.get("unlock_requirement", {})
	var req_type: String = req.get("type", "start")

	match req_type:
		"start":
			return {"current": 1, "required": 1, "description": "Always available"}

		"total_drops":
			var count: int = req.get("count", 0)
			var current := SaveManager.get_total_drops()
			return {"current": current, "required": count, "description": "Get %d drop(s)" % count}

		"rare_drops":
			var count: int = req.get("count", 0)
			var rare := SaveManager.get_rarity_drops("rare")
			var epic := SaveManager.get_rarity_drops("epic")
			var legendary := SaveManager.get_rarity_drops("legendary")
			var mythic := SaveManager.get_rarity_drops("mythic")
			var current := rare + epic + legendary + mythic
			return {"current": current, "required": count, "description": "Get %d rare+ drop(s)" % count}

		"collect_all_before":
			var required_items := get_all_items_before_npc(npc_id)
			var collected := 0
			for item in required_items:
				if item["type"] == "worm" and SaveManager.has_worm(item["name"]):
					collected += 1
				elif item["type"] == "pattern" and SaveManager.has_pattern(item["name"]):
					collected += 1
			return {"current": collected, "required": required_items.size(), "description": "Collect all previous items"}

	return {"current": 0, "required": 1, "description": "Unknown"}

# =============================================================================
# RANDOM LOOT
# =============================================================================

static func roll_loot(npc_id: String) -> Dictionary:
	## Roll for a random item from an NPC's loot pool
	## Returns { type: "worm"|"pattern"|"cosmetic", name: String, rarity: String, is_new: bool, is_shiny: bool }
	## Relics use their actual drop_chance from CosmeticDefs
	var pool := get_npc_loot_pool(npc_id)
	if pool.is_empty():
		return {}

	var item: Dictionary = {}

	# First, try rolling for relics using their actual drop_chance
	var roll := randf()
	var cumulative := 0.0
	for pool_item in pool:
		if pool_item.get("type") == "cosmetic":
			var cosmetic := CosmeticDefs.get_cosmetic(pool_item["name"])
			var drop_chance: float = cosmetic.get("drop_chance", 0.0)
			cumulative += drop_chance
			if roll < cumulative:
				item = pool_item
				break

	# If no relic hit, roll from the weighted non-relic pool
	if item.is_empty():
		var weighted_pool: Array = []
		for pool_item in pool:
			if pool_item.get("type") != "cosmetic":
				var weight := _get_rarity_weight(pool_item["rarity"])
				for i in range(weight):
					weighted_pool.append(pool_item)

		if weighted_pool.is_empty():
			# Fallback to any non-cosmetic item
			for pool_item in pool:
				if pool_item.get("type") != "cosmetic":
					weighted_pool.append(pool_item)

		if not weighted_pool.is_empty():
			item = weighted_pool[randi() % weighted_pool.size()]

	if item.is_empty():
		return {}

	# Check if it's new
	var is_new := false
	if item["type"] == "worm":
		is_new = not SaveManager.has_worm(item["name"])
	elif item["type"] == "pattern":
		is_new = not SaveManager.has_pattern(item["name"])
	elif item["type"] == "cosmetic":
		is_new = not SaveManager.has_cosmetic(item["name"])

	# Roll for shiny (1 in 100)
	var is_shiny := SaveManager.roll_shiny()

	return {
		"type": item["type"],
		"name": item["name"],
		"rarity": item["rarity"],
		"is_new": is_new,
		"is_shiny": is_shiny,
	}

static func _get_rarity_weight(rarity: String) -> int:
	## Weights for loot drop chances - higher = more common
	## Relic is handled separately via relic_drop_chance
	match rarity:
		"common": return 100
		"uncommon": return 45
		"rare": return 18
		"epic": return 7
		"legendary": return 3
		"mythic": return 1
		"relic": return 1  # Same rarity as mythic - ultra rare
	return 20

static func roll_relic_drop(npc_id: String) -> Dictionary:
	## Attempt to roll for a relic from this NPC's pool.
	## Each relic has its own drop chance (1/400 to 1/4000).
	## Returns empty dict if no relic drop.

	var npc_relics := CosmeticDefs.get_npc_relics(npc_id)
	if npc_relics.is_empty():
		return {}

	# Roll for each relic independently
	for relic in npc_relics:
		var drop_chance: float = relic.get("drop_chance", 0.0)
		if drop_chance > 0.0 and randf() < drop_chance:
			# Got a relic!
			var is_new := not SaveManager.has_cosmetic(relic["name"])
			var is_shiny := CosmeticDefs.roll_shiny()

			return {
				"type": "cosmetic",
				"name": relic["name"],
				"rarity": "relic",
				"is_new": is_new,
				"is_relic": true,
				"is_shiny": is_shiny,
			}

	return {}

static func get_npc_relic_info(npc_id: String) -> Array:
	## Returns info about relics that can drop from this NPC
	## For display in UI
	var relics := CosmeticDefs.get_npc_relics(npc_id)
	var result: Array = []
	for relic in relics:
		var drop_chance: float = relic.get("drop_chance", 0.0)
		var odds := int(1.0 / drop_chance) if drop_chance > 0 else 0
		result.append({
			"name": relic["name"],
			"slot": relic.get("slot", ""),
			"bonus": relic.get("bonus", ""),
			"odds": odds,  # e.g., 400 means "1 in 400"
			"owned": SaveManager.has_cosmetic(relic["name"]),
		})
	return result

static func get_loot_chances(npc_id: String) -> Dictionary:
	## Calculate drop chance percentage for each item in the loot pool
	## Returns { "item_name": percentage }
	## Relics use their actual drop_chance from CosmeticDefs
	var pool := get_npc_loot_pool(npc_id)
	if pool.is_empty():
		return {}

	# First, sum up relic drop chances (these are fixed probabilities)
	var total_relic_chance := 0.0
	var relic_chances: Dictionary = {}
	for item in pool:
		if item.get("type") == "cosmetic":
			var cosmetic := CosmeticDefs.get_cosmetic(item["name"])
			var drop_chance: float = cosmetic.get("drop_chance", 0.0)
			relic_chances[item["name"]] = drop_chance
			total_relic_chance += drop_chance

	# Remaining probability goes to non-relic items
	var non_relic_probability := 1.0 - total_relic_chance

	# Calculate total weight for non-relic items
	var total_weight := 0.0
	for item in pool:
		if item.get("type") != "cosmetic":
			total_weight += float(_get_rarity_weight(item["rarity"]))

	# Build the chances dictionary
	var chances: Dictionary = {}

	# Add relic chances (as percentages)
	for relic_name in relic_chances:
		chances[relic_name] = relic_chances[relic_name] * 100.0

	# Add non-relic chances (share the remaining probability by weight)
	if total_weight > 0.0:
		for item in pool:
			if item.get("type") != "cosmetic":
				var weight := float(_get_rarity_weight(item["rarity"]))
				var percentage := (weight / total_weight) * non_relic_probability * 100.0
				chances[item["name"]] = percentage

	return chances
