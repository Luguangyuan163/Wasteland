extends Node
## 背包 + 装备（Autoload 单例）：所有场景都能通过 Inventory 访问
##
## 注册方式：项目设置 → 自动加载 → Inventory = res://scripts/inventory.gd

signal changed
signal equipped_changed  # 当前装备变化时通知 HUD
signal hotbar_changed    # 装备栏槽位内容变化时通知 HUD

## 物品 ID → 显示名（HUD 用）
const NAMES := {
	"wood": "木材",
	"stone": "石头",
	"iron": "铁矿石",
	"parts": "零件",
	"frost_crystal": "冰晶",
	"ember": "余烬",
	"rad_dust": "辐射尘",
	"gear": "齿轮",
	"swamp_herb": "沼泽草药",
	"gem": "宝石",
	"sky_crystal": "天空晶石",
	"salt_crystal": "盐晶",
	"cactus_fiber": "仙人掌纤维",
	"thunder_crystal": "雷晶",
	"glow_shroom": "荧光菇",
	"spore": "孢子",
	"rune_stone": "符文石",
	"relic": "古物",
	"soul_ember": "灵魂余烬",
	"bone": "白骨",
	"clean_water": "净水",
	"oasis_herb": "绿洲草药",
	"stone_axe": "石斧",
	"torch": "火把",
	"darkstone": "暗石",
}

## 装备栏：5 个槽位，槽位 → 物品 ID（"" 表示空槽，选中空槽 = 徒手）
const HOTBAR_SIZE := 5
var hotbar := ["", "", "", "", ""]

## 武器数据：物品 ID → 伤害 / 是否范围伤害
## 火把不是武器（照明用），所以不在表里；范围武器后续加入时标 area: true
const EQUIP_EFFECTS := {
	"stone_axe": {"damage": 2, "area": false},
}

## 背包内容：物品 ID → 数量
var items := {}

## 当前装备的物品 ID，"" 表示徒手
var equipped := ""
var equipped_slot := 0  # 当前选中的槽位


## 选中一个槽位（没有物品或物品数量为 0 的槽 = 徒手）
func select_slot(slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	var id: String = hotbar[slot]
	if id != "" and get_count(id) <= 0:
		return
	equipped_slot = slot
	equipped = id
	equipped_changed.emit()


## 把背包里的物品放入某个槽位（同一物品只占一个槽）
func assign_slot(slot: int, id: String) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE or id == "":
		return
	for i in HOTBAR_SIZE:
		if hotbar[i] == id:
			hotbar[i] = ""
	if equipped_slot == slot:
		equipped = id
	hotbar[slot] = id
	hotbar_changed.emit()
	equipped_changed.emit()


## 清空一个槽位（选中它就变回徒手）
func clear_slot(slot: int) -> void:
	if slot < 0 or slot >= HOTBAR_SIZE:
		return
	hotbar[slot] = ""
	if equipped_slot == slot:
		equipped = ""
		equipped_changed.emit()
	hotbar_changed.emit()


func add_item(id: String, amount: int) -> void:
	items[id] = items.get(id, 0) + amount
	changed.emit()


## 扣除物品：数量不够返回 false，足够则扣除并返回 true
func spend_item(id: String, amount: int) -> bool:
	if get_count(id) < amount:
		return false
	items[id] -= amount
	# 装备中的物品用完就自动卸下，避免拿着不存在的武器
	if id == equipped and items[id] <= 0:
		equipped = ""
		equipped_changed.emit()
	# 对应槽位里的物品用完就清掉，避免装备栏残留空物品
	for i in HOTBAR_SIZE:
		if hotbar[i] == id and items[id] <= 0:
			hotbar[i] = ""
			hotbar_changed.emit()
	changed.emit()
	return true


func get_count(id: String) -> int:
	return items.get(id, 0)


func total_count() -> int:
	var total := 0
	for count in items.values():
		total += count
	return total
