extends CharacterBody2D
## CorePlayer —— V1.3 玩家核心。
## 能力：WASD 移动 / 鼠标瞄准射击（双武器槽）/ 翻滚无敌帧 / 治疗瓶 /
##       过载生成与主动泄压(V) / 构筑决定的系统技能(R) / 12 类武器弹道。
## 碰撞：layer=1（玩家），mask=8（实体障碍与锁门）。

const RADIUS := 13.0
const BASE_SPEED := 320.0
const ROLL_SPEED := 820.0
const ROLL_TIME := 0.22
const ROLL_IFRAME := 0.26
const ROLL_CD := 0.80
const SWAP_CD := 0.30
const SKILL_CD := 12.0
const VENT_SPEED_MULT := 0.58
const GLOW_SCALE := 0.78
## 八向角色贴图放大倍率：32×44 在 1180px 宽的菱形场地里偏小，放大一点才看得清
const ACTOR_SCALE := 1.25

var speed := BASE_SPEED
var venting := false

var _cd := 0.0
var _look := Vector2.RIGHT
var _move_dir := Vector2.ZERO
var _view: IsoShim
var _sprite: Sprite2D
var _glow: Sprite2D
var _thruster: Sprite2D
var _orbit_view: IsoShim
var _t := 0.0

# 八向行走
var _face_dir := 2
var _step := 0.0
var _idle_step := 0.0
var _delta_cached := 0.0

# 翻滚
var _roll_t := 0.0
var _iframe_t := 0.0
var _roll_cd_t := 0.0
var _roll_dir := Vector2.RIGHT
var _afterimage_t := 0.0

# 武器
var _swap_cd := 0.0
var _phase_buff := 0.0
var _orbiters: Array = []
var _orb_pos: Array = []
var _orbit_dmg_t := 0.0

# 技能
var _skill_cd_t := 0.0
var _skill_buff := 0.0
var _skill_id := ""
var _shield_t := 0.0
var _scan_t := 0.0
var _reload_armed := false

var _player_modulate := Color.WHITE


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 8

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = RADIUS
	shape.shape = circ
	add_child(shape)

	# 等距投影载体：可见子节点全部挂到它下面，用「等距屏幕坐标」摆放。
	# 本体仍然跑在 1:1 逻辑坐标里（物理 / 碰撞 / 瞄准全不变）。
	_view = IsoShim.follow_owner(self, 0, 14.0)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.actor_tex(_face_dir)
	# 脚底对齐：贴图内脚在 y=ACTOR_FOOT，而精灵是居中绘制的，所以要上抬这么多
	_sprite.position = Vector2(0.0, -(PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * ACTOR_SCALE)
	_sprite.scale = Vector2(ACTOR_SCALE, ACTOR_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 5
	_view.add_child(_sprite)

	# 反应堆外溢光（叠加混合，跟随脉冲）
	_glow = Sprite2D.new()
	_glow.texture = PixelArt.radial_glow_tex(64, Color(0.30, 0.95, 0.85), 2.6)
	var gmat := CanvasItemMaterial.new()
	gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = gmat
	_glow.position = Vector2(0.0, -16.0)
	_glow.z_index = 4
	_glow.modulate = Color(1, 1, 1, 0.34)
	_view.add_child(_glow)

	# 推进器尾焰（仅在移动 / 翻滚时出现）
	_thruster = Sprite2D.new()
	_thruster.texture = PixelArt.thruster_tex(Color(0.88, 1.0, 0.98), Color(0.22, 0.72, 1.0))
	_thruster.z_index = 4
	_thruster.visible = false
	_view.add_child(_thruster)


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	_cd = maxf(0.0, _cd - delta)
	_swap_cd = maxf(0.0, _swap_cd - delta)
	_roll_cd_t = maxf(0.0, _roll_cd_t - delta)
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_phase_buff = maxf(0.0, _phase_buff - delta)
	_skill_cd_t = maxf(0.0, _skill_cd_t - delta)
	_skill_buff = maxf(0.0, _skill_buff - delta)
	_shield_t = maxf(0.0, _shield_t - delta)
	_scan_t = maxf(0.0, _scan_t - delta)
	EventBus.skill_cd_changed.emit(skill_cd_ratio())

	# 泄压（按住 V）：不能射击，移速下降，但快速降低过载
	venting = Input.is_physical_key_pressed(KEY_V) and GameState.active and not Overload.locked
	Overload.vent(delta, venting)

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
			_phase_buff = 2.0 if GameState.has_protocol("phase") else 0.0
			if GameState.has_card("reload"):
				_reload_armed = true
	else:
		var spd := speed * GameState.move_mult()
		if venting:
			spd *= VENT_SPEED_MULT
		velocity = _move_dir * spd
	move_and_slide()

	# 行走相位：8 向贴图靠它切帧；停下就回站姿（phase=-1）
	if _move_dir != Vector2.ZERO and _roll_t <= 0.0:
		_step += delta * 9.0
	else:
		_step = 0.0

	# 朝向：鼠标在「等距屏幕」上，必须先反投影回逻辑坐标再算方向，
	# 否则瞄准会整体歪掉 45°。
	var mouse := Iso.to_logical(get_global_mouse_position())
	var to_mouse := mouse - global_position
	if to_mouse.length() > 1.0:
		_look = to_mouse.normalized()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _roll_t <= 0.0 and not venting:
		_try_shoot()

	_update_orbiters(delta)


func _process(delta: float) -> void:
	_t += delta
	_delta_cached = delta
	if _sprite != null:
		_update_actor()
		var col := _player_modulate
		if _iframe_t > 0.0:
			col.a = 0.45
		elif venting:
			col = col.lerp(Color(0.5, 0.85, 1.0), 0.55)
		if _shield_t > 0.0:
			col = col.lerp(Color(0.55, 0.85, 1.0), 0.35)
		_sprite.modulate = col
	_update_reactor_glow()
	_update_thruster()


## 八向贴图：走路时朝移动方向（这样才看得到摆腿），站住时朝瞄准方向。
func _update_actor() -> void:
	var face := _move_dir
	if _roll_t > 0.0:
		face = _roll_dir
	elif face == Vector2.ZERO:
		face = _look
	_face_dir = Iso.dir8_of_logical(face)
	var ph := -1
	if _move_dir != Vector2.ZERO and _roll_t <= 0.0:
		ph = int(_step) % PixelArt.ACTOR_WALK
	else:
		# 站住时播待机呼吸循环（8 帧，约 1.1 秒一轮），不再是定格贴图
		_idle_step += _delta_cached * 7.3
		ph = PixelArt.ACTOR_IDLE_BASE + int(_idle_step) % PixelArt.ACTOR_IDLE
	_sprite.texture = PixelArt.actor_tex(_face_dir, ph)


## 反应堆光晕：与机体同频脉冲；泄压时转冷蓝，无敌帧时压暗
func _update_reactor_glow() -> void:
	if _glow == null:
		return
	var gp := (1.0 + 0.12 * sin(_t * 4.4)) * GLOW_SCALE
	_glow.scale = Vector2(gp, gp)
	var a := 0.30 + 0.11 * sin(_t * 4.4)
	var tint := Color(0.30, 0.95, 0.85)
	if _iframe_t > 0.0:
		a = 0.18
	elif venting:
		tint = Color(0.35, 0.70, 1.0)
		a = 0.70
	elif _shield_t > 0.0:
		tint = Color(0.45, 0.80, 1.0)
		a = 0.62
	_glow.modulate = Color(tint.r, tint.g, tint.b, a)


## 尾焰：朝移动反方向喷出（翻滚时用翻滚方向）。方向要先从逻辑投到屏幕。
func _update_thruster() -> void:
	if _thruster == null:
		return
	var dir := _roll_dir if _roll_t > 0.0 else _move_dir
	if dir == Vector2.ZERO or not GameState.active:
		_thruster.visible = false
		return
	var sdir := Iso.dir_to_screen(dir)
	if sdir.length() < 0.001:
		sdir = Vector2.LEFT
	sdir = sdir.normalized()
	_thruster.visible = true
	_thruster.rotation = (-sdir).angle()
	var w := 22.0
	if _thruster.texture != null:
		w = float(_thruster.texture.get_width())
	_thruster.position = Vector2(0.0, -14.0) - sdir * (10.0 + w * 0.35)
	var flick := 0.84 + 0.18 * sin(_t * 27.0)
	_thruster.scale = Vector2(flick, flick)


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


func reset_roll_cd() -> void:
	_roll_cd_t = 0.0


func roll_cd_ratio() -> float:
	if _roll_cd_t <= 0.0:
		return 0.0
	return clampf(_roll_cd_t / (ROLL_CD * maxf(0.1, GameState.roll_cd_mult())), 0.0, 1.0)


func is_invulnerable() -> bool:
	return _iframe_t > 0.0


func _spawn_afterimage(_delta: float) -> void:
	var host := get_parent() as Node2D
	if host == null:
		return
	# 残影是「一次性静态贴花」：钉在当时的逻辑坐标上，之后不再跟随
	var holder := IsoShim.anchored(host, global_position, 4)
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture if _sprite != null else PixelArt.actor_tex(_face_dir)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _sprite != null:
		ghost.position = _sprite.position
		ghost.scale = _sprite.scale
	ghost.modulate = Color(0.5, 1.0, 0.9, 0.35)
	holder.add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(holder.queue_free)


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

	Overload.add_weapon(wid)

	var kind := str(w.get("kind", "DIRECT"))
	var crit := false
	if _reload_armed:
		crit = true
		_reload_armed = false
	else:
		crit = randf() < GameState.effective_crit() + (0.40 if _scan_t > 0.0 else 0.0)
	var dmg := int(round(float(w.get("dmg", 10)) * GameState.firepower_mult()
		* _damage_bonus() * GameState.tag_damage_mult()))
	if crit:
		dmg = int(round(float(dmg) * GameState.crit_damage_mult()))
		if GameState.tag_tier(Tags.PRECISION) >= 3:
			reset_roll_cd()

	match kind:
		"BEAM":
			_fire_beam(w, dmg, crit, wid)
		"ORBIT":
			pass
		"NOVA":
			_fire_nova(w, dmg, crit, wid)
		"LOB":
			_fire_lob(w, dmg, crit, wid)
		"CONE":
			_fire_cone(w, dmg, crit, wid)
		_:
			var proj: int = int(w.get("proj", 1)) + GameState.bonus_proj \
				+ int(GameState.card_value("bonus_proj", 0.0))
			var spread: float = float(w.get("spread", 0.05))
			var spd: float = float(w.get("speed", 600.0))
			var life: float = float(w.get("life", 1.2))
			var is_homing := (kind == "HOMING")
			var turn: float = float(w.get("turn", 4.5))
			for i in proj:
				var off := (float(i) - (proj - 1) * 0.5) * spread
				_fire_bullet(_look.rotated(off), dmg, spd, life, w, wid,
					bool(w.get("pierce", false)), is_homing, turn, crit)
	EventBus.fx_shoot.emit(global_position, _look)


func _damage_bonus() -> float:
	var m := 1.0
	if _phase_buff > 0.0:
		m += 0.40 if GameState.has_protocol("phase") else 0.0
	if _skill_buff > 0.0:
		m += 0.50
	if Overload.overdrive():
		m += 0.10
	return m


func _bullet_opts(w: Dictionary, wid: String) -> Dictionary:
	return {
		"bounce": int(w.get("bounce", 0)),
		"chain": int(w.get("chain", 0)) + GameState.tag_chain_bonus(),
		"chain_range": float(w.get("chain_range", 190.0)),
		"chain_falloff": float(w.get("chain_falloff", 0.75)),
		"aoe": float(w.get("aoe", 0.0)),
		"heal": int(w.get("heal", 0)),
		"status": WeaponDB.status_of(wid),
		"status_dur": WeaponDB.status_duration_of(wid),
		"status_power": 1.0,
		"weapon_id": wid,
	}


func _outgoing_dmg(raw: int) -> int:
	return int(round(float(raw) * GameState.chain_mult()))


func _fire_bullet(dir: Vector2, dmg: int, spd: float, life: float, w: Dictionary,
		wid: String, is_pierce: bool, is_homing: bool, turn: float, crit: bool) -> void:
	var b: Node = load("res://scripts/entities/Bullet.gd").new()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (RADIUS + 12.0)
	b.setup(dir, _outgoing_dmg(dmg), spd, life, w.get("color", Color(1, 1, 1)),
		is_pierce, is_homing, turn, _bullet_opts(w, wid))
	if crit:
		b.modulate = Color(1.0, 0.9, 0.4)


func _fire_beam(w: Dictionary, dmg: int, crit: bool, wid: String) -> void:
	var color: Color = w.get("color", Color(0.55, 0.9, 1.0))
	var length: float = float(w.get("range", 900.0))
	var end := global_position + _look * length
	EventBus.beam_fired.emit(global_position, end, color)
	var status := WeaponDB.status_of(wid)
	var dur := WeaponDB.status_duration_of(wid)
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
			en.take_damage(_outgoing_dmg(dmg))
			if status != "" and en is Enemy:
				(en as Enemy).apply_status(status, dur)
			EventBus.hit_enemy.emit(en.global_position, color, dmg, crit)


func _fire_nova(w: Dictionary, dmg: int, crit: bool, wid: String) -> void:
	var radius: float = float(w.get("radius", 210.0))
	var knock: float = float(w.get("knockback", 380.0))
	EventBus.beam_fired.emit(global_position, global_position + Vector2(radius, 0), w.get("color", Color(1, 0.7, 0.4)))
	var color: Color = w.get("color", Color(1.0, 0.72, 0.42))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var d: Vector2 = en.global_position - global_position
		if d.length() <= radius:
			en.take_damage(_outgoing_dmg(dmg))
			if en is Enemy:
				(en as Enemy).apply_status(Enemy.STATUS_BURN, 3.5)
			EventBus.hit_enemy.emit(en.global_position, color, dmg, crit)
			if en is CharacterBody2D:
				(en as CharacterBody2D).global_position += d.normalized() * 26.0
	# 视觉扩散环
	_spawn_ring(radius, color)


func _spawn_ring(radius: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * float(i) / 36.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	ring.points = pts
	ring.global_position = global_position
	ring.z_index = 18
	get_parent().add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(radius / 10.0, radius / 10.0), 0.28)
	tw.tween_property(ring, "modulate:a", 0.0, 0.28)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


func _fire_lob(w: Dictionary, dmg: int, crit: bool, wid: String) -> void:
	var speed: float = float(w.get("speed", 400.0))
	var target := get_global_mouse_position()
	var dist := global_position.distance_to(target)
	var life := clampf(dist / speed, 0.22, 1.15)
	var dir := (target - global_position).normalized()
	_fire_bullet(dir, dmg, speed, life, w, wid, false, false, 0.0, crit)


func _fire_cone(w: Dictionary, dmg: int, crit: bool, wid: String) -> void:
	var proj: int = int(w.get("proj", 6))
	var spread: float = float(w.get("spread", 0.42))
	var spd: float = float(w.get("speed", 400.0))
	var rng: float = float(w.get("range", 200.0))
	var life := maxf(0.1, rng / maxf(1.0, spd))
	for i in proj:
		var off := (float(i) - (proj - 1) * 0.5) * (spread / float(maxi(1, proj - 1)) * 2.2)
		_fire_bullet(_look.rotated(off), dmg, spd, life, w, wid, false, false, 0.0, crit)


func swap_weapon() -> void:
	if _swap_cd > 0.0:
		return
	_swap_cd = SWAP_CD
	GameState.swap_weapon()
	_refresh_orbiters()


# ---------------- 系统技能（由构筑决定） ----------------
func skill_id() -> String:
	var counts := GameState.tag_counts()
	var best := ""
	var best_n := 0
	for t in Tags.ALL:
		var n := int(counts.get(t, 0))
		if n > best_n:
			best_n = n
			best = t
	if best_n == 0:
		return "emergency_stop"
	match best:
		Tags.OVERCLOCK:
			return "overclock_pulse"
		Tags.CRYO:
			return "cryo_nova"
		Tags.ARC:
			return "arc_storm"
		Tags.VOID:
			return "phase_dash"
		Tags.SALVAGE:
			return "magnet_sweep"
		Tags.FORTIFY:
			return "force_field"
		Tags.PRECISION:
			return "weak_scan"
	return "emergency_stop"


func skill_cd_ratio() -> float:
	return clampf(_skill_cd_t / SKILL_CD, 0.0, 1.0)


## 教学房推进到「技能」步骤时清零冷却，避免玩家前面误按 R 后卡住
func reset_skill_cd() -> void:
	_skill_cd_t = 0.0


func use_skill() -> bool:
	if not GameState.active or _skill_cd_t > 0.0:
		return false
	_skill_cd_t = SKILL_CD
	_skill_id = skill_id()
	EventBus.skill_used.emit(_skill_id)
	match _skill_id:
		"overclock_pulse":
			_skill_buff = 3.0
			Overload.add(25.0)
			EventBus.toast.emit(Lang.t("skill_overclock_pulse"))
		"cryo_nova":
			_cryo_nova()
			EventBus.toast.emit(Lang.t("skill_cryo_nova"))
		"arc_storm":
			_arc_storm()
			EventBus.toast.emit(Lang.t("skill_arc_storm"))
		"phase_dash":
			_iframe_t = 1.2
			reset_roll_cd()
			EventBus.toast.emit(Lang.t("skill_phase_dash"))
		"magnet_sweep":
			_magnet_sweep()
			EventBus.toast.emit(Lang.t("skill_magnet_sweep"))
		"force_field":
			_shield_t = 5.0
			EventBus.toast.emit(Lang.t("skill_force_field"))
		"weak_scan":
			_scan_t = 6.0
			EventBus.toast.emit(Lang.t("skill_weak_scan"))
		_:
			Overload.reduce(40.0)
			EventBus.toast.emit(Lang.t("skill_emergency_stop"))
	return true


func _cryo_nova() -> void:
	Overload.reduce(15.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		if en.global_position.distance_to(global_position) < 260.0:
			if en is Enemy:
				(en as Enemy).apply_status(Enemy.STATUS_FREEZE, 3.2)
			en.take_damage(18)
	_spawn_ring(260.0, Color(0.55, 0.9, 1.0))


func _arc_storm() -> void:
	Overload.add(18.0)
	var color := Color(0.72, 0.62, 1.0)
	var list: Array = get_tree().get_nodes_in_group("enemies")
	for e in list:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		en.take_damage(26)
		if en is Enemy:
			(en as Enemy).apply_status(Enemy.STATUS_SHOCK, 4.0)
		EventBus.beam_fired.emit(global_position, en.global_position, color)
		EventBus.hit_enemy.emit(en.global_position, color, 26, false)


func _magnet_sweep() -> void:
	for l in get_tree().get_nodes_in_group("loot_cards"):
		if not is_instance_valid(l):
			continue
		var ln: Node2D = l
		ln.global_position = global_position
		if ln.has_method("pick"):
			ln.pick()
	GameState.add_gold(20)


# ---------------- 环绕无人机 ----------------
## 无人机画在等距屏幕坐标里（挂在自己的投影载体上），但**伤害判定用逻辑坐标**
## —— 所以另外维护一份 _orb_pos，别拿屏幕坐标去算距离。
func _refresh_orbiters() -> void:
	for o in _orbiters:
		if is_instance_valid(o):
			o.queue_free()
	_orbiters.clear()
	_orb_pos.clear()
	var wid := GameState.current_weapon()
	if WeaponDB.kind_of(wid) != "ORBIT":
		return
	if _orbit_view == null or not is_instance_valid(_orbit_view):
		_orbit_view = IsoShim.follow_owner(self, -1)
	var count: int = int(WeaponDB.info(wid).get("count", 2))
	for _i in count:
		var s := Sprite2D.new()
		s.texture = PixelArt.circle_tex(16, Color(0.7, 1.0, 0.9), Color(0.1, 0.6, 0.5), Color(0.02, 0.3, 0.28))
		s.z_index = 6
		_orbit_view.add_child(s)
		_orbiters.append(s)
		_orb_pos.append(Vector2.ZERO)


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
	var radius: float = float(w.get("radius", 58.0))
	var spin: float = float(w.get("spin", 3.2))
	var step := TAU / float(maxi(1, _orbiters.size()))
	for i in _orbiters.size():
		var ang := _t * spin + step * float(i)
		var d := Vector2(cos(ang), sin(ang))
		_orb_pos[i] = global_position + d * radius
		var o: Sprite2D = _orbiters[i]
		if not is_instance_valid(o):
			continue
		# 逻辑圆周在等距下是一个 2:1 的椭圆 —— 直接投过去就对了
		o.position = Iso.dir_to_screen(d) * Iso.SCALE * radius
	_orbit_dmg_t -= delta
	# 环绕无人机持续产热（很慢）
	Overload.add(delta * 1.2)
	if _orbit_dmg_t <= 0.0:
		_orbit_dmg_t = float(w.get("tick", 0.4))
		var dmg := int(round(float(w.get("dmg", 10)) * GameState.firepower_mult() * GameState.tag_damage_mult()))
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e
			for i in _orb_pos.size():
				if en.global_position.distance_to(_orb_pos[i]) < 24.0:
					e.take_damage(dmg)
					if e is Enemy:
						(e as Enemy).apply_status(Enemy.STATUS_SHOCK, 2.5)
					EventBus.hit_enemy.emit(e.global_position, Color(0.7, 1.0, 0.9), dmg, false)
					break


# ---------------- 受伤 / 治疗 ----------------
func take_hit(dmg: int) -> void:
	if not GameState.active:
		return
	if is_invulnerable():
		return
	var amount := dmg
	if _shield_t > 0.0:
		amount = int(round(float(amount) * 0.5))
	if GameState.tag_tier(Tags.FORTIFY) >= 1:
		amount = int(round(float(amount) * (1.0 - GameState.tag_damage_reduction() * 0.5)))
	GameState.damage_core(maxi(1, amount))


func use_flask() -> void:
	var mult := float(GameState.challenge_agg().get("heal_mult", 1.0))
	if mult < 1.0:
		if GameState.flask_charges <= 0 or not GameState.active:
			return
		GameState.flask_charges -= 1
		GameState.heal(int(round(float(GameState.max_hp) * 0.4 * mult)))
		EventBus.flask_used.emit(GameState.flask_charges)
	else:
		if GameState.use_flask():
			EventBus.toast.emit(Lang.t("hud_flask"))


func get_radius() -> float:
	return RADIUS


func reset_for_new_room() -> void:
	_roll_t = 0.0
	_iframe_t = 0.0
	_skill_cd_t = minf(_skill_cd_t, SKILL_CD * 0.4)
	_refresh_orbiters()
