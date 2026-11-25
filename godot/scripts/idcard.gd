extends Control
## La pièce d'identité du client, dessinée comme une vraie carte : photo, champs, bande MRZ,
## hologramme. Les fraudes se voient comme en vrai : photo d'une autre personne (carte prêtée),
## date de naissance retouchée qui ne correspond plus à la bande MRZ, etc.

var c: Dictionary = {}
var words: Array = []
var t := 0.0
const CITIES := ["PARIS", "LYON", "MARSEILLE", "TOURS", "LILLE", "NANTES", "BORDEAUX", "RENNES", "TOULOUSE", "ORLÉANS", "BLOIS", "NIORT", "DIJON", "NANCY"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0; anchor_top = 0
	offset_left = 24; offset_top = 150
	offset_right = 24 + 470; offset_bottom = 150 + 300
	visible = false

func show_for(cl: Dictionary, w: Array) -> void:
	c = cl
	words = w
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()

func _col_of(list: Array, word: String, def: Color) -> Color:
	for x in list:
		if x[1] == word: return x[0]
	return def

func _h(s: String, k: int) -> int:
	return abs((s + str(k)).hash())

func _mrz_name(s: String) -> String:
	var r := s.to_upper()
	for p in [["É", "E"], ["È", "E"], ["Ë", "E"], ["Ï", "I"], ["Î", "I"], ["Ç", "C"], ["Ô", "O"], [" ", "<"], ["-", "<"], ["'", ""]]:
		r = r.replace(p[0], p[1])
	return r

func _draw() -> void:
	if c.is_empty(): return
	var f := ThemeDB.fallback_font
	var W := 460.0
	var H := 290.0
	var student: bool = not c["has_id"] and c.get("student_card", false)
	var kind: String = c.get("id_type", "Carte nationale d'identité")
	var foreign: bool = not (kind.begins_with("Carte nationale") or kind.begins_with("Permis") or student)
	var bg1 := Color("#e9d7e6")
	var bg2 := Color("#cfe1f2")
	var title := "RÉPUBLIQUE FRANÇAISE"
	var sub := "CARTE NATIONALE D'IDENTITÉ / IDENTITY CARD"
	if kind.begins_with("Permis"):
		bg1 = Color("#f4c9d6"); bg2 = Color("#f9e2ea"); sub = "PERMIS DE CONDUIRE"
	elif foreign:
		bg1 = Color("#dfe7d2"); bg2 = Color("#eef0e6"); title = kind.to_upper(); sub = "DOCUMENT ÉTRANGER"
	if student:
		bg1 = Color("#dfe9f7"); bg2 = Color("#ffffff"); title = "UNIVERSITÉ"; sub = "CARTE D'ÉTUDIANT·E"
	# fond de carte, coins arrondis, dégradé
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg1
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	draw_style_box(sb, Rect2(0, 0, W, H))
	for i in 24:
		var k := i / 23.0
		draw_rect(Rect2(8 + k * (W - 16), 8, (W - 16) / 23.0 + 1, H - 16), bg1.lerp(bg2, k) * Color(1, 1, 1, 0.55))
	# guilloches (motif de sécurité)
	for i in 14:
		var pts := PackedVector2Array()
		for x in range(0, int(W), 8):
			pts.append(Vector2(x, 70 + i * 14 + sin(x * 0.045 + i) * 6))
		draw_polyline(pts, Color(0.5, 0.4, 0.6, 0.12), 1.0)
	draw_string(f, Vector2(18, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#1b2a55"))
	draw_string(f, Vector2(18, 46), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#3a3f66"))
	if not foreign and not student:
		draw_rect(Rect2(W - 70, 14, 16, 30), Color("#1f3fae"))
		draw_rect(Rect2(W - 54, 14, 16, 30), Color("#f2f2f2"))
		draw_rect(Rect2(W - 38, 14, 16, 30), Color("#d0202e"))
	# ---- photo ----
	var pr := Rect2(18, 62, 118, 150)
	draw_rect(pr, Color("#e9eef2"))
	var hair_w := ""
	var hs_w := ""
	var skin_w := ""
	if words.size() >= 3:
		hair_w = words[0]; hs_w = words[1]; skin_w = words[2]
	if c.get("borrowed", false) and c.get("owner_look") != null:
		hair_w = c["owner_look"][0]; hs_w = c["owner_look"][1]; skin_w = c["owner_look"][2]
	var skin := _col_of(Data.SKINS, skin_w, Color("#d9a57a"))
	var hair := _col_of(Data.HAIRS, hair_w, Color("#8a8a8a") if hair_w == "gris" else Color("#2e1c10"))
	var seed_name: String = c["id_name"] if c.get("id_name", "") != "" else c["first"]
	var fw := 30.0 + (_h(seed_name, 1) % 8)
	var cx := pr.position.x + pr.size.x / 2.0
	var cy := pr.position.y + 66.0
	draw_rect(Rect2(cx - 50, cy + 52, 100, 40), Color("#3a3f4a"))
	draw_rect(Rect2(cx - 12, cy + 34, 24, 22), skin)
	draw_set_transform(Vector2(cx, cy), 0.0, Vector2(fw / 36.0, 1.25))
	draw_circle(Vector2.ZERO, 36.0, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hs_w != "rasés" and hs_w != "très courts":
		draw_set_transform(Vector2(cx, cy - 22), 0.0, Vector2(fw / 34.0, 0.65))
		draw_circle(Vector2.ZERO, 38.0, hair)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2(cx, cy - 30), 0.0, Vector2(fw / 36.0, 0.35))
		draw_circle(Vector2.ZERO, 36.0, hair.lerp(skin, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hs_w in ["longs", "mi-longs", "bouclés", "afro bouclés"]:
		draw_rect(Rect2(cx - fw - 6, cy - 20, 12, 70 if hs_w == "longs" else 44), hair)
		draw_rect(Rect2(cx + fw - 6, cy - 20, 12, 70 if hs_w == "longs" else 44), hair)
	if hs_w in ["attachés", "en chignon"]:
		draw_circle(Vector2(cx, cy - 50), 13, hair)
	draw_circle(Vector2(cx - 12, cy - 2), 3.2, Color("#1a1a1a"))
	draw_circle(Vector2(cx + 12, cy - 2), 3.2, Color("#1a1a1a"))
	draw_line(Vector2(cx, cy + 2), Vector2(cx - 2, cy + 14), skin.darkened(0.3), 2.0)
	draw_line(Vector2(cx - 10, cy + 24), Vector2(cx + 10, cy + 24), skin.darkened(0.45), 2.0)
	# hologramme qui miroite
	var sh := fmod(t * 0.6, 1.6) - 0.3
	for i in 6:
		var a := clampf(0.25 - absf(i / 6.0 - sh) * 0.6, 0.0, 0.25)
		draw_rect(Rect2(pr.position.x + i * pr.size.x / 6.0, pr.position.y, pr.size.x / 6.0, pr.size.y), Color.from_hsv(fmod(t * 0.2 + i * 0.1, 1.0), 0.6, 1.0, a))
	# ---- champs ----
	var nm: String = c["id_name"] if c.get("id_name", "") != "" else c["first"] + " " + c["last"]
	var parts := nm.split(" ", false)
	var last: String = parts[parts.size() - 1] if parts.size() > 0 else c["last"]
	var first: String = " ".join(parts.slice(0, parts.size() - 1)) if parts.size() > 1 else c["first"]
	var x0 := 152.0
	var y := 74.0
	var lab := Color("#4a4f70")
	var val := Color("#111111")
	var rows := [["NOM / Surname", last.to_upper()], ["Prénoms / Given names", first]]
	if student:
		rows.append(["Établissement", "Université de Tours"])
		rows.append(["Année universitaire", "%d-%d" % [Data.GAME_Y, Data.GAME_Y + 1]])
	else:
		rows.append(["Sexe / Sex", c.get("id_sex", "M" if c["sex"] == "H" else "F")])
		rows.append(["Nationalité", "FRA" if not foreign else "—"])
	for r in rows:
		draw_string(f, Vector2(x0, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		draw_string(f, Vector2(x0, y + 15), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, val)
		y += 34
	if not student:
		var dob: Array = c["dob"]
		var dtxt := "%02d %02d %d" % [dob[2], dob[1], dob[0]]
		draw_string(f, Vector2(x0 + 150, 142), "Date de naiss. / Date of birth", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		if c.get("altered", false):
			# chiffres retouchés : encre plus épaisse et légèrement décalée
			draw_string(f, Vector2(x0 + 150.6, 157.6), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#2a1a1a"))
			draw_string(f, Vector2(x0 + 151.2, 157), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#2a1a1a"))
		else:
			draw_string(f, Vector2(x0 + 150, 157), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, val)
		var city: String = CITIES[_h(nm, 2) % CITIES.size()]
		draw_string(f, Vector2(x0 + 150, 176), "Lieu de naissance", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		draw_string(f, Vector2(x0 + 150, 191), city, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, val)
		var issue: int = Data.GAME_Y - (_h(nm, 3) % 9)
		var exp_y: int = issue + 10
		var exp_m: int = 1 + _h(nm, 4) % 12
		draw_string(f, Vector2(x0, 210), "Date d'expiration / Date of expiry", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		draw_string(f, Vector2(x0, 225), "%02d %02d %d" % [1 + _h(nm, 5) % 28, exp_m, exp_y], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, val)
		var docn := "%s%07d" % [["X", "Y", "Z", "F"][_h(nm, 6) % 4] + str(_h(nm, 7) % 10), _h(nm, 8) % 10000000]
		draw_string(f, Vector2(x0 + 150, 210), "N° du document", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lab)
		draw_string(f, Vector2(x0 + 150, 225), docn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, val)
		# bande MRZ : la vraie date de naissance y est encodée (une retouche ne la change pas)
		var real: Array = c.get("true_dob", c["dob"])
		var mz := "%02d%02d%02d" % [int(real[0]) % 100, real[1], real[2]]
		var l1 := ("IDFRA" + _mrz_name(last) + "<<" + _mrz_name(first) + "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<").substr(0, 36)
		var l2 := (docn + "<" + str(_h(nm, 9) % 10) + "FRA" + mz + str(_h(mz, 1) % 10) + ("M" if c["sex"] == "H" else "F") + "%02d%02d%02d" % [exp_y % 100, exp_m, 1] + "<<<<<<<<<<<<").substr(0, 36)
		draw_rect(Rect2(10, H - 56, W - 20, 46), Color(1, 1, 1, 0.55))
		draw_string(f, Vector2(18, H - 37), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#111111"))
		draw_string(f, Vector2(18, H - 17), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#111111"))
	else:
		draw_string(f, Vector2(x0, 220), "Aucune date de naissance sur ce document.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7a2a2a"))
