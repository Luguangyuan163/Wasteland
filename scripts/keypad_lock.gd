extends Node2D
## 密码锁：靠近按 E 输入密码（三位数），密码由地图生成器按世界种子生成。
## 与遗迹装置联动：装置未激活前输入无效；装置破解后揭示密码并允许输入。
## 密码正确 → 打开关联门 + 发奖励；密码错误 → 提示并清空（可无限重试，避免卡关）

@export var code := "483"
@export var linked_door: Node = null
@export var solved := false
@export var input_enabled := false  # 联动：遗迹装置激活后变为 true
@export var revealed := false       # 是否已向玩家揭示密码

const REWARDS := {"relic": 2, "gem": 1, "parts": 2}
const PANEL_SCENE := preload("res://scenes/keypad_panel.tscn")

var _player_near := false
var _panel: CanvasLayer = null
@onready var _hint: Label = $Hint
@onready var _status: Label = $Status
@onready var _screen: Polygon2D = $Screen


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	# 只有离玩家最近的可交互谜题才显示提示，避免多个标签重叠
	_hint.visible = _player_near and not solved and _is_nearest_interactable()
	_hint.text = "按 E 输入密码" if input_enabled else "按 E 检查密码锁"


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_near = false


## 自己是否离玩家最近（和按 E 实际会触发的谜题一致）
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


## 玩家按 E 调用：激活后打开输入面板
func try_open() -> void:
	if solved:
		return
	if not input_enabled:
		AudioManager.play_sfx("puzzle_fail")
		SaveManager.toast.emit("密码锁纹丝不动——也许某处遗迹装置能唤醒它")
		return
	if _panel == null:
		_panel = PANEL_SCENE.instantiate()
		get_parent().add_child(_panel)  # 挂在密码锁所在场景（世界）下，CanvasLayer 渲染到全屏
	_panel.open(self)


## 面板提交密码（面板是独立 UI 层，只把结果传回来）
func submit(input: String) -> void:
	if solved or not input_enabled:
		return
	if input == code:
		_solve()
	else:
		AudioManager.play_sfx("puzzle_fail")
		SaveManager.toast.emit("密码错误，密码锁发出一声闷响")


func _solve() -> void:
	solved = true
	AudioManager.play_sfx("puzzle_ok")
	if linked_door != null and linked_door.has_method("set_open"):
		linked_door.set_open(true)
	for id in REWARDS:
		Inventory.add_item(id, REWARDS[id])
	SaveManager.toast.emit("密码正确！遗迹宝库开启，获得古物×2、宝石×1、零件×2")
	if _panel != null:
		_panel.close()
	_refresh_visual()


## 联动：遗迹装置破解后调用——激活输入并揭示密码
func reveal_code() -> void:
	if solved:
		return
	revealed = true
	input_enabled = true
	AudioManager.play_sfx("puzzle_ok")
	SaveManager.toast.emit("遗迹装置激活了密码锁，铭文显示密码：%s" % code)
	_refresh_visual()


## 读档恢复状态（密码由种子重建，这里只恢复进度，避免重复发奖）
func apply_state(state: Dictionary) -> void:
	code = str(state.get("code", code))
	input_enabled = bool(state.get("input_enabled", input_enabled))
	revealed = bool(state.get("revealed", revealed))
	solved = bool(state.get("solved", solved))
	if solved and linked_door != null and linked_door.has_method("set_open"):
		linked_door.set_open(true)
	_refresh_visual()


func _refresh_visual() -> void:
	if _screen == null:
		return
	if solved:
		_screen.color = Color(0.3, 0.65, 0.3)
	elif input_enabled:
		_screen.color = Color(0.35, 0.45, 0.7)
	else:
		_screen.color = Color(0.25, 0.25, 0.32)
	if _status != null:
		_status.text = "已开启" if solved else ("等待输入" if input_enabled else "未激活")
