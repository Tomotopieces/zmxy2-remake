---
name: zmxy2-entity-migration
description: zmxy2-remake only. Move game files into the per-entity layout (game/entities/<kind>/<name>/: scene, animation library, data, textures, scripts, own effects together) and rename files / ids with every reference updated. Use for "迁移项目结构", "把 X 挪到 entities", "改文件名/改 id", "整理贴图命名".
---

# 按实体迁移目录与改名

目标结构（README 的 Path 表是总览）：

```
game/entities/<kind>/<name>/      kind = heroes / fabao / monsters / effects / ...
├── <name>.tscn, <name>_actions.tres   角色/动画场景（场景名 = 文件夹名，Puppet 按此查找）
├── <name>.tres                        数值（HeroData 等）
├── <name>.gd                          该实体专属脚本（如有）
├── tex/                               只给它用的贴图
├── slots/                             装备部件
└── effects/<effect>/                  只属于它的特效场景（各带 tex/）
```
归属按**谁在用**判断，不看名字：只有一个使用者的东西放进使用者的目录（悟空的 `fx_hit7_fire` → `entities/heroes/wukong/effects/`，背包的光 → `ui/backpack/effects/`，只有 3-1 用的着色器 → `entities/objects/river_water/`）；角色的副本（悟空怪、唐僧怪）和界面里的预览（背包、商城、法宝面板）算作同一个使用者。真正被几个使用者共用的：贴图放 `entities/shared/`、`stages/shared/`、`ui/shared/`，特效放 `entities/effects/`，代码放 `src/`。用 `bash tools/find_refs.sh <文件>` 查使用者；代码里拼名字的（`Puppet.create("gogo")`、`"fx_" + ...`）find_refs 查不到，要 grep 字符串。

## 工具

`node tools/move_entity.js <from> <to> [<from> <to> ...]`（路径相对 `game/`，文件或文件夹）
- 文件连同 `.import` / `.uid` 一起搬（uid 不变）；搬空的旧文件夹删掉。
- 改写 `game/` 下所有 `.tscn .tres .gd .gdshader .import .json .cfg .godot .md` 里的 `res://<from>`（只匹配完整路径段，`wukong` 不会误改 `wukong_hit10`）。
- **不改**代码里拼出来的路径：迁移前先 `grep -rn '"res://' game/src game/tools` 找 `%s` / 字符串拼接，逐个改。已有的查找入口：`Puppet._path`（按场景名在 `entities/` 下找，找不到回落 `scenes/actors/`）、`GameState.hero_data_path`、`Fabao.create`。

改名同理：from 和 to 在同一个文件夹即可（`a/x.png a/y.png`）。

## 流程

1. **编辑器必须关掉**（开着的场景会把旧路径写回去）。先 `git status`，把用户未提交的改动单独提交。
2. 在单独分支上做；改之前留基线：三位主角技能探针日志（`res://tools/skill_probe.tscn -- <key>`，`role=<name>`）、`tools/panel_shot.tscn` 截图。
3. 跑 `move_entity.js`；改代码里拼路径的地方；`godot --headless --path game --import` 无报错。
4. `bash tools/find_refs.sh <新路径>` 确认被引用；`grep -rn 'res://<旧路径>'` 为空。
5. 验证：探针日志逐行一致、`bash tools/run_checks.sh` 全过、截图对比（`magick compare -metric AE -fuzz 2%`，会动的光有零星差异属正常）。
6. 提交（按路径 `git add`）。`project.godot` 若被编辑器加回 `buses/default_bus_layout="uid://..."`，提交前删掉。

## 命名规则

- 物品 id：物品名全拼（`pinyin-pro`，`ü`→`v`），`普通的X`→`putong_x`，`绝·X`→`jue_x`，`N级强化石`→`qianghuashi_N`；不要按拼音首字母猜名字。改 id 时同时改：`data/equipment.tres`、各角色 `.tres` 的 `fabao`、`data/monsters/*.tres` 掉落、`data/stages.json`、脚本里的字面量、`tools/*_check.gd`，并在 `SaveGame._migrate` 里加旧 id 映射（否则旧存档里的物品读档时被丢掉）。
- 物品图：`assets/items/<id>_fall.png`（掉落物形态）；没有掉落物形态的才用原版带框图 `<id>_icon.png`。
- 贴图：`<所属实体>_<用途>.png`，用途取自用到它的节点/动作（`wukong_hit1_part3`、`tab_menu_background`），有原版部件名的用部件名（`weapon`、`cloth`、`wings`）。不要用 `OtherMat_v10_341`、`Common_v7_438` 这类库名+编号。
- 场景节点：PascalCase，可读单词，不用纯编号。
- 改完同步网站数据：`cd ../zmxy2-remake-site && npm run data -- ../godot-zmxy2`。

## 命名

- 怪物目录 = 怪物名字的全拼（`shouyeren`、`qinguangwang_kuilei`），同一个 Boss 的几个形态加序号（`zhuanlunwang_1`…`_3`、`taishanwang_1`…`_4`）；新怪物没有名字时先问用户定名，不要自己起。代码用 `MonsterData.folder(id)` 按数据里的 `id` 找目录，不要拼 `monster%d`。
- 关卡目录 = 关卡名的全拼（`guicheng`、`luoxuandiyu_wuguanwang`），编号到目录的对照只在 `Level.STAGES`。
- 法宝一律叫 `fabao`（不用 treasure / sutra）：`entities/fabao/<id>/`、`ui/fabao/`、类型 `&"fabao"`。
- 场景节点名用 PascalCase 的可读词：根节点 = 场景名，装备变体 = `<部位><id>`（`Wing2`），关卡里的图 = `<图层>Piece<n>`，界面里的图 = 图片名去掉界面前缀，其余部件 = `<父节点>Part<n>`。`node tools/rename_nodes.js` 按这套规则改名并改写场景和动画里的节点路径；代码里按名字找的节点（`$Name`、`%Name`、`"Name"`）不会被改。
- 改名后用 `node tools/move_entity.js` 移文件（改写 res:// 路径），代码里拼出来的名字另外 grep。
