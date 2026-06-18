# ChapterSelect.gd — 三章关卡选择
extends Node2D

func _ready():
	RenderingServer.canvas_item_set_snap(position, true)
	var back_btn = $UI/BackBtn as Button
	if back_btn:
		back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ant_nest_hub.tscn"))
