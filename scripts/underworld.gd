extends Node2D
## 地心世界（黑暗群系）：独立小地图，整图黑暗，有暗石资源、尖刺陷阱和地心怪物
## 每次进入重新生成（随机种子），带回的暗石等资源保留在背包

const MAP_W := 30
const MAP_H := 24
const TILE_SIZE := 32.0

const TILE_SET := preload("res://assets/tiles/ground_tiles.tres")
const RESOURCE_SCENE := preload("res://scenes/resource_node.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const TRAP_SCENE := preload("res://scenes/trap.tscn")
const PORTAL_SCENE := preload("res://scenes/portal.tscn")

const GRASS_TILE := Vector2i(0, 0)
const MUD_TILE := Vector2i(1, 0)
const STONE_TILE := Vector2i(0, 1)

const SPAWN_CELL := Vector2i(15, 12)  # 地心入口/出生点
const HUB_CENTER := Vector2i(15, 4)   # 地心怪物聚集地（大 Boss 固定刷新）
const HUB_RADIUS := 3

var map_seed := 0
var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer = null


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = TILE_SET
	_ground.z_index = -10
	add_child(_ground)
	# 地心世界整图黑暗：调暗 + 玩家光照常开
	get_node("CanvasModulate").color = Color(0.03, 0.03, 0.05)
	var player = get_node("Player")
	player.get_node("PointLight2D").energy = 1.0
	player.get_node("Camera2D").limit_right = MAP_W * TILE_SIZE
	player.get_node("Camera2D").limit_bottom = MAP_H * TILE_SIZE
	generate(randi())
	# 地心环境音：更低沉、带心跳脉冲（第十二课）
	AudioManager.set_ambient("underworld")
	TutorialHints.show_first_time("underworld", "地心世界：更黑暗、怪物更强；找到发光传送门按 E 返回地表")
	# 从地表传送进来（无待处理读档）或读档回到地心时恢复状态
	var info := SaveManager.consume_pending_load()
	if not info.is_empty():
		SaveManager.load_game_from(info.path, info.keep_inventory)


func generate(seed_value: int, saved_resources: Array = [], _saved_pipes: Array = []) -> void:
	map_seed = seed_value
	_rng.seed = seed_value
	_build_tiles()
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.free()
	for node in get_tree().get_nodes_in_group("traps"):
		node.free()
	for node in get_tree().get_nodes_in_group("portals"):
		node.free()
	if saved_resources.is_empty():
		_spawn_resources()
	else:
		_spawn_saved_resources(saved_resources)
	_build_traps()
	_build_return_portal()
	_build_boss_hub()


func _build_tiles() -> void:
	_ground.clear()
	for x in MAP_W:
		for y in MAP_H:
			var is_border := x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1
			_ground.set_cell(Vector2i(x, y), 0, STONE_TILE if is_border else GRASS_TILE)
	# 随机泥地/石头块，制造地下环境起伏
	for i in 5:
		var cx := _rng.randi_range(3, MAP_W - 4)
		var cy := _rng.randi_range(3, MAP_H - 4)
		var radius := _rng.randi_range(2, 3)
		var tile: Vector2i = MUD_TILE if _rng.randf() < 0.7 else STONE_TILE
		for x in range(cx - radius, cx + radius + 1):
			for y in range(cy - radius, cy + radius + 1):
				if Vector2(x - cx, y - cy).length() <= radius and _rng.randf() < 0.6:
					_ground.set_cell(Vector2i(x, y), 0, tile)
	# 出生点周围草地
	for x in range(SPAWN_CELL.x - 2, SPAWN_CELL.x + 3):
		for y in range(SPAWN_CELL.y - 2, SPAWN_CELL.y + 3):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)


func _spawn_resources() -> void:
	for i in 10:
		_spawn_resource(_random_clear_cell(), "darkstone", "暗石", 2, 4, Color(0.45, 0.3, 0.6))


func _spawn_saved_resources(saved: Array) -> void:
	for r in saved:
		var node: Node2D = RESOURCE_SCENE.instantiate()
		node.resource_id = r.id
		node.resource_name = "暗石"
		node.amount = r.amount
		node.color = Color(0.45, 0.3, 0.6)
		node.global_position = Vector2(r.x, r.y)
		add_child(node)


func _build_traps() -> void:
	for i in 4:
		var trap: Area2D = TRAP_SCENE.instantiate()
		trap.global_position = Vector2(_random_clear_cell()) * TILE_SIZE + Vector2(16, 16)
		add_child(trap)


func _build_return_portal() -> void:
	var portal: Node2D = PORTAL_SCENE.instantiate()
	portal.target_scene = "res://scenes/world.tscn"
	portal.hint_text = "按 E 返回地表"
	portal.global_position = Vector2(SPAWN_CELL.x * TILE_SIZE + 16, (SPAWN_CELL.y + 2) * TILE_SIZE + 16)
	add_child(portal)


## 地心怪物聚集地：地心领主固定刷新，带精英和普通守卫
func _build_boss_hub() -> void:
	for x in range(HUB_CENTER.x - HUB_RADIUS, HUB_CENTER.x + HUB_RADIUS + 1):
		for y in range(HUB_CENTER.y - HUB_RADIUS, HUB_CENTER.y + HUB_RADIUS + 1):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)
	var marker := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(Vector2(HUB_CENTER) * TILE_SIZE + Vector2(16, 16) + Vector2(cos(a), sin(a)) * ((HUB_RADIUS + 0.5) * TILE_SIZE))
	marker.polygon = points
	marker.color = Color(0.7, 0.15, 0.15, 0.35)
	marker.z_index = -1
	marker.add_to_group("hub_markers")
	add_child(marker)
	_spawn_enemy_node("deep_lord", HUB_CENTER + Vector2i(0, 0))
	_spawn_enemy_node("deep_elite", HUB_CENTER + Vector2i(2, 0))
	_spawn_enemy_node("dark", HUB_CENTER + Vector2i(-2, 0))
	_spawn_enemy_node("dark", HUB_CENTER + Vector2i(0, 2))


func _spawn_enemy_node(type: String, cell: Vector2i) -> void:
	var enemy: Node2D = ENEMY_SCENE.instantiate()
	enemy.enemy_type = type
	enemy.global_position = Vector2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16)
	add_child(enemy)


func _random_clear_cell() -> Vector2i:
	for i in 50:
		var cell := Vector2i(_rng.randi_range(1, MAP_W - 2), _rng.randi_range(1, MAP_H - 2))
		if Vector2(cell - SPAWN_CELL).length() < 3.0:
			continue
		var atlas := _ground.get_cell_atlas_coords(cell)
		if atlas == STONE_TILE:
			continue
		return cell
	return SPAWN_CELL + Vector2i(4, 0)


func _spawn_resource(cell: Vector2i, id: String, display_name: String, min_amt: int, max_amt: int, color: Color) -> void:
	if cell.x <= 0 or cell.y <= 0 or cell.x >= MAP_W - 1 or cell.y >= MAP_H - 1:
		return
	var node: Node2D = RESOURCE_SCENE.instantiate()
	node.resource_id = id
	node.resource_name = display_name
	node.amount = _rng.randi_range(min_amt, max_amt)
	node.color = color
	node.global_position = Vector2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16)
	add_child(node)
