extends Node3D
## Sécurité de nuit 3D — boucle de jeu : la porte (23h → 1h30) puis la salle (1h30 → 5h).

const PersonScript = preload("res://scripts/person.gd")
const WorldScript = preload("res://scripts/world.gd")
const LifeScript = preload("res://scripts/life.gd")
const UIScript = preload("res://scripts/ui.gd")
const FightScript = preload("res://scripts/fight.gd")
const AudioScript = preload("res://scripts/audio.gd")
const CareerScript = preload("res://scripts/career.gd")

var world
var life
var ui
var fight
var audio
var env: Environment
var moon: DirectionalLight3D
var minimap: Control
var compass: Control
var sens := 1.0
var career
var nq := 14
var mod_minor := 1.0
var mod_iv := 0.0
var mod_agr := 0
var minors_q := 0
var minor_in := false
var hq := true
var post: ColorRect = null
var player: CharacterBody3D
var pvis
var cam: Camera3D
var cam_yaw := PI * 0.82
var cam_pitch := 0.32
var crosshair: Label

var phase := "menu"
var minute := 0.0
var secu := 70.0
var rep := 65.0
var inside := 30
var cap := 110
var cash := 0
var price := 15
var inc_k := 1.0
var faults: Array = []
var goods: Array = []
var mcourante: Array = []
var queue: Array = []
var cur = null
var served := 0
var black: Array = []
var crowd: Array = []
var colleagues: Array = []
var incs: Array = []
var salle_t := 0.0
var salle_d := 300.0
var next_inc := 12.0
var pend: Array = []
var cur_inc = null
var sel_npc = null
var radio_txt := ""
var ui_t := 0.0
var menu_t := 0.0

# =====================================================================
#  DÉMARRAGE
# =====================================================================
func _ready() -> void:
	_setup_env()
	world = WorldScript.new()
	add_child(world)
	world.build(Data.venue)
	Data.ground = Callable(world, "floor_y")
	_venue_env()
	_setup_post()
	ui = UIScript.new()
	add_child(ui)
	fight = FightScript.new()
	fight.game = self
	add_child(fight)
	audio = AudioScript.new()
	add_child(audio)
	life = LifeScript.new()
	life.game = self
	add_child(life)
	career = CareerScript.new()
	career.game = self
	add_child(career)
	# minicarte (en bas à droite) et flèche vers l'incident (en haut au centre)
	minimap = Control.new()
	minimap.anchor_left = 1; minimap.anchor_right = 1; minimap.anchor_top = 1; minimap.anchor_bottom = 1
	minimap.offset_left = -262; minimap.offset_right = -14; minimap.offset_top = -330; minimap.offset_bottom = -14
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	minimap.visible = false
	ui.add_child(minimap)
	compass = Control.new()
	compass.anchor_left = 0.5; compass.anchor_right = 0.5
	compass.offset_left = -160; compass.offset_right = 160; compass.offset_top = 14; compass.offset_bottom = 74
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.draw.connect(_draw_compass)
	ui.add_child(compass)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 26)
	crosshair.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	crosshair.anchor_left = 0.5; crosshair.anchor_right = 0.5; crosshair.anchor_top = 0.5; crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8; crosshair.offset_top = -17
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	ui.add_child(crosshair)
	cam = Camera3D.new()
	cam.fov = 75.0 if Data.fps else 62.0
	cam.far = 200
	add_child(cam)
	cam.current = true
	apply_quality()
	if Data.goto_vestiaire and Data.CAR != null:
		Data.goto_vestiaire = false
		career.vestiaire()
	else:
		_menu()

func _setup_env() -> void:
	env = Environment.new()
	# ciel de nuit urbain : bleu profond, horizon orangé par l'éclairage de la ville
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.01, 0.012, 0.035)
	sm.sky_horizon_color = Color(0.09, 0.06, 0.07)
	sm.ground_bottom_color = Color(0.01, 0.01, 0.015)
	sm.ground_horizon_color = Color(0.09, 0.06, 0.07)
	sm.sun_angle_max = 0.0
	sm.sky_energy_multiplier = 0.6
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.33, 0.55)
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, [0.0, 1.0, 0.9, 0.8, 0.6, 0.4, 0.2][i])
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.6, 0.5, 0.8)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 48.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.6, 0.9)
	moon.light_energy = 0.3
	moon.shadow_enabled = true
	moon.rotation = Vector3(-0.9, 0.6, 0)
	add_child(moon)

## Vignettage et grain de pellicule, par-dessus l'image 3D (sous l'interface)
func _setup_post() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	post = ColorRect.new()
	post.anchor_right = 1.0
	post.anchor_bottom = 1.0
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float vig = 0.55;
uniform float grain = 0.04;
uniform float pain = 0.0;
uniform float daze = 0.0;
uniform float hit = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = UV - 0.5;
	float ca = 0.006 * hit + 0.004 * daze;
	float lod = daze * 2.2;
	vec3 c;
	c.r = textureLod(scr, uv + dir * ca, lod).r;
	c.g = textureLod(scr, uv, lod).g;
	c.b = textureLod(scr, uv - dir * ca, lod).b;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), daze * 0.6);
	float v = smoothstep(0.3, 0.85, length(dir * vec2(1.0, 0.85)));
	c *= 1.0 - v * (vig + daze * 0.45);
	c = mix(c, vec3(0.55, 0.0, 0.0), v * pain * 0.75);
	float n = fract(sin(dot(floor(UV * vec2(800.0, 450.0)) + floor(TIME * 24.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	post.material = mat
	cl.add_child(post)

## Ambiance propre au lieu (fumée, couleur de l'air, lumière ambiante)
func _venue_env() -> void:
	match world.theme:
		"pub":
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_albedo = Color(0.9, 0.75, 0.6)
			env.ambient_light_color = Color(0.55, 0.42, 0.3)
		"chic":
			env.volumetric_fog_density = 0.01
			env.volumetric_fog_albedo = Color(0.95, 0.85, 0.7)
			env.ambient_light_color = Color(0.5, 0.4, 0.32)
		"indus":
			env.volumetric_fog_density = 0.03
			env.volumetric_fog_albedo = Color(0.7, 0.8, 0.9)
			env.ambient_light_color = Color(0.3, 0.33, 0.4)
		_:
			env.volumetric_fog_density = 0.022
			env.volumetric_fog_albedo = Color(0.6, 0.5, 0.8)
			env.ambient_light_color = Color(0.4, 0.33, 0.55)
	if world.rain != null:
		env.volumetric_fog_density += 0.006

## Niveaux de qualité : 0 bas, 1 moyen, 2 haut, 3 ultra
const QNAMES := ["Bas", "Moyen", "Haut", "Ultra"]
func apply_quality() -> void:
	var q: int = Data.quality
	var vp := get_viewport()
	env.volumetric_fog_enabled = q >= 1
	env.ssao_enabled = q >= 1
	env.ssr_enabled = q >= 2
	env.ssil_enabled = q >= 3
	env.glow_enabled = true
	moon.shadow_enabled = q >= 1
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q <= 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = q >= 3
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = 0.75 if q == 0 else 1.0
	vp.positional_shadow_atlas_size = [1024, 2048, 4096, 8192][q]
	env.ssr_max_steps = 96 if q >= 3 else 48
	if world != null and world.rain != null:
		world.rain.amount = [800, 2000, 4000, 6000][q]
	if post != null: post.visible = q >= 1

func _mk_person(o: Dictionary):
	var p = PersonScript.new()
	p.setup(o)
	world.add_child(p)
	return p

func _menu() -> void:
	phase = "menu"
	ui.show_screen("Sécurité de nuit 3D",
		"[color=#b9b3cc]jumahestudi — prototype Godot[/color]\n\nTu es agent de sécurité de nuit, de 23 h à 5 h, dans quatre établissements : un bar de quartier, une discothèque, un club chic et un club électro géant.\n\nD'abord [b]la porte[/b] : chaque client s'avance. Observe-le, contrôle sa pièce, propose une palpation, pose une question, puis décide. Ensuite [b]la salle[/b] : fais tes rondes, rejoins les incidents à pied et interviens. Chaque décision est jugée selon le droit français.\n\n[b]Commandes[/b]\nZQSD / WASD : se déplacer  ·  Souris : regarder (clique dans le jeu)\nV : vue 1re / 3e personne  ·  Maj : courir  ·  E : parler / contrôler / intervenir\nR : radio, envoyer un collègue (en salle)  ·  Échap : libérer la souris / fermer\n\n[b]Baston[/b]\nClic gauche : repousser  ·  Clic droit : saisir (clé de bras)  ·  F maintenu : garde\nEspace : esquive (ou se relever)  ·  A : frapper (regard haut = visage, bas = corps)  ·  H : secourir (PLS)  ·  Tab : verrouiller un adversaire  ·  T : injonction  ·  E : escorter dehors  ·  R : renfort\nChaque geste est jugé : un agent n'a pas plus de droits qu'un citoyen.",
		_menu_buttons())

func _menu_buttons() -> Array:
	var bts := []
	var sv = CareerScript.load_save()
	if sv != null and int(sv.get("night", 0)) > 0:
		bts.append({"t": "Continuer la carrière — nuit %d, saison %d" % [int(sv["night"]) + 1, int(sv["season"])], "k": "main", "cb": func(): Data.CAR = CareerScript.load_save(); career.vestiaire()})
		bts.append({"t": "Nouvelle carrière (efface la progression)", "cb": func(): career.new_career(); career.vestiaire()})
	else:
		bts.append({"t": "Commencer la carrière (saisons de 5 nuits)", "k": "main", "cb": func(): career.new_career(); career.vestiaire()})
	bts.append({"t": "Nuit libre (sans carrière) — choisir l'établissement", "cb": func(): Data.CAR = null; venue_menu(false)})
	bts.append({"t": "Crédits des modèles 3D", "cb": _credits})
	return bts

## Choix de l'établissement (nuit libre : tous ; carrière : selon l'expérience)
func venue_menu(career_mode: bool) -> void:
	var xp: int = int(Data.CAR["xp"]) if (career_mode and Data.CAR != null) else 99999
	var body := "[color=#b9b3cc]Chaque lieu a sa taille, sa jauge, son public et son équipe.[/color]\n\n"
	var bts := []
	for k in WorldScript.VENUES.keys():
		var v: Dictionary = WorldScript.VENUES[k]
		var locked: bool = xp < int(v["unlock"])
		body += "[b]%s[/b] — %s · jauge %d · équipe : %s\n[color=#b9b3cc]%s%s[/color]\n\n" % [v["name"], v["type"], v["cap"], ", ".join(PackedStringArray(v["agents"])), v["sub"],
			(" · [color=#ff9a9a]débloqué à %d XP[/color]" % v["unlock"]) if locked else ""]
		var kk: String = k
		var pick := func():
			Data.venue = kk
			if career_mode:
				Data.CAR["venue"] = kk
				career.save()
				career.vestiaire()
			else:
				_start()
		bts.append({"t": v["name"] + (" (verrouillé)" if locked else ""), "k": "main" if k == Data.venue else "", "off": locked, "cb": pick})
	var back := func():
		if career_mode: career.vestiaire()
		else: _menu()
	bts.append({"t": "Retour", "cb": back})
	ui.show_screen("Choisir l'établissement", body, bts)

func _credits() -> void:
	var t := "[b]Modèles 3D du décor[/b] (licence Creative Commons Attribution 4.0, via Sketchfab)\n\n"
	t += "• « Bar Bar » — anDDDres\n• « Bright bar table and stool set » — WwWuengy\n• « UFO modern chandelier » — WwWuengy\n• « Equalizer with 3D indicators » — s7ntech\n• « Night dance club lowpoly » — 00amza\n\n"
	t += "[b]Personnages[/b] (CC-BY 4.0, via Sketchfab)\n• « .Fuse Orion Clothes 3 » — Leonardo Carvalho\n• « Posty - Just Skin And Clothes 4 » — posty\n• « Black clothes » — 10melikasagharchi\n• « brown clothes with man » — ZEBandit3D\n• « Male Character- Clothes and Hair » — sapenton8821\n\n"
	t += "Personnages et animations : Mixamo (Adobe), non redistribués.\nJeu : jumahestudi."
	ui.show_screen("Crédits", t, [{"t": "Retour", "k": "main", "cb": _menu}])

## Reconstruit le décor si l'établissement a changé depuis le chargement
func _ensure_world() -> void:
	if world.vk == Data.venue: return
	remove_child(world)
	world.queue_free()
	world = WorldScript.new()
	add_child(world)
	world.build(Data.venue)
	Data.ground = Callable(world, "floor_y")
	_venue_env()
	apply_quality()

# =====================================================================
#  NOUVELLE NUIT
# =====================================================================
func _start() -> void:
	ui.hide_screen()
	_ensure_world()
	var V: Dictionary = world.V
	cap = int(V["cap"]); nq = int(V["nq"]); price = int(V["price"]); inc_k = float(V["inc_k"])
	inside = int(round(cap * 0.27))
	phase = "door"
	audio.start()
	minimap.visible = true
	# joueur
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.3
	caps.height = 1.8
	cs.shape = caps
	cs.position = Vector3(0, 0.9, 0)
	player.add_child(cs)
	add_child(player)
	player.position = Vector3(-0.4, 0, 1.1)
	pvis = PersonScript.new()
	pvis.setup({"agent": true, "sex": "H", "skin": Data.SKINS[2], "hair": Data.HAIRS[0], "hs": "buzz", "height": 1.82, "no_beard": true})
	player.add_child(pvis)
	# collègues
	var AG := {
		"Moussa": {"sex": "H", "skin": Data.SKINS[4], "hair": Data.HAIRS[0], "hs": "buzz", "height": 1.9, "band": "#33e1ff", "no_beard": true, "home": Vector3(world.X(-9.4), 0, world.Zm(-12.5))},
		"Sarah": {"sex": "F", "skin": Data.SKINS[1], "hair": Data.HAIRS[5], "hs": "bun", "height": 1.7, "band": "#ff3d9a", "home": Vector3(world.X(3.0), 0, world.Zm(-11.5))},
		"Karim": {"sex": "H", "skin": Data.SKINS[3], "hair": Data.HAIRS[1], "hs": "short", "height": 1.85, "band": "#ffc04d", "home": Vector3(world.X(8.0), 0, world.Zm(-20.0))},
		"Inès": {"sex": "F", "skin": Data.SKINS[2], "hair": Data.HAIRS[0], "hs": "long", "height": 1.68, "band": "#3ee08f", "home": Vector3(world.X(-6.0), 0, world.Zm(-25.0))}}
	colleagues = []
	var gx := [-1.1, 1.6, -2.0, 2.4]
	var names: Array = V["agents"]
	for i in names.size():
		var nm: String = names[i]
		var d: Dictionary = AG[nm].duplicate()
		d["agent"] = true
		d["pos"] = Vector3(gx[i % 4], 0, 0.6 + 0.4 * floorf(i / 2.0))
		d["yaw"] = PI
		var ag = _mk_person(d)
		ag.pname = nm
		ag.home = d["home"]
		colleagues.append(ag)
	if Data.CAR != null:
		career.setup_night()
		career.setup_team()
	# liste noire
	var sg: Array = Data.SIGNS.duplicate()
	sg.shuffle()
	var sm: Array = Data.signed_models()
	sm.shuffle()
	black = []
	Data.reserved = []
	for k in 2:
		var e := {"name": Data.PREN_H.pick_random() + " " + Data.NOMS.pick_random(), "t": sg[k]["t"], "f": sg[k]["f"], "model": "", "sex": "H",
			"motif": ["bagarre sur la piste", "a frappé un barman", "vol au vestiaire", "harcèlement de clientes"].pick_random()}
		if sm.size() > k:
			e["model"] = sm[k][0]; e["t"] = sm[k][1]; e["f"] = {}; e["sex"] = sm[k][2]
			if e["sex"] == "F": e["name"] = Data.PREN_F.pick_random() + " " + Data.NOMS.pick_random()
			Data.reserved.append(sm[k][0])
		black.append(e)
	# public déjà à l'intérieur
	for i in int(V["crowd"]):
		_spawn_inside(null, true)
	life.setup()
	# file
	var test_i := randi_range(2, nq - 1)
	for i in nq:
		queue.append(_gen_client(i, {"testing": i == test_i}))
	var bi := randi_range(3, 9)
	if bi == test_i: bi = 10
	var b := _gen_client(bi, {"minor": false, "sex": black[0]["sex"]})
	b["black"] = black[0]
	if randf() < 0.5:
		b["alias"] = true
		b["id_name"] = black[0]["name"]
	else:
		var parts: PackedStringArray = black[0]["name"].split(" ")
		b["first"] = parts[0]; b["last"] = parts[1]
	queue[bi] = b
	var has_w := false
	var has_m := false
	for c in queue:
		if c["weapon"]: has_w = true
		if c["minor"]: has_m = true
	if not has_w:
		var kw := randi_range(5, nq - 2)
		if queue[kw]["black"] == null and not queue[kw]["testing"]:
			queue[kw] = _gen_client(kw, {"weapon": true, "sex": "H"})
	if not has_m:
		var k2 := randi_range(1, 4)
		if queue[k2]["black"] == null and not queue[k2]["testing"]:
			queue[k2] = _gen_client(k2, {"minor": true})
	for i in queue.size():
		_mk_client_npc(queue[i], i)
	if Data.CAR != null:
		career.queue_specials()
		career.plan_door_events()
	minors_q = 0
	for c in queue:
		if c["minor"]: minors_q += 1
	_set_radio("%s : « Les portes ouvrent. Le premier client avance. Va le voir (touche E). »" % colleagues[0].pname)
	_next_client(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# =====================================================================
#  CLIENTS
# =====================================================================
func _gen_client(i: int, opt := {}) -> Dictionary:
	var sex = opt.get("sex", "H" if randf() < 0.55 else "F")
	var minor = opt.get("minor", randf() < 0.1 * mod_minor)
	var age: int = randi_range(16, 17) if minor else (randi_range(18, 21) if randf() < 0.35 else randi_range(22, 48))
	var r := randf()
	var q := randf() + mod_agr * 0.08
	var att := "calme"
	if q > 0.6: att = "impatient"
	if q > 0.8: att = "arrogant"
	if q > 0.92: att = "menacant"
	var c := {"i": i, "sex": sex, "first": (Data.PREN_H if sex == "H" else Data.PREN_F).pick_random(), "last": Data.NOMS.pick_random(),
		"age": age, "minor": minor, "size": 1 if randf() < 0.4 else randi_range(2, 3),
		"iv": opt.get("iv", 0 if r < 0.56 - mod_iv else (1 if r < 0.84 - mod_iv / 2.0 else 2)),
		"tenue": "surv" if randf() < 0.12 else ["soignee", "jean", "chemise", "robe"].pick_random(),
		"att": att, "weapon": opt.get("weapon", sex == "H" and randf() < 0.08), "drug": randf() < 0.09,
		"testing": opt.get("testing", false), "black": null, "alias": false,
		"id_checked": false, "palp": "", "palp_refused": false, "found": "", "asked": [],
		"has_id": true, "borrowed": false, "id_name": "", "cues": [], "quote": "", "owner_look": null, "mates": []}
	if sex == "H" and c["tenue"] == "robe": c["tenue"] = "chemise"
	var y := Data.GAME_Y - age - (1 if randf() < 0.5 else 0)
	var m := randi_range(1, 12)
	var d := randi_range(1, 28)
	if minor:
		var w := randf()
		if w < 0.5:
			c["borrowed"] = true
			y = Data.GAME_Y - randi_range(20, 24)
			c["id_name"] = (Data.PREN_H if sex == "H" else Data.PREN_F).pick_random() + " " + c["last"]
		elif w < 0.8:
			c["has_id"] = false
	elif randf() < 0.04:
		c["has_id"] = false
	if c["testing"]:
		c["iv"] = 0; c["att"] = "calme"; c["weapon"] = false; c["drug"] = false; c["minor"] = false
		c["has_id"] = true; c["borrowed"] = false; c["size"] = 2; c["id_name"] = ""
		c["tenue"] = ["soignee", "jean", "chemise"].pick_random()
		if age < 18: c["age"] = 24; y = Data.GAME_Y - 25
	if c["weapon"]: c["iv"] = max(1, c["iv"])
	c["dob"] = [y, m, d]
	c["id_age"] = Data.age_from(y, m, d)
	if not c["borrowed"]:
		c["age"] = c["id_age"]
		c["minor"] = c["id_age"] < 18
	return c

func _client_look(c: Dictionary) -> Dictionary:
	var o := {"sex": c["sex"], "dress": c["tenue"] == "robe", "no_surv": c["testing"]}
	match c["tenue"]:
		"surv":
			var col = ["#1f3fae", "#111111", "#7a1414"].pick_random()
			o["top"] = col; o["bottom"] = col; o["cap"] = ["#111111", "#f2f2f2", "#1f3fae"].pick_random(); o["shoes"] = "#eeeeee"
		"soignee":
			o["top"] = "#22252d" if c["sex"] == "H" else ["#b0164e", "#6a1b9a", "#111111"].pick_random(); o["bottom"] = "#16181e"; o["shoes"] = "#111111"
		"chemise":
			o["top"] = ["#e3e9f2", "#c9d6ea", "#f2e6e6"].pick_random(); o["bottom"] = "#1b2433"
		"robe":
			o["top"] = ["#b0164e", "#6a1b9a", "#111111", "#0e5e6f", "#c0392b"].pick_random()
	if c["minor"] or c.get("young", false):
		o["height"] = randf_range(1.64, 1.76) if c["sex"] == "H" else randf_range(1.55, 1.66)
	if c.get("model", "") != "": o["model"] = c["model"]
	if c.get("prim", false):
		o["prim"] = true
		for k in c.get("look", {}).keys(): o[k] = c["look"][k]
	if c["black"] != null:
		if c["black"]["model"] != "":
			o["model"] = c["black"]["model"]
			o["sex"] = c["black"]["sex"]
		else:
			var f: Dictionary = c["black"]["f"]
			for k in f.keys():
				o[k] = f[k]
			o["sex"] = "H"
			o["no_beard"] = true
			o["prim"] = true
	return o

func _mk_client_npc(c: Dictionary, i: int) -> void:
	var o := _client_look(c)
	o["pos"] = Vector3(2.6 + i * 0.95, 0, 2.9)
	o["yaw"] = -PI / 2
	var n = _mk_person(o)
	n.sway = 1.0 if c["iv"] == 2 else (0.3 if c["iv"] == 1 else 0.0)
	n.data = c
	# avec un vrai personnage, la tenue décrite est celle du modèle
	if n.meta.has("tenue"):
		c["tenue"] = n.meta["tenue"]
	if n.meta.has("tenue_txt"):
		c["tenue_txt"] = n.meta["tenue_txt"]
	if n.model_path != "" and n.meta.has("sexe") and not c.has("hab"):
		var sx := "F" if str(n.meta["sexe"]).to_upper().begins_with("F") else "H"
		if sx != c["sex"]:
			c["sex"] = sx
			c["first"] = (Data.PREN_H if sx == "H" else Data.PREN_F).pick_random()
	c["npc"] = n
	c["mates"] = []
	for k in range(1, c["size"]):
		var mo := {"pos": Vector3(2.6 + i * 0.95 + 0.2, 0, 3.4 + k * 0.4), "yaw": -PI / 2}
		var m = _mk_person(mo)
		m.sway = 0.4 if c["iv"] > 0 else 0.0
		c["mates"].append(m)

func _tenue_txt(c: Dictionary) -> String:
	if c.has("tenue_txt"): return c["tenue_txt"]
	match c["tenue"]:
		"soignee": return "Tenue de soirée" if c["sex"] == "F" else "Costume sombre"
		"jean": return "Jean et chaussures de ville"
		"chemise": return "Chemise et pantalon"
		"robe": return "Robe de soirée"
		"surv": return "Survêtement et casquette"
	return ""

func _cues(c: Dictionary) -> Array:
	if c["cues"].size() > 0: return c["cues"]
	var o := [_tenue_txt(c)]
	if c["iv"] == 0: o.append("Paraît sobre")
	if c["iv"] == 1: o.append("Haleine alcoolisée, rit fort, mais tient debout")
	if c["iv"] == 2: o.append(["Titube, élocution pâteuse", "Yeux vitreux, perd l'équilibre", "Se tient au poteau, parle difficilement"].pick_random())
	if (c["minor"] and randf() < 0.7) or (not c["minor"] and c["age"] <= 19 and randf() < 0.35): o.append("Visage très jeune")
	if c["att"] == "impatient": o.append("S'impatiente, souffle")
	if c["att"] == "arrogant": o.append("Ton méprisant")
	if c["att"] == "menacant": o.append("Regard fixe, se colle à toi, mâchoire serrée")
	if c["weapon"] and randf() < 0.4: o.append("Garde la main dans la poche de sa veste")
	if c["drug"] and randf() < 0.3: o.append("Pupilles dilatées, très nerveux")
	if c["size"] > 1: o.append("Accompagné(e) de %d personne(s)" % (c["size"] - 1))
	if c["black"] != null: o.append(c["black"]["t"].substr(0, 1).to_upper() + c["black"]["t"].substr(1))
	for x in c.get("extra_cues", []): o.append(x)
	c["cues"] = o
	return o

func _quote(c: Dictionary) -> String:
	if c["quote"] != "": return c["quote"]
	var q: String = ["« Bonsoir ! »", "« Bonsoir, c'est combien l'entrée ? »", "« Salut, on fête un anniversaire. »"].pick_random()
	if c["black"] != null: q = ["« Allez, je suis un habitué ici. »", "« C'est la première fois que je viens, promis. »"].pick_random()
	elif c["minor"] and not c["has_id"]: q = "« J'ai oublié ma carte, mais j'ai 19 ans, je vous jure. »"
	elif c["att"] == "menacant": q = "« Tu vas me laisser entrer, sinon on se retrouve à la sortie. »"
	elif c["att"] == "arrogant": q = "« On a réservé une bouteille, dépêche. »"
	elif c["iv"] == 2: q = "« Ssssalut… on vient juste… danser un peu… »"
	elif c["att"] == "impatient": q = "« Ça fait 40 minutes qu'on attend… »"
	c["quote"] = q
	return q

# =====================================================================
#  LA PORTE
# =====================================================================
func _next_client(from_ev := false) -> void:
	if not from_ev and Data.CAR != null and career.door_ev.has(served) and queue.size() > 0 and minute < 150:
		var k: String = career.door_ev[served]
		career.door_ev.erase(served)
		career.door_event(k)
		return
	if queue.is_empty() or minute >= 150:
		_start_salle()
		return
	cur = queue.pop_front()
	var n = cur["npc"]
	n.face = PI
	n.walk_to([Vector2(1.4, 2.7), Vector2(0.6, 2.3)])
	for k in cur["mates"].size():
		cur["mates"][k].walk_to([Vector2(1.4 + k * 0.5, 2.9), Vector2(1.0 + k * 0.6, 2.9)])
	for i in queue.size():
		var c = queue[i]
		c["npc"].face = -PI / 2
		c["npc"].walk_to([Vector2(2.6 + i * 0.95, 2.9)])
		for k in c["mates"].size():
			c["mates"][k].walk_to([Vector2(2.6 + i * 0.95 + 0.2, 3.4 + (k + 1) * 0.4)])

func _cur_ready() -> bool:
	return cur != null and cur["npc"].path.is_empty()

func _fmt_dob(d: Array) -> String:
	return "%02d/%02d/%d" % [d[2], d[1], d[0]]

func _door_panel() -> void:
	var c = cur
	if c == null: return
	var body := ""
	for x in _cues(c):
		body += "• " + x + "\n"
	body += "\n[i]" + _quote(c) + "[/i]\n"
	if c["id_checked"]:
		body += "\n[color=#9fd3ff][b]Pièce d'identité[/b][/color]\n"
		if not c["has_id"] and c.get("student_card", false):
			body += "[b]Carte étudiante[/b] au nom de %s %s — photo, établissement, année en cours. Aucune date de naissance.\n" % [c["first"], c["last"]]
		elif not c["has_id"]:
			body += "[b]Aucune pièce d'identité présentée.[/b]\n"
		else:
			var words: Array = c["npc"].id_words()
			var photo := ""
			var hair_w := ""
			var hs_w := ""
			var skin_w := ""
			if words.is_empty():
				photo = "Photo : visage différent (forme du nez, mâchoire, yeux)" if c["borrowed"] else "Photo : correspond au visage"
			else:
				hair_w = words[0]; hs_w = words[1]; skin_w = words[2]
			if c["borrowed"] and not words.is_empty():
				if c["owner_look"] == null:
					var hh = Data.HAIRS.pick_random()
					while hh[1] == hair_w: hh = Data.HAIRS.pick_random()
					c["owner_look"] = [hh[1], ["courts", "longs", "attachés", "rasés"].pick_random(), Data.SKINS.pick_random()[1]]
				hair_w = c["owner_look"][0]; hs_w = c["owner_look"][1]; skin_w = c["owner_look"][2]
			var nm: String = c["id_name"] if c["id_name"] != "" else c["first"] + " " + c["last"]
			if photo == "": photo = "Photo : cheveux %s, %s · peau %s" % [hair_w, hs_w, skin_w]
			if c.get("trans_id", false): photo = "Photo ancienne : même visage, cheveux plus courts"
			body += "[color=#b9b3cc]%s[/color]\n" % c.get("id_type", "Carte nationale d'identité")
			body += "Nom : %s%s\nNé(e) le : %s → [b]%d ans[/b]\n%s\n" % [nm, (" · Sexe : " + c["id_sex"]) if c.has("id_sex") else "", _fmt_dob(c["dob"]), c["id_age"], photo]
			if c.get("altered", false):
				if not c.has("alt_seen"): c["alt_seen"] = 2 if career.eq("scanner") else (1 if randf() < 0.55 else 0)
				if c["alt_seen"] == 2: body += "[color=#ff6a6a]Lecteur de pièces : zone de la date de naissance modifiée[/color]\n"
				elif c["alt_seen"] == 1: body += "[color=#b9b3cc]L'encre de la date de naissance paraît un peu plus épaisse que le reste.[/color]\n"
	if c["palp"] != "":
		body += "\n" + c["palp"] + "\n"
	for a in c["asked"]:
		body += "\n[b]" + a[0] + "[/b]\n" + a[1] + "\n"
	var bl := "\n[color=#b9b3cc][b]Consignes[/b] : 18 ans minimum, pièce exigée · pas de survêtement, sweat à capuche ni casquette · capacité %d[/color]\n[color=#ff9a9a][b]Liste noire[/b][/color]\n" % cap
	for b in black:
		bl += "• %s — %s ([i]%s[/i])\n" % [b["name"], b["t"], b["motif"]]
	body += bl
	ui.open_panel("%s %s" % [c["first"], c["last"]], "Nom annoncé · %s · salle %d/%d · %s" % ["Homme" if c["sex"] == "H" else "Femme", inside, cap, Data.fmt_clock(minute)], body, [
		{"row": [{"t": "Pièce", "k": "cy", "off": c["id_checked"], "cb": _check_id},
			{"t": "Palpation", "k": "cy", "off": c["palp"] != "", "cb": _palp},
			{"t": "Question", "k": "cy", "off": c["asked"].size() > 0, "cb": _ask_dob}]},
		{"t": "Faire entrer", "k": "ok", "cb": _admit},
		{"t": "Refuser…", "k": "bad", "cb": _refuse_menu},
		{"t": "Reculer", "cb": _close_panel}])

func _check_id() -> void:
	cur["id_checked"] = true
	minute += 1
	_door_panel()

func _palp() -> void:
	var c = cur
	var consent: bool = randf() < 0.45 if (c["weapon"] or c["drug"]) else randf() < 0.93
	var fem = null
	for a in colleagues:
		if is_instance_valid(a) and a.sex == "F": fem = a
	var who := "Tu"
	if c["sex"] == "F":
		if fem == null:
			c["palp"] = "Aucune agente ce soir : la palpation de sécurité d'une femme ne peut être faite que par une femme."
			_door_panel()
			return
		who = fem.pname
	minute += 1
	if not consent:
		c["palp_refused"] = true
		c["palp"] = "%s l'accord pour une palpation : [b]refus[/b]." % ("Tu demandes" if who == "Tu" else who + " demande")
	elif c["weapon"]:
		c["found"] = "arme"
		c["palp"] = "%s avec son accord : [b][color=#ff6a6a]couteau pliant[/color][/b] dans la poche de veste." % ("Tu palpes" if who == "Tu" else who + " palpe")
	elif c.get("bottle", false):
		c["found"] = "bouteille"
		c["palp"] = "Contrôle du sac avec accord : [b]une bouteille de vodka[/b] entamée."
	elif c["drug"]:
		c["found"] = "drogue"
		c["palp"] = "Palpation avec accord : une petite boîte qu'il ouvre lui-même, [b]sachets de résine de cannabis[/b]."
	else:
		c["palp"] = "%s avec son accord : rien à signaler." % ("Tu palpes" if who == "Tu" else who + " palpe")
	if c["sex"] == "F" and fem != null:
		fem.path = []
		fem.position = Vector3(0.2, 0, 2.0)
		fem.yaw = 0.0
	_door_panel()

func _ask_dob() -> void:
	var c = cur
	var d: Array = c.get("true_dob", c["dob"])
	var ds := "%d %s %d" % [d[2], Data.MOIS[d[1] - 1], d[0]]
	var a := "« Le %s. »" % ds
	if c["iv"] == 2: a = "« Le… euh… %s… je crois ? »" % ds
	elif c["borrowed"]: a = "« Euh… le… attends » (il hésite et regarde ailleurs)" if randf() < 0.6 else "« Le %s. » (récité très vite)" % ds
	elif c["minor"] and not c["has_id"]: a = "« %d… euh, oui, 19 ans. » (il compte sur ses doigts)" % (Data.GAME_Y - 19)
	elif c["alias"]: a = "« Pourquoi tu me demandes ça ? »"
	elif c.get("altered", false): a = "« Le %s. » (sans hésiter)" % ds
	if c.get("deaf", false): a = "Il tape sur son téléphone et te le montre : « %s »" % ds
	c["asked"].append(["Quelle est ta date de naissance ?", a])
	minute += 0.5
	_door_panel()

func _refuse_menu() -> void:
	var bts := []
	for r in Data.REFUS:
		var key: String = r[0]
		bts.append({"t": r[1], "cb": func(): _refuse(key)})
	bts.append({"t": "Retour", "cb": _door_panel})
	ui.open_panel("Motif du refus", "", "", bts)

func _fault(t: String, law: String) -> void:
	faults.append([t, law])

func _good(t: String) -> void:
	goods.append(t)

func _mc(t: String) -> void:
	mcourante.append(Data.fmt_clock(minute) + " — " + t)

func _clampg() -> void:
	secu = clamp(secu, 0, 100)
	rep = clamp(rep, 0, 100)

func _admit() -> void:
	var c = cur
	var res := []
	var full: bool = inside + c["size"] > cap
	inside += c["size"]
	cash += price * c["size"]
	if full:
		secu -= 10
		_fault("Jauge dépassée (%d/%d)." % [inside, cap], "Règlement de sécurité incendie des ERP : l'effectif maximal ne doit jamais être dépassé.")
		res.append(["b", "Jauge dépassée.", ""])
	if c["minor"]:
		minor_in = true
		rep -= 6
		_fault("Mineur(e) de %d ans admis(e) (%s)." % [c["age"], c["first"]], "Art. L3342-1 Code de la santé publique : alcool interdit aux mineurs.")
		res.append(["b", "%s a en réalité [b]%d ans[/b].%s" % [c["first"], c["age"], " Pièce empruntée : la photo ne correspondait pas." if c["borrowed"] else ""], ""])
		pend.append("mineur")
	if c["iv"] == 2:
		secu -= 5
		_fault("%s %s, manifestement ivre, admis(e)." % [c["first"], c["last"]], "Interdit de servir une personne manifestement ivre (Code de la santé publique).")
		res.append(["b", "Manifestement ivre : ça va se payer plus tard.", ""])
		pend.append(["malaise", "vomi", "refus"].pick_random())
	if c["black"] != null:
		rep -= 5
		_fault("%s (liste noire) est entré%s." % [c["black"]["name"], " sous un faux nom" if c["alias"] else ""], "Consigne de l'exploitant non respectée.")
		res.append(["b", "C'était [b]%s[/b], de la liste noire (%s)." % [c["black"]["name"], c["black"]["t"]], ""])
		pend.append("bagarre")
	if c["weapon"]:
		if c["found"] == "arme":
			secu -= 15
			_fault("Entrée avec un couteau découvert.", "Une arme découverte doit entraîner un refus.")
			res.append(["b", "Il est entré avec le couteau que tu avais trouvé !", ""])
		pend.append("arme")
	if c["found"] == "drogue":
		secu -= 6
		_fault("Entrée avec stupéfiants découverts.", "Fermeture administrative possible (art. L3332-15 CSP).")
		pend.append("deal")
	if c["tenue"] == "surv":
		rep -= 3
		res.append(["n", "Survêtement : consigne du gérant non respectée.", ""])
	if not c["has_id"] and not c["minor"]:
		rep -= 2
		res.append(["n", "Entré sans pièce d'identité.", ""])
	if Data.CAR != null: career.eval_admit(c, res)
	if res.is_empty():
		rep += 1.5
		res.append(["", "Entrée sans problème.", ""])
		if c["testing"]: res.append(["", "(C'était un [b]testing[/b] anti-discrimination : bonne décision.)", ""])
	_mc("Porte — entrée : %s %s" % [c["first"], c["last"]])
	_spawn_inside(c, false)
	_clampg()
	var bad := false
	for r in res:
		if r[0] == "b": bad = true
	_done_client("Entrée… discutable" if bad else "Client entré", res)

func _refuse(k: String) -> void:
	var c = cur
	var full: bool = inside + c["size"] > cap
	var lb := ""
	for r in Data.REFUS:
		if r[0] == k: lb = r[1]
	var valid := false
	match k:
		"ivresse": valid = c["iv"] == 2
		"mineur": valid = c["minor"] or not c["has_id"] or (c["id_checked"] and c["borrowed"])
		"tenue": valid = c["tenue"] == "surv"
		"cap": valid = full
		"comport": valid = c["att"] == "menacant" or c["att"] == "arrogant"
		"palp": valid = c["palp_refused"]
		"objet": valid = c["found"] != ""
		"liste": valid = c["black"] != null
	if c["black"] != null and k != "profil" and k != "sans": valid = true
	if k == "mineur" and (c.get("student_card", false) or (c.get("altered", false) and c["minor"])): valid = true
	var res := []
	if Data.CAR != null and career.eval_refuse(c, valid, res):
		_mc("Porte — refus : %s %s (%s)" % [c["first"], c["last"], lb])
		c["npc"].walk_to([Vector2(4, 4.5), Vector2(12, 5.2), Vector2(28, 5.2)], func(p): p.queue_free())
		for m in c["mates"]: m.walk_to([Vector2(4.5, 4.8), Vector2(12, 5.4), Vector2(28, 5.4)], func(p): p.queue_free())
		_clampg()
		_done_client("Refus problématique", res)
		return
	if valid:
		secu += 4 if (c["weapon"] or c["black"] != null or c["iv"] == 2) else 1
		_good("Refus fondé : %s %s (%s)." % [c["first"], c["last"], lb])
		res.append(["", "Refus fondé.", ""])
		if c["black"] != null: res.append(["", "C'était bien [b]%s[/b]%s." % [c["black"]["name"], ", sous un faux nom" if c["alias"] else ""], ""])
		if c["weapon"] and c["found"] == "": res.append(["", "(Il cachait un couteau.)", ""])
		if c["minor"]: res.append(["", "Bien vu : %d ans." % c["age"], ""])
	elif c["testing"] or k == "profil" or k == "sans":
		rep -= 20 if c["testing"] else 6
		_fault("Refus de %s %s sans motif objectif%s." % [c["first"], c["last"], " lors d'un testing" if c["testing"] else ""], "Discrimination dans l'accès à un lieu ouvert au public (art. 225-1 et 225-2 Code pénal) : jusqu'à 5 ans et 75 000 €.")
		res.append(["b", "C'était un [b]testing[/b] d'une association antiraciste." if c["testing"] else "Aucun motif objectif : le client menace de porter plainte.", ""])
	else:
		rep -= 4
		res.append(["n", "Motif inexact : client perdu, risque de contestation.", ""])
	_mc("Porte — refus : %s %s (%s)" % [c["first"], c["last"], lb])
	var n = c["npc"]
	n.speed = 1.6
	n.walk_to([Vector2(4, 4.5), Vector2(12, 5.2), Vector2(28, 5.2)], func(p): p.queue_free())
	for m in c["mates"]:
		m.walk_to([Vector2(4.5, 4.8), Vector2(12, 5.4), Vector2(28, 5.4)], func(p): p.queue_free())
	var attack: bool = (c["att"] == "menacant" and randf() < 0.5) or (c["iv"] == 2 and randf() < 0.18) or (c["black"] != null and randf() < 0.3)
	if attack:
		n.path = []
		n.on_arrive = null
		n.anim = "fight"
		for m in c["mates"]:
			m.path = []; m.on_arrive = null; m.anim = "fight"
		res.append(["b", "Il ne l'accepte pas : il revient vers toi, le poing serré…", ""])
		var fsrc := {"npc": n, "mates": c["mates"], "name": c["first"], "weapon": c["weapon"] and c["found"] == "", "title": "Agression à la porte", "door": true, "drunk": int(c.get("iv", 0)) >= 1}
		_clampg()
		cur = null
		served += 1
		minute += 7
		_result_panel("Ça dégénère", res, func(): fight.start(fsrc))
		return
	if c["att"] == "menacant" and randf() < 0.4: pend.append("exterieur")
	_clampg()
	var bad := false
	for r in res:
		if r[0] == "b": bad = true
	_done_client("Refus problématique" if bad else "Entrée refusée", res)

func _done_client(title: String, res: Array) -> void:
	cur = null
	served += 1
	minute += 7
	_result_panel(title, res, _next_client)

func _result_panel(title: String, res: Array, next = null) -> void:
	var body := ""
	for r in res:
		var col := "#9fe0b4"
		if r[0] == "b": col = "#ff8a8a"
		elif r[0] == "n": col = "#ffd27a"
		body += "[color=%s]%s[/color]\n" % [col, r[1]]
		if r.size() > 2 and r[2] != "": body += "[color=#b9b3cc][i]Loi : %s[/i][/color]\n" % r[2]
		body += "\n"
	var cont := func():
		_close_panel()
		if next != null:
			next.call()
	ui.open_panel(title, "", body, [{"t": "Continuer", "k": "main", "cb": cont}])

func _close_panel() -> void:
	ui.close_panel()
	if phase == "door" or phase == "salle":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# =====================================================================
#  LA SALLE
# =====================================================================
func _spawn_inside(c, init: bool) -> void:
	var zs: Array = ["piste", "piste", "piste", "bar", "bar", "vip", "fumoir", "toilettes"].filter(func(k): return world.ZR.has(k))
	var z: String = zs.pick_random()
	var p: Vector3 = world.zpt(z)
	var n
	if c == null:
		n = _mk_person({"pos": p})
	else:
		n = c["npc"]
	var set_anim := func(q):
		if z == "piste": q.anim = "dance"
		elif z == "bar": q.anim = ["drink", "talk", "idle"].pick_random()
		elif z == "fumoir": q.anim = ["talk", "phone"].pick_random()
		else: q.anim = ["idle", "talk"].pick_random()
		q.yaw = randf_range(-3, 3)
	if init:
		n.position = p
		set_anim.call(n)
	else:
		n.walk_to(world.route(n.position, p), set_anim)
	n.zone = z
	crowd.append(n)
	if c != null:
		for m in c["mates"]:
			var q := Vector3(p.x + randf_range(-0.8, 0.8), 0, p.z + randf_range(-0.8, 0.8))
			m.walk_to(world.route(m.position, q), set_anim)
			m.zone = z
			crowd.append(m)

func _start_salle() -> void:
	if phase == "salle": return
	phase = "salle"
	minute = max(minute, 150)
	salle_t = 0
	next_inc = 12
	_set_radio("Gérant : « La file est finie. Tout le monde en salle. Fais tes rondes, je compte sur toi. »")
	for a in colleagues:
		a.walk_to(world.route(a.position, a.home))
	for c in queue:
		c["npc"].queue_free()
		for m in c["mates"]: m.queue_free()
	queue.clear()
	pend.shuffle()

func _is_viol(ty: String) -> bool:
	var re := RegEx.new()
	re.compile("arme|harcel|bagarre|rixe|filles|refus|exterieur|dj|conjugal|homophobe|racket|onepunch|attouch|photo|agentagresse|provoc|insulte|bouteille|garde|lacrymo")
	return re.search(ty) != null

func _is_med(ty: String) -> bool:
	var re := RegEx.new()
	re.compile("malaise|ghb|chute|overdose|allergie|vomi|chaleur|angoisse|arret|epilepsie|coma|piqure|tete|asthme|verre|podium|projecteur")
	return re.search(ty) != null

func _spawn_incident(ty: String) -> void:
	if not Data.INC.has(ty): return
	var d: Dictionary = Data.INC[ty]
	var zs := []
	for z in d["zones"]:
		if world.ZR.has(z): zs.append(z)
	if zs.is_empty(): zs = ["piste"]
	var z: String = zs.pick_random()
	var p: Vector3 = world.zpt(z)
	var inc := {"ty": ty, "z": z, "p": p, "t0": salle_t, "dl": max(28.0, float(d.get("dl", 20)) * 2.6) * (1.3 if career.eq("radio") else 1.0), "st": "open", "actors": [], "agent": null, "need": int(d.get("need", 1))}
	var viol := _is_viol(ty)
	var med := _is_med(ty)
	var n := 8 if ty == "rixe" else (2 if viol or med else 1)
	for k in n:
		var a = _mk_person({"pos": Vector3(p.x + cos(k * 2.4) * (0.5 + k * 0.15), 0, p.z + sin(k * 2.4) * (0.5 + k * 0.15))})
		if viol:
			a.anim = "fight"
			a.yaw = atan2(p.x - a.position.x, p.z - a.position.z)
		elif med and k == 0:
			a.anim = "fallen"
		else:
			a.anim = "talk"
		inc["actors"].append(a)
	# repère au sol + losange + lumière
	var mk := Node3D.new()
	mk.position = p
	world.add_child(mk)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2; cm.bottom_radius = 1.2; cm.height = 0.02
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.3, 0, 0)
	dm.emission_enabled = true
	dm.emission = Color(1, 0.1, 0.1)
	dm.emission_energy_multiplier = 2.0
	disc.material_override = dm
	disc.position.y = 0.03
	mk.add_child(disc)
	var dia := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, 0.22)
	dia.mesh = bm
	dia.material_override = dm
	dia.position.y = 2.6
	dia.rotation.z = PI / 4
	mk.add_child(dia)
	var fire := ty.contains("feu") or ty.contains("bougies") or ty.contains("etincelles") or ty.contains("fumigene") or ty.contains("petards")
	var lt := OmniLight3D.new()
	lt.light_color = Color(1, 0.45, 0.1) if fire else Color(1, 0.1, 0.1)
	lt.omni_range = 6.0 if fire else 3.5
	lt.light_energy = 3.0 if fire else 1.5
	lt.position.y = 1.2
	mk.add_child(lt)
	inc["mk"] = mk; inc["dia"] = dia; inc["dm"] = dm; inc["lt"] = lt; inc["fire"] = fire
	incs.append(inc)
	var who = null
	for a in colleagues:
		if a.task == null and a.position.distance_to(p) < 9.0: who = a
	if who != null:
		_set_radio("%s : « Problème zone %s : %s ! »" % [who.pname, WorldScript.ZLBL[z].to_lower(), Data.clean(d["t"]).to_lower()])
	else:
		_set_radio("Un barman : « Il se passe quelque chose côté %s ! »" % WorldScript.ZLBL[z].to_lower())
	audio.sfx("radio")

func _near_inc():
	var best = null
	var bd := 2.6
	for i in incs:
		if i["st"] != "open" and i["st"] != "assigned": continue
		var d: float = player.position.distance_to(i["p"])
		if d < bd:
			bd = d; best = i
	return best

func _agents_near(p: Vector3) -> int:
	var n := 1
	for a in colleagues:
		if a.position.distance_to(p) < 5.0: n += 1
	return n

func _inc_panel(inc: Dictionary) -> void:
	cur_inc = inc
	var d: Dictionary = Data.INC[inc["ty"]]
	var order := range(d["o"].size())
	order.shuffle()
	var bts := []
	for oi in order:
		var idx: int = oi
		bts.append({"t": Data.lbl(d["o"][idx]["t"]), "cb": func(): _decide(idx)})
	if _is_viol(inc["ty"]):
		var the_inc: Dictionary = inc
		bts.append({"t": "Intervention physique", "k": "bad", "cb": func(): fight.start({"inc": the_inc, "title": Data.clean(Data.INC[the_inc["ty"]]["t"])})})
	bts.append({"t": "Reculer", "cb": _close_panel})
	ui.open_panel(d["t"], "%s · %s · agents sur place : %d" % [WorldScript.ZLBL[inc["z"]], Data.fmt_clock(minute), _agents_near(inc["p"])], d["desc"], bts)

func _decide(oi: int) -> void:
	var inc = cur_inc
	var d: Dictionary = Data.INC[inc["ty"]]
	var o: Dictionary = d["o"][oi]
	var ds: float = o.get("s", 0)
	var dr: float = o.get("r", 0)
	var extra := ""
	if o.has("g"):
		var p: float = 0.82 - min(1.0, (salle_t - inc["t0"]) / inc["dl"]) * 0.25 - float(d.get("hard", 0))
		var here := _agents_near(inc["p"])
		if d.has("need") and here < int(d["need"]): p -= (int(d["need"]) - here) * 0.2
		if inc["ty"] == "arret": p = 0.35
		if randf() > clamp(p, 0.15, 0.95):
			var C = [["Le client se débat et te bouscule violemment : tu as mal à l'épaule.", -4, 0], ["Ses amis s'en mêlent, ça dure plus longtemps que prévu.", -3, -2], ["Une vidéo coupée de la scène circule déjà sur les réseaux.", 0, -5], ["Les secours mettent longtemps à arriver.", -4, 0]].pick_random()
			ds += C[1]; dr += C[2]
			extra = "\n[color=#ffd27a]Complication : %s[/color]\n" % C[0]
	# équipement acheté en carrière
	if o.get("dae", false):
		if career.eq("dae"):
			ds += 5
			extra += "\n[color=#9fe0b4]Le défibrillateur délivre un choc : le pouls revient avant l'arrivée des pompiers.[/color]\n"
		elif Data.CAR != null:
			ds -= 8
			_fault("Arrêt cardiaque : aucun défibrillateur sur place.", "DAE obligatoire dans les ERP de catégories 1 à 4 (décret n° 2018-1186).")
			extra += "\n[color=#ff8a8a]Pas de défibrillateur dans l'établissement : massage seul jusqu'aux pompiers.[/color]\n"
	if o.get("gl", false) and career.eq("gants"):
		ds += 2
		extra += "\n[color=#9fe0b4]Les gants anti-coupure te protègent.[/color]\n"
	if o.has("g") and career.eq("video") and inc["ty"] in ["vol", "attouchement", "deal", "ghb", "agentagresse"]:
		dr += 3
		extra += "\n[color=#9fe0b4]Les images de vidéoprotection sont conservées et remises à la police sur réquisition.[/color]\n"
	secu += ds; rep += dr
	_clampg()
	if o.has("f"): _fault("%s (%s) : %s" % [Data.clean(d["t"]), Data.fmt_clock(minute), o["f"]], o.get("law", ""))
	if o.has("g"): _good("%s : %s" % [Data.clean(d["t"]), o["g"]])
	_mc("%s (%s) : %s" % [Data.clean(d["t"]), WorldScript.ZLBL[inc["z"]], o["t"].split(",")[0].to_lower()])
	inc["st"] = "done"
	_end_inc(inc)
	var col := "#9fe0b4" if o.has("g") else ("#ff8a8a" if o.has("f") else "#ffd27a")
	var main_txt: String = o.get("g", o.get("f", o.get("txt", "")))
	var body := "[color=#b9b3cc]Ton choix : %s[/color]\n\n[color=%s]%s[/color]\n" % [o["t"], col, main_txt]
	if o.has("f") and o.has("txt"): body += o["txt"] + "\n"
	if o.has("law"): body += "\n[color=#b9b3cc][i]Loi : %s[/i][/color]\n" % o["law"]
	body += extra
	if d.has("note"): body += "\n[color=#c8a8ff]Inspiré de faits réels : %s[/color]\n" % d["note"]
	var title := "Bonne intervention" if o.has("g") else ("Faute" if o.has("f") else "Résultat")
	ui.open_panel(title, "", body, [{"t": "Continuer la ronde", "k": "main", "cb": _close_panel}])

func _end_inc(inc: Dictionary) -> void:
	if inc.has("mk") and is_instance_valid(inc["mk"]): inc["mk"].queue_free()
	var k := 0
	for a in inc["actors"]:
		if not is_instance_valid(a): continue
		if a.anim == "fallen":
			_free_later(a, 15.0)
			continue
		a.anim = "walk"
		var pts: Array = world.route(a.position, Vector3(randf_range(-1, 1), 0, 3 + k * 0.3))
		pts.append(Vector2(12, 5)); pts.append(Vector2(28, 5))
		a.walk_to(pts, func(q): q.queue_free())
		k += 1
	if inc["agent"] != null:
		var ag = inc["agent"]
		ag.task = null
		ag.run = false
		ag.walk_to(world.route(ag.position, ag.home))

func _free_later(n, secs: float) -> void:
	await get_tree().create_timer(secs).timeout
	if is_instance_valid(n):
		n.queue_free()

func _fail_inc(inc: Dictionary) -> void:
	var d: Dictionary = Data.INC[inc["ty"]]
	var f: Dictionary = d.get("fail", {})
	inc["st"] = "failed"
	secu += float(f.get("s", 0)); rep += float(f.get("r", 0))
	_clampg()
	_fault("%s non traité (%s) : %s" % [Data.clean(d["t"]), Data.fmt_clock(minute), f.get("txt", "ça a dégénéré")], f.get("f", "") if f.has("txt") else "")
	_mc("%s (%s) — personne sur place à temps" % [Data.clean(d["t"]), WorldScript.ZLBL[inc["z"]]])
	_set_radio("« %s : trop tard… %s »" % [Data.clean(d["t"]), f.get("txt", "")])
	_end_inc(inc)

func _radio_menu() -> void:
	var bts := []
	var body := ""
	for inc in incs:
		if inc["st"] != "open": continue
		var row := []
		for a in colleagues:
			var ag = a
			var ii = inc
			row.append({"t": a.pname + (" (occupé)" if a.task != null else ""), "k": "cy", "off": a.task != null, "cb": func(): _send_agent(ag, ii)})
		bts.append({"t": Data.clean(Data.INC[inc["ty"]]["t"]) + " · " + WorldScript.ZLBL[inc["z"]], "off": true})
		bts.append({"row": row})
	if bts.is_empty(): body = "Aucun incident en cours."
	bts.append({"t": "Fermer", "cb": _close_panel})
	ui.open_panel("Radio", "Envoyer un collègue sur un incident (il interviendra seul).", body, bts)

func _send_agent(a, inc: Dictionary) -> void:
	a.task = inc
	inc["st"] = "assigned"
	inc["agent"] = a
	a.run = true
	inc["dm"].emission = Color(0.2, 0.8, 1.0)
	_set_radio("%s : « J'y vais. »" % a.pname)
	var arrived := func(q):
		_agent_arrived(q, inc)
	a.walk_to(world.route(a.position, inc["p"] + Vector3(0.8, 0, 0.8)), arrived)
	_close_panel()

func _agent_arrived(q, inc: Dictionary) -> void:
	q.run = false
	q.anim = "talk"
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(q):
		_agent_resolve(q, inc)

func _agent_resolve(a, inc: Dictionary) -> void:
	if inc["st"] != "assigned": return
	var d: Dictionary = Data.INC[inc["ty"]]
	var o: Dictionary = d["o"][0]
	for x in d["o"]:
		if x.has("g"):
			o = x; break
	var nm := Data.clean(d["t"])
	if randf() < 0.62:
		secu += float(o.get("s", 0)) * 0.7; rep += float(o.get("r", 0)) * 0.7
		_good("%s : géré par %s." % [nm, a.pname])
		_set_radio("%s : « %s : c'est réglé. »" % [a.pname, nm])
	else:
		secu -= 4; rep -= 3
		_set_radio("%s : « %s : j'ai eu du mal, ça a mal tourné… »" % [a.pname, nm])
	_clampg()
	_mc("%s (%s) — %s" % [nm, WorldScript.ZLBL[inc["z"]], a.pname])
	inc["st"] = "done"
	_end_inc(inc)

func _step_salle(delta: float) -> void:
	salle_t += delta
	if Data.CAR != null and career.step_salle(): return
	minute = 150 + salle_t * (210.0 / salle_d)
	if salle_t > next_inc and salle_t < salle_d - 15:
		var ty := ""
		if pend.size() > 0 and randf() < 0.6:
			ty = pend.pop_front()
		else:
			var pool := []
			for k in Data.INC.keys():
				if k in Data.EXCL: continue
				var ok := false
				for z in Data.INC[k]["zones"]:
					if world.ZR.has(z): ok = true
				if ok: pool.append(k)
			ty = pool.pick_random()
		_spawn_incident(ty)
		next_inc = salle_t + randf_range(22, 38) * inc_k
	for i in incs:
		if i["st"] == "open" and salle_t - i["t0"] > i["dl"]:
			_fail_inc(i)
	if salle_t >= salle_d:
		_end_night()

func _end_night() -> void:
	phase = "end"
	ui.close_panel()
	if fight.active:
		fight.active = false
		ui.set_fight("")
	var nf := faults.size()
	var note := int(clamp(round(secu / 100.0 * 9 + rep / 100.0 * 7 + 3 - nf * 1.4 + min(8, goods.size()) * 0.2), 0, 20))
	var ok := 0
	var ko := 0
	for i in incs:
		if i["st"] == "done": ok += 1
		if i["st"] == "failed": ko += 1
	var body := "[center][font_size=64][color=#ff3d9a]%d/20[/color][/font_size][/center]\n" % note
	body += "[center][color=#b9b3cc]Sécurité %d · Réputation %d · Entrées %d € · Incidents gérés %d · ratés %d[/color][/center]\n\n" % [round(secu), round(rep), cash, ok, ko]
	body += "[font_size=22]Fautes et risques (%d)[/font_size]\n" % nf
	if nf == 0: body += "[color=#9fe0b4]Aucune faute. Impeccable.[/color]\n"
	for f in faults:
		body += "[color=#ff8a8a]• %s[/color]\n" % f[0]
		if f[1] != "": body += "   [color=#b9b3cc][i]Loi : %s[/i][/color]\n" % f[1]
	body += "\n[font_size=22]Bien fait (%d)[/font_size]\n" % goods.size()
	for g in goods:
		body += "[color=#9fe0b4]• %s[/color]\n" % g
	body += "\n[font_size=22]Main courante[/font_size]\n[color=#b9b3cc]"
	for m in mcourante:
		body += m + "\n"
	body += "[/color]"
	var bts := []
	if Data.CAR != null:
		body = body.replace("[font_size=22]Fautes et risques", career.end_night(note) + "\n\n[font_size=22]Fautes et risques")
		bts.append({"t": "Vestiaire — nuit suivante", "k": "main", "cb": func(): Data.goto_vestiaire = true; get_tree().reload_current_scene()})
		bts.append({"t": "Menu principal", "cb": func(): get_tree().reload_current_scene()})
	else:
		bts.append({"t": "Nouvelle nuit", "k": "main", "cb": func(): get_tree().reload_current_scene()})
	ui.show_screen("05h00 — Fermeture", body, bts)

# =====================================================================
#  ENTRÉES & BOUCLE
# =====================================================================
func _set_radio(t: String) -> void:
	radio_txt = Data.clean(t)
	ui.radio.text = radio_txt

func _move_dir() -> Vector3:
	var f := Vector3(sin(cam_yaw), 0, cos(cam_yaw))
	var r := Vector3(-f.z, 0, f.x)
	var mv := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv += f
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv -= f
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv -= r
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv += r
	return mv.normalized() if mv.length() > 0.01 else Vector3.ZERO

func _interact() -> void:
	if fight.active: return
	var P := player.position
	if phase == "door" and _cur_ready() and P.distance_to(cur["npc"].position) < 2.4:
		_door_panel()
		return
	if phase == "salle":
		var i = _near_inc()
		if i != null:
			_inc_panel(i)
			return
		var best = null
		var bd := 1.8
		for n in crowd:
			if not is_instance_valid(n) or n.data == null: continue
			var d: float = P.distance_to(n.position)
			if d < bd:
				bd = d; best = n
		if best != null: _client_info(best)

func _client_info(n) -> void:
	sel_npc = n
	var c: Dictionary = n.data
	var body := ""
	var cs := _cues(c)
	for k in min(4, cs.size()):
		body += "• " + cs[k] + "\n"
	ui.open_panel("%s %s" % [c["first"], c["last"]], "Entré(e) ce soir · zone " + WorldScript.ZLBL.get(n.zone, ""), body, [
		{"t": "Le faire sortir (exclusion)", "k": "bad", "cb": _exclude},
		{"t": "Laisser", "cb": _close_panel}])

func _exclude() -> void:
	var n = sel_npc
	var c: Dictionary = n.data
	var just: bool = c["iv"] == 2 or c["att"] != "calme" or c["weapon"] or c["black"] != null or c["minor"] or c["drug"]
	var body := ""
	if just:
		secu += 5
		_good("Exclusion justifiée : %s %s." % [c["first"], c["last"]])
		body = "[color=#9fe0b4]Exclusion justifiée : un incident est sans doute évité.[/color]"
	else:
		rep -= 6
		_fault("Exclusion sans motif de %s %s." % [c["first"], c["last"]], "Exclure sans motif objectif peut constituer une discrimination (art. 225-1 Code pénal).")
		body = "[color=#ff8a8a]Il n'avait rien fait : il proteste et menace de porter plainte.[/color]"
	_clampg()
	_mc("Exclusion : %s %s" % [c["first"], c["last"]])
	crowd.erase(n)
	var pts: Array = world.route(n.position, Vector3(0, 0, 2))
	pts.append(Vector2(12, 5)); pts.append(Vector2(28, 5))
	n.walk_to(pts, func(q): q.queue_free())
	ui.open_panel("Exclusion", "", body, [{"t": "Continuer", "k": "main", "cb": _close_panel}])

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= e.relative.x * 0.0026 * sens
		cam_pitch = clamp(cam_pitch + e.relative.y * 0.0022 * sens, -1.2 if Data.fps else -0.25, 1.2 if Data.fps else 1.0)
	if fight.active and not ui.panel_open and not ui.screen_open:
		if e is InputEventMouseButton and e.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif e.button_index == MOUSE_BUTTON_LEFT:
				fight.push()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				fight.grab()
			return
		if e is InputEventKey and e.pressed and not e.echo:
			match e.physical_keycode:
				KEY_SPACE: fight.do_dodge(_move_dir())
				KEY_Q, KEY_G: fight.punch()   # touche A sur clavier AZERTY
				KEY_TAB: fight.toggle_lock()
				KEY_T: fight.verbal()
				KEY_E: fight.escort()
				KEY_R: fight.backup()
				KEY_H: fight.aid()
				KEY_ESCAPE: _pause_menu()
			return
	if e is InputEventMouseButton and e.pressed and not ui.panel_open and not ui.screen_open and (phase == "door" or phase == "salle"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_E and not ui.panel_open and not ui.screen_open and (phase == "door" or phase == "salle"):
			_interact()
		elif e.physical_keycode == KEY_V and not ui.panel_open and not ui.screen_open:
			_toggle_view()
		elif e.physical_keycode == KEY_R and not ui.panel_open and phase == "salle":
			_radio_menu()
		elif e.physical_keycode == KEY_ESCAPE:
			if ui.panel_open: _close_panel()
			elif phase == "door" or phase == "salle": _pause_menu()
			else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if player == null:
		menu_t += delta
		cam.position = Vector3(sin(menu_t * 0.08) * 9, 3.2, 9 + cos(menu_t * 0.08) * 3)
		cam.look_at(Vector3(0, 2.2, 0))
		return
	var playing: bool = (phase == "door" or phase == "salle") and not ui.panel_open and not ui.screen_open
	if playing:
		var mv := _move_dir()
		var run := Input.is_physical_key_pressed(KEY_SHIFT)
		var down: bool = pvis.anim == "fallen"
		if mv.length() > 0.01 and not down:
			var sp: float = ((3.6 if run else 2.2) * fight.move_mult()) if fight.active else (5.4 if run else 2.9)
			player.velocity = mv * sp
			if not fight.active and not Data.fps: pvis.yaw = pvis.turn_to(pvis.yaw, atan2(mv.x, mv.z), delta * 10.0)
			pvis.anim = "walk"
			pvis.walk_ph += sp * delta * (4.0 if run else 5.2)
		else:
			player.velocity = Vector3.ZERO
			if pvis.anim == "walk": pvis.anim = "fight" if fight.active else "idle"
		if fight.active and pvis.anim == "idle": pvis.anim = "fight"
		if not fight.active and pvis.anim == "fight": pvis.anim = "idle"
		player.move_and_slide()
		if fight.active:
			fight.step(delta, mv)
			if phase == "salle": next_inc += delta
		else:
			fight.hp = min(100.0, fight.hp + 1.5 * delta)
		player.position.y = world.floor_y(player.position.x, player.position.z)
		if phase == "salle":
			_step_salle(delta)
	else:
		player.velocity = Vector3.ZERO
	crosshair.visible = Data.fps and (phase == "door" or phase == "salle") and not ui.screen_open
	pvis.visible = not Data.fps
	if Data.fps:
		# vue à la première personne : la caméra est dans les yeux de l'agent
		pvis.yaw = cam_yaw
		var head := player.position + Vector3(0, 1.68, 0) + Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * 0.12
		if pvis.anim == "fallen": head.y = player.position.y + 0.35
		if fight.shake > 0:
			fight.shake = max(0.0, fight.shake - delta * 0.8)
			head += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * fight.shake * 0.5
		head += _daze_wobble()
		cam.position = head
		var cpf := cos(cam_pitch)
		cam.look_at(head + Vector3(sin(cam_yaw) * cpf, -sin(cam_pitch), cos(cam_yaw) * cpf))
		return
	# caméra 3e personne avec anti-collision
	var tg := player.position + Vector3(0, 1.55, 0)
	var cp := cos(cam_pitch)
	var D := 3.3
	var eye := tg + Vector3(-sin(cam_yaw) * cp * D, sin(cam_pitch) * D + 0.25, -cos(cam_yaw) * cp * D)
	var q := PhysicsRayQueryParameters3D.create(tg, eye)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		eye = tg + (hit["position"] - tg) * 0.85
	if player.position.z < -0.2: eye.y = min(eye.y, 3.75)
	if fight.shake > 0:
		fight.shake = max(0.0, fight.shake - delta * 0.8)
		eye += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * fight.shake
	cam.position = eye + _daze_wobble()
	cam.look_at(tg + Vector3(sin(cam_yaw) * 1.2, -0.15, cos(cam_yaw) * 1.2))

## Sonné : la vision tangue
func _daze_wobble() -> Vector3:
	if not fight.active or fight.daze <= 0.0: return Vector3.ZERO
	var tt := Time.get_ticks_msec() / 1000.0
	return Vector3(sin(tt * 1.7), sin(tt * 2.3) * 0.5, cos(tt * 1.3)) * (fight.daze / 100.0) * 0.18

func _process(delta: float) -> void:
	world.animate(delta)
	if post != null and post.visible:
		var pm: ShaderMaterial = post.material
		var fa: bool = fight.active
		pm.set_shader_parameter("pain", clampf(fight.pain / 100.0, 0.0, 1.0) if fa else 0.0)
		pm.set_shader_parameter("daze", clampf(fight.daze / 100.0, 0.0, 1.0) if fa else 0.0)
		pm.set_shader_parameter("hit", fight.hit_fx if fa else 0.0)
	if phase == "door" or phase == "salle":
		life.step(delta)
	if player != null:
		audio.set_place(world.region(player.position.x, player.position.z), player.position.z)
		minimap.queue_redraw()
		compass.queue_redraw()
	# repères d'incidents
	var t := Time.get_ticks_msec() / 1000.0
	for i in incs:
		if (i["st"] == "open" or i["st"] == "assigned") and is_instance_valid(i.get("mk")):
			i["dia"].rotation.y = t * 2.0
			i["dia"].position.y = 2.6 + sin(t * 3.0) * 0.12
			i["dm"].emission_energy_multiplier = 1.5 + sin(t * 6.0) * 1.0
			if i["fire"]: i["lt"].light_energy = 2.5 + randf() * 1.5
	if player == null or phase == "end": return
	# invite d'action
	var pr := ""
	if not ui.panel_open and not fight.active:
		var P := player.position
		if phase == "door" and _cur_ready() and P.distance_to(cur["npc"].position) < 2.4:
			pr = "[E]  Contrôler le client"
		elif phase == "salle":
			var ni = _near_inc()
			if ni != null:
				pr = "[E]  Intervenir : " + Data.clean(Data.INC[ni["ty"]]["t"])
			else:
				for n in crowd:
					if is_instance_valid(n) and n.data != null and P.distance_to(n.position) < 1.8:
						pr = "[E]  Observer " + n.data["first"]
						break
	ui.prompt.text = pr
	ui_t += delta
	if ui_t < 0.2: return
	ui_t = 0
	ui.set_hud(Data.fmt_clock(minute), inside, cap, secu, rep)
	if phase == "door":
		var st := "Le client avance…"
		if _cur_ready(): st = "Approche-toi du client et appuie sur E"
		ui.obj.text = "PORTE\n%s\nFile : %d · Clique pour viser à la souris" % [st, queue.size()]
	else:
		ui.obj.text = "RONDE EN SALLE\nRejoins les incidents (repères rouges) et appuie sur E.\nR : radio, envoyer un collègue · Maj : courir"
	var lst := ""
	for i in incs:
		if i["st"] == "open":
			lst += "%s — %s · %d s\n" % [Data.clean(Data.INC[i["ty"]]["t"]), WorldScript.ZLBL[i["z"]], max(0, ceil(i["dl"] - (salle_t - i["t0"])))]
		elif i["st"] == "assigned":
			lst += "%s — %s en route\n" % [Data.clean(Data.INC[i["ty"]]["t"]), i["agent"].pname]
	ui.incs.text = lst

# =====================================================================
#  PAUSE ET RÉGLAGES
# =====================================================================
func _pause_menu() -> void:
	var body := "[color=#b9b3cc]Le temps est arrêté tant que ce menu est ouvert.[/color]\n\nSensibilité de la souris : [b]%d %%[/b]\nVolume : [b]%d %%[/b]\nQualité graphique : [b]%s[/b]\nPlein écran : [b]%s[/b]" % [
		round(sens * 100), round(audio.volume_master * 100), QNAMES[Data.quality],
		"oui" if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else "non"]
	ui.open_panel("Pause", "", body, [
		{"t": "Reprendre", "k": "main", "cb": _close_panel},
		{"row": [{"t": "Souris −", "cb": func(): sens = max(0.3, sens - 0.1); _pause_menu()}, {"t": "Souris +", "cb": func(): sens = min(3.0, sens + 0.1); _pause_menu()}]},
		{"row": [{"t": "Volume −", "cb": func(): audio.set_master(audio.volume_master - 0.1); _pause_menu()}, {"t": "Volume +", "cb": func(): audio.set_master(audio.volume_master + 0.1); _pause_menu()}]},
		{"t": "Qualité graphique : %s (changer — baisse si le jeu rame)" % QNAMES[Data.quality], "cb": func(): Data.quality = (Data.quality + 1) % 4; apply_quality(); _pause_menu()},
		{"t": "Vue : %s (touche V)" % ("1re personne" if Data.fps else "3e personne"), "cb": func(): _toggle_view(); _pause_menu()},
		{"t": "Plein écran : activer / désactiver", "cb": _toggle_fullscreen},
		{"t": "Abandonner la nuit et revenir au menu", "k": "bad", "cb": func(): get_tree().reload_current_scene()}])

func _toggle_view() -> void:
	Data.fps = not Data.fps
	cam.fov = 75.0 if Data.fps else 62.0
	cam_pitch = 0.05 if Data.fps else 0.32

func _toggle_hq() -> void:
	hq = not hq
	env.volumetric_fog_enabled = hq
	env.ssao_enabled = hq
	env.glow_enabled = hq
	moon.shadow_enabled = hq
	_pause_menu()

func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_pause_menu()

# =====================================================================
#  MINICARTE ET BOUSSOLE
# =====================================================================
func _mm(x: float, z: float, sz: Vector2) -> Vector2:
	var w: float = 2.0 * world.W + 2.0
	var h: float = -world.ZB + 9.0
	var sc: float = min(sz.x / w, sz.y / h)
	var ox: float = (sz.x - w * sc) / 2.0
	return Vector2(ox + (x + world.W + 1.0) * sc, (z - world.ZB + 1.0) * sc)

func _draw_minimap() -> void:
	var sz := minimap.size
	var sc: float = min(sz.x / (2.0 * world.W + 2.0), sz.y / (-world.ZB + 9.0))
	minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.03, 0.07, 0.85))
	minimap.draw_rect(Rect2(_mm(-world.W, world.ZB, sz), Vector2(2.0 * world.W, -world.ZB) * sc), Color(0.1, 0.08, 0.14))
	minimap.draw_rect(Rect2(_mm(-world.W - 1.0, 0, sz), Vector2(2.0 * world.W + 2.0, 7) * sc), Color(0.12, 0.12, 0.14))
	var zc := {"piste": Color("#ff3d9a"), "bar": Color("#ffc04d"), "vip": Color("#b04dff"), "fumoir": Color("#99aaaa"), "toilettes": Color("#33e1ff"), "vestiaire": Color("#88aa66"), "secours": Color("#3ee08f"), "hall": Color("#5a1030"), "porte": Color("#444444")}
	for k in world.ZR.keys():
		var r: Array = world.ZR[k]
		var c: Color = zc.get(k, Color.GRAY)
		c.a = 0.35
		minimap.draw_rect(Rect2(_mm(r[0], r[2], sz), Vector2(r[1] - r[0], r[3] - r[2]) * sc), c)
	var t := Time.get_ticks_msec() / 1000.0
	for i in incs:
		if i["st"] != "open" and i["st"] != "assigned" and i["st"] != "fight": continue
		var col := Color(0.3, 0.9, 1.0) if i["st"] == "assigned" else (Color(1, 0.25, 0.25) if sin(t * 8.0) > 0 else Color(1, 0.7, 0.7))
		minimap.draw_circle(_mm(i["p"].x, i["p"].z, sz), 6.0, col)
	for a in colleagues:
		if is_instance_valid(a):
			minimap.draw_circle(_mm(a.position.x, a.position.z, sz), 4.0, a.band_col if a.band_col != null else Color.CYAN)
	if player != null:
		var pp := _mm(player.position.x, player.position.z, sz)
		var f := Vector2(sin(cam_yaw), cos(cam_yaw))
		var rgt := Vector2(-f.y, f.x)
		minimap.draw_colored_polygon(PackedVector2Array([pp + f * 10.0, pp - f * 6.0 + rgt * 6.0, pp - f * 6.0 - rgt * 6.0]), Color.WHITE)

func _nearest_open_inc():
	if player == null: return null
	var best = null
	var bd := 1e9
	for i in incs:
		if i["st"] != "open": continue
		var d: float = player.position.distance_to(i["p"])
		if d < bd:
			bd = d; best = i
	return best

func _draw_compass() -> void:
	if phase != "salle" or ui.panel_open or fight.active: return
	var i = _nearest_open_inc()
	if i == null: return
	var dv: Vector3 = i["p"] - player.position
	var dist := Vector2(dv.x, dv.z).length()
	if dist < 2.5: return
	var ang := atan2(dv.x, dv.z) - cam_yaw
	var c := Vector2(30, 30)
	var f := Vector2(-sin(ang), -cos(ang))
	var rgt := Vector2(-f.y, f.x)
	compass.draw_circle(c, 26.0, Color(0, 0, 0, 0.55))
	compass.draw_colored_polygon(PackedVector2Array([c + f * 20.0, c - f * 10.0 + rgt * 11.0, c - f * 4.0, c - f * 10.0 - rgt * 11.0]), Color(1, 0.3, 0.3))
	var font := ThemeDB.fallback_font
	compass.draw_string(font, Vector2(66, 26), Data.clean(Data.INC[i["ty"]]["t"]), HORIZONTAL_ALIGNMENT_LEFT, 250, 16, Color.WHITE)
	compass.draw_string(font, Vector2(66, 46), "%d m · %s" % [round(dist), WorldScript.ZLBL[i["z"]]], HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color(1, 0.7, 0.7))
