# zmxy2-remake — 造梦西游2：十殿阎罗篇 Godot 重制版

Godot 4.7 (Forward+, 2D MSAA) remake of the Flash game 《造梦西游2》. The original's numbers and behaviour are kept; everything is rebuilt natively.
Playable: 孙悟空 / 唐僧 / 猪八戒 (八戒 unlocks with the first 红孩儿 kill). Stage folders are the pinyin of the stage's name (`guicheng` = 1-1 鬼城 … `zhuanlundian` = 4-1, hidden `baigumijing` … `guoqinghuodong`, `leitai` = debug arena); `Level.STAGES` maps stage numbers to them.
Answers to the user: Simplified Chinese. Deleting files: Recycle Bin (`bash tools/trash.sh <path>`), never `rm`.

## Layout
| Path | What |
|---|---|
| `game/` | the Godot project, one folder per thing: everything of a hero, monster, stage or UI screen (scene, animations, numbers, pictures, its own script and effects) sits together. Shared code is in `src/` |
| `game/entities/heroes/<role>/` | `<role>.tscn` + `<role>_actions.tres` (actor scene), `<role>.tres` (HeroData: numbers, moves), `hero_<role>.gd` (唐僧 / 八戒), `tex/`, `slots/` (equipment variants), `bag_<role>/` (the bag portrait), `effects/<name>/` (its own effects, bullets) |
| `game/entities/monsters/<name>/` | folder = the pinyin of the monster's name (`shouyeren`; forms numbered: `zhuanlunwang_1`; names from the user when the data has none): `<name>.tscn` + `_actions.tres`, `<name>.tres` (MonsterData with its `id`; `<name>_<stage>.tres` = a stage's own numbers), `<name>_brain.gd` (its AI, if not a shared template), `tex/`, `effects/<name>/` (its bullets and effects). `MonsterData.folder(id)` finds the folder |
| `game/entities/fabao/<id>/` | a 法宝: `<id>.tscn`, `fabao_<id>.gd`, `effects/` |
| `game/entities/{objects,items,effects}/<name>/` | stage mechanisms (scene with its script on the root), pickups (`potion_*`, `orb_*`), effects several things use (hit sparks, level-up, status effects, the tomb); an effect only one hero / monster / screen uses is in its `effects/` (`ui/hud/effects/gogo`) |
| `game/stages/<stage>/` | `<stage>.tscn` (scenery + playing field, see "Stage scenes"), `lighting.json` (its look), `<stage>.gd` (its special rules, if any), `tex/`; `stages/shared/` = pictures several stages use |
| `game/ui/<name>/` | a UI layout `<name>.tscn` (see "UI scenes"), its script and `tex/`; `ui/components/` reusable parts (stat, slot, buttons, gradients), `ui/shared/` shared pictures; `game/main.tscn` is the title screen |
| `game/src/` | shared code: `actors` (Actor, Hero, Monster, Fabao, `brains/` = MonsterBrain + shared templates), `combat`, `core` (game_state, layers, rng, save, forge, controls), `data` (resource classes), `items`, `level` (Level, StageLighting, shaders, `layout/`), `puppet`, `screens` / `ui` (shared screen code) |
| `game/src/core/layers.gd` | screen size (940x590) and z-order constants (`Layers.Z_*`): never use a raw `z_index` number |
| (no shared actor folder) | a picture belongs to whoever it was drawn for — `<owner>_…` in that owner's `tex/`; a boss that borrows another's move (平等王) or a copy of a hero (悟空怪 / 唐僧怪, which use the hero's own pictures) references it there |
| `game/assets/` | `items/<id>_fall.png` (item pictures: the drop picture, or `<id>_icon.png` = the original framed one when there is none), `fonts/`, `sounds/` |
| `game/data/` | global tables: `equipment.tres` (every item; ids = full pinyin of the name), `drops.tres`, `stages.json` — edit them directly |
| `.pi/skills/zmxy2-entity-migration/` | how to move / rename files and ids in this layout without breaking references (`tools/move_entity.js`), and the naming rules |
| `tools/extract/fix_scene_uids.js` | `--fix` refreshes stale texture uids in scenes ("missing dependency"). Pictures are named `<owner>_<use>.png` (`wukong_hit1_part3`, `tab_menu_background`) |
| `.claude/skills/stage-rework/` | how to rework a stage's scene and design its look |

## Run / test / export
- Run: open `game/` in Godot 4.7 (F5). Debug builds: `~` console (items, teleport, boss fight), keys 1 refill / 2 hit boxes / 3 test gear / 4 kill all / 5 restart / 6 invincible / 7 invulnerable monsters glow yellow (temporary). F11 fullscreen. In a stage: C bag, V skills, B fabao, Esc / Tab settings — one menu (`TabMenu`, ui/tab_menu/tab_menu.tscn) with tabs 背包 / 技能 / 法宝 / 设置; the pad switches tabs with LT / RT.
- Web build: `bash tools/export_web.sh` (preset "Web", single-threaded, saves in the browser's IndexedDB). It uses the loading shell `game/web_shell/shell.html` (the original loading picture and bar) and splits the pack into content-defined chunks (`tools/web_chunks.js` → `web/chunks/*.bin` + `web/pck.json`) and writes `web/sw.js`, a service worker that rebuilds `index.pck` from the chunks in the browser cache: an update downloads only the chunks that changed (a script edit is ~1 MB); test with `node tools/serve_web.js` → http://localhost:8060/. `web/` is committed (pck / wasm via LFS) and is published to GitHub Pages by `.github/workflows/pages.yml` on every push that changes it. The web export templates are in the 4.7.2 template bundle.
- Panels fade in/out with `UiFade` (`src/ui/ui_fade.gd`); screen changes (title → role select → map → stage) go through `ScreenFade` in `main.gd`.
- Checks (headless, exit code = result, all run at --fixed-fps 60 so game time does not wait for real time, 6 at once): `bash tools/run_checks.sh [group|name]` — groups `hero` (role/feel), `monster` (ai_trace + loot; `MONSTERS=45,58` limits the AI traces), `ui` (bag/forge/pad), `stage` (camera/walk/stage_test), `fabao`. Run the group that matches the change; the full set (~3 min) only before a merge or an export.
- Who uses a file (the editor's View Owners): `bash tools/find_refs.sh <file>...` (by res:// path and uid); run it before deleting a replaced texture or scene.
- Screenshots: `godot --path game --position 6000,6000 res://tools/light_shot.tscn -- <area,level> <out.png> <camera x> [monster ids] [wait s] [strike s]` (stage with its lighting); also `game/tools/{ui_shot,panel_shot,stage_shot,puppet_shot,puppet_strip,seam_check,skill_shot,fx_gallery}`.
- Skill timelines: `godot --headless --path game res://tools/skill_probe.tscn -- <keys> [air] [role=<name>]` logs the hero's state every physics tick (compare before / after a change to the hero code).
- Export: `bash tools/build.sh` → `build/zmxy2_<branch>_v<version>.exe` (4.7.2 export templates).
- Saves: `user://saves/slot_N.json` (`core/save_game.gd`). Items are `Item` objects. Gameplay randomness only through `Rng` (weather uses its own generator).
- Godot headless: `class_name` scripts need `godot --headless --path game --import` first; autoloads do not exist under `-s` scripts (use a tiny scene runner); Windows shell heredocs eat backslashes and many files are CRLF — edit with the Edit tool or scripts that split on `\r\n`.
- Throw-away runner scenes must quit even when they fail: first line of `_ready()` = `get_tree().create_timer(<budget s>, true, false, true).timeout.connect(get_tree().quit.bind(2))`, then the work, then `get_tree().quit()`. Always run them under `timeout`.
- Live debugging (godot-ai MCP plugin, editor open): `project_run` the game, then `game_manage` ops `suspend` / `next_frame` / `resume` (pause and step frames), `get_scene_tree` / `get_node_info` (runtime state), `input_action` / `input_sequence` (frame-timed input), `editor_manage` op `game_eval` (run GDScript in the running game), `editor_screenshot` source `game`, `logs_read` source `game`.

## Data
- The scenes (stages, actors, UI, objects) and `game/data/` are hand-edited and are the source of truth: there are no generators for them any more.
- Never scrub the 4399 logo embedded inside a texture.

## Stage scenes
Every stage's scenery is an editor scene `stages/<stage>/<stage>.tscn` that the user arranges by hand (`git status` shows his uncommitted edits — never overwrite them). The playing field is its `Layout` node; the look comes from `stages/<stage>/lighting.json`.
- `Scenery/Guides` editor-only reference lines (dropped at run time); `Background/Sky` (CanvasLayer -2) the sky picture, scrolled by `Level` over the stage length; `Art/{Far 0.8, Middle 0.9, Near 1.0}` `Parallax2D` layers; `Ground` the floor art; `Objects` mechanisms.
- `Layout` (`StageLayout`, `size` = the stage's extent): `Walls/Ground` the floors and ramps (one StaticBody2D, collision layer 1), `Walls/Platform*` one-way floating platforms (layer 2) and `Walls/HiddenWall*` walls a stage script switches on (AnimatableBody2D); `Stops/Stop*` camera stops (`CameraStop`: the screen locks with its right edge at the stop's x, `back` = how far left the hero may go), each with `Spawn*` children (`MonsterSpawn`: `monster` id, `delay`, `interval`, `total`, `boss`); `ExitDoor` the exit portal with its `EnterZone`.
- The layering is the user's job: never decide depth for him. A piece moved to a layer has x = scroll_scale × original x.
- Every bitmap placement of the original is its own `Sprite2D` (named `<bitmap>_<n>`, painting order); nothing is merged. A row of one picture laid edge to edge (floor, haze) is ONE `TextureRect`: repeat on, stretch Tile, texture filter Nearest.
- Mechanisms are scenes of their own with a script on the root and `@export` parameters, instanced under `Objects` at their real world position (no parallax), built from plain Sprite2D + AnimationPlayer — **never a Puppet** (parts are hidden in the editor). `Level` moves `Objects` into the world; the stage script (`stages/<stage>/<stage>.gd`) finds them there.
- 5-1 (and boss rooms) have one painting + a floor: 2 nodes. 2-2 (`panguandian`) was ONE baked 4700x522 JPEG in the original; it was rebuilt from the loose bitmaps of 2-3; only the boss end (x ≥ 3745) stays a crop of the baked bitmap.
- Textures: `stages/<stage>/tex/<stage>_<layer>_<n>.png`; shared ones in `stages/shared/`.

## Actor scenes
Every animated body is a **hand-edited** scene `<name>.tscn`: in its folder under `entities/` (found by file name: `Puppet` indexes every scene named like its folder). Moving or renaming files: see the `zmxy2-entity-migration` skill.
- Heroes, monsters and potions: the root is the logic body itself (`CharacterBody2D` with `hero.gd` / `hero_bajie.gd` / `hero_tangseng.gd` / `monster.gd` / `potion.gd`), with the art `Puppet` and the body collider `Body` as children; `Hero.create()` / `Monster.create(data)` / `Potion.spawn()` instantiate the scene. `Puppet.create(name)` returns just the art (glows, shadows, previews).
- Effects, bullets, mechanisms: the root is the `Puppet` (`src/puppet/puppet.gd`); `Puppet.create(name)` instantiates it.
- Inside a `Puppet`: `Poses/<Action>` = the parts of one action (only the playing one is visible; a scene with one action has no `Poses`, its parts sit under the root); `EquipSlot` parts change with the equipment (variants in the entity's `slots/`).
- `Hitbox` / `Hurtbox` `Shape` tracks = attack and hurt boxes (position, size, disabled per key; any shape).
- Method tracks `ev_*` = gameplay events: `ev_new_hit` (a new hit may land), `ev_finished` (action over), `ev_set_vx` / `ev_set_vy` / `ev_set_vx_forward` (px/s) and `ev_scale_vx` (factor) = movement, `ev_stop_move`, `ev_call(name)` = skill hook, `ev_grounded_call(name)` = only when on the floor, `ev_boss_dead_fx`, `ev_shake`.
- An action lasts its animation length; tweak by moving keys / changing the length in the Animation panel. The animations are the text file `<name>_actions.tres`.

## UI scenes
Every UI layout is a **hand-edited** scene `ui/<name>/<name>.tscn`; `UiLayout.create(name)` instantiates it. The nodes the code reaches are **scene-unique names** (`%Name`, "Access as Unique Name" in the editor): move them anywhere in the scene, but renaming one breaks its link. Every scene-unique button reports its click by its node name (`button_pressed("BtnClose")`). Gauges are a holder with a `Fill` TextureProgressBar; icons picked by number (HUD skill icons, the bag's level) are `IconSet` sprites (`icons` + `index`); the map's stages are Buttons with a `Picture` and a larger `HoverPicture`.
The 背包 / 法宝 attribute rows are instances of `ui/components/stat.tscn` (`caption`, `width`; the code fills the value with `set_value`); equipment sockets are `equipment_slot.tscn`, bag cells `slot.tscn`.

## Stage look (`StageLighting`)
`game/src/level/stage_lighting.gd` reads `stages/<stage>/lighting.json`; a stage without a file is drawn as the original. Every key is optional: `use` (another stage's file as the base), `scene` (tints of art/ground/far, rim light, feet fade), `layers` (per-layer blur/tint/rim/fade by node name), `body`/`shadow` (actor light, soft shadow), `fog`, `moon`, `rain`, `lightning`, `lamps`, `glows`, `sway`, `ash` (floating particles), `stars`, `grade` (saturation, vignette, brightness).
Rim light / moon exist because 1-1…1-3 have a moon — they are not a general setting; a new stage's style is designed from scratch (what lights this place?). Draw order: far/sky −2, moon −1, world 0, mist 1, grade 2, HUD 3.

## Game-systems notes
- Monster AI: one `MonsterBrain` per monster (`entities/monsters/<name>/<name>_brain.gd`, templates `src/actors/brains/boss_b.gd` / `boss_d.gd`), parameters in `MonsterData.brain`. Hits: Hitbox/Hurtbox Area2D pairs keyed by the animation, de-duplicated per swing by serial (`combat/hit_dealer.gd`).
- Activities (中秋 / 七夕 / 国庆) have a panel with on/off switches; 贪/嗔/痴 stacking, forge (`core/forge.gd`), fabao (`entities/fabao/`), skill/shop screens are in `ui/`.
- Docs of the original's analysis were removed from the tree; they live in git history (`git log --diff-filter=D --name-only -- docs`).

## Branches
`main` — released remake (remake 0.1: the scene-based remake with the new stage looks; earlier releases were v1.0…v1.3.1).

## Fonts

`game/assets/fonts/` keeps the full fonts. `tools/build.sh` and `tools/export_web.sh` cut them down to the characters
the game can show (every character in the game's scenes, scripts and data, plus ASCII and common CJK punctuation) with
`tools/subset_fonts.py` (fontTools; conda python), export, then put the full fonts back (backup in tools/dl/fonts_full;
`python tools/subset_fonts.py restore` if an export was interrupted). Text typed in at run time (the debug console) can
only show those characters.

## Game feel

- Input buffer: an attack / skill / jump press is kept `HeroData.input_buffer` (0.12 s) and done as soon as it can be (also a jump pressed just before landing). Hit, death and the rage transform clear it.
- Turning: a move never turns while it plays; the next move starts facing the held direction (back pressed during combo hit 4 sends hit 5 the other way).
- Per attack (`AttackData`, group Feel): `hitstop` (s; x1.5 on a crit), `hitstop_once` (multi-hit moves stop on their first hit only), `shake` (camera trauma 0..1, once per round of hits), `rumble` (gamepad). Hit-stop freezes the whole fight (`Level.world`: actors, bullets, effects) while the level, camera shake, HUD and menus go on; it never touches `Engine.time_scale` and is skipped during a boss's bullet time.
- Camera shake: trauma model in `Level` (offset = 24 px × trauma², smooth noise, 1.8 trauma/s decay). Pause menu: 画面震动 / 手柄震动 switches (`src/core/feel.gd`, saved in user://settings.cfg); pad rumble runs at half strength (`Feel.RUMBLE_SCALE`).
- Sounds: hero move sounds and hit sounds on monsters vary within ±10 % (`Snd.sfx_varied`).
