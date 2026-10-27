class_name SaveGame
extends RefCounted
## Save slots (<saves>/slot_N.json) of the GameState profile: serialising, atomic writes with a .bak, versioning and
## validated loading. GameState keeps the one-line entry points (save_to, load_from, slot_info, autosave).

const VERSION := 2

## Saves live in a "saves" folder next to the exe (editor and web: user://saves, the browser's IndexedDB).
static func dir() -> String:
	var d := "user://saves" if OS.has_feature("editor") or OS.has_feature("web") else OS.get_executable_path().get_base_dir().path_join("saves")
	DirAccess.make_dir_recursive_absolute(d)
	return d

static func slot_path(i: int) -> String:
	return dir().path_join("slot_%d.json" % i)

static func account_path() -> String:
	return dir().path_join("account.json")

## Account-wide data that belongs to no slot: which heroes are unlocked.
static func read_account(g: Node) -> void:
	if not FileAccess.file_exists(account_path()):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(account_path()))
	if d is Dictionary and d.get("unlocked") is Dictionary:
		for r in g.unlocked:
			g.unlocked[r] = g.unlocked[r] or d.unlocked.get(r, false) == true

static func write_account(g: Node) -> void:
	var f := FileAccess.open(account_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": g.unlocked}))

static func to_dict(g: Node) -> Dictionary:
	var w := {}
	for k in g.worn:
		w[String(k)] = g.worn[k].to_dict() if g.worn[k] else {}
	return {
		"version": VERSION,
		"role": g.role,
		"level": g.level, "exp": g.exp, "souls": g.souls, "attack": g.attack,
		"skills": g.skills.keys().filter(func(k): return g.skills[k]).map(func(k): return String(k)),
		"passives": g.passives,
		"bag": g.bag.map(func(it: Item): return it.to_dict()), "worn": w,
		"stage": [g.stage.x, g.stage.y], "progress": [g.progress.x, g.progress.y],
		"opening_seen": g.opening_seen, "hhe_seen": g.hhe_seen, "cloth_gift": g.cloth_gift, "buffs": g.buffs,
		"merit": g.merit,
		"activity_days": g.activity_days, "moon_event": g.moon_event,
		"title": "Lv.%d  %s  %d-%d" % [g.level, g.hero_data.character, g.progress.x, g.progress.y],
		"datetime": Time.get_datetime_string_from_system(false, true),
	}

## Written to a temporary file and renamed over the slot (a crash mid-write cannot truncate it); the previous slot is
## kept as <slot>.bak, which reading falls back to when the slot cannot be parsed.
static func write(i: int, d: Dictionary) -> bool:
	var path: String = slot_path(i)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("save: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_error("save: cannot replace %s" % path)
		return false
	return true

## The parsed save of a slot (falling back to its backup), {} when empty or unreadable.
static func read(i: int) -> Dictionary:
	for path in [slot_path(i), (slot_path(i)) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			return _migrate(json.data)
		push_warning("save: %s is not readable" % path)
	return {}

## Item ids before version 2 (pinyin initials) -> the current ids (full pinyin of the name).
const V1_IDS := {
	"ptxzf": "putong_xingzhepao", "ptxzg": "putong_xingzhegun", "ptjs": "putong_jiasha",
	"ptsmz": "putong_songmuzhang", "ptsf": "putong_shifu", "ptmlf": "putong_molanfu", "dslj": "dishalingjie",
	"dsyj": "dishayuanjia", "dsqz": "dishaquanzhang", "tsgl": "tianshagulian", "tsyp": "tianshayupao",
	"tsyj": "tianshayueji", "xhyk": "xuehaiyaoke", "xhxh": "xuehaixiehuang", "xhmj": "xuehaimojia",
	"zljs": "jinlanjiasha", "jhcz": "lunhuizhang", "dszk": "dashengzhankai", "ryjgb": "qingtianzhu",
	"qssp": "qianshengsuipian", "jssp": "jinshengsuipian", "lssp": "laishengsuipian", "ssc": "sanshengchui",
	"fygwj": "fengyinguiwangjian", "yzfw": "yangzhifuwen", "yinzfw": "yinzhifuwen", "gwj": "guiwangjian",
	"hshb": "hongsehuaban", "lshb": "lvsehuaban", "zshb": "zisehuaban", "qcp": "qicaipao", "jgj": "jingangjia",
	"lcgy": "luochaguiyi", "gtq": "gutengqiang", "lzp": "laozhepao", "gtb": "gutengbang", "lcld": "luochaliandao",
	"bsxj": "baishuangxiongjia", "bszj": "baishuangzhongjia", "bsyz": "baishuangyaozhang",
	"csgs": "cangshengguashi", "lczh": "luochazhihuan", "jcdp": "jiuchidingpa", "tpzy": "tianpengzhanyi",
	"yll": "yanluoling", "t": "tan", "c": "chen", "ch": "chi", "dzj": "dicangjie", "dzjj": "dicangjinjie",
	"bsz": "bishuizhu", "jxbuff": "wangudeshuiniu", "xique": "xingyundexique", "szyj": "shezhiyinji",
	"xzyj": "xiezhiyinji", "zzyj": "zhuzhiyinji", "mzyj": "chanzhiyinji", "gzyj": "gongzhiyinji",
	"dcyj": "duchongyinji", "xyb": "xiaoyuebing", "jxdyb": "meiguiyuebing", "jmdyb": "lanmeiyuebing",
	"jgjdyb": "lvjuyuebing", "jfydyb": "jianguoyuebing", "jbldyb": "mangguoyuebing", "myz": "mingyuezhang",
	"nyd": "ningyuedao", "syc": "shangyuechui", "xtzy": "xingtianzhiyi", "dshl": "dishahulu",
	"tsgj": "tianshagujian", "bsj": "baishuangjing", "lsys": "luochayaosan", "xhmt": "xuehaimotong",
	"wds": "wudushou", "wpqhs1": "qianghuashi_1", "wpqhs2": "qianghuashi_2", "wpqhs3": "qianghuashi_3",
	"wpqhs4": "qianghuashi_4", "wpqhs5": "qianghuashi_5", "wpxyf": "xingyunfu", "wpbdf": "baodifu",
	"sbbl": "shuangbeibaolv", "wdd": "wududan", "wkmrz": "wukonghuangtouzhuang",
	"tsmrz": "tangsenghuangtouzhuang", "bjmrz": "bajiehuangtouzhuang", "wkbsz": "wukonghongtouzhuang",
	"tsbsz": "tangsenghongtouzhuang", "bjbsz": "bajiehongtouzhuang", "jwkzyf": "jue_wukongzhuangyuanfu",
	"jtszyf": "jue_tangsengzhuangyuanfu", "jbjzyf": "jue_bajiezhuangyuanfu", "jwkwdg": "jue_wukongxizhuang",
	"jtswdg": "jue_tangsengxizhuang", "jbjwdg": "jue_bajiexizhuang", "wkwdg": "wukongxizhuang",
	"tswdg": "tangsengxizhuang", "bjwdg": "bajiexizhuang", "wkzyf": "wukongzhuangyuanfu",
	"tszyf": "tangsengzhuangyuanfu", "bjzyf": "bajiezhuangyuanfu", "hhbuff": "huihuang", "ttzy": "tiantingzhiyi"
}

## Brings an older save up to VERSION (version 0 = written before the field existed; same layout as 1).
static func _migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version", 0)) < 2:
		for it in d.get("bag", []) if d.get("bag") is Array else []:
			if it is Dictionary and it.get("id") is String:
				it.id = V1_IDS.get(it.id, it.id)
		var w = d.get("worn", {})
		if w is Dictionary:
			for k in w:
				if w[k] is Dictionary and w[k].get("id") is String:
					w[k].id = V1_IDS.get(w[k].id, w[k].id)
	var worn = d.get("worn", {})
	if worn is Dictionary and worn.has("treasure"):   # the 法宝 slot was called "treasure" before
		worn["fabao"] = worn["treasure"]
		worn.erase("treasure")
	d["version"] = VERSION
	return d

## {title, datetime} of a slot, or {} when empty.
static func info(i: int) -> Dictionary:
	var d := read(i)
	return {"title": str(d.get("title", "")), "datetime": str(d.get("datetime", ""))} if not d.is_empty() else {}

static func _pair(v: Variant, fallback: Vector2i) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1])) if v is Array and v.size() >= 2 else fallback

## Applies a read save to the profile `g` (already reset by the caller), validating and clamping every field.
static func apply(g: Node, d: Dictionary) -> void:
	var hero: HeroData = g.hero_data   # the caller has already started a new game as the saved role
	g.level = clampi(int(d.get("level", 1)), 1, hero.level_max)
	g.exp = maxi(int(d.get("exp", 0)), 0)
	g.souls = maxi(int(d.get("souls", 0)), 0)
	g.attack = maxi(int(d.get("attack", hero.attack_power(g.level))), 0)
	for s in d.get("skills", []):
		if s is String:
			g.skills[StringName(s)] = true
	var pv = d.get("passives", [])
	if pv is Array:
		for n in mini(pv.size(), g.passives.size()):
			g.passives[n] = clampi(int(pv[n]), 0, hero.passive_max)
	g.bag.clear()
	for it in d.get("bag", []) if d.get("bag") is Array else []:
		var clean := Item.from_dict(it)
		if clean:
			g.bag.append(clean)
	var w = d.get("worn", {})
	for k in g.worn:
		g.worn[k] = Item.from_dict(w.get(String(k))) if w is Dictionary else null
	g.stage = _pair(d.get("stage"), Vector2i(1, 1))
	g.progress = _pair(d.get("progress"), Vector2i(1, 1))
	g.opening_seen = d.get("opening_seen", true) == true
	g.hhe_seen = d.get("hhe_seen", false) == true
	g.cloth_gift = d.get("cloth_gift", false) == true
	g.merit = maxi(int(d.get("merit", 0)), 0)
	g.moon_event = d.get("moon_event", true) != false
	var ad = d.get("activity_days", {})
	if ad is Dictionary:
		for a in ad:
			if ad[a] is String:
				g.activity_days[str(a)] = ad[a]
	var bf = d.get("buffs", {})
	if bf is Dictionary:
		for b in bf:
			if EquipmentCatalog.get_catalog().buffs.has(b) and (bf[b] is float or bf[b] is int):
				g.buffs[b] = float(bf[b])
