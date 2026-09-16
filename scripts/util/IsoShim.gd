class_name IsoShim
extends Node2D
## IsoShim —— 等距投影载体。
##
## 把它挂在任意「逻辑坐标节点」下（或自己指定一个逻辑坐标），它每帧把自己的
## global_position 投影成等距屏幕坐标。于是它的**子节点就可以直接按等距屏幕
## 坐标摆放**，完全不需要知道原来那是一张俯视图。
##
## 这样做的意义：物理 / 碰撞 / AI / 房间生成全部跑在原来的 1:1 逻辑坐标里，
## 一行都不用改；被换掉的只有「画在哪」这一层。
##
## 用法：
##   var view := IsoShim.follow_owner(self, 0, 14.0)   # 跟随本节点，带 14px 落影
##   view.add_child(sprite)                            # sprite.position 直接用屏幕偏移
##
## 注意：
##   * 本节点的 z_as_relative 关掉，所以它的 z_index 是「全场绝对深度」；
##     子节点保持 z_as_relative 开启，于是它们的 z_index 叠在落位深度之上。
##   * follow_parent=false 时用 logical 手动定位（静态道具 / 一次性残影）。

## true = 每帧读取父节点的逻辑坐标；false = 使用 logical 字段
var follow_parent := true
## 手动指定的逻辑坐标（follow_parent=false 时生效）
var logical := Vector2.ZERO
## 叠在深度排序 z 上的偏移。负值 = 压在地面贴花层，正值 = 略靠前
var z_base := 0
## >0 时自动挂一块等距菱形落影，单位是屏幕像素的横向半径
var footprint := 0.0
## 落影不透明度
var shadow_alpha := 0.34

var _shadow: Polygon2D = null


func _ready() -> void:
	z_as_relative = false
	if follow_parent and get_parent() is Node2D:
		logical = (get_parent() as Node2D).global_position
	if footprint > 0.0:
		_make_shadow()


func _process(_delta: float) -> void:
	if follow_parent:
		var p := get_parent()
		if p is Node2D:
			logical = (p as Node2D).global_position
	global_position = Iso.to_screen(logical)
	z_index = Iso.z_of(logical) + z_base


## 换一个落影尺寸（半径按屏幕像素算）
func set_footprint(r: float, alpha: float = -1.0) -> void:
	footprint = r
	if alpha >= 0.0:
		shadow_alpha = alpha
	if is_inside_tree():
		_make_shadow()


func _make_shadow() -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = Polygon2D.new()
	var r := footprint
	# 2:1 等距菱形（纵向半高只有横向一半），和地板透视一致
	_shadow.polygon = PackedVector2Array([
		Vector2(0.0, -r * 0.5), Vector2(r, 0.0),
		Vector2(0.0, r * 0.5), Vector2(-r, 0.0)])
	_shadow.color = Color(0.0, 0.0, 0.0, shadow_alpha)
	_shadow.antialiased = false
	_shadow.z_index = -1
	_shadow.name = "Shadow"
	add_child(_shadow)


# ---------------- 构造助手 ----------------
## 跟随 owner 的逻辑坐标（绝大多数实体用这个）
static func follow_owner(owner_node: Node2D, z_base_v: int = 0, footprint_v: float = 0.0) -> IsoShim:
	var s := IsoShim.new()
	s.follow_parent = true
	s.z_base = z_base_v
	s.footprint = footprint_v
	owner_node.add_child(s)
	return s


## 钉死在某个逻辑坐标（静态道具 / 一次性残影用这个）
static func anchored(parent: Node2D, at: Vector2, z_base_v: int = 0, footprint_v: float = 0.0) -> IsoShim:
	var s := IsoShim.new()
	s.follow_parent = false
	s.logical = at
	s.z_base = z_base_v
	s.footprint = footprint_v
	parent.add_child(s)
	return s
