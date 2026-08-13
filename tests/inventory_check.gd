extends SceneTree
## 背包验收脚本：16 格限制、堆叠、扣除、旧存档迁移、满包掉落、死亡掉落包部分拾取、存档往返、HUD 面板
## 运行：godot --headless --path . --script res://tests/inventory_check.gd
## 结果写入 res://tests/inventory_report.txt

const REPORT_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/inventory_report.txt"
const SAVE_PATH := "user://inventory_check_save.json"

var _frames := 0
var _world: Node = null
var _log := ""
var _fail := 0


func _initialize() -> void:
	_log = "== 背包系统检测（%s）==\n" % Time.get_datetime_string_from_system()


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
	var inv: Node = root.get_node("Inventory")
	var sm: Node = root.get_node("SaveManager")
	inv.clear_all()

	_log += "== 1. 16 格上限与堆叠 ==\n"
	var types := ["wood", "stone", "iron", "parts", "darkstone", "frost_crystal", "ember", "rad_dust",
		"gear", "swamp_herb", "gem", "sky_crystal", "salt_crystal", "thunder_crystal", "glow_shroom", "spore"]
	var all_ok := true
	for t in types:
		if not inv.add_item(t, 1):
			all_ok = false
	_check(all_ok, "16 种不同物品全部放入")
	_check(inv.filled_slots() == 16, "占满 16 格")
	_check(not inv.add_item("bone", 1), "第 17 种物品被拒绝")
	_check(inv.filled_slots() == 16 and inv.get_count("bone") == 0, "拒绝后格子数不变")
	_check(inv.add_item("wood", 5), "同类物品可继续堆叠")
	_check(inv.get_count("wood") == 6 and inv.filled_slots() == 16, "堆叠不占新格子")
	_check(inv.can_add("wood") and not inv.can_add("bone"), "can_add 判定正确")

	_log += "== 2. 扣除与空格回收 ==\n"
	inv.spend_item("wood", 4)
	_check(inv.get_count("wood") == 2 and inv.filled_slots() == 16, "部分扣除保留格子")
	inv.spend_item("wood", 2)
	_check(inv.get_count("wood") == 0 and inv.filled_slots() == 15, "清空后格子回收")
	_check(not inv.spend_item("wood", 1), "数量不足拒绝扣除")

	_log += "== 3. 旧存档迁移与新格式恢复 ==\n"
	inv.clear_all()
	inv.items = {"wood": 3, "stone": 2}
	inv.restore_backpack([])
	_check(inv.filled_slots() == 2 and inv.get_count("wood") == 3, "旧存档 items 字典迁移到 16 格")
	var new_data := []
	for i in 16:
		new_data.append("" if i % 2 == 0 else {"id": "gem", "count": i})
	inv.restore_backpack(new_data)
	_check(inv.filled_slots() == 8 and inv.get_count("gem") == 1 + 3 + 5 + 7 + 9 + 11 + 13 + 15, "新格式 16 格精确还原")

	_log += "== 4. 满包掉落与死亡掉落包部分拾取 ==\n"
	inv.clear_all()
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	_world = world_scene.instantiate()
	root.add_child(_world)
	current_scene = _world
	var pos := Vector2(3200, 2400)
	inv.drop_on_ground("gem", 2, pos)
	var gem_on_ground := 0
	for r in get_nodes_in_group("resource_nodes"):
		if r.resource_id == "gem" and r.global_position.distance_to(pos) < 1.0:
			gem_on_ground += 1
	_check(gem_on_ground >= 1, "满包兜底：物品掉在地上成为资源点")
	inv.clear_all()
	for t in types:
		inv.add_item(t, 1)
	var bag := load("res://scenes/death_bag.tscn") as PackedScene
	var bag_node: Node2D = bag.instantiate()
	bag_node.items = {"bone": 1, "rune_stone": 1}
	_world.add_child(bag_node)
	bag_node.pick_up()
	_check(bag_node.is_inside_tree() and bag_node.items.has("bone"), "背包满时掉落包保留未装下的物品")
	inv.spend_item("spore", 1)
	inv.spend_item("glow_shroom", 1)
	bag_node.pick_up()
	_check(bag_node.is_queued_for_deletion(), "腾出格子后可全部捡回（已排入销毁）")

	_log += "== 5. 存档往返（16 格 + 装备栏） ==\n"
	inv.clear_all()
	inv.add_item("wood", 5)
	inv.add_item("stone_axe", 1)
	inv.hotbar[0] = "stone_axe"
	inv.equipped = "stone_axe"
	sm._save_to(SAVE_PATH)
	inv.clear_all()
	sm.load_game_from(SAVE_PATH, false)
	_check(inv.get_count("wood") == 5 and inv.get_count("stone_axe") == 1, "读档恢复物品")
	_check(inv.hotbar[0] == "stone_axe" and inv.equipped == "stone_axe", "读档恢复装备栏")
	_check(inv.filled_slots() == 2, "读档后格子数正确")

	_log += "== 6. HUD：平时只显示格数，按 I 打开显示全部 ==\n"
	var hud := _world.get_node("HUD")
	hud._refresh()
	_check(hud._label.text.contains("背包 2/16"), "顶部只显示摘要（%s）" % hud._label.text)
	hud._toggle_backpack()
	_check(hud._backpack_panel.visible, "按 I 打开背包面板")
	var grid: Node = hud._backpack_panel.get_node("VBox/Grid")
	_check(grid.get_child_count() == 16, "背包面板 16 格")
	var has_item_text := false
	for child in grid.get_children():
		if str(child.text).contains("木材") or str(child.text).contains("石斧"):
			has_item_text = true
	_check(has_item_text, "面板里完整显示物品名与数量")
	hud._toggle_backpack()
	_check(not hud._backpack_panel.visible, "再按 I 关闭背包")
	inv.clear_all()
	_log += "== 检测结束：失败 %d 项 ==\n" % _fail


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_log)
		file.close()
