extends CanvasLayer
## 制作面板：列出工作台的配方，点按钮合成
## 玩家靠近工作台按 E 打开，再按 E 或 Esc 关闭

## 用 preload 而不是 class_name 引用工作台脚本：
## class_name 需要编辑器扫描后才会生效，直接 preload 更稳定
const WORKBENCH_SCRIPT := preload("res://scripts/workbench.gd")

var workbench: WORKBENCH_SCRIPT = null


func _ready() -> void:
	visible = false


## 打开面板，记住当前使用的工作台（之后合成要检查玩家是否还在旁边）
func open(target: Node) -> void:
	workbench = target as WORKBENCH_SCRIPT
	if workbench == null:
		return
	AudioManager.play_sfx("ui_click")
	_refresh()
	visible = true


func close() -> void:
	AudioManager.play_sfx("ui_close")
	visible = false
	workbench = null


func is_open() -> bool:
	return visible


## 根据配方数据重建按钮列表：先清空旧的，再逐个生成
## 用代码生成而不是写死在场景里，以后加配方不用改 UI
func _refresh() -> void:
	for child in $Panel/VBox.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "制作（工作台）"
	$Panel/VBox.add_child(title)
	for recipe_id in workbench.RECIPES:
		var recipe: Dictionary = workbench.RECIPES[recipe_id]
		var button := Button.new()
		button.text = "%s　%s" % [recipe.name, _format_cost(recipe.cost)]
		button.pressed.connect(_on_recipe_pressed.bind(recipe_id))
		$Panel/VBox.add_child(button)


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in cost:
		parts.append("%s×%d" % [Inventory.NAMES.get(id, id), cost[id]])
	return "（" + " ".join(parts) + "）"


func _on_recipe_pressed(recipe_id: String) -> void:
	if workbench != null:
		workbench.craft(recipe_id)
