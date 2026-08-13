extends SceneTree
## 地图布局验证脚本（临时）：检查群系占比、关键地标所在群系、世界场景能否正常生成
## 运行：godot --headless --path . --script res://tests/map_layout_check.gd
## 结果写入 user://map_layout_report.txt（headless 下 stdout 不可见）

const MAP_W := 200
const MAP_H := 150
const SEED := 12345
const REPORT_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_layout_report.txt"
const ASCII_FULL_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_ascii_full.txt"
const ASCII_SMALL_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_ascii_small.txt"
const TILE_DUMP_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_tiles.txt"
const ROAD_GRID_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_roads_grid.txt"
const ROAD_ASCII_PATH := "E:/Codex/游戏项目/wasteland-echo/tests/map_roads_ascii_small.txt"

var _frames := 0
var _log := ""
var _world_signature_prev := ""


func _initialize() -> void:
	_log = ""
	_log += "== 引擎版本 ==\n" + Engine.get_version_info()["string"] + "\n"
	_verify_biome_layout()
	_log += "== 开始实例化世界场景 ==\n"
	_flush()
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_log += "== 场景实例化完成，准备 add_child ==\n"
	_flush()
	root.add_child(world)
	_log += "== add_child 完成（generate 已执行） ==\n"
	_flush()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		var world := root.get_node_or_null("World")
		if world == null:
			_log += "错误：World 场景未加载\n"
			_flush()
			quit(1)
			return true
		var ground := world.get_node("Ground") as TileMapLayer
		var resource_count := get_nodes_in_group("resource_nodes").size()
		var biome_grid: Array = world._biome_grid
		_log += "map_seed = %d\n" % world.map_seed
		_log += "ground cells = %d / %d\n" % [ground.get_used_cells().size(), MAP_W * MAP_H]
		_log += "resource_nodes = %d\n" % resource_count
		_log += "biome_grid size = %d\n" % biome_grid.size()
		_log += "workbenches = %d\n" % get_nodes_in_group("workbenches").size()
		_log += "enemies(surface) = %d\n" % get_nodes_in_group("enemies").size()
		# v2 规则：地标模板 + 放置间距 + 刷怪器同步
		var puzzle_anchor: Vector2i = world.puzzle_anchor
		var hub_cell: Vector2i = world.hub_cell
		var portal_cell: Vector2i = world.portal_cell
		var spawn_cell: Vector2i = world.SPAWN_CELL
		var d_spawn_puzzle := Vector2(puzzle_anchor - spawn_cell).length()
		var d_spawn_hub := Vector2(hub_cell - spawn_cell).length()
		var d_puzzle_hub := Vector2(hub_cell - puzzle_anchor).length()
		var d_hub_portal := Vector2(portal_cell - hub_cell).length()
		var spawner := world.get_node("EnemySpawner")
		var hub_synced: bool = spawner.hub_center.distance_to(Vector2(hub_cell.x * 32 + 16, hub_cell.y * 32 + 16)) < 1.0
		var spawn_safe_synced: bool = spawner.spawn_safe_center.distance_to(Vector2(spawn_cell.x * 32 + 16, spawn_cell.y * 32 + 16)) < 1.0
		_log += "谜题锚点=%s(%s) 聚集地=%s(%s) 传送门=%s(%s)\n" % [
			str(puzzle_anchor), BiomeDefs.get_biome_at(puzzle_anchor + Vector2i(2, 3), world.map_seed),
			str(hub_cell), BiomeDefs.get_biome_at(hub_cell, world.map_seed),
			str(portal_cell), BiomeDefs.get_biome_at(portal_cell, world.map_seed)]
		_log += "距离：出生点→谜题=%.1f 出生点→聚集地=%.1f 谜题→聚集地=%.1f 聚集地→传送门=%.1f\n" % [d_spawn_puzzle, d_spawn_hub, d_puzzle_hub, d_hub_portal]
		_log += "道路格数 = %d（成功连通 %d/20 段），刷怪器聚集地同步 = %s\n" % [world._road_cells_count, world._road_segments_ok, str(hub_synced)]
		_log += "刷怪安全区：中心同步 = %s，半径 = %.0f px，开局安全期 = %.0f 秒\n" % [str(spawn_safe_synced), spawner.spawn_safe_radius, spawner.grace_duration]
		if d_spawn_hub < 20.0:
			_log += "错误：聚集地离出生点太近！\n"
		if d_spawn_puzzle < 12.0 or d_spawn_puzzle > 19.0:
			_log += "错误：谜题距离不合规！\n"
		if d_hub_portal < 12.0:
			_log += "错误：传送门离聚集地太近！\n"
		if not hub_synced:
			_log += "错误：刷怪器聚集地中心未同步！\n"
		if not spawn_safe_synced:
			_log += "错误：刷怪器出生点安全区中心未同步！\n"
		if world._road_cells_count <= 0:
			_log += "错误：没有铺出道路！\n"
		if world._road_segments_ok < 20:
			_log += "错误：道路未完全连通各地标！\n"
		# 可达性：从出生点 BFS，确认玩家能走到传送门和所有巢穴
		var reach_info := _check_reachability(world)
		_log += "可达性：可走区域 = %d%%（%d/%d 格），传送门可达 = %s，巢穴门可达 = %d/14\n" % [
			reach_info["pct"], reach_info["reachable"], reach_info["total"], str(reach_info["portal_ok"]), reach_info["lairs_ok"]]
		_log += "巢穴可达明细：%s\n" % str(reach_info["lair_hits"].keys())
		_log += "巢穴门口可达：%s\n" % str(reach_info["gate_hits"].keys())
		_log += "关键地点可达：%s\n" % str(reach_info["extra_hits"].keys())
		for t in ["谜题门口", "聚集地", "工作台"]:
			if not reach_info["extra_hits"].has(t):
				_log += "错误：%s 不可达！\n" % t
		if reach_info["gate_hits"].size() < 14:
			for miss in ["暗域", "冰脉", "爆炎", "辐射", "机械", "沼泽", "峡谷", "天空", "沙丘", "雷鸣", "真菌", "遗迹", "墓园", "绿洲"]:
				if not reach_info["gate_hits"].has(miss):
					_log += _dump_gate_area(world, miss)
		if not reach_info["portal_ok"] or reach_info["lairs_ok"] < 14:
			_log += "错误：出生点无法到达关键地标！\n"
		# v3：暗域之城内容
		var tyrant_count := 0
		var parts_nodes := 0
		var darkstone_nodes := 0
		var frost_nodes := 0
		var ember_nodes := 0
		var rad_nodes := 0
		var gear_nodes := 0
		var herb_nodes := 0
		var gem_nodes := 0
		var sky_nodes := 0
		var salt_nodes := 0
		var fiber_nodes := 0
		var thunder_nodes := 0
		var shroom_nodes := 0
		var spore_nodes := 0
		var rune_nodes := 0
		var relic_nodes := 0
		var ember2_nodes := 0
		var bone_nodes := 0
		var water_nodes := 0
		var herb2_nodes := 0
		for e in get_nodes_in_group("enemies"):
			if e.enemy_type in ["tyrant", "frost_lord", "flame_lord", "rad_lord", "mech_overlord", "swamp_lord", "canyon_lord", "sky_dragon", "sand_lord", "storm_lord", "fungal_lord", "relic_lord", "wraith_lord", "oasis_lord"]:
				tyrant_count += 1
		for n in get_nodes_in_group("resource_nodes"):
			if n.resource_id == "parts":
				parts_nodes += 1
			elif n.resource_id == "darkstone":
				darkstone_nodes += 1
			elif n.resource_id == "frost_crystal":
				frost_nodes += 1
			elif n.resource_id == "ember":
				ember_nodes += 1
			elif n.resource_id == "rad_dust":
				rad_nodes += 1
			elif n.resource_id == "gear":
				gear_nodes += 1
			elif n.resource_id == "swamp_herb":
				herb_nodes += 1
			elif n.resource_id == "gem":
				gem_nodes += 1
			elif n.resource_id == "sky_crystal":
				sky_nodes += 1
			elif n.resource_id == "salt_crystal":
				salt_nodes += 1
			elif n.resource_id == "cactus_fiber":
				fiber_nodes += 1
			elif n.resource_id == "thunder_crystal":
				thunder_nodes += 1
			elif n.resource_id == "glow_shroom":
				shroom_nodes += 1
			elif n.resource_id == "spore":
				spore_nodes += 1
			elif n.resource_id == "rune_stone":
				rune_nodes += 1
			elif n.resource_id == "relic":
				relic_nodes += 1
			elif n.resource_id == "soul_ember":
				ember2_nodes += 1
			elif n.resource_id == "bone":
				bone_nodes += 1
			elif n.resource_id == "clean_water":
				water_nodes += 1
			elif n.resource_id == "oasis_herb":
				herb2_nodes += 1
		_log += "大Boss = %d/14，零件 = %d，暗石 = %d，冰晶 = %d，余烬 = %d，辐射尘 = %d，齿轮 = %d，草药 = %d，宝石 = %d，天晶 = %d\n" % [tyrant_count, parts_nodes, darkstone_nodes, frost_nodes, ember_nodes, rad_nodes, gear_nodes, herb_nodes, gem_nodes, sky_nodes]
		_log += "新群系资源：盐晶 = %d，纤维 = %d，雷晶 = %d，荧光菇 = %d，孢子 = %d，符文石 = %d，古物 = %d，灵魂余烬 = %d，白骨 = %d，净水 = %d，绿洲草药 = %d\n" % [salt_nodes, fiber_nodes, thunder_nodes, shroom_nodes, spore_nodes, rune_nodes, relic_nodes, ember2_nodes, bone_nodes, water_nodes, herb2_nodes]
		if tyrant_count < 14:
			_log += "错误：群系大Boss未全部生成（%d/14）！\n" % tyrant_count
		if parts_nodes < 10:
			_log += "错误：零件资源点过少！\n"
		if darkstone_nodes < 8:
			_log += "错误：暗石资源点过少！\n"
		if frost_nodes < 10:
			_log += "错误：冰晶资源点过少！\n"
		if ember_nodes < 8:
			_log += "错误：余烬资源点过少！\n"
		if rad_nodes < 8:
			_log += "错误：辐射尘资源点过少！\n"
		if gear_nodes < 8:
			_log += "错误：齿轮资源点过少！\n"
		if herb_nodes < 8:
			_log += "错误：沼泽草药资源点过少！\n"
		if gem_nodes < 8:
			_log += "错误：宝石资源点过少！\n"
		if sky_nodes < 6:
			_log += "错误：天空晶石资源点过少！\n"
		if salt_nodes < 8:
			_log += "错误：盐晶资源点过少！\n"
		if fiber_nodes < 6:
			_log += "错误：仙人掌纤维资源点过少！\n"
		if thunder_nodes < 8:
			_log += "错误：雷晶资源点过少！\n"
		if shroom_nodes < 8:
			_log += "错误：荧光菇资源点过少！\n"
		if spore_nodes < 6:
			_log += "错误：孢子资源点过少！\n"
		if rune_nodes < 6:
			_log += "错误：符文石资源点过少！\n"
		if relic_nodes < 4:
			_log += "错误：古物资源点过少！\n"
		if ember2_nodes < 7:
			_log += "错误：灵魂余烬资源点过少！\n"
		if bone_nodes < 4:
			_log += "错误：白骨资源点过少！\n"
		if water_nodes < 6:
			_log += "错误：净水资源点过少！\n"
		if herb2_nodes < 4:
			_log += "错误：绿洲草药资源点过少！\n"
		# 细节检查：实体不得卡在挡路石头上
		var on_stone := _count_nodes_on_stone(world)
		_log += "卡在石头上的实体：资源=%d 怪物=%d 建筑/机关=%d\n" % [on_stone["resources"], on_stone["enemies"], on_stone["buildings"]]
		if on_stone["resources"] + on_stone["enemies"] + on_stone["buildings"] > 0:
			_log += "错误：有实体卡在石头上！\n"
		# 边界必须封死（玩家走不出去）
		var border_ok := _check_border(world)
		_log += "边界石墙完整 = %s\n" % str(border_ok)
		if not border_ok:
			_log += "错误：边界存在缺口！\n"
		# 出生安全区必须纯净（纯草地、无怪无资源）
		var spawn_detail := _check_spawn_zone(world)
		_log += "出生安全区纯净 = %s\n" % str(spawn_detail["ok"])
		if not spawn_detail["ok"]:
			_log += "错误：出生安全区有杂质！%s\n" % spawn_detail["detail"]
		_flush()
		_dump_ascii(biome_grid)
		_dump_tiles(ground)
		_dump_road_overlay(world)
	elif _frames == 6:
		# 同种子再生一致性：同一地图种子应生成完全相同的图与资源
		var world := root.get_node_or_null("World")
		if world == null:
			return false
		_world_signature_prev = _world_signature(world)
		world.generate(world.map_seed, [], [])
		_log += "== 已用同一种子重新生成，等待帧结算 ==\n"
		_flush()
	elif _frames == 7:
		var world := root.get_node_or_null("World")
		if world == null:
			return false
		var sig2 := _world_signature(world)
		_log += "同种子再生一致性 = %s\n" % str(_world_signature_prev == sig2)
		if _world_signature_prev != sig2:
			_log += "错误：同一种子两次生成结果不一致！\n"
			var parts1: PackedStringArray = _world_signature_prev.split("\n")
			var parts2: PackedStringArray = sig2.split("\n")
			_log += "  差异：群系图一致 = %s，瓦片一致 = %s，资源列表一致 = %s\n" % [str(parts1[0] == parts2[0]), str(parts1[1] == parts2[1]), str(parts1[2] == parts2[2])]
			if parts1[1] != parts2[1]:
				var t1: String = parts1[1]
				var t2: String = parts2[1]
				var ti := 0
				while ti < mini(t1.length(), t2.length()):
					if t1[ti] != t2[ti]:
						var cell_idx := ti / 4
						_log += "  第 %d 个瓦片不同（格子 %d,%d）：第一次=%s 第二次=%s\n" % [cell_idx, cell_idx % MAP_W, cell_idx / MAP_W, t1.substr(ti, 3), t2.substr(ti, 3)]
						break
					ti += 1
			if parts1[2] != parts2[2]:
				var a: Array = JSON.parse_string(parts1[2])
				var b: Array = JSON.parse_string(parts2[2])
				_log += "  资源数量：第一次=%d 第二次=%d\n" % [a.size(), b.size()]
				_log += "  第一次前5：%s\n" % str(a.slice(0, 5))
				_log += "  第二次前5：%s\n" % str(b.slice(0, 5))
				var i2 := 0
				while i2 < mini(a.size(), b.size()):
					if a[i2] != b[i2]:
						_log += "  第 %d 个资源不同：第一次=%s 第二次=%s\n" % [i2, str(a[i2]), str(b[i2])]
						break
					i2 += 1
		_flush()
		_log += "== 开始实例化地心世界 ==\n"
		_flush()
		var underworld: Node = (load("res://scenes/underworld.tscn") as PackedScene).instantiate()
		underworld.name = "Underworld"
		root.add_child(underworld)
		_log += "== 地心世界 add_child 完成 ==\n"
		_flush()
	elif _frames == 10:
		var uw := root.get_node_or_null("Underworld")
		if uw == null:
			_log += "错误：Underworld 场景未加载\n"
			_flush()
			quit(1)
			return true
		var uw_ground := uw.get_node("Ground") as TileMapLayer
		_log += "underworld ground cells = %d / %d\n" % [uw_ground.get_used_cells().size(), 30 * 24]
		_log += "underworld enemies = %d\n" % get_nodes_in_group("enemies").size()
		_log += "== 全部验证完成 ==\n"
		_flush()
		quit(0)
		return true
	return false


## 把地面瓦片转成字符网格（g=草地 m=泥地 s=石头 w=水 i=冰 n=雪 l=岩浆 c=焦岩 x=辐射土 q=毒沼 e=金属板 u=锈蚀），供生成预览图
func _dump_tiles(ground: TileMapLayer) -> void:
	var text := ""
	for y in MAP_H:
		var row := ""
		for x in MAP_W:
			var atlas: Vector2i = ground.get_cell_atlas_coords(Vector2i(x, y))
			if atlas == Vector2i(0, 0):
				row += "g"
			elif atlas == Vector2i(1, 0):
				row += "m"
			elif atlas == Vector2i(0, 1):
				row += "s"
			elif atlas == Vector2i(2, 0):
				row += "i"
			elif atlas == Vector2i(3, 0):
				row += "n"
			elif atlas == Vector2i(2, 1):
				row += "l"
			elif atlas == Vector2i(3, 1):
				row += "c"
			elif atlas == Vector2i(0, 2):
				row += "x"
			elif atlas == Vector2i(1, 2):
				row += "q"
			elif atlas == Vector2i(2, 2):
				row += "e"
			elif atlas == Vector2i(3, 2):
				row += "u"
			elif atlas == Vector2i(0, 3):
				row += "a"  # 沙地
			elif atlas == Vector2i(1, 3):
				row += "h"  # 菌地
			elif atlas == Vector2i(2, 3):
				row += "o"  # 符文石板
			elif atlas == Vector2i(3, 3):
				row += "t"  # 墓土
			else:
				row += "w"
		text += row + "\n"
	var f := FileAccess.open(TILE_DUMP_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


## 道路叠加图：+ = 道路，S = 出生点，P = 谜题，H = 聚集地，T = 传送门
func _dump_road_overlay(world: Node) -> void:
	var road_set := {}
	for c in world.road_cells:
		road_set[c] = true
	var grid: Array[String] = []
	var grid_plain := ""
	for y in MAP_H:
		var row := ""
		for x in MAP_W:
			var cell := Vector2i(x, y)
			var ch := "."
			if road_set.has(cell):
				ch = "+"
			row += ch
		grid.append(row)
		grid_plain += row + "\n"
	var f1 := FileAccess.open(ROAD_GRID_PATH, FileAccess.WRITE)
	if f1 != null:
		f1.store_string(grid_plain)
		f1.close()
	# 4×4 降采样概览：优先显示地标字母，其次显示道路 +
	var small := ""
	for y0 in range(0, MAP_H, 4):
		var small_row := ""
		for x0 in range(0, MAP_W, 4):
			var ch := "."
			for dy in range(4):
				for dx in range(4):
					var cell := Vector2i(x0 + dx, y0 + dy)
					var mark := "."
					if road_set.has(cell):
						mark = "+"
					if cell == world.SPAWN_CELL:
						mark = "S"
					elif cell == world.puzzle_anchor:
						mark = "P"
					elif cell == world.hub_cell:
						mark = "H"
					elif cell == world.portal_cell:
						mark = "T"
					if mark != ".":
						ch = mark
						break
				if ch != ".":
					break
			small_row += ch
		small += small_row + "\n"
	var f2 := FileAccess.open(ROAD_ASCII_PATH, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(small)
		f2.close()


## 把群系图转成 ASCII 概览，方便直接看区域布局
## 字母：w=废土 f=林地 r=石丘 D=暗域之城 .=未来群系 B=边界
func _dump_ascii(biome_grid: Array) -> void:
	var full := ""
	var small := ""
	for y in MAP_H:
		var row := ""
		for x in MAP_W:
			row += _biome_char(biome_grid[y * MAP_W + x])
		full += row + "\n"
		# 4×4 降采样（取块内左上角），生成一张小概览图
		if y % 4 == 0:
			var small_row := ""
			for x in range(0, MAP_W, 4):
				small_row += _biome_char(biome_grid[y * MAP_W + x])
			small += small_row + "\n"
	var f1 := FileAccess.open(ASCII_FULL_PATH, FileAccess.WRITE)
	if f1 != null:
		f1.store_string(full)
		f1.close()
	var f2 := FileAccess.open(ASCII_SMALL_PATH, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(small)
		f2.close()


func _biome_char(biome_id: String) -> String:
	match biome_id:
		"border":
			return "B"
		"wasteland":
			return "w"
		"forest":
			return "f"
		"rocky":
			return "r"
		"dark_city":
			return "D"
		"ice_vein":
			return "I"
		"flame_city":
			return "F"
		"rad_waste":
			return "R"
		"mech_ruins":
			return "M"
		"swamp":
			return "s"
		"canyon":
			return "C"
		"sky_island":
			return "Y"
		"dune_wastes":
			return "U"
		"thunder_highlands":
			return "K"
		"fungal_grove":
			return "H"
		"ancient_relics":
			return "A"
		"ghost_graveyard":
			return "X"
		"life_oasis":
			return "O"
	return "."


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_log)
		file.close()


## 调试：转储某个巢穴门口周边 13×13 的瓦片（s=石头 其他=可通行），并标出门口位置
func _dump_gate_area(world: Node, lair_name: String) -> String:
	var centers := {
		"暗域": Vector2i(150, 120), "冰脉": Vector2i(30, 78), "爆炎": Vector2i(48, 122),
		"辐射": Vector2i(170, 78), "机械": Vector2i(100, 134), "沼泽": Vector2i(42, 40),
		"峡谷": Vector2i(158, 40), "天空": Vector2i(100, 26),
		"沙丘": Vector2i(22, 44), "雷鸣": Vector2i(178, 44), "真菌": Vector2i(36, 112),
		"遗迹": Vector2i(126, 136), "墓园": Vector2i(168, 110), "绿洲": Vector2i(72, 30),
	}
	var ground := world.get_node("Ground") as TileMapLayer
	var c: Vector2i = centers[lair_name]
	var out := "  [%s 门口周边] 门口=(%d,%d) 中心=(%d,%d)\n" % [lair_name, c.x, c.y - 5, c.x, c.y]
	var gate := Vector2i(c.x, c.y - 5)
	out += "  门口在道路格列表 = %s，门口瓦片 = %s\n" % [str(gate in world.road_cells), str(ground.get_cell_atlas_coords(gate))]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = gate + d
		out += "  邻格(%d,%d) 瓦片=%s 在道路=%s\n" % [n.x, n.y, str(ground.get_cell_atlas_coords(n)), str(n in world.road_cells)]
	for y in range(c.y - 9, c.y + 4):
		var row := ""
		for x in range(c.x - 6, c.x + 7):
			var atlas := ground.get_cell_atlas_coords(Vector2i(x, y))
			var ch := "."
			if atlas == Vector2i(0, 1):
				ch = "#"  # 石头（挡路）
			if x == c.x and y == c.y - 5:
				ch = "G"  # 门口
			elif x == c.x and y == c.y:
				ch = "B"  # Boss
			row += ch
		out += "  %s\n" % row
	return out


## 世界签名：群系图 + 资源位置（用于验证同种子生成一致性）
func _world_signature(world: Node) -> String:
	var parts: Array[String] = []
	parts.append(JSON.stringify(world._biome_grid))
	# 瓦片网格（压缩为字符）
	var ground := world.get_node("Ground") as TileMapLayer
	var tile_str := ""
	for y in MAP_H:
		for x in MAP_W:
			var atlas := ground.get_cell_atlas_coords(Vector2i(x, y))
			tile_str += "%d,%d;" % [atlas.x, atlas.y]
	parts.append(tile_str)
	var res: Array[String] = []
	for n in get_nodes_in_group("resource_nodes"):
		res.append("%s:%.0f,%.0f" % [n.resource_id, n.global_position.x, n.global_position.y])
	res.sort()
	parts.append(JSON.stringify(res))
	return "\n".join(parts)


## 统计卡在挡路石头（STONE_TILE）上的实体
func _count_nodes_on_stone(world: Node) -> Dictionary:
	var ground := world.get_node("Ground") as TileMapLayer
	var res := 0
	var enemies := 0
	var buildings := 0
	for n in get_nodes_in_group("resource_nodes") + get_nodes_in_group("enemies") \
			+ get_nodes_in_group("doors") + get_nodes_in_group("pressure_plates") \
			+ get_nodes_in_group("power_pipes") + get_nodes_in_group("portals") + get_nodes_in_group("workbenches"):
		var cell := Vector2i(floori(n.global_position.x / 32.0), floori(n.global_position.y / 32.0))
		if ground.get_cell_atlas_coords(cell) != Vector2i(0, 1):
			continue
		if n.is_in_group("resource_nodes"):
			res += 1
		elif n.is_in_group("enemies"):
			enemies += 1
		else:
			buildings += 1
	return {"resources": res, "enemies": enemies, "buildings": buildings}


## 边界必须全石墙（玩家走不出地图）
func _check_border(world: Node) -> bool:
	var ground := world.get_node("Ground") as TileMapLayer
	for x in MAP_W:
		for y in [0, MAP_H - 1]:
			if ground.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(0, 1):
				return false
	for y in MAP_H:
		for x in [0, MAP_W - 1]:
			if ground.get_cell_atlas_coords(Vector2i(x, y)) != Vector2i(0, 1):
				return false
	return true


## 出生安全区：SPAWN_SAFE_RADIUS 内必须全草地，且无怪物/资源（工作台是刻意放的"家"）
func _check_spawn_zone(world: Node) -> Dictionary:
	var ground := world.get_node("Ground") as TileMapLayer
	var spawn: Vector2i = world.SPAWN_CELL
	var safe: int = world.SPAWN_SAFE_RADIUS
	for y in range(spawn.y - safe, spawn.y + safe + 1):
		for x in range(spawn.x - safe, spawn.x + safe + 1):
			var cell := Vector2i(x, y)
			var atlas := ground.get_cell_atlas_coords(cell)
			# 草地或"出营地小路"（泥地路格）都算纯净
			if atlas != Vector2i(0, 0) and not (atlas == Vector2i(1, 0) and cell in world.road_cells):
				return {"ok": false, "detail": "格子(%d,%d)瓦片=%s非草地" % [x, y, str(atlas)]}
	var center := Vector2(spawn) * 32.0 + Vector2(16.0, 16.0)  # 格子中心（与 _is_spawn_safe 的圆心一致）
	for n in get_nodes_in_group("enemies") + get_nodes_in_group("resource_nodes"):
		if n.global_position.distance_to(center) < float(safe) * 32.0:
			var label := "实体"
			if "resource_id" in n:
				label = n.resource_id
			elif "enemy_type" in n:
				label = n.enemy_type
			return {"ok": false, "detail": "%s 出现在安全区内(%s)" % [label, str(n.global_position)]}
	return {"ok": true, "detail": ""}


## 从出生点 BFS：统计可走区域占比，并检查传送门 / 8 个巢穴中心是否可达
func _check_reachability(world: Node) -> Dictionary:
	var ground := world.get_node("Ground") as TileMapLayer
	var start: Vector2i = world.SPAWN_CELL
	var lair_centers := [
		Vector2i(150, 120), Vector2i(30, 78), Vector2i(48, 122), Vector2i(170, 78),
		Vector2i(100, 134), Vector2i(42, 40), Vector2i(158, 40), Vector2i(100, 26),
		Vector2i(22, 44), Vector2i(178, 44), Vector2i(36, 112), Vector2i(126, 136),
		Vector2i(168, 110), Vector2i(72, 30),
	]
	var lair_gates := [
		Vector2i(150, 115), Vector2i(30, 73), Vector2i(48, 117), Vector2i(170, 73),
		Vector2i(100, 129), Vector2i(42, 35), Vector2i(158, 35), Vector2i(100, 21),
		Vector2i(22, 39), Vector2i(178, 39), Vector2i(36, 107), Vector2i(126, 131),
		Vector2i(168, 105), Vector2i(72, 25),
	]
	var lair_names := ["暗域", "冰脉", "爆炎", "辐射", "机械", "沼泽", "峡谷", "天空", "沙丘", "雷鸣", "真菌", "遗迹", "墓园", "绿洲"]
	var portal_cell: Vector2i = world.portal_cell
	var extra_targets := {
		"谜题门口": world.puzzle_anchor + Vector2i(-2, 1),
		"聚集地": world.hub_cell,
		"工作台": world.SPAWN_CELL + Vector2i(0, 3),
	}
	var is_walkable := func(cell: Vector2i) -> bool:
		if cell.x < 0 or cell.y < 0 or cell.x >= MAP_W or cell.y >= MAP_H:
			return false
		return ground.get_cell_atlas_coords(cell) != Vector2i(0, 1)  # STONE_TILE 挡路
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var reachable := 0
	var portal_ok := false
	var lairs_ok := 0
	var lair_hits := {}
	var gate_hits := {}
	var extra_hits := {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		reachable += 1
		if cell == portal_cell:
			portal_ok = true
		if cell in lair_centers:
			lairs_ok += 1
			lair_hits[lair_names[lair_centers.find(cell)]] = true
		if cell in lair_gates:
			gate_hits[lair_names[lair_gates.find(cell)]] = true
		for t in extra_targets:
			if cell == extra_targets[t]:
				extra_hits[t] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var nxt: Vector2i = cell + d
			if not visited.has(nxt) and is_walkable.call(nxt):
				# 物理连通：对角步需要两个转角格都可走，否则被石头"角夹住"过不去
				if absi(d.x) == 1 and absi(d.y) == 1:
					if not is_walkable.call(Vector2i(cell.x + d.x, cell.y)) \
							or not is_walkable.call(Vector2i(cell.x, cell.y + d.y)):
						continue
				visited[nxt] = true
				queue.append(nxt)
	return {
		"pct": int(round(reachable * 100.0 / (MAP_W * MAP_H))),
		"reachable": reachable,
		"total": MAP_W * MAP_H,
		"portal_ok": portal_ok,
		"lairs_ok": lairs_ok,
		"lair_hits": lair_hits,
		"gate_hits": gate_hits,
		"extra_hits": extra_hits,
	}


func _verify_biome_layout() -> void:
	var total := MAP_W * MAP_H
	var seeds := [12345, 2026, 77777, 424242, 1]
	for seed in seeds:
		var counts := {}
		var transition := 0
		for x in MAP_W:
			for y in MAP_H:
				var cell := Vector2i(x, y)
				var biome: String = BiomeDefs.get_biome_at(cell, seed)
				counts[biome] = counts.get(biome, 0) + 1
				if BiomeDefs.is_transition(cell, seed):
					transition += 1
		_log += "--- seed %d ---\n" % seed
		for b in counts:
			_log += "  %s = %d (%.1f%%)\n" % [b, counts[b], counts[b] * 100.0 / total]
		var surface_total: int = int(counts.get("wasteland", 0)) + int(counts.get("forest", 0)) + int(counts.get("rocky", 0))
		var ice_pct: float = float(counts.get("ice_vein", 0)) * 100.0 / total
		var flame_pct: float = float(counts.get("flame_city", 0)) * 100.0 / total
		var rad_pct: float = float(counts.get("rad_waste", 0)) * 100.0 / total
		var mech_pct: float = float(counts.get("mech_ruins", 0)) * 100.0 / total
		var swamp_pct: float = float(counts.get("swamp", 0)) * 100.0 / total
		var canyon_pct: float = float(counts.get("canyon", 0)) * 100.0 / total
		var sky_pct: float = float(counts.get("sky_island", 0)) * 100.0 / total
		var dune_pct: float = float(counts.get("dune_wastes", 0)) * 100.0 / total
		var thunder_pct: float = float(counts.get("thunder_highlands", 0)) * 100.0 / total
		var fungal_pct: float = float(counts.get("fungal_grove", 0)) * 100.0 / total
		var relic_pct: float = float(counts.get("ancient_relics", 0)) * 100.0 / total
		var grave_pct: float = float(counts.get("ghost_graveyard", 0)) * 100.0 / total
		var oasis_pct: float = float(counts.get("life_oasis", 0)) * 100.0 / total
		var future_pct: float = float(counts.get("future_wild", 0)) * 100.0 / total
		_log += "  过渡带 = %d 格，地表 = %.1f%% 暗域 = %.1f%% 冰脉 = %.1f%% 爆炎 = %.1f%% 辐射 = %.1f%% 机械 = %.1f%% 沼泽 = %.1f%% 峡谷 = %.1f%% 天空 = %.1f%% 沙丘 = %.1f%% 雷鸣 = %.1f%% 真菌 = %.1f%% 遗迹 = %.1f%% 墓园 = %.1f%% 绿洲 = %.1f%% 未来 = %.1f%%\n" % [
			transition, surface_total * 100.0 / total, counts.get("dark_city", 0) * 100.0 / total, ice_pct, flame_pct, rad_pct, mech_pct, swamp_pct, canyon_pct, sky_pct, dune_pct, thunder_pct, fungal_pct, relic_pct, grave_pct, oasis_pct, future_pct]
		# 关键地标必须落在普通地表内，暗域中心必须是暗域之城（v5 中枢布局）
		var spawn := BiomeDefs.get_biome_at(Vector2i(100, 75), seed)
		var puzzle := BiomeDefs.get_biome_at(Vector2i(112, 82), seed)
		var hub := BiomeDefs.get_biome_at(Vector2i(115, 78), seed)
		var dark := BiomeDefs.get_biome_at(Vector2i(150, 120), seed)
		_log += "  地标：出生点=%s 谜题=%s 聚集地=%s 暗域中心=%s\n" % [spawn, puzzle, hub, dark]
		if not BiomeDefs.is_surface(spawn) or not BiomeDefs.is_surface(puzzle) or not BiomeDefs.is_surface(hub):
			_log += "  错误：关键地标不在普通地表区域！\n"
		if dark != "dark_city":
			_log += "  错误：暗域之城中心不在暗域区域！\n"
		if surface_total * 100.0 / total < 18.0 or surface_total * 100.0 / total > 24.0:
			_log += "  错误：普通地表占比异常（%.1f%%）！\n" % (surface_total * 100.0 / total)
		if counts.get("dark_city", 0) * 100.0 / total < 7.0 or counts.get("dark_city", 0) * 100.0 / total > 12.0:
			_log += "  错误：暗域之城占比异常（%.1f%%）！\n" % (counts.get("dark_city", 0) * 100.0 / total)
		if ice_pct < 4.0 or ice_pct > 8.0:
			_log += "  错误：极寒冰脉占比异常（%.1f%%）！\n" % ice_pct
		if flame_pct < 4.0 or flame_pct > 9.0:
			_log += "  错误：爆炎之城占比异常（%.1f%%）！\n" % flame_pct
		if rad_pct < 3.5 or rad_pct > 8.0:
			_log += "  错误：辐射荒原占比异常（%.1f%%）！\n" % rad_pct
		if mech_pct < 3.0 or mech_pct > 8.0:
			_log += "  错误：机械废墟占比异常（%.1f%%）！\n" % mech_pct
		if swamp_pct < 3.0 or swamp_pct > 8.0:
			_log += "  错误：迷雾沼泽占比异常（%.1f%%）！\n" % swamp_pct
		if canyon_pct < 3.5 or canyon_pct > 8.0:
			_log += "  错误：幽深峡谷占比异常（%.1f%%）！\n" % canyon_pct
		if sky_pct < 2.0 or sky_pct > 6.0:
			_log += "  错误：天空岛占比异常（%.1f%%）！\n" % sky_pct
		if dune_pct < 1.8 or dune_pct > 6.0:
			_log += "  错误：荒芜沙丘占比异常（%.1f%%）！\n" % dune_pct
		if thunder_pct < 1.8 or thunder_pct > 6.0:
			_log += "  错误：雷鸣高原占比异常（%.1f%%）！\n" % thunder_pct
		if fungal_pct < 1.8 or fungal_pct > 6.0:
			_log += "  错误：真菌孢林占比异常（%.1f%%）！\n" % fungal_pct
		if relic_pct < 1.0 or relic_pct > 4.5:
			_log += "  错误：古代遗迹占比异常（%.1f%%）！\n" % relic_pct
		if grave_pct < 1.5 or grave_pct > 5.0:
			_log += "  错误：幽灵墓园占比异常（%.1f%%）！\n" % grave_pct
		if oasis_pct < 1.5 or oasis_pct > 5.0:
			_log += "  错误：生命绿洲占比异常（%.1f%%）！\n" % oasis_pct
	_flush()
