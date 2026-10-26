@tool
class_name GaugeSlider
extends Control
## A setting drawn like the boss HP bar (ui/components/gauge_slider.tscn): caption, frame and red gauge.
## `steps` = how many steps above 0 (20 = 5 % each); `labels` (one per value, 0..steps) names the value beside the bar,
## empty = no text. Click / drag on the bar, or left / right while it has the pad / keyboard focus.

signal value_changed(value: int)

@export var caption := "":
	set(v):
		caption = v
		if is_node_ready():
			$Caption.text = v
@export var steps := 20:
	set(v):
		steps = maxi(v, 1)
		if is_node_ready():
			_show()
@export var labels: PackedStringArray:
	set(v):
		labels = v
		if is_node_ready():
			_show()

var value := 0:
	set(v):
		value = clampi(v, 0, steps)
		if is_node_ready():
			_show()

const HOT := Color(1, 0.6, 0)   ## caption colour on hover / focus (a hovered set_btn)

func _ready() -> void:
	$Caption.text = caption
	_show()
	mouse_entered.connect(_tint.bind(true))
	mouse_exited.connect(func(): _tint(has_focus()))
	focus_entered.connect(_tint.bind(true))
	focus_exited.connect(_tint.bind(false))

func _show() -> void:
	var g: TextureProgressBar = $Gauge
	g.max_value = steps
	g.value = value
	$Level.text = labels[value] if value < labels.size() else ""

func _tint(on: bool) -> void:
	$Caption.add_theme_color_override(&"font_color", HOT if on else Color.WHITE)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_set_from_mouse(e.position.x)
		accept_event()
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_set_from_mouse(e.position.x)
		accept_event()
	elif e.is_action_pressed(&"ui_left", true):
		_change(value - 1)
		accept_event()
	elif e.is_action_pressed(&"ui_right", true):
		_change(value + 1)
		accept_event()

func _set_from_mouse(x: float) -> void:
	var g: Control = $Gauge
	_change(roundi(clampf((x - g.position.x) / g.size.x, 0.0, 1.0) * steps))

func _change(v: int) -> void:
	v = clampi(v, 0, steps)
	if v == value:
		return
	value = v
	value_changed.emit(value)
