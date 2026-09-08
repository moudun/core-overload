extends CharacterBody2D
## CorePlayer —— 玩家控制的地牢核心：WASD/方向键移动 + 鼠标左键自动射击。
## 所有 Build 数值（射速/伤害/弹道/移速）由拾取卡牌累加，可叠加。

const RADIUS := 13.0
const BASE_SPEED := 320.0
const BASE_FIRE_CD := 0.17
const BASE_DAMAGE := 12

var speed := BASE_SPEED
var fire_cd := BASE_FIRE_CD
var damage := BASE_DAMAGE
var projectiles := 1
var _cd := 0.0
var _look := Vector2.RIGHT
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 0  # 不参与物理阻挡，靠边界钳制

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = RADIUS
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.player_core_tex()
	_sprite.z_index = 5
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	_cd = maxf(0.0, _cd - delta)

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
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	var vp := get_viewport_rect()
	global_position = global_position.clamp(Vector2(30, 62), Vector2(vp.size.x - 30, vp.size.y - 30))

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_shoot()


func _process(delta: float) -> void:
	_t += delta
	var p := 1.0 + 0.06 * sin(_t * 5.0)
	if _sprite != null:
		_sprite.scale = Vector2(p, p)


func _try_shoot() -> void:
	if _cd > 0.0:
		return
	_cd = fire_cd
	_look = get_global_mouse_position() - global_position
	if _look.length() < 0.001:
		_look = Vector2.RIGHT
	_look = _look.normalized()
	var base_ang := _look.angle()
	for i in projectiles:
		var off := (float(i) - (projectiles - 1) * 0.5) * 0.14
		_fire_one(base_ang + off)


func _fire_one(ang: float) -> void:
	var dir := Vector2.from_angle(ang)
	var b: Node = _make_bullet()
	get_parent().add_child(b)
	b.global_position = global_position + dir * (RADIUS + 12.0)
	b.setup(dir, damage)
	EventBus.fx_shoot.emit(b.global_position, dir)


func _make_bullet() -> Node:
	var script: GDScript = load("res://scripts/entities/Bullet.gd")
	return script.new()


func get_radius() -> float:
	return RADIUS


func reset_build() -> void:
	speed = BASE_SPEED
	fire_cd = BASE_FIRE_CD
	damage = BASE_DAMAGE
	projectiles = 1
	_cd = 0.0
	EventBus.player_stats_changed.emit()
