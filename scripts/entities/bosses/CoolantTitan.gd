extends CharacterBody2D
## Boss 1 —— 冷却巨兽 Coolant Titan（区块 1）。
## 阶段一：蓄力冲撞（0.8s 预警）→ 高速冲刺 → 撞墙眩晕 1.5s（输出窗口）
## 阶段二（≤50% HP）：冲撞后追加 12 向放射水弹 + 召唤 3 只 runner

const HP := 260
const DASH_SPEED := 780.0
const DASH_TIME := 0.65
const TELEGRAPH := 0.80
const STUN_TIME := 1.5

var hp := HP
var max_hp := HP
var stunned := false
var _state := "idle"
var _t := 0.0
var _dir := Vector2.RIGHT
var _flash := 0.0
var _sprite: Sprite2D
var _line: Line2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 38.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.boss_tex(0)
	add_child(_sprite)

	_line = Line2D.new()
	_line.width = 6.0
	_line.default_color = Color(1.0, 0.3, 0.25, 0.6)
	_line.z_index = -1
	add_child(_line)

	_t = 1.2
	EventBus.boss_spawned.emit("COOLANT TITAN", hp)


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE

	_t -= delta
	var p := get_tree().get_first_node_in_group("player")

	match _state:
		"idle":
			_line.clear_points()
			if p != null:
				velocity = (p.global_position - global_position).normalized() * 55.0
			else:
				velocity = Vector2.ZERO
			move_and_slide()
			if _t <= 0.0:
				_state = "telegraph"
				_t = TELEGRAPH
				if p != null:
					_dir = (p.global_position - global_position).normalized()
		"telegraph":
			velocity = Vector2.ZERO
			_line.clear_points()
			_line.add_point(Vector2.ZERO)
			_line.add_point(_dir * 900.0)
			if _t <= 0.0:
				_line.clear_points()
				_state = "dash"
				_t = DASH_TIME
		"dash":
			velocity = _dir * DASH_SPEED
			move_and_slide()
			if p != null and global_position.distance_to(p.global_position) < 52.0 and p.has_method("take_hit"):
				p.take_hit(22)
			if _t <= 0.0 or get_slide_collision_count() > 0:
				_after_dash()
		"stun":
			velocity = Vector2.ZERO
			_sprite.modulate = Color(0.55, 0.75, 1.0)
			if _t <= 0.0:
				_sprite.modulate = Color.WHITE
				stunned = false
				_state = "idle"
				_t = 0.9
	EventBus.boss_hp_changed.emit(hp, max_hp)


func _after_dash() -> void:
	stunned = true
	_state = "stun"
	_t = STUN_TIME
	if float(hp) <= float(max_hp) * 0.5:
		_radial_burst()
		_summon_runners()


func _radial_burst() -> void:
	for i in 12:
		var ang := TAU * float(i) / 12.0
		_spawn_bullet(Vector2.from_angle(ang), 12, 260.0, Color(0.4, 0.85, 1.0))


func _summon_runners() -> void:
	for i in 3:
		var e: Node = load("res://scripts/entities/Enemy.gd").new()
		get_parent().add_child(e)
		e.global_position = global_position + Vector2(randf_range(-70, 70), randf_range(-70, 70))
		e.setup(2, GameState.biome_index, false)


func _spawn_bullet(dir: Vector2, dmg: int, speed: float, color: Color) -> void:
	var b: Node = load("res://scripts/entities/EnemyBullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * 44.0
	b.setup(dir, dmg, speed, color)


func take_damage(v: int) -> void:
	hp -= v
	_flash = 0.08
	if stunned:
		hp -= int(v * 0.5)  # 眩晕窗口额外承伤
	EventBus.boss_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.add_kill()
	GameState.add_cells(EnemyDB.BOSSES[0]["cells"])
	GameState.add_gold(EnemyDB.BOSSES[0]["gold"])
	EventBus.enemy_killed.emit(global_position)
	EventBus.boss_died.emit()
	queue_free()
