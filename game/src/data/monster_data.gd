class_name MonsterData
extends Resource
## Monster tuning (entities/monsters/monster<id>/monster<id>.tres; a stage's own numbers in monster<id>_<stage>.tres).
## Units: px, seconds.

@export var id := 0
@export var display_name := ""
@export var puppet := ""
@export var is_boss := false

@export_group("Stats")
@export var speed := 0.0
@export var hp := 1
@export var def := 0
@export var mdef := 0.0
@export var exp := 0
@export var souls := 0             ## red orb power ("gxp" in the original)

@export_group("AI")
@export var sight := 300.0
@export var attack_range := 80.0
@export var attack_chance := 50    ## percent per attack check
@export var attack_check := 1.5    ## seconds between attack decisions in range
@export var think_walk_at := 0.5   ## wander: seconds into the cycle when a direction is picked
@export var walk_times := PackedFloat32Array([3.0, 4.0])
@export var wander_rest := 1.0     ## random extra idle after a walk
@export var knockback_decay := 0.0 ## velocity multiplier per second while faster than walk speed
@export var gravity := 0.0
@export var hp_bar_time := 2.0
@export var hp_bar_fade := 1.0
@export var move_while_attacking: PackedStringArray

@export_group("Drops")
@export var equip_chance := 0.15
@export var stone_rate := 0.0     ## boss: chance of a 1级强化石
@export var equip_drops: PackedStringArray

@export var attacks: Dictionary = {}   ## action -> AttackData

@export_group("Behaviour")
@export var brain_type := ""           ## shared brain script (boss_b, boss_d ...); brain_<id>.gd wins if present
@export var brain := {}                ## brain parameters (frames already converted to seconds)
@export var behind := false            ## drawn right above the background, behind every character (MainGame.createMonster)
@export var is_prop := false           ## scenery that can be hit: no damage numbers, HP bar, exp or combo
@export var immovable := false         ## not pulled / pushed (totems, props)

const DIR := "res://entities/monsters"
static var _folders := {}   ## monster id -> its folder name (the pinyin of its name: shouyeren), from the data files

## The folder of monster `id` under entities/monsters ("" if there is none).
static func folder(id: int) -> String:
	if _folders.is_empty():
		for d in ResourceLoader.list_directory(DIR):
			var f := d.trim_suffix("/")
			var md := load(DIR.path_join(f).path_join(f + ".tres")) as MonsterData
			if md:
				_folders[md.id] = f
	return _folders.get(id, "")

## The data file of monster `id` ("" stage = the base numbers, else the stage's own: <folder>_<stage>.tres).
static func path(id: int, stage := "") -> String:
	var f := folder(id)
	return DIR.path_join(f).path_join(f + ("" if stage == "" else "_" + stage) + ".tres")

## Every monster id there is.
static func ids() -> Array:
	folder(0)
	var a := _folders.keys()
	a.sort()
	return a
