extends Node2D

@onready var firefly: Sprite2D = $Firefly
@onready var workbench: Sprite2D = $Workbench
@onready var crucible: Sprite2D = $Crucible
@onready var bench_mats: Node2D = $WorkbenchMaterials
@onready var vignette: ColorRect = $Vignette

@onready var synth_graph: VBoxContainer = $UI/SynthesisPanel/SynthesisGraph
@onready var material_scroll: ScrollContainer = $UI/ControlPanel/ControlContent/MaterialScroll
@onready var grind_slider: HSlider = $UI/ControlPanel/ControlContent/GrindSlider
@onready var temp_slider: HSlider = $UI/ControlPanel/ControlContent/TempSlider
@onready var grind_label: Label = $UI/ControlPanel/ControlContent/GrindLabel
@onready var temp_label: Label = $UI/ControlPanel/ControlContent/TempLabel
@onready var synthesize_btn: Button = $UI/ControlPanel/ControlContent/BtnRow/SynthesizeBtn
@onready var test_field_btn: Button = $UI/ControlPanel/ControlContent/BtnRow/TestFieldBtn
@onready var hub_btn: Button = $UI/HubBtn
@onready var hint_label: Label = $UI/HintLabel
@onready var selected_label: Label = $UI/ControlPanel/ControlContent/SelectedLabel

const AssetMap = preload("res://resources/asset_map.gd")

var selected_materials: Dictionary = {}
var grind_level: int = 1
var temperature: int = 0
var last_recipe: Dictionary = {}
var synth_cooldown: float = 0.0
var bench_sprites: Array = []
var firefly_time: float = 0.0
var is_synthesizing: bool = false
var synth_anim: float = 0.0
var synth_frame: int = 0
var _pending_recipe: Dictionary = {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.04, 0.02, 0.01, 1.0))
	RecipeDB.recipe_discovered.connect(_on_recipe_discovered)
	grind_slider.value_changed.connect(_on_grind)
	temp_slider.value_changed.connect(_on_temp)
	synthesize_btn.pressed.connect(_on_synthesize)
	test_field_btn.pressed.connect(_on_test_field)
	hub_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ant_nest_hub.tscn"))
	
	# Vignette shader
	var mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { float d = distance(UV, vec2(0.5)); COLOR = vec4(0.015, 0.008, 0.003, smoothstep(0.25, 0.9, d) * 0.5); }"
	mat.shader = sh
	vignette.material = mat
	
	call_deferred("_build_all")


func _build_all() -> void:
	_build_graph()
	_build_materials()
	_show("选择原料放入工作台……")


func _build_graph() -> void:
	for c in synth_graph.get_children(): c.queue_free()
	for rec in RecipeDB.recipes:
		var sid = rec["id"]
		var discovered = RecipeDB.is_discovered(sid)
		var inter = rec["recipe_type"] == "intermediate"
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 14)
		icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.texture = load("res://assets/ui_node_intermediate.png" if inter and discovered else "res://assets/ui_node_known_explosive.png" if discovered else "res://assets/ui_node_locked.png")
		row.add_child(icon)
		var lbl = Label.new()
		lbl.custom_minimum_size = Vector2(190, 16)
		if discovered:
			lbl.text = ("★ " if sid == "black_powder" else "") + rec.get("player_name", sid)
			lbl.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26) if inter else Color(0.96, 0.82, 0.42))
		else:
			lbl.text = "???"
			lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		row.add_child(lbl)
		synth_graph.add_child(row)
		if not rec.get("parent_ids", []).is_empty():
			var conn = Label.new()
			conn.text = "     |-"
			conn.add_theme_color_override("font_color", Color(0.25, 0.25, 0.25))
			conn.add_theme_font_size_override("font_size", 9)
			synth_graph.add_child(conn)


func _build_materials() -> void:
	for c in material_scroll.get_children(): c.queue_free()
	var box = VBoxContainer.new()
	material_scroll.add_child(box)
	var mats = InventoryManager.get_available_materials()
	var rare = ["fireant_venom", "lead_powder"]
	var show_rare = RecipeDB.discovered_ids.size() > 1
	for mid in mats:
		if mid in rare and not show_rare: continue
		var m = mats[mid]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var ip = AssetMap.get_material_icon(mid)
		if ResourceLoader.exists(ip):
			var ic = TextureRect.new()
			ic.texture = load(ip)
			ic.custom_minimum_size = Vector2(22, 22)
			ic.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			row.add_child(ic)
		var btn = Button.new()
		btn.text = m["name"]
		btn.custom_minimum_size = Vector2(100, 24)
		btn.pressed.connect(_toggle_mat.bind(mid, btn))
		_update_btn(btn, mid)
		row.add_child(btn)
		var qty = Label.new()
		qty.text = "inf"
		qty.custom_minimum_size = Vector2(28, 24)
		qty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		row.add_child(qty)
		box.add_child(row)
	for iid in InventoryManager.get_available_intermediates():
		var r = RecipeDB.get_recipe_by_id(iid)
		if r.is_empty(): continue
		var row = HBoxContainer.new()
		var ip = AssetMap.get_intermediate_icon(iid)
		if ResourceLoader.exists(ip):
			var ic = TextureRect.new()
			ic.texture = load(ip)
			ic.custom_minimum_size = Vector2(22, 22)
			ic.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			row.add_child(ic)
		var lbl = Label.new()
		lbl.text = "~ " + r["player_name"]
		lbl.add_theme_color_override("font_color", Color(0.49, 0.76, 0.26))
		row.add_child(lbl)
		box.add_child(row)


func _update_btn(btn: Button, mid: String) -> void:
	btn.self_modulate = Color(1.0, 0.84, 0.42) if mid in selected_materials else Color(1, 1, 1)


func _toggle_mat(mid: String, btn: Button) -> void:
	if mid in selected_materials: selected_materials.erase(mid)
	else: selected_materials[mid] = 50.0
	_update_btn(btn, mid)
	_update_bench()
	_update_status()


func _update_bench() -> void:
	for s in bench_sprites: s.queue_free()
	bench_sprites.clear()
	if selected_materials.is_empty(): return
	var cx = workbench.position.x; var cy = workbench.position.y - 20
	var n = selected_materials.size(); var r = min(80.0, 15.0 + n * 12.0); var i = 0
	for mid in selected_materials:
		var ip = AssetMap.get_material_icon(mid)
		if not ResourceLoader.exists(ip): continue
		var a = (float(i) / n) * TAU - TAU/4
		var s = Sprite2D.new()
		s.texture = load(ip)
		s.position = Vector2(cx + cos(a) * r, cy + sin(a) * r * 0.5)
		s.scale = Vector2(1.3, 1.3); s.z_index = 1
		bench_mats.add_child(s); bench_sprites.append(s); i += 1


func _update_status() -> void:
	if selected_materials.is_empty(): selected_label.text = "工作台上: (空)"; return
	var parts = []; for mid in selected_materials: parts.append(InventoryManager.get_available_materials().get(mid, {}).get("name", mid))
	var bars = ""; for k in range(1,6): bars += "■" if k <= grind_level else "□"
	selected_label.text = "工作台上: %s" % ", ".join(parts)
	grind_label.text = "研磨: Lv%d  [ %s ]" % [grind_level, bars]


func _on_grind(v: float) -> void: grind_level = int(clamp(v, 1, 5)); _update_status()
func _on_temp(v: float) -> void: temperature = int(clamp(v, 0, 100)); temp_label.text = "温度: %d C" % temperature


func _on_synthesize() -> void:
	if synth_cooldown > 0 or is_synthesizing: return
	synth_cooldown = 0.8
	if selected_materials.is_empty(): _show("工作台是空的。先选几种原料。"); return
	var result = RecipeDB.match(selected_materials.duplicate(), grind_level, temperature, EquipmentStore.get_owned_operations())
	if result.is_empty(): _fail(); return
	is_synthesizing = true; synth_anim = 0.0; _pending_recipe = result; synthesize_btn.disabled = true
	_show("坩埚里冒出了气泡……")


func _fail() -> void:
	var acid = "formic_acid" in selected_materials
	var carbon = true; for k in selected_materials: if k not in ["charcoal","clay","rot_soil"]: carbon = false
	_show("全是碳……焦黑废渣。" if carbon else ("刺激性白烟涌出！" if acid else "一团火球……什么都没了。"))
	crucible.texture = load("res://assets/crucible_bubble_5.png")
	await get_tree().create_timer(0.6).timeout; crucible.texture = load("res://assets/crucible_bubble_0.png")


func _process(delta: float) -> void:
	if synth_cooldown > 0: synth_cooldown -= delta
	firefly_time += delta * 2.0; var p = 0.7 + sin(firefly_time) * 0.2
	firefly.modulate = Color(1.0, 1.0, 0.82, p)
	if is_synthesizing:
		synth_anim += delta; var f = int(synth_anim * 8) % 8
		if f != synth_frame: synth_frame = f; crucible.texture = load("res://assets/crucible_bubble_%d.png" % f)
		if synth_anim > 2.2:
			is_synthesizing = false; synthesize_btn.disabled = false
			crucible.texture = load("res://assets/crucible_bubble_0.png"); _done()


func _done() -> void:
	var r = _pending_recipe; _pending_recipe = {}
	if r.is_empty(): return
	last_recipe = r
	if not r["discovered"]:
		RecipeDB.discover(r["id"]); _show(r.get("hint_text", "坩埚里冒出奇怪的烟……"))
		var tw = create_tween(); tw.tween_property(crucible, "modulate", Color(1.0,0.95,0.4,0.7), 0.15); tw.tween_property(crucible, "modulate", Color(1,1,1,1), 0.3)
	else:
		_show("合成了 %s！去试验场测试吧。" % r.get("player_name", r["id"]))


func _on_recipe_discovered(_id: String, _type: String) -> void: _build_graph(); _build_materials()
func _on_test_field() -> void: RecipeDB.pending_recipe = last_recipe; get_tree().change_scene_to_file("res://scenes/test_field.tscn")
func _show(txt: String) -> void: hint_label.text = txt
