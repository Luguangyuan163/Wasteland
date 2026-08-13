extends SceneTree
## 脱困机制验证：把玩家丢到出生点（空地），强制触发 _try_unstuck，
## 确认能正常执行并落到可通行格子上（不在石头上）

var _frames := 0
var _world: Node = null


func _initialize() -> void:
	_world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		var player: Node2D = _world.get_node("Player")
		var ground := _world.get_node("Ground") as TileMapLayer
		var spawn: Vector2i = _world.SPAWN_CELL
		player.global_position = Vector2(spawn.x * 32 + 16, spawn.y * 32 + 16)
		player._blocked_time = 99.0
		player._try_unstuck()
		var cell := Vector2i(floori(player.global_position.x / 32.0), floori(player.global_position.y / 32.0))
		var atlas: Vector2i = ground.get_cell_atlas_coords(cell)
		print("[UNSTUCK] new pos=", player.global_position, " cell=", cell, " tile=", atlas)
		if atlas == Vector2i(0, 1):
			print("[UNSTUCK] FAIL: 转移到了石头上")
			quit(1)
			return true
		print("[UNSTUCK] OK")
		quit(0)
		return true
	return false
