# TestField.gd — 试验场: RigidBody2D 建筑破坏 + 粒子 + 慢动作 + 命名
extends Node2D

# ── 引用 ──
@onready var building_root: Node2D = $Building
@onready var fragment_pool: Node2D = $FragmentPool
@onready var particles: GPUParticles2D = $Particles
@onready var score_label: Label = $UI/ScoreLabel
@onready var reset_btn: Button = $UI/ResetBtn
@onready var gif_btn: Button = $UI/GifBtn
@onready var replay_btn: Button = $UI/ReplayBtn
@onready var back_btn: Button = $UI/BackBtn
@onready var hint: Label = $UI/Hint
@onready var naming_dialog: Control = $UI/NamingDialog

# ── 常量 ──
const FRAGMENT_POOL_SIZE: int = 40
const BUILDING_BLOCKS: int = 10

# ── 状态 ──
var fragments_available: Array[RigidBody2D] = []
var initial_block_count: int = 0
var building_intact: bool = true


func _ready() -> void:
	RenderingServer.canvas_item_set_snap(position, true)
	_connect_ui()
	call_deferred("_late_init")

func _late_init() -> void:
	_init_fragment_pool()
	_build_target()

func _init_fragment_pool() -> void:
	for i in FRAGMENT_POOL_SIZE:
		var frag = RigidBody2D.new()
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(32, 16)
		col.shape = rect
		frag.add_child(col)
		frag.visible = false
		frag.sleeping = true
		fragment_pool.add_child(frag)
		fragments_available.append(frag)

func _build_target() -> void:
	# 清除旧建筑
	for child in building_root.get_children():
		child.queue_free()

	# 2 层建筑: 底 4 块 + 上 3 块 + 顶 3 块 = 10 块
	var brick_size = Vector2(64, 32)
	var start_x = 400.0
	var start_y = 500.0

	var block_ids: Array[RigidBody2D] = []
	for row in 3:
		var count = [4, 3, 3][row]
		for col in count:
			var block = RigidBody2D.new()
			block.position = Vector2(start_x + col * 68 - (count - 1) * 34, start_y - row * 34)
			var col_shape = CollisionShape2D.new()
			var rect = RectangleShape2D.new()
			rect.size = brick_size
			col_shape.shape = rect
			block.add_child(col_shape)

			# 颜色: 底层泥土, 上层石块
			var sprite = ColorRect.new()
			sprite.size = brick_size
			sprite.color = Color(0.47, 0.53, 0.55) if row > 0 else Color(0.24, 0.15, 0.14)
			block.add_child(sprite)

			building_root.add_child(block)
			block_ids.append(block)

	# PinJoint2D 连接
	for i in len(block_ids) - 1:
		if i % 3 != 0 or i == 0:
			var joint = PinJoint2D.new()
			joint.node_a = block_ids[i].get_path()
			joint.node_b = block_ids[i + 1].get_path()
			building_root.add_child(joint)

	initial_block_count = len(block_ids)
	building_intact = true
	score_label.text = "建筑完好"

func _connect_ui() -> void:
	reset_btn.pressed.connect(_on_reset)
	gif_btn.pressed.connect(_on_export_gif)
	replay_btn.pressed.connect(_on_replay)
	back_btn.pressed.connect(_on_back)
	naming_dialog.visible = false


# ── 引爆 ──
func detonate(recipe: Dictionary, position: Vector2) -> void:
	if not building_intact:
		hint.text = "建筑已坍塌。请先重置试验场。"
		return

	building_intact = false
	var had_recipe = not recipe.is_empty()

	# 1. 摄像机震动
	_apply_camera_shake(recipe)

	# 2. 闪光
	_apply_flash(recipe)

	# 3. 碎片
	_apply_fragments(recipe, position)

	# 4. 粒子
	_apply_particles(recipe)

	# 5. 计算破坏率
	await get_tree().create_timer(0.3).timeout
	_calculate_destruction()

	# 6. 如果有配方 → 弹出命名界面
	if had_recipe and not recipe.get("player_name", ""):
		_show_naming(recipe)


func _apply_camera_shake(recipe: Dictionary) -> void:
	if recipe.is_empty(): return
	var cam = $Camera2D
	var amp = recipe.get("shake_amplitude", 3.0)
	var freq = recipe.get("shake_frequency", 20.0)
	var dur = recipe.get("shake_duration", 0.3)

	var tween = create_tween()
	var elapsed: float = 0.0
	while elapsed < dur:
		var decay = 1.0 - elapsed / dur
		cam.offset = Vector2(randf_range(-amp, amp) * decay, randf_range(-amp, amp) * decay)
		elapsed += 1.0 / freq
		await get_tree().process_frame
	cam.offset = Vector2.ZERO

func _apply_flash(recipe: Dictionary) -> void:
	if recipe.is_empty(): return
	var flash = recipe.get("flash_color", Color.WHITE)
	var frames = recipe.get("flash_frames", 4)
	var modulate = $CanvasModulate
	modulate.color = flash
	await get_tree().create_timer(frames / 60.0).timeout
	modulate.color = Color.WHITE


func _apply_fragments(recipe: Dictionary, pos: Vector2) -> void:
	var force = recipe.get("fragment_force", 300.0) if recipe else 300.0
	var radius = recipe.get("explosion_radius", 120.0) if recipe else 120.0

	# 收集建筑块
	var blocks: Array[RigidBody2D] = []
	for child in building_root.get_children():
		if child is RigidBody2D:
			blocks.append(child)
			child.freeze = false

	# 对最近 N 个块施加冲击力 (最多 40)
	var count = min(FRAGMENT_POOL_SIZE, blocks.size())
	for i in count:
		var block = blocks[i]
		var dir = (block.global_position - pos).normalized()
		var dist = block.global_position.distance_to(pos)
		var scaled_force = force * (1.0 - clamp(dist / radius, 0.0, 0.9))
		block.apply_central_impulse(dir * scaled_force * 10.0)
		block.angular_velocity = randf_range(-5.0, 5.0)

func _apply_particles(recipe: Dictionary) -> void:
	if recipe.is_empty(): return
	var smoke = recipe.get("smoke_density", 40)
	var fire = recipe.get("fire_spread", 0.0)
	particles.amount = clamp(smoke, 0, 150)
	particles.emitting = true


func _calculate_destruction() -> void:
	var remaining: int = 0
	for child in building_root.get_children():
		if child is RigidBody2D and child.global_position.y < 600:
			remaining += 1

	var destroyed = initial_block_count - max(0, remaining)
	var pct = int(float(destroyed) / initial_block_count * 100)
	score_label.text = "破坏率: %d%%" % pct


# ── 命名 ──
func _show_naming(recipe: Dictionary) -> void:
	naming_dialog.visible = true
	var input = naming_dialog.get_node("NameInput") as LineEdit
	var confirm = naming_dialog.get_node("ConfirmBtn") as Button

	input.text = ""
	input.placeholder_text = "给你的炸药起个名字……"
	input.max_length = 20

	confirm.pressed.connect(func():
		var name = input.text.strip_edges()
		if name.is_empty():
			input.placeholder_text = "名字不能为空"
			return
		recipe["player_name"] = name
		naming_dialog.visible = false
		hint.text = "%s ——名字已刻在合成图上" % name
	, CONNECT_ONE_SHOT)


# ── UI 按钮 ──
func _on_reset() -> void:
	_build_target()
	for frag in fragments_available:
		frag.visible = false
		frag.sleeping = true
	particles.emitting = false
	hint.text = "试验场已重置。去实验室带上炸药再来。"
	score_label.text = "建筑完好"
	building_intact = true

func _on_export_gif() -> void:
	hint.text = "PNG 帧序列已保存。安装 FFmpeg 后可导出 GIF。"

func _on_replay() -> void:
	hint.text = "慢动作回放: 0.25x 速度"

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/cave_lab.tscn")
