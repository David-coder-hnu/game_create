# CaveLab.gd — 洞穴实验室主脚本
extends Node2D

const AssetMap = preload("res://resources/asset_map.gd")

# ── UI 引用 ──
@onready var synth_graph: Control = $UI/SynthesisGraph
@onready var material_panel: Control = $UI/MaterialPanel
@onready var grind_slider: HSlider = $UI/GrindSlider
@onready var temp_slider: HSlider = $UI/TempSlider
@onready var grind_label: Label = $UI/GrindLabel
@onready var temp_label: Label = $UI/TempLabel
@onready var synthesize_btn: Button = $UI/SynthesizeBtn
@onready var test_field_btn: Button = $UI/TestFieldBtn
@onready var hub_btn: Button = $UI/HubBtn
@onready var hint_label: Label = $UI/HintLabel

# ── 精灵节点 ──
@onready var firefly: Sprite2D = $Firefly
@onready var workbench: Sprite2D = $Workbench

# ── 状态 ──
var selected_materials: Dictionary = {}
var grind_level: int = 1
var temperature: int = 0
var last_recipe: Dictionary = {}
var synth_cooldown: float = 0.0
var graph_nodes: Array = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.02, 0.01, 1.0))
	RecipeDB.recipe_discovered.connect(_on_recipe_discovered)
	grind_slider.value_changed.connect(_on_grind_changed)
	temp_slider.value_changed.connect(_on_temp_changed)
	synthesize_btn.pressed.connect(_on_synthesize)
	test_field_btn.pressed.connect(_on_test_field)
	hub_btn.pressed.connect(_on_back_to_hub)
	call_deferred("_late_init")


func _late_init() -> void:
	_build_synthesis_graph()
	_build_material_panel()
	_show_hint("黑火药配方已知。试试调整研磨度和温度，合成火药……")
	if not RecipeDB.is_discovered("brown_powder"):
		_show_hint("试试把黑火药磨得更细，温度提高一点？")


func _process(delta: float) -> void:
	if synth_cooldown > 0:
		synth_cooldown -= delta


# ── 合成图 (带精灵节点) ──
func _build_synthesis_graph() -> void:
	for node_info in graph_nodes:
		node_info["parent"].queue_free()
	graph_nodes.clear()

	var content = synth_graph.get_child(0) if synth_graph.get_child_count() > 0 else synth_graph
	var owned_ops = EquipmentStore.get_owned_operations()
	var y = 4

	for rec in RecipeDB.recipes:
		var sid = rec["id"]
		var discovered = RecipeDB.is_discovered(sid)
		var is_intermediate = rec["recipe_type"] == "intermediate"

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 22)

		# 节点图标
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 16)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

		if discovered:
			if is_intermediate:
				icon.texture = load("res://assets/external/runestone_water.png")
			else:
				icon.texture = load("res://assets/external/runestone_fire.png")
		else:
			var missing: Array[String] = []
			for op in rec["required_operations"]:
				if op not in owned_ops:
					missing.append(op)
			if missing.is_empty():
				icon.texture = load("res://assets/external/runestone_blank_1.png")
			else:
				icon.texture = load("res://assets/external/runestone_blank_1.png")
				icon.tooltip_text = rec.get("lock_text", "需要: %s" % ", ".join(missing))
		row.add_child(icon)

		# 节点名称
		var label = Label.new()
		label.custom_minimum_size = Vector2(220, 20)
		if discovered:
			if is_intermediate:
				label.text = "⚗ %s" % rec["player_name"]
				label.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26))
			else:
				var nm = rec.get("player_name", "")
				var prefix = "★ " if sid == "black_powder" else ""
				label.text = "%s%s" % [prefix, nm if nm else sid]
				label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42))
		else:
			label.text = "???"
			label.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
		row.add_child(label)

		content.add_child(row)
		graph_nodes.append({"parent": row, "recipe_id": sid})

		# 连线指示
		var parents = rec.get("parent_ids", [])
		if not parents.is_empty():
			var conn = Label.new()
			conn.text = "  ├─ " if len(parents) > 1 or rec != RecipeDB.recipes[-1] else "  └─ "
			conn.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
			content.add_child(conn)
			graph_nodes.append({"parent": conn, "recipe_id": ""})

		y += 26


func _refresh_synthesis_graph() -> void:
	_build_synthesis_graph()


# ── 原料面板 (带精灵图标) ──
func _build_material_panel() -> void:
	for child in material_panel.get_children():
		child.queue_free()
	var container = VBoxContainer.new()
	material_panel.add_child(container)

	var all_mats = InventoryManager.get_available_materials()
	for mat_id in all_mats:
		var mat = all_mats[mat_id]
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)

		# 精灵图标
		var tex_path = "res://assets/external/crystal_blue.png" % mat_id
		if ResourceLoader.exists(tex_path):
			var icon = TextureRect.new()
			icon.texture = load(tex_path)
			icon.custom_minimum_size = Vector2(32, 32)
			icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(icon)

		# 名字 + 选择按钮
		var btn = Button.new()
		btn.text = "%s" % mat["name"]
		var selected = mat_id in selected_materials
		btn.self_modulate = Color(1.0, 0.84, 0.42) if selected else Color(1, 1, 1)
		btn.custom_minimum_size = Vector2(140, 26)
		btn.pressed.connect(_on_material_toggle.bind(mat_id, btn))
		row.add_child(btn)

		container.add_child(row)

	# 中间体区
	var inters = InventoryManager.get_available_intermediates()
	for inter_id in inters:
		var rec = RecipeDB.get_recipe_by_id(inter_id)
		if rec.is_empty():
			continue
		var row = HBoxContainer.new()
		var tex_path = "res://assets/external/stoppered_bottle_empty.png" % inter_id
		if ResourceLoader.exists(tex_path):
			var icon = TextureRect.new()
			icon.texture = load(tex_path)
			icon.custom_minimum_size = Vector2(32, 32)
			icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			row.add_child(icon)

		var label = Label.new()
		label.text = "⚗ %s" % rec["player_name"]
		label.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26))
		row.add_child(label)
		container.add_child(row)


func _on_material_toggle(mat_id: String, btn: Button) -> void:
	if mat_id in selected_materials:
		selected_materials.erase(mat_id)
		btn.self_modulate = Color(1, 1, 1)
	else:
		selected_materials[mat_id] = 50.0
		btn.self_modulate = Color(1.0, 0.84, 0.42)
	_refresh_selected_display()


func _refresh_selected_display() -> void:
	var total: float = 0.0
	for v in selected_materials.values():
		total += v
	if total > 0:
		for mat_id in selected_materials:
			selected_materials[mat_id] = selected_materials[mat_id] / total * 100.0

	var parts: Array[String] = []
	for mat_id in selected_materials:
		parts.append("%s %.0f%%" % [mat_id, selected_materials[mat_id]])
	_show_hint("原料: %s | 研磨 Lv%d | 温度 %d°C" % [
		", ".join(parts) if parts else "未选择", grind_level, temperature
	])


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
	synth_cooldown = 0.5

	if selected_materials.is_empty():
		_show_hint("先选至少一种原料，放在工作台上。")
		return

	var owned_ops = EquipmentStore.get_owned_operations()
	var result = RecipeDB.match(selected_materials.duplicate(), grind_level, temperature)

	if result.is_empty():
		_show_failure_animation(selected_materials)
		return

	var missing: Array[String] = []
	for op in result["required_operations"]:
		if op not in owned_ops:
			missing.append(op)
	if not missing.is_empty():
		_show_hint(result.get("lock_text", "需要操作: %s" % ", ".join(missing)))
		return

	last_recipe = result
	if not result["discovered"]:
		var msg = result.get("hint_text", "坩埚里冒出奇怪的烟……你好像搞出了什么东西。")
		RecipeDB.discover(result["id"])
		_show_hint(msg)
	else:
		var nm = result.get("player_name", result["id"])
		_show_hint("合成了 %s (已发现)。 带去试验场测试？" % nm)


func _show_failure_animation(ingredients: Dictionary) -> void:
	var has_acid = "formic_acid" in ingredients
	var has_niter = "saltpeter" in ingredients
	var all_carbon = true
	for k in ingredients:
		if k not in ["charcoal", "clay", "rot_soil"]:
			all_carbon = false; break
	if all_carbon:
		_show_hint("全是碳……坩埚里剩下一团焦黑废渣。")
	elif has_acid:
		_show_hint("刺激性白烟从坩埚里涌出来——咳、咳。")
	else:
		_show_hint("坩埚里冒出一小团火球……然后什么都没了。")


func _on_recipe_discovered(recipe_id: String, recipe_type: String) -> void:
	_refresh_synthesis_graph()
	_build_material_panel()


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
