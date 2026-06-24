# EquipmentStore UI — 设备商店场景 (不是 Autoload!)
extends Node2D

@onready var device_list: ScrollContainer = $UI/DeviceList
@onready var status_label: Label = $UI/StatusLabel

func _ready():
	SceneTransition.style_all_buttons($UI)
	var back_btn = $UI/BackBtn as Button
	back_btn.pressed.connect(func(): SceneTransition.fade_to("res://scenes/ant_nest_hub.tscn"))
	call_deferred("_build_device_list")

func _build_device_list():
	var container = VBoxContainer.new()
	device_list.add_child(container)

	for dev in EquipmentStore.devices:
		var row = HBoxContainer.new()
		var owned = dev["owned"]
		var label = Label.new()
		var cost_str = ""
		if dev["cost_sand"] > 0:
			cost_str += " %d砂粒" % dev["cost_sand"]
		for pid in dev["cost_parts"]:
			cost_str += " +%d %s" % [dev["cost_parts"][pid], pid]

		label.text = "%s %s [%s]%s" % [
			"✓" if owned else "○",
			dev["name"],
			dev["type"],
			cost_str
		]
		row.add_child(label)

		if not owned:
			var buy_btn = Button.new()
			buy_btn.text = "购买"
			buy_btn.pressed.connect(_on_buy.bind(dev["id"]))
			row.add_child(buy_btn)

		container.add_child(row)

	_refresh_status()

func _on_buy(device_id: String):
	var ok = EquipmentStore.purchase(device_id)
	if ok:
		for child in device_list.get_children():
			child.queue_free()
		_build_device_list()
	else:
		status_label.text = "资源不足！当前砂粒: %d" % EquipmentStore.sand

func _refresh_status():
	status_label.text = "设备商店 — 砂粒: %d | 精密零件: %d | 耐酸零件: %d" % [
		EquipmentStore.sand,
		EquipmentStore.parts.get("precision", 0),
		EquipmentStore.parts.get("acid_resist", 0)
	]
