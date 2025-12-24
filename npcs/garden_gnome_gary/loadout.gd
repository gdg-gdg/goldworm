extends RefCounted
class_name GardenGnomeGaryLoadout
## Garden Gnome Gary - Medium-Easy opponent
## Loadout: 2-3 segment worms, 2-3 cell patterns

# Worms this NPC can use in battle (picks 2 randomly)
static var WORMS: Array[String] = [
	"Sprout",
	"Bean",
	"Dot",
	"Pip",
	"Wiggles",
	"Bendy",
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
]
