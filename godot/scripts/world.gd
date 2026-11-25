extends Node3D
## Les établissements : rue, file d'attente, façade, hall, puis la salle (piste LED, bar, carré VIP,
## fumoir, toilettes, issue de secours). La salle s'adapte à la taille de chaque établissement,
## et le décor utilise les modèles 3D de assets/decor/ quand ils sont présents (licence CC-BY 4.0,
## voir CREDITS.md).

const VENUES := {
	"comptoir": {"name": "Le Comptoir", "type": "Bar de quartier", "sub": "Petit bar à bières, coin danse, terrasse fumeurs. Clientèle d'habitués.",
		"sx": 0.62, "sz": 0.55, "cap": 60, "crowd": 16, "nq": 10, "agents": ["Sarah"], "no_vip": true, "price": 0, "inc_k": 1.25,
		"neon": "#ffc04d", "wall": "#4a3322", "floor": "#3a2616", "accent": "#e08a2c", "unlock": 0, "facade": "#3a2a1e", "fh": 4.2, "theme": "pub"},
	"neon": {"name": "Le Néon", "type": "Discothèque", "sub": "Le club du centre-ville : piste LED, carré VIP, fumoir.",
		"sx": 1.0, "sz": 1.0, "cap": 110, "crowd": 30, "nq": 14, "agents": ["Moussa", "Sarah"], "no_vip": false, "price": 15, "inc_k": 1.0,
		"neon": "#ff3d9a", "wall": "#231a2b", "floor": "#141019", "accent": "#9b1239", "unlock": 0, "facade": "#2a1f2e", "fh": 6.0, "theme": "led"},
	"palace": {"name": "Le Palace", "type": "Club chic", "sub": "Clientèle aisée, grand carré VIP avec son propre bar, dress code strict.",
		"sx": 1.18, "sz": 1.12, "cap": 160, "crowd": 42, "nq": 16, "agents": ["Moussa", "Sarah", "Karim"], "no_vip": false, "price": 25, "inc_k": 0.9,
		"neon": "#ffd27a", "wall": "#3a0f16", "floor": "#e6e0d4", "accent": "#c9a227", "unlock": 300, "facade": "#2b2418", "fh": 6.0, "theme": "chic"},
	"usine": {"name": "L'Usine", "type": "Club électro géant", "sub": "Ancien entrepôt, 300 personnes, DJ internationaux, murs d'équaliseurs. Le plus dur.",
		"sx": 1.42, "sz": 1.45, "cap": 300, "crowd": 70, "nq": 20, "agents": ["Moussa", "Sarah", "Karim", "Inès"], "no_vip": false, "price": 20, "inc_k": 0.72,
		"neon": "#33e1ff", "wall": "#40444c", "floor": "#4a4c50", "accent": "#3a6ea8", "unlock": 700, "facade": "#2a2d33", "fh": 9.0, "theme": "indus"},
	"club": {"name": "Le Velvet", "type": "Club lounge", "sub": "Grande salle avec podium central, banquettes, mezzanine : une clientèle qui sort, qui boit, et qui joue.",
		"sx": 1.0, "sz": 1.0, "cap": 220, "crowd": 46, "nq": 16, "agents": ["Moussa", "Sarah", "Karim"], "no_vip": false, "price": 20, "inc_k": 0.85,
		"neon": "#b04dff", "wall": "#2a1a33", "floor": "#1a1420", "accent": "#7a2a9a", "unlock": 500, "facade": "#24182e", "fh": 7.0, "theme": "model"}}

const ZLBL := {"porte":"Entrée (dehors)","hall":"Hall","vestiaire":"Vestiaire","piste":"Piste","bar":"Bar","vip":"Carré VIP","fumoir":"Fumoir","toilettes":"Toilettes","secours":"Issue de secours"}

var vk := "neon"
var V: Dictionary = VENUES["neon"]
var ZR := {}
var W := 15.0          # demi-largeur de la salle
var ZB := -30.0        # fond de la salle
var HC := 4.05         # hauteur du plafond
var sx := 1.0
var sz := 1.0
var geo := {}          # repères calculés (toilettes, fumoir…)
var UP := {}
const CLUB_O := Vector3(1.0, 0.0, -50.0)      # décalage du modèle 3D du Velvet
const CLUB_IN := Vector2(-2.0, -38.5)         # où l'on arrive dans la salle
const CLUB_OUT := Vector2(-2.0, -36.9)        # porte de sortie vers le hall
const PARENT := {"out": "hall", "hall": "main", "toi": "main", "fum": "main", "main": ""}

var tiles := []
var ledwall := []
var lasers := []
var theme := "led"
var texc := {}
var rain: GPUParticles3D = null
var neons := []
var dj_lights := []
var ball: MeshInstance3D
var exit_sign: MeshInstance3D
var leds: Array = []          # LED rouges des caméras de surveillance
var cars: Array = []          # voitures qui passent dans la rue
var tlight: Array = []        # feu tricolore [rouge, orange, vert]
var pharma: MeshInstance3D
var house: Array = []         # lumières de salle (rallumées à la fermeture)
var smoke: GPUParticles3D = null
var smoke_t := 8.0
var closing := 0.0
var neon_light: OmniLight3D
var anims: Array = []
var t := 0.0
var pc := Vector2(0, -18)    # centre de la piste

func X(x: float) -> float:
	return x * sx

func Zm(z: float) -> float:
	return z if z > -6.1 else -6.1 + (z + 6.1) * sz

func _geo() -> void:
	if vk == "club":
		W = 18.9; ZB = -67.9; HC = 4.3
		ZR = {"porte": [-1.5, 4.0, 1.2, 4.0], "hall": [-3.0, 3.0, -5.5, -1.0], "vestiaire": [-3.6, -2.6, -5.0, -1.0],
			"piste": [-8.0, 1.0, -53.0, -47.5], "bar": [-16.0, -14.6, -58.0, -45.0], "vip": [-8.0, 5.0, -63.0, -60.5],
			"secours": [7.0, 9.0, -54.0, -48.0]}
		var bx := -16.4
		geo = {"djz": -51.8, "djw": 0.0, "djh": 0.0, "barman_x": (bx - 0.45 + (-W + 0.7)) / 2.0, "bar_z0": -58.0, "bar_z1": -45.0,
			"bar_front_x": bx + 1.0, "bx": bx, "dj_pos": Vector3(-10.5, 0, -51.8), "dj_yaw": PI / 2.0,
			"tx": -99.0, "tz": -99.0, "fx": 99.0, "fz0": -99.0, "dz": -99.0, "gx0": -99.0, "gx1": -98.0}
		UP = {"out": [Vector2(0, 1), Vector2(0, -0.8)], "hall": [Vector2(0, -4.6), Vector2(0, -6.0)]}
		return
	W = 15.0 * sx
	ZB = Zm(-30.0)
	HC = 5.5 if vk == "usine" else 4.05
	ZR = {"porte": [-1.5, 4.0, 1.2, 4.0], "hall": [-3.0, 3.0, -5.5, -1.0], "vestiaire": [-3.6, -2.6, -5.0, -1.0],
		"piste": [X(-5.5), X(5.5), Zm(-23.5), Zm(-12.5)], "bar": [X(-10.4), X(-8.0), Zm(-23.0), Zm(-9.5)],
		"fumoir": [X(10.0), X(14.5), Zm(-13.5), Zm(-7.5)], "toilettes": [X(-14.5), X(-9.5), Zm(-29.5), Zm(-26.0)],
		"secours": [W - 2.5, W - 0.6, Zm(-20.0), Zm(-16.0)]}
	if not V["no_vip"]:
		ZR["vip"] = [X(9.0), X(14.0), Zm(-29.0), Zm(-21.0)]
	geo = {"bar_z0": Zm(-22.0), "bar_z1": Zm(-10.0), "bar_front_x": X(-9.6), "dj_pos": Vector3(0, 0, Zm(-27.5) + 0.35), "dj_yaw": 0.0, "djz": Zm(-27.5), "djw": 0.0 if vk == "comptoir" else 4.0 * minf(sx, 1.2), "djh": 1.2 if vk == "usine" else 0.6, "barman_x": (X(-11.0) - 0.45 + (-W + 0.7)) / 2.0, "tx": X(-9.1), "tz": Zm(-25.1), "fx": X(9.1), "fz0": Zm(-14.1), "dz": Zm(-9.4), "gx0": X(-12.4), "gx1": X(-10.0)}
	var gm: float = (geo["gx0"] + geo["gx1"]) / 2.0
	UP = {"out": [Vector2(0, 1), Vector2(0, -0.8)], "hall": [Vector2(0, -4.6), Vector2(0, -7.6)],
		"toi": [Vector2(gm, geo["tz"] - 1.2), Vector2(gm, geo["tz"] + 1.4)],
		"fum": [Vector2(geo["fx"] + 0.9, geo["dz"]), Vector2(geo["fx"] - 0.9, geo["dz"])]}

## Hauteur du sol à un endroit (trottoir, piste LED, estrade du carré VIP)
func floor_y(x: float, z: float) -> float:
	if theme == "model" and z < -20.0:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 3.4, z), Vector3(x, -3.5, z), 1)
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		return h["position"].y if not h.is_empty() else 0.0
	if ZR.has("vip"):
		var v: Array = ZR["vip"]
		if x > v[0] - 1.0 and x < W and z > v[2] - 1.0 and z < v[3]: return 0.3
	if z > 0.0 and z < 6.0 and absf(x) < 22.0: return 0.12
	if absf(x) < geo["djw"] and absf(z - geo["djz"]) < 1.75: return geo["djh"]
	var p: Array = ZR["piste"]
	if x > p[0] - 0.5 and x < p[1] + 0.5 and z > p[2] - 0.5 and z < p[3] + 0.5: return 0.08
	return 0.0

func zpt(z: String) -> Vector3:
	var r = ZR[z]
	return Vector3(randf_range(r[0], r[1]), 0, randf_range(r[2], r[3]))

# ---------- navigation par points de passage ----------
func region(x: float, z: float) -> String:
	if theme == "model":
		if z > 0.4: return "out"
		if z > -6.6: return "hall"
		return "main"
	if z > 0.4: return "out"
	if z > -6.2: return "hall"
	if x < geo["tx"] and z < geo["tz"]: return "toi"
	if x > geo["fx"] and z > geo["fz0"] and z < -6.0: return "fum"
	return "main"

func route(a: Vector3, b: Vector3) -> Array:
	var ra := region(a.x, a.z)
	var rb := region(b.x, b.z)
	if ra == rb: return [Vector2(b.x, b.z)]
	if theme == "model":
		# le Velvet : on passe du hall à la salle par la porte (un Vector3 = téléportation)
		var pts := []
		if ra == "out": pts.append_array(UP["out"])
		if ra == "main":
			pts.append(CLUB_OUT)
			pts.append(Vector3(0, 0, -5.6))
			if rb == "out": pts.append_array([Vector2(0, -0.8), Vector2(0, 1)])
		elif rb == "main":
			pts.append_array(UP["hall"])
			pts.append(Vector3(CLUB_IN.x, 0, CLUB_IN.y))
		elif ra == "hall" and rb == "out":
			pts.append_array([Vector2(0, -0.8), Vector2(0, 1)])
		pts.append(Vector2(b.x, b.z))
		return pts
	var ca := []
	var cb := []
	var r := ra
	while r != "":
		ca.append(r); r = PARENT[r]
	r = rb
	while r != "":
		cb.append(r); r = PARENT[r]
	var common := ""
	for x in ca:
		if x in cb:
			common = x; break
	var pts := []
	for x in ca:
		if x == common: break
		pts.append_array(UP[x])
	var down := []
	for x in cb:
		if x == common: break
		var u: Array = UP[x].duplicate()
		u.reverse()
		down = u + down
	pts.append_array(down)
	pts.append(Vector2(b.x, b.z))
	return pts

# ---------- construction ----------
func _mat(c: Color, emi := Color.BLACK, e := 0.0, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emi
		m.emission_energy_multiplier = e
	return m

## Textures procédurales (bruit) : grain du bois, béton, plâtre, asphalte mouillé, marbre
func _tex(kind: String) -> Dictionary:
	if texc.has(kind): return texc[kind]
	var n := FastNoiseLite.new()
	n.seed = kind.hash()
	var lo := 0.72
	var freq := 0.03
	match kind:
		"wood":
			n.noise_type = FastNoiseLite.TYPE_PERLIN; freq = 0.06; lo = 0.68
			n.fractal_octaves = 3
		"concrete":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; freq = 0.05; lo = 0.7
			n.fractal_octaves = 5
		"plaster":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX; freq = 0.08; lo = 0.86
		"asphalt":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR; freq = 0.12; lo = 0.7
		"marble":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; freq = 0.02; lo = 0.8
			n.domain_warp_enabled = true
			n.domain_warp_amplitude = 60.0
		"fabric":
			n.noise_type = FastNoiseLite.TYPE_VALUE; freq = 0.4; lo = 0.82
	n.frequency = freq
	var g := Gradient.new()
	g.set_color(0, Color(lo, lo, lo))
	g.set_color(1, Color(1, 1, 1))
	var alb := NoiseTexture2D.new()
	alb.width = 512; alb.height = 512; alb.seamless = true
	alb.noise = n
	alb.color_ramp = g
	var nrm := NoiseTexture2D.new()
	nrm.width = 512; nrm.height = 512; nrm.seamless = true
	nrm.noise = n
	nrm.as_normal_map = true
	nrm.bump_strength = 2.0 if kind != "plaster" else 1.2
	var d := {"alb": alb, "nrm": nrm}
	if kind == "asphalt":
		# flaques : grandes taches lisses qui reflètent les lumières
		var pn := FastNoiseLite.new()
		pn.seed = 7
		pn.frequency = 0.012
		var pg := Gradient.new()
		pg.offsets = PackedFloat32Array([0.0, 0.45, 0.6, 1.0])
		pg.colors = PackedColorArray([Color(0.05, 0.05, 0.05), Color(0.08, 0.08, 0.08), Color(0.7, 0.7, 0.7), Color(0.85, 0.85, 0.85)])
		var rt := NoiseTexture2D.new()
		rt.width = 512; rt.height = 512; rt.seamless = true
		rt.noise = pn
		rt.color_ramp = pg
		d["rough"] = rt
	texc[kind] = d
	return d

## Habille un objet avec une texture (projection triplanaire : pas besoin de coordonnées UV)
func surface(mi: MeshInstance3D, kind: String, scale := 0.5, rough := -1.0) -> void:
	if mi == null: return
	var m: StandardMaterial3D = mi.material_override
	var d := _tex(kind)
	m.albedo_texture = d["alb"]
	m.normal_enabled = true
	m.normal_texture = d["nrm"]
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	if kind == "wood": m.uv1_scale = Vector3(scale * 0.25, scale, scale * 3.0)
	if d.has("rough"):
		m.roughness = 1.0
		m.roughness_texture = d["rough"]
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	elif rough >= 0.0:
		m.roughness = rough

## Projecteur asservi (lyre) : faisceau visible dans la fumée
func mover(p: Vector3, col: String, energy := 14.0) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.position = p
	s.light_color = Color(col)
	s.light_energy = energy
	s.spot_range = HC + 10.0
	s.spot_angle = 14.0
	s.spot_attenuation = 0.6
	s.light_volumetric_fog_energy = 4.0
	s.set_meta("mover", true)
	s.rotation = Vector3(-PI / 2.0, 0, 0)
	add_child(s)
	sph(p + Vector3(0, 0.1, 0), 0.16, "#111111", "", 0.0, 0.3, 0.8)
	return s

func box(c: Vector3, s: Vector3, col: String, collide := false, emi := "", e := 0.0, rough := 0.8, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = _mat(Color(col), Color(emi) if emi != "" else Color.BLACK, e, rough, metal)
	mi.position = c
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = s
		cs.shape = sh
		sb.add_child(cs)
		sb.position = c
		add_child(sb)
	return mi

func cyl(c: Vector3, r: float, h: float, col: String, collide := false, emi := "", e := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h
	mi.mesh = cm
	mi.material_override = _mat(Color(col), Color(emi) if emi != "" else Color.BLACK, e)
	mi.position = c
	add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = r; sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		sb.position = c
		add_child(sb)
	return mi

func sph(c: Vector3, r: float, col: String, emi := "", e := 0.0, rough := 0.6, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2
	mi.mesh = sm
	mi.material_override = _mat(Color(col), Color(emi) if emi != "" else Color.BLACK, e, rough, metal)
	mi.position = c
	add_child(mi)
	return mi

func omni(c: Vector3, col: String, rng: float, energy: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = c
	l.light_color = Color(col)
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = shadow
	add_child(l)
	return l

# ---------- modèles 3D du dossier assets/decor ----------
func has_decor(key: String) -> bool:
	return ResourceLoader.exists("res://assets/decor/%s.glb" % key)

## Place un modèle : centré au sol sur « pos », tourné de « ry », mis à l'échelle pour que
## sa plus grande dimension horizontale (ou sa hauteur si by_height) vaille « size ».
## Une taille négative donne directement le facteur d'échelle (ex. -0.0254 : modèle en pouces).
func prop(key: String, pos: Vector3, ry: float, size: float, by_height := false, collide := true, strip_room := false) -> Node3D:
	if not has_decor(key): return null
	var sc = load("res://assets/decor/%s.glb" % key)
	if sc == null or not (sc is PackedScene): return null
	var inst: Node3D = sc.instantiate()
	var holder := Node3D.new()
	holder.add_child(inst)
	var bb := _aabb(inst)
	if bb.size == Vector3.ZERO:
		holder.queue_free()
		return null
	var ref: float = bb.size.y if by_height else maxf(bb.size.x, bb.size.z)
	var k: float = -size if size < 0.0 else size / maxf(ref, 0.0001)
	inst.scale = Vector3.ONE * k
	inst.position = Vector3(-(bb.position.x + bb.size.x / 2.0) * k, -bb.position.y * k, -(bb.position.z + bb.size.z / 2.0) * k)
	holder.position = pos
	holder.rotation.y = ry
	add_child(holder)
	# les modèles « pièce entière » (murs, sol, plafond) : on ne garde que le mobilier
	if strip_room:
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var b2: AABB = _node_aabb(mi, inst)
			var s2: Vector3 = b2.size * k
			var flat_big: bool = s2.y < 0.35 and s2.x > 2.6 and s2.z > 1.8
			var wall: bool = s2.y > 2.0 and minf(s2.x, s2.z) < 0.35 and maxf(s2.x, s2.z) > 2.4
			if flat_big or wall: mi.visible = false
	# animations intégrées au modèle (équaliseur, lumières des tabourets…)
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null:
		var lst := ap.get_animation_list()
		for an in lst:
			if an == "RESET": continue
			var anim: Animation = ap.get_animation(an)
			anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(an)
			break
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var fs: Vector3 = bb.size * k
		sh.size = Vector3(fs.x, fs.y, fs.z) * Vector3(0.9, 1.0, 0.9)
		cs.shape = sh
		cs.position = Vector3(0, fs.y / 2.0, 0)
		sb.add_child(cs)
		holder.add_child(sb)
	return holder

func _node_aabb(mi: VisualInstance3D, root: Node) -> AABB:
	var xf := Transform3D()
	var n: Node = mi
	while n != null and n != root:
		var n3 := n as Node3D
		if n3 != null: xf = n3.transform * xf
		n = n.get_parent()
	return xf * mi.get_aabb()

func _aabb(root: Node3D) -> AABB:
	var res := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = _node_aabb(mi, root)
		if first:
			res = b; first = false
		else:
			res = res.merge(b)
	return res

func build(key := "neon") -> void:
	vk = key if VENUES.has(key) else "neon"
	V = VENUES[vk]
	sx = V["sx"]; sz = V["sz"]
	theme = V["theme"]
	_geo()
	var NE: String = V["neon"]
	var WC: String = V["wall"]
	var FW: float = max(20.0, W + 1.5)
	var FH: float = V["fh"]
	# ---- DEHORS ----
	surface(box(Vector3(0, -0.05, 14), Vector3(2 * FW + 20, 0.1, 30), "#1d1c22", true, "", 0.0, 0.35), "asphalt", 0.15)
	var x := -FW - 4.0
	while x < FW + 6.0:
		box(Vector3(x, 0.005, 11), Vector3(2, 0.01, 0.18), "#d8d2b0")
		x += 4.0
	surface(box(Vector3(0, 0.06, 3), Vector3(2 * FW + 4, 0.12, 6), "#3a3840", false, "", 0.0, 0.5), "concrete", 0.4, 0.45)
	box(Vector3(0, 0.13, 6), Vector3(2 * FW + 4, 0.02, 0.25), "#4a4752")
	x = 2.2
	while x < 11.0:
		cyl(Vector3(x, 0.5, 2.0), 0.04, 1.0, "#c9a227")
		x += 1.6
	box(Vector3(6.5, 0.85, 2.0), Vector3(8.6, 0.06, 0.06), V["accent"], true)
	for s in [-1, 1]:
		cyl(Vector3(s * 1.3, 0.5, 1.5), 0.05, 1.0, "#c9a227")
		sph(Vector3(s * 1.3, 1.03, 1.5), 0.07, "#e8c547", "", 0.0, 0.3, 0.8)
	for i in 8:
		sph(Vector3(-1.3 + i * (2.6 / 7.0), 0.86 - sin(i / 7.0 * PI) * 0.12, 1.5), 0.045, V["accent"])
	# façade
	var fc: String = V["facade"]
	surface(box(Vector3(-(2 + FW) / 2.0, FH / 2.0, -0.2), Vector3(FW - 2, FH, 0.4), fc, true), "concrete" if theme == "indus" else "plaster", 0.5)
	surface(box(Vector3((2 + FW) / 2.0, FH / 2.0, -0.2), Vector3(FW - 2, FH, 0.4), fc, true), "concrete" if theme == "indus" else "plaster", 0.5)
	box(Vector3(0, (3.2 + FH) / 2.0, -0.2), Vector3(4, FH - 3.2, 0.4), fc)
	if vk == "comptoir":
		for s in [-1, 1]: box(Vector3(s * 5, 1.6, 0.01), Vector3(3, 1.6, 0.05), "#000000", false, "#ffb860", 1.5)
		box(Vector3(0, 3.6, 0.6), Vector3(9, 0.1, 1.4), "#7a1d1d")
	if vk == "usine":
		x = -FW + 2.0
		while x < FW:
			box(Vector3(x, 6.5, 0.02), Vector3(2.2, 1.6, 0.05), "#0b0d10", false, "#1f3a44", 1.0)
			x += 3.0
	if vk == "palace":
		for s in [-1, 1]:
			cyl(Vector3(s * 2.6, 1.6, 0.4), 0.18, 3.2, "#d8c48a")
			sph(Vector3(s * 2.6, 3.3, 0.4), 0.22, "#000000", "#ffe2a0", 3.0)
		box(Vector3(0, 0.14, 1.2), Vector3(3, 0.04, 2.4), "#7a0f1f")
	for s in [-1, 1]:
		box(Vector3(s * 1.75, 1.6, 0), Vector3(0.3, 3.2, 0.5), "#111111", false, "#26030d", 1.0)
	box(Vector3(0, 3.25, 0), Vector3(3.8, 0.25, 0.5), "#111111")
	var sy: float = min(FH - 0.8, 4.4)
	box(Vector3(0, sy, 0.08), Vector3(4.6, 0.9, 0.12), "#1a0a14")
	for i in 5:
		neons.append(box(Vector3(-1.8 + i * 0.9, sy, 0.16), Vector3(0.55, 0.55, 0.04), "#000000", false, NE, 4.0))
	neons.append(box(Vector3(0, sy + 0.55, 0.16), Vector3(4.4, 0.06, 0.04), "#000000", false, NE, 4.0))
	neons.append(box(Vector3(0, sy - 0.55, 0.16), Vector3(4.4, 0.06, 0.04), "#000000", false, NE, 4.0))
	neon_light = omni(Vector3(0, sy - 0.1, 1.6), NE, 9.0, 2.0, true)
	box(Vector3(0, 3.45, 0.9), Vector3(3.6, 0.12, 1.8), "#300c22")
	# éclairage de la porte : on doit voir les visages des clients
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.4, 3.3, 1.6)
	spot.rotation = Vector3(-1.25, 0, 0)
	spot.light_color = Color("#ffe6c4")
	spot.light_energy = 6.0
	spot.spot_range = 7.0
	spot.spot_angle = 40.0
	spot.shadow_enabled = true
	add_child(spot)
	omni(Vector3(1.5, 2.6, 3.4), "#ffd9b0", 6.0, 1.6)
	omni(Vector3(6.5, 3.0, 4.0), "#ffcf9a", 9.0, 1.4)
	for lx in [-12.0, 9.0, 22.0]:
		cyl(Vector3(lx, 2.5, 5.6), 0.07, 5.0, "#2a2a33", true)
		box(Vector3(lx, 5, 5.2), Vector3(0.15, 0.1, 0.8), "#2a2a33")
		sph(Vector3(lx, 4.9, 4.85), 0.16, "#000000", "#ffd27a", 3.0)
		omni(Vector3(lx, 4.6, 4.8), "#ffcf7a", 9.0, 1.0, lx == 9.0)
		var ls := SpotLight3D.new()
		ls.position = Vector3(lx, 4.75, 4.85)
		ls.rotation = Vector3(-PI / 2.0, 0, 0)
		ls.light_color = Color("#ffcf7a")
		ls.light_energy = 6.0
		ls.spot_range = 7.0
		ls.spot_angle = 38.0
		ls.light_volumetric_fog_energy = 2.5
		add_child(ls)
	for car in [[-16.0, "#7b1d1d"], [-9.0, "#1d3d7b"], [15.0, "#d0d0d6"], [20.5, "#232323"]]:
		var cx: float = car[0]
		box(Vector3(cx, 0.65, 8.5), Vector3(4.2, 0.7, 1.8), car[1], true, "", 0.0, 0.25, 0.6)
		box(Vector3(cx - 0.2, 1.25, 8.5), Vector3(2.2, 0.55, 1.6), car[1], false, "", 0.0, 0.25, 0.6)
		box(Vector3(cx - 0.2, 1.25, 8.5), Vector3(2.25, 0.45, 1.62), "#0d1622", false, "", 0.0, 0.05, 0.3)
		for w in [Vector2(-1.4, -0.9), Vector2(1.4, -0.9), Vector2(-1.4, 0.9), Vector2(1.4, 0.9)]:
			var wh := cyl(Vector3(cx + w.x, 0.35, 8.5 + w.y), 0.35, 0.25, "#0b0b0b")
			wh.rotation.x = PI / 2
		sph(Vector3(cx + 2.1, 0.75, 7.9), 0.08, "#000000", "#fff6c8", 4.0)
		sph(Vector3(cx + 2.1, 0.75, 9.1), 0.08, "#000000", "#fff6c8", 4.0)
	box(Vector3(0, 9, 24), Vector3(2 * FW + 20, 18, 1), "#120f1a")
	x = -FW - 6.0
	while x < FW + 8.0:
		var yy := 2.0
		while yy < 17.0:
			if randf() > 0.45:
				box(Vector3(x, yy, 23.45), Vector3(1.2, 1.4, 0.05), "#000000", false, "#ffcf7a" if randf() > 0.5 else "#7ad7ff", 1.5)
			yy += 3.0
		x += 3.0
	box(Vector3(-FW - 5, 9, 5), Vector3(1, 18, 40), "#120f1a", true)
	box(Vector3(FW + 5, 9, 5), Vector3(1, 18, 40), "#120f1a", true)
	box(Vector3(0, 1, 16.5), Vector3(2 * FW + 20, 2, 1), "#120f1a", true)
	# ---- INTÉRIEUR ----
	if theme == "model":
		_build_club()
		return
	var D: float = -ZB
	var flo := box(Vector3(0, -0.05, ZB / 2.0), Vector3(2 * W, 0.1, D), V["floor"], true, "", 0.0, 0.3, 0.1)
	match theme:
		"led": surface(flo, "concrete", 0.3, 0.12)
		"chic": surface(flo, "marble", 0.12, 0.08)
		"indus": surface(flo, "concrete", 0.35, 0.55)
		_: surface(flo, "wood", 0.5, 0.5)
	box(Vector3(0, HC, ZB / 2.0), Vector3(2 * W, 0.1, D), "#09070d")
	var wkind := "concrete" if theme == "indus" else ("fabric" if theme == "chic" else ("wood" if theme == "pub" else "plaster"))
	surface(box(Vector3(-W - 0.1, HC / 2.0, ZB / 2.0), Vector3(0.3, HC, D), WC, true), wkind, 0.5)
	var ez: float = Zm(-17.0)
	surface(box(Vector3(W + 0.1, HC / 2.0, (ZB + ez - 1.2) / 2.0), Vector3(0.3, HC, ez - 1.2 - ZB), WC, true), wkind, 0.5)
	surface(box(Vector3(W + 0.1, HC / 2.0, (ez + 1.2) / 2.0), Vector3(0.3, HC, -(ez + 1.2)), WC, true), wkind, 0.5)
	surface(box(Vector3(0, HC / 2.0, ZB - 0.1), Vector3(2 * W, HC, 0.3), WC, true), wkind, 0.5)
	if vk == "usine":
		x = -W + 3.0
		while x < W:
			box(Vector3(x, HC - 0.4, ZB / 2.0), Vector3(0.25, 0.4, D), "#3a3f48")
			x += 6.0
	if vk == "palace":
		var zz := -8.0
		while zz > ZB + 1.0:
			for s in [-1, 1]: box(Vector3(s * (W - 0.05), 2.0, zz), Vector3(0.06, 3.6, 0.12), "#c9a227", false, "#2a1f05", 1.0)
			zz -= 4.0
	# issue de secours
	box(Vector3(W + 0.1, 1.1, ez), Vector3(0.25, 2.2, 2.2), "#1d4d2e", true, "#003a14", 0.5)
	box(Vector3(W + 0.1, (2.2 + HC) / 2.0, ez), Vector3(0.3, HC - 2.2, 2.2), WC)
	exit_sign = box(Vector3(W - 0.15, 2.6, ez), Vector3(0.06, 0.35, 1), "#000000", false, "#30ff7a", 4.0)
	omni(Vector3(W - 1.0, 2.6, ez), "#30ff7a", 5.0, 0.8)
	# hall (taille fixe)
	box(Vector3(-(3 + W) / 2.0, HC / 2.0, -6.1), Vector3(W - 3, HC, 0.3), WC, true)
	box(Vector3((3 + W) / 2.0, HC / 2.0, -6.1), Vector3(W - 3, HC, 0.3), WC, true)
	box(Vector3(4.1, HC / 2.0, -3), Vector3(0.3, HC, 6), WC, true)
	box(Vector3(0, 0.01, -3), Vector3(3.6, 0.02, 5), V["accent"])
	box(Vector3(-4.4, 0.55, -3), Vector3(0.8, 1.1, 4), "#3a2a1c", true)
	box(Vector3(-4.4, 1.12, -3), Vector3(0.9, 0.05, 4.1), "#6b4a2c")
	box(Vector3(-5.2, HC / 2.0, -3), Vector3(0.1, HC, 6), WC)
	var z := -5.0
	while z < -0.8:
		box(Vector3(-6.5, 1.6, z), Vector3(0.5, 1, 0.28), ["#3d6fd8", "#c0392b", "#2c3e50", "#8e44ad", "#16a085", "#111111", "#c49a6c"].pick_random())
		z += 0.35
	if W > 10.5: box(Vector3(-10, HC / 2.0, -3), Vector3(0.3, HC, 6), WC, true)
	omni(Vector3(-3, 3.6, -3), "#ffd9a8", 7.0, 1.0)
	_build_floor_and_stage()
	# bar
	var bz0: float = Zm(-23.0)
	var bz1: float = Zm(-9.0)
	var bx: float = X(-11.0)
	_build_bar(bx, bz0, bz1)
	# tables hautes et tabourets autour de la piste
	if has_decor("bright_bar_table_and_stool_set"):
		var tsets := [[X(-7.4), Zm(-12.2)], [X(-7.4), Zm(-24.4)], [X(7.4), Zm(-16.0)], [X(7.4), Zm(-19.8)]]
		if vk == "usine": tsets.append_array([[X(-7.4), Zm(-18.3)], [X(7.4), Zm(-23.6)]])
		if vk == "comptoir": tsets = [[X(-6.6), Zm(-12.6)], [X(6.6), Zm(-17.0)]]
		for ts in tsets:
			prop("bright_bar_table_and_stool_set", Vector3(ts[0], 0, ts[1]), PI / 2.0, 1.9)
	# carré VIP
	if not V["no_vip"]:
		var vr: Array = ZR["vip"]
		var vx0: float = vr[0] - 1.0
		var vx1: float = W
		var vcx: float = (vx0 + vx1) / 2.0
		var vw: float = vx1 - vx0
		var vz0: float = vr[2] - 1.0
		var vz1: float = vr[3]
		var vcz: float = (vz0 + vz1) / 2.0
		var vd: float = vz1 - vz0
		box(Vector3(vcx, 0.15, vcz), Vector3(vw, 0.3, vd), "#2b1a08" if vk == "palace" else "#2a0f34")
		box(Vector3(vx0 + 0.1, 0.55, vcz), Vector3(0.08, 0.5, vd), V["accent"])
		if vk == "palace" and has_decor("bar_bar"):
			# le Palace a son propre bar dans le carré VIP
			prop("bar_bar", Vector3(vcx, 0.3, vz0 + 1.6), 0.0, -0.0254, false, false, true)
			var sbv := StaticBody3D.new()
			var csv := CollisionShape3D.new()
			var shv := BoxShape3D.new()
			shv.size = Vector3(3.2, 1.1, 0.5)
			csv.shape = shv
			sbv.position = Vector3(vcx, 0.85, vz0 + 1.8)
			sbv.add_child(csv)
			add_child(sbv)
		else:
			box(Vector3(vcx, 0.55, vz0 + 0.4), Vector3(vw - 0.4, 0.7, 0.7), "#5b1f6e", true)
			box(Vector3(vcx, 1.05, vz0 + 0.15), Vector3(vw - 0.4, 0.6, 0.25), "#4a1a5a")
		box(Vector3(W - 0.9, 0.55, vcz + 1.0), Vector3(0.7, 0.7, vd - 3.0), "#5b1f6e", true)
		box(Vector3(W - 0.65, 1.05, vcz + 1.0), Vector3(0.25, 0.6, vd - 3.0), "#4a1a5a")
		var tx := vx0 + 2.0
		while tx < W - 2.0:
			var tz := vz0 + (4.2 if vk == "palace" else 2.0)
			while tz < vz1 - 1.0:
				cyl(Vector3(tx, 0.55, tz), 0.45, 0.08, "#1a1420", true)
				cyl(Vector3(tx, 0.3, tz), 0.08, 0.5, "#c9a227")
				cyl(Vector3(tx, 0.75, tz), 0.12, 0.3, "#9fe0ff", false, "#1a4a66", 1.5)
				if has_decor("ufo_modern_chandelier"):
					prop("ufo_modern_chandelier", Vector3(tx, HC - 0.32, tz), 0.0, 1.0, false, false)
				tz += 3.4
			tx += 2.4
		omni(Vector3(vcx, HC - 0.6, vcz), "#ffd27a" if vk == "palace" else "#b04dff", 9.0 + vw * 0.4, 2.0)
	# fumoir
	var fx: float = geo["fx"]
	var fz0: float = geo["fz0"]
	var dz: float = geo["dz"]
	box(Vector3(fx, HC / 2.0, (fz0 + dz - 1.7) / 2.0), Vector3(0.2, HC, dz - 1.7 - fz0), WC, true)
	box(Vector3(fx, HC / 2.0, (dz + 1.7 - 6.1) / 2.0), Vector3(0.2, HC, -6.1 - (dz + 1.7)), WC, true)
	box(Vector3(fx, (2.8 + HC) / 2.0, dz), Vector3(0.2, HC - 2.8, 3.4), WC)
	box(Vector3((fx + W) / 2.0, HC / 2.0, fz0), Vector3(W - fx, HC, 0.2), WC, true)
	var glass := box(Vector3(fx, 1.4, dz), Vector3(0.06, 2.8, 3.4), "#7ad7ff")
	var gm: StandardMaterial3D = glass.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.5, 0.85, 1.0, 0.15)
	gm.roughness = 0.05
	for c in [Vector2(X(11), Zm(-12.5)), Vector2(X(13.6), Zm(-12.5)), Vector2(X(13.6), Zm(-8.5))]:
		cyl(Vector3(c.x, 0.5, c.y), 0.18, 1.0, "#333333", true)
	omni(Vector3((fx + W) / 2.0, HC - 0.6, (fz0 - 6.1) / 2.0), "#c8c8d8", 7.0, 1.0)
	# toilettes
	var tzz: float = geo["tz"]
	var txx: float = geo["tx"]
	var gx0: float = geo["gx0"]
	var gx1: float = geo["gx1"]
	box(Vector3((-W + gx0) / 2.0, HC / 2.0, tzz), Vector3(gx0 + W, HC, 0.2), WC, true)
	box(Vector3((gx1 + txx) / 2.0, HC / 2.0, tzz), Vector3(txx - gx1, HC, 0.2), WC, true)
	box(Vector3(txx, HC / 2.0, (tzz + ZB) / 2.0), Vector3(0.2, HC, tzz - ZB), WC, true)
	box(Vector3((gx0 + gx1) / 2.0, (2.8 + HC) / 2.0, tzz), Vector3(gx1 - gx0, HC - 2.8, 0.2), WC)
	var ns: int = max(2, int(round(3 * sx)))
	for k in ns:
		var stx: float = -W + 0.6 + k * ((txx + W - 1.0) / ns)
		box(Vector3(stx, 1.1, ZB + 1.4), Vector3(0.06, 2.2, 2.6), "#3a5266", true)
		cyl(Vector3(stx + 0.6, 0.25, ZB + 0.4), 0.22, 0.5, "#e8eef2")
	box(Vector3((txx - W) / 2.0, 0.01, (tzz + ZB) / 2.0), Vector3(txx + W - 0.2, 0.02, tzz - ZB - 0.2), "#2a3a46", false, "", 0.0, 0.15)
	omni(Vector3((txx - W) / 2.0, HC - 0.6, (tzz + ZB) / 2.0), "#cfe9ff", 7.0, 1.2)
	_build_theme_decor()
	_build_atmosphere()
	_build_details()
	_build_street_life()
	# plafonniers
	var px := -W + 3.0
	while px <= W - 3.0:
		var pz := -9.0
		while pz >= ZB + 3.0:
			sph(Vector3(px, HC - 0.1, pz), 0.12, "#000000", "#ffcf9a" if theme == "pub" or theme == "chic" else NE, 3.0)
			pz -= 6.0
		px += 6.0

# ---------- le Velvet : la salle vient du modèle 3D « Night Dance Club » ----------
func _build_club() -> void:
	var NE: String = V["neon"]
	var WC: String = V["wall"]
	# hall (même organisation que les autres lieux)
	box(Vector3(0, -0.05, -3.05), Vector3(2 * W, 0.1, 6.1), V["floor"], true)
	box(Vector3(0, HC, -3.05), Vector3(2 * W, 0.1, 6.1), "#09070d")
	box(Vector3(-(3 + W) / 2.0, HC / 2.0, -6.1), Vector3(W - 3, HC, 0.3), WC, true)
	box(Vector3((3 + W) / 2.0, HC / 2.0, -6.1), Vector3(W - 3, HC, 0.3), WC, true)
	box(Vector3(4.1, HC / 2.0, -3), Vector3(0.3, HC, 6), WC, true)
	box(Vector3(-10, HC / 2.0, -3), Vector3(0.3, HC, 6), WC, true)
	box(Vector3(0, 0.01, -3), Vector3(3.6, 0.02, 5), V["accent"])
	box(Vector3(-4.4, 0.55, -3), Vector3(0.8, 1.1, 4), "#3a2a1c", true)
	box(Vector3(-4.4, 1.12, -3), Vector3(0.9, 0.05, 4.1), "#6b4a2c")
	box(Vector3(-5.2, HC / 2.0, -3), Vector3(0.1, HC, 6), WC)
	var z := -5.0
	while z < -0.8:
		box(Vector3(-6.5, 1.6, z), Vector3(0.5, 1, 0.28), ["#3d6fd8", "#c0392b", "#2c3e50", "#8e44ad", "#16a085", "#111111", "#c49a6c"].pick_random())
		z += 0.35
	omni(Vector3(-3, 3.6, -3), "#ffd9a8", 7.0, 1.0)
	# grande porte capitonnée vers la salle
	box(Vector3(0, 1.5, -6.28), Vector3(6.0, 3.0, 0.06), "#2a0f34", false, "#1a0622", 0.6, 0.9)
	neons.append(box(Vector3(0, 3.05, -6.2), Vector3(6.2, 0.06, 0.04), "#000000", false, NE, 4.0))
	sign3d(Vector3(0, 3.4, -6.18), "VELVET", Color(0.85, 0.6, 1.0), PI, 80)
	_hall_bits()
	# la salle (modèle 3D)
	if has_decor("night_dance_club_lowpoly"):
		var sc = load("res://assets/decor/night_dance_club_lowpoly.glb")
		var inst: Node3D = sc.instantiate()
		inst.position = CLUB_O
		add_child(inst)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m3 := mi as MeshInstance3D
			m3.create_trimesh_collision()
			var room := String(m3.name).begins_with("BaseRoom")
			for ch in m3.get_children():
				if ch is StaticBody3D:
					ch.collision_layer = 1 if room else 2
	else:
		box(CLUB_O + Vector3(-5, -0.05, 0), Vector3(30, 0.1, 32), V["floor"], true)
	# porte de sortie (retour au hall)
	box(Vector3(CLUB_OUT.x, 1.2, CLUB_OUT.y + 0.35), Vector3(2.0, 2.4, 0.08), "#1a0622", false, "#300a40", 0.8)
	sign3d(Vector3(CLUB_OUT.x, 2.6, CLUB_OUT.y + 0.3), "SORTIE", Color(0.2, 1.0, 0.45), PI, 40)
	omni(Vector3(CLUB_OUT.x, 2.4, CLUB_OUT.y - 0.5), "#30ff7a", 4.0, 0.6)
	# bar le long du mur de gauche
	_build_bar(geo["bx"], geo["bar_z0"] - 1.0, geo["bar_z1"] + 1.0)
	# scène DJ au bout du podium
	var dp: Vector3 = geo["dj_pos"]
	box(dp + Vector3(1.0, 0.5, 0), Vector3(0.8, 1.0, 2.6), "#0c0c12", true, "#0a0006", 1.0)
	neons.append(box(dp + Vector3(1.42, 1.02, 0), Vector3(0.04, 0.04, 2.6), "#000000", false, "#33e1ff", 5.0))
	# lumière : lyres au-dessus du podium, couleurs, fumée
	var pr: Array = ZR["piste"]
	pc = Vector2((pr[0] + pr[1]) / 2.0, (pr[2] + pr[3]) / 2.0)
	theme = "led"   # mêmes animations de lumière que le Néon
	for k in 4:
		dj_lights.append(mover(Vector3(pc.x - 4.0 + k * 2.7, HC - 0.25, pc.y - 4.0), [NE, "#33e1ff", "#ffffff", "#ffc04d"][k]))
	dj_lights.append_array([omni(Vector3(pc.x - 3, HC - 0.4, pc.y), NE, 10.0, 2.0, true), omni(Vector3(pc.x + 3, HC - 0.4, pc.y), "#33e1ff", 10.0, 2.0)])
	var fv := FogVolume.new()
	fv.size = Vector3(14.0, HC, 12.0)
	fv.position = Vector3(pc.x, HC / 2.0, pc.y)
	var fm := FogMaterial.new()
	fm.density = 0.05
	fm.albedo = Color(0.9, 0.85, 1.0)
	fm.edge_fade = 0.4
	fv.material = fm
	add_child(fv)
	theme = "model"
	for p in [Vector3(-12, 3.6, -40), Vector3(5, 3.6, -42), Vector3(-5, 3.6, -62), Vector3(6, 3.6, -58), Vector3(-15, 3.6, -52)]:
		omni(p, ["#b04dff", "#ff3d9a", "#ffc04d"].pick_random(), 10.0, 1.2)
	# lumières de salle pour la fermeture
	for p in [Vector3(-10, 3.9, -42), Vector3(2, 3.9, -42), Vector3(-10, 3.9, -58), Vector3(2, 3.9, -58), Vector3(-4, 3.9, -50)]:
		house.append(omni(p, "#fff4e0", 12.0, 0.0))
	_build_atmosphere()
	_build_street_life()

## Hall du Velvet : panneaux, caisse, extincteur, caméra
func _hall_bits() -> void:
	_extinguisher(Vector3(3.9, 0, -4.6), -PI / 2.0)
	var bxs := box(Vector3(0, 2.95, -0.45), Vector3(0.36, 0.13, 0.06), "#f2f2f2", false, "#2aff70", 1.2)
	bxs.rotation.y = PI
	sign3d(Vector3(0, 2.95, -0.485), "SORTIE  →", Color(0.1, 0.9, 0.35), PI, 20)
	sign3d(Vector3(-5.12, 2.6, -3.0), "VESTIAIRE", Color(1.0, 0.85, 0.6), PI / 2.0, 36)
	sign3d(Vector3(4.05, 2.2, -2.0), "Interdit de fumer et de vapoter\nArt. L3512-8 Code de la santé publique", Color(0.95, 0.95, 0.95), -PI / 2.0, 16, false)
	sign3d(Vector3(4.05, 1.7, -2.0), "Vente d'alcool interdite aux mineurs", Color(0.95, 0.95, 0.95), -PI / 2.0, 16, false)
	box(Vector3(2.9, 0.55, -2.2), Vector3(1.6, 1.1, 0.7), "#22202a", true, "", 0.0, 0.5)
	box(Vector3(2.9, 1.12, -2.2), Vector3(1.7, 0.05, 0.8), "#4a4752", false, "", 0.0, 0.25, 0.3)
	box(Vector3(2.6, 1.22, -2.27), Vector3(0.06, 0.05, 0.01), "#000000", false, "#3ee08f", 1.5)
	sign3d(Vector3(2.9, 0.75, -1.84), "ENTRÉE %d €" % int(V["price"]), Color(1, 0.9, 0.6), 0.0, 26)
	_camera_dome(Vector3(0, HC - 0.12, -3.0))
	_camera_dome(Vector3(1.6, 3.15, 0.4))

# ---------- petits détails qui font vrai ----------
func sign3d(p: Vector3, txt: String, col: Color, ry := 0.0, sz := 48, emissive := true) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.position = p
	l.rotation.y = ry
	l.font_size = sz
	l.pixel_size = 0.004
	l.modulate = col
	l.outline_size = 0
	l.shaded = not emissive
	l.double_sided = false
	add_child(l)
	return l

func _extinguisher(p: Vector3, ry: float) -> void:
	var e := cyl(p + Vector3(0, 0.55, 0), 0.08, 0.5, "#c0121e")
	(e.material_override as StandardMaterial3D).roughness = 0.35
	cyl(p + Vector3(0, 0.84, 0), 0.03, 0.08, "#111111")
	var s := box(p + Vector3(0, 1.25, 0), Vector3(0.22, 0.22, 0.02), "#c0121e", false, "#40000a", 0.6)
	s.rotation.y = ry
	sign3d(p + Vector3(0, 1.25, 0) + Vector3(sin(ry), 0, cos(ry)) * 0.012, "EXT.", Color(1, 1, 1), ry, 22, false)

func _camera_dome(p: Vector3) -> void:
	sph(p, 0.11, "#0d0d0f", "", 0.0, 0.1, 0.6)
	leds.append(sph(p + Vector3(0, -0.06, 0.07), 0.012, "#000000", "#ff2020", 4.0))

func _build_details() -> void:
	var tzz: float = geo["tz"]
	var gx0: float = geo["gx0"]
	var gx1: float = geo["gx1"]
	var fx: float = geo["fx"]
	var dz: float = geo["dz"]
	var ez: float = Zm(-17.0)
	# extincteurs (obligatoires dans un ERP) et blocs d'éclairage de sécurité
	_extinguisher(Vector3(W - 0.15, 0, Zm(-11.0)), -PI / 2.0)
	_extinguisher(Vector3(W - 0.15, 0, Zm(-25.0)), -PI / 2.0)
	_extinguisher(Vector3(3.9, 0, -4.6), -PI / 2.0)
	_extinguisher(Vector3((gx1 + geo["tx"]) / 2.0, 0, tzz + 0.15), 0.0)
	for p in [[Vector3(0, 2.75, -6.35), PI], [Vector3(0, 2.95, -0.45), PI], [Vector3(W - 0.2, 2.25, ez), -PI / 2.0]]:
		var bx := box(p[0], Vector3(0.36, 0.13, 0.06), "#f2f2f2", false, "#2aff70", 1.2)
		bx.rotation.y = p[1]
		sign3d(p[0] + Vector3(sin(p[1]), 0, cos(p[1])) * 0.035, "SORTIE  →", Color(0.1, 0.9, 0.35), p[1], 20)
	# panneaux
	sign3d(Vector3((gx0 + gx1) / 2.0, 3.0, tzz + 0.13), "TOILETTES", Color(0.85, 0.95, 1.0), 0.0, 40)
	sign3d(Vector3(fx - 0.12, 3.0, dz), "FUMOIR", Color(0.9, 0.9, 0.9), -PI / 2.0, 40)
	sign3d(Vector3(fx - 0.12, 2.6, dz), "Porte maintenue fermée", Color(0.7, 0.7, 0.7), -PI / 2.0, 18, false)
	sign3d(Vector3(-5.12, 2.6, -3.0), "VESTIAIRE", Color(1.0, 0.85, 0.6), PI / 2.0, 36)
	sign3d(Vector3(4.05, 2.2, -2.0), "Interdit de fumer et de vapoter\nArt. L3512-8 Code de la santé publique", Color(0.95, 0.95, 0.95), -PI / 2.0, 16, false)
	sign3d(Vector3(4.05, 1.7, -2.0), "Vente d'alcool interdite aux mineurs", Color(0.95, 0.95, 0.95), -PI / 2.0, 16, false)
	if ZR.has("vip"):
		var vr: Array = ZR["vip"]
		sign3d(Vector3(vr[0] - 1.0, 1.4, (vr[2] + vr[3]) / 2.0), "CARRÉ VIP · RÉSERVÉ", Color(1.0, 0.85, 0.5), -PI / 2.0, 30)
	# caisse à l'entrée avec terminal de paiement
	box(Vector3(2.9, 0.55, -2.2), Vector3(1.6, 1.1, 0.7), "#22202a", true, "", 0.0, 0.5)
	box(Vector3(2.9, 1.12, -2.2), Vector3(1.7, 0.05, 0.8), "#4a4752", false, "", 0.0, 0.25, 0.3)
	box(Vector3(2.6, 1.2, -2.3), Vector3(0.09, 0.14, 0.05), "#111111")
	box(Vector3(2.6, 1.22, -2.27), Vector3(0.06, 0.05, 0.01), "#000000", false, "#3ee08f", 1.5)
	sign3d(Vector3(2.9, 0.75, -1.84), "ENTRÉE %s" % ("LIBRE" if int(V["price"]) == 0 else "%d €" % int(V["price"])), Color(1, 0.9, 0.6), 0.0, 26)
	# caméras de vidéoprotection
	_camera_dome(Vector3(0, HC - 0.12, -3.0))
	_camera_dome(Vector3(X(-9.0), HC - 0.12, Zm(-15.0)))
	_camera_dome(Vector3(pc.x + 5.0, HC - 0.12, pc.y + 4.0))
	_camera_dome(Vector3(1.6, 3.15, 0.4))
	# enceintes murales
	for z in [Zm(-12.0), Zm(-20.0)]:
		for s in [-1, 1]:
			var sp := box(Vector3(s * (W - 0.25), HC - 0.8, z), Vector3(0.35, 0.55, 0.35), "#0b0b0d")
			sp.rotation.y = s * 0.3
	# lavabos et miroirs aux toilettes
	var sx0: float = -W + 0.8
	while sx0 < geo["tx"] - 0.6:
		box(Vector3(sx0, 0.85, tzz - 0.35), Vector3(0.55, 0.12, 0.4), "#e8eef2", false, "", 0.0, 0.2)
		cyl(Vector3(sx0, 1.0, tzz - 0.2), 0.015, 0.18, "#c8c8cc")
		box(Vector3(sx0, 1.6, tzz - 0.13), Vector3(0.6, 0.8, 0.02), "#9aa6b4", false, "#1a2028", 0.4, 0.02, 0.9)
		sx0 += 1.1
	# affiches de soirée dans le hall
	var events := ["SAMEDI · DJ SET", "JEUDI ÉTUDIANT", "SOIRÉE ANNÉES 2000", "LADIES NIGHT", "AFTER WORK 18 H"]
	for k in 3:
		var pz: float = -1.2 - k * 1.5
		var col := Color.from_hsv(randf(), 0.7, 0.9)
		box(Vector3(-5.13, 1.6, pz), Vector3(0.02, 0.85, 0.6), "#111111", false, col.to_html(false), 0.8)
		sign3d(Vector3(-5.11, 1.6, pz), events[(k + vk.length()) % events.size()].replace(" · ", "\n"), Color(1, 1, 1), PI / 2.0, 18)
	# lumières de salle, éteintes pendant la soirée (rallumées à la fermeture)
	var hx := -W + 4.0
	while hx < W:
		var hz := -9.0
		while hz > ZB + 2.0:
			var hl := omni(Vector3(hx, HC - 0.3, hz), "#fff4e0", 9.0, 0.0)
			house.append(hl)
			hz -= 8.0
		hx += 8.0
	# machine à fumée sur la scène (bouffées régulières)
	if theme == "led" or theme == "indus":
		smoke = GPUParticles3D.new()
		smoke.amount = 60
		smoke.lifetime = 6.0
		smoke.emitting = false
		smoke.one_shot = false
		smoke.position = Vector3(0, geo["djh"] + 0.3, geo["djz"] + 1.8)
		smoke.visibility_aabb = AABB(Vector3(-10, -2, -2), Vector3(20, 8, 16))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0.2, 1)
		pm.spread = 35.0
		pm.initial_velocity_min = 1.2
		pm.initial_velocity_max = 2.4
		pm.gravity = Vector3(0, 0.05, 0)
		pm.damping_min = 0.4; pm.damping_max = 0.8
		pm.scale_min = 1.5; pm.scale_max = 3.0
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.3)); sc.add_point(Vector2(1, 1.0))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		var ga := Gradient.new()
		ga.set_color(0, Color(1, 1, 1, 0.22)); ga.set_color(1, Color(1, 1, 1, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = ga
		pm.color_ramp = gt
		smoke.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		var sm := StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var rad := GradientTexture2D.new()
		rad.fill = GradientTexture2D.FILL_RADIAL
		rad.fill_from = Vector2(0.5, 0.5)
		rad.fill_to = Vector2(1.0, 0.5)
		var rg := Gradient.new()
		rg.set_color(0, Color(0.85, 0.85, 0.95, 1.0)); rg.set_color(1, Color(0.85, 0.85, 0.95, 0.0))
		rad.gradient = rg
		sm.albedo_texture = rad
		q.material = sm
		smoke.draw_pass_1 = q
		add_child(smoke)
	# structure métallique (truss) qui porte les lyres
	if theme == "led" or theme == "indus":
		var tw: float = 13.0 * sx
		for zz in [pc.y - 5.0 * sz, pc.y + 5.0 * sz]:
			box(Vector3(pc.x, HC - 0.12, zz), Vector3(tw, 0.12, 0.12), "#8a8f96", false, "", 0.0, 0.3, 0.9)
			box(Vector3(pc.x, HC - 0.36, zz), Vector3(tw, 0.04, 0.04), "#8a8f96", false, "", 0.0, 0.3, 0.9)

# ---------- la rue : voitures, feu tricolore, poubelles, commerces ----------
func _build_street_life() -> void:
	# commerces en face : kebab et pharmacie (croix verte qui clignote)
	sign3d(Vector3(-11.0, 3.2, 23.4), "KEBAB · OUVERT", Color(1.0, 0.55, 0.15), PI, 90)
	omni(Vector3(-11.0, 3.0, 22.4), "#ff9a3c", 7.0, 1.2)
	pharma = box(Vector3(9.0, 4.2, 23.35), Vector3(0.9, 0.9, 0.08), "#000000", false, "#20ff60", 4.0)
	box(Vector3(9.0, 4.2, 23.3), Vector3(0.3, 0.9, 0.08), "#000000", false, "#20ff60", 4.0)
	sign3d(Vector3(16.0, 3.0, 23.4), "TABAC", Color(1, 0.3, 0.3), PI, 70)
	# poubelles, affiches collées, plaque d'égout qui fume
	for bxp in [-14.5, -13.6]:
		box(Vector3(bxp, 0.55, 5.4), Vector3(0.7, 1.0, 0.6), "#1d5a2a", true, "", 0.0, 0.6)
		box(Vector3(bxp, 1.07, 5.4), Vector3(0.74, 0.06, 0.64), "#174a22")
	for k in 4:
		box(Vector3(-6.0 - k * 0.75, 1.5 + (k % 2) * 0.2, 0.02), Vector3(0.6, 0.85, 0.01), Color.from_hsv(randf(), 0.5, 0.8).to_html(false), false, "", 0.0, 0.9)
	var st := GPUParticles3D.new()
	st.amount = 24
	st.lifetime = 3.0
	st.position = Vector3(5.0, 0.05, 12.5)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.4; pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.2, 0)
	pm.scale_min = 0.8; pm.scale_max = 1.6
	var ga := Gradient.new()
	ga.set_color(0, Color(1, 1, 1, 0.18)); ga.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ga
	pm.color_ramp = gt
	st.process_material = pm
	var q := QuadMesh.new()
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rad := GradientTexture2D.new()
	rad.fill = GradientTexture2D.FILL_RADIAL
	rad.fill_from = Vector2(0.5, 0.5); rad.fill_to = Vector2(1.0, 0.5)
	var rg := Gradient.new()
	rg.set_color(0, Color(0.9, 0.9, 0.95, 1.0)); rg.set_color(1, Color(0.9, 0.9, 0.95, 0.0))
	rad.gradient = rg
	sm.albedo_texture = rad
	q.material = sm
	st.draw_pass_1 = q
	add_child(st)
	cyl(Vector3(5.0, 0.005, 12.5), 0.35, 0.01, "#222226", false, "", 0.0)
	# feu tricolore
	cyl(Vector3(-17.5, 1.6, 6.3), 0.06, 3.2, "#2a2a30")
	box(Vector3(-17.5, 3.0, 6.45), Vector3(0.3, 0.8, 0.2), "#111114")
	for k in 3:
		tlight.append(sph(Vector3(-17.5, 3.25 - k * 0.25, 6.56), 0.08, "#151515", ["#ff2020", "#ffaa00", "#20ff60"][k], 0.001))
	# voitures qui passent, phares allumés
	for k in 2:
		var car := Node3D.new()
		var col: String = ["#d9d9de", "#1d1d22", "#7a1d1d", "#1d3d7b"][randi() % 4]
		var b1 := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(4.2, 0.7, 1.8)
		b1.mesh = bm; b1.material_override = _mat(Color(col), Color.BLACK, 0.0, 0.25, 0.6); b1.position.y = 0.65
		car.add_child(b1)
		var b2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new(); bm2.size = Vector3(2.2, 0.55, 1.6)
		b2.mesh = bm2; b2.material_override = _mat(Color("#0d1622"), Color.BLACK, 0.0, 0.05, 0.3); b2.position = Vector3(-0.2, 1.25, 0)
		car.add_child(b2)
		for s in [-0.65, 0.65]:
			var hl := MeshInstance3D.new()
			var hs := SphereMesh.new(); hs.radius = 0.09; hs.height = 0.18
			hl.mesh = hs; hl.material_override = _mat(Color.BLACK, Color("#fff6c8"), 5.0); hl.position = Vector3(2.1, 0.75, s)
			car.add_child(hl)
			var tl := MeshInstance3D.new()
			tl.mesh = hs; tl.material_override = _mat(Color.BLACK, Color("#ff2020"), 3.0); tl.position = Vector3(-2.1, 0.75, s)
			car.add_child(tl)
		var sp := SpotLight3D.new()
		sp.position = Vector3(2.2, 0.75, 0)
		sp.rotation.y = -PI / 2.0
		sp.light_color = Color("#fff3d0")
		sp.light_energy = 5.0
		sp.spot_range = 16.0
		sp.spot_angle = 30.0
		sp.light_volumetric_fog_energy = 1.5
		car.add_child(sp)
		var dirn: float = 1.0 if k == 0 else -1.0
		car.rotation.y = 0.0 if dirn > 0 else PI
		car.position = Vector3(-60.0 + k * 70.0, 0, 11.0 if dirn > 0 else 13.2)
		car.set_meta("dir", dirn)
		car.set_meta("v", randf_range(7.0, 11.0))
		add_child(car)
		cars.append(car)

## Fin de soirée : on rallume la salle et on coupe les effets
func set_closing(k: float) -> void:
	closing = clampf(k, 0.0, 1.0)
	for h in house: h.light_energy = closing * 1.6
	for l in dj_lights: l.visible = closing < 0.6
	for l in lasers: l.visible = closing < 0.3 and l.visible

# ---------- reflets (sols brillants, flaques) et pluie ----------
func _build_atmosphere() -> void:
	var pin := ReflectionProbe.new()
	pin.size = Vector3(2.0 * W, HC, -ZB)
	pin.position = Vector3(0, HC / 2.0, ZB / 2.0)
	pin.box_projection = true
	pin.interior = true
	pin.update_mode = ReflectionProbe.UPDATE_ONCE
	pin.intensity = 0.6
	add_child(pin)
	var pout := ReflectionProbe.new()
	pout.size = Vector3(60, 14, 24)
	pout.position = Vector3(0, 6, 10)
	pout.box_projection = true
	pout.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(pout)
	# pluie fine une nuit sur deux
	if randf() < 0.5:
		rain = GPUParticles3D.new()
		rain.amount = 4000
		rain.lifetime = 0.9
		rain.position = Vector3(0, 12, 10)
		rain.visibility_aabb = AABB(Vector3(-40, -14, -12), Vector3(80, 16, 24))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(34, 0.2, 9)
		pm.direction = Vector3(0.08, -1, 0)
		pm.spread = 2.0
		pm.initial_velocity_min = 13.0
		pm.initial_velocity_max = 16.0
		pm.gravity = Vector3(0, -9.8, 0)
		rain.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.012, 0.45)
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color = Color(0.75, 0.8, 0.95, 0.35)
		rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		rm.billboard_keep_scale = true
		qm.material = rm
		rain.draw_pass_1 = qm
		add_child(rain)

# ---------- sol de danse et scène, différents selon l'établissement ----------
func _build_floor_and_stage() -> void:
	var NE: String = V["neon"]
	var pr: Array = ZR["piste"]
	pc = Vector2((pr[0] + pr[1]) / 2.0, (pr[2] + pr[3]) / 2.0)
	var ni: int = max(4, int(round(8 * sx)))
	var nj: int = max(4, int(round(8 * sz)))
	var djz: float = Zm(-27.5)
	match theme:
		"pub":
			# parquet en planches, petit coin danse éclairé par deux spots chauds
			var z0 := -6.3
			var k := 0
			while z0 > ZB:
				surface(box(Vector3(0, 0.005, z0 - 0.3), Vector3(2 * W - 0.1, 0.01, 0.58), ["#5a3a22", "#4f321c", "#62402a"][k % 3], false, "", 0.0, 0.55), "wood", 0.8, 0.45)
				z0 -= 0.6
				k += 1
			for s in [-1, 1]:
				var sp := SpotLight3D.new()
				sp.position = Vector3(pc.x + s * 1.5, HC - 0.2, pc.y)
				sp.rotation = Vector3(-PI / 2.0, 0, 0)
				sp.light_color = Color("#ffb46a")
				sp.light_energy = 4.0
				sp.spot_range = HC + 1.0
				sp.spot_angle = 35.0
				add_child(sp)
				dj_lights.append(sp)
			# juke-box à la place de la cabine DJ
			box(Vector3(0, 0.8, ZB + 0.5), Vector3(1.1, 1.6, 0.7), "#5a1a10", true, "", 0.0, 0.3, 0.3)
			neons.append(box(Vector3(0, 1.1, ZB + 0.86), Vector3(0.9, 0.6, 0.02), "#000000", false, "#ff9a3c", 3.0))
			neons.append(box(Vector3(0, 1.55, ZB + 0.86), Vector3(1.0, 0.08, 0.02), "#000000", false, "#ff3d9a", 4.0))
			omni(Vector3(0, 1.4, ZB + 1.5), "#ff9a3c", 4.0, 1.0)
		"chic":
			# damier de marbre noir et blanc, bordure dorée, lumière chaude qui « respire »
			for i in ni:
				for j in nj:
					var dark: bool = (i + j) % 2 == 0
					var tl := box(Vector3(pc.x - (ni - 1) * 0.75 + i * 1.5, 0.04, pc.y - (nj - 1) * 0.75 + j * 1.5), Vector3(1.48, 0.08, 1.48), "#141210" if dark else "#efe9dc", false, "#ffcf7a", 0.0, 0.08, 0.1)
					surface(tl, "marble", 0.3, 0.06)
					tl.set_meta("ij", Vector2i(i, j))
					tl.set_meta("mode", "warm")
					tiles.append(tl)
			var bw: float = ni * 1.5 + 0.3
			var bd: float = nj * 1.5 + 0.3
			for s in [-1, 1]:
				box(Vector3(pc.x + s * bw / 2.0, 0.05, pc.y), Vector3(0.15, 0.1, bd), "#c9a227", false, "#5a4000", 1.0, 0.2, 0.9)
				box(Vector3(pc.x, 0.05, pc.y + s * bd / 2.0), Vector3(bw, 0.1, 0.15), "#c9a227", false, "#5a4000", 1.0, 0.2, 0.9)
			# scène avec rideau de velours rouge
			box(Vector3(0, 0.3, djz), Vector3(8 * min(sx, 1.2), 0.6, 3.5), "#2a0a10", true)
			box(Vector3(0, 1.1, djz + 1.1), Vector3(3.4, 1, 0.8), "#1a1008", true, "", 0.0, 0.3, 0.4)
			box(Vector3(0, 1.62, djz + 1.5), Vector3(3.4, 0.05, 0.05), "#c9a227", false, "#ffcf7a", 2.0, 0.2, 0.9)
			var cx := -W + 0.4
			while cx < W:
				box(Vector3(cx, HC / 2.0, ZB + 0.25), Vector3(0.38, HC, 0.25 + 0.1 * float(int(cx * 3.0) % 2)), "#7a0f1f", false, "#1a0004", 0.6, 0.9)
				cx += 0.4
			box(Vector3(0, HC - 0.3, ZB + 0.45), Vector3(2 * W, 0.6, 0.2), "#c9a227", false, "#3a2a00", 1.0, 0.3, 0.9)
			for spx in [-4.5 * sx, 4.5 * sx]:
				cyl(Vector3(spx, 1.3, djz - 0.8), 0.35, 2.6, "#d8c48a", true)
			# grands lustres au-dessus de la piste
			for k in 3:
				var lz: float = pc.y - 4.0 + k * 4.0
				if has_decor("ufo_modern_chandelier"):
					prop("ufo_modern_chandelier", Vector3(pc.x, HC - 0.55, lz), 0.0, 1.8, false, false)
				else:
					sph(Vector3(pc.x, HC - 0.6, lz), 0.5, "#ffffff", "#ffe2a0", 3.0)
				dj_lights.append(omni(Vector3(pc.x, HC - 0.9, lz), "#ffd9a0", 9.0, 2.2, k == 1))
		"indus":
			# béton, piste en dalles grises qui flashent au rythme, mur LED et lasers
			for i in ni:
				for j in nj:
					var tl := box(Vector3(pc.x - (ni - 1) * 0.75 + i * 1.5, 0.04, pc.y - (nj - 1) * 0.75 + j * 1.5), Vector3(1.42, 0.08, 1.42), "#2a2c30", false, "#ffffff", 0.0, 0.4, 0.5)
					tl.set_meta("ij", Vector2i(i, j))
					tl.set_meta("mode", "strobe")
					tiles.append(tl)
			box(Vector3(0, 0.6, djz), Vector3(8 * min(sx, 1.2), 1.2, 3.5), "#1a1c20", true, "", 0.0, 0.4, 0.7)
			box(Vector3(0, 1.7, djz + 1.1), Vector3(3.4, 1, 0.8), "#0c0c12", true)
			neons.append(box(Vector3(0, 2.22, djz + 1.5), Vector3(3.4, 0.04, 0.04), "#000000", false, "#30ff7a", 5.0))
			# mur LED derrière le DJ
			var cols: int = int(2.0 * W / 1.2)
			var rows: int = int((HC - 1.4) / 1.0)
			for i in cols:
				for j in rows:
					var p := box(Vector3(-W + 0.6 + i * 1.2, 1.4 + j * 1.0 + 0.5, ZB + 0.2), Vector3(1.15, 0.95, 0.1), "#050505", false, "#00ff88", 1.0)
					p.set_meta("ij", Vector2i(i, j))
					ledwall.append(p)
			# lasers
			for k in 6:
				var lz := Node3D.new()
				lz.position = Vector3(-6.0 + k * 2.4, HC - 0.3, djz + 0.5)
				add_child(lz)
				var beam := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.025, 0.025, 26.0)
				beam.mesh = bm
				var mm := StandardMaterial3D.new()
				mm.albedo_color = Color.BLACK
				mm.emission_enabled = true
				mm.emission = Color("#30ff7a") if k % 2 == 0 else Color("#ff2a4a")
				mm.emission_energy_multiplier = 6.0
				mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				beam.material_override = mm
				beam.position = Vector3(0, 0, 13.0)
				lz.add_child(beam)
				lasers.append(lz)
		_:
			# le Néon : piste LED arc-en-ciel
			for i in ni:
				for j in nj:
					var tl := box(Vector3(pc.x - (ni - 1) * 0.75 + i * 1.5, 0.04, pc.y - (nj - 1) * 0.75 + j * 1.5), Vector3(1.44, 0.08, 1.44), "#0a0a10", false, "#ff00ff", 1.5, 0.2)
					tl.set_meta("ij", Vector2i(i, j))
					tl.set_meta("mode", "led")
					tiles.append(tl)
			box(Vector3(0, 0.3, djz), Vector3(8 * min(sx, 1.2), 0.6, 3.5), "#15121c", true)
			box(Vector3(0, 1.1, djz + 1.1), Vector3(3.4, 1, 0.8), "#0c0c12", true, "#0a0006", 1.0)
			neons.append(box(Vector3(0, 1.62, djz + 1.5), Vector3(3.4, 0.04, 0.04), "#000000", false, "#33e1ff", 5.0))
	# enceintes / équaliseurs
	if theme != "pub":
		var spk := [-5.0 * sx, 5.0 * sx]
		if theme == "indus": spk = [-5.0 * sx, -9.0 * sx, 5.0 * sx, 9.0 * sx]
		for spx in spk:
			var hh: float = 3.6 if theme == "indus" else 2.8
			if theme != "chic" and has_decor("equalizer_with_3d_indicators"):
				prop("equalizer_with_3d_indicators", Vector3(spx, 0, djz - 0.6), 0.0, hh, true)
			elif theme != "chic":
				box(Vector3(spx, hh / 2.0, djz - 1.0), Vector3(1.3, hh, 1.1), "#0b0b0f", true)
	# lumières de piste
	if theme == "led" or theme == "indus":
		dj_lights.append_array([omni(Vector3(-4, HC - 0.45, pc.y - 4), NE, 11.0, 2.0, true), omni(Vector3(4, HC - 0.45, pc.y), "#33e1ff", 11.0, 2.0), omni(Vector3(0, HC - 0.45, pc.y + 4), "#ffc04d", 10.0, 1.6)])
		# lyres au plafond, faisceaux dans la fumée
		var nm: int = 6 if theme == "indus" else 4
		for k in nm:
			var mx: float = pc.x - 6.0 * sx + k * (12.0 * sx / maxf(1.0, nm - 1))
			dj_lights.append(mover(Vector3(mx, HC - 0.25, pc.y - 5.0 * sz), [NE, "#33e1ff", "#ffffff", "#b04dff", "#30ff7a", "#ffc04d"][k % 6]))
		# fumée sur la piste
		var fv := FogVolume.new()
		fv.size = Vector3(14.0 * sx, HC, 14.0 * sz)
		fv.position = Vector3(pc.x, HC / 2.0, pc.y)
		var fm := FogMaterial.new()
		fm.density = 0.05 if theme == "led" else 0.08
		fm.albedo = Color(0.9, 0.9, 1.0)
		fm.edge_fade = 0.4
		fv.material = fm
		add_child(fv)
	if theme == "indus":
		dj_lights.append(omni(Vector3(-8, HC - 0.45, pc.y), "#b04dff", 13.0, 3.0))
		dj_lights.append(omni(Vector3(8, HC - 0.45, pc.y - 6), "#30ff7a", 13.0, 2.6))
	if theme == "led":
		ball = sph(Vector3(pc.x, HC - 0.65, pc.y), 0.35, "#cccccc", "#404050", 0.5, 0.05, 1.0)

# ---------- le bar : comptoir, tireuses, étagères rétroéclairées, tabourets, suspensions ----------
func _build_bar(bx: float, bz0: float, bz1: float) -> void:
	var bl: float = bz1 - bz0
	var bzc: float = (bz0 + bz1) / 2.0
	var body := "#3b2516"
	var top := "#6b4226"
	var top_r := 0.25
	var top_m := 0.0
	var stool := "#7a1d1d"
	var shelf_glow := "#ffb060"
	match theme:
		"pub":
			body = "#4a2a14"; top = "#8a5a2e"; stool = "#2a1a10"; shelf_glow = "#ffb060"
		"led":
			body = "#0c0a12"; top = "#141018"; top_r = 0.05; stool = "#ff3d9a"; shelf_glow = "#ff3d9a"
		"chic":
			body = "#24160c"; top = "#efe9dc"; top_r = 0.08; stool = "#7a0f1f"; shelf_glow = "#ffd27a"
		"indus":
			body = "#2e3136"; top = "#8a8f96"; top_r = 0.3; top_m = 0.8; stool = "#3a3d42"; shelf_glow = "#33e1ff"
	# comptoir
	box(Vector3(bx, 0.55, bzc), Vector3(0.9, 1.1, bl), body, true, "", 0.0, 0.5)
	if theme == "pub" or theme == "chic":
		var zp := bz0 + 0.6
		while zp < bz1 - 0.4:
			box(Vector3(bx + 0.46, 0.55, zp), Vector3(0.02, 0.75, 0.9), "#2a160a" if theme == "pub" else "#c9a227", false, "", 0.0, 0.4, 0.5 if theme == "chic" else 0.0)
			zp += 1.2
	box(Vector3(bx + 0.05, 1.13, bzc), Vector3(1.15, 0.07, bl + 0.2), top, false, "", 0.0, top_r, top_m)
	# barre repose-pieds en laiton
	var rail := cyl(Vector3(bx + 0.62, 0.22, bzc), 0.03, bl, "#c9a227")
	rail.rotation.x = PI / 2.0
	# bandeau lumineux sous le plateau
	neons.append(box(Vector3(bx + 0.5, 1.02, bzc), Vector3(0.02, 0.03, bl - 0.2), "#000000", false, shelf_glow, 3.0))
	# tireuses à bière et verres
	var zt := bz0 + 1.0
	while zt < bz1 - 0.8:
		cyl(Vector3(bx - 0.15, 1.3, zt), 0.03, 0.32, "#d8d8dc", false, "", 0.0)
		for k in 3:
			cyl(Vector3(bx - 0.15, 1.5, zt - 0.12 + k * 0.12), 0.018, 0.16, ["#1a1a1a", "#c0392b", "#f1c40f"][k])
		zt += 3.0
	zt = bz0 + 0.7
	while zt < bz1 - 0.5:
		if randf() < 0.55:
			var g := cyl(Vector3(bx + randf_range(-0.1, 0.3), 1.24, zt), 0.04, 0.15, "#e8c66a" if randf() < 0.6 else "#f2f2f2", false, "#3a2a00", 0.4)
			g.set_meta("glass", true)
		zt += 0.45
	# meuble arrière, miroir et étagères rétroéclairées
	box(Vector3(-W + 0.45, 0.5, bzc), Vector3(0.6, 1.0, bl - 0.6), body, true)
	box(Vector3(-W + 0.18, 2.0, bzc), Vector3(0.04, 1.8, bl - 1.0), "#2a3038", false, "#1a2028", 0.6, 0.02, 0.9)
	for sy in [1.35, 1.85, 2.35]:
		box(Vector3(-W + 0.4, sy, bzc), Vector3(0.36, 0.03, bl - 1.0), "#d8d8dc", false, shelf_glow, 1.2, 0.2, 0.3)
		var zb := bz0 + 0.8
		while zb < bz1 - 0.8:
			if randf() < 0.85:
				var bc: String = ["#2e7d32", "#6d3b12", "#a0522d", "#d0d0d0", "#1b3a5c", "#7a1d1d", "#c9a227"].pick_random()
				var hh := randf_range(0.22, 0.34)
				cyl(Vector3(-W + 0.4, sy + 0.02 + hh / 2.0, zb), 0.045, hh, bc, false, bc, 0.5)
			zb += 0.16
	omni(Vector3(-W + 1.0, 2.0, bzc), shelf_glow, maxf(6.0, bl * 0.6), 0.8)
	# tabourets
	var zs := bz0 + 0.4
	while zs < bz1:
		cyl(Vector3(bx + 0.85, 0.38, zs), 0.04, 0.76, "#c9a227" if theme == "chic" else "#555555")
		cyl(Vector3(bx + 0.85, 0.79, zs), 0.21, 0.08, stool)
		zs += 1.2
	# suspensions au-dessus du comptoir
	var zl := bz0 + 1.5
	while zl < bz1:
		match theme:
			"chic":
				if has_decor("ufo_modern_chandelier"):
					prop("ufo_modern_chandelier", Vector3(bx - 0.1, HC - 0.32, zl), 0.0, 0.8, false, false)
			"indus":
				cyl(Vector3(bx - 0.1, HC - 0.6, zl), 0.008, 1.2, "#111111")
				cyl(Vector3(bx - 0.1, HC - 1.25, zl), 0.16, 0.22, "#2e3136", false, "", 0.0)
				sph(Vector3(bx - 0.1, HC - 1.38, zl), 0.07, "#000000", "#ffd27a", 4.0)
			_:
				cyl(Vector3(bx - 0.1, HC - 0.5, zl), 0.008, 1.0, "#111111")
				cyl(Vector3(bx - 0.1, HC - 1.05, zl), 0.18, 0.16, "#1f3a2a" if theme == "pub" else "#111111", false, "", 0.0)
				sph(Vector3(bx - 0.1, HC - 1.15, zl), 0.07, "#000000", "#ffcf8a", 4.0)
		omni(Vector3(bx - 0.1, HC - 1.4, zl), "#ffcf8a" if theme != "led" else "#ff9ad0", 4.5, 1.4)
		zl += 2.4 if theme == "pub" else 3.0

# ---------- décor propre à chaque établissement ----------
func _build_theme_decor() -> void:
	match theme:
		"pub":
			# lambris bois, fléchettes, télé, enseignes de bière, ardoise
			for s in [-1, 1]:
				box(Vector3(s * (W - 0.06), 0.6, ZB / 2.0 - 3.0), Vector3(0.04, 1.2, -ZB - 6.5), "#3a2212", false, "", 0.0, 0.6)
			box(Vector3(0, 0.6, ZB + 0.06), Vector3(2 * W, 1.2, 0.04), "#3a2212")
			var df := cyl(Vector3(W - 0.08, 1.7, Zm(-20.0)), 0.23, 0.04, "#1a1a1a")
			df.rotation.z = PI / 2.0
			var df2 := cyl(Vector3(W - 0.1, 1.7, Zm(-20.0)), 0.16, 0.04, "#c0392b")
			df2.rotation.z = PI / 2.0
			neons.append(box(Vector3(W - 0.08, 2.4, Zm(-14.0)), Vector3(0.05, 0.75, 1.3), "#000000", false, "#3a7bd5", 1.6))
			neons.append(box(Vector3(-W + 0.1, 2.9, Zm(-14.0)), Vector3(0.04, 0.35, 1.4), "#000000", false, "#ffb000", 3.0))
			neons.append(box(Vector3(-W + 0.1, 2.9, Zm(-18.0)), Vector3(0.04, 0.35, 1.4), "#000000", false, "#e74c3c", 3.0))
			box(Vector3(W - 0.08, 1.5, Zm(-11.0)), Vector3(0.04, 1.0, 0.8), "#1d2a1d")
			# tables rondes avec chaises
			for tp in [[X(4.0), Zm(-12.0)], [X(5.0), Zm(-24.0)], [X(-4.0), Zm(-25.0)], [X(5.0), Zm(-9.0)]]:
				cyl(Vector3(tp[0], 0.74, tp[1]), 0.45, 0.04, "#6b4226", true)
				cyl(Vector3(tp[0], 0.37, tp[1]), 0.05, 0.74, "#2a1a10")
				for a in 4:
					var ang: float = a * PI / 2.0
					box(Vector3(tp[0] + cos(ang) * 0.7, 0.45, tp[1] + sin(ang) * 0.7), Vector3(0.4, 0.05, 0.4), "#4a2a14")
		"chic":
			# colonnes dorées et appliques le long des murs
			var zz := -8.0
			while zz > ZB + 2.0:
				for s in [-1, 1]:
					cyl(Vector3(s * (W - 0.35), HC / 2.0, zz), 0.22, HC, "#e8dcc0", true)
					sph(Vector3(s * (W - 0.6), 2.4, zz + 1.2), 0.1, "#000000", "#ffe2a0", 3.0)
				zz -= 4.0
			omni(Vector3(0, HC - 0.5, -10.0), "#ffe2c0", 14.0, 1.2)
		"indus":
			# poutres métalliques, piliers et caisses de transport
			var zz := -9.0
			while zz > ZB + 2.0:
				for s in [-1, 1]:
					box(Vector3(s * W * 0.45, HC / 2.0, zz), Vector3(0.3, HC, 0.3), "#3a3f48", true, "", 0.0, 0.4, 0.8)
				box(Vector3(0, HC - 0.2, zz), Vector3(2 * W, 0.3, 0.25), "#3a3f48", false, "", 0.0, 0.4, 0.8)
				zz -= 6.0
			for cp in [[-W + 1.2, -7.6], [W * 0.5, ZB + 1.5], [-W * 0.5, ZB + 1.5]]:
				box(Vector3(cp[0], 0.45, cp[1]), Vector3(1.2, 0.9, 1.2), "#6b5a3a", true)
			for k in 4:
				box(Vector3(-W + 0.06, 3.2, Zm(-10.0 - k * 5.0)), Vector3(0.04, 1.4, 3.0), "#000000", false, ["#ff3d9a", "#33e1ff", "#30ff7a", "#ffc04d"][k], 0.8)

func animate(delta: float) -> void:
	t += delta
	var beat := fmod(t * 2.0, 1.0)   # 120 BPM
	for tl in tiles:
		var ij: Vector2i = tl.get_meta("ij")
		var m: StandardMaterial3D = tl.material_override
		match String(tl.get_meta("mode", "led")):
			"warm":
				m.emission_energy_multiplier = 0.15 + 0.15 * sin(t * 0.8 + ij.x * 0.5 + ij.y * 0.3)
			"strobe":
				var on: bool = (ij.x + ij.y + int(t * 2.0)) % 4 == 0
				m.emission = Color("#30ff7a") if int(t * 0.25) % 2 == 0 else Color("#ffffff")
				m.emission_energy_multiplier = (3.0 * (1.0 - beat)) if on else 0.0
			_:
				var h := fmod((ij.x * 37 + ij.y * 53) / 360.0 + t * 0.25, 1.0)
				var a := 0.35 + 0.35 * maxf(0.0, sin(t * 2.5 + ij.x * 0.7 + ij.y * 0.5))
				m.emission = Color.from_hsv(h, 0.9, 1.0)
				m.emission_energy_multiplier = a * 4.0
	if closing > 0.0:
		for tl in tiles:
			var mt: StandardMaterial3D = tl.material_override
			mt.emission_energy_multiplier *= 1.0 - closing * 0.85
	for p in ledwall:
		var ij2: Vector2i = p.get_meta("ij")
		var m3: StandardMaterial3D = p.material_override
		var wv := sin(ij2.x * 0.5 - t * 3.0) * 0.5 + 0.5
		m3.emission = Color.from_hsv(fmod(0.33 + ij2.y * 0.05 + t * 0.03, 1.0), 1.0, 1.0)
		m3.emission_energy_multiplier = 2.5 * wv * (0.4 + 0.6 * (1.0 - beat))
	for k in lasers.size():
		var lz: Node3D = lasers[k]
		lz.rotation = Vector3(0.25 + 0.15 * sin(t * 0.7 + k), sin(t * 0.9 + k * 1.3) * 0.7, 0)
		lz.visible = int(t * 0.5) % 3 != 0 and closing < 0.3
	var fl := sin(t * 23.0) > 0.97 or fmod(t * 1000.0, 4200.0) < 90.0
	for n in neons:
		var m2: StandardMaterial3D = n.material_override
		if not n.has_meta("e0"): n.set_meta("e0", m2.emission_energy_multiplier)
		m2.emission_energy_multiplier = n.get_meta("e0") * (0.2 if fl else 1.0)
	if neon_light: neon_light.light_energy = 0.5 if fl else 2.0
	for k in dj_lights.size():
		if theme == "pub" or theme == "chic": break
		var l: Light3D = dj_lights[k]
		if l.has_meta("mover"):
			# balayage des lyres, couleurs qui changent toutes les 4 mesures
			var sw := t * 0.7 + k * 1.1
			l.rotation = Vector3(-PI / 2.0 + sin(sw) * 0.55, cos(sw * 0.8) * 0.6, 0)
			l.light_color = Color.from_hsv(fmod(floor(t / 8.0) * 0.17 + k * 0.12, 1.0), 0.9, 1.0)
			l.light_energy = 14.0 * (0.55 + 0.45 * (1.0 - beat)) if theme == "indus" else 12.0
			continue
		var a2 := t * 0.6 + k * 2.1
		l.position = Vector3(pc.x + cos(a2) * 4.5 * sx, HC - 0.45, pc.y + sin(a2) * 5.0 * sz)
		l.light_color = Color.from_hsv(fmod(t * 0.08 + k / 3.0, 1.0), 1.0, 1.0)
	if ball: ball.rotation.y = t * 0.8
	for k in leds.size():
		leds[k].visible = fmod(t + k * 0.37, 2.0) < 0.15
	if pharma:
		var pmm: StandardMaterial3D = pharma.material_override
		pmm.emission_energy_multiplier = 4.0 if fmod(t, 1.2) < 0.8 else 0.6
	# feu tricolore : vert 12 s, orange 3 s, rouge 12 s
	if tlight.size() == 3:
		var ph := fmod(t, 27.0)
		var on := 2 if ph < 12.0 else (1 if ph < 15.0 else 0)
		for k in 3:
			var tm: StandardMaterial3D = tlight[k].material_override
			tm.emission_enabled = true
			tm.emission_energy_multiplier = 4.0 if k == on else 0.0
	for car in cars:
		var dirn: float = car.get_meta("dir")
		car.position.x += dirn * float(car.get_meta("v")) * delta
		if absf(car.position.x) > 60.0:
			car.position.x = -60.0 * dirn
			car.set_meta("v", randf_range(7.0, 11.0))
	if smoke != null and closing < 0.3:
		smoke_t -= delta
		if smoke_t <= 0.0:
			smoke.emitting = not smoke.emitting
			smoke_t = 2.5 if smoke.emitting else randf_range(18.0, 30.0)
	if exit_sign:
		var em: StandardMaterial3D = exit_sign.material_override
		em.emission_energy_multiplier = 3.0 + 1.5 * sin(t * 2.0)
