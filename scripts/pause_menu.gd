extends CanvasLayer
## 暂停菜单：继续 / 设置 / 返回主菜单
## 由 PauseManager 持有，跨场景常驻，process_mode 设为 ALWAYS 才能在暂停时操作


func _ready() -> void:
	$Dim.mouse_filter = Control.MOUSE_FILTER_STOP  # 挡住底层点击
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/SettingsButton.pressed.connect(_on_settings)
	$Panel/VBox/MenuButton.pressed.connect(_on_menu)
	$SettingsPanel.back_pressed.connect(func() -> void: $SettingsPanel.visible = false)


func _on_resume() -> void:
	AudioManager.play_sfx("ui_click")
	PauseManager.set_paused(false)


func _on_settings() -> void:
	AudioManager.play_sfx("ui_click")
	$Panel.visible = false
	$SettingsPanel.visible = true


func _on_menu() -> void:
	AudioManager.play_sfx("ui_click")
	PauseManager.set_paused(false)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
