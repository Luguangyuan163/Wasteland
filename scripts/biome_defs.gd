class_name BiomeDefs
## 群系数据定义与查询 —— 供 map_generator 和 spawn_manager 共用
##
## 每个群系不只是 换底色 ，而是独立的地形特征集合：
##   1. ground_tiles  —— 加权地面瓦片混合（不是单一色块）
##   2. structures    —— 群系专属大型结构（废墟、岩层、水塘、建筑残骸）
##   3. scatter       —— 小型散落装饰（碎石、草丛、水洼）
##   4. resources     —— 资源数量 + 是否成群出现
##   5. monsters      —— 怪物池 + 难度
##
## 对应文档：
## - [怪物图鉴.md](../docs/怪物图鉴.md) §6 刷新规则
## - [资源文档.md](../docs/资源文档.md) §1 群系资源总览

# ============================================================
# 瓦片常量（与 map_generator.gd / underworld.gd 保持一致）
# ============================================================
const GRASS_TILE  := Vector2i(0, 0)  ## 草地（可通行）
const MUD_TILE    := Vector2i(1, 0)  ## 泥地（可通行，废土感）
const STONE_TILE  := Vector2i(0, 1)  ## 石头（有碰撞！挡路挡怪）
const WATER_TILE  := Vector2i(1, 1)  ## 水（装饰，v1 可通行）
const ICE_TILE    := Vector2i(2, 0)  ## 冰面（极寒冰脉，可通行）
const SNOW_TILE   := Vector2i(3, 0)  ## 雪地（极寒冰脉，可通行）
const LAVA_TILE   := Vector2i(2, 1)  ## 岩浆（爆炎之城，装饰可通行）
const SCORCH_TILE := Vector2i(3, 1)  ## 焦岩（爆炎之城，可通行）
const RAD_TILE    := Vector2i(0, 2)  ## 辐射土（辐射荒原，可通行）
const TOXIC_TILE  := Vector2i(1, 2)  ## 毒沼（辐射荒原，装饰可通行）
const METAL_TILE  := Vector2i(2, 2)  ## 金属板（机械废墟，可通行）
const RUST_TILE   := Vector2i(3, 2)  ## 锈蚀铁板（机械废墟，可通行）
const SAND_TILE   := Vector2i(0, 3)  ## 沙地（荒芜沙丘，可通行）
const FUNGAL_TILE := Vector2i(1, 3)  ## 菌地（真菌孢林，可通行）
const RUNE_TILE   := Vector2i(2, 3)  ## 符文石板（古代遗迹，可通行）
const GRAVE_TILE  := Vector2i(3, 3)  ## 墓土（幽灵墓园，可通行）

# ============================================================
# 群系定义表
# ============================================================
const BIOMES := {
	# ═══════════════════════════════════════════════════════════
	# 废土荒原 —— 开阔荒原 + 断壁残垣 + 碎石散落
	# 视觉：黄褐泥地为主，点缀枯草和碎石		# 结构：残墙段、瓦砾堆、散落岩石		# ═══════════════════════════════════════════════════════════
	"wasteland": {
		"name": "废土荒原",
		# 地面 = 加权混合（总和不必为 100）
		"ground_tiles": {MUD_TILE: 55, GRASS_TILE: 30, STONE_TILE: 15},
		# 大型结构（在地图生成第二阶段放置）
		"structures": {
			"ruined_wall":   {"count": 18, "min_len": 3, "max_len": 8},   # 残墙段
			"rock_formation": {"count": 14, "min_r": 2, "max_r": 4},       # 岩层露头
			"debris_field":  {"count": 12, "radius": 3},                    # 瓦砾堆
		},
		# 小散落（在地图生成第三阶段，按格概率撒）
		"scatter": {
			"tiles": [STONE_TILE, STONE_TILE, MUD_TILE, GRASS_TILE, GRASS_TILE],  # 重复=权重
			"chance": 0.03,
		},
		# 资源：分散出现（资源点之间距离较大）
		"resources": {"wood": 120, "stone": 80},
		"resource_clustered": false,
		# 怪物
		"difficulty": 1.0,
		"normal_types": ["goblin", "walker", "runner"],
		"mini_boss": "brute",
		"elite": "elite",
		"is_dark": false,
	},

	# ═══════════════════════════════════════════════════════════
	# 茂密林地 —— 草地为主 + 水塘散布 + 树丛密集
	# 视觉：翠绿草地，蓝水点缀，泥地小路穿插		# 结构：水塘、密集树丛（木材资源成群出现）		# ═══════════════════════════════════════════════════════════
	"forest": {
		"name": "茂密林地",
		"ground_tiles": {GRASS_TILE: 60, MUD_TILE: 25, WATER_TILE: 10, STONE_TILE: 5},
		"structures": {
			"water_pool":    {"count": 10, "min_r": 2, "max_r": 4},        # 水塘
			"tree_grove":    {"count": 18, "min_r": 2, "max_r": 4},        # 密集树丛
			"rock_formation": {"count": 5, "min_r": 1, "max_r": 2},        # 少量小石块
		},
		"scatter": {
			"tiles": [GRASS_TILE, GRASS_TILE, GRASS_TILE, MUD_TILE, WATER_TILE],
			"chance": 0.04,
		},
		"resources": {"wood": 100, "stone": 20},
		"resource_clustered": true,   # 资源成群出现（树丛）
		"cluster_size": [4, 8],
		"difficulty": 1.1,
		"normal_types": ["goblin", "runner", "goblin"],
		"mini_boss": "brute",
		"elite": "elite",
		"is_dark": false,
	},

	# ═══════════════════════════════════════════════════════════
	# 石丘 —— 石块密布 + 岩层阻路 + 稀疏植被		# 视觉：灰石与绿草交错，大片岩层形成天然屏障		# 结构：大型岩层、石柱群、碎石坡
	# ═══════════════════════════════════════════════════════════
	"rocky": {
		"name": "石丘",
		"ground_tiles": {GRASS_TILE: 40, STONE_TILE: 40, MUD_TILE: 20},
		"structures": {
			"rock_formation": {"count": 25, "min_r": 2, "max_r": 5},      # 大量岩层
			"boulder_field":  {"count": 8, "radius": 4},                    # 巨石阵
			"ruined_wall":    {"count": 4, "min_len": 2, "max_len": 4},       # 少量残墙
		},
		"scatter": {
			"tiles": [STONE_TILE, STONE_TILE, STONE_TILE, GRASS_TILE, MUD_TILE],
			"chance": 0.06,  # 石丘散落更密集
		},
		"resources": {"wood": 20, "stone": 50},
		"resource_clustered": false,
		"difficulty": 1.2,
		"normal_types": ["walker", "elite"],
		"mini_boss": "brute",
		"elite": "elite",
		"is_dark": false,
	},

	# ═══════════════════════════════════════════════════════════
	# 暗域废墟 —— 建筑残骸 + 瓦砾遍地 + 黑暗水坑
	# 视觉：深色泥地为主，大量石墙残骸，零星污水坑
	# 结构：建筑外壳、坍塌墙段、瓦砾场、污水池
	# ═══════════════════════════════════════════════════════════
	"dark_city": {
		"name": "暗域废墟",
		"ground_tiles": {MUD_TILE: 45, STONE_TILE: 30, GRASS_TILE: 15, WATER_TILE: 10},
		"structures": {
			"building_shell": {"count": 6, "min_size": 3, "max_size": 6},   # 建筑残骸（矩形围墙）
			"ruined_wall":    {"count": 20, "min_len": 3, "max_len": 10},    # 大量残墙
			"debris_field":   {"count": 15, "radius": 4},                     # 瓦砾场
			"water_pool":     {"count": 5, "min_r": 1, "max_r": 3},          # 污水坑
		},
		"scatter": {
			"tiles": [STONE_TILE, STONE_TILE, STONE_TILE, MUD_TILE, WATER_TILE],
			"chance": 0.08,  # 废墟遍地碎块
		},
		"resources": {"parts": 24, "darkstone": 14},
		"resource_clustered": true,
		"cluster_size": [3, 6],
		"difficulty": 2.0,
		"normal_types": ["husk", "shade"],
		"mini_boss": "reaper",
		"elite": "dark_elite",
		"is_dark": true,
	},

	# ═══════════════════════════════════════════════════════════
	# 极寒冰脉 —— 永夜雪原 + 冰柱群 + 冰湖
	# 视觉：雪地为主，冰面与冰柱点缀，蓝水冰湖
	# 结构：冰柱群、冰湖、冻结岩层
	# ═══════════════════════════════════════════════════════════
	"ice_vein": {
		"name": "极寒冰脉",
		"ground_tiles": {SNOW_TILE: 65, ICE_TILE: 20, STONE_TILE: 10, WATER_TILE: 5},
		"structures": {
			"ice_spike":     {"count": 16, "min_r": 2, "max_r": 4},  # 冰柱群
			"water_pool":    {"count": 8, "min_r": 2, "max_r": 4},   # 冰湖
			"rock_formation": {"count": 6, "min_r": 1, "max_r": 3},  # 冻结岩层
		},
		"scatter": {
			"tiles": [SNOW_TILE, SNOW_TILE, ICE_TILE, STONE_TILE],
			"chance": 0.03,
		},
		"resources": {"frost_crystal": 20, "stone": 15},
		"resource_clustered": false,
		"difficulty": 1.5,
		"normal_types": ["ice_wolf", "frost_walker"],
		"mini_boss": "ice_giant",
		"elite": "frost_elite",
		"is_dark": true,   # 极夜暴风雪：永暗，可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 爆炎之城 —— 焦黑废墟 + 熔岩池 + 余烬遍地
	# 视觉：焦岩为主，熔岩池点缀，泥地废墟
	# 结构：熔岩池、烧毁建筑、瓦砾场
	# ═══════════════════════════════════════════════════════════
	"flame_city": {
		"name": "爆炎之城",
		"ground_tiles": {MUD_TILE: 20, SCORCH_TILE: 45, LAVA_TILE: 20, STONE_TILE: 15},
		"structures": {
			"lava_pool":      {"count": 12, "min_r": 2, "max_r": 4},  # 熔岩池
			"building_shell": {"count": 5, "min_size": 3, "max_size": 6},  # 烧毁建筑
			"debris_field":   {"count": 10, "radius": 3},             # 瓦砾场
		},
		"scatter": {
			"tiles": [SCORCH_TILE, SCORCH_TILE, LAVA_TILE, STONE_TILE, MUD_TILE],
			"chance": 0.05,
		},
		"resources": {"ember": 18, "stone": 15},
		"resource_clustered": true,
		"cluster_size": [3, 5],
		"difficulty": 2.5,
		"normal_types": ["emberling", "cinder_brute"],
		"mini_boss": "magma_beast",
		"elite": "flame_elite",
		"is_dark": true,   # 黑烟遮天：永暗，可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 辐射荒原 —— 毒雾弥漫 + 辐射土 + 毒沼
	# 视觉：黄绿辐射土为主，毒沼点缀
	# 结构：毒沼、辐射岩层、瓦砾场
	# ═══════════════════════════════════════════════════════════
	"rad_waste": {
		"name": "辐射荒原",
		"ground_tiles": {RAD_TILE: 60, TOXIC_TILE: 15, MUD_TILE: 15, STONE_TILE: 10},
		"structures": {
			"toxic_pool":     {"count": 10, "min_r": 2, "max_r": 4},  # 毒沼
			"rock_formation": {"count": 8, "min_r": 2, "max_r": 4},   # 辐射岩层
			"debris_field":   {"count": 8, "radius": 3},              # 瓦砾场
		},
		"scatter": {
			"tiles": [RAD_TILE, RAD_TILE, TOXIC_TILE, STONE_TILE],
			"chance": 0.04,
		},
		"resources": {"rad_dust": 18, "stone": 12},
		"resource_clustered": false,
		"difficulty": 1.8,
		"normal_types": ["rad_mutant", "rad_crawler"],
		"mini_boss": "rad_beast",
		"elite": "rad_elite",
		"is_dark": true,   # 毒雾弥漫：永暗，可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 机械废墟 —— 金属废墟 + 锈蚀铁板 + 油污
	# 视觉：金属板与锈蚀铁板为主，泥地废墟
	# 结构：机械残骸、厂房残壳、瓦砾场
	# ═══════════════════════════════════════════════════════════
	"mech_ruins": {
		"name": "机械废墟",
		"ground_tiles": {METAL_TILE: 50, RUST_TILE: 25, MUD_TILE: 15, STONE_TILE: 10},
		"structures": {
			"wreck":          {"count": 12, "min_r": 2, "max_r": 4},  # 机械残骸
			"building_shell": {"count": 4, "min_size": 3, "max_size": 5},  # 厂房残壳
			"debris_field":   {"count": 8, "radius": 3},              # 瓦砾场
		},
		"scatter": {
			"tiles": [METAL_TILE, METAL_TILE, RUST_TILE, STONE_TILE, MUD_TILE],
			"chance": 0.05,
		},
		"resources": {"gear": 16, "parts": 10},
		"resource_clustered": true,
		"cluster_size": [3, 5],
		"difficulty": 2.2,
		"normal_types": ["sentinel", "rust_bot"],
		"mini_boss": "war_machine",
		"elite": "mech_elite",
		"is_dark": true,   # 阴暗厂房：永暗，可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 迷雾沼泽 —— 泥沼 + 水潭 + 雾
	# 视觉：泥地为主，水潭散布
	# 结构：沼泽水潭、树丛、瓦砾
	# ═══════════════════════════════════════════════════════════
	"swamp": {
		"name": "迷雾沼泽",
		"ground_tiles": {MUD_TILE: 45, WATER_TILE: 25, GRASS_TILE: 20, STONE_TILE: 10},
		"structures": {
			"water_pool":    {"count": 12, "min_r": 2, "max_r": 4},  # 沼泽水潭
			"tree_grove":    {"count": 8, "min_r": 2, "max_r": 3},   # 湿地树丛
			"debris_field":  {"count": 5, "radius": 3},              # 沉船/瓦砾
		},
		"scatter": {
			"tiles": [MUD_TILE, MUD_TILE, WATER_TILE, GRASS_TILE],
			"chance": 0.04,
		},
		"resources": {"swamp_herb": 18, "wood": 10},
		"resource_clustered": true,
		"cluster_size": [3, 5],
		"difficulty": 1.6,
		"normal_types": ["frogman", "swamp_slime"],
		"mini_boss": "swamp_beast",
		"elite": "swamp_elite",
		"is_dark": true,   # 迷雾弥漫：永暗，可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 幽深峡谷 —— 岩石峭壁 + 谷底溪流
	# 视觉：石头为主，泥地/草地点缀，溪流穿过
	# 结构：岩层、巨石阵、残墙
	# ═══════════════════════════════════════════════════════════
	"canyon": {
		"name": "幽深峡谷",
		"ground_tiles": {STONE_TILE: 45, MUD_TILE: 25, GRASS_TILE: 20, WATER_TILE: 10},
		"structures": {
			"rock_formation": {"count": 16, "min_r": 2, "max_r": 5},  # 峭壁岩层
			"boulder_field":  {"count": 6, "radius": 3},               # 巨石阵
			"ruined_wall":    {"count": 6, "min_len": 3, "max_len": 6},  # 残墙
		},
		"scatter": {
			"tiles": [STONE_TILE, STONE_TILE, MUD_TILE, GRASS_TILE],
			"chance": 0.05,
		},
		"resources": {"gem": 14, "stone": 12},
		"resource_clustered": true,   # 峡谷矿脉：宝石成簇出现，避免在石地/水地找不到落点
		"cluster_size": [3, 5],
		"difficulty": 2.0,
		"normal_types": ["canyon_lizard", "stone_golem"],
		"mini_boss": "canyon_beast",
		"elite": "canyon_elite",
		"is_dark": true,   # 峡谷深处阴影：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 天空岛 —— 浮空岛 + 云中湖
	# 视觉：草地为主，云中湖与岩块点缀
	# 结构：岩层、云中湖、树丛
	# ═══════════════════════════════════════════════════════════
	"sky_island": {
		"name": "天空岛",
		"ground_tiles": {GRASS_TILE: 50, STONE_TILE: 20, MUD_TILE: 15, WATER_TILE: 15},
		"structures": {
			"rock_formation": {"count": 8, "min_r": 2, "max_r": 4},  # 浮岛岩核
			"water_pool":     {"count": 8, "min_r": 2, "max_r": 4},  # 云中湖
			"tree_grove":     {"count": 6, "min_r": 2, "max_r": 3},  # 岛林
		},
		"scatter": {
			"tiles": [GRASS_TILE, GRASS_TILE, STONE_TILE, WATER_TILE],
			"chance": 0.03,
		},
		"resources": {"sky_crystal": 12, "stone": 8},
		"resource_clustered": false,
		"difficulty": 2.4,
		"normal_types": ["harpy", "sky_golem"],
		"mini_boss": "sky_beast",
		"elite": "sky_elite",
		"is_dark": true,   # 云层雷暴遮蔽：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 荒芜沙丘 —— 沙暴弥漫 + 沙丘 + 零星绿洲
	# 视觉：沙地为主，泥地/草地点缀，砂岩露头
	# 结构：砂岩露头、风蚀残骸、绿洲水洼
	# ═══════════════════════════════════════════════════════════
	"dune_wastes": {
		"name": "荒芜沙丘",
		"ground_tiles": {SAND_TILE: 65, MUD_TILE: 15, GRASS_TILE: 10, STONE_TILE: 10},
		"structures": {
			"rock_formation": {"count": 8, "min_r": 2, "max_r": 4},   # 砂岩露头
			"debris_field":   {"count": 8, "radius": 3},              # 风蚀残骸
			"water_pool":     {"count": 4, "min_r": 1, "max_r": 3},   # 绿洲水洼
		},
		"scatter": {
			"tiles": [SAND_TILE, SAND_TILE, MUD_TILE, STONE_TILE],
			"chance": 0.05,
		},
		"resources": {"salt_crystal": 14, "cactus_fiber": 10},
		"resource_clustered": false,
		"difficulty": 1.5,
		"normal_types": ["sand_scorpion", "vulture"],
		"mini_boss": "sand_beast",
		"elite": "dune_elite",
		"is_dark": true,   # 沙尘暴遮天：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 雷鸣高原 —— 雷暴云 + 焦黑岩峰 + 闪电裂隙
	# 视觉：石头为主，焦岩/泥地点缀
	# 结构：岩峰、巨石阵、瓦砾
	# ═══════════════════════════════════════════════════════════
	"thunder_highlands": {
		"name": "雷鸣高原",
		"ground_tiles": {STONE_TILE: 45, SCORCH_TILE: 25, MUD_TILE: 20, GRASS_TILE: 10},
		"structures": {
			"rock_formation": {"count": 10, "min_r": 2, "max_r": 4},  # 岩峰
			"boulder_field":  {"count": 5, "radius": 3},               # 巨石阵
			"debris_field":   {"count": 6, "radius": 3},               # 雷击瓦砾
		},
		"scatter": {
			"tiles": [STONE_TILE, SCORCH_TILE, MUD_TILE],
			"chance": 0.06,
		},
		"resources": {"thunder_crystal": 16, "stone": 12},
		"resource_clustered": false,
		"difficulty": 2.6,
		"normal_types": ["thunder_hawk", "arc_golem"],
		"mini_boss": "storm_beast",
		"elite": "thunder_elite",
		"is_dark": true,   # 雷暴云遮蔽：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 真菌孢林 —— 荧光菌毯 + 巨型蘑菇 + 致幻孢子
	# 视觉：菌地为主，泥地/草地点缀
	# 结构：菌丛（树丛模板）、水潭、瓦砾
	# ═══════════════════════════════════════════════════════════
	"fungal_grove": {
		"name": "真菌孢林",
		"ground_tiles": {FUNGAL_TILE: 55, MUD_TILE: 25, GRASS_TILE: 15, WATER_TILE: 5},
		"structures": {
			"tree_grove":    {"count": 10, "min_r": 2, "max_r": 4},  # 巨型蘑菇丛
			"water_pool":    {"count": 6, "min_r": 2, "max_r": 3},   # 孢水潭
			"debris_field":  {"count": 5, "radius": 3},              # 朽木瓦砾
		},
		"scatter": {
			"tiles": [FUNGAL_TILE, FUNGAL_TILE, MUD_TILE, GRASS_TILE],
			"chance": 0.06,
		},
		"resources": {"glow_shroom": 16, "spore": 10},
		"resource_clustered": false,
		"difficulty": 1.9,
		"normal_types": ["sporeling", "hypno_moth"],
		"mini_boss": "spore_king",
		"elite": "fungal_elite",
		"is_dark": true,   # 致幻迷雾：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 古代遗迹 —— 符文石板 + 神殿残骸 + 石像守卫
	# 视觉：符文石板为主，石头/草地点缀
	# 结构：神殿残壳（建筑模板）、岩层、瓦砾
	# ═══════════════════════════════════════════════════════════
	"ancient_relics": {
		"name": "古代遗迹",
		"ground_tiles": {RUNE_TILE: 50, STONE_TILE: 25, GRASS_TILE: 15, MUD_TILE: 10},
		"structures": {
			"building_shell": {"count": 8, "min_size": 3, "max_size": 6},  # 神殿残壳
			"rock_formation": {"count": 6, "min_r": 2, "max_r": 4},        # 岩柱
			"debris_field":   {"count": 8, "radius": 3},                    # 塌落石料
		},
		"scatter": {
			"tiles": [RUNE_TILE, RUNE_TILE, STONE_TILE, GRASS_TILE],
			"chance": 0.07,
		},
		"resources": {"rune_stone": 10, "relic": 6},
		"resource_clustered": false,
		"difficulty": 2.4,
		"normal_types": ["relic_guard", "gargoyle"],
		"mini_boss": "relic_colossus",
		"elite": "relic_elite",
		"is_dark": true,   # 遗迹深处无光：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 幽灵墓园 —— 灰暗墓土 + 残碑 + 阴森墓室
	# 视觉：墓土为主，石头/泥地点缀
	# 结构：墓室（建筑模板）、残碑（残墙）、瓦砾
	# ═══════════════════════════════════════════════════════════
	"ghost_graveyard": {
		"name": "幽灵墓园",
		"ground_tiles": {GRAVE_TILE: 60, STONE_TILE: 20, MUD_TILE: 15, GRASS_TILE: 5},
		"structures": {
			"building_shell": {"count": 6, "min_size": 3, "max_size": 5},  # 墓室
			"ruined_wall":    {"count": 10, "min_len": 3, "max_len": 7},   # 残碑墙
			"debris_field":   {"count": 6, "radius": 3},                    # 坍墓碑
		},
		"scatter": {
			"tiles": [GRAVE_TILE, GRAVE_TILE, STONE_TILE, MUD_TILE],
			"chance": 0.07,
		},
		"resources": {"soul_ember": 10, "bone": 6},
		"resource_clustered": false,
		"difficulty": 2.2,
		"normal_types": ["ghost", "bone_guard"],
		"mini_boss": "grave_beast",
		"elite": "grave_elite",
		"is_dark": true,   # 常年阴霾：可刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 生命绿洲 —— 清泉 + 草地 + 水潭（地表边缘的安全补给站）
	# 视觉：草地为主，清亮水潭点缀
	# 结构：泉池（水潭）、树丛、岩层
	# ═══════════════════════════════════════════════════════════
	"life_oasis": {
		"name": "生命绿洲",
		"ground_tiles": {GRASS_TILE: 55, WATER_TILE: 25, MUD_TILE: 15, STONE_TILE: 5},
		"structures": {
			"water_pool":    {"count": 8, "min_r": 2, "max_r": 4},  # 清泉池
			"tree_grove":    {"count": 6, "min_r": 2, "max_r": 3},  # 绿洲林
			"rock_formation": {"count": 4, "min_r": 1, "max_r": 3}, # 泉眼岩
		},
		"scatter": {
			"tiles": [GRASS_TILE, WATER_TILE, MUD_TILE],
			"chance": 0.04,
		},
		"resources": {"clean_water": 10, "oasis_herb": 6},
		"resource_clustered": false,
		"difficulty": 1.2,
		"normal_types": ["oasis_viper", "oasis_mosquito"],
		"mini_boss": "oasis_croc",
		"elite": "oasis_elite",
		"is_dark": false,   # 绿洲明亮 = 安全补给站，不刷怪
	},

	# ═══════════════════════════════════════════════════════════
	# 荒芜废土 —— 极度荒凉，南部占位群系		# 视觉：龟裂大地，零星枯草，几乎无结构
	# P3 落地新内容时替换为正式群系		# ═══════════════════════════════════════════════════════════
	"future_wild": {
		"name": "荒芜废土",
		"ground_tiles": {MUD_TILE: 50, GRASS_TILE: 35, STONE_TILE: 15},
		"structures": {
			"rock_formation": {"count": 6, "min_r": 1, "max_r": 3},
			"debris_field":   {"count": 5, "radius": 2},
		},
		"scatter": {
			"tiles": [STONE_TILE, MUD_TILE, GRASS_TILE],
			"chance": 0.02,
		},
		"resources": {"wood": 15, "stone": 15},
		"resource_clustered": false,
		"difficulty": 1.0,
		"normal_types": ["walker"],
		"mini_boss": "brute",
		"elite": "elite",
		"is_dark": false,
	},
}

# ============================================================
# 群系区域图 v5（中枢 + 放射环带，参考《饥荒》枢纽分支 + RPG 地图的城镇放射路网）
# ============================================================
# 世界不是用两张噪声硬切群系，而是先规划"大区域"，再在内部细分：
#   - 普通地表（wasteland/forest/rocky）：地图中心的椭圆"安全大陆"，约占 20%
#   - 暗域之城（dark_city）：东南，约占 9%
#   - 极寒冰脉（ice_vein）：西，约占 7.5%
#   - 爆炎之城（flame_city）：西南，约占 5.7%
#   - 辐射荒原（rad_waste）：东，约占 7.5%
#   - 机械废墟（mech_ruins）：南，约占 5%
#   - 迷雾沼泽（swamp）：西北，约占 5%
#   - 幽深峡谷（canyon）：东北，约占 5%
#   - 天空岛（sky_island）：北，外圈"环岛湖"（sky_moat），约占 3%
#   - 未来群系（future_wild 占位）：其余 ~28%
# 普通地表内部格无条件优先归属地表（安全区不被群系椭圆侵入）；区域边界用噪声
# 扰动成不规则曲线，并用 TRANSITION_MARGIN 宽的过渡带（碎石/枯地）避免硬切。
const TEMP_COLD := 0.38
const TEMP_HOT  := 0.62
const HUMID_DRY  := 0.45
const HUMID_WET  := 0.55


const SURFACE_CENTER := Vector2(100.0, 75.0)   # 普通地表 = 世界中枢（地图中心）
const SURFACE_RADIUS := Vector2(74.0, 26.0)    # 面积 ≈ π×74×26 ≈ 6045 格 ≈ 20.2%
const DARK_CENTER := Vector2(150.0, 120.0)     # 暗域之城（东南）
const DARK_RADIUS := Vector2(42.0, 27.0)       # 面积 ≈ π×42×27 ≈ 3563 格 ≈ 11.9%（与新群系共边后实测 ~8%）
const ICE_CENTER := Vector2(30.0, 78.0)        # 极寒冰脉（西）
const ICE_RADIUS := Vector2(33.0, 25.0)        # 面积 ≈ π×33×25 ≈ 2592 格 ≈ 8.6%（西缘与地表重叠处归地表）
const FLAME_CENTER := Vector2(48.0, 122.0)     # 爆炎之城（西南）
const FLAME_RADIUS := Vector2(32.0, 19.0)      # 面积 ≈ π×32×19 ≈ 1910 格 ≈ 6.4%
const RAD_CENTER := Vector2(170.0, 78.0)       # 辐射荒原（东）
const RAD_RADIUS := Vector2(33.0, 25.0)        # 面积 ≈ π×33×25 ≈ 2592 格 ≈ 8.6%（东缘与地表重叠处归地表）
const MECH_CENTER := Vector2(100.0, 134.0)     # 机械废墟（南）
const MECH_RADIUS := Vector2(32.0, 17.0)       # 面积 ≈ π×32×17 ≈ 1709 格 ≈ 5.7%
const SWAMP_CENTER := Vector2(42.0, 40.0)      # 迷雾沼泽（西北）
const SWAMP_RADIUS := Vector2(30.0, 18.0)      # 面积 ≈ π×30×18 ≈ 1696 格 ≈ 5.7%
const CANYON_CENTER := Vector2(158.0, 40.0)    # 幽深峡谷（东北）
const CANYON_RADIUS := Vector2(30.0, 18.0)     # 面积 ≈ π×30×18 ≈ 1696 格 ≈ 5.7%
const SKY_CENTER := Vector2(100.0, 26.0)       # 天空岛（北，环岛湖环绕）
const SKY_RADIUS := Vector2(26.0, 13.0)        # 面积 ≈ π×26×13 ≈ 1062 格 ≈ 3.5%
const DUNE_CENTER := Vector2(22.0, 44.0)       # 荒芜沙丘（西北，沼泽与冰脉之间）
const DUNE_RADIUS := Vector2(28.0, 17.0)       # 面积 ≈ π×28×17 ≈ 1495 格 ≈ 5.0%（与邻群系共边后实测 ~3%）
const THUNDER_CENTER := Vector2(178.0, 44.0)   # 雷鸣高原（东北，峡谷与辐射之间）
const THUNDER_RADIUS := Vector2(28.0, 17.0)    # 面积 ≈ π×28×17 ≈ 1495 格 ≈ 5.0%
const FUNGAL_CENTER := Vector2(36.0, 112.0)    # 真菌孢林（西南偏西，冰脉与爆炎之间）
const FUNGAL_RADIUS := Vector2(28.0, 17.0)     # 面积 ≈ π×28×17 ≈ 1495 格 ≈ 5.0%
const RELIC_CENTER := Vector2(126.0, 136.0)    # 古代遗迹（南偏东，机械与暗域之间）
const RELIC_RADIUS := Vector2(26.0, 14.0)      # 面积 ≈ π×26×14 ≈ 1144 格 ≈ 3.8%
const GRAVE_CENTER := Vector2(168.0, 110.0)    # 幽灵墓园（东南偏东，暗域与辐射之间）
const GRAVE_RADIUS := Vector2(28.0, 16.0)      # 面积 ≈ π×28×16 ≈ 1407 格 ≈ 4.7%
const OASIS_CENTER := Vector2(72.0, 30.0)      # 生命绿洲（北偏西，沼泽与天空岛之间）
const OASIS_RADIUS := Vector2(26.0, 15.0)      # 面积 ≈ π×26×15 ≈ 1225 格 ≈ 4.1%
const SKY_MOAT := 0.55                         # 天空岛外圈"环岛湖"宽度（椭圆度量，约 5~7 格）
const REGION_WARP := 0.25        # 边界噪声扰动幅度（让区域边缘不规则、更自然）
const TRANSITION_MARGIN := 0.18  # 边界过渡带（椭圆度量单位，约 4~6 格，加宽让边界更柔和）


## 返回 {biome, margin}：
## biome   = 该格所属群系
## margin  = 离最近区域边界的带符号距离（<0 在区域内，>0 在区域外）
static func region_info(cell: Vector2i, seed_value: int) -> Dictionary:
	var d_surface := _warped_dist(cell, SURFACE_CENTER, SURFACE_RADIUS, seed_value)
	# 普通地表 = 安全中枢：内部格无条件优先归属地表，四周群系椭圆不侵入出生区
	if d_surface < 0.0:
		return {"biome": _surface_biome(cell, seed_value), "margin": d_surface}
	var d_dark := _warped_dist(cell, DARK_CENTER, DARK_RADIUS, seed_value)
	var d_ice := _warped_dist(cell, ICE_CENTER, ICE_RADIUS, seed_value)
	var d_flame := _warped_dist(cell, FLAME_CENTER, FLAME_RADIUS, seed_value)
	var d_rad := _warped_dist(cell, RAD_CENTER, RAD_RADIUS, seed_value)
	var d_mech := _warped_dist(cell, MECH_CENTER, MECH_RADIUS, seed_value)
	var d_swamp := _warped_dist(cell, SWAMP_CENTER, SWAMP_RADIUS, seed_value)
	var d_canyon := _warped_dist(cell, CANYON_CENTER, CANYON_RADIUS, seed_value)
	var d_sky := _warped_dist(cell, SKY_CENTER, SKY_RADIUS, seed_value)
	var d_dune := _warped_dist(cell, DUNE_CENTER, DUNE_RADIUS, seed_value)
	var d_thunder := _warped_dist(cell, THUNDER_CENTER, THUNDER_RADIUS, seed_value)
	var d_fungal := _warped_dist(cell, FUNGAL_CENTER, FUNGAL_RADIUS, seed_value)
	var d_relic := _warped_dist(cell, RELIC_CENTER, RELIC_RADIUS, seed_value)
	var d_grave := _warped_dist(cell, GRAVE_CENTER, GRAVE_RADIUS, seed_value)
	var d_oasis := _warped_dist(cell, OASIS_CENTER, OASIS_RADIUS, seed_value)
	var margin := d_surface
	margin = minf(margin, d_dark)
	margin = minf(margin, d_ice)
	margin = minf(margin, d_flame)
	margin = minf(margin, d_rad)
	margin = minf(margin, d_mech)
	margin = minf(margin, d_swamp)
	margin = minf(margin, d_canyon)
	margin = minf(margin, d_sky)
	margin = minf(margin, d_dune)
	margin = minf(margin, d_thunder)
	margin = minf(margin, d_fungal)
	margin = minf(margin, d_relic)
	margin = minf(margin, d_grave)
	margin = minf(margin, d_oasis)
	var biome := "future_wild"
	var best_dist := INF
	var best_region := "future_wild"
	if d_surface < best_dist:
		best_dist = d_surface
		best_region = "surface"
	if d_dark < best_dist:
		best_dist = d_dark
		best_region = "dark_city"
	if d_ice < best_dist:
		best_dist = d_ice
		best_region = "ice_vein"
	if d_flame < best_dist:
		best_dist = d_flame
		best_region = "flame_city"
	if d_rad < best_dist:
		best_dist = d_rad
		best_region = "rad_waste"
	if d_mech < best_dist:
		best_dist = d_mech
		best_region = "mech_ruins"
	if d_swamp < best_dist:
		best_dist = d_swamp
		best_region = "swamp"
	if d_canyon < best_dist:
		best_dist = d_canyon
		best_region = "canyon"
	if d_sky < best_dist:
		best_dist = d_sky
		best_region = "sky_island"
	if d_dune < best_dist:
		best_dist = d_dune
		best_region = "dune_wastes"
	if d_thunder < best_dist:
		best_dist = d_thunder
		best_region = "thunder_highlands"
	if d_fungal < best_dist:
		best_dist = d_fungal
		best_region = "fungal_grove"
	if d_relic < best_dist:
		best_dist = d_relic
		best_region = "ancient_relics"
	if d_grave < best_dist:
		best_dist = d_grave
		best_region = "ghost_graveyard"
	if d_oasis < best_dist:
		best_dist = d_oasis
		best_region = "life_oasis"
	if best_dist < 0.0:
		match best_region:
			"surface":
				biome = _surface_biome(cell, seed_value)
			"dark_city":
				biome = "dark_city"
			"ice_vein":
				biome = "ice_vein"
			"flame_city":
				biome = "flame_city"
			"rad_waste":
				biome = "rad_waste"
			"mech_ruins":
				biome = "mech_ruins"
			"swamp":
				biome = "swamp"
			"canyon":
				biome = "canyon"
			"sky_island":
				biome = "sky_island"
			"dune_wastes":
				biome = "dune_wastes"
			"thunder_highlands":
				biome = "thunder_highlands"
			"fungal_grove":
				biome = "fungal_grove"
			"ancient_relics":
				biome = "ancient_relics"
			"ghost_graveyard":
				biome = "ghost_graveyard"
			"life_oasis":
				biome = "life_oasis"
	return {"biome": biome, "margin": margin}


## 椭圆带符号距离 + 噪声扰动（边界不规则，看起来更自然）
static func _warped_dist(cell: Vector2i, center: Vector2, radius: Vector2, seed_value: int) -> float:
	var dx := (cell.x - center.x) / radius.x
	var dy := (cell.y - center.y) / radius.y
	# 频率 0.3：噪声格点约 67 格，边界会呈几十格尺度的自然起伏，而不是一整条直线
	var warp := (SimpleNoise.fbm_noise(cell.x * 0.3, cell.y * 0.3, seed_value + 4242, 2) - 0.5) * 2.0 * REGION_WARP
	return dx * dx + dy * dy - 1.0 + warp


static func get_biome_at(cell: Vector2i, seed_value: int) -> String:
	return region_info(cell, seed_value)["biome"]


## 该格是否处于区域边界的过渡带（地图生成器用来铺碎石/枯地）
static func is_transition(cell: Vector2i, seed_value: int) -> bool:
	return absf(region_info(cell, seed_value)["margin"]) < TRANSITION_MARGIN


## 天空岛"环岛湖"：位于天空岛椭圆外的环带 → 水域（地图生成器铺水）
static func sky_moat(cell: Vector2i, seed_value: int) -> bool:
	var d := _warped_dist(cell, SKY_CENTER, SKY_RADIUS, seed_value)
	return d > 0.0 and d < SKY_MOAT


## 普通地表内部再细分：温度 / 湿度 → 废土 / 林地 / 石丘
static func _surface_biome(cell: Vector2i, seed_value: int) -> String:
	# 频率 0.35：噪声格点约 57 格，地表椭圆内部能分出几十格大小的废土/林地/石丘片区
	# （之前 0.012 的格点约 1667 格，整个地表区域对同一张种子几乎是单一群系）
	var temp  := SimpleNoise.fbm_noise(cell.x * 0.35, cell.y * 0.35, seed_value, 3)
	var humid := SimpleNoise.fbm_noise(cell.x * 0.35 + 500.0, cell.y * 0.35 + 500.0, seed_value + 777, 3)
	if temp < TEMP_COLD:
		return "rocky"
	elif temp > TEMP_HOT:
		return "forest" if humid > HUMID_WET else "wasteland"
	else:
		if humid > HUMID_WET:
			return "forest"
		elif humid < HUMID_DRY:
			return "rocky"
		return "wasteland"


## 是否属于普通地表（废土/林地/石丘）
static func is_surface(biome_id: String) -> bool:
	return biome_id == "wasteland" or biome_id == "forest" or biome_id == "rocky"


static func get_biome_def(biome_id: String) -> Dictionary:
	return BIOMES.get(biome_id, BIOMES["wasteland"])


static func get_biome_def_at(pos: Vector2, seed_value: int) -> Dictionary:
	var cell := Vector2i(floori(pos.x / 32.0), floori(pos.y / 32.0))
	return get_biome_def(get_biome_at(cell, seed_value))
