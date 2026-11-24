extends Node
## Mode carrière : saisons de 5 nuits, vestiaire entre les nuits, habitués (Kévin, Lucas, Nadia…),
## clients particuliers, événements de porte, appels du gérant, vie de l'équipe, équipement,
## grades, trophées et journal du lendemain. Sauvegarde dans user://carriere.json.

const SAVE := "user://carriere.json"
var game
var D := {}                 # données (data/carriere.json)
var new_troph: Array = []
var cur_ev: Dictionary = {}
var cur_ev_k := ""
var cur_ger := ""
var door_ev := {}           # index de client -> événement de porte
var calls: Array = []
var call_t: Array = []

func _ready() -> void:
	var txt := FileAccess.get_file_as_string("res://data/carriere.json")
	var d = JSON.parse_string(txt)
	if d is Dictionary: D = d

# ---------------------------------------------------------------------
#  Sauvegarde
# ---------------------------------------------------------------------
static func load_save():
	if not FileAccess.file_exists("user://carriere.json"): return null
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://carriere.json"))
	return d if d is Dictionary else null

func save() -> void:
	if Data.CAR == null: return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(Data.CAR))

func new_career() -> void:
	Data.CAR = {"night": 0, "season": 1, "xp": 0, "sat": 60.0, "morale": 70.0, "funds": 150, "equip": {}, "lopez": 0, "martin": 0,
		"samk": 0, "sam": false, "sam_gone": false, "hab": {}, "troph": {}, "hist": [], "discri": false, "papers": [],
		"alea": null, "tev": null, "tev_res": "", "gone": "", "drunk_ag": "", "extra": false}
	_hab_init()
	save()

func C() -> Dictionary:
	return Data.CAR

func N() -> Dictionary:
	return D["NIGHTS3"][int(C()["night"]) % 5]

func nidx() -> int:
	return int(C()["night"]) % 5

func eq(k: String) -> bool:
	return Data.CAR != null and C()["equip"].get(k, false)

func rank(xp: float) -> int:
	var r := 0
	for i in D["RANKS3"].size():
		if xp >= D["RANKS3"][i][0]: r = i
	return r

func trophy(id: String) -> void:
	if Data.CAR == null or C()["troph"].has(id): return
	C()["troph"][id] = 1
	for t in D["TROPH3"]:
		if t["id"] == id: new_troph.append(t)

# ---------------------------------------------------------------------
#  Habitués : un visage fixe pour toute la carrière
# ---------------------------------------------------------------------
func _hab_init() -> void:
	var H: Dictionary = C()["hab"]
	if H.has("kevin"): return
	var mh: Array = Data.CHARS["H"].duplicate()
	var mf: Array = Data.CHARS["F"].duplicate()
	mh.shuffle(); mf.shuffle()
	H["kevin"] = {"n": "Kévin " + Data.NOMS.pick_random(), "model": mh[0] if mh.size() > 0 else "", "age": randi_range(24, 34), "m": randi_range(1, 12), "d": randi_range(1, 28)}
	H["lucas"] = {"n": "Lucas " + Data.NOMS.pick_random(), "bro": Data.PREN_H.pick_random(), "model": mh[1] if mh.size() > 1 else (mh[0] if mh.size() > 0 else "")}
	H["nadia"] = {"n": "Nadia " + Data.NOMS.pick_random(), "ex": Data.PREN_H.pick_random(), "model": mf[0] if mf.size() > 0 else ""}
	H["ex_model"] = mh[2] if mh.size() > 2 else (mh[0] if mh.size() > 0 else "")

# ---------------------------------------------------------------------
#  Préparation d'une nuit
# ---------------------------------------------------------------------
func setup_night() -> void:
	var c := C()
	_hab_init()
	if c["alea"] == null: c["alea"] = D["ALEAS3"][0]
	var n := N()
	var al: Dictionary = c["alea"]
	game.cap = int(round(110.0 * float(n["cap"]) / 110.0))
	game.nq = int(n["nQ"]) + int(al.get("nQ", 0)) + min(3, int(c["season"]) - 1)
	game.mod_minor = float(n["minor"]) * float(al.get("minor", 1))
	game.mod_iv = float(n["iv"]) + float(al.get("iv", 0))
	game.mod_agr = 1 if al.get("agr", 0) else 0
	for x in al.get("inc", []):
		if Data.INC.has(x): game.pend.append(x)
	calls = n["ger"].duplicate()
	calls.shuffle()
	calls = calls.slice(0, 1 + (1 if (int(c["season"]) > 1 or nidx() >= 3) else 0))
	call_t = [70.0, 170.0]

## Après la création des collègues : absences, agent ivre, Sam le débutant
func setup_team() -> void:
	var c := C()
	if c["gone"] != "":
		for a in game.colleagues.duplicate():
			if a.pname == c["gone"]:
				if c["extra"] or a.sex == "H":
					a.pname = "Extra"
				else:
					a.queue_free()
					game.colleagues.erase(a)
	if c["drunk_ag"] != "":
		for a in game.colleagues:
			if a.pname == c["drunk_ag"]:
				a.sway = 0.4
				a.set_meta("drunk", true)
	if c["sam"]:
		var s = game._mk_person({"agent": true, "sex": "H", "pos": Vector3(2.4, 0, 0.4), "skin": Data.SKINS[1], "hair": Data.HAIRS[4], "hs": "short", "height": 1.76, "band": "#e4ff4d", "no_beard": true, "yaw": PI})
		s.pname = "Sam"
		s.home = Vector3(-6, 0, -18)
		s.set_meta("rookie", true)
		game.colleagues.append(s)
	if c["morale"] < 40:
		for a in game.colleagues: a.set_meta("slow", true)

## Les habitués et les clients particuliers prennent place dans la file
func queue_specials() -> void:
	var n := N()
	var sp := ["kevin", "lucas", "nadia"]
	for x in n["special"]:
		if not x in ["chienperso", "chienguide", "fauteuil"]: sp.append(x)
	if nidx() >= 1 and nidx() <= 3: sp.append("nadiaex")
	var free := []
	for i in range(1, game.queue.size()):
		var q = game.queue[i]
		if q["black"] == null and not q["testing"]: free.append(i)
	var early := []
	var late := []
	for i in free:
		if i <= 12: early.append(i)
		else: late.append(i)
	early.shuffle(); late.shuffle()
	var slots := early + late
	for j in sp.size():
		if j >= slots.size(): break
		var i: int = slots[j]
		var old = game.queue[i]
		if old.has("npc") and is_instance_valid(old["npc"]):
			old["npc"].queue_free()
			for m in old["mates"]: m.queue_free()
		var c := special(sp[j], i)
		if c.is_empty(): continue
		game.queue[i] = c
		game._mk_client_npc(c, i)

func _base(i: int, o := {}) -> Dictionary:
	var c: Dictionary = game._gen_client(i, o)
	c["att"] = "calme"; c["drug"] = false; c["weapon"] = false; c["iv"] = 0
	c["has_id"] = true; c["borrowed"] = false; c["id_name"] = ""; c["minor"] = false
	c["extra_cues"] = []
	return c

func _set_dob(c: Dictionary, y: int, m: int, d: int) -> void:
	c["dob"] = [y, m, d]
	c["id_age"] = Data.age_from(y, m, d)

func special(k: String, i: int) -> Dictionary:
	var n := nidx()
	var H: Dictionary = C()["hab"]
	var c := {}
	match k:
		"kevin":
			var h: Dictionary = H["kevin"]
			c = _base(i, {"sex": "H", "minor": false})
			var p: PackedStringArray = h["n"].split(" ")
			c["first"] = p[0]; c["last"] = p[1]; c["hab"] = "kevin"; c["model"] = h["model"]
			c["iv"] = [0, 1, 2, 0, 0][n]; c["att"] = ["calme", "impatient", "arrogant", "calme", "calme"][n]; c["size"] = [2, 3, 2, 1, 2][n]
			c["age"] = int(h["age"])
			_set_dob(c, Data.GAME_Y - int(h["age"]) - (1 if int(h["m"]) > Data.GAME_M else 0), int(h["m"]), int(h["d"]))
			c["id_type"] = "Permis de conduire"
			c["extra_cues"].append("Habitué : Kévin, client de tous les week-ends")
			if n == 1: c["extra_cues"].append("Veut passer devant tout le monde parce qu'il est habitué")
			c["quote"] = ["« Salut chef ! Kévin, tu te souviens de moi ? Je viens tous les week-ends ! »", "« Allez, fais-moi passer devant la file, on se connaît maintenant ! »", "« Ch'uis un habitué… tu peux pas me refuser, moi… »", "« Je suis venu m'excuser pour la dernière fois. Ce soir je reste sobre, promis. »", "« Je te présente ma copine ! C'est notre premier rendez-vous ici. »"][n]
		"lucas":
			var h2: Dictionary = H["lucas"]
			c = _base(i, {"sex": "H", "minor": false})
			var p2: PackedStringArray = h2["n"].split(" ")
			c["first"] = p2[0]; c["last"] = p2[1]; c["hab"] = "lucas"; c["model"] = h2["model"]
			c["minor"] = n < 4; c["age"] = 17 if n < 4 else 18; c["size"] = 3 if n == 4 else 2
			c["id_type"] = "Carte nationale d'identité"
			c["young"] = true
			_set_dob(c, Data.GAME_Y - 17, (Data.GAME_M + 1) % 12 + 1, randi_range(1, 28))
			c["extra_cues"].append("Lucas, le petit frère de %s, le barman" % h2["bro"])
			match n:
				0:
					c["has_id"] = false
					c["quote"] = "« Je suis le frère de %s, le barman ! Il m'a dit que je pouvais venir. »" % h2["bro"]
				1:
					c["borrowed"] = true
					c["id_name"] = h2["bro"] + " " + c["last"]
					_set_dob(c, Data.GAME_Y - 23, 4, 12)
					c["quote"] = "« Voilà ma carte. Tranquille. » (il évite ton regard)"
				2:
					c["has_id"] = false
					c["student_card"] = true
					c["quote"] = "« J'ai que ma carte étudiante, mais je suis en première année ! »"
				3:
					c["altered"] = true
					c["true_dob"] = c["dob"]
					_set_dob(c, Data.GAME_Y - 19, 2, 3)
					c["quote"] = "« Cette fois j'ai ma vraie carte, regarde. »"
				4:
					_set_dob(c, Data.GAME_Y - 18, Data.GAME_M, Data.GAME_D)
					c["quote"] = "« Cette fois c'est la bonne : j'ai 18 ans AUJOURD'HUI ! Regarde la date ! »"
					c["extra_cues"].append("Ses amis portent des ballons « 18 ans »")
		"nadia":
			var h3: Dictionary = H["nadia"]
			c = _base(i, {"sex": "F", "minor": false})
			var p3: PackedStringArray = h3["n"].split(" ")
			c["first"] = p3[0]; c["last"] = p3[1]; c["hab"] = "nadia"; c["model"] = h3["model"]; c["size"] = 2
			c["extra_cues"].append(["Nadia, une habituée souriante", "Nadia, l'habituée. Elle a l'air inquiète et regarde derrière elle", "Nadia, l'habituée. Fatiguée, elle garde son téléphone à la main", "Nadia, l'habituée. Elle tient une enveloppe officielle", "Nadia, l'habituée, avec un bouquet de fleurs"][n])
			c["quote"] = ["« Bonsoir ! Comme d'habitude ce soir. »", "« Si un grand brun, %s, demande après moi… ne lui dites pas que je suis là, s'il vous plaît. »" % h3["ex"], "« Ça va mieux… mais il m'envoie encore des messages. Si je demande Angela au bar, vous savez. »", "« J'ai obtenu une ordonnance de protection : il n'a plus le droit de m'approcher. »", "« Ces fleurs sont pour toute l'équipe. Grâce à vous, je me sens en sécurité ici. Merci. »"][n]
		"nadiaex":
			c = _base(i, {"sex": "H", "minor": false})
			c["first"] = H["nadia"]["ex"]; c["hab"] = "nadiaex"; c["model"] = H.get("ex_model", "")
			c["att"] = "menacant" if n >= 2 else "impatient"; c["size"] = 1
			c["quote"] = "« Nadia est là ? C'est ma copine, je dois lui parler. »"
			c["extra_cues"].append("Grand, brun, scrute l'intérieur par-dessus ton épaule")
		"etranger":
			c = _base(i, {"minor": false}); c["size"] = 2; c["protect"] = "origine"
			c["id_type"] = ["Passeport britannique", "Carte d'identité italienne", "Passeport américain", "Carte d'identité belge", "Passeport brésilien"].pick_random()
			c["extra_cues"].append("Touristes, parlent français avec un fort accent")
			c["quote"] = "« Bonsoir ! Hmm… deux personnes, please ? »"
		"senior":
			c = _base(i, {"minor": false}); c["size"] = 2; c["protect"] = "age"
			c["age"] = randi_range(62, 68)
			_set_dob(c, Data.GAME_Y - int(c["age"]) - 1, randi_range(1, 10), randi_range(1, 28))
			c["extra_cues"].append("La soixantaine, très élégants")
			c["quote"] = "« On fête nos 40 ans de mariage, on venait danser ici quand on était jeunes ! »"
		"foulard":
			c = _base(i, {"sex": "F", "minor": false}); c["size"] = 3; c["protect"] = "religion"; c["tenue"] = "robe"
			c["prim"] = true; c["look"] = {"cap": "#5b3a6e", "hs": "bun"}
			c["extra_cues"].append("Porte un foulard sur les cheveux, en tenue de soirée, avec deux amies")
		"trans":
			c = _base(i, {"sex": "F", "minor": false}); c["size"] = 2; c["protect"] = "genre"
			c["id_name"] = Data.PREN_H.pick_random() + " " + c["last"]; c["id_sex"] = "M"; c["trans_id"] = true
			c["quote"] = "« Bonsoir. Je préfère prévenir : ma pièce est à mon ancien prénom, le changement d'état civil est en cours. »"
		"sourd":
			c = _base(i, {"minor": false}); c["size"] = 2; c["protect"] = "handicap"; c["deaf"] = true
			c["extra_cues"].append("Malentendant : il te montre un message écrit sur son téléphone")
			c["quote"] = "(Sur son téléphone : « Bonsoir, je suis sourd. Nous sommes deux, merci ! »)"
		"garcons":
			c = _base(i, {"sex": "H", "minor": false}); c["size"] = 4; c["protect"] = "sexe"
			c["extra_cues"].append("Quatre hommes, aucune femme dans le groupe")
			c["quote"] = "« Bonsoir, on est quatre, c'est l'enterrement de vie de garçon d'un pote. »"
		"mystere":
			c = _base(i, {"minor": false}); c["size"] = 1; c["mystere"] = true
			c["quote"] = "« Bonsoir. Une personne, s'il vous plaît. » (il observe attentivement l'accueil)"
		"altered":
			c = game._gen_client(i, {"minor": true})
			c["extra_cues"] = []
			c["has_id"] = true; c["borrowed"] = false; c["id_name"] = ""; c["minor"] = true
			c["altered"] = true; c["true_dob"] = c["dob"]; c["young"] = true
			_set_dob(c, Data.GAME_Y - randi_range(19, 21), randi_range(1, 12), randi_range(1, 28))
		"evjf":
			c = _base(i, {"sex": "F", "minor": false}); c["iv"] = 1; c["att"] = "impatient"; c["size"] = 5
			c["bottle"] = randf() < 0.6
			c["extra_cues"].append("Enterrement de vie de jeune fille, cinq copines en diadèmes")
			if c["bottle"] and randf() < 0.5: c["extra_cues"].append("L'une d'elles a quelque chose de lourd dans son sac")
			c["quote"] = "« C'est le dernier soir de liberté de Julie !!! »"
		"vip":
			c = _base(i, {"sex": "H", "minor": false}); c["first"] = "Maxime"; c["last"] = "Rolland"; c["vip"] = true; c["size"] = 4
			if n == 2 or (n == 4 and randf() < 0.5):
				c["iv"] = 2; c["att"] = "arrogant"
				c["quote"] = "« Wesh, on a gagné ce soir ! Laisse passer les champions ! »"
			else:
				c["quote"] = "« Bonsoir, on est sur la liste du patron, merci à vous. »"
			c["extra_cues"].append("Troisième ligne du club de rugby local, sur la liste VIP du gérant")
	if not c.is_empty():
		c["special"] = k
		c["cues"] = []
	return c

# ---------------------------------------------------------------------
#  Évaluation des clients particuliers (porte)
# ---------------------------------------------------------------------
func eval_admit(c: Dictionary, res: Array) -> void:
	var n := nidx()
	if c.get("found", "") == "bouteille":
		game.rep -= 2
		res.append(["n", "La bouteille entre avec elles : alcool extérieur en salle.", ""])
		game.pend.append("vomi")
	if c.get("hab", "") == "nadiaex":
		game.secu -= 10 if n >= 2 else 6
		game.rep -= 5
		game._fault("%s, l'homme que Nadia redoutait, est entré." % c["first"], "Il est visé par une ordonnance de protection : délit s'il l'approche (art. 227-4-2 Code pénal)." if n == 3 else "Une cliente avait signalé un danger : la protection des personnes passe avant l'entrée d'un client.")
		res.append(["b", "Il file droit vers le bar en cherchant Nadia du regard.", ""])
		game.pend.append("conjugal" if Data.INC.has("conjugal") else "bagarre")
	if c.get("hab", "") == "lucas" and not c["minor"]:
		trophy("lucas")
		res.append(["", "Lucas lève les bras : « Enfin ! » Son frère lui offre un soft au bar.", ""])
	if c.get("hab", "") == "nadia" and n == 4:
		trophy("nadia")
		game.rep += 3
		C()["morale"] = clamp(C()["morale"] + 4, 0, 100)
		res.append(["", "Les fleurs passent de main en main dans l'équipe. Ce genre de soirée rappelle pourquoi on fait ce métier.", ""])
	if c.get("mystere", false):
		var bad := false
		for r in res:
			if r[0] == "b": bad = true
		C()["sat"] = clamp(C()["sat"] + (-6 if bad else (6 if c["id_checked"] else -2)), 0, 100)
		if not bad and c["id_checked"]:
			game.rep += 3
			game._good("Client mystère de la direction : accueil jugé professionnel.")
		res.append(["b" if bad else ("" if c["id_checked"] else "n"), "(C'était un [b]client mystère[/b] envoyé par la direction : %s.)" % ("rapport sévère" if bad else ("rapport excellent" if c["id_checked"] else "il note que la pièce d'identité n'a pas été contrôlée"))])

## Renvoie true si le refus a été traité ici (cas particuliers)
func eval_refuse(c: Dictionary, valid: bool, res: Array) -> bool:
	if valid:
		if c.get("hab", "") == "nadiaex": res.append(["", "Il repart en jurant. L'équipe garde un œil sur la rue : Nadia est en sécurité.", ""])
		if c.get("hab", "") == "kevin" and c["iv"] == 2: res.append(["", "Kévin râle mais rentre chez lui. Il reviendra s'excuser…", ""])
		return false
	if c.get("hab", "") == "lucas" and not c["minor"]:
		game.rep -= 4
		game._fault("Lucas refusé alors qu'il avait 18 ans ce jour-là.", "La majorité est acquise le jour de l'anniversaire : une pièce valide prouvant 18 ans suffit.")
		res.append(["b", "Il avait 18 ans aujourd'hui : la date était sur sa carte.", ""])
		return true
	if c.get("mystere", false):
		game.rep -= 8
		C()["sat"] = clamp(C()["sat"] - 10, 0, 100)
		game._fault("Client mystère refusé sans motif objectif.", "Un refus doit toujours reposer sur un motif objectif et identique pour tous.")
		res.append(["b", "C'était un [b]client mystère[/b] de la direction : rapport catastrophique.", ""])
		return true
	if c.has("protect"):
		var crit: String = {"origine": "l'origine", "age": "l'âge", "religion": "la religion", "genre": "l'identité de genre", "handicap": "le handicap", "sexe": "le sexe"}.get(c["protect"], "un critère personnel")
		game.rep -= 14
		C()["discri"] = true
		game._fault("Refus de %s %s : motif lié à %s." % [c["first"], c["last"], crit], "Discrimination (art. 225-1 et 225-2 Code pénal) : refuser l'accès en raison de %s est puni jusqu'à 5 ans et 75 000 € dans un lieu ouvert au public." % crit)
		res.append(["b", "Aucun motif objectif : le groupe filme ton refus et parle de porter plainte.", ""])
		return true
	return false

# ---------------------------------------------------------------------
#  Événements de porte
# ---------------------------------------------------------------------
func plan_door_events() -> void:
	var evs := ["lopez"]
	if nidx() >= 1: evs.append("martin")
	if nidx() == 3: evs.append("ordonnance")
	for e in C()["alea"].get("ev", []):
		if Data.DOOR_EV.has(e) or e in ["controle"]: evs.append(e)
	var pool := []
	for k in Data.DOOR_EV.keys():
		if not k in ["ordonnance", "controle", "revanche", "supporters", "pluie"] and not k in evs: pool.append(k)
	pool.shuffle()
	evs.append_array(pool.slice(0, 3))
	evs.shuffle()
	evs = evs.slice(0, 5)
	door_ev = {}
	var L: int = game.queue.size()
	for j in evs.size():
		door_ev[1 + int((j + 0.5) * (L - 2) / max(1, evs.size()))] = evs[j]

func _lopez() -> Dictionary:
	return D["LOPEZ"]["%d_%d" % [nidx(), clamp(int(C()["lopez"]), 0, 2)]]

func _martin() -> Dictionary:
	return D["MARTIN"]["%d_%d" % [nidx(), clamp(int(C()["martin"]), 0, 1)]]

func door_event(k: String) -> void:
	var e: Dictionary = {}
	if k == "lopez": e = _lopez()
	elif k == "martin": e = _martin()
	elif Data.DOOR_EV.has(k): e = Data.DOOR_EV[k]
	if e.is_empty() or not e.has("o"):
		game._next_client(true)
		return
	cur_ev = e
	cur_ev_k = k
	game.audio.sfx("radio")
	if e.get("special", "") == "controle":
		var names := []
		for a in game.colleagues: names.append(a.pname)
		game.ui.open_panel(e["t"], "", e["d"] + "\n\n[color=#9fe0b4]%s : cartes professionnelles valides.[/color]" % ", ".join(PackedStringArray(names)), [
			{"t": "Présenter les cartes de toute l'équipe", "k": "main", "cb": _controle_ok}])
		return
	var order := range(e["o"].size())
	order.shuffle()
	var bts := []
	for oi in order:
		var idx: int = oi
		bts.append({"t": Data.lbl(e["o"][idx]["t"]), "cb": func(): _door_do(idx)})
	if k in ["file", "revanche", "supporters", "dealers"]:
		bts.append({"t": "Intervention physique", "k": "bad", "cb": _door_brawl})
	game.ui.open_panel(e["t"], "Porte · " + Data.fmt_clock(game.minute), e["d"], bts)

func _controle_ok() -> void:
	game.rep += 3
	game._good("Contrôle police : équipe en règle, registre tenu.")
	game._mc("Porte — contrôle des cartes professionnelles")
	game._clampg()
	game._result_panel("Contrôle terminé", [["", "Le policier vérifie les cartes et le registre : tout est en règle.", ""]], _next_after_event)

func _next_after_event() -> void:
	game._next_client(true)

func _door_do(i: int) -> void:
	var e := cur_ev
	var o: Dictionary = e["o"][i]
	var c := C()
	if o.has("lp"): c["lopez"] = int(c["lopez"]) + int(o["lp"])
	if o.has("mt"): c["martin"] = int(c["martin"]) + int(o["mt"])
	if o.has("sat"): c["sat"] = clamp(float(c["sat"]) + float(o["sat"]), 0, 100)
	if o.has("mo"): c["morale"] = clamp(float(c["morale"]) + float(o["mo"]), 0, 100)
	if o.has("tr"): trophy(o["tr"])
	if cur_ev_k == "pourboire" and o.has("g"): trophy("incorr")
	game.secu += float(o.get("s", 0))
	game.rep += float(o.get("r", 0))
	if o.has("f"): game._fault("%s : %s" % [Data.clean(e["t"]), o["f"]], o.get("law", ""))
	if o.has("g"): game._good("%s : %s" % [Data.clean(e["t"]), o["g"]])
	game._mc("Porte — %s : %s" % [Data.clean(e["t"]), o["t"].split(",")[0].to_lower()])
	var res := [["" if o.has("g") else ("b" if o.has("f") else "n"), o.get("g", o.get("txt", o.get("f", ""))), o.get("law", "")]]
	if o.has("f") and o.has("txt"): res.append(["b", o["txt"], ""])
	if o.has("g") and randf() < 0.22:
		var x = [["…mais ça a pris du temps : la file s'impatiente et deux groupes partent.", -2, 0], ["…le gérant aurait préféré qu'on fasse autrement, et il te le fait savoir.", 0, -2]].pick_random()
		game.rep += x[1]
		c["sat"] = clamp(float(c["sat"]) + x[2], 0, 100)
		res.append(["n", "Complication : " + x[0], ""])
	game.minute += 4
	game._clampg()
	game._result_panel("Bonne réponse" if o.has("g") else ("Faute" if o.has("f") else "Résultat"), res, _next_after_event)

func _door_brawl() -> void:
	var P: Vector3 = game.player.position
	var a = game._mk_person({"sex": "H", "pos": P + Vector3(1.6, 0, 1.4)})
	var b = game._mk_person({"sex": "H", "pos": P + Vector3(2.4, 0, 1.8)})
	game.fight.start({"npc": a, "mates": [b], "name": Data.PREN_H.pick_random(), "title": Data.clean(cur_ev["t"]), "door": true, "from_ev": true})

# ---------------------------------------------------------------------
#  Appels du gérant (en salle)
# ---------------------------------------------------------------------
func step_salle() -> bool:
	if calls.size() > 0 and call_t.size() > 0 and game.salle_t > call_t[0] and not game.fight.active:
		call_t.pop_front()
		_ger_call(calls.pop_front())
		return true
	return false

func _ger_call(k: String) -> void:
	if not Data.GER.has(k): return
	var e: Dictionary = Data.GER[k]
	cur_ger = k
	game.audio.sfx("radio")
	game._set_radio("Ton téléphone vibre : le gérant.")
	var order := range(e["o"].size())
	order.shuffle()
	var bts := []
	for oi in order:
		var idx: int = oi
		bts.append({"t": Data.lbl(e["o"][idx]["t"]), "cb": func(): _ger_do(idx)})
	game.ui.open_panel(e["t"], "Appel · " + Data.fmt_clock(game.minute), e["d"], bts)

func _ger_do(i: int) -> void:
	var e: Dictionary = Data.GER[cur_ger]
	var o: Dictionary = e["o"][i]
	game.secu += float(o.get("s", 0))
	game.rep += float(o.get("r", 0))
	if o.has("sat"): C()["sat"] = clamp(float(C()["sat"]) + float(o["sat"]), 0, 100)
	game._clampg()
	if o.has("f"): game._fault("Appel du gérant — %s" % o["f"], o.get("law", ""))
	if o.has("g"): game._good("Appel du gérant : %s" % o["g"])
	game._mc("Appel du gérant : %s" % o["t"].split(",")[0].to_lower())
	var res := [["" if o.has("g") else ("b" if o.has("f") else "n"), o.get("g", o.get("txt", o.get("f", ""))), o.get("law", "")]]
	if o.has("f") and o.has("txt"): res.append(["b", o["txt"], ""])
	if o.get("act", "") == "cap":
		game.inside += 30
		game.pend.append_array(["chaleur", "malaise"])
		res.append(["n", "La salle est bondée : %d/%d." % [game.inside, game.cap], ""])
	if o.get("act", "") == "agentOff" and game.colleagues.size() > 0:
		var a = game.colleagues[game.colleagues.size() - 1]
		a.walk_to(game.world.route(a.position, Vector3(0, 0, 1)) + [Vector2(10, 5), Vector2(28, 5)], func(q): q.visible = false)
		game.colleagues.erase(a)
		C()["morale"] = clamp(float(C()["morale"]) - 6, 0, 100)
		res.append(["n", "%s rentre chez lui/elle : un agent de moins jusqu'à la fermeture." % a.pname, ""])
	game._result_panel("Bonne réponse" if o.has("g") else ("Faute" if o.has("f") else "Résultat"), res, null)

# ---------------------------------------------------------------------
#  Vie de l'équipe (entre deux nuits)
# ---------------------------------------------------------------------
func _team_event() -> Dictionary:
	var c := C()
	var n := nidx()
	var tm: Array = ["Moussa", "Sarah"]
	if n == 1 and not c["sam"] and not c["sam_gone"]:
		return {"id": "sam_arrive", "t": "Sam rejoint l'équipe", "d": "22 ans, tout juste diplômé, carte professionnelle toute neuve. Le gérant te le confie : « Forme-le, il a du potentiel. » Il est très motivé, mais très stressé.",
			"o": ["Le prendre en binôme ce soir et lui expliquer chaque décision", "Le mettre directement au bar, il apprendra sur le tas"]}
	if n == 3 and c["sam"]:
		return {"id": "sam_doute", "t": "Sam doute", "d": "Après sa soirée difficile, Sam t'attend au vestiaire : « Je crois que ce métier n'est pas fait pour moi… »",
			"o": ["Prendre 10 minutes pour débriefer avec lui, sans le juger, et lui fixer un objectif simple pour ce soir", "« Endurcis-toi, c'est la nuit, c'est comme ça. »"]}
	if n == 4 and c["sam"]:
		if int(c["samk"]) >= 2:
			return {"id": "sam_ok", "t": "Sam a pris confiance", "d": "Grâce à ton accompagnement, Sam est devenu un agent fiable. Il te remercie : « Sans toi, j'aurais lâché. »", "o": ["Le féliciter devant l'équipe"]}
		if int(c["samk"]) <= 0:
			return {"id": "sam_part", "t": "Sam a démissionné", "d": "Par SMS cet après-midi : « Ce métier n'est pas pour moi. » Un jeune à qui personne n'a vraiment tendu la main.", "o": ["Prendre acte"]}
	var a: String = tm.pick_random()
	var b: String = "Sarah" if a == "Moussa" else "Moussa"
	var ev := [
		{"id": "debauche", "a": a, "t": "Le concurrent débauche", "d": "Le gérant du club d'en face propose à [b]%s[/b] 30 € de plus par soirée." % a, "o": ["Prendre sur ton fonds d'équipe pour lui verser une prime (60 €)", "Lui parler de l'équipe et de ses perspectives"]},
		{"id": "conflit", "t": "Conflit dans l'équipe", "d": "[b]%s[/b] et [b]%s[/b] ne se parlent plus depuis une dispute sur les pauses." % [a, b], "o": ["Organiser une explication à trois et revoir le planning des pauses", "Ignorer, ce sont des adultes"]},
		{"id": "alcool", "a": a, "t": "Arrivé avec de l'alcool", "d": "[b]%s[/b] arrive en retard en sentant l'alcool : « C'était l'anniversaire de mon frère, ça va, je gère. »" % a, "o": ["Le/la renvoyer chez lui/elle ce soir (inapte au service)", "Le/la laisser travailler"]},
		{"id": "malade", "t": "Sarah malade", "d": "Sarah t'appelle : forte fièvre, arrêt maladie.", "o": ["Trouver une extra pour la soirée (−40 € sur le fonds)", "Travailler en sous-effectif"]}]
	if float(c["sat"]) >= 65:
		ev.append({"id": "prime", "t": "Prime du gérant", "d": "Content de l'équipe, le gérant te donne 80 € de prime à répartir.", "o": ["La partager avec l'équipe", "La mettre dans le fonds d'équipement"]})
	return ev.pick_random()

func _team_do(i: int) -> void:
	var c := C()
	var e: Dictionary = c["tev"]
	var r := ""
	match e["id"]:
		"sam_arrive":
			c["sam"] = true
			if i == 0:
				c["samk"] = int(c["samk"]) + 1
				r = "Sam te suit comme ton ombre et prend des notes. Il sera en salle avec le reste de l'équipe."
			else:
				r = "Sam prend son poste seul, un peu perdu."
		"sam_doute":
			if i == 0:
				c["samk"] = int(c["samk"]) + 1
				c["morale"] = clamp(float(c["morale"]) + 3, 0, 100)
				r = "Sam respire mieux. « Merci… personne n'avait pris le temps de m'expliquer. »"
			else:
				c["samk"] = int(c["samk"]) - 1
				r = "Sam baisse la tête et prend son poste sans un mot."
		"sam_ok":
			trophy("sam")
			c["morale"] = clamp(float(c["morale"]) + 5, 0, 100)
			r = "L'équipe applaudit. Le moral grimpe."
		"sam_part":
			c["sam"] = false; c["sam_gone"] = true
			c["morale"] = clamp(float(c["morale"]) - 5, 0, 100)
			r = "L'équipe est touchée par son départ."
		"debauche":
			if i == 0:
				c["funds"] = int(c["funds"]) - 60
				c["morale"] = clamp(float(c["morale"]) + 3, 0, 100)
				r = "%s reste, touché(e) d'être reconnu(e)." % e["a"]
			elif randf() < float(c["morale"]) / 100.0:
				c["morale"] = clamp(float(c["morale"]) + 2, 0, 100)
				r = "%s reste : « Ici, on se serre les coudes. »" % e["a"]
			else:
				c["gone"] = e["a"]
				c["morale"] = clamp(float(c["morale"]) - 4, 0, 100)
				r = "%s part ce soir chez le concurrent : un extra le/la remplace, moins expérimenté." % e["a"]
		"conflit":
			if i == 0:
				c["morale"] = clamp(float(c["morale"]) + 6, 0, 100)
				r = "Explication franche, planning revu : l'ambiance s'apaise."
			else:
				c["morale"] = clamp(float(c["morale"]) - 7, 0, 100)
				r = "Le conflit pourrit l'ambiance : ils mettront plus de temps à réagir ce soir."
		"alcool":
			if i == 0:
				c["gone"] = e["a"]
				r = "%s rentre. Un extra le/la remplace. Un agent alcoolisé en service est un danger pour tous." % e["a"]
			else:
				c["drunk_ag"] = e["a"]
				r = "%s prend son poste… avec des réflexes émoussés." % e["a"]
		"malade":
			if i == 0:
				c["funds"] = int(c["funds"]) - 40
				c["gone"] = "Sarah"; c["extra"] = true
				r = "Une extra la remplace ce soir."
			else:
				c["gone"] = "Sarah"
				r = "Tu feras sans agent féminin ce soir : les palpations de femmes seront impossibles."
		"prime":
			if i == 0:
				c["morale"] = clamp(float(c["morale"]) + 7, 0, 100)
				r = "L'équipe apprécie le geste : le moral grimpe."
			else:
				c["funds"] = int(c["funds"]) + 80
				r = "+80 € pour l'équipement."
	c["tev_res"] = r
	save()
	vestiaire()

# ---------------------------------------------------------------------
#  Vestiaire
# ---------------------------------------------------------------------
func vestiaire() -> void:
	var c := C()
	var n := N()
	if c["alea"] == null:
		c["alea"] = D["ALEAS3"][0] if int(c["night"]) == 0 else D["ALEAS3"].pick_random()
	if c["tev"] == null:
		c["tev"] = _team_event()
		c["tev_res"] = ""
	save()
	var r := rank(float(c["xp"]))
	var nx = D["RANKS3"][r + 1] if r + 1 < D["RANKS3"].size() else null
	var mood := "excellent" if c["morale"] >= 75 else ("correct" if c["morale"] >= 55 else ("en baisse" if c["morale"] >= 35 else "au plus bas"))
	var nt := 0
	for t in D["TROPH3"]:
		if c["troph"].has(t["id"]): nt += 1
	var team := "Moussa, Sarah" + (", Sam (débutant)" if c["sam"] else "") + ((" · [b]%s[/b] absent(e) ce soir" % c["gone"]) if c["gone"] != "" else "")
	var body := "[color=#b9b3cc]Saison %d · %s — %s[/color]\n\n" % [c["season"], n["name"], n["sub"]]
	body += "[color=#ffc04d][b]%s[/b][/color] · %d XP%s\n" % [D["RANKS3"][r][1], c["xp"], (" · prochain grade : %s (%d XP)" % [nx[1], nx[0]]) if nx != null else " · grade maximal"]
	body += "Gérant : [b]%d/100[/b] · Moral de l'équipe : [b]%s[/b] · Fonds : [b]%d €[/b]\n" % [round(c["sat"]), mood, c["funds"]]
	body += "Équipe : %s\n\n" % team
	body += "[color=#ffd27a][b]Ce soir : %s[/b][/color]\n%s\n\n" % [Data.clean(c["alea"]["t"]), c["alea"]["d"]]
	var tev: Dictionary = c["tev"]
	body += "[color=#c8a8ff][b]%s[/b][/color]\n%s\n" % [tev["t"], tev["d"]]
	if c["tev_res"] != "": body += "\n[color=#9fe0b4]%s[/color]\n" % c["tev_res"]
	var bts := []
	if c["tev_res"] == "":
		for i in tev["o"].size():
			var idx: int = i
			bts.append({"t": tev["o"][i], "cb": func(): _team_do(idx)})
	bts.append({"t": "Prendre son service" if c["tev_res"] != "" else "Règle d'abord la situation de l'équipe", "k": "main", "off": c["tev_res"] == "", "cb": _go})
	bts.append({"t": "Équipement (fonds : %d €)" % c["funds"], "cb": _shop})
	bts.append({"t": "Trophées (%d/%d) et revue de presse" % [nt, D["TROPH3"].size()], "cb": _trophies})
	bts.append({"t": "Menu principal", "cb": func(): game._menu()})
	game.ui.show_screen("Vestiaire — nuit %d" % (int(c["night"]) + 1), body, bts)

func _go() -> void:
	game.ui.hide_screen()
	game._start()

func _shop() -> void:
	var c := C()
	var body := "[color=#b9b3cc]Fonds d'équipe : [b]%d €[/b][/color]\n\n" % c["funds"]
	var bts := []
	for k in D["EQUIP3"].keys():
		var e: Dictionary = D["EQUIP3"][k]
		var own: bool = c["equip"].get(k, false)
		body += "[b]%s[/b] — %s\n[color=#b9b3cc]%s[/color]\n\n" % [Data.clean(e["n"]), "acquis" if own else "%d €" % e["p"], e["d"]]
		if not own:
			var kk: String = k
			bts.append({"t": "Acheter : %s (%d €)" % [Data.clean(e["n"]), e["p"]], "k": "cy", "off": int(c["funds"]) < int(e["p"]), "cb": func(): _buy(kk)})
	bts.append({"t": "Retour au vestiaire", "k": "main", "cb": vestiaire})
	game.ui.show_screen("Équipement", body, bts)

func _buy(k: String) -> void:
	var c := C()
	var e: Dictionary = D["EQUIP3"][k]
	if int(c["funds"]) < int(e["p"]): return
	c["funds"] = int(c["funds"]) - int(e["p"])
	c["equip"][k] = true
	var all := true
	for x in D["EQUIP3"].keys():
		if not c["equip"].get(x, false): all = false
	if all: trophy("equip")
	save()
	_shop()

func _trophies() -> void:
	var c := C()
	var body := ""
	for t in D["TROPH3"]:
		var got: bool = c["troph"].has(t["id"])
		body += "%s[b]%s[/b] — %s%s\n" % ["" if got else "[color=#6b6680]", t["n"], t["d"], "" if got else " (verrouillé)[/color]"]
	body += "\n[b]Revue de presse[/b]\n"
	var papers: Array = c["papers"]
	if papers.is_empty(): body += "[color=#b9b3cc]Rien pour l'instant.[/color]\n"
	for k in range(papers.size() - 1, max(-1, papers.size() - 7), -1):
		var p: Dictionary = papers[k]
		body += "[color=%s]Nuit %d — [b]%s[/b][/color]\n[i]%s[/i]\n\n" % ["#ff8a8a" if p["bad"] else "#9fe0b4", p["n"], p["t"], p["sub"]]
	game.ui.show_screen("Trophées", body, [{"t": "Retour au vestiaire", "k": "main", "cb": vestiaire}])

# ---------------------------------------------------------------------
#  Fin de nuit
# ---------------------------------------------------------------------
func end_night(note: int) -> String:
	var c := C()
	var night0 := int(c["night"])
	c["night"] = night0 + 1
	if int(c["night"]) % 5 == 0: c["season"] = int(c["season"]) + 1
	var xp: int = max(0, note * 10 + game.goods.size() * 4 - game.faults.size() * 3)
	var r0 := rank(float(c["xp"]))
	c["xp"] = int(c["xp"]) + xp
	var r1 := rank(float(c["xp"]))
	c["sat"] = clamp(float(c["sat"]) + (note - 11) * 1.6 + (game.rep - 60.0) * 0.08, 0, 100)
	c["funds"] = int(c["funds"]) + int(round(60 + note * 6))
	c["morale"] = clamp(float(c["morale"]) + (3 if game.faults.size() <= 2 else -3), 0, 100)
	var hl := headline()
	hl["n"] = night0 + 1
	c["papers"].append(hl)
	trophy("first")
	if game.faults.is_empty(): trophy("perfect")
	if note >= 18: trophy("twenty")
	if game.minors_q > 0 and not game.minor_in: trophy("physio")
	if int(c["night"]) % 5 == 0:
		if float(c["sat"]) >= 20: trophy("season")
		if not c["discri"]: trophy("clean")
		c["discri"] = false
	c["hist"].append({"n": night0 + 1, "note": note})
	c["alea"] = null; c["tev"] = null; c["tev_res"] = ""; c["gone"] = ""; c["drunk_ag"] = ""; c["extra"] = false
	var fired: bool = float(c["sat"]) < 15
	if fired:
		c["sat"] = 50.0
		if int(c["night"]) % 5 != 0:
			c["night"] = int(ceil(float(c["night"]) / 5.0)) * 5
			c["season"] = int(c["night"]) / 5 + 1
	save()
	var s := "\n[font_size=22]Carrière[/font_size]\n"
	s += "[color=#ffc04d]+%d XP%s · Gérant %d/100 · Fonds %d €[/color]\n" % [xp, (" — [b]Promotion : %s ![/b]" % D["RANKS3"][r1][1]) if r1 > r0 else "", round(c["sat"]), c["funds"]]
	s += "\n[color=#b9b3cc]La Gazette du lendemain[/color]\n[color=%s][b]%s[/b][/color]\n[i]%s[/i]\n" % ["#ff8a8a" if hl["bad"] else "#9fe0b4", hl["t"], hl["sub"]]
	for t in new_troph:
		s += "\n[color=#ff3d9a]Trophée débloqué : [b]%s[/b] — %s[/color]" % [t["n"], t["d"]]
	new_troph = []
	if fired:
		s += "\n\n[color=#ff8a8a][b]Le gérant met fin à ta mission.[/b] Satisfaction trop basse : tu es remplacé. Ton grade et tes trophées sont conservés : tu repars au début de la saison suivante.[/color]"
	return s

func headline() -> Dictionary:
	var F := ""
	for f in game.faults: F += f[0] + " " + f[1] + " "
	var rules := [["inconscient|SAMU appelé", "Un client hospitalisé après une intervention musclée au Néon", "Une enquête est ouverte sur les méthodes de la sécurité."],
		["sans être attaqué|déjà maîtrisée", "Vidéo choc : un agent de sécurité du Néon frappe un client", "Les images tournent sur les réseaux sociaux."],
		["[Rr]ixe", "Nuit de violence au Néon : une rixe fait plusieurs blessés", "Le préfet pourrait ordonner une fermeture administrative."],
		["couteau|arme", "Un client blessé au couteau au Néon", "La question des contrôles à l'entrée est posée."],
		["testing|Discrimination|discrimination", "Discrimination à l'entrée du Néon : une association porte plainte", "Les images du refus circulent sur les réseaux."],
		["Jauge", "Le Néon bondé au-delà de sa capacité", "Un client : « On ne pouvait plus bouger. »"],
		["[Mm]ineur", "Des mineurs servis en alcool au Néon ?", "Les parents d'une adolescente s'indignent."]]
	for r in rules:
		var re := RegEx.new()
		re.compile(r[0])
		if re.search(F) != null: return {"t": r[1], "sub": r[2], "bad": true}
	if game.faults.size() >= 5: return {"t": "Soirée agitée au Néon", "sub": "Plusieurs incidents signalés par des riverains.", "bad": true}
	if game.goods.size() >= 8 and game.faults.size() <= 1: return {"t": "Le Néon, l'adresse où l'on fait la fête en sécurité", "sub": "Clients et riverains saluent le travail de l'équipe de sécurité.", "bad": false}
	return {"t": "Une nuit ordinaire au Néon", "sub": "Rien à signaler dans la presse locale.", "bad": false}
