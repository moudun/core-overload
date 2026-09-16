extends CharacterBody2D
## Enemy —— V1.2 入侵者。
## kind: 0 drone(追踪自爆) / 1 brute(慢速高伤) / 2 runner(高速) / 3 spitter(远程)
## elite: 精英变体（体型更大、掉细胞）。数值由 EnemyDB 按区块缩放。
## 碰撞：layer=2，mask=8（障碍）。

class_name Enemy

var kind := 0
var elite := false
var hp := 1
var dmg := 10
var radius := 10.0
var ranged := false
var fire_cd := 0.0
var _fire_t := 0.0
var _bullet_speed := 240.0
var _keep_min := 260.0
var _keep_max := 420.0
var _flash := 0.0
var _sprite: Sprite2D


func setup(k: int, biome: int, is_elite: bool = false) -> void:
	kind = k
	elite = is_elite
	var st: Dictionary = EnemyDB.stats(k, biome, is_elite)
	hp = int(st["hp"])
	dmg = int(st["dmg"])
	radius = float(st["radius"])
	ranged = bool(st["ranged"])
	fire_cd = float(st["fire_cd"])
	_bullet_speed = float(st["bullet_speed"])
	_keep_min = float(st["keep_min"])
	_keep_max = float(st["keep_max"])
	_fire_t = randf() * fire_cd if fire_cd > 0.0 else 0.0
	_update_visual()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 8

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = radius
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	add_child(_sprite)
	_update_visual()


func _update_visual() -> void:
	if _sprite == null:
		return
	_sprite.texture = PixelArt.enemy_tex(kind)
	var base_tex := 22.0
	var s := radius * 2.0 / base_tex * (1.4 if elite else 1.0)
	_sprite.scale = Vector2(s, s)
	if elite:
		_sprite.modulate = Color(1.0, 0.75, 1.0)


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	var target: Node2D = get_tree().get_first_node_in_group("player")
	if target == null:
		return
	var delta_v: Vector2 = target.global_position - global_position
	var dist := delta_v.length()

	if ranged:
		# 远程：保持距离并射击
		if dist < _keep_min:
			velocity = -delta_v.normalized() * speed_value() * 0.8
		elif dist > _keep_max:
			velocity = delta_v.normalized() * speed_value()
		else:
			velocity = Vector2.ZERO
		_fire_t -= delta
		if _fire_t <= 0.0 and fire_cd > 0.0:
			_fire_t = fire_cd
			_shoot(delta_v.normalized())
	else:
		velocity = delta_v.normalized() * speed_value() if dist > 0.001 else Vector2.ZERO
	move_and_slide()

	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(3.0, 3.0, 3.0) if _flash > 0.0 else Color.WHITE
	elif _sprite != null:
		_sprite.modulate = Color(1.0, 0.75, 1.0) if elite else Color.WHITE

	# 近战接触伤害（远程单位不自爆）
	if not ranged:
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p != null:
			var d2: Vector2 = p.global_position - global_position
			var r_sum: float = get_radius() + (p.get_radius() if p.has_method("get_radius") else 13.0)
			if d2.length() < r_sum:
				if p.has_method("take_hit"):
					p.take_hit(dmg)
				queue_free()


func speed_value() -> float:
	var st: Dictionary = EnemyDB.stats(kind, GameState.biome_index, elite)
	return float(st["speed"])


func _shoot(dir: Vector2) -> void:
	var b: Node = load("res://scripts/entities/EnemyBullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (radius + 8.0)
	b.setup(dir, dmg, _bullet_speed)
	EventBus.enemy_shot.emit(b.global_position, dir)


func get_radius() -> float:
	return radius


func take_damage(v: int) -> void:
	hp -= v
	_flash = 0.09
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.add_kill()
	if elite:
		GameState.add_cells(3 + randi() % 3)
		GameState.add_gold(8 + randi() % 8)
	else:
		GameState.add_gold(1 + randi() % 3)
	EventBus.enemy_killed.emit(global_position)
	queue_free()
