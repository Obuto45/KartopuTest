extends Node3D
## Menü, HUD, test sahnesi ve tur yönetimi (tur kararlarını host verir).

const PlayerScript := preload("res://player.gd")
const ForestScript := preload("res://forest.gd")
const Chars := preload("res://characters.gd")
const HP_W := 316.0 # can barının iç genişliği (px)
const STATUS := {"stun": "SERSEMLEDİN", "blind": "KÖR OLDUN", "silence": "SUSTURULDUN", "confuse": "YÖNLER TERS",
	"slow": "YAVAŞLADIN", "vuln": "İŞARETLENDİN", "burn": "YANIYORSUN", "haste": "HIZLI", "power": "GÜÇLÜ ROKET",
	"rapid": "SERİ ATEŞ", "multi": "ÜÇLÜ ATIŞ", "armor": "ZIRH", "size": "BOY DEĞİŞTİ", "invis": "GÖRÜNMEZ",
	"float": "SÜZÜLÜYOR", "regen": "İYİLEŞİYOR"}
const SPAWNS := [Vector3(-14, 1, -14), Vector3(14, 1, 14), Vector3(-14, 1, 14), Vector3(14, 1, -14)]

var ui: Control
var info: Label
var members: Label
var start_btn: Button
var friends_box: VBoxContainer
var invite_box: VBoxContainer
var dmg_rect: ColorRect
var hud: Control
var char_lbl: Label
var hp_fill: ColorRect
var hp_trail: ColorRect # hasar sonrası yavaşça kısalan beyaz iz
var hp_ticks: Control # her 20 canda bir çizgi
var hp_txt: Label
var trail_f := 1.0
var char_btn: Button
var char_wrap: ColorRect
var char_cards := [] # ızgaradaki her karakter kutusunun StyleBoxFlat'ı
var char_sel := 0 # seçim ekranında incelenen karakter
var char_view: Node3D # önizleme sahnesinde modelin durduğu yer
var char_info := {} # ayrıntı panelindeki etiketler
var status_lbl: Label # üzerimdeki süreli etkiler
var score_lbl: Label
var center_lbl: Label
var blind_rect: ColorRect # kör edici etkiler: ekran beyazlar
var spec_lbl: Label
var slots := [] # [[StyleBoxFlat, Label], ...]
var settings_wrap: ColorRect
var vol_lbl: Label
var res_opt: OptionButton
var close_btn: Button
var ingame_box: VBoxContainer
var world: Node3D
var players: Node3D
var round_over := false


func _ready() -> void:
	_setup_input()
	_build_ui()
	Net.status.connect(func(m): info.text = m)
	Net.lobby_changed.connect(_refresh)
	Net.left.connect(_back_to_menu)
	Net.invited.connect(_on_invited)
	Updater.status.connect(func(m): info.text = m)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	_refresh()


func _setup_input() -> void:
	var keys := {"fwd": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "slot1": KEY_1, "slot2": KEY_2, "slot3": KEY_3, "slot4": KEY_4, "skill": KEY_Q}
	for a in keys:
		InputMap.add_action(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[a]
		InputMap.action_add_event(a, ev)
	var mouse := {"throw": MOUSE_BUTTON_LEFT}
	for a in mouse:
		InputMap.add_action(a)
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse[a]
		InputMap.action_add_event(a, ev)


# ---------- UI ----------

func _lbl(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 36
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _full_label(size: int, h: int, v: int) -> Label:
	var l := _lbl(hud, "", size)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 20; l.offset_top = 20; l.offset_right = -20; l.offset_bottom = -20
	l.horizontal_alignment = h
	l.vertical_alignment = v
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func _sb(c: Color, radius := 8, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	t.set_stylebox("normal", "Button", _sb(Color(0.15, 0.17, 0.26)))
	t.set_stylebox("hover", "Button", _sb(Color(0.85, 0.42, 0.12)))
	t.set_stylebox("pressed", "Button", _sb(Color(0.6, 0.28, 0.08)))
	t.set_stylebox("disabled", "Button", _sb(Color(0.12, 0.12, 0.16, 0.6)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.92, 0.94, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	for k in ["normal", "hover", "pressed"]:
		t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	var p := _sb(Color(0.06, 0.07, 0.11, 0.93), 14, 26)
	p.set_border_width_all(2)
	p.border_color = Color(0.95, 0.5, 0.15, 0.45)
	t.set_stylebox("panel", "PanelContainer", p)
	return t


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := _make_theme()

	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = theme
	layer.add_child(ui)
	var bg := TextureRect.new() # menü arka planı: koyu lacivertten mora geçiş
	var grad := Gradient.new()
	grad.set_color(0, Color(0.04, 0.06, 0.14))
	grad.set_color(1, Color(0.22, 0.07, 0.16))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 9)
	panel.add_child(v)

	var title := _lbl(v, "BAZUKA SAVAŞI", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	var sub := _lbl(v, "Steam: " + (Net.my_name() if Net.steam_ok else "BAĞLI DEĞİL (Steam açık mı?)"), 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.text += "   •   sürüm " + Updater.version()
	invite_box = VBoxContainer.new() # gelen davetler burada çıkar
	v.add_child(invite_box)
	char_btn = _btn(v, "", _open_chars)
	_update_char_btn()
	_btn(v, "Steam Lobisi Kur", Net.host_steam)
	_btn(v, "Arkadaşlar (davet et / lobisine katıl)", _show_friends)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 0
	friends_box = VBoxContainer.new()
	friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(friends_box)
	v.add_child(scroll)
	start_btn = _btn(v, "▶  Oyunu Başlat (host)", _on_start)
	members = _lbl(v, "", 16)
	_btn(v, "Lobiden Çık", Net.leave)
	v.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	v.add_child(row)
	for b in [_btn(row, "Ayarlar", _open_settings), _btn(row, "Çıkış", get_tree().quit)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var test := HBoxContainer.new()
	test.add_theme_constant_override("separation", 9)
	v.add_child(test)
	var tl := _lbl(test, "Tek PC testi:", 14)
	tl.modulate = Color(1, 1, 1, 0.6)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF # HBox içinde harf harf kırılmasın
	for b in [_btn(test, "Yerel Host", Net.host_local), _btn(test, "Yerel Katıl", Net.join_local)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info = _lbl(v, "Arkadaşın daveti kabul edince lobiye girer. Sonra 'Oyunu Başlat'.", 14)
	info.modulate = Color(1, 1, 1, 0.75)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	dmg_rect = ColorRect.new() # hasar alınca kırmızı ekran
	dmg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dmg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_rect.color = Color(1, 0, 0, 0)
	hud.add_child(dmg_rect)
	blind_rect = ColorRect.new()
	blind_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blind_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blind_rect.color = Color(1, 1, 0.95, 0)
	hud.add_child(blind_rect)
	_full_label(28, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER).text = "+"
	_build_hp_bar()
	score_lbl = _full_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	center_lbl = _full_label(52, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	spec_lbl = _full_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	spec_lbl.offset_top = 60
	_full_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM).text = \
		"WASD yürü | Boşluk zıpla (havada 2. zıplama) | Shift+WASD atıl | 1-4 eşya | Q karakter yeteneği | Sol tık kullan | ESC menü/ayarlar | F10 çık"
	# Alt envanter çubuğu (hotbar)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -245; bar.offset_right = 245
	bar.offset_top = -140; bar.offset_bottom = -50
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)
	for i in 5: # 1-4 eşyalar + Q karakter yeteneği
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(90, 84)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15)
		cell.add_child(l)
		bar.add_child(cell)
		slots.append([sb, l])
	status_lbl = _full_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	status_lbl.offset_bottom = -150
	hud.hide()
	_build_settings(layer, theme)
	_build_chars(layer, theme)


## Sol üst: karakter adı + 20'lik dilimli can barı, hasarda beyaz iz, sayı.
func _build_hp_bar() -> void:
	var box := Control.new()
	box.position = Vector2(20, 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(box)
	char_lbl = _lbl(box, "", 18)
	char_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	char_lbl.add_theme_constant_override("outline_size", 6)
	char_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	var back := ColorRect.new()
	back.position = Vector2(0, 28)
	back.size = Vector2(HP_W + 4, 30)
	back.color = Color(0, 0, 0, 0.65)
	box.add_child(back)
	hp_trail = ColorRect.new()
	hp_fill = ColorRect.new()
	hp_ticks = Control.new()
	for r in [hp_trail, hp_fill, hp_ticks]:
		r.position = Vector2(2, 30)
		r.size = Vector2(HP_W, 26)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(r)
	hp_trail.color = Color(1, 1, 1, 0.85)
	hp_txt = _lbl(box, "", 17)
	hp_txt.position = Vector2(2, 30)
	hp_txt.size = Vector2(HP_W, 26)
	hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_txt.add_theme_constant_override("outline_size", 5)
	hp_txt.add_theme_color_override("font_outline_color", Color.BLACK)


func _update_hp_bar(me: Node, dt: float) -> void:
	var f := clampf(float(me.hp) / me.max_hp, 0.0, 1.0)
	trail_f = f if f >= trail_f else move_toward(trail_f, f, dt * 0.5)
	hp_fill.size.x = HP_W * f
	hp_trail.size.x = HP_W * trail_f
	var c := Color(0.95, 0.85, 0.2).lerp(Color(0.3, 0.9, 0.35), (f - 0.5) * 2.0) if f > 0.5 \
		else Color(0.9, 0.15, 0.1).lerp(Color(0.95, 0.85, 0.2), f * 2.0)
	if f <= 0.3 and f > 0.0: # kritik: yanıp söner
		c = c.lerp(Color.WHITE, 0.35 * absf(sin(Time.get_ticks_msec() * 0.008)))
	hp_fill.color = c
	hp_txt.text = "%d / %d" % [me.hp, me.max_hp]
	var n: int = me.max_hp / 20 - 1
	if hp_ticks.get_child_count() != n: # dilim çizgileri (can üst sınırı değişince yeniden)
		for t in hp_ticks.get_children():
			t.queue_free()
		for k in n:
			var line := ColorRect.new()
			line.color = Color(0, 0, 0, 0.55)
			line.size = Vector2(2, 26)
			line.position.x = HP_W * (k + 1) * 20.0 / me.max_hp - 1.0
			hp_ticks.add_child(line)
	char_lbl.text = "%s  •  %s" % [me.ch.name, me.ch.role]
	char_lbl.modulate = me.ch.color.lightened(0.3)


# ---------- Karakter seçimi ----------

func _build_chars(layer: CanvasLayer, theme: Theme) -> void:
	char_wrap = ColorRect.new()
	char_wrap.color = Color(0.03, 0.04, 0.08, 0.98) # alttaki menü görünmesin
	char_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	char_wrap.theme = theme
	layer.add_child(char_wrap)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	char_wrap.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var title := _lbl(v, "KARAKTERİNİ SEÇ   •   %d karakter" % Chars.LIST.size(), 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	# Sol: kaydırmalı portre ızgarası.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in Chars.LIST.size():
		var c: Dictionary = Chars.LIST[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 126)
		b.icon = load("res://icons/%s.png" % c.model)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = c.name
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		b.tooltip_text = "%s – %s" % [c.name, c.skill_name]
		var sb := _sb(Color(c.color.darkened(0.72), 0.95), 10, 6)
		sb.set_border_width_all(3)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_show_char.bind(i))
		grid.add_child(b)
		char_cards.append(sb)

	# Sağ: seçili karakterin 3D önizlemesi ve ayrıntıları.
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 430
	row.add_child(panel)
	var d := VBoxContainer.new()
	d.add_theme_constant_override("separation", 7)
	panel.add_child(d)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(380, 280)
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	vp.add_child(sun)
	var pcam := Camera3D.new()
	pcam.fov = 32
	pcam.position = Vector3(0, 1.35, 6.6)
	pcam.rotation.x = -0.03
	vp.add_child(pcam)
	char_view = Node3D.new()
	vp.add_child(char_view)
	char_info.name = _lbl(d, "", 30)
	char_info.role = _lbl(d, "", 15)
	char_info.role.modulate = Color(1, 1, 1, 0.65)
	char_info.stats = _lbl(d, "", 15)
	char_info.passive = _lbl(d, "", 15)
	char_info.skill = _lbl(d, "", 16)
	char_info.skill.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	char_info.quote = _lbl(d, "", 15)
	char_info.quote.modulate = Color(0.75, 0.9, 1.0)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 9)
	d.add_child(btns)
	for b in [_btn(btns, "✔  SEÇ", func(): _pick_char(char_sel)), _btn(btns, "Kapat", char_wrap.hide)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_wrap.hide()


## Seçim ekranında bir karakteri inceler: 3D model, sayılar, yetenek.
func _show_char(i: int) -> void:
	char_sel = i
	var c := Chars.get_char(i)
	for k in char_cards.size():
		char_cards[k].border_color = Color(1, 0.85, 0.2) if k == i else Color(0.3, 0.3, 0.35, 0.5)
	for n in char_view.get_children():
		n.queue_free()
	var m: Node3D = load("res://models/chars/%s.glb" % c.model).instantiate()
	m.rotation.y = 0.35
	char_view.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	char_info.name.text = c.name
	char_info.name.add_theme_color_override("font_color", c.color.lightened(0.3))
	char_info.role.text = c.role
	char_info.stats.text = "Can %d   •   Hız %%%d   •   Kalkan %d sn" % [c.get("hp", 100), roundi(c.get("speed", 1.0) * 100.0), c.get("shield_cd", 8.0)]
	char_info.passive.text = "Pasif: " + Chars.passive_text(c)
	char_info.skill.text = "Q – %s (%d sn)\n%s" % [c.skill_name, c.cd, c.skill_desc]
	char_info.quote.text = "\"%s\"" % c.quote


func _open_chars() -> void:
	_show_char(Net.my_char)
	char_wrap.show()


func _pick_char(i: int) -> void:
	Net.set_char(i)
	_update_char_btn()
	char_wrap.hide()


func _update_char_btn() -> void:
	var c := Chars.get_char(Net.my_char)
	char_btn.text = "Karakter: %s (%s)  –  değiştir" % [c.name, c.role]


func _build_settings(layer: CanvasLayer, theme: Theme) -> void:
	settings_wrap = ColorRect.new() # arkayı karartır, tıklamaları yutar
	settings_wrap.color = Color(0, 0, 0, 0.55)
	settings_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_wrap.theme = theme
	layer.add_child(settings_wrap)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_wrap.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_lbl(v, "AYARLAR", 32).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vol_lbl = _lbl(v, "", 17)
	var vol := HSlider.new()
	vol.min_value = 0.0; vol.max_value = 1.0; vol.step = 0.05
	vol.value = Settings.volume
	vol.value_changed.connect(_on_volume)
	v.add_child(vol)
	_on_volume(vol.value)

	_lbl(v, "Ekran modu", 17)
	var mode := OptionButton.new()
	for m in Settings.MODES:
		mode.add_item(m)
	mode.selected = Settings.mode
	mode.item_selected.connect(_on_mode)
	v.add_child(mode)
	_lbl(v, "Çözünürlük (pencere modunda)", 17)
	res_opt = OptionButton.new()
	for r in Settings.RESOLUTIONS:
		res_opt.add_item("%d x %d" % [r.x, r.y])
	res_opt.selected = Settings.resolution
	res_opt.disabled = Settings.mode != 0
	res_opt.item_selected.connect(_on_res)
	v.add_child(res_opt)

	v.add_child(HSeparator.new())
	ingame_box = VBoxContainer.new()
	v.add_child(ingame_box)
	_btn(ingame_box, "Lobiden Çık", Net.leave)
	close_btn = _btn(v, "Kapat", _close_settings)
	settings_wrap.hide()


func _on_volume(x: float) -> void:
	Settings.volume = x
	Settings.apply_audio()
	vol_lbl.text = "Ses: %d%%" % roundi(x * 100.0)


func _on_mode(i: int) -> void:
	Settings.mode = i
	res_opt.disabled = i != 0
	Settings.apply_display()
	Settings.save()


func _on_res(i: int) -> void:
	Settings.resolution = i
	Settings.apply_display()
	Settings.save()


func _open_settings() -> void:
	ingame_box.visible = world != null
	close_btn.text = "Oyuna Dön" if world else "Kapat"
	settings_wrap.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_settings() -> void:
	settings_wrap.hide()
	Settings.save()
	if world:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_friends() -> void:
	for c in friends_box.get_children():
		c.queue_free()
	var list := Net.online_friends()
	var n := 0
	for f in list:
		if f[2] != 0 and f[2] != Net.lobby_id:
			_btn(friends_box, "▶ Lobisine katıl: " + f[1], Net.join_lobby.bind(f[2]))
			n += 1
		if Net.lobby_id != 0:
			_btn(friends_box, "Davet et: " + f[1], Net.invite_friend.bind(f[0], f[1]))
			n += 1
	if list.is_empty():
		info.text = "Çevrimiçi Steam arkadaşı yok."
	elif Net.lobby_id == 0:
		info.text = "Davet için önce 'Steam Lobisi Kur'a bas. Lobisi olan arkadaşa ▶ ile katılabilirsin."
	(friends_box.get_parent() as Control).custom_minimum_size.y = min(n, 5) * 40


func _on_invited(from_name: String, lobby: int) -> void:
	for c in invite_box.get_children():
		c.queue_free()
	_lbl(invite_box, "%s seni lobisine davet etti!" % from_name, 18)
	_btn(invite_box, "✔ Daveti Kabul Et", func():
		for c in invite_box.get_children():
			c.queue_free()
		Net.join_lobby(lobby))
	_btn(invite_box, "✖ Reddet", func():
		for c in invite_box.get_children():
			c.queue_free())
	Sfx.play2d(Sfx.hurt, -6.0) # bildirim sesi


func _refresh() -> void:
	var lines := PackedStringArray()
	for id in Net.names:
		lines.append(("★ " if id == 1 else "• ") + str(Net.names[id]) + "  –  " + Chars.get_char(Net.chars.get(id, 0)).name)
	members.text = "Lobidekiler:\n" + "\n".join(lines) if Net.online() else ""
	start_btn.disabled = not (Net.online() and multiplayer.is_server())


func _process(dt: float) -> void:
	if players == null:
		return
	var me = players.get_node_or_null(str(multiplayer.get_unique_id()))
	if me:
		_update_hp_bar(me, dt)
		dmg_rect.color.a = me.flash * 1.2
		blind_rect.color.a = clampf(me.bt("blind") * 2.0, 0.0, 1.0) # son 0,5 sn'de açılır
		var sh := "AKTİF" if me.shield_on else ("%d sn" % ceili(me.shield_cd) if me.shield_cd > 0.0 else "HAZIR")
		var texts := ["1\nBAZUKA", "2\nKALKAN\n" + sh, "3\nDUVAR\n" + _cd_text(me.wall_cd), "4\nKILIÇ",
			"Q\n%s\n%s" % [me.ch.skill_name, _cd_text(me.skill_cd)]]
		for i in 5:
			slots[i][0].border_color = Color(1, 0.85, 0.2) if me.slot == i + 1 else Color(0.5, 0.5, 0.5, 0.6)
			slots[i][1].text = texts[i]
		slots[4][0].border_color = me.ch.color if me.skill_cd <= 0.0 else Color(0.5, 0.5, 0.5, 0.6) # Q hazırsa karakter renginde
		var st := PackedStringArray()
		for k in me.buffs:
			if STATUS.has(k) and me.hp > 0:
				st.append("%s %.1f" % [STATUS[k], me.buffs[k][1]])
		status_lbl.text = "   ".join(st)
		spec_lbl.text = "İZLENİYOR: %s\nSol tık / Sağ tık: oyuncu değiştir" \
			% Net.display_name(me.spec_target.name.to_int()) if me.hp <= 0 and is_instance_valid(me.spec_target) else ""
	var s := PackedStringArray()
	for p in players.get_children():
		s.append("%s  %d" % [Net.display_name(p.name.to_int()), p.hp])
	score_lbl.text = "\n".join(s)


func _cd_text(t: float) -> String:
	return "%d sn" % ceili(t) if t > 0.0 else "HAZIR"


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if char_wrap.visible:
			char_wrap.hide()
		elif settings_wrap.visible:
			_close_settings()
		elif world:
			_open_settings()
		return
	if world == null or settings_wrap.visible:
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_F10:
		Net.leave()


# ---------- Oyun akışı ----------

func _on_start() -> void:
	var ids := [1]
	ids.append_array(Array(multiplayer.get_peers()))
	ids.sort()
	start_game.rpc(ids)


@rpc("authority", "call_local", "reliable")
func start_game(ids: Array) -> void:
	_clear_world()
	_build_world()
	for i in ids.size():
		var p: CharacterBody3D = PlayerScript.new()
		p.name = str(ids[i])
		p.set_multiplayer_authority(ids[i])
		p.spawn_pos = SPAWNS[i % SPAWNS.size()]
		players.add_child(p)
	round_over = false
	center_lbl.text = ""
	ui.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Kurban kendi makinesinde ölünce host'a bildirir; kazananı host belirler.
@rpc("any_peer", "call_local", "reliable")
func report_death(dead_id: int) -> void:
	if not multiplayer.is_server() or round_over or players == null:
		return
	var alive := players.get_children().filter(func(p): return p.hp > 0 and p.name.to_int() != dead_id)
	if alive.size() > 1:
		return
	var winner: String = Net.display_name(alive[0].name.to_int()) if alive.size() == 1 else "Kimse"
	end_round.rpc(winner)
	await get_tree().create_timer(3.0).timeout
	if players:
		restart_round.rpc()


@rpc("authority", "call_local", "reliable")
func end_round(winner: String) -> void:
	round_over = true
	for t in [3, 2, 1]:
		if not round_over:
			return
		center_lbl.text = "%s KAZANDI!\nYeni tur %d sn içinde..." % [winner, t]
		await get_tree().create_timer(1.0).timeout


@rpc("authority", "call_local", "reliable")
func restart_round() -> void:
	round_over = false
	center_lbl.text = ""
	if players:
		for p in players.get_children():
			p.respawn()


func _on_peer_left(id: int) -> void:
	if players:
		var n := players.get_node_or_null(str(id))
		if n:
			n.queue_free()


func _clear_world() -> void:
	if world:
		remove_child(world) # isim hemen boşalsın, RPC yolları eşleşsin
		world.queue_free()
	world = null
	players = null


func _back_to_menu() -> void:
	_clear_world()
	round_over = false
	hud.hide()
	settings_wrap.hide()
	ui.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


# ---------- Harita ----------

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var forest: Node3D = ForestScript.new()
	forest.spawns = SPAWNS
	world.add_child(forest)

	players = Node3D.new()
	players.name = "Players"
	world.add_child(players)
