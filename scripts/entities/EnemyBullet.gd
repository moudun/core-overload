extends Area2D
## EnemyBullet —— V1.3 敌方弹丸（spitter / Boss 弹幕 / 故障体）。
## 可被翻滚无敌帧穿过：命中时调用玩家 take_hit，由玩家内部判定无敌。
## 标记 is_hazard 的弹丸不吃「反射镜」以外的反弹。
## 碰撞层：layer=16，mask=1（玩家）+8（实体）。

var damage := 10
var _dir := Vector2.RIGHT
var _speed := 240.0
var _life := 6.0
var _view: IsoShim
var _sprite: Sprite2D
var _pingpong := 0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 8
	monitoring = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 5.0
	shape.shape = circ
	add_child(shape)

	_view = IsoShim.follow_owner(self, 1, 4.0)
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.circle_tex(14, Color(1.0, 0.85, 0.35), Color(0.85, 0.35, 0.1), Color(0.35, 0.1, 0.03))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -4.0)
	_view.add_child(_sprite)
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
		# 反射镜房间：玩家弹会反弹，敌方弹也会被弹开一次（增加变数）
		if GameState.has_modifier("reflective") and _pingpong < 1:
			_pingpong += 1
			_dir = -_dir
			return
		queue_free()
