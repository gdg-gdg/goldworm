extends RefCounted
class_name FarmerJoeLoadout
## Farmer Joe - Easy opponent
## Loadout: 3-segment worms, basic 1-2 cell patterns

# Worms this NPC can use in battle (picks 2 randomly)
static var WORMS: Array[String] = [
	"Sprout",
	"Bean",
	"Wiggles",
]

# Attack patterns this NPC can roll during battle
static var PATTERNS: Array[String] = [
	"Pebble",
	"Twins",
	"Stack",
	"Diagonal",
]
