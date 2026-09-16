extends CharacterBody2D
## CorePlayer —— V1.2 玩家核心。
## 能力：WASD 移动 / 鼠标瞄准射击（双武器槽）/ 翻滚无敌帧 / 治疗瓶 / 暴击。
## 碰撞：layer=1（玩家），mask=8（实体障碍与锁门）。

const RADIUS := 13.0
const BASE_SPEED := 320.0
const ROLL_SPEED := 820.0
const ROLL_TIME := 0.22
const ROLL_IFRAME := 0.26
const ROLL_CD := 0.80
const SWAP_CD := 0.30

var speed := BASE_SPEED
var _cd := 0.0
var _look := Vector2.RIGHT
var _move_dir := Vector2.ZERO
var _sprite: Sprite2D
var _t := 0.0

# 翻滚
var _roll_t := 0.0
var _iframe_t := 0.0
var _roll_cd_t := 0.0
var _roll_dir := Vector2.RIGHT
var _afterimage_t := 0.0

# 武器
var _swap_cd := 0.0
var _phase_buff := 0.0      # 相位协议：翻滚后增伤计时
var _orbiters: Array = []
var _orbit_dmg_t := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 8

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = RADIUS
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.player_core_tex()
	_sprite.z_index = 5
	add_child(_sprite)

	GameState.reset_run()


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	_cd = maxf(0.0, _cd - delta)
	_swap_cd = maxf(0.0, _swap_cd - delta)
	_roll_cd_t = maxf(0.0, _roll_cd_t - delta)
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_phase_buff = maxf(0.0, _phase_buff - delta)

	# 输入方向
	_move_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		_move_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		_move_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		_move_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		_move_dir.y += 1.0
	if _move_dir != Vector2.ZERO:
		_move_dir = _move_dir.normalized()

	# 翻滚位移优先
	if _roll_t > 0.0:
		_roll_t -= delta
		velocity = _roll_dir * ROLL_SPEED
		_spawn_afterimage(delta)
		if _roll_t <= 0.0:
			_phase_buff = 1.0 if GameState.has_protocol("phase") else 0.0
	else:
		velocity = _move_dir * speed * GameState.move_mult()
	move_and_slide()

	# 朝向
	var mouse := get_global_mouse_position()
	var to_mouse := mouse - global_position
	if to_mouse.length() > 1.0:
		_look = to_mouse.normalized()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _roll_t <= 0.0:
		_try_shoot()

	_update_orbiters(delta)


func _process(delta: float) -> void:
	_t += delta
	if _sprite != null:
		var p := 1.0 + 0.06 * sin(_t * 5.0)
		_sprite.scale = Vector2(p, p)
		if _iframe_t > 0.0:
			_sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
		else:
			_sprite.modulate = Color.WHITE


# ---------------- 翻滚 ----------------
func try_roll() -> void:
	if not GameState.active:
		return
	if _roll_cd_t > 0.0 or _roll_t > 0.0:
		return
	_roll_dir = _move_dir if _move_dir != Vector2.ZERO else _look
	_roll_t = ROLL_TIME
	_iframe_t = ROLL_IFRAME
	_roll_cd_t = ROLL_CD * GameState.roll_cd_mult()
	EventBus.roll_started.emit()


func roll_cd_ratio() -> float:
	## 0 = 就绪，1 = 刚用完（用于 HUD 环形指示）
	if _roll_cd_t <= 0.0:
		return 0.0
	return clampf(_roll_cd_t / (ROLL_CD * maxf(0.1, GameState.roll_cd_mult())), 0.0, 1.0)


func is_invulnerable() -> bool:
	return _iframe_t > 0.0


func _spawn_afterimage(_delta: float) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = PixelArt.player_core_tex()
	ghost.global_position = global_position
	ghost.modulate = Color(0.5, 1.0, 0.9, 0.35)
	ghost.z_index = 4
	get_parent().add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


# ---------------- 射击 ----------------
func _try_shoot() -> void:
	if _cd > 0.0:
		return
	var wid := GameState.current_weapon()
	var w: Dictionary = WeaponDB.info(wid)
	var cd: float = float(w.get("cd", 0.2)) * GameState.cooldown_mult()
	if cd <= 0.0:
		cd = 0.05
	_cd = cd

	var kind := str(w.get("kind", "DIRECT"))
	var dmg := int(round(float(w.get("dmg", 10)) * GameState.firepower_mult() * _damage_bonus()))
	var crit := randf() < GameState.crit_chance
	if crit:
		dmg = int(round(float(dmg) * 2.0))

	match kind:
		"BEAM":
			_fire_beam(w, dmg, crit)
		"ORBIT":
			pass  # 环绕无人机持续生效，见 _update_orbiters
		_:
			var proj: int = int(w.get("proj", 1)) + GameState.bonus_proj
			var spread: float = float(w.get("spread", 0.05))
			var spd: float = float(w.get("speed", 600.0))
			var life: float = float(w.get("life", 1.2))
			var is_homing := (kind == "HOMING")
			var turn: float = float(w.get("turn", 4.5))
			for i in proj:
				var off := (float(i) - (proj - 1) * 0.5) * spread
				_fire_bullet(_look.rotated(off), dmg, spd, life, w, is_homing, turn, crit)
	EventBus.fx_shoot.emit(global_position, _look)


func _damage_bonus() -> float:
	return 1.4 if _phase_buff > 0.0 else 1.0


func _fire_bullet(dir: Vector2, dmg: int, spd: float, life: float, w: Dictionary,
		is_homing: bool, turn: float, crit: bool) -> void:
	var b: Node = load("res://scripts/entities/Bullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (RADIUS + 12.0)
	b.setup(dir, dmg, spd, life, w.get("color", Color(1, 1, 1)), false, is_homing, turn)
	if crit:
		b.modulate = Color(1.0, 0.9, 0.4)


func _fire_beam(w: Dictionary, dmg: int, crit: bool) -> void:
	var color: Color = w.get("color", Color(0.55, 0.9, 1.0))
	var length: float = float(w.get("range", 900.0))
	var end := global_position + _look * length
	EventBus.beam_fired.emit(global_position, end, color)
	# 贯穿：命中直线上所有敌人
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var to_e: Vector2 = en.global_position - global_position
		var along: float = to_e.dot(_look)
		if along < 0.0 or along > length:
			continue
		var perp: float = (to_e - _look * along).length()
		if perp < 26.0:
			e.take_damage(dmg)
			EventBus.hit_enemy.emit(en.global_position, color, dmg, crit)


func swap_weapon() -> void:
	if _swap_cd > 0.0:
		return
	_swap_cd = SWAP_CD
	GameState.swap_weapon()
	_refresh_orbiters()


# ---------------- 环绕无人机 ----------------
func _refresh_orbiters() -> void:
	for o in _orbiters:
		if is_instance_valid(o):
			o.queue_free()
	_orbiters.clear()
	var wid := GameState.current_weapon()
	if WeaponDB.info(wid).get("kind", "") == "ORBIT":
		var count: int = int(WeaponDB.info(wid).get("count", 2))
		for i in count:
			var s := Sprite2D.new()
			s.texture = PixelArt.circle_tex(16, Color(0.7, 1.0, 0.9), Color(0.1, 0.6, 0.5), Color(0.02, 0.3, 0.28))
			s.z_index = 6
			get_parent().add_child(s)
			_orbiters.append(s)


func _update_orbiters(delta: float) -> void:
	var wid := GameState.current_weapon()
	var w: Dictionary = WeaponDB.info(wid)
	var is_orbit := str(w.get("kind", "")) == "ORBIT"
	if is_orbit and _orbiters.is_empty():
		_refresh_orbiters()
	elif not is_orbit and not _orbiters.is_empty():
		_refresh_orbiters()
	if not is_orbit:
		return
	var radius: float = float(w.get("radius", 55.0))
	var spin: float = float(w.get("spin", 3.2))
	var step := TAU / float(_orbiters.size())
	for i in _orbiters.size():
		var o: Sprite2D = _orbiters[i]
		if not is_instance_valid(o):
			continue
		var ang := _t * spin + step * float(i)
		o.global_position = global_position + Vector2(cos(ang), sin(ang)) * radius
	_orbit_dmg_t -= delta
	if _orbit_dmg_t <= 0.0:
		_orbit_dmg_t = float(w.get("tick", 0.4))
		var dmg := int(round(float(w.get("dmg", 10)) * GameState.firepower_mult() * _damage_bonus()))
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			for o in _orbiters:
				if is_instance_valid(o) and e.global_position.distance_to(o.global_position) < 22.0:
					e.take_damage(dmg)
					EventBus.hit_enemy.emit(e.global_position, Color(0.7, 1.0, 0.9), dmg, false)
					break


# ---------------- 受伤 / 治疗 ----------------
func take_hit(dmg: int) -> void:
	if not GameState.active:
		return
	if is_invulnerable():
		return
	GameState.damage_core(dmg)


func use_flask() -> void:
	if GameState.use_flask():
		EventBus.toast.emit(Lang.t("hud_flask"))


func get_radius() -> float:
	return RADIUS


func reset_for_new_room() -> void:
	_roll_t = 0.0
	_iframe_t = 0.0
	_refresh_orbiters()
