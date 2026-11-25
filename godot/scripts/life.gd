extends Node
## Vie de la salle : barmans, DJ, clients qui changent d'activité (piste, bar, toilettes, fumoir,
## carré VIP), arrivées pendant la nuit et départs progressifs vers la fin.

var game                      # main.gd
var barmen: Array = []
var dj = null
var tick := 0.0
var arrive_t := 25.0
var chat_t := 0.0
var smokers: Array = []
var queue_t := 0.0
var close_done := false

const EXIT_PTS := [Vector2(12, 5), Vector2(28, 5)]

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Personnel : barmans derrière le comptoir et DJ en cabine
func setup() -> void:
	var w = game.world
	var nb: int = 1 if w.vk == "comptoir" else (2 if w.vk != "usine" else 3)
	var bz0: float = w.Zm(-22.0)
	var bz1: float = w.Zm(-10.0)
	var bxs: float = w.geo["barman_x"]
	for i in nb:
		var z: float = lerpf(bz0, bz1, (i + 0.5) / nb)
		var b = game._mk_person({"pos": Vector3(bxs, 0, z), "yaw": PI / 2.0, "no_surv": true})
		b.pname = "Barman"
		b.anim = "idle"
		b.speed = 1.1
		b.set_meta("z0", lerpf(bz0, bz1, float(i) / nb))
		b.set_meta("z1", lerpf(bz0, bz1, float(i + 1) / nb))
		b.set_meta("next", _now() + randf_range(2, 6))
		barmen.append(b)
	# fumeurs sur le trottoir, à côté de l'entrée
	for k in randi_range(2, 4):
		var s = game._mk_person({"pos": Vector3(-3.2 - k * 0.9 + randf_range(-0.2, 0.2), 0, 1.0 + randf_range(-0.2, 0.4)), "yaw": randf_range(-PI, PI)})
		s.anim = ["phone", "talk", "idle"].pick_random()
		s.pname = "Fumeur"
		smokers.append(s)
	if w.vk != "comptoir":
		dj = game._mk_person({"pos": Vector3(0, 0, w.geo["djz"] + 0.35), "yaw": 0.0, "no_surv": true})
		dj.pname = "DJ"
		dj.anim = "dance"

func _busy(n) -> bool:
	if not is_instance_valid(n): return true
	if n.path.size() > 0: return true
	if n.get_meta("fight", false) or n.task != null: return true
	if n == game.sel_npc: return true
	return false

func step(delta: float) -> void:
	if game.player == null: return
	var w = game.world
	var now := _now()
	# barmans : ils servent, essuient, se déplacent le long du comptoir
	for b in barmen:
		if not is_instance_valid(b) or b.path.size() > 0: continue
		if now > float(b.get_meta("next")):
			b.set_meta("next", now + randf_range(4, 9))
			var r := randf()
			if r < 0.4:
				var z: float = randf_range(b.get_meta("z0"), b.get_meta("z1"))
				b.face = PI / 2.0
				b.walk_to([Vector2(w.geo["barman_x"], z)])
			else:
				b.anim = "drink" if r < 0.7 else "talk"
				b.yaw = PI / 2.0
	if dj != null and is_instance_valid(dj):
		dj.yaw = sin(now * 0.4) * 0.3
	# dans la file : on patiente, on regarde son téléphone, on discute
	queue_t -= delta
	if queue_t <= 0.0 and game.phase == "door":
		queue_t = 1.5
		var qq: Array = game.queue
		if qq.size() > 0:
			var c: Dictionary = qq.pick_random()
			var qn = c["npc"]
			if is_instance_valid(qn) and qn.path.is_empty():
				qn.anim = ["idle", "phone", "talk", "idle"].pick_random()
				qn.yaw = -PI / 2.0 + randf_range(-0.9, 0.9)
	# les fumeurs tournent un peu sur eux-mêmes
	for s in smokers:
		if is_instance_valid(s) and randf() < 0.004:
			s.yaw = randf_range(-PI, PI)
			s.anim = ["phone", "talk", "idle"].pick_random()
	# fermeture : tout le monde sort
	if game.world.closing > 0.3 and not close_done:
		close_done = true
		for n in game.crowd.duplicate():
			if not _busy(n) and randf() < 0.85:
				_leave(n)
		for b in barmen:
			if is_instance_valid(b): b.anim = "talk"
		if dj != null and is_instance_valid(dj): dj.anim = "idle"
	tick += delta
	if tick < 0.5: return
	tick = 0.0
	if game.fight.active: return
	var progress := 0.0
	if game.phase == "salle":
		progress = game.salle_t / game.salle_d
	# changements d'activité : quelques clients à la fois, pour que ça reste naturel
	var moved := 0
	var crowd: Array = game.crowd.duplicate()
	crowd.shuffle()
	for n in crowd:
		if moved >= 2: break
		if _busy(n): continue
		if not n.has_meta("next"):
			n.set_meta("next", now + randf_range(8, 40))
			continue
		if now < float(n.get_meta("next")): continue
		n.set_meta("next", now + randf_range(18, 50))
		_new_activity(n, progress)
		moved += 1
	# arrivées pendant la nuit (début de salle), départs vers la fin
	if game.phase == "salle":
		arrive_t -= 0.5
		if arrive_t <= 0.0:
			arrive_t = randf_range(14, 26)
			if progress < 0.6 and game.inside < int(game.cap * 0.9):
				_arrival()
	# petites conversations entre voisins
	chat_t -= 0.5
	if chat_t <= 0.0:
		chat_t = 3.0
		_chat()

func _new_activity(n, progress: float) -> void:
	var w = game.world
	# en fin de nuit, de plus en plus de monde rentre
	var leave_w := 0.03 + maxf(0.0, progress - 0.55) * 1.2
	if randf() < leave_w:
		_leave(n)
		return
	var opts := [["piste", 5.0], ["bar", 4.0], ["toilettes", 1.2], ["fumoir", 1.5]]
	if w.ZR.has("vip"): opts.append(["vip", 1.0])
	var tot := 0.0
	for o in opts: tot += o[1]
	var r := randf() * tot
	var z: String = "piste"
	for o in opts:
		r -= o[1]
		if r <= 0.0:
			z = o[0]; break
	if z == n.zone and z != "piste":
		z = "piste"
	var p: Vector3 = w.zpt(z)
	n.zone = z
	var done := func(q):
		match z:
			"piste":
				q.anim = "dance"; q.yaw = randf_range(-PI, PI)
			"bar":
				q.anim = "talk"
				q.yaw = -PI / 2.0
				_serve(q)
			"toilettes":
				q.anim = ["idle", "phone"].pick_random()
				q.set_meta("next", _now() + randf_range(10, 20))
			"fumoir":
				q.anim = ["talk", "phone"].pick_random(); q.yaw = randf_range(-PI, PI)
			_:
				q.anim = ["talk", "drink", "dance"].pick_random(); q.yaw = randf_range(-PI, PI)
	n.walk_to(w.route(n.position, p), done)

## Le barman le plus proche vient prendre la commande, puis le client boit
func _serve(q) -> void:
	var best = null
	var bd := 99.0
	for b in barmen:
		if not is_instance_valid(b): continue
		var d: float = absf(b.position.z - q.position.z)
		if d < bd:
			bd = d; best = b
	if best == null: return
	var z: float = clampf(q.position.z, minf(best.get_meta("z0"), best.get_meta("z1")) - 1.0, maxf(best.get_meta("z0"), best.get_meta("z1")) + 1.0)
	best.set_meta("next", _now() + 6.0)
	best.face = PI / 2.0
	var bb = best
	var at_client := func(x): x.anim = "talk"
	best.walk_to([Vector2(game.world.geo["barman_x"], z)], at_client)
	var after := func():
		if is_instance_valid(q) and q.path.is_empty() and q.zone == "bar": q.anim = "drink"
		if is_instance_valid(bb) and bb.path.is_empty(): bb.anim = "drink"
	var t := get_tree().create_timer(randf_range(4.0, 7.0))
	t.timeout.connect(after)

func _leave(n) -> void:
	game.crowd.erase(n)
	game.inside = maxi(0, game.inside - 1)
	var pts: Array = game.world.route(n.position, Vector3(randf_range(-0.6, 0.6), 0, 2.0))
	pts.append_array(EXIT_PTS)
	n.walk_to(pts, func(q): q.queue_free())

func _arrival() -> void:
	var w = game.world
	var n = game._mk_person({"pos": Vector3(randf_range(18, 26), 0, 5.0)})
	game.inside += 1
	var z: String = ["piste", "piste", "bar"].pick_random()
	var p: Vector3 = w.zpt(z)
	var pts: Array = [Vector2(1.0, 4.0), Vector2(0, 1.0)]
	pts.append_array(w.route(Vector3(0, 0, 1.0), p))
	n.zone = z
	n.set_meta("next", _now() + randf_range(25, 50))
	game.crowd.append(n)
	var settle := func(q):
		q.anim = "dance" if z == "piste" else "talk"
		q.yaw = -PI / 2.0 if z == "bar" else randf_range(-PI, PI)
	n.walk_to(pts, settle)

## Deux clients immobiles proches se tournent l'un vers l'autre et discutent
func _chat() -> void:
	var c: Array = game.crowd
	if c.size() < 2: return
	for k in 4:
		var a = c.pick_random()
		if _busy(a) or a.zone == "piste": continue
		for b in c:
			if b == a or _busy(b): continue
			var d: float = a.position.distance_to(b.position)
			if d > 0.5 and d < 1.8:
				a.yaw = atan2(b.position.x - a.position.x, b.position.z - a.position.z)
				b.yaw = atan2(a.position.x - b.position.x, a.position.z - b.position.z)
				a.anim = "talk"
				b.anim = ["talk", "drink", "idle"].pick_random()
				return
