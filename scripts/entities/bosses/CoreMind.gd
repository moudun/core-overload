extends CharacterBody2D
## Boss 3 —— 主脑本体 The Core Mind（区块 3，最终 Boss）。
## 阶段一（>66%）：旋转螺旋弹幕 + 每 5s 召唤 drone
## 阶段二（≤66%）：4 道旋转激光扫射（每 0.6s 结算一次线上伤害）+ 追踪弹
## 阶段三（≤33%）：狂暴 —— 弹幕密度 ×1.5 + 移动撞击

const HP := 600
const SPIRAL_GAP := 0.09
const LASER_TICK := 0.6

var hp := HP
var max_hp := HP
var _angle := 0.0
var _spiral_t := 0.0
var _summon_t := 5.0
var _laser_t := 0.0
var _charge_t := 6.0
var _charging := false
var _charge_dir := Vector2.RIGHT
var _flash := 0.0
var _view: IsoShim
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2
	collision_mask = 8
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 46.0
	shape.shape = circ
	add_child(shape)

	_view = IsoShim.follow_owner(self, 0, 46.0 * 0.84)
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.boss_tex(2)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -34.0)
	_view.add_child(_sprite)
	EventBus.boss_spawned.emit("THE CORE MIND", hp)


func _phase() -> int:
	var r := float(hp) / float(max_hp)
	if r <= 0.33:
		return 3
	if r <= 0.66:
		return 2
	return 1


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else Color.WHITE

	var ph := _phase()
	var p := get_tree().get_first_node_in_group("player")

	# 缓慢游走 / 狂暴冲撞
	if _charging:
		velocity = _charge_dir * 620.0
		_charge_t -= delta
		if _charge_t <= 0.0:
			_charging = false
			_charge_t = 6.0
	elif p != null:
		var pn: Node2D = p
		var d: Vector2 = pn.global_position - global_position
		velocity = d.normalized() * (70.0 if ph < 3 else 110.0)
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# 螺旋弹幕（阶段一 & 三）
	if ph != 2:
		_spiral_t -= delta
		if _spiral_t <= 0.0:
			_spiral_t = SPIRAL_GAP / (1.5 if ph == 3 else 1.0)
			_angle += 0.42
			var arms := 2 if ph == 1 else 3
			for i in arms:
				var ang := _angle + TAU * float(i) / float(arms)
				_spawn(Vector2.from_angle(ang), 10, 270.0, Color(0.5, 0.95, 1.0))

	# 旋转激光（阶段二 & 三）
	if ph >= 2:
		_laser_t -= delta
		if _laser_t <= 0.0:
			_laser_t = LASER_TICK
			_fire_lasers(4 if ph == 2 else 6)

	# 追踪弹（阶段三）
	if ph == 3 and p != null:
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = 2.2
			_spawn((p.global_position - global_position).normalized(), 14, 320.0, Color(1.0, 0.4, 0.9))
	elif ph == 1:
		_summon_t -= delta
		if _summon_t <= 0.0:
			_summon_t = 5.0
			_summon_drones()

	# 狂暴冲撞
	if ph == 3 and not _charging and p != null:
		if randf() < 0.004:
			_charging = true
			_charge_dir = (p.global_position - global_position).normalized()
			_charge_t = 0.7

	if p != null and global_position.distance_to(p.global_position) < 58.0 and p.has_method("take_hit"):
		p.take_hit(20)
	EventBus.boss_hp_changed.emit(hp, max_hp)


func _fire_lasers(count: int) -> void:
	for i in count:
		var ang := _angle * 0.6 + TAU * float(i) / float(count)
		var dir := Vector2.from_angle(ang)
		EventBus.beam_fired.emit(global_position, global_position + dir * 900.0, Color(1.0, 0.35, 0.3))
		var p := get_tree().get_first_node_in_group("player")
		if p == null:
			continue
		var pn: Node2D = p
		var to_p: Vector2 = pn.global_position - global_position
		var along: float = to_p.dot(dir)
		if along < 0.0 or along > 900.0:
			continue
		if (to_p - dir * along).length() < 24.0 and p.has_method("take_hit"):
			p.take_hit(16)


func _summon_drones() -> void:
	for i in 2:
		var e: Node = load("res://scripts/entities/Enemy.gd").new()
		get_parent().add_child(e)
		e.global_position = global_position + Vector2(randf_range(-110, 110), randf_range(-110, 110))
		e.setup(0, GameState.biome_index, false)


func _spawn(dir: Vector2, dmg: int, speed: float, color: Color) -> void:
	var b: Node = load("res://scripts/entities/EnemyBullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * 52.0
	b.setup(dir, dmg, speed, color)


func take_damage(v: int) -> void:
	hp -= v
	_flash = 0.08
	EventBus.boss_hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.add_kill()
	GameState.add_cells(EnemyDB.BOSSES[2]["cells"], true)
	GameState.add_gold(EnemyDB.BOSSES[2]["gold"])
	EventBus.enemy_killed.emit(global_position)
	EventBus.boss_died.emit()
	EventBus.run_victory.emit()
	queue_free()
