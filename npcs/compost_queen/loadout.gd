extends RefCounted
class_name CompostQueenLoadout
## Compost Queen - Hard opponent
## Loadout: 4-5 segment worms, 4-5 cell patterns

# Worms this NPC can use in battle (picks 2 randomly)
static var WORMS: Array[String] = [
	"Lumpy",
	"Slinky",
	"Noodle",
	"Hook",
	"Ziggy",
	"Tee",
	"Thicc",
	"Zigzag",
]

# Attack patterns this NPC can roll during battle
static var PATTERNS: Array[String] = [
	"Square",
	"Tetris-L",
	"Tetris-T",
	"Tetris-S",
	"Line4",
	"Diamond",
	"Cross",
	"Domino",
	"Chonky-L",
	"Hammer",
]
