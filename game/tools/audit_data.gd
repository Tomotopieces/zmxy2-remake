extends SceneTree
func _init() -> void:
	var out := {}
	for f in DirAccess.get_files_at("res://data/monsters"):
		if not f.ends_with(".tres"): continue
		var d: MonsterData = load("res://data/monsters/" + f)
		var acts := {}
		for k in d.attacks:
			var a: AttackData = d.attacks[k]
			acts[String(k)] = {"max_hits": a.max_hits, "rehit": snappedf(a.rehit_interval, 0.001), "flat": a.flat, "pm": a.power_mul, "kind": a.kind, "kb": [a.knockback.x, a.knockback.y]}
		out["Monster%d" % d.id] = acts
	for r in ["wukong", "tangseng", "bajie"]:
		var d: HeroData = load(GameState.hero_data_path(r))
		var acts := {}
		for k in d.attacks:
			var a: AttackData = d.attacks[k]
			acts[String(k)] = {"max_hits": a.max_hits, "rehit": snappedf(a.rehit_interval, 0.001), "flat": a.flat, "pm": a.power_mul, "kind": a.kind, "kb": [a.knockback.x, a.knockback.y]}
		out[{"wukong": "Role1", "tangseng": "Role2", "bajie": "Role3"}[r]] = acts
	var fo := FileAccess.open(ProjectSettings.globalize_path("res://../tools/dl/audit/remake_data.json"), FileAccess.WRITE)
	fo.store_string(JSON.stringify(out))
	quit()
