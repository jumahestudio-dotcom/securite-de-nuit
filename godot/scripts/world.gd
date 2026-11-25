extends Node3D
## Les établissements : rue, file d'attente, façade, hall, puis la salle (piste LED, bar, carré VIP,
## fumoir, toilettes, issue de secours). La salle s'adapte à la taille de chaque établissement,
## et le décor utilise les modèles 3D de assets/decor/ quand ils sont présents (licence CC-BY 4.0,
## voir CREDITS.md).

const VENUES := {
	"comptoir": {"name": "Le Comptoir", "type": "Bar de quartier", "sub": "Petit bar à bières, coin danse, terrasse fumeurs. Clientèle d'habitués.",
		"sx": 0.62, "sz": 0.55, "cap": 60, "crowd": 16, "nq": 10, "agents": ["Sarah"], "no_vip": true, "price": 0, "inc_k": 1.25,
		"neon": "#ffc04d", "wall": "#2b2219", "floor": "#1a140e", "accent": "#e08a2c", "unlock": 0, "facade": "#3a2a1e", "fh": 4.2},
	"neon": {"name": "Le Néon", "type": "Discothèque", "sub": "Le club du centre-ville : piste LED, carré VIP, fumoir.",
		"sx": 1.0, "sz": 1.0, "cap": 110, "crowd": 30, "nq": 14, "agents": ["Moussa", "Sarah"], "no_vip": false, "price": 15, "inc_k": 1.0,
		"neon": "#ff3d9a", "wall": "#231a2b", "floor": "#141019", "accent": "#9b1239", "unlock": 0, "facade": "#2a1f2e", "fh": 6.0},
	"palace": {"name": "Le Palace", "type": "Club chic", "sub": "Clientèle aisée, grand carré VIP avec son propre bar, dress code strict.",
		"sx": 1.18, "sz": 1.12, "cap": 160, "crowd": 42, "nq": 16, "agents": ["Moussa", "Sarah", "Karim"], "no_vip": false, "price": 25, "inc_k": 0.9,
		"neon": "#ffd27a", "wall": "#1f1a12", "floor": "#15110b", "accent": "#c9a227", "unlock": 300, "facade": "#2b2418", "fh": 6.0},
	"usine": {"name": "L'Usine", "type": "Club électro géant", "sub": "Ancien entrepôt, 300 personnes, DJ internationaux, murs d'équaliseurs. Le plus dur.",
		"sx": 1.42, "sz": 1.45, "cap": 300, "crowd": 70, "nq": 20, "agents": ["Moussa", "Sarah", "Karim", "Inès"], "no_vip": false, "price": 20, "inc_k": 0.72,
		"neon": "#33e1ff", "wall": "#1b1e24", "floor": "#101216", "accent": "#3a6ea8", "unlock": 700, "facade": "#2a2d33", "fh": 9.0}}

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
const PARENT := {"out": "hall", "hall": "main", "toi": "main", "fum": "main", "main": ""}

var tiles := []
var neons := []
var dj_lights := []
var ball: MeshInstance3D
var exit_sign: MeshInstance3D
var neon_light: OmniLight3D
var anims: Array = []
var t := 0.0
var pc := Vector2(0, -18)    # centre de la piste

func X(x: float) -> float:
	return x * sx

func Zm(z: float) -> float:
	return z if z > -6.1 else -6.1 + (z + 6.1) * sz

func _geo() -> void:
	W = 15.0 * sx
	ZB = Zm(-30.0)
	HC = 5.5 if vk == "usine" else 4.05
	ZR = {"porte": [-1.5, 4.0, 1.2, 4.0], "hall": [-3.0, 3.0, -5.5, -1.0], "vestiaire": [-3.6, -2.6, -5.0, -1.0],
		"piste": [X(-5.5), X(5.5), Zm(-23.5), Zm(-12.5)], "bar": [X(-10.4), X(-8.0), Zm(-23.0), Zm(-9.5)],
		"fumoir": [X(10.0), X(14.5), Zm(-13.5), Zm(-7.5)], "toilettes": [X(-14.5), X(-9.5), Zm(-29.5), Zm(-26.0)],
		"secours": [W - 2.5, W - 0.6, Zm(-20.0), Zm(-16.0)]}
	if not V["no_vip"]:
		ZR["vip"] = [X(9.0), X(14.0), Zm(-29.0), Zm(-21.0)]
	geo = {"tx": X(-9.1), "tz": Zm(-25.1), "fx": X(9.1), "fz0": Zm(-14.1), "dz": Zm(-9.4), "gx0": X(-12.4), "gx1": X(-10.0)}
	var gm: float = (geo["gx0"] + geo["gx1"]) / 2.0
	UP = {"out": [Vector2(0, 1), Vector2(0, -0.8)], "hall": [Vector2(0, -4.6), Vector2(0, -7.6)],
		"toi": [Vector2(gm, geo["tz"] - 1.2), Vector2(gm, geo["tz"] + 1.4)],
		"fum": [Vector2(geo["fx"] + 0.9, geo["dz"]), Vector2(geo["fx"] - 0.9, geo["dz"])]}

## Hauteur du sol à un endroit (trottoir, piste LED, estrade du carré VIP)
func floor_y(x: float, z: float) -> float:
	if ZR.has("vip"):
		var v: Array = ZR["vip"]
		if x > v[0] - 1.0 and x < W and z > v[2] - 1.0 and z < v[3]: return 0.3
	if z > 0.0 and z < 6.0 and absf(x) < 22.0: return 0.12
	var p: Array = ZR["piste"]
	if x > p[0] - 0.5 and x < p[1] + 0.5 and z > p[2] - 0.5 and z < p[3] + 0.5: return 0.08
	return 0.0

func zpt(z: String) -> Vector3:
	var r = ZR[z]
	return Vector3(randf_range(r[0], r[1]), 0, randf_range(r[2], r[3]))

# ---------- navigation par points de passage ----------
func region(x: float, z: float) -> String:
	if z > 0.4: return "out"
	if z > -6.2: return "hall"
	if x < geo["tx"] and z < geo["tz"]: return "toi"
	if x > geo["fx"] and z > geo["fz0"] and z < -6.0: return "fum"
	return "main"

func route(a: Vector3, b: Vector3) -> Array:
	var ra := region(a.x, a.z)
	var rb := region(b.x, b.z)
	if ra == rb: return [Vector2(b.x, b.z)]
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
	_geo()
	var NE: String = V["neon"]
	var WC: String = V["wall"]
	var FW: float = max(20.0, W + 1.5)
	var FH: float = V["fh"]
	# ---- DEHORS ----
	box(Vector3(0, -0.05, 14), Vector3(2 * FW + 20, 0.1, 30), "#17161c", true, "", 0.0, 0.35)
	var x := -FW - 4.0
	while x < FW + 6.0:
		box(Vector3(x, 0.005, 11), Vector3(2, 0.01, 0.18), "#d8d2b0")
		x += 4.0
	box(Vector3(0, 0.06, 3), Vector3(2 * FW + 4, 0.12, 6), "#2c2a33", false, "", 0.0, 0.5)
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
	box(Vector3(-(2 + FW) / 2.0, FH / 2.0, -0.2), Vector3(FW - 2, FH, 0.4), fc, true)
	box(Vector3((2 + FW) / 2.0, FH / 2.0, -0.2), Vector3(FW - 2, FH, 0.4), fc, true)
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
		omni(Vector3(lx, 4.6, 4.8), "#ffcf7a", 11.0, 1.6, lx == 9.0)
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
	var D: float = -ZB
	box(Vector3(0, -0.05, ZB / 2.0), Vector3(2 * W, 0.1, D), V["floor"], true, "", 0.0, 0.3, 0.1)
	box(Vector3(0, HC, ZB / 2.0), Vector3(2 * W, 0.1, D), "#09070d")
	box(Vector3(-W - 0.1, HC / 2.0, ZB / 2.0), Vector3(0.3, HC, D), WC, true)
	var ez: float = Zm(-17.0)
	box(Vector3(W + 0.1, HC / 2.0, (ZB + ez - 1.2) / 2.0), Vector3(0.3, HC, ez - 1.2 - ZB), WC, true)
	box(Vector3(W + 0.1, HC / 2.0, (ez + 1.2) / 2.0), Vector3(0.3, HC, -(ez + 1.2)), WC, true)
	box(Vector3(0, HC / 2.0, ZB - 0.1), Vector3(2 * W, HC, 0.3), WC, true)
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
	# piste LED
	var pr: Array = ZR["piste"]
	pc = Vector2((pr[0] + pr[1]) / 2.0, (pr[2] + pr[3]) / 2.0)
	var ni: int = max(4, int(round(8 * sx)))
	var nj: int = max(4, int(round(8 * sz)))
	for i in ni:
		for j in nj:
			var tl := box(Vector3(pc.x - (ni - 1) * 0.75 + i * 1.5, 0.04, pc.y - (nj - 1) * 0.75 + j * 1.5), Vector3(1.44, 0.08, 1.44), "#0a0a10", false, "#ff00ff", 1.5, 0.2)
			tl.set_meta("ij", Vector2i(i, j))
			tiles.append(tl)
	# cabine DJ
	var djz: float = Zm(-27.5)
	box(Vector3(0, 0.3, djz), Vector3(8 * min(sx, 1.2), 0.6, 3.5), "#15121c", true)
	box(Vector3(0, 1.1, djz + 1.1), Vector3(3.4, 1, 0.8), "#0c0c12", true, "#0a0006", 1.0)
	neons.append(box(Vector3(0, 1.62, djz + 1.5), Vector3(3.4, 0.04, 0.04), "#000000", false, "#33e1ff", 5.0))
	# enceintes : équaliseurs animés si le modèle est là, sinon caissons
	var spk := [-5.0 * sx, 5.0 * sx]
	if vk == "usine": spk = [-5.0 * sx, -9.0 * sx, 5.0 * sx, 9.0 * sx]
	for spx in spk:
		var hh: float = 3.6 if vk == "usine" else 2.8
		if vk != "comptoir" and has_decor("equalizer_with_3d_indicators"):
			prop("equalizer_with_3d_indicators", Vector3(spx, 0, djz - 0.6), 0.0, hh, true)
		else:
			box(Vector3(spx, hh / 2.0, djz - 1.0), Vector3(1.3, hh, 1.1), "#0b0b0f", true)
	dj_lights = [omni(Vector3(-4, HC - 0.45, pc.y - 4), NE, 11.0, 3.0, true), omni(Vector3(4, HC - 0.45, pc.y), "#33e1ff", 11.0, 3.0), omni(Vector3(0, HC - 0.45, pc.y + 4), "#ffc04d", 10.0, 2.4)]
	if vk == "usine":
		dj_lights.append(omni(Vector3(-8, HC - 0.45, pc.y), "#b04dff", 13.0, 3.0))
		dj_lights.append(omni(Vector3(8, HC - 0.45, pc.y - 6), "#30ff7a", 13.0, 2.6))
	ball = sph(Vector3(pc.x, HC - 0.65, pc.y), 0.35, "#cccccc", "#404050", 0.5, 0.05, 1.0)
	# bar
	var bz0: float = Zm(-23.0)
	var bz1: float = Zm(-9.0)
	var bl: float = bz1 - bz0
	var bzc: float = (bz0 + bz1) / 2.0
	var bx: float = X(-11.0)
	if vk == "comptoir" and has_decor("bar_bar"):
		# au Comptoir, le vrai bar (comptoir, étagères à bouteilles, tabourets) remplace le bar en blocs
		prop("bar_bar", Vector3(bx - 0.6, 0, bzc), PI / 2.0, -0.0254, false, false, true)
		var sbb := StaticBody3D.new()
		var csb := CollisionShape3D.new()
		var shb := BoxShape3D.new()
		shb.size = Vector3(0.6, 1.1, 3.2)
		csb.shape = shb
		sbb.position = Vector3(bx - 0.6, 0.55, bzc)
		sbb.add_child(csb)
		add_child(sbb)
	else:
		box(Vector3(bx, 0.55, bzc), Vector3(0.9, 1.1, bl), "#3b2516", true)
		box(Vector3(bx, 1.13, bzc), Vector3(1.1, 0.06, bl + 0.2), "#7a4b28", false, "", 0.0, 0.2, 0.2)
		neons.append(box(Vector3(bx + 0.48, 0.95, bzc), Vector3(0.03, 0.05, bl - 0.2), "#000000", false, "#33e1ff" if vk == "usine" else "#ffc04d", 5.0))
		box(Vector3(-W + 0.4, 1.6, bzc), Vector3(0.6, 2.4, bl - 1), "#1d1410")
		z = bz0 + 0.5
		while z < bz1 - 0.5:
			for by in [1.25, 1.85]:
				cyl(Vector3(-W + 0.65, by + 0.15, z), 0.06, 0.36, "#000000", false, ["#3ee08f", "#ffc04d", "#33e1ff", "#ff7ab6", "#e74c3c"].pick_random(), 2.0)
			z += 0.32
		z = bz0
		while z < bz1:
			cyl(Vector3(bx + 0.8, 0.4, z), 0.06, 0.8, "#555555")
			cyl(Vector3(bx + 0.8, 0.82, z), 0.22, 0.06, V["accent"])
			z += 1.6
	# lustres au-dessus du bar (ou simples lampes)
	z = bz0 + 3.0
	while z < bz1:
		if has_decor("ufo_modern_chandelier"):
			prop("ufo_modern_chandelier", Vector3(bx - 0.8, HC - 0.32, z), 0.0, 0.9, false, false)
		omni(Vector3(bx - 1.0, HC - 0.7, z), "#ffb070", 8.0, 1.6)
		z += 6.0
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
	# plafonniers
	var px := -W + 3.0
	while px <= W - 3.0:
		var pz := -9.0
		while pz >= ZB + 3.0:
			sph(Vector3(px, HC - 0.1, pz), 0.12, "#000000", NE, 3.0)
			pz -= 6.0
		px += 6.0

func animate(delta: float) -> void:
	t += delta
	for tl in tiles:
		var ij: Vector2i = tl.get_meta("ij")
		var h := fmod((ij.x * 37 + ij.y * 53) / 360.0 + t * 0.25, 1.0)
		var a := 0.35 + 0.35 * maxf(0.0, sin(t * 2.5 + ij.x * 0.7 + ij.y * 0.5))
		var m: StandardMaterial3D = tl.material_override
		m.emission = Color.from_hsv(h, 0.9, 1.0)
		m.emission_energy_multiplier = a * 4.0
	var fl := sin(t * 23.0) > 0.97 or fmod(t * 1000.0, 4200.0) < 90.0
	for n in neons:
		var m2: StandardMaterial3D = n.material_override
		if not n.has_meta("e0"): n.set_meta("e0", m2.emission_energy_multiplier)
		m2.emission_energy_multiplier = n.get_meta("e0") * (0.2 if fl else 1.0)
	if neon_light: neon_light.light_energy = 0.5 if fl else 2.0
	for k in dj_lights.size():
		var l: OmniLight3D = dj_lights[k]
		var a2 := t * 0.6 + k * 2.1
		l.position = Vector3(pc.x + cos(a2) * 4.5 * sx, HC - 0.45, pc.y + sin(a2) * 5.0 * sz)
		l.light_color = Color.from_hsv(fmod(t * 0.08 + k / 3.0, 1.0), 1.0, 1.0)
	if ball: ball.rotation.y = t * 0.8
	if exit_sign:
		var em: StandardMaterial3D = exit_sign.material_override
		em.emission_energy_multiplier = 3.0 + 1.5 * sin(t * 2.0)
