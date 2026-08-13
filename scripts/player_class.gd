extends Node
## 职业系统（P3，2026-08-13）：勘探者 / 工程师 / 医师，各 3 个技能 + 技能树雏形
##
## - 职业在主菜单"开始游戏"时选择（class_select 场景），随存档保存
## - 技能点来源：击杀大Boss +2、小Boss +1、普通怪每 10 只 +1
## - 技能等级 0~3，花费技能点逐级提升，不同职业互不影响
## - player.gd 读取 skill_level() 实时应用加成；HUD 按 K 打开技能树

signal changed  # 职业/技能点/技能等级变化时通知 HUD 与玩家刷新

const CLASSES := {
	"scout": {
		"name": "勘探者",
		"desc": "擅长探索与采集：视野更远、跑得更快、采得更多",
		"skills": [
			{"id": "eagle_eye", "name": "鹰眼", "desc": "黑暗中的视野半径 +25%/级", "max": 3},
			{"id": "swift", "name": "疾行", "desc": "移动速度 +8%/级", "max": 3},
			{"id": "gatherer", "name": "采集大师", "desc": "采集产出 +20%/级", "max": 3},
		],
	},
	"engineer": {
		"name": "工程师",
		"desc": "擅长建造与机关：造得更远、更省，拆了能回收",
		"skills": [
			{"id": "long_arm", "name": "巧手", "desc": "建造范围 +1 格/级", "max": 3},
			{"id": "thrifty", "name": "节俭", "desc": "建造消耗 -15%/级", "max": 3},
			{"id": "salvage", "name": "拆解回收", "desc": "拆除建筑返还 40%/55%/70% 材料", "max": 3},
		],
	},
	"medic": {
		"name": "医师",
		"desc": "擅长生存与续航：更耐打、自动回血、复活更快",
		"skills": [
			{"id": "vitality", "name": "强健", "desc": "生命上限 +20/级", "max": 3},
			{"id": "regeneration", "name": "再生", "desc": "每秒回复 0.4/0.8/1.2 生命", "max": 3},
			{"id": "resilient", "name": "顽强", "desc": "复活延迟 -0.5/1.0/1.5 秒", "max": 3},
		],
	},
}

var class_id := ""         # 当前职业（""=未选择）
var skill_points := 0      # 可用技能点
var skill_levels := {}     # skill_id -> 等级（0~3）
var _regular_kills := 0    # 普通击杀计数（每 10 只 +1 技能点）


## 选择职业（新游戏时调用），清空上一职业的进度
func set_class(id: String) -> void:
	if not CLASSES.has(id):
		return
	class_id = id
	skill_points = 0
	skill_levels.clear()
	_regular_kills = 0
	changed.emit()


func get_class_def() -> Dictionary:
	return CLASSES.get(class_id, {})


func skill_list() -> Array:
	return get_class_def().get("skills", [])


func skill_level(id: String) -> int:
	return int(skill_levels.get(id, 0))


func skill_def(id: String) -> Dictionary:
	for s in skill_list():
		if s["id"] == id:
			return s
	return {}


func can_upgrade(id: String) -> bool:
	if class_id == "" or skill_points <= 0:
		return false
	var s := skill_def(id)
	if s.is_empty():
		return false
	return skill_level(id) < int(s["max"])


## 花费 1 点技能点升级指定技能
func upgrade(id: String) -> void:
	if not can_upgrade(id):
		return
	skill_points -= 1
	skill_levels[id] = skill_level(id) + 1
	changed.emit()


## 击杀奖励：大Boss +2、小Boss +1、普通怪每 10 只 +1
func on_enemy_killed(kind: String) -> void:
	match kind:
		"大Boss":
			skill_points += 2
		"小Boss":
			skill_points += 1
		_:
			_regular_kills += 1
			if _regular_kills >= 10:
				_regular_kills = 0
				skill_points += 1
	changed.emit()


## 存档数据（SaveManager 调用）
func to_save() -> Dictionary:
	return {
		"class_id": class_id,
		"skill_points": skill_points,
		"skill_levels": skill_levels.duplicate(),
	}


## 读档恢复（旧存档没有职业时默认给勘探者，保证技能树可用）
func restore_from_save(data: Dictionary) -> void:
	class_id = str(data.get("class_id", ""))
	if class_id == "":
		class_id = "scout"
	skill_points = int(data.get("skill_points", 0))
	var levels: Dictionary = data.get("skill_levels", {})
	skill_levels = (levels as Dictionary).duplicate()
	_regular_kills = 0
	changed.emit()
