extends CharacterBody2D
## Boss 2 —— 墓场之主 Gravekeeper（区块 2）。
## 循环：瞬移（淡出 0.5s）→ 3 连扇形弹幕（间隔 0.4s）→ 召唤 2 座 spitter
## ≤40% HP 时瞬移与弹幕频率 ×1.5

const HP := 420
const VANISH := 0.5
const VOLLEY_GAP := 0.4

var hp := HP
var max_hp := HP
var _state := "vanish"
var _t := VANISH
var _volley := 0
var _flash := 0.0
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 34.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.boss_tex(1)
	add_child(_sprite)
	EventBus.boss_spawned.emit("GRAVEKEEPER", hp)


func _rate() -> float:
	return 1.5 if float(hp) <= float(max_hp) * 0.4 else 1.0


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE
	_t -= delta * _rate()

	match _state:
		"vanish":
			_sprite.modulate.a = 0.25
			collision_mask = 0
			if _t <= 0.0:
				_teleport()
				_sprite.modulate.a = 1.0
				collision_mask = 8
				_state = "volley"
				_t = VOLLEY_GAP
				_volley = 0
		"volley":
			velocity = Vector2.ZERO
			if _t <= 0.0:
				_fire_fan()
				_volley += 1
				_t = VOLLEY_GAP
				if _volley >= 3:
					_state = "summon"
					_t = 0.5
		"summon":
			if _t <= 0.0:
				_summon_spitters()
				_state = "vanish"
				_t = VANISH

	var p := get_tree().get_first_node_in_group("player")
	if p != null and _state != "vanish":
		if global_position.distance_to(p.global_position) < 46.0 and p.has_method("take_hit"):
			p.take_hit(18)
	EventBus.boss_hp_changed.emit(hp, max_hp)


func _teleport() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var base: Vector2 = Vector2(640, 360)
	if p != null:
		base = (p as Node2D).global_position
	for _i in 12:
		var cand: Vector2 = base + Vector2(randf_range(-420, 420), randf_range(-260, 260))
		if cand.x > 90 and cand.x < 1190 and cand.y > 120 and cand.y < 640:
			global_position = cand
			return
	global_position = base + Vector2(0, -260)


func _fire_fan() -> void:
	var p := get_tree().get_first_node_in_group("player")
	var base_ang: float = 0.0
	if p != null:
		base_ang = ((p as Node2D).global_position - global_position).angle()
	for i in 5:
		var ang: float = base_ang + (float(i) - 2.0) * 0.18
		_spawn(Vector2.from_angle(ang), 12, 300.0, Color(1.0, 0.55, 0.35))


func _summon_spitters() -> void:
	for i in 2:
		var e: Node = load("res://scripts/entities/Enemy.gd").new()
		get_parent().add_child(e)
		e.global_position = global_position + Vector2(randf_range(-120, 120), randf_range(-90, 90))
		e.setup(3, GameState.biome_index, false)


func _spawn(dir: Vector2, dmg: int, speed: float, color: Color) -> void:
	var b: Node = load("res://scripts/entities/EnemyBullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * 40.0
	b.setup(dir, dmg, speed, color)


func take_damage(v: int) -> void:
	hp -= v
	_flash = 0.08
	EventBus.boss_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.add_kill()
	GameState.add_cells(EnemyDB.BOSSES[1]["cells"])
	GameState.add_gold(EnemyDB.BOSSES[1]["gold"])
	EventBus.enemy_killed.emit(global_position)
	EventBus.boss_died.emit()
	queue_free()
