extends RefCounted
class_name PatternDefs
## pattern_defs.gd - Attack pattern definitions
## =============================================
## Edit this file to add/modify attack patterns.
##
## Each pattern has:
##   - name: Display name
##   - cells: Array of Vector2i offsets from anchor point
##   - rotatable: Whether it can be rotated (base value, overridden by case opening)
##   - weight: Rarity weight (higher = more common)
##   - is_miss: (optional) If true, this skips the turn instead of attacking
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

static var PATTERNS: Array = [
	# ===================
	# MISSES - Skip turn!
	# ===================
	{
		"name": "Dud",
		"cells": [],
		"rotatable": false,
		"weight": 3,
		"is_miss": true
	},
	{
		"name": "Misfire",
		"cells": [],
		"rotatable": false,
		"weight": 2,
		"is_miss": true
	},
	{
		"name": "Jammed",
		"cells": [],
		"rotatable": false,
		"weight": 1.5,
		"is_miss": true
	},

	# ===================
	# 1 block - Common (grey)
	# ===================
	{
		"name": "Pebble",
		"cells": [Vector2i(0, 0)],
		"rotatable": false,
		"weight": 10
	},

	# ===================
	# 2 blocks - Common (light blue)
	# ===================
	{
		"name": "Twins",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"rotatable": true,
		"weight": 8
	},
	{
		"name": "Stack",
		"cells": [Vector2i(0, 0), Vector2i(0, 1)],
		"rotatable": true,
		"weight": 8
	},

	# ===================
	# 3 blocks - Uncommon (blue)
	# ===================
	{
		"name": "Spike",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"rotatable": true,
		"weight": 6
	},
	{
		"name": "Corner",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"rotatable": true,
		"weight": 6
	},
	{
		"name": "Stairs",
		"cells": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)],
		"rotatable": true,
		"weight": 5
	},

	# ===================
	# 4 blocks - Rare (purple)
	# ===================
	{
		"name": "Square",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": false,
		"weight": 4
	},
	{
		"name": "Tetris-L",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 4
	},
	{
		"name": "Tetris-T",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
		"rotatable": true,
		"weight": 4
	},
	{
		"name": "Tetris-S",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 4
	},
	{
		"name": "Line4",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"rotatable": true,
		"weight": 3
	},

	# ===================
	# 5 blocks - Epic (pink)
	# ===================
	{
		"name": "Cross",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
		"rotatable": true,
		"weight": 2
	},
	{
		"name": "Domino",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)],
		"rotatable": true,
		"weight": 2
	},
	{
		"name": "Chonky-L",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)],
		"rotatable": true,
		"weight": 2
	},
	{
		"name": "Hammer",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, 2)],
		"rotatable": true,
		"weight": 2
	},

	# ===================
	# 6 blocks - Legendary (red)
	# ===================
	{
		"name": "Big-Cross",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)],
		"rotatable": true,
		"weight": 1
	},
	{
		"name": "Chungus",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 1
	},
	{
		"name": "Stairway",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2)],
		"rotatable": true,
		"weight": 1
	},

	# ===================
	# 7 blocks - Mythic (gold)
	# ===================
	{
		"name": "Nuke",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(0, 2), Vector2i(0, -2)],
		"rotatable": true,
		"weight": 0.5
	},
	{
		"name": "Annihilator",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)],
		"rotatable": true,
		"weight": 0.3
	},
]
