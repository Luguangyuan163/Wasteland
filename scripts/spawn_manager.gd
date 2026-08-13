extends Node2D
## 探索刷怪（第十一周改版 + 渐进式刷怪 2026-08-10）：玩家探索时在周围随机补怪
## 群系难度（difficulty）：地表=1、地心=3、暗域之城=2（biome_aware 模式按所在群系实时调整）。难度越高：
##   - 刷怪上限越高（spawn_cap × difficulty，上限取整）
##   - 刷新间隔越短（check_interval ÷ difficulty）
##   - 精英/首领混入概率越高（× difficulty，分别封顶 0.40 / 0.25）
## 刷怪上限：玩家视野/光照范围内最多 spawn_cap 只；玩家进入怪物聚集地时上限提高到 hub_cap
## 每个群系配置自己的普通怪池 + 小 boss + 大 boss（小概率混入） 
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const TILE_SIZE := 32.0
const MIN_COUNT_RADIUS := 480.0  # 统计范围下限：必须覆盖 220~420 的刷怪带，避免黑暗群系在光照外无限堆积
const SPAWN_MIN_DIST := 160.0     # 刷怪离玩家的最小距离（px），避免"突然刷在身后"
const CLUSTER_MIN := 2            # 集群刷怪：最少几只
const CLUSTER_MAX := 4            # 集群刷怪：最多几只
const CLUSTER_RADIUS := 64.0      # 同一集群内怪物散布半径（px）
const LIGHT_THRESHOLD := 7        # MC 式光照门槛：亮度 < 7 才能刷怪（0=全黑, 15=全亮）
const GRACE_DURATION := 120.0     # 开局安全期（秒）：出生后这段时间完全不刷怪，给玩家发育/探索时间
@export var normal_types: Array[String] = ["goblin", "walker", "runner"]
@export var mini_boss_type := "brute"
@export var elite_type := "elite"  # 本群系精英怪
@export var map_width := 200  # 地表大世界=200×150（地心等传送世界单独配置）
@export var map_height := 150
@export var difficulty := 1.0        # 群系难度：地表=1、地心=3、暗域之城=2（预留）
@export var spawn_cap := 10          # 玩家视野/光照范围内最多保留的怪物数
@export var hub_cap := 100           # 玩家在怪物聚集地时的刷怪上限
@export var hub_center := Vector2.ZERO  # 本群系聚集地中心（world/underworld 各自配置）
@export var hub_radius := 128.0      # 距聚集地中心多少像素内算“处于聚集地”
@export var check_interval := 3.0    # 地表基准：每隔多久检查补怪
@export var spawn_radius_min := 220.0
@export var spawn_radius_max := 420.0
@export var mini_boss_chance := 0.06  # 地表基准：首领混入概率
@export var elite_chance := 0.10      # 地表基准：精英混入概率
@export var require_darkness := true  ## MC 式光照规则：true=只在黑暗处刷怪（地表）  false=全图刷怪（地心） 
@export var biome_aware := false  ## true=按所在群系动态调整难度/怪池（地表大世界）；false=固定用本场景配置（地心）
@export var grace_duration := GRACE_DURATION  ## 开局安全期时长（秒），0=关闭
@export var spawn_safe_center := Vector2.ZERO  ## 出生点安全区中心（px；地表世界由 map_generator 同步，ZERO=关闭）
@export var spawn_safe_radius := 480.0         ## 出生点安全区半径（px），安全区内永不刷怪
var _timer := 0.0
var _elapsed := 0.0
var _grace_done := false
var _effective_cap := 10        # 按难度换算后的上限
var _effective_interval := 3.0  # 按难度换算后的检查间隔
var _mini_boss_chance := 0.06   # 按难度换算后的首领概率
var _elite_chance := 0.10       # 按难度换算后的精英概率 

func _ready() -> void:
	# 渐进式刷怪：上限、间隔、精英/首领概率全部按群系难度换算
	_effective_cap = int(round(spawn_cap * difficulty))
	_effective_interval = check_interval / difficulty
	_mini_boss_chance = minf(mini_boss_chance * difficulty, 0.25)
	_elite_chance = minf(elite_chance * difficulty, 0.40)
	if grace_duration > 0.0:
		SaveManager.toast.emit("开局安全期 %d 秒：出生点附近不会刷怪，先采集资源发育" % int(grace_duration))


func _physics_process(delta: float) -> void:
	# 开局安全期：前 grace_duration 秒完全不刷怪（玩家有充足时间发育/探索）
	_elapsed += delta
	if not _grace_done:
		if _elapsed < grace_duration:
			return
		_grace_done = true
	_timer += delta
	if _timer < _current_interval():
		return
	_timer = 0.0
	_replenish()


## 当前刷新间隔：biome_aware 模式按玩家所在群系难度换算，否则用场景配置
func _current_interval() -> float:
	if not biome_aware:
		return _effective_interval
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return _effective_interval
	return check_interval / _difficulty_at(player.global_position)


## 玩家视野/光照范围内怪物少于上限时，以集群方式补足
## 新增（2026-08-10）：MC 式光照门槛 —— 地表明亮处不刷怪
## 新增（2026-08-10）：集群刷怪 —— 每次生成 2~4 只同类型的怪物群
func _replenish() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var alive := 0
	var count_radius := maxf(player.get_vision_radius(), MIN_COUNT_RADIUS)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player.global_position) <= count_radius:
			alive += 1
	var cap := _current_cap(player)
	if alive >= cap:
		return
	# 集群刷怪：计算还需补多少，每次生成 2~4 只
	var needed := cap - alive
	while needed > 0:
		var cluster_size := mini(needed, randi_range(CLUSTER_MIN, CLUSTER_MAX))
		# 找一个满足光照条件的合法位置
		var center := _pick_dark_spawn_position(player)
		if center == Vector2.ZERO:
			break  # 找不到暗处就停止（MC 规则：不强行在亮处刷）
		_spawn_cluster(player, cluster_size, center)
		needed -= cluster_size


## 当前刷怪上限：玩家处于怪物聚集地内用 hub_cap，否则用 spawn_cap
func _current_cap(player) -> int:
	if hub_center != Vector2.ZERO and player.global_position.distance_to(hub_center) <= hub_radius:
		return hub_cap
	if biome_aware:
		return int(round(spawn_cap * _difficulty_at(player.global_position)))
	return _effective_cap


## 旧版逐只生成（保留为兜底，集群刷怪失败时降级使用）
func _spawn_one(player) -> void:
	var enemy: Node2D = ENEMY_SCENE.instantiate()
	enemy.enemy_type = _pick_type()
	enemy.global_position = _pick_spawn_position(player.global_position)
	get_parent().add_child(enemy)


## 集群刷怪：在 center 周围散布 count 只同类型怪物
## 参照 MC 的 pack spawn —— 玩家遇到"一群哥布林"每 又是一只 更有战斗节奏
func _spawn_cluster(_player, count: int, center: Vector2) -> void:
	var monster_type := _pick_type_for_position(center)
	for i in count:
		var enemy: Node2D = ENEMY_SCENE.instantiate()
		enemy.enemy_type = monster_type
		# 群内随机偏移，让它们自然散开而非叠在一起
		var offset := Vector2(randf_range(-CLUSTER_RADIUS, CLUSTER_RADIUS), randf_range(-CLUSTER_RADIUS, CLUSTER_RADIUS))
		var pos := center + offset
		pos.x = clampf(pos.x, 16.0, map_width * TILE_SIZE - 16.0)
		pos.y = clampf(pos.y, 16.0, map_height * TILE_SIZE - 16.0)
		if _is_clear(pos):
			enemy.global_position = pos
		else:
			enemy.global_position = center  # 被挡就放集群中心
		get_parent().add_child(enemy)


## 从父节点（World / map_generator）获取地图种子
func _get_map_seed() -> int:
	var parent := get_parent()
	if parent != null and parent.get("map_seed") != null:
		return parent.map_seed
	return 0


## MC 式光照检测：计算某点的光照等级（0=全黑, 15=全亮）
## 怪物只能在亮度 < LIGHT_THRESHOLD 的区域生成
## 为什么这样做：参照 MC 核心规则 —— 地表明亮 = 安全，室内/废墟/地心 = 危险
func _light_level_at(pos: Vector2) -> int:
	# 1. 先查群系：暗域废墟 always dark
	var biome: Dictionary = BiomeDefs.get_biome_def_at(pos, _get_map_seed())
	if biome.get("is_dark", false):
		return 0  # 全黑 → 必定刷怪
	# 2. require_darkness=false（地心世界）→ 始终视为暗
	if not require_darkness:
		return 0
	# 3. 检查是否在建造物"屋顶"下（玩家建造的墙/地板 = 室内 = 暗区）
	for buildable in get_tree().get_nodes_in_group("buildables"):
		if pos.distance_to(buildable.global_position) < 64.0:
			return 5  # 建筑物附近视为暗区（低于阈值 7）
	# 4. 默认：地表明亮 = 不刷怪
	return 15


## 找一个光照等级低于刷怪阈值 + 可通行 + 有视线的位置
## 找不到则返回 Vector2.ZERO（调用方跳过本次刷怪）
func _pick_dark_spawn_position(player) -> Vector2:
	for attempt in 40:
		var pos := _random_pos(player.global_position)
		if pos.distance_to(player.global_position) < SPAWN_MIN_DIST:
			continue
		if _in_spawn_safe_zone(pos):
			continue
		if not _is_clear(pos):
			continue
		if _light_level_at(pos) >= LIGHT_THRESHOLD:
			continue  # 太亮 → MC 规则不刷
		if not _has_los_between(pos, player.global_position):
			continue
		return pos
	# 降级：不要求视线（建筑拐角等视野盲区也接受）
	for attempt in 20:
		var pos := _random_pos(player.global_position)
		if pos.distance_to(player.global_position) < SPAWN_MIN_DIST:
			continue
		if _in_spawn_safe_zone(pos):
			continue
		if not _is_clear(pos):
			continue
		if _light_level_at(pos) >= LIGHT_THRESHOLD:
			continue
		return pos
	return Vector2.ZERO  # 彻底找不到暗处 → 不刷怪 

## 按刷怪位置的群系选怪物类型（替代旧 _pick_type 的写死数组）
## 为什么群系感知：不同群系有不同怪物池，石丘精英多、林地疾行者多
func _pick_type_for_position(pos: Vector2) -> String:
	var biome: Dictionary = BiomeDefs.get_biome_def_at(pos, _get_map_seed())
	if not biome_aware:
		# 地心等固定配置场景：用本场景导出的怪物池 + 场景难度换算后的概率
		var r0 := randf()
		if r0 < _mini_boss_chance:
			return mini_boss_type
		if r0 < _mini_boss_chance + _elite_chance:
			return elite_type
		return normal_types[randi() % normal_types.size()]
	var normal: Array = biome.get("normal_types", normal_types)
	var mini_boss: String = biome.get("mini_boss", mini_boss_type)
	var elite: String = biome.get("elite", elite_type)
	# 概率判定（沿用现有难度换算后的概率值）
	# 概率再按所在群系难度缩放（地表 1~1.2，暗域之城 2）
	var biome_diff: float = biome.get("difficulty", difficulty)
	var mini := minf(_mini_boss_chance * biome_diff, 0.25)
	var el := minf(_elite_chance * biome_diff, 0.40)
	var r := randf()
	if r < mini:
		return mini_boss
	if r < mini + el:
		return elite
	return normal[randi() % normal.size()]


## 某位置对应的群系难度（biome_aware 模式），否则返回场景难度
func _difficulty_at(pos: Vector2) -> float:
	if not biome_aware:
		return difficulty
	var biome: Dictionary = BiomeDefs.get_biome_def_at(pos, _get_map_seed())
	return biome.get("difficulty", difficulty)


## 旧版 _pick_type：保留为兜底（当无法获取 map_seed 时使用）
func _pick_type() -> String:
	var r := randf()
	if r < _mini_boss_chance:
		return mini_boss_type
	if r < _mini_boss_chance + _elite_chance:
		return elite_type
	return normal_types[randi() % normal_types.size()]


## 在玩家周围随机挑可通行且看得见玩家的位置（边缘 clamp 后校验最小距离）
func _pick_spawn_position(center: Vector2) -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	for i in 40:
		var pos := _random_pos(center)
		if pos.distance_to(center) >= SPAWN_MIN_DIST and not _in_spawn_safe_zone(pos) and _is_clear(pos) and (player == null or _has_los_between(pos, player.global_position)):
			return pos
	for i in 40:
		var pos := _random_pos(center)
		if pos.distance_to(center) >= SPAWN_MIN_DIST and not _in_spawn_safe_zone(pos) and _is_clear(pos):
			return pos
	return center + Vector2(spawn_radius_min, 0.0)


## 出生点安全区：地图生成器把出生点中心同步到这里，安全区内永不刷怪
func _in_spawn_safe_zone(pos: Vector2) -> bool:
	return spawn_safe_center != Vector2.ZERO and spawn_safe_radius > 0.0 \
		and pos.distance_to(spawn_safe_center) <= spawn_safe_radius


func _random_pos(center: Vector2) -> Vector2:
	var angle := randf() * TAU
	var dist := randf_range(spawn_radius_min, spawn_radius_max)
	var pos := center + Vector2.from_angle(angle) * dist
	pos.x = clampf(pos.x, 16.0, map_width * TILE_SIZE - 16.0)
	pos.y = clampf(pos.y, 16.0, map_height * TILE_SIZE - 16.0)
	return pos


func _has_los_between(from: Vector2, to: Vector2) -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return true
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [player.get_rid()]
	return space.intersect_ray(query).is_empty()


func _is_clear(pos: Vector2) -> bool:
	for layer in get_parent().get_children():
		if layer is TileMapLayer:
			var coords: Vector2i = layer.local_to_map(layer.to_local(pos))
			if layer.get_cell_source_id(coords) == -1:
				continue
			var data: TileData = layer.get_cell_tile_data(coords)
			if data != null and data.get_collision_polygons_count(0) > 0:
				return false
	return true
