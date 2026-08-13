extends CanvasLayer
## HUD：背包 + 生命 + 装备栏 + 死亡提示 + 装备栏管理面板

const SKILL_PANEL_SCENE := preload("res://scenes/skill_panel.tscn")

@onready var _label: Label = $Label
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _hp_value: Label = $HpValue
@onready var _death_overlay: Control = $DeathOverlay
@onready var _hotbar: HBoxContainer = $Hotbar
@onready var _attack_hint: Label = $AttackHint
@onready var _toast: Label = $Toast
@onready var _equip_panel: Control = $EquipPanel
@onready var _dark_overlay: ColorRect = $DarkOverlay
@onready var _backpack_panel: Control = $BackpackPanel

var _player = null  # 不写死类型：hp/max_hp 是玩家的自定义属性
var _toast_time := 0.0
var _selected_slot := 0  # 装备栏管理面板里当前选中的槽位
var _skill_panel: Control = null
var _class_label: Label = null
var _dark_bar: ProgressBar = null
var _dark_label: Label = null


func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Inventory.changed.connect(_refresh_hotbar)  # 物品数量变化也要刷新装备栏
	Inventory.changed.connect(_refresh_backpack)  # 背包面板打开时实时刷新
	Inventory.hotbar_changed.connect(_refresh_hotbar)
	Inventory.equipped_changed.connect(_refresh_hotbar)
	Inventory.equipped_changed.connect(_refresh_attack_hint)
	_refresh()
	_refresh_hotbar()
	_refresh_attack_hint()
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.health_changed.connect(_refresh_health)
		_player.died.connect(_on_player_died)
		_player.respawned.connect(_on_player_respawned)
		_player.darkness_changed.connect(_refresh_dark)
		_refresh_health()
	SaveManager.toast.connect(_on_toast)
	_setup_equip_panel()
	_setup_backpack_panel()
	# P3 职业系统：左上角显示职业与技能点，K 打开技能树
	PlayerClass.changed.connect(_refresh_class_label)
	_class_label = Label.new()
	_class_label.offset_left = 16.0
	_class_label.offset_top = 84.0
	_class_label.offset_right = 720.0
	_class_label.offset_bottom = 110.0
	_class_label.add_theme_color_override("font_color", Color(0.82, 0.95, 0.82))
	_class_label.add_theme_font_size_override("font_size", 15)
	add_child(_class_label)
	_refresh_class_label()
	_setup_dark_ui()
	_refresh_dark()
	_skill_panel = SKILL_PANEL_SCENE.instantiate()
	add_child(_skill_panel)
	TutorialHints.show_first_time("class", "职业技能：按 K 打开技能树，击杀 BOSS 可获得技能点")


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			if _skill_panel.visible:
				_skill_panel.close()
			if _backpack_panel.visible:
				_backpack_panel.visible = false
			_toggle_equip_panel()
		elif event.physical_keycode == KEY_I:
			if _skill_panel.visible:
				_skill_panel.close()
			if _equip_panel.visible:
				_equip_panel.visible = false
			_toggle_backpack()
		elif event.physical_keycode == KEY_K:
			if _equip_panel.visible:
				_equip_panel.visible = false
			if _backpack_panel.visible:
				_backpack_panel.visible = false
			if _skill_panel.visible:
				_skill_panel.close()
			else:
				_skill_panel.open()
		elif event.physical_keycode == KEY_ESCAPE:
			if _backpack_panel.visible:
				_backpack_panel.visible = false
				get_viewport().set_input_as_handled()
			elif _skill_panel.visible:
				_skill_panel.close()
				get_viewport().set_input_as_handled()
			elif _equip_panel.visible:
				_equip_panel.visible = false
				get_viewport().set_input_as_handled()


func _refresh() -> void:
	# 背包内容只在打开背包面板时完整展示，平时只显示已用格数
	_label.text = "背包 %d/%d　按 I 打开" % [Inventory.filled_slots(), Inventory.BACKPACK_SIZE]


func _refresh_health() -> void:
	if _player != null:
		_health_bar.max_value = _player.max_hp
		_health_bar.value = _player.hp
		_hp_value.text = "%d/%d" % [_player.hp, _player.max_hp]


## 刷新左上角职业/技能点提示
func _refresh_class_label() -> void:
	if _class_label == null:
		return
	var def := PlayerClass.get_class_def()
	if PlayerClass.class_id == "":
		_class_label.text = "职业技能：按 K 查看（主菜单新游戏时选择职业）"
	else:
		_class_label.text = "%s　技能点 %d　按 K 打开技能树" % [def.get("name", "?"), PlayerClass.skill_points]


## 黑暗侵蚀指示条：左上角职业栏下方，只有黑暗值 > 0 时显示
func _setup_dark_ui() -> void:
	_dark_bar = ProgressBar.new()
	_dark_bar.offset_left = 16.0
	_dark_bar.offset_top = 116.0
	_dark_bar.offset_right = 176.0
	_dark_bar.offset_bottom = 132.0
	_dark_bar.max_value = 100.0
	_dark_bar.show_percentage = false
	_dark_bar.add_theme_stylebox_override("fill", _dark_style(Color(0.45, 0.1, 0.5)))
	_dark_bar.add_theme_stylebox_override("background", _dark_style(Color(0.05, 0.05, 0.08)))
	add_child(_dark_bar)
	_dark_label = Label.new()
	_dark_label.offset_left = 180.0
	_dark_label.offset_top = 112.0
	_dark_label.offset_right = 340.0
	_dark_label.offset_bottom = 134.0
	_dark_label.add_theme_color_override("font_color", Color(0.75, 0.6, 0.8))
	_dark_label.add_theme_font_size_override("font_size", 13)
	_dark_label.text = "黑暗侵蚀"
	add_child(_dark_label)


func _dark_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb


## 黑暗值 → 屏幕边缘晕影 + 侵蚀条（满值前火把是唯一对策）
func _refresh_dark() -> void:
	if _player == null:
		return
	var exposure := float(_player.dark_exposure)
	var alpha := clampf(exposure / 100.0 * 0.45, 0.0, 0.45)
	_dark_overlay.color = Color(0, 0, 0, alpha)
	if _dark_bar != null:
		_dark_bar.value = exposure
		var show := exposure > 0.5
		_dark_bar.visible = show
		_dark_label.visible = show
		if show:
			_dark_label.text = "黑暗侵蚀 %d%%" % int(exposure)


func _on_player_died() -> void:
	_death_overlay.visible = true


func _on_player_respawned() -> void:
	_death_overlay.visible = false


## 刷新底部装备栏：物品名只在选中槽位显示，其他槽用 ● 占位
func _refresh_hotbar() -> void:
	for i in Inventory.HOTBAR_SIZE:
		var button := _get_hotbar_button(i)
		var id: String = Inventory.hotbar[i]
		var selected := i == Inventory.equipped_slot
		if selected:
			if id == "":
				button.text = "%d 徒手" % (i + 1)
			else:
				button.text = "%d %s ×%d" % [i + 1, Inventory.NAMES.get(id, id), Inventory.get_count(id)]
		else:
			if id == "":
				button.text = "%d 空" % (i + 1)
			else:
				button.text = "%d ● ×%d" % [i + 1, Inventory.get_count(id)]
		button.disabled = id != "" and Inventory.get_count(id) <= 0
		button.modulate = Color(1, 0.9, 0.3) if selected else Color(1, 1, 1)


## 拿到第 i 个槽位的按钮；第一次访问时才创建并绑定点击
func _get_hotbar_button(i: int) -> Button:
	if i < _hotbar.get_child_count():
		return _hotbar.get_child(i) as Button
	var button := Button.new()
	button.pressed.connect(Inventory.select_slot.bind(i))
	_hotbar.add_child(button)
	return button


## 攻击提示跟着装备走：真武器显示伤害与单体/范围，非武器（火把）显示 1 伤害
func _refresh_attack_hint() -> void:
	var weapon: Dictionary = Inventory.EQUIP_EFFECTS.get(Inventory.equipped, {})
	var weapon_name := "徒手" if Inventory.equipped == "" else str(Inventory.NAMES.get(Inventory.equipped, Inventory.equipped))
	if weapon.is_empty():
		var extra := "（照明，扩大视野）" if Inventory.equipped == "torch" else ""
		_attack_hint.text = "左键：攻击（当前装备：%s%s，1 伤害）　I 背包　C 装备栏　F5 保存 / F9 读取" % [weapon_name, extra]
		return
	var kind := "范围" if weapon.get("area", false) else "单体"
	_attack_hint.text = "左键：攻击（当前装备：%s，%d 伤害 %s）　I 背包　C 装备栏　F5 保存 / F9 读取" % [weapon_name, weapon.get("damage", 1), kind]


## 装备栏管理面板：按 C 打开；点槽位选中，点背包物品放入，再点选中槽位清除
func _toggle_equip_panel() -> void:
	AudioManager.play_sfx("ui_click")
	_equip_panel.visible = not _equip_panel.visible
	if _equip_panel.visible:
		_refresh_equip_panel()


func _setup_equip_panel() -> void:
	var slots := _equip_panel.get_node("VBox/Slots")
	for i in Inventory.HOTBAR_SIZE:
		var button := Button.new()
		button.pressed.connect(_on_equip_slot_pressed.bind(i))
		slots.add_child(button)
	_equip_panel.get_node("VBox/CloseHint").text = "按 C 或 Esc 关闭"


## 背包面板：按 I 打开，4×4 共 16 格，只读展示全部物品（装备分配仍走 C 装备栏）
func _setup_backpack_panel() -> void:
	var grid := _backpack_panel.get_node("VBox/Grid") as GridContainer
	for i in Inventory.BACKPACK_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 44)
		button.disabled = true
		grid.add_child(button)
	_backpack_panel.get_node("VBox/CloseHint").text = "按 I 或 Esc 关闭"


func _toggle_backpack() -> void:
	AudioManager.play_sfx("ui_click")
	_backpack_panel.visible = not _backpack_panel.visible
	if _backpack_panel.visible:
		_refresh_backpack()


## 刷新 16 格显示：每格 = 物品名 ×数量，空格显示序号+空
func _refresh_backpack() -> void:
	if _backpack_panel == null:
		return
	var grid := _backpack_panel.get_node("VBox/Grid") as GridContainer
	for i in Inventory.BACKPACK_SIZE:
		var button: Button = grid.get_child(i)
		var slot: Variant = Inventory.backpack[i]
		if slot is Dictionary:
			button.text = "%s ×%d" % [Inventory.NAMES.get(slot.id, slot.id), slot.count]
		else:
			button.text = "%d 空" % (i + 1)


func _on_equip_slot_pressed(i: int) -> void:
	if _selected_slot == i and Inventory.hotbar[i] != "":
		Inventory.clear_slot(i)  # 再点一次清空
	else:
		_selected_slot = i
	_refresh_equip_panel()


func _refresh_equip_panel() -> void:
	var slots := _equip_panel.get_node("VBox/Slots")
	for i in Inventory.HOTBAR_SIZE:
		var button: Button = slots.get_child(i)
		var id: String = Inventory.hotbar[i]
		button.text = "%d %s" % [i + 1, "空" if id == "" else str(Inventory.NAMES.get(id, id))]
		button.modulate = Color(1, 0.9, 0.3) if i == _selected_slot else Color(1, 1, 1)
	var list := _equip_panel.get_node("VBox/Items")
	for child in list.get_children():
		child.queue_free()
	for id in Inventory.items:
		if Inventory.items[id] > 0:
			var btn := Button.new()
			btn.text = "%s ×%d" % [Inventory.NAMES.get(id, id), Inventory.items[id]]
			btn.pressed.connect(_on_assign_item.bind(id))
			list.add_child(btn)


func _on_assign_item(id: String) -> void:
	Inventory.assign_slot(_selected_slot, id)
	AudioManager.play_sfx("equip")
	_refresh_equip_panel.call_deferred()  # 等按钮信号结束再刷新，避免释放正在点击的按钮


## 显示一条 2.5 秒后消失的提示
func _on_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = 2.5
