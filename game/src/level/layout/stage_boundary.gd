@tool
class_name StageBoundary
extends StaticBody2D
## The stage's outer walls (Layout/Walls/Boundary). Its child `Area` (a disabled CollisionShape2D with a
## RectangleShape2D) is the playing field: select it and drag the corner / edge handles like any collision shape.
## Solid walls are built just outside its left, right and top edges and, unless `open_bottom` (a stage with pits or
## water to fall into), its bottom. `Area` itself never collides.

const THICK := 200.0   ## walls reach this far outside the area, so nothing tunnels through them

@export var open_bottom := false:
	set(v):
		open_bottom = v
		_rebuild()

var _built := Rect2()

func _ready() -> void:
	collision_mask = 0
	set_process(Engine.is_editor_hint())   # in the editor: follow the handles
	_rebuild()

func _process(_dt: float) -> void:
	if area_rect() != _built:
		_rebuild()

## The playing field in this node's space (the `Area` rectangle).
func area_rect() -> Rect2:
	var a := get_node_or_null("Area") as CollisionShape2D
	if a == null or not (a.shape is RectangleShape2D):
		return Rect2()
	var s: Vector2 = (a.shape as RectangleShape2D).size
	return Rect2(a.position - s / 2.0, s)

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var a := get_node_or_null("Area") as CollisionShape2D
	if a != null:
		a.disabled = true
	for c in get_children():
		if c.has_meta(&"boundary"):
			remove_child(c)
			c.free()
	var r := area_rect()
	_built = r
	if r.size == Vector2.ZERO:
		return
	var t := THICK
	var sides: Array[Rect2] = [
		Rect2(r.position.x - t, r.position.y - t, t, r.size.y + 2.0 * t),   # left
		Rect2(r.end.x, r.position.y - t, t, r.size.y + 2.0 * t),            # right
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2.0 * t, t),   # top
	]
	if not open_bottom:
		sides.append(Rect2(r.position.x - t, r.end.y, r.size.x + 2.0 * t, t))
	for s in sides:
		var shape := RectangleShape2D.new()
		shape.size = s.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = s.get_center()
		cs.set_meta(&"boundary", true)   # built here, never saved into the scene (no owner)
		add_child(cs)
