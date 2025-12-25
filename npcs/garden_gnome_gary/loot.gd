extends RefCounted
class_name GardenGnomeGaryLoot
## Garden Gnome Gary - Loot pool
## Drops: Uncommon worms and patterns (including gapped)

# Worms that can drop from defeating this NPC
static var WORMS: Array[String] = [
	"Curly",
	"Triplet",
]

# Patterns that can drop from defeating this NPC
static var PATTERNS: Array[String] = [
	"Gap",
	"Split-Pair",
	"Hollow-Corner",
	"Square",
	"Tetris-L",
	"Tetris-T",
]
