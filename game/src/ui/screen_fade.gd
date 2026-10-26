class_name ScreenFade
extends CanvasLayer
## Screen transition: the screen goes black at once, the swap runs under it, the new screen fades in.
## Input is blocked for the whole transition; runs while paused and ignores bullet time.

const IN_TIME := 0.15

var _rect := ColorRect.new()
var _busy := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color.BLACK
	_rect.size = Layers.VIEW
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

## Runs swap() under black. A request during a running transition is ignored.
func play(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect.modulate.a = 1.0
	await RenderingServer.frame_post_draw   # the black frame is on screen before the swap
	swap.call()
	# building the new screen can take a long frame (a stage: ~0.7 s); a tween started in it would spend that whole
	# frame at once and skip the fade, so it starts once a normal frame has gone by
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tw := _tween()
	tw.tween_property(_rect, "modulate:a", 0.0, IN_TIME)
	await tw.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func busy() -> bool:
	return _busy

func _input(_e: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()

func _tween() -> Tween:
	return create_tween().set_ignore_time_scale().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
