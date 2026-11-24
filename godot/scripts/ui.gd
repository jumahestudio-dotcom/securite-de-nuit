extends CanvasLayer
## Interface : HUD, objectif, radio, invite d'action, panneau de décision, écrans plein écran.

var hud: HBoxContainer
var chips := {}
var obj: Label
var radio: Label
var prompt: Label
var incs: Label
var panel: PanelContainer
var pbox: VBoxContainer
var screen: ColorRect
var sbox: VBoxContainer
var panel_open := false
var screen_open := false

const C_BG := Color(0.09, 0.075, 0.14, 0.94)
const C_LINE := Color(0.23, 0.2, 0.34)
const C_NEON := Color("#ff3d9a")
const C_CY := Color("#33e1ff")
const C_OK := Color("#3ee08f")
const C_BAD := Color("#ff5a5a")

func _sb(bg: Color, border: Color, rad := 10, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(rad)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.7; s.content_margin_bottom = pad * 0.7
	return s

func _label(txt := "", size := 16, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _ready() -> void:
	# HUD (haut gauche)
	hud = HBoxContainer.new()
	hud.position = Vector2(14, 12)
	hud.add_theme_constant_override("separation", 8)
	add_child(hud)
	for k in ["Heure", "Jauge", "Sécurité", "Réputation"]:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.04, 0.08, 0.8), C_LINE, 10, 10))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(_label(k, 12, Color(0.75, 0.72, 0.85)))
		var val := _label("-", 22)
		v.add_child(val)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(90, 4)
		bar.show_percentage = false
		bar.max_value = 100
		bar.add_theme_stylebox_override("background", _sb(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 2, 0))
		bar.add_theme_stylebox_override("fill", _sb(C_OK, Color(0, 0, 0, 0), 2, 0))
		v.add_child(bar)
		pc.add_child(v)
		hud.add_child(pc)
		chips[k] = [val, bar]
	# objectif (haut droite)
	var op := PanelContainer.new()
	op.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.04, 0.08, 0.8), Color("#ffc04d"), 10, 12))
	op.anchor_left = 1; op.anchor_right = 1
	op.offset_left = -380; op.offset_right = -14; op.offset_top = 12
	obj = _label("", 15)
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj.custom_minimum_size = Vector2(340, 0)
	op.add_child(obj)
	add_child(op)
	# incidents en cours (droite)
	incs = _label("", 14, Color("#ffb3b3"))
	incs.anchor_left = 1; incs.anchor_right = 1
	incs.offset_left = -380; incs.offset_right = -14; incs.offset_top = 140
	incs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(incs)
	# radio (bas gauche)
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", _sb(Color(0.03, 0.09, 0.05, 0.8), Color("#1f4a2c"), 10, 12))
	rp.anchor_top = 1; rp.anchor_bottom = 1
	rp.offset_left = 14; rp.offset_top = -70; rp.offset_bottom = -14; rp.offset_right = 600
	radio = _label("", 15, Color("#9fe0b4"))
	radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rp.add_child(radio)
	add_child(rp)
	# invite d'action (centre)
	prompt = _label("", 18)
	prompt.anchor_left = 0.5; prompt.anchor_right = 0.5; prompt.anchor_top = 0.62; prompt.anchor_bottom = 0.62
	prompt.offset_left = -300; prompt.offset_right = 300
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 6)
	add_child(prompt)
	# panneau de décision (droite)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(C_BG, C_LINE, 16, 16))
	panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_top = 0; panel.anchor_bottom = 1
	panel.offset_left = -500; panel.offset_right = -16; panel.offset_top = 90; panel.offset_bottom = -90
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	pbox = VBoxContainer.new()
	pbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pbox.add_theme_constant_override("separation", 8)
	sc.add_child(pbox)
	panel.visible = false
	add_child(panel)
	# écran plein (menu / bilan)
	screen = ColorRect.new()
	screen.color = Color(0.02, 0.015, 0.04, 0.92)
	screen.anchor_right = 1; screen.anchor_bottom = 1
	var center := CenterContainer.new()
	center.anchor_right = 1; center.anchor_bottom = 1
	screen.add_child(center)
	var spc := PanelContainer.new()
	spc.add_theme_stylebox_override("panel", _sb(C_BG, C_LINE, 18, 24))
	spc.custom_minimum_size = Vector2(760, 0)
	center.add_child(spc)
	var ssc := ScrollContainer.new()
	ssc.custom_minimum_size = Vector2(740, 640)
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	spc.add_child(ssc)
	sbox = VBoxContainer.new()
	sbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sbox.add_theme_constant_override("separation", 10)
	ssc.add_child(sbox)
	screen.visible = false
	add_child(screen)

func _rich(bb: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	r.text = bb
	return r

func _button(b: Dictionary) -> Button:
	var bt := Button.new()
	bt.text = Data.clean(b.get("t", ""))
	bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.custom_minimum_size = Vector2(0, 40)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind: String = b.get("k", "")
	var col := C_LINE
	var fc := Color.WHITE
	match kind:
		"main": col = C_NEON
		"ok": col = C_OK; fc = C_OK
		"bad": col = C_BAD; fc = C_BAD
		"cy": col = C_CY; fc = C_CY
	var bg := Color(0.14, 0.12, 0.2) if kind != "main" else Color(0.55, 0.12, 0.38)
	bt.add_theme_stylebox_override("normal", _sb(bg, col, 10, 12))
	bt.add_theme_stylebox_override("hover", _sb(bg.lightened(0.15), col, 10, 12))
	bt.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.2), col, 10, 12))
	bt.add_theme_stylebox_override("disabled", _sb(bg.darkened(0.4), C_LINE, 10, 12))
	bt.add_theme_color_override("font_color", fc)
	bt.add_theme_color_override("font_hover_color", fc.lightened(0.3))
	bt.add_theme_font_size_override("font_size", 16)
	bt.disabled = b.get("off", false)
	var cb = b.get("cb", null)
	if cb != null:
		bt.pressed.connect(cb)
	return bt

func _fill(box: VBoxContainer, title: String, sub: String, body: String, buttons: Array) -> void:
	for c in box.get_children():
		c.queue_free()
	var tl := _label(Data.clean(title), 28, Color.WHITE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tl)
	if sub != "":
		var sl := _label(Data.clean(sub), 13, Color(0.7, 0.67, 0.8))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sl)
	if body != "":
		box.add_child(_rich(Data.clean(body)))
	for b in buttons:
		if b.has("row"):
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			for bb in b["row"]:
				hb.add_child(_button(bb))
			box.add_child(hb)
		else:
			box.add_child(_button(b))

func open_panel(title: String, sub: String, body: String, buttons: Array) -> void:
	_fill(pbox, title, sub, body, buttons)
	panel.visible = true
	panel_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_panel() -> void:
	panel.visible = false
	panel_open = false

func show_screen(title: String, body: String, buttons: Array) -> void:
	_fill(sbox, title, "", body, buttons)
	screen.visible = true
	screen_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_screen() -> void:
	screen.visible = false
	screen_open = false

func set_hud(clock: String, inside: int, cap: int, secu: float, rep: float) -> void:
	chips["Heure"][0].text = clock
	chips["Heure"][1].value = 0
	chips["Jauge"][0].text = "%d/%d" % [inside, cap]
	chips["Jauge"][1].value = 100.0 * inside / max(1, cap)
	chips["Sécurité"][0].text = str(int(round(secu)))
	chips["Sécurité"][1].value = secu
	chips["Réputation"][0].text = str(int(round(rep)))
	chips["Réputation"][1].value = rep
