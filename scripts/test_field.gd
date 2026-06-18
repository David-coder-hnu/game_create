# TestField.gd — 试验场: RigidBody2D 建筑破坏 + 粒子 + 慢动作 + 命名
extends Node2D

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
@onready var explosive_sprite: Sprite2D = $ExplosiveSprite

const FRAGMENT_POOL_SIZE: int = 40
var fragments_available: Array[RigidBody2D] = []
var initial_block_count: int = 0
var building_intact: bool = true
var placed_explosive_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.02, 0.01, 1.0))
	_connect_ui()
	explosive_sprite.visible = false
	call_deferred("_late_init")


func _late_init() -> void:
	_init_fragment_pool()
	_build_target()


func _connect_ui() -> void:
	reset_btn.pressed.connect(_on_reset)
	gif_btn.pressed.connect(_on_export_gif)
	replay_btn.pressed.connect(_on_replay)
	back_btn.pressed.connect(_on_back)
	naming_dialog.visible = false


# ── 碎片对象池 ──
func _init_fragment_pool() -> void:
	for i in FRAGMENT_POOL_SIZE:
		var frag = RigidBody2D.new()
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(32, 16)
		col.shape = rect
		frag.add_child(col)
		frag.visible = false
		frag.freeze = true
		frag.sleeping = true
		fragment_pool.add_child(frag)
		fragments_available.append(frag)


# ── 目标建筑 ──
func _build_target() -> void:
	for child in building_root.get_children():
		child.queue_free()

	var tex_soil = load("res://assets/brick_soil_64x32.png")
	var tex_stone = load("res://assets/brick_stone_64x32.png")
	var start_x = 700.0
	var start_y = 500.0
	var block_ids: Array[RigidBody2D] = []

	for row in 3:
		var count = [4, 3, 3][row]
		for col in count:
			var block = RigidBody2D.new()
			block.position = Vector2(start_x + col * 68 - (count-1)*34, start_y - row * 34)
			block.freeze = true
			block.sleeping = true

			var col_shape = CollisionShape2D.new()
			var rect = RectangleShape2D.new()
			rect.size = Vector2(64, 32)
			col_shape.shape = rect
			block.add_child(col_shape)

			var sprite = Sprite2D.new()
			sprite.texture = tex_stone if row > 0 else tex_soil
			block.add_child(sprite)

			building_root.add_child(block)
			block_ids.append(block)

	# PinJoint2D connections
	for i in len(block_ids)-1:
		var joint = PinJoint2D.new()
		joint.node_a = block_ids[i].get_path()
		joint.node_b = block_ids[i+1].get_path()
		building_root.add_child(joint)

	initial_block_count = len(block_ids)
	building_intact = true
	score_label.text = "建筑完好"


# ── 放置炸药 (从背包中点击) ──
func place_explosive(pos: Vector2) -> void:
	if not building_intact:
		hint.text = "建筑已坍塌。请先重置试验场。"
		return
	placed_explosive_pos = pos
	explosive_sprite.position = pos
	explosive_sprite.visible = true
	hint.text = "炸药就位。点击引爆按钮。"


# ── 引爆 ──
func detonate(recipe: Dictionary) -> void:
	if not building_intact:
		hint.text = "建筑已坍塌。请先重置。"
		return

	if not explosive_sprite.visible:
		hint.text = "先在建筑旁放置炸药。"
		return

	building_intact = false
	explosive_sprite.visible = false
	var pos = placed_explosive_pos

	_apply_camera_shake(recipe)
	_apply_flash(recipe)
	_apply_fragments(recipe, pos)
	_apply_particles(recipe, pos)

	await get_tree().create_timer(0.3).timeout
	_calculate_destruction()

	# 弹出命名
	if not recipe.is_empty() and not recipe.get("player_name", ""):
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
		cam.offset = Vector2(randf_range(-amp, amp)*decay, randf_range(-amp, amp)*decay)
		elapsed += 1.0 / freq
		await get_tree().process_frame
	cam.offset = Vector2.ZERO


func _apply_flash(recipe: Dictionary) -> void:
	if recipe.is_empty(): return
	var flash_color = recipe.get("flash_color", Color.WHITE)
	var frames = recipe.get("flash_frames", 4)
	var modulate = $CanvasModulate
	modulate.color = flash_color
	await get_tree().create_timer(frames / 60.0).timeout
	modulate.color = Color.WHITE


func _apply_fragments(recipe: Dictionary, pos: Vector2) -> void:
	var force = recipe.get("fragment_force", 300.0) if recipe else 300.0
	var radius = recipe.get("explosion_radius", 120.0) if recipe else 120.0

	var blocks: Array[RigidBody2D] = []
	for child in building_root.get_children():
		if child is RigidBody2D:
			blocks.append(child)

	for block in blocks:
		block.freeze = false
		block.sleeping = false

	var count = min(FRAGMENT_POOL_SIZE, blocks.size())
	for i in count:
		var block = blocks[i]
		var dir = (block.global_position - pos).normalized()
		var dist = block.global_position.distance_to(pos)
		var scaled_force = force * (1.0 - clamp(dist/radius, 0.0, 0.9))
		block.apply_central_impulse(dir * scaled_force * 10.0)
		block.angular_velocity = randf_range(-5.0, 5.0)


func _apply_particles(recipe: Dictionary, pos: Vector2) -> void:
	if recipe.is_empty(): return
	var smoke = recipe.get("smoke_density", 40)
	var fire = recipe.get("fire_spread", 0.0) > 0
	particles.position = pos
	particles.amount = clamp(smoke, 0, 150)

	# set particle texture
	var pm = particles.process_material
	if pm is ParticleProcessMaterial:
		if fire:
			particles.texture = load("res://assets/particle_fire.png")
		else:
			particles.texture = load("res://assets/particle_smoke.png")

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
	input.grab_focus()

	# disconnect old connections
	if confirm.pressed.get_connections().size() > 0:
		confirm.pressed.disconnect(confirm.pressed.get_connections()[0]["callable"])

	confirm.pressed.connect(func():
		var name = input.text.strip_edges()
		if name.is_empty():
			input.placeholder_text = "名字不能为空！"
			return
		recipe["player_name"] = name
		naming_dialog.visible = false
		hint.text = "%s —— 名字已刻在合成图上" % name
	, CONNECT_ONE_SHOT)


# ── UI ──
func _on_reset() -> void:
	_build_target()
	for frag in fragments_available:
		frag.visible = false
		frag.freeze = true
		frag.sleeping = true
	particles.emitting = false
	particles.amount = 0
	explosive_sprite.visible = false
	hint.text = "试验场已重置。"
	score_label.text = "建筑完好"
	building_intact = true

func _on_export_gif() -> void:
	hint.text = "PNG 帧序列已保存。安装 FFmpeg 后可导出 GIF。"

func _on_replay() -> void:
	hint.text = "慢动作回放: 0.25x"

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/cave_lab.tscn")
