extends Control
## 技能树面板（P3）：按 K 打开，显示当前职业 / 技能点 / 3 个技能
## 有技能点时可点击"升级"，每级消耗 1 点，等级上限 3


func _ready() -> void:
	$Panel/VBox/CloseButton.pressed.connect(close)
	PlayerClass.changed.connect(_refresh)
	_refresh()


func open() -> void:
	visible = true
	_refresh()


func close() -> void:
	visible = false


func _refresh() -> void:
	var def := PlayerClass.get_class_def()
	$Panel/VBox/ClassLabel.text = "职业：%s　　技能点：%d" % [def.get("name", "未选择"), PlayerClass.skill_points]
	var list := $Panel/VBox/Scroll/List
	for child in list.get_children():
		child.queue_free()
	if PlayerClass.class_id == "":
		var empty := Label.new()
		empty.text = "尚未选择职业（主菜单 → 开始游戏时选择）"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
		return
	for s in PlayerClass.skill_list():
		var lvl := PlayerClass.skill_level(s["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = "%s　Lv%d / %d" % [s["name"], lvl, s["max"]]
		name_label.add_theme_font_size_override("font_size", 17)
		var desc_label := Label.new()
		desc_label.text = str(s["desc"])
		desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.8))
		desc_label.add_theme_font_size_override("font_size", 13)
		info.add_child(name_label)
		info.add_child(desc_label)
		var btn := Button.new()
		btn.text = "升级（1 技能点）"
		btn.disabled = not PlayerClass.can_upgrade(s["id"])
		btn.pressed.connect(func() -> void:
			PlayerClass.upgrade(s["id"])
			AudioManager.play_sfx("ui_click")
		)
		row.add_child(info)
		row.add_child(btn)
		list.add_child(row)
