# InventoryManager.gd — 原料库存 (Autoload 单例)
extends Node

# 16 种自然原料 (原型全无限)
var natural_materials: Dictionary = {
	"sulfur":       {"name": "硫磺石",  "desc": "火山蚁丘的黄色结晶",  "icon_color": Color(0.96, 0.82, 0.42)},
	"saltpeter":    {"name": "硝石晶",  "desc": "洞穴壁上的白色刮取物", "icon_color": Color(0.9, 0.9, 0.9)},
	"charcoal":     {"name": "碳粉",    "desc": "烧过的枯枝研磨",      "icon_color": Color(0.1, 0.1, 0.1)},
	"clay":         {"name": "黏土",    "desc": "红褐色泥块",           "icon_color": Color(0.55, 0.43, 0.39)},
	"iron_rust":    {"name": "铁锈粉",  "desc": "废弃金属的红色粉末",   "icon_color": Color(0.63, 0.32, 0.18)},
	"limestone":    {"name": "石灰石",  "desc": "白色石料",            "icon_color": Color(0.9, 0.9, 0.85)},
	"diatomite":    {"name": "硅藻土",  "desc": "白色轻粉",            "icon_color": Color(0.95, 0.95, 0.9)},
	"formic_acid":  {"name": "蚁酸液",  "desc": "行军蚁自卫酸液",      "icon_color": Color(0.49, 0.76, 0.26)},
	"beeswax":      {"name": "蜂巢蜡",  "desc": "野蜂巢穴采集",        "icon_color": Color(0.96, 0.82, 0.42)},
	"resin":        {"name": "天然树脂","desc": "松树基部的金色胶块",  "icon_color": Color(0.85, 0.65, 0.13)},
	"fat":          {"name": "肥脂",    "desc": "蚜虫分泌的黄色油脂",  "icon_color": Color(0.9, 0.8, 0.5)},
	"plant_ash":    {"name": "草木灰",  "desc": "枯枝烧尽后的白灰",    "icon_color": Color(0.85, 0.85, 0.85)},
	"rot_soil":     {"name": "腐败土",  "desc": "腐烂落叶的黑土",      "icon_color": Color(0.2, 0.15, 0.1)},
	"ammonium":     {"name": "洞壁硝铵","desc": "洞穴深处的白色针状结晶","icon_color": Color(0.95, 0.95, 0.9)},
	"fireant_venom":{"name": "火蚁毒液","desc": "红火蚁战斗掉落 (稀有)","icon_color": Color(1.0, 0.44, 0.0)},
	"lead_powder":  {"name": "铅粉",    "desc": "特殊地质矿脉 (稀有)",  "icon_color": Color(0.45, 0.45, 0.5)},
}

# 已解锁中间体 (id -> 数量, -1 表示无限/可重复制作)
var intermediates: Dictionary = {}


func _ready() -> void:
	# 实例化时会连接 RecipeDB 信号
	RecipeDB.recipe_discovered.connect(_on_recipe_discovered)


func _on_recipe_discovered(recipe_id: String, recipe_type: String) -> void:
	if recipe_type == "intermediate":
		intermediates[recipe_id] = -1  # 解锁，可无限使用


# ── 查询 ──
func get_available_materials() -> Dictionary:
	"""返回 {material_id: {name, desc, icon_color}} (自然原料)"""
	return natural_materials.duplicate()

func get_available_intermediates() -> Dictionary:
	return intermediates.duplicate()

func is_available(mat_id: String) -> bool:
	return mat_id in natural_materials or mat_id in intermediates
