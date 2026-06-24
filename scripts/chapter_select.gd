# ChapterSelect.gd — 三章关卡选择
extends Node2D

func _ready():
	var back_btn = $UI/BackBtn as Button
	if back_btn:
		back_btn.pressed.connect(func(): SceneTransition.fade_to("res://scenes/ant_nest_hub.tscn"))
