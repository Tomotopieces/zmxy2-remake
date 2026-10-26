class_name UiFade
extends RefCounted
## Very quick fade of a full-screen panel (a CanvasLayer has no modulate: its CanvasItem children fade).
## Runs while the game is paused and ignores bullet time.

const IN_TIME := 0.1
const OUT_TIME := 0.1

## Call at the end of the panel's _ready().
static func fade_in(panel: CanvasLayer) -> void:
	Snd.ui()
	var items := _items(panel)
	for c in items:
		c.modulate.a = 0.0
	# the frame that built the panel is often long; a tween started in it would spend that frame at once and skip the fade
	await panel.get_tree().process_frame
	await panel.get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var tw := _tween(panel)
	for c in items:
		if is_instance_valid(c):
			tw.tween_property(c, "modulate:a", 1.0, IN_TIME)

## Use instead of queue_free(): the panel stops taking input, fades out, then is freed.
static func close(panel: CanvasLayer) -> void:
	if panel.has_meta(&"closing"):
		return
	panel.set_meta(&"closing", true)
	Snd.ui()
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := _tween(panel)
	for c in _items(panel):
		tw.tween_property(c, "modulate:a", 0.0, OUT_TIME)
	tw.chain().tween_callback(panel.queue_free)

static func _tween(panel: CanvasLayer) -> Tween:
	var tw := panel.get_tree().create_tween().set_parallel().set_ignore_time_scale()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tw

static func _items(panel: CanvasLayer) -> Array:
	return panel.get_children().filter(func(c): return c is CanvasItem)
