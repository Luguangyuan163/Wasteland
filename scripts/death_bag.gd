extends Node2D
## 死亡掉落包：玩家死亡时把背包物品掉在这里，回来按 E 捡回
## 挂在组 "death_bags" 里，玩家交互时优先捡取

var items := {}  # 物品 ID → 数量

@onready var _hint: Label = $Hint


func _ready() -> void:
	_hint.text = "按 E 拾取：" + _summary()
	_hint.visible = false
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_hint.visible = true


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		_hint.visible = false


## 玩家调用：把掉落物全部转回背包，然后消失
func pick_up() -> void:
	AudioManager.play_sfx("pickup")
	var remaining := {}
	for id in items:
		if not Inventory.add_item(id, items[id]):
			remaining[id] = items[id]
	if remaining.is_empty():
		items.clear()
		SaveManager.toast.emit("捡回了掉落物品")
		queue_free()
	else:
		# 背包满：没装下的留在包里，之后腾出空间再回来捡
		items = remaining
		_hint.text = "按 E 拾取：" + _summary()
		SaveManager.toast.emit("背包已满，部分物品没能捡回")


func _summary() -> String:
	var parts: Array[String] = []
	for id in items:
		parts.append("%s×%d" % [Inventory.NAMES.get(id, id), items[id]])
	return "、".join(parts) if not parts.is_empty() else "空"
