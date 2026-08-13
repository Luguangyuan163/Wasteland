extends Node2D
## 异常事件管理器：探索中随机触发低语 / 灯光闪烁 / 脚印 / 黑影掠过，营造中度恐怖氛围。
## 频率与场景黑暗程度挂钩：明亮地表 20~40 秒一次，黑暗群系/地心 8~20 秒一次。
## 事件全部是程序化占位表现（合成音效 + Polygon2D），P4 换建模时替换素材。
## 对应手册第 4 章"恐怖手段清单"：异常事件 = 灯光闪烁、低语声、脚印等环境事件。

const FOOTPRINT_LIFE := 8.0   # 脚印存在时间（秒）
const FOOTPRINT_COUNT := 5

var _cooldown := 0.0


func _ready() -> void:
	_schedule_next()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead or get_tree().paused:
		_schedule_next()
		return
	_trigger_random_event()
	_schedule_next()


## 按场景黑暗程度排下一次事件
func _schedule_next() -> void:
	_cooldown = randf_range(8.0, 20.0) if _is_dark_scene() else randf_range(20.0, 40.0)


func _is_dark_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	if scene.has_method("is_in_dark_zone"):
		var player = get_tree().get_first_node_in_group("player")
		if player == null:
			return false
		return scene.is_in_dark_zone(player.global_position)
	return true  # 地心世界等独立场景：全图黑暗


## 抽一个事件：黑暗场景更偏向"诡异"，明亮场景只有低语/脚印
func _trigger_random_event() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _is_dark_scene():
		var r := randf()
		if r < 0.35:
			_trigger("whisper")
		elif r < 0.60:
			_trigger("flicker")
		elif r < 0.85:
			_trigger("footprints")
		else:
			_trigger("shadow")
	elif randf() < 0.6:
		_trigger("whisper")
	else:
		_trigger("footprints")


## 公开触发入口（测试/调试用）
func trigger_event(type: String) -> void:
	_trigger(type)


func _trigger(type: String) -> void:
	match type:
		"whisper":
			AudioManager.play_sfx("anomaly_whisper")
		"flicker":
			_flicker_lights()
		"footprints":
			_spawn_footprints()
		"shadow":
			AudioManager.play_sfx("anomaly_shadow")
			_spawn_shadow()
		_:
			pass


## 灯光闪烁：玩家的点光源短暂变暗再恢复（地心/暗域里特别明显）
func _flicker_lights() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var light: PointLight2D = player.get_node_or_null("PointLight2D")
	if light == null:
		return
	AudioManager.play_sfx("anomaly_flicker")
	var original := light.energy
	light.energy = original * 0.25
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.tween_property(light, "energy", original * 0.7, 0.10)
	tween.tween_interval(0.12)
	tween.tween_property(light, "energy", original, 0.25)


## 脚印：玩家附近生成一小串暗色脚印，几秒后淡出（"有什么东西来过"）
func _spawn_footprints() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	AudioManager.play_sfx("anomaly_whisper")
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var origin: Vector2 = player.global_position + dir * randf_range(140.0, 220.0)
	var footprints := Node2D.new()
	footprints.name = "AnomalyFootprints"
	get_parent().add_child(footprints)
	for i in FOOTPRINT_COUNT:
		var mark := Polygon2D.new()
		var w := 9.0
		mark.polygon = PackedVector2Array([Vector2(-w, -w * 0.6), Vector2(w, -w * 0.6), Vector2(w * 0.6, w * 0.8), Vector2(-w * 0.6, w * 0.8)])
		mark.color = Color(0.06, 0.05, 0.07, 0.5)
		mark.position = Vector2(i * 16.0, sin(i * 1.7) * 6.0)
		mark.rotation = randf_range(-0.4, 0.4)
		footprints.add_child(mark)
	footprints.global_position = origin
	footprints.add_to_group("anomaly_footprints")
	var tween := create_tween()
	tween.tween_interval(FOOTPRINT_LIFE)
	tween.tween_property(footprints, "modulate:a", 0.0, 1.0)
	tween.tween_callback(footprints.queue_free)


## 黑影掠过：一块暗色影子快速扫过玩家附近，伴随低沉风声
func _spawn_shadow() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var shadow := Polygon2D.new()
	var w := 90.0
	shadow.polygon = PackedVector2Array([Vector2(-w, -w * 0.55), Vector2(w, -w * 0.55), Vector2(w, w * 0.55), Vector2(-w, w * 0.55)])
	shadow.color = Color(0.03, 0.02, 0.04, 0.0)
	shadow.z_index = 5
	var side := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	var offset := Vector2(-side.y, side.x)
	shadow.global_position = player.global_position + side * 220.0
	get_parent().add_child(shadow)
	shadow.add_to_group("anomaly_shadows")
	var tween := create_tween()
	tween.tween_property(shadow, "color:a", 0.45, 0.25)
	tween.tween_property(shadow, "global_position", player.global_position + side * 620.0 + offset * 80.0, 0.5)
	tween.tween_property(shadow, "color:a", 0.0, 0.3)
	tween.tween_callback(shadow.queue_free)
