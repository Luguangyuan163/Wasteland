extends Node2D
## 随机地图生成器 v5（中枢 + 放射环带，2026-08-11）
## 布局：普通地表 = 地图中心椭圆"安全大陆"，8 个群系按方位环绕（西北沼泽/西冰脉/
## 西南爆炎/南机械/东南暗域/东辐射/东北峡谷/北天空岛），天空岛外圈有"环岛湖"。
## 参照《我的世界》《泰拉瑞亚》《饥荒》+ GitHub RPG 地图生成器的多 pass 生成：
##   地形（区域图+噪声）→ 群系结构 → 散落装饰 → 出生点安全区 → 结构模板 → 路网
## 路网 = 星形拓扑：出生点→谜题→聚集地→传送门（世界枢纽），再从传送门放射 8 条
## 支线直通各群系大Boss巢穴正门，玩家从出生点能直接选方向探索任何群系。
## 每次开局用随机种子生成一张 200×150 地图；存档记录种子，读档可还原同一张图
## 黑暗群系在“地心世界”（独立场景），地表是正常亮度，刷一个通往地心的传送门

const MAP_W := 200  # 大世界地图：200×150 = 30000 格，是旧图 40×30 的 25 倍（满足“至少 20 倍”）
const MAP_H := 150
const TILE_SIZE := 32.0
const BORDER_WIDTH := 3          # 自然边界宽度：最外 3 格是“废墟碎石带”
const SPAWN_SAFE_RADIUS := 8     # 出生点安全区半径（格）：出生营地，玩家先发育

const TILE_SET := preload("res://assets/tiles/ground_tiles.tres")
const RESOURCE_SCENE := preload("res://scenes/resource_node.tscn")
const DOOR_SCENE := preload("res://scenes/door.tscn")
const PLATE_SCENE := preload("res://scenes/pressure_plate.tscn")
const PIPE_SCENE := preload("res://scenes/power_pipe.tscn")
const KEYPAD_SCENE := preload("res://scenes/keypad_lock.tscn")
const RELIC_SCENE := preload("res://scenes/relic_device.tscn")
const ALTAR_SCENE := preload("res://scenes/twin_altar.tscn")
const PORTAL_SCENE := preload("res://scenes/portal.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const WORKBENCH_SCENE := preload("res://scenes/workbench.tscn")

const GRASS_TILE := Vector2i(0, 0)   # 草地（可通行）
const MUD_TILE := Vector2i(1, 0)     # 泥地（可通行）
const STONE_TILE := Vector2i(0, 1)   # 石头（有碰撞，挡路）
const WATER_TILE := Vector2i(1, 1)   # 水（装饰，v1 可通行）
const ICE_TILE := Vector2i(2, 0)     # 冰面（极寒冰脉）
const SNOW_TILE := Vector2i(3, 0)    # 雪地（极寒冰脉）
const LAVA_TILE := Vector2i(2, 1)    # 岩浆（爆炎之城）
const SCORCH_TILE := Vector2i(3, 1)  # 焦岩（爆炎之城）
const RAD_TILE := Vector2i(0, 2)     # 辐射土（辐射荒原）
const TOXIC_TILE := Vector2i(1, 2)   # 毒沼（辐射荒原）
const METAL_TILE := Vector2i(2, 2)   # 金属板（机械废墟）
const RUST_TILE := Vector2i(3, 2)    # 锈蚀铁板（机械废墟）
const SAND_TILE := Vector2i(0, 3)    # 沙地（荒芜沙丘）
const FUNGAL_TILE := Vector2i(1, 3)  # 菌地（真菌孢林）
const RUNE_TILE := Vector2i(2, 3)    # 符文石板（古代遗迹）
const GRAVE_TILE := Vector2i(3, 3)   # 墓土（幽灵墓园）

const SPAWN_CELL := Vector2i(100, 75)  # 出生点所在格（玩家出生在世界中心 (3216,2416)）

## 大世界群系布局（区域图 v5）：总图 200×150 = 30000 格
## 普通地表 ~20%：中心椭圆"安全大陆"（出生点/谜题/聚集地），内部细分废土/林地/石丘
## 8 个群系按方位环绕：西北沼泽 / 西冰脉 / 西南爆炎 / 南机械 / 东南暗域 / 东辐射 / 东北峡谷 / 北天空岛
## 未来群系 ~28%：环带间隙 + 外圈（future_wild 占位，后续群系补齐）
## 区域边界用噪声扰动 + 过渡带避免硬切；天空岛外圈铺"环岛湖"
## 地心等传送进入的世界单独计算尺寸，不占上述比例
## 谜题/聚集地/传送门 = 模板 + 放置规则（参照《饥荒》set pieces 思路，不再写死坐标）
## 压力板密室模板（5×6）：西墙开 3 行门洞，门外 2 格放压力板，西侧 14~17 格放能量管道
const PUZZLE_SIZE := Vector2i(5, 6)
const DOORWAY_OFFSETS := [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(-1, 3), Vector2i(0, 3)]
const PLATE_OFFSET := Vector2i(-2, 2)
const PIPE_OFFSETS := [Vector2i(-17, 4), Vector2i(-16, 4), Vector2i(-15, 4), Vector2i(-14, 4)]

## 解谜扩展（P3）：遗迹密室（密码锁 + 遗迹装置 联动）与双子机关碑（联动谜题 2）
const RELIC_ROOM_SIZE := Vector2i(7, 6)   # 遗迹密室尺寸（含墙）
const RELIC_DOORWAY_OFFSETS := [Vector2i(2, -1), Vector2i(3, -1), Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)]
const RELIC_MIN_DIST := 22.0  # 遗迹密室离出生点距离（格），比压力板谜题更远一点
const RELIC_MAX_DIST := 34.0

## 怪物聚集地模板：7×7 竞技场，大 Boss + 精英守卫
const HUB_RADIUS := 3

## 放置规则（地标间距 / 避让）
const PUZZLE_MIN_DIST := 12.0      # 谜题离出生点的最小/最大距离（格），开局附近就能找到
const PUZZLE_MAX_DIST := 18.0
const HUB_MIN_DIST_FROM_SPAWN := 20.0   # 聚集地放在地表深处，不贴着出生点
const HUB_MIN_DIST_FROM_PUZZLE := 12.0
const PORTAL_MIN_DIST_FROM_HUB := 12.0

const ROAD_TILE := Vector2i(1, 0)  # 泥地 = 废土道路（路网引导探索）
const _DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

## 群系大Boss巢穴模板：15×15 广场，中央 9×9 石墙围城（北墙开 2 格正门），按群系主题装饰
const LAIR_HALF := 7        # 广场半宽（15×15）
const LAIR_KEEP_HALF := 4   # 中央围城半宽（9×9）
const DARK_KEEP_CENTER := Vector2i(150, 120)  # 暗域暴君巢穴中心（与 BiomeDefs.DARK_CENTER 一致）

## 8 个群系大Boss巢穴定义（中心与 biome_defs 区域中心保持一致）
const LAIR_DEFS := [
	{"center": Vector2i(150, 120), "boss": "tyrant", "elite": "dark_elite", "guards": ["husk", "shade"], "floor_a": MUD_TILE, "floor_b": GRASS_TILE, "decor": "water", "treasure": [{"off": Vector2i(0, 3), "id": "parts", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "parts", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "darkstone", "min": 2, "max": 4}]},
	{"center": Vector2i(30, 78), "boss": "frost_lord", "elite": "frost_elite", "guards": ["ice_wolf", "frost_walker"], "floor_a": SNOW_TILE, "floor_b": ICE_TILE, "decor": "ice", "treasure": [{"off": Vector2i(0, 3), "id": "frost_crystal", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "frost_crystal", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(48, 122), "boss": "flame_lord", "elite": "flame_elite", "guards": ["emberling", "cinder_brute"], "floor_a": SCORCH_TILE, "floor_b": LAVA_TILE, "decor": "lava", "treasure": [{"off": Vector2i(0, 3), "id": "ember", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "ember", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(170, 78), "boss": "rad_lord", "elite": "rad_elite", "guards": ["rad_mutant", "rad_crawler"], "floor_a": RAD_TILE, "floor_b": TOXIC_TILE, "decor": "toxic", "treasure": [{"off": Vector2i(0, 3), "id": "rad_dust", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "rad_dust", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(100, 134), "boss": "mech_overlord", "elite": "mech_elite", "guards": ["sentinel", "rust_bot"], "floor_a": METAL_TILE, "floor_b": RUST_TILE, "decor": "metal", "treasure": [{"off": Vector2i(0, 3), "id": "gear", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "gear", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "parts", "min": 1, "max": 2}]},
	{"center": Vector2i(42, 40), "boss": "swamp_lord", "elite": "swamp_elite", "guards": ["frogman", "swamp_slime"], "floor_a": MUD_TILE, "floor_b": WATER_TILE, "decor": "water", "treasure": [{"off": Vector2i(0, 3), "id": "swamp_herb", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "swamp_herb", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "wood", "min": 1, "max": 2}]},
	{"center": Vector2i(158, 40), "boss": "canyon_lord", "elite": "canyon_elite", "guards": ["canyon_lizard", "stone_golem"], "floor_a": STONE_TILE, "floor_b": MUD_TILE, "decor": "rock", "treasure": [{"off": Vector2i(0, 3), "id": "gem", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "gem", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(100, 26), "boss": "sky_dragon", "elite": "sky_elite", "guards": ["harpy", "sky_golem"], "floor_a": GRASS_TILE, "floor_b": WATER_TILE, "decor": "water", "treasure": [{"off": Vector2i(0, 3), "id": "sky_crystal", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "sky_crystal", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(22, 44), "boss": "sand_lord", "elite": "dune_elite", "guards": ["sand_scorpion", "vulture"], "floor_a": SAND_TILE, "floor_b": MUD_TILE, "decor": "rock", "treasure": [{"off": Vector2i(0, 3), "id": "salt_crystal", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "salt_crystal", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "cactus_fiber", "min": 1, "max": 2}]},
	{"center": Vector2i(178, 44), "boss": "storm_lord", "elite": "thunder_elite", "guards": ["thunder_hawk", "arc_golem"], "floor_a": STONE_TILE, "floor_b": SCORCH_TILE, "decor": "rock", "treasure": [{"off": Vector2i(0, 3), "id": "thunder_crystal", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "thunder_crystal", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "stone", "min": 2, "max": 3}]},
	{"center": Vector2i(36, 112), "boss": "fungal_lord", "elite": "fungal_elite", "guards": ["sporeling", "hypno_moth"], "floor_a": FUNGAL_TILE, "floor_b": MUD_TILE, "decor": "water", "treasure": [{"off": Vector2i(0, 3), "id": "glow_shroom", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "glow_shroom", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "spore", "min": 1, "max": 2}]},
	{"center": Vector2i(126, 136), "boss": "relic_lord", "elite": "relic_elite", "guards": ["relic_guard", "gargoyle"], "floor_a": RUNE_TILE, "floor_b": MUD_TILE, "decor": "rock", "treasure": [{"off": Vector2i(0, 3), "id": "rune_stone", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "rune_stone", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "relic", "min": 1, "max": 2}]},
	{"center": Vector2i(168, 110), "boss": "wraith_lord", "elite": "grave_elite", "guards": ["ghost", "bone_guard"], "floor_a": GRAVE_TILE, "floor_b": MUD_TILE, "decor": "rock", "treasure": [{"off": Vector2i(0, 3), "id": "soul_ember", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "soul_ember", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "bone", "min": 1, "max": 2}]},
	{"center": Vector2i(72, 30), "boss": "oasis_lord", "elite": "oasis_elite", "guards": ["oasis_viper", "oasis_mosquito"], "floor_a": GRASS_TILE, "floor_b": WATER_TILE, "decor": "water", "treasure": [{"off": Vector2i(0, 3), "id": "clean_water", "min": 2, "max": 4}, {"off": Vector2i(-1, 3), "id": "clean_water", "min": 2, "max": 4}, {"off": Vector2i(1, 3), "id": "oasis_herb", "min": 1, "max": 2}]},
]

## 资源点元数据：ID → 显示名 / 颜色 / 单次采集量（新增资源在这里登记）
const RESOURCE_META := {
	"wood": {"name": "木材", "color": Color(0.35, 0.65, 0.25), "min": 1, "max": 2},
	"stone": {"name": "石头", "color": Color(0.55, 0.55, 0.55), "min": 2, "max": 3},
	"iron": {"name": "铁矿石", "color": Color(0.4, 0.5, 0.8), "min": 1, "max": 2},
	"darkstone": {"name": "暗石", "color": Color(0.45, 0.3, 0.6), "min": 2, "max": 4},
	"parts": {"name": "零件", "color": Color(0.8, 0.7, 0.35), "min": 1, "max": 3},
	"frost_crystal": {"name": "冰晶", "color": Color(0.65, 0.85, 1.0), "min": 1, "max": 3},
	"ember": {"name": "余烬", "color": Color(1.0, 0.6, 0.15), "min": 1, "max": 3},
	"rad_dust": {"name": "辐射尘", "color": Color(0.55, 0.75, 0.25), "min": 1, "max": 3},
	"gear": {"name": "齿轮", "color": Color(0.6, 0.65, 0.75), "min": 1, "max": 3},
	"swamp_herb": {"name": "沼泽草药", "color": Color(0.45, 0.7, 0.3), "min": 1, "max": 3},
	"gem": {"name": "宝石", "color": Color(1.0, 0.6, 0.8), "min": 1, "max": 3},
	"sky_crystal": {"name": "天空晶石", "color": Color(0.75, 0.9, 1.0), "min": 1, "max": 3},
	"salt_crystal": {"name": "盐晶", "color": Color(0.9, 0.85, 0.7), "min": 1, "max": 3},
	"cactus_fiber": {"name": "仙人掌纤维", "color": Color(0.45, 0.6, 0.3), "min": 1, "max": 2},
	"thunder_crystal": {"name": "雷晶", "color": Color(0.6, 0.65, 1.0), "min": 1, "max": 3},
	"glow_shroom": {"name": "荧光菇", "color": Color(0.7, 0.55, 0.9), "min": 1, "max": 3},
	"spore": {"name": "孢子", "color": Color(0.8, 0.7, 0.9), "min": 1, "max": 2},
	"rune_stone": {"name": "符文石", "color": Color(0.55, 0.7, 0.85), "min": 1, "max": 3},
	"relic": {"name": "古物", "color": Color(0.85, 0.7, 0.45), "min": 1, "max": 2},
	"soul_ember": {"name": "灵魂余烬", "color": Color(0.7, 0.75, 0.95), "min": 1, "max": 3},
	"bone": {"name": "白骨", "color": Color(0.9, 0.9, 0.85), "min": 1, "max": 2},
	"clean_water": {"name": "净水", "color": Color(0.4, 0.75, 0.9), "min": 1, "max": 3},
	"oasis_herb": {"name": "绿洲草药", "color": Color(0.4, 0.75, 0.45), "min": 1, "max": 2},
}

## 本局地标位置（由种子 + 放置规则决定，读档重建时保持一致）
var puzzle_anchor := Vector2i(107, 25)    # 压力板密室左上角（模板锚点）
var puzzle_cells: Array[Vector2i] = []    # 本局谜题占用的所有格（资源/结构避让用）
var portal_cell := Vector2i(106, 15)      # 本局传送门格
var hub_cell := Vector2i(100, 22)         # 本局聚集地中心
var _lair_rects: Array[Rect2i] = []       # 本局所有群系 Boss 巢穴占用的矩形（资源/结构避让用）
var _road_cells_count := 0                # 本局铺了多少格道路（验证用）
var road_cells: Array[Vector2i] = []      # 本局道路格（验证/调试用）
var _road_segments_ok := 0                # 成功连通的路径段数

var map_seed := 0
var _pipes: Array = []  # 本局能量管道节点（读档时按此恢复状态）
var relic_anchor := Vector2i(112, 60)   # 遗迹密室锚点（左上角，由种子决定）
var altar_a_cell := Vector2i(106, 63)   # 双子碑 A（先激活）
var altar_b_cell := Vector2i(116, 68)   # 双子碑 B（后激活）
var _relic_code := "000"                # 本局密码锁密码（种子决定，读档可复现）
var _relic_sequence: Array = [0, 1, 2, 3]  # 本局遗迹装置符文顺序
var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer = null
var _biome_grid: Array[String] = []  ## 群系缓存（200×150 一维数组，行优先 [y*MAP_W + x]；供验证/调试与后续系统读取）


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = TILE_SET
	_ground.z_index = -10  # 强制画在最底层，否则会盖住玩家/建筑/怪物
	add_child(_ground)
	generate(randi())  # 每次开局一张新图
	# 地表环境音：低频风声循环（第十二课）
	AudioManager.set_ambient("surface")
	# 首次进入游戏时按顺序给新手提示；看过的不会重复显示（第十二课）
	TutorialHints.show_first_time("move", "移动：WASD 或方向键")
	TutorialHints.show_first_time("gather", "采集：靠近树木或矿石，按 E")
	TutorialHints.show_first_time("build", "建造：按 B 进入建造模式，1-4 选择类型，左键放置、右键拆除")
	TutorialHints.show_first_time("craft", "制作：靠近工作台按 E 打开制作面板")
	TutorialHints.show_first_time("combat", "战斗：左键攻击；数字键 1-5 切换装备")
	TutorialHints.show_first_time("save", "存档：F5 保存 / F9 读取")
	# 地表无黑暗：关闭玩家视野光
	var light = get_node_or_null("Player/PointLight2D")
	if light != null:
		light.energy = 0.0
	var info := SaveManager.consume_pending_load()
	if info.is_empty():
		SaveManager.toast.emit("探索废土：踩压力板开门、转动管道接通；遗迹密室藏着密码锁，先激活遗迹装置")
	else:
		SaveManager.load_game_from(info.path, info.keep_inventory)  # 从地心返回 读档到地表时恢复状态 

## 生成地图：清空旧的，铺瓦片，放资源
## saved_resources 为空则随机分布；读档时传入存档的资源列表（保持采集状态）
func generate(seed_value: int, saved_resources: Array = [], saved_pipes: Array = [], saved_puzzles: Array = []) -> void:
	map_seed = seed_value
	_rng.seed = seed_value
	# 重置会参与 _build_tiles 避让判断的状态：否则第二次生成会残留上一次的谜题/巢穴格子，
	# 导致结构放置序列错位、同一种子两次生成不一致
	puzzle_cells.clear()
	_lair_rects.clear()
	_build_tiles()
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		node.queue_free()
	# 清掉旧谜题实体（门/压力板/管道），重新生成，避免读档重复
	for node in get_tree().get_nodes_in_group("doors") + get_tree().get_nodes_in_group("pressure_plates") \
		+ get_tree().get_nodes_in_group("power_pipes") + get_tree().get_nodes_in_group("keypad_locks") \
		+ get_tree().get_nodes_in_group("relic_devices") + get_tree().get_nodes_in_group("twin_altars"):
		node.free()
	for node in get_tree().get_nodes_in_group("portals"):
		node.free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.free()
	for m in get_tree().get_nodes_in_group("hub_markers"):
		m.queue_free()
	_place_lairs()      # 登记所有群系 Boss 巢穴的占用矩形（资源/结构避让）
	_place_landmarks()  # 先登记巢穴，再定地标：谜题/聚集地/传送门都要避开巢穴（否则路网可能被巢穴切断）
	_build_puzzles(saved_resources.is_empty())  # 全新开局才放房间奖励，读档从存档恢复
	_build_relic_puzzles(saved_resources.is_empty())  # 解谜扩展：遗迹密室 + 双子机关碑
	_build_portal()
	_build_boss_hub()
	_build_lairs()      # 先建巢穴，再修路（路网绕开巢穴围墙，只从正门通道接入）
	_build_roads()
	_spawn_start_workbench()
	if saved_resources.is_empty():
		_spawn_random_resources()
	else:
		_spawn_saved_resources(saved_resources)
	# 恢复管道状态（读档）
	for i in mini(saved_pipes.size(), _pipes.size()):
		_pipes[i].apply_state(saved_pipes[i])
	# 读档后若全部接通：标记已解决，避免玩家再转一次触发重复奖励
	if not saved_pipes.is_empty():
		var all_connected := true
		for p in _pipes:
			if not p.connected:
				all_connected = false
				break
		if all_connected:
			for p in _pipes:
				p.mark_solved()
	# 恢复谜题进度（密码锁/遗迹装置/双子碑），已解的不会重置、不重复发奖
	_restore_puzzle_states(saved_puzzles)


## 在地图上随机放一个通往地心世界的传送门（避开出生点和谜题）
func _build_portal() -> void:
	var portal: Node2D = PORTAL_SCENE.instantiate()
	portal.target_scene = "res://scenes/underworld.tscn"
	portal.global_position = Vector2(portal_cell) * TILE_SIZE + Vector2(16, 16)
	add_child(portal)


func _portal_cell(rng: RandomNumberGenerator) -> Vector2i:
	for i in 120:
		var cell := Vector2i(rng.randi_range(2, MAP_W - 3), rng.randi_range(2, MAP_H - 3))
		if _is_spawn_safe(cell) or _is_puzzle_cell(cell):
			continue
		if _is_reserved_cell(cell):
			continue  # 传送门不能落在群系 Boss 巢穴里
		if Vector2(cell - hub_cell).length() < PORTAL_MIN_DIST_FROM_HUB:
			continue
		# 传送门只放在普通地表区域，保证开局就能找到（暗域/未来群系暂不放）
		if not BiomeDefs.is_surface(BiomeDefs.get_biome_at(cell, map_seed)):
			continue
		var atlas := _ground.get_cell_atlas_coords(cell)
		if atlas == STONE_TILE or atlas == WATER_TILE:
			continue
		return cell
	return SPAWN_CELL + Vector2i(6, 0)


## 地标放置规则：谜题在出生点附近（12~18 格），聚集地在地表深处（≥20 格），传送门避开两者
func _place_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 999
	puzzle_anchor = _pick_puzzle_anchor(rng)
	puzzle_cells = _compute_puzzle_cells(puzzle_anchor)
	relic_anchor = _pick_relic_anchor(rng)
	puzzle_cells.append_array(_compute_relic_cells(relic_anchor))
	var altars: Array = _pick_altar_cells(rng)
	altar_a_cell = altars[0]
	altar_b_cell = altars[1]
	puzzle_cells.append_array(_compute_altar_cells(altar_a_cell, altar_b_cell))
	hub_cell = _pick_hub_cell(rng)
	portal_cell = _portal_cell(rng)
	# 谜题内容由世界种子决定：读档重建时生成同一把锁、同一串符文
	_relic_code = "%03d" % (absi(map_seed) % 1000)
	var seq_rng := RandomNumberGenerator.new()
	seq_rng.seed = map_seed + 557
	_relic_sequence = [0, 1, 2, 3]
	# Fisher-Yates 洗牌：用种子 RNG 保证同一世界种子生成同一序列（读档可复现）
	for i in range(_relic_sequence.size() - 1, 0, -1):
		var j := seq_rng.randi_range(0, i)
		var tmp: int = _relic_sequence[i]
		_relic_sequence[i] = _relic_sequence[j]
		_relic_sequence[j] = tmp


## 在普通地表内、离出生点 12~18 格处选压力板密室的锚点（左上角）
func _pick_puzzle_anchor(rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 100:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(PUZZLE_MIN_DIST, PUZZLE_MAX_DIST)
		var anchor := SPAWN_CELL + Vector2i(round(cos(angle) * dist), round(sin(angle) * dist))
		if _valid_puzzle_anchor(anchor):
			return anchor
	# 兜底：出生点东南方的固定位置（仍在普通地表内）
	return SPAWN_CELL + Vector2i(12, 8)


func _valid_puzzle_anchor(anchor: Vector2i) -> bool:
	# 房间 + 西侧管道必须都在图内（管道最西到 anchor.x-17）
	if anchor.x < 22 or anchor.y < 5:
		return false
	if anchor.x + PUZZLE_SIZE.x > MAP_W - 4 or anchor.y + PUZZLE_SIZE.y > MAP_H - 4:
		return false
	# 房间不能压到出生点安全区
	for y in range(anchor.y, anchor.y + PUZZLE_SIZE.y):
		for x in range(anchor.x, anchor.x + PUZZLE_SIZE.x):
			if _is_spawn_safe_box(Vector2i(x, y)):
				return false
	# 房间中心必须在普通地表区域
	var center := anchor + Vector2i(PUZZLE_SIZE.x / 2, PUZZLE_SIZE.y / 2)
	if not BiomeDefs.is_surface(BiomeDefs.get_biome_at(center, map_seed)):
		return false
	# 谜题足迹（房间 + 门外 + 管道 + 压力板）不能压进群系 Boss 巢穴
	for cell2 in _compute_puzzle_cells(anchor):
		if _is_reserved_cell(cell2):
			return false
	return true


func _compute_puzzle_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(anchor.y, anchor.y + PUZZLE_SIZE.y):
		for x in range(anchor.x, anchor.x + PUZZLE_SIZE.x):
			cells.append(Vector2i(x, y))
	for off in DOORWAY_OFFSETS:
		cells.append(anchor + off)
	for off in PIPE_OFFSETS:
		cells.append(anchor + off)
	cells.append(anchor + PLATE_OFFSET)
	return cells


## 遗迹密室锚点：普通地表内、离出生点 22~34 格、避开压力板谜题与巢穴
func _pick_relic_anchor(rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 120:
		var angle := rng.randf() * TAU
		var dist := rng.randf_range(RELIC_MIN_DIST, RELIC_MAX_DIST)
		var anchor := SPAWN_CELL + Vector2i(round(cos(angle) * dist), round(sin(angle) * dist))
		if _valid_relic_anchor(anchor):
			return anchor
	return SPAWN_CELL + Vector2i(24, 14)  # 兜底：出生点东南（仍在普通地表）


func _valid_relic_anchor(anchor: Vector2i) -> bool:
	if anchor.x < 5 or anchor.y < 5:
		return false
	if anchor.x + RELIC_ROOM_SIZE.x > MAP_W - 4 or anchor.y + RELIC_ROOM_SIZE.y > MAP_H - 4:
		return false
	for cell2 in _compute_relic_cells(anchor):
		if _is_spawn_safe(cell2) or _is_reserved_cell(cell2):
			return false
	var center := anchor + Vector2i(RELIC_ROOM_SIZE.x / 2, RELIC_ROOM_SIZE.y / 2)
	if not BiomeDefs.is_surface(BiomeDefs.get_biome_at(center, map_seed)):
		return false
	return true


func _compute_relic_cells(anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(anchor.y, anchor.y + RELIC_ROOM_SIZE.y):
		for x in range(anchor.x, anchor.x + RELIC_ROOM_SIZE.x):
			cells.append(Vector2i(x, y))
	for off in RELIC_DOORWAY_OFFSETS:
		cells.append(anchor + off)
	return cells


## 双子碑位置：遗迹密室附近两块空地（间距 ≥5 格），A 先激活、B 后激活
func _pick_altar_cells(rng: RandomNumberGenerator) -> Array:
	for attempt in 80:
		var a := relic_anchor + Vector2i(rng.randi_range(-9, 9), rng.randi_range(-6, 6))
		if not _valid_altar_cell(a):
			continue
		for attempt2 in 40:
			var b := relic_anchor + Vector2i(rng.randi_range(-9, 9), rng.randi_range(-6, 6))
			if a == b or Vector2(b - a).length() < 5.0:
				continue
			if _valid_altar_cell(b):
				return [a, b]
	return [relic_anchor + Vector2i(-6, 2), relic_anchor + Vector2i(8, 4)]


func _valid_altar_cell(cell: Vector2i) -> bool:
	if cell.x < 3 or cell.y < 3 or cell.x >= MAP_W - 3 or cell.y >= MAP_H - 3:
		return false
	if _is_spawn_safe(cell) or _is_reserved_cell(cell):
		return false
	if not BiomeDefs.is_surface(BiomeDefs.get_biome_at(cell, map_seed)):
		return false
	# 双子碑要和遗迹密室保持 ≥2 格间距：路网终点在石碑旁边一格，
	# 若石碑贴着密室墙，终点会落在墙上导致 A* 无法到达
	var relic_cells := _compute_relic_cells(relic_anchor)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if relic_cells.has(cell + Vector2i(dx, dy)):
				return false
	var atlas := _ground.get_cell_atlas_coords(cell)
	if atlas == STONE_TILE or atlas == WATER_TILE or atlas == LAVA_TILE:
		return false
	return true


func _compute_altar_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	return [a, b]


## 聚集地：普通地表深处（离出生点 ≥20 格、离谜题 ≥12 格）的独立竞技场
func _pick_hub_cell(rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 120:
		var cell := Vector2i(rng.randi_range(6, MAP_W - 7), rng.randi_range(6, MAP_H - 7))
		if Vector2(cell - SPAWN_CELL).length() < HUB_MIN_DIST_FROM_SPAWN:
			continue
		if _is_puzzle_cell(cell):
			continue
		if Vector2(cell - puzzle_anchor).length() < HUB_MIN_DIST_FROM_PUZZLE:
			continue
		if _hub_area_overlaps_lair(cell):
			continue  # 聚集地 7×7 竞技场不能压进群系 Boss 巢穴
		if not BiomeDefs.is_surface(BiomeDefs.get_biome_at(cell, map_seed)):
			continue
		if BiomeDefs.is_transition(cell, map_seed):
			continue
		if _ground.get_cell_atlas_coords(cell) == WATER_TILE:
			continue
		return cell
	return SPAWN_CELL + Vector2i(25, 10)


## 聚集地 7×7 竞技场是否与某个群系 Boss 巢穴（或谜题）重叠
func _hub_area_overlaps_lair(center: Vector2i) -> bool:
	for x in range(center.x - HUB_RADIUS, center.x + HUB_RADIUS + 1):
		for y in range(center.y - HUB_RADIUS, center.y + HUB_RADIUS + 1):
			if _is_reserved_cell(Vector2i(x, y)):
				return true
	return false


## 群系中心的怪物聚集地：大 Boss 固定刷新，带精英和普通守卫
func _build_boss_hub() -> void:
	for x in range(hub_cell.x - HUB_RADIUS, hub_cell.x + HUB_RADIUS + 1):
		for y in range(hub_cell.y - HUB_RADIUS, hub_cell.y + HUB_RADIUS + 1):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)
	# 同步刷怪器的聚集地中心：玩家进入 128px 内时刷怪上限提到 100
	var spawner := get_node_or_null("EnemySpawner")
	if spawner != null:
		spawner.hub_center = Vector2(hub_cell.x * TILE_SIZE + 16, hub_cell.y * TILE_SIZE + 16)
		# 出生点安全区同步：刷怪器在出生点附近永不刷怪（开局安全期见 spawn_manager）
		spawner.spawn_safe_center = Vector2(SPAWN_CELL.x * TILE_SIZE + 16, SPAWN_CELL.y * TILE_SIZE + 16)
		spawner.spawn_safe_radius = float(SPAWN_SAFE_RADIUS * 2) * TILE_SIZE  # 禁刷区半径 = 出生营地半径 × 2（16 格）
	# 红色聚集地标记，从远处就能看出“这里不对劲”
	var marker := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		points.append(Vector2(hub_cell) * TILE_SIZE + Vector2(16, 16) + Vector2(cos(a), sin(a)) * ((HUB_RADIUS + 0.5) * TILE_SIZE))
	marker.polygon = points
	marker.color = Color(0.7, 0.15, 0.15, 0.35)
	marker.z_index = -1
	marker.add_to_group("hub_markers")
	add_child(marker)
	_spawn_enemy_node("warlord", hub_cell + Vector2i(0, 0))
	_spawn_enemy_node("elite", hub_cell + Vector2i(2, 1))
	_spawn_enemy_node("goblin", hub_cell + Vector2i(-2, 0))
	_spawn_enemy_node("walker", hub_cell + Vector2i(1, -2))


func _spawn_enemy_node(type: String, cell: Vector2i) -> void:
	var enemy: Node2D = ENEMY_SCENE.instantiate()
	enemy.enemy_type = type
	enemy.global_position = Vector2(cell.x * TILE_SIZE + 16, cell.y * TILE_SIZE + 16)
	add_child(enemy)


## 登记所有群系 Boss 巢穴的占用矩形（资源/结构避让用）
func _place_lairs() -> void:
	_lair_rects.clear()
	for l in LAIR_DEFS:
		var center: Vector2i = l["center"]
		_lair_rects.append(Rect2i(center - Vector2i(LAIR_HALF, LAIR_HALF), Vector2i(LAIR_HALF * 2 + 1, LAIR_HALF * 2 + 1)))


## 按 LAIR_DEFS 生成全部群系大Boss巢穴
func _build_lairs() -> void:
	for l in LAIR_DEFS:
		_build_boss_lair(l)


## 群系大Boss巢穴模板：15×15 广场 + 中央 9×9 石墙围城（北墙正门）+ 主题装饰
## 固定刷 大Boss + 精英 + 2 守卫，巢内宝库放群系专属资源
func _build_boss_lair(l: Dictionary) -> void:
	var c: Vector2i = l["center"]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + c.x * 7 + c.y * 13  # 每个巢穴独立种子，读档重建一致
	var fa: Vector2i = l["floor_a"]
	if fa == STONE_TILE:
		fa = MUD_TILE  # 广场地面不能是挡路石头（峡谷等石系群系兜底）
	# 1) 广场地面：群系主题地面
	for y in range(c.y - LAIR_HALF, c.y + LAIR_HALF + 1):
		for x in range(c.x - LAIR_HALF, c.x + LAIR_HALF + 1):
			var roll := rng.randf()
			_ground.set_cell(Vector2i(x, y), 0, fa if roll < 0.7 else (l["floor_b"] if roll < 0.9 else GRASS_TILE))
	# 2) 中央围城：石墙，北墙留 2 格正门（对着主干道）
	for y in range(c.y - LAIR_KEEP_HALF, c.y + LAIR_KEEP_HALF + 1):
		for x in range(c.x - LAIR_KEEP_HALF, c.x + LAIR_KEEP_HALF + 1):
			var cell := Vector2i(x, y)
			var is_wall := x == c.x - LAIR_KEEP_HALF or x == c.x + LAIR_KEEP_HALF or y == c.y - LAIR_KEEP_HALF or y == c.y + LAIR_KEEP_HALF
			if not is_wall:
				_ground.set_cell(cell, 0, GRASS_TILE if rng.randf() < 0.5 else fa)
				continue
			if y == c.y - LAIR_KEEP_HALF and absi(x - c.x) <= 1:
				_ground.set_cell(cell, 0, MUD_TILE)  # 北墙正门
				continue
			if rng.randf() < 0.18:
				_ground.set_cell(cell, 0, MUD_TILE)  # 墙上缺口（废墟感）
				continue
			_ground.set_cell(cell, 0, STONE_TILE)
	# 2.5) 巢穴内部（Boss/守卫/宝库站位）整体强制可通行，防止群系地面是石头导致卡死
	for gx in range(c.x - 3, c.x + 4):
		for gy in range(c.y - 3, c.y + 4):
			_ground.set_cell(Vector2i(gx, gy), 0, GRASS_TILE if rng.randf() < 0.5 else l["floor_b"])
	# 3) 群系主题装饰（围城外，避开围城）
	var rect := Rect2i(c - Vector2i(LAIR_HALF, LAIR_HALF), Vector2i(LAIR_HALF * 2 + 1, LAIR_HALF * 2 + 1))
	var decor: String = l["decor"]
	for i in 6:
		var px := rng.randi_range(c.x - LAIR_HALF + 1, c.x + LAIR_HALF - 1)
		var py := rng.randi_range(c.y - LAIR_HALF + 1, c.y + LAIR_HALF - 1)
		if Vector2i(px, py).distance_to(c) < float(LAIR_KEEP_HALF + 2):
			continue
		_place_lair_decor(decor, Vector2i(px, py), rect, rng)
	# 3.5) 正门通道：北墙外 4 列强制铺泥地（路网从这里接入 Boss 门口，防止被地面/装饰堵死）
	for gx in range(c.x - 1, c.x + 2):
		for gy in range(c.y - LAIR_KEEP_HALF - 3, c.y - LAIR_KEEP_HALF + 1):
			_ground.set_cell(Vector2i(gx, gy), 0, MUD_TILE)
	# 4) 守卫：大Boss + 精英 + 2 只普通
	_spawn_enemy_node(l["boss"], c)
	_spawn_enemy_node(l["elite"], c + Vector2i(2, 2))
	var guards: Array = l["guards"]
	_spawn_enemy_node(guards[0], c + Vector2i(-3, 1))
	_spawn_enemy_node(guards[1], c + Vector2i(3, -1))
	# 5) 巢穴宝库：群系专属资源
	for t in l["treasure"]:
		var meta: Dictionary = RESOURCE_META.get(t["id"], {"name": t["id"], "color": Color(0.6, 0.6, 0.6)})
		_spawn_resource(c + t["off"], t["id"], meta["name"], t["min"], t["max"], meta["color"])


## 巢穴主题装饰：按群系在围城外铺一小片特色地形
func _place_lair_decor(decor: String, cell: Vector2i, rect: Rect2i, rng: RandomNumberGenerator) -> void:
	var tile := WATER_TILE
	var chance := 0.55
	match decor:
		"ice":
			tile = ICE_TILE
			chance = 0.65
		"lava":
			tile = LAVA_TILE
			chance = 0.5
		"toxic":
			tile = TOXIC_TILE
			chance = 0.5
		"metal":
			tile = METAL_TILE
			chance = 0.6
		"rock":
			tile = STONE_TILE
			chance = 0.6
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cc := cell + Vector2i(dx, dy)
			if rng.randf() < chance and rect.has_point(cc):
				_ground.set_cell(cc, 0, RUST_TILE if (decor == "metal" and rng.randf() < 0.4) else tile)


## 废土路网（星形拓扑）：出生点 → 谜题门口 → 聚集地 → 传送门（世界枢纽），
## 再从传送门放射 8 条支线直通各群系大Boss巢穴正门。
## 参照《饥荒》枢纽分支 + RPG 城镇放射路网：玩家从出生点可直奔任意群系，不迷路
func _build_roads() -> void:
	_road_cells_count = 0
	_road_segments_ok = 0
	road_cells.clear()
	var segments: Array = [
		[SPAWN_CELL + Vector2i(0, 2), puzzle_anchor + DOORWAY_OFFSETS[0] + Vector2i(-1, 0)],  # 出生点营地南出口 → 谜题门口
		[puzzle_anchor + DOORWAY_OFFSETS[0] + Vector2i(-1, 0), hub_cell + Vector2i(0, 2)],     # 谜题门口 → 聚集地边缘
		[hub_cell + Vector2i(0, 2), portal_cell],                                             # 聚集地边缘 → 传送门（世界枢纽）
		[SPAWN_CELL + Vector2i(0, 2), relic_anchor + Vector2i(2, -2)],                        # 出生点 → 遗迹密室门口
		[relic_anchor + Vector2i(2, -2), altar_a_cell + Vector2i(1, 0)],                      # 密室 → 石碑 A
		[altar_a_cell + Vector2i(1, 0), altar_b_cell + Vector2i(1, 0)],                       # 石碑 A → 石碑 B
	]
	for l in LAIR_DEFS:
		var c: Vector2i = l["center"]
		segments.append([portal_cell, c + Vector2i(0, -LAIR_KEEP_HALF - 1)])  # 传送门 → 各群系Boss巢穴正门
	for i in segments.size():
		var seg: Array = segments[i]
		var path := _find_road_path(seg[0], seg[1])
		if path.is_empty():
			print("[ROAD] 段 %d 失败: %s -> %s" % [i + 1, str(seg[0]), str(seg[1])])
			continue
		_road_segments_ok += 1
		for cell in path:
			_ground.set_cell(cell, 0, ROAD_TILE)
			road_cells.append(cell)
			_road_cells_count += 1
		# 对角断点修复：A* 允许 8 方向步进，若某一对角步的两个转角格是石头，
		# 玩家会被"角夹住"走不过去 → 把其中一个转角格补成泥地，保证路真的能走通
		for j in path.size() - 1:
			var a: Vector2i = path[j]
			var b: Vector2i = path[j + 1]
			var d := b - a
			if absi(d.x) != 1 or absi(d.y) != 1:
				continue
			for corner in [Vector2i(a.x + d.x, a.y), Vector2i(a.x, a.y + d.y)]:
				if _is_reserved_cell(corner):
					continue
				if _ground.get_cell_atlas_coords(corner) == STONE_TILE:
					_ground.set_cell(corner, 0, ROAD_TILE)
					road_cells.append(corner)
					_road_cells_count += 1
					break  # 补一块就够打开角，另一块保持原样


## A* 寻路：找到一条尽量笔直的废土道路（绕开水域，可碾过碎石/残墙——"开路"感）
func _find_road_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var open: Array = []  # 二叉堆 [f, g, cell]
	var came_from := {}
	var g_score := {from: 0.0}
	var closed := {}
	_heap_push(open, [_heuristic(from, to), 0.0, from])
	var steps := 0
	while not open.is_empty() and steps < 200000:
		steps += 1
		var entry: Array = _heap_pop(open)
		var cell: Vector2i = entry[2]
		if cell == to:
			return _reconstruct_path(came_from, to)
		if closed.has(cell):
			continue
		closed[cell] = true
		for dir in _DIRS8:
			var nxt: Vector2i = cell + dir
			if not _road_passable(nxt):
				continue
			var step_cost := 1.0 if (dir.x == 0 or dir.y == 0) else 1.41
			var g: float = float(entry[1]) + step_cost + _road_cost(nxt)
			if g_score.has(nxt) and g >= g_score[nxt]:
				continue
			g_score[nxt] = g
			came_from[nxt] = cell
			_heap_push(open, [g + _heuristic(nxt, to), g, nxt])
	return []


## 二叉堆：push（按 f 值排序，f 小的优先）
func _heap_push(heap: Array, item: Array) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if heap[p][0] <= heap[i][0]:
			break
		var tmp: Array = heap[p]
		heap[p] = heap[i]
		heap[i] = tmp
		i = p


## 二叉堆：pop 最小值
func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var smallest := i
		if l < n and heap[l][0] < heap[smallest][0]:
			smallest = l
		if r < n and heap[r][0] < heap[smallest][0]:
			smallest = r
		if smallest == i:
			break
		var tmp: Array = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = tmp
		i = smallest
	return top


func _reconstruct_path(came_from: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := goal
	while came_from.has(cur):
		path.append(cur)
		cur = came_from[cur]
	path.reverse()
	return path


func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return maxf(dx, dy) + 0.41 * minf(dx, dy)


## 道路可走：不出边界、不进谜题房间；水域多收费（绕行），实在绕不开就当"浅滩"碾过去
func _road_passable(cell: Vector2i) -> bool:
	if cell.x < BORDER_WIDTH or cell.y < BORDER_WIDTH or cell.x >= MAP_W - BORDER_WIDTH or cell.y >= MAP_H - BORDER_WIDTH:
		return false
	if _is_puzzle_cell(cell):
		return false
	# 巢穴：路网绕开围墙，只允许从正门通道进入
	if _is_in_lair_rect(cell) and not _is_lair_corridor(cell):
		return false
	return true


func _is_in_lair_rect(cell: Vector2i) -> bool:
	for rect in _lair_rects:
		if rect.has_point(cell):
			return true
	return false


## 巢穴正门通道：北墙外 4 列（路网从这里接入 Boss 门口）
func _is_lair_corridor(cell: Vector2i) -> bool:
	for l in LAIR_DEFS:
		var c: Vector2i = l["center"]
		if cell.x >= c.x - 1 and cell.x <= c.x + 1 and cell.y >= c.y - LAIR_KEEP_HALF - 3 and cell.y <= c.y - LAIR_KEEP_HALF:
			return true
	return false


func _road_cost(cell: Vector2i) -> float:
	var atlas := _ground.get_cell_atlas_coords(cell)
	return 6.0 if (atlas == WATER_TILE or atlas == LAVA_TILE or atlas == TOXIC_TILE) else 1.0


func _build_tiles() -> void:
	_ground.clear()
	_biome_grid.clear()
	# ═══ Pass 1：地形 ═══		# 区域图决定群系，噪声把地面分成连续色块（MC/泰拉瑞亚式）
	_build_ground_layer()
	# ═══ Pass 2：群系专属大型结构 ═══		# 参照 MC 的沙漠神殿/丛林神庙/村庄——每个群系有独特结构
	_build_biome_structures()
	# ═══ Pass 3：小型散落装饰 ═══
	_build_biome_scatter()
	# ═══ Pass 4：出生点安全区 ═══
	_build_spawn_safe_zone()


## Pass 1：区域图 + 噪声地面
## 每个群系有自己的瓦片配比（如废土 55%泥地+30%草地+15%石头），
## 但不再每格独立随机（那样是“盐和胡椒”），而是用低频率噪声切出连续色块，
## 同一片区域是一整块泥地/草地/石地，边界再自然过渡。
func _build_ground_layer() -> void:
	var ground_rng := RandomNumberGenerator.new()
	ground_rng.seed = map_seed + 333  # 独立种子
	for y in MAP_H:
		for x in MAP_W:
			var cell := Vector2i(x, y)
			# 自然边界：最外 3 格是“废墟碎石带”，外圈硬石挡路、内圈碎石+泥地（断崖废墟感）
			if _is_border_cell(x, y):
				_biome_grid.append("border")
				var hard_edge := x == 0 or y == 0 or x == MAP_W - 1 or y == MAP_H - 1
				_ground.set_cell(cell, 0, STONE_TILE if (hard_edge or ground_rng.randf() < 0.55) else MUD_TILE)
				continue
			# 区域图一次算好群系 + 到边界的距离（避免重复算噪声）
			var info: Dictionary = BiomeDefs.region_info(cell, map_seed)
			var biome_id: String = info["biome"]
			_biome_grid.append(biome_id)
			# 天空岛"环岛湖"：天空岛椭圆外一圈铺水，形成真正的"岛"
			if BiomeDefs.sky_moat(cell, map_seed):
				_ground.set_cell(cell, 0, WATER_TILE)
				continue
			# 区域边界过渡带：群系瓦片 + 碎石/枯地混合（噪声咬边），避免两个群系硬切
			if absf(info["margin"]) < BiomeDefs.TRANSITION_MARGIN:
				# 按离边界的距离做渐变：越靠群系内部越接近本群系地面，越靠外越接近碎石/枯地
				var t := clampf((float(info["margin"]) + BiomeDefs.TRANSITION_MARGIN) / (2.0 * BiomeDefs.TRANSITION_MARGIN), 0.0, 1.0)
				var roll := ground_rng.randf()
				var biome_share := lerpf(0.92, 0.15, t)
				var mud_share := lerpf(0.97, 0.70, t)
				if roll < biome_share:
					# 保持本群系地面 → 边界像"群系逐渐淡出"，而不是一条硬碎石圈
					var biome: Dictionary = BiomeDefs.get_biome_def(biome_id)
					_ground.set_cell(cell, 0, _noise_pick_tile(biome["ground_tiles"], cell, map_seed))
				elif roll < mud_share:
					_ground.set_cell(cell, 0, MUD_TILE)
				else:
					_ground.set_cell(cell, 0, STONE_TILE)
				continue
			var biome: Dictionary = BiomeDefs.get_biome_def(biome_id)
			_ground.set_cell(cell, 0, _noise_pick_tile(biome["ground_tiles"], cell, map_seed))


func _is_border_cell(x: int, y: int) -> bool:
	return x < BORDER_WIDTH or y < BORDER_WIDTH or x >= MAP_W - BORDER_WIDTH or y >= MAP_H - BORDER_WIDTH


## 某点是否在黑暗群系（管道等物体的"黑暗中不可见"规则用）
func is_in_dark_zone(pos: Vector2) -> bool:
	return BiomeDefs.get_biome_def_at(pos, map_seed).get("is_dark", false)


## 玩家当前是否身处黑暗群系
func is_player_in_dark() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return is_in_dark_zone(player.global_position)


## 从 {tile: weight, ...} 中按权重把噪声值映射到瓦片：连续色块而非逐格随机
func _noise_pick_tile(tiles: Dictionary, cell: Vector2i, seed_value: int) -> Vector2i:
	# 频率 0.45：噪声格点约 44 格，区域内形成 2~5 个色块带（之前 0.045 格点约 444 格，
	# 整个群系都落在一个噪声单元里，结果每个群系几乎只有一种瓦片）
	var n := SimpleNoise.fbm_noise(cell.x * 0.45, cell.y * 0.45, seed_value + 333, 3)
	var total := 0
	for tile in tiles:
		total += tiles[tile]
	var acc := 0.0
	for tile in tiles:
		acc += float(tiles[tile]) / float(total)
		if n <= acc:
			return tile
	return GRASS_TILE  # 兜底


## Pass 4：出生点安全区 —— 半径 6 格清成草地，作为“家”
func _build_spawn_safe_zone() -> void:
	for x in range(SPAWN_CELL.x - SPAWN_SAFE_RADIUS, SPAWN_CELL.x + SPAWN_SAFE_RADIUS + 1):
		for y in range(SPAWN_CELL.y - SPAWN_SAFE_RADIUS, SPAWN_CELL.y + SPAWN_SAFE_RADIUS + 1):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)


## 出生点初始工作台：开局就有“家”的制作点（研究建议：出生点=安全区+初始设施）
func _spawn_start_workbench() -> void:
	var wb: Node2D = WORKBENCH_SCENE.instantiate()
	wb.global_position = Vector2(SPAWN_CELL.x * TILE_SIZE + 16, (SPAWN_CELL.y + 3) * TILE_SIZE + 16)
	add_child(wb)


## Pass 2：群系专属大型结构生成
## 每个群系的结构类型不同：废土=残墙+瓦砾，林地=水塘+树丛，石丘=岩层+巨石阵，暗域=建筑残骸
func _build_biome_structures() -> void:
	var struct_rng := RandomNumberGenerator.new()
	struct_rng.seed = map_seed + 555
	for biome_id in BiomeDefs.BIOMES:
		var biome: Dictionary = BiomeDefs.BIOMES[biome_id]
		var structures: Dictionary = biome.get("structures", {})
		for struct_type in structures:
			var cfg: Dictionary = structures[struct_type]
			var count: int = cfg["count"]
			for i in count:
				# 在群系内随机选一个结构中心
				var center := _random_cell_in_biome(biome_id, struct_rng)
				if center == Vector2i.ZERO:
					continue
				# 按结构类型分发到对应的生成函数
				_place_structure(struct_type, center, cfg, struct_rng)


## 根据结构类型名调用对应的生成函数
func _place_structure(type: String, center: Vector2i, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	match type:
		"ruined_wall":
			var length := rng.randi_range(cfg["min_len"], cfg["max_len"])
			var horizontal := rng.randf() < 0.5
			_gen_ruined_wall(center, length, horizontal, rng)
		"rock_formation":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_rock_formation(center, radius, rng)
		"debris_field":
			var radius: int = cfg["radius"]
			_gen_debris_field(center, radius, rng)
		"water_pool":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_water_pool(center, radius, rng)
		"ice_spike":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_ice_spike(center, radius, rng)
		"lava_pool":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_lava_pool(center, radius, rng)
		"toxic_pool":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_toxic_pool(center, radius, rng)
		"wreck":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_wreck(center, radius, rng)
		"tree_grove":
			var radius := rng.randi_range(cfg["min_r"], cfg["max_r"])
			_gen_tree_grove(center, radius, rng)
		"building_shell":
			var size := rng.randi_range(cfg["min_size"], cfg["max_size"])
			_gen_building_shell(center, size, rng)
		"boulder_field":
			var radius: int = cfg["radius"]
			_gen_boulder_field(center, radius, rng)


# ── 结构生成器：每种结构类型一个函数 ──

## 残墙段：一段直线石墙，有随机缺口（废墟感）
func _gen_ruined_wall(center: Vector2i, length: int, horizontal: bool, rng: RandomNumberGenerator) -> void:
	for i in length:
		if rng.randf() < 0.75:  # 25% 概率缺一块 → 废墟的破碎感
			var cell := center + (Vector2i(i, 0) if horizontal else Vector2i(0, i))
			if _valid_structure_cell(cell):
				_ground.set_cell(cell, 0, STONE_TILE)


## 岩层露头：圆形石簇，模拟自然岩石露出地表
func _gen_rock_formation(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if Vector2(x, y).length() <= radius and rng.randf() < 0.65:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, STONE_TILE)


## 瓦砾场：散落的碎石和小块废墟，比岩层更稀疏
func _gen_debris_field(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if abs(x) + abs(y) <= radius * 2 and rng.randf() < 0.3:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					# 瓦砾混杂石头和泥土
					_ground.set_cell(cell, 0, STONE_TILE if rng.randf() < 0.7 else MUD_TILE)


## 水塘：圆形水域，林地特征
func _gen_water_pool(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var dist := Vector2(x, y).length()
			if dist <= radius and rng.randf() < (1.0 - dist / (radius + 1.0) * 0.3):
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, WATER_TILE)


## 冰柱群：放射状冰面簇（雪原上的冰晶尖刺）
func _gen_ice_spike(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if Vector2(x, y).length() <= radius and rng.randf() < 0.6:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, ICE_TILE)


## 熔岩池：放射状岩浆池（爆炎之城）
func _gen_lava_pool(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var dist := Vector2(x, y).length()
			if dist <= radius and rng.randf() < (1.0 - dist / (radius + 1.0) * 0.3):
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, LAVA_TILE)


## 毒沼：放射状毒沼池（辐射荒原）
func _gen_toxic_pool(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var dist := Vector2(x, y).length()
			if dist <= radius and rng.randf() < (1.0 - dist / (radius + 1.0) * 0.3):
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, TOXIC_TILE)


## 机械残骸：金属板 + 锈蚀铁板混合的残骸堆（机械废墟）
func _gen_wreck(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if Vector2(x, y).length() <= radius and rng.randf() < 0.55:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, METAL_TILE if rng.randf() < 0.6 else RUST_TILE)


## 树丛标记：在地面上铺泥地印记（实际树木在资源阶段放置）
## 圆形泥地 + 资源成群生成 = 视觉上的"密林区块"
func _gen_tree_grove(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if Vector2(x, y).length() <= radius and rng.randf() < 0.5:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, MUD_TILE)  # 树丛地面 = 泥地


## 建筑残骸：矩形石墙轮廓（四面墙 + 随机缺口），暗域废墟特征
func _gen_building_shell(center: Vector2i, size: int, rng: RandomNumberGenerator) -> void:
	var half := floori(size / 2.0)
	for x in range(-half, half + 1):
		for y in range(-half, half + 1):
			# 只有外轮廓是石墙（矩形边框）
			var is_edge := x == -half or x == half or y == -half or y == half
			if not is_edge:
				continue
			if rng.randf() < 0.8:  # 20% 概率缺一块 = 残破感
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, STONE_TILE)
	# 内部地面：泥地（曾经的室内地板）
	for x in range(-half + 1, half):
		for y in range(-half + 1, half):
			if rng.randf() < 0.5:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, MUD_TILE)


## 巨石阵：密集的大型岩石圆圈排列，石丘专属
func _gen_boulder_field(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	# 外圈：大石块环
	for i in 12:
		var angle := TAU * i / 12.0 + rng.randf() * 0.3
		var dist := radius + rng.randf_range(-1.0, 1.0)
		var bx := center.x + int(round(cos(angle) * dist))
		var by := center.y + int(round(sin(angle) * dist))
		# 每个定位点放一个 1~2 格的小石簇
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if rng.randf() < 0.5:
					var cell := Vector2i(bx + dx, by + dy)
					if _valid_structure_cell(cell):
						_ground.set_cell(cell, 0, STONE_TILE)
	# 内部：稀疏碎石
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if Vector2(x, y).length() <= radius and rng.randf() < 0.2:
				var cell := center + Vector2i(x, y)
				if _valid_structure_cell(cell):
					_ground.set_cell(cell, 0, STONE_TILE if rng.randf() < 0.6 else GRASS_TILE)


# ── 结构辅助函数 ──

## 在指定群系内随机选一个合法的结构中心
func _random_cell_in_biome(biome_id: String, rng: RandomNumberGenerator) -> Vector2i:
	for attempt in 30:
		var cell := Vector2i(rng.randi_range(3, MAP_W - 4), rng.randi_range(3, MAP_H - 4))
		if _is_spawn_safe(cell) or _is_reserved_cell(cell):
			continue
		if BiomeDefs.get_biome_at(cell, map_seed) != biome_id:
			continue
		return cell
	return Vector2i.ZERO


## 结构格是否合法：不覆盖出生点、谜题、边界
func _valid_structure_cell(cell: Vector2i) -> bool:
	if cell.x <= 1 or cell.y <= 1 or cell.x >= MAP_W - 2 or cell.y >= MAP_H - 2:
		return false
	if _is_spawn_safe(cell) or _is_reserved_cell(cell):
		return false
	return true


## 第 3 层：小型散落装饰 —— 按格概率撒零星瓦片
func _build_biome_scatter() -> void:
	var scatter_rng := RandomNumberGenerator.new()
	scatter_rng.seed = map_seed + 777
	# 不逐格扫描全部 30000 格（太慢），改为随机采样
	var samples := floori(MAP_W * MAP_H / 4.0)  # 采样 25%
	for i in samples:
		var cell := Vector2i(scatter_rng.randi_range(2, MAP_W - 3), scatter_rng.randi_range(2, MAP_H - 3))
		if _is_spawn_safe(cell) or _is_puzzle_cell(cell):
			continue
		# 如果这格已经是石头或水（结构生成的），不覆盖
		var existing := _ground.get_cell_atlas_coords(cell)
		if existing == STONE_TILE or existing == WATER_TILE:
			continue
		var biome_id := BiomeDefs.get_biome_at(cell, map_seed)
		var biome: Dictionary = BiomeDefs.get_biome_def(biome_id)
		var scatter: Dictionary = biome.get("scatter", {})
		if scatter.is_empty():
			continue
		if scatter_rng.randf() >= scatter.get("chance", 0.02):
			continue
		var tiles: Array = scatter["tiles"]
		_ground.set_cell(cell, 0, tiles[scatter_rng.randi_range(0, tiles.size() - 1)])


## 按群系分配资源（替代旧的全图均匀撒布）
## 每个群系独立控制：资源类型、数量、是否成群出现
## 集群模式（林地/暗域）：资源以 个 为单位集中出现，而非全图分散
func _spawn_random_resources() -> void:
	for biome_id in BiomeDefs.BIOMES:
		var biome: Dictionary = BiomeDefs.BIOMES[biome_id]
		var res: Dictionary = biome.get("resources", {})
		var is_clustered: bool = biome.get("resource_clustered", false)
		var cluster_size: Array = biome.get("cluster_size", [3, 6])
		for res_id in res:
			var amount: int = res[res_id]
			var meta: Dictionary = RESOURCE_META.get(res_id, {"name": res_id, "color": Color(0.6, 0.6, 0.6), "min": 1, "max": 2})
			var display_name: String = meta["name"]
			var color: Color = meta["color"]
			var min_amt: int = meta["min"]
			var max_amt: int = meta["max"]
			if is_clustered:
				# 集群模式：先选一个群系内的中心，在中心周围撒一批资源
				_spawn_clustered_resources(biome_id, res_id, display_name, amount, min_amt, max_amt, color, cluster_size)
			else:
				# 分散模式：逐个找空地放置
				for i in amount:
					var cell := _find_cell_in_biome(biome_id)
					if cell != Vector2i.ZERO:
						_spawn_resource(cell, res_id, display_name, min_amt, max_amt, color)


## 集群模式资源放置：在群系内选一个中心，周围撒 cluster_size 个同类型资源
func _spawn_clustered_resources(biome_id: String, res_id: String, display_name: String, total: int, min_amt: int, max_amt: int, color: Color, cluster_size: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 60811  # 独立种子：保证同一地图种子生成的资源位置一致（读档/重开可复现）
	var placed := 0
	for attempt in 100:  # 最多尝试 100 个集羆
		if placed >= total:
			break
		var center := _find_cell_in_biome(biome_id)
		if center == Vector2i.ZERO:
			continue
		# 在这个中心周围撒一批
		var batch := mini(clamp(rng.randi_range(cluster_size[0], cluster_size[1]), cluster_size[0], cluster_size[1]), total - placed)
		for i in batch:
			var offset := Vector2i(rng.randi_range(-3, 3), rng.randi_range(-3, 3))
			var cell := center + offset
			if _is_spawn_safe(cell) or _is_reserved_cell(cell):
				continue
			if cell.x <= 1 or cell.y <= 1 or cell.x >= MAP_W - 1 or cell.y >= MAP_H - 1:
				continue
			var atlas := _ground.get_cell_atlas_coords(cell)
			if atlas == STONE_TILE or atlas == WATER_TILE:
				continue
			if BiomeDefs.get_biome_at(cell, map_seed) != biome_id:
				continue
			_spawn_resource(cell, res_id, display_name, min_amt, max_amt, color)
			placed += 1


## 在指定群系内找一个可放置资源的空地
func _find_cell_in_biome(biome_id: String) -> Vector2i:
	for attempt in 400:
		var cell := Vector2i(_rng.randi_range(1, MAP_W - 2), _rng.randi_range(1, MAP_H - 2))
		if _is_spawn_safe(cell) or _is_reserved_cell(cell):
			continue
		var atlas := _ground.get_cell_atlas_coords(cell)
		if atlas == STONE_TILE or atlas == WATER_TILE:
			continue
		if BiomeDefs.get_biome_at(cell, map_seed) != biome_id:
			continue
		return cell
	return Vector2i.ZERO


## 谜题模板：压力板密室（门 + 门外压力板 + 房间奖励）和能量管道，按本局锚点摆放
func _build_puzzles(with_rewards: bool) -> void:
	var anchor := puzzle_anchor
	# 1) 压力板密室：石墙围起来，西墙开 2 格门洞
	for y in range(anchor.y, anchor.y + PUZZLE_SIZE.y):
		for x in range(anchor.x, anchor.x + PUZZLE_SIZE.x):
			var cell := Vector2i(x, y)
			var is_border := x == anchor.x or x == anchor.x + PUZZLE_SIZE.x - 1 \
				or y == anchor.y or y == anchor.y + PUZZLE_SIZE.y - 1
			_ground.set_cell(cell, 0, STONE_TILE if is_border else GRASS_TILE)
	# 门洞 + 门前空地清成草地（x 只到 26，房间西墙 x=27 只挖门洞那几格）
	for off in DOORWAY_OFFSETS:
		_ground.set_cell(anchor + off, 0, GRASS_TILE)
	for x in range(anchor.x - 3, anchor.x):
		for y in range(anchor.y + 1, anchor.y + 4):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)
	# 生成门和压力板（门盖住 2 格门洞）
	var door: StaticBody2D = DOOR_SCENE.instantiate()
	var door_cell := anchor + DOORWAY_OFFSETS[0]
	var doorway_center := Vector2(door_cell.x * TILE_SIZE + TILE_SIZE, (door_cell.y + 1) * TILE_SIZE + 16)
	door.global_position = doorway_center
	add_child(door)
	var plate: Node2D = PLATE_SCENE.instantiate()
	plate.global_position = Vector2((anchor + PLATE_OFFSET).x * TILE_SIZE + 16, (anchor + PLATE_OFFSET).y * TILE_SIZE + 16)
	plate.door = door
	add_child(plate)
	# 房间内奖励资源（仅全新开局）：2 铁矿石 + 3 根 + 2 石头
	if with_rewards:
		var rewards := [
			{"cell": anchor + Vector2i(2, 2), "id": "iron", "name": "铁矿石", "min": 1, "max": 2, "color": Color(0.4, 0.5, 0.8)},
			{"cell": anchor + Vector2i(3, 3), "id": "iron", "name": "铁矿石", "min": 1, "max": 2, "color": Color(0.4, 0.5, 0.8)},
			{"cell": anchor + Vector2i(1, 3), "id": "wood", "name": "木材", "min": 1, "max": 2, "color": Color(0.35, 0.65, 0.25)},
			{"cell": anchor + Vector2i(3, 4), "id": "wood", "name": "木材", "min": 1, "max": 2, "color": Color(0.35, 0.65, 0.25)},
			{"cell": anchor + Vector2i(1, 4), "id": "wood", "name": "木材", "min": 1, "max": 2, "color": Color(0.35, 0.65, 0.25)},
			{"cell": anchor + Vector2i(2, 4), "id": "stone", "name": "石头", "min": 2, "max": 3, "color": Color(0.55, 0.55, 0.55)},
			{"cell": anchor + Vector2i(3, 2), "id": "stone", "name": "石头", "min": 2, "max": 3, "color": Color(0.55, 0.55, 0.55)},
		]
		for r in rewards:
			_spawn_resource(r["cell"], r["id"], r["name"], r["min"], r["max"], r["color"])
	# 2) 能量管道：一排 4 根，地面清成草地
	for off in PIPE_OFFSETS:
		_ground.set_cell(anchor + off, 0, GRASS_TILE)
	_pipes = []
	for off in PIPE_OFFSETS:
		var pipe: Node2D = PIPE_SCENE.instantiate()
		pipe.global_position = Vector2((anchor + off).x * TILE_SIZE + 16, (anchor + off).y * TILE_SIZE + 16)
		add_child(pipe)
		_pipes.append(pipe)


## 解谜扩展：遗迹密室（密码锁 + 遗迹装置 联动）与双子机关碑（联动谜题 2）
func _build_relic_puzzles(with_rewards: bool) -> void:
	_build_relic_chamber(with_rewards)
	_build_twin_altars()


## 遗迹密室：7×6 石墙房间，北墙门洞装门；屋内是遗迹装置 + 密码锁
func _build_relic_chamber(with_rewards: bool) -> void:
	var anchor := relic_anchor
	# 石墙围合的密室，地面铺符文石板
	for y in range(anchor.y, anchor.y + RELIC_ROOM_SIZE.y):
		for x in range(anchor.x, anchor.x + RELIC_ROOM_SIZE.x):
			var cell := Vector2i(x, y)
			var is_border := x == anchor.x or x == anchor.x + RELIC_ROOM_SIZE.x - 1 \
				or y == anchor.y or y == anchor.y + RELIC_ROOM_SIZE.y - 1
			_ground.set_cell(cell, 0, STONE_TILE if is_border else RUNE_TILE)
	# 北墙门洞（2 列 × 3 行）+ 门外 2 行清地
	for off in RELIC_DOORWAY_OFFSETS:
		_ground.set_cell(anchor + off, 0, GRASS_TILE)
	for x in range(anchor.x + 1, anchor.x + RELIC_ROOM_SIZE.x - 1):
		for y in range(anchor.y - 2, anchor.y):
			_ground.set_cell(Vector2i(x, y), 0, GRASS_TILE)
	# 门：盖住北墙门洞（与压力板密室同一门模板）
	var door: StaticBody2D = DOOR_SCENE.instantiate()
	var door_cell := anchor + Vector2i(2, 0)
	door.global_position = Vector2(door_cell.x * TILE_SIZE + TILE_SIZE, door_cell.y * TILE_SIZE + 16)
	add_child(door)
	# 密码锁：南墙内侧（玩家站在屋内按 E 交互）
	var keypad: Node2D = KEYPAD_SCENE.instantiate()
	keypad.code = _relic_code
	keypad.linked_door = door
	keypad.global_position = Vector2((anchor.x + RELIC_ROOM_SIZE.x / 2) * TILE_SIZE + 16, (anchor.y + RELIC_ROOM_SIZE.y - 1) * TILE_SIZE + 16)
	add_child(keypad)
	# 遗迹装置：房间中央偏西，4 个符文环绕
	var device: Node2D = RELIC_SCENE.instantiate()
	device.sequence = _relic_sequence.duplicate()
	device.linked_keypad = keypad
	device.global_position = Vector2((anchor.x + 2) * TILE_SIZE + 16, (anchor.y + 3) * TILE_SIZE + 16)
	add_child(device)
	# 房间内小奖励（仅全新开局）
	if with_rewards:
		_spawn_resource(anchor + Vector2i(4, 2), "rune_stone", "符文石", 1, 2, Color(0.55, 0.7, 0.85))
		_spawn_resource(anchor + Vector2i(4, 3), "parts", "零件", 1, 2, Color(0.8, 0.7, 0.35))


## 双子机关碑：两座石碑（A 先 B 后），周围清成草地当平台
func _build_twin_altars() -> void:
	var a: Node2D = ALTAR_SCENE.instantiate()
	a.is_first = true
	a.global_position = Vector2(altar_a_cell) * TILE_SIZE + Vector2(16, 16)
	add_child(a)
	var b: Node2D = ALTAR_SCENE.instantiate()
	b.is_first = false
	b.global_position = Vector2(altar_b_cell) * TILE_SIZE + Vector2(16, 16)
	add_child(b)
	a.partner = b
	b.partner = a
	for cell in [altar_a_cell, altar_b_cell]:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_ground.set_cell(cell + Vector2i(dx, dy), 0, GRASS_TILE)


## 读档恢复谜题进度：已解的锁/装置/石碑保持解开，不重复发奖
func _restore_puzzle_states(saved_puzzles: Array) -> void:
	for state in saved_puzzles:
		match str(state.get("type", "")):
			"keypad":
				for k in get_tree().get_nodes_in_group("keypad_locks"):
					k.apply_state(state)
					break
			"relic":
				for r in get_tree().get_nodes_in_group("relic_devices"):
					r.apply_state(state)
					break
			"altar":
				for a in get_tree().get_nodes_in_group("twin_altars"):
					a.apply_state(state)


## 读档时按存档列表恢复资源（采集过的不会复活）
func _spawn_saved_resources(saved: Array) -> void:
	for r in saved:
		var meta: Dictionary = RESOURCE_META.get(r.id, {"name": r.id, "color": Color(0.6, 0.6, 0.6)})
		var node: Node2D = RESOURCE_SCENE.instantiate()
		node.resource_id = r.id
		node.resource_name = meta["name"]
		node.amount = r.amount
		node.color = meta["color"]
		node.global_position = Vector2(r.x, r.y)
		add_child(node)


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


func _is_spawn_safe(cell: Vector2i) -> bool:
	return Vector2(cell - SPAWN_CELL).length() < float(SPAWN_SAFE_RADIUS)


## 出生安全区方形判定：与 _build_spawn_safe_zone 清出的草地范围一致。
## 圆形判定（_is_spawn_safe）允许房间墙侵入方形角落（如 (92,82) 距出生点 10.6 格，
## 在圆形外但在方形内），导致安全区角落出现石头。
func _is_spawn_safe_box(cell: Vector2i) -> bool:
	return absi(cell.x - SPAWN_CELL.x) <= SPAWN_SAFE_RADIUS and absi(cell.y - SPAWN_CELL.y) <= SPAWN_SAFE_RADIUS


## 谜题占用的格子：随机资源不要刷进去
func _is_puzzle_cell(cell: Vector2i) -> bool:
	return cell in puzzle_cells


## 保留格：谜题 + 暗域广场（结构/随机资源不要刷进去）
func _is_reserved_cell(cell: Vector2i) -> bool:
	if _is_puzzle_cell(cell):
		return true
	for rect in _lair_rects:
		if rect.has_point(cell):
			return true
	return false
