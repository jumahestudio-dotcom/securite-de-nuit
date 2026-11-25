extends Node
## Parler aux gens : collègues, barmans, DJ, clients. Les clients viennent aussi te voir
## d'eux-mêmes avec leurs problèmes. Chaque réponse est une décision jugée.

const WorldScript = preload("res://scripts/world.gd")

var game
var cut_until := 0.0          # musique coupée à la demande (DJ)
var approach = null           # client qui marche vers toi pour te parler
var approach_t := 40.0
var asked_ev := {}            # demandes déjà faites cette nuit
var pauses := {}              # collègues qui ont eu leur pause
var on_break := {}            # collègue -> fin de pause
var phone_t := 70.0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _btn(t: String, cb: Callable, k := "") -> Dictionary:
	return {"t": t, "k": k, "cb": cb}

## Qui est devant toi (à portée de voix) ?
func who_near():
	var P: Vector3 = game.player.position
	var f := Vector3(sin(game.cam_yaw), 0, cos(game.cam_yaw))
	var best = null
	var bd := 2.0
	var lst: Array = []
	lst.append_array(game.colleagues)
	lst.append_array(game.life.barmen)
	if game.life.dj != null: lst.append(game.life.dj)
	if game.phase == "salle": lst.append_array(game.crowd)
	for n in lst:
		if not is_instance_valid(n) or not n.visible: continue
		var dv: Vector3 = n.position - P
		dv.y = 0
		var d := dv.length()
		if d > bd: continue
		if d > 0.8 and dv.normalized().dot(f) < 0.2: continue
		bd = d; best = n
	return best

func label_for(n) -> String:
	if n in game.colleagues: return "Parler à " + n.pname
	if n in game.life.barmen: return "Parler au barman"
	if n == game.life.dj: return "Parler au DJ"
	if n.data != null: return "Parler à " + n.data["first"]
	return "Parler au client"

func open_for(n) -> void:
	n.yaw = atan2(game.player.position.x - n.position.x, game.player.position.z - n.position.z)
	if n in game.colleagues: colleague(n)
	elif n in game.life.barmen: barman(n)
	elif n == game.life.dj: dj(n)
	else: client(n)

func _say(title: String, txt: String) -> void:
	game.ui.open_panel(title, "", txt, [_btn("Continuer", game._close_panel, "main")])

# =====================================================================
#  COLLÈGUES
# =====================================================================
func colleague(a) -> void:
	var nm: String = a.pname
	var body := ""
	var bts := []
	if a.has_meta("phone_bad"):
		body = "[b]%s[/b] est sur son téléphone depuis plusieurs minutes, dos à la salle." % nm
		bts.append(_btn("Le prendre à part et lui rappeler calmement la consigne", func(): _recadre(a, 0)))
		bts.append(_btn("L'engueuler devant les clients", func(): _recadre(a, 1)))
		bts.append(_btn("Laisser faire, il a le droit de souffler", func(): _recadre(a, 2)))
		bts.shuffle()
		game.ui.open_panel(nm, "Collègue", body, bts)
		return
	body = "%s : « %s »" % [nm, ["Ça va, c'est calme de mon côté.", "Grosse ambiance ce soir.", "Je garde un œil sur le bar.", "Ça commence à boire sec."].pick_random()]
	if on_break.has(nm): body = "%s est en pause." % nm
	bts.append(_btn("Faire le point sur sa zone", func(): _report(a)))
	if not pauses.has(nm) and not on_break.has(nm) and game.phase == "salle":
		bts.append(_btn("Lui accorder sa pause (20 min)", func(): _pause(a)))
	var row := []
	for z in ["hall", "piste", "bar", "fumoir"]:
		if not game.world.ZR.has(z): continue
		var zz: String = z
		row.append({"t": WorldScript.ZLBL[z], "k": "cy", "cb": func(): _post(a, zz)})
	bts.append({"t": "Le placer en poste :", "off": true})
	bts.append({"row": row})
	bts.append(_btn("Retour", game._close_panel))
	game.ui.open_panel(nm, "Collègue · " + ("en pause" if on_break.has(nm) else "en poste"), body, bts)

func _report(a) -> void:
	var hz: String = game.world.region(a.home.x, a.home.z)
	for i in game.incs:
		if i.get("hidden", false) and i["st"] == "open" and i["p"].distance_to(a.home) < 12.0:
			i["hidden"] = false
			if is_instance_valid(i.get("mk")): i["mk"].visible = true
			game._good("Point avec %s : %s signalé." % [a.pname, Data.clean(Data.INC[i["ty"]]["t"]).to_lower()])
			_say(a.pname, "%s : « Justement, il y a un truc qui me gêne côté %s : %s. Je n'osais pas quitter mon poste. »" % [a.pname, WorldScript.ZLBL[i["z"]].to_lower(), Data.clean(Data.INC[i["ty"]]["t"]).to_lower()])
			return
	var c = _pick_drunk()
	if c != null and randf() < 0.6:
		_flag_drunk(c)
		_say(a.pname, "%s : « Le client que je te montre là-bas commence à être bien chargé. Je l'ai à l'œil. »" % a.pname)
		return
	_say(a.pname, "%s : « RAS de mon côté%s. »" % [a.pname, " (zone : %s)" % hz if hz != "main" else ""])

func _pause(a) -> void:
	var nm: String = a.pname
	pauses[nm] = true
	on_break[nm] = _now() + 28.0
	a.task = {"pause": true}
	a.walk_to(game.world.route(a.position, Vector3(-2.0, 0, -4.5)))
	game._good("Pause accordée à %s." % nm)
	if Data.CAR != null: Data.CAR["morale"] = minf(100.0, float(Data.CAR["morale"]) + 2.0)
	_say(nm, "%s : « Merci, j'en avais besoin. Je reviens dans 20 minutes. »\n\n[color=#b9b3cc][i]Code du travail : au moins 20 minutes de pause dès 6 heures de travail (art. L3121-16).[/i][/color]" % nm)

func _post(a, z: String) -> void:
	a.home = game.world.zpt(z)
	if a.task == null: a.walk_to(game.world.route(a.position, a.home))
	game._close_panel()
	game._set_radio("%s : « Bien reçu, je me mets côté %s. »" % [a.pname, WorldScript.ZLBL[z].to_lower()])

func _recadre(a, k: int) -> void:
	a.remove_meta("phone_bad")
	a.anim = "idle"
	match k:
		0:
			game._good("Collègue recadré calmement, à l'écart des clients.")
			_say(a.pname, "%s : « T'as raison, désolé. Je range ça. »" % a.pname)
		1:
			game.rep -= 3
			if Data.CAR != null: Data.CAR["morale"] = maxf(0.0, float(Data.CAR["morale"]) - 6.0)
			game._fault("Collègue humilié devant les clients.", "On recadre en privé : le faire en public abîme l'autorité de toute l'équipe et le moral.")
			_say(a.pname, "%s range son téléphone, vexé. Des clients ont tout vu." % a.pname)
		2:
			game.secu -= 3
			game._fault("Agent sur son téléphone en poste, laissé faire.", "Un agent qui ne regarde pas sa zone, c'est une zone sans surveillance.")
			_say(a.pname, "%s continue de scroller." % a.pname)
	game._clampg()

# =====================================================================
#  BARMAN ET DJ
# =====================================================================
func barman(b) -> void:
	var bts := [
		_btn("« Qui a trop bu ce soir ? »", func(): _bar_drunk()),
		_btn("« Tu as vu passer quelque chose de louche ? »", func(): _bar_seen()),
		_btn("Lui demander un verre d'eau", func(): _say("Barman", "Il te tend un verre d'eau fraîche. Ça fait du bien.")),
		_btn("Boire un shot avec lui, vite fait", func(): _bar_shot()),
		_btn("Retour", game._close_panel)]
	game.ui.open_panel("Barman", "Derrière le comptoir", "« Ça va chef ? Qu'est-ce que je te sers ? »", bts)

func _bar_drunk() -> void:
	var c = _pick_drunk()
	if c == null:
		_say("Barman", "« Franchement, ça va pour l'instant. »")
		return
	_flag_drunk(c)
	var stop := func():
		game._good("Barman prévenu de ne plus servir un client manifestement ivre.")
		_say("Barman", "« OK, je ne le sers plus, je lui propose de l'eau. »\n\n[color=#b9b3cc][i]Code de la santé publique : il est interdit de servir de l'alcool à une personne manifestement ivre.[/i][/color]")
	var let := func():
		game.secu -= 3
		game._fault("Client ivre resservi au bar.", "Servir une personne manifestement ivre est interdit (Code de la santé publique) et l'exploitant en est responsable.")
		_say("Barman", "« Ça marche, c'est lui qui paye. » Le client commande une autre tournée.")
	game.ui.open_panel("Barman", "", "« Celui-là, je l'ai servi cinq fois. Il ne tient plus debout. » (signalé en orange)", [
		_btn("« Tu arrêtes de le servir, propose-lui de l'eau. Je vais le voir. »", stop, "ok"),
		_btn("« Tant qu'il paye… »", let, "bad")])

func _bar_seen() -> void:
	for i in game.incs:
		if i.get("hidden", false) and i["st"] == "open":
			i["hidden"] = false
			if is_instance_valid(i.get("mk")): i["mk"].visible = true
			game._good("Information du barman : %s." % Data.clean(Data.INC[i["ty"]]["t"]).to_lower())
			_say("Barman", "« Ouais… côté %s, %s. Je voulais t'en parler. »" % [WorldScript.ZLBL[i["z"]].to_lower(), Data.clean(Data.INC[i["ty"]]["t"]).to_lower()])
			return
	_say("Barman", "« Rien de spécial. Je te fais signe s'il y a un souci. »")

func _bar_shot() -> void:
	game.secu -= 5; game.rep -= 3
	game._clampg()
	game._fault("Alcool bu pendant le service.", "Un agent de sécurité ne boit pas en service : vigilance, image de l'établissement, et faute grave au regard de son contrat.")
	_say("Barman", "Le shot brûle un peu. Moussa t'a vu faire et secoue la tête.")

func dj(d) -> void:
	var cut := func():
		var viol := false
		for i in game.incs:
			if (i["st"] == "open" or i["st"] == "fight") and game._is_viol(i["ty"]): viol = true
		if viol:
			game.secu += 4
			game._good("Musique coupée et lumière rallumée pour casser une bagarre.")
			cut_until = _now() + 12.0
			_say("DJ", "Le son s'arrête, la lumière monte : tout le monde se fige, ça calme net.")
		else:
			game.rep -= 3
			_say("DJ", "Le son coupe sans raison : la salle siffle. « Tu me fais quoi, là ? »")
		game._clampg()
	var annonce := func():
		game.rep += 1
		game._clampg()
		_say("DJ", "Au micro : « On fume dehors, on prend soin les uns des autres, et pensez à l'eau gratuite au bar ! »")
	game.ui.open_panel("DJ", "Cabine", "« Yo ! Tu veux quoi ? »", [
		_btn("Couper la musique et rallumer (pour calmer une bagarre)", cut),
		_btn("Faire passer un message de prévention au micro", annonce),
		_btn("Retour", game._close_panel)])

# =====================================================================
#  CLIENTS
# =====================================================================
func _prof(n) -> Dictionary:
	if n.data != null:
		return {"iv": int(n.data.get("iv", 0)) + (1 if n.has_meta("drunk_flag") else 0), "name": n.data["first"], "data": true}
	if not n.has_meta("prof"):
		n.set_meta("prof", {"iv": [0, 0, 1, 1, 2].pick_random(), "name": (Data.PREN_H + Data.PREN_F).pick_random(), "data": false})
	var p: Dictionary = n.get_meta("prof")
	if n.has_meta("drunk_flag"): p["iv"] = 2
	return p

func client(n) -> void:
	var p := _prof(n)
	var iv: int = mini(2, int(p["iv"]))
	var cue: String = ["Paraît en forme, sourit.", "Rit fort, verre à la main, haleine alcoolisée.", "Titube, s'accroche à son ami, le regard dans le vague."][iv]
	var q: String = ["« Super soirée ! »", "« Ça va chef ? Tu bois un coup ? »", "« Ch'uis… ch'uis bien… t'inquiète… »"][iv]
	var bts := [_btn("Discuter deux minutes", func(): _chat(n))]
	if iv >= 2:
		bts.append(_btn("Lui proposer de l'eau et l'éthylotest de l'établissement, vérifier qu'il ne conduit pas", func(): _drunk_care(n, 0), "ok"))
		bts.append(_btn("Le raccompagner dehors avec ses amis, taxi appelé", func(): _drunk_care(n, 1)))
		bts.append(_btn("Le mettre dehors seul, il n'avait qu'à moins boire", func(): _drunk_care(n, 2), "bad"))
	bts.append(_btn("Lui demander poliment d'ouvrir son sac (il peut refuser)", func(): _bag(n, false)))
	bts.append(_btn("Fouiller son sac sans lui demander", func(): _bag(n, true), "bad"))
	if n.data != null:
		bts.append(_btn("Le faire sortir (exclusion)", func(): game.sel_npc = n; game._exclude(), "bad"))
	bts.append(_btn("Laisser", game._close_panel))
	game.sel_npc = n
	game.ui.open_panel(p["name"], "Client · zone " + WorldScript.ZLBL.get(n.zone, ""), "• %s\n\n[i]%s[/i]" % [cue, q], bts)

func _chat(n) -> void:
	game.rep += 1
	game._clampg()
	for i in game.incs:
		if i.get("hidden", false) and i["st"] == "open" and randf() < 0.6:
			i["hidden"] = false
			if is_instance_valid(i.get("mk")): i["mk"].visible = true
			game._good("Un client a signalé : %s." % Data.clean(Data.INC[i["ty"]]["t"]).to_lower())
			_say("Discussion", "« Au fait… y a un truc bizarre côté %s. Je sais pas si c'est grave. » (%s)" % [WorldScript.ZLBL[i["z"]].to_lower(), Data.clean(Data.INC[i["ty"]]["t"]).to_lower()])
			return
	_say("Discussion", ["« Elle est cool cette boîte, on se sent en sécurité. »", "« Le DJ est trop bien ce soir ! »", "« Vous faites des longues nuits, vous… respect. »", "« Il fait chaud sur la piste, hein ? »"].pick_random())

func _drunk_care(n, k: int) -> void:
	match k:
		0:
			game.secu += 3; game.rep += 2
			game._good("Client ivre pris en charge : eau, éthylotest, pas de volant.")
			_say("Prévention", "Il souffle : 1,1 g. « Ah ouais… je laisse la voiture. » Son ami appelle un VTC.\n\n[color=#b9b3cc][i]Les discothèques doivent mettre des éthylotests à disposition des clients (Code de la santé publique, art. L3341-4).[/i][/color]")
			n.remove_meta("drunk_flag")
			n.set_tag("")
		1:
			game.secu += 2
			game._good("Client ivre raccompagné dehors avec ses amis, taxi appelé.")
			game.life._leave(n)
			n.set_tag("")
			_say("Prévention", "Tu le raccompagnes calmement, ses amis le soutiennent jusqu'au taxi.")
		2:
			game.secu -= 4; game.rep -= 4
			game._fault("Client très ivre mis dehors seul.", "Laisser seule dans la rue une personne hors d'état de se protéger peut constituer une mise en danger ou une non-assistance (art. 223-6 Code pénal) : on la confie à ses amis, à un taxi ou aux secours.")
			game.life._leave(n)
			n.set_tag("")
			_say("Prévention", "Il part en zigzaguant vers la route, seul…")
	game._clampg()

func _bag(n, forced: bool) -> void:
	if forced:
		game.rep -= 5
		game._fault("Sac fouillé sans consentement.", "Seuls les officiers de police judiciaire peuvent fouiller un sac. Un agent peut seulement en demander l'ouverture, avec l'accord de la personne (art. L613-2 Code de la sécurité intérieure).")
		_say("Sac", "Le client hurle : « Vous avez pas le droit ! » Il filme la scène.")
	elif randf() < 0.7:
		game._good("Ouverture de sac demandée avec le consentement du client.")
		_say("Sac", "Il ouvre son sac de bonne grâce : portefeuille, chargeur, chewing-gums. Rien d'anormal.")
	else:
		_say("Sac", "« Non, j'ai pas envie. » C'est son droit. Tu restes attentif, sans insister.\n\n[color=#b9b3cc][i]Le refus n'est pas une preuve : sans consentement, pas d'inspection.[/i][/color]")
	game._clampg()

func _pick_drunk():
	var cand := []
	for n in game.crowd:
		if not is_instance_valid(n) or n.has_meta("drunk_flag"): continue
		if n.data != null and int(n.data.get("iv", 0)) >= 1: cand.append(n)
		elif n.data == null and randf() < 0.15: cand.append(n)
	return cand.pick_random() if cand.size() > 0 else null

func _flag_drunk(n) -> void:
	n.set_meta("drunk_flag", true)
	n.sway = maxf(n.sway, 0.8)
	n.set_tag("ivre", Color(1.0, 0.6, 0.15))

# =====================================================================
#  LES CLIENTS VIENNENT TE VOIR
# =====================================================================
const REQ := {
	"tel": {"t": "« Mon téléphone a disparu ! Quelqu'un me l'a volé, j'en suis sûre ! »", "o": [
		["Noter la description, passer l'info aux collègues à la radio, lui conseiller de porter plainte et de bloquer la ligne", 3, 2, "Vol signalé : description diffusée, plainte conseillée.", ""],
		["Fouiller les gens autour d'elle", -3, -5, "Fouille de clients sans pouvoir le faire.", "Un agent ne peut ni fouiller ni contraindre : seuls les policiers le peuvent."],
		["« C'est pas mon problème, fallait faire attention. »", 0, -4, "Victime de vol renvoyée sans aide.", "L'accueil et l'orientation des victimes font partie de la mission."]]},
	"amie": {"t": "« Ma copine ne va pas bien du tout, elle est aux toilettes, elle répond plus ! »", "o": [
		["« J'y vais tout de suite, montre-moi. » (et prévenir un collègue)", 2, 1, "Alerte d'une amie prise au sérieux immédiatement.", "", "malaise"],
		["« Donne-lui de l'eau, ça va passer. »", -3, -2, "Alerte de malaise minimisée.", "Une personne qui ne répond plus est une urgence : on y va et on évalue.", "malaise"]]},
	"colle": {"t": "« Un mec n'arrête pas de me coller sur la piste, il m'a touchée… »", "o": [
		["La mettre en sécurité près du bar, aller identifier l'homme, l'exclure, lui proposer de porter plainte", 4, 3, "Victime protégée, agresseur identifié et exclu.", "Un attouchement est une agression sexuelle (art. 222-22 Code pénal) : on protège, on écarte l'auteur, on oriente vers la plainte."],
		["« Change de coin, tu seras tranquille. »", -3, -5, "Agression signalée minimisée.", "Ce n'est pas à la victime de se déplacer : on intervient auprès de l'auteur."],
		["Aller lui mettre une gifle", -5, -4, "Violence sur un client sans légitime défense.", "Se faire justice soi-même = violences volontaires (art. 222-13)."]]},
	"pote": {"t": "« Mon pote attend dehors depuis une heure, tu peux le faire passer devant ? Allez… »", "o": [
		["« Désolé, il fait la queue comme tout le monde. »", 1, 0, "Pas de passe-droit à l'entrée.", ""],
		["« Allez, OK, dis-lui de venir. »", -2, -2, "Passe-droit à l'entrée.", "Faire passer quelqu'un sans contrôle, c'est un trou dans la sécurité (et la jauge)."],
		["« Pour 20 €, c'est faisable. »", -6, -6, "Argent accepté pour faire entrer quelqu'un.", "Monnayer l'entrée : faute grave, licenciement et retrait de la carte professionnelle (code de déontologie, CSI)."]]},
	"bakchich": {"t": "Il glisse un billet de 50 € : « Ferme les yeux si mon pote fume un joint au fumoir, OK ? »", "o": [
		["Refuser le billet fermement et rappeler que c'est interdit ici", 3, 1, "Tentative de corruption refusée.", ""],
		["Prendre le billet", -8, -6, "Billet accepté pour fermer les yeux sur des stupéfiants.", "Usage de stupéfiants (art. L3421-1 CSP) toléré contre de l'argent : faute grave, complicité possible."],
		["Refuser l'argent mais laisser faire", -3, -2, "Usage de stupéfiants toléré.", "L'exploitant doit faire cesser l'usage de stupéfiants dans son établissement, sous peine de fermeture administrative."]]},
	"volant": {"t": "Un client fait tourner ses clés de voiture : « Je rentre, je suis bien, je conduis mieux bourré ! »", "o": [
		["Lui proposer l'éthylotest de l'établissement, un taxi ou de rester boire de l'eau, prévenir ses amis", 4, 2, "Conduite en état d'ivresse évitée.", "Les discothèques doivent fournir des éthylotests (art. L3341-4 CSP)."],
		["Lui arracher ses clés de force", -2, -3, "Clés confisquées de force.", "Un agent n'a aucun pouvoir de contrainte : on convainc, on prévient les amis, et en dernier recours on appelle le 17."],
		["Le laisser partir", -3, -1, "Client ivre laissé prendre le volant.", "Rien ne t'y oblige légalement, mais un accident à la sortie engage l'image et parfois la responsabilité de l'établissement."]]},
	"drogue": {"t": "« Eh, t'aurais pas un plan pour de la C ? Tu dois connaître du monde, toi… »", "o": [
		["« Non. Et ici, c'est interdit. » Puis prévenir les collègues de le garder à l'œil", 2, 0, "Sollicitation de stupéfiants signalée à l'équipe.", ""],
		["Lui donner le nom d'un type qui traîne au fumoir", -8, -6, "Mise en relation pour des stupéfiants.", "Faciliter l'acquisition de stupéfiants : complicité de trafic (art. 222-37 Code pénal)."]]},
	"soeur": {"t": "« Ma petite sœur est entrée avec la carte d'une copine, elle a 16 ans et elle est complètement ivre… »", "o": [
		["La retrouver, la mettre à l'écart au calme, appeler ses parents ou les secours, ne pas la laisser seule", 4, 2, "Mineure ivre prise en charge et confiée à ses proches.", "Une mineure ivre est une personne vulnérable : on la protège jusqu'à ce qu'un adulte responsable ou les secours la prennent en charge."],
		["La mettre dehors tout de suite", -5, -4, "Mineure ivre mise dehors seule.", "Mettre dehors une mineure ivre, de nuit : mise en danger, et la vente d'alcool à une mineure engage l'établissement (art. L3342-1 CSP)."]]},
	"gerant": {"t": "« Je veux parler au responsable ! On m'a facturé deux bouteilles au lieu d'une ! »", "o": [
		["L'écouter calmement, l'accompagner au bar et appeler le gérant", 2, 2, "Litige client désamorcé et transmis au gérant.", ""],
		["« Si t'es pas content, tu sors. »", -2, -4, "Client menacé d'exclusion pour une réclamation.", "Une réclamation n'est pas un motif d'exclusion : on désamorce et on transmet."]]},
	"merci": {"t": "« Merci pour tout à l'heure, franchement vous gérez bien ici. »", "o": [
		["« Merci, bonne soirée ! »", 0, 2, "", ""]]}}

func step(delta: float) -> void:
	if game.player == null or game.fight.active: return
	var now := _now()
	# fins de pause
	for nm in on_break.keys():
		if now > on_break[nm]:
			on_break.erase(nm)
			for a in game.colleagues:
				if is_instance_valid(a) and a.pname == nm:
					a.task = null
					a.walk_to(game.world.route(a.position, a.home))
					game._set_radio("%s : « Je reprends mon poste. »" % nm)
	# un collègue décroche sur son téléphone
	if game.phase == "salle":
		phone_t -= delta
		if phone_t <= 0.0:
			phone_t = randf_range(70.0, 120.0)
			var free := []
			for a in game.colleagues:
				if is_instance_valid(a) and a.task == null and not a.get_meta("fight", false) and a.path.is_empty(): free.append(a)
			if free.size() > 0 and randf() < 0.6:
				var a = free.pick_random()
				a.set_meta("phone_bad", true)
				a.anim = "phone"
	# un client vient te voir
	if game.phase != "salle" or game.ui.panel_open or game.ui.screen_open: return
	if approach != null:
		if not is_instance_valid(approach):
			approach = null
			return
		var d: float = approach.position.distance_to(game.player.position)
		if d > 9.0:
			approach.remove_meta("req")
			approach = null
			return
		if d < 1.7:
			approach.path = []
			approach.anim = "talk"
			approach.yaw = atan2(game.player.position.x - approach.position.x, game.player.position.z - approach.position.z)
			var k: String = approach.get_meta("req")
			approach.remove_meta("req")
			var who = approach
			approach = null
			_request(who, k)
		elif approach.path.is_empty() or randf() < 0.05:
			approach.walk_to([Vector2(game.player.position.x, game.player.position.z)])
		return
	approach_t -= delta
	if approach_t > 0.0: return
	approach_t = randf_range(35.0, 60.0)
	var keys := []
	for k in REQ.keys():
		if not asked_ev.has(k): keys.append(k)
	if keys.is_empty(): return
	var cand := []
	for n in game.crowd:
		if is_instance_valid(n) and n.path.is_empty() and n.position.distance_to(game.player.position) < 14.0: cand.append(n)
	if cand.is_empty(): return
	var c = cand.pick_random()
	var kk: String = keys.pick_random()
	asked_ev[kk] = true
	c.set_meta("req", kk)
	c.run = false
	approach = c
	c.walk_to([Vector2(game.player.position.x, game.player.position.z)])

func _request(n, k: String) -> void:
	var r: Dictionary = REQ[k]
	var opts: Array = r["o"].duplicate()
	opts.shuffle()
	var bts := []
	for o in opts:
		var oo: Array = o
		bts.append(_btn(oo[0], func(): _answer(n, k, oo)))
	var nm: String = n.data["first"] if n.data != null else _prof(n)["name"]
	game.ui.open_panel(nm + " vient te voir", "Client", "[i]%s[/i]" % r["t"], bts)

func _answer(n, k: String, o: Array) -> void:
	game.secu += float(o[1]); game.rep += float(o[2])
	game._clampg()
	if int(o[1]) < 0 or int(o[2]) < -1:
		game._fault(o[3], o[4])
	elif o[3] != "":
		game._good(o[3])
	game._mc("Demande d'un client : %s" % o[0].split(",")[0].to_lower())
	if o.size() > 5 and o[5] != "":
		game._spawn_incident(o[5])
	var col := "#9fe0b4" if int(o[1]) >= 0 and int(o[2]) >= 0 else "#ff8a8a"
	var body := "[color=#b9b3cc]Ta réponse : %s[/color]\n\n[color=%s]%s[/color]" % [o[0], col, o[3] if o[3] != "" else "Il repart avec le sourire."]
	if o[4] != "": body += "\n\n[color=#b9b3cc][i]%s[/i][/color]" % o[4]
	if is_instance_valid(n): n.anim = "dance" if n.zone == "piste" else "talk"
	game.ui.open_panel("Réponse", "", body, [_btn("Continuer", game._close_panel, "main")])

## Bilan de fin de nuit : pauses de l'équipe
func end_checks() -> void:
	for a in game.colleagues:
		if not is_instance_valid(a) or a.pname == "Extra": continue
		if not pauses.has(a.pname):
			game._fault("Aucune pause accordée à %s de la nuit." % a.pname, "Code du travail : au moins 20 minutes de pause dès 6 heures de travail effectif (art. L3121-16). Un agent épuisé est un agent moins vigilant.")
