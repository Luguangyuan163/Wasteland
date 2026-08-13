extends SceneTree
## 多种子路网 + 谜题布局抽查：固定 5 个种子生成世界，验证路网 20/20、谜题齐全、石碑不贴密室
## 运行：godot --headless --path . --script res://tests/road_multiseed_check.gd

const REPORT_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/road_multiseed_report.txt"
const SEEDS := [12345, 20260813, 42, 777, 999999]

var _log := ""
var _fail := 0
var _idx := 0
var _world: Node = null
var _frames := 0


func _initialize() -> void:
	_log = "== 多种子路网/谜题抽查 ==\n"


func _process(_delta: float) -> bool:
	_frames += 1
	if _world == null:
		if _idx >= SEEDS.size():
			_flush()
			print(_log)
			quit(1 if _fail > 0 else 0)
			return true
		var scene := load("res://scenes/world.tscn") as PackedScene
		_world = scene.instantiate()
		root.add_child(_world)
		_world.generate(SEEDS[_idx])
		_frames = 0
		return false
	if _frames < 5:
		return false
	var seed_value: int = SEEDS[_idx]
	_check(_world._road_segments_ok >= 20, "种子 %d：路网 %d/20" % [seed_value, _world._road_segments_ok])
	var k := get_nodes_in_group("keypad_locks").size()
	var r := get_nodes_in_group("relic_devices").size()
	var a := get_nodes_in_group("twin_altars").size()
	_check(k == 1 and r == 1 and a == 2, "种子 %d：谜题齐全（锁%d 装置%d 碑%d）" % [seed_value, k, r, a])
	# 石碑必须与密室保持 ≥2 格间距（否则路网终点落在墙上）
	var anchor: Vector2i = _world.relic_anchor
	var relic_cells: Array = _world._compute_relic_cells(anchor)
	var altars_ok := true
	for altar in get_nodes_in_group("twin_altars"):
		var cell := Vector2i(floori(altar.global_position.x / 32.0), floori(altar.global_position.y / 32.0))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if relic_cells.has(cell + Vector2i(dx, dy)):
					altars_ok = false
	_check(altars_ok, "种子 %d：双子碑不贴密室" % seed_value)
	_world.free()
	_world = null
	_idx += 1
	return false


func _check(cond: bool, name: String) -> void:
	if cond:
		_log += "PASS %s\n" % name
	else:
		_fail += 1
		_log += "FAIL %s\n" % name


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_log)
		file.close()
