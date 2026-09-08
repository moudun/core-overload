extends Node2D
## MainGame —— V1.1 主控：地图/玩家/HUD/波次生成/掉落/特效/音效全部在此编排。
## 玩法：控制核心在地牢中移动射击，抵御入侵者波次；击杀掉落卡牌即时强化。

const W := 1280
const H := 720
const PLAY_AREA := Rect2(26, 64, 1228, 630)

var _player: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _red_flash: ColorRect
var _flash_alpha := 0.0
var _shake := 0.0

# 波次与生成
var _intro_t := 5.0
var _spawn_q: Array = []       # 待生成敌人 kind
var _spawn_t := 0.0
var _next_wave_t := -1.0
var _first_drop_done := false

# 音效池
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	_build_sfx()
	_connect_events()
	_start_intro()
	get_viewport().size = Vector2i(W, H)


func _build_world() -> void:
	# 背景 CanvasLayer(低层) —— 地板与墙
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)

	var floor_img := _build_floor_image()
	var floor_tex := ImageTexture.create_from_image(floor_img)
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = floor_tex
	floor_sprite.centered = false
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_layer.add_child(floor_sprite)

	# 边界墙（视觉：粗色块 + 内沿亮线）
	_wall_strip(bg_layer, 0, 0, W, 26)
	_wall_strip(bg_layer, 0, H - 26, W, 26)
	_wall_strip(bg_layer, 0, 26, 26, H - 52)
	_wall_strip(bg_layer, W - 26, 26, 26, H - 52)
	var edge := ColorRect.new()
	edge.color = Color(0.5, 0.55, 0.58)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.position = Vector2(26, 24)
	edge.size = Vector2(W - 52, 2)
	bg_layer.add_child(edge)
	var edge2 := ColorRect.new()
	edge2.color = Color(0.5, 0.55, 0.58)
	edge2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge2.position = Vector2(26, H - 26)
	edge2.size = Vector2(W - 52, 2)
	bg_layer.add_child(edge2)
	var edge3 := ColorRect.new()
	edge3.color = Color(0.5, 0.55, 0.58)
	edge3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge3.position = Vector2(24, 26)
	edge3.size = Vector2(2, H - 52)
	bg_layer.add_child(edge3)
	var edge4 := ColorRect.new()
	edge4.color = Color(0.5, 0.55, 0.58)
	edge4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge4.position = Vector2(W - 26, 26)
	edge4.size = Vector2(2, H - 52)
	bg_layer.add_child(edge4)

	# 玩家
	_player = load("res://scripts/entities/CorePlayer.gd").new()
	add_child(_player)
	_player.global_position = Vector2(W / 2.0, H / 2.0 + 30)

	# 摄像机（固定全景 + 震屏）
	_camera = Camera2D.new()
	_camera.position = Vector2(W / 2.0, H / 2.0)
	add_child(_camera)

	# 受击红闪
	_red_flash = ColorRect.new()
	_red_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	_red_flash.position = Vector2.ZERO
	_red_flash.size = Vector2(W, H)
	_red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_red_flash)


func _wall_strip(parent: Node, x: float, y: float, w: float, h: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.24, 0.26, 0.30)
	r.position = Vector2(x, y)
	r.size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _build_floor_image() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var light_c := Color(0.175, 0.185, 0.215)
	var dark_c := Color(0.135, 0.145, 0.17)
	var s := 32
	for gy in range(H / s):
		for gx in range(W / s):
			var col := light_c if (gx + gy) % 2 == 0 else dark_c
			if (gx * 7 + gy * 13) % 9 == 0:
				col = col.darkened(0.07)
			img.fill_rect(Rect2i(gx * s, gy * s, s, s), col)
	var seam := Color(0.055, 0.06, 0.07)
	for y in range(0, H, s):
		img.fill_rect(Rect2i(0, y, W, 2), seam)
	for x in range(0, W, s):
		img.fill_rect(Rect2i(x, 0, 2, H), seam)
	return img


func _build_hud() -> void:
	_hud = load("res://scripts/ui/HUD.gd").new()
	add_child(_hud)


func _build_sfx() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.volume_db = -12.0
		add_child(p)
		_sfx.append(p)


func _connect_events() -> void:
	EventBus.fx_shoot.connect(func(_p, _d): _play_tone(760, 540, 0.05, 0.16))
	EventBus.hit_enemy.connect(func(pos, _c): _spark(pos, Color(1.0, 0.85, 0.5), 5))
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.hit_core.connect(_on_hit_core)
	EventBus.card_picked.connect(func(_id): _play_tone(540, 900, 0.09, 0.3))
	EventBus.game_over.connect(_on_game_over)


# ---------------- 流程 ----------------
func _start_intro() -> void:
	GameState.reset_run()
	_hud.show_tutorial([
		Lang.t("tutorial_t1"),
		Lang.t("tutorial_t2"),
		Lang.t("tutorial_t3"),
		Lang.t("tutorial_t4"),
		Lang.t("lang_switch_hint"),
	])
	_intro_t = 5.0


func _process(delta: float) -> void:
	# 红闪淡出 + 震屏衰减
	_flash_alpha = maxf(0.0, _flash_alpha - delta * 1.6)
	_red_flash.color.a = _flash_alpha * 0.5
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 26.0
	else:
		_camera.offset = Vector2.ZERO

	if not GameState.active:
		return
	if _intro_t > 0.0:
		_intro_t -= delta
		if _intro_t <= 0.0:
			_start_wave()
		return

	# 波次间隙 -> 下一波
	if _next_wave_t > 0.0:
		_next_wave_t -= delta
		if _next_wave_t <= 0.0 and GameState.active:
			_start_wave()
		return

	# 队列生成
	if not _spawn_q.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			var kind: int = _spawn_q.pop_front()
			_spawn_enemy(kind)
			_spawn_t = maxf(0.14, 0.4 - GameState.wave * 0.012)

	# 波次清空检测
	if _spawn_q.is_empty() and GameState.wave > 0 and _next_wave_t < 0.0:
		if get_tree().get_nodes_in_group("enemies").is_empty():
			GameState.add_wave_clear_bonus()
			EventBus.wave_cleared.emit(GameState.wave)
			_next_wave_t = 3.0


func _start_wave() -> void:
	GameState.next_wave()
	var w := GameState.wave
	var count := mini(5 + w * 3, 30)
	_spawn_q.clear()
	for i in count:
		_spawn_q.append(Enemy.build_kind(w))
	_spawn_t = 0.5


func _spawn_enemy(kind: int) -> void:
	var e: Node = load("res://scripts/entities/Enemy.gd").new()
	add_child(e)
	var side := randi() % 4
	match side:
		0:
			e.global_position = Vector2(randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x), PLAY_AREA.position.y - 40)
		1:
			e.global_position = Vector2(randf_range(PLAY_AREA.position.x, PLAY_AREA.end.x), PLAY_AREA.end.y + 40)
		2:
			e.global_position = Vector2(PLAY_AREA.position.x - 40, randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y))
		_:
			e.global_position = Vector2(PLAY_AREA.end.x + 40, randf_range(PLAY_AREA.position.y, PLAY_AREA.end.y))
	e.setup(kind, GameState.wave)


func _on_enemy_killed(pos: Vector2) -> void:
	_explosion(pos, Color(1.0, 0.35, 0.2), 14)
	_play_tone(220, 70, 0.18, 0.34)
	_maybe_drop.call_deferred(pos)


func _maybe_drop(pos: Vector2) -> void:
	var drop := false
	var id := ""
	if not _first_drop_done:
		drop = true
		id = "rapid"
		_first_drop_done = true
	elif randf() < minf(0.16 + GameState.wave * 0.05, 0.42):
		drop = true
		id = CardPool.random_id()
	if not drop:
		return
	var c: Node = load("res://scripts/entities/LootCard.gd").new()
	add_child(c)
	c.global_position = pos + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	c.setup(id)


func _on_hit_core(_dmg: int) -> void:
	_flash_alpha = 1.0
	_shake = 0.8
	_play_tone(200, 55, 0.3, 0.5)


func _on_game_over() -> void:
	_camera.offset = Vector2.ZERO


# ---------------- 特效与音效 ----------------
func _spark(pos: Vector2, color: Color, count: int) -> void:
	var cp := CPUParticles2D.new()
	cp.position = pos
	cp.emitting = true
	cp.one_shot = true
	cp.amount = count
	cp.lifetime = 0.3
	cp.explosiveness = 1.0
	cp.direction = Vector2.UP
	cp.spread = 180
	cp.gravity = Vector2(0, 60)
	cp.initial_velocity_min = 30
	cp.initial_velocity_max = 120
	cp.scale_amount_min = 0.8
	cp.scale_amount_max = 1.6
	cp.color = color
	cp.z_index = 30
	add_child(cp)
	get_tree().create_timer(1.0).timeout.connect(cp.queue_free)


func _explosion(pos: Vector2, color: Color, count: int) -> void:
	_spark(pos, color, count)


func _play_tone(f1: float, f2: float, dur: float, vol: float) -> void:
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = _tone_wav(f1, f2, dur, vol)
	p.play()


func _tone_wav(f1: float, f2: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var frac := float(i) / float(n)
		var freq := lerpf(f1, f2, frac)
		ph += TAU * freq / rate
		var env := exp(-3.4 * frac)
		var s := (sin(ph) + 0.28 * sin(2.0 * ph)) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	w.data = data
	return w


# ---------------- 输入 ----------------
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			Lang.toggle()
		elif event.keycode == KEY_R and not GameState.active:
			_restart()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _restart() -> void:
	for g in ["enemies", "loot_cards"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()
	GameState.reset_run()
	_player.global_position = Vector2(W / 2.0, H / 2.0 + 30)
	_player.reset_build()
	_hud.hide_game_over()
	_spawn_q.clear()
	_next_wave_t = -1.0
	_first_drop_done = false
	_start_intro()
