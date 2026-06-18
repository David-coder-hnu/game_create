# CaveLab.gd — 洞穴实验室主脚本
extends Node2D

# ── UI 引用 ──
@onready var synth_graph: Control = $UI/SynthesisGraph
@onready var material_panel: Control = $UI/MaterialPanel
@onready var grind_slider: HSlider = $UI/Workbench/GrindSlider
@onready var temp_slider: HSlider = $UI/Workbench/TempSlider
@onready var grind_label: Label = $UI/Workbench/GrindLabel
@onready var temp_label: Label = $UI/Workbench/TempLabel
@onready var synthesize_btn: Button = $UI/Workbench/SynthesizeBtn
@onready var test_field_btn: Button = $UI/Workbench/TestFieldBtn
@onready var hub_btn: Button = $UI/HubBtn
@onready var hint_label: Label = $UI/HintLabel

# ── 状态 ──
var selected_materials: Dictionary = {}  # {mat_id: ratio}
var grind_level: int = 1
var temperature: int = 0
var last_recipe: Dictionary = {}
var synth_cooldown: float = 0.0


func _ready() -> void:
	# 像素网格对齐
	RenderingServer.canvas_item_set_snap(position, true)

	# 连接信号
	RecipeDB.recipe_discovered.connect(_on_recipe_discovered)
	grind_slider.value_changed.connect(_on_grind_changed)
	temp_slider.value_changed.connect(_on_temp_changed)
	synthesize_btn.pressed.connect(_on_synthesize)
	test_field_btn.pressed.connect(_on_test_field)
	hub_btn.pressed.connect(_on_back_to_hub)

	# 初始状态
	_build_material_panel()
	_refresh_synthesis_graph()
	_show_hint("黑火药配方已知。试试调整研磨度和温度，合成火药……")

	# 首次游玩：环境引导
	if not RecipeDB.is_discovered("brown_powder"):
		_show_hint("试试把黑火药磨得更细，温度提高一点？")


func _process(delta: float) -> void:
	if synth_cooldown > 0:
		synth_cooldown -= delta


# ── 原料面板 ──
func _build_material_panel() -> void:
	material_panel.clear()
	var all_mats = InventoryManager.get_available_materials()
	for mat_id in all_mats:
		var mat = all_mats[mat_id]
		var btn = Button.new()
		btn.text = "%s [%s]" % [mat["name"], mat_id]
		btn.custom_minimum_size = Vector2(160, 28)
		btn.pressed.connect(_on_material_selected.bind(mat_id))
		material_panel.add_child(btn)

	# 中间体
	var inters = InventoryManager.get_available_intermediates()
	for inter_id in inters:
		var rec = RecipeDB.get_recipe_by_id(inter_id)
		if rec.is_empty():
			continue
		var btn = Button.new()
		btn.text = "⚗ %s" % rec["player_name"]
		btn.custom_minimum_size = Vector2(160, 28)
		btn.pressed.connect(_on_material_selected.bind(inter_id))
		material_panel.add_child(btn)


# ── 原料选择 ──
func _on_material_selected(mat_id: String) -> void:
	if mat_id in selected_materials:
		selected_materials.erase(mat_id)
	else:
		# 默认 50% 比例
		selected_materials[mat_id] = 50.0
	_refresh_selected_display()


func _refresh_selected_display() -> void:
	# 归一化选择的比例
	var total: float = 0.0
	for v in selected_materials.values():
		total += v
	if total > 0:
		for mat_id in selected_materials:
			selected_materials[mat_id] = selected_materials[mat_id] / total * 100.0

	var display: Array[String] = []
	for mat_id in selected_materials:
		display.append("%s %.0f%%" % [mat_id, selected_materials[mat_id]])
	# 更新 hint 区域
	_show_hint("原料: %s | 研磨: Lv%d | 温度: %d°C" % [", ".join(display) if display else "未选择", grind_level, temperature])


# ── 滑块 ──
func _on_grind_changed(value: float) -> void:
	grind_level = int(clamp(value, 1, 5))
	grind_label.text = "研磨: Lv%d [粗粒 ■□□□□ 极细]" % grind_level
	_refresh_selected_display()

func _on_temp_changed(value: float) -> void:
	temperature = int(value)
	temp_label.text = "温度: %d°C" % temperature
	_refresh_selected_display()


# ── 合成 ──
func _on_synthesize() -> void:
	if synth_cooldown > 0:
		return
	synth_cooldown = 0.5  # 防抖

	if selected_materials.is_empty():
		_show_hint("先选至少一种原料，放在工作台上。")
		return

	var owned_ops = EquipmentStore.get_owned_operations()
	var result = RecipeDB.match(selected_materials.duplicate(), grind_level, temperature)

	if result.is_empty():
		_show_failure_animation(selected_materials)
		_show_hint("坩埚里什么都没留下。换个组合试试？")
		return

	# 检查设备锁
	var missing: Array[String] = []
	for op in result["required_operations"]:
		if op not in owned_ops:
			missing.append(op)
	if not missing.is_empty():
		var lock_text = result.get("lock_text", "需要操作: %s" % ", ".join(missing))
		_show_hint(lock_text)
		return

	last_recipe = result

	if not result["discovered"]:
		# 首次发现
		var old_name = result.get("player_name", "")
		RecipeDB.discover(result["id"])
		_show_hint(result["hint_text"])
	else:
		_show_hint("合成了 %s (已发现)。带去试验场测试？" % result.get("player_name", result["id"]))


func _show_failure_animation(ingredients: Dictionary) -> void:
	# 失败效果：全部碳→焦渣 / 含蚁酸→白烟 / 硝石多→小火球
	var has_acid = "formic_acid" in ingredients
	var has_niter = "saltpeter" in ingredients
	var all_carbon = ingredients.keys().all(func(k): return k in ["charcoal", "clay", "rot_soil"])

	if all_carbon:
		_show_hint("全是碳……坩埚里剩下一团焦黑废渣。")
	elif has_acid:
		_show_hint("刺激性白烟从坩埚里涌出来——咳、咳。")
	else:
		_show_hint("坩埚里冒出一小团火球……然后什么都没了。")


# ── 发现回调 ──
func _on_recipe_discovered(recipe_id: String, recipe_type: String) -> void:
	_refresh_synthesis_graph()
	_build_material_panel()


# ── 合成图 ──
func _refresh_synthesis_graph() -> void:
	synth_graph.clear()
	var all_recipes = RecipeDB.recipes
	var owned_ops = EquipmentStore.get_owned_operations()

	for rec in all_recipes:
		var label = Label.new()
		var sid = rec["id"]
		var discovered = RecipeDB.is_discovered(sid)

		if discovered:
			if rec["recipe_type"] == "intermediate":
				label.text = "⚗ %s" % rec["player_name"]
				label.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26))
			else:
				var name = rec.get("player_name", sid)
				label.text = "%s %s" % (["★", ""][int(sid != "black_powder")], name if name else sid)
				label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42))
		else:
			var missing: Array[String] = []
			for op in rec["required_operations"]:
				if op not in owned_ops:
					missing.append(op)
			if missing.is_empty():
				label.text = "???"
				label.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
			else:
				label.text = "🔒 ???"
				label.tooltip_text = rec.get("lock_text", "需要: %s" % ", ".join(missing))
				label.add_theme_color_override("font_color", Color(0.27, 0.27, 0.27))

		label.position = Vector2(20 + (rec.get("grind_level", 1) - 1) * 140, 20 + all_recipes.find(rec) * 24)
		synth_graph.add_child(label)


# ── 导航 ──
func _on_test_field() -> void:
	if last_recipe.is_empty():
		_show_hint("先去合成点什么，再去试验场。")
		return
	get_tree().change_scene_to_file("res://scenes/test_field.tscn")

func _on_back_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/ant_nest_hub.tscn")

func _show_hint(text: String) -> void:
	hint_label.text = text
