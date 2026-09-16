extends Node
## _smoke.gd —— 临时冒烟测试驱动（验证时挂为 autoload，验证完即移除）。
## 覆盖：数据表一致性 / 双语键完整性 / OVERLOAD 分段 / 路线图 DAG 不变量 /
##       11 类房间 FSM / 新手教学关卡 / 骇入小游戏构建 /
##       玩家机体与 HUD 构建（美术层）/ 等距 2.5D 投影与八向角色 /
##       断点存档往返 / 三区块完整 Run。

var _pass := 0
var _fail: Array = []
var _victory_seen := false
var _finished_seen := false


func _ok(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		_pass += 1
	else:
		_fail.append(name + ("  <" + extra + ">" if extra != "" else ""))


func _ready() -> void:
	await get_tree().process_frame
	Engine.time_scale = 4.0
	# 核心用例（路线图 / 完整 Run）跑「非教学」路径：先标记教学已完成，
	# 教学本身由 _test_tutorial() 单独覆盖。
	MetaState.tutorial_done = true
	_test_data()
	_test_lang()
	_test_overload()
	_test_challenges()
	_test_route_invariants()
	_test_full_run()
	await _test_rooms()
	await _test_tutorial()
	_test_hack()
	await _test_art_ui()
	await _test_iso()
	await _test_onboarding()
	await _test_save_roundtrip()
	Engine.time_scale = 1.0
	_report()


func _report() -> void:
	print("SMOKE_PASS=", _pass)
	if _fail.is_empty():
		print("SMOKE_RESULT=ALL_GREEN")
	else:
		for f in _fail:
			print("SMOKE_FAIL: ", f)
		print("SMOKE_RESULT=FAILED  n=", _fail.size())
	get_tree().quit(0 if _fail.is_empty() else 1)


# ============================================================ 1. 数据表
func _test_data() -> void:
	_ok("weapons=12", WeaponDB.ALL_IDS.size() == 12, str(WeaponDB.ALL_IDS.size()))
	_ok("protocols=12", ProtocolDB.ALL_IDS.size() == 12, str(ProtocolDB.ALL_IDS.size()))
	_ok("cards=8", CardDB.ALL_IDS.size() == 8, str(CardDB.ALL_IDS.size()))
	_ok("modifiers=12", ModifierDB.ALL_IDS.size() == 12, str(ModifierDB.ALL_IDS.size()))
	_ok("rooms=11", RoomDB.ROOMS.size() == 11, str(RoomDB.ROOMS.size()))
	_ok("bosses=3", EnemyDB.BOSSES.size() == 3, str(EnemyDB.BOSSES.size()))
	_ok("tags=7", Tags.ALL.size() == 7, str(Tags.ALL.size()))
	_ok("meta_upgrades=10", MetaDB.UPGRADES.size() == 10, str(MetaDB.UPGRADES.size()))

	for w in WeaponDB.STARTER_IDS:
		_ok("starter weapon exists: " + str(w), WeaponDB.ALL_IDS.has(w))
	for lvl in MetaDB.LAB_UNLOCKS:
		for w in (lvl as Array):
			_ok("lab unlock exists: " + str(w), WeaponDB.ALL_IDS.has(str(w)))
	for lvl in MetaDB.RESEARCH_UNLOCKS:
		for p in (lvl as Array):
			_ok("research unlock exists: " + str(p), ProtocolDB.ALL_IDS.has(str(p)))

	# 武器数据：pulse（初始中立武器）/ homing 设计上不带标签，其余必须带
	var tagless: Array = []
	for w in WeaponDB.ALL_IDS:
		var wid := str(w)
		# orbiter 是被动环绕无人机（cd=0），不产生热量，heat=0 属设计内
		if wid == "orbiter":
			_ok("weapon heat>=0: " + wid, WeaponDB.heat_of(wid) >= 0.0)
		else:
			_ok("weapon heat>0: " + wid, WeaponDB.heat_of(wid) > 0.0,
				str(WeaponDB.heat_of(wid)))
		_ok("weapon kind: " + wid, WeaponDB.kind_of(wid) != "")
		if WeaponDB.tags_of(wid).is_empty():
			tagless.append(wid)
	_ok("at most 2 tagless weapons", tagless.size() <= 2, str(tagless))
	for p in ProtocolDB.ALL_IDS:
		var pid := str(p)
		_ok("protocol lv1..3: " + pid,
			ProtocolDB.value_at(pid, 1) != 0.0 and ProtocolDB.value_at(pid, 3) != 0.0)
		_ok("protocol tags: " + pid, ProtocolDB.tags_of(pid).size() > 0)
	for c in CardDB.ALL_IDS:
		var cid := str(c)
		_ok("card duration>=1: " + cid, CardDB.duration(cid) >= 1)
		_ok("card tags: " + cid, CardDB.tags_of(cid).size() > 0)

	# MetaState.levels 必须覆盖全部升级项，否则 _save 会漏字段
	for u in MetaDB.UPGRADES:
		var uid := str(u["id"])
		_ok("levels has: " + uid, MetaState.levels.has(uid))
		_ok("cost curve non-empty: " + uid, MetaDB.cost_at(uid, 0) > 0)


# ============================================================ 2. 双语
func _test_lang() -> void:
	var zh: int = Lang._ZH.size()
	var en: int = Lang._EN.size()
	_ok("lang zh keys >= 300", zh >= 300, str(zh))
	_ok("lang en keys >= 300", en >= 300, str(en))
	# 两语键集合必须完全一致
	var missing_en: Array = []
	for k in Lang._ZH.keys():
		if not Lang._EN.has(k):
			missing_en.append(k)
	var missing_zh: Array = []
	for k in Lang._EN.keys():
		if not Lang._ZH.has(k):
			missing_zh.append(k)
	_ok("en covers zh", missing_en.is_empty(), str(missing_en.slice(0, 6)))
	_ok("zh covers en", missing_zh.is_empty(), str(missing_zh.slice(0, 6)))

	for rid in RoomDB.ROOMS.keys():
		_ok("lang room_" + str(rid), Lang.has("room_" + str(rid)))
		_ok("lang reward_" + str(rid), Lang.has("reward_" + str(rid)))
	for w in WeaponDB.ALL_IDS:
		_ok("lang w_" + str(w), Lang.has("w_" + str(w)))
	for p in ProtocolDB.ALL_IDS:
		_ok("lang proto_" + str(p), Lang.has("proto_" + str(p)))
	for c in CardDB.ALL_IDS:
		_ok("lang card_" + str(c), Lang.has("card_" + str(c)))
	for u in MetaDB.UPGRADES:
		_ok("lang " + str(u["key"]), Lang.has(str(u["key"])))
		_ok("lang " + str(u["desc_key"]), Lang.has(str(u["desc_key"])))
	for m in ModifierDB.ALL_IDS:
		var mi: Dictionary = ModifierDB.info(str(m))
		_ok("lang " + str(mi["name_key"]), Lang.has(str(mi["name_key"])))
		_ok("lang " + str(mi["desc_key"]), Lang.has(str(mi["desc_key"])))
	for t in Tags.ALL:
		_ok("lang tag_" + str(t), Lang.has("tag_" + str(t)))
		for dk in (Tags.DESC_KEYS[t] as Array):
			_ok("lang " + str(dk), Lang.has(str(dk)))


# ============================================================ 3. OVERLOAD
func _test_overload() -> void:
	var cases := [[0.0, 0], [39.9, 0], [40.0, 1], [69.9, 1], [70.0, 2],
		[89.9, 2], [90.0, 3], [99.9, 3], [100.0, 4]]
	for c in cases:
		Overload.value = float(c[0])
		_ok("overload tier @%s" % str(c[0]), Overload.tier() == int(c[1]),
			"got %d want %d" % [Overload.tier(), int(c[1])])

	Overload.reset()
	Overload.heat_mult = 1.0
	Overload.resistance = 0.0
	Overload.add(30.0)
	_ok("add raises value", absf(Overload.value - 30.0) < 0.01, str(Overload.value))
	Overload.heat_mult = 2.0
	Overload.add(10.0)
	_ok("heat_mult scales gain", absf(Overload.value - 50.0) < 0.01, str(Overload.value))
	Overload.heat_mult = 1.0
	Overload.resistance = 0.5
	Overload.add(20.0)
	# 50 + 20 * heat_mult(1.0) * (1 - resistance 0.5) = 60
	_ok("resistance halves gain", absf(Overload.value - 60.0) < 0.01, str(Overload.value))
	Overload.resistance = 0.0
	Overload.vent(1.0, true)
	_ok("vent reduces", Overload.value < 60.0, str(Overload.value))

	# 收益杠杆单调
	Overload.reset()
	var dm := 1.0
	for v in [0.0, 50.0, 75.0, 95.0, 100.0]:
		Overload.value = v
		_ok("dmg mult rises @%s" % str(v), Overload.damage_mult() >= dm,
			"%f < %f" % [Overload.damage_mult(), dm])
		dm = Overload.damage_mult()
	Overload.value = 95.0
	_ok("overdrive @95", Overload.overdrive())
	Overload.value = 100.0
	_ok("enemy dmg up in danger", Overload.enemy_damage_mult() > 1.0)

	# 崩溃
	Overload.reset()
	var before := Overload.meltdowns
	Overload.value = 100.0
	Overload.trigger_meltdown("surge")
	_ok("meltdown counted", Overload.meltdowns == before + 1)
	_ok("meltdown resets to 28", absf(Overload.value - 28.0) < 0.01, str(Overload.value))
	_ok("meltdown locks", Overload.locked)
	Overload.reset()


# ============================================================ 3b. 挑战词缀
func _test_challenges() -> void:
	var saved: Array = MetaState.active_challenges.duplicate()

	MetaState.clear_challenges()
	GameState.reset_run()
	var base_res := Overload.resistance
	var base_hp := GameState.max_hp
	var base_count := GameState.enemy_count_mult()
	var base_gold := GameState.gold_mult()
	var base_drop := GameState.challenge_drop_bonus()

	MetaState.clear_challenges()
	MetaState.active_challenges = ["thermal"]
	GameState.reset_run()
	_ok("challenge thermal lowers resistance", Overload.resistance < base_res,
		"%f vs %f" % [Overload.resistance, base_res])

	MetaState.clear_challenges()
	MetaState.active_challenges = ["glass"]
	GameState.reset_run()
	_ok("challenge glass cuts hp", GameState.max_hp < base_hp, str(GameState.max_hp))
	_ok("challenge glass boosts gold", GameState.gold_mult() > base_gold,
		"%f vs %f" % [GameState.gold_mult(), base_gold])

	MetaState.clear_challenges()
	MetaState.active_challenges = ["noheal"]
	GameState.reset_run()
	_ok("challenge noheal halves healing",
		float(GameState.challenge_agg().get("heal_mult", 1.0)) < 1.0,
		str(GameState.challenge_agg().get("heal_mult", 1.0)))

	MetaState.clear_challenges()
	MetaState.active_challenges = ["signal"]
	GameState.reset_run()
	_ok("challenge signal adds enemies", GameState.enemy_count_mult() > base_count,
		"%f vs %f" % [GameState.enemy_count_mult(), base_count])

	MetaState.clear_challenges()
	MetaState.active_challenges = ["blackout"]
	GameState.reset_run()
	_ok("challenge blackout raises drop rate", GameState.challenge_drop_bonus() > base_drop,
		str(GameState.challenge_drop_bonus()))

	MetaState.clear_challenges()
	MetaState.active_challenges = ["hunger"]
	GameState.reset_run()
	var c0 := GameState.cells
	GameState.add_cells(100, false)
	var plain := GameState.cells - c0
	c0 = GameState.cells
	GameState.add_cells(100, true)
	var boss := GameState.cells - c0
	_ok("challenge hunger boosts boss cells", boss > plain, "%d vs %d" % [boss, plain])

	MetaState.clear_challenges()
	for c in saved:
		MetaState.active_challenges.append(str(c))
	GameState.reset_run()


# ============================================================ 4. 路线图 DAG
func _count_paths() -> int:
	var last := RunDirector.layers.size() - 1
	if last < 1:
		return 0
	var boss_id := int((RunDirector.layers[last] as Array)[0])
	var memo := {boss_id: 1}
	for li in range(last - 1, -1, -1):
		for nid_v in (RunDirector.layers[li] as Array):
			var nid := int(nid_v)
			var total := 0
			for nx in (RunDirector.nodes[nid]["next"] as Array):
				total += int(memo.get(int(nx), 0))
			memo[nid] = total
	var all := 0
	for nid_v in (RunDirector.layers[0] as Array):
		all += int(memo.get(int(nid_v), 0))
	return all


func _check_route_once(tag: String) -> void:
	var n := RunDirector.nodes.size()
	_ok("route[%s] nodes 7-9" % tag, n >= 7 and n <= 9, str(n))

	var kinds := {}
	var boss_count := 0
	var cycles := 0
	for k in RunDirector.nodes.keys():
		var nd: Dictionary = RunDirector.nodes[k]
		var kind := str(nd["kind"])
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		_ok("route[%s] kind valid: %s" % [tag, kind], RoomDB.exists(kind))
		if kind == "boss":
			boss_count += 1
		for nx in (nd["next"] as Array):
			if int(RunDirector.nodes[int(nx)]["layer"]) <= int(nd["layer"]):
				cycles += 1
	_ok("route[%s] exactly 1 boss" % tag, boss_count == 1, str(boss_count))
	_ok("route[%s] acyclic/forward" % tag, cycles == 0, str(cycles))

	for g in RunDirector.GUARANTEED:
		_ok("route[%s] guaranteed %s" % [tag, str(g)], int(kinds.get(str(g), 0)) >= 1)

	# 每个非首层节点至少一条入边
	var orphans := 0
	for k in RunDirector.nodes.keys():
		var nd: Dictionary = RunDirector.nodes[k]
		if int(nd["layer"]) > 0 and (nd["prev"] as Array).is_empty():
			orphans += 1
	_ok("route[%s] no orphan nodes" % tag, orphans == 0, str(orphans))

	# 至少两条到 Boss 的路线
	var paths := _count_paths()
	_ok("route[%s] >=2 paths to boss" % tag, paths >= 2, str(paths))

	# 起始层必须至少有一个低风险入口（risk<=2），否则开局没有安全选项
	var first_layer: Array = RunDirector.layers[0]
	_ok("route[%s] start layer non-empty" % tag, not first_layer.is_empty())
	var low := 0
	for nid_v in first_layer:
		if RoomDB.risk_of(str(RunDirector.nodes[int(nid_v)]["kind"])) <= 2:
			low += 1
	_ok("route[%s] start has low-risk option" % tag, low >= 1, str(low))


func _test_route_invariants() -> void:
	for i in 300:
		RunDirector.start_run()
		_check_route_once(str(i))
		# 每层节点总数校验
		var total := 0
		for L in RunDirector.layers:
			total += (L as Array).size()
		_ok("route[%d] layers sum == nodes" % i, total == RunDirector.nodes.size(),
			"%d vs %d" % [total, RunDirector.nodes.size()])


# ============================================================ 5. 完整 Run
func _test_full_run() -> void:
	RunDirector.run_finished.connect(_on_run_finished)

	var victory := 0
	var steps_used := 0
	for run_i in 5:
		_finished_seen = false
		_victory_seen = false
		RunDirector.start_run()
		var guard := 0
		while not _finished_seen and guard < 300:
			if not RunDirector.pending.is_empty():
				RunDirector.choose(int(RunDirector.pending[0]))
			RunDirector.complete_room()
			guard += 1
		_ok("run[%d] reached end" % run_i, _finished_seen, "guard=%d" % guard)
		_ok("run[%d] victory" % run_i, _victory_seen)
		if _victory_seen:
			victory += 1
		steps_used += guard
	_ok("all 5 runs victorious", victory == 5, str(victory))
	# 每局 3 区块 × (3 层选择 + Boss) = 12 间房
	_ok("run step budget sane", steps_used >= 5 * 10 and steps_used <= 5 * 40, str(steps_used))


func _on_run_finished(v: bool) -> void:
	_finished_seen = true
	if v:
		_victory_seen = true


# ============================================================ 6. 11 类房间
func _dummy_player() -> Node2D:
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = Vector2(320, 380)
	return p


## 真实的 CorePlayer（教学房需要读 venting / 技能冷却等真实状态）
func _real_player() -> Node2D:
	var p: Node2D = load("res://scripts/entities/CorePlayer.gd").new()
	add_child(p)
	p.global_position = Vector2(320, 380)
	return p


func _test_rooms() -> void:
	var player := _dummy_player()
	var expected := {
		"combat": RoomManager.State.COMBAT,
		"elite": RoomManager.State.COMBAT,
		"treasure": RoomManager.State.COMBAT,
		"repair": RoomManager.State.CLEARED,
		"shop": RoomManager.State.CLEARED,
		"lab": RoomManager.State.CLEARED,
		"glitch": RoomManager.State.PUZZLE,
		"harvest": RoomManager.State.COMBAT,
		"hack": RoomManager.State.CLEARED,
		"boss": RoomManager.State.COMBAT,
		"tutorial": RoomManager.State.TUTORIAL,
	}
	for kind in RoomDB.ROOMS.keys():
		var k := str(kind)
		var room := RoomManager.new()
		add_child(room)
		room.setup(k, 0, 0, 2)
		_ok("room[%s] built" % k, room.room_type == k)
		# 推进若干帧让 FSM 入场锁定
		var guard := 0
		while room._state == RoomManager.State.BUILD and guard < 30:
			await get_tree().process_frame
			guard += 1
		_ok("room[%s] state after entry" % k,
			room._state == expected[k], "got %d want %d" % [room._state, expected[k]])
		if k == "boss":
			await get_tree().process_frame
			_ok("room[boss] boss node spawned",
				not get_tree().get_nodes_in_group("boss").is_empty())

		# 非战斗房：按各自机制驱动到 CLEARED
		if RoomDB.is_combat(k) or k == "glitch" or k == "harvest":
			var g2 := 0
			while room._state != RoomManager.State.CLEARED and g2 < 400:
				if k == "glitch" and room._seq_idx < (room._seq as Array).size():
					# 按正确顺序修复管线，验证解谜完成路径
					room._try_repair(int((room._seq as Array)[room._seq_idx]))
				if k == "harvest":
					# 直接把限时压到尽头，验证结算路径（正常玩法是怪被清完/超时）
					room._harvest_t = minf(float(room._harvest_t), 0.05)
				await get_tree().process_frame
				for e in get_tree().get_nodes_in_group("enemies"):
					if is_instance_valid(e):
						e.queue_free()
				g2 += 1
			_ok("room[%s] reaches CLEARED" % k,
				room._state == RoomManager.State.CLEARED, "state=%d" % room._state)

		room.queue_free()
		for g in ["enemies", "boss", "loot_cards"]:
			for e in get_tree().get_nodes_in_group(g):
				if is_instance_valid(e):
					e.queue_free()
		await get_tree().process_frame
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().process_frame


# ============================================================ 6b. 新手教学关卡
## 等教学房推进到「第 want_idx 步」（最多 30 帧，不依赖 process_frame 与 _process 的先后）
func _await_tut(room: Node, want_idx: int) -> void:
	var g := 0
	while int(room._tut_idx) < want_idx and g < 30:
		await get_tree().process_frame
		g += 1


func _test_tutorial() -> void:
	var saved_done: bool = MetaState.tutorial_done

	# --- 入口 A：新档首局自动插入教学房，且不弹路线图 ---
	MetaState.tutorial_done = false
	RunDirector.pending_tutorial = false
	RunDirector.start_run()
	_ok("tutorial auto-inserted on fresh run", RunDirector.tutorial_pending)
	_ok("tutorial defers route map", RunDirector.pending.is_empty(), str(RunDirector.pending))

	# --- 入口 B：主菜单「训练关卡」强制重玩 ---
	MetaState.tutorial_done = true
	RunDirector.pending_tutorial = true
	RunDirector.start_run()
	_ok("tutorial forced from menu", RunDirector.tutorial_pending)
	_ok("pending_tutorial consumed", not RunDirector.pending_tutorial)

	# --- 数据表：教学房存在、但永不进入随机路线图 ---
	_ok("tutorial in ROOMS", RoomDB.exists("tutorial"))
	_ok("tutorial excluded from map", RoomDB.EXCLUDED_FROM_MAP.has("tutorial"))
	var in_pool := false
	for e in RoomDB.weighted_pool(9):
		if str((e as Dictionary)["id"]) == "tutorial":
			in_pool = true
	_ok("tutorial never in weighted pool", not in_pool)
	_ok("tutorial is not a combat room", not RoomDB.is_combat("tutorial"))
	_ok("tutorial steps complete list",
		RoomManager.TUTORIAL_STEPS.size() == 6, str(RoomManager.TUTORIAL_STEPS.size()))

	# --- 逐步推进：move → shoot → roll → swap → vent → skill → CLEARED ---
	var player := _real_player()
	player.global_position = Vector2(320, 380)
	GameState.weapons[0] = "pulse"
	GameState.weapons[1] = ""
	GameState.weapon_index = 0

	var room := RoomManager.new()
	add_child(room)
	room.setup("tutorial", 0, 0, 0)
	_ok("tutorial grants secondary weapon", GameState.weapons[1] != "", str(GameState.weapons))

	var guard0 := 0
	while room._state == RoomManager.State.BUILD and guard0 < 30:
		await get_tree().process_frame
		guard0 += 1
	_ok("tutorial enters TUTORIAL state", room._state == RoomManager.State.TUTORIAL,
		"state=%d" % room._state)
	_ok("tutorial step0 is move",
		str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "move", "idx=%d" % room._tut_idx)

	# 1) 移动
	player.global_position = Vector2(520, 380)
	await _await_tut(room, 1)
	_ok("tutorial step -> shoot", str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "shoot",
		"idx=%d" % room._tut_idx)

	# 2) 射击命中 3 次
	for _i in RoomManager.TUTORIAL_SHOOT_HITS:
		EventBus.hit_enemy.emit(Vector2(850, 380), Color.WHITE, 10, false)
		await get_tree().process_frame
	await _await_tut(room, 2)
	_ok("tutorial counts hits", room._tut_hits >= RoomManager.TUTORIAL_SHOOT_HITS,
		str(room._tut_hits))
	_ok("tutorial step -> roll", str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "roll",
		"idx=%d" % room._tut_idx)

	# 3) 翻滚
	EventBus.roll_started.emit()
	await _await_tut(room, 3)
	_ok("tutorial step -> swap", str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "swap",
		"idx=%d" % room._tut_idx)

	# 4) 换武器（切走当前槽即算完成）
	var swap_from := room._tut_swap_from
	GameState.swap_weapon()
	await _await_tut(room, 4)
	_ok("swap changes slot", GameState.weapon_index != swap_from,
		"%d vs %d" % [GameState.weapon_index, swap_from])
	_ok("tutorial step -> vent", str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "vent",
		"idx=%d" % room._tut_idx)
	_ok("vent step preloads overload", Overload.value > 10.0, str(Overload.value))

	# 5) 泄压（把过载压到阈值以下）
	Overload.reduce(100.0)
	await _await_tut(room, 5)
	_ok("tutorial step -> skill", str(RoomManager.TUTORIAL_STEPS[room._tut_idx]) == "skill",
		"idx=%d" % room._tut_idx)

	# 6) 系统技能
	EventBus.skill_used.emit("emergency_stop")
	await _await_tut(room, RoomManager.TUTORIAL_STEPS.size())
	await get_tree().process_frame
	_ok("tutorial reaches CLEARED", room._state == RoomManager.State.CLEARED,
		"state=%d" % room._state)
	_ok("tutorial cleans up dummy",
		room._tut_dummy == null and get_tree().get_nodes_in_group("enemies").is_empty())

	# 走上出口 → 教学结束，路线图这时才第一次出现
	room._player_in_exit = true
	var g3 := 0
	while room._state != RoomManager.State.TRANSITION and g3 < 60:
		await get_tree().process_frame
		g3 += 1
	_ok("tutorial exit transitions", room._state == RoomManager.State.TRANSITION,
		"state=%d" % room._state)
	_ok("tutorial completion opens route map", not RunDirector.pending.is_empty(),
		str(RunDirector.pending))
	_ok("tutorial marked done", MetaState.tutorial_done)

	room.queue_free()
	for g in ["enemies", "boss", "loot_cards"]:
		for e in get_tree().get_nodes_in_group(g):
			if is_instance_valid(e):
				e.queue_free()
	await get_tree().process_frame
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().process_frame

	MetaState.set_tutorial_done(saved_done)
	RunDirector.pending_tutorial = false


# ============================================================ 7. 骇入小游戏
func _test_hack() -> void:
	var h: Node = load("res://scripts/hack/HackGame.gd").new()
	add_child(h)
	_ok("hack game built", h != null and is_instance_valid(h))
	h.queue_free()


# ============================================================ 7.5 美术 / 界面
## 覆盖：玩家机体贴图（非圆形剪影）/ 图标与界面贴图 / 机体光晕与尾焰 / HUD 全量构建。
func _test_art_ui() -> void:
	# --- 玩家机体：不再是一颗球 ---
	var tex := PixelArt.player_core_tex()
	_ok("player tex 34x34", tex.get_width() == 34 and tex.get_height() == 34,
		"%dx%d" % [tex.get_width(), tex.get_height()])
	var img := tex.get_image()
	_ok("player tex has transparent margin", img.get_pixel(0, 0).a == 0.0)
	var amber := 0
	var cyan := 0
	for y in 34:
		for x in 34:
			var c := img.get_pixel(x, y)
			if c.a < 0.9:
				continue
			if c.r > 0.9 and c.g > 0.55 and c.b < 0.6:
				amber += 1
			if c.g > 0.9 and c.b > 0.8 and c.r < 0.5:
				cyan += 1
	_ok("player has 4 thruster pods (amber)", amber > 40, str(amber))
	_ok("player has cyan core + rim", cyan > 45, str(cyan))
	# 非圆剪影：斜向吊舱必须比正交方向探得更远
	var max_h := 0.0
	var max_diag := 0.0
	for r in 16:
		if img.get_pixel(17 + r, 17).a > 0.5:
			max_h = float(r)
		if img.get_pixel(17 + r, 17 + r).a > 0.5:
			max_diag = float(r) * sqrt(2.0)
	_ok("player silhouette is not a ball", max_diag > max_h * 1.25,
		"h=%.1f diag=%.1f" % [max_h, max_diag])

	# --- 图标 / 界面贴图 ---
	for k in ["hp", "bolt", "roll", "skill", "coin", "cell", "energy", "source", "depth", "warn"]:
		var t := PixelArt.icon_tex(k, 16, Color.WHITE)
		_ok("icon 16x16: " + k, t.get_width() == 16 and t.get_height() == 16)
		var im := t.get_image()
		var filled := false
		for y in 16:
			for x in 16:
				if im.get_pixel(x, y).a > 0.5:
					filled = true
		_ok("icon non-empty: " + k, filled)
	_ok("panel slice 24x24", PixelArt.panel_slice_texture(Color.CYAN).get_width() == 24)
	_ok("vignette built", PixelArt.vignette_tex(32, 18).get_width() == 32)
	_ok("radial glow built", PixelArt.radial_glow_tex(32, Color.CYAN).get_height() == 32)
	_ok("thruster built", PixelArt.thruster_tex(Color.WHITE, Color.CYAN).get_height() == 13)
	_ok("theme panel is 9-slice", UITheme.panel(UITheme.CYAN) is StyleBoxTexture)
	_ok("theme bar slot is flat", UITheme.bar_slot(UITheme.RED) is StyleBoxFlat)

	# --- 玩家节点：光晕 / 尾焰挂载正确 ---
	var p: Node2D = load("res://scripts/entities/CorePlayer.gd").new()
	add_child(p)
	await get_tree().process_frame
	_ok("player has reactor glow", p.get("_glow") != null)
	_ok("player has thruster plume", p.get("_thruster") != null)
	_ok("player sprite uses 8-dir actor tex",
		p.get("_sprite").texture.get_width() == PixelArt.ACTOR_W
		and p.get("_sprite").texture.get_height() == PixelArt.ACTOR_H)
	_ok("player visuals live under an IsoShim",
		p.get("_view") is IsoShim and (p.get("_sprite") as Sprite2D).get_parent() == p.get("_view"))
	_ok("player faces 8-dir index", int(p.get("_face_dir")) >= 0 and int(p.get("_face_dir")) < 8)
	p.queue_free()
	await get_tree().process_frame

	# --- HUD 全量构建 ---
	var hud: CanvasLayer = load("res://scripts/ui/HUD.gd").new()
	add_child(hud)
	await get_tree().process_frame
	for k in ["_hp_fg", "_hp_gloss", "_ov_fg", "_ov_gloss", "_vignette", "_danger_vig",
			"_banner_band", "_banner_line_a", "_toast_accent", "_room_label", "_depth_label",
			"_gold_label", "_cells_label", "_energy_label", "_source_label",
			"_roll_ctl", "_skill_ctl", "_tag_box", "_protos_label", "_cards_label",
			"_boss_fg", "_overlay"]:
		_ok("hud built: " + k, hud.get(k) != null)
	_ok("hud 2 weapon slots", (hud.get("_slot_bgs") as Array).size() == 2)
	_ok("hud source label filled", str(hud.get("_source_label").text) != "")
	_ok("hud hp label filled", str(hud.get("_hp_label").text) != "")
	# 教学目标面板：事件驱动创建，并带步骤进度条
	EventBus.tutorial_step.emit(2, 6, "roll")
	await get_tree().process_frame
	_ok("hud tutorial panel created", hud.get("_tut_panel") != null)
	_ok("hud tutorial progress bar filled", hud.get("_tut_bar_fg").size.x > 0.0,
		str(hud.get("_tut_bar_fg").size.x))
	_ok("hud tutorial goal text", str(hud.get("_tut_goal_label").text) != "")
	hud.queue_free()
	await get_tree().process_frame


# ============================================================ 7.5 等距 2.5D 层
## 这一层是最容易「看起来对但其实是错的」的地方：
## 投影公式、反投影往返、深度单调性、方向查表、投影载体的落位与排序，
## 以及房间几何的闸门开合，全部必须有断言兜住。
func _test_iso() -> void:
	# --- 投影 / 反投影 ---
	var probes := [Vector2(0, 0), Vector2(1280, 720), Vector2(176, 380), Vector2(640, 64)]
	for p in probes:
		var back: Vector2 = Iso.to_logical(Iso.to_screen(p))
		_ok("iso roundtrip " + str(p), back.distance_to(p) < 0.01,
			"got " + str(back))
	# 2:1 —— 逻辑 +x 走一格，屏幕应当横向走 0.5*SCALE、纵向走 0.25*SCALE
	var d: Vector2 = Iso.to_screen(Vector2(100, 0)) - Iso.to_screen(Vector2.ZERO)
	_ok("iso is 2:1", absf(d.y / d.x - 0.5) < 0.001, str(d))

	# --- 深度：x+y 单调，且全屏范围只用一个 z 波段 ---
	var z_lo := Iso.z_of(Vector2(0, 0))
	var z_hi := Iso.z_of(Vector2(1280, 720))
	_ok("depth monotonic", z_hi > z_lo, "%d -> %d" % [z_lo, z_hi])
	_ok("depth band is sane", z_lo > -200 and z_hi < 200)

	# --- 8 向查表：逻辑轴在等距里落在屏幕对角线上，不能想当然 ---
	_ok("dir8 logical +x -> SE", Iso.dir8_of_logical(Vector2(1, 0)) == 1,
		str(Iso.dir8_of_logical(Vector2(1, 0))))
	_ok("dir8 logical -x -> NW", Iso.dir8_of_logical(Vector2(-1, 0)) == 5,
		str(Iso.dir8_of_logical(Vector2(-1, 0))))
	_ok("dir8 logical +y -> SW", Iso.dir8_of_logical(Vector2(0, 1)) == 3,
		str(Iso.dir8_of_logical(Vector2(0, 1))))
	_ok("dir8 logical -y -> NE", Iso.dir8_of_logical(Vector2(0, -1)) == 7,
		str(Iso.dir8_of_logical(Vector2(0, -1))))
	# 屏幕上的正右方向，反投影回逻辑应当是「右上」那条轴
	_ok("dir8 screen right -> E", Iso.dir8_of_screen(Vector2(1, 0)) == 0,
		str(Iso.dir8_of_screen(Vector2(1, 0))))
	for i in 8:
		_ok("actor tex dir %d built" % i, PixelArt.actor_tex(i).get_width() == PixelArt.ACTOR_W)
	# 缓存：同一 (dir, phase) 必须返回同一个对象，否则每帧都会把贴图重新上传 GPU
	_ok("actor tex cached",
		PixelArt.actor_tex(3, 2) == PixelArt.actor_tex(3, 2))
	for f in PixelArt.ACTOR_WALK:
		_ok("actor walk frame %d built" % f,
			PixelArt.actor_tex(0, f).get_height() == PixelArt.ACTOR_H)

	# --- 投影载体：落位 + 全场绝对深度 ---
	var holder := Node2D.new()
	add_child(holder)
	await get_tree().process_frame
	var shim := IsoShim.anchored(holder, Vector2(400, 300), 3, 12.0)
	await get_tree().process_frame
	_ok("shim projects to iso screen",
		(shim as Node2D).global_position.distance_to(Iso.to_screen(Vector2(400, 300))) < 0.01,
		str((shim as Node2D).global_position))
	_ok("shim z is absolute depth", int(shim.z_index) == Iso.z_of(Vector2(400, 300)) + 3,
		"%d vs %d" % [shim.z_index, Iso.z_of(Vector2(400, 300)) + 3])
	_ok("shim z_as_relative off", not shim.z_as_relative)
	_ok("shim shadow child", shim.get_node_or_null("Shadow") is Polygon2D)
	# 近处（x+y 更大）的一定排在远处之前
	var near := IsoShim.anchored(holder, Vector2(900, 600), 0)
	var far := IsoShim.anchored(holder, Vector2(100, 100), 0)
	await get_tree().process_frame
	_ok("shim depth sort near over far", int(near.z_index) > int(far.z_index),
		"%d vs %d" % [near.z_index, far.z_index])
	holder.queue_free()
	await get_tree().process_frame

	# --- 房间几何：闸门开合要真的改色，碰撞体必须与可见几何同源 ---
	var room := Node2D.new()
	add_child(room)
	var parts: Dictionary = RoomFactory.build(room, 0)
	_ok("room exposes iso view", parts.get("view") is Node2D)
	_ok("room floor is iso tex", (parts["floor"] as Sprite2D).texture.get_width() == 640)
	_ok("room has 2 blockers", (parts["blockers"] as Array).size() == 2)
	var gate: Node2D = parts["door_left"]
	_ok("gate built", gate != null and gate.get_node_or_null("GateBody") != null)
	IsoRoom.set_gate_open(gate, true)
	_ok("gate open turns cool",
		(gate.get_node("GateStrip") as Polygon2D).color.g > 0.9,
		str((gate.get_node("GateStrip") as Polygon2D).color))
	IsoRoom.set_gate_open(gate, false)
	_ok("gate locked turns warm",
		(gate.get_node("GateStrip") as Polygon2D).color.r > 0.9,
		str((gate.get_node("GateStrip") as Polygon2D).color))
	RoomFactory.add_pillars(room, 0, 3, parts["view"])
	_ok("pillars made", room.get_tree() != null)
	room.queue_free()
	await get_tree().process_frame

	# --- 实体可见层：都挂在 IsoShim 下，且交互用的是逻辑坐标 ---
	var e: Node = load("res://scripts/entities/Enemy.gd").new()
	add_child(e)
	e.setup(1, 0, false)
	await get_tree().process_frame
	_ok("enemy has iso shim", e.get("_view") is IsoShim)
	_ok("enemy sprite under shim",
		(e.get("_sprite") as Sprite2D).get_parent() == e.get("_view"))
	_ok("enemy shield ring under shim",
		(e.get("_shield_ring") as Line2D).get_parent() == e.get("_view"))
	e.queue_free()
	await get_tree().process_frame

	var b: Node = load("res://scripts/entities/Bullet.gd").new()
	add_child(b)
	b.setup(Vector2(1, 0), 10, 600.0, 1.0, Color.WHITE)
	await get_tree().process_frame
	_ok("bullet has iso shim", b.get("_view") is IsoShim)
	_ok("bullet sprite under shim",
		(b.get("_sprite") as Sprite2D).get_parent() == b.get("_view"))
	b.queue_free()
	await get_tree().process_frame

	var loot: Node = load("res://scripts/entities/LootCard.gd").new()
	add_child(loot)
	loot.setup("gold", "", 5)
	await get_tree().process_frame
	_ok("loot has iso shim", loot.get("_view") is IsoShim)
	_ok("loot is not input-pickable in iso", not (loot as Area2D).input_pickable)
	loot.queue_free()
	await get_tree().process_frame


# ============================================================ 7b. 上手引导（本轮新增）
## 覆盖 6 项玩家反馈的修复：
##   1) 宝箱按 E 能开（走近即可，且放在主走廊上）
##   2) 侧边指导栏可折叠 + 持久化
##   3) 商店/宝箱/终端的交互提示文本齐全
##   4) 漫画引导图 4 页存在且在 assets/（能打进 exe）
##   5) 敌人有专属外形（不再是方块/圆盘）
##   6) 玩家有待机动画帧
func _test_onboarding() -> void:
	# ---------- 1) 宝箱 ----------
	var player := _dummy_player()   # 注意：_dummy_player 内部已经 add_child 过了
	player.global_position = RoomManager.CHEST_POS
	var room := RoomManager.new()
	room.setup("treasure", 0, 0, 1)
	add_child(room)
	await get_tree().process_frame
	_ok("chest exists", room._chest != null and is_instance_valid(room._chest))
	# 宝箱必须在主走廊上：出生点 → 宝箱是一条直线且无障碍
	_ok("chest on main corridor", absf(RoomManager.CHEST_POS.y - RoomManager.SPAWN_ENTRY.y) < 1.0,
		str(RoomManager.CHEST_POS))
	# 交互半径要够大（等距下视觉误差会让人「觉得踩上去了」）
	var d_spawn := RoomManager.CHEST_POS.distance_to(RoomManager.SPAWN_ENTRY)
	_ok("chest reachable by walking", d_spawn < 700.0, str(d_spawn))
	# 站在宝箱旁应当能开。
	# 注意交互用「边沿触发」：先离远 tick 一次把 _chest_near 落成 false（模拟玩家走过来），
	# 再靠近按 E，才是真实玩家路径。直接连按两次 pressed=true 会被去重吃掉。
	player.global_position = Vector2(-4000, -4000)
	room._tick_interactions(player, false)
	player.global_position = RoomManager.CHEST_POS
	room._tick_interactions(player, true)
	await get_tree().process_frame
	_ok("chest opens with E nearby", room._chest == null, "chest still present")
	# 开完箱_chest 被置空，提示也不该再出现
	room._tick_interactions(player, false)
	_ok("no prompt after chest opened", room._prompt.is_empty(), str(room._prompt))
	room.queue_free()
	await get_tree().process_frame

	# ---------- 2) 提示文本 ----------
	var room2 := RoomManager.new()
	room2.setup("treasure", 0, 0, 1)
	add_child(room2)
	var p2 := _dummy_player()
	p2.global_position = RoomManager.CHEST_POS
	await get_tree().process_frame
	room2._tick_interactions(p2, false)
	_ok("prompt filled when near chest", not room2._prompt.is_empty(),
		str(room2._prompt))
	_ok("prompt has chest label",
		str(room2._prompt.get("label", "")) == Lang.t("prompt_chest"),
		str(room2._prompt.get("label", "")))
	# 远离时提示要清空
	p2.global_position = Vector2(40, 60)
	room2._tick_interactions(p2, false)
	_ok("prompt cleared when far", room2._prompt.is_empty(), str(room2._prompt))
	room2.queue_free()
	await get_tree().process_frame

	# ---------- 3) 商店交互 ----------
	var room3 := RoomManager.new()
	room3.setup("shop", 0, 0, 1)
	add_child(room3)
	await get_tree().process_frame
	_ok("shop has items", room3._shop_items.size() > 0, str(room3._shop_items.size()))
	if room3._shop_items.size() > 0:
		var it: Dictionary = room3._shop_items[0]
		var node: Node2D = it["node"]
		var p3 := _dummy_player()
		# 同样的边沿触发要求：先离远落一次 latch
		p3.global_position = Vector2(-4000, -4000)
		room3._tick_interactions(p3, false)
		p3.global_position = room3._logical_of(node)
		await get_tree().process_frame
		room3._tick_interactions(p3, false)
		_ok("shop prompt appears", str(room3._prompt.get("id", "")) == "shop",
			str(room3._prompt))
		# 给钱后按 E 应当买下
		GameState.add_gold_raw(9999)
		var before_n := room3._shop_items.size()
		room3._tick_interactions(p3, true)
		await get_tree().process_frame
		_ok("shop buy removes item", room3._shop_items.size() < before_n,
			"%d -> %d" % [before_n, room3._shop_items.size()])
		# 不松手（同一次按住）不该连续扣钱
		var after_first := room3._shop_items.size()
		room3._tick_interactions(p3, true)
		await get_tree().process_frame
		_ok("holding E does not double-buy", room3._shop_items.size() == after_first,
			"%d -> %d" % [after_first, room3._shop_items.size()])
		# 走开再回来，必须还能买下一件（回归：曾因下标复用导致第二件买不掉）
		if room3._shop_items.size() > 0:
			p3.global_position = Vector2(-4000, -4000)
			room3._tick_interactions(p3, false)
			p3.global_position = room3._logical_of(room3._shop_items[0]["node"])
			room3._tick_interactions(p3, false)
			var before_2 := room3._shop_items.size()
			room3._tick_interactions(p3, true)
			await get_tree().process_frame
			_ok("shop can buy second item after walking away",
				room3._shop_items.size() < before_2,
				"%d -> %d" % [before_2, room3._shop_items.size()])
		p3.queue_free()
	room3.queue_free()
	await get_tree().process_frame

	# ---------- 4) 指南栏文案 & 折叠持久化 ----------
	var gkeys := ["guide_move", "guide_shoot", "guide_roll", "guide_swap", "guide_skill",
		"guide_flask", "guide_interact", "guide_chest", "guide_shop", "guide_hack",
		"guide_glitch", "guide_overload", "guide_vent", "guide_lang"]
	for k in gkeys:
		_ok("guide key " + k, Lang.t(k) != k, Lang.t(k))
	var saved_guide := Settings.hud_guide_open
	Settings.set_hud_guide_open(false)
	_ok("guide collapse persists", Settings.hud_guide_open == false)
	Settings.set_hud_guide_open(true)
	_ok("guide expand persists", Settings.hud_guide_open == true)
	Settings.set_hud_guide_open(saved_guide)

	# 提示 key 也要齐全
	for k in ["prompt_chest", "prompt_shop", "prompt_hack", "prompt_repair", "prompt_key"]:
		_ok("prompt key " + k, Lang.t(k) != k, Lang.t(k))

	# ---------- 5) 漫画引导图 ----------
	var pages := [
		"res://assets/story-comic/01_page_awakening.png",
		"res://assets/story-comic/02_page_overload.png",
		"res://assets/story-comic/03_page_loot.png",
		"res://assets/story-comic/04_page_controls.png",
	]
	for pth in pages:
		_ok("comic page exists " + pth.get_file(), ResourceLoader.exists(pth))
	var t0: Texture2D = load(pages[0])
	_ok("comic page loads", t0 != null)
	if t0 != null:
		_ok("comic page is 1280x720",
			t0.get_width() == 1280 and t0.get_height() == 720,
			"%dx%d" % [t0.get_width(), t0.get_height()])
	# intro_seen 标志
	var saved_seen: bool = MetaState.intro_seen
	MetaState.intro_seen = false
	MetaState.mark_intro_seen()
	_ok("mark_intro_seen sets flag", MetaState.intro_seen)
	MetaState.intro_seen = saved_seen

	# ---------- 6) 敌人专属外形 ----------
	var sigs := {}
	for k in 5:
		var t := PixelArt.enemy_tex(k)
		_ok("enemy tex %d non-empty" % k, t != null and t.get_width() > 0)
		var im := t.get_image()
		# 统计不透明像素 + 颜色多样性，用来证明「是有形状的，不是纯方块」
		var opaque := 0
		var cols := {}
		var w := im.get_width()
		var h := im.get_height()
		for y in h:
			for x in w:
				var c := im.get_pixel(x, y)
				if c.a > 0.5:
					opaque += 1
					cols["%d_%d_%d" % [int(c.r * 12), int(c.g * 12), int(c.b * 12)]] = true
		sigs[k] = [opaque, cols.size()]
		_ok("enemy %d has body" % k, opaque > 120, str(opaque))
		# 方块只会有 2-3 种主色；有细节的造型颜色明显更多
		_ok("enemy %d has detail" % k, cols.size() >= 5, str(cols.size()))
	# 5 种外形必须互不相同（不能都是同一个方块）
	var shapes := {}
	for k in 5:
		shapes[str(sigs[k])] = true
	_ok("enemy shapes are distinct", shapes.size() == 5, str(shapes.size()))
	# 缓存要命中（同 kind 重复取应当是同一个对象）
	_ok("enemy tex cached", PixelArt.enemy_tex(0) == PixelArt.enemy_tex(0))

	# ---------- 7) 玩家待机动画 ----------
	_ok("idle frames defined", PixelArt.ACTOR_IDLE >= 6, str(PixelArt.ACTOR_IDLE))
	var idle_tex := {}
	for i in PixelArt.ACTOR_IDLE:
		var ph := PixelArt.ACTOR_IDLE_BASE + i
		var t := PixelArt.actor_tex(2, ph)
		_ok("idle frame %d exists" % i, t != null)
		idle_tex[i] = t
	# 待机各帧必须**不完全一样**（否则就是没动画）
	var distinct := {}
	for i in PixelArt.ACTOR_IDLE:
		distinct[str(idle_tex[i])] = true
	_ok("idle frames differ", distinct.size() >= 3, str(distinct.size()))
	# 待机与静态站姿也要不同
	_ok("idle differs from static",
		str(PixelArt.actor_tex(2, PixelArt.ACTOR_IDLE_BASE)) != str(PixelArt.actor_tex(2, -1)))
	# 走路帧不受影响（回归）
	var walk_ok := true
	for i in PixelArt.ACTOR_WALK:
		if PixelArt.actor_tex(0, i) == null:
			walk_ok = false
	_ok("walk frames still fine", walk_ok)

	# 玩家真的会用待机帧
	var rp := _real_player()
	await get_tree().process_frame
	rp._update_actor()
	_ok("player uses idle phase when standing",
		rp._sprite.texture == PixelArt.actor_tex(rp._face_dir, PixelArt.ACTOR_IDLE_BASE),
		"face=%d" % rp._face_dir)
	rp.queue_free()
	await get_tree().process_frame
	player.queue_free()
	await get_tree().process_frame


# ============================================================ 8. 断点存档
func _test_save_roundtrip() -> void:
	RunDirector.start_run()
	GameState.add_gold_raw(123)
	GameState.grant_scroll("firepower")
	GameState.grant_scroll("firepower")
	GameState.add_protocol("siphon")
	GameState.add_card("allin")
	GameState.equip_weapon("scatter")
	GameState.add_cells(7)

	var snap := GameState.snapshot()
	_ok("save wrote checkpoint", RunSave.save_checkpoint(RunDirector.snapshot(), "combat"))
	_ok("save detectable", RunSave.has_save())
	var sum := RunSave.summary()
	_ok("summary biome>=1", int(sum.get("biome", 0)) >= 1, str(sum.get("biome", 0)))

	# 破坏当前状态
	GameState.reset_run()
	_ok("state scrambled", GameState.gold != int(snap["gold"]))

	# 读档还原
	var payload := RunSave.load_payload()
	_ok("payload loaded", not payload.is_empty())
	GameState.restore(payload["game"])
	RunDirector.resume_run(payload["route"], int(payload["route"].get("biome", 0)))

	_ok("restored gold", GameState.gold == int(snap["gold"]),
		"%d vs %d" % [GameState.gold, int(snap["gold"])])
	_ok("restored firepower", GameState.firepower == int(snap["firepower"]),
		"%d vs %d" % [GameState.firepower, int(snap["firepower"])])
	_ok("restored cells", GameState.cells == int(snap["cells"]),
		"%d vs %d" % [GameState.cells, int(snap["cells"])])
	_ok("restored protocol", GameState.has_protocol("siphon"))
	_ok("restored card", GameState.has_card("allin"))
	_ok("restored weapon", GameState.all_weapons().has("scatter"),
		str(GameState.all_weapons()))
	_ok("restored route nodes", RunDirector.nodes.size() == int(payload["route"]["nodes"].size()))
	_ok("resume has choices", not RunDirector.pending.is_empty())

	# 覆盖战斗中的写盘：active=false 时不应写
	GameState.active = false
	_ok("no save when inactive", not RunSave.save_checkpoint({}, "none"))
	GameState.active = true

	RunSave.clear()
	_ok("cleared", not RunSave.has_save())
