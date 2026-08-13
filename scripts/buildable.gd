extends StaticBody2D
## 建造物：石墙 / 木地板 / 篝火 / 工作台
## 对应计划表：P1 第 5 周「建造模式：放置墙、地板、工作台」

## 蓝图数据：类型 → 名称 / 消耗 / 颜色 / 是否有碰撞 / 专用场景（可选）
## 所有建筑的类型、成本、外观都集中在这里，方便以后统一调整
## 专用场景：工作台有自己的脚本和感应区，所以单独一个场景；其他建筑用本场景
const BLUEPRINTS := {
	"wall": {
		"name": "石墙",
		"cost": {"wood": 2},
		"color": Color(0.65, 0.6, 0.5, 1),
		"collision": true,
	},
	"floor": {
		"name": "木地板",
		"cost": {"wood": 1},
		"color": Color(0.55, 0.4, 0.25, 1),
		"collision": false,
	},
	"campfire": {
		"name": "篝火",
		"cost": {"wood": 1},
		"color": Color(1, 0.55, 0.1, 1),
		"collision": false,
	},
	"workbench": {
		"name": "工作台",
		"cost": {"wood": 3, "stone": 2},
		"color": Color(0.55, 0.42, 0.28, 1),
		"collision": true,
		"scene": preload("res://scenes/workbench.tscn"),
	}
}

@export var type: String = "wall"


func _ready() -> void:
	var blueprint: Dictionary = BLUEPRINTS[type]
	$Visual.color = blueprint.color
	$CollisionShape2D.set_deferred("disabled", not blueprint.collision)
	if type == "floor":
		z_index = -1  # 地板画在角色脚下
