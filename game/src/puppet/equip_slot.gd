@tool
class_name EquipSlot
extends Node2D
## A puppet part whose look depends on the equipped item.
## `variants` maps equipment show-id -> PackedScene (static sprites, or a looping AnimationPlayer for wings).
## cloth_ex slots show variant (cloth id) and are empty for ids without an entry.

@export_enum("cloth", "cloth_ex", "weapon", "wing") var kind := "cloth"
@export var variants: Dictionary = {}
@export var variant_id := 1:
	set(v):
		variant_id = v
		if is_inside_tree():
			_apply()

var _inst: Node
## A variant that is itself animated along the action (metadata follow_action, e.g. 普通的袈裟 bending with 唐僧 in
## 玄冰阵): its "follow" animation is held at the playing action's time.
var _follow: AnimationPlayer
var _puppet: Puppet

func _ready() -> void:
	set_process(false)
	_apply()

func _process(_delta: float) -> void:
	if _follow == null or _puppet == null or _puppet.anim == null:
		return
	_follow.seek(_puppet.anim.current_animation_position, true)

func set_variant(id: int) -> void:
	variant_id = id

func _apply() -> void:
	if _inst:
		_inst.queue_free()
		_inst = null
	_follow = null
	set_process(false)
	var ps: PackedScene = variants.get(variant_id)
	if ps:
		_inst = ps.instantiate()
		add_child(_inst)
		if _inst.has_meta(&"follow_action"):
			var n := get_parent()
			while n != null and not n is Puppet:
				n = n.get_parent()
			_puppet = n
			_follow = _inst.get_node("Anim")
			_follow.play(&"follow")
			_follow.pause()
			set_process(_puppet != null)
		if material != null:   # an effect on the slot (halo, tint) applies to its sprites
			for c: CanvasItem in _inst.find_children("*", "CanvasItem", true, false) + [_inst]:
				c.use_parent_material = true   # every level down to the sprites takes the slot's effect
