extends RefCounted
class_name ShaderConfig
## ShaderConfig.gd - Background shader color configurations
## =========================================================
## Uses env_tint and spec_color for n64_bg.gdshader

# Screen color presets (env_tint, spec_color, base_color)
const SCREENS := {
	"main_menu": {
		"env_tint": Color(0.15, 0.15, 0.2),
		"spec_color": Color(0.3, 0.3, 0.4),
		"base_color": Color(0.05, 0.05, 0.08),  # Very dark
	},
	"npc_menu": {
		"env_tint": Color(0.4, 0.7, 0.5),
		"spec_color": Color(0.8, 1.0, 0.7),
		"base_color": Color(0.1, 0.2, 0.12),  # Dark green
	},
	"collection": {
		"env_tint": Color(0.7, 0.5, 0.3),
		"spec_color": Color(1.0, 0.8, 0.5),
		"base_color": Color(0.2, 0.15, 0.08),  # Dark bronze
	},
	"case_opening": {
		"env_tint": Color(0.6, 0.65, 0.7),
		"spec_color": Color(0.9, 0.95, 1.0),
		"base_color": Color(0.15, 0.15, 0.18),  # Silver-grey
	},
}

# NPC fight colors (keyed by npc_id)
const NPC_FIGHTS := {
	"npc1": {  # Farmer Joe - green
		"env_tint": Color(0.3, 0.65, 0.35),
		"spec_color": Color(0.6, 1.0, 0.5),
		"base_color": Color(0.08, 0.18, 0.08),
	},
	"npc2": {  # Garden Gnome Gary - earthy brown
		"env_tint": Color(0.6, 0.45, 0.3),
		"spec_color": Color(0.9, 0.7, 0.4),
		"base_color": Color(0.15, 0.1, 0.06),
	},
	"npc3": {  # Mole King - deep underground
		"env_tint": Color(0.4, 0.35, 0.3),
		"spec_color": Color(0.6, 0.5, 0.4),
		"base_color": Color(0.1, 0.08, 0.06),
	},
	"npc4": {  # Compost Queen - decay purple
		"env_tint": Color(0.5, 0.3, 0.6),
		"spec_color": Color(0.8, 0.5, 1.0),
		"base_color": Color(0.12, 0.06, 0.15),
	},
	"npc5": {  # Worm God - cosmic gold
		"env_tint": Color(0.9, 0.7, 0.3),
		"spec_color": Color(1.0, 0.9, 0.5),
		"base_color": Color(0.2, 0.15, 0.05),
	},
}

# Rarity colors for case opening reveals
const RARITY_COLORS := {
	"common": {
		"env_tint": Color(0.5, 0.5, 0.55),
		"spec_color": Color(0.7, 0.7, 0.75),
		"base_color": Color(0.12, 0.12, 0.14),  # Grey
	},
	"uncommon": {
		"env_tint": Color(0.35, 0.6, 0.4),
		"spec_color": Color(0.5, 0.9, 0.6),
		"base_color": Color(0.08, 0.18, 0.1),  # Green
	},
	"rare": {
		"env_tint": Color(0.4, 0.5, 0.9),
		"spec_color": Color(0.6, 0.7, 1.0),
		"base_color": Color(0.08, 0.1, 0.25),  # Blue
	},
	"epic": {
		"env_tint": Color(0.7, 0.35, 0.85),
		"spec_color": Color(0.9, 0.5, 1.0),
		"base_color": Color(0.18, 0.08, 0.22),  # Purple
	},
	"legendary": {
		"env_tint": Color(1.0, 0.6, 0.25),
		"spec_color": Color(1.0, 0.85, 0.4),
		"base_color": Color(0.25, 0.15, 0.05),  # Orange
	},
	"mythic": {
		"env_tint": Color(1.0, 0.85, 0.35),
		"spec_color": Color(1.0, 1.0, 0.6),
		"base_color": Color(0.3, 0.25, 0.05),  # Gold
	},
	"relic": {
		"env_tint": Color(0.35, 0.95, 0.65),
		"spec_color": Color(0.5, 1.0, 0.8),
		"base_color": Color(0.05, 0.25, 0.18),  # Teal
	},
}

# Rarity priority for finding highest
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic", "relic"]

static func get_screen_colors(screen_name: String) -> Dictionary:
	return SCREENS.get(screen_name, SCREENS["main_menu"])

static func get_npc_fight_colors(npc_id: String) -> Dictionary:
	return NPC_FIGHTS.get(npc_id, NPC_FIGHTS["npc1"])

static func get_rarity_colors(rarity: String) -> Dictionary:
	return RARITY_COLORS.get(rarity.to_lower(), RARITY_COLORS["common"])

static func get_highest_rarity(rarities: Array) -> String:
	## Given an array of rarity strings, return the highest one
	var highest_idx := -1
	for rarity in rarities:
		var idx := RARITY_ORDER.find(rarity.to_lower())
		if idx > highest_idx:
			highest_idx = idx
	if highest_idx >= 0:
		return RARITY_ORDER[highest_idx]
	return "common"

static func apply_to_material(mat: ShaderMaterial, colors: Dictionary) -> void:
	## Apply color config to a shader material (n64_bg.gdshader)
	if mat == null:
		return
	if colors.has("env_tint"):
		var c: Color = colors["env_tint"]
		mat.set_shader_parameter("env_tint", Vector3(c.r, c.g, c.b))
	if colors.has("spec_color"):
		var c: Color = colors["spec_color"]
		mat.set_shader_parameter("spec_color", Vector3(c.r, c.g, c.b))
	if colors.has("base_color"):
		var c: Color = colors["base_color"]
		mat.set_shader_parameter("base_color", Vector3(c.r, c.g, c.b))
