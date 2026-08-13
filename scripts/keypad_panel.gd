extends CanvasLayer
## 密码锁输入面板：0-9 数字键 + 清除 + 确认，独立 UI 层，不直接碰游戏数据
## 打开后按 E（玩家侧）或 Esc 关闭；支持小键盘数字与回车

const CODE_LEN := 3

var _lock: Node = null
var _input := ""

@onready var _display: Label = $Panel/VBox/Display


func _ready() -> void:
	visible = false
	add_to_group("keypad_panels")
	_build_buttons()


func open(lock: Node) -> void:
	_lock = lock
	_input = ""
	_refresh_display()
	AudioManager.play_sfx("ui_click")
	visible = true


func close() -> void:
	AudioManager.play_sfx("ui_close")
	visible = false
	_lock = null


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm()
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				_clear()
				get_viewport().set_input_as_handled()
		if event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_9:
			_press_digit(str(event.physical_keycode - KEY_0))
			get_viewport().set_input_as_handled()


func _press_digit(digit: String) -> void:
	if _input.length() >= CODE_LEN:
		return
	_input += digit
	AudioManager.play_sfx("keypad_beep")
	_refresh_display()


func _clear() -> void:
	_input = ""
	AudioManager.play_sfx("ui_close")
	_refresh_display()


func _confirm() -> void:
	if _lock == null:
		return
	if _input.length() < CODE_LEN:
		SaveManager.toast.emit("密码是 %d 位数，还没输完" % CODE_LEN)
		return
	_lock.submit(_input)
	if _lock == null or _lock.solved:  # 正确密码会让 _solve() 主动关闭面板并清空 _lock
		close()
	else:
		_input = ""
		_refresh_display()


func _refresh_display() -> void:
	if _display == null:
		return
	var shown := _input
	while shown.length() < CODE_LEN:
		shown += "＿"
	_display.text = shown


## 用代码生成数字键盘（0-9 + 清除 + 确认），避免场景里写死 12 个按钮
func _build_buttons() -> void:
	var grid: GridContainer = $Panel/VBox/Grid
	for d in 9:
		var btn := Button.new()
		btn.text = str(d + 1)
		btn.custom_minimum_size = Vector2(48, 40)
		btn.pressed.connect(_press_digit.bind(str(d + 1)))
		grid.add_child(btn)
	var clear_btn := Button.new()
	clear_btn.text = "清除"
	clear_btn.pressed.connect(_clear)
	grid.add_child(clear_btn)
	var zero_btn := Button.new()
	zero_btn.text = "0"
	zero_btn.pressed.connect(_press_digit.bind("0"))
	grid.add_child(zero_btn)
	var ok_btn := Button.new()
	ok_btn.text = "确认"
	ok_btn.pressed.connect(_confirm)
	grid.add_child(ok_btn)
