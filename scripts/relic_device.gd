extends Node2D
## 遗迹装置：记忆序列谜题。按 E 启动后 4 个符文按顺序点亮，玩家用鼠标按同样顺序点击。
## 破解后激活联动密码锁并揭示密码（构成"遗迹装置 → 密码锁 → 宝库"联动谜题）。

@export var sequence: Array = [0, 1, 2, 3]  # 符文点亮顺序（0~3，生成器按种子洗牌）
@export var linked_keypad: Node = null      # 联动：密码锁
@export var solved := false

const REWARDS := {"rune_stone": 2, "parts": 1}
const SEQUENCE_LEN := 4
const SHOW_DELAY := 0.45   # 演示阶段每个符文亮多久
const FAIL_DELAY := 0.9    # 点错后重置前停顿

var _player_near := false
var _accepting := false   # 演示结束，等待玩家点击
var _step := 0            # 玩家已正确复述到第几步
var _timer: SceneTreeTimer = null
@onready var _status: Label = $Status
@onready var _hint: Label = $Hint


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	for i in SEQUENCE_LEN:
		var node: Area2D = get_node("Nodes/Node%d" % i)
		node.input_event.connect(_on_node_clicked.bind(i))
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	_hint.visible = _player_near and not solved and _is_nearest_interactable()


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


## 玩家按 E 调用：开始（或重看）符文序列演示
func start_attempt() -> void:
	if solved:
		return
	if _accepting:
		SaveManager.toast.emit("符文正在等待你点击——按顺序点它们")
		return
	AudioManager.play_sfx("puzzle_press")
	_step = 0
	_status.text = "记住符文的点亮顺序……"
	_play_sequence(0)


func _play_sequence(idx: int) -> void:
	if idx >= SEQUENCE_LEN:
		_accepting = true
		_status.text = "轮到你了——按顺序点击符文"
		return
	_light(idx, true)
	_timer = get_tree().create_timer(SHOW_DELAY)
	_timer.timeout.connect(func() -> void:
		_light(idx, false)
		_play_sequence(idx + 1)
	)


func _light(idx: int, on: bool) -> void:
	var node: Area2D = get_node("Nodes/Node%d" % idx)
	node.get_node("Visual").color = Color(1.0, 0.85, 0.4) if on else Color(0.35, 0.35, 0.45)


func _on_node_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, idx: int) -> void:
	if not _accepting or solved:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press_node(idx)


## 玩家点击/测试调用：检查是否与序列下一步一致
func _press_node(idx: int) -> void:
	if not _accepting or solved:
		return
	if sequence[_step] != idx:
		_fail_flash()
		AudioManager.play_sfx("puzzle_fail")
		_status.text = "顺序不对……装置重新演示"
		SaveManager.toast.emit("符文闪过红光，序列重置")
		_accepting = false
		_timer = get_tree().create_timer(FAIL_DELAY)
		_timer.timeout.connect(func() -> void:
			_step = 0
			_play_sequence(0)
		)
		return
	AudioManager.play_sfx("keypad_beep")
	_step += 1
	_light(idx, true)  # 复述正确时符文保持点亮
	if _step >= SEQUENCE_LEN:
		_solve()


## 点错时全部符文闪红，提示玩家"顺序错误"
func _fail_flash() -> void:
	for i in SEQUENCE_LEN:
		var node: Area2D = get_node("Nodes/Node%d" % i)
		node.get_node("Visual").color = Color(0.9, 0.25, 0.2)
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(func() -> void:
		if not solved:
			for i2 in SEQUENCE_LEN:
				_light(i2, false)
	)


func _solve() -> void:
	solved = true
	_accepting = false
	AudioManager.play_sfx("puzzle_ok")
	_status.text = "已激活"
	if linked_keypad != null and linked_keypad.has_method("reveal_code"):
		linked_keypad.reveal_code()
	for id in REWARDS:
		Inventory.add_item(id, REWARDS[id])
	SaveManager.toast.emit("遗迹装置被唤醒！获得符文石×2、零件×1")
	_refresh_visual()


## 读档恢复：已破解则不再演示
func apply_state(state: Dictionary) -> void:
	sequence = state.get("sequence", sequence)
	solved = bool(state.get("solved", solved))
	if solved:
		_accepting = false
		_status.text = "已激活"
	_refresh_visual()


func _refresh_visual() -> void:
	if _status == null:
		return
	_status.text = "已激活" if solved else "遗迹装置（按 E 启动）"
