extends Area2D
## EnemyBullet —— 敌方弹丸（spitter / Boss 弹幕）。
## 可被翻滚无敌帧穿过：命中时调用玩家 take_hit，由玩家内部判定无敌。
## 碰撞层：layer=16，mask=1（玩家）+8（实体）。

var damage := 10
var _dir := Vector2.RIGHT
var _speed := 240.0
var _life := 5.0
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 8
	monitoring = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 5.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.circle_tex(14, Color(1.0, 0.85, 0.35), Color(0.85, 0.35, 0.1), Color(0.35, 0.1, 0.03))
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func setup(dir: Vector2, dmg: int, speed: float, color: Color = Color(1.0, 0.8, 0.3)) -> void:
	_dir = dir.normalized()
	damage = dmg
	_speed = speed
	if _sprite != null:
		_sprite.modulate = color


func _physics_process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_hit"):
		body.take_hit(damage)
		queue_free()
	elif body.is_in_group("solid"):
		queue_free()
