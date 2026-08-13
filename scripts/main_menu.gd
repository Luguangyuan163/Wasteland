extends Control
## 主菜单：开始游戏 / 设置 / 退出


func _ready() -> void:
	AudioManager.stop_ambient()  # 回到菜单停止环境音，避免两个场景音叠加
	$CenterPanel/VBox/StartButton.pressed.connect(_on_start)
	$CenterPanel/VBox/SettingsButton.pressed.connect(_on_settings)
	$CenterPanel/VBox/QuitButton.pressed.connect(_on_quit)
	$SettingsPanel.back_pressed.connect(func() -> void: $SettingsPanel.visible = false)


func _on_start() -> void:
	AudioManager.play_sfx("ui_click")
	# P3 职业系统：新游戏先选职业（勘探者/工程师/医师），再进入世界
	get_tree().change_scene_to_file("res://scenes/class_select.tscn")


func _on_settings() -> void:
	AudioManager.play_sfx("ui_click")
	$SettingsPanel.visible = true


func _on_quit() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().quit()
