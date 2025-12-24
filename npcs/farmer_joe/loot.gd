extends RefCounted
class_name FarmerJoeLoot
## Farmer Joe - Loot pool
## Drops: Common worms and basic patterns

# Worms that can drop from defeating this NPC
static var WORMS: Array[String] = [
	"Dot",
	"Pip",
]

# Patterns that can drop from defeating this NPC
static var PATTERNS: Array[String] = [
	"Diagonal",
	"Skip",
	"Stairs",
	"Bent",
]
