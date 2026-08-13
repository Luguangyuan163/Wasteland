extends CharacterBody2D
## 玩家角色：移动 + 采集 + 建造 + 制作 + 战斗 + 装备 + 死亡掉落/重生
##
## 移动：WASD / 方向键
## 采集：靠近资源点按 E
## 制作：靠近工作台按 E 打开制作面板
## 建造：按 B 进入建造模式，1/2/3/4 选类型，左键放置，右键拆除（只能建在身边 4 格内）
## 战斗：左键朝鼠标方向 120° 扇形攻击，单体 范围伤害按武器数据表
## 装备：非建造模式下按 1/2/3 切换徒手/石斧/火把
## 死亡：生命归零后背包掉成地上掉落包，回出生点重生（带短暂无敌）
## 光照：黑暗环境中点光源跟随玩家，装备火把扩大视野

const BUILDABLE_SCENE := preload("res://scenes/buildable.tscn")
const BUILDABLE_SCRIPT := preload("res://scripts/buildable.gd")
const CRAFTING_PANEL_SCENE := preload("res://scenes/crafting_panel.tscn")
const DEATH_BAG_SCENE := preload("res://scenes/death_bag.tscn")

const TILE_SIZE := 32.0
const ATTACK_RANGE := 70.0    # 近战攻击距离（像素）
const ATTACK_COOLDOWN := 0.5  # 两次攻击的最小间隔（秒）
const ATTACK_CONE_DEG := 120.0  # 攻击扇形总角度（以鼠标方向为中心）
const TORCH_SCALE := 1.7        # 有火把 = 当前完整视野
const NO_TORCH_SCALE := TORCH_SCALE / 4.0  # 无火把 = 视野的 1/4（必须借助光源）
const TORCH_COLOR := Color(1.0, 0.68, 0.32)  # 火把暖橙光（更接近火焰色）
const LIGHT_TEXTURE_RADIUS := 128.0  # 点光源贴图 256px 的一半：视野半径 = 贴图半径 × 缩放
const UNSTUCK_DELAY := 2.5     # 按住移动键但持续被卡住的秒数 → 自动脱困
const UNSTUCK_RADIUS := 4      # 脱困搜索半径（格）

signal health_changed  # 生命变化时通知 HUD 刷新
signal died            # 死亡时通知 HUD / 波次系统
signal respawned       # 重生完成时通知 HUD

@export var move_speed: float = 400.0
@export var gather_radius: float = 64.0
@export var workbench_radius: float = 72.0
@export var respawn_delay := 3.0  # 死亡后多久重生（秒）
@export var respawn_invincible := 3.0  # 复活后的无敌时间（秒），防止复活即死
@export var build_range: float = 128.0  # 建造范围：4 格（像素） 
var max_hp := 100
var hp := max_hp
var attack_cd := 0.0
var invincible := 0.0  # 复活无敌剩余时间（秒）
var dead := false
var spawn_position := Vector2.ZERO
var build_mode := false
var selected_type := "wall"
var ghost: Node2D = null
var crafting_panel: CanvasLayer = null
var _half_cone_dot := 0.5  # 扇形半角余弦，_ready 里按 ATTACK_CONE_DEG 计算
var vision_radius := 0.0  # 黑暗群系中的视野半径（px），_update_light 里按装备更新；怪物索敌用
var _blocked_time := 0.0   # 连续被卡住的时间（秒），超时自动转移到附近空地
var _regen_acc := 0.0      # 医师·再生的分数生命累加器
@onready var _light: PointLight2D = $PointLight2D


func _ready() -> void:
	spawn_position = global_position  # 记录出生点，死亡后回到这里
	_half_cone_dot = cos(deg_to_rad(ATTACK_CONE_DEG / 2.0))
	_setup_light()
	Inventory.equipped_changed.connect(_update_light)
	_update_light()
	# P3 职业系统：职业变化时实时应用被动加成
	PlayerClass.changed.connect(_apply_class_mods)
	_apply_class_mods()


func _physics_process(delta: float) -> void:
	if dead:
		return
	# 复活无敌：闪烁提示 + 计时
	if invincible > 0.0:
		invincible -= delta
		modulate.a = 0.35 if fmod(invincible, 0.3) < 0.15 else 1.0
	elif modulate.a != 1.0:
		modulate.a = 1.0
	# 火把微光闪烁（恐怖氛围小细节）
	if Inventory.equipped == "torch":
		_light.texture_scale = TORCH_SCALE + randf() * 0.15
	# 0. 攻击冷却计时
	attack_cd = maxf(0.0, attack_cd - delta)

	# 1. 移动
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * _effective_move_speed()
	move_and_slide()
	# 卡住检测：一直按着方向键却几乎没位移 → 说明被地形/建筑夹住，自动脱困
	if dead or direction == Vector2.ZERO:
		_blocked_time = 0.0
	elif velocity.length() < 5.0:
		_blocked_time += delta
		if _blocked_time >= UNSTUCK_DELAY:
			_blocked_time = 0.0
			_try_unstuck()
	else:
		_blocked_time = 0.0
	# 医师·再生：每秒回复 0.4×等级 生命（不超过上限）
	var regen_lvl := PlayerClass.skill_level("regeneration")
	if regen_lvl > 0 and hp < max_hp:
		_regen_acc += 0.4 * regen_lvl * delta
		if _regen_acc >= 1.0:
			var gain := int(_regen_acc)
			_regen_acc -= float(gain)
			var prev := hp
			hp = mini(max_hp, hp + gain)
			if hp != prev:
				health_changed.emit()

	# 2. 交互（采集 / 制作）
	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# 3. 建造模式下，预览跟随鼠标并吸附到网格
	if build_mode and is_instance_valid(ghost):
		ghost.global_position = _snap_to_grid(get_global_mouse_position())
		_update_ghost_validity()


func _unhandled_input(event: InputEvent) -> void:
	if dead or get_tree().paused:
		return
	if event.is_action_pressed("build_mode"):
		_toggle_build_mode()
	elif build_mode:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_1:
				selected_type = "wall"
			elif event.physical_keycode == KEY_2:
				selected_type = "floor"
			elif event.physical_keycode == KEY_3:
				selected_type = "campfire"
			elif event.physical_keycode == KEY_4:
				selected_type = "workbench"
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_try_place()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_remove_nearest_buildable()
	elif event.is_action_pressed("ui_cancel"):
		if crafting_panel != null and crafting_panel.is_open():
			crafting_panel.close()
			get_viewport().set_input_as_handled()  # 已处理，暂停管理器不再响应这次 Esc
	else:
		# 非建造模式：数字键切换装备
		if event is InputEventKey and event.pressed and not event.echo:
			var slot := _hotbar_slot_for_key(event.physical_keycode)
			if slot >= 0 and slot < Inventory.HOTBAR_SIZE:
				Inventory.select_slot(slot)
				AudioManager.play_sfx("equip")
				return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_attack()


## 切换建造模式：创建/销毁半透明预览
func _toggle_build_mode() -> void:
	build_mode = not build_mode
	AudioManager.play_sfx("equip")
	if build_mode:
		ghost = _scene_for_type(selected_type).instantiate()
		if ghost.get("type") != null:
			ghost.type = selected_type
		ghost.modulate.a = 0.5
		ghost.remove_from_group("buildables")  # 预览不算已放置的建造物
		ghost.remove_from_group("workbenches")  # 预览不能被当成工作台交互
		ghost.z_index = 10
		get_parent().add_child(ghost)
		ghost.get_node("CollisionShape2D").disabled = true  # 预览不挡路（_ready 之后覆盖）
		if ghost.has_node("InteractArea"):
			ghost.get_node("InteractArea").monitoring = false  # 预览不触发感应区
		_update_build_hint(true)
	else:
		if is_instance_valid(ghost):
			ghost.queue_free()
		_update_build_hint(false)


## 蓝图里可能指定了专用场景（如工作台），没指定就用默认建造物场景
func _scene_for_type(type: String) -> PackedScene:
	return BUILDABLE_SCRIPT.BLUEPRINTS[type].get("scene", BUILDABLE_SCENE)


## 幽灵预览按建造范围变色：范围内白色半透明，超出范围红色半透明
func _update_ghost_validity() -> void:
	var in_range := ghost.global_position.distance_to(global_position) <= build_range
	ghost.modulate = Color(1, 1, 1, 0.5) if in_range else Color(1, 0.3, 0.3, 0.5)


## 尝试在预览位置放置建筑：范围校验 + 占格校验 + 资源校验，再扣除、生成
func _try_place() -> void:
	if ghost.global_position.distance_to(global_position) > build_range:
		return  # 超出建造范围
	if _cell_blocked():
		return  # 同格已有建筑，或玩家自己站在这格
	var blueprint: Dictionary = BUILDABLE_SCRIPT.BLUEPRINTS[selected_type]
	# 工程师·节俭：建造消耗 -15%/级
	var discount := 1.0 - 0.15 * PlayerClass.skill_level("thrifty")
	for id in blueprint.cost:
		if Inventory.get_count(id) < _build_cost(blueprint, id, discount):
			return  # 资源不够，什么都不发生
	for id in blueprint.cost:
		Inventory.spend_item(id, _build_cost(blueprint, id, discount))
	var buildable: Node2D = _scene_for_type(selected_type).instantiate()
	if buildable.get("type") != null:
		buildable.type = selected_type
	buildable.global_position = ghost.global_position
	get_parent().add_child(buildable)
	AudioManager.play_sfx("build")


## 目标格是否被占：玩家站在这格，或已有建筑占着同一格
func _cell_blocked() -> bool:
	if global_position.distance_to(ghost.global_position) < 24.0:
		return true  # 玩家本人占着这格
	for node in get_tree().get_nodes_in_group("buildables"):
		if node.global_position.distance_to(ghost.global_position) < 1.0:
			return true
	return false


## 右键拆除离预览最近的建造物
func _remove_nearest_buildable() -> void:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("buildables"):
		var dist := ghost.global_position.distance_to(node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	if best != null and best_dist <= 48.0 and best.global_position.distance_to(global_position) <= build_range:
		_salvage_refund(best)
		best.queue_free()
		AudioManager.play_sfx("remove")


## 把坐标吸附到 32px 网格（与瓦片地图对齐）
func _snap_to_grid(pos: Vector2) -> Vector2:
	var cell := Vector2(floor(pos.x / TILE_SIZE), floor(pos.y / TILE_SIZE))
	return cell * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)


## 按 E 的交互逻辑：先关面板 → 再开工作台制作 → 最后才是采集
func _try_interact() -> void:
	if build_mode:
		return
	if crafting_panel != null and crafting_panel.is_open():
		crafting_panel.close()
		return
	# 密码锁面板开着时再按 E = 关闭面板（和制作面板一致）
	var keypad_panel := get_tree().get_first_node_in_group("keypad_panels")
	if keypad_panel != null and keypad_panel.is_open():
		keypad_panel.close()
		return
	# 死亡掉落包优先捡取
	var bag := _nearest_node_in_group("death_bags", gather_radius)
	if bag != null:
		bag.pick_up()
		return
	# 能量管道：靠近按 E 转动
	var pipe := _nearest_node_in_group("power_pipes", gather_radius)
	if pipe != null:
		pipe.toggle()
		return
	# 密码锁：靠近按 E 输入密码（遗迹装置激活后才有反应）
	var keypad := _nearest_node_in_group("keypad_locks", gather_radius)
	if keypad != null:
		keypad.try_open()
		return
	# 遗迹装置：靠近按 E 启动符文序列谜题
	var relic := _nearest_node_in_group("relic_devices", gather_radius)
	if relic != null:
		relic.start_attempt()
		return
	# 双子机关碑：靠近按 E 激活（先 A 后 B，联动谜题）
	var altar := _nearest_node_in_group("twin_altars", gather_radius)
	if altar != null:
		altar.activate()
		return
	# 传送门：靠近按 E 进入目标世界
	var portal := _nearest_node_in_group("portals", gather_radius)
	if portal != null:
		portal.enter()
		return
	var workbench := _nearest_node_in_group("workbenches", workbench_radius)
	if workbench != null:
		_open_crafting(workbench)
		return
	_try_gather()


## 打开制作面板（第一次使用时才创建）
func _open_crafting(workbench: Node) -> void:
	if crafting_panel == null:
		crafting_panel = CRAFTING_PANEL_SCENE.instantiate()
		get_tree().current_scene.add_child(crafting_panel)
	crafting_panel.open(workbench)


## 在组 "resource_nodes" 里找最近的资源点，够近就采集
func _try_gather() -> void:
	var best := _nearest_node_in_group("resource_nodes", gather_radius)
	if best == null:
		return
	var result: Dictionary = best.gather()
	if not result.is_empty():
		# 勘探者·采集大师：采集产出 +20%/级
		var bonus := 1.0 + 0.2 * PlayerClass.skill_level("gatherer")
		var amount := maxi(1, int(round(float(result.amount) * bonus)))
		Inventory.add_item(result.resource_id, amount)
		AudioManager.play_sfx("gather")
		best.queue_free()


## 在指定组里找离玩家最近的节点，超过 max_dist 视为不在旁边
func _nearest_node_in_group(group: String, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	if best != null and best_dist <= max_dist:
		return best
	return null


## 左键攻击：以鼠标方向为轴做 120° 扇形判定
## 单体武器打扇形内最近一个；范围武器（后续加入）打扇形内全部
func _try_attack() -> void:
	if build_mode or attack_cd > 0.0:
		return
	attack_cd = ATTACK_COOLDOWN
	var aim := get_global_mouse_position() - global_position
	_spawn_swing(get_global_mouse_position())
	AudioManager.play_sfx("attack")
	var targets := _enemies_in_attack_cone(aim)
	if targets.is_empty():
		return
	var weapon: Dictionary = Inventory.EQUIP_EFFECTS.get(Inventory.equipped, {})
	var damage: int = weapon.get("damage", 1)
	if weapon.get("area", false):
		for enemy in targets:
			enemy.take_damage(damage)
	else:
		targets[0].take_damage(damage)  # 单体：只打最近一个 

## 收集攻击扇形内的敌人（距离 + 夹角），按距离从近到远排序
func _enemies_in_attack_cone(aim: Vector2) -> Array:
	var targets: Array = []
	var aim_dir := aim.normalized()
	var has_aim := aim.length() > 0.5  # 鼠标几乎贴在角色身上时不做方向过滤（浮点安全阈值）
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > ATTACK_RANGE:
			continue
		if has_aim and aim_dir.dot(to_enemy.normalized()) < _half_cone_dot:
			continue  # 夹角太大，在扇形外（打不到背后/侧面）
		targets.append(enemy)
	targets.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return targets


## 数字键 → 装备栏槽位（0 开始），不在栏里的键返回 -1
func _hotbar_slot_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		KEY_5: return 4
	return -1


## 攻击特效：一条从玩家指向目标的黄色短线，0.15 秒后消失
func _spawn_swing(target: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(1, 0.9, 0.4)
	line.points = PackedVector2Array([Vector2.ZERO, (target - global_position).limit_length(ATTACK_RANGE)])
	add_child(line)
	get_tree().create_timer(0.15).timeout.connect(func() -> void: line.queue_free())


## 受到伤害：扣血、闪红、通知 HUD；生命归零则进入死亡流程
func take_damage(amount: int) -> void:
	if dead or invincible > 0.0:
		return
	hp = maxi(0, hp - amount)
	health_changed.emit()
	if hp <= 0:
		_die()
		return
	AudioManager.play_sfx("hurt")
	modulate = Color(1, 0.45, 0.45)
	get_tree().create_timer(0.2).timeout.connect(func() -> void: modulate = Color(1, 1, 1))


## 死亡：掉落背包物品、锁操作，等 respawn_delay 秒后重生
func _die() -> void:
	dead = true
	died.emit()
	AudioManager.play_sfx("player_die")
	TutorialHints.show_first_time("death", "你倒下了：背包物品掉落在原地，复活后记得回去按 E 捡回")
	velocity = Vector2.ZERO
	modulate = Color(0.45, 0.45, 0.45)
	_drop_inventory()  # 背包物品掉在死亡位置，方便之后回来捡
	await get_tree().create_timer(respawn_delay).timeout
	respawn()


## 把背包里所有物品掉成地上的“死亡掉落包”，背包清空
func _drop_inventory() -> void:
	if Inventory.total_count() <= 0:
		return  # 背包是空的就不掉
	var bag: Node2D = DEATH_BAG_SCENE.instantiate()
	bag.items = Inventory.items.duplicate()
	bag.global_position = global_position
	get_parent().add_child(bag)
	Inventory.items.clear()
	Inventory.equipped = ""
	Inventory.changed.emit()
	Inventory.equipped_changed.emit()


func respawn() -> void:
	dead = false
	hp = max_hp
	AudioManager.play_sfx("respawn")
	global_position = spawn_position
	modulate = Color(1, 1, 1)
	invincible = respawn_invincible  # 复活保护：短暂无敌，避免被围殴
	health_changed.emit()
	respawned.emit()


## 卡住自动脱困：在周围找一块最近的空地转移（防止玩家被石头/水/建筑夹住出不去）
## 参照：地图里偶尔会出现"对角夹缝"（8 方向看似连通、实际挤不过去），
## 这个机制保证任何情况下玩家都不会永久卡死
func _try_unstuck() -> void:
	var ground = _ground_layer()
	if ground == null:
		return
	var start := Vector2i(floori(global_position.x / 32.0), floori(global_position.y / 32.0))
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var best: Vector2i = start
	var best_dist := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var d := absi(cell.x - start.x) + absi(cell.y - start.y)
		if d > best_dist and _cell_walkable(ground, cell):
			best = cell
			best_dist = d
		if d >= UNSTUCK_RADIUS:
			continue
		for dir2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cell + dir2
			if not visited.has(nxt) and _cell_walkable(ground, nxt):
				visited[nxt] = true
				queue.append(nxt)
	if best_dist >= 2:
		global_position = Vector2(best) * 32.0 + Vector2(16, 16)
		SaveManager.toast.emit("检测到卡住，已自动转移到附近空地")


func _ground_layer():
	var world = get_parent()
	if world != null and "get_node" in world:
		return world.get_node_or_null("Ground")
	return null


func _cell_walkable(ground: TileMapLayer, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= 400 or cell.y >= 400:
		return false
	return ground.get_cell_atlas_coords(cell) != Vector2i(0, 1)  # 石头（0,1）挡路


func _update_build_hint(hint_visible: bool) -> void:
	var hint: Label = get_tree().get_first_node_in_group("build_hint")
	if hint:
		hint.visible = hint_visible


## 创建点光源的径向渐变贴图（代码生成，不用额外素材）
func _setup_light() -> void:
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)  # 圆心在贴图中心（默认在左上角，会导致扇形光）
	grad.fill_to = Vector2(1.0, 0.5)    # 半径覆盖整张贴图
	grad.width = 256
	grad.height = 256
	_light.texture = grad


## 按当前装备切换光照：火把更大、暖色；其他基础白光
func _update_light() -> void:
	# 勘探者·鹰眼：黑暗中的视野半径 +25%/级（火把/基础光同步放大）
	var eagle := 1.0 + 0.25 * PlayerClass.skill_level("eagle_eye")
	if Inventory.equipped == "torch":
		_light.color = TORCH_COLOR
		_light.texture_scale = TORCH_SCALE * eagle
		vision_radius = TORCH_SCALE * LIGHT_TEXTURE_RADIUS * eagle
	else:
		_light.color = Color(1, 1, 1)
		_light.texture_scale = NO_TORCH_SCALE * eagle
		vision_radius = NO_TORCH_SCALE * LIGHT_TEXTURE_RADIUS * eagle


## 勘探者·疾行：移动速度 +8%/级
func _effective_move_speed() -> float:
	return move_speed * (1.0 + 0.08 * PlayerClass.skill_level("swift"))


## 工程师·节俭：按折扣计算单项建造消耗（最低 1 个）
func _build_cost(blueprint: Dictionary, id: String, discount: float) -> int:
	return maxi(1, int(round(float(blueprint.cost[id]) * discount)))


## 工程师·拆解回收：拆除建筑返还 40%/55%/70% 材料
func _salvage_refund(buildable: Node) -> void:
	var salvage := 0.4 + 0.15 * PlayerClass.skill_level("salvage")
	if salvage <= 0.0:
		return
	var t = buildable.get("type")
	var type := "wall" if t == null else str(t)
	var blueprint: Dictionary = BUILDABLE_SCRIPT.BLUEPRINTS.get(type, {})
	for id in blueprint.get("cost", {}):
		var refund := int(round(float(blueprint.cost[id]) * salvage))
		if refund > 0:
			Inventory.add_item(id, refund)


## 职业被动加成实时应用：强健(生命上限)/顽强(复活延迟)/巧手(建造范围)/鹰眼(视野)
func _apply_class_mods() -> void:
	var old_max := max_hp
	max_hp = 100 + 20 * PlayerClass.skill_level("vitality")
	if max_hp > old_max:
		hp = mini(max_hp, hp + (max_hp - old_max))  # 升级立即补上新增的上限
	else:
		hp = mini(hp, max_hp)
	respawn_delay = maxf(0.5, 3.0 - 0.5 * PlayerClass.skill_level("resilient"))
	build_range = 128.0 + 32.0 * PlayerClass.skill_level("long_arm")
	_update_light()
	health_changed.emit()


## 某点是否在玩家当前视野内（怪物索敌用））
## 黑暗群系（点光源开启）= 光照半径内；明亮地表 = 相机可视矩形内
## 注意：视野半径用稳定值计算，不受火把每帧微光闪烁影响，避免索敌边界抖动
func can_see_position(pos: Vector2) -> bool:
	if _light.energy > 0.0:
		return global_position.distance_to(pos) <= vision_radius
	var cam: Camera2D = $Camera2D
	var half := get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	var center := cam.get_screen_center_position()
	return Rect2(center - half, half * 2.0).has_point(pos)


## 玩家当前视野半径（px）：黑暗群系=光照半径，明亮地表=相机可视矩形半对角线
## 供刷怪上限等系统统计“玩家视野/光照范围内”的怪物数量
func get_vision_radius() -> float:
	if _light.energy > 0.0:
		return vision_radius
	var cam: Camera2D = $Camera2D
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
	return half.length()
