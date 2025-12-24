extends RefCounted
class_name MoleKingLoadout
## Mole King - Medium opponent
## Loadout: 3-4 segment worms, 3-4 cell patterns

# Worms this NPC can use in battle (picks 2 randomly)
static var WORMS: Array[String] = [
	"Wiggles",
	"Bendy",
	"Curly",
	"Triplet",
	"Lumpy",
	"Slinky",
	"Chonk",
]

# Attack patterns this NPC can roll during battle
static var PATTERNS: Array[String] = [
	"Spike",
	"Corner",
	"Stairs",
	"Bent",
	"Gap",
	"Square",
	"Tetris-L",
	"Tetris-T",
	"Tetris-S",
]
