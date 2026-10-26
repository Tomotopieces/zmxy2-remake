extends SceneTree
## Per-frame (1/24 s) Hitbox / Hurtbox rects and method events of every actor scene's animations -> tools/dl/audit/remake.json
func _init() -> void:
	var out := {}
	for dir in Puppet.all_names():
		var p := Puppet._path(dir)
		if not ResourceLoader.exists(p):
			continue
		var n: Node = (load(p) as PackedScene).instantiate()
		if n.has_node("Puppet"):   # a character: its art is the Puppet child
			var art := n.get_node("Puppet")
			n.remove_child(art)
			n.free()
			n = art
		root.add_child(n)
		var anim: AnimationPlayer = n.get_node_or_null("Anim")
		if anim == null:
			n.free()
			continue
		var acts := {}
		for an in anim.get_animation_list():
			var a: Animation = anim.get_animation(an)
			var ev := []
			for t in a.get_track_count():
				if a.track_get_type(t) == Animation.TYPE_METHOD:
					for k in a.track_get_key_count(t):
						ev.append([roundi(a.track_get_key_time(t, k) * 24.0), String(a.method_track_get_name(t, k)), a.method_track_get_params(t, k)])
			var hit := []
			var hurt := []
			anim.play(an)
			var frames := maxi(1, roundi(a.length * 24.0))
			for f in frames:
				anim.seek(f / 24.0, true)
				hit.append(_rect(n, "Hitbox"))
				hurt.append(_rect(n, "Hurtbox"))
			acts[an] = {"length": a.length, "frames": frames, "loop": a.loop_mode != Animation.LOOP_NONE, "hit": hit, "hurt": hurt, "events": ev}
		out[dir] = acts
		n.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tools/dl/audit"))
	var f := FileAccess.open(ProjectSettings.globalize_path("res://../tools/dl/audit/remake.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	print("actors ", out.size())
	quit()

func _rect(n: Node, box: String):
	var area: Area2D = n.get_node_or_null(box)
	if area == null:
		return "none"
	var cs: CollisionShape2D = area.get_child(0)
	if cs.disabled or cs.shape == null:
		return null
	var r: Rect2 = (area.transform * cs.transform) * cs.shape.get_rect()
	if cs.shape is CircleShape2D:
		return ["circle", snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]
	return [snappedf(r.position.x, 0.1), snappedf(r.position.y, 0.1), snappedf(r.size.x, 0.1), snappedf(r.size.y, 0.1)]
