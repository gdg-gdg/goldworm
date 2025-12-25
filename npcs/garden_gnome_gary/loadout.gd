extends RefCounted
class_name GardenGnomeGaryLoadout
## Garden Gnome Gary - Medium-Easy opponent
## Loadout: 3-4 segment worms, 2-3 cell patterns

# Worms this NPC can use in battle (picks 2 randomly)
static var WORMS: Array[String] = [
	"Sprout",
	"Bean",
	"Wiggles",
	"Bendy",
	"Triplet",
]

# Attack patterns this NPC can roll during battle
static var PATTERNS: Array[String] = [
	"Pebble",
	"Twins",
	"Stack",
	"Diagonal",
	"Spike",
	"Corner",
	"Bent",
	"Gap",
]
