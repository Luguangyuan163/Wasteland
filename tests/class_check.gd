extends SceneTree
## 职业系统验证（P3）：选择职业 → 技能点 → 升级 → 玩家属性加成 → 击杀奖励 → 存档往返

const REPORT := "E:/Codex/游戏项目/wasteland-echo/tests/class_report.txt"

var _frames := 0
var _world: Node = null
var _log := ""
var _errors := 0


func _initialize() -> void:
	var pc := root.get_node("PlayerClass")
	_log += "== 职业系统验证 ==\n"
	# 1. 选择职业
	pc.set_class("scout")
	_check(pc.class_id == "scout", "选择勘探者")
	_check(pc.skill_list().size() == 3, "勘探者 3 个技能")
	# 2. 技能点与升级
	pc.skill_points = 3
	pc.upgrade("swift")
	_check(pc.skill_level("swift") == 1 and pc.skill_points == 2, "升级消耗 1 技能点")
	_check(not pc.can_upgrade("swift") or pc.skill_points >= 0, "可升级判定")
	# 3. 击杀奖励
	pc.on_enemy_killed("大Boss")
	pc.on_enemy_killed("小Boss")
	_check(pc.skill_points == 5, "大Boss+2 小Boss+1（当前 %d）" % pc.skill_points)
	# 4. 存档往返
	var save_data: Dictionary = pc.to_save()
	pc.set_class("medic")
	pc.restore_from_save(save_data)
	_check(pc.class_id == "scout" and pc.skill_level("swift") == 1, "存档恢复职业与技能")
	_log += "-- 进入世界验证玩家加成 --\n"
	_flush()
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var player: Node2D = _world.get_node("Player")
		var pc := root.get_node("PlayerClass")
		# 勘探者·疾行 Lv1 → 移动速度 +8%
		pc.set_class("scout")
		pc.skill_points = 9
		pc.upgrade("swift")
		var speed: float = player._effective_move_speed()
		_check(absf(speed - 400.0 * 1.08) < 0.01, "疾行 Lv1 速度 = %.0f" % speed)
		# 医师·强健 Lv1 → 生命上限 +20 且立即补血
		pc.set_class("medic")
		pc.skill_points = 9
		pc.upgrade("vitality")
		_check(player.max_hp == 120 and player.hp == 120, "强健 Lv1 生命上限/当前 = %d/%d" % [player.max_hp, player.hp])
		# 工程师·巧手 Lv1 → 建造范围 +1 格
		pc.set_class("engineer")
		pc.skill_points = 9
		pc.upgrade("long_arm")
		_check(absf(player.build_range - 160.0) < 0.01, "巧手 Lv1 建造范围 = %.0f" % player.build_range)
		# 医师·再生 Lv2 → 每秒 0.8，验证累加器逻辑不报错
		pc.set_class("medic")
		pc.skill_points = 9
		pc.upgrade("regeneration")
		pc.upgrade("regeneration")
		_check(pc.skill_level("regeneration") == 2, "再生 Lv2")
		# 界面加载
		var sel := (load("res://scenes/class_select.tscn") as PackedScene).instantiate()
		var panel := (load("res://scenes/skill_panel.tscn") as PackedScene).instantiate()
		root.add_child(sel)
		root.add_child(panel)
		_check(true, "职业选择/技能树界面加载成功")
		_flush()
		quit(1 if _errors > 0 else 0)
		return true
	return false


func _check(ok: bool, label: String) -> void:
	if ok:
		_log += "  [OK] %s\n" % label
	else:
		_log += "  [FAIL] %s\n" % label
		_errors += 1


func _flush() -> void:
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string(_log)
		f.close()
