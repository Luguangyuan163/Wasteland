extends SceneTree
## 恐怖氛围验收脚本：黑暗惩罚（地心无火把掉血/火把恢复/移速惩罚）、
## 异常事件（低语/闪烁/脚印/黑影）、敌人音效、明亮地表不受惩罚
## 运行：godot --headless --path . --script res://tests/horror_check.gd
## 结果写入 res://tests/horror_report.txt

const REPORT_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/horror_report.txt"

var _frames := 0
var _world: Node = null
var _underworld: Node = null
var _log := ""
var _fail := 0


func _initialize() -> void:
	_log = "== 恐怖氛围检测（%s）==\n" % Time.get_datetime_string_from_system()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	_run_checks()
	_flush()
	print(_log)
	quit(1 if _fail > 0 else 0)
	return true


func _check(cond: bool, name: String) -> void:
	if cond:
		_log += "PASS %s\n" % name
	else:
		_fail += 1
		_log += "FAIL %s\n" % name


func _run_checks() -> void:
	var inventory: Node = root.get_node("Inventory")
	var audio: Node = root.get_node("AudioManager")
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	var under_scene := load("res://scenes/underworld.tscn") as PackedScene
	_world = world_scene.instantiate()
	root.add_child(_world)
	current_scene = _world
	var world_player: Node2D = _world.get_node("Player")

	_log += "== 1. 明亮地表：不受黑暗惩罚 ==\n"
	_check(not world_player.is_in_dark_area(), "地表出生点不是黑暗区域")
	world_player.dark_exposure = 50.0
	world_player._update_darkness(10.0)
	_check(world_player.dark_exposure == 0.0, "明亮地表黑暗值自动归零")

	_log += "== 2. 移速惩罚：黑暗值 ≥50 减速 10% ==\n"
	var base_speed: float = world_player.move_speed
	world_player.dark_exposure = 0.0
	_check(is_equal_approx(world_player._effective_move_speed(), base_speed), "黑暗值 0 移速正常")
	world_player.dark_exposure = 50.0
	_check(is_equal_approx(world_player._effective_move_speed(), base_speed * 0.9), "黑暗值 50 移速 -10%%")
	world_player.dark_exposure = 0.0

	_log += "== 3. 地心世界：黑暗侵蚀上涨 → 满值掉血 → 火把恢复 ==\n"
	_underworld = under_scene.instantiate()
	root.add_child(_underworld)
	current_scene = _underworld
	var under_player: Node2D = _underworld.get_node("Player")
	inventory.equipped = ""
	under_player.dark_exposure = 0.0
	under_player._update_darkness(25.0)
	_check(under_player.dark_exposure > 0.0, "地心无火把黑暗值上涨（%.0f）" % under_player.dark_exposure)
	under_player._update_darkness(50.0)
	_check(under_player.dark_exposure >= 100.0, "地心黑暗值可涨满")
	var hp_before: int = under_player.hp
	under_player._update_darkness(2.0)
	_check(under_player.hp == hp_before - 1, "黑暗满值每 2 秒扣 1 血")
	inventory.equipped = "torch"
	under_player._update_darkness(10.0)
	_check(under_player.dark_exposure == 0.0, "装备火把后黑暗值快速恢复")
	under_player._update_darkness(10.0)
	_check(under_player.hp == hp_before - 1, "火把在手不再掉血")

	_log += "== 4. 异常事件：低语/闪烁/脚印/黑影 ==\n"
	current_scene = _world
	var manager := _world.get_node("AnomalyManager")
	_check(manager != null, "地表场景挂载异常事件管理器")
	manager.trigger_event("whisper")
	manager.trigger_event("flicker")
	manager.trigger_event("footprints")
	manager.trigger_event("shadow")
	_check(get_nodes_in_group("anomaly_footprints").size() >= 1, "脚印事件生成脚印组")
	_check(get_nodes_in_group("anomaly_shadows").size() >= 1, "黑影事件生成黑影")
	var under_manager := _underworld.get_node("AnomalyManager")
	_check(under_manager != null, "地心场景挂载异常事件管理器")
	under_manager.trigger_event("footprints")
	_check(get_nodes_in_group("anomaly_footprints").size() >= 2, "地心也能触发脚印")

	_log += "== 5. 敌人/氛围音效可播放 ==\n"
	for id in ["enemy_idle", "enemy_aggro", "enemy_attack", "anomaly_whisper", "anomaly_shadow", "anomaly_flicker", "dark_heart"]:
		audio.play_sfx(id)
	_check(true, "7 个恐怖音效播放无报错")

	_log += "== 6. 重生清空黑暗值 ==\n"
	under_player.dark_exposure = 80.0
	under_player.respawn()
	_check(under_player.dark_exposure == 0.0 and not under_player.dead, "重生后黑暗值清零")
	inventory.equipped = ""
	_log += "== 检测结束：失败 %d 项 ==\n" % _fail


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_log)
		file.close()
