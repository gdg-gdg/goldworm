extends RefCounted
class_name WormDefs
## worm_defs.gd - Worm shape definitions
## ======================================
## Worms are organized by rarity and assigned to NPC loot pools.
##
## Rarity by segment count:
##   2 segments = Common (grey)
##   3 segments = Uncommon (blue)
##   4 segments = Rare (purple)
##   5 segments = Epic (pink)
##
## Starting worms: Sprout, Bean (given to player at game start)

static var WORMS := {
	# ===================
	# 2-segment - Common
	# ===================
	"Sprout": {
		"name": "Sprout",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"rotatable": true,
		"rarity": "common",
		"pool": "starter"
	},
	"Bean": {
		"name": "Bean",
		"cells": [Vector2i(0, 0), Vector2i(0, 1)],
		"rotatable": true,
		"rarity": "common",
		"pool": "starter"
	},
	"Dot": {
		"name": "Dot",
		"cells": [Vector2i(0, 0), Vector2i(1, 1)],
		"rotatable": true,
		"rarity": "common",
		"pool": "npc1"
	},
	"Pip": {
		"name": "Pip",
		"cells": [Vector2i(0, 0), Vector2i(-1, 1)],
		"rotatable": true,
		"rarity": "common",
		"pool": "npc1"
	},

	# ===================
	# 3-segment - Uncommon
	# ===================
	"Wiggles": {
		"name": "Wiggles",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc1"
	},
	"Bendy": {
		"name": "Bendy",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"rotatable": true,
		"rarity": "uncommon",
		"pool": "npc1"
	},
	"Curly": {
		"name": "Curly",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
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
		"pool": "npc2"
	},

	# ===================
	# 4-segment - Rare
	# ===================
	"Lumpy": {
		"name": "Lumpy",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc2"
	},
	"Slinky": {
		"name": "Slinky",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc2"
	},
	"Chonk": {
		"name": "Chonk",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": false,
		"rarity": "rare",
		"pool": "npc3"
	},
	"Noodle": {
		"name": "Noodle",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc3"
	},
	"Hook": {
		"name": "Hook",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc3"
	},
	"Ziggy": {
		"name": "Ziggy",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc3"
	},
	"Tee": {
		"name": "Tee",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"rotatable": true,
		"rarity": "rare",
		"pool": "npc4"
	},

	# ===================
	# 5-segment - Epic
	# ===================
	"Thicc": {
		"name": "Thicc",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, -1)],
		"rotatable": true,
		"rarity": "epic",
		"pool": "npc4"
	},
	"Zigzag": {
		"name": "Zigzag",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		"rotatable": true,
		"rarity": "epic",
		"pool": "npc4"
	},
	"BigBoi": {
		"name": "BigBoi",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)],
		"rotatable": true,
		"rarity": "epic",
		"pool": "npc4"
	},
	"Crawler": {
		"name": "Crawler",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
		"rotatable": true,
		"rarity": "epic",
		"pool": "npc5"
	},
	"Chunk": {
		"name": "Chunk",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0)],
		"rotatable": true,
		"rarity": "epic",
		"pool": "npc5"
	},
	"Omega": {
		"name": "Omega",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)],
		"rotatable": true,
		"rarity": "epic",
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
