class_name PauseMenu
extends Control
## 设置, a page of the TabMenu (ui/set_menu/set_menu.tscn): continue, the music / sound / ambience volumes and the
## screen shake / pad rumble levels (GaugeSlider: volumes in 5 % steps, shake and rumble 关 / 弱 / 中 / 强), help, back
## to the map, back to the title.

signal to_map
signal to_menu

const VOLUME_STEPS := 20   ## 5 % a step
const BUSES := {"MusicVolume": &"Music", "SfxVolume": &"SFX", "AmbienceVolume": &"Ambience"}

var in_stage := true   ## false on the map: no 继续游戏 / 返回地图
var on_title := false  ## the title's 设置: no 游戏帮助 / 返回标题界面 either (the title has its own 游戏帮助)
var _ui: UiLayout

func _ready() -> void:
	_ui = UiLayout.create("set_menu")
	add_child(_ui)
	for b in ["BtnContinue", "BtnBackToMap"]:
		_ui.piece(b).visible = in_stage
	for b in ["BtnHelp", "BtnBackToTitle"]:
		_ui.piece(b).visible = not on_title
	for s in BUSES:
		var g: GaugeSlider = _ui.piece(s)
		g.steps = VOLUME_STEPS
		g.value = roundi(_bus_volume(BUSES[s]) * VOLUME_STEPS)
		g.value_changed.connect(func(v: int): Snd.set_bus_volume(BUSES[s], float(v) / VOLUME_STEPS))
	var shake: GaugeSlider = _ui.piece("ScreenShake")
	shake.value = Feel.screen_shake
	shake.value_changed.connect(func(v: int):
		Feel.screen_shake = v
		Feel.save_settings()
		if Level.current:
			Level.current.add_trauma(0.4))   # a sample of the new strength
	var rumble: GaugeSlider = _ui.piece("PadRumble")
	rumble.value = Feel.pad_rumble
	rumble.value_changed.connect(func(v: int):
		Feel.pad_rumble = v
		Feel.save_settings()
		Feel.rumble(0.5, 0.15))
	_ui.button_pressed.connect(_on_button)

static func _bus_volume(bus: StringName) -> float:
	match bus:
		&"Music": return Snd.music_volume
		&"SFX": return Snd.sfx_volume
	return Snd.ambience_volume

func _on_button(b: String) -> void:
	match b:
		"BtnContinue": TabMenu.close_of(self)
		"BtnBackToMap": to_map.emit()
		"BtnBackToTitle": to_menu.emit()
		"BtnHelp": add_child(HelpPanel.new())
