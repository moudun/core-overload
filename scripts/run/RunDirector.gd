extends Node
## RouteDirector.gd (Autoload，注册名 RunDirector) —— V1.3 Run 总控 + 分支路线图。
##
## 每个区块生成一张「系统拓扑图」：7–9 个节点，从起点到 Boss 至少存在两条有效路线。
## 玩家清空一间房后，从当前节点连出的下一层节点中挑一个推进。
## 实际建房仍由 MainGame 监听 room_requested 完成。

signal room_requested(biome: int, room_index: int, room_type: String, depth: int)
signal run_started
signal run_finished(victory: bool)
signal route_ready(choices: Array)

const BIOMES := 3

## 每区块的层结构候选（不含 Boss），总节点数 = sum + 1，控制在 7–9
const LAYER_SHAPES := [
	[2, 2, 2],
	[2, 3, 2],
	[3, 2, 2],
	[2, 2, 3],
	[3, 3, 2],
	[2, 3, 3],
]

## 每个区块保证出现的房间类型（避免随机权重把它们漏掉）
const GUARANTEED := ["shop", "repair", "hack"]

var biome := 0
var nodes: Dictionary = {}       # id(int) -> Dictionary
var layers: Array = []           # Array[Array[int]]
var current := -1                # 当前节点 id；-1 = 起点
var cleared: Array = []          # 已通过的节点 id
var pending: Array = []          # 当前可选的节点 id
var room_counter := 0            # 本区块内第几间房（HUD 用）

## 主菜单「继续 Run」时放入待恢复的存档 payload，由 MainGame 启动后消费一次
var pending_resume: Dictionary = {}

## 主菜单「训练关卡」入口：强制下一局先跑教学房（不影响 tutorial_done）
var pending_tutorial := false

## 本局是否正处于「教学房阶段」；教学房由 start_run 直接请求，
## 不走路线图，因此这段时间不会 _present_choices（也就不会弹出 RouteMap）。
var tutorial_pending := false


func _ready() -> void:
	pass


# ---------------- 开局 ----------------
func start_run() -> void:
	GameState.reset_run()
	biome = 0
	room_counter = 0
	_build_route(0)
	run_started.emit()
	# 新档首局 → 自动进教学；主菜单「训练关卡」→ 强制重玩。
	var want_tutorial := pending_tutorial or not MetaState.tutorial_done
	pending_tutorial = false
	if want_tutorial:
		tutorial_pending = true
		room_requested.emit(0, 0, "tutorial", 0)
		return
	tutorial_pending = false
	_present_choices()


## 从断点存档恢复（不重置 GameState，由调用方先 restore）
func resume_run(route_state: Dictionary, biome_index: int) -> void:
	biome = biome_index
	nodes = {}
	layers = []
	cleared = []
	pending = []
	tutorial_pending = false
	pending_tutorial = false
	current = int(route_state.get("current", -1))
	room_counter = int(route_state.get("room_counter", 0))
	var raw_nodes: Variant = route_state.get("nodes", {})
	if raw_nodes is Dictionary:
		for k in (raw_nodes as Dictionary).keys():
			var n: Dictionary = (raw_nodes as Dictionary)[k]
			nodes[int(k)] = n
	var raw_layers: Variant = route_state.get("layers", [])
	if raw_layers is Array:
		for L in (raw_layers as Array):
			var layer: Array = []
			if L is Array:
				for v in (L as Array):
					layer.append(int(v))
			layers.append(layer)
	var raw_cleared: Variant = route_state.get("cleared", [])
	if raw_cleared is Array:
		for v in (raw_cleared as Array):
			cleared.append(int(v))
	_present_choices()


# ---------------- 路线生成 ----------------
func _build_route(biome_idx: int) -> void:
	biome = biome_idx
	nodes = {}
	layers = []
	cleared = []
	pending = []
	current = -1
	room_counter = 0
	tutorial_pending = false
	GameState.reroll_left = MetaState.reroll_charges()

	var shape: Array = LAYER_SHAPES[randi() % LAYER_SHAPES.size()]
	var next_id := 0
	# 逐层建节点（层 0 为起点层）
	for li in shape.size():
		var layer: Array = []
		for _s in int(shape[li]):
			nodes[next_id] = {
				"id": next_id, "layer": li, "slot": layer.size(),
				"kind": "combat", "risk": 1, "next": [], "prev": [],
			}
			layer.append(next_id)
			next_id += 1
		layers.append(layer)
	# Boss 节点
	var boss_layer: Array = [next_id]
	nodes[next_id] = {
		"id": next_id, "layer": shape.size(), "slot": 0,
		"kind": "boss", "risk": 5, "next": [], "prev": [],
	}
	next_id += 1
	layers.append(boss_layer)

	_link_layers()
	_assign_kinds()
	for wid in GUARANTEED:
		_ensure_kind(wid)
	# 注意：必须放在保证房型落位之后，否则 _ensure_kind 可能把起点层唯一的低风险入口改掉
	_ensure_safe_start()


func _link_layers() -> void:
	# 相邻层之间建立有向边；保证后一层每个节点至少有一条入边
	for li in range(layers.size() - 1):
		var cur_layer: Array = layers[li]
		var nxt_layer: Array = layers[li + 1]
		if cur_layer.is_empty() or nxt_layer.is_empty():
			continue
		var cur_n := cur_layer.size()
		var nxt_n := nxt_layer.size()
		for i in cur_n:
			# 按比例连到下一层 1–2 个节点
			var start := int(floor(float(i) * float(nxt_n) / float(cur_n)))
			var end := int(ceil(float(i + 1) * float(nxt_n) / float(cur_n))) - 1
			start = clampi(start, 0, nxt_n - 1)
			end = clampi(end, start, nxt_n - 1)
			for j in range(start, end + 1):
				_add_edge(int(cur_layer[i]), int(nxt_layer[j]))
			if randf() < 0.40 and nxt_n > 1:
				_add_edge(int(cur_layer[i]), int(nxt_layer[randi() % nxt_n]))
		# 补足入边为 0 的节点：连到最近的上一层节点
		for j in nxt_n:
			var tid := int(nxt_layer[j])
			if (nodes[tid]["prev"] as Array).is_empty():
				var src_i := clampi(int(round(float(j) * float(cur_n) / float(nxt_n))), 0, cur_n - 1)
				_add_edge(int(cur_layer[src_i]), tid)


func _add_edge(from_id: int, to_id: int) -> void:
	var nxt: Array = nodes[from_id]["next"]
	if not nxt.has(to_id):
		nxt.append(to_id)
	var prv: Array = nodes[to_id]["prev"]
	if not prv.has(from_id):
		prv.append(from_id)


func _assign_kinds() -> void:
	var used := {}
	for li in range(layers.size() - 1):
		var layer: Array = layers[li]
		for nid_v in layer:
			var nid := int(nid_v)
			var depth := li + 1
			var pool := RoomDB.weighted_pool(depth)
			var kind := _pick_weighted(pool, used)
			if kind == "":
				kind = "combat"
			nodes[nid]["kind"] = kind
			nodes[nid]["risk"] = RoomDB.risk_of(kind)
			used[kind] = int(used.get(kind, 0)) + 1
	# 起点层的低风险保证改由 _ensure_safe_start() 在保证房型落位后统一处理
	# 倒数第二层提高风险感
	var pre_boss: Array = layers[layers.size() - 2]
	for nid_v in pre_boss:
		var nid := int(nid_v)
		var k := str(nodes[nid]["kind"])
		if k == "combat" and randf() < 0.55:
			nodes[nid]["kind"] = "elite"
			nodes[nid]["risk"] = RoomDB.risk_of("elite")


## 起点层必须至少留一个「低风险入口」（risk <= 2），否则开局就没有安全选项。
## 优先降级非保证房型的节点，避免为了安全把 shop / repair / hack 的保底挤掉。
func _ensure_safe_start() -> void:
	if layers.is_empty() or (layers[0] as Array).is_empty():
		return
	var start: Array = layers[0]
	for nid_v in start:
		if RoomDB.risk_of(str(nodes[int(nid_v)]["kind"])) <= 2:
			return
	var target := -1
	for nid_v in start:
		if not GUARANTEED.has(str(nodes[int(nid_v)]["kind"])):
			target = int(nid_v)
			break
	if target < 0:
		target = int(start[0])
	nodes[target]["kind"] = "combat"
	nodes[target]["risk"] = RoomDB.risk_of("combat")


func _pick_weighted(pool: Array, used: Dictionary) -> String:
	if pool.is_empty():
		return "combat"
	var filtered: Array = []
	for p in pool:
		var pid := str(p["id"])
		if int(used.get(pid, 0)) >= RoomDB.max_per_biome(pid):
			continue
		filtered.append(p)
	if filtered.is_empty():
		filtered = pool
	var total := 0
	for p in filtered:
		total += int(p["weight"])
	var r := randi_range(0, maxi(0, total - 1))
	var acc := 0
	for p in filtered:
		acc += int(p["weight"])
		if r < acc:
			return str(p["id"])
	return str(filtered[filtered.size() - 1]["id"])


## 保证某类房间至少出现一次：挤掉一个非保证、非 Boss 的节点
func _ensure_kind(kind: String) -> void:
	for nid in nodes.keys():
		if str(nodes[nid]["kind"]) == kind and kind != "boss":
			return
	var candidates: Array = []
	for nid in nodes.keys():
		var k := str(nodes[nid]["kind"])
		if k == "boss" or GUARANTEED.has(k):
			continue
		if k == "combat" or k == "elite" or k == "treasure" or k == "glitch":
			candidates.append(int(nid))
	if candidates.is_empty():
		for nid in nodes.keys():
			if str(nodes[nid]["kind"]) != "boss":
				candidates.append(int(nid))
	if candidates.is_empty():
		return
	# 优先放在中后段
	candidates.sort_custom(func(a, b): return int(nodes[a]["layer"]) > int(nodes[b]["layer"]))
	var target: int = int(candidates[mini(randi() % 2, candidates.size() - 1)])
	nodes[target]["kind"] = kind
	nodes[target]["risk"] = RoomDB.risk_of(kind)


# ---------------- 选择 / 推进 ----------------
func _present_choices() -> void:
	var ids: Array = []
	if current < 0:
		ids = (layers[0] as Array).duplicate()
	else:
		ids = (nodes[current]["next"] as Array).duplicate()
	pending = []
	for v in ids:
		pending.append(int(v))
	var choices: Array = []
	for nid_v in pending:
		var nid := int(nid_v)
		var n: Dictionary = nodes[nid]
		choices.append({
			"id": nid,
			"kind": str(n["kind"]),
			"risk": int(n["risk"]),
			"layer": int(n["layer"]),
			"slot": int(n["slot"]),
			"name": RoomDB.display_name(str(n["kind"])),
			"reward": RoomDB.reward_hint(str(n["kind"])),
			"color": RoomDB.color_of(str(n["kind"])),
		})
	route_ready.emit(choices)
	# UI（RouteMap）监听的是全局总线；两个信号都发，宿主与覆盖层各取所需
	EventBus.route_ready.emit(choices)


func choose(node_id: int) -> bool:
	if not pending.has(node_id):
		return false
	var n: Dictionary = nodes[node_id]
	current = node_id
	EventBus.route_node_chosen.emit(node_id)
	room_requested.emit(biome, room_counter, str(n["kind"]), int(n["layer"]) + 1)
	return true


## 由 MainGame 在房间清空后调用
func complete_room() -> void:
	# 教学房不占路线节点、不计入房间序号，直接进入第一次路线选择
	if tutorial_pending:
		tutorial_pending = false
		MetaState.set_tutorial_done(true)
		EventBus.tutorial_finished.emit()
		_present_choices()
		return
	room_counter += 1
	if current >= 0 and not cleared.has(current):
		cleared.append(current)
	var kind := "combat"
	if current >= 0:
		kind = str(nodes[current]["kind"])
	GameState.tick_cards()
	GameState.room_index = room_counter
	if kind == "boss":
		_advance_biome()
		return
	_present_choices()


func _advance_biome() -> void:
	# Boss 清空：发区块奖励
	var src := MetaDB.SOURCE_PER_BIOME + _biome_source_bonus()
	MetaState.add_source(src)
	EventBus.toast.emit(Lang.f("biome_source_gain", [src]))
	# 中继：每区块补满治疗瓶
	GameState.refill_flask()
	var nb := biome + 1
	if nb >= BIOMES:
		GameState.active = false
		run_finished.emit(true)
		EventBus.run_victory.emit()
		return
	_build_route(nb)
	# 注意：biome_index 由 MainGame 在房间切换时同步，这里先更新，供 HUD 读取
	GameState.biome_index = nb
	_present_choices()


func _biome_source_bonus() -> int:
	return biome * 2


func current_kind() -> String:
	if current < 0:
		return "combat"
	return str(nodes[current]["kind"])


func biome_name() -> String:
	return Lang.t("biome_%d" % (biome + 1))


func total_layers() -> int:
	return layers.size()


# ---------------- 存档 ----------------
func snapshot() -> Dictionary:
	return {
		"biome": biome,
		"current": current,
		"cleared": cleared.duplicate(),
		"room_counter": room_counter,
		"nodes": _nodes_to_plain(),
		"layers": _layers_to_plain(),
	}


func _nodes_to_plain() -> Dictionary:
	var out := {}
	for k in nodes.keys():
		var n: Dictionary = nodes[k]
		out[str(k)] = {
			"id": int(n["id"]), "layer": int(n["layer"]), "slot": int(n["slot"]),
			"kind": str(n["kind"]), "risk": int(n["risk"]),
			"next": (n["next"] as Array).duplicate(), "prev": (n["prev"] as Array).duplicate(),
		}
	return out


func _layers_to_plain() -> Array:
	var out: Array = []
	for L in layers:
		var layer: Array = []
		for v in (L as Array):
			layer.append(int(v))
		out.append(layer)
	return out
