# AntNestHub.gd — 蚁巢 Hub: 洞穴实验室 + 试验场 + 章节选择的主入口
extends Node2D

@onready var cave_lab_button: Button = $UI/CaveLabBtn
@onready var test_field_button: Button = $UI/TestFieldBtn
@onready var chapter_select_button: Button = $UI/ChapterSelectBtn
@onready var equipment_store_button: Button = $UI/EquipmentStoreBtn

func _ready() -> void:
	SceneTransition.style_all_buttons($UI)
	cave_lab_button.pressed.connect(_on_cave_lab)
	test_field_button.pressed.connect(_on_test_field)
	chapter_select_button.pressed.connect(_on_chapter_select)
	equipment_store_button.pressed.connect(_on_equipment_store)

func _on_cave_lab() -> void:
	SceneTransition.fade_to("res://scenes/cave_lab.tscn")

func _on_test_field() -> void:
	get_tree().change_scene_to_file("res://scenes/test_field.tscn")

func _on_chapter_select() -> void:
	get_tree().change_scene_to_file("res://scenes/chapter_select.tscn")

func _on_equipment_store() -> void:
	get_tree().change_scene_to_file("res://scenes/equipment_store.tscn")
