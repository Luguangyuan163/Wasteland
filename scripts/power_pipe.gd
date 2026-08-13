extends Node2D
## 能量管道：靠近按 E 转动（断开/接通），全部接通后发奖励
## 挂在组 power_pipes，玩家交互时调用 toggle()

@export var connected := false

const REWARDS := {"iron": 2, "stone": 2}

var _solved := false
var _player_near := false
@onready var _hint: Label = $Hint


func _ready() -> void:
	_update_visual()
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	_update_visibility()
	# 只有离玩家最近的管道才显示“按 E”提示，避免相邻管道提示重叠
	_hint.visible = _player_near and _is_nearest_to_player() and _visible_now()


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = false


## 自己是否离玩家最近（和按 E 实际会转动的管道一致）
func _is_nearest_to_player() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var my_dist: float = player.global_position.distance_to(global_position)
	for p in get_tree().get_nodes_in_group("power_pipes"):
		if p == self:
			continue
		if player.global_position.distance_to(p.global_position) <= my_dist:
			return false
	return true


func toggle() -> void:
	if _solved or not _visible_now():
		return  # 已解决就不再转动
	connected = not connected
	_update_visual()
	AudioManager.play_sfx("pipe_toggle")
	_check_solved()


## 管道在黑暗区域内、玩家在黑暗区域外时不可见，也不能交互
func _visible_now() -> bool:
	var world = get_tree().current_scene
	if world == null or not world.has_method("is_in_dark_zone"):
		return true
	return not (world.is_in_dark_zone(global_position) and not world.is_player_in_dark())


func _update_visibility() -> void:
	var v := _visible_now()
	$Visual.visible = v
	$Line.visible = v


## 读档时恢复状态
func apply_state(state: bool) -> void:
	connected = state
	_update_visual()


## 读档后若全部管道已接通：标记已解决（不给第二次奖励）
func mark_solved() -> void:
	_solved = true


func _check_solved() -> void:
	for p in get_tree().get_nodes_in_group("power_pipes"):
		if not p.connected:
			return
	# 全部接通：标记所有管道已解决，只发一次奖励
	for p in get_tree().get_nodes_in_group("power_pipes"):
		p._solved = true
	for id in REWARDS:
		Inventory.add_item(id, REWARDS[id])
	AudioManager.play_sfx("craft")  # 奖励达成提示音
	SaveManager.toast.emit("能量管道接通！获得奖励：铁矿石×2、石头×2")


func _update_visual() -> void:
	$Visual.color = Color(0.35, 0.8, 0.35) if connected else Color(0.5, 0.5, 0.5)
	$Line.rotation = 0.0 if connected else PI / 2.0  # 接通横放，断开竖放
