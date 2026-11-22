extends Node3D
## Menü, HUD, test sahnesi ve tur yönetimi (tur kararlarını host verir).

const PlayerScript := preload("res://player.gd")
const ForestScript := preload("res://forest.gd")
const WorldScript := preload("res://world.gd")
const ExplosionScript := preload("res://explosion.gd")
const Chars := preload("res://characters.gd")
const TdUi := preload("res://td_ui.gd")
const Profile := preload("res://profile.gd")
const Balance := preload("res://balance.gd")
const COSM_SLOTS := {"tint": "Karakter Rengi", "title": "Unvan", "fx": "Kurşun ve Namlu Ateşi Rengi"}
## Profile.QUESTS istatistiği -> açılma koşulu ("%d" hedef). wins_<zorluk> ayrıca _quest_text'te.
const QUEST_TEXT := {"best_match_kills": "Tek maçta %d öldürme", "best_wave": "%d. dalgaya ulaş", "builds": "Toplam %d yapı kur",
	"hard_best_wave": "Zor ya da Kabus'ta %d. dalgaya ulaş", "wins": "%d maç kazan"}
const LANG_NAMES := ["Otomatik (sistem dili)", "Türkçe", "English"] # Settings.LANGUAGES sırasıyla; dil adları çevrilmez
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
	"td": ["TOWER DEFENSE", "Rapunzel'in kulesini birlikte savunun. Tek başına da başlatabilirsin.", "▶  Savunmayı Başlat (host)"],
	"world": ["AÇIK DÜNYA", "Lanetli topraklarda birlikte dolaşın. Tek başına da başlatabilirsin.", "▶  Dünyayı Başlat (host)"]}
const MENU_SPOT := Vector3(14, 0, 14) # menü sahnesi bir doğma noktasında: etrafı ağaçsız
const MENU_CREW := [40, 50, 34, 8, 26] # seçilen karakterin yanında duranlar
# Menü kamerası [konum, bakılan nokta], ekibe göre: giriş ekranı geniş ve ortalı, menüde ekip sağda.
const CAM_INTRO := [Vector3(0, 1.75, 6.6), Vector3(0, 1.55, 0)] # 6,6 m: daha geride ağaç var
const CAM_MENU := [Vector3(0.6, 1.4, 6.6), Vector3(-2.6, 1.1, 0)]

var mode := "arena" # "arena" | "td": host seçer, set_mode ile istemcilere gider
var ui: Control
var ui_layer: CanvasLayer
var td_ui: Control # yalnız TD maçında var (td_ui.gd)
var hotbar: Control # arena envanter çubuğu: TD'de gizlenir
var help_lbl: Control
var lobby_title: Label
var lobby_sub: Label
var weapon_btn: Button
var weapon_wrap: ColorRect
var weapon_grid: GridContainer
var weapon_list: Array = TdUi.consts("res://weapons.gd").get("LIST", []) # weapons.gd yoksa boş
var weapon_sel := 0 # Net.my_weapon yoksa yerel seçim
var dev := OS.is_debug_build() or "--dev" in OS.get_cmdline_user_args() # Yerel Host/Katıl düğmeleri
var diff_id := "normal" # TD zorluğu (host seçer, istemciler set_opts ile görür)
var endless := false
var diff_opt: OptionButton
var diff_hint: Label
var endless_chk: CheckBox
var td_box: VBoxContainer # yalnız TD lobisinde: zorluk + sonsuz mod
var find_box: VBoxContainer
var solo_box: VBoxContainer # tek başına zorluk seçimi
var solo_free_diff := false # tek başına seçilen zorluk kilit denetimine takılmaz (yalnız _on_start bir kez okur)
var growth_box: VBoxContainer
var _pf_names := {} # Profile'ın var olan statik fonksiyonları (iskelet/gerçek farkı)
var info: Label
var members: Label
var start_btn: Button
var crosshair: Control
var letterbox: Array[ColorRect] = [] # sinematik şeritler: yalnız giriş ekranında
var friends_box: VBoxContainer
var invite_box: VBoxContainer
var dmg_rect: ColorRect
var hud: Control
var char_lbl: Label
var hp_fill: Panel
var hp_fill_sb: StyleBoxFlat
var hp_trail: Panel # hasar sonrası yavaşça kısalan beyaz iz
var hp_accent: ColorRect # sol dikey karakter rengi şeridi
var hp_ticks: Control # her 20 canda bir çizgi
var hp_txt: Label
var trail_f := 1.0
var char_btn: Button
var char_wrap: ColorRect
var char_grid: HFlowContainer
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
var ver_lbl: Label
var chars_title: Label
var shake_slider: HSlider
var intro_logo: Label
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
		"slot5": KEY_5, "shop": KEY_B, "ready": KEY_G, "interact": KEY_E, "reload": KEY_R} # son satır TD için
	for a in keys:
		InputMap.add_action(a)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[a]
		InputMap.action_add_event(a, ev)
	var mouse := {"throw": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
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
	var bn := _sb(Color(0.13, 0.15, 0.23, 0.94), 9, 10)
	bn.set_border_width_all(1)
	bn.border_color = Color(1.0, 1.0, 1.0, 0.14)
	var bh := _sb(Color(0.88, 0.44, 0.12, 0.98), 9, 10)
	bh.set_border_width_all(1)
	bh.border_color = Color(1.0, 0.85, 0.45, 0.65)
	var bp := _sb(Color(0.62, 0.29, 0.08, 0.98), 9, 10)
	bp.set_border_width_all(1)
	bp.border_color = Color(1.0, 0.72, 0.3, 0.45)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", _sb(Color(0.10, 0.11, 0.15, 0.6), 9, 10))
	var focus := _sb(Color(0, 0, 0, 0), 9, 10) # klavye / gamepad odağı görünsün (fare odağı çizilmez)
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = Color(1.0, 0.62, 0.18)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.92, 0.94, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.65, 0.65, 0.7))
	for k in ["normal", "hover", "pressed"]:
		t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	var p := _sb(Color(0.05, 0.06, 0.10, 0.94), 14, 26)
	p.set_border_width_all(1)
	p.border_color = Color(1.0, 0.62, 0.22, 0.42)
	p.shadow_color = Color(0, 0, 0, 0.5)
	p.shadow_size = 16
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
	t.set_stylebox("focus", "BigButton", mh)
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


## Taktik nişangâh: 4 ince kol + merkez nokta, dış hatlı (her arka planda net seçilir).
class CrosshairView extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var gap := 5.0
		var arm := 9.0
		var dirs := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
		for d in dirs:
			draw_line(c + d * (gap - 1.0), c + d * (gap + arm + 1.0), Color(0, 0, 0, 0.78), 4.0)
		draw_circle(c, 2.6, Color(0, 0, 0, 0.78))
		for d in dirs:
			draw_line(c + d * gap, c + d * (gap + arm), Color(1, 1, 1, 0.95), 2.0)
		draw_circle(c, 1.5, Color(1.0, 0.92, 0.55, 0.95))


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
	crosshair = CrosshairView.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	_build_hp_bar()

	# Sağ üst oyuncu / skor kartı (yarı saydam koyu cam panel)
	var score_card := PanelContainer.new()
	score_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	score_card.offset_top = 16; score_card.offset_right = -20
	var sc_sb := _sb(Color(0.05, 0.06, 0.10, 0.76), 10, 0)
	sc_sb.content_margin_left = 14; sc_sb.content_margin_right = 14
	sc_sb.content_margin_top = 8; sc_sb.content_margin_bottom = 8
	sc_sb.set_border_width_all(1)
	sc_sb.border_color = Color(1.0, 1.0, 1.0, 0.14)
	sc_sb.shadow_color = Color(0, 0, 0, 0.35)
	sc_sb.shadow_size = 8
	score_card.add_theme_stylebox_override("panel", sc_sb)
	hud.add_child(score_card)
	score_lbl = _lbl(score_card, "", 16)
	score_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	score_lbl.add_theme_constant_override("outline_size", 3)
	score_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))

	center_lbl = _full_label(52, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	spec_lbl = _full_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	spec_lbl.offset_top = 60

	# En altta ince, çakışmasız kontrol şeridi
	var help_pill := PanelContainer.new()
	help_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help_pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_pill.offset_bottom = -8
	var hp_pill_sb := _sb(Color(0.04, 0.05, 0.09, 0.62), 10, 0)
	hp_pill_sb.content_margin_left = 16; hp_pill_sb.content_margin_right = 16
	hp_pill_sb.content_margin_top = 4; hp_pill_sb.content_margin_bottom = 4
	hp_pill_sb.set_border_width_all(1)
	hp_pill_sb.border_color = Color(1, 1, 1, 0.10)
	help_pill.add_theme_stylebox_override("panel", hp_pill_sb)
	hud.add_child(help_pill)
	var hl := _lbl(help_pill,
		"WASD Yürü  •  Boşluk Zıpla (2x)  •  Shift Atıl  •  1-4 Eşya  •  Q Yetenek  •  Sol Tık Kullan  •  ESC Menü", 12)
	hl.autowrap_mode = TextServer.AUTOWRAP_OFF
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.add_theme_color_override("font_color", Color(0.88, 0.91, 0.96, 0.9))
	help_lbl = help_pill

	# Alt envanter çubuğu (hotbar): koyu cam dock, tuş rozetleri, taşmayan hizalı simge ve durum metinleri
	var dock := PanelContainer.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -42
	var dock_sb := _sb(Color(0.04, 0.05, 0.09, 0.74), 14, 0)
	dock_sb.content_margin_left = 10; dock_sb.content_margin_right = 10
	dock_sb.content_margin_top = 8; dock_sb.content_margin_bottom = 8
	dock_sb.set_border_width_all(1)
	dock_sb.border_color = Color(1.0, 0.86, 0.55, 0.22)
	dock_sb.shadow_color = Color(0, 0, 0, 0.45)
	dock_sb.shadow_size = 12
	dock.add_theme_stylebox_override("panel", dock_sb)
	hud.add_child(dock)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 8)
	dock.add_child(bar)
	hotbar = dock

	var keys_txt := ["1", "2", "3", "4", "Q"]
	for i in 5: # 1-4 eşyalar + Q karakter yeteneği
		if i == 4: # Eşyalar ile Q yeteneği arasında ince dikey ayırıcı
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(2, 66)
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sep.color = Color(1, 1, 1, 0.16)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bar.add_child(sep)
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(138 if i == 4 else 94, 88)
		cell.clip_contents = true
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := _sb(Color(0.09, 0.11, 0.17, 0.86), 10, 0)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.55, 0.60, 0.70, 0.35)
		cell.add_theme_stylebox_override("panel", sb)

		var inner := Control.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(inner)

		# Sol üst tuş rozeti (keycap)
		var key_box := PanelContainer.new()
		key_box.position = Vector2(6, 5)
		key_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_sb := _sb(Color(0.03, 0.04, 0.07, 0.88), 5, 0)
		key_sb.content_margin_left = 6; key_sb.content_margin_right = 6
		key_sb.content_margin_top = 1; key_sb.content_margin_bottom = 1
		key_sb.set_border_width_all(1)
		key_sb.border_color = Color(1, 1, 1, 0.22)
		key_box.add_theme_stylebox_override("panel", key_sb)
		var key_lbl := _lbl(key_box, keys_txt[i], 11)
		key_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		key_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65) if i == 4 else Color(0.88, 0.92, 1.0))
		inner.add_child(key_box)

		# Orta simge alanı (Bazuka / Kılıç için taşmayan boşluklu yerleşim)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 10; icon.offset_right = -10
		icon.offset_top = 16; icon.offset_bottom = -26
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)

		# Başlık etiketi (altta veya ortada temiz hizalı)
		var name_lbl := Label.new()
		name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_lbl.offset_left = 5; name_lbl.offset_right = -5
		name_lbl.offset_top = 24 if (i != 0 and i != 3) else 58
		name_lbl.offset_bottom = -26 if (i != 0 and i != 3) else -8
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_size_override("font_size", 12 if i == 4 else 13)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		name_lbl.add_theme_constant_override("outline_size", 3)
		name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		inner.add_child(name_lbl)

		# Alt durum etiketi (HAZIR / AKTİF / süre)
		var sub_lbl := Label.new()
		sub_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		sub_lbl.offset_left = 5; sub_lbl.offset_right = -5
		sub_lbl.offset_top = -24; sub_lbl.offset_bottom = -7
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_constant_override("outline_size", 3)
		sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		inner.add_child(sub_lbl)

		# Bekleme süresi ince alt barı
		var cdb := ProgressBar.new()
		cdb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cdb.offset_left = 4; cdb.offset_right = -4
		cdb.offset_top = -5; cdb.offset_bottom = -1
		cdb.show_percentage = false
		cdb.max_value = 1.0
		cdb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cdb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		cdb.add_theme_stylebox_override("fill", _sb(Color(1.0, 0.82, 0.32, 0.92), 2, 0))
		inner.add_child(cdb)

		bar.add_child(cell)
		slots.append([sb, name_lbl, icon, cdb, 0.0, sub_lbl, key_sb])

	status_lbl = _full_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	status_lbl.offset_bottom = -152
	hud.hide()
	_build_settings(layer, theme)
	_build_chars(layer, theme)
	_build_weapons(layer, theme)


## Sol üst: modern cam kart içinde karakter adı, renk şeridi ve yuvarlatılmış 20'lik dilimli can barı.
func _build_hp_bar() -> void:
	var card := PanelContainer.new()
	card.position = Vector2(18, 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card_sb := _sb(Color(0.05, 0.06, 0.10, 0.78), 12, 0)
	card_sb.set_border_width_all(1)
	card_sb.border_color = Color(1.0, 1.0, 1.0, 0.15)
	card_sb.shadow_color = Color(0, 0, 0, 0.40)
	card_sb.shadow_size = 10
	card.add_theme_stylebox_override("panel", card_sb)
	hud.add_child(card)

	var box := Control.new()
	box.custom_minimum_size = Vector2(HP_W + 32, 68)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	hp_accent = ColorRect.new()
	hp_accent.position = Vector2(6, 10)
	hp_accent.size = Vector2(4, 48)
	hp_accent.color = Color(1.0, 0.72, 0.22)
	hp_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp_accent)

	char_lbl = _lbl(box, "", 16)
	char_lbl.position = Vector2(18, 7)
	char_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	char_lbl.add_theme_constant_override("outline_size", 4)
	char_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	var back := Panel.new()
	back.position = Vector2(18, 34)
	back.size = Vector2(HP_W + 4, 24)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_sb := _sb(Color(0.02, 0.03, 0.05, 0.90), 7, 0)
	back_sb.set_border_width_all(1)
	back_sb.border_color = Color(1, 1, 1, 0.12)
	back.add_theme_stylebox_override("panel", back_sb)
	box.add_child(back)

	hp_trail = Panel.new()
	hp_trail.position = Vector2(20, 36)
	hp_trail.size = Vector2(HP_W, 20)
	hp_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_trail.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.85), 5, 0))
	box.add_child(hp_trail)

	hp_fill = Panel.new()
	hp_fill.position = Vector2(20, 36)
	hp_fill.size = Vector2(HP_W, 20)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_fill_sb = _sb(Color(0.28, 0.88, 0.36), 5, 0)
	hp_fill.add_theme_stylebox_override("panel", hp_fill_sb)
	box.add_child(hp_fill)

	# Üst ince cam parıltı şeridi
	var gloss := ColorRect.new()
	gloss.position = Vector2(21, 37)
	gloss.size = Vector2(HP_W - 2, 7)
	gloss.color = Color(1, 1, 1, 0.18)
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gloss)

	hp_ticks = Control.new()
	hp_ticks.position = Vector2(20, 36)
	hp_ticks.size = Vector2(HP_W, 20)
	hp_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(hp_ticks)

	hp_txt = _lbl(box, "", 14)
	hp_txt.position = Vector2(20, 35)
	hp_txt.size = Vector2(HP_W, 22)
	hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_txt.add_theme_color_override("font_color", Color.WHITE)
	hp_txt.add_theme_constant_override("outline_size", 4)
	hp_txt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))


func _update_hp_bar(me: Node, dt: float) -> void:
	var f := clampf(float(me.hp) / me.max_hp, 0.0, 1.0)
	trail_f = f if f >= trail_f else move_toward(trail_f, f, dt * 0.5)
	hp_fill.size.x = maxf(HP_W * f, 0.0)
	hp_fill.visible = f > 0.001
	hp_trail.size.x = maxf(HP_W * trail_f, 0.0)
	hp_trail.visible = trail_f > 0.001
	var c := Color(0.96, 0.82, 0.18).lerp(Color(0.24, 0.88, 0.42), (f - 0.5) * 2.0) if f > 0.5 \
		else Color(0.92, 0.16, 0.14).lerp(Color(0.96, 0.82, 0.18), f * 2.0)
	if f <= 0.3 and f > 0.0: # kritik: yanıp söner
		c = c.lerp(Color.WHITE, 0.35 * absf(sin(Time.get_ticks_msec() * 0.008)))
	hp_fill_sb.bg_color = c
	hp_txt.text = "%d / %d" % [me.hp, me.max_hp]
	var n: int = me.max_hp / 20 - 1
	if hp_ticks.get_child_count() != n: # dilim çizgileri (can üst sınırı değişince yeniden)
		for t in hp_ticks.get_children():
			t.queue_free()
		for k in n:
			var line := ColorRect.new()
			line.color = Color(0, 0, 0, 0.38)
			line.size = Vector2(2, 20)
			line.position.x = HP_W * (k + 1) * 20.0 / me.max_hp - 1.0
			hp_ticks.add_child(line)
	char_lbl.text = "%s  •  %s" % [tr(me.ch.name), tr(me.ch.role)]
	char_lbl.modulate = me.ch.color.lightened(0.35)
	hp_accent.color = me.ch.color.lightened(0.15)


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
		letterbox.append(bar)

	# Giriş ekranı
	var intro := _page("intro")
	var iv := VBoxContainer.new()
	iv.set_anchors_preset(Control.PRESET_TOP_WIDE)
	iv.offset_top = 90
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_theme_constant_override("separation", 4)
	intro.add_child(iv)
	intro_logo = _logo(iv, "BAZUKA SAVAŞI", 124)
	intro_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_big(mv, "GELİŞİM", _open_growth)
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
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_mode_card(cards, "AÇIK DÜNYA", "Co-op  •  1–4 oyuncu", Color(0.7, 0.45, 1.0),
		"Lanetli orman, sis bataklığı, kül dağları ve yıkık krallık: 1 km'lik karanlık dünyayı keşfet.",
		"▶  DÜNYAYA ÇIK", _pick_mode.bind("world"))
	var quick := HBoxContainer.new()
	quick.alignment = BoxContainer.ALIGNMENT_CENTER
	quick.add_theme_constant_override("separation", 20)
	mc.add_child(quick)
	var solo_b := _btn(quick, "⚡  TEK BAŞINA OYNA  (Steam gerekmez)", _solo_td)
	solo_b.custom_minimum_size = Vector2(520, 60)
	solo_b.add_theme_font_size_override("font_size", 22)
	var find_b := _btn(quick, "🔍  Açık Lobi Bul", _open_find)
	find_b.custom_minimum_size = Vector2(300, 60)
	var back := _btn(mc, "◀  Geri", _show_page.bind("main"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size.x = 220

	# Arena lobisi: Steam lobisi, arkadaşlar, başlat
	var lv := _column(_page("lobby"))
	lobby_title = _logo(lv, "ARENA", 72)
	lobby_sub = _txt(lv, MODES.arena[1], 17, 0.75)
	lv.add_child(_gap(8))
	var panel := PanelContainer.new()
	var ps: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer").duplicate()
	ps.set_content_margin_all(16) # 720p: TD lobisi (zorluk + sonsuz satırı) ekrana sığsın
	panel.add_theme_stylebox_override("panel", ps)
	lv.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 9)
	v.add_child(hrow)
	_btn(hrow, "Steam Lobisi Kur", Net.host_steam).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pub := CheckBox.new()
	pub.text = "Herkese açık"
	pub.toggled.connect(func(on: bool): Net.public_lobby = on)
	hrow.add_child(pub)
	_btn(v, "Arkadaşlar (davet et / lobisine katıl)", _show_friends)
	var scroll := ScrollContainer.new()
	friends_box = VBoxContainer.new()
	friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(friends_box)
	scroll.visible = false # liste boşken ayırma boşluğu da kalmasın
	v.add_child(scroll)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 9)
	v.add_child(crow)
	_btn(crow, "Karakter Değiştir", _open_chars).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_btn = _btn(crow, "", _open_weapons)
	weapon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	td_box = VBoxContainer.new()
	td_box.add_theme_constant_override("separation", 4)
	v.add_child(td_box)
	diff_opt = OptionButton.new()
	for k in Balance.DIFFS:
		diff_opt.add_item(Balance.DIFFS[k].name)
	diff_opt.item_selected.connect(_pick_diff)
	td_box.add_child(diff_opt)
	diff_hint = _lbl(td_box, "", 14)
	endless_chk = CheckBox.new()
	endless_chk.text = "Sonsuz Mod"
	endless_chk.toggled.connect(func(on: bool): endless = on; _sync_opts())
	td_box.add_child(endless_chk)
	start_btn = _btn(v, "▶  Oyunu Başlat (host)", _on_start)
	start_btn.custom_minimum_size.y = 48
	members = _lbl(v, "", 16)
	_btn(v, "Lobiden Çık", Net.leave)
	var test := HBoxContainer.new()
	test.add_theme_constant_override("separation", 9)
	test.visible = dev
	v.add_child(test)
	var tl := _lbl(test, "Tek PC testi:", 14)
	tl.modulate = Color(1, 1, 1, 0.6)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF # HBox içinde harf harf kırılmasın
	for b in [_btn(test, "Yerel Host", Net.host_local), _btn(test, "Yerel Katıl", Net.join_local)]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_gap(6))
	_btn(lv, "◀  Geri", _show_page.bind("modes"))

	# Tek başına: zorluk seçimi
	var sv := _column(_page("solo"))
	_logo(sv, "ZORLUK", 44)
	_txt(sv, "Kuleyi hangi zorlukta savunacaksın?", 17, 0.75)
	solo_box = VBoxContainer.new()
	solo_box.add_theme_constant_override("separation", 6)
	sv.add_child(solo_box)
	_btn(sv, "◀  Geri", _show_page.bind("modes"))

	# Açık lobi bul
	var fv := _column(_page("find"))
	_logo(fv, "LOBİ BUL", 64)
	_txt(fv, "Herkese açık, senin sürümünde lobiler.", 17, 0.75)
	var fs := ScrollContainer.new()
	fs.custom_minimum_size.y = 300
	fs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fv.add_child(fs)
	find_box = VBoxContainer.new()
	find_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs.add_child(find_box)
	_btn(fv, "↻  Yenile", _open_find)
	_btn(fv, "◀  Geri", _show_page.bind("modes"))
	Net.lobbies_found.connect(_on_lobbies)

	# Gelişim: Altın Saç, kalıcı yükseltmeler, açılımlar
	var gv := _column(_page("growth"))
	_logo(gv, "GELİŞİM", 64)
	var gs := ScrollContainer.new()
	gs.custom_minimum_size.y = 430
	gs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gv.add_child(gs)
	growth_box = VBoxContainer.new()
	growth_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	growth_box.add_theme_constant_override("separation", 6)
	gs.add_child(growth_box)
	_btn(gv, "◀  Geri", _show_page.bind("main"))

	# Her sayfada görünenler: alt bilgi satırı, sürüm, gelen davetler
	info = _txt(ui, "", 15, 0.8)
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_left = 40; info.offset_right = -260; info.offset_top = -78; info.offset_bottom = -42
	ver_lbl = _txt(ui, tr("sürüm %s") % Updater.version(), 14, 0.55)
	ver_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver_lbl.offset_left = -200; ver_lbl.offset_right = -24; ver_lbl.offset_top = -64; ver_lbl.offset_bottom = -42
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	card.custom_minimum_size = Vector2(370, 380)
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
	var dl := _txt(v, desc, 17, 0.9)
	dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dl.custom_minimum_size.x = 310 # sıfır genişlikte sarma, kutuyu dev yüksekliğe şişirmesin
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
	td_box.visible = mode == "td"
	_update_diff_ui()
	_update_weapon_btn()
	_refresh()


func _show_page(n: String) -> void:
	page = n
	if n == "intro": # İngilizce ad ("BAZOOKA BUDDIES") daha uzun: 720p'de ekrana sığsın
		var w := intro_logo.get_theme_font("font").get_string_size(intro_logo.atr(intro_logo.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 124).x
		intro_logo.add_theme_font_size_override("font_size", mini(124, int(124.0 * (get_viewport().get_visible_rect().size.x - 80.0) / maxf(w, 1.0))))
	for k in pages:
		pages[k].visible = k == n
	var p: Control = pages[n]
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.35)
	for b in letterbox:
		tw.tween_property(b, "modulate:a", 1.0 if n == "intro" else 0.0, 0.4)
	tw.tween_property(shade, "modulate:a", 0.25 if n == "intro" else (0.75 if n == "modes" else 1.0), 0.6)
	tw.tween_property(self, "cam_k", 0.0 if n == "intro" else 1.0, 1.4)
	var first := p.get_child(0) as Control # içerik soldan kayarak gelsin
	if n == "modes": # sarmalı etiketler kutuyu şişirip ekran dışına itebiliyor: tam ekrana geri çek
		first.set_anchors_and_offsets_preset.call_deferred(Control.PRESET_FULL_RECT)
	tw.tween_property(first, "position:x", first.position.x, 0.4).from(first.position.x - 50)
	for b: Button in p.find_children("*", "Button", true, false): # klavye / gamepad ile gezilebilsin
		if b.visible and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus.call_deferred()
			break


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
	chars_title = _lbl(v, tr("KARAKTERİNİ SEÇ   •   %d karakter") % Chars.LIST.size(), 30)
	chars_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
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
	char_grid = grid
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
	var sun := DirectionalLight3D.new() # 3 noktalı stüdyo aydınlatması
	sun.rotation = Vector3(-0.6, 0.55, 0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 1.25
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -1.9, 0)
	fill.light_color = Color(0.62, 0.78, 1.0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	var rim_l := DirectionalLight3D.new()
	rim_l.rotation = Vector3(0.2, 2.75, 0)
	rim_l.light_color = Color(1.0, 0.82, 0.52)
	rim_l.light_energy = 0.7
	vp.add_child(rim_l)
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
	var rim := ShaderMaterial.new()
	rim.shader = preload("res://shaders/char_rim.gdshader")
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/outline.gdshader")
	rim.next_pass = outline
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = rim
	char_view.add_child(m)
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	ap.play("Idle")
	char_info.name.text = tr(c.name)
	char_info.name.add_theme_color_override("font_color", c.color.lightened(0.3))
	char_info.role.text = tr(c.role)
	char_info.stats.text = tr("Can %d   •   Hız %%%d   •   Kalkan %d sn") % [c.get("hp", 100), roundi(c.get("speed", 1.0) * 100.0), c.get("shield_cd", 8.0)]
	char_info.passive.text = tr("Pasif: %s") % passive_text(c)
	char_info.skill.text = tr("Q – %s (%d sn)\n%s") % [tr(c.skill_name), c.cd, tr(c.skill_desc)]
	char_info.quote.text = "\"%s\"" % tr(c.quote)


## Chars.passive_text'in çevrilen kopyası (characters.gd veri dosyası değişmesin diye burada).
## i18n_test, Türkçe'de ikisinin aynı çıktığını 52 karakterde denetler.
func passive_text(c: Dictionary) -> String:
	var p := PackedStringArray()
	if c.has("hp"): p.append(tr("%d can") % c.hp)
	if c.has("speed"): p.append(tr("%+d%% hız") % roundi((c.speed - 1.0) * 100.0))
	if c.has("shield_cd"): p.append(tr("kalkan %d sn'de dolar") % c.shield_cd)
	if c.has("dodge"): p.append(tr("%%%d şansla hasardan sıyrılır") % roundi(c.dodge * 100.0))
	if c.has("throw_mult"): p.append(tr("roketleri %%%d hızlı") % roundi((c.throw_mult - 1.0) * 100.0))
	if c.has("fire_cd"): p.append(tr("%%%d seri ateş") % roundi((1.0 / c.fire_cd - 1.0) * 100.0))
	if c.has("rocket_dmg"): p.append(tr("roket hasarı %d") % c.rocket_dmg)
	if c.has("sword_dmg"): p.append(tr("kılıç hasarı %d") % c.sword_dmg)
	if c.has("regen"): p.append(tr("saniyede %s can yeniler") % str(c.regen))
	if c.has("jump"): p.append(tr("%%%d yüksek zıplar") % roundi((c.jump - 1.0) * 100.0))
	if c.has("air_jumps"): p.append(tr("havada %d kez zıplar") % c.air_jumps)
	if c.has("wall_cd"): p.append(tr("duvar %d sn'de dolar") % c.wall_cd)
	if c.get("sit_shield", false): p.append(tr("2 sn durunca kendiliğinden kalkan alır"))
	return " • ".join(p) if not p.is_empty() else tr("Dengeli: zaafı da yok, üstünlüğü de.")


func _open_chars() -> void:
	for i in char_grid.get_child_count(): # ipucu: dil değişebildiği için her açılışta
		var c := Chars.get_char(i)
		char_grid.get_child(i).tooltip_text = "%s – %s" % [tr(c.name), tr(c.skill_name)]
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
	char_btn.text = tr("KARAKTER  ·  %s") % tr(c.name).to_upper()


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
	var scroll := ScrollContainer.new() # 720p'de 3. satır ve Kapat ekrana sığsın
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	weapon_grid = GridContainer.new()
	weapon_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
	weapon_grid.add_theme_constant_override("h_separation", 12)
	weapon_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(weapon_grid)
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
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	vp.add_child(model)
	var box := AABB()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.65, 0.85, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 2.3 # koyu silahlar koyu kartta kaybolmasın
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(0.3, -2.4, 0)
	rim.light_color = Color(0.68, 0.84, 1.0)
	rim.light_energy = 1.15
	vp.add_child(rim)
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
	_fix_weapon()
	for c in weapon_grid.get_children():
		c.queue_free()
	var rar: Dictionary = TdUi.consts("res://weapons.gd").get("RARITY", {})
	# Çubuklar en iyi silaha göre dolar. rate atış arası süre olduğu için tersi alınır.
	var bars := [["Hasar", func(w): return float(w.get("dmg", 0)) * w.get("n", 1), "%d"],
		["Atış hızı", func(w): return 1.0 / maxf(w.get("rate", 1.0), 0.05), tr("%.1f/sn")], ["Menzil", func(w): return float(w.get("range", 60.0)), "%d m"]]
	var wide := get_viewport().get_visible_rect().size.x >= 1560.0
	weapon_grid.columns = 5 if wide else 4 # dar pencerede taşmasın
	var order := range(weapon_list.size()) # nadirliğe göre: sıradan -> efsanevi (seçim numarası değişmez)
	order.sort_custom(func(a, b): return [rar.keys().find(weapon_list[a].get("rarity", "")), a] < [rar.keys().find(weapon_list[b].get("rarity", "")), b])
	for i in order:
		var w: Dictionary = weapon_list[i]
		var r: Dictionary = rar.get(w.get("rarity", ""), {})
		var c: Color = r.get("color", Color(0.75, 0.78, 0.85))
		var b := Button.new() # tıklanabilir kart: içindekiler fareyi yutmaz
		b.custom_minimum_size = Vector2(290, 300)
		var sb := _sb(Color(c.darkened(0.8), 0.95), 12, 0)
		sb.set_border_width_all(4 if i == _my_weapon() else 2)
		sb.border_color = Color(1, 0.85, 0.2) if i == _my_weapon() else Color(c, 0.7)
		var sh: StyleBoxFlat = sb.duplicate()
		sh.bg_color = Color(c.darkened(0.6), 0.95)
		for st in ["normal", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("hover", sh)
		var locked := not _unlocked("weapon:" + str(w.get("id", "")))
		if locked:
			b.disabled = true
			b.modulate = Color(0.5, 0.5, 0.55)
		else:
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
		_logo(cv, tr(str(w.get("name", "?"))).to_upper(), 22, c.lightened(0.25)).clip_text = true
		var tag := _lbl(cv, tr(str(r.get("name", ""))).to_upper() + (tr("   ✔ SEÇİLİ") if i == _my_weapon() else ""), 13)
		tag.add_theme_color_override("font_color", c)
		var pic := TextureRect.new()
		pic.texture = weapon_icon(str(w.get("id", "")))
		pic.custom_minimum_size.y = 84
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cv.add_child(pic)
		var d := _lbl(cv, tr(str(w.get("desc", ""))), 15)
		d.modulate.a = 0.85
		d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		d.custom_minimum_size.y = 42 # iki satır: clip_text tek satıra indirmesin
		d.clip_text = true
		if locked: # açma koşulu: "Tek maçta 150 öldürme (112/150)"
			pic.custom_minimum_size.y = 56
			d.text = tr("🔒 KİLİTLİ") + "\n" + _quest_text("weapon:" + str(w.get("id", "")))
			d.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
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


# ---------- Profil, zorluk, lobi bul, gelişim ----------

## Profile'ın gerçek API'si birleşince çalışsın, iskeletle çökmesin: fonksiyon yoksa varsayılan döner.
func _pf(fn: String, args := [], def = null) -> Variant:
	if _pf_names.is_empty():
		var pg: GDScript = Profile
		for m in pg.get_script_method_list():
			_pf_names[m.name] = true
	var pg: GDScript = Profile
	return pg.callv(fn, args) if _pf_names.has(fn) else def


func _unlocked(id: String) -> bool:
	return bool(_pf("is_unlocked", [id], true))


func _diff_keys() -> Array:
	return Balance.DIFFS.keys()


## "🔒 Normal'i kazan": Balance.DIFFS[...].unlock = "win_<önceki>".
func _diff_lock_text(k: String) -> String:
	var u: String = Balance.DIFFS[k].get("unlock", "")
	return tr("🔒 %s'i kazan") % tr(Balance.DIFFS[u.trim_prefix("win_")].name) if u.begins_with("win_") and Balance.DIFFS.has(u.trim_prefix("win_")) else tr("🔒 Kilitli")


func _update_diff_ui() -> void:
	var keys := _diff_keys()
	for i in keys.size():
		var ok := _unlocked("diff:" + keys[i])
		diff_opt.set_item_disabled(i, not ok)
		diff_opt.set_item_text(i, tr(Balance.DIFFS[keys[i]].name) + ("" if ok else "  " + _diff_lock_text(keys[i])))
	diff_opt.select(maxi(keys.find(diff_id), 0))
	var host := not Net.online() or multiplayer.is_server()
	if host and not _unlocked("diff:" + diff_id): # katıldığın lobinin kilitli zorluğu sende kalmasın
		diff_id = "normal"
		diff_opt.select(maxi(keys.find(diff_id), 0))
	if host and not _unlocked("mode:endless"):
		endless = false
	diff_opt.disabled = not host
	endless_chk.disabled = not host or not _unlocked("mode:endless")
	endless_chk.set_pressed_no_signal(endless)
	endless_chk.text = "Sonsuz Mod" if _unlocked("mode:endless") else "Sonsuz Mod  🔒 Kilitli"
	diff_hint.text = "" if host else "Zorluğu host seçer."
	diff_hint.visible = diff_hint.text != ""


func _pick_diff(i: int) -> void:
	diff_id = _diff_keys()[i]
	_sync_opts()


func _sync_opts() -> void:
	_refresh()


@rpc("authority", "call_remote", "reliable")
func set_opts(d: String, e: bool) -> void:
	diff_id = d if Balance.DIFFS.has(d) else "normal"
	endless = e
	_update_diff_ui()


## Tek başına: önce zorluk seçilir (kilitsiz; Kabus listede yok), sonra maç başlar.
func _solo_td() -> void:
	if Net.online():
		Net.leave()
	set_mode("td")
	for c in solo_box.get_children():
		c.queue_free()
	for k in ["easy", "normal", "hard"]:
		var d: Dictionary = Balance.DIFFS[k]
		var b := _btn(solo_box, "%s   •   %s" % [tr(d.name), _diff_effect(d)], _solo_start.bind(k))
		b.custom_minimum_size = Vector2(560, 46)
	_show_page("solo")


## "Yaratık canı %75 • hasar %80 • para %115 • ödül %50": DIFFS çarpanlarının kısa özeti.
func _diff_effect(d: Dictionary) -> String:
	return tr("Yaratık canı %%%d  •  hasar %%%d  •  para %%%d") % [roundi(d.hp * 100.0), roundi(d.dmg * 100.0), roundi(d.money * 100.0)]


func _solo_start(k: String) -> void:
	diff_id = k
	solo_free_diff = true
	_on_start()


func _open_find() -> void:
	_show_page("find")
	for c in find_box.get_children():
		c.queue_free()
	if not Net.steam_ok:
		_lbl(find_box, "Lobi bulmak için Steam açık olmalı. Steam'siz oynamak için TEK BAŞINA OYNA'yı kullan.", 17)
		return
	_lbl(find_box, "Aranıyor…", 17)
	Net.find_lobbies()


func _on_lobbies(list: Array) -> void:
	for c in find_box.get_children():
		c.queue_free()
	if list.is_empty():
		_lbl(find_box, "Açık lobi yok — sen kur!", 18)
	for l in list:
		var d: String = tr(Balance.DIFFS.get(l.diff, {}).get("name", "-"))
		var m: String = tr(MODES.get(l.mode, ["?"])[0])
		_btn(find_box, "▶ %s  •  %s  •  %s  •  %d/4" % [l.name, m, d, l.n], Net.join_lobby.bind(l.id))


func _open_growth() -> void:
	_show_page("growth")
	for c in growth_box.get_children():
		c.queue_free()
	var gold = _pf("gold", [], null)
	if gold == null:
		_lbl(growth_box, "Yakında", 22)
		return
	_lbl(growth_box, tr("Altın Saç: %d") % int(gold), 24).add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	_lbl(growth_box, "Yalnızca görünüm: oyuna avantaj vermez. Diğer oyuncular da görür.", 14).modulate.a = 0.72
	var sel: Dictionary = Profile.cosm_sel()
	for slot in Profile.SLOTS:
		_lbl(growth_box, tr(COSM_SLOTS[slot]), 20)
		for id in Profile.COSMETICS:
			var c: Dictionary = Profile.COSMETICS[id]
			if c.slot != slot:
				continue
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.08, 0.13, 0.88), 8, 10))
			growth_box.add_child(row)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			row.add_child(h)
			var nm := _lbl(h, ("●  " if slot != "title" else "[%s]  " % tr(c.text)) + tr(c.name), 18)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if c.has("color"):
				nm.add_theme_color_override("font_color", c.color)
			var owned: bool = Profile.cosm_owned(id)
			var on: bool = sel[slot] == id
			var b := _btn(h, tr("Seçili") if on else tr("Seç") if owned else tr("Satın Al  ·  %d") % c.price, func():
				if owned:
					Profile.cosm_select(slot, "" if on else id)
				elif Profile.cosm_buy(id):
					Profile.cosm_select(slot, id)
					Sfx.play2d(Sfx.hurt, -6.0)
				_open_growth())
			b.custom_minimum_size.x = 140
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = not owned and c.price > Profile.gold()
	_lbl(growth_box, "Açılımlar", 20)
	var rows := []
	for w in weapon_list:
		rows.append(["weapon:" + str(w.get("id", "")), tr(str(w.get("name", "?")))])
	for k in _diff_keys():
		if Balance.DIFFS[k].get("unlock", "") != "":
			rows.append(["diff:" + k, tr("Zorluk: %s") % tr(Balance.DIFFS[k].name)])
	rows.append(["mode:endless", tr("Sonsuz Mod")])
	for r in rows:
		_lbl(growth_box, _unlock_line(r[0], r[1]), 15)


## "✔ Ad" ya da "🔒 Ad  —  Tek maçta 150 öldürme  (3/150)".
func _unlock_line(id: String, name: String) -> String:
	if _unlocked(id):
		return "✔ " + name
	return "🔒 " + name + "  —  " + _quest_text(id)


## Açma koşulu ve ilerleme: "Tek maçta 150 öldürme  (112/150)"; koşul bilinmiyorsa "Kazanarak aç."
func _quest_text(id: String) -> String:
	var q: Array = Profile.QUESTS.get(id, [])
	if q.size() != 2:
		return tr("Kazanarak aç.")
	var key: String = q[0]
	var d := key.trim_prefix("wins_")
	var t: String = tr("%s zorluğunda kazan") % tr(Balance.DIFFS[d].name) if key.begins_with("wins_") and Balance.DIFFS.has(d) \
		else tr(QUEST_TEXT.get(key, "%d")) % q[1]
	var pr = _pf("unlock_progress", [id], null)
	return t + ("  (%d/%d)" % [pr[0], pr[1]] if pr is Array and pr.size() == 2 else "")


## Dil değişince koddan biçimlenen yazılar yeniden kurulur (düz metinleri Control'ler kendisi çevirir).
func _retranslate() -> void:
	ver_lbl.text = tr("sürüm %s") % Updater.version()
	chars_title.text = tr("KARAKTERİNİ SEÇ   •   %d karakter") % Chars.LIST.size()
	_update_char_btn()
	_on_volume(Settings.volume)
	shake_slider.value_changed.emit(shake_slider.value)
	set_mode(mode) # lobi yazıları, zorluk listesi, silah düğmesi, üyeler
	if page == "growth":
		_open_growth()


## Seçili silah kilitliyse varsayılan tabancaya düş.
func _fix_weapon() -> void:
	var i := _my_weapon()
	if i >= 0 and i < weapon_list.size() and not _unlocked("weapon:" + str(weapon_list[i].get("id", ""))):
		for j in weapon_list.size():
			if weapon_list[j].get("id", "") == "pistol":
				_pick_weapon(j)
				return


func _weapon_name(i: int) -> String:
	return tr(str(weapon_list[i].get("name", "?"))) if i >= 0 and i < weapon_list.size() else "?"


func _update_weapon_btn() -> void:
	weapon_btn.text = tr("Silah Seç  ·  %s") % _weapon_name(_my_weapon())


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
	var sc := ScrollContainer.new() # ekrana sığmazsa kaydırılır
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(450, minf(640.0, get_viewport().get_visible_rect().size.y * 0.85))
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	_lbl(v, "AYARLAR", 32).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl(v, "— SES —", 15).modulate = Color(1, 1, 1, 0.6)

	vol_lbl = _lbl(v, "", 17)
	var vol := HSlider.new()
	vol.min_value = 0.0; vol.max_value = 1.0; vol.step = 0.05
	vol.value = Settings.volume
	vol.value_changed.connect(_on_volume)
	v.add_child(vol)
	_on_volume(vol.value)

	_lbl(v, "— GÖRÜNTÜ —", 15).modulate = Color(1, 1, 1, 0.6)
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
	_lbl(v, "Grafik kalitesi", 17)
	var q := OptionButton.new()
	for n in Settings.QUALITIES:
		q.add_item(n)
	q.selected = Settings.quality
	q.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		Settings.apply_quality()
		Settings.save())
	v.add_child(q)
	var shake_lbl := _lbl(v, "", 17)
	shake_slider = HSlider.new()
	shake_slider.min_value = 0.0; shake_slider.max_value = 1.0; shake_slider.step = 0.1
	shake_slider.value_changed.connect(func(x: float) -> void:
		Settings.shake = x
		shake_lbl.text = tr("Kamera sarsıntısı: %d%%") % roundi(x * 100.0))
	shake_slider.value = Settings.shake
	shake_slider.value_changed.emit(shake_slider.value)
	v.add_child(shake_slider)
	_lbl(v, "Dil / Language", 17)
	var lang := OptionButton.new()
	for n in LANG_NAMES:
		lang.add_item(n)
	lang.selected = maxi(Settings.LANGUAGES.find(Settings.language), 0)
	lang.item_selected.connect(func(i: int) -> void:
		Settings.language = Settings.LANGUAGES[i]
		Settings.apply_language()
		_retranslate()
		Settings.save())
	v.add_child(lang)

	v.add_child(HSeparator.new())
	ingame_box = VBoxContainer.new()
	v.add_child(ingame_box)
	_btn(ingame_box, "Lobiden Çık", Net.leave)
	close_btn = _btn(v, "Kapat", _close_settings)
	settings_wrap.hide()


func _on_volume(x: float) -> void:
	Settings.volume = x
	Settings.apply_audio()
	vol_lbl.text = tr("Ses: %d%%") % roundi(x * 100.0)


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
			_btn(friends_box, tr("▶ Lobisine katıl: %s") % f[1], Net.join_lobby.bind(f[2]))
			n += 1
		if Net.lobby_id != 0:
			_btn(friends_box, tr("Davet et: %s") % f[1], Net.invite_friend.bind(f[0], f[1]))
			n += 1
	if list.is_empty():
		info.text = "Çevrimiçi Steam arkadaşı yok."
	elif Net.lobby_id == 0:
		info.text = "Davet için önce 'Steam Lobisi Kur'a bas. Lobisi olan arkadaşa ▶ ile katılabilirsin."
	(friends_box.get_parent() as Control).custom_minimum_size.y = min(n, 5) * 40
	(friends_box.get_parent() as Control).visible = n > 0


func _on_invited(from_name: String, lobby: int) -> void:
	for c in invite_box.get_children():
		c.queue_free()
	_lbl(invite_box, tr("%s seni lobisine davet etti!") % from_name, 18)
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
		var line: String = ("★ " if id == 1 else "• ") + str(Net.names[id]) + "  –  " + tr(Chars.get_char(Net.chars.get(id, 0)).name)
		if mode == "td" and wsel is Dictionary and wsel.has(id):
			line += "  •  " + _weapon_name(wsel[id])
		lines.append(line)
	members.text = tr("Lobidekiler:") + "\n" + "\n".join(lines) if Net.online() else ""
	members.visible = members.text != "" # boşken sütunda yer kaplamasın (720p'de Geri sığsın)
	start_btn.disabled = not (Net.online() and multiplayer.is_server())
	if not Net.online():
		start_btn.disabled = mode == "arena"
		start_btn.text = "▶  Tek Başına Başla" if mode != "arena" else "Önce lobi kur (Steam)"
	elif not multiplayer.is_server():
		start_btn.text = "Host'un başlatması bekleniyor…"
	else:
		start_btn.text = MODES.get(mode, MODES.arena)[2]
	if Net.online() and multiplayer.is_server():
		set_opts.rpc(diff_id, endless)
		Net.set_meta_data(mode, diff_id)
	_update_diff_ui()
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
		crosshair.visible = me.hp > 0
		blind_rect.color.a = clampf(me.bt("blind") * 2.0, 0.0, 1.0) # son 0,5 sn'de açılır
		var sh := tr("AKTİF") if me.shield_on else _cd_text(me.shield_cd)
		var names := [tr("BAZUKA"), tr("KALKAN"), tr("DUVAR"), tr("KILIÇ"), tr(me.ch.skill_name)]
		var subs := ["", sh, _cd_text(me.wall_cd), "", _cd_text(me.skill_cd)]
		var left := [me.cd, me.shield_cd, me.wall_cd, me.sword_cd, me.skill_cd]
		for i in 5:
			var s: Array = slots[i]
			var sb: StyleBoxFlat = s[0]
			var name_lbl: Label = s[1]
			var icon: TextureRect = s[2]
			var cdb: ProgressBar = s[3]
			var sub_lbl: Label = s[5]
			var key_sb: StyleBoxFlat = s[6]
			var active: bool = (me.slot == i + 1)
			if i == 4:
				var ready_q: bool = me.skill_cd <= 0.0
				sb.border_color = me.ch.color.lightened(0.15) if ready_q else Color(0.45, 0.48, 0.56, 0.35)
				sb.bg_color = me.ch.color.darkened(0.72) if ready_q else Color(0.08, 0.09, 0.14, 0.78)
				sb.bg_color.a = 0.88 if ready_q else 0.76
				key_sb.border_color = me.ch.color.lightened(0.25) if ready_q else Color(1, 1, 1, 0.16)
			else:
				sb.border_color = Color(1.0, 0.82, 0.25) if active else Color(0.55, 0.60, 0.70, 0.32)
				sb.bg_color = Color(0.22, 0.17, 0.06, 0.90) if active else Color(0.09, 0.11, 0.17, 0.84)
				key_sb.border_color = Color(1.0, 0.82, 0.25) if active else Color(1, 1, 1, 0.20)
			if i == 0 or i == 3:
				if icon.texture == null:
					icon.texture = weapon_icon("bazooka" if i == 0 else "sword")
			name_lbl.text = names[i]
			sub_lbl.text = subs[i]
			if i == 1 and me.shield_on:
				sub_lbl.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
			elif left[i] > 0.0:
				sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.32))
			else:
				sub_lbl.add_theme_color_override("font_color", Color(0.38, 0.95, 0.52))
			s[4] = maxf(s[4], left[i]) if left[i] > 0.0 else 0.0
			cdb.value = left[i] / s[4] if s[4] > 0.0 else 0.0
		var st := PackedStringArray()
		for k in me.buffs:
			if STATUS.has(k) and me.hp > 0:
				st.append("%s %.1f" % [tr(STATUS[k]), me.buffs[k][1]])
		status_lbl.text = "   ".join(st)
		spec_lbl.text = tr("İZLENİYOR: %s\nSol tık / Sağ tık: oyuncu değiştir") \
			% Net.display_name(me.spec_target.name.to_int()) if me.hp <= 0 and is_instance_valid(me.spec_target) else ""
	var s := PackedStringArray()
	for p in players.get_children():
		s.append("%s  %d" % [Net.display_name(p.name.to_int()), p.hp])
	score_lbl.text = "\n".join(s)


func _cd_text(t: float) -> String:
	return tr("%d sn") % ceili(t) if t > 0.0 else tr("HAZIR")


func _unhandled_input(e: InputEvent) -> void:
	if world == null and not char_wrap.visible and not weapon_wrap.visible and not settings_wrap.visible:
		if page == "intro" and (e is InputEventKey or e is InputEventMouseButton) and e.pressed:
			_show_page("main")
			get_viewport().set_input_as_handled()
			return
		if e.is_action_pressed("ui_cancel") and page in ["modes", "lobby", "solo"]:
			_show_page("main" if page == "modes" else "modes")
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
	if mode == "td":
		_fix_weapon() # Net.solo seçili silahı yazmadan önce: kilitliyse tabancaya düşsün
	if not Net.online():
		Net.solo() # Steam'siz tek kişilik: OfflineMultiplayerPeer zaten sunucu, call_local rpc çalışır
	var ids := [1]
	ids.append_array(Array(multiplayer.get_peers()))
	ids.sort()
	if Net.steam_ok and Net.lobby_id != 0: # maç sürerken gelen katılmasın (dünyası yok, rpc'ler boşa düşer)
		Steam.setLobbyJoinable(Net.lobby_id, false)
	if mode == "td":
		var d := diff_id if solo_free_diff or _unlocked("diff:" + diff_id) else "normal"
		solo_free_diff = false
		start_td.rpc(ids, {"difficulty": d, "endless": endless and _unlocked("mode:endless")})
	elif mode == "world":
		start_world.rpc(ids)
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


## Açık dünya: harita world.gd'den, oyuncular merkezdeki düzlükte doğar; düşman ve tur yok.
@rpc("authority", "call_local", "reliable")
func start_world(ids: Array) -> void:
	_clear_world()
	_set_menu_bg(false)
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var w: Node3D = WorldScript.new()
	w.name = "OpenWorld"
	world.add_child(w)
	players = Node3D.new()
	players.name = "Players"
	world.add_child(players)
	w.players = players
	var sp: Array = w.spawns()
	for i in ids.size():
		var p: CharacterBody3D = PlayerScript.new()
		p.name = str(ids[i])
		p.set_multiplayer_authority(ids[i])
		p.spawn_pos = sp[i % sp.size()]
		players.add_child(p)
	round_over = false
	center_lbl.text = ""
	ui.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Tower Defense maçı: ortası açık harita, oyuncular kule dibinde; dalgaları td.gd yürütür.
@rpc("authority", "call_local", "reliable")
## opts: {"difficulty": "easy"|"normal"|"hard"|"nightmare", "endless": bool}; eski çağrılar için boş olabilir.
func start_td(ids: Array, opts := {}) -> void:
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
		t.opts.merge(opts, true)
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
	if mode == "world":
		await get_tree().create_timer(3.0).timeout
		respawn_peer.rpc(dead_id)
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
		center_lbl.text = tr("%s KAZANDI!\nYeni tur %d sn içinde...") % [tr(winner), t]
		await get_tree().create_timer(1.0).timeout


@rpc("authority", "call_local", "reliable")
func restart_round() -> void:
	round_over = false
	center_lbl.text = ""
	if players:
		for p in players.get_children():
			p.respawn()


@rpc("authority", "call_local", "reliable")
func respawn_peer(id: int) -> void:
	var p: Node = players.get_node_or_null(str(id)) if players else null
	if p:
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
	if Net.steam_ok and Net.lobby_id != 0 and multiplayer.is_server():
		Steam.setLobbyJoinable(Net.lobby_id, true)
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
