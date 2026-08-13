extends Node
## 暂停管理（第十一课）：Esc 暂停/继续，暂停菜单跨场景常驻

const PAUSE_MENU := preload("res://scenes/pause_menu.tscn")

var _menu: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也要能接收输入
	_menu = PAUSE_MENU.instantiate()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.visible = false
	add_child(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_menu.visible = paused
