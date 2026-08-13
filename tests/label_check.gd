extends SceneTree
## 验证敌人名字标签防重叠：同簇多只应全部可见且垂直错位

var _frames := 0
var _world: Node = null


func _initialize() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		# 把玩家传送到暗域巢穴南侧，让守卫在攻击距离上散开
		var player: Node2D = _world.get_node("Player")
		player.global_position = Vector2(150, 116) * 32.0
		# 在玩家旁边撒一簇 4 只怪（模拟探索刷怪的密集集群）
		var offsets := [Vector2(0, 40), Vector2(30, 10), Vector2(-25, 25), Vector2(15, -30)]
		var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
		for i in 4:
			var e: Node2D = enemy_scene.instantiate()
			e.enemy_type = "husk"
			e.global_position = player.global_position + offsets[i]
			_world.add_child(e)
		return false
	if _frames != 10:
		return false
	# 找玩家附近的守卫：它们天然聚成一簇
	var player_pos: Vector2 = _world.get_node("Player").global_position
	var near: Array = []
	for e in get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player_pos) < 300.0:
			near.append(e)
	var y_set := {}
	var all_visible := true
	for e in near:
		var label: Label = e.get_node("NameLabel")
		all_visible = all_visible and label.visible
		y_set[label.position.y] = true
		print("[LABEL] %s 位置=%s 标签偏移y=%.1f" % [e.enemy_type, str(e.global_position), label.position.y])
	print("[LABEL] 簇内敌人=%d 全部显示名字=%s 垂直错位档数=%d" % [near.size(), str(all_visible), y_set.size()])
	quit(0)
	return true
