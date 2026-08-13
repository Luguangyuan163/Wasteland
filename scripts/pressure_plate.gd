extends Node2D
## 压力板：玩家踩下后打开关联的门（v1 永久打开）

var door: Node = null  # 由地图生成器绑定
var _pressed := false


func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and not _pressed:
		_pressed = true
		AudioManager.play_sfx("puzzle_press")
		if door != null and door.has_method("set_open"):
			door.set_open(true)
		SaveManager.toast.emit("压力板被踩下，门开了")
