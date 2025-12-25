extends RefCounted
class_name CosmeticDefs
## cosmetic_defs.gd - Relic cosmetic definitions
## ==============================================
## Relics are ultra-rare cosmetic items with gameplay bonuses.
## They can drop from NPCs, achievements, or cases.
##
## Sources:
##   - "npc": Drops from specific NPC (uses npc_id and drop_chance)
##   - "achievement": Unlocked via achievements (not implemented yet)
##   - "case": Can appear in victory cases (not implemented yet)
##
## Drop chances range from 1/400 (0.0025) to 1/4000 (0.00025)
## All relics have 1/100 chance to be SHINY when obtained

const SHINY_CHANCE := 0.01  # 1 in 100

static var COSMETICS: Dictionary = {
	# ===================
	# NPC1 - Farmer Joe (1 relic, easier drop)
	# ===================
	"Gardener's Gauntlets": {
		"name": "Gardener's Gauntlets",
		"slot": "hands",
		"description": "Heavy-duty gloves for serious garden warfare.",
		"bonus": "Patterns deal +1 splash damage to adjacent cells (10% chance)",
		"effect_id": "splash_damage",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc1",
		"drop_chance": 0.0025,  # 1 in 400
	},

	# ===================
	# NPC2 - Garden Gnome Gary (2 relics)
	# ===================
	"Gnome's Lantern": {
		"name": "Gnome's Lantern",
		"slot": "back",
		"description": "A tiny lantern that illuminates hidden things.",
		"bonus": "Last hit area glows faintly on enemy grid",
		"effect_id": "hit_glow",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc2",
		"drop_chance": 0.00125,  # 1 in 800
	},
	"Root-Walker Sandals": {
		"name": "Root-Walker Sandals",
		"slot": "feet",
		"description": "Made from the roots of the World Tree.",
		"bonus": "Your worms can be placed diagonally adjacent",
		"effect_id": "diagonal_place",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc2",
		"drop_chance": 0.001,  # 1 in 1000
	},

	# ===================
	# NPC3 - Mole King (2 relics)
	# ===================
	"Mole King's Helm": {
		"name": "Mole King's Helm",
		"slot": "hat",
		"description": "Once worn by the ruler of the underground.",
		"bonus": "Start battles with 1 revealed enemy cell",
		"effect_id": "reveal_start",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc3",
		"drop_chance": 0.000667,  # 1 in 1500
	},
	"Boots of Burrowing": {
		"name": "Boots of Burrowing",
		"slot": "feet",
		"description": "Allow the wearer to sense underground movement.",
		"bonus": "See enemy worm count at start of battle",
		"effect_id": "worm_sense",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc3",
		"drop_chance": 0.0005,  # 1 in 2000
	},

	# ===================
	# NPC4 - Compost Queen (3 relics)
	# ===================
	"Crown of Compost": {
		"name": "Crown of Compost",
		"slot": "hat",
		"description": "A crown woven from the finest decomposed matter.",
		"bonus": "+1 pattern reroll per match",
		"effect_id": "reroll_bonus",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc4",
		"drop_chance": 0.0004,  # 1 in 2500
	},
	"Compost Queen's Pendant": {
		"name": "Compost Queen's Pendant",
		"slot": "neck",
		"description": "Contains a fragment of pure decay.",
		"bonus": "Hits have 10% chance to spread to one adjacent cell",
		"effect_id": "decay_spread",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc4",
		"drop_chance": 0.000333,  # 1 in 3000
	},
	"Earthworm Cape": {
		"name": "Earthworm Cape",
		"slot": "back",
		"description": "Woven from the silk of giant earthworms.",
		"bonus": "Your worms take 1 extra hit before dying",
		"effect_id": "worm_armor",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc4",
		"drop_chance": 0.00025,  # 1 in 4000
	},

	# ===================
	# NPC5 - Worm God (2 relics, hardest drops)
	# ===================
	"Amulet of the Worm God": {
		"name": "Amulet of the Worm God",
		"slot": "neck",
		"description": "An ancient artifact pulsing with worm energy.",
		"bonus": "5% chance to strike twice",
		"effect_id": "double_strike",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc5",
		"drop_chance": 0.00025,  # 1 in 4000
	},
	"Worm-Silk Gloves": {
		"name": "Worm-Silk Gloves",
		"slot": "hands",
		"description": "Impossibly smooth gloves that enhance dexterity.",
		"bonus": "+1 free rotation per turn",
		"effect_id": "free_rotation",
		"rarity": "relic",
		"source": "npc",
		"npc_id": "npc5",
		"drop_chance": 0.00025,  # 1 in 4000
	},
}

# Get all relics as an array
static func get_all_relics() -> Array:
	var result: Array = []
	for name in COSMETICS:
		result.append(COSMETICS[name])
	return result

# Get relics by slot
static func get_relics_by_slot(slot: String) -> Array:
	var result: Array = []
	for name in COSMETICS:
		if COSMETICS[name].get("slot") == slot:
			result.append(COSMETICS[name])
	return result

# Get a specific cosmetic by name
static func get_cosmetic(name: String) -> Dictionary:
	return COSMETICS.get(name, {})

# Get all slot types
static func get_all_slots() -> Array:
	return ["hat", "back", "hands", "neck", "feet"]

# Get relics that drop from a specific NPC
static func get_npc_relics(npc_id: String) -> Array:
	var result: Array = []
	for name in COSMETICS:
		var cosmetic: Dictionary = COSMETICS[name]
		if cosmetic.get("source") == "npc" and cosmetic.get("npc_id") == npc_id:
			result.append(cosmetic)
	return result

# Get drop chance for a specific relic
static func get_drop_chance(relic_name: String) -> float:
	var cosmetic: Dictionary = COSMETICS.get(relic_name, {})
	return cosmetic.get("drop_chance", 0.0)

# Check if a roll is shiny (1 in 100)
static func roll_shiny() -> bool:
	return randf() < SHINY_CHANCE
