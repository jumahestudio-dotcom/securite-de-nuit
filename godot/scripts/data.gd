extends Node
## Données du jeu chargées au démarrage (autoload « Data »).
## Les fichiers JSON viennent de la version web : incidents, événements de porte, appels du gérant.

var INC: Dictionary = {}
var DOOR_EV: Dictionary = {}
var GER: Dictionary = {}

var GAME_Y := 2026
var GAME_M := 11
var GAME_D := 14

var PREN_H := ["Louis","Yanis","Thomas","Mehdi","Kylian","Romain","Bilal","Antoine","Maxime","Sofiane","Enzo","Nathan","Mamadou","Théo","Jordan","Rayan","Florian","Quentin","Adam","Dylan","Samir","Bastien"]
var PREN_F := ["Léa","Camille","Manon","Chloé","Yasmine","Emma","Jade","Aïcha","Clara","Lina","Océane","Laura","Nour","Pauline","Mélissa","Anaïs","Sabrina","Fatou"]
var NOMS := ["Martin","Bernard","Dubois","Moreau","Laurent","Garcia","Benali","Diallo","Petit","Roux","Fontaine","Mercier","Haddad","Lefèvre","Nguyen","Rousseau","Girard","Mendes","Traoré","Blanc"]
var MOIS := ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"]

# [couleur, mot]
var SKINS := [[Color("#f3d5bd"),"très claire"],[Color("#e7b896"),"claire"],[Color("#d39a6a"),"mate"],[Color("#b07040"),"métissée"],[Color("#8a5530"),"foncée"],[Color("#5e3b22"),"très foncée"]]
var HAIRS := [[Color("#1a1410"),"noirs"],[Color("#2e1c10"),"bruns foncés"],[Color("#5a3a1e"),"châtains"],[Color("#8a6236"),"châtain clair"],[Color("#c9a15b"),"blonds"],[Color("#b5512b"),"roux"]]
var TOPS := ["#3d6fd8","#c0392b","#16a085","#7f8c8d","#8e44ad","#d35400","#2c3e50","#f1c40f","#1abc9c","#e84393","#ecf0f1","#111111"]

# Signes distinctifs pour la liste noire (visibles en 3D)
var SIGNS := [
	{"t":"crâne rasé, barbe rousse","f":{"hs":"bald","beard":"#b5512b"}},
	{"t":"casquette blanche, blouson jaune","f":{"cap":"#f2f2f2","top":"#e6c200"}},
	{"t":"très grand, cheveux longs gris","f":{"height":1.97,"hs":"long","hair":[Color("#9a9a9a"),"gris"]}},
	{"t":"lunettes, crâne rasé, manteau rouge","f":{"glasses":true,"hs":"bald","top":"#a01818"}},
]

var REFUS := [["ivresse","État d'ivresse manifeste"],["mineur","Âge / pas de pièce valable"],["tenue","Tenue non conforme (dress code)"],["cap","Capacité maximale atteinte"],["comport","Comportement agressif / menaces"],["palp","Refus de palpation"],["objet","Objet dangereux / stupéfiants trouvés"],["liste","Personne sur liste noire"],["profil","« Pas le profil de la maison »"],["sans","Sans donner de motif"]]

# Incidents propres à d'autres établissements (casino, plage…)
var EXCL := ["triche","perdant","jackpot","riviere","barbecue","feucamp","baignade","samerreur","agentboit","agentmalaise","agente"]

var _emoji := RegEx.new()

# ---------- vrais personnages (Mixamo) ----------
var CHARS := {"H": [], "F": [], "A": []}   # chemins des modèles par catégorie
var CHAR_META := {}                        # description de chaque modèle (personnages.json)
var ANIMS := {}                            # nom -> Animation (Idle, Walk, Run…)
var reserved: Array = []                   # modèles réservés (liste noire de la nuit)
var LIB_CACHE := {}                        # bibliothèques d'animations déjà adaptées

func _ready() -> void:
	_scan_assets()
	INC = _load("res://data/incidents.json")
	DOOR_EV = _load("res://data/door_events.json")
	GER = _load("res://data/gerant.json")
	_emoji.compile("[\\x{1F000}-\\x{1FFFF}\\x{2600}-\\x{27BF}\\x{FE0F}\\x{200D}]")
	randomize()

func _load(p: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(p)
	var d = JSON.parse_string(txt)
	if d == null:
		push_error("Impossible de lire " + p)
		return {}
	return d

## Retire les emojis (la police par défaut de Godot ne les affiche pas)
func clean(s) -> String:
	return _emoji.sub(str(s), "", true).strip_edges()

## Libellé court d'une option (sans indice)
func lbl(t: String) -> String:
	var seps := [" : ", ", ", " ; ", " — "]
	var cut := t.length()
	for sp in seps:
		var i := t.find(sp)
		if i > 0 and i < cut:
			cut = i
	var x := t.substr(0, cut)
	if x.length() < 16 and cut < t.length():
		var rest := t.substr(cut + 2)
		var cut2 := rest.length()
		for sp in seps:
			var j := rest.find(sp)
			if j > 0 and j < cut2:
				cut2 = j
		x += ", " + rest.substr(0, cut2)
	var re := RegEx.new()
	re.compile("\\s*\\(.*?\\)\\s*")
	x = re.sub(x, " ", true).strip_edges()
	if x.length() > 70:
		x = x.substr(0, 68)
		var k := x.rfind(" ")
		if k > 30:
			x = x.substr(0, k)
		x += "…"
	return clean(x.substr(0, 1).to_upper() + x.substr(1))

func age_from(y: int, m: int, d: int) -> int:
	var a := GAME_Y - y
	if m > GAME_M or (m == GAME_M and d > GAME_D):
		a -= 1
	return a

func fmt_clock(minutes: float) -> String:
	var t := (23 * 60 + int(minutes)) % 1440
	return "%02dh%02d" % [t / 60, t % 60]

# ---------- chargement des modèles et animations ----------
func _list(dirp: String, out: Array) -> void:
	var d := DirAccess.open(dirp)
	if d == null: return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."): _list(dirp + "/" + f, out)
		else:
			var nm := f.trim_suffix(".import").trim_suffix(".remap")
			var ext := nm.get_extension().to_lower()
			if ext in ["fbx", "glb", "gltf", "blend"]:
				var full := dirp + "/" + nm
				if not out.has(full): out.append(full)
		f = d.get_next()
	d.list_dir_end()

func _scan_assets() -> void:
	if FileAccess.file_exists("res://assets/characters/personnages.json"):
		var m = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/personnages.json"))
		if m is Dictionary: CHAR_META = m
	var files := []
	_list("res://assets/characters", files)
	for p in files:
		var fn: String = p.get_file()
		var meta: Dictionary = CHAR_META.get(fn, {})
		var cat := ""
		var low: String = p.to_lower()
		if "/agents/" in low or fn.to_lower().begins_with("a_"): cat = "A"
		elif "/femmes/" in low or fn.to_lower().begins_with("f_"): cat = "F"
		elif "/hommes/" in low or fn.to_lower().begins_with("h_"): cat = "H"
		if meta.get("role", "") == "agent": cat = "A"
		elif meta.has("sexe"): cat = "F" if str(meta["sexe"]).to_upper().begins_with("F") else "H"
		if cat == "": cat = "H"
		CHARS[cat].append(p)
	var afiles := []
	_list("res://assets/animations", afiles)
	for p in afiles:
		var sc = load(p)
		if sc == null or not (sc is PackedScene): continue
		var inst: Node = sc.instantiate()
		var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if ap != null:
			for an in ap.get_animation_list():
				if an == "RESET": continue
				var anim: Animation = ap.get_animation(an).duplicate(true)
				var key := anim_key(p.get_file().get_basename())
				ANIMS[key] = anim
				break
		inst.free()
	print("Personnages : %d hommes, %d femmes, %d agents · animations : %s" % [CHARS["H"].size(), CHARS["F"].size(), CHARS["A"].size(), ", ".join(PackedStringArray(ANIMS.keys()))])

func has_models() -> bool:
	return CHARS["H"].size() + CHARS["F"].size() > 0

func pick_model(cat: String, no_surv := false) -> String:
	var l: Array = []
	for p in CHARS.get(cat, []):
		if p in reserved: continue
		if no_surv and str(CHAR_META.get(p.get_file(), {}).get("tenue", "")) == "surv": continue
		l.append(p)
	if l.is_empty(): return ""
	return l.pick_random()

## Modèles décrits avec un « signe » distinctif (utilisables pour la liste noire)
func signed_models() -> Array:
	var out := []
	for cat in ["H", "F"]:
		for p in CHARS[cat]:
			var m: Dictionary = CHAR_META.get(p.get_file(), {})
			if str(m.get("signe", "")) != "": out.append([p, str(m["signe"]), cat])
	return out

## Nom d'animation à partir du nom de fichier Mixamo (Walking.fbx → Walk, Hip Hop Dancing.fbx → Dance…)
func anim_key(fname: String) -> String:
	var k := fname.to_lower().replace(" ", "_").replace("-", "_")
	var re := RegEx.new()
	re.compile("_?\\(\\d+\\)$")
	k = re.sub(k, "")
	var alias := {"idle": "Idle", "breathing_idle": "Idle", "walking": "Walk", "walk": "Walk", "running": "Run", "run": "Run",
		"hip_hop_dancing": "Dance", "dancing": "Dance", "dance": "Dance", "salsa_dancing": "Dance", "dying": "Fall", "falling_back_death": "Fall", "fall": "Fall",
		"talking": "Talk", "talk": "Talk", "punching_bag": "Fight", "fighting_idle": "Fight", "boxing": "Fight", "fight": "Fight",
		"drinking": "Drink", "drink": "Drink", "talking_on_phone": "Phone", "phone": "Phone", "sitting_idle": "Sit", "sit": "Sit", "surrender": "Surrender"}
	if alias.has(k): return alias[k]
	for a in alias.keys():
		if k.begins_with(a): return alias[a]
	return fname.substr(0, 1).to_upper() + fname.substr(1)
