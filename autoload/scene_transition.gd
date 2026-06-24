# SceneTransition.gd — 全局场景过渡动画
extends Node

var overlay: ColorRect
var tween: Tween

func _ready() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(overlay)


func fade_to(scene_path: String, duration: float = 0.25) -> void:
	if tween and tween.is_running(): tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 1), duration)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	fade_in(duration)


func fade_in(duration: float = 0.25) -> void:
	if tween and tween.is_running(): tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), duration)


# Apply pixel-art button style to a Button node
static func style_button(btn: Button) -> void:
	var normal = StyleBoxTexture.new()
	normal.texture = load("res://assets/ui_btn_default.png")
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover = StyleBoxTexture.new()
	hover.texture = load("res://assets/ui_btn_hover.png")
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 4
	hover.content_margin_bottom = 4
	var pressed = StyleBoxTexture.new()
	pressed.texture = load("res://assets/ui_btn_pressed.png")
	pressed.content_margin_left = 10
	pressed.content_margin_right = 10
	pressed.content_margin_top = 4
	pressed.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

static func style_all_buttons(root: Node) -> void:
	for child in root.get_children():
		if child is Button:
			style_button(child)
		style_all_buttons(child)
