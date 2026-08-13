extends PanelContainer
## 设置面板：音量滑块，保存到 user://settings.cfg

signal back_pressed  # 点“返回”时通知父级收起面板

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const KEY := "master_volume"

var volume := 0.8  # 0.0 ~ 1.0

@onready var _slider: HSlider = $Margin/VBox/VolumeRow/Slider


func _ready() -> void:
	_load()
	_apply()
	_slider.value = volume * 100.0
	_slider.value_changed.connect(_on_volume_changed)
	# 拖动结束才播一声提示，避免拖动过程中连续发声
	_slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_sfx("ui_click"))
	$Margin/VBox/BackButton.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click")
		back_pressed.emit())


func _on_volume_changed(value: float) -> void:
	volume = value / 100.0
	_apply()
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		volume = float(cfg.get_value(SECTION, KEY, 0.8))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY, volume)
	cfg.save(SETTINGS_PATH)


func _apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volume))
