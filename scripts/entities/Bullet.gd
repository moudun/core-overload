extends Area2D
## Bullet —— V1.3 玩家弹头。
## 支持：散射 / 穿透 / 追踪 / 墙面反弹 / 落点爆炸 / 电弧连锁 / 附加状态 / 吸血。
## 碰撞层：layer=4（玩家弹），mask=2（敌人）+8（实体障碍）。

var damage := 10
var pierce := false
var homing := false
var turn_rate := 4.5
var bounces := 0
var chain := 0
var chain_range := 190.0
var chain_falloff := 0.75
var aoe := 0.0
var heal_on_hit := 0
var status_id := ""
var status_dur := 0.0
var status_power := 1.0
var weapon_id := "pulse"
var reflect_blocked := false

var _dir := Vector2.RIGHT
var _speed := 620.0
var _life := 1.2
var _hit_list: Array = []
var _view: IsoShim
var _sprite: Sprite2D
var _homing_target: Node2D = null


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 8
	monitoring = true
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 4.0
	shape.shape = circ
	add_child(shape)
	_view = IsoShim.follow_owner(self, 1, 3.0)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.add_child(_sprite)
	body_entered.connect(_on_body_entered)


func setup(dir: Vector2, dmg: int, speed: float, life: float,
		color: Color, is_pierce: bool = false, is_homing: bool = false,
		turn: float = 4.5, opts: Dictionary = {}) -> void:
	_dir = dir.normalized()
	damage = dmg
	_speed = speed
	_life = life
	pierce = is_pierce
	homing = is_homing
	turn_rate = turn
	bounces = int(opts.get("bounce", 0))
	chain = int(opts.get("chain", 0))
	chain_range = float(opts.get("chain_range", 190.0))
	chain_falloff = float(opts.get("chain_falloff", 0.75))
	aoe = float(opts.get("aoe", 0.0))
	heal_on_hit = int(opts.get("heal", 0))
	status_id = str(opts.get("status", ""))
	status_dur = float(opts.get("status_dur", 0.0))
	status_power = float(opts.get("status_power", 1.0))
	weapon_id = str(opts.get("weapon_id", "pulse"))
	if _sprite == null:
		_view = IsoShim.follow_owner(self, 1, 3.0)
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_view.add_child(_sprite)
	_sprite.texture = PixelArt.bullet_tex()
	_sprite.modulate = color
	_sprite.rotation = Iso.dir_to_screen(_dir).angle()
	var s := 1.0
	if aoe > 0.0:
		s = 1.5
	if bounces > 0:
		s = 1.25
	_sprite.scale = Vector2(s, s)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(self):
		return
	if homing:
		var target := _homing_target
		if target == null or not is_instance_valid(target):
			target = _nearest_enemy()
			_homing_target = target
		if target != null:
			var want := (target.global_position - global_position).normalized()
			var ang := _dir.angle_to(want)
			_dir = _dir.rotated(clampf(ang, -turn_rate * delta, turn_rate * delta))
			if _sprite != null:
				_sprite.rotation = Iso.dir_to_screen(_dir).angle()
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		if aoe > 0.0:
			_explode()
		queue_free()


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := 999999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		var d: float = en.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		if _hit_list.has(body):
			return
		_hit_list.append(body)
		_apply_hit(body)
		if aoe > 0.0:
			_explode()
			queue_free()
			return
		if not pierce and bounces <= 0:
			queue_free()
	elif body.is_in_group("solid"):
		if bounces > 0:
			bounces -= 1
			_bounce_off(body)
			return
		if GameState.has_modifier("reflective") and not reflect_blocked:
			_reflect()
			return
		if aoe > 0.0:
			_explode()
		queue_free()


func _reflect() -> void:
	reflect_blocked = true
	_dir = -_dir
	if _sprite != null:
		_sprite.rotation = Iso.dir_to_screen(_dir).angle()
	global_position += _dir * 14.0


func _bounce_off(body: Node2D) -> void:
	var n := (global_position - body.global_position).normalized()
	if n == Vector2.ZERO:
		n = Vector2.RIGHT
	_dir = _dir.bounce(n)
	if _sprite != null:
		_sprite.rotation = Iso.dir_to_screen(_dir).angle()
	global_position += _dir * 14.0


func _apply_hit(body: Node) -> void:
	var dmg := damage
	var applied := ""
	if body is Enemy:
		var en: Enemy = body
		dmg = int(round(float(damage) * en.damage_taken_mult()))
		en.take_damage(damage)
		applied = WeaponDB.status_of(weapon_id)
		if applied != "":
			var dur := status_dur
			if applied == Enemy.STATUS_FREEZE:
				dur += GameState.tag_freeze_bonus()
			en.apply_status(applied, dur, status_power)
		if GameState.has_protocol("cryo_field") and randf() < GameState.protocol_value("cryo_field"):
			en.apply_status(Enemy.STATUS_FREEZE, 1.6)
		if GameState.has_card("ice") and randf() < float(CardDB.info("ice").get("freeze_chance", 0.2)):
			en.apply_status(Enemy.STATUS_FREEZE, 2.0)
	else:
		body.take_damage(damage)
	EventBus.hit_enemy.emit(global_position, status_color(), dmg, dmg >= 40)
	if heal_on_hit > 0:
		GameState.heal(heal_on_hit)
	if GameState.has_protocol("vampiric") and dmg >= 40:
		GameState.heal(int(GameState.protocol_value("vampiric")))
	if chain > 0:
		_chain_to(body)


func status_color() -> Color:
	if _sprite != null:
		return _sprite.modulate
	return Color(1.0, 0.8, 0.4)


func _chain_to(from: Node) -> void:
	var from_node: Node2D = from
	var reached: Array = [from]
	var current := from_node
	var dmg := float(damage)
	var done := 0
	while done < chain:
		done += 1
		dmg *= chain_falloff
		var next: Node2D = null
		var best := chain_range
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or reached.has(e):
				continue
			var en: Node2D = e
			var d: float = en.global_position.distance_to(current.global_position)
			if d < best:
				best = d
				next = en
		if next == null:
			break
		var amount := maxi(1, int(round(dmg)))
		if next.has_method("take_damage"):
			next.take_damage(amount)
		if next is Enemy:
			(next as Enemy).apply_status(Enemy.STATUS_SHOCK, 3.0)
		EventBus.beam_fired.emit(current.global_position, next.global_position, Color(0.72, 0.62, 1.0))
		EventBus.hit_enemy.emit(next.global_position, Color(0.72, 0.62, 1.0), amount, false)
		reached.append(next)
		current = next


func _explode() -> void:
	var amount := maxi(4, int(round(float(damage) * 0.8)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e
		if en.global_position.distance_to(global_position) < aoe:
			if en.has_method("take_damage"):
				en.take_damage(amount)
			if en is Enemy:
				(en as Enemy).apply_status(Enemy.STATUS_BURN, 3.0)
			EventBus.hit_enemy.emit(en.global_position, Color(1.0, 0.55, 0.25), amount, false)
	EventBus.enemy_killed.emit(global_position)
