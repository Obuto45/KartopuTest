extends Control
## Tower Defense arayüzü: XP çubuğu, kule canı, dalga bilgisi, 5 slotluk envanter, TAB stat paneli,
## seviye kartları (yeniden çek / ele), mağaza, ölüm sayacı, boss barı, modifikatörler, ilk maç rehberi ve maç sonu özeti. Veriyi "td" grubundaki düğümden ve yerel oyuncudan
## okur; td.gd / weapons.gd / balance.gd eksikse alanlar güvenli varsayılana düşer (çökmez).
## 1080p'ye göre tasarlandı, pencere yüksekliğine oranla ölçeklenir (_fit).

const TYPES := {"stat": "▲  STAT", "char": "★  KARAKTER", "weapon": "✚  YENİ SİLAH", "weapon_up": "◆  SİLAH YÜKSELTME", "evo": "✦  EVRİM"}
const Balance := preload("res://balance.gd")
const Profile := preload("res://profile.gd")
const MOD_ICONS := {"fast": "⚡", "armored": "⛨", "gold": "✦", "swarm": "⁂", "elite": "♛", "night": "☾"}
const DIFF_COLORS := {"easy": Color(0.4, 0.85, 0.45), "normal": Color(0.45, 0.6, 0.9), "hard": Color(0.95, 0.5, 0.12), "nightmare": Color(0.85, 0.15, 0.2)}
## İlk maç rehberi: [tuşlar, ne yapılır]; koşul tutunca sıradakine geçer (_tut_tick).
const TUT := [
	[["SOL TIK"], "ateş et"],
	[["B"], "mağazayı aç, bir Duvar al"],
	[["4"], "duvarı eline al: yeşil hayaleti kuleyle yaratık yolu arasına koy, sol tıkla kur"],
	[["G"], "hazırım: dalgayı başlat"],
	[["1", "2", "3"], "kart seç"],
	[["TAB"], "stat panelini aç, puanını harca"],
]
const BOSS_C := Color(0.8, 0.45, 1.0)
const GOLD := Color(1.0, 0.82, 0.25)
const ORANGE := Color(1.0, 0.62, 0.18)
const GREY := Color(0.55, 0.57, 0.62)
const RED := Color(1.0, 0.35, 0.3)
const DARK := Color(0.05, 0.06, 0.1, 0.9)

var main: Node # main.gd: tema yardımcıları ve oyuncular
var td: Node
var player: Node # yerel oyuncu (testte yerine sahte düğüm konabilir)
var weapons: Array = consts("res://weapons.gd").get("LIST", [])
var rarity: Dictionary = consts("res://weapons.gd").get("RARITY", {})
var stat_defs: Array = consts("res://weapons.gd").get("STATS", [])
var items: Dictionary = consts("res://weapons.gd").get("ITEMS", {}) # yaratıktan düşen eşyalar
var equips: Dictionary = consts("res://weapons.gd").get("EQUIPS", {})
var wconsts: Dictionary = consts("res://weapons.gd") # kart yazılarını çevirirken CHAR_UPS / UPS / EVOS
var shop: Array = consts("res://balance.gd").get("SHOP", [])
var wave_count: int = consts("res://balance.gd").get("WAVE_COUNT", 10)
var respawn_time: float = consts("res://balance.gd").get("RESPAWN_TIME", 8.0)

var state := ""
var level := -1
var xp_f := 0.0
var slow_t := 0.0 # seyrek yenilenen parçalar (hazır listesi, stat satırları)
var card_sig := ""
var inv_sig := ""
var xp_fill: ColorRect
var xp_flash: ColorRect
var lvl_badge: PanelContainer
var lvl_lbl: Label
var tower_fill: ColorRect
var tower_txt: Label
var tower_title: Label
var wave_lbl: Label
var left_lbl: Label
var money_lbl: Label
var break_lbl: Label
var ready_lbl: Label
var banner: VBoxContainer
var banner_tw: Tween
var cells := [] # 5 envanter hücresi + Q: {sb, name, count, pips}
var stats_panel: PanelContainer
var stats_sub: Label
var points_lbl: Label
var stat_box: VBoxContainer
var stat_rows := [] # {def, bar, val, btn}
var weap_box: VBoxContainer
var cards_box: VBoxContainer
var cards_hint: Label
var hint_lbl: Label # kısayollar; yalnız molada
var cards_row: HBoxContainer
var shop_wrap: ColorRect
var shop_money: Label
var shop_grid: GridContainer
var shop_msg: Label
var shop_rows := [] # {item, btn}
var dead_lbl: Label
var end_wrap: ColorRect
var diff_lbl: Label # kule başlığının yanında zorluk
var diff_seen := ""
var mod_row: HBoxContainer # savaşta modifikatör etiketleri
var mods_lbl: Label # molada sıradaki dalganın modifikatörleri
var mods_sig := ""
var boss_box: VBoxContainer
var boss_name: Label
var boss_fill: ColorRect
var boss_txt: Label
var cards_at := 0 # kartlar bu zamandan önce görünmez (dalga afişiyle çakışmasın)
var reroll_btn: Button
var banish_btn: Button
var rerolls: int = Profile.upgrade_level("reroll") # maç başında kalıcı yükseltmeden, maç boyunca azalır
var banishes: int = Profile.upgrade_level("banish")
var banish_mode := false # Ele'ye basıldı: sıradaki 1/2/3 kartı eler
var tut := -1 if Profile.tutorial_done() else 0 # rehber adımı; -1 = kapalı
var tut_n := 0 # adımın başlangıç sayacı (yapı / stat puanı)
var tut_seen := false # kart adımı: kartlar göründü mü
var tut_card: PanelContainer
var tut_step: Label
var tut_keys: HBoxContainer
var tut_txt: Label
var night_on := false
var night_tw: Tween
var night_base := {} # Environment / ışık -> özgün değerler
var summary := {} # td.summary_ready
var run_gold := -1 # bu maçta kazanılan Altın Saç (-1: henüz yok)
var run_new: Array = [] # bu maçta açılanlar


## Bir betiğin sabitleri; dosya yoksa (ya da henüz bozuksa) boş sözlük.
static func consts(path: String) -> Dictionary:
	var s = load(path) if ResourceLoader.exists(path) else null
	return s.get_script_constant_map() if s is Script else {}


func _g(o, k: String, d):
	if o == null or not is_instance_valid(o):
		return d
	var v = o.get(k)
	return d if v == null else v


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = main.ui.theme
	get_viewport().size_changed.connect(_fit)
	_fit()
	_build_top()
	_build_bottom()
	_build_stats()
	_build_cards()
	_build_shop()
	_build_end()
	_build_aim()


## Dürbün çerçevesi (keskin nişancı, sağ tık) ve yay germe halkası (nişangâhın çevresi).
var scope: ColorRect
var ring: Control


func _build_aim() -> void:
	scope = ColorRect.new()
	scope.set_anchors_preset(PRESET_FULL_RECT)
	scope.mouse_filter = MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec2 px;
void fragment() {
	vec2 p = (UV - 0.5) * px / px.y;
	float r = length(p);
	float a = smoothstep(0.40, 0.405, r) + step(abs(p.x), 0.0012) * step(r, 0.4) + step(abs(p.y), 0.0012) * step(r, 0.4);
	a = max(a, smoothstep(0.392, 0.4, r) * 0.6);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a, 0.0, 1.0));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	scope.material = m
	scope.visible = false
	add_child(scope)
	ring = Control.new()
	ring.mouse_filter = MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(PRESET_CENTER)
	ring.draw.connect(func():
		var age := (Time.get_ticks_msec() - int(_g(player, "hit_ms", -10000))) / 1000.0
		if age < 0.16: # isabet işareti: 4 çapraz çizgi; öldürücü vuruşta kırmızı ve büyük
			var kill: bool = _g(player, "hit_kill", false)
			var hc := Color(1.0, 0.25, 0.2) if kill else Color(1, 1, 1, 0.95)
			var r0 := 9.0 if kill else 7.0
			var r1 := r0 + (9.0 if kill else 6.0) * (1.0 - age / 0.16 * 0.4)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				ring.draw_line(d.normalized() * r0, d.normalized() * r1, hc, 2.5 if kill else 2.0, true)
		var k: float = _g(player, "draw_k", 0.0)
		if _g(player, "busy", "") == "charge":
			var c := Color.WHITE if k >= 1.0 else Color(1, 1, 1, 0.55)
			ring.draw_arc(Vector2.ZERO, 26.0, -PI / 2, -PI / 2 + TAU * k, 48, c, 3.0 if k >= 1.0 else 2.0, true))
	add_child(ring)


func _update_aim() -> void:
	scope.visible = _g(player, "scoped", false)
	(scope.material as ShaderMaterial).set_shader_parameter("px", size)
	ring.queue_redraw()


func _fit() -> void:
	var vp := get_viewport_rect().size
	var k := clampf(vp.y / 1080.0, 0.75, 2.0) # 720p'de yazılar okunmaz olmasın diye alt sınır
	scale = Vector2(k, k)
	position = Vector2.ZERO
	size = vp / k


## Tek satırlık, fareyi yutmayan yazı. big: logo yazı tipi.
func _t(parent: Node, text: String, size_px: int, c := Color.WHITE, big := false) -> Label:
	var l: Label = main._logo(parent, text, size_px, c) if big else main._txt(parent, text, size_px, 1.0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l


func _rect(parent: Node, c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = MOUSE_FILTER_IGNORE
	r.set_anchors_preset(PRESET_FULL_RECT)
	parent.add_child(r)
	return r


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b: Button = main._btn(parent, text, cb)
	b.focus_mode = FOCUS_NONE # Boşluk/Enter oyunda düğmeye basmasın
	return b


## Renkli zeminli küçük etiket (zorluk, modifikatör, tuş, rozet). Dönen Label'ın ebeveyni paneldir.
func _chip(parent: Node, text: String, bg: Color, fg: Color, px := 15) -> Label:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.size_flags_vertical = SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = main._sb(bg, 6, 0)
	sb.content_margin_left = 9; sb.content_margin_right = 9; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var l := _t(p, text, px, fg)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Klavye tuşu görünümü: açık zemin, altta kalın kenar.
func _key(parent: Node, k: String) -> void:
	var l := _chip(parent, k, Color(0.93, 0.94, 0.98), Color(0.08, 0.09, 0.13), 22)
	var sb: StyleBoxFlat = l.get_parent().get_theme_stylebox("panel")
	sb.border_width_bottom = 4
	sb.border_color = Color(0.5, 0.53, 0.62)
	sb.content_margin_left = 12; sb.content_margin_right = 12


# ---------- Kurulum ----------

func _build_top() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(PRESET_CENTER_TOP)
	top.offset_left = -310; top.offset_right = 310; top.offset_top = 8
	top.grow_horizontal = GROW_DIRECTION_BOTH # boss barı / rehber kartı genişse iki yana büyür
	top.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 3)
	add_child(top)
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.mouse_filter = MOUSE_FILTER_IGNORE
	trow.add_theme_constant_override("separation", 12)
	top.add_child(trow)
	tower_title = _t(trow, "♜  RAPUNZEL'İN KULESİ", 21, Color(1.0, 0.9, 0.7), true)
	diff_lbl = _chip(trow, "", DIFF_COLORS.normal, Color.WHITE, 14)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(620, 26)
	bar.size_flags_horizontal = SIZE_SHRINK_CENTER
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	top.add_child(bar)
	_rect(bar, Color(0, 0, 0, 0.7))
	tower_fill = _rect(bar, Color(0.3, 0.9, 0.35))
	tower_fill.offset_left = 3; tower_fill.offset_top = 3; tower_fill.offset_bottom = -3
	tower_txt = _t(bar, "", 18)
	tower_txt.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tower_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tower_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 26)
	top.add_child(row)
	wave_lbl = _t(row, "", 28, Color.WHITE, true)
	left_lbl = _t(row, "", 19)
	money_lbl = _t(row, "", 22, GOLD)
	mod_row = HBoxContainer.new()
	mod_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mod_row.mouse_filter = MOUSE_FILTER_IGNORE
	mod_row.add_theme_constant_override("separation", 8)
	top.add_child(mod_row)

	# Boss barı: kule barından geniş, mor; yalnız boss yaşarken.
	boss_box = VBoxContainer.new()
	boss_box.mouse_filter = MOUSE_FILTER_IGNORE
	boss_box.add_theme_constant_override("separation", 0)
	boss_box.hide()
	top.add_child(boss_box)
	boss_name = _t(boss_box, "", 26, BOSS_C, true)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bb := Control.new()
	bb.custom_minimum_size = Vector2(780, 22)
	bb.mouse_filter = MOUSE_FILTER_IGNORE
	boss_box.add_child(bb)
	_rect(bb, Color(0, 0, 0, 0.75))
	boss_fill = _rect(bb, Color(0.62, 0.2, 0.85))
	boss_fill.offset_left = 3; boss_fill.offset_top = 3; boss_fill.offset_bottom = -3
	boss_txt = _t(bb, "", 15)
	boss_txt.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	boss_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	break_lbl = _t(top, "", 19, Color(0.7, 0.95, 1.0))
	break_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mods_lbl = _t(top, "", 18, Color(0.88, 0.75, 1.0))
	mods_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_lbl = _t(top, "", 18)
	ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_lbl.modulate.a = 0.85
	_build_tut(top)

	banner = VBoxContainer.new() # dalga başladı / temizlendi / boss
	banner.anchor_right = 1.0
	banner.anchor_top = 0.24; banner.anchor_bottom = 0.24
	banner.mouse_filter = MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)
	_t(banner, "", 92, ORANGE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t(banner, "", 24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t(banner, "", 22, Color(0.88, 0.75, 1.0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # modifikatörler

	dead_lbl = _t(self, "", 50, RED, true)
	dead_lbl.anchor_right = 1.0
	dead_lbl.anchor_top = 0.4; dead_lbl.anchor_bottom = 0.4
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Rehber kartı: üst bilgi bloğunun hemen altında, büyük yazı ve tuş simgeleri.
func _build_tut(parent: Node) -> void:
	tut_card = PanelContainer.new()
	tut_card.size_flags_horizontal = SIZE_SHRINK_CENTER
	tut_card.mouse_filter = MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = main._sb(Color(0.05, 0.06, 0.1, 0.9), 12, 14)
	sb.border_width_left = 6
	sb.border_color = GOLD
	tut_card.add_theme_stylebox_override("panel", sb)
	tut_card.hide()
	parent.add_child(tut_card)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	tut_card.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(head)
	tut_step = _t(head, "", 15, ORANGE)
	tut_step.size_flags_horizontal = SIZE_EXPAND_FILL
	_t(head, "H: rehberi atla", 15).modulate.a = 0.6
	var body := HBoxContainer.new()
	body.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	tut_keys = HBoxContainer.new()
	tut_keys.mouse_filter = MOUSE_FILTER_IGNORE
	tut_keys.add_theme_constant_override("separation", 6)
	body.add_child(tut_keys)
	tut_txt = _t(body, "", 26)
	tut_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_txt.custom_minimum_size.x = 560
	tut_txt.size_flags_horizontal = SIZE_EXPAND_FILL
	if tut >= 0:
		_tut_show()


func _build_bottom() -> void:
	# XP çubuğu: en altta boydan boya, üstünde sayı yok; solunda seviye rozeti.
	var back := _rect(self, Color(0, 0, 0, 0.75))
	back.set_anchors_preset(PRESET_BOTTOM_WIDE)
	back.offset_left = 112; back.offset_top = -14
	xp_fill = _rect(back, Color(0.35, 0.78, 1.0))
	xp_fill.offset_top = 2; xp_fill.offset_bottom = -2
	xp_fill.anchor_right = 0.0
	xp_flash = _rect(back, Color(1, 1, 1, 0))
	lvl_badge = PanelContainer.new()
	lvl_badge.set_anchors_preset(PRESET_BOTTOM_LEFT)
	lvl_badge.offset_top = -36; lvl_badge.offset_right = 112
	lvl_badge.pivot_offset = Vector2(56, 36)
	lvl_badge.mouse_filter = MOUSE_FILTER_IGNORE
	var bs: StyleBoxFlat = main._sb(Color(0.08, 0.12, 0.2, 0.95), 0, 2)
	bs.corner_radius_top_right = 10
	bs.border_width_top = 2; bs.border_width_right = 2
	bs.border_color = Color(0.35, 0.78, 1.0)
	lvl_badge.add_theme_stylebox_override("panel", bs)
	add_child(lvl_badge)
	lvl_lbl = _t(lvl_badge, "", 21, Color.WHITE, true)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl = _t(self, "TAB statlar   •   B mağaza   •   G hazır   •   1–5 envanter   •   Q yetenek   •   ESC menü", 17)
	hint_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE) # ekran genişliğinde, ortalı, envanterin üstünde: rozet ve slotlarla çakışmaz
	hint_lbl.offset_left = 0; hint_lbl.offset_right = 0
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.offset_top = -196; hint_lbl.offset_bottom = -172
	hint_lbl.modulate.a = 0.7

	# Envanter: 1-3 silah/ekipman, 4-5 yapı/eşya, sonra Q yeteneği; gruplar başlıkla ayrılır.
	var inv := HBoxContainer.new()
	inv.set_anchors_preset(PRESET_CENTER_BOTTOM)
	inv.grow_horizontal = GROW_DIRECTION_BOTH
	inv.grow_vertical = GROW_DIRECTION_BEGIN
	inv.offset_bottom = -26
	inv.mouse_filter = MOUSE_FILTER_IGNORE
	inv.add_theme_constant_override("separation", 22)
	add_child(inv)
	var key := 1
	for g in [["SİLAH  /  EKİPMAN", 3], ["YAPI  /  EŞYA", 2], ["YETENEK", 1]]:
		var gv := VBoxContainer.new()
		gv.mouse_filter = MOUSE_FILTER_IGNORE
		gv.add_theme_constant_override("separation", 2)
		inv.add_child(gv)
		var cap := _t(gv, g[0], 16)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.modulate.a = 0.6
		var gh := HBoxContainer.new()
		gh.mouse_filter = MOUSE_FILTER_IGNORE
		gh.add_theme_constant_override("separation", 8)
		gv.add_child(gh)
		for i in g[1]:
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(112, 92)
			cell.mouse_filter = MOUSE_FILTER_IGNORE
			var sb: StyleBoxFlat = main._sb(Color(0, 0, 0, 0.5), 8, 6)
			sb.set_border_width_all(3)
			cell.add_theme_stylebox_override("panel", sb)
			gh.add_child(cell)
			var icon := TextureRect.new() # silah simgesi (yalnız silah slotunda dolu)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			cell.add_child(icon)
			var k := _t(cell, str(key) if key <= 5 else "Q", 14)
			k.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			k.modulate.a = 0.75
			var n := _t(cell, "", 15)
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var cnt := _t(cell, "", 16, GOLD)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			var pips := _t(cell, "", 14, GOLD)
			pips.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pips.size_flags_vertical = SIZE_SHRINK_BEGIN
			var cdb := ProgressBar.new() # bekleme süresi: dolu = yeni kullanıldı, boşalınca hazır
			cdb.show_percentage = false
			cdb.max_value = 1.0
			cdb.custom_minimum_size.y = 5
			cdb.size_flags_vertical = SIZE_SHRINK_END
			cdb.mouse_filter = MOUSE_FILTER_IGNORE
			cdb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
			cdb.add_theme_stylebox_override("fill", main._sb(Color(1, 1, 1, 0.85), 2, 0))
			cell.add_child(cdb)
			cells.append({"sb": sb, "name": n, "count": cnt, "pips": pips, "icon": icon, "cd": cdb, "cd_max": 0.0})
			key += 1


func _build_stats() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.set_anchors_preset(PRESET_CENTER_LEFT)
	stats_panel.grow_vertical = GROW_DIRECTION_BOTH
	stats_panel.offset_left = 40
	stats_panel.custom_minimum_size.x = 520
	stats_panel.hide()
	add_child(stats_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	stats_panel.add_child(v)
	_t(v, "STATLAR", 34, ORANGE, true)
	stats_sub = _t(v, "", 16)
	stats_sub.modulate.a = 0.8
	points_lbl = _t(v, "", 17, GOLD)
	v.add_child(HSeparator.new())
	stat_box = VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 5)
	v.add_child(stat_box)
	v.add_child(HSeparator.new())
	_t(v, "SİLAHLAR VE EKİPMAN", 15, ORANGE)
	weap_box = VBoxContainer.new()
	v.add_child(weap_box)


func _build_cards() -> void:
	cards_box = VBoxContainer.new()
	cards_box.set_anchors_preset(PRESET_CENTER_BOTTOM)
	cards_box.grow_horizontal = GROW_DIRECTION_BOTH
	cards_box.grow_vertical = GROW_DIRECTION_BEGIN
	cards_box.offset_bottom = -176 # envanterin üstünde, nişangâhın altında: görüşü kapatmaz
	cards_box.mouse_filter = MOUSE_FILTER_IGNORE
	cards_box.add_theme_constant_override("separation", 4)
	cards_box.hide()
	add_child(cards_box)
	_t(cards_box, "SEVİYE ATLADIN!", 34, GOLD, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_hint = _t(cards_box, "", 16)
	cards_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.mouse_filter = MOUSE_FILTER_IGNORE
	cards_row.add_theme_constant_override("separation", 18)
	cards_box.add_child(cards_row)
	var rb := HBoxContainer.new() # kalıcı yükseltmeden gelen haklar
	rb.alignment = BoxContainer.ALIGNMENT_CENTER
	rb.mouse_filter = MOUSE_FILTER_IGNORE
	rb.add_theme_constant_override("separation", 14)
	cards_box.add_child(rb)
	reroll_btn = _button(rb, "", _reroll)
	banish_btn = _button(rb, "", _banish_toggle)
	for b in [reroll_btn, banish_btn]:
		b.custom_minimum_size = Vector2(300, 40)


func _build_shop() -> void:
	shop_wrap = _rect(self, Color(0, 0, 0, 0.5))
	shop_wrap.mouse_filter = MOUSE_FILTER_STOP
	shop_wrap.hide()
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	shop_wrap.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_t(head, "MAĞAZA", 46, ORANGE, true).size_flags_horizontal = SIZE_EXPAND_FILL
	shop_money = _t(head, "", 30, GOLD, true)
	_t(v, "Takım parasıyla alınır. Yapı 4–5. slota gelir: slotu seç, sol tıkla yerleştir.", 15).modulate.a = 0.7
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 10)
	shop_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(shop_grid)
	shop_msg = _t(v, " ", 17)
	shop_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var close := _button(v, "Kapat  (B)", shop_wrap.hide)
	close.size_flags_horizontal = SIZE_SHRINK_CENTER
	close.custom_minimum_size.x = 220


func _build_end() -> void:
	end_wrap = _rect(self, Color(0, 0, 0, 0.8)) # altındaki HUD özetle karışmasın
	end_wrap.mouse_filter = MOUSE_FILTER_STOP
	end_wrap.hide()


# ---------- Her kare ----------

func _process(dt: float) -> void:
	if td == null or not is_instance_valid(td):
		td = get_tree().get_first_node_in_group("td")
		if td and td.has_signal("changed"):
			td.connect("changed", func(): slow_t = 0.0)
		if td and td.has_signal("summary_ready"):
			td.connect("summary_ready", _on_summary)
	if (player == null or not is_instance_valid(player)) and main.players:
		player = main.players.get_node_or_null(str(multiplayer.get_unique_id()))
	if scope:
		_update_aim()
	var st: String = _g(td, "state", "break")
	hint_lbl.visible = st == "break"
	var wave: int = _g(td, "wave", 0)
	var money: int = _g(td, "money", 0)
	var ended := st == "won" or st == "lost"
	var endless: bool = _g(td, "endless", false)
	var mods: Array = _g(td, "mods", [])
	if st != state: # durum geçişleri: afişler, mağazanın kapanması, oyun sonu
		if st == "fight":
			shop_wrap.hide()
			var bt: String = Balance.wave(maxi(wave, 1), 1).boss
			var final := wave >= wave_count and not endless
			var sub := (tr("%s geliyor!") % _boss_title(bt)) if bt != "" else ("Son dalga: kuleyi ne pahasına olursa olsun koru." if final else "Yaratıklar geliyor!")
			_banner("SON DALGA!" if final else tr("DALGA %d") % wave, sub, RED if bt != "" or final else ORANGE, _mods_text(mods, false))
			cards_at = Time.get_ticks_msec() + 1500 # kartlar afişin üstüne binmesin
		elif st == "break" and state == "fight":
			_banner("DALGA TEMİZLENDİ", "Mola: B ile mağaza, TAB ile stat puanları.", Color(0.5, 1.0, 0.6),
				(tr("Sıradaki dalga:  %s") % _mods_text(mods, false)) if not mods.is_empty() else "")
		elif ended and not end_wrap.visible:
			_show_end(st == "won", wave)
		state = st
	_night(st == "fight" and mods.has("night"))

	# Kule canı: azaldıkça kırmızıya döner, %30 altında yanıp söner.
	var tmax: int = maxi(_g(td, "tower_max", 1), 1)
	var thp: int = _g(td, "tower_hp", tmax)
	var f := clampf(float(thp) / tmax, 0.0, 1.0)
	tower_fill.anchor_right = f
	tower_fill.offset_right = -3.0 * f
	var c := Color(0.95, 0.8, 0.2).lerp(Color(0.3, 0.9, 0.35), (f - 0.5) * 2.0) if f > 0.5 \
		else Color(0.9, 0.15, 0.1).lerp(Color(0.95, 0.8, 0.2), f * 2.0)
	var low := f <= 0.3 and not ended
	var pulse := absf(sin(Time.get_ticks_msec() * 0.008))
	tower_fill.color = c.lerp(Color.WHITE, 0.4 * pulse) if low else c
	tower_title.add_theme_color_override("font_color", RED.lerp(Color.WHITE, 0.5 * pulse) if low else Color(1.0, 0.9, 0.7))
	tower_txt.text = "%d / %d" % [thp, tmax]
	# td.wave son başlayan dalgadır: molada sıradaki gösterilir.
	wave_lbl.text = tr("DALGA %d / ∞") % maxi(wave + int(st == "break"), 1) if endless \
		else tr("DALGA %d / %d") % [clampi(wave + int(st == "break"), 1, wave_count), wave_count]
	var diff: String = _g(td, "difficulty", "normal")
	if diff != diff_seen:
		diff_seen = diff
		diff_lbl.text = tr(str(Balance.DIFFS.get(diff, {}).get("name", diff))).to_upper()
		(diff_lbl.get_parent().get_theme_stylebox("panel") as StyleBoxFlat).bg_color = DIFF_COLORS.get(diff, GREY)
	var msig := str(mods)
	if msig != mods_sig:
		mods_sig = msig
		for n in mod_row.get_children():
			n.queue_free()
		for m in mods:
			_chip(mod_row, "%s %s" % [MOD_ICONS.get(m, "•"), tr(str(Balance.MODS.get(m, {}).get("name", m))).to_upper()], Color(0.22, 0.1, 0.32, 0.85), Color(0.92, 0.82, 1.0), 15)
		mods_lbl.text = tr("Sıradaki dalga:  %s") % _mods_text(mods, true) if not mods.is_empty() else ""
	mod_row.visible = st == "fight" and not mods.is_empty()
	mods_lbl.visible = st == "break" and not mods.is_empty()
	# Boss: td._by_id'deki yaratık düğümü (her makinede _spawn ile dolar), canı hp / max_hp.
	var boss = _g(td, "_by_id", {}).get(_g(td, "boss_eid", 0))
	boss_box.visible = st == "fight" and is_instance_valid(boss) and boss.hp > 0
	if boss_box.visible:
		var bf := clampf(float(boss.hp) / maxi(boss.max_hp, 1), 0.0, 1.0)
		boss_fill.anchor_right = bf
		boss_fill.offset_right = -3.0 * bf
		boss_name.text = _boss_title(boss.type).to_upper()
		boss_txt.text = "%d / %d" % [boss.hp, boss.max_hp]
	left_lbl.text = tr("Kalan yaratık: %d") % _g(td, "enemies_left", 0) if st == "fight" else tr("Öldürülen: %d") % _g(td, "kills", 0)
	money_lbl.text = "₺ %d" % money
	break_lbl.visible = st == "break"
	ready_lbl.visible = st == "break"
	break_lbl.text = tr("MOLA   •   sıradaki dalgaya %d sn") % ceili(_g(td, "time_left", 0.0))

	# XP: yumuşak dolar; seviye atlayınca sıfırdan başlar ve parlar.
	var lv: int = _g(td, "level", 1)
	if lv != level:
		if level >= 0:
			xp_f = 0.0
			_flash_xp()
		level = lv
		lvl_lbl.text = tr("SV %d") % lv
	var target := clampf(float(_g(td, "xp", 0)) / maxi(_g(td, "xp_next", 1), 1), 0.0, 1.0)
	xp_f = lerpf(xp_f, target, 1.0 - exp(-8.0 * dt))
	xp_fill.anchor_right = xp_f

	_update_inv()
	var alive: bool = _g(player, "hp", 1) > 0
	dead_lbl.visible = not alive and not ended
	if dead_lbl.visible:
		dead_lbl.text = tr("ÖLDÜN\nYeniden doğuş: %d sn") % maxi(ceili(_g(player, "respawn_t", respawn_time - _g(player, "dead_t", 0.0))), 0)

	# Kartlar: liste değişince yeniden kurulur.
	var cards: Array = _g(player, "cards", [])
	var sig := str(cards)
	if sig != card_sig:
		card_sig = sig
		_make_cards(cards)
	var was := cards_box.visible
	cards_box.visible = not cards.is_empty() and not ended and Time.get_ticks_msec() >= cards_at
	if cards_box.visible and not was and banner.modulate.a > 0.0: # kartlar gelince afiş hemen çekilir: üst üste binmez
		banner_tw.kill()
		banner_tw = create_tween()
		banner_tw.tween_property(banner, "modulate:a", 0.0, 0.2)
	if cards.is_empty():
		banish_mode = false
	cards_hint.text = "Elemek istediğin kartı seç: bu maçta bir daha çıkmaz" if banish_mode \
		else "1 / 2 / 3 tuşuyla ya da tıklayarak seç" if st == "break" else "1 / 2 / 3 tuşuyla seç"
	if cards_box.visible:
		reroll_btn.text = tr("↻  Yeniden Çek  [4]   •   %d hak") % rerolls
		reroll_btn.disabled = rerolls <= 0
		banish_btn.text = "✕  Hangisi? 1 / 2 / 3   ([5] vazgeç)" if banish_mode else tr("✕  Ele  [5]   •   %d hak") % banishes
		banish_btn.disabled = banishes <= 0
		cards_row.modulate = Color(1.0, 0.6, 0.55) if banish_mode else Color.WHITE
	_tut_tick(st, ended, cards_box.visible)

	stats_panel.visible = Input.is_action_pressed("stats") and not ended and not shop_wrap.visible
	if shop_wrap.visible:
		shop_money.text = "₺ %d" % money
		for r in shop_rows:
			r.btn.add_theme_color_override("font_color", Color.WHITE if money >= int(r.item.get("price", 0)) else RED)
	slow_t -= dt
	if slow_t <= 0.0:
		slow_t = 0.2
		_refresh_ready(st)
		if stats_panel.visible:
			_refresh_stats(st)

	if not main.settings_wrap.visible: # imleç: panel açıkken görünür, yoksa oyuna yakalı
		var m := Input.MOUSE_MODE_VISIBLE if want_mouse() else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != m:
			Input.mouse_mode = m


## Kart seçimi sürüyor mu: açıkken 1/2/3 kart seçer, envanter slotu değişmemeli (player.gd buna bakar).
func cards_open() -> bool:
	return cards_box.visible


## Savaşta kartlar imleci serbest bırakmaz (oyuncu donmasın, tuşla seçilir); molada her panel bırakır.
func want_mouse() -> bool:
	return shop_wrap.visible or end_wrap.visible or (state == "break" and (stats_panel.visible or cards_open()))


func _input(e: InputEvent) -> void:
	if main.settings_wrap.visible or end_wrap.visible:
		return
	if tut == 0 and e.is_action_pressed("throw") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_tut_next() # ilk ateş; olay oyuncuya da gider
	var key: int = e.physical_keycode if e is InputEventKey and e.pressed and not e.echo else 0
	if shop_wrap.visible and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("shop")):
		shop_wrap.hide()
	elif cards_open() and key in [KEY_1, KEY_2, KEY_3]:
		_choose(key - KEY_1)
	elif cards_open() and key == KEY_4:
		_reroll()
	elif cards_open() and key == KEY_5:
		_banish_toggle()
	elif tut >= 0 and key == KEY_H:
		tut = TUT.size() - 1
		_tut_next()
	elif e.is_action_pressed("shop"):
		if state == "break":
			_open_shop()
		else:
			_banner("", "Mağaza yalnız molada açılır.", Color.WHITE)
	elif e.is_action_pressed("ready") and state == "break" and td and td.has_method("ready_up"):
		td.ready_up()
	else:
		return
	get_viewport().set_input_as_handled()


func _banner(title: String, sub: String, c: Color, extra := "") -> void:
	var t: Label = banner.get_child(0)
	t.text = title
	t.visible = title != ""
	t.add_theme_color_override("font_color", c)
	(banner.get_child(1) as Label).text = sub
	(banner.get_child(2) as Label).text = extra
	banner.get_child(2).visible = extra != ""
	# rehber kartı açıksa onun altına kayar (yerel koordinat = küresel / ölçek)
	banner.offset_top = maxf((tut_card.get_global_rect().end.y / scale.y + 8.0 - 0.24 * size.y) if tut_card.visible else 0.0, 0.0)
	banner.offset_bottom = banner.offset_top
	if banner_tw:
		banner_tw.kill()
	banner.modulate.a = 0.0
	banner_tw = create_tween()
	banner_tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	banner_tw.tween_interval(1.8)
	banner_tw.tween_property(banner, "modulate:a", 0.0, 0.6)


func _flash_xp() -> void:
	xp_flash.color.a = 0.95
	lvl_badge.scale = Vector2(1.5, 1.5)
	var tw := create_tween().set_parallel()
	tw.tween_property(xp_flash, "color:a", 0.0, 0.8)
	tw.tween_property(lvl_badge, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- Envanter ----------

## Envanter kaydının adı ve rengi: silah (nadirlik rengi), yapı (mağaza rengi) ya da ham id.
func _item(d: Dictionary) -> Dictionary:
	var id = d.get("id", "")
	var src: Dictionary = {}
	match d.get("kind", ""):
		"build":
			for s in shop:
				if s.get("id") == id:
					src = s
		"item":
			src = items.get(id, {})
		"equip":
			src = equips.get(id, {})
		_:
			for w in weapons:
				if w.get("id") == id:
					src = w
	var c: Color = src.get("color", Color.WHITE)
	if src.has("rarity"):
		c = rarity.get(src.rarity, {}).get("color", c)
	return {"name": str(src.get("name", id)).capitalize() if src.is_empty() else tr(str(src.name)), "color": c}


func _update_inv() -> void:
	var inv: Array = _g(player, "inv", [])
	var sel: int = _g(player, "slot", 0)
	for i in 5:
		var d: Dictionary = inv[i] if i < inv.size() and inv[i] is Dictionary else {}
		var c: Dictionary = cells[i]
		var it := _item(d) if not d.is_empty() else {"name": "", "color": Color(GREY, 0.5)}
		c.name.text = it.name
		var tex: Texture2D = main.weapon_icon(str(d.id)) if d.get("kind", "") == "weapon" else null
		c.icon.texture = tex
		c.name.size_flags_vertical = SIZE_SHRINK_END if tex else SIZE_FILL # simge varken ad alta iner
		c.name.add_theme_font_size_override("font_size", 12 if tex else 15)
		# Bekleme: silahlar ortak cd'yi (yalnız seçili slotta), kalkan ve duvar kendi süresini gösterir.
		var left: float = _g(player, "shield_cd", 0.0) if d.get("id", "") == "shield" else _g(player, "wall_cd", 0.0) if d.get("id", "") == "wall" 			else _g(player, "cd", 0.0) if d.get("kind", "") == "weapon" and sel == i + 1 else 0.0
		if sel == i + 1 and _g(player, "reloading", false): # doldurma ilerlemesi
			left = _g(player, "reload_t", 0.0)
		c.cd_max = maxf(c.cd_max, left) if left > 0.0 else 0.0
		c.cd.value = left / c.cd_max if c.cd_max > 0.0 else 0.0
		c.count.text = "x%d" % d.count if int(d.get("count", 1)) > 1 else ""
		c.count.modulate = Color.WHITE
		var mag := 0
		if d.get("kind", "") == "weapon":
			for w in weapons:
				if w.get("id") == d.id:
					mag = w.get("mag", 0)
		if mag > 0: # şarjör: "12 / ∞" (alevde yakıt yüzdesi); azalınca turuncu, boşken kırmızı yanıp söner
			var am: int = d.get("ammo", mag)
			c.count.text = tr("%%%d") % roundi(am * 100.0 / mag) if d.id == "flame" else "%d / ∞" % am
			if am <= 0:
				c.count.modulate = Color(1.0, 0.25, 0.2, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012))
			elif am <= mag / 4:
				c.count.modulate = Color(1.0, 0.6, 0.15)
		c.pips.text = "●".repeat(clampi(int(d.get("lvl", 0)), 0, 8))
		c.sb.border_color = it.color
		c.sb.bg_color = Color(0.95, 0.5, 0.1, 0.42) if sel == i + 1 else Color(0, 0, 0, 0.5)
		c.sb.shadow_color = Color(1.0, 0.85, 0.3, 0.75)
		c.sb.shadow_size = 12 if sel == i + 1 else 0
	var ch: Dictionary = _g(player, "ch", {})
	var cd: float = _g(player, "skill_cd", 0.0)
	cells[5].name.text = "%s\n%s" % [tr(ch.get("skill_name", "")), main._cd_text(cd)]
	cells[5].sb.border_color = ch.get("color", GREY) if cd <= 0.0 else Color(GREY, 0.6)


# ---------- Hazır listesi ve stat paneli ----------

## td.gd oyları ready_votes + is_ready() ile tutuyor; sözleşmedeki ready sözlüğü de kabul edilir.
func _is_ready(id: int) -> bool:
	if td and td.has_method("is_ready"):
		return td.is_ready(id)
	return _g(td, "ready", {}).get(id, false)


func _refresh_ready(st: String) -> void:
	if st != "break":
		return
	var names := PackedStringArray()
	for id in Net.names:
		names.append(("✔ " if _is_ready(id) else "○ ") + Net.display_name(id))
	var mine := _is_ready(multiplayer.get_unique_id())
	ready_lbl.text = (tr("Hazırsın") if mine else tr("G: Hazır")) + "      " + "    ".join(names)


## Stat değeri yazısı: çarpanlar "+%20", oranlar "%15", sayılar düz (weapons.gd stat_text ile aynı kural).
func _num(id: String, v: float) -> String:
	if id in ["hp", "bounce"]:
		return str(int(v))
	if id in ["armor", "crit"]:
		return tr("%%%d") % roundi(v * 100.0) # Türkçe "%10", İngilizce "10%"
	return "%+d%%" % roundi((v - 1.0) * 100.0)


func _refresh_stats(st: String) -> void:
	if stat_rows.size() != stat_defs.size(): # satırlar bir kez kurulur
		for n in stat_box.get_children():
			n.queue_free()
		stat_rows.clear()
		for d in stat_defs:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			stat_box.add_child(row)
			_t(row, str(d.get("name", d.get("id", "?"))), 17).custom_minimum_size.x = 150
			var pb := ProgressBar.new()
			pb.show_percentage = false
			pb.size_flags_horizontal = SIZE_EXPAND_FILL
			pb.size_flags_vertical = SIZE_SHRINK_CENTER
			pb.custom_minimum_size.y = 10
			pb.add_theme_stylebox_override("background", main._sb(Color(0, 0, 0, 0.6), 4, 0))
			pb.add_theme_stylebox_override("fill", main._sb(ORANGE, 4, 0))
			pb.min_value = float(d.get("base", 0.0))
			pb.max_value = maxf(float(d.get("max", 0.0)), pb.min_value + 0.001)
			row.add_child(pb)
			var val := _t(row, "", 17)
			val.custom_minimum_size.x = 64
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var b := _button(row, "+", _spend.bind(str(d.get("id", ""))))
			b.custom_minimum_size = Vector2(36, 30)
			b.add_theme_font_size_override("font_size", 20)
			stat_rows.append({"def": d, "bar": pb, "val": val, "btn": b})
	var stats: Dictionary = _g(player, "stats", {})
	var pts: int = _g(player, "stat_points", 0)
	for r in stat_rows:
		var v: float = float(stats.get(r.def.get("id", ""), r.def.get("base", 0.0)))
		r.bar.value = v
		r.val.text = _num(str(r.def.get("id", "")), v)
		# görünmez olunca yer kaplamaya devam etsin: satırlar zıplamasın
		r.btn.modulate.a = 1.0 if st == "break" and pts > 0 and v < r.bar.max_value - 0.0001 else 0.0
		r.btn.disabled = r.btn.modulate.a < 1.0
	stats_sub.text = tr("%s   •   Seviye %d") % [tr(_g(player, "ch", {}).get("name", "Oyuncu")), _g(player, "level", level)]
	points_lbl.text = (tr("Harcanacak stat puanı: %d   (+ ile dağıt)") % pts) if st == "break" and pts > 0 \
		else (tr("Stat puanı: %d   (molada harcanır)") % pts)
	var inv: Array = _g(player, "inv", [])
	if str(inv) != inv_sig:
		inv_sig = str(inv)
		for n in weap_box.get_children():
			n.queue_free()
		for d in inv:
			if d is Dictionary and d.get("kind", "") in ["weapon", "equip"]:
				var it := _item(d)
				var lvl := int(d.get("lvl", 1))
				_t(weap_box, tr("%s    Sv %d   %s") % [it.name, lvl, "●".repeat(clampi(lvl, 0, 8))], 17, it.color.lightened(0.2))


func _spend(id: String) -> void:
	if player and player.has_method("spend_point"):
		player.spend_point(id)
	slow_t = 0.0


# ---------- Seviye kartları ----------

func _make_cards(cards: Array) -> void:
	for n in cards_row.get_children():
		n.queue_free()
	for i in cards.size():
		var d: Dictionary = cards[i]
		var r: Dictionary = rarity.get(d.get("rarity", ""), {})
		var c: Color = r.get("color", Color(0.8, 0.82, 0.9))
		var evo: bool = d.get("type", "") == "evo"
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(310, 236)
		card.pivot_offset = Vector2(155, 118)
		var sb: StyleBoxFlat = main._sb(Color(c.darkened(0.86), 0.94), 14, 16)
		sb.set_border_width_all(4 if evo else 2)
		sb.border_width_top = 7
		sb.border_color = GOLD if evo else c
		if evo: # evrim: altın kenar nabız gibi parlar
			sb.shadow_color = Color(GOLD, 0.7)
			var glow := card.create_tween().set_loops()
			glow.tween_property(sb, "shadow_size", 22, 0.6).from(6).set_trans(Tween.TRANS_SINE)
			glow.tween_property(sb, "shadow_size", 6, 0.6).set_trans(Tween.TRANS_SINE)
		card.add_theme_stylebox_override("panel", sb)
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_choose(i))
		card.mouse_entered.connect(func(): sb.bg_color = Color(c.darkened(0.7), 0.96))
		card.mouse_exited.connect(func(): sb.bg_color = Color(c.darkened(0.86), 0.94))
		cards_row.add_child(card)
		var v := VBoxContainer.new()
		v.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var head := HBoxContainer.new()
		head.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_child(head)
		if evo:
			_chip(head, "✦ EVRİM", GOLD, Color(0.12, 0.06, 0.0), 15)
		var ty := _t(head, "" if evo else TYPES.get(d.get("type", ""), "KART"), 13)
		ty.modulate.a = 0.8
		ty.size_flags_horizontal = SIZE_EXPAND_FILL
		_t(head, tr(str(r.get("name", ""))).to_upper(), 13, c)
		var txt := card_text(d)
		var title := _t(v, txt[0], 25, c.lightened(0.3), true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc := _t(v, txt[1], 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = SIZE_EXPAND_FILL
		desc.modulate.a = 0.9
		_t(v, "[ %d ]" % (i + 1), 22, Color.WHITE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.modulate.a = 0.0 # sırayla zıplayarak belirir
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.05 + i * 0.08)
		tw.tween_property(card, "scale", Vector2.ONE, 0.35).from(Vector2(0.6, 0.6)).set_delay(0.05 + i * 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kartın [başlık, açıklama] çevirisi. weapons.gd yazıyı Türkçe birleştirir; burada id'den tablolara dönülüp
## parçalar ayrı ayrı çevrilir. Tanınmayan kartta düz tr().
func card_text(d: Dictionary) -> Array:
	var title := str(d.get("title", "?"))
	var desc := str(d.get("desc", ""))
	var a := str(d.get("id", "")).split(":")
	var lv := ""
	var m := RegEx.create_from_string("\\(sv\\. (\\d+)/(\\d+)\\)$").search(desc)
	if m:
		lv = tr("  (sv. %d/%d)") % [int(m.get_string(1)), int(m.get_string(2))]
	if a.size() >= 2:
		match str(d.get("type", "")):
			"stat": # weapons.pool ile aynı: "Can: 100 → 115" (oyuncunun şimdiki statından)
				for s in stat_defs:
					if s.get("id") == a[1] and a.size() >= 3:
						var v := float(_g(player, "stats", {}).get(s.id, s.base))
						return [tr(s.name), "%s: %s → %s" % [tr(s.name), _num(s.id, v), _num(s.id, minf(v + s.step * int(a[2]), s.max))]]
			"char":
				for u in wconsts.get("CHAR_UPS", []):
					if u.id == a[1]:
						var ch: Dictionary = _g(player, "ch", {})
						var who := tr(str(ch.get("name" if u.get("passive", false) else "skill_name", "")))
						return [tr(u.name), tr(u.desc) % who + lv]
			"weapon":
				var src: Dictionary = equips.get(a[1], {}) if a[0] == "equip" else {}
				for w in weapons:
					if a[0] == "weapon" and w.get("id") == a[1]:
						src = w
				if src.has("name"):
					return [(tr("EKİPMAN: %s") if a[0] == "equip" else tr("YENİ SİLAH: %s")) % tr(src.name), tr(str(src.get("desc", "")))]
			"weapon_up":
				for u in wconsts.get("UPS", {}).get(a[1], []):
					if a.size() >= 3 and u.id == a[2]:
						return ["%s: %s" % [_item({"kind": "weapon", "id": a[1]}).name, tr(u.name)], tr(u.desc) + lv]
			"evo":
				var ev: Dictionary = wconsts.get("EVOS", {}).get(a[1], {})
				if ev.has("name"):
					return [tr("EVRİM: %s") % tr(ev.name), tr(str(ev.get("desc", "")))]
	return [tr(title), tr(desc)]


func _choose(i: int) -> void:
	if banish_mode:
		banish_mode = false
		if banishes > 0 and player and player.has_method("banish_card") and player.banish_card(i):
			banishes -= 1
			Sfx.play2d(Sfx.whoosh, -4.0)
	elif player and player.has_method("choose_card") and i < _g(player, "cards", []).size():
		player.choose_card(i)
		Sfx.play2d(Sfx.whoosh, -4.0)


func _reroll() -> void:
	if rerolls > 0 and player and player.has_method("reroll_cards"):
		rerolls -= 1
		banish_mode = false
		player.reroll_cards()
		Sfx.play2d(Sfx.whoosh, -4.0)


func _banish_toggle() -> void:
	banish_mode = banishes > 0 and not banish_mode


# ---------- Mağaza ----------

func _open_shop() -> void:
	if shop_rows.size() != shop.size():
		for n in shop_grid.get_children():
			n.queue_free()
		shop_rows.clear()
		for it in shop:
			var c: Color = it.get("color", ORANGE)
			var p := PanelContainer.new()
			p.custom_minimum_size = Vector2(450, 92)
			var sb: StyleBoxFlat = main._sb(Color(0.1, 0.11, 0.17, 0.95), 8, 12)
			sb.border_width_left = 7
			sb.border_color = c
			p.add_theme_stylebox_override("panel", sb)
			shop_grid.add_child(p)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 12)
			p.add_child(h)
			var v := VBoxContainer.new()
			v.size_flags_horizontal = SIZE_EXPAND_FILL
			h.add_child(v)
			_t(v, tr(str(it.get("name", it.get("id", "?")))).to_upper(), 23, c.lightened(0.35), true)
			var d := _t(v, tr(str(it.get("desc", ""))), 14)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.modulate.a = 0.8
			var b := Button.new() # _buy düğmenin kendisini ister, o yüzden _button ile kurulmaz
			b.text = "₺ %d" % int(it.get("price", 0))
			b.focus_mode = FOCUS_NONE
			h.add_child(b)
			b.pressed.connect(_buy.bind(it, b))
			b.custom_minimum_size = Vector2(104, 46)
			b.size_flags_vertical = SIZE_SHRINK_CENTER
			b.add_theme_font_size_override("font_size", 20)
			shop_rows.append({"item": it, "btn": b})
	shop_msg.text = " "
	shop_wrap.show()
	var panel: Control = shop_wrap.get_child(0).get_child(0)
	panel.pivot_offset = panel.size / 2.0
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.2).from(Vector2(0.9, 0.9)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Önce kontrol, sonra istek (yarım alım olmaz); parayı host düşer. Yetmezse fiyat düğmesi sallanır.
func _buy(it: Dictionary, b: Button) -> void:
	var price := int(it.get("price", 0))
	var money: int = _g(td, "money", 0)
	var inv: Array = _g(player, "inv", [])
	var room := inv.size() < 5 # envanter bilinmiyorsa kararı host verir
	for i in [3, 4]:
		if i < inv.size() and (inv[i].is_empty() or inv[i].get("id") == it.get("id")):
			room = true
	if money < price:
		_shop_say(tr("Para yetmiyor: %d ₺ eksik.") % (price - money), RED)
		var x := b.position.x
		var tw := create_tween()
		for dx in [8, -8, 5, -5, 0]:
			tw.tween_property(b, "position:x", x + dx, 0.04)
	elif not room:
		_shop_say("Envanter dolu: 4. ve 5. slotta yer yok. Önce elindeki yapıyı yerleştir.", RED)
	elif td and td.has_method("buy") and td.buy(str(it.get("id", ""))) != false:
		_shop_say(tr("%s alındı.") % tr(str(it.get("name", ""))), Color(0.5, 1.0, 0.6))
	else:
		_shop_say("Şu an alınamıyor.", RED)


func _shop_say(text: String, c: Color) -> void:
	shop_msg.text = text
	shop_msg.add_theme_color_override("font_color", c)
	create_tween().tween_property(shop_msg, "modulate", Color.WHITE, 0.5).from(Color(2, 2, 2))


# ---------- Boss, modifikatör, gece ----------

func _boss_title(type: String) -> String:
	return (tr("BOSS: %s") if type == "boss" else tr("ARA BOSS: %s")) % tr(str(Balance.ENEMIES.get(type, {}).get("name", type)))


## Kısa: "⚡ Hızlı   ☾ Gece"; uzun: her biri "⚡ Hızlı — açıklama" satırı.
func _mods_text(ms: Array, long: bool) -> String:
	var out := PackedStringArray()
	for m in ms:
		var d: Dictionary = Balance.MODS.get(m, {})
		out.append("%s %s" % [MOD_ICONS.get(m, "•"), tr(str(d.get("name", m)))] + (" — " + tr(str(d.get("desc", ""))) if long else ""))
	return ("\n" if long else "     ").join(out)


## "night": yalnız bu makinede, dünyadaki WorldEnvironment sisini koyulaştırır ve güneşi kısar; kapanınca geri alır.
func _night(on: bool) -> void:
	if on == night_on:
		return
	night_on = on
	var w: Node = main.get("world")
	if w == null or not is_instance_valid(w):
		return
	if night_base.is_empty():
		for we in w.find_children("*", "WorldEnvironment", true, false):
			if we.environment:
				var env: Environment = we.environment
				night_base[env] = [env.fog_density, env.volumetric_fog_density, env.fog_light_color]
		for l in w.find_children("*", "DirectionalLight3D", true, false):
			night_base[l] = l.light_energy
	if night_tw:
		night_tw.kill()
	night_tw = create_tween().set_parallel()
	for o in night_base:
		if o is Environment:
			var b: Array = night_base[o]
			night_tw.tween_property(o, "fog_density", b[0] * (9.0 if on else 1.0), 2.0)
			night_tw.tween_property(o, "volumetric_fog_density", b[1] * (4.0 if on else 1.0), 2.0)
			night_tw.tween_property(o, "fog_light_color", b[2] * Color(0.2, 0.25, 0.45) if on else b[2], 2.0)
		else:
			night_tw.tween_property(o, "light_energy", night_base[o] * (0.25 if on else 1.0), 2.0)


# ---------- İlk maç rehberi ----------

func _tut_show() -> void:
	for n in tut_keys.get_children():
		n.queue_free()
	for k in TUT[tut][0]:
		_key(tut_keys, k)
	tut_txt.text = TUT[tut][1]
	tut_step.text = tr("İLK MAÇ REHBERİ   %d / %d") % [tut + 1, TUT.size()]
	create_tween().tween_property(tut_card, "modulate", Color.WHITE, 0.5).from(Color(1.8, 1.6, 1.0))


## Sıradaki adım; son adımdan sonra (ya da H ile atlanınca) profile "bitti" yazar.
func _tut_next() -> void:
	tut += 1
	tut_seen = false
	if tut >= TUT.size():
		tut = -1
		tut_card.hide()
		Profile.set_tutorial_done()
		_banner("", "Rehber tamam. İyi savunmalar!", Color.WHITE)
		return
	tut_n = _builds() if tut == 2 else int(_g(player, "stat_points", 0))
	_tut_show()


func _builds() -> int:
	var b = _g(td, "builds", null)
	return b.get_child_count() if b is Node else 0


## Adım koşulları (yerel): 0 ilk ateş (_input), 1 yapı alındı, 2 yapı kuruldu, 3 hazır oyu, 4 kart seçildi, 5 stat puanı harcandı.
func _tut_tick(st: String, ended: bool, cards_vis: bool) -> void:
	if tut < 0:
		return
	var show := not ended
	if tut == 1:
		var inv: Array = _g(player, "inv", [])
		if inv.any(func(it): return it is Dictionary and it.get("kind", "") == "build"):
			_tut_next()
		elif _builds() > 0: # alıp kurmuş bile: kurma adımı da geçer
			tut = 2
			_tut_next()
	elif tut == 2 and _builds() > tut_n:
		_tut_next()
	elif tut == 3 and (st == "fight" or _is_ready(multiplayer.get_unique_id())):
		_tut_next()
	elif tut == 4: # yalnız kartlar açıkken görünür; seçilince (liste değişince) geçer
		show = show and cards_vis
		if cards_vis and not tut_seen:
			tut_seen = true
			tut_n = card_sig.hash()
		elif tut_seen and card_sig.hash() != tut_n:
			_tut_next()
	elif tut == 5:
		show = show and st == "break"
		var pts: int = _g(player, "stat_points", 0)
		if pts < tut_n or (stats_panel.visible and pts == 0):
			_tut_next()
		else:
			tut_n = pts
	tut_card.visible = show and tut >= 0


# ---------- Oyun sonu ----------

## td.summary_ready: profile işlenir (yalnız bu makinenin oyuncusu), son ekran özetle yeniden kurulur.
func _on_summary(d: Dictionary) -> void:
	summary = d
	if run_gold < 0:
		var g0 := Profile.gold()
		var d2 := d.duplicate()
		d2["tower_hp"] = _g(td, "tower_hp", 0) # ACH_FLAWLESS için
		d2["tower_max"] = _g(td, "tower_max", 0)
		run_new = Profile.add_run(d2, multiplayer.get_unique_id())
		run_gold = Profile.gold() - g0
	_show_end(bool(d.get("won", false)), int(d.get("wave", _g(td, "wave", 0))))


func _show_end(won: bool, wave: int) -> void:
	shop_wrap.hide()
	var again := end_wrap.visible # özet sonradan geldi: yeniden belirme yok
	for n in end_wrap.get_children():
		n.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	end_wrap.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	var endless: bool = summary.get("endless", _g(td, "endless", false))
	var diff: String = summary.get("difficulty", _g(td, "difficulty", "normal"))
	var title := tr("ZAFER!") if won else (tr("SONSUZ: DALGA %d") % wave if endless else tr("KULE DÜŞTÜ"))
	_t(v, title, 92, GOLD if won else RED, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t(v, tr("Rapunzel güvende. Kule tüm dalgalara dayandı.") if won else (tr("Kule %d. dalgada düştü.") % wave if endless else tr("Yaratıklar kuleyi ele geçirdi.")), 24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for s in [["DALGA", str(wave) if endless else "%d / %d" % [wave, wave_count]], ["ZORLUK", tr(str(Balance.DIFFS.get(diff, {}).get("name", diff)))],
			["ÖLDÜRME", str(_g(td, "kills", 0))], ["SEVİYE", str(_g(td, "level", 1))]]:
		var p := PanelContainer.new()
		p.custom_minimum_size.x = 200
		row.add_child(p)
		var pv := VBoxContainer.new()
		p.add_child(pv)
		var cap := _t(pv, s[0], 15, ORANGE)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var val := _t(pv, s[1], 38, DIFF_COLORS.get(diff, Color.WHITE).lightened(0.3) if s[0] == "ZORLUK" else Color.WHITE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if summary.get("players") is Dictionary and not summary.players.is_empty():
		_end_players(v, summary.players, summary.get("mvp", 0))
	if run_gold >= 0:
		_end_profile(v)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	v.add_child(btns)
	# ertelenmiş: düğme sinyali sürerken bu arayüz ağaçtan çıkarılmasın
	if multiplayer.is_server():
		_button(btns, "↻  Tekrar Oyna", func(): main._on_start.call_deferred())
	_button(btns, "◀  Menüye Dön", func(): Net.leave.call_deferred())
	for b in btns.get_children():
		b.custom_minimum_size = Vector2(240, 54)
		b.add_theme_font_size_override("font_size", 20)
	if not multiplayer.is_server():
		_t(v, "Yeniden başlatmayı host yapar.", 15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif won and not endless:
		var note := _t(v, "İpucu: lobide Sonsuz modu açarsan 10. dalgadan sonra da savaş sürer.", 15, Color(0.7, 0.95, 1.0))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_wrap.show()
	if not again:
		end_wrap.modulate.a = 0.0
		create_tween().tween_property(end_wrap, "modulate:a", 1.0, 0.5)


## Oyuncu tablosu: ad, hasar, öldürme, kritik, yapı, ölüm, unvanlar; MVP altın çerçeveli.
func _end_players(parent: Node, ps: Dictionary, mvp: int) -> void:
	var titles := {}
	for peer in ps:
		titles[peer] = []
	# shortcut: isabet sayısı tutulmuyor; "kritik oranı" = kritik / öldürme. pstats'a "hits" eklenirse ona geçilir.
	for t in [["Kasap", "kills"], ["Mimar", "builds"], ["Keskin Göz", "crit"]]:
		var top := 0
		var hi := 0.0
		for peer in ps:
			var st: Dictionary = ps[peer]
			var x := float(st.get("crits", 0)) / maxi(int(st.get("kills", 0)), 1) if t[1] == "crit" else float(st.get(t[1], 0))
			if x > hi:
				hi = x
				top = peer
		if top != 0:
			titles[top].append(tr(t[0]))
	for peer in ps:
		if int(ps[peer].get("deaths", 0)) == 0:
			titles[peer].append(tr("Ölümsüz"))
	var widths := [250, 110, 110, 100, 90, 90, 330]
	var rows := [["OYUNCU", "HASAR", "ÖLDÜRME", "KRİTİK", "YAPI", "ÖLÜM", "UNVAN"]]
	var peers := ps.keys()
	peers.sort()
	for peer in peers:
		var st: Dictionary = ps[peer]
		rows.append([Net.display_name(int(peer)), str(st.get("dmg", 0)), str(st.get("kills", 0)), str(st.get("crits", 0)),
			str(st.get("builds", 0)), str(st.get("deaths", 0)), "  •  ".join(PackedStringArray(titles[peer])), peer])
	for r in rows:
		var head: bool = r.size() == 7
		var star: bool = not head and r[7] == mvp
		var p := PanelContainer.new()
		var sb: StyleBoxFlat = main._sb(Color(0, 0, 0, 0.0 if head else 0.45), 8, 6)
		if star:
			sb.bg_color = Color(0.35, 0.25, 0.05, 0.75)
			sb.set_border_width_all(2)
			sb.border_color = GOLD
		p.add_theme_stylebox_override("panel", sb)
		parent.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		p.add_child(h)
		for c in 7:
			var txt: String = ("★ MVP  " if star and c == 0 else "") + r[c]
			var l := _t(h, txt, 14 if head else (18 if c != 6 else 16), ORANGE if head else (GOLD if star and c == 0 else Color.WHITE))
			l.custom_minimum_size.x = widths[c]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if c in [0, 6] else HORIZONTAL_ALIGNMENT_CENTER
			if c == 6:
				l.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0) if not head else ORANGE)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Kalıcı ilerleme: kazanılan Altın Saç, yeni açılımlar, sıradaki açılımların ilerlemesi.
func _end_profile(parent: Node) -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = SIZE_SHRINK_CENTER
	p.custom_minimum_size.x = 760
	var sb: StyleBoxFlat = main._sb(Color(0.12, 0.09, 0.03, 0.92), 12, 14)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD, 0.7)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	v.add_child(h)
	_t(h, tr("+%d ALTIN SAÇ") % run_gold, 34, GOLD, true)
	_t(h, tr("Toplam: %d") % Profile.gold(), 18).size_flags_vertical = SIZE_SHRINK_CENTER
	if not run_new.is_empty(): # tek satır (çok açılımda kaydırarak): "YENİ: Yay, Bumerang açıldı!"
		var l := _t(v, tr("YENİ: %s açıldı!") % ", ".join(PackedStringArray(run_new.map(_unlock_name))), 22, Color(0.5, 1.0, 0.6), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 720
	var prog := PackedStringArray()
	for id in Profile.QUESTS:
		var q: Array = Profile.unlock_progress(id)
		if q[0] < q[1] and prog.size() < 3:
			prog.append("%s: %d/%d" % [_unlock_name(id), q[0], q[1]])
	if not prog.is_empty():
		var l := _t(v, tr("Sıradaki açılımlar:   %s") % "     ".join(prog), 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.85


## "weapon:bow" -> "Yay", "diff:hard" -> "Zor zorluğu", "mode:endless" -> "Sonsuz mod".
func _unlock_name(id: String) -> String:
	var k := id.get_slice(":", 1)
	if id.begins_with("weapon:"):
		for w in weapons:
			if w.get("id") == k:
				return tr(str(w.name))
	elif id.begins_with("diff:"):
		return tr("%s zorluğu") % tr(str(Balance.DIFFS.get(k, {}).get("name", k)))
	elif id == "mode:endless":
		return tr("Sonsuz mod")
	return k.capitalize()
