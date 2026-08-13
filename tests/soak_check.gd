extends SceneTree
## 浸泡测试：把玩家依次传送到各群系中心，触发探索刷怪/敌人 AI/死亡重生/标签系统
## 运行：godot --headless --path . --script res://tests/soak_check.gd（结果看日志是否有脚本错误）

var _frames := 0
var _world: Node = null
var _player: Node2D = null
var _stops := [
	{"pos": Vector2(100, 75), "label": "地表"},
	{"pos": Vector2(30, 78), "label": "冰脉"},
	{"pos": Vector2(48, 122), "label": "爆炎"},
	{"pos": Vector2(170, 78), "label": "辐射"},
	{"pos": Vector2(100, 134), "label": "机械"},
	{"pos": Vector2(150, 120), "label": "暗域"},
	{"pos": Vector2(42, 40), "label": "沼泽"},
	{"pos": Vector2(158, 40), "label": "峡谷"},
	{"pos": Vector2(100, 26), "label": "天空"},
	{"pos": Vector2(22, 44), "label": "沙丘"},
	{"pos": Vector2(178, 44), "label": "雷鸣"},
	{"pos": Vector2(36, 112), "label": "真菌"},
	{"pos": Vector2(126, 136), "label": "遗迹"},
	{"pos": Vector2(168, 110), "label": "墓园"},
	{"pos": Vector2(72, 30), "label": "绿洲"},
]
var _stop_idx := -1
var _frames_in_stop := 0
const FRAMES_PER_STOP := 200


func _initialize() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	_player = _world.get_node("Player")
	# 浸泡测试要触发探索刷怪：关掉开局安全期，否则 120 秒内刷怪器完全休眠
	var spawner := _world.get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.grace_duration = 0.0


func _process(_delta: float) -> bool:
	_frames += 1
	if _world == null:
		return false
	if _stop_idx == -1:
		if _frames >= 5:
			_stop_idx = 0
			_player.global_position = _stops[0]["pos"] * 32.0
		return false
	_frames_in_stop += 1
	if _frames_in_stop >= FRAMES_PER_STOP:
		_stop_idx += 1
		_frames_in_stop = 0
		if _stop_idx >= _stops.size():
			print("[SOAK] 完成，总帧数=%d，怪物数=%d" % [_frames, get_nodes_in_group("enemies").size()])
			quit(0)
			return true
		_player.global_position = _stops[_stop_idx]["pos"] * 32.0
		print("[SOAK] 前往群系：%s" % _stops[_stop_idx]["label"])
	return false
