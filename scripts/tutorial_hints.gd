extends Node
## 新手教程提示（第十二课）：首次进入时按顺序弹出操作提示，提示过的永久不再显示
## 已看记录存 user://tutorial.cfg；提示队列一次显示一条，几秒后自动切换

const HINT_SCENE := preload("res://scenes/tutorial_hint.tscn")
const CONFIG_PATH := "user://tutorial.cfg"
const HINT_SECONDS := 3.5  # 每条提示停留时间

var _queue: Array[String] = []
var _current := ""
var _timer := 0.0
var _panel: PanelContainer = null
var _label: Label = null
var _seen := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也继续显示，避免暂停打断提示
	_load_seen()
	var layer: CanvasLayer = HINT_SCENE.instantiate()
	add_child(layer)
	_panel = layer.get_node("Panel") as PanelContainer
	_label = layer.get_node("Panel/Label") as Label


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_advance()


## 首次提示：只在从未看过时入队并立即标记，避免重复打扰
func show_first_time(id: String, text: String) -> void:
	if _seen.has(id):
		return
	_seen[id] = true
	_save_seen()
	enqueue(text)


## 加入提示队列（可被 show_first_time 调用，也可手动加）
func enqueue(text: String) -> void:
	_queue.append(text)
	if _current.is_empty():
		_advance()


## 显示下一条；队列空则隐藏
func _advance() -> void:
	if _queue.is_empty():
		_current = ""
		_panel.visible = false
		return
	_current = _queue.pop_front()
	_label.text = _current
	_panel.visible = true
	_timer = HINT_SECONDS


func _load_seen() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for key in cfg.get_section_keys("hints"):
		_seen[key] = true


func _save_seen() -> void:
	var cfg := ConfigFile.new()
	for key in _seen:
		cfg.set_value("hints", key, true)
	cfg.save(CONFIG_PATH)
