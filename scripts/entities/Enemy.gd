extends CharacterBody2D
## Enemy —— V1.3 入侵者（含护盾与状态系统）。
## kind: 0 drone / 1 brute / 2 runner / 3 spitter / 4 glitch
## 状态：burn 燃烧 / freeze 冻结 / shock 感电 / mark 标记
## 碰撞：layer=2，mask=8（障碍）。

class_name Enemy

const STATUS_BURN := "burn"
const STATUS_FREEZE := "freeze"
const STATUS_SHOCK := "shock"
const STATUS_MARK := "mark"

var kind := 0
var elite := false
var hp := 1
var max_hp := 1
var shield := 0
var max_shield := 0
var dmg := 10
var radius := 10.0
var ranged := false
var fire_cd := 0.0
var _fire_t := 0.0
var _bullet_speed := 240.0
var _keep_min := 260.0
var _keep_max := 420.0
var _flash := 0.0
var _view: IsoShim
var _sprite: Sprite2D
var _shield_ring: Line2D
var jitter := false
var _jitter_t := 0.0
var _jitter := Vector2.ZERO

## 浮动相位：让敌人有自己的呼吸/悬浮节奏，别像一张定格贴图
var _anim_t := 0.0
var _base_lift := 0.0

## 状态表：{status_id: {"t": 剩余时间, "power": 强度}}
var statuses: Dictionary = {}
var _burn_tick := 0.0
var _dead := false


func setup(k: int, biome: int, is_elite: bool = false) -> void:
	kind = k
	elite = is_elite
	var st: Dictionary = EnemyDB.stats(
		k, biome, is_elite,
		GameState.enemy_shield_bonus(),
		GameState.enemy_hp_mult() + float(GameState.challenge_agg().get("enemy_hp", 0.0)),
		GameState.enemy_count_mult(),
		GameState.enemy_dmg_mult(),
		GameState.enemy_speed_mult()
	)
	hp = int(st["hp"])
	max_hp = hp
	shield = int(st["shield"])
	max_shield = shield
	dmg = int(st["dmg"])
	radius = float(st["radius"])
	ranged = bool(st["ranged"])
	jitter = bool(st.get("jitter", false))
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

	# 等距投影载体：可见部分挂它下面，碰撞体仍留在本体（逻辑坐标）
	_view = IsoShim.follow_owner(self, 0, radius * 0.84)

	_sprite = Sprite2D.new()
	_view.add_child(_sprite)

	_shield_ring = Line2D.new()
	_shield_ring.width = 2.0
	_shield_ring.default_color = Color(0.55, 0.75, 1.0, 0.85)
	_shield_ring.closed = true
	_shield_ring.z_index = 7
	_shield_ring.visible = false
	_view.add_child(_shield_ring)
	_rebuild_shield_ring()

	_update_visual()


## 护盾环本来是逻辑半径的圆，等距下必须画成 2:1 椭圆
func _rebuild_shield_ring() -> void:
	if _shield_ring == null:
		return
	var r := (radius + 6.0) * Iso.SCALE
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Iso.dir_to_screen(Vector2(cos(a), sin(a))) * r)
	_shield_ring.points = pts


func _update_visual() -> void:
	if _sprite == null:
		return
	_sprite.texture = PixelArt.enemy_tex(kind)
	# 敌人贴图统一 40×40，按碰撞半径缩放到合适大小（原来是 22 基准，现在按 30 算，
	# 加上贴图本身留了边距，最终视觉尺寸和以前接近但外形完全不同了）
	var base_tex := 30.0
	var s := radius * 2.0 / base_tex * (1.4 if elite else 1.0)
	_sprite.scale = Vector2(s, s)
	# 抬到落影之上，看起来才像「悬在地面上」的一个单位，而不是一张贴在地上的贴纸
	_base_lift = radius * 0.9
	_sprite.position = Vector2(0.0, -_base_lift)
	if _view != null and is_instance_valid(_view):
		_view.set_footprint(radius * 1.05)
	# 每种敌人给一个不同的浮动频率，一群敌人不会整齐划一地一起上下
	_anim_t = randf() * TAU
	_rebuild_shield_ring()
	_apply_tint()


func _apply_tint() -> void:
	if _sprite == null:
		return
	if _flash > 0.0:
		_sprite.modulate = Color(3.0, 3.0, 3.0)
		return
	var col := Color(1.0, 0.75, 1.0) if elite else Color.WHITE
	if has_status(STATUS_FREEZE):
		col = col.lerp(Color(0.55, 0.85, 1.0), 0.65)
	elif has_status(STATUS_BURN):
		col = col.lerp(Color(1.0, 0.55, 0.25), 0.45)
	elif has_status(STATUS_SHOCK):
		col = col.lerp(Color(0.75, 0.65, 1.0), 0.45)
	elif has_status(STATUS_MARK):
		col = col.lerp(Color(1.0, 0.45, 0.85), 0.35)
	_sprite.modulate = col
	if _shield_ring != null:
		_shield_ring.visible = shield > 0


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not GameState.active:
		return
	_flash = maxf(0.0, _flash - delta)
	_tick_status(delta)
	_tick_anim(delta)

	var target: Node2D = get_tree().get_first_node_in_group("player")
	if target == null:
		return
	var delta_v: Vector2 = target.global_position - global_position
	var dist := delta_v.length()
	var speed := speed_value()
	if has_status(STATUS_FREEZE):
		speed *= 0.30

	if jitter:
		_jitter_t -= delta
		if _jitter_t <= 0.0:
			_jitter_t = randf_range(0.25, 0.6)
			_jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 90.0

	if ranged:
		if dist < _keep_min:
			velocity = -delta_v.normalized() * speed * 0.8
		elif dist > _keep_max:
			velocity = delta_v.normalized() * speed
		else:
			velocity = Vector2.ZERO
		_fire_t -= delta
		if _fire_t <= 0.0 and fire_cd > 0.0 and not has_status(STATUS_FREEZE):
			_fire_t = fire_cd
			_shoot(delta_v.normalized())
	else:
		velocity = delta_v.normalized() * speed if dist > 0.001 else Vector2.ZERO
	if jitter:
		velocity += _jitter
	move_and_slide()
	_apply_tint()

	# 近战接触伤害（远程单位不自爆）
	if not ranged:
		var p: Node2D = get_tree().get_first_node_in_group("player")
		if p != null:
			var d2: Vector2 = p.global_position - global_position
			var r_sum: float = get_radius() + (p.get_radius() if p.has_method("get_radius") else 13.0)
			if d2.length() < r_sum:
				if p.has_method("take_hit"):
					p.take_hit(dmg)
				_die(false)


func speed_value() -> float:
	var st: Dictionary = EnemyDB.stats(kind, GameState.biome_index, elite)
	return float(st["speed"])


## 待机浮动：上下轻微起伏 + 极轻微的横向摆动，让敌人「活着」。
## 不同 kind 用不同频率/幅度：drone 悬浮感强，brute 几乎不动，runner 有冲刺前倾感。
func _tick_anim(delta: float) -> void:
	if _sprite == null:
		return
	var spd := 2.2
	var amp := 1.6
	match kind:
		1:  # brute：重，几乎不浮
			spd = 1.2
			amp = 0.8
		2:  # runner：快而急促
			spd = 5.4
			amp = 2.2
		3:  # spitter：炮台式的缓慢稳定
			spd = 1.6
			amp = 1.1
		4:  # glitch：高频抖动
			spd = 7.5
			amp = 2.6
	_anim_t += delta * spd
	var bob := sin(_anim_t) * amp
	var sway := cos(_anim_t * 0.5) * (amp * 0.25 if kind != 1 else 0.0)
	_sprite.position = Vector2(sway, -_base_lift + bob)


# ---------------- 状态 ----------------
func has_status(id: String) -> bool:
	return statuses.has(id)


func apply_status(id: String, duration: float, power: float = 1.0) -> void:
	if duration <= 0.0:
		return
	var cur: Dictionary = statuses.get(id, {"t": 0.0, "power": power})
	cur["t"] = maxf(float(cur["t"]), duration)
	cur["power"] = maxf(float(cur["power"]), power)
	statuses[id] = cur
	if id == STATUS_FREEZE and shield > 0:
		break_shield()          # 冰结直接击碎护盾
	if id == STATUS_SHOCK and shield > 0:
		break_shield()


func break_shield() -> void:
	if shield <= 0:
		return
	shield = 0
	EventBus.hit_enemy.emit(global_position, Color(0.6, 0.85, 1.0), 0, false)
	if _shield_ring != null:
		_shield_ring.visible = false


func _tick_status(delta: float) -> void:
	if statuses.is_empty():
		return
	var keys := statuses.keys()
	for k in keys:
		var s: Dictionary = statuses[k]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			statuses.erase(k)
	# 燃烧 DoT
	if has_status(STATUS_BURN):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			var dot := maxi(1, int(round(float(max_hp) * 0.05)))
			take_damage(dot, false)


# ---------------- 受伤 ----------------
func take_damage(v: int, show_fx: bool = true) -> void:
	if _dead:
		return
	var dmg_in := float(v)
	dmg_in *= damage_taken_mult()
	if shield > 0:
		var absorbed := mini(shield, int(round(dmg_in)))
		shield -= absorbed
		dmg_in -= float(absorbed)
		if shield <= 0 and _shield_ring != null:
			_shield_ring.visible = false
		if show_fx:
			EventBus.hit_enemy.emit(global_position, Color(0.55, 0.80, 1.0), absorbed, false)
		if dmg_in <= 0.0:
			_flash = 0.06
			return
	hp -= int(round(dmg_in))
	_flash = 0.09
	if show_fx:
		EventBus.hit_enemy.emit(global_position, tint_color(), int(round(dmg_in)), dmg_in >= 40.0)
	if hp <= 0:
		_on_death()


func damage_taken_mult() -> float:
	var m := 1.0
	if has_status(STATUS_FREEZE):
		m += 0.30
		m += GameState.tag_frozen_damage_bonus()
	if has_status(STATUS_MARK):
		m += 0.25
	if has_status(STATUS_SHOCK):
		m += 0.15
	return m


func tint_color() -> Color:
	if has_status(STATUS_FREEZE):
		return Color(0.55, 0.9, 1.0)
	if has_status(STATUS_BURN):
		return Color(1.0, 0.6, 0.3)
	if has_status(STATUS_SHOCK):
		return Color(0.8, 0.7, 1.0)
	return Color(1.0, 0.8, 0.4)


func _on_death() -> void:
	GameState.add_kill(global_position, elite)
	if elite:
		GameState.add_cells(3 + randi() % 3)
		GameState.add_gold(8 + randi() % 8)
	else:
		GameState.add_gold(1 + randi() % 3)
	# 冰结 6 层：冻结目标死亡爆裂
	if has_status(STATUS_FREEZE) and GameState.tag_tier(Tags.CRYO) >= 3:
		_freeze_burst()
	elif GameState.has_card("ice") and has_status(STATUS_FREEZE):
		_freeze_burst()
	# 链式反应协议
	if GameState.has_protocol("chain"):
		var chance := GameState.protocol_value("chain")
		if randf() < chance:
			_kill_explosion()
	EventBus.enemy_killed.emit(global_position)
	_dead = true
	queue_free()


func _die(count_kill: bool) -> void:
	if _dead:
		return
	if count_kill:
		GameState.add_kill(global_position, elite)
	EventBus.enemy_killed.emit(global_position)
	_dead = true
	queue_free()


func _freeze_burst() -> void:
	var amount := maxi(6, int(round(float(max_hp) * 0.6)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self:
			continue
		var en: Enemy = e
		if en.global_position.distance_to(global_position) < 110.0:
			en.take_damage(amount)
	EventBus.hit_enemy.emit(global_position, Color(0.6, 0.95, 1.0), amount, true)


func _kill_explosion() -> void:
	var amount := maxi(8, int(round(float(max_hp) * 0.9)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self:
			continue
		var en: Enemy = e
		if en.global_position.distance_to(global_position) < 120.0:
			en.take_damage(amount)
	EventBus.hit_enemy.emit(global_position, Color(0.75, 0.6, 1.0), amount, true)


func _shoot(dir: Vector2) -> void:
	var b: Node = load("res://scripts/entities/EnemyBullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (radius + 8.0)
	b.setup(dir, dmg, _bullet_speed)
	EventBus.enemy_shot.emit(b.global_position, dir)


func get_radius() -> float:
	return radius


func is_alive() -> bool:
	return not _dead and hp > 0
