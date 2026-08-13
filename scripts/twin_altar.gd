extends Node2D
## 双子机关碑：两座石碑联动的限时谜题。
## 先激活 A（is_first=true），15 秒内激活 B（partner）→ 两碑共鸣，奖励在 B 旁出现。
## 顺序错误或超时都会重置 A 的激活状态。

@export var partner: Node = null
@export var is_first := true     # true = 必须先激活的碑
@export var solved := false

const LINK_TIME := 15.0    # 激活第一座后给玩家找第二座的时间（秒）
const RESOURCE_SCENE := preload("res://scenes/resource_node.tscn")

var _player_near := false
var _first_active := false  # 本碑处于"已激活等待联动"状态
var _timer: SceneTreeTimer = null
@onready var _visual: Polygon2D = $Visual
@onready var _hint: Label = $Hint
@onready var _status: Label = $Status


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	_hint.visible = _player_near and not solved and _is_nearest_interactable()
	_hint.text = "按 E 激活石碑" if is_first else "按 E 激活石碑"


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = false


func _is_nearest_interactable() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var my_dist: float = player.global_position.distance_to(global_position)
	for group in ["keypad_locks", "relic_devices", "twin_altars", "power_pipes", "portals"]:
		for node in get_tree().get_nodes_in_group(group):
			if node == self:
				continue
			if player.global_position.distance_to(node.global_position) <= my_dist:
				return false
	return true


## 玩家按 E 调用
func activate() -> void:
	if solved:
		return
	if is_first:
		_first_active = true
		AudioManager.play_sfx("puzzle_press")
		SaveManager.toast.emit("第一座石碑亮起——快去激活另一座！")
		_start_link_timer()
		_refresh_visual()
		return
	# 第二座：必须先激活过第一座
	if partner != null and partner._first_active:
		_solve_pair()
	else:
		AudioManager.play_sfx("puzzle_fail")
		SaveManager.toast.emit("第二座石碑亮了又灭——得先激活另一座")
		_flash_fail()


func _start_link_timer() -> void:
	if _timer != null:
		return
	_timer = get_tree().create_timer(LINK_TIME)
	_timer.timeout.connect(func() -> void:
		if _first_active and not solved:
			_first_active = false
			AudioManager.play_sfx("puzzle_fail")
			SaveManager.toast.emit("石碑的光芒消散了——需要先激活第一座再尽快激活第二座")
			_refresh_visual()
	)


func _solve_pair() -> void:
	solved = true
	_first_active = false
	AudioManager.play_sfx("puzzle_ok")
	if partner != null:
		partner.solved = true
		partner._first_active = false
		partner._refresh_visual()
	SaveManager.toast.emit("双子石碑共鸣！宝藏从第二座石碑旁浮现，获得宝石×2、石头×4")
	_spawn_rewards()
	_refresh_visual()


## 奖励直接生成在第二座石碑（后激活的那座）旁
func _spawn_rewards() -> void:
	var spot: Vector2 = global_position
	if is_first and partner != null:
		spot = partner.global_position
	spot += Vector2(0, 26)
	var metas := [{"id": "gem", "name": "宝石", "color": Color(1.0, 0.6, 0.8), "n": 2},
		{"id": "stone", "name": "石头", "color": Color(0.55, 0.55, 0.55), "n": 4}]
	for m in metas:
		for i in m["n"]:
			var node: Node2D = RESOURCE_SCENE.instantiate()
			node.resource_id = m["id"]
			node.resource_name = m["name"]
			node.amount = 1
			node.color = m["color"]
			node.global_position = spot + Vector2((i - m["n"] / 2.0 + 0.5) * 24.0, 0.0)
			get_parent().add_child(node)  # 挂在石碑所在场景（世界）下


## 顺序错误/超时时石碑闪红
func _flash_fail() -> void:
	_visual.color = Color(0.9, 0.25, 0.2)
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func() -> void:
		if not solved:
			_refresh_visual()
	)


## 读档恢复（两座都恢复；已解开的门保持打开，奖励不重复发）
func apply_state(state: Dictionary) -> void:
	solved = bool(state.get("solved", solved))
	if solved:
		_first_active = false
		if partner != null:
			partner.solved = true
			partner._first_active = false
			partner._refresh_visual()
	_refresh_visual()


func _refresh_visual() -> void:
	if _visual == null:
		return
	_visual.color = Color(0.85, 0.75, 0.45) if solved else (Color(0.6, 0.75, 0.9) if _first_active else Color(0.45, 0.42, 0.38))
	if _status != null:
		_status.text = "已共鸣" if solved else ("已激活" if _first_active else "石碑")
