extends StaticBody2D
## 工作台：玩家靠近后按 E 打开制作面板
## 对应计划表：P1 第 5 周「制作系统 v1：工作台合成物品」

## 配方数据：配方 ID → 名称 / 消耗 / 产出物品 / 数量
## 和 BLUEPRINTS 一样先用字典集中管理，方便以后迁移到 Resource 文件
const RECIPES := {
	"stone_axe": {
		"name": "石斧",
		"cost": {"wood": 3, "stone": 2},
		"product": "stone_axe",
		"amount": 1,
	},
	"torch": {
		"name": "火把",
		"cost": {"wood": 1},
		"product": "torch",
		"amount": 1,
	},
}

@export var type: String = "workbench"  # 类型标识，存档/读档用（与其他建筑统一）

var _player_nearby := false


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_player_nearby = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_player_nearby = false


func is_player_nearby() -> bool:
	return _player_nearby


## 尝试合成一个配方：玩家在旁边 + 材料足够 → 扣材料、加产出，返回是否成功
func craft(recipe_id: String) -> bool:
	if not _player_nearby:
		return false
	if not RECIPES.has(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	for id in recipe.cost:
		if Inventory.get_count(id) < recipe.cost[id]:
			AudioManager.play_sfx("craft_fail")  # 材料不够：播放失败音
			return false  # 材料不够，什么都不发生
	if not Inventory.can_add(recipe.product):
		AudioManager.play_sfx("craft_fail")
		SaveManager.toast.emit("背包已满，做不了新东西")
		return false
	for id in recipe.cost:
		Inventory.spend_item(id, recipe.cost[id])
	Inventory.add_item(recipe.product, recipe.amount)
	AudioManager.play_sfx("craft")
	return true
