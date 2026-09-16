extends Area2D
## Bullet —— 玩家弹头。V1.2：按武器参数支持散射 / 穿透 / 追踪。
## 碰撞层：layer=4（玩家弹），mask=2（敌人）+8（实体障碍）。

var damage := 10
var pierce := false
var homing := false
var turn_rate := 4.5
var _dir := Vector2.RIGHT
var _speed := 620.0
var _life := 1.2
var _hit_list: Array = []
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 8
	monitoring = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 4.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	add_child(_sprite)
	body_entered.connect(_on_body_entered)


func setup(dir: Vector2, dmg: int, speed: float, life: float,
		color: Color, is_pierce: bool = false, is_homing: bool = false, turn: float = 4.5) -> void:
	_dir = dir.normalized()
	damage = dmg
	_speed = speed
	_life = life
	pierce = is_pierce
	homing = is_homing
	turn_rate = turn
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = PixelArt.bullet_tex()
	_sprite.modulate = color
	_sprite.rotation = _dir.angle()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	if homing:
		var target := _nearest_enemy()
		if target != null:
			var want := (target.global_position - global_position).normalized()
			var ang := _dir.angle_to(want)
			_dir = _dir.rotated(clampf(ang, -turn_rate * delta, turn_rate * delta))
			if _sprite != null:
				_sprite.rotation = _dir.angle()
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 999999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var d: float = en.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		if _hit_list.has(body):
			return
		_hit_list.append(body)
		body.take_damage(damage)
		var crit := damage >= 40
		EventBus.hit_enemy.emit(global_position, Color(1.0, 0.8, 0.4), damage, crit)
		if not pierce:
			queue_free()
	elif body.is_in_group("solid"):
		queue_free()
