# AntChem Asset Map — maps material/intermediate/equipment IDs to CC0 sprite paths
# Idylwild's Arcanum (OpenGameArt, CC0) + OPP2017 Cave Tiles (Public Domain)
extends RefCounted

const MATERIAL_ICONS = {
	"sulfur":       "res://assets/external/crystal_orange.png",
	"saltpeter":    "res://assets/external/crystal_blue.png",
	"charcoal":     "res://assets/external/bonemeal.png",
	"clay":         "res://assets/external/runestone_earth.png",
	"iron_rust":    "res://assets/external/raw_purple_gem.png",
	"limestone":    "res://assets/external/diamond.png",
	"diatomite":    "res://assets/external/raw_green_gem.png",
	"formic_acid":  "res://assets/external/potion_half_1.png",
	"beeswax":      "res://assets/external/potion_full_2.png",
	"resin":        "res://assets/external/potion_full_3.png",
	"fat":          "res://assets/external/stoppered_bottle_filled.png",
	"plant_ash":    "res://assets/external/bone.png",
	"rot_soil":     "res://assets/external/mandrake_root.png",
	"ammonium":     "res://assets/external/cut_green_gem.png",
	"fireant_venom":"res://assets/external/potion_full_1.png",
	"lead_powder":  "res://assets/external/crystal_purple.png",
}

static func get_material_icon(mat_id: String) -> String:
	return MATERIAL_ICONS.get(mat_id, "")
