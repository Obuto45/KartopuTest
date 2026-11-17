extends Node3D
## Menü, HUD, test sahnesi ve tur yönetimi (tur kararlarını host verir).

const PlayerScript := preload("res://player.gd")
const ForestScript := preload("res://forest.gd")
const ExplosionScript := preload("res://explosion.gd")
const Chars := preload("res://characters.gd")
const TdUi := preload("res://td_ui.gd")
const HP_W := 316.0 # can barının iç genişliği (px)
const STATUS := {"stun": "SERSEMLEDİN", "blind": "KÖR OLDUN", "silence": "SUSTURULDUN", "confuse": "YÖNLER TERS",
	"slow": "YAVAŞLADIN", "vuln": "İŞARETLENDİN", "burn": "YANIYORSUN", "haste": "HIZLI", "power": "GÜÇLÜ ROKET",
	"rapid": "SERİ ATEŞ", "multi": "ÜÇLÜ ATIŞ", "armor": "ZIRH", "size": "BOY DEĞİŞTİ", "invis": "GÖRÜNMEZ",
	"float": "SÜZÜLÜYOR", "regen": "İYİLEŞİYOR"}
const SPAWNS := [Vector3(-14, 1, -14), Vector3(14, 1, 14), Vector3(-14, 1, 14), Vector3(14, 1, -14)]
# TD: orta alan (kule ve çevresi) ağaçsız kalsın; oyuncular kulenin dibinde doğar.
const TD_CLEAR := [Vector3(0, 0, 0), Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, 6), Vector3(0, 0, -6)]
const TD_SPAWNS := [Vector3(5, 1, 0), Vector3(-5, 1, 0), Vector3(0, 1, 5), Vector3(0, 1, -5)]
const MODES := {"arena": ["ARENA", "Lobi kur, arkadaşlarını davet et, savaşı başlat.", "▶  Oyunu Başlat (host)"],
	"td": ["TOWER DEFENSE", "Rapunzel'in kulesini birlikte savunun. Tek başına da başlatabilirsin.", "▶  Savunmayı Başlat (host)"]}
const MENU_SPOT := Vector3(14, 0, 14) # menü sahnesi bir doğma noktasında: etrafı ağaçsız
const MENU_CREW := [40, 50, 34, 8, 26] # seçilen karakterin yanında duranlar
# Menü kamerası [konum, bakılan nokta], ekibe göre: giriş ekranı geniş ve ortalı, menüde ekip sağda.
const CAM_INTRO := [Vector3(0, 1.75, 6.6), Vector3(0, 1.55, 0)] # 6,6 m: daha geride ağaç var
const CAM_MENU := [Vector3(0.6, 1.4, 6.6), Vector3(-2.6, 1.1, 0)]

var mode := "arena" # "arena" | "td": host seçer, set_mode ile istemcilere gider
var ui: Control
var ui_layer: CanvasLayer
var td_ui: Control # yalnız TD maçında var (td_ui.gd)
var hotbar: HBoxContainer # arena envanter çubuğu: TD'de gizlenir
var help_lbl: Label
var lobby_title: Label
var lobby_sub: Label
var weapon_btn: Button
var weapon_wrap: ColorRect
var weapon_grid: GridContainer
var weapon_list: Array = TdUi.consts("res://weapons.gd").get("LIST", []) # weapons.gd yoksa boş
var weapon_sel := 0 # Net.my_weapon yoksa yerel seçim
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
var pages := {} # menü sayfaları: intro, main, modes, lobby
var page := ""
var shade: TextureRect # soldan kararma: menü yazıları okunsun
var prompt: Label # giriş ekranında yanıp sönen yazı
var menu_bg: Node3D # menüde arkadaki canlı orman sahnesi
var menu_cam: Camera3D
var cam_k := 0.0 # 0 giriş çerçevesi, 1 menü çerçevesi
var menu_t := 0.0
var boom_t := 1.5


func _ready() -> void:
	_setup_input()
	_build_ui()
	Net.status.connect(func(m): info.text = m)
	Net.lobby_changed.connect(_refresh)
	Net.left.connect(_back_to_menu)
	Net.invited.connect(_on_invited)
	Updater.status.connect(func(m): info.text = m)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.peer_connected.connect(func(id): # yeni gelen hostun modunu öğrensin
		if multiplayer.is_server():
			set_mode.rpc_id(id, mode))
	_set_menu_bg(true)
	_show_page("intro")
	set_mode("arena")
	if "--selftest" in OS.get_cmdline_user_args(): # yayın öncesi: paketlenmiş exe'de haritayı açıp bir kare kaydeder
		Net.host_local()
		_on_start()
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/selftest.png")
		get_tree().quit()


func _setup_input() -> void:
	var keys := {"fwd": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "slot1": KEY_1, "slot2": KEY_2, "slot3": KEY_3, "slot4": KEY_4, "skill": KEY_Q,
		"slot5": KEY_5, "stats": KEY_TAB, "shop": KEY_B, "ready": KEY_G, "interact": KEY_E} # son satır TD için
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
	# Ana menü düğmeleri: büyük, sola yaslı, üstüne gelince turuncu şerit ve içeri kayma.
	t.set_type_variation("BigButton", "Button")
	var mn := _sb(Color(0, 0, 0, 0), 4, 0)
	mn.content_margin_left = 22
	var mh := _sb(Color(0.95, 0.45, 0.1, 0.9), 4, 0)
	mh.content_margin_left = 40
	mh.border_width_left = 6
	mh.border_color = Color(1.0, 0.85, 0.4)
	for k in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(k, "BigButton", mh if k != "normal" and k != "disabled" else mn)
	t.set_font_size("font_size", "BigButton", 30)
	t.set_constant("outline_size", "BigButton", 6)
	t.set_color("font_outline_color", "BigButton", Color(0, 0, 0, 0.7))
	return t


## Oyunun logosu: kalın sistem yazı tipi, koyu dış hat ve gölge.
func _logo(parent: Node, text: String, size: int, c := Color(1.0, 0.62, 0.18)) -> Label:
	var l := _lbl(parent, text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Sans-Serif"])
	f.font_weight = 900
	l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.0))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", maxi(size / 16, 2))
	l.add_theme_constant_override("shadow_outline_size", maxi(size / 7, 4))
	return l


## Okunaklı küçük yazı: menü sahnenin üstünde durduğu için dış hatlı.
func _txt(parent: Node, text: String, size: int, alpha := 0.85) -> Label:
	var l := _lbl(parent, text, size)
	l.modulate.a = alpha
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer
	var theme := _make_theme()

	_build_menu(layer, theme)

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
	help_lbl = _full_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM)
	help_lbl.text = \
		"WASD yürü | Boşluk zıpla (havada 2. zıplama) | Shift+WASD atıl | 1-4 eşya | Q karakter yeteneği | Sol tık kullan | ESC menü/ayarlar | F10 çık"
	# Alt envanter çubuğu (hotbar)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -245; bar.offset_right = 245
	bar.offset_top = -140; bar.offset_bottom = -50
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)
	hotbar = bar
	for i in 5: # 1-4 eşyalar + Q karakter yeteneği
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(90, 84)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("panel", sb)
		var icon := TextureRect.new() # bazuka ve kılıçta simge; ilk HUD karesinde doldurulur
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15)
		cell.add_child(l)
		var cdb := ProgressBar.new() # bekleme süresi: dolu = yeni kullanıldı, boşalınca hazır
		cdb.show_percentage = false
		cdb.max_value = 1.0
		cdb.custom_minimum_size.y = 5
		cdb.size_flags_vertical = Control.SIZE_SHRINK_END
		cdb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cdb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		cdb.add_theme_stylebox_override("fill", _sb(Color(1, 1, 1, 0.85), 2, 0))
		cell.add_child(cdb)
		bar.add_child(cell)
		slots.append([sb, l, icon, cdb, 0.0])
	status_lbl = _full_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	status_lbl.offset_bottom = -150
	hud.hide()
	_build_settings(layer, theme)
	_build_chars(layer, theme)
	_build_weapons(layer, theme)


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


# ---------- Menü ----------

func _build_menu(layer: CanvasLayer, theme: Theme) -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE # boş yere tıklama giriş ekranını geçebilsin
	ui.theme = theme
	layer.add_child(ui)
	shade = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.06, 0.94))
	grad.set_color(1, Color(0.02, 0.02, 0.06, 0.0))
	grad.add_point(0.5, Color(0.02, 0.02, 0.06, 0.5))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	for edge in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]: # sinematik siyah şeritler
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.85)
		bar.set_anchors_preset(edge)
		bar.custom_minimum_size.y = 34
		if edge == Control.PRESET_BOTTOM_WIDE:
			bar.offset_top = -34
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(bar)

	# Giriş ekranı
	var intro := _page("intro")
	var iv := VBoxContainer.new()
	iv.set_anchors_preset(Control.PRESET_TOP_WIDE)
	iv.offset_top = 90
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 4)
	intro.add_child(iv)
	_logo(iv, "BAZUKA SAVAŞI", 124).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_txt(iv, "R O K E T L E R    •    K A O S    •    A R K A D A Ş L A R", 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = _txt(intro, "BAŞLAMAK İÇİN BİR TUŞA BAS", 24, 1.0)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -110; prompt.offset_bottom = -70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Ana menü: solda büyük düğmeler, sağda canlı sahnedeki ekip
	var mv := _column(_page("main"))
	_logo(mv, "BAZUKA\nSAVAŞI", 76)
	_txt(mv, "4 kişilik bazuka kaosu", 18, 0.75)
	mv.add_child(_gap(36))
	_big(mv, "OYNA", _show_page.bind("modes"))
	char_btn = _big(mv, "", _open_chars)
	_update_char_btn()
	_big(mv, "AYARLAR", _open_settings)
	_big(mv, "ÇIKIŞ", get_tree().quit)
	mv.add_child(_gap(30))
	var steam := _txt(mv, ("●  Steam: " + Net.my_name()) if Net.steam_ok else "●  Steam bağlı değil (Steam açık mı?)", 15, 0.7)
	steam.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if Net.steam_ok else Color(1.0, 0.6, 0.5))

	# Mod seçimi: iki büyük kart
	var modes := _page("modes")
	var mc := VBoxContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_theme_constant_override("separation", 26)
	modes.add_child(mc)
	_logo(mc, "OYUN MODU SEÇ", 58, Color.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 30)
	mc.add_child(cards)
	_mode_card(cards, "ARENA", "PvP  •  2–4 oyuncu", Color(1.0, 0.55, 0.15),
		"Herkes birbirine karşı. 52 karakter, bazuka, kalkan, duvar ve kılıç. Son ayakta kalan turu kazanır.",
		"▶  ARENAYA GİR", _pick_mode.bind("arena"))
	_mode_card(cards, "TOWER DEFENSE", "Co-op  •  1–4 oyuncu", Color(0.4, 0.75, 1.0),
		"Rapunzel'in kulesini savun. 10 dalga yaratık, seviye atladıkça kart seç, molada mağazadan duvar, tuzak ve taret al.",
		"▶  KULEYİ SAVUN", _pick_mode.bind("td"))
	var back := _btn(mc, "◀  Geri", _show_page.bind("main"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 220

	# Arena lobisi: Steam lobisi, arkadaşlar, başlat
	var lv := _column(_page("lobby"))
	lobby_title = _logo(lv, "ARENA", 72)
	lobby_sub = _txt(lv, MODES.arena[1], 17, 0.75)
	lv.add_child(_gap(14))
	var panel := PanelContainer.new()
	lv.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	panel.add_child(v)
	_btn(v, "Steam Lobisi Kur", Net.host_steam)
	_btn(v, "Arkadaşlar (davet et / lobisine katıl)", _show_friends)
	var scroll := ScrollContainer.new()
	friends_box = VBoxContainer.new()
	friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(friends_box)
	v.add_child(scroll)
	_btn(v, "Karakter Değiştir", _open_chars)
	weapon_btn = _btn(v, "", _open_weapons)
	start_btn = _btn(v, "▶  Oyunu Başlat (host)", _on_start)
	start_btn.custom_minimum_size.y = 48
	members = _lbl(v, "", 16)
	_btn(v, "Lobiden Çık", Net.leave)
	var test := HBoxContainer.new()
	test.add_theme_constant_override("separation", 9)
	v.add_child(test)
	var tl := _lbl(test, "Tek PC testi:", 14)
	tl.modulate = Color(1, 1, 1, 0.6)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF # HBox içinde harf harf kırılmasın
	for b in [_btn(test, "Yerel Host", Net.host_local), _btn(test, "Yerel Katıl", Net.join_local)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_gap(6))
	_btn(lv, "◀  Geri", _show_page.bind("modes"))

	# Her sayfada görünenler: alt bilgi satırı, sürüm, gelen davetler
	info = _txt(ui, "", 15, 0.8)
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_left = 40; info.offset_right = -260; info.offset_top = -78; info.offset_bottom = -42
	var ver := _txt(ui, "sürüm " + Updater.version(), 14, 0.55)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -200; ver.offset_right = -24; ver.offset_top = -64; ver.offset_bottom = -42
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	invite_box = VBoxContainer.new() # gelen davetler sağ üstte çıkar
	invite_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	invite_box.offset_left = -380; invite_box.offset_right = -30; invite_box.offset_top = 60
	ui.add_child(invite_box)


func _big(parent: Node, text: String, cb: Callable) -> Button:
	var b := _btn(parent, text, cb)
	b.theme_type_variation = "BigButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 56
	return b


func _page(n: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.hide()
	ui.add_child(c)
	pages[n] = c
	return c


## Sol sütun: ana menü ve lobi burada, sağ taraf sahneye kalır.
func _column(parent: Control) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	c.offset_left = 90; c.offset_right = 90 + 470
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 6)
	parent.add_child(c)
	return c


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _mode_card(parent: Node, title: String, tag: String, c: Color, desc: String, btn: String, cb: Callable) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 380)
	var sb := _sb(Color(0.05, 0.06, 0.1, 0.88), 16, 28)
	sb.set_border_width_all(2)
	sb.border_width_top = 6
	sb.border_color = c
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	_logo(v, title, 46, c)
	var t := _txt(v, tag, 18, 0.8)
	t.add_theme_color_override("font_color", c.lightened(0.4))
	_txt(v, desc, 17, 0.9).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var b := _btn(v, btn, cb if cb.is_valid() else func(): pass)
	b.custom_minimum_size.y = 54
	b.add_theme_font_size_override("font_size", 20)
	if not cb.is_valid(): # henüz yok: soluk kart, kapalı düğme, köşede "YAKINDA" bandı
		b.disabled = true
		card.modulate = Color(0.8, 0.8, 0.85)
		var badge := _logo(card, "YAKINDA", 22, Color.WHITE)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var bs := _sb(Color(0.85, 0.2, 0.25), 6, 8)
		badge.add_theme_stylebox_override("normal", bs)
		badge.rotation_degrees = 8


## Mod kartı: modu host seçer; lobiye bağlı istemci hostun modunda kalır.
func _pick_mode(m: String) -> void:
	if Net.online() and not multiplayer.is_server():
		_show_page("lobby")
		return
	set_mode(m)
	if Net.online():
		set_mode.rpc(m)
	_show_page("lobby")


@rpc("authority", "call_remote", "reliable")
func set_mode(m: String) -> void:
	mode = m if MODES.has(m) else "arena"
	lobby_title.text = MODES[mode][0]
	lobby_title.add_theme_font_size_override("font_size", 72 if mode == "arena" else 54) # uzun ad sütuna sığsın
	lobby_sub.text = MODES[mode][1]
	start_btn.text = MODES[mode][2]
	weapon_btn.visible = mode == "td"
	_update_weapon_btn()
	_refresh()


func _show_page(n: String) -> void:
	page = n
	for k in pages:
		pages[k].visible = k == n
	var p: Control = pages[n]
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.35)
	tw.tween_property(shade, "modulate:a", 0.25 if n == "intro" else (0.75 if n == "modes" else 1.0), 0.6)
	tw.tween_property(self, "cam_k", 0.0 if n == "intro" else 1.0, 1.4)
	var first := p.get_child(0) as Control # içerik soldan kayarak gelsin
	tw.tween_property(first, "position:x", first.position.x, 0.4).from(first.position.x - 50)


## Menüdeki canlı sahne: orman, seçili karakter ve ekibi, arkada ara ara patlamalar.
func _set_menu_bg(on: bool) -> void:
	if menu_bg:
		remove_child(menu_bg)
		menu_bg.queue_free()
		menu_bg = null
	if not on:
		return
	menu_bg = Node3D.new()
	add_child(menu_bg)
	var forest: Node3D = ForestScript.new()
	forest.spawns = SPAWNS
	menu_bg.add_child(forest)
	menu_cam = Camera3D.new()
	menu_cam.fov = 62
	menu_bg.add_child(menu_cam)
	menu_cam.current = true
	_menu_crew()


func _menu_crew() -> void:
	var old := menu_bg.get_node_or_null("Crew")
	if old:
		menu_bg.remove_child(old)
		old.queue_free()
	var crew := Node3D.new()
	crew.name = "Crew"
	crew.position = MENU_SPOT
	crew.rotation.y = PI / 4 # ekibin önü (+Z) köşeye, kamera haritanın içine baksın
	menu_bg.add_child(crew)
	var ids := [Net.my_char]
	ids.append_array(MENU_CREW.filter(func(i): return i != Net.my_char).slice(0, 4))
	var spots := [Vector3(0, 0, 0.3), Vector3(-1.45, 0, -0.6), Vector3(1.45, 0, -0.6), Vector3(-2.8, 0, -1.5), Vector3(2.8, 0, -1.5)]
	for k in ids.size():
		var m: Node3D = load("res://models/chars/%s.glb" % Chars.get_char(ids[k]).model).instantiate()
		m.scale = Vector3.ONE * 0.72
		m.position = spots[k]
		m.rotation.y = -spots[k].x * 0.1 # hafifçe ortaya dönük
		crew.add_child(m)
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		ap.play("Idle")
		ap.seek(randf() * ap.current_animation_length) # hepsi aynı anda sallanmasın


func _menu_anim(dt: float) -> void:
	menu_t += dt
	var crew := menu_bg.get_node_or_null("Crew") as Node3D
	if crew == null:
		return
	var sway := Vector3(sin(menu_t * 0.13) * 0.5, sin(menu_t * 0.21) * 0.1, sin(menu_t * 0.09) * 0.3)
	var pos: Vector3 = CAM_INTRO[0].lerp(CAM_MENU[0], cam_k) + sway
	var at: Vector3 = CAM_INTRO[1].lerp(CAM_MENU[1], cam_k)
	menu_cam.global_position = crew.global_transform * pos
	menu_cam.look_at(crew.global_transform * at)
	prompt.modulate.a = 0.45 + 0.55 * absf(sin(menu_t * 2.2))
	boom_t -= dt
	if boom_t <= 0.0: # ekibin arkasında, ormanın içinde patlamalar
		boom_t = randf_range(2.0, 3.8)
		var fx: Node3D = ExplosionScript.new()
		fx.position = crew.global_transform * Vector3(randf_range(-9, 9), 0.3, randf_range(-24, -11))
		fx.scale = Vector3.ONE * randf_range(1.0, 1.7)
		menu_bg.add_child(fx)
		Sfx.play3d(Sfx.boom, fx.position, -6.0)


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
	if menu_bg:
		_menu_crew()
	char_wrap.hide()


func _update_char_btn() -> void:
	var c := Chars.get_char(Net.my_char)
	char_btn.text = "KARAKTER  ·  %s" % c.name.to_upper()


# ---------- Silah seçimi (TD) ----------

func _build_weapons(layer: CanvasLayer, theme: Theme) -> void:
	weapon_wrap = ColorRect.new()
	weapon_wrap.color = Color(0.03, 0.04, 0.08, 0.98)
	weapon_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	weapon_wrap.theme = theme
	layer.add_child(weapon_wrap)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	weapon_wrap.add_child(v)
	_logo(v, "SİLAHINI SEÇ", 50).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_txt(v, "Tower Defense'e bu silahla girersin. Yenileri seviye kartlarından gelir.", 17, 0.7).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_grid = GridContainer.new()
	weapon_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	weapon_grid.add_theme_constant_override("h_separation", 12)
	weapon_grid.add_theme_constant_override("v_separation", 12)
	v.add_child(weapon_grid)
	var close := _btn(v, "Kapat", weapon_wrap.hide)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size.x = 220
	weapon_wrap.hide()


## Silahın 3B modelinden simge: tek kare çizilen küçük bir görüntü alanı, id başına bir kez kurulur.
var _icons := {}
func weapon_icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var W = load("res://weapons.gd")
	if not ResourceLoader.exists("res://models/%s.glb" % id):
		return null
	var model: Node3D = W.make_prop({"id": id})
	if id == "sword":
		model.rotation.z = PI / 2 # yassı yüzü kameraya
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	vp.add_child(model)
	var box := AABB()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.9, 0)
	sun.light_energy = 2.2 # koyu silahlar koyu kartta kaybolmasın
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.environment.ambient_light_energy = 2.5
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(box.get_longest_axis_size() * 0.72, 0.2) # yandan, hafif üstten: namlu sola bakar
	vp.add_child(cam)
	var c := box.get_center()
	cam.look_at_from_position(c + Vector3(3.0, 0.9, 1.1), c)
	_icons[id] = vp.get_texture()
	return _icons[id]


func _my_weapon() -> int:
	var w = Net.get("my_weapon")
	return weapon_sel if w == null else int(w)


## Kartlar her açılışta yeniden kurulur: 10 kart, seçili olan vurgulu.
func _open_weapons() -> void:
	for c in weapon_grid.get_children():
		c.queue_free()
	var rar: Dictionary = TdUi.consts("res://weapons.gd").get("RARITY", {})
	# Çubuklar en iyi silaha göre dolar. rate atış arası süre olduğu için tersi alınır.
	var bars := [["Hasar", func(w): return float(w.get("dmg", 0)) * w.get("n", 1), "%d"],
		["Atış hızı", func(w): return 1.0 / maxf(w.get("rate", 1.0), 0.05), "%.1f/sn"], ["Menzil", func(w): return float(w.get("range", 60.0)), "%d m"]]
	var wide := get_viewport().get_visible_rect().size.x >= 1560.0
	weapon_grid.columns = 5 if wide else 4 # dar pencerede taşmasın
	var order := range(weapon_list.size()) # nadirliğe göre: sıradan -> efsanevi (seçim numarası değişmez)
	order.sort_custom(func(a, b): return [rar.keys().find(weapon_list[a].get("rarity", "")), a] < [rar.keys().find(weapon_list[b].get("rarity", "")), b])
	for i in order:
		var w: Dictionary = weapon_list[i]
		var r: Dictionary = rar.get(w.get("rarity", ""), {})
		var c: Color = r.get("color", Color(0.75, 0.78, 0.85))
		var b := Button.new() # tıklanabilir kart: içindekiler fareyi yutmaz
		b.custom_minimum_size = Vector2(290, 318)
		var sb := _sb(Color(c.darkened(0.8), 0.95), 12, 0)
		sb.set_border_width_all(4 if i == _my_weapon() else 2)
		sb.border_color = Color(1, 0.85, 0.2) if i == _my_weapon() else Color(c, 0.7)
		var sh: StyleBoxFlat = sb.duplicate()
		sh.bg_color = Color(c.darkened(0.6), 0.95)
		for st in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("hover", sh)
		b.pressed.connect(_pick_weapon.bind(i))
		weapon_grid.add_child(b)
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 14)
		b.add_child(m)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		m.add_child(cv)
		_logo(cv, str(w.get("name", "?")).to_upper(), 25, c.lightened(0.25)).clip_text = true
		var tag := _lbl(cv, str(r.get("name", "")).to_upper() + ("   ✔ SEÇİLİ" if i == _my_weapon() else ""), 13)
		tag.add_theme_color_override("font_color", c)
		var pic := TextureRect.new()
		pic.texture = weapon_icon(str(w.get("id", "")))
		pic.custom_minimum_size.y = 84
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cv.add_child(pic)
		var d := _lbl(cv, str(w.get("desc", "")), 15)
		d.modulate.a = 0.85
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		d.clip_text = true
		for st in bars:
			var row := HBoxContainer.new()
			cv.add_child(row)
			var n := _lbl(row, st[0], 13)
			n.autowrap_mode = TextServer.AUTOWRAP_OFF
			n.custom_minimum_size.x = 84
			n.modulate.a = 0.7
			var pb := ProgressBar.new()
			pb.show_percentage = false
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pb.custom_minimum_size.y = 9
			pb.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.55), 4, 0))
			pb.add_theme_stylebox_override("fill", _sb(c, 4, 0))
			pb.max_value = weapon_list.map(st[1]).max()
			pb.value = st[1].call(w)
			row.add_child(pb)
			var num := _lbl(row, st[2] % st[1].call(w), 13)
			num.autowrap_mode = TextServer.AUTOWRAP_OFF
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			num.custom_minimum_size.x = 58
		for n in m.find_children("*", "Control", true, false) + [m]:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if weapon_list.is_empty():
		_lbl(weapon_grid, "Silah listesi yüklenemedi (weapons.gd).", 18)
	weapon_wrap.show()


func _pick_weapon(i: int) -> void:
	weapon_sel = i
	if Net.has_method("set_weapon"):
		Net.set_weapon(i)
	_update_weapon_btn()
	_refresh()
	weapon_wrap.hide()


func _weapon_name(i: int) -> String:
	return str(weapon_list[i].get("name", "?")) if i >= 0 and i < weapon_list.size() else "?"


func _update_weapon_btn() -> void:
	weapon_btn.text = "Silah Seç  ·  %s" % _weapon_name(_my_weapon())


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
	var wsel = Net.get("weapons") # peer -> silah no (net.gd'de varsa)
	for id in Net.names:
		var line: String = ("★ " if id == 1 else "• ") + str(Net.names[id]) + "  –  " + Chars.get_char(Net.chars.get(id, 0)).name
		if mode == "td" and wsel is Dictionary and wsel.has(id):
			line += "  •  " + _weapon_name(wsel[id])
		lines.append(line)
	members.text = "Lobidekiler:\n" + "\n".join(lines) if Net.online() else ""
	start_btn.disabled = not (Net.online() and multiplayer.is_server())
	if Net.online() and world == null and page in ["intro", "main", "modes"]:
		_show_page("lobby")


func _process(dt: float) -> void:
	if menu_bg:
		_menu_anim(dt)
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
		var left := [me.cd, me.shield_cd, me.wall_cd, me.sword_cd, me.skill_cd]
		for i in 5:
			var s: Array = slots[i]
			s[0].border_color = Color(1, 0.85, 0.2) if me.slot == i + 1 else Color(0.5, 0.5, 0.5, 0.6)
			if i == 0 or i == 3: # simgeli slot: yalnız tuş numarası, ad simgenin altında
				if s[2].texture == null:
					s[2].texture = weapon_icon("bazooka" if i == 0 else "sword")
				s[1].text = "%d

%s" % [i + 1, "BAZUKA" if i == 0 else "KILIÇ"]
				s[1].vertical_alignment = VERTICAL_ALIGNMENT_TOP
			else:
				s[1].text = texts[i]
			s[4] = maxf(s[4], left[i]) if left[i] > 0.0 else 0.0
			s[3].value = left[i] / s[4] if s[4] > 0.0 else 0.0
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
	if world == null and not char_wrap.visible and not weapon_wrap.visible and not settings_wrap.visible:
		if page == "intro" and (e is InputEventKey or e is InputEventMouseButton) and e.pressed:
			_show_page("main")
			get_viewport().set_input_as_handled()
			return
		if e.is_action_pressed("ui_cancel") and page in ["modes", "lobby"]:
			_show_page("modes" if page == "lobby" else "main")
			return
	if e.is_action_pressed("ui_cancel"):
		if char_wrap.visible:
			char_wrap.hide()
		elif weapon_wrap.visible:
			weapon_wrap.hide()
		elif settings_wrap.visible:
			_close_settings()
		elif world:
			_open_settings()
		return
	if world == null or settings_wrap.visible:
		return
	if e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if td_ui == null: # TD'de imleci td_ui yönetir (mağaza, kartlar açıkken görünür kalmalı)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.keycode == KEY_F10:
		Net.leave()


# ---------- Oyun akışı ----------

func _on_start() -> void:
	var ids := [1]
	ids.append_array(Array(multiplayer.get_peers()))
	ids.sort()
	if mode == "td":
		start_td.rpc(ids)
	else:
		start_game.rpc(ids)


@rpc("authority", "call_local", "reliable")
func start_game(ids: Array) -> void:
	_clear_world()
	_set_menu_bg(false)
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


## Tower Defense maçı: ortası açık harita, oyuncular kule dibinde; dalgaları td.gd yürütür.
@rpc("authority", "call_local", "reliable")
func start_td(ids: Array) -> void:
	_clear_world()
	_set_menu_bg(false)
	_build_world(TD_CLEAR)
	for i in ids.size():
		var p: CharacterBody3D = PlayerScript.new()
		p.name = str(ids[i])
		p.set_multiplayer_authority(ids[i])
		p.spawn_pos = TD_SPAWNS[i % TD_SPAWNS.size()]
		players.add_child(p)
	if ResourceLoader.exists("res://td.gd"):
		var t: Node = load("res://td.gd").new()
		t.name = "TD"
		world.add_child(t)
	td_ui = TdUi.new()
	td_ui.main = self
	ui_layer.add_child(td_ui)
	ui_layer.move_child(td_ui, hud.get_index() + 1) # ayarlar ve seçim ekranları üstte kalsın
	for n in [hotbar, help_lbl, spec_lbl]: # TD'de bunların yerini td_ui tutar
		n.hide()
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
	if td_ui: # TD arayüzü maçla birlikte gider, arena HUD'u eski haline döner
		ui_layer.remove_child(td_ui)
		td_ui.queue_free()
		td_ui = null
		for n in [hotbar, help_lbl, spec_lbl]:
			n.show()


func _back_to_menu() -> void:
	_clear_world()
	round_over = false
	hud.hide()
	settings_wrap.hide()
	ui.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu_bg == null:
		_set_menu_bg(true)
	_show_page("lobby" if Net.online() else "main")
	_refresh()


# ---------- Harita ----------

func _build_world(clear: Array = SPAWNS) -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var forest: Node3D = ForestScript.new()
	forest.spawns = clear
	world.add_child(forest)

	players = Node3D.new()
	players.name = "Players"
	world.add_child(players)
