extends Node2D
## MainGame.gd —— V1.3 主控（Roguelite 分支路线 + 11 类房间 + 局内断点）。
##
## 编排链：
##   RunDirector(分支路线图) → RoomManager(单房间 FSM) → 玩家 / HUD / 特效 / 音效
## 覆盖层：
##   RouteMap(路线选择) · RewardChoice(三选一) · BuildPanel(Tab 构筑检视)
##   PauseMenu(ESC 暂停 / 保存断点) · HackGame(底层骇入竖版射击)
##
## 所有覆盖层都是 CanvasLayer 且 process_mode=ALWAYS，游戏树暂停时仍可交互。

const W := 1280
const H := 720
const RoomMgr := preload("res://scripts/run/RoomManager.gd")

var _player: Node2D
var _hud: CanvasLayer
var _camera: Camera2D
var _flash: ColorRect          # 受击红闪
var _fade: ColorRect           # 转场黑幕
var _room: Node2D = null
var _build_panel: CanvasLayer
var _hack: Node2D = null
var _pause_layer: CanvasLayer
var _pause_confirm: Control
var _transitioning := false
var _flash_a := 0.0
var _shake := 0.0
var _ended := false

var _sfx: Array[AudioStreamPlayer] = []
var _sfx_i := 0


func _ready() -> void:
	_build_world()
	_build_hud()
	_build_overlays()
	_build_pause()
	_build_sfx()
	_connect_events()
	get_viewport().size = Vector2i(W, H)
	_boot_run()


## 启动：有「继续 Run」请求则恢复断点，否则开新局
func _boot_run() -> void:
	var pending := RunDirector.pending_resume
	RunDirector.pending_resume = {}
	if not pending.is_empty():
		var g: Variant = pending.get("game", {})
		if g is Dictionary and not (g as Dictionary).is_empty():
			GameState.restore(g as Dictionary)
		var route: Dictionary = {}
		var rr: Variant = pending.get("route", {})
		if rr is Dictionary:
			route = rr
		RunDirector.resume_run(route, int(route.get("biome", 0)))
		EventBus.toast.emit(Lang.t("menu_continue"))
		return
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
	_flash.z_index = 200
	add_child(_flash)


func _build_hud() -> void:
	_hud = load("res://scripts/ui/HUD.gd").new()
	_hud.name = "HUD"
	add_child(_hud)
	# 转场黑幕（HUD 之上、覆盖层之下）
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _build_overlays() -> void:
	# 构筑检视（Tab；不暂停）
	_build_panel = load("res://scripts/ui/BuildPanel.gd").new()
	_build_panel.name = "BuildPanel"
	add_child(_build_panel)
	# 路线图 + 奖励三选一（两者自行监听 EventBus）
	var route_map: Node = load("res://scripts/ui/RouteMap.gd").new()
	route_map.name = "RouteMap"
	add_child(route_map)
	var reward: Node = load("res://scripts/ui/RewardChoice.gd").new()
	reward.name = "RewardChoice"
	add_child(reward)


func _build_pause() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseMenu"
	_pause_layer.layer = 70
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(440, 190)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)

	var title := Label.new()
	title.name = "PauseTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	box.add_child(title)

	var hint := Label.new()
	hint.name = "PauseHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.62))
	box.add_child(hint)

	box.add_child(HSeparator.new())

	_pause_button(box, "BtnResume", _resume)
	_pause_button(box, "BtnBuild", _pause_view_build)
	_pause_button(box, "BtnSaveQuit", _save_and_quit)
	var abandon := _pause_button(box, "BtnAbandon", _show_abandon_confirm)
	abandon.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	# 放弃确认
	_pause_confirm = Control.new()
	_pause_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_confirm.visible = false
	_pause_confirm.z_index = 5
	root.add_child(_pause_confirm)
	var cdim := ColorRect.new()
	cdim.color = Color(0.0, 0.0, 0.0, 0.82)
	cdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_confirm.add_child(cdim)
	var cbox := VBoxContainer.new()
	cbox.position = Vector2(440, 280)
	cbox.custom_minimum_size = Vector2(400, 0)
	cbox.add_theme_constant_override("separation", 14)
	_pause_confirm.add_child(cbox)
	var clabel := Label.new()
	clabel.name = "ConfirmLabel"
	clabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clabel.add_theme_font_size_override("font_size", 18)
	clabel.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	cbox.add_child(clabel)
	_pause_button(cbox, "BtnYes", _abandon_run).add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_pause_button(cbox, "BtnNo", func() -> void: _pause_confirm.visible = false)

	_pause_layer.visible = false


func _pause_button(parent: Node, btn_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = btn_name
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(0.88, 0.94, 0.90))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_sfx() -> void:
	for _i in 16:
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
	EventBus.skill_used.connect(func(_s): _play_tone(520, 1300, 0.22, 0.20))
	EventBus.overload_meltdown.connect(func(_e): _play_tone(180, 60, 0.45, 0.40))
	EventBus.overload_vented.connect(func(): _play_tone(900, 300, 0.24, 0.16))
	EventBus.core_hp_changed.connect(_on_core_hp_changed)
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.game_over.connect(_on_game_over)
	EventBus.run_victory.connect(_on_victory)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.hack_requested.connect(_on_hack_requested)
	EventBus.hack_finished.connect(_on_hack_finished)


# ---------------- 房间流程 ----------------
func _on_room_requested(biome: int, room_index: int, room_type: String, depth: int) -> void:
	_load_room.call_deferred(biome, room_index, room_type, depth)


func _load_room(biome: int, room_index: int, room_type: String, depth: int) -> void:
	if _transitioning:
		return
	_transitioning = true
	# 中断可能仍在运行的骇入小游戏
	if _hack != null and is_instance_valid(_hack):
		_hack.queue_free()
	_hack = null
	if get_tree().paused:
		get_tree().paused = false

	await _fade_to(1.0, 0.20)

	# 清理旧房间与场上残留
	for g in ["enemies", "loot_cards", "boss", "room"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()
	if is_instance_valid(_room):
		_room.queue_free()
	_room = null
	await get_tree().process_frame

	# 同步单局坐标 + 新建房间
	GameState.biome_index = biome
	GameState.room_index = room_index
	GameState.room_depth = depth
	_room = RoomMgr.new()
	add_child(_room)
	_player.global_position = RoomMgr.SPAWN_ENTRY
	_player.reset_for_new_room()
	_room.setup(room_type, biome, room_index, depth)

	await _fade_to(0.0, 0.25)
	_transitioning = false


func _fade_to(target_a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_a, dur)
	await tw.finished


# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	_flash_a = maxf(0.0, _flash_a - delta * 1.6)
	_flash.color.a = _flash_a * 0.45
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 24.0
	else:
		_camera.offset = Vector2.ZERO

	if not GameState.active or _player == null or not is_instance_valid(_player):
		return
	if get_tree().paused or _transitioning:
		return
	# 翻滚（按住可连续触发，冷却由玩家侧限制）
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
	if GameState.core_hp < GameState.max_hp:
		_flash_a = 1.0
		_shake = 0.7
		_play_tone(200, 55, 0.28, 0.42)


func _on_beam(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = color
	# 光束端点也是逻辑坐标，要一起投到等距屏幕上
	line.add_point(Iso.to_screen(from))
	line.add_point(Iso.to_screen(to))
	line.z_index = 60
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)
	_play_tone(1200, 300, 0.10, 0.14)


## 清空房间 = 安全状态 → 写入断点存档（RouteMap 会随后弹出）
func _on_room_cleared() -> void:
	if not GameState.active or _ended:
		return
	# 教学房不是路线节点：不为它写断点，否则会覆盖/产生一个没有意义的「开局前」存档
	if RunDirector.tutorial_pending:
		return
	RunSave.save_checkpoint(RunDirector.snapshot(), RunDirector.current_kind())


func _on_boss_died() -> void:
	MetaState.add_source(MetaDB.SOURCE_PER_BOSS)
	_play_tone(140, 40, 0.60, 0.45)


func _on_game_over() -> void:
	if _ended:
		return
	_ended = true
	_camera.offset = Vector2.ZERO
	RunSave.clear()
	var tech := MetaState.tech_from_cells(GameState.cells)
	GameState.cells = 0
	EventBus.cells_changed.emit(0)
	MetaState.record_run(GameState.score, false)
	_hud.show_end(false, tech, 0)
	_play_tone(220, 40, 0.90, 0.50)


func _on_victory() -> void:
	if _ended:
		return
	_ended = true
	_camera.offset = Vector2.ZERO
	RunSave.clear()
	MetaState.add_source(MetaDB.SOURCE_VICTORY)
	var tech := MetaState.tech_from_cells(GameState.cells)
	GameState.cells = 0
	EventBus.cells_changed.emit(0)
	MetaState.record_run(GameState.score, true)
	_hud.show_end(true, tech, MetaDB.SOURCE_VICTORY)
	_play_tone(600, 1400, 0.70, 0.42)


# ---------------- 骇入小游戏 ----------------
func _on_hack_requested() -> void:
	if _hack != null and is_instance_valid(_hack):
		return
	_hack = load("res://scripts/hack/HackGame.gd").new()
	_hack.name = "HackGame"
	_hack.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hack)
	# 冻结主战场：骇入期间房间逻辑与敌人停止
	get_tree().paused = true


func _on_hack_finished(success: bool, _score: int, reward: int) -> void:
	if get_tree().paused:
		get_tree().paused = false
	if _room != null and is_instance_valid(_room) and _room.has_method("on_hack_finished"):
		_room.on_hack_finished(success, _score, reward)
	if success:
		_play_tone(700, 1500, 0.40, 0.30)
	_hack = null


# ---------------- 暂停菜单 ----------------
func _open_pause() -> void:
	_pause_confirm.visible = false
	_pause_layer.visible = true
	if _build_panel.has_method("close"):
		_build_panel.close()
	get_tree().paused = true
	_refresh_pause_texts()


func _refresh_pause_texts() -> void:
	_set_label(_pause_layer, "PauseTitle", Lang.t("pause_title"))
	_set_label(_pause_layer, "PauseHint", Lang.t("pause_save_hint"))
	_set_btn(_pause_layer, "BtnResume", Lang.t("pause_resume"))
	_set_btn(_pause_layer, "BtnBuild", Lang.t("pause_build"))
	_set_btn(_pause_layer, "BtnSaveQuit", Lang.t("pause_save_quit"))
	_set_btn(_pause_layer, "BtnAbandon", Lang.t("pause_abandon"))
	_set_label(_pause_layer, "ConfirmLabel", Lang.t("pause_abandon_confirm"))
	_set_btn(_pause_layer, "BtnYes", Lang.t("pause_abandon_yes"))
	_set_btn(_pause_layer, "BtnNo", Lang.t("pause_abandon_no"))


func _set_label(root: Node, node_name: String, text: String) -> void:
	var n := root.find_child(node_name, true, false)
	if n is Label:
		(n as Label).text = text


func _set_btn(root: Node, node_name: String, text: String) -> void:
	var n := root.find_child(node_name, true, false)
	if n is Button:
		(n as Button).text = text


func _resume() -> void:
	_pause_layer.visible = false
	get_tree().paused = false


func _pause_view_build() -> void:
	_pause_layer.visible = false
	if _build_panel.has_method("toggle"):
		_build_panel.toggle()
	# 保持暂停，让玩家安静看构筑


func _show_abandon_confirm() -> void:
	_pause_confirm.visible = true
	_refresh_pause_texts()


func _save_and_quit() -> void:
	# 教学房里没有值得保存的进度：直接放弃，下次新的一局会重放教学
	if GameState.active and not _ended and not RunDirector.tutorial_pending:
		RunSave.save_checkpoint(RunDirector.snapshot(), RunDirector.current_kind())
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _abandon_run() -> void:
	RunSave.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _toggle_pause() -> void:
	if _ended:
		# 结算界面：ESC 回主菜单
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	if _pause_layer.visible:
		_resume()
	elif get_tree().paused:
		# 当前暂停来自 BuildPanel / 覆盖层
		if _build_panel.visible:
			_build_panel.close()
		if _hack != null and is_instance_valid(_hack):
			return
		get_tree().paused = false
		_open_pause()
	else:
		_open_pause()


func _restart() -> void:
	_ended = false
	RunSave.clear()
	GameState.reset_run()
	_hud.hide_end()
	RunDirector.start_run()


# ---------------- 特效 / 音效 ----------------
## 特效位置全部来自 EventBus 上的**逻辑坐标**，这里统一投到等距屏幕坐标。
## z 走独立的高位band：等距深度最大到 ~41，所以 60 以上一定压在场内所有实体之上。
func _spark(pos: Vector2, color: Color, count: int) -> void:
	var cp := CPUParticles2D.new()
	cp.position = Iso.to_screen(pos)
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
	cp.z_index = 70
	add_child(cp)
	get_tree().create_timer(1.0).timeout.connect(cp.queue_free)


func _explosion(pos: Vector2, color: Color, count: int) -> void:
	_spark(pos, color, count)


func _dmg_number(pos: Vector2, amount: int, crit: bool) -> void:
	var l := Label.new()
	l.text = ("%d!" % amount) if crit else str(amount)
	l.position = Iso.to_screen(pos) + Vector2(randf_range(-10, 10), -30)
	l.z_index = 80
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
	if _sfx.is_empty():
		return
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
	# 骇入小游戏自行处理按键
	if _hack != null and is_instance_valid(_hack):
		return
	# 覆盖层打开时不吃按键（RouteMap / RewardChoice 自己处理 1-4）
	if get_tree().paused and not _pause_layer.visible:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		return
	match event.keycode:
		KEY_L:
			Lang.toggle()
		KEY_ESCAPE:
			_toggle_pause()
		KEY_TAB:
			if not _ended:
				if _build_panel.has_method("toggle"):
					_build_panel.toggle()
		KEY_R:
			if _ended:
				_restart()
			elif GameState.active and _player != null:
				_player.use_skill()
		KEY_Q:
			if GameState.active and _player != null:
				_player.swap_weapon()
		KEY_F:
			if GameState.active and _player != null:
				_player.use_flask()
