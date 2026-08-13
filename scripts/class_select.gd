extends Control
## 职业选择（P3）：新游戏开始时选择勘探者 / 工程师 / 医师
## 技能点来源提示：击杀大Boss +2 / 小Boss +1 / 普通怪每 10 只 +1


func _ready() -> void:
	$CenterPanel/VBox/BackButton.pressed.connect(_on_back)
	var list := $CenterPanel/VBox/ClassList
	for id in PlayerClass.CLASSES:
		var def: Dictionary = PlayerClass.CLASSES[id]
		var btn := Button.new()
		btn.text = "%s　%s" % [def["name"], def["desc"]]
		btn.tooltip_text = "选择 %s" % def["name"]
		btn.pressed.connect(_pick.bind(id))
		list.add_child(btn)


func _pick(id: String) -> void:
	AudioManager.play_sfx("ui_click")
	PlayerClass.set_class(id)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_back() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
