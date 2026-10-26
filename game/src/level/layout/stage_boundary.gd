@tool
class_name StageBoundary
extends StaticBody2D
## The stage's outer walls (Layout/Walls/Boundary): the inside of `rect` is the playing field; solid walls are built
## along its left, right and top edges and, unless `open_bottom` (a stage with pits or water to fall into), its bottom.
## Edit `rect` in the inspector; the orange frame in the editor is its outline.

const THICK := 200.0   ## walls reach this far outside the rect, so nothing tunnels through them

@export var rect := Rect2(0, 0, 940, 520):
	set(v):
		rect = v
		_rebuild()
@export var open_bottom := false:
	set(v):
		open_bottom = v
		_rebuild()

func _ready() -> void:
	collision_mask = 0
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta(&"boundary"):
			remove_child(c)
			c.free()
	var r := rect
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
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(rect, Color(1, 0.55, 0), false, 3.0)
