extends Node3D
## Personnage 3D provisoire (formes simples + animations procédurales).
## Si un modèle res://assets/characters/human.glb existe, il est utilisé à la place
## (voir LISEZMOI.md pour les noms d'animations attendus).

var sex := "H"
var skin := Color("#e7b896")
var skin_word := "claire"
var hair := Color("#2e1c10")
var hair_word := "bruns foncés"
var hs := "short"
var top := Color("#3d6fd8")
var bottom := Color("#1b2433")
var shoes := Color("#111111")
var dress := false
var cap_col = null
var beard_col = null
var glasses := false
var agent := false
var band_col = null
var height := 1.75

var anim := "idle"
var ph := 0.0
var walk_ph := 0.0
var speed := 1.35
var run := false
var path: Array = []
var on_arrive = null
var face = null
var sway := 0.0
var yaw := 0.0
var pose := {}
var pose_until := 0.0
var ring = null           # couleur d'aura (élan d'un coup)
var data = null           # lien vers la fiche client
var pname := ""
var home := Vector3.ZERO
var task = null
var zone := ""

var body: Node3D
var torso: Node3D
var head: Node3D
var legs := []
var arms := []
var mats := []
var glb = null
var glb_anim: AnimationPlayer = null
var model_path := ""
var meta := {}
var hs_word := ""
var cur_clip := ""
var act_name := ""
var act_until := 0.0
var tag: Label3D = null
var skel_ref: Skeleton3D = null
var foot_ids: Array = []
var foot_h := 0.05

func setup(o: Dictionary) -> void:
	sex = o.get("sex", "H" if randf() < 0.55 else "F")
	var sk = o.get("skin", Data.SKINS.pick_random())
	var hr = o.get("hair", Data.HAIRS.pick_random())
	skin = sk[0]; skin_word = sk[1]; hair = hr[0]; hair_word = hr[1]
	height = o.get("height", randf_range(1.7, 1.88) if sex == "H" else randf_range(1.58, 1.74))
	if sex == "H":
		hs = o.get("hs", ["short","short","buzz","curly"].pick_random())
	else:
		hs = o.get("hs", ["long","long","bun","bob"].pick_random())
	top = Color(o.get("top", Data.TOPS.pick_random()))
	bottom = Color(o.get("bottom", ["#1b2433","#23232b","#2f3b52","#3a2e25","#111111"].pick_random()))
	shoes = Color(o.get("shoes", ["#111111","#eeeeee","#3a2a1a"].pick_random()))
	dress = o.get("dress", sex == "F" and randf() < 0.45)
	if o.has("cap"): cap_col = Color(o["cap"])
	if o.has("beard"): beard_col = Color(o["beard"])
	glasses = o.get("glasses", false)
	agent = o.get("agent", false)
	if o.has("band"): band_col = Color(o["band"])
	if agent:
		top = Color("#111318"); bottom = Color("#14161c"); dress = false; cap_col = null
	if sex == "H" and beard_col == null and not o.get("no_beard", false) and randf() < 0.15:
		beard_col = hair
	ph = randf() * TAU
	# vrai personnage 3D si disponible
	model_path = o.get("model", "")
	if model_path == "" and not o.get("prim", false):
		model_path = Data.pick_model("A" if agent else sex, o.get("no_surv", false))
	if model_path != "":
		meta = Data.CHAR_META.get(model_path.get_file(), {})
		skin_word = str(meta.get("peau", ""))
		hair_word = str(meta.get("cheveux", ""))
		hs_word = str(meta.get("coiffure", ""))
	if o.has("pos"): position = o["pos"]
	yaw = o.get("yaw", 0.0)
	_build()

func _mat(c: Color, emi := Color.BLACK, e := 0.0, rough := 0.75) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emi
		m.emission_energy_multiplier = e
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color, emi := Color.BLACK, e := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emi, e)
	mi.position = pos
	parent.add_child(mi)
	mats.append(mi)
	return mi

func _sph(parent: Node3D, pos: Vector3, scl: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 10
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

## Mots pour la photo de la pièce d'identité ([] si le modèle n'est pas décrit)
func id_words() -> Array:
	if model_path != "" and (hair_word == "" or skin_word == ""):
		return []
	var h := hs_word
	if h == "":
		h = {"short": "courts", "buzz": "très courts", "curly": "bouclés", "long": "longs", "bun": "attachés", "bob": "mi-longs", "bald": "rasés"}.get(hs, "courts")
	return [hair_word, h, skin_word]

func _build() -> void:
	if model_path != "" and _build_model():
		return
	body = Node3D.new()
	add_child(body)
	body.scale = Vector3.ONE * (height / 1.75)
	# jambes
	for s in [-1, 1]:
		var lp := Node3D.new()
		lp.position = Vector3(s * 0.1, 0.9, 0)
		body.add_child(lp)
		if not dress:
			_box(lp, Vector3(0, -0.44, 0), Vector3(0.15, 0.88, 0.17), bottom)
		else:
			_box(lp, Vector3(0, -0.62, 0), Vector3(0.09, 0.5, 0.1), skin)
		_box(lp, Vector3(0, -0.88, 0.05), Vector3(0.15, 0.08, 0.27), shoes)
		legs.append(lp)
	if dress:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.17; cm.bottom_radius = 0.24; cm.height = 0.42
		mi.mesh = cm
		mi.material_override = _mat(top)
		mi.position = Vector3(0, 0.8, 0)
		body.add_child(mi)
	# torse
	torso = Node3D.new()
	torso.position = Vector3(0, 0.9, 0)
	body.add_child(torso)
	_box(torso, Vector3(0, 0.3, 0), Vector3(0.42, 0.6, 0.24), top)
	if agent:
		_box(torso, Vector3(0, 0.42, 0.125), Vector3(0.3, 0.08, 0.01), Color(0.9, 0.9, 0.9), Color(1, 0.9, 0.4), 0.6)
	# bras
	for s in [-1, 1]:
		var ap := Node3D.new()
		ap.position = Vector3(s * 0.27, 0.56, 0)
		torso.add_child(ap)
		_box(ap, Vector3(0, -0.3, 0), Vector3(0.11, 0.6, 0.12), top)
		if agent and s < 0:
			_box(ap, Vector3(0, -0.12, 0), Vector3(0.125, 0.07, 0.135), Color(0.2, 0.2, 0.2), Color(1, 0.75, 0.05), 1.5)
		if band_col != null and s > 0:
			_box(ap, Vector3(0, -0.12, 0), Vector3(0.125, 0.07, 0.135), Color(0.2, 0.2, 0.2), band_col, 1.5)
		_sph(ap, Vector3(0, -0.64, 0), Vector3(0.1, 0.11, 0.1), skin)
		arms.append(ap)
	# tête
	_sph(torso, Vector3(0, 0.64, 0), Vector3(0.1, 0.12, 0.1), skin)
	head = Node3D.new()
	head.position = Vector3(0, 0.8, 0)
	torso.add_child(head)
	_sph(head, Vector3.ZERO, Vector3(0.23, 0.27, 0.24), skin)
	for s in [-1, 1]:
		_sph(head, Vector3(s * 0.05, 0.02, 0.112), Vector3(0.03, 0.03, 0.02), Color(0.05, 0.05, 0.05))
	_box(head, Vector3(0, -0.07, 0.11), Vector3(0.07, 0.012, 0.01), Color(0.35, 0.12, 0.12))
	if glasses:
		_box(head, Vector3(0, 0.02, 0.12), Vector3(0.2, 0.035, 0.02), Color(0.03, 0.03, 0.03))
	if beard_col != null:
		_box(head, Vector3(0, -0.08, 0.06), Vector3(0.21, 0.1, 0.13), beard_col)
	if hs != "bald" and cap_col == null:
		if hs == "buzz":
			_sph(head, Vector3(0, 0.04, -0.01), Vector3(0.235, 0.22, 0.245), hair)
		else:
			_sph(head, Vector3(0, 0.055, -0.012), Vector3(0.25, 0.21, 0.255), hair)
		if hs == "long": _box(head, Vector3(0, -0.12, -0.09), Vector3(0.25, 0.36, 0.1), hair)
		if hs == "bob": _box(head, Vector3(0, -0.04, -0.05), Vector3(0.27, 0.18, 0.2), hair)
		if hs == "bun": _sph(head, Vector3(0, 0.13, -0.1), Vector3(0.12, 0.12, 0.12), hair)
		if hs == "curly":
			for q in [Vector3(-0.07,0.12,0), Vector3(0.07,0.12,0), Vector3(0,0.12,-0.07), Vector3(0,0.12,0.05)]:
				_sph(head, q, Vector3(0.13, 0.1, 0.13), hair)
	if cap_col != null:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.125; cm.bottom_radius = 0.13; cm.height = 0.09
		mi.mesh = cm
		mi.material_override = _mat(cap_col)
		mi.position = Vector3(0, 0.1, 0)
		head.add_child(mi)
		_box(head, Vector3(0, 0.07, 0.16), Vector3(0.2, 0.02, 0.14), cap_col)
	if agent:
		_sph(head, Vector3(0.12, 0, 0), Vector3(0.03, 0.04, 0.03), Color(0.1, 0.1, 0.1))
	# ombre au sol
	var sh := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.32; cm2.bottom_radius = 0.32; cm2.height = 0.01
	sh.mesh = cm2
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.45)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.material_override = smat
	sh.position = Vector3(0, 0.012, 0)
	add_child(sh)

## Nom d'os sans préfixe Mixamo ni numéro ajouté par Sketchfab : « mixamorig:Hips_01 » -> « Hips »
func _bkey(bn: String) -> String:
	var r := RegEx.new()
	r.compile("^mixamorig\\d*[_:]")
	var k := r.sub(bn, "")
	var r2 := RegEx.new()
	r2.compile("_\\d+$")
	return r2.sub(k, "")

func _build_model() -> bool:
	var sc = load(model_path)
	if sc == null or not (sc is PackedScene):
		push_warning("Modèle illisible : " + model_path)
		return false
	glb = sc.instantiate()
	add_child(glb)
	# mise à l'échelle : on mesure le modèle et on l'amène à la taille voulue
	var top_y := 0.0
	var found := false
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != null and n != glb:
			if n is Node3D: xf = n.transform * xf
			n = n.get_parent()
		var bb: AABB = xf * mi.get_aabb()
		top_y = max(top_y, bb.end.y)
		found = true
	if found and top_y > 0.01:
		glb.scale = Vector3.ONE * (height / top_y)
	# animations partagées (squelette Mixamo commun)
	glb_anim = glb.find_child("AnimationPlayer", true, false)
	if glb_anim == null:
		glb_anim = AnimationPlayer.new()
		glb.add_child(glb_anim)
	var skel: Skeleton3D = null
	var skels: Array = glb.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0: skel = skels[0]
	# os des pieds, pour poser le personnage sur le sol à chaque image
	if skel != null:
		skel_ref = skel
		for bi in skel.get_bone_count():
			var bn := _bkey(skel.get_bone_name(bi))
			if bn.ends_with("LeftToeBase") or bn.ends_with("RightToeBase"): foot_ids.append(bi)
		if foot_ids.is_empty():
			foot_h = 0.09
			for bi in skel.get_bone_count():
				var bn2 := _bkey(skel.get_bone_name(bi))
				if bn2.ends_with("LeftFoot") or bn2.ends_with("RightFoot"): foot_ids.append(bi)
	if skel == null or Data.ANIMS.is_empty():
		return true
	var root: Node = glb_anim.get_node(glb_anim.root_node)
	var skel_path := str(root.get_path_to(skel))
	var ckey := skel_path + "|" + skel.get_bone_name(0)
	if Data.LIB_CACHE.has(ckey):
		if glb_anim.has_animation_library("sdn"):
			glb_anim.remove_animation_library("sdn")
		glb_anim.add_animation_library("sdn", Data.LIB_CACHE[ckey])
		return true
	var lib := AnimationLibrary.new()
	# les préfixes Mixamo changent d'un fichier à l'autre (mixamorig_, mixamorig4_, mixamorig:) :
	# on relie les pistes aux os par la fin du nom (Hips, Spine, LeftArm…)
	var pre := RegEx.new()
	pre.compile("^mixamorig\\d*[_:]")
	var bmap := {}
	var hips := -1
	for bi in skel.get_bone_count():
		var bnm := skel.get_bone_name(bi)
		var suf := _bkey(bnm)
		bmap[suf] = bnm
		if suf == "Hips": hips = bi
	for key in Data.ANIMS.keys():
		if not key in ["Idle", "Walk", "Run", "Dance", "Fight", "Fall", "Talk", "Drink", "Phone", "Sit", "Surrender", "Punch", "Hit", "Block", "Shove", "Kneel", "DrunkWalk", "Kick", "Headbutt", "Cheer", "Smoke", "Lean", "GetUp", "Wave", "DrunkIdle"]: continue
		var a: Animation = Data.ANIMS[key].duplicate(true)
		var loop: bool = not key in ["Fall", "Punch", "Hit", "Shove", "Kick", "Headbutt", "GetUp"]
		a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
		# échelle des déplacements : hauteur des hanches du personnage / hauteur des hanches dans l'animation
		var ratio := 1.0
		var drop := []
		for t in a.get_track_count():
			var np: NodePath = a.track_get_path(t)
			var bone := str(np.get_concatenated_subnames())
			if bone == "" and np.get_name_count() > 0:
				bone = str(np.get_name(np.get_name_count() - 1))
			if bone == "": continue
			var target: String = bmap.get(pre.sub(bone.replace(":", "_"), ""), "")
			if target == "":
				drop.append(t)
				continue
			a.track_set_path(t, NodePath(skel_path + ":" + target))
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and _bkey(target) == "Hips" and a.track_get_key_count(t) > 0 and hips >= 0:
				var v0: Vector3 = a.track_get_key_value(t, 0)
				var rest_y: float = skel.get_bone_rest(hips).origin.y
				if absf(v0.y) > 0.0001 and absf(rest_y) > 0.0001:
					ratio = rest_y / v0.y
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k) * ratio
					# marche « sur place » : on bloque le déplacement horizontal des hanches
					if loop: v = Vector3(v0.x * ratio, v.y, v0.z * ratio)
					a.track_set_key_value(t, k, v)
			elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				# les autres os ne bougent pas en translation : on garde la pose du personnage
				drop.append(t)
		drop.reverse()
		for t in drop:
			a.remove_track(t)
		lib.add_animation(key, a)
	if glb_anim.has_animation_library("sdn"):
		glb_anim.remove_animation_library("sdn")
	glb_anim.add_animation_library("sdn", lib)
	Data.LIB_CACHE[ckey] = lib
	return true

## Action ponctuelle (coup, poussée, réaction…) : animation Mixamo si elle existe, sinon pose simple
func act(n: String, dur: float) -> void:
	act_name = n
	act_until = Time.get_ticks_msec() / 1000.0 + dur
	cur_clip = ""
	if glb == null:
		match n:
			"Punch": set_pose({"arm_r": -1.6, "lean": 0.3}, dur)
			"Shove": set_pose({"arm_l": -1.5, "arm_r": -1.5, "lean": 0.25}, dur)
			"Grab": set_pose({"arm_l": -1.25, "arm_r": -1.25, "lean": 0.2}, dur)
			"Hit": set_pose({"lean": -0.45, "arm_l": -0.3, "arm_r": -0.3}, dur)
			"Windup": set_pose({"arm_r": 0.9, "arm_l": -1.4, "lean": -0.25}, dur)
			"Block": set_pose({"arm_l": -2.7, "arm_r": -2.5, "lean": 0.1}, dur)
			"Verbal": set_pose({"arm_r": -1.2, "arm_l": -0.4}, dur)

## Petite étiquette au-dessus de la tête (nom, agitation…)
func set_tag(txt: String, col := Color.WHITE) -> void:
	if txt == "":
		if tag != null: tag.visible = false
		return
	if tag == null:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = true
		tag.pixel_size = 0.0012
		tag.font_size = 28
		tag.outline_size = 8
		tag.position = Vector3(0, height + 0.35, 0)
		add_child(tag)
	tag.visible = true
	tag.text = txt
	tag.modulate = col

func set_pose(p: Dictionary, dur: float) -> void:
	pose = p
	pose_until = Time.get_ticks_msec() / 1000.0 + dur

func walk_to(pts: Array, cb = null) -> void:
	path = pts.duplicate()
	on_arrive = cb
	anim = "walk"

func turn_to(a: float, b: float, k: float) -> float:
	var d := wrapf(b - a, -PI, PI)
	return a + d * clamp(k, 0.0, 1.0)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# suivi de chemin
	if path.size() > 0 and path[0] is Vector3:
		# passage d'une porte : on réapparaît de l'autre côté
		var tp: Vector3 = path.pop_front()
		position.x = tp.x; position.z = tp.z
		if path.is_empty() and on_arrive != null:
			var cb0 = on_arrive
			on_arrive = null
			if cb0 is Callable and cb0.is_valid(): cb0.call(self)
	if path.size() > 0:
		var q = path[0]
		var dx: float = q.x - position.x
		var dz: float = q.y - position.z
		var d := sqrt(dx * dx + dz * dz)
		var sp := speed * (2.0 if run else 1.0) * delta
		if d <= sp:
			position.x = q.x; position.z = q.y
			path.pop_front()
			if path.is_empty():
				if anim == "walk": anim = "idle"
				if face != null:
					yaw = face; face = null
				var cb = on_arrive
				on_arrive = null
				if cb != null and cb is Callable and cb.is_valid():
					cb.call(self)
		else:
			position.x += dx / d * sp
			position.z += dz / d * sp
			yaw = turn_to(yaw, atan2(dx, dz), delta * 8.0)
			walk_ph += sp * 5.2
	rotation.y = yaw
	position.y = Data.ground.call(position.x, position.z)
	if glb != null:
		_anim_glb()
		return
	_anim_prim(t)

func _anim_glb() -> void:
	if glb_anim == null: return
	var now := Time.get_ticks_msec() / 1000.0
	if now < act_until:
		var alt := {"Windup": ["Punch", "Fight"], "Grab": ["Shove", "Punch", "Fight"], "Shove": ["Shove", "Punch"], "Verbal": ["Talk"], "Block": ["Block", "Fight"], "Hit": ["Hit"], "Punch": ["Punch"], "Kick": ["Kick", "Punch"], "Headbutt": ["Headbutt", "Punch"], "GetUp": ["GetUp", "Idle"], "Wave": ["Wave", "Talk"]}
		for n2 in alt.get(act_name, [act_name]):
			var f2: String = "sdn/" + n2
			if glb_anim.has_animation(f2):
				if cur_clip != f2:
					cur_clip = f2
					glb_anim.play(f2, 0.08)
				_ground()
				return
	var wanted := {"kneel": ["Kneel", "Sit", "Idle"], "walk": ["Walk"], "dance": ["Dance", "Idle"], "fight": ["Fight", "Idle"], "fallen": ["Fall"], "sit": ["Sit", "Idle"],
		"drink": ["Drink", "Talk", "Idle"], "talk": ["Talk", "Idle"], "phone": ["Phone", "Talk", "Idle"], "raise": ["Surrender", "Idle"], "idle": ["Idle"],
		"smoke": ["Smoke", "Phone", "Idle"], "lean": ["Lean", "Idle"], "cheer": ["Cheer", "Dance", "Idle"]}
	var list: Array = wanted.get(anim, ["Idle"])
	if run and anim == "walk": list = ["Run", "Walk"]
	elif anim == "walk" and sway > 0.5: list = ["DrunkWalk", "Walk"]
	elif anim == "idle" and sway > 0.5: list = ["DrunkIdle", "Idle"]
	elif anim == "dance" and int(ph * 10.0) % 3 == 0: list = ["Cheer", "Dance", "Idle"]
	for n in list:
		var full: String = "sdn/" + n
		if glb_anim.has_animation(full):
			if cur_clip != full:
				cur_clip = full
				glb_anim.play(full, 0.25)
				glb_anim.seek(randf() * 0.5 if n != "Fall" else 0.0)
			break
	_ground()
	# légère titubation des personnes ivres
	if sway > 0.0:
		glb.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * 1.6 + ph) * 0.1 * sway

## Recale le modèle pour que le pied le plus bas touche le sol (corrige les tailles de squelette différentes)
func _ground() -> void:
	if skel_ref == null or foot_ids.is_empty() or not is_inside_tree(): return
	var low := INF
	for bi in foot_ids:
		var gp: Vector3 = (skel_ref.global_transform * skel_ref.get_bone_global_pose(bi)).origin
		low = min(low, gp.y)
	if low == INF: return
	var err: float = (low - global_position.y) - foot_h
	if absf(err) > 0.25:
		glb.position.y -= err
	else:
		glb.position.y -= err * 0.25

func _anim_prim(t: float) -> void:
	var leg := 0.0; var arm := 0.0; var bob := 0.0; var lean := 0.0; var roll := 0.0
	var arm_l = null; var arm_r = null
	match anim:
		"walk":
			leg = sin(walk_ph) * 0.55; arm = -leg * 0.8; bob = abs(cos(walk_ph)) * 0.03
		"dance":
			var s := sin(t * 4.2 + ph)
			bob = abs(s) * 0.09; arm_l = -2.5 + s * 0.4; arm_r = -2.5 - s * 0.4; leg = s * 0.15; roll = sin(t * 2.1 + ph) * 0.06
		"fight":
			var s2 := sin(t * 9.0 + ph)
			arm_l = -1.5 + max(0.0, s2) * 0.4; arm_r = -1.5 + max(0.0, -s2) * 0.4; lean = 0.18; bob = abs(s2) * 0.03; leg = 0.15
		"drink":
			arm_r = -1.9 + sin(t * 0.7 + ph) * 0.25; arm_l = -0.1
		"talk":
			arm_r = -0.6 + sin(t * 3.0 + ph) * 0.4; arm_l = -0.1
		"phone":
			arm_r = -2.6; arm_l = -0.1
		"raise":
			arm_l = -2.9; arm_r = -2.9
	if t < pose_until:
		if pose.has("arm_l"): arm_l = pose["arm_l"]
		if pose.has("arm_r"): arm_r = pose["arm_r"]
		if pose.has("lean"): lean = pose["lean"]
		if pose.has("leg"): leg = pose["leg"]
	if sway > 0.0:
		roll += sin(t * 1.6 + ph) * 0.12 * sway
	var k := height / 1.75
	if anim == "fallen":
		body.position = Vector3(0, 0.14, 0.9 * k)
		body.rotation = Vector3(-PI / 2, 0, 0)
	elif anim == "sit" or anim == "kneel":
		body.position = Vector3(0, -0.42 * k, 0)
		body.rotation = Vector3.ZERO
	else:
		body.position = Vector3(0, bob, 0)
		body.rotation = Vector3(0, 0, roll)
	var seated := anim == "sit" or anim == "kneel"
	var sit_l := -1.45 if seated else 0.0
	legs[0].rotation.x = sit_l if seated else -leg
	legs[1].rotation.x = sit_l if seated else leg
	torso.rotation.x = lean
	arms[0].rotation = Vector3(arm_l if arm_l != null else -arm, 0, -0.08)
	arms[1].rotation = Vector3(arm_r if arm_r != null else arm, 0, 0.08)
