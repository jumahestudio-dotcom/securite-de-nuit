extends Node
## Mode baston : intervention physique en temps réel, jugée selon le droit français.
## Un agent de sécurité n'a pas plus de droits qu'un citoyen : seule la légitime défense
## (art. 122-5 du Code pénal) justifie un coup, et la force doit rester strictement nécessaire.

var game                     # référence vers main.gd
var active := false
var t := 0.0
var foes: Array = []
var src: Dictionary = {}
var title := ""
var log_lines: Array = []
var stats := {}
var vcd := 0.0               # délai entre deux injonctions
var end_t := -1.0
var shake := 0.0
var ui_t := 0.0
var lock = null              # adversaire verrouillé (Tab)
var witnesses: Array = []    # clients qui filment avec leur téléphone
var fight_pos := Vector3.ZERO

# état du joueur
var hp := 100.0
var sta := 100.0
var cd := 0.0
var dodge := 0.0
var dodge_dir := Vector3.ZERO

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _p():
	return game.player

# =====================================================================
#  DÉBUT
# =====================================================================
func _mk_foe(npc, o := {}) -> Dictionary:
	npc.path = []
	npc.on_arrive = null
	npc.anim = "fight"
	return {"npc": npc, "name": o.get("name", Data.PREN_H.pick_random()), "hp": 100.0, "sta": 100.0,
		"agit": o.get("agit", randf_range(62, 95)), "aggr": o.get("aggr", randf_range(0.45, 1.0)),
		"weapon": o.get("weapon", false), "wname": o.get("wname", "couteau"), "st": "active", "wind": 0.0, "cd": randf_range(0.6, 1.6),
		"last_atk": -99.0, "stag": 0.0, "ctrl_t": 0.0, "ctrl_by": null, "warned": 0, "other": null,
		"pushes": 0, "hit_by": 0, "aggro": o.get("aggro", false)}

func start(s: Dictionary) -> void:
	game.ui.close_panel()
	src = s
	title = s.get("title", "Bagarre")
	active = true
	t = 0.0
	end_t = -1.0
	foes = []
	log_lines = []
	lock = null
	stats = {"cut": 0, "disarm": 0, "push": 0, "grab": 0, "grab_ok": 0, "verb": 0, "verb_ok": 0, "hit_sd": 0, "hit_nosd": 0, "hit_down": 0,
		"blocked": 0, "dodged": 0, "taken": 0.0, "long_pin": 0, "escort": 0, "col_ctrl": 0}
	hp = max(hp, 60.0)
	sta = 100.0
	if s.has("inc"):
		var inc: Dictionary = s["inc"]
		inc["st"] = "fight"
		var n: int = min(inc["actors"].size(), 8 if inc["ty"] == "rixe" else 2)
		for k in n:
			var armed: bool = (inc["ty"] == "arme" or inc["ty"] == "bouteille") and k == 0
			foes.append(_mk_foe(inc["actors"][k], {"weapon": armed, "wname": "tesson de bouteille" if inc["ty"] == "bouteille" else "couteau"}))
		if foes.size() >= 2 and inc["ty"] != "arme":
			for i in foes.size():
				var j: int = i ^ 1
				foes[i]["other"] = foes[j] if j < foes.size() else foes[0]
				if randf() < 0.25: foes[i]["aggro"] = true
		elif foes.size() > 0:
			foes[0]["aggro"] = true
	else:
		foes.append(_mk_foe(s["npc"], {"aggro": true, "name": s.get("name", "Le client"), "agit": randf_range(80, 98), "aggr": randf_range(0.75, 1.0), "weapon": s.get("weapon", false)}))
		for m in s.get("mates", []):
			if randf() < 0.5:
				foes.append(_mk_foe(m, {"aggro": true, "agit": randf_range(55, 85), "aggr": randf_range(0.4, 0.8)}))
	game._set_radio("Toi : « %s »" % ("J'interviens !" if s.has("inc") else "Je suis pris à partie à la porte !"))
	game.audio.sfx("radio")
	# des clients sortent leur téléphone et filment
	fight_pos = foes[0]["npc"].position if foes.size() > 0 else game.player.position
	witnesses = []
	for c in game.crowd:
		if witnesses.size() >= 3: break
		if not is_instance_valid(c): continue
		var is_foe := false
		for o in foes:
			if o["npc"] == c: is_foe = true
		if is_foe: continue
		var dw: float = c.position.distance_to(fight_pos)
		if dw > 3.0 and dw < 10.0 and randf() < 0.6:
			c.set_meta("prev_anim", c.anim)
			c.anim = "phone"
			c.yaw = atan2(fight_pos.x - c.position.x, fight_pos.z - c.position.z)
			witnesses.append(c)
	game.ui.flash(Color(1, 0.2, 0.2, 0.25))
	_log("Tu arrives au contact." if s.has("inc") else "Le client se jette sur toi.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _log(s: String) -> void:
	log_lines.push_front(s)
	if log_lines.size() > 4: log_lines.resize(4)

# =====================================================================
#  OUTILS
# =====================================================================
func _fwd() -> Vector3:
	return Vector3(sin(game.cam_yaw), 0, cos(game.cam_yaw))

func _target(rng: float, sts: Array, cone := 0.85):
	var P: Vector3 = _p().position
	var f := _fwd()
	var best = null
	var bd := rng
	for o in foes:
		if not o["st"] in sts: continue
		var d3: Vector3 = o["npc"].position - P
		d3.y = 0
		var d := d3.length()
		if d > bd: continue
		var ang: float = 0.0
		if d > 0.01: ang = acos(clamp(d3.normalized().dot(f), -1.0, 1.0))
		if ang < cone or d < 0.7:
			bd = d
			best = o
	return best

func _self_def(o: Dictionary) -> bool:
	return _now() - o["last_atk"] < 2.6 or (o["weapon"] and o["st"] == "active")

func _allies_near(o: Dictionary) -> int:
	var n := 0
	for a in game.colleagues:
		if a.position.distance_to(o["npc"].position) < 2.0: n += 1
	return n

# =====================================================================
#  ACTIONS DU JOUEUR
# =====================================================================
func push() -> void:
	if cd > 0 or sta < 10: return
	cd = 0.45; sta -= 12
	game.pvis.act("Shove", 0.45)
	game.audio.sfx("whoosh")
	var o = _target(1.6, ["active", "calm"])
	if o == null:
		_log("Tu pousses dans le vide.")
		return
	stats["push"] += 1
	var f := _fwd()
	o["npc"].position += f * 0.9
	o["stag"] = 0.7; o["wind"] = 0.0; o["sta"] -= 8; o["pushes"] += 1
	if randf() < 0.5: o["aggro"] = true
	if o["st"] == "active" and _now() - o["last_atk"] > 2.6:
		o["agit"] = clamp(o["agit"] - 2, 0, 100)
	o["npc"].act("Hit", 0.5)
	_log("Tu repousses %s." % o["name"])

func punch() -> void:
	if cd > 0 or sta < 10: return
	cd = 0.55; sta -= 15
	game.pvis.act("Punch", 0.5)
	var o = _target(1.45, ["active", "calm", "controlled", "down", "grabbed"])
	if o == null:
		_log("Ton coup part dans le vide.")
		return
	var lawful: bool = o["st"] == "active" and _self_def(o)
	if o["st"] in ["down", "controlled", "calm"]: stats["hit_down"] += 1
	elif lawful: stats["hit_sd"] += 1
	else: stats["hit_nosd"] += 1
	o["hp"] -= 24; o["hit_by"] += 1; o["aggro"] = true; o["stag"] = 0.9; o["wind"] = 0.0; o["sta"] -= 15
	o["agit"] = clamp(o["agit"] + (2 if lawful else 12), 0, 100)
	shake = 0.12
	o["npc"].act("Hit", 0.6)
	o["npc"].position += _fwd() * 0.4
	game.audio.sfx("punch")
	_hitstop(0.06)
	_log("Tu frappes %s." % o["name"])
	if o["hp"] <= 0 and o["st"] != "down":
		o["st"] = "down"
		o["npc"].anim = "fallen"
		o["npc"].act("", 0)
		_log("%s s'effondre et ne bouge plus." % o["name"])
		game.ui.flash(Color(1, 0, 0, 0.3))

func grab() -> void:
	if cd > 0 or sta < 15: return
	cd = 0.6; sta -= 18
	game.pvis.act("Grab", 0.45)
	var o = _target(1.3, ["active", "calm"])
	if o == null:
		_log("Tu attrapes le vide.")
		return
	stats["grab"] += 1
	var p: float = 0.18 + (100.0 - o["sta"]) / 140.0 + (0.35 if o["stag"] > 0 else 0.0) + _allies_near(o) * 0.18 - o["agit"] / 320.0 + (0.5 if o["st"] == "calm" else 0.0) - (0.15 if o["weapon"] else 0.0)
	if randf() < clamp(p, 0.05, 0.95):
		stats["grab_ok"] += 1
		o["st"] = "grabbed"; o["wind"] = 0.0; o["ctrl_t"] = 0.0
		o["npc"].anim = "fight"
		_log("Tu saisis %s (clé de bras). Il se débat…" % o["name"])
		if o["weapon"]:
			o["weapon"] = false
			stats["disarm"] += 1
			_log("Tu bloques son bras : le %s tombe au sol." % o["wname"])
	else:
		o["agit"] = clamp(o["agit"] + 6, 0, 100)
		o["aggro"] = true
		sta -= 8
		if o["weapon"]:
			hp -= 18
			stats["cut"] += 1
			shake = 0.25
			game.ui.flash(Color(1, 0, 0, 0.5))
			game.audio.sfx("hurt")
			_log("%s se dégage et te blesse avec son %s !" % [o["name"], o["wname"]])
		else:
			_log("%s se dégage." % o["name"])

func verbal() -> void:
	if vcd > 0: return
	vcd = 2.5
	stats["verb"] += 1
	game.pvis.act("Verbal", 0.7)
	var P: Vector3 = _p().position
	var any := false
	for o in foes:
		if o["st"] != "active": continue
		if o["npc"].position.distance_to(P) > 4.0: continue
		if o["agit"] < 72 and not o["weapon"]:
			o["agit"] -= randf_range(10, 17)
			any = true
		else:
			o["agit"] = clamp(o["agit"] + 2, 0, 100)
	if any: stats["verb_ok"] += 1
	_log(["« Calmez-vous ! Ça s'arrête maintenant ! »", "« Sécurité ! On se sépare ! »", "« Recule ! Recule ! »"].pick_random())

func do_dodge(mv: Vector3) -> void:
	if sta < 20 or dodge > 0: return
	sta -= 22
	dodge = 0.38
	dodge_dir = mv if mv.length() > 0.01 else -_fwd()
	dodge_dir = dodge_dir.normalized()

func escort() -> void:
	var P: Vector3 = _p().position
	var best = null
	var bd := 1.8
	for o in foes:
		if o["st"] != "controlled" and o["st"] != "calm": continue
		var d: float = o["npc"].position.distance_to(P)
		if d < bd:
			bd = d; best = o
	if best != null: _escort_out(best, "toi")

func _escort_out(o: Dictionary, by: String) -> void:
	o["st"] = "out"
	o["npc"].set_tag("")
	o["npc"].anim = "walk"
	stats["escort"] += 1
	var pts: Array = game.world.route(o["npc"].position, Vector3(randf_range(-0.5, 0.5), 0, 1.5))
	pts.append(Vector2(6, 4.8)); pts.append(Vector2(28, 5))
	o["npc"].speed = 1.4
	o["npc"].walk_to(pts, func(q): q.queue_free())
	_log("Tu raccompagnes %s vers la sortie, bras tenu." % o["name"] if by == "toi" else "%s sort %s." % [by, o["name"]])

func toggle_lock() -> void:
	if lock != null:
		lock = null
		_log("Verrouillage désactivé.")
		return
	var P: Vector3 = _p().position
	var bd := 8.0
	for o in foes:
		if not o["st"] in ["active", "calm", "grabbed"]: continue
		var d: float = o["npc"].position.distance_to(P)
		if d < bd:
			bd = d; lock = o
	if lock != null: _log("Cible verrouillée : %s." % lock["name"])

func _hitstop(dur := 0.07) -> void:
	Engine.time_scale = 0.06
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

func backup() -> void:
	var free := []
	for a in game.colleagues:
		if not a.get_meta("fight", false) and a.task == null: free.append(a)
	if free.is_empty():
		_log("Radio : personne de disponible.")
		return
	var P: Vector3 = _p().position
	free.sort_custom(func(x, y): return x.position.distance_to(P) < y.position.distance_to(P))
	var a = free[0]
	a.set_meta("fight", true)
	a.set_meta("fcd", 2.0)
	a.run = true
	_log("Radio : « Renfort ! » — %s arrive en courant." % a.pname)
	game._set_radio("%s : « J'arrive ! »" % a.pname)

# =====================================================================
#  BOUCLE
# =====================================================================
func step(dt: float, mv: Vector3) -> void:
	t += dt
	vcd = max(0.0, vcd - dt)
	cd = max(0.0, cd - dt)
	var blocking := Input.is_physical_key_pressed(KEY_F) and sta > 0
	sta = clamp(sta + (-9.0 if blocking else 16.0) * dt, 0, 100)
	var pl: CharacterBody3D = _p()
	var P := pl.position
	if dodge > 0:
		dodge -= dt
		pl.velocity = dodge_dir * 6.5
		pl.move_and_slide()
	if blocking: game.pvis.act("Block", 0.08)
	# caméra qui suit la cible verrouillée
	if lock != null:
		if not lock["st"] in ["active", "calm", "grabbed"] or not is_instance_valid(lock["npc"]):
			lock = null
		else:
			var lp: Vector3 = lock["npc"].position - P
			game.cam_yaw = lerp_angle(game.cam_yaw, atan2(lp.x, lp.z), clamp(dt * 6.0, 0.0, 1.0))
	game.pvis.yaw = game.pvis.turn_to(game.pvis.yaw, game.cam_yaw, dt * 14.0)
	for o in foes:
		var n = o["npc"]
		if not is_instance_valid(n): continue
		o["stag"] = max(0.0, o["stag"] - dt)
		o["sta"] = clamp(o["sta"] + 5 * dt, 0, 100)
		var d3: Vector3 = P - n.position
		d3.y = 0
		var d := d3.length()
		_update_tag(o)
		match o["st"]:
			"grabbed":
				o["ctrl_t"] += dt
				var f := _fwd()
				n.position = Vector3(P.x + f.x * 0.62, n.position.y, P.z + f.z * 0.62)
				n.yaw = game.cam_yaw
				sta -= 14 * dt
				game.pvis.act("Grab", 0.08)
				if sta <= 0:
					o["st"] = "active"; o["stag"] = 0.0
					o["agit"] = clamp(o["agit"] + 8, 0, 100)
					cd = 0.8
					_log("Épuisé, tu lâches %s." % o["name"])
				elif o["ctrl_t"] > 2.3:
					o["st"] = "controlled"; o["ctrl_t"] = 0.0
					n.anim = "kneel"
					o["agit"] = clamp(o["agit"] - 35, 0, 100)
					_log("%s est maîtrisé, à genoux. (E : le raccompagner)" % o["name"])
				continue
			"controlled":
				o["ctrl_t"] += dt
				n.anim = "kneel"
				if o["ctrl_t"] > 18 and o["warned"] == 0:
					o["warned"] = 1
					_log("%s : « J'arrive plus à respirer… »" % o["name"])
				if o["ctrl_t"] > 30 and o["warned"] == 1:
					o["warned"] = 2
					stats["long_pin"] += 1
					_log("%s ne répond plus très bien…" % o["name"])
				continue
			"calm":
				n.anim = "raise"
				o["ctrl_t"] += dt
				continue
			"active":
				pass
			_:
				continue
		# désescalade naturelle
		o["agit"] = clamp(o["agit"] - (0.3 if o["weapon"] else 1.1) * dt - (2.0 * dt if o["sta"] < 30 else 0.0), 0, 100)
		if o["agit"] < 22:
			o["st"] = "calm"; o["ctrl_t"] = 0.0
			n.anim = "raise"
			_log("%s lève les mains : « C'est bon, c'est bon ! »" % o["name"])
			continue
		if o["stag"] > 0:
			n.anim = "fight"
			continue
		# cible : toi, ou l'autre bagarreur
		var tx := P
		var td := d
		var vs_foe := false
		var atk := 0
		for x in foes:
			if not is_same(x, o) and x["st"] == "active" and x["aggro"] and x["wind"] > 0: atk += 1
		var other = o["other"]
		if other != null and not is_same(other, o) and other["st"] == "active" and (not o["aggro"] or d > 3.5):
			tx = other["npc"].position
			var dd: Vector3 = tx - n.position
			dd.y = 0
			td = dd.length()
			vs_foe = true
		if not vs_foe and not o["aggro"]:
			if d < 1.3 or randf() < 0.004:
				o["aggro"] = true
			else:
				n.anim = "fight"
				n.yaw = n.turn_to(n.yaw, atan2(d3.x, d3.z), dt * 4.0)
				continue
		var ty := atan2(tx.x - n.position.x, tx.z - n.position.z)
		n.yaw = n.turn_to(n.yaw, ty, dt * 8.0)
		# élan puis coup
		if o["wind"] > 0:
			o["wind"] -= dt
			n.act("Windup", 0.1)
			if o["wind"] <= 0:
				n.act("Punch", 0.45)
				o["cd"] = randf_range(1.3, 2.6) / o["aggr"]
				if vs_foe:
					if td < 1.6:
						other["hp"] -= 6
						other["npc"].act("Hit", 0.4)
					continue
				o["last_atk"] = _now()
				if d < 1.6:
					if dodge > 0:
						stats["dodged"] += 1
						_log("Tu esquives le coup de %s." % o["name"])
					else:
						var dmg: float = 26.0 if o["weapon"] else randf_range(6, 10)
						if blocking and not o["weapon"]:
							dmg *= 0.18
							stats["blocked"] += 1
							sta -= 10
						elif blocking:
							dmg *= 0.6
						hp -= dmg
						stats["taken"] += dmg
						shake = 0.08 if blocking else 0.22
						game.audio.sfx("block" if blocking else "punch")
						if not blocking:
							var back: Vector3 = -d3.normalized() * -0.25
							pl.position += Vector3(back.x, 0, back.z)
							_hitstop(0.05)
						if not blocking: game.pvis.act("Hit", 0.4)
						game.ui.flash(Color(1, 0, 0, 0.45) if o["weapon"] else Color(1, 0.15, 0.15, 0.25))
						if o["weapon"]: _log("%s te touche avec son %s !" % [o["name"], o["wname"]])
						elif blocking: _log("Tu bloques le coup de %s." % o["name"])
						else: _log("%s te frappe !" % o["name"])
			continue
		var reach := 1.0 if vs_foe else 1.15
		if td > reach:
			var sp := (2.4 if td > 3 else 1.5) * dt
			n.position.x += sin(ty) * sp
			n.position.z += cos(ty) * sp
			n.anim = "walk"
			n.walk_ph += sp * 5.0
		else:
			n.anim = "fight"
		o["cd"] -= dt
		if td < 1.7 and o["cd"] <= 0 and (vs_foe or atk < 2) and randf() < o["aggr"] * (o["agit"] / 100.0) + 0.15:
			o["wind"] = 0.6
		elif o["cd"] <= 0:
			o["cd"] = 0.4
	_step_colleagues(dt)
	if hp <= 0:
		finish(true)
		return
	var done := true
	for o in foes:
		if not (o["st"] == "out" or o["st"] == "down" or (o["st"] == "controlled" and o["ctrl_by"] != null)):
			done = false
	if done:
		if end_t < 0: end_t = t
		if t - end_t > 1.5: finish(false)
	else:
		end_t = -1.0
	ui_t += dt
	if ui_t > 0.15:
		ui_t = 0
		_hud()

func _step_colleagues(dt: float) -> void:
	for a in game.colleagues:
		if not a.get_meta("fight", false): continue
		var fcd: float = a.get_meta("fcd", 0.0) - dt
		a.set_meta("fcd", fcd)
		var tgt = null
		var bd := 99.0
		for o in foes:
			var ok: bool = o["st"] == "active" or o["st"] == "calm" or (o["st"] == "controlled" and o["ctrl_by"] == a)
			if not ok: continue
			var dd: float = o["npc"].position.distance_to(a.position)
			if dd < bd:
				bd = dd; tgt = o
		if tgt == null:
			a.set_meta("fight", false)
			a.run = false
			a.walk_to(game.world.route(a.position, a.home))
			continue
		if bd > 1.1:
			if a.path.is_empty() or fcd <= 0:
				a.set_meta("fcd", 0.5)
				a.walk_to([Vector2(tgt["npc"].position.x + 0.6, tgt["npc"].position.z + 0.6)])
		else:
			a.path = []
			a.anim = "fight"
			a.yaw = atan2(tgt["npc"].position.x - a.position.x, tgt["npc"].position.z - a.position.z)
			if fcd <= 0:
				a.set_meta("fcd", 1.6)
				if tgt["st"] == "controlled":
					if tgt["ctrl_t"] > 3: _escort_out(tgt, a.pname)
				elif tgt["st"] == "calm":
					tgt["st"] = "controlled"; tgt["ctrl_t"] = 0.0; tgt["ctrl_by"] = a
					tgt["npc"].anim = "kneel"
				elif randf() < 0.32 + (100.0 - tgt["sta"]) / 300.0:
					tgt["st"] = "controlled"; tgt["ctrl_t"] = 0.0; tgt["ctrl_by"] = a
					tgt["npc"].anim = "kneel"
					stats["col_ctrl"] += 1
					a.act("Grab", 0.6)
					_log("%s maîtrise %s." % [a.pname, tgt["name"]])
				else:
					tgt["agit"] = clamp(tgt["agit"] - 6, 0, 100)
					tgt["stag"] = 0.5
					a.act("Shove", 0.4)

func _update_tag(o: Dictionary) -> void:
	var n = o["npc"]
	var st: String = o["st"]
	if st == "out":
		n.set_tag("")
		return
	var bars := int(round(o["agit"] / 10.0))
	var txt: String = o["name"] + ("  [%s]" % o["wname"] if o["weapon"] else "") + "\n" + "|".repeat(bars) + ".".repeat(10 - bars)
	var col := Color(1, 0.3, 0.45)
	match st:
		"calm": col = Color(1, 0.8, 0.2); txt = o["name"] + "\nse rend"
		"grabbed": col = Color(0.3, 0.9, 1); txt = o["name"] + "\nsaisi"
		"controlled": col = Color(0.3, 0.9, 1); txt = o["name"] + "\nmaîtrisé"
		"down": col = Color(1, 0.2, 0.2); txt = o["name"] + "\ninconscient"
	if lock != null and is_same(lock, o):
		txt = "> " + txt + " <"
	if st == "active" and o["wind"] > 0:
		col = Color(1, 0.1, 0.1)
		txt = "!! " + txt
	n.set_tag(txt, col)

func _hud() -> void:
	var lbl := {"active": "agressif", "grabbed": "saisi", "controlled": "maîtrisé", "calm": "se rend", "down": "inconscient", "out": "sorti"}
	var s := "[b][color=#ff6a85]BASTON — %s[/color][/b]\n" % Data.clean(title)
	s += "Toi : vie [color=%s]%d[/color] · endurance [color=#ffc04d]%d[/color]\n" % ["#ff4d4d" if hp < 35 else "#3ee08f", round(hp), round(sta)]
	var k := 0
	for o in foes:
		if o["st"] == "out" or k >= 6: continue
		k += 1
		s += "%s%s : agitation %d · %s\n" % [o["name"], " (lame)" if o["weapon"] else "", round(o["agit"]), lbl.get(o["st"], "")]
	s += "\n[color=#ffd6de]"
	for i in log_lines.size():
		s += log_lines[i] + "\n"
	s += "[/color]\n[color=#b9a0a8][font_size=12]Tab verrouiller · Clic G repousser · Clic D saisir · F garde · Espace esquive · A frapper · T injonction · E escorter · R renfort[/font_size][/color]"
	game.ui.set_fight(s)

# =====================================================================
#  FIN ET JUGEMENT
# =====================================================================
func finish(ko: bool) -> void:
	active = false
	game.ui.set_fight("")
	for a in game.colleagues:
		if a.get_meta("fight", false):
			a.set_meta("fight", false)
			a.run = false
			a.walk_to(game.world.route(a.position, a.home))
	var S: Dictionary = stats
	var res := []
	var ds := 0.0
	var dr := 0.0
	if ko:
		game.pvis.anim = "fallen"
		ds -= 15; dr -= 6
		res.append(["b", "Tu es au sol, sonné. Tes collègues et la police terminent l'intervention. Arrêt de travail et ITT probables.", ""])
		for o in foes:
			if o["st"] in ["active", "calm", "controlled", "grabbed"]:
				_escort_out(o, "La police")
		_recover()
	var down := []
	for o in foes:
		if is_instance_valid(o["npc"]): o["npc"].set_tag("")
		if o["st"] == "down": down.append(o)
	if S["hit_nosd"] > 0:
		ds -= 3 * S["hit_nosd"]; dr -= 4 * S["hit_nosd"]
		game._fault("%s : %d coup(s) porté(s) sans être attaqué à ce moment-là." % [Data.clean(title), S["hit_nosd"]],
			"Un agent n'a aucun pouvoir de contrainte particulier : seule la légitime défense (art. 122-5 Code pénal) justifie un coup — riposte immédiate, nécessaire et proportionnée. Sinon : violences volontaires (art. 222-13), et carte professionnelle CNAPS en jeu.")
	if S["hit_down"] > 0:
		ds -= 6; dr -= 10
		game._fault("%s : %d coup(s) sur une personne déjà maîtrisée, à terre ou qui se rendait." % [Data.clean(title), S["hit_down"]],
			"Plus aucune menace = plus de légitime défense. Violences volontaires aggravées ; licenciement et retrait de carte professionnelle quasi certains.")
	if down.size() > 0:
		var by_you := false
		var names := []
		for o in down:
			names.append(o["name"])
			if o["hit_by"] > 0: by_you = true
		if by_you:
			ds -= 5; dr -= 8
			game._fault("%s : %s inconscient(s) au sol après tes coups. SAMU appelé." % [Data.clean(title), ", ".join(PackedStringArray(names))],
				"Un seul coup peut tuer (chute, tête sur le sol). Violences ayant entraîné une ITT, voire la mort sans intention de la donner (art. 222-7 Code pénal).")
		else:
			ds -= 3
			res.append(["n", "%s est resté au sol après la bagarre : SAMU appelé." % ", ".join(PackedStringArray(names)), ""])
		for o in down:
			game._free_later(o["npc"], 20.0)
	if S["long_pin"] > 0:
		ds -= 6; dr -= 6
		game._fault("%s : personne maintenue au sol trop longtemps malgré ses plaintes." % Data.clean(title),
			"Risque d'asphyxie posturale : la maîtrise au sol doit être la plus courte possible, puis on relève et on surveille la personne.")
	if S["verb_ok"] > 0:
		ds += 2
		game._good("%s : désescalade verbale efficace." % Data.clean(title))
	if S["grab_ok"] > 0 and S["hit_nosd"] == 0 and S["hit_down"] == 0:
		ds += 4; dr += 2
		game._good("%s : maîtrise par saisie sans coup inutile." % Data.clean(title))
	if S["escort"] > 0:
		game._good("%s : %d personne(s) sortie(s) de l'établissement." % [Data.clean(title), S["escort"]])
	if S["disarm"] > 0:
		ds += 3
		game._good("%s : adversaire désarmé." % Data.clean(title))
	if S["cut"] > 0:
		res.append(["b", "Tu as été blessé en tentant de saisir une personne armée. Face à une arme, la priorité est la distance, l'alerte (17) et la protection du public.", ""])
	# vidéos des témoins
	var bad_gesture: bool = S["hit_nosd"] > 0 or S["hit_down"] > 0 or S["long_pin"] > 0
	if witnesses.size() > 0:
		if bad_gesture:
			dr -= 6
			res.append(["b", "Des clients ont filmé : la vidéo de tes coups circule déjà sur les réseaux sociaux.", ""])
		else:
			dr += 2
			res.append(["", "Des clients ont filmé : on y voit une intervention calme et maîtrisée.", ""])
	for w in witnesses:
		if is_instance_valid(w): w.anim = w.get_meta("prev_anim", "idle")
	witnesses = []
	# police : arme, blessé ou personne interpellée
	var handed := []
	var armed_seen := false
	for o in foes:
		if o["wname"] != "" and (o["weapon"] or S["disarm"] > 0): armed_seen = true
		if o["st"] == "controlled" and is_instance_valid(o["npc"]): handed.append(o)
	if handed.size() > 0 or down.size() > 0 or armed_seen or ko:
		_call_police(handed, fight_pos)
		if handed.size() > 0:
			game._good("%s : %d personne(s) interpellée(s) et remise(s) à la police." % [Data.clean(title), handed.size()])
			res.append(["", "La police arrive et prend en charge la personne maîtrisée.", "Art. 73 du Code de procédure pénale : en cas de délit flagrant, toute personne peut appréhender l'auteur et le conduire devant l'officier de police judiciaire le plus proche."])
	if S["hit_sd"] > 0 and S["hit_nosd"] == 0:
		game._good("%s : riposte en légitime défense, proportionnée." % Data.clean(title))
	if not ko and S["hit_nosd"] == 0 and S["hit_down"] == 0 and down.is_empty() and S["long_pin"] == 0:
		ds += 5; dr += 3
	game.secu += ds
	game.rep += dr
	game._clampg()
	game._mc("%s : intervention physique — %s (coups %d, maîtrises %d, sorties %d)" % [Data.clean(title), "agent au sol" if ko else "terminée",
		S["hit_sd"] + S["hit_nosd"] + S["hit_down"], S["grab_ok"] + S["col_ctrl"], S["escort"]])
	if src.has("inc"):
		var inc: Dictionary = src["inc"]
		inc["st"] = "done"
		var keep := []
		for a in inc["actors"]:
			var is_foe := false
			for o in foes:
				if o["npc"] == a: is_foe = true
			if not is_foe: keep.append(a)
		inc["actors"] = keep
		game._end_inc(inc)
	var body := ""
	for r in res:
		var rc := "#ff8a8a" if r[0] == "b" else ("#9fe0b4" if r[0] == "" else "#ffd27a")
		body += "[color=%s]%s[/color]\n" % [rc, r[1]]
		if r[2] != "": body += "[color=#b9b3cc][i]Loi : %s[/i][/color]\n" % r[2]
		body += "\n"
	body += "[color=#b9b3cc]Coups reçus : %d PV · bloqués %d · esquivés %d\nPoussées %d · saisies réussies %d/%d · injonctions %d · maîtrises par collègues %d\nCoups portés : %d[/color]\n\n" % [
		round(S["taken"]), S["blocked"], S["dodged"], S["push"], S["grab_ok"], S["grab"], S["verb"], S["col_ctrl"], S["hit_sd"] + S["hit_nosd"] + S["hit_down"]]
	body += "[i]Le détail juridique est dans le bilan de fin de nuit.[/i]"
	var cont := func():
		game._close_panel()
		if game.phase == "door" and game.cur == null:
			game._next_client()
	game.ui.open_panel("K.-O." if ko else "Fin de l'intervention", Data.clean(title) + " · " + Data.fmt_clock(game.minute), body,
		[{"t": "Continuer", "k": "main", "cb": cont}])

func _recover() -> void:
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(game.pvis): game.pvis.anim = "idle"
	hp = 55.0

## La police arrive par la rue, rejoint la scène et repart avec les personnes interpellées
func _call_police(handed: Array, where: Vector3) -> void:
	game._set_radio("Police : « Équipage en route, deux minutes. »")
	game._mc("Appel police (17) : %s" % Data.clean(title))
	var cops := []
	for k in 2:
		var c = game._mk_person({"prim": true, "sex": "H", "pos": Vector3(3 + k * 0.8, 0, 6.5), "top": "#1c2a4a", "bottom": "#1c2a4a", "cap": "#16213a", "shoes": "#0d0d0d", "band": "#3a7bff", "no_beard": true, "hs": "buzz"})
		c.pname = "Policier"
		cops.append(c)
	for o in handed:
		o["st"] = "out"
		o["npc"].set_tag("")
	await get_tree().create_timer(6.0).timeout
	for k in cops.size():
		var c = cops[k]
		if not is_instance_valid(c): continue
		c.run = true
		c.walk_to(game.world.route(c.position, where + Vector3(0.8 * k, 0, 0.8)))
	await get_tree().create_timer(12.0).timeout
	game._set_radio("Police : « On prend le relais. Merci pour la main courante. »")
	for o in handed:
		if not is_instance_valid(o["npc"]): continue
		o["npc"].anim = "walk"
		var pts: Array = game.world.route(o["npc"].position, Vector3(0, 0, 2))
		pts.append(Vector2(10, 7)); pts.append(Vector2(30, 7))
		o["npc"].walk_to(pts, func(q): q.queue_free())
	for c in cops:
		if not is_instance_valid(c): continue
		c.run = false
		var pts2: Array = game.world.route(c.position, Vector3(0.5, 0, 2))
		pts2.append(Vector2(10, 7.4)); pts2.append(Vector2(30, 7.4))
		c.walk_to(pts2, func(q): q.queue_free())
