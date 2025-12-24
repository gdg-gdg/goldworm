extends RefCounted
class_name WormDefs
## worm_defs.gd - Worm shape definitions
## ======================================
## Edit this file to add/modify worm types.
##
## Each worm has:
##   - name: Display name
##   - cells: Array of Vector2i offsets from origin
##   - rotatable: Whether it can be rotated (base value, overridden by case opening)
##   - weight: Rarity weight (higher = more common)
##
## Rarity by segment count:
##   2 segments = Common (grey)
##   3 segments = Uncommon (blue)
##   4 segments = Rare (purple)
##   5 segments = Epic (pink)

static var WORMS := {
	# 2-segment worms - Common (weight: 10)
	"Sprout": {
		"name": "Sprout",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)],
		"rotatable": true,
		"weight": 10
	},
	"Bean": {
		"name": "Bean",
		"cells": [Vector2i(0, 0), Vector2i(0, 1)],
		"rotatable": true,
		"weight": 10
	},

	# 3-segment worms - Uncommon (weight: 6)
	"Wiggles": {
		"name": "Wiggles",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		"rotatable": true,
		"weight": 6
	},
	"Bendy": {
		"name": "Bendy",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
		"rotatable": true,
		"weight": 6
	},

	# 4-segment worms - Rare (weight: 3)
	"Lumpy": {
		"name": "Lumpy",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 3
	},
	"Slinky": {
		"name": "Slinky",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 3
	},
	"Chonk": {
		"name": "Chonk",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		"rotatable": false,
		"weight": 3
	},
	"Noodle": {
		"name": "Noodle",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
		"rotatable": true,
		"weight": 3
	},

	# 5-segment worms - Epic (weight: 1)
	"Thicc": {
		"name": "Thicc",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(1, -1)],
		"rotatable": true,
		"weight": 1
	},
	"Zigzag": {
		"name": "Zigzag",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2)],
		"rotatable": true,
		"weight": 1
	},
	"BigBoi": {
		"name": "BigBoi",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)],
		"rotatable": true,
		"weight": 1
	},
}

# List of worm names available for selection
static var POOL: Array = [
	"Sprout", "Bean",
	"Wiggles", "Bendy",
	"Lumpy", "Slinky", "Chonk", "Noodle",
	"Thicc", "Zigzag", "BigBoi"
]
