extends Node
## Premiers secours pas à pas (gestes du PSC1) sur les incidents médicaux :
## protéger, examiner, agir, alerter le 15, surveiller. Chaque choix est jugé.

const WorldScript = preload("res://scripts/world.gd")

var game
var inc: Dictionary = {}
var prof := ""
var steps: Array = []
var si := 0
var score := 0
var errs: Array = []      # [texte de l'erreur, loi / règle]
var oks: Array = []

const PROF := {"malaise": "inconscient", "coma": "inconscient", "ghb": "inconscient", "ghbhomme": "inconscient",
	"arret": "arret", "epilepsie": "convulsions", "overdose": "convulsions", "allergie": "allergie",
	"chaleur": "conscient", "angoisse": "conscient", "badtrip": "conscient", "verre": "hemorragie", "chute": "trauma", "podium": "trauma"}

static func has_protocol(ty: String) -> bool:
	return PROF.has(ty)

func start(i: Dictionary) -> void:
	inc = i
	prof = PROF[i["ty"]]
	si = 0
	score = 0
	errs = []
	oks = []
	steps = _build_steps()
	for a in inc["actors"]:
		if is_instance_valid(a): a.anim = "fallen" if prof in ["inconscient", "arret", "convulsions", "trauma"] else "kneel"
	_show()

func _step(title: String, situ: String, opts: Array) -> Dictionary:
	return {"t": title, "s": situ, "o": opts}

## Chaque option : [texte, points, erreur (vide si correct), loi/règle]
func _build_steps() -> Array:
	var st := []
	var deplace_mal: bool = prof in ["inconscient", "arret", "convulsions", "trauma", "hemorragie"]
	st.append(_step("1. Protéger", "Des clients s'agglutinent, la musique est forte, il y a du verre au sol.", [
		["Faire écarter les curieux, faire rallumer la lumière et baisser la musique, dégager le verre", 2, "", ""],
		["Te précipiter sur la personne sans regarder autour", -1, "Pas de protection de la zone : risque de sur-accident (verre, bousculade).", "Premier geste du secouriste : protéger la victime, les témoins et soi-même."],
		["La porter dehors pour qu'elle prenne l'air", -3 if deplace_mal else 0, "Victime déplacée sans nécessité." if deplace_mal else "", "On ne déplace une victime qu'en cas de danger immédiat et impossible à écarter."]]))
	match prof:
		"inconscient":
			st.append(_step("2. Examiner", "Tu lui parles fort et lui demandes de serrer ta main : aucune réaction. Tu bascules sa tête en arrière, tu regardes et écoutes 10 secondes : sa poitrine se soulève, elle respire.", [
				["La mettre en position latérale de sécurité (PLS)", 3, "", ""],
				["La laisser sur le dos en attendant", -3, "Personne inconsciente laissée sur le dos.", "Sur le dos, une personne inconsciente peut s'étouffer avec sa langue ou ses vomissements : PLS."],
				["L'asseoir contre le mur et lui tapoter les joues", -2, "Personne inconsciente assise.", "Assise, sa tête retombe et ses voies aériennes se ferment : PLS."],
				["Lui jeter de l'eau froide pour la réveiller", -2, "Tentative de « réveil » inutile.", "On ne cherche pas à réveiller : on protège sa respiration (PLS) et on alerte."]]))
		"arret":
			st.append(_step("2. Examiner", "Aucune réaction quand tu lui parles. Tête basculée en arrière, tu regardes 10 secondes : pas de respiration, seulement un hoquet irrégulier.", [
				["Faire appeler le 15 et apporter le défibrillateur, commencer tout de suite le massage cardiaque", 4, "", ""],
				["La mettre en PLS", -4, "Arrêt cardiaque pris pour un simple malaise.", "Une respiration absente ou anormale (gasps) = arrêt cardiaque : massage + défibrillateur immédiatement."],
				["Attendre les secours en surveillant", -4, "Aucun massage pendant l'arrêt cardiaque.", "Chaque minute sans massage fait perdre environ 10 % de chances de survie."]]))
		"convulsions":
			st.append(_step("2. Agir pendant la crise", "Il est au sol et convulse violemment, la tête cogne par terre.", [
				["Écarter ce qui l'entoure, protéger sa tête (veste pliée), regarder l'heure, ne pas le tenir", 3, "", ""],
				["Le maintenir fermement au sol pour arrêter la crise", -3, "Personne en convulsions maintenue de force.", "On ne bloque jamais les mouvements : risque de fractures et de blessures."],
				["Lui mettre quelque chose entre les dents", -3, "Objet mis dans la bouche.", "Il ne peut pas « avaler sa langue » : un objet dans la bouche casse des dents ou étouffe."]]))
			st.append(_step("3. Après la crise", "Les convulsions s'arrêtent au bout de deux minutes. Il ne répond pas mais respire, bruyamment.", [
				["Le mettre en PLS et surveiller sa respiration", 3, "", ""],
				["L'aider à se relever pour le faire marcher", -3, "Personne relevée juste après une crise.", "Après une crise, la personne reste inconsciente ou confuse : PLS et surveillance."]]))
		"allergie":
			st.append(_step("2. Examiner et agir", "Elle est consciente mais respire mal, ses lèvres gonflent, des plaques rouges apparaissent. Son amie dit qu'elle est allergique aux arachides et qu'elle a un stylo d'adrénaline dans son sac.", [
				["L'aider à s'injecter le stylo d'adrénaline et l'installer assise, penchée en avant pour respirer", 4, "", ""],
				["L'allonger à plat sur le dos", -2, "Personne qui étouffe allongée à plat.", "Une personne consciente qui respire mal s'installe assise ou demi-assise."],
				["Lui donner un grand verre d'eau", -2, "Boisson donnée à une personne qui étouffe.", "On ne fait rien boire à une personne qui a du mal à respirer ou à avaler."]]))
		"conscient":
			st.append(_step("2. Examiner et agir", "Consciente, pâle, en sueur, elle tremble et dit qu'elle se sent très mal.", [
				["L'installer au calme, assise, desserrer ses vêtements, lui parler doucement, lui faire boire de l'eau par petites gorgées", 3, "", ""],
				["La laisser seule aux toilettes le temps que ça passe", -3, "Personne malade laissée seule.", "On ne laisse jamais seule une personne qui fait un malaise : son état peut s'aggraver d'un coup."],
				["Lui proposer un café bien serré ou un verre pour se remettre", -2, "Stimulant ou alcool proposé.", "Ni alcool ni excitant : de l'eau, du calme, et l'avis du 15."]]))
		"hemorragie":
			st.append(_step("2. Arrêter le saignement", "Il s'est profondément coupé à l'avant-bras sur un verre brisé : le sang coule en continu.", [
				["Mettre des gants, appuyer fort et sans relâcher sur la plaie avec un linge propre, l'allonger", 3, "", ""],
				["Lui faire un garrot avec ta ceinture tout de suite", -1, "Garrot posé d'emblée.", "La compression directe arrête presque tous les saignements ; le garrot est le dernier recours."],
				["L'envoyer rincer la plaie aux toilettes", -2, "Saignement abondant non comprimé.", "Un saignement abondant se comprime immédiatement ; on ne laisse pas la victime partir seule."]]))
		"trauma":
			st.append(_step("2. Examiner", "Il est tombé de haut. Il est conscient mais se plaint du cou et du dos, il a des fourmillements dans les mains.", [
				["Lui dire de ne pas bouger et lui maintenir la tête dans l'axe, à deux mains", 3, "", ""],
				["L'aider à se relever doucement", -3, "Victime d'une chute relevée.", "Douleur du cou et fourmillements = atteinte possible de la colonne : on ne bouge pas la victime."],
				["Le porter sur une banquette pour qu'il soit mieux", -3, "Victime d'une chute déplacée.", "Le moindre mouvement peut aggraver une lésion de la moelle épinière."]]))
	var call_bad := -4
	var call_txt := "Non-assistance à personne en danger (art. 223-6 Code pénal)."
	if prof == "conscient":
		call_bad = -2
		call_txt = "En cas de doute, le 15 donne un avis médical gratuit : on appelle."
	st.append(_step("Alerter", "Il faut prévenir les secours.", [
		["Appeler le 15 et donner un bilan précis : âge, conscience, respiration, ce qui s'est passé, adresse exacte et accès", 3, "", ""],
		["Appeler le 15 en disant juste « venez vite, quelqu'un fait un malaise »", 1, "Alerte imprécise.", "Le bilan (conscience, respiration, circonstances, adresse) permet d'envoyer les bons moyens tout de suite."],
		["Ne pas appeler : ses amis vont le ramener chez lui", call_bad, "Secours non appelés.", call_txt]]))
	var sv := [["Rester à côté jusqu'aux secours, la couvrir, revérifier sa respiration, envoyer quelqu'un accueillir les secours à l'entrée", 3, "", ""],
		["La confier à ses amis et reprendre ta ronde", -3, "Victime laissée sans surveillance.", "L'état d'une victime change vite : on la surveille jusqu'à l'arrivée des secours."],
		["La faire sortir dans la rue pour attendre l'ambulance au frais", -2, "Victime déplacée dehors.", "On attend les secours là où la victime est protégée, sans la déplacer."]]
	if inc["ty"] in ["ghb", "ghbhomme"]:
		sv.append(["Rester avec elle, mettre son verre de côté et noter les témoins pour la police (soupçon de soumission chimique)", 5, "", ""])
	st.append(_step("Surveiller", "En attendant les secours…", sv))
	return st

func _show() -> void:
	var stp: Dictionary = steps[si]
	var d: Dictionary = Data.INC[inc["ty"]]
	var order := range(stp["o"].size())
	order.shuffle()
	var bts := []
	for oi in order:
		var idx: int = oi
		bts.append({"t": stp["o"][idx][0], "cb": func(): _pick(idx)})
	var body := "[color=#b9b3cc]%s[/color]\n\n%s" % [Data.clean(d["t"]), stp["s"]]
	game.ui.open_panel("Premiers secours — " + stp["t"], "Étape %d sur %d" % [si + 1, steps.size()], body, bts)

func _pick(idx: int) -> void:
	var o: Array = steps[si]["o"][idx]
	score += int(o[1])
	if o[2] != "": errs.append([o[2], o[3]])
	elif int(o[1]) > 0: oks.append(o[0])
	si += 1
	if si < steps.size():
		_show()
	else:
		_finish()

func _finish() -> void:
	var d: Dictionary = Data.INC[inc["ty"]]
	var mx := 0
	for s in steps:
		var best := 0
		for o in s["o"]: best = maxi(best, int(o[1]))
		mx += best
	var ratio: float = float(score) / maxf(1.0, mx)
	var txt := ""
	var col := "#9fe0b4"
	if prof == "arret":
		var dae: bool = Data.CAR == null or game.career.eq("dae")
		if ratio > 0.8 and dae:
			txt = "Le défibrillateur délivre un choc, tu reprends le massage : le cœur repart avant l'arrivée du SMUR. Il est transporté en réanimation, vivant."
		elif ratio > 0.8:
			txt = "Massage ininterrompu jusqu'aux pompiers, mais sans défibrillateur dans l'établissement. Le SMUR récupère un pouls, pronostic très réservé."
			col = "#ffd27a"
			if Data.CAR != null: errs.append(["Pas de défibrillateur dans l'établissement.", "DAE obligatoire dans les ERP de catégories 1 à 4 (décret n° 2018-1186)."])
		else:
			txt = "Les secours arrivent trop tard pour le sauver."
			col = "#ff8a8a"
	elif ratio > 0.8:
		txt = "Le SAMU arrive et prend le relais : grâce à tes gestes, la victime est stable et transportée à l'hôpital."
	elif ratio > 0.45:
		txt = "La victime est prise en charge, mais certains gestes ont fait perdre du temps ou pris des risques."
		col = "#ffd27a"
	else:
		txt = "Son état s'aggrave avant l'arrivée des secours : elle part en urgence absolue."
		col = "#ff8a8a"
	var ds := score * 1.2 - 4.0
	var dr := 2.0 if ratio > 0.8 else (-2.0 if ratio < 0.45 else 0.0)
	game.secu += ds
	game.rep += dr
	game._clampg()
	for e in errs:
		game._fault("%s (premiers secours) : %s" % [Data.clean(d["t"]), e[0]], e[1])
	if ratio > 0.8:
		game._good("%s : premiers secours bien menés, 15 alerté avec un bilan." % Data.clean(d["t"]))
		if Data.CAR != null: game.career.trophy("secours")
	game._mc("%s (%s) : premiers secours, %d/%d" % [Data.clean(d["t"]), WorldScript.ZLBL[inc["z"]], maxi(0, score), mx])
	game._set_radio("Toi : « Victime prise en charge par le SAMU. »")
	inc["st"] = "done"
	for a in inc["actors"]:
		if is_instance_valid(a): game._free_later(a, 25.0)
	inc["actors"] = []
	game._end_inc(inc)
	var body := "[color=%s]%s[/color]\n\n" % [col, txt]
	if oks.size() > 0:
		body += "[b]Bons gestes[/b]\n"
		for k in oks: body += "[color=#9fe0b4]• %s[/color]\n" % k
	if errs.size() > 0:
		body += "\n[b]Erreurs[/b]\n"
		for e in errs: body += "[color=#ff8a8a]• %s[/color]\n[color=#b9b3cc][i]%s[/i][/color]\n" % [e[0], e[1]]
	body += "\n[color=#b9b3cc]Score : %d / %d · Formation conseillée : PSC1 (7 h, ouverte à tous)[/color]" % [maxi(0, score), mx]
	game.ui.open_panel("Premiers secours — bilan", "", body, [{"t": "Continuer la ronde", "k": "main", "cb": game._close_panel}])
