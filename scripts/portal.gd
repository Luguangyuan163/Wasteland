extends Node2D
## 传送门：走近按 E 进入目标世界（地表→地心世界 / 地心世界→地表）
## 挂在组 portals，玩家交互时调用 enter()

@export var target_scene := ""  # 目标场景路径（由地图生成器设置）
@export var hint_text := "按 E 进入地心世界"

var _player_near := false
@onready var _hint: Label = $Hint


func _ready() -> void:
	_hint.text = hint_text
	_hint.visible = false
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	$Swirl.rotation += delta * 1.5  # 缓慢旋转，提示这是传送门
	_hint.visible = _player_near


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = false


func enter() -> void:
	AudioManager.play_sfx("portal")
	if target_scene == "res://scenes/underworld.tscn":
		SaveManager.enter_underworld()
	else:
		SaveManager.return_to_surface()
