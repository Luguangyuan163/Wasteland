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
## 背包：16 格，每格一种物品（数量可堆叠）；满 16 种后需要整理/消耗才能装新物品
const BACKPACK_SIZE := 16
const RESOURCE_SCENE := preload("res://scenes/resource_node.tscn")

var hotbar := ["", "", "", "", ""]

## 武器数据：物品 ID → 伤害 / 是否范围伤害
## 火把不是武器（照明用），所以不在表里；范围武器后续加入时标 area: true
const EQUIP_EFFECTS := {
	"stone_axe": {"damage": 2, "area": false},
}

## 背包格子：16 个元素，"" 表示空，否则是 {"id": String, "count": int}
var backpack: Array = []

## 背包内容聚合（兼容旧系统）：物品 ID → 数量，_sync_items 从背包格重建
var items := {}

## 当前装备的物品 ID，"" 表示徒手
var equipped := ""
var equipped_slot := 0  # 当前选中的槽位


func _ready() -> void:
	if backpack.is_empty():
		for i in BACKPACK_SIZE:
			backpack.append("")


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


## 放入物品；背包满（没有同物品格子、也没有空格）时返回 false，调用方决定怎么办
func add_item(id: String, amount: int) -> bool:
	if id == "" or amount <= 0:
		return true
	# 已有同类格子：数量直接累加（一格子一种物品，数量不限）
	for slot in backpack:
		if slot is Dictionary and slot.id == id:
			slot.count += amount
			_sync_items()
			changed.emit()
			return true
	# 找空格子开新堆
	for i in BACKPACK_SIZE:
		if _slot_empty(backpack[i]):
			backpack[i] = {"id": id, "count": amount}
			_sync_items()
			changed.emit()
			return true
	return false


## 能否放入该物品（有同类格或空格子）；制作前先查，避免扣了材料却放不下
func can_add(id: String) -> bool:
	if id == "":
		return true
	for slot in backpack:
		if slot is Dictionary and slot.id == id:
			return true
	for i in BACKPACK_SIZE:
		if _slot_empty(backpack[i]):
			return true
	return false


## 扣除物品：数量不够返回 false，足够则扣除并返回 true
func spend_item(id: String, amount: int) -> bool:
	if get_count(id) < amount:
		return false
	# 从背包格子里逐格扣除（可能跨多个格子）
	var remaining := amount
	for i in BACKPACK_SIZE:
		if backpack[i] is Dictionary and backpack[i].id == id:
			var take: int = mini(remaining, backpack[i].count)
			backpack[i].count -= take
			remaining -= take
			if backpack[i].count <= 0:
				backpack[i] = ""
			if remaining <= 0:
				break
	_sync_items()
	# 装备中的物品用完就自动卸下，避免拿着不存在的武器
	if id == equipped and items.get(id, 0) <= 0:
		equipped = ""
		equipped_changed.emit()
	# 对应槽位里的物品用完就清掉，避免装备栏残留空物品
	for i in HOTBAR_SIZE:
		if hotbar[i] == id and items.get(id, 0) <= 0:
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


## 已占用的格子数（HUD 摘要用）
func filled_slots() -> int:
	var n := 0
	for slot in backpack:
		if slot is Dictionary:
			n += 1
	return n


## 从"ID→数量"字典补充背包（旧存档迁移 / 拾取等）；返回是否全部放下
func restore_from_dict(data: Dictionary) -> bool:
	var all_ok := true
	for id in data:
		if not add_item(id, data[id]):
			all_ok = false
	return all_ok


## 按存档恢复背包：新格式直接还原 16 格；旧存档（无 backpack 字段）从 items 字典重建
func restore_backpack(data: Array) -> void:
	backpack = []
	for i in BACKPACK_SIZE:
		backpack.append("")
	if data.size() == BACKPACK_SIZE:
		for i in BACKPACK_SIZE:
			var slot: Variant = data[i]
			if slot is Dictionary and not slot.is_empty():
				backpack[i] = {"id": str(slot.get("id", "")), "count": int(slot.get("count", 0))}
	else:
		restore_from_dict(items.duplicate())
	_sync_items()


## 清空整个背包（死亡掉落后用）
func clear_all() -> void:
	items.clear()
	backpack = []
	for i in BACKPACK_SIZE:
		backpack.append("")
	equipped = ""
	for i in HOTBAR_SIZE:
		hotbar[i] = ""
	changed.emit()
	equipped_changed.emit()
	hotbar_changed.emit()


## 背包满时的兜底：把放不下的物品掉在地上（资源点形式），玩家稍后可捡
func drop_on_ground(id: String, amount: int, pos: Vector2) -> void:
	var node: Node2D = RESOURCE_SCENE.instantiate()
	node.resource_id = id
	node.resource_name = NAMES.get(id, id)
	node.amount = amount
	node.color = Color(0.7, 0.7, 0.7)
	node.global_position = pos
	var host := get_tree().current_scene
	if host != null:
		host.add_child(node)


## 从背包格子重建 items 聚合字典（旧系统全部走 items，保持兼容）
func _sync_items() -> void:
	items.clear()
	for slot in backpack:
		if slot is Dictionary:
			items[slot.id] = items.get(slot.id, 0) + slot.count


## 判断格子是否为空（空标记是 ""；防御性兼容 null）
func _slot_empty(slot: Variant) -> bool:
	return not (slot is Dictionary) and (slot == "" or slot == null)
