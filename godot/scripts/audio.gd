extends Node
## Son du jeu, entièrement généré au démarrage (aucun fichier audio à télécharger) :
## musique de club en boucle, brouhaha de foule, bruitages (coups, radio…).
## La musique est étouffée dehors et dans le hall, pleine puissance dans la salle.

const RATE := 22050

var music: AudioStreamPlayer
var crowd: AudioStreamPlayer
var sfx_players: Array = []
var sounds := {}
var lp: AudioEffectLowPassFilter
var music_bus := -1
var crowd_bus := -1
var target_cut := 600.0
var target_mvol := -8.0
var target_cvol := -30.0
var fade := 0.0               # fin de soirée : la musique s'arrête
var volume_master := 1.0
var rain: AudioStreamPlayer
var rain_on := false
var style := ""

func _ready() -> void:
	_make_buses()
	music = AudioStreamPlayer.new()
	music.stream = _gen_music()
	music.bus = "Musique"
	add_child(music)
	crowd = AudioStreamPlayer.new()
	crowd.stream = _gen_crowd()
	crowd.bus = "Foule"
	add_child(crowd)
	for k in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
	sounds["punch"] = _gen_hit(70.0, 0.16, 0.9)
	sounds["hurt"] = _gen_hit(55.0, 0.24, 1.0)
	sounds["block"] = _gen_hit(140.0, 0.08, 0.5)
	sounds["whoosh"] = _gen_whoosh()
	sounds["radio"] = _gen_radio()
	sounds["heart"] = _gen_heart()
	rain = AudioStreamPlayer.new()
	rain.stream = _gen_rain()
	rain.bus = "Master"
	rain.volume_db = -80.0
	add_child(rain)

## Musique propre à l'établissement : pop-rock au pub, house au Néon, deep house au Palace,
## techno à l'Usine, RnB / hip-hop au Velvet
func set_style(s: String, raining: bool) -> void:
	rain_on = raining
	if raining and not rain.playing: rain.play()
	if s == style: return
	style = s
	var was: bool = music.playing
	music.stream = _gen_track(s)
	if was: music.play()

func start() -> void:
	if not music.playing: music.play()
	if not crowd.playing: crowd.play()

func _make_buses() -> void:
	AudioServer.add_bus()
	music_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(music_bus, "Musique")
	AudioServer.set_bus_send(music_bus, "Master")
	lp = AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 600.0
	AudioServer.add_bus_effect(music_bus, lp)
	AudioServer.add_bus()
	crowd_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(crowd_bus, "Foule")
	AudioServer.set_bus_send(crowd_bus, "Master")

## Réglage selon l'endroit où se trouve le joueur
func set_place(reg: String, _z: float) -> void:
	if rain != null:
		rain.volume_db = (-8.0 if reg == "out" else (-24.0 if reg == "hall" else -80.0)) if rain_on else -80.0
	if reg == "out":       # dehors
		target_cut = 450.0; target_mvol = -10.0; target_cvol = -40.0
	elif reg == "hall":
		target_cut = 1400.0; target_mvol = -6.0; target_cvol = -24.0
	elif reg == "toi" or reg == "fum":   # toilettes / fumoir
		target_cut = 900.0; target_mvol = -8.0; target_cvol = -26.0
	else:                  # salle
		target_cut = 16000.0; target_mvol = -2.0; target_cvol = -16.0

func set_master(v: float) -> void:
	volume_master = clamp(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(max(volume_master, 0.001)))

func _process(delta: float) -> void:
	if lp == null: return
	var k: float = clamp(delta * 3.0, 0.0, 1.0)
	lp.cutoff_hz = lerp(lp.cutoff_hz, target_cut, k)
	AudioServer.set_bus_volume_db(music_bus, lerp(AudioServer.get_bus_volume_db(music_bus), target_mvol - fade * 40.0, k))
	AudioServer.set_bus_volume_db(crowd_bus, lerp(AudioServer.get_bus_volume_db(crowd_bus), target_cvol, k))

func sfx(snd: String, vol_db := 0.0) -> void:
	if not sounds.has(snd): return
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[snd]
			p.volume_db = vol_db
			p.pitch_scale = randf_range(0.92, 1.08)
			p.play()
			return

# ---------------------------------------------------------------------
#  Génération
# ---------------------------------------------------------------------
func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

## 4 mesures de house à 124 BPM (grosse caisse, charleston, basse, nappes)
func _gen_music() -> AudioStreamWAV:
	var bpm := 124.0
	var beat := 60.0 / bpm
	var n := int(beat * 16.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var bass_notes := [45, 41, 36, 43]
	var seed_noise := 12345
	var lp_bass := 0.0
	for i in n:
		var t := float(i) / RATE
		var b := t / beat                 # position en temps
		var bar := int(b / 4.0) % 4
		var tb := fmod(b, 1.0) * beat     # temps écoulé depuis le dernier temps
		var s := 0.0
		# grosse caisse sur chaque temps
		var kf := 50.0 + 110.0 * exp(-tb * 30.0)
		s += sin(TAU * kf * tb) * exp(-tb * 7.0) * 0.9
		# charleston sur les contretemps
		var off := fmod(b + 0.5, 1.0) * beat
		seed_noise = (seed_noise * 1103515245 + 12345) & 0x7fffffff
		var nz := float(seed_noise) / 1073741824.0 - 1.0
		s += nz * exp(-off * 40.0) * 0.18
		# basse en croches décalées
		var e8 := fmod(b * 2.0, 1.0) * beat * 0.5
		var on := int(b * 2.0) % 2 == 1
		if on:
			var f := _midi(bass_notes[bar])
			var saw := 2.0 * fmod(t * f, 1.0) - 1.0
			lp_bass += (saw - lp_bass) * 0.08
			s += lp_bass * exp(-e8 * 6.0) * 0.45
		# nappes
		var tbar := fmod(b, 4.0) * beat
		var env := minf(1.0, tbar * 2.0) * exp(-tbar * 0.35)
		for m in chords[bar]:
			s += sin(TAU * _midi(m) * t) * 0.06 * env
		buf[i] = s * 0.55
	return _to_wav(buf, true)

## Brouhaha : bruit filtré, modulé lentement
func _gen_crowd() -> AudioStreamWAV:
	var n := RATE * 4
	var buf := PackedFloat32Array()
	buf.resize(n)
	var a := 0.0
	var b2 := 0.0
	var sd := 777
	for i in n:
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var w := float(sd) / 1073741824.0 - 1.0
		a += (w - a) * 0.05
		b2 += (a - b2) * 0.2
		var t := float(i) / RATE
		var mod := 0.6 + 0.4 * sin(TAU * 0.5 * t) * sin(TAU * 1.3 * t + 1.0)
		buf[i] = b2 * 3.0 * mod
	# fondu aux bords pour une boucle sans clic
	for i in 800:
		var g := float(i) / 800.0
		buf[i] *= g
		buf[n - 1 - i] *= g
	return _to_wav(buf, true)

func _noise(sd: Array) -> float:
	sd[0] = (int(sd[0]) * 1103515245 + 12345) & 0x7fffffff
	return float(sd[0]) / 1073741824.0 - 1.0

## Générateur de morceaux (8 mesures en boucle)
func _gen_track(s: String) -> AudioStreamWAV:
	var bpm := 124.0
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
	var bass := [45, 41, 36, 43]
	match s:
		"pub":
			bpm = 112.0; chords = [[60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60]]; bass = [48, 43, 45, 41]
		"chic":
			bpm = 118.0; chords = [[62, 65, 69, 72], [60, 64, 67, 71], [57, 60, 64, 67], [59, 62, 65, 69]]; bass = [38, 36, 33, 35]
		"indus":
			bpm = 132.0; chords = [[57, 60, 64], [57, 60, 64], [55, 58, 62], [53, 57, 60]]; bass = [33, 33, 31, 29]
		"model":
			bpm = 92.0; chords = [[61, 64, 68, 71], [59, 62, 66, 69], [57, 61, 64, 68], [56, 59, 63, 66]]; bass = [37, 35, 33, 32]
	if s == "led" or s == "": return _gen_music()
	var beat := 60.0 / bpm
	var n := int(beat * 32.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sd := [4242]
	var lpb := 0.0
	var acid := 0.0
	for i in n:
		var t := float(i) / RATE
		var b := t / beat
		var bar := int(b / 4.0) % 4
		var tb := fmod(b, 1.0) * beat
		var beat_i := int(b) % 4
		var smp := 0.0
		var nz := _noise(sd)
		match s:
			"pub":
				# batterie rock : grosse caisse 1 et 3, caisse claire 2 et 4
				if beat_i % 2 == 0:
					smp += sin(TAU * (55.0 + 90.0 * exp(-tb * 25.0)) * tb) * exp(-tb * 9.0) * 0.8
				else:
					smp += nz * exp(-tb * 14.0) * 0.45 + sin(TAU * 190.0 * tb) * exp(-tb * 20.0) * 0.2
				var e8 := fmod(b * 2.0, 1.0) * beat * 0.5
				smp += nz * exp(-e8 * 60.0) * 0.08
				var fb := _midi(bass[bar])
				smp += (2.0 * fmod(t * fb, 1.0) - 1.0) * exp(-tb * 3.0) * 0.22
				# guitare : accords en croches, son saturé
				var g := 0.0
				for m in chords[bar]: g += sign(sin(TAU * _midi(m) * t)) * 0.5 + sin(TAU * _midi(m) * 2.0 * t) * 0.3
				smp += clampf(g * 0.4, -1.0, 1.0) * exp(-e8 * 5.0) * 0.12
			"chic":
				# deep house : grosse caisse douce, charleston swing, accords de piano électrique
				smp += sin(TAU * (48.0 + 70.0 * exp(-tb * 28.0)) * tb) * exp(-tb * 8.0) * 0.65
				var off := fmod(b + 0.42, 1.0) * beat
				smp += nz * exp(-off * 45.0) * 0.1
				var tbar := fmod(b, 4.0) * beat
				for m in chords[bar]:
					var f := _midi(m)
					smp += sin(TAU * f * t + 0.6 * sin(TAU * f * 2.0 * t)) * 0.045 * exp(-fmod(b, 2.0) * beat * 0.9) * (0.85 + 0.15 * sin(TAU * 5.0 * t))
				var fb2 := _midi(bass[bar])
				smp += sin(TAU * fb2 * t) * 0.3 * (0.6 + 0.4 * exp(-tb * 4.0)) * minf(1.0, tbar * 4.0)
			"indus":
				# techno : grosse caisse lourde, grondement, charleston ouvert, ligne acide
				smp += sin(TAU * (45.0 + 120.0 * exp(-tb * 35.0)) * tb) * exp(-tb * 6.0) * 0.95
				smp += sin(TAU * 45.0 * t) * 0.18 * clampf((tb - 0.12) * 8.0, 0.0, 1.0) * exp(-tb * 3.0)
				var off2 := fmod(b + 0.5, 1.0) * beat
				smp += nz * exp(-off2 * 18.0) * 0.14
				var step := int(b * 4.0) % 16
				var notes := [0, 0, 12, 0, 3, 0, 15, 0, 0, 7, 0, 12, 0, 3, 10, 0]
				var fa := _midi(bass[bar] + 12 + notes[step])
				var e16 := fmod(b * 4.0, 1.0) * beat * 0.25
				var saw := 2.0 * fmod(t * fa, 1.0) - 1.0
				var cut := 0.05 + 0.25 * exp(-e16 * 30.0) * (0.5 + 0.5 * sin(TAU * t / (beat * 16.0)))
				acid += (saw - acid) * cut
				smp += acid * 0.22
			"model":
				# RnB / hip-hop : grosse caisse et caisse claire, basse 808, nappes
				var pos16 := int(b * 4.0) % 16
				var e16b := fmod(b * 4.0, 1.0) * beat * 0.25
				if pos16 in [0, 7, 10]:
					smp += sin(TAU * (40.0 + 60.0 * exp(-e16b * 20.0)) * e16b) * exp(-e16b * 3.5) * 0.9
				if pos16 in [4, 12]:
					smp += nz * exp(-e16b * 12.0) * 0.4
				smp += nz * exp(-fmod(b * 2.0, 1.0) * beat * 0.5 * 70.0) * 0.05
				var tbar2 := fmod(b, 4.0) * beat
				for m in chords[bar]:
					smp += sin(TAU * _midi(m) * t) * 0.04 * minf(1.0, tbar2 * 1.5) * exp(-tbar2 * 0.25)
		lpb += (smp - lpb) * 0.6
		buf[i] = lpb * 0.6
	return _to_wav(buf, true)

## Pluie : bruit doux et continu
func _gen_rain() -> AudioStreamWAV:
	var n := RATE * 3
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sd := [99]
	var a := 0.0
	for i in n:
		var w := _noise(sd)
		a += (w - a) * 0.35
		var drop := 0.0
		if randf() < 0.002: drop = randf_range(0.2, 0.5)
		buf[i] = a * 0.35 + drop * w
	for i in 600:
		var g := float(i) / 600.0
		buf[i] *= g
		buf[n - 1 - i] *= g
	return _to_wav(buf, true)

## Battement de cœur (quand tu es blessé)
func _gen_heart() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 48.0 * t) * exp(-t * 18.0)
		var t2 := t - 0.18
		if t2 > 0: s += sin(TAU * 42.0 * t2) * exp(-t2 * 20.0) * 0.7
		buf[i] = s * 0.9
	return _to_wav(buf, false)

func _gen_hit(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sd := 99
	for i in n:
		var t := float(i) / RATE
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var w := float(sd) / 1073741824.0 - 1.0
		var f := freq * (1.0 + 2.0 * exp(-t * 40.0))
		buf[i] = (sin(TAU * f * t) * exp(-t * 18.0) + w * exp(-t * 60.0) * 0.6) * amp
	return _to_wav(buf, false)

func _gen_whoosh() -> AudioStreamWAV:
	var n := int(0.22 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var a := 0.0
	var sd := 4242
	for i in n:
		var t := float(i) / RATE
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var w := float(sd) / 1073741824.0 - 1.0
		var k := 0.02 + 0.3 * (t / 0.22)
		a += (w - a) * k
		buf[i] = a * sin(PI * t / 0.22) * 0.8
	return _to_wav(buf, false)

func _gen_radio() -> AudioStreamWAV:
	var n := int(0.45 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var sd := 31337
	for i in n:
		var t := float(i) / RATE
		sd = (sd * 1103515245 + 12345) & 0x7fffffff
		var w := float(sd) / 1073741824.0 - 1.0
		var s := w * 0.25 * exp(-t * 6.0)                       # grésillement
		if t < 0.09: s += sign(sin(TAU * 1250.0 * t)) * 0.25     # bip 1
		elif t > 0.13 and t < 0.22: s += sign(sin(TAU * 940.0 * t)) * 0.25   # bip 2
		buf[i] = s
	return _to_wav(buf, false)
