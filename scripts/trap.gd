extends Area2D
## 尖刺陷阱：玩家踩上去掉血（地心世界的威胁）

@export var damage := 5
@export var cooldown := 1.0

var _cd := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func _on_body_entered(body: Node) -> void:
	if _cd > 0.0:
		return
	if body is CharacterBody2D and body.has_method("take_damage"):
		_cd = cooldown
		body.take_damage(damage)
