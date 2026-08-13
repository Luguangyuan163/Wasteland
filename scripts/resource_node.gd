extends Node2D
## 资源点：玩家走进范围按 E 采集
##
## 渲染（2026-08-13）：不再用纯色块——每个资源点 = 黑色描边 + 分类形状 +
## 中文首字图标（白字黑描边）+ 靠近显示名字，解决"色块颜色相近看不清物品"的问题。
## 形状按大类区分：方块=矿物 / 菱形=植物 / 圆=液体 / 星=晶体 / 六边形=工业与遗物
##
## 放在组 "resource_nodes" 中，玩家会寻找最近的资源点并调用 gather()
## 对应计划表：P1 第 3 周「资源点：数据结构与采集交互」

@export var resource_id: String = "wood"        # 物品 ID（Inventory 里的键）
@export var resource_name: String = "木材"       # 显示名
@export var amount: int = 1                     # 每次采集获得的数量
@export var color: Color = Color(0.35, 0.65, 0.25)  # 视觉颜色（树=绿，矿石=灰）

## 资源分类：形状 + 图标字符（与颜色无关，彻底避免撞色）
const CATEGORY := {
	"wood": {"shape": "diamond", "glyph": "木"},
	"stone": {"shape": "square", "glyph": "石"},
	"iron": {"shape": "square", "glyph": "铁"},
	"darkstone": {"shape": "square", "glyph": "暗"},
	"parts": {"shape": "hexagon", "glyph": "件"},
	"frost_crystal": {"shape": "star", "glyph": "冰"},
	"ember": {"shape": "star", "glyph": "烬"},
	"rad_dust": {"shape": "star", "glyph": "尘"},
	"gear": {"shape": "hexagon", "glyph": "齿"},
	"swamp_herb": {"shape": "diamond", "glyph": "草"},
	"gem": {"shape": "star", "glyph": "宝"},
	"sky_crystal": {"shape": "star", "glyph": "天"},
	"salt_crystal": {"shape": "square", "glyph": "盐"},
	"cactus_fiber": {"shape": "diamond", "glyph": "纤"},
	"thunder_crystal": {"shape": "star", "glyph": "雷"},
	"glow_shroom": {"shape": "diamond", "glyph": "菇"},
	"spore": {"shape": "circle", "glyph": "孢"},
	"rune_stone": {"shape": "square", "glyph": "符"},
	"relic": {"shape": "hexagon", "glyph": "古"},
	"soul_ember": {"shape": "star", "glyph": "魂"},
	"bone": {"shape": "hexagon", "glyph": "骨"},
	"clean_water": {"shape": "circle", "glyph": "水"},
	"oasis_herb": {"shape": "diamond", "glyph": "药"},
}

var _player_nearby := false
var _name_nearby := false

@onready var _outline: Polygon2D = $Outline
@onready var _visual: Polygon2D = $Visual
@onready var _glyph: Label = $Glyph
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	var cat: Dictionary = CATEGORY.get(resource_id, {"shape": "square", "glyph": "物"})
	var pts := _shape_points(cat["shape"])
	var outline_pts := PackedVector2Array()
	for p in pts:
		outline_pts.append(p * 1.32)
	_outline.polygon = outline_pts
	_outline.color = Color(0.05, 0.05, 0.05, 0.92)
	_visual.polygon = pts
	# 主体颜色提亮一档，配合黑描边在任何地面上都醒目
	_visual.color = color.lightened(0.18)
	_glyph.text = cat["glyph"]
	_glyph.modulate = Color(1, 1, 1, 0.96)
	_name_label.text = "%s ×%d" % [resource_name, amount]
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	$NameArea.body_entered.connect(_on_name_entered)
	$NameArea.body_exited.connect(_on_name_exited)


func _process(_delta: float) -> void:
	_name_label.visible = _name_nearby


func _on_name_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_name_nearby = true


func _on_name_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_name_nearby = false


## 按分类生成形状顶点：方块/菱形/圆/五角星/六边形
static func _shape_points(shape: String) -> PackedVector2Array:
	match shape:
		"diamond":
			return PackedVector2Array([Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0)])
		"circle":
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				pts.append(Vector2(cos(a), sin(a)) * 14.0)
			return pts
		"hexagon":
			var pts2 := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 - PI / 6.0
				pts2.append(Vector2(cos(a), sin(a)) * 14.0)
			return pts2
		"star":
			var pts3 := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI / 2.0
				var r := 15.0 if i % 2 == 0 else 6.5
				pts3.append(Vector2(cos(a), sin(a)) * r)
			return pts3
		_:  # square
			return PackedVector2Array([Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)])


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_nearby = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_nearby = false


## 玩家调用：玩家在范围内才返回物品数据，否则返回空字典
func gather() -> Dictionary:
	if not _player_nearby:
		return {}
	return {"resource_id": resource_id, "amount": amount}
