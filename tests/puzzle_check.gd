extends SceneTree
## 解谜扩展验收脚本：验证 密码锁 / 遗迹装置 / 双子机关碑 完整链路 + 存档恢复
## 运行：godot --headless --path . --script res://tests/puzzle_check.gd
## 结果写入 res://tests/puzzle_report.txt（headless 下 stdout 不可见）

const REPORT_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/puzzle_report.txt"

var _frames := 0
var _world: Node = null
var _log := ""
var _fail := 0


func _initialize() -> void:
	_log = "== 解谜扩展检测（%s）==\n" % Time.get_datetime_string_from_system()
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	_world = world_scene.instantiate()
	root.add_child(_world)
	current_scene = _world  # 模拟正常游戏：存档等系统依赖 current_scene


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
	_log += "== 1. 世界生成：谜题实体齐全 ==\n"
	var keypads := get_nodes_in_group("keypad_locks")
	var relics := get_nodes_in_group("relic_devices")
	var altars := get_nodes_in_group("twin_altars")
	_check(keypads.size() == 1, "密码锁 1 个（实际 %d）" % keypads.size())
	_check(relics.size() == 1, "遗迹装置 1 个（实际 %d）" % relics.size())
	_check(altars.size() == 2, "双子碑 2 座（实际 %d）" % altars.size())
	_check(_world._road_segments_ok >= 20, "路网 20 段全通（实际 %d）" % _world._road_segments_ok)
	var code: String = keypads[0].code
	_check(code.length() == 3 and code.is_valid_int(), "密码为三位数字（%s）" % code)
	_check(relics[0].sequence.size() == 4, "符文序列长度 4（%s）" % str(relics[0].sequence))

	_log += "== 2. 联动链：遗迹装置 → 密码锁 ==\n"
	var keypad: Node = keypads[0]
	var relic: Node = relics[0]
	_check(not keypad.solved and not keypad.input_enabled, "密码锁初始未激活")
	keypad.try_open()
	_check(not keypad.input_enabled, "未激活时按 E 无法输入")
	# 模拟玩家：先点错一个符文（顺序重置），再按正确顺序复述
	relic._accepting = true
	relic._step = 0
	var wrong: int = (int(relic.sequence[0]) + 1) % 4
	relic._press_node(wrong)
	_check(not relic.solved and not relic._accepting, "点错符文顺序重置")
	relic._accepting = true
	relic._step = 0
	for i in relic.sequence:
		relic._press_node(int(i))
	_check(relic.solved, "按正确顺序复述 → 装置破解")
	_check(keypad.input_enabled and keypad.revealed, "破解后密码锁被激活并揭示密码")

	_log += "== 3. 密码锁面板：错误/正确输入 ==\n"
	keypad.try_open()
	var panel := get_first_node_in_group("keypad_panels")
	_check(panel != null and panel.call("is_open"), "激活后按 E 弹出密码面板")
	if panel != null:
		var wrong_code := "%03d" % ((int(code) + 1) % 1000)
		panel.set("_input", wrong_code)
		panel.call("_confirm")
		_check(not keypad.solved, "错误密码不开门（%s）" % wrong_code)
		panel.set("_input", code)
		panel.call("_confirm")
		_check(keypad.solved, "正确密码开门（%s）" % code)
		_check(not panel.call("is_open"), "成功后面板自动关闭")
	_check(keypad.linked_door != null and keypad.linked_door.is_open, "关联门已打开")

	_log += "== 4. 双子机关碑：顺序 + 限时联动 ==\n"
	var altar_a: Node = null
	var altar_b: Node = null
	for a in altars:
		if a.is_first:
			altar_a = a
		else:
			altar_b = a
	altar_b.activate()
	_check(not altar_b.solved and not altar_a._first_active, "先激活第二座 → 无效")
	altar_a.activate()
	_check(altar_a._first_active, "先激活第一座 → 等待联动")
	altar_b.activate()
	_check(altar_a.solved and altar_b.solved, "限时内激活两座 → 双碑共鸣")
	var gem_count := 0
	for r in get_nodes_in_group("resource_nodes"):
		if r.resource_id == "gem" and r.global_position.distance_to(altar_b.global_position) < 100.0:
			gem_count += 1
	_check(gem_count >= 2, "奖励宝石在石碑旁生成（%d）" % gem_count)

	_log += "== 5. 存档往返：已解谜题不重置、不重复发奖 ==\n"
	var save_manager: Node = root.get_node("SaveManager")
	var inventory: Node = root.get_node("Inventory")
	var puzzles: Array = save_manager._collect_puzzles()
	_check(puzzles.size() == 4, "存档记录 4 条谜题状态（实际 %d）" % puzzles.size())
	var relic_before: int = inventory.items.get("relic", 0)
	save_manager._save_to("user://puzzle_check_save.json")
	save_manager.load_game_from("user://puzzle_check_save.json", false)
	var keypads2 := get_nodes_in_group("keypad_locks")
	var relics2 := get_nodes_in_group("relic_devices")
	var altars2 := get_nodes_in_group("twin_altars")
	_check(keypads2.size() == 1 and relics2.size() == 1 and altars2.size() == 2, "读档后实体数量不重复")
	_check(keypads2[0].solved, "读档后密码锁仍为已解")
	_check(keypads2[0].input_enabled, "读档后密码锁仍可输入")
	_check(relics2[0].solved, "读档后遗迹装置仍为已解")
	_check(altars2[0].solved and altars2[1].solved, "读档后双子碑仍为已解")
	_check(inventory.items.get("relic", 0) == relic_before, "读档不重复发奖励（古物 %d）" % inventory.items.get("relic", 0))

	_log += "== 6. 布局合法性 ==\n"
	# 密码锁/装置在遗迹密室内，石碑在密室外
	var anchor: Vector2i = _world.relic_anchor
	var room_rect := Rect2(Vector2(anchor.x * 32.0, anchor.y * 32.0), Vector2(7 * 32.0, 6 * 32.0))
	var kp_pos: Vector2 = keypads2[0].global_position
	var rl_pos: Vector2 = relics2[0].global_position
	_check(room_rect.has_point(kp_pos), "密码锁位于密室内")
	_check(room_rect.has_point(rl_pos), "遗迹装置位于密室内")
	_check(not room_rect.has_point(altars2[0].global_position), "石碑 A 在密室外")
	_check(not room_rect.has_point(altars2[1].global_position), "石碑 B 在密室外")
	# 全部实体在 200×150 地图范围内
	var ok_bounds := true
	for node in get_nodes_in_group("keypad_locks") + get_nodes_in_group("relic_devices") + get_nodes_in_group("twin_altars"):
		if node.global_position.x < 32.0 or node.global_position.y < 32.0 \
			or node.global_position.x > 200 * 32.0 or node.global_position.y > 150 * 32.0:
			ok_bounds = false
	_check(ok_bounds, "所有谜题实体在地图边界内")
	_log += "== 检测结束：失败 %d 项 ==\n" % _fail


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_log)
		file.close()
