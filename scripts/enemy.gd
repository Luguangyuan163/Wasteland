extends CharacterBody2D
## 敌人：发现玩家后追击（需要视线），进入攻击距离立即停靠并攻击
## 修复（2026-08-10）：停靠距离大于身体尺寸，怪物不再贴进玩家身体
## 索敌（2026-08-10）：改为玩家视野制——怪物在玩家可见范围内（地表=屏幕内，黑暗群系=光照半径内）一直追击，离开视野即停止
## 头顶显示名字与类型（普通/精英/小Boss/大Boss）以及血条
## 对应计划表：P1 第 6 周「敌人 AI：追踪与攻击」
## 敌人类型表：类型 → 名字/血量/伤害/速度/颜色/体型/掉落
## 3 种普通（哥布林/游荡者/疾行者）+ 1 种精英 + 地心怪物（独立类型）
const ENEMY_TYPES := {
	"goblin": {"name": "哥布林", "type": "普通", "max_hp": 3, "damage": 5, "speed": 100.0, "color": Color(0.75, 0.2, 0.15), "scale": 1.0, "drops": {"wood": 1}},
	"walker": {"name": "游荡者", "type": "普通", "max_hp": 6, "damage": 7, "speed": 75.0, "color": Color(0.8, 0.55, 0.2), "scale": 1.15, "drops": {"wood": 2}},
	"runner": {"name": "疾行者", "type": "普通", "max_hp": 2, "damage": 4, "speed": 165.0, "color": Color(0.5, 0.8, 0.3), "scale": 0.8, "drops": {"wood": 1}},
	"elite": {"name": "废土精英", "type": "精英", "max_hp": 12, "damage": 12, "speed": 95.0, "color": Color(0.4, 0.2, 0.6), "scale": 1.4, "drops": {"wood": 2, "stone": 1}},
	"dark": {"name": "地心怪物", "type": "普通", "max_hp": 5, "damage": 8, "speed": 110.0, "color": Color(0.55, 0.2, 0.5), "scale": 1.0, "drops": {"wood": 1}},
	"deep_elite": {"name": "地心精英", "type": "精英", "max_hp": 8, "damage": 10, "speed": 120.0, "color": Color(0.5, 0.25, 0.8), "scale": 1.3, "drops": {"darkstone": 2}},
	"brute": {"name": "废土兽", "type": "小Boss", "max_hp": 10, "damage": 10, "speed": 90.0, "color": Color(0.65, 0.35, 0.2), "scale": 1.5, "drops": {"wood": 3, "stone": 1}},
	"warlord": {"name": "废土领主", "type": "大Boss", "max_hp": 25, "damage": 15, "speed": 80.0, "color": Color(0.3, 0.25, 0.2), "scale": 2.0, "drops": {"wood": 5, "stone": 3, "iron": 1}},
	"deep_beast": {"name": "地心巨兽", "type": "小Boss", "max_hp": 12, "damage": 12, "speed": 100.0, "color": Color(0.6, 0.2, 0.7), "scale": 1.5, "drops": {"darkstone": 3}},
	"deep_lord": {"name": "地心领主", "type": "大Boss", "max_hp": 30, "damage": 18, "speed": 85.0, "color": Color(0.3, 0.1, 0.4), "scale": 2.0, "drops": {"darkstone": 6}},
	## 暗域之城专属怪（P3 落地）：灰烬傀儡 / 暗影猎手 / 暗域精英 / 暗域收割者 / 暗域暴君
	"husk": {"name": "暗域傀儡", "type": "普通", "max_hp": 8, "damage": 9, "speed": 70.0, "color": Color(0.42, 0.38, 0.45), "scale": 1.2, "drops": {"parts": 1}},
	"shade": {"name": "暗影猎手", "type": "普通", "max_hp": 4, "damage": 8, "speed": 150.0, "color": Color(0.5, 0.3, 0.55), "scale": 0.9, "drops": {"parts": 1}},
	"dark_elite": {"name": "暗域精英", "type": "精英", "max_hp": 14, "damage": 14, "speed": 100.0, "color": Color(0.45, 0.2, 0.75), "scale": 1.4, "drops": {"parts": 2, "darkstone": 1}},
	"reaper": {"name": "暗域收割者", "type": "小Boss", "max_hp": 16, "damage": 14, "speed": 95.0, "color": Color(0.55, 0.15, 0.2), "scale": 1.6, "drops": {"parts": 3}},
	"tyrant": {"name": "暗域暴君", "type": "大Boss", "max_hp": 35, "damage": 20, "speed": 85.0, "color": Color(0.2, 0.1, 0.25), "scale": 2.1, "drops": {"parts": 5, "darkstone": 3}},
	## 极寒冰脉专属怪（v3.1）：冰原狼 / 霜缚者 / 冰晶精英 / 冰川巨人
	"ice_wolf": {"name": "冰原狼", "type": "普通", "max_hp": 5, "damage": 8, "speed": 155.0, "color": Color(0.62, 0.82, 1.0), "scale": 1.0, "drops": {"frost_crystal": 1}},
	"frost_walker": {"name": "霜缚者", "type": "普通", "max_hp": 9, "damage": 10, "speed": 70.0, "color": Color(0.75, 0.85, 0.95), "scale": 1.2, "drops": {"frost_crystal": 1}},
	"frost_elite": {"name": "冰晶精英", "type": "精英", "max_hp": 16, "damage": 14, "speed": 100.0, "color": Color(0.5, 0.75, 1.0), "scale": 1.4, "drops": {"frost_crystal": 2, "stone": 1}},
	"ice_giant": {"name": "冰川巨人", "type": "小Boss", "max_hp": 20, "damage": 16, "speed": 80.0, "color": Color(0.7, 0.9, 1.0), "scale": 1.7, "drops": {"frost_crystal": 3}},
	## 爆炎之城专属怪（v3.1）：余烬魔 / 焦灼者 / 爆炎精英 / 熔岩兽
	"emberling": {"name": "余烬魔", "type": "普通", "max_hp": 6, "damage": 10, "speed": 140.0, "color": Color(1.0, 0.55, 0.2), "scale": 0.9, "drops": {"ember": 1}},
	"cinder_brute": {"name": "焦灼者", "type": "普通", "max_hp": 10, "damage": 11, "speed": 80.0, "color": Color(0.7, 0.3, 0.15), "scale": 1.2, "drops": {"ember": 1}},
	"flame_elite": {"name": "爆炎精英", "type": "精英", "max_hp": 16, "damage": 16, "speed": 105.0, "color": Color(1.0, 0.4, 0.1), "scale": 1.4, "drops": {"ember": 2, "stone": 1}},
	"magma_beast": {"name": "熔岩兽", "type": "小Boss", "max_hp": 22, "damage": 18, "speed": 90.0, "color": Color(0.9, 0.3, 0.05), "scale": 1.7, "drops": {"ember": 3}},
	## 辐射荒原专属怪（v3.2）：辐射变异体 / 辐射爬行者 / 辐射精英 / 辐射巨兽
	"rad_mutant": {"name": "辐射变异体", "type": "普通", "max_hp": 7, "damage": 9, "speed": 120.0, "color": Color(0.45, 0.7, 0.25), "scale": 1.1, "drops": {"rad_dust": 1}},
	"rad_crawler": {"name": "辐射爬行者", "type": "普通", "max_hp": 4, "damage": 7, "speed": 160.0, "color": Color(0.65, 0.85, 0.3), "scale": 0.8, "drops": {"rad_dust": 1}},
	"rad_elite": {"name": "辐射精英", "type": "精英", "max_hp": 15, "damage": 15, "speed": 105.0, "color": Color(0.55, 0.8, 0.15), "scale": 1.4, "drops": {"rad_dust": 2, "stone": 1}},
	"rad_beast": {"name": "辐射巨兽", "type": "小Boss", "max_hp": 20, "damage": 17, "speed": 85.0, "color": Color(0.4, 0.6, 0.15), "scale": 1.7, "drops": {"rad_dust": 3}},
	## 机械废墟专属怪（v3.2）：机械哨兵 / 锈蚀机械 / 机械精英 / 战争机械
	"sentinel": {"name": "机械哨兵", "type": "普通", "max_hp": 6, "damage": 9, "speed": 130.0, "color": Color(0.55, 0.6, 0.7), "scale": 1.0, "drops": {"gear": 1}},
	"rust_bot": {"name": "锈蚀机械", "type": "普通", "max_hp": 9, "damage": 10, "speed": 85.0, "color": Color(0.7, 0.5, 0.35), "scale": 1.2, "drops": {"gear": 1}},
	"mech_elite": {"name": "机械精英", "type": "精英", "max_hp": 15, "damage": 15, "speed": 105.0, "color": Color(0.45, 0.55, 0.8), "scale": 1.4, "drops": {"gear": 2, "parts": 1}},
	"war_machine": {"name": "战争机械", "type": "小Boss", "max_hp": 22, "damage": 18, "speed": 80.0, "color": Color(0.35, 0.4, 0.55), "scale": 1.7, "drops": {"gear": 3, "parts": 1}},
	## 迷雾沼泽专属怪（v4）：蛙人 / 沼泽史莱姆 / 沼泽精英 / 沼泽巨兽 / 沼泽领主（大Boss）
	"frogman": {"name": "蛙人", "type": "普通", "max_hp": 6, "damage": 8, "speed": 125.0, "color": Color(0.35, 0.7, 0.35), "scale": 1.0, "drops": {"swamp_herb": 1}},
	"swamp_slime": {"name": "沼泽史莱姆", "type": "普通", "max_hp": 8, "damage": 9, "speed": 70.0, "color": Color(0.25, 0.45, 0.3), "scale": 1.2, "drops": {"swamp_herb": 1}},
	"swamp_elite": {"name": "沼泽精英", "type": "精英", "max_hp": 15, "damage": 14, "speed": 100.0, "color": Color(0.3, 0.65, 0.4), "scale": 1.4, "drops": {"swamp_herb": 2, "wood": 1}},
	"swamp_beast": {"name": "沼泽巨兽", "type": "小Boss", "max_hp": 20, "damage": 16, "speed": 85.0, "color": Color(0.25, 0.5, 0.3), "scale": 1.7, "drops": {"swamp_herb": 3}},
	"swamp_lord": {"name": "沼泽领主", "type": "大Boss", "max_hp": 33, "damage": 19, "speed": 85.0, "color": Color(0.15, 0.4, 0.25), "scale": 2.0, "drops": {"swamp_herb": 5, "wood": 2}},
	## 幽深峡谷专属怪（v4）：峡谷蜥蜴 / 石魔像 / 峡谷精英 / 峡谷巨兽 / 峡谷领主（大Boss）
	"canyon_lizard": {"name": "峡谷蜥蜴", "type": "普通", "max_hp": 6, "damage": 9, "speed": 135.0, "color": Color(0.75, 0.55, 0.3), "scale": 1.0, "drops": {"gem": 1}},
	"stone_golem": {"name": "石魔像", "type": "普通", "max_hp": 10, "damage": 11, "speed": 65.0, "color": Color(0.55, 0.5, 0.45), "scale": 1.25, "drops": {"gem": 1}},
	"canyon_elite": {"name": "峡谷精英", "type": "精英", "max_hp": 16, "damage": 15, "speed": 95.0, "color": Color(0.8, 0.6, 0.2), "scale": 1.4, "drops": {"gem": 2, "stone": 1}},
	"canyon_beast": {"name": "峡谷巨兽", "type": "小Boss", "max_hp": 21, "damage": 17, "speed": 80.0, "color": Color(0.6, 0.45, 0.3), "scale": 1.7, "drops": {"gem": 3}},
	"canyon_lord": {"name": "峡谷领主", "type": "大Boss", "max_hp": 35, "damage": 20, "speed": 80.0, "color": Color(0.45, 0.35, 0.2), "scale": 2.1, "drops": {"gem": 5, "stone": 2}},
	## 天空岛专属怪（v4）：鹰身女妖 / 天空魔像 / 天空精英 / 天空巨兽 / 天空龙（大Boss）
	"harpy": {"name": "鹰身女妖", "type": "普通", "max_hp": 5, "damage": 8, "speed": 160.0, "color": Color(0.75, 0.8, 0.95), "scale": 0.9, "drops": {"sky_crystal": 1}},
	"sky_golem": {"name": "天空魔像", "type": "普通", "max_hp": 9, "damage": 10, "speed": 75.0, "color": Color(0.7, 0.75, 0.85), "scale": 1.2, "drops": {"sky_crystal": 1}},
	"sky_elite": {"name": "天空精英", "type": "精英", "max_hp": 15, "damage": 15, "speed": 105.0, "color": Color(0.6, 0.7, 1.0), "scale": 1.4, "drops": {"sky_crystal": 2, "stone": 1}},
	"sky_beast": {"name": "天空巨兽", "type": "小Boss", "max_hp": 21, "damage": 17, "speed": 85.0, "color": Color(0.55, 0.65, 0.9), "scale": 1.7, "drops": {"sky_crystal": 3}},
	"sky_dragon": {"name": "天空龙", "type": "大Boss", "max_hp": 38, "damage": 21, "speed": 90.0, "color": Color(0.4, 0.55, 1.0), "scale": 2.2, "drops": {"sky_crystal": 5, "stone": 2}},
	## 其余群系大Boss（v4 巢穴）：冰脉领主 / 爆炎领主 / 辐射领主 / 机械霸主
	"frost_lord": {"name": "冰脉领主", "type": "大Boss", "max_hp": 32, "damage": 18, "speed": 80.0, "color": Color(0.7, 0.9, 1.0), "scale": 2.0, "drops": {"frost_crystal": 5, "stone": 2}},
	"flame_lord": {"name": "爆炎领主", "type": "大Boss", "max_hp": 34, "damage": 20, "speed": 85.0, "color": Color(1.0, 0.45, 0.1), "scale": 2.0, "drops": {"ember": 5, "stone": 2}},
	"rad_lord": {"name": "辐射领主", "type": "大Boss", "max_hp": 32, "damage": 18, "speed": 85.0, "color": Color(0.55, 0.75, 0.2), "scale": 2.0, "drops": {"rad_dust": 5, "stone": 2}},
	"mech_overlord": {"name": "机械霸主", "type": "大Boss", "max_hp": 36, "damage": 20, "speed": 80.0, "color": Color(0.3, 0.35, 0.5), "scale": 2.1, "drops": {"gear": 5, "parts": 2}},
	## 荒芜沙丘专属怪（v5）：沙蝎 / 秃鹫 / 沙丘精英 / 沙暴巨兽 / 沙暴领主（大Boss）
	"sand_scorpion": {"name": "沙蝎", "type": "普通", "max_hp": 5, "damage": 8, "speed": 145.0, "color": Color(0.8, 0.65, 0.3), "scale": 0.9, "drops": {"salt_crystal": 1}},
	"vulture": {"name": "秃鹫", "type": "普通", "max_hp": 4, "damage": 7, "speed": 160.0, "color": Color(0.55, 0.5, 0.5), "scale": 1.0, "drops": {"cactus_fiber": 1}},
	"dune_elite": {"name": "沙丘精英", "type": "精英", "max_hp": 14, "damage": 14, "speed": 105.0, "color": Color(0.85, 0.7, 0.2), "scale": 1.4, "drops": {"salt_crystal": 2, "stone": 1}},
	"sand_beast": {"name": "沙暴巨兽", "type": "小Boss", "max_hp": 19, "damage": 16, "speed": 85.0, "color": Color(0.9, 0.75, 0.35), "scale": 1.7, "drops": {"salt_crystal": 3}},
	"sand_lord": {"name": "沙暴领主", "type": "大Boss", "max_hp": 33, "damage": 19, "speed": 85.0, "color": Color(0.85, 0.7, 0.3), "scale": 2.1, "drops": {"salt_crystal": 5, "cactus_fiber": 2}},
	## 雷鸣高原专属怪（v5）：雷鹰 / 电弧傀儡 / 雷电精英 / 雷暴巨兽 / 雷暴领主（大Boss）
	"thunder_hawk": {"name": "雷鹰", "type": "普通", "max_hp": 5, "damage": 9, "speed": 165.0, "color": Color(0.75, 0.8, 1.0), "scale": 0.9, "drops": {"thunder_crystal": 1}},
	"arc_golem": {"name": "电弧傀儡", "type": "普通", "max_hp": 10, "damage": 11, "speed": 75.0, "color": Color(0.55, 0.6, 0.9), "scale": 1.25, "drops": {"thunder_crystal": 1}},
	"thunder_elite": {"name": "雷电精英", "type": "精英", "max_hp": 16, "damage": 16, "speed": 105.0, "color": Color(0.5, 0.55, 1.0), "scale": 1.4, "drops": {"thunder_crystal": 2, "stone": 1}},
	"storm_beast": {"name": "雷暴巨兽", "type": "小Boss", "max_hp": 22, "damage": 18, "speed": 90.0, "color": Color(0.6, 0.65, 1.0), "scale": 1.7, "drops": {"thunder_crystal": 3}},
	"storm_lord": {"name": "雷暴领主", "type": "大Boss", "max_hp": 38, "damage": 21, "speed": 90.0, "color": Color(0.45, 0.5, 1.0), "scale": 2.2, "drops": {"thunder_crystal": 5, "stone": 2}},
	## 真菌孢林专属怪（v5）：孢菇人 / 迷幻蛾 / 真菌精英 / 孢王 / 菌母（大Boss）
	"sporeling": {"name": "孢菇人", "type": "普通", "max_hp": 7, "damage": 9, "speed": 110.0, "color": Color(0.65, 0.5, 0.75), "scale": 1.1, "drops": {"glow_shroom": 1}},
	"hypno_moth": {"name": "迷幻蛾", "type": "普通", "max_hp": 3, "damage": 7, "speed": 155.0, "color": Color(0.8, 0.65, 0.9), "scale": 0.8, "drops": {"spore": 1}},
	"fungal_elite": {"name": "真菌精英", "type": "精英", "max_hp": 15, "damage": 15, "speed": 100.0, "color": Color(0.7, 0.5, 0.85), "scale": 1.4, "drops": {"glow_shroom": 2, "spore": 1}},
	"spore_king": {"name": "孢王", "type": "小Boss", "max_hp": 20, "damage": 17, "speed": 85.0, "color": Color(0.75, 0.45, 0.9), "scale": 1.7, "drops": {"glow_shroom": 3, "spore": 1}},
	"fungal_lord": {"name": "菌母", "type": "大Boss", "max_hp": 34, "damage": 20, "speed": 80.0, "color": Color(0.65, 0.4, 0.85), "scale": 2.1, "drops": {"glow_shroom": 5, "spore": 2}},
	## 古代遗迹专属怪（v5）：遗迹守卫 / 石像鬼 / 遗迹精英 / 遗迹巨像 / 遗迹之主（大Boss）
	"relic_guard": {"name": "遗迹守卫", "type": "普通", "max_hp": 9, "damage": 10, "speed": 70.0, "color": Color(0.55, 0.6, 0.7), "scale": 1.2, "drops": {"rune_stone": 1}},
	"gargoyle": {"name": "石像鬼", "type": "普通", "max_hp": 6, "damage": 9, "speed": 120.0, "color": Color(0.5, 0.52, 0.6), "scale": 1.0, "drops": {"relic": 1}},
	"relic_elite": {"name": "遗迹精英", "type": "精英", "max_hp": 16, "damage": 15, "speed": 95.0, "color": Color(0.6, 0.65, 0.85), "scale": 1.4, "drops": {"rune_stone": 2, "relic": 1}},
	"relic_colossus": {"name": "遗迹巨像", "type": "小Boss", "max_hp": 21, "damage": 17, "speed": 75.0, "color": Color(0.45, 0.5, 0.65), "scale": 1.8, "drops": {"rune_stone": 3, "relic": 1}},
	"relic_lord": {"name": "遗迹之主", "type": "大Boss", "max_hp": 36, "damage": 20, "speed": 80.0, "color": Color(0.35, 0.4, 0.55), "scale": 2.2, "drops": {"rune_stone": 5, "relic": 2}},
	## 幽灵墓园专属怪（v5）：幽灵 / 骸骨卫兵 / 墓园精英 / 墓穴巨兽 / 幽魂领主（大Boss）
	"ghost": {"name": "幽灵", "type": "普通", "max_hp": 4, "damage": 8, "speed": 150.0, "color": Color(0.7, 0.75, 0.85), "scale": 0.9, "drops": {"soul_ember": 1}},
	"bone_guard": {"name": "骸骨卫兵", "type": "普通", "max_hp": 8, "damage": 10, "speed": 85.0, "color": Color(0.85, 0.85, 0.8), "scale": 1.15, "drops": {"bone": 1}},
	"grave_elite": {"name": "墓园精英", "type": "精英", "max_hp": 15, "damage": 15, "speed": 100.0, "color": Color(0.6, 0.65, 0.8), "scale": 1.4, "drops": {"soul_ember": 2, "bone": 1}},
	"grave_beast": {"name": "墓穴巨兽", "type": "小Boss", "max_hp": 20, "damage": 17, "speed": 80.0, "color": Color(0.5, 0.55, 0.7), "scale": 1.7, "drops": {"soul_ember": 3, "bone": 1}},
	"wraith_lord": {"name": "幽魂领主", "type": "大Boss", "max_hp": 35, "damage": 20, "speed": 85.0, "color": Color(0.55, 0.5, 0.8), "scale": 2.1, "drops": {"soul_ember": 5, "bone": 2}},
	## 生命绿洲专属怪（v5）：绿洲水蛇 / 绿洲巨蚊 / 绿洲精英 / 绿洲巨鳄 / 绿洲之主（大Boss）
	"oasis_viper": {"name": "绿洲水蛇", "type": "普通", "max_hp": 4, "damage": 6, "speed": 130.0, "color": Color(0.35, 0.65, 0.45), "scale": 0.9, "drops": {"oasis_herb": 1}},
	"oasis_mosquito": {"name": "绿洲巨蚊", "type": "普通", "max_hp": 3, "damage": 5, "speed": 165.0, "color": Color(0.7, 0.75, 0.8), "scale": 0.8, "drops": {"clean_water": 1}},
	"oasis_elite": {"name": "绿洲精英", "type": "精英", "max_hp": 13, "damage": 13, "speed": 100.0, "color": Color(0.4, 0.7, 0.55), "scale": 1.3, "drops": {"clean_water": 2, "oasis_herb": 1}},
	"oasis_croc": {"name": "绿洲巨鳄", "type": "小Boss", "max_hp": 17, "damage": 15, "speed": 90.0, "color": Color(0.35, 0.55, 0.4), "scale": 1.6, "drops": {"clean_water": 3, "oasis_herb": 1}},
	"oasis_lord": {"name": "绿洲之主", "type": "大Boss", "max_hp": 30, "damage": 18, "speed": 85.0, "color": Color(0.3, 0.55, 0.4), "scale": 2.0, "drops": {"clean_water": 5, "oasis_herb": 2}},
}

@export var enemy_type := "goblin"
@export var attack_range: float = 48.0  # 攻击/停靠距离：身体 32px，留约 16px 间隙，避免贴脸粘连
@export var attack_cooldown: float = 1.0

## 类型标签颜色：与图鉴分类一致，方便玩家一眼分辨威胁等级
const TYPE_COLORS := {
	"普通": Color(0.85, 0.9, 0.85),
	"精英": Color(0.72, 0.55, 1.0),
	"小Boss": Color(1.0, 0.7, 0.35),
	"大Boss": Color(1.0, 0.4, 0.35),
}

var max_hp := 3      # 由类型表在 _ready 里赋值
var damage := 5
var move_speed := 100.0
var hp := 3
var attack_cd := 0.0
var _player = null  # 不写死类型：take_damage 是玩家的自定义方法，动态调用
@onready var _health_bar: Node2D = $HealthBar
@onready var _health_fill: ColorRect = $HealthBar/Fill


func _ready() -> void:
	if not ENEMY_TYPES.has(enemy_type):
		enemy_type = "goblin"
	var t: Dictionary = ENEMY_TYPES[enemy_type]
	hp = t.max_hp
	max_hp = t.max_hp
	damage = t.damage
	move_speed = t.speed
	$Visual.color = t.color
	scale = Vector2(t.scale, t.scale)
	# 头顶信息：名字 · 类型，按类型着色；大Boss整体放大，文字反向缩放保持可读
	$NameLabel.text = "%s · %s" % [t.name, t.get("type", "普通")]
	$NameLabel.modulate = TYPE_COLORS.get(t.get("type", "普通"), Color(1, 1, 1))
	$NameLabel.scale = Vector2.ONE / t.scale
	_player = get_tree().get_first_node_in_group("player")
	_update_health_bar()


func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if _player == null or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	var can_see := _has_line_of_sight()
	# 索敌 = 玩家视野制：玩家视野内（地表=屏幕内，黑暗群系=光照半径内）且怪能看见玩家就一直追；
	# 一进入攻击距离就立即停住，
	# 不再减速滑行钻进玩家身体，保证两者之间始终留出间隙，不会出现“玩家背着怪物走”
	var player_sees_me: bool = _player.can_see_position(global_position)
	if player_sees_me and can_see and dist > attack_range:
		velocity = velocity.lerp((_player.global_position - global_position).normalized() * move_speed, 0.15)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		# 停靠时不要调用 move_and_slide：Godot 会把“每帧执行 move_and_slide 的静止
		# KinematicBody”当作活动体，玩家碰到它后会被玩家物理以同速拖着走
		# （即“背着怪物”bug）。停住时不参与物理更新即可彻底避免。
	# 攻击：玩家视野内、攻击距离内且有视线（隔墙不打）
	if player_sees_me and dist <= attack_range and can_see and attack_cd <= 0.0:
		attack_cd = attack_cooldown
		_player.take_damage(damage)
	_update_label_visibility()


## 名字标签防重叠：太远的敌人不显示名字；同屏近处的敌人按"靠上的排前面"垂直错位堆叠，
## 让每只怪的名字都可见且互不遮挡（标签宽 140px，光靠隐藏解决不了并排重叠）
func _update_label_visibility() -> void:
	var hide := false
	var slot := 0
	if _player != null and global_position.distance_to(_player.global_position) > 560.0:
		hide = true  # 太远：不显示名字，减少画面噪点
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self:
				continue
			if global_position.distance_to(e.global_position) >= 110.0:
				continue
			# 比我"靠上"（y 更小）或同一行靠左的敌人：我给它们让出一个身位
			if e.global_position.y < global_position.y - 10.0:
				slot += 1
			elif absf(e.global_position.y - global_position.y) <= 10.0 and e.global_position.x < global_position.x:
				slot += 1
	$NameLabel.visible = not hide
	# 标签往上错位堆叠（每个身位 15px），同簇多只时从上到下排开；除以体型缩放保证世界间距一致
	$NameLabel.position.y = -float(slot) * 15.0 / scale.x


## 与玩家之间是否有墙/建筑遮挡：射线检测碰撞层 1（瓦片墙 + 建筑）
## 敌人自身在碰撞层 2，不会被自己的射线挡住
func _has_line_of_sight() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 1)
	query.exclude = [_player.get_rid()]  # 玩家是射线终点，不算遮挡
	return space.intersect_ray(query).is_empty()


## 受到伤害；返回 true 表示被击杀
func take_damage(amount: int) -> bool:
	hp -= amount
	_update_health_bar()
	modulate = Color(1, 0.3, 0.3)
	get_tree().create_timer(0.15).timeout.connect(func() -> void: modulate = Color(1, 1, 1))
	if hp <= 0:
		_die()
		return true
	AudioManager.play_sfx("hit")  # 击杀音由 _die 单独播，避免两个音叠加
	return false


## 头顶血条：受伤后才显示，血量按比例缩短
func _update_health_bar() -> void:
	_health_bar.visible = hp < max_hp
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_health_fill.size.x = 34.0 * ratio


func _die() -> void:
	AudioManager.play_sfx("enemy_die")
	var drops: Dictionary = ENEMY_TYPES[enemy_type].drops
	for id in drops:
		Inventory.add_item(id, drops[id])
	# P3 职业系统：击杀奖励技能点（大Boss +2 / 小Boss +1 / 普通怪每 10 只 +1）
	PlayerClass.on_enemy_killed(ENEMY_TYPES[enemy_type].get("type", "普通"))
	queue_free()
