extends CharacterBody2D
## Enemy —— 入侵者（怪物）：自动追踪玩家核心，撞击造成核心伤害并自毁。
## kind: 0 普通 / 1 重甲 / 2 快速。数值随波次轻微缩放。

class_name Enemy

const BASE_STATS := {
	0: {"hp": 2, "speed": 72.0, "dmg": 12, "radius": 10.0},
	1: {"hp": 6, "speed": 46.0, "dmg": 24, "radius": 12.0},
	2: {"hp": 1, "speed": 122.0, "dmg": 8, "radius": 8.0},
}

var kind := 0
var hp := 1
var dmg := 10
var speed := 60.0
var radius := 10.0
var _flash := 0.0
var _sprite: Sprite2D


static func build_kind(wave: int) -> int:
	var r := randf()
	if wave >= 3 and r < 0.20:
		return 2
	if wave >= 2 and r < 0.42:
		return 1
	return 0


func setup(k: int, wave: int) -> void:
	kind = k
	var st: Dictionary = BASE_STATS[kind]
	radius = float(st["radius"])
	var scale_p := 1.0 + float(wave - 1) * 0.08
	hp = maxi(1, int(round(float(st["hp"]) * scale_p)))
	speed = float(st["speed"]) * (1.0 + float(wave - 1) * 0.035)
	dmg = int(st["dmg"])
	_update_visual()


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = radius
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	add_child(_sprite)
	_update_visual()


func _update_visual() -> void:
	if _sprite == null:
		return
	_sprite.texture = PixelArt.enemy_tex(kind)
	var base_tex := 22.0
	_sprite.scale = Vector2(radius * 2.0 / base_tex, radius * 2.0 / base_tex)


func _physics_process(delta: float) -> void:
	if not GameState.active:
		return
	var target: Node2D = get_tree().get_first_node_in_group("player")
	if target == null:
		return
	var delta_v: Vector2 = target.global_position - global_position
	var dist := delta_v.length()
	if dist > 0.001:
		velocity = delta_v / dist * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if _flash > 0.0:
		_flash -= delta
		_sprite.modulate = Color(3.0, 3.0, 3.0) if _flash > 0.0 else Color.WHITE
	else:
		_sprite.modulate = Color.WHITE

	# 撞击判定（移动后重算，先于死亡清理）
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p != null:
		var d2: Vector2 = p.global_position - global_position
		var r_sum: float = get_radius() + (p.get_radius() if p.has_method("get_radius") else 13.0)
		if d2.length() < r_sum:
			GameState.damage_core(dmg)
			queue_free()


func get_radius() -> float:
	return radius


func take_damage(v: int) -> void:
	hp -= v
	_flash = 0.09
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.add_kill()
	EventBus.enemy_killed.emit(global_position)
	queue_free()
