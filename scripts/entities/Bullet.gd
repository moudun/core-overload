extends Area2D
## Bullet —— 玩家弹头：直线飞行，命中敌人造成伤害后销毁。

const SPEED := 600.0
const LIFE := 1.4

var _dir := Vector2.RIGHT
var damage := 10
var _life := LIFE
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2  # 只撞敌人
	monitoring = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 3.5
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.bullet_tex()
	add_child(_sprite)
	_sprite.rotation = _dir.angle() if _dir != Vector2.ZERO else 0.0
	body_entered.connect(_on_body_entered)


func setup(dir: Vector2, dmg: int) -> void:
	_dir = dir
	damage = dmg
	if is_inside_tree() and _sprite != null:
		_sprite.rotation = _dir.angle()
	_sprite.rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	global_position += _dir * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		body.take_damage(damage)
		EventBus.hit_enemy.emit(global_position, Color(1.0, 0.8, 0.4))
		queue_free()
	elif body.is_in_group("solid_wall"):
		queue_free()
