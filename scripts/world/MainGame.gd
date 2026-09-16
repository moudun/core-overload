extends Node2D
## MainGame —— V1.2 主控（Roguelite 房间流程）。
## 编排：RunDirector(房间序列) → RoomManager(单房间 FSM) → 玩家 / HUD / 特效 / 音效。
## 切换房间时走黑屏转场，玩家位置由 CorePlayer.reset_for_new_room 复位。

const W := 1280
const H := 720
const RoomMgr := preload("res://scripts/run/RoomManager.gd")

var _player: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _flash: ColorRect          # 受击红闪
var _fade: ColorRect           # 转场黑幕
var _room: Node2D = null
var _transitioning := false
var _flash_a := 0.0
var _shake := 0.0

var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	_build_sfx()
	_connect_events()
	get_viewport().size = Vector2i(W, H)
	RunDirector.start_run()


# ---------------- 场景构建 ----------------
func _build_world() -> void:
	# 玩家（跨房间复用，只创建一次）
	_player = load("res://scripts/entities/CorePlayer.gd").new()
	add_child(_player)
	_player.global_position = RoomMgr.SPAWN_ENTRY

	# 固定全景摄像机 + 震屏
	_camera = Camera2D.new()
	_camera.position = Vector2(W / 2.0, H / 2.0)
	add_child(_camera)

	# 受击红闪
	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	_flash.position = Vector2.ZERO
	_flash.size = Vector2(W, H)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 90
	add_child(_flash)


func _build_hud() -> void:
	_hud = load("res://scripts/ui/HUD.gd").new()
	add_child(_hud)
	# 过载卷轴三选一
	var scroll_choice: Node = load("res://scripts/ui/ScrollChoice.gd").new()
	scroll_choice.name = "ScrollChoice"
	add_child(scroll_choice)
	# 转场黑幕（HUD 之上）
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _build_sfx() -> void:
	for _i in 14:
		var p := AudioStreamPlayer.new()
		p.volume_db = Settings.volume_db()
		add_child(p)
		_sfx.append(p)


func _connect_events() -> void:
	RunDirector.room_requested.connect(_on_room_requested)
	EventBus.fx_shoot.connect(func(_p, _d): _play_tone(760, 520, 0.05, 0.14))
	EventBus.hit_enemy.connect(_on_hit_enemy)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_shot.connect(func(_p, _d): _play_tone(320, 220, 0.08, 0.10))
	EventBus.beam_fired.connect(_on_beam)
	EventBus.roll_started.connect(func(): _play_tone(420, 880, 0.10, 0.16))
	EventBus.flask_used.connect(func(_c): _play_tone(520, 1040, 0.18, 0.22))
	EventBus.scroll_chosen.connect(func(_k): _play_tone(600, 1200, 0.16, 0.24))
	EventBus.core_hp_changed.connect(_on_core_hp_changed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.run_victory.connect(_on_victory)


# ---------------- 房间流程 ----------------
func _on_room_requested(biome: int, room_index: int, room_type: String) -> void:
	_load_room.call_deferred(biome, room_index, room_type)


func _load_room(biome: int, room_index: int, room_type: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to(1.0, 0.20)

	# 清理旧房间
	for g in ["enemies", "loot_cards", "boss"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()
	if is_instance_valid(_room):
		_room.set_process(false)
		_room.set_physics_process(false)
		_room.queue_free()
	_room = null
	await get_tree().process_frame

	# 新建房间
	_room = RoomMgr.new()
	add_child(_room)
	_player.global_position = RoomMgr.SPAWN_ENTRY
	_player.reset_for_new_room()
	_room.setup(room_type, biome, room_index)

	await _fade_to(0.0, 0.25)
	_transitioning = false


func _fade_to(target_a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_a, dur)
	await tw.finished


# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	# 红闪衰减 + 震屏衰减
	_flash_a = maxf(0.0, _flash_a - delta * 1.6)
	_flash.color.a = _flash_a * 0.45
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 24.0
	else:
		_camera.offset = Vector2.ZERO

	# 翻滚（按住可连续触发，冷却由玩家侧限制）
	if GameState.active and _player != null and is_instance_valid(_player):
		if Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE):
			_player.try_roll()


# ---------------- 事件回调 ----------------
func _on_hit_enemy(pos: Vector2, color: Color, amount: int, crit: bool) -> void:
	_spark(pos, color, 4 if not crit else 7)
	_dmg_number(pos, amount, crit)
	_play_tone(900, 640, 0.04, 0.10)


func _on_enemy_killed(pos: Vector2) -> void:
	_explosion(pos, Color(1.0, 0.45, 0.2), 14)
	_play_tone(220, 70, 0.18, 0.30)


func _on_core_hp_changed() -> void:
	# 仅在掉血时触发反馈（回血不给震屏）
	if GameState.core_hp < GameState.max_hp:
		_flash_a = 1.0
		_shake = 0.7
		_play_tone(200, 55, 0.28, 0.42)


func _on_beam(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = color
	line.add_point(from)
	line.add_point(to)
	line.z_index = 20
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)
	_play_tone(1200, 300, 0.10, 0.14)


func _on_game_over() -> void:
	_camera.offset = Vector2.ZERO
	var tech := MetaState.tech_from_cells(GameState.cells)
	GameState.cells = 0
	EventBus.cells_changed.emit(0)
	_hud.show_end(false, tech)


func _on_victory() -> void:
	_camera.offset = Vector2.ZERO
	var tech := MetaState.tech_from_cells(GameState.cells)
	GameState.cells = 0
	EventBus.cells_changed.emit(0)
	_hud.show_end(true, tech)


# ---------------- 特效 / 音效 ----------------
func _spark(pos: Vector2, color: Color, count: int) -> void:
	var cp := CPUParticles2D.new()
	cp.position = pos
	cp.emitting = true
	cp.one_shot = true
	cp.amount = count
	cp.lifetime = 0.28
	cp.explosiveness = 1.0
	cp.direction = Vector2.UP
	cp.spread = 180
	cp.gravity = Vector2(0, 70)
	cp.initial_velocity_min = 40
	cp.initial_velocity_max = 140
	cp.scale_amount_min = 0.7
	cp.scale_amount_max = 1.4
	cp.color = color
	cp.z_index = 30
	add_child(cp)
	get_tree().create_timer(1.0).timeout.connect(cp.queue_free)


func _explosion(pos: Vector2, color: Color, count: int) -> void:
	_spark(pos, color, count)


func _dmg_number(pos: Vector2, amount: int, crit: bool) -> void:
	var l := Label.new()
	l.text = ("%d!" % amount) if crit else str(amount)
	l.position = pos + Vector2(randf_range(-10, 10), -18)
	l.z_index = 40
	l.add_theme_font_size_override("font_size", 20 if crit else 14)
	l.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.25) if crit else Color(0.95, 1.0, 0.95))
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector2(randf_range(-14, 14), -42), 0.55)
	tw.tween_property(l, "modulate:a", 0.0, 0.55)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


func _play_tone(f1: float, f2: float, dur: float, vol: float) -> void:
	var p := _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = _tone_wav(f1, f2, dur, vol)
	p.volume_db = Settings.volume_db()
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
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_L:
			Lang.toggle()
		KEY_Q:
			if GameState.active and _player != null:
				_player.swap_weapon()
		KEY_F:
			if GameState.active and _player != null:
				_player.use_flask()
		KEY_R:
			if not GameState.active:
				_restart()
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _restart() -> void:
	GameState.reset_run()
	_hud.hide_end()
	RunDirector.start_run()
