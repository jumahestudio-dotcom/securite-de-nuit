extends Node3D
## Le Néon : rue, file d'attente, façade, hall, salle (piste LED, bar, carré VIP, fumoir, toilettes).

const ZR := {
	"porte": [-1.5, 4.0, 1.2, 4.0], "hall": [-3.0, 3.0, -5.5, -1.0], "vestiaire": [-3.6, -2.6, -5.0, -1.0],
	"piste": [-5.5, 5.5, -23.5, -12.5], "bar": [-10.4, -8.0, -23.0, -9.5], "vip": [9.0, 14.0, -29.0, -21.0],
	"fumoir": [10.0, 14.5, -13.5, -7.5], "toilettes": [-14.5, -9.5, -29.5, -26.0], "secours": [12.5, 14.4, -20.0, -16.0]}
const ZLBL := {"porte":"Entrée (dehors)","hall":"Hall","vestiaire":"Vestiaire","piste":"Piste","bar":"Bar","vip":"Carré VIP","fumoir":"Fumoir","toilettes":"Toilettes","secours":"Issue de secours"}

var tiles := []
var neons := []
var dj_lights := []
var ball: MeshInstance3D
var exit_sign: MeshInstance3D
var neon_light: OmniLight3D
var t := 0.0

## Hauteur du sol à un endroit (trottoir, piste LED, estrade du carré VIP)
func floor_y(x: float, z: float) -> float:
	if x > 8.0 and x < 15.0 and z > -30.0 and z < -21.0: return 0.3
	if z > 0.0 and z < 6.0 and absf(x) < 22.0: return 0.12
	if absf(x) < 6.0 and z > -24.0 and z < -12.0: return 0.08
	return 0.0

func zpt(z: String) -> Vector3:
	var r = ZR[z]
	return Vector3(randf_range(r[0], r[1]), 0, randf_range(r[2], r[3]))

# ---------- navigation par points de passage ----------
func region(x: float, z: float) -> String:
	if z > 0.4: return "out"
	if z > -6.2: return "hall"
	if x < -9.1 and z < -25.0: return "toi"
	if x > 9.1 and z > -14.1 and z < -6.0: return "fum"
	return "main"

const UP := {"out": [Vector2(0, 1), Vector2(0, -0.8)], "hall": [Vector2(0, -4.6), Vector2(0, -7.6)],
	"toi": [Vector2(-11.2, -26.4), Vector2(-11.2, -23.6)], "fum": [Vector2(10, -9.4), Vector2(8.2, -9.4)]}
const PARENT := {"out": "hall", "hall": "main", "toi": "main", "fum": "main", "main": ""}

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

func build() -> void:
	# ---- DEHORS ----
	box(Vector3(0, -0.05, 14), Vector3(60, 0.1, 30), "#17161c", true, "", 0.0, 0.35)  # chaussée mouillée
	var x := -24.0
	while x < 26.0:
		box(Vector3(x, 0.005, 11), Vector3(2, 0.01, 0.18), "#d8d2b0")
		x += 4.0
	box(Vector3(0, 0.06, 3), Vector3(44, 0.12, 6), "#2c2a33", false, "", 0.0, 0.5)
	box(Vector3(0, 0.13, 6), Vector3(44, 0.02, 0.25), "#4a4752")
	x = 2.2
	while x < 11.0:
		cyl(Vector3(x, 0.5, 2.0), 0.04, 1.0, "#c9a227")
		x += 1.6
	box(Vector3(6.5, 0.85, 2.0), Vector3(8.6, 0.06, 0.06), "#9b1239", true)
	for s in [-1, 1]:
		cyl(Vector3(s * 1.3, 0.5, 1.5), 0.05, 1.0, "#c9a227", false, "", 0.0)
		sph(Vector3(s * 1.3, 1.03, 1.5), 0.07, "#e8c547", "", 0.0, 0.3, 0.8)
	for i in 8:
		sph(Vector3(-1.3 + i * (2.6 / 7.0), 0.86 - sin(i / 7.0 * PI) * 0.12, 1.5), 0.045, "#a3123f")
	# façade
	box(Vector3(-11, 3, -0.2), Vector3(18, 6, 0.4), "#2a1f2e", true)
	box(Vector3(11, 3, -0.2), Vector3(18, 6, 0.4), "#2a1f2e", true)
	box(Vector3(0, 4.6, -0.2), Vector3(4, 2.8, 0.4), "#2a1f2e")
	for s in [-1, 1]:
		box(Vector3(s * 1.75, 1.6, 0), Vector3(0.3, 3.2, 0.5), "#111111", false, "#26030d", 1.0)
	box(Vector3(0, 3.25, 0), Vector3(3.8, 0.25, 0.5), "#111111")
	box(Vector3(0, 4.4, 0.08), Vector3(4.6, 0.9, 0.12), "#1a0a14")
	for i in 5:
		neons.append(box(Vector3(-1.8 + i * 0.9, 4.4, 0.16), Vector3(0.55, 0.55, 0.04), "#000000", false, "#ff3d9a", 4.0))
	neons.append(box(Vector3(0, 4.95, 0.16), Vector3(4.4, 0.06, 0.04), "#000000", false, "#ff3d9a", 4.0))
	neons.append(box(Vector3(0, 3.85, 0.16), Vector3(4.4, 0.06, 0.04), "#000000", false, "#ff3d9a", 4.0))
	neon_light = omni(Vector3(0, 4.3, 1.6), "#ff3d9a", 9.0, 2.0, true)
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
	box(Vector3(0, 9, 24), Vector3(60, 18, 1), "#120f1a")
	x = -26.0
	while x < 28.0:
		var y := 2.0
		while y < 17.0:
			if randf() > 0.45:
				box(Vector3(x, y, 23.45), Vector3(1.2, 1.4, 0.05), "#000000", false, "#ffcf7a" if randf() > 0.5 else "#7ad7ff", 1.5)
			y += 3.0
		x += 3.0
	box(Vector3(-25, 9, 5), Vector3(1, 18, 40), "#120f1a", true)
	box(Vector3(25, 9, 5), Vector3(1, 18, 40), "#120f1a", true)
	box(Vector3(0, 1, 16.5), Vector3(60, 2, 1), "#120f1a", true)
	# ---- INTÉRIEUR ----
	box(Vector3(0, -0.05, -15), Vector3(30, 0.1, 30), "#141019", true, "", 0.0, 0.3, 0.1)
	box(Vector3(0, 4.05, -15.2), Vector3(30, 0.1, 29.6), "#09070d")
	box(Vector3(-15.1, 2, -15), Vector3(0.3, 4, 30), "#231a2b", true)
	box(Vector3(15.1, 2, -24.5), Vector3(0.3, 4, 11), "#231a2b", true)
	box(Vector3(15.1, 2, -7.5), Vector3(0.3, 4, 15), "#231a2b", true)
	box(Vector3(0, 2, -30.1), Vector3(30, 4, 0.3), "#231a2b", true)
	# issue de secours
	box(Vector3(15.1, 1.1, -17), Vector3(0.25, 2.2, 2.2), "#1d4d2e", true, "#003a14", 0.5)
	box(Vector3(15.1, 3, -17), Vector3(0.3, 1.6, 2.2), "#231a2b")
	exit_sign = box(Vector3(14.85, 2.6, -17), Vector3(0.06, 0.35, 1), "#000000", false, "#30ff7a", 4.0)
	omni(Vector3(14, 2.6, -17), "#30ff7a", 5.0, 0.8)
	# hall
	box(Vector3(-9, 2, -6.1), Vector3(12, 4, 0.3), "#2a2035", true)
	box(Vector3(9, 2, -6.1), Vector3(12, 4, 0.3), "#2a2035", true)
	box(Vector3(4.1, 2, -3), Vector3(0.3, 4, 6), "#2a2035", true)
	box(Vector3(0, 0.01, -3), Vector3(3.6, 0.02, 5), "#5a1030")
	box(Vector3(-4.4, 0.55, -3), Vector3(0.8, 1.1, 4), "#3a2a1c", true)
	box(Vector3(-4.4, 1.12, -3), Vector3(0.9, 0.05, 4.1), "#6b4a2c")
	box(Vector3(-5.2, 2, -3), Vector3(0.1, 4, 6), "#2a2035")
	var z := -5.0
	while z < -0.8:
		box(Vector3(-6.5, 1.6, z), Vector3(0.5, 1, 0.28), ["#3d6fd8","#c0392b","#2c3e50","#8e44ad","#16a085","#111111","#c49a6c"].pick_random())
		z += 0.35
	box(Vector3(-10, 2, -3), Vector3(0.3, 4, 6), "#2a2035", true)
	omni(Vector3(-3, 3.6, -3), "#ffd9a8", 7.0, 1.0)
	# piste LED
	for i in 8:
		for j in 8:
			var tl := box(Vector3(-5.25 + i * 1.5, 0.04, -23.25 + j * 1.5), Vector3(1.44, 0.08, 1.44), "#0a0a10", false, "#ff00ff", 1.5, 0.2)
			tl.set_meta("ij", Vector2i(i, j))
			tiles.append(tl)
	# DJ
	box(Vector3(0, 0.3, -27.5), Vector3(8, 0.6, 3.5), "#15121c", true)
	box(Vector3(0, 1.1, -26.4), Vector3(3.4, 1, 0.8), "#0c0c12", true, "#0a0006", 1.0)
	neons.append(box(Vector3(0, 1.62, -26), Vector3(3.4, 0.04, 0.04), "#000000", false, "#33e1ff", 5.0))
	for sx in [-5.0, 5.0]:
		box(Vector3(sx, 1.4, -28.5), Vector3(1.3, 2.8, 1.1), "#0b0b0f", true)
	dj_lights = [omni(Vector3(-4, 3.6, -22), "#ff3d9a", 11.0, 3.0, true), omni(Vector3(4, 3.6, -18), "#33e1ff", 11.0, 3.0), omni(Vector3(0, 3.6, -14), "#ffc04d", 10.0, 2.4)]
	ball = sph(Vector3(0, 3.4, -18), 0.35, "#cccccc", "#404050", 0.5, 0.05, 1.0)
	# bar
	box(Vector3(-11, 0.55, -16), Vector3(0.9, 1.1, 14), "#3b2516", true)
	box(Vector3(-11, 1.13, -16), Vector3(1.1, 0.06, 14.2), "#7a4b28", false, "", 0.0, 0.2, 0.2)
	neons.append(box(Vector3(-10.52, 0.95, -16), Vector3(0.03, 0.05, 13.8), "#000000", false, "#ffc04d", 5.0))
	box(Vector3(-14.6, 1.6, -16), Vector3(0.6, 2.4, 13), "#1d1410")
	z = -22.0
	while z < -10.0:
		for by in [1.25, 1.85]:
			cyl(Vector3(-14.35, by + 0.15, z), 0.06, 0.36, "#000000", false, ["#3ee08f","#ffc04d","#33e1ff","#ff7ab6","#e74c3c"].pick_random(), 2.0)
		z += 0.32
	z = -22.0
	while z < -9.0:
		cyl(Vector3(-10.2, 0.4, z), 0.06, 0.8, "#555555")
		cyl(Vector3(-10.2, 0.82, z), 0.22, 0.06, "#7a1430")
		z += 1.6
	omni(Vector3(-12, 3.4, -12), "#ffb070", 8.0, 1.6)
	omni(Vector3(-12, 3.4, -20), "#ffb070", 8.0, 1.6)
	# carré VIP
	box(Vector3(11.5, 0.15, -25.5), Vector3(7, 0.3, 9), "#2a0f34")
	box(Vector3(8.1, 0.55, -25.5), Vector3(0.08, 0.5, 9), "#9b1239")
	box(Vector3(11.5, 0.55, -29.6), Vector3(6.6, 0.7, 0.7), "#5b1f6e", true)
	box(Vector3(11.5, 1.05, -29.85), Vector3(6.6, 0.6, 0.25), "#4a1a5a")
	box(Vector3(14.6, 0.55, -25.5), Vector3(0.7, 0.7, 7), "#5b1f6e", true)
	box(Vector3(14.85, 1.05, -25.5), Vector3(0.25, 0.6, 7), "#4a1a5a")
	for tb in [Vector2(10.5, -27.5), Vector2(12.8, -27.5), Vector2(12.8, -24.0)]:
		cyl(Vector3(tb.x, 0.55, tb.y), 0.45, 0.08, "#1a1420", true)
		cyl(Vector3(tb.x, 0.75, tb.y), 0.12, 0.3, "#9fe0ff", false, "#1a4a66", 1.5)
	omni(Vector3(11.5, 3.4, -25.5), "#b04dff", 9.0, 2.0)
	# fumoir
	box(Vector3(9.1, 2, -12.5), Vector3(0.2, 4, 2), "#2a2035", true)
	box(Vector3(9.1, 2, -7), Vector3(0.2, 4, 1.4), "#2a2035", true)
	box(Vector3(9.1, 3.4, -9.4), Vector3(0.2, 1.2, 3.6), "#2a2035")
	box(Vector3(12, 2, -14.1), Vector3(6, 4, 0.2), "#2a2035", true)
	var glass := box(Vector3(9.1, 1.4, -9.4), Vector3(0.06, 2.8, 3.4), "#7ad7ff")
	var gm: StandardMaterial3D = glass.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.5, 0.85, 1.0, 0.15)
	gm.roughness = 0.05
	for c in [Vector2(11, -12.5), Vector2(13.6, -12.5), Vector2(13.6, -8.5)]:
		cyl(Vector3(c.x, 0.5, c.y), 0.18, 1.0, "#333333", true)
	omni(Vector3(12, 3.4, -10.5), "#c8c8d8", 7.0, 1.0)
	# toilettes
	box(Vector3(-13.5, 2, -25.1), Vector3(3, 4, 0.2), "#2a2035", true)
	box(Vector3(-9.6, 2, -25.1), Vector3(0.8, 4, 0.2), "#2a2035", true)
	box(Vector3(-9.1, 2, -27.6), Vector3(0.2, 4, 5), "#2a2035", true)
	box(Vector3(-11, 3.5, -25.1), Vector3(2.2, 1, 0.2), "#2a2035")
	var sx2 := -14.4
	while sx2 < -10.5:
		box(Vector3(sx2, 1.1, -28.6), Vector3(0.06, 2.2, 2.6), "#3a5266", true)
		cyl(Vector3(sx2 + 0.65, 0.25, -29.6), 0.22, 0.5, "#e8eef2")
		sx2 += 1.3
	box(Vector3(-12, 0.01, -27.5), Vector3(5.6, 0.02, 4.6), "#2a3a46", false, "", 0.0, 0.15)
	omni(Vector3(-12, 3.4, -27.5), "#cfe9ff", 7.0, 1.2)
	# plafonniers
	var px := -12.0
	while px <= 12.0:
		var pz := -27.0
		while pz <= -9.0:
			sph(Vector3(px, 3.95, pz), 0.12, "#000000", "#ff3d9a", 3.0)
			pz += 6.0
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
		l.position = Vector3(cos(a2) * 4.5, 3.4, -18 + sin(a2) * 5)
		l.light_color = Color.from_hsv(fmod(t * 0.08 + k / 3.0, 1.0), 1.0, 1.0)
	if ball: ball.rotation.y = t * 0.8
	if exit_sign:
		var em: StandardMaterial3D = exit_sign.material_override
		em.emission_energy_multiplier = 3.0 + 1.5 * sin(t * 2.0)
