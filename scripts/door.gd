extends StaticBody2D
## 门：压力板踩下后打开（v1 为永久打开，避免玩家被关在房间里）

var is_open := false


func set_open(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	AudioManager.play_sfx("door_open")
	$CollisionShape2D.set_deferred("disabled", open)
	$Visual.modulate.a = 0.25 if open else 1.0  # 打开时半透明，还能看到门的位置
