extends RefCounted
class_name WormDefs
## worm_defs.gd - Worm shape definitions
## ======================================
## Worms are organized by rarity.
##
## Distribution: 3 common, 4 uncommon, 2 rare, 1 mythic (10 total)
##
## NPC1/NPC2 only use 3+ cell worms (no tiny worms early game)
##
## Starting worms: Sprout, Bean (given to player at game start)

static var WORMS := {
	# ===================
	# COMMON (3 worms) - 3 cells, basic shapes
	# ===================
	"Sprout": {
		"name": "Sprout",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"rotatable": true,
		"rarity": "common",
		"pool": "starter"
	},
	"Bean": {
		"name": "Bean",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"rotatable": true,
		"rarity": "common",
		"pool": "starter"
	},
	"Wiggles": {
		"name": "Wiggles",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": true,
		"rarity": "common",
		"pool": "npc1"
	},

	# ===================
	# UNCOMMON (4 worms) - 3-4 cells, interesting shapes
	# ===================
	"Bendy": {
		"name": "Bendy",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc1"
	},
	"Curly": {
		"name": "Curly",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc2"
	},
	"Triplet": {
		"name": "Triplet",
		"cells": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 0)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc2"
	},
	"Slope": {
		"name": "Slope",
		"cells": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc3"
	},

	# ===================
	# RARE (2 worms) - 4-5 cells, complex shapes
	# ===================
	"Chonk": {
		"name": "Chonk",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": false,
		"rarity": "rare",
		"pool": "npc3"
	},
	"Zigzag": {
		"name": "Zigzag",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc4"
	},

	# ===================
	# MYTHIC (1 worm) - Big boi, 6+ cells
	# ===================
	"Leviathan": {
		"name": "Leviathan",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)],
		"rotatable": true,
		"rarity": "mythic",
		"pool": "npc5"
	},
}

# All worm names in pool
static var POOL: Array:
	get:
		return WORMS.keys()

# Get worms by their loot pool
static func get_worms_in_pool(pool_name: String) -> Array:
	var result: Array = []
	for worm_name in WORMS:
		if WORMS[worm_name].get("pool") == pool_name:
			result.append(worm_name)
	return result

# Get worms by rarity
static func get_worms_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for worm_name in WORMS:
		if WORMS[worm_name].get("rarity") == rarity:
			result.append(worm_name)
	return result

# Get rarity of a worm
static func get_rarity(worm_name: String) -> String:
	return WORMS.get(worm_name, {}).get("rarity", "common")
