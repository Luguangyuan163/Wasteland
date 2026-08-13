extends Node
## 存档管理器（第八课）：保存/读取游戏状态到 user://save.json
## 对应计划表：P1 第 8 周「存档/读档：场景、背包、基地」
## F5 保存，F9 读取；user:// 是 Godot 分配的用户数据目录，不用管路径在哪

const SAVE_PATH := "user://save.json"
const TRANSIT_PATH := "user://transition.json"  # 进出地心世界的过渡存档（不干扰手动存档）
const BUILDABLE_SCENE := preload("res://scenes/buildable.tscn")
const BUILDABLE_SCRIPT := preload("res://scripts/buildable.gd")
const DEATH_BAG_SCENE := preload("res://scenes/death_bag.tscn")

signal toast(text: String)  # 通知 HUD 显示提示

var _pending_path := ""  # 等待新场景在 _ready 里继续的读档文件
var _pending_keep_inventory := false


func _unhandled_input(event: InputEvent) -> void:
	# 直接判断键码，不依赖输入映射，更稳（F5/F9）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F5:
			save_game()
		elif event.physical_keycode == KEY_F9:
			load_game()


## 收集当前游戏状态并写入存档文件
func save_game() -> void:
	_save_to(SAVE_PATH)


func _save_to(path: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return  # 死亡读秒时不让存档，避免存下一个半死状态
	var data := {
		"version": 1,
		"scene": get_tree().current_scene.scene_file_path,
		"map_seed": _map_seed(),
		"resources": _collect_resources(),
		"pipes": _collect_pipes(),
		"player": {
			"position": [player.global_position.x, player.global_position.y],
			"hp": player.hp,
		},
		"inventory": {
			"items": Inventory.items.duplicate(),
			"equipped": Inventory.equipped,
			"hotbar": Inventory.hotbar.duplicate(),
		},
		"class": PlayerClass.to_save(),
		"buildables": _collect_buildables(),
		"death_bags": _collect_death_bags(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	toast.emit("已保存")
	AudioManager.play_sfx("save")


## 进入地心世界：先记录地表状态，再切换场景
func enter_underworld() -> void:
	_save_to(TRANSIT_PATH)
	get_tree().change_scene_to_file("res://scenes/underworld.tscn")


## 从地心返回地表：切回场景，由地表 _ready 恢复（保留地心收获）
func return_to_surface() -> void:
	_pending_path = TRANSIT_PATH
	_pending_keep_inventory = true
	get_tree().change_scene_to_file("res://scenes/world.tscn")


## 新场景加载完成后调用：有待处理的读档则返回信息，否则返回空字典
func consume_pending_load() -> Dictionary:
	if _pending_path.is_empty():
		return {}
	var info := {"path": _pending_path, "keep_inventory": _pending_keep_inventory}
	_pending_path = ""
	_pending_keep_inventory = false
	return info


## 把场上所有建筑的位置和类型收集成数组
func _collect_buildables() -> Array:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("buildables"):
		list.append({
			"type": String(node.get("type")),
			"x": node.global_position.x,
			"y": node.global_position.y,
		})
	return list


## 收集场上所有死亡掉落包（位置 + 里面的物品）
func _collect_death_bags() -> Array:
	var list: Array = []
	for bag in get_tree().get_nodes_in_group("death_bags"):
		list.append({
			"x": bag.global_position.x,
			"y": bag.global_position.y,
			"items": bag.items.duplicate(),
		})
	return list


## 读取存档并应用到当前场景
func load_game(keep_inventory: bool = false) -> void:
	load_game_from(SAVE_PATH, keep_inventory)


func load_game_from(path: String, keep_inventory: bool) -> void:
	if not FileAccess.file_exists(path):
		toast.emit("没有存档")
		AudioManager.play_sfx("ui_close")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		toast.emit("存档损坏，无法读取")
		return
	# 存档记录的是另一个世界：先切场景，再由新场景在 _ready 里继续读档
	var target: String = data.get("scene", "res://scenes/world.tscn")
	var current_path := get_tree().current_scene.scene_file_path
	if current_path != target:
		_pending_path = path
		_pending_keep_inventory = keep_inventory
		get_tree().change_scene_to_file(target)
		return
	_apply_load(data, keep_inventory)


func _apply_load(data: Variant, keep_inventory: bool) -> void:
	# 地图：用存档种子重建（含资源状态），保证读档后还是同一张图
	var world = get_tree().current_scene
	if world != null and world.has_method("generate"):
		world.generate(int(data.get("map_seed", 0)), data.get("resources", []), data.get("pipes", []))
	# 先清掉当前场上的敌人和建筑，再按存档重建
	_clear_entities()
	# 背包与装备
	if not keep_inventory:  # 从地心返回时保留背包里的收获
		Inventory.items = (data.inventory.items as Dictionary).duplicate()
		Inventory.equipped = data.inventory.equipped
		Inventory.hotbar = (data.inventory.get("hotbar", ["", "", "", "", ""]) as Array).duplicate()
		Inventory.equipped_slot = Inventory.hotbar.find(Inventory.equipped)
		if Inventory.equipped_slot < 0:
			Inventory.equipped_slot = 0
		Inventory.changed.emit()
		Inventory.equipped_changed.emit()
		Inventory.hotbar_changed.emit()
	# 职业与技能树（P3）：读档恢复，旧存档默认给勘探者
	PlayerClass.restore_from_save(data.get("class", {}))
	# 玩家：位置、生命（最低保留 1，避免读档即死亡）
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var pos: Array = data.player.position
		player.global_position = Vector2(pos[0], pos[1])
		player.hp = maxi(1, int(data.player.hp))
		player.dead = false
		player.modulate = Color(1, 1, 1)
		player.health_changed.emit()
	# 建筑
	for b in data.buildables:
		_spawn_buildable(b)
	# 死亡掉落包
	for b in data.get("death_bags", []):
		_spawn_death_bag(b)
	toast.emit("已读取存档")
	AudioManager.play_sfx("load")


func _map_seed() -> int:
	var world = get_tree().current_scene
	if world == null or not world.has_method("generate"):
		return 0
	return world.map_seed


## 收集场上还活着的资源点（位置/类型/数量），读档时按它恢复，采过的不会复活
func _collect_resources() -> Array:
	var list: Array = []
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		list.append({
			"id": node.resource_id,
			"amount": node.amount,
			"x": node.global_position.x,
			"y": node.global_position.y,
		})
	return list


## 收集能量管道的接通状态，读档后恢复（已解决的谜题不会重置）
func _collect_pipes() -> Array:
	var list: Array = []
	for pipe in get_tree().get_nodes_in_group("power_pipes"):
		list.append(pipe.connected)
	return list


## 清掉场上现有的敌人和建筑，避免和存档内容叠加
func _clear_entities() -> void:
	for node in get_tree().get_nodes_in_group("buildables"):
		node.queue_free()
	for bag in get_tree().get_nodes_in_group("death_bags"):
		bag.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()


## 按类型重新生成一个建筑（和工作台这种"专用场景"也兼容）
func _spawn_buildable(b: Variant) -> void:
	var type: String = b.type
	var scene: PackedScene = BUILDABLE_SCRIPT.BLUEPRINTS[type].get("scene", BUILDABLE_SCENE)
	var node: Node2D = scene.instantiate()
	if node.get("type") != null:
		node.type = type
	node.global_position = Vector2(b.x, b.y)
	get_tree().current_scene.add_child(node)


## 按存档恢复一个死亡掉落包
func _spawn_death_bag(b: Variant) -> void:
	var bag: Node2D = DEATH_BAG_SCENE.instantiate()
	bag.items = (b.items as Dictionary).duplicate()
	bag.global_position = Vector2(b.x, b.y)
	get_tree().current_scene.add_child(bag)
