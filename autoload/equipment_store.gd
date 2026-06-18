# EquipmentStore.gd — AntChem 设备商店 (Autoload 单例)
extends Node

# 14 件设备。已拥有 = owned[device_id] = true
var owned: Dictionary = {}
var operations: Dictionary = {}  # op_name -> [device_ids that provide it]

# 设备定义
var devices: Array[Dictionary] = [
	{ "id": "mortar_stone",      "name": "碎石研钵",   "type": "研磨", "ops": ["crush"],            "owned": true,  "cost_sand": 0,   "cost_parts": {},     "desc": "一块凹石板+一块圆石。能捣碎。精度上限 Lv2。" },
	{ "id": "mortar_graded",     "name": "分级研钵",   "type": "研磨", "ops": ["graded_grind"],     "owned": false, "cost_sand": 300, "cost_parts": {},     "desc": "多层筛网的陶钵。操作: 分级研磨。精度可达 Lv4。" },
	{ "id": "mortar_precision",  "name": "精密研钵",   "type": "研磨", "ops": ["precision_grind"],  "owned": false, "cost_sand": 600, "cost_parts": {"precision": 2}, "desc": "" },
	{ "id": "firefly_lamp",      "name": "萤火虫灯",   "type": "加热", "ops": ["heat_basic"],       "owned": true,  "cost_sand": 0,   "cost_parts": {},     "desc": "几只萤火虫装在树脂壳里。能加热但没法控温。温度上限 40°C。" },
	{ "id": "crucible_thermo",   "name": "恒温坩埚",   "type": "加热", "ops": ["heat_controlled"],  "owned": false, "cost_sand": 250, "cost_parts": {},     "desc": "封闭陶瓷坩埚，带控温气孔。精确到 ±5°C。" },
	{ "id": "furnace",           "name": "高温熔炉",   "type": "加热", "ops": ["heat_high", "high_oxidation"], "owned": false, "cost_sand": 1000, "cost_parts": {"precision": 5, "fireant_core": 1}, "desc": "耐火石搭建的熔炉，可达 200°C+。操作: 高温氧化 / 金属熔融。" },
	{ "id": "still",             "name": "蒸馏管",     "type": "液体", "ops": ["distillation"],     "owned": false, "cost_sand": 200, "cost_parts": {"precision": 1}, "desc": "弯弯曲曲的空心草茎。能把液体蒸发再凝结。" },
	{ "id": "acid_bench",        "name": "酸蚀台",     "type": "液体", "ops": ["nitration"],        "owned": false, "cost_sand": 500, "cost_parts": {"acid_resist": 2}, "desc": "耐酸石材台面，安全处理腐蚀性液体。" },
	{ "id": "nut_crucible",      "name": "坚果坩埚",   "type": "混合", "ops": ["mix"],              "owned": true,  "cost_sand": 0,   "cost_parts": {},     "desc": "掏空的坚果壳。基础混合容器。" },
	{ "id": "soak_trough",       "name": "纤维浸泡槽", "type": "混合", "ops": ["soak"],             "owned": false, "cost_sand": 400, "cost_parts": {},     "desc": "石凿的浅槽。纤维在液体中浸泡吸收。" },
	{ "id": "press_hydraulic",   "name": "水压塑形机", "type": "混合", "ops": ["press"],            "owned": false, "cost_sand": 800, "cost_parts": {"precision": 3}, "desc": "利用水压将炸药压制成任意形状。" },
	{ "id": "cure_oven",         "name": "恒温固化炉", "type": "固化", "ops": ["cure"],             "owned": false, "cost_sand": 350, "cost_parts": {"precision": 1}, "desc": "密封的陶炉，低温恒温固化。" },
	{ "id": "det_testbench",     "name": "起爆器测试台","type": "固化", "ops": ["det_packaging"],   "owned": false, "cost_sand": 600, "cost_parts": {"precision": 2}, "desc": "隔离测试舱，安全封装起爆装置。" },
	{ "id": "stone_trough",      "name": "石凿槽",     "type": "混合", "ops": [],                   "owned": true,  "cost_sand": 0,   "cost_parts": {},     "desc": "基础混合槽位。" },
]

# 资源
var sand: int = 1000  # 砂粒 (原型阶段给足够)
var parts: Dictionary = { "precision": 10, "acid_resist": 5, "fireant_core": 0 }


func _ready() -> void:
	_sync_state()


func _sync_state() -> void:
	owned.clear()
	operations.clear()
	for d in devices:
		owned[d["id"]] = d["owned"]
		for op in d["ops"]:
			if op not in operations:
				operations[op] = []
			operations[op].append(d["id"])


# ── 购买 ──
func purchase(device_id: String) -> bool:
	for d in devices:
		if d["id"] == device_id:
			if d["owned"]:
				return false  # 已拥有
			if not _can_afford(d):
				return false
			_deduct(d)
			d["owned"] = true
			_sync_state()
			return true
	return false


func _can_afford(d: Dictionary) -> bool:
	if sand < d["cost_sand"]:
		return false
	for part_id in d["cost_parts"]:
		var needed = d["cost_parts"][part_id]
		if parts.get(part_id, 0) < needed:
			return false
	return true


func _deduct(d: Dictionary) -> void:
	sand -= d["cost_sand"]
	for part_id in d["cost_parts"]:
		parts[part_id] = parts.get(part_id, 0) - d["cost_parts"][part_id]


# ── 查询 ──
func get_owned_operations() -> Array[String]:
	var ops: Array[String] = []
	for d in devices:
		if d["owned"]:
			ops.append_array(d["ops"])
	return ops

func owns_operation(op: String) -> bool:
	return op in get_owned_operations()
