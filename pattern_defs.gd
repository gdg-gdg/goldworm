extends RefCounted
class_name PatternDefs
## pattern_defs.gd - Attack pattern definitions
## =============================================
## Patterns are organized by rarity and assigned to NPC loot pools.
##
## Rarity by cell count:
##   0 cells (miss) = appears as dark/negative
##   1 cell = Common (grey)
##   2 cells = Common (light blue)
##   3 cells = Uncommon (blue)
##   4 cells = Rare (purple)
##   5 cells = Epic (pink)
##   6 cells = Legendary (red)
##   7 cells = Mythic (gold)
##
## Starting patterns: Pebble, Twins, Stack, Spike, Corner

static var PATTERNS: Array = [
	# ===================
	# MISSES - Skip turn! (Always available)
	# ===================
	{
		"name": "Dud",
		"cells": [],
		"rotatable": false,
		"weight": 3,
		"is_miss": true,
		"rarity": "miss",
		"pool": "always"
	},
	{
		"name": "Misfire",
		"cells": [],
		"rotatable": false,
		"weight": 2,
		"is_miss": true,
		"rarity": "miss",
		"pool": "always"
	},
	{
		"name": "Jammed",
		"cells": [],
		"rotatable": false,
		"weight": 1.5,
		"is_miss": true,
		"rarity": "miss",
		"pool": "always"
	},

	# ===================
	# 1 block - Common (starter)
	# ===================
	{
		"name": "Pebble",
		"cells": [Vector2i(0, 0)],
		"rotatable": false,
		"weight": 10,
		"rarity": "common",
		"pool": "starter"
	},

	# ===================
	# 2 blocks - Common (starter)
	# ===================
	{
		"name": "Twins",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"rotatable": true,
		"weight": 8,
		"rarity": "common",
		"pool": "starter"
	},
	{
		"name": "Stack",
		"cells": [Vector2i(0, 0), Vector2i(0, 1)],
		"rotatable": true,
		"weight": 8,
		"rarity": "common",
		"pool": "starter"
	},
	{
		"name": "Diagonal",
		"cells": [Vector2i(0, 0), Vector2i(1, 1)],
		"rotatable": true,
		"weight": 7,
		"rarity": "common",
		"pool": "npc1"
	},
	{
		"name": "Skip",
		"cells": [Vector2i(0, 0), Vector2i(2, 0)],
		"rotatable": true,
		"weight": 6,
		"rarity": "common",
		"pool": "npc1"
	},

	# ===================
	# 3 blocks - Uncommon (starter + npc1)
	# ===================
	{
		"name": "Spike",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"rotatable": true,
		"weight": 6,
		"rarity": "uncommon",
		"pool": "starter"
	},
	{
		"name": "Corner",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"rotatable": true,
		"weight": 6,
		"rarity": "uncommon",
		"pool": "starter"
	},
	{
		"name": "Stairs",
		"cells": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
		"rotatable": true,
		"weight": 5,
		"rarity": "uncommon",
		"pool": "npc1"
	},
	{
		"name": "Bent",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"rotatable": true,
		"weight": 5,
		"rarity": "uncommon",
		"pool": "npc1"
	},
	{
		"name": "Gap",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0)],
		"rotatable": true,
		"weight": 5,
		"rarity": "uncommon",
		"pool": "npc2"
	},

	# ===================
	# 4 blocks - Rare (npc2)
	# ===================
	{
		"name": "Square",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": false,
		"weight": 4,
		"rarity": "rare",
		"pool": "npc2"
	},
	{
		"name": "Tetris-L",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 4,
		"rarity": "rare",
		"pool": "npc2"
	},
	{
		"name": "Tetris-T",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"rotatable": true,
		"weight": 4,
		"rarity": "rare",
		"pool": "npc2"
	},
	{
		"name": "Tetris-S",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 4,
		"rarity": "rare",
		"pool": "npc3"
	},
	{
		"name": "Line4",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"rotatable": true,
		"weight": 3,
		"rarity": "rare",
		"pool": "npc3"
	},
	{
		"name": "Scatter",
		"cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(3, 1)],
		"rotatable": true,
		"weight": 3,
		"rarity": "rare",
		"pool": "npc3"
	},
	{
		"name": "Diamond",
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)],
		"rotatable": false,
		"weight": 3,
		"rarity": "rare",
		"pool": "npc3"
	},

	# ===================
	# 5 blocks - Epic (npc3 + npc4)
	# ===================
	{
		"name": "Cross",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
		"rotatable": true,
		"weight": 2,
		"rarity": "epic",
		"pool": "npc3"
	},
	{
		"name": "Domino",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
		"rotatable": true,
		"weight": 2,
		"rarity": "epic",
		"pool": "npc4"
	},
	{
		"name": "Chonky-L",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
		"rotatable": true,
		"weight": 2,
		"rarity": "epic",
		"pool": "npc4"
	},
	{
		"name": "Hammer",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"rotatable": true,
		"weight": 2,
		"rarity": "epic",
		"pool": "npc4"
	},
	{
		"name": "Arrow",
		"cells": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(1, 2), Vector2i(1, 3)],
		"rotatable": true,
		"weight": 2,
		"rarity": "epic",
		"pool": "npc4"
	},

	# ===================
	# 6 blocks - Legendary (npc4 + npc5)
	# ===================
	{
		"name": "Big-Cross",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
		"rotatable": true,
		"weight": 1,
		"rarity": "legendary",
		"pool": "npc4"
	},
	{
		"name": "Chungus",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 1,
		"rarity": "legendary",
		"pool": "npc5"
	},
	{
		"name": "Stairway",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)],
		"rotatable": true,
		"weight": 1,
		"rarity": "legendary",
		"pool": "npc5"
	},
	{
		"name": "Tetris-J",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)],
		"rotatable": true,
		"weight": 1,
		"rarity": "legendary",
		"pool": "npc5"
	},

	# ===================
	# 7 blocks - Mythic (npc5)
	# ===================
	{
		"name": "Nuke",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(0, 2), Vector2i(0, -2)],
		"rotatable": true,
		"weight": 0.5,
		"rarity": "mythic",
		"pool": "npc5"
	},
	{
		"name": "Annihilator",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)],
		"rotatable": true,
		"weight": 0.3,
		"rarity": "mythic",
		"pool": "npc5"
	},
	{
		"name": "Carpet",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)],
		"rotatable": true,
		"weight": 0.4,
		"rarity": "mythic",
		"pool": "npc5"
	},
]

# Get patterns by their loot pool
static func get_patterns_in_pool(pool_name: String) -> Array:
	var result: Array = []
	for pattern in PATTERNS:
		if pattern.get("pool") == pool_name:
			result.append(pattern)
	return result

# Get patterns by rarity
static func get_patterns_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for pattern in PATTERNS:
		if pattern.get("rarity") == rarity:
			result.append(pattern)
	return result

# Get a pattern by name
static func get_pattern(name: String) -> Dictionary:
	for pattern in PATTERNS:
		if pattern.get("name") == name:
			return pattern
	return {}

# Get rarity of a pattern
static func get_rarity(pattern_name: String) -> String:
	for pattern in PATTERNS:
		if pattern.get("name") == pattern_name:
			return pattern.get("rarity", "common")
	return "common"
