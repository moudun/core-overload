extends Node2D
## HackGame.gd —— V1.3「底层骇入 / KERNEL HACK」竖版射击房间。
##
## 玩家操控一个「数据包」在底层网络中向上渗透：
##   3 波入侵进程 → 防火墙 mini-boss
## 通关取出「底层源代码」（局外永久货币）；护盾归零则只取回部分数据。
## 完全自绘、自循环，与主流程通过 EventBus.hack_started / hack_finished 通信。

const W := 1280
const H := 720
const PLAY_TOP := 70.0
const PLAY_BOTTOM := 700.0
const PLAY_LEFT := 10.0
const PLAY_RIGHT := 1270.0

const SHIP_SPEED := 360.0
const FIRE_INTERVAL := 0.13
const BULLET_DMG := 3
const BULLET_SPEED := 900.0
const ENEMY_BULLET_SPEED := 260.0

const WAVES := [
	[{"kind": 0, "n": 5}, {"kind": 2, "n": 4}],
	[{"kind": 0, "n": 5}, {"kind": 1, "n": 3}, {"kind": 3, "n": 2}],
	[{"kind": 2, "n": 5}, {"kind": 1, "n": 4}, {"kind": 3, "n": 3}, {"kind": 4, "n": 1}],
]

var shield := 3
var max_shield := 3
var score := 0
var finished := false
var success := false

var _root: Node2D
var _bg: Sprite2D
var _ship: Sprite2D
var _ship_pos := Vector2(640, 620)
var _ship_t := 0.0
var _fire_t := 0.0
var _invuln_t := 0.0
var _hacked_t := 0.0

var _bullets: Array = []
var _ebullets: Array = []
var _enemies: Array = []
var _boss: Dictionary = {}

var _wave_idx := -1
var _phase := "intro"          # intro / wave / boss / done
var _spawn_q: Array = []
var _spawn_t := 0.0
var _wave_banner := ""
var _wave_banner_t := 0.0
var _intro_t := 1.1

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	z_index = 50
	_build()
	shield = 3 + MetaState.hack_shield_bonus()
	max_shield = shield
	EventBus.hack_started.emit()
	set_process(true)


func _build() -> void:
	_bg = Sprite2D.new()
	_bg.texture = PixelArt.hack_bg_tex(W, H)
	_bg.centered = false
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.position = Vector2.ZERO
	add_child(_bg)

	_ship = Sprite2D.new()
	_ship.texture = PixelArt.hack_ship_tex()
	_ship.position = _ship_pos
	_ship.z_index = 4
	add_child(_ship)


# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	if finished:
		return
	_ship_t += delta
	_invuln_t = maxf(0.0, _invuln_t - delta)
	if _wave_banner_t > 0.0:
		_wave_banner_t -= delta
	if _hacked_t > 0.0:
		_hacked_t = maxf(0.0, _hacked_t - delta)

	match _phase:
		"intro":
			_intro_t -= delta
			if _intro_t <= 0.0:
				_start_wave(0)
		"wave":
			_tick_spawn(delta)
			if _spawn_q.is_empty() and _enemies.is_empty():
				if _wave_idx + 1 < WAVES.size():
					_start_wave(_wave_idx + 1)
				else:
					_start_boss()
		"boss":
			_tick_boss(delta)
			if _boss.is_empty():
				_finish(true)
		_:
			pass

	_move_ship(delta)
	_auto_fire(delta)
	_tick_bullets(delta)
	_tick_enemies(delta)
	_tick_ebullets(delta)
	_draw_overlay()


# ---------------- 玩家 ----------------
func _move_ship(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		_ship_pos += dir.normalized() * SHIP_SPEED * delta
	else:
		var m := get_viewport().get_mouse_position()
		if m.y > PLAY_TOP and m.y < PLAY_BOTTOM:
			_ship_pos = _ship_pos.lerp(m, clampf(delta * 9.0, 0.0, 1.0))
	_ship_pos.x = clampf(_ship_pos.x, PLAY_LEFT + 16.0, PLAY_RIGHT - 16.0)
	_ship_pos.y = clampf(_ship_pos.y, PLAY_TOP + 16.0, PLAY_BOTTOM - 16.0)
	if _ship != null:
		_ship.position = _ship_pos
		_ship.modulate = Color(1, 1, 1, 0.4) if _invuln_t > 0.0 else Color.WHITE
		if _invuln_t > 0.0:
			_ship.modulate.a = 0.4 + 0.4 * absf(sin(_ship_t * 30.0))


func _auto_fire(delta: float) -> void:
	_fire_t -= delta
	if _fire_t > 0.0:
		return
	_fire_t = FIRE_INTERVAL
	_spawn_bullet(_ship_pos + Vector2(-6, -14), Vector2(0, -1), BULLET_DMG)
	_spawn_bullet(_ship_pos + Vector2(6, -14), Vector2(0, -1), BULLET_DMG)
	EventBus.fx_shoot.emit(_ship_pos, Vector2.UP)


func _spawn_bullet(pos: Vector2, dir: Vector2, dmg: int) -> void:
	var s := Sprite2D.new()
	s.texture = PixelArt.hack_bullet_tex(Color(0.55, 1.0, 0.90), 4, 12)
	s.position = pos
	s.z_index = 3
	add_child(s)
	_bullets.append({"node": s, "pos": pos, "dir": dir.normalized(), "dmg": dmg})


func _tick_bullets(delta: float) -> void:
	for i in range(_bullets.size() - 1, -1, -1):
		var b: Dictionary = _bullets[i]
		var pos: Vector2 = b["pos"] + (b["dir"] as Vector2) * BULLET_SPEED * delta
		b["pos"] = pos
		var node: Sprite2D = b["node"]
		node.position = pos
		if pos.y < PLAY_TOP - 10.0:
			node.queue_free()
			_bullets.remove_at(i)
			continue
		var hit := _hit_enemy_at(pos, int(b["dmg"]))
		if hit:
			node.queue_free()
			_bullets.remove_at(i)


func _hit_enemy_at(pos: Vector2, dmg: int) -> bool:
	for i in range(_enemies.size() - 1, -1, -1):
		var en: Dictionary = _enemies[i]
		if Vector2(en["pos"]).distance_to(pos) < float(en["r"]) + 5.0:
			en["hp"] = int(en["hp"]) - dmg
			(en["node"] as Sprite2D).modulate = Color(2.4, 2.4, 2.4)
			EventBus.hit_enemy.emit(pos, Color(0.55, 1.0, 0.9), dmg, false)
			if int(en["hp"]) <= 0:
				_kill_enemy(en)
			return true
	if not _boss.is_empty():
		var bpos: Vector2 = _boss["pos"]
		if bpos.distance_to(pos) < float(_boss["r"]) + 5.0:
			_boss["hp"] = int(_boss["hp"]) - dmg
			(_boss["node"] as Sprite2D).modulate = Color(2.4, 2.4, 2.4)
			EventBus.hit_enemy.emit(pos, Color(0.55, 1.0, 0.9), dmg, false)
			if int(_boss["hp"]) <= 0:
				_kill_boss()
			return true
	return false


# ---------------- 敌人 ----------------
func _start_wave(idx: int) -> void:
	_wave_idx = idx
	_phase = "wave"
	_spawn_q = []
	var spec: Array = WAVES[idx]
	for entry in spec:
		var ed: Dictionary = entry
		for _i in int(ed["n"]):
			_spawn_q.append(int(ed["kind"]))
	_shuffle(_spawn_q)
	_spawn_t = 0.35
	_wave_banner = Lang.f("hack_wave", [idx + 1, WAVES.size() + 1])
	_wave_banner_t = 1.8


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _tick_spawn(delta: float) -> void:
	if _spawn_q.is_empty():
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = maxf(0.22, 0.66 - float(_wave_idx) * 0.10)
	var kind := int(_spawn_q.pop_front())
	_spawn_enemy(kind)


func _spawn_enemy(kind: int) -> void:
	var s := Sprite2D.new()
	s.texture = PixelArt.hack_enemy_tex(kind)
	s.z_index = 2
	add_child(s)

	var hp := 3
	var spd := 92.0
	var r := 11.0
	var fire_cd := 0.0
	match kind:
		1:
			hp = 9
			spd = 58.0
			r = 14.0
		2:
			hp = 2
			spd = 195.0
			r = 10.0
		3:
			hp = 5
			spd = 48.0
			r = 13.0
			fire_cd = 1.7
		4:
			hp = 14
			spd = 70.0
			r = 16.0
			fire_cd = 1.2
	var pos := Vector2(_rng.randf_range(PLAY_LEFT + 40.0, PLAY_RIGHT - 40.0), PLAY_TOP - 30.0)
	s.position = pos
	_enemies.append({
		"node": s, "pos": pos, "hp": hp, "max_hp": hp, "kind": kind,
		"spd": spd, "r": r, "fire_cd": fire_cd, "fire_t": _rng.randf_range(0.4, 1.6),
		"t": _rng.randf() * TAU, "elite": kind == 4,
	})


func _tick_enemies(delta: float) -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		var e: Dictionary = _enemies[i]
		var node: Sprite2D = e["node"]
		if not is_instance_valid(node):
			_enemies.remove_at(i)
			continue
		e["t"] = float(e["t"]) + delta
		var pos: Vector2 = e["pos"]
		var kind := int(e["kind"])
		if kind == 2:
			pos.x += sin(float(e["t"]) * 3.4) * 190.0 * delta
		elif kind == 4:
			pos.x += sin(float(e["t"]) * 1.8) * 120.0 * delta
		pos.y += float(e["spd"]) * delta
		pos.x = clampf(pos.x, PLAY_LEFT + 16.0, PLAY_RIGHT - 16.0)
		e["pos"] = pos
		node.position = pos
		node.rotation = sin(float(e["t"]) * 2.0) * 0.12
		if node.modulate.r > 1.5:
			node.modulate = Color(1, 1, 1)

		var fire_cd := float(e["fire_cd"])
		if fire_cd > 0.0:
			e["fire_t"] = float(e["fire_t"]) - delta
			if float(e["fire_t"]) <= 0.0:
				e["fire_t"] = fire_cd
				_enemy_shoot(pos, (_ship_pos - pos).normalized(), 9)
		if pos.y > PLAY_BOTTOM + 24.0:
			node.queue_free()
			_enemies.remove_at(i)
			_damage_ship(1)


func _kill_enemy(e: Dictionary) -> void:
	var node: Sprite2D = e["node"]
	score += 100 + int(e["kind"]) * 25
	EventBus.enemy_killed.emit(node.position)
	node.queue_free()
	_enemies.erase(e)


func _enemy_shoot(pos: Vector2, dir: Vector2, dmg: int) -> void:
	var s := Sprite2D.new()
	s.texture = PixelArt.hack_bullet_tex(Color(1.0, 0.42, 0.45), 6, 12)
	s.rotation = dir.angle() - PI / 2.0
	s.position = pos
	s.z_index = 3
	add_child(s)
	_ebullets.append({"node": s, "pos": pos, "dir": dir, "dmg": dmg})
	EventBus.enemy_shot.emit(pos, dir)


func _tick_ebullets(delta: float) -> void:
	for i in range(_ebullets.size() - 1, -1, -1):
		var b: Dictionary = _ebullets[i]
		var pos: Vector2 = b["pos"] + (b["dir"] as Vector2) * ENEMY_BULLET_SPEED * delta
		b["pos"] = pos
		var node: Sprite2D = b["node"]
		node.position = pos
		if pos.y < PLAY_TOP - 20.0 or pos.y > PLAY_BOTTOM + 20.0 or pos.x < -20.0 or pos.x > W + 20.0:
			node.queue_free()
			_ebullets.remove_at(i)
			continue
		if _invuln_t <= 0.0 and pos.distance_to(_ship_pos) < 15.0:
			node.queue_free()
			_ebullets.remove_at(i)
			_damage_ship(int(b["dmg"]))


# ---------------- Boss：防火墙 ----------------
func _start_boss() -> void:
	_phase = "boss"
	var s := Sprite2D.new()
	s.texture = PixelArt.hack_boss_tex()
	s.z_index = 2
	s.position = Vector2(640, 180)
	add_child(s)
	var hp := 130 + MetaState.level_of("hack_rig") * 30
	_boss = {
		"node": s, "pos": Vector2(640, 180), "hp": hp, "max_hp": hp, "r": 34.0,
		"t": 0.0, "dir": 1.0, "radial_t": 2.2, "aim_t": 1.0, "move_t": 0.0,
		"speed": 140.0 + float(MetaState.level_of("hack_rig")) * 18.0,
	}
	_wave_banner = Lang.t("hack_boss")
	_wave_banner_t = 2.0
	EventBus.boss_spawned.emit(Lang.t("hack_boss"), hp)


func _tick_boss(delta: float) -> void:
	if _boss.is_empty():
		return
	var node: Sprite2D = _boss["node"]
	if not is_instance_valid(node):
		_boss = {}
		return
	_boss["t"] = float(_boss["t"]) + delta
	var pos: Vector2 = _boss["pos"]
	_boss["move_t"] = float(_boss["move_t"]) + delta
	if float(_boss["move_t"]) > 1.4:
		_boss["move_t"] = 0.0
		_boss["dir"] = -float(_boss["dir"])
	pos.x += float(_boss["dir"]) * float(_boss["speed"]) * delta
	pos.x = clampf(pos.x, PLAY_LEFT + 60.0, PLAY_RIGHT - 60.0)
	pos.y = 170.0 + sin(float(_boss["t"]) * 1.5) * 26.0
	_boss["pos"] = pos
	node.position = pos
	if node.modulate.r > 1.5:
		node.modulate = Color(1, 1, 1)

	_boss["radial_t"] = float(_boss["radial_t"]) - delta
	if float(_boss["radial_t"]) <= 0.0:
		_boss["radial_t"] = 2.4
		var n := 12
		for i in n:
			_enemy_shoot(pos, Vector2.from_angle(TAU * float(i) / float(n) + float(_boss["t"]) * 0.4), 10)
	_boss["aim_t"] = float(_boss["aim_t"]) - delta
	if float(_boss["aim_t"]) <= 0.0:
		_boss["aim_t"] = 0.85
		_enemy_shoot(pos, (_ship_pos - pos).normalized(), 9)


func _kill_boss() -> void:
	var node: Sprite2D = _boss["node"]
	score += 1500
	EventBus.boss_died.emit()
	EventBus.enemy_killed.emit(node.position)
	for _i in 3:
		EventBus.enemy_killed.emit(node.position + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-40, 40)))
	node.queue_free()
	_boss = {}
	_finish(true)


# ---------------- 受伤 / 结算 ----------------
func _damage_ship(amount: int) -> void:
	if _invuln_t > 0.0 or finished:
		return
	shield -= amount
	_invuln_t = 0.9
	if shield <= 0:
		shield = 0
		_finish(false)


func _finish(win: bool) -> void:
	if finished:
		return
	finished = true
	success = win
	_phase = "done"
	_hacked_t = 1.4
	var mult := MetaState.hack_reward_mult()
	var base := float(MetaDB.SOURCE_PER_HACK) + float(score) / 420.0
	var reward := int(round(base * mult))
	if not win:
		reward = maxi(2, int(round(float(reward) * 0.30)))
	if win:
		GameState.add_gold(45)
		GameState.add_cells(6)
	else:
		GameState.add_gold(15)
		GameState.add_cells(2)
	EventBus.toast.emit(Lang.f("hack_score", [score]))
	EventBus.hack_finished.emit(win, score, reward)
	# 延迟销毁，让结算横幅可见
	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


# ---------------- 自绘叠加层 ----------------
func _draw_overlay() -> void:
	queue_redraw()


func _draw() -> void:
	# 护盾
	var x := 16.0
	for i in max_shield:
		var col := Color(0.30, 1.0, 0.80, 0.95) if i < shield else Color(0.14, 0.20, 0.22, 0.9)
		draw_rect(Rect2(x + float(i) * 20.0, PLAY_TOP + 6.0, 16.0, 16.0), col)
	# 边界
	draw_line(Vector2(PLAY_LEFT, PLAY_TOP), Vector2(PLAY_RIGHT, PLAY_TOP), Color(0.15, 0.5, 0.55, 0.7), 2.0)
	draw_line(Vector2(PLAY_LEFT, PLAY_BOTTOM), Vector2(PLAY_RIGHT, PLAY_BOTTOM), Color(0.15, 0.5, 0.55, 0.7), 2.0)
	# Boss 血条
	if not _boss.is_empty():
		var r := float(int(_boss["hp"])) / float(maxi(1, int(_boss["max_hp"])))
		draw_rect(Rect2(340, 96, 600, 14), Color(0.10, 0.06, 0.10, 0.9))
		draw_rect(Rect2(342, 98, 596.0 * clampf(r, 0.0, 1.0), 10), Color(1.0, 0.36, 0.41))
	# 中央横幅
	var f: Font = ThemeDB.fallback_font
	if _wave_banner_t > 0.0 and f != null:
		draw_string(f, Vector2(430, 300), _wave_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1.0, 0.72, 0.28))
	if _hacked_t > 0.0 and f != null:
		draw_string(f, Vector2(360, 320), Lang.t("hack_clear") if success else Lang.t("hack_fail"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.30, 1.0, 0.80) if success else Color(1.0, 0.36, 0.41))
