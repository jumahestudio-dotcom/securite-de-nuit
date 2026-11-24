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
var volume_master := 1.0

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
func set_place(x: float, z: float) -> void:
	if z > 0.4:            # dehors
		target_cut = 450.0; target_mvol = -10.0; target_cvol = -40.0
	elif z > -6.2:         # hall
		target_cut = 1400.0; target_mvol = -6.0; target_cvol = -24.0
	elif (x < -9.1 and z < -25.0) or (x > 9.1 and z > -14.1 and z < -6.0):   # toilettes / fumoir
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
	AudioServer.set_bus_volume_db(music_bus, lerp(AudioServer.get_bus_volume_db(music_bus), target_mvol, k))
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
