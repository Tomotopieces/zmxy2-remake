class_name Feel
extends RefCounted
## Game-feel switches and the gamepad rumble.
## screen_shake / pad_rumble are player settings (设置 page, saved in user://settings.cfg [feel]): a level
## 0 = off, 1 = weak, 2 = medium (default), 3 = strong; LEVEL_SCALE is what each level multiplies the effect by.

const SETTINGS := "user://settings.cfg"
const LEVEL_SCALE: Array[float] = [0.0, 0.5, 1.0, 1.5]

static var screen_shake := 2
static var pad_rumble := 2
static var hitstop_on := true   ## off for frame-exact test runs (tools/ai_trace)

static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		screen_shake = _level(cf.get_value("feel", "screen_shake", screen_shake))
		pad_rumble = _level(cf.get_value("feel", "pad_rumble", pad_rumble))

## A saved level (older settings saved on / off: on = medium).
static func _level(v: Variant) -> int:
	if v is bool:
		return 2 if v else 0
	return clampi(int(v), 0, 3) if v is int or v is float else 2

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("feel", "screen_shake", screen_shake)
	cf.set_value("feel", "pad_rumble", pad_rumble)
	if cf.save(SETTINGS) != OK:
		push_warning("settings could not be saved")

const RUMBLE_SCALE := 0.5   ## overall pad rumble strength

## Rumbles every connected pad: strength 0..1 before RUMBLE_SCALE (the heavy motor; the light one at 60 %).
static func rumble(strength: float, seconds: float) -> void:
	if pad_rumble == 0:
		return
	var s := minf(strength * RUMBLE_SCALE * LEVEL_SCALE[pad_rumble], 1.0)
	if OS.has_feature("web"):
		# Godot's web build has no pad vibration: the browser's Gamepad API rumbles the pads instead
		JavaScriptBridge.eval(WEB_RUMBLE % [int(seconds * 1000.0), s, s * 0.6], true)
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, s * 0.6, s, seconds)

const WEB_RUMBLE := """for (const p of navigator.getGamepads ? navigator.getGamepads() : []) {
	if (p && p.vibrationActuator) p.vibrationActuator.playEffect('dual-rumble',
		{duration: %d, strongMagnitude: %f, weakMagnitude: %f}).catch(() => {});
}"""
