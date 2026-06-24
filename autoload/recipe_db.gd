# RecipeDB.gd — AntChem 配方数据库 (Autoload 单例)
# 职责: 存储全部配方、匹配检测、发现状态、Signal 发射
# 三向同步: SynthesisGraph + InventoryManager + EquipmentStore 均监听信号
extends Node

# ── 数据 ──
var recipes: Array[Dictionary] = []
var discovered_ids: Array[String] = []
var pending_recipe: Dictionary = {}  # data bridge to test_field

# ── 信号 ──
signal recipe_discovered(recipe_id: String, recipe_type: String)
# recipe_type: "explosive" | "intermediate"

# ── 配方数据: [1起始 + 3炸药 + 3中间体 + 1炸药 + 2🔒可见] = 9节点原型 ──
func _ready() -> void:
	_load_prototype_recipes()

func _load_prototype_recipes() -> void:
	recipes = [
		# === 分支一: 黑火药家族 (4节点: 起始 + 2炸药 + 1🔒) ===
		{
			"id": "black_powder",
			"parent_ids": [],
			"recipe_type": "explosive",
			"discovered": true,  # 开局已知
			"player_name": "黑火药",
			"hint_text": "",
			"lock_text": "",
			"required_operations": ["crush", "mix", "heat_basic"],
			"ingredients": { "sulfur": 15.0, "saltpeter": 75.0, "charcoal": 10.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 0, "temp_tolerance": 40,
			"match_key": "",
			# 爆炸效果
			"explosion_radius": 120.0,
			"fragment_force": 300.0,
			"smoke_color": Color(0.62, 0.62, 0.62, 1.0), # --smoke-gray
			"smoke_density": 80,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			# 镜头效果
			"shake_amplitude": 3.0, "shake_frequency": 20.0, "shake_duration": 0.3,
			"flash_color": Color.WHITE, "flash_frames": 4,
			"shockwave_enabled": false
		},
		{
			"id": "brown_powder",
			"parent_ids": ["black_powder"],
			"recipe_type": "explosive",
			"discovered": false,
			"player_name": "",
			"hint_text": "坩埚里飘出棕红色的烟雾……这火药的颜色不太一样。",
			"lock_text": "",
			"required_operations": ["crush", "mix", "heat_basic"],
			"ingredients": { "sulfur": 5.0, "saltpeter": 80.0, "charcoal": 15.0 },
			"grind_level": 3, "grind_tolerance": 1,
			"temperature": 40, "temp_tolerance": 20,
			"match_key": "",
			"explosion_radius": 160.0,
			"fragment_force": 280.0,
			"smoke_color": Color(0.63, 0.32, 0.18, 1.0),
			"smoke_density": 60,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			"shake_amplitude": 4.0, "shake_frequency": 18.0, "shake_duration": 0.35,
			"flash_color": Color(1.0, 0.84, 0.42, 1.0), "flash_frames": 5,
			"shockwave_enabled": false
		},
		{
			"id": "slow_burn",
			"parent_ids": ["black_powder"],
			"recipe_type": "explosive",
			"discovered": false,
			"player_name": "",
			"hint_text": "坩埚里没有烟——只有一股闷烧的焦味。这东西烧得很慢……但推得很猛。",
			"lock_text": "",
			"required_operations": ["crush", "mix", "heat_basic"],
			"ingredients": { "sulfur": 10.0, "saltpeter": 70.0, "charcoal": 10.0, "clay": 10.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 10, "temp_tolerance": 10,
			"match_key": "",
			"explosion_radius": 80.0,
			"fragment_force": 500.0,
			"smoke_color": Color(0.55, 0.55, 0.55, 1.0),
			"smoke_density": 30,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "cone",
			"special_effect": "delayed",
			"shake_amplitude": 2.0, "shake_frequency": 8.0, "shake_duration": 0.2,
			"flash_color": Color.WHITE, "flash_frames": 3,
			"shockwave_enabled": false
		},
		{
			"id": "fast_burn",
			"parent_ids": ["black_powder"],
			"recipe_type": "explosive",
			"discovered": false,
			"player_name": "",
			"hint_text": "坩埚几乎要跳起来了——这粉末细得像灰尘，反应快得离谱。",
			"lock_text": "需要操作: 极细研磨 (精度 Lv4)。当前设备精度上限 Lv2。",
			"required_operations": ["graded_grind", "heat_controlled"],
			"ingredients": { "sulfur": 5.0, "saltpeter": 78.0, "charcoal": 17.0 },
			"grind_level": 4, "grind_tolerance": 0,
			"temperature": 80, "temp_tolerance": 10,
			"match_key": "",
			"explosion_radius": 60.0,
			"fragment_force": 700.0,
			"smoke_color": Color(0.5, 0.5, 0.5, 1.0),
			"smoke_density": 20,
			"fire_enabled": true, "fire_spread": 40.0,
			"shrapnel_pattern": "directional",
			"special_effect": "directional_blast",
			"shake_amplitude": 5.0, "shake_frequency": 25.0, "shake_duration": 0.4,
			"flash_color": Color(1.0, 0.84, 0.42, 1.0), "flash_frames": 4,
			"shockwave_enabled": true
		},

		# === 分支二: 硝化纤维 + 起爆 (3节点) ===
		{
			"id": "nitrating_acid",
			"parent_ids": ["black_powder"],
			"recipe_type": "intermediate",
			"discovered": false,
			"player_name": "硝化酸液",
			"hint_text": "刺鼻的黄色酸液——滴在木头上会烧焦。这东西似乎能把含碳的东西'硝化'成爆炸物。",
			"lock_text": "需要操作: 液体蒸馏。当前没有可用的蒸馏设备。",
			"required_operations": ["distillation", "heat_controlled"],
			"ingredients": { "saltpeter": 60.0, "formic_acid": 30.0, "sulfur": 10.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 30, "temp_tolerance": 10,
			"match_key": "",
			"explosion_radius": 0.0, "fragment_force": 0.0,
			"smoke_color": Color.GRAY, "smoke_density": 0,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			"shake_amplitude": 0.0, "shake_frequency": 0.0, "shake_duration": 0.0,
			"flash_color": Color.WHITE, "flash_frames": 0,
			"shockwave_enabled": false
		},
		{
			"id": "carbon_fiber",
			"parent_ids": ["black_powder"],
			"recipe_type": "intermediate",
			"discovered": false,
			"player_name": "碳化纤维",
			"hint_text": "轻而坚韧的黑色纤维。也许可以被什么液体浸泡？",
			"lock_text": "需要操作: 分级研磨 (精度 Lv4)。",
			"required_operations": ["graded_grind", "heat_basic"],
			"ingredients": { "charcoal": 70.0, "clay": 30.0 },
			"grind_level": 3, "grind_tolerance": 1,
			"temperature": 40, "temp_tolerance": 10,
			"match_key": "",
			"explosion_radius": 0.0, "fragment_force": 0.0,
			"smoke_color": Color.GRAY, "smoke_density": 0,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			"shake_amplitude": 0.0, "shake_frequency": 0.0, "shake_duration": 0.0,
			"flash_color": Color.WHITE, "flash_frames": 0,
			"shockwave_enabled": false
		},
		{
			"id": "nitrocellulose",
			"parent_ids": ["carbon_fiber", "nitrating_acid"],
			"recipe_type": "explosive",
			"discovered": false,
			"player_name": "",
			"hint_text": "纤维被硝化后变成浅黄色蓬松物——出乎意料地爆炸。",
			"lock_text": "需要操作: 浸泡吸收。",
			"required_operations": ["soak"],
			"ingredients": { "carbon_fiber": 80.0, "nitrating_acid": 20.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 10, "temp_tolerance": 10,
			"match_key": "",
			"explosion_radius": 100.0,
			"fragment_force": 800.0,
			"smoke_color": Color(0.9, 0.9, 0.85, 1.0),
			"smoke_density": 10,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			"shake_amplitude": 8.0, "shake_frequency": 22.0, "shake_duration": 0.5,
			"flash_color": Color(1.0, 1.0, 0.8, 1.0), "flash_frames": 5,
			"shockwave_enabled": true
		},

		# === 分支三: 芳香族 (2节点) ===
		{
			"id": "aromatic_oil",
			"parent_ids": [],
			"recipe_type": "intermediate",
			"discovered": false,
			"player_name": "芳香油",
			"hint_text": "轻而刺鼻的黄色油脂——单独没什么用，但一滴硝化酸液滴进去就猛烈冒泡……这东西遇到酸会剧烈反应。",
			"lock_text": "需要操作: 液体蒸馏。",
			"required_operations": ["distillation"],
			"ingredients": { "resin": 100.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 60, "temp_tolerance": 20,
			"match_key": "",
			"explosion_radius": 0.0, "fragment_force": 0.0,
			"smoke_color": Color.GRAY, "smoke_density": 0,
			"fire_enabled": false, "fire_spread": 0.0,
			"shrapnel_pattern": "radial",
			"special_effect": "none",
			"shake_amplitude": 0.0, "shake_frequency": 0.0, "shake_duration": 0.0,
			"flash_color": Color.WHITE, "flash_frames": 0,
			"shockwave_enabled": false
		},
		{
			"id": "tnt",
			"parent_ids": ["aromatic_oil", "nitrating_acid"],
			"recipe_type": "explosive",
			"discovered": false,
			"player_name": "",
			"hint_text": "苍黄色结晶片——出奇地稳定，可以徒手搬运。但用雷管引爆时释放出可怕的破坏力。",
			"lock_text": "需要操作: 硝化反应。精确控温 ≤10°C。",
			"required_operations": ["nitration", "heat_controlled"],
			"ingredients": { "aromatic_oil": 30.0, "nitrating_acid": 70.0 },
			"grind_level": 1, "grind_tolerance": 1,
			"temperature": 5, "temp_tolerance": 5,
			"match_key": "",
			"explosion_radius": 200.0,
			"fragment_force": 900.0,
			"smoke_color": Color(0.7, 0.65, 0.2, 1.0),
			"smoke_density": 70,
			"fire_enabled": true, "fire_spread": 80.0,
			"shrapnel_pattern": "radial",
			"special_effect": "armor_piercing",
			"shake_amplitude": 6.0, "shake_frequency": 15.0, "shake_duration": 0.5,
			"flash_color": Color(1.0, 0.9, 0.3, 1.0), "flash_frames": 6,
			"shockwave_enabled": true
		},
	]

	# 计算 match_key: round(value/5)*5 量化为5%桶
	for recipe in recipes:
		var parts: Array[String] = []
		for mat_id in recipe["ingredients"]:
			var val = recipe["ingredients"][mat_id]
			parts.append("%s:%d" % [mat_id, int(round(val / 5.0) * 5)])
		parts.sort()
		var grind_bucket = int(round(recipe["grind_level"] / 1.0))  # 1..5
		var temp_bucket = int(round(recipe["temperature"] / 5.0) * 5)  # 5°C buckets
		recipe["match_key"] = "|".join(parts) + "|g%d|t%d" % [grind_bucket, temp_bucket]
		if recipe["discovered"]:
			discovered_ids.append(recipe["id"])


# ── 配方匹配 (容差 ±5% 量化到 5% 桶) ──
func match(ingredients: Dictionary, grind_level: int, temperature: int, owned_operations: Array[String] = []) -> Dictionary:
	"""返回匹配到的 recipe dict, 或空 dict。
	grind_level 和 temperature 使用配方中定义的 tolerance 进行范围匹配。"""
	var key_parts: Array[String] = []
	for mat_id in ingredients:
		var val = ingredients[mat_id]
		key_parts.append("%s:%d" % [mat_id, int(round(val / 5.0) * 5)])
	key_parts.sort()
	var ingredient_key = "|".join(key_parts)

	for recipe in recipes:
		# 先比原料 (快速排除)
		if recipe["match_key"] == "":
			continue
		var rec_parts = recipe["match_key"].split("|g")[0]
		if rec_parts != ingredient_key:
			continue
		# 容差匹配: 研磨度 ± tolerance
		var rec_grind: int = recipe.get("grind_level", 1)
		var grind_tol: int = recipe.get("grind_tolerance", 0)
		if grind_level < rec_grind - grind_tol or grind_level > rec_grind + grind_tol:
			continue
		# 容差匹配: 温度 ± tolerance
		var rec_temp: int = recipe.get("temperature", 0)
		var temp_tol: int = recipe.get("temp_tolerance", 0)
		if temperature < rec_temp - temp_tol or temperature > rec_temp + temp_tol:
			continue
		# 额外检查: 所有 required_operations 是否被拥有
		for op in recipe.get("required_operations", []):
			if op not in owned_operations:
				return {}
		return recipe
	return {}


# ── 发现流程 ──
func discover(recipe_id: String) -> void:
	if recipe_id in discovered_ids:
		return
	discovered_ids.append(recipe_id)
	var recipe = get_recipe_by_id(recipe_id)
	if recipe.is_empty():
		return
	recipe["discovered"] = true
	emit_signal("recipe_discovered", recipe_id, recipe["recipe_type"])


# ── 查询 ──
func get_recipe_by_id(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}

func is_discovered(id: String) -> bool:
	return id in discovered_ids

func get_equipment_locked_recipes(owned_operations: Array[String]) -> Array[Dictionary]:
	"""返回设备锁状态: [{recipe, can_craft, missing_ops}]"""
	var result: Array[Dictionary] = []
	for r in recipes:
		var missing: Array[String] = []
		for op in r["required_operations"]:
			if op not in owned_operations:
				missing.append(op)
		result.append({"recipe": r, "can_craft": missing.is_empty(), "missing_ops": missing})
	return result
