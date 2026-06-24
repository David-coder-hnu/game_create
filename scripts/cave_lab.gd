# CaveLab.gd — 洞穴实验室 (重构版)
# 按 DESIGN.md §5.1 实现: 洞穴壁背景 + 工作台 + 坩埚 + 原料散落 + 合成图 + 萤火虫光
extends Node2D

const AssetMap = preload("res://resources/asset_map.gd")
const TILE_SIZE = 32
const VIEW_W = 1920
const VIEW_H = 1080

# ── 场景节点 ──
@onready var cave_walls: Node2D = $CaveWalls
@onready var vignette: ColorRect = $Vignette
@onready var workbench: Sprite2D = $Workbench
@onready var crucible: Sprite2D = $Crucible
@onready var bench_mats: Node2D = $WorkbenchMaterials
@onready var firefly: Sprite2D = $Firefly

# ── UI 节点 ──
@onready var synth_panel: PanelContainer = $UI/SynthesisPanel
@onready var synth_graph: VBoxContainer = $UI/SynthesisPanel/SynthesisGraph
@onready var material_panel: ScrollContainer = $UI/MaterialPanel
@onready var grind_slider: HSlider = $UI/GrindSlider
@onready var temp_slider: HSlider = $UI/TempSlider
@onready var grind_label: Label = $UI/GrindLabel
@onready var temp_label: Label = $UI/TempLabel
@onready var synthesize_btn: Button = $UI/SynthesizeBtn
@onready var test_field_btn: Button = $UI/TestFieldBtn
@onready var hub_btn: Button = $UI/HubBtn
@onready var hint_label: Label = $UI/HintLabel
@onready var selected_label: Label = $UI/SelectedLabel

# ── 状态 ──
var selected_materials: Dictionary = {}
var grind_level: int = 1
var temperature: int = 0
var last_recipe: Dictionary = {}
var synth_cooldown: float = 0.0
var graph_nodes: Array = []
var bench_sprite_nodes: Array = []
var firefly_pulse: float = 0.0
var is_synthesizing: bool = false
var synth_anim_timer: float = 0.0
var synth_bubble_frame: int = 0


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
	_build_cave_walls()
	_build_vignette()
	_build_synthesis_graph()
	_build_material_panel()
	_show_hint("欢迎回到洞穴实验室。选几种原料放到工作台上，试试合成……")

# ── 洞穴壁 (铺设 cave_wall_tile.png) ──
func _build_cave_walls() -> void:
	for child in cave_walls.get_children():
		child.queue_free()
	var tex = load("res://assets/cave_wall_tile.png")
	for row in range(ceil(VIEW_H / TILE_SIZE) + 1):
		for col in range(ceil(VIEW_W / TILE_SIZE) + 1):
			var tile = Sprite2D.new()
			tile.texture = tex
			tile.position = Vector2(col * TILE_SIZE, row * TILE_SIZE)
			tile.centered = false
			cave_walls.add_child(tile)

# ── 暗角 (四角渐暗 → 画面中心亮) ──
func _build_vignette() -> void:
	# 用 script 每帧绘制暗角 radial gradient
	vignette.material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);
	float vignette = smoothstep(0.3, 0.95, dist) * 0.45;
	COLOR = vec4(0.02, 0.01, 0.005, vignette);
}
"""
	vignette.material.shader = shader

# ── 合成图面板 ──
func _build_synthesis_graph() -> void:
	for node_info in graph_nodes:
		node_info["parent"].queue_free()
	graph_nodes.clear()

	for child in synth_graph.get_children():
		child.queue_free()

	var owned_ops = EquipmentStore.get_owned_operations()

	for rec in RecipeDB.recipes:
		var sid = rec["id"]
		var discovered = RecipeDB.is_discovered(sid)
		var is_intermediate = rec["recipe_type"] == "intermediate"

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# 图标
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 16)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

		if discovered:
			icon.texture = load("res://assets/ui_node_intermediate.png" if is_intermediate else "res://assets/ui_node_known_explosive.png")
		else:
			icon.texture = load("res://assets/ui_node_locked.png")
			var missing := []
			for op in rec["required_operations"]:
				if op not in owned_ops:
					missing.append(op)
			if not missing.is_empty():
				icon.tooltip_text = "需要: %s" % ", ".join(missing)
		row.add_child(icon)

		# 名字
		var label = Label.new()
		label.custom_minimum_size = Vector2(210, 18)
		if discovered:
			var prefix = "★ " if sid == "black_powder" else ""
			var nm = rec.get("player_name", sid)
			label.text = "%s%s" % [prefix, nm]
			label.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26) if is_intermediate else Color(0.96, 0.82, 0.42))
		else:
			label.text = "???"
			label.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
		row.add_child(label)
		synth_graph.add_child(row)
		graph_nodes.append({"parent": row, "recipe_id": sid})

		# 连线指示
		var parents = rec.get("parent_ids", [])
		if not parents.is_empty():
			var conn = Label.new()
			conn.text = "     ├─ "
			conn.add_theme_color_override("font_color", Color(0.33, 0.33, 0.33))
			conn.add_theme_font_size_override("font_size", 10)
			synth_graph.add_child(conn)
			graph_nodes.append({"parent": conn, "recipe_id": ""})


func _refresh_synthesis_graph() -> void:
	_build_synthesis_graph()

# ── 原料面板 ──
func _build_material_panel() -> void:
	for child in material_panel.get_children():
		child.queue_free()
	var container = VBoxContainer.new()
	material_panel.add_child(container)

	var all_mats = InventoryManager.get_available_materials()
	# 初始只显示基础原料，稀有原料需要解锁
	var rare_mats = ["fireant_venom", "lead_powder"]
	# Show rare materials once any explosive (beyond black powder) is discovered
	var discovered_any_rare = RecipeDB.discovered_ids.size() > 1

	for mat_id in all_mats:
		# 稀有原料初始隐藏
		if mat_id in rare_mats and not discovered_any_rare:
			continue

		var mat = all_mats[mat_id]
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 30)
		row.add_theme_constant_override("separation", 6)

		# 精灵图标
		var tex_path = AssetMap.get_material_icon(mat_id)
		if ResourceLoader.exists(tex_path):
			var icon = TextureRect.new()
			icon.texture = load(tex_path)
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(icon)

		# 名字按钮
		var btn = Button.new()
		btn.text = mat["name"]
		btn.custom_minimum_size = Vector2(120, 26)
		btn.pressed.connect(_on_material_toggle.bind(mat_id, btn))
		_update_mat_button(btn, mat_id)
		row.add_child(btn)

		# 数量显示
		var qty_label = Label.new()
		qty_label.text = "∞" if mat_id not in rare_mats else "×0"
		qty_label.custom_minimum_size = Vector2(32, 26)
		qty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		row.add_child(qty_label)

		container.add_child(row)

	# 中间体
	var inters = InventoryManager.get_available_intermediates()
	for inter_id in inters:
		var rec = RecipeDB.get_recipe_by_id(inter_id)
		if rec.is_empty():
			continue
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		var tex_path = AssetMap.get_intermediate_icon(inter_id)
		if ResourceLoader.exists(tex_path):
			var icon = TextureRect.new()
			icon.texture = load(tex_path)
			icon.custom_minimum_size = Vector2(28, 28)
			icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			row.add_child(icon)
		var label = Label.new()
		label.text = "⚗ %s" % rec["player_name"]
		label.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26))
		row.add_child(label)
		container.add_child(row)


func _update_mat_button(btn: Button, mat_id: String) -> void:
	if mat_id in selected_materials:
		btn.self_modulate = Color(1.0, 0.84, 0.42)
	else:
		btn.self_modulate = Color(1, 1, 1)


func _on_material_toggle(mat_id: String, btn: Button) -> void:
	if mat_id in selected_materials:
		selected_materials.erase(mat_id)
	else:
		selected_materials[mat_id] = 50.0  # 默认 50% 比例
	_update_mat_button(btn, mat_id)
	_update_bench_sprites()
	_refresh_selected_display()


# ── 工作台上散落的原料精灵 ──
func _update_bench_sprites() -> void:
	for s in bench_sprite_nodes:
		s.queue_free()
	bench_sprite_nodes.clear()

	var count = selected_materials.size()
	if count == 0:
		return

	var idx = 0
	# 原料围绕工作台中心排列
	var cx = workbench.position.x
	var cy = workbench.position.y - 15  # 放在工作台上半部分
	var radius = min(60.0, 20.0 + count * 8.0)

	for mat_id in selected_materials:
		var tex_path = AssetMap.get_material_icon(mat_id)
		if not ResourceLoader.exists(tex_path):
			continue
		var angle = (float(idx) / count) * TAU - TAU / 4
		var sx = cx + cos(angle) * radius
		var sy = cy + sin(angle) * radius * 0.6
		var sprite = Sprite2D.new()
		sprite.texture = load(tex_path)
		sprite.position = Vector2(sx, sy)
		sprite.scale = Vector2(1.2, 1.2)
		sprite.z_index = 1
		bench_mats.add_child(sprite)
		bench_sprite_nodes.append(sprite)
		idx += 1


func _refresh_selected_display() -> void:
	if selected_materials.is_empty():
		selected_label.text = "工作台上: (空)"
		return
	var parts: Array[String] = []
	for mat_id in selected_materials:
		var mat = InventoryManager.get_available_materials().get(mat_id, {})
		var name = mat.get("name", mat_id)
		parts.append("%s" % name)
	selected_label.text = "工作台上: %s | 研磨 Lv%d | %d°C" % [", ".join(parts), grind_level, temperature]


# ── 滑块 ──
func _on_grind_changed(value: float) -> void:
	grind_level = int(clamp(value, 1, 5))
	var bars = ""
	for i in range(1, 6):
		bars += "■" if i <= grind_level else "□"
	grind_label.text = "研磨: Lv%d [粗粒 %s 极细]" % [grind_level, bars]
	_refresh_selected_display()

func _on_temp_changed(value: float) -> void:
	temperature = int(clamp(value, 0, 100))
	temp_label.text = "温度: %d°C" % temperature
	_refresh_selected_display()


# ── 合成逻辑 ──
func _on_synthesize() -> void:
	if synth_cooldown > 0 or is_synthesizing:
		return
	synth_cooldown = 0.8

	if selected_materials.is_empty():
		_show_hint("工作台还是空的。先在右边选几种原料放上来。")
		return

	var owned_ops = EquipmentStore.get_owned_operations()
	var result = RecipeDB.match(selected_materials.duplicate(), grind_level, temperature, owned_ops)

	if result.is_empty():
		_show_failure_animation()
		return

	# 开始合成动画
	_start_synth_animation(result)


func _start_synth_animation(recipe: Dictionary) -> void:
	is_synthesizing = true
	synth_anim_timer = 0.0
	synth_bubble_frame = 0
	synthesize_btn.disabled = true
	_pending_recipe = recipe
	_show_hint("坩埚里开始冒泡……")


func _process(delta: float) -> void:
	if synth_cooldown > 0:
		synth_cooldown -= delta
	
	# 萤火虫脉动
	firefly_pulse += delta * 2.5
	var pulse = 0.85 + sin(firefly_pulse) * 0.15
	firefly.modulate = Color(1.0, 1.0, 0.85, 0.7 + pulse * 0.2)

	# 合成动画
	if is_synthesizing:
		synth_anim_timer += delta
		var frame = int(synth_anim_timer * 6) % 8
		if frame != synth_bubble_frame:
			synth_bubble_frame = frame
			var tex_path = "res://assets/crucible_bubble_%d.png" % frame
			if ResourceLoader.exists(tex_path):
				crucible.texture = load(tex_path)

		if synth_anim_timer > 2.0:
			# 动画结束
			is_synthesizing = false
			synthesize_btn.disabled = false
			crucible.texture = load("res://assets/crucible_bubble_0.png")
			_complete_synthesis()


var _pending_recipe: Dictionary = {}

func _complete_synthesis() -> void:
	var result = _pending_recipe
	if result.is_empty():
		return
	
	last_recipe = result
	if not result["discovered"]:
		var msg = result.get("hint_text", "坩埚里冒出奇怪的烟……你好像搞出了什么东西。")
		RecipeDB.discover(result["id"])
		_show_hint(msg)
		# 闪烁效果
		_flash_crucible_success()
	else:
		var nm = result.get("player_name", result["id"])
		_show_hint("合成了 %s！带去试验场测试？" % nm)

	_pending_recipe = {}


func _flash_crucible_success() -> void:
	var tween = create_tween()
	tween.tween_property(crucible, "modulate", Color(1.0, 0.96, 0.42, 0.8), 0.15)
	tween.tween_property(crucible, "modulate", Color(1, 1, 1, 1), 0.3)


func _show_failure_animation() -> void:
	var has_acid = "formic_acid" in selected_materials
	var all_carbon = true
	for k in selected_materials:
		if k not in ["charcoal", "clay", "rot_soil"]:
			all_carbon = false; break
	if all_carbon:
		_show_hint("全是碳……坩埚里剩下一团焦黑废渣。")
	elif has_acid:
		_show_hint("刺激性白烟从坩埚里涌出来——咳、咳。")
	else:
		_show_hint("坩埚里冒出一小团火球……然后什么都没了。")
	
	# 冒烟效果
	crucible.texture = load("res://assets/crucible_bubble_5.png")
	await get_tree().create_timer(0.8).timeout
	crucible.texture = load("res://assets/crucible_bubble_0.png")


func _on_recipe_discovered(recipe_id: String, recipe_type: String) -> void:
	_refresh_synthesis_graph()
	_build_material_panel()


# ── 导航 ──
func _on_test_field() -> void:
	RecipeDB.pending_recipe = last_recipe
	get_tree().change_scene_to_file("res://scenes/test_field.tscn")

func _on_back_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/ant_nest_hub.tscn")

func _show_hint(text: String) -> void:
	hint_label.text = text
