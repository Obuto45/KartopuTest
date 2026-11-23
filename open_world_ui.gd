extends Control
## Açık Dünya HUD: Gece/Gündüz göstergesi, canlı dairesel radar/minimap,
## 5+15 slotluk tam envanter ve çanta (E / Tab), seviye atlama kartları (Evrim dahil),
## kutu açma istemi, silah dock'u, XP çubuğu ve dürbün/nişangâh katmanı.

const Weapons := preload("res://weapons.gd")
const Balance := preload("res://balance.gd")

const TYPES := {"stat": "▲  STAT", "char": "★  KARAKTER", "weapon": "✚  YENİ SİLAH", "weapon_up": "◆  SİLAH YÜKSELTME", "evo": "✦  EVRİM"}
const GOLD := Color(1.0, 0.82, 0.25)
const ORANGE := Color(1.0, 0.62, 0.18)
const GREY := Color(0.55, 0.58, 0.65)
const RED := Color(1.0, 0.35, 0.30)

var main: Node
var ow: Node
var player: Node3D

var weapons: Array = Weapons.LIST
var rarity: Dictionary = Weapons.RARITY
var stat_defs: Array = Weapons.STATS
var items: Dictionary = Weapons.ITEMS
var equips: Dictionary = Weapons.EQUIPS

# Üst-sol bilgi kartı
var day_lbl: Label
var rival_lbl: Label
var monster_lbl: Label
var crate_lbl: Label

# Minimap
var minimap: Control

# Alt XP + Hotbar
var xp_fill: ColorRect
var xp_flash: ColorRect
var lvl_badge: PanelContainer
var lvl_lbl: Label
var cells := [] # 5 slot + Q

# Etkileşim istemi + bildirim + ölüm
var prompt_box: PanelContainer
var prompt_lbl: Label
var toast_box: PanelContainer
var toast_lbl: Label
var toast_tw: Tween
var dead_lbl: Label

# Çanta (5 el + 15 çanta)
var inv_wrap: PanelContainer
var inv_msg: Label
var inv_cells := []
var inv_sel := -1

# Seviye kartları
var cards_box: VBoxContainer
var cards_row: HBoxContainer
var card_sig := ""

# Dürbün + nişangâh halkası
var scope: ColorRect
var ring: Control

var _last_lvl := 1
var _xp_f := 0.0


class MinimapView extends Control:
	var ui_ref: Control

	func _draw() -> void:
		if ui_ref == null or ui_ref.ow == null or not is_instance_valid(ui_ref.ow):
			return
		var ow_n: Node = ui_ref.ow
		var p: Node3D = ui_ref.player
		var center := size * 0.5
		var rad := minf(size.x, size.y) * 0.5 - 4.0
		var world_r := 76.0 # radar menzili (metre)

		# Koyu cam daire ve menzil halkaları
		draw_circle(center, rad, Color(0.04, 0.06, 0.10, 0.84))
		draw_arc(center, rad, 0.0, TAU, 64, Color(1.0, 0.82, 0.45, 0.48), 2.0, true)
		draw_arc(center, rad * 0.66, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.09), 1.0, true)
		draw_arc(center, rad * 0.33, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.09), 1.0, true)
		draw_line(center + Vector2(-rad + 6, 0), center + Vector2(rad - 6, 0), Color(1, 1, 1, 0.07), 1.0)
		draw_line(center + Vector2(0, -rad + 6), center + Vector2(0, rad - 6), Color(1, 1, 1, 0.07), 1.0)

		var ppos := p.global_position if p and is_instance_valid(p) else Vector3.ZERO
		var scale_k := (rad - 8.0) / world_r

		# 1. Evler (sıcak kehribar kareler)
		for h in ow_n.houses_data:
			var rel := Vector2(h.pos.x - ppos.x, h.pos.z - ppos.z) * scale_k
			if rel.length() > rad - 7.0:
				rel = rel.normalized() * (rad - 7.0)
			var pt := center + rel
			draw_rect(Rect2(pt - Vector2(4.5, 4.5), Vector2(9, 9)), Color(0.95, 0.68, 0.30, 0.92), true)
			draw_rect(Rect2(pt - Vector2(4.5, 4.5), Vector2(9, 9)), Color(0.15, 0.08, 0.02, 0.9), false, 1.2)

		# 2. Açılmamış kutular (parlak camgöbeği elmaslar)
		for c in ow_n.crates:
			if c.opened:
				continue
			var rel := Vector2(c.pos.x - ppos.x, c.pos.z - ppos.z) * scale_k
			if rel.length() > rad - 6.0:
				continue
			var pt := center + rel
			var pts := PackedVector2Array([pt + Vector2(0, -4), pt + Vector2(4, 0), pt + Vector2(0, 4), pt + Vector2(-4, 0)])
			draw_colored_polygon(pts, Color(0.35, 0.95, 1.0, 0.95))

		# 3. Düşmanlar: karakter muhafızları (mor/altın) ve yaratıklar (kırmızı)
		for e in ow_n.elist:
			if not is_instance_valid(e) or e.hp <= 0:
				continue
			var rel := Vector2(e.global_position.x - ppos.x, e.global_position.z - ppos.z) * scale_k
			if rel.length() > rad - 5.0:
				continue
			var pt := center + rel
			if e.is_in_group("rivals"):
				var is_el := bool(e.get("elite"))
				draw_circle(pt, 3.6 if is_el else 2.5, Color(1.0, 0.82, 0.25) if is_el else Color(0.76, 0.45, 1.0))
			else:
				var is_boss := str(e.get("type")) == "boss"
				draw_circle(pt, 4.5 if is_boss else 2.4, Color(1.0, 0.22, 0.55) if is_boss else Color(1.0, 0.32, 0.28))

		# 4. Oyuncu bakış konisi ve yön oku (merkezde)
		var yaw := 0.0
		if p and is_instance_valid(p):
			var fwd := -p.global_basis.z
			yaw = atan2(fwd.x, -fwd.z)
		var cone_l := center + Vector2(sin(yaw - 0.45), -cos(yaw - 0.45)) * 22.0
		var cone_r := center + Vector2(sin(yaw + 0.45), -cos(yaw + 0.45)) * 22.0
		draw_colored_polygon(PackedVector2Array([center, cone_l, cone_r]), Color(0.45, 1.0, 0.65, 0.16))
		var tip := center + Vector2(sin(yaw), -cos(yaw)) * 7.5
		var bl := center + Vector2(sin(yaw + 2.45), -cos(yaw + 2.45)) * 5.8
		var br := center + Vector2(sin(yaw - 2.45), -cos(yaw - 2.45)) * 5.8
		draw_colored_polygon(PackedVector2Array([tip, bl, br]), Color(0.45, 1.0, 0.65, 1.0))


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = main.ui.theme
	_build_top_left()
	_build_minimap()
	_build_bottom()
	_build_prompt_and_toast()
	_build_inv()
	_build_cards()
	_build_aim()


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


func _chip(parent: Node, text: String, bg: Color, fg: Color, px := 14) -> Label:
	var p := PanelContainer.new()
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.size_flags_vertical = SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = main._sb(bg, 6, 0)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var l := _t(p, text, px, fg)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------- Kurulum ----------

func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_TOP_LEFT)
	panel.offset_left = 20; panel.offset_top = 104
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = main._sb(Color(0.04, 0.05, 0.09, 0.78), 12, 10)
	sb.set_border_width_all(1)
	sb.border_color = Color(1.0, 0.82, 0.45, 0.28)
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	day_lbl = _t(v, "☀  GÜNDÜZ  •  AÇIK DÜNYA", 15, Color(1.0, 0.88, 0.50), true)
	var stats := HBoxContainer.new()
	stats.mouse_filter = MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 14)
	v.add_child(stats)
	rival_lbl = _t(stats, "⚔ Muhafız: 0/48", 14, Color(0.84, 0.65, 1.0))
	monster_lbl = _t(stats, "☠ Yaratık: 0/30", 14, Color(1.0, 0.56, 0.52))
	crate_lbl = _t(stats, "✦ Kutu: 0/22", 14, Color(0.45, 0.94, 1.0))
	var tip := _t(v, "[E] Kutu Aç / Çanta   •   [Tab] Çanta   •   [Q] Yetenek", 12, Color(0.82, 0.86, 0.94))
	tip.modulate.a = 0.72


func _build_minimap() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(PRESET_TOP_RIGHT)
	box.offset_left = -204; box.offset_right = -18
	box.offset_top = 16
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var mv := MinimapView.new()
	mv.ui_ref = self
	mv.custom_minimum_size = Vector2(180, 180)
	mv.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(mv)
	minimap = mv

	var leg_p := PanelContainer.new()
	leg_p.mouse_filter = MOUSE_FILTER_IGNORE
	var lsb: StyleBoxFlat = main._sb(Color(0.04, 0.06, 0.10, 0.78), 8, 4)
	lsb.content_margin_left = 8; lsb.content_margin_right = 8
	leg_p.add_theme_stylebox_override("panel", lsb)
	box.add_child(leg_p)
	var leg := _t(leg_p, "■ Ev  ◆ Kutu  ● Muhafız  ● Yaratık", 11, Color(0.92, 0.95, 1.0))
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_bottom() -> void:
	# Alt XP çubuğu + seviye rozeti
	var back := _rect(self, Color(0, 0, 0, 0.74))
	back.set_anchors_preset(PRESET_BOTTOM_WIDE)
	back.offset_left = 104; back.offset_top = -12
	xp_fill = _rect(back, Color(0.35, 0.82, 1.0))
	xp_fill.offset_top = 2; xp_fill.offset_bottom = -2
	xp_fill.anchor_right = 0.0
	xp_flash = _rect(back, Color(1, 1, 1, 0))

	lvl_badge = PanelContainer.new()
	lvl_badge.set_anchors_preset(PRESET_BOTTOM_LEFT)
	lvl_badge.offset_top = -34; lvl_badge.offset_right = 104
	lvl_badge.pivot_offset = Vector2(52, 34)
	lvl_badge.mouse_filter = MOUSE_FILTER_IGNORE
	var bs: StyleBoxFlat = main._sb(Color(0.07, 0.11, 0.19, 0.94), 0, 2)
	bs.corner_radius_top_right = 10
	bs.border_width_top = 2; bs.border_width_right = 2
	bs.border_color = Color(0.35, 0.82, 1.0)
	lvl_badge.add_theme_stylebox_override("panel", bs)
	add_child(lvl_badge)
	lvl_lbl = _t(lvl_badge, "SV 1", 19, Color.WHITE, true)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Koyu cam silah / eşya / Q dock'u
	var dock := PanelContainer.new()
	dock.set_anchors_preset(PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = GROW_DIRECTION_BOTH
	dock.grow_vertical = GROW_DIRECTION_BEGIN
	dock.offset_bottom = -20
	dock.mouse_filter = MOUSE_FILTER_IGNORE
	var dock_sb: StyleBoxFlat = main._sb(Color(0.04, 0.05, 0.09, 0.76), 14, 0)
	dock_sb.content_margin_left = 12; dock_sb.content_margin_right = 12
	dock_sb.content_margin_top = 6; dock_sb.content_margin_bottom = 8
	dock_sb.set_border_width_all(1)
	dock_sb.border_color = Color(1.0, 0.86, 0.55, 0.24)
	dock_sb.shadow_color = Color(0, 0, 0, 0.45)
	dock_sb.shadow_size = 12
	dock.add_theme_stylebox_override("panel", dock_sb)
	add_child(dock)

	var inv := HBoxContainer.new()
	inv.mouse_filter = MOUSE_FILTER_IGNORE
	inv.add_theme_constant_override("separation", 14)
	dock.add_child(inv)

	var key := 1
	for g in [["SİLAH  /  EKİPMAN", 3], ["EŞYA", 2], ["YETENEK", 1]]:
		var gv := VBoxContainer.new()
		gv.mouse_filter = MOUSE_FILTER_IGNORE
		gv.add_theme_constant_override("separation", 3)
		inv.add_child(gv)
		var cap := _t(gv, g[0], 11, Color(0.86, 0.90, 0.96))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.modulate.a = 0.72
		var gh := HBoxContainer.new()
		gh.mouse_filter = MOUSE_FILTER_IGNORE
		gh.add_theme_constant_override("separation", 7)
		gv.add_child(gh)
		for _i in g[1]:
			var is_q := key > 5
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(118 if is_q else 102, 84)
			cell.mouse_filter = MOUSE_FILTER_IGNORE
			var sb: StyleBoxFlat = main._sb(Color(0.08, 0.10, 0.16, 0.86), 10, 5)
			sb.set_border_width_all(2)
			cell.add_theme_stylebox_override("panel", sb)
			gh.add_child(cell)

			var icon_m := MarginContainer.new()
			icon_m.mouse_filter = MOUSE_FILTER_IGNORE
			icon_m.add_theme_constant_override("margin_top", 10)
			icon_m.add_theme_constant_override("margin_bottom", 20)
			icon_m.add_theme_constant_override("margin_left", 5)
			icon_m.add_theme_constant_override("margin_right", 5)
			cell.add_child(icon_m)
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = MOUSE_FILTER_IGNORE
			icon_m.add_child(icon)

			var kwrap := PanelContainer.new()
			kwrap.size_flags_horizontal = SIZE_SHRINK_BEGIN
			kwrap.size_flags_vertical = SIZE_SHRINK_BEGIN
			kwrap.mouse_filter = MOUSE_FILTER_IGNORE
			var ksb: StyleBoxFlat = main._sb(Color(0.03, 0.04, 0.07, 0.88), 5, 0)
			ksb.content_margin_left = 5; ksb.content_margin_right = 5
			ksb.set_border_width_all(1)
			ksb.border_color = Color(1, 1, 1, 0.22)
			kwrap.add_theme_stylebox_override("panel", ksb)
			cell.add_child(kwrap)
			var kl := _t(kwrap, "Q" if is_q else str(key), 11, Color(1.0, 0.90, 0.65) if is_q else Color(0.9, 0.94, 1.0))
			kl.add_theme_constant_override("outline_size", 0)

			var n_wrap := MarginContainer.new()
			n_wrap.mouse_filter = MOUSE_FILTER_IGNORE
			n_wrap.add_theme_constant_override("margin_top", 18 if is_q else 0)
			n_wrap.add_theme_constant_override("margin_bottom", 3)
			cell.add_child(n_wrap)
			var n := _t(n_wrap, "", 12)
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			var cnt := _t(cell, "", 12, GOLD)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			var pips := _t(cell, "", 11, GOLD)
			pips.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			pips.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pips.size_flags_vertical = SIZE_SHRINK_BEGIN

			var cdb := ProgressBar.new()
			cdb.show_percentage = false
			cdb.max_value = 1.0
			cdb.custom_minimum_size.y = 4
			cdb.size_flags_vertical = SIZE_SHRINK_END
			cdb.mouse_filter = MOUSE_FILTER_IGNORE
			cdb.add_theme_stylebox_override("background", StyleBoxEmpty.new())
			cdb.add_theme_stylebox_override("fill", main._sb(Color(1.0, 0.82, 0.32, 0.92), 2, 0))
			cell.add_child(cdb)

			cells.append({"sb": sb, "name": n, "count": cnt, "pips": pips, "icon": icon, "cd": cdb, "cd_max": 0.0})
			key += 1


func _build_prompt_and_toast() -> void:
	prompt_box = PanelContainer.new()
	prompt_box.set_anchors_preset(PRESET_CENTER_BOTTOM)
	prompt_box.grow_horizontal = GROW_DIRECTION_BOTH
	prompt_box.grow_vertical = GROW_DIRECTION_BEGIN
	prompt_box.offset_bottom = -138
	prompt_box.mouse_filter = MOUSE_FILTER_IGNORE
	var psb: StyleBoxFlat = main._sb(Color(0.05, 0.08, 0.14, 0.90), 10, 8)
	psb.set_border_width_all(2)
	psb.border_color = Color(0.35, 0.92, 1.0, 0.85)
	prompt_box.add_theme_stylebox_override("panel", psb)
	prompt_box.hide()
	add_child(prompt_box)
	prompt_lbl = _t(prompt_box, "[E] Kutuyu Aç", 17, Color(0.85, 0.98, 1.0), true)

	toast_box = PanelContainer.new()
	toast_box.set_anchors_preset(PRESET_CENTER_TOP)
	toast_box.grow_horizontal = GROW_DIRECTION_BOTH
	toast_box.offset_top = 18
	toast_box.mouse_filter = MOUSE_FILTER_IGNORE
	var tsb: StyleBoxFlat = main._sb(Color(0.04, 0.06, 0.10, 0.88), 10, 10)
	tsb.set_border_width_all(1)
	tsb.border_color = Color(1.0, 0.82, 0.45, 0.45)
	toast_box.add_theme_stylebox_override("panel", tsb)
	toast_box.modulate.a = 0.0
	add_child(toast_box)
	toast_lbl = _t(toast_box, "", 16, Color.WHITE)

	dead_lbl = _t(self, "", 42, RED, true)
	dead_lbl.anchor_right = 1.0
	dead_lbl.anchor_top = 0.42; dead_lbl.anchor_bottom = 0.42
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_inv() -> void:
	inv_wrap = PanelContainer.new()
	inv_wrap.set_anchors_preset(PRESET_CENTER)
	inv_wrap.grow_horizontal = GROW_DIRECTION_BOTH
	inv_wrap.grow_vertical = GROW_DIRECTION_BOTH
	var sb: StyleBoxFlat = main._sb(Color(0.05, 0.06, 0.10, 0.96), 14, 18)
	sb.set_border_width_all(1)
	sb.border_color = Color(1.0, 0.72, 0.28, 0.42)
	sb.shadow_color = Color(0, 0, 0, 0.58)
	sb.shadow_size = 18
	inv_wrap.add_theme_stylebox_override("panel", sb)
	inv_wrap.hide()
	add_child(inv_wrap)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	inv_wrap.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_t(head, "ENVANTER & ÇANTA", 32, ORANGE, true).size_flags_horizontal = SIZE_EXPAND_FILL
	_chip(head, "E / TAB", Color(0.93, 0.94, 0.98), Color(0.08, 0.09, 0.13), 15)
	_t(v, "Sürükle-bırak ya da tıkla -> hedef slota tıkla. Silah / ekipman 1–3, eşyalar 4–5. slota girer.", 14).modulate.a = 0.75
	_t(v, "EL SLOTLARI (1–5)", 14, ORANGE)
	var hand := HBoxContainer.new()
	hand.add_theme_constant_override("separation", 8)
	v.add_child(hand)
	for i in 5:
		_inv_cell(hand, i)
	v.add_child(HSeparator.new())
	_t(v, "ÇANTA (15 SLOT)", 14, ORANGE)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for i in Weapons.BAG_SIZE:
		_inv_cell(grid, 5 + i)
	inv_msg = _t(v, " ", 15)
	inv_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _inv_cell(parent: Node, idx: int) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(114, 80)
	var sb: StyleBoxFlat = main._sb(Color(0.08, 0.10, 0.16, 0.72), 8, 6)
	sb.set_border_width_all(2)
	cell.add_theme_stylebox_override("panel", sb)
	cell.set_drag_forwarding(_inv_drag.bind(idx), _inv_can_drop.bind(idx), _inv_drop.bind(idx))
	cell.gui_input.connect(_inv_click.bind(idx))
	parent.add_child(cell)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	if idx < 5:
		_t(cell, str(idx + 1), 12).modulate.a = 0.75
	var n := _t(cell, "", 13)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var info := _t(cell, "", 13, GOLD)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	inv_cells.append({"sb": sb, "icon": icon, "name": n, "info": info})


func _build_cards() -> void:
	cards_box = VBoxContainer.new()
	cards_box.set_anchors_preset(PRESET_CENTER)
	cards_box.grow_horizontal = GROW_DIRECTION_BOTH
	cards_box.grow_vertical = GROW_DIRECTION_BOTH
	cards_box.mouse_filter = MOUSE_FILTER_IGNORE
	cards_box.add_theme_constant_override("separation", 8)
	cards_box.hide()
	add_child(cards_box)
	_t(cards_box, "★  SEVİYE ATLADIN!  ★", 34, GOLD, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_t(cards_box, "Bir kart seç  ([1] [2] [3]  veya tıkla)", 15, Color(0.9, 0.94, 1.0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.mouse_filter = MOUSE_FILTER_IGNORE
	cards_row.add_theme_constant_override("separation", 16)
	cards_box.add_child(cards_row)


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
		if player == null or not is_instance_valid(player):
			return
		var age := (Time.get_ticks_msec() - int(player.get("hit_ms"))) / 1000.0
		if age < 0.16:
			var kill := bool(player.get("hit_kill"))
			var hc := Color(1.0, 0.25, 0.2) if kill else Color(1, 1, 1, 0.95)
			var r0 := 9.0 if kill else 7.0
			var r1 := r0 + (9.0 if kill else 6.0) * (1.0 - age / 0.16 * 0.4)
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				ring.draw_line(d.normalized() * r0, d.normalized() * r1, hc, 2.5 if kill else 2.0, true)
		var k := float(player.get("draw_k"))
		if str(player.get("busy")) == "charge":
			var c := Color.WHITE if k >= 1.0 else Color(1, 1, 1, 0.55)
			ring.draw_arc(Vector2.ZERO, 26.0, -PI / 2, -PI / 2 + TAU * k, 48, c, 3.0 if k >= 1.0 else 2.0, true))
	add_child(ring)


func _update_aim() -> void:
	if player == null or not is_instance_valid(player):
		scope.visible = false
		return
	scope.visible = bool(player.get("scoped"))
	(scope.material as ShaderMaterial).set_shader_parameter("px", size)
	ring.queue_redraw()


# ---------- Her kare ----------

func _process(dt: float) -> void:
	if ow == null or not is_instance_valid(ow):
		ow = get_tree().get_first_node_in_group("open_world")
		if ow and ow.has_signal("toast"):
			ow.toast.connect(_show_toast)
	if (player == null or not is_instance_valid(player)) and main.players:
		player = main.players.get_node_or_null(str(multiplayer.get_unique_id())) as Node3D
	if ow == null or player == null:
		return

	_update_aim()
	_update_top_left()
	_update_xp(dt)
	_update_hotbar()
	_update_prompt()
	_update_cards()
	if inv_wrap.visible:
		_refresh_inv()
	if minimap:
		minimap.queue_redraw()

	var alive := int(player.get("hp")) > 0
	dead_lbl.text = "" if alive else "DÜŞTÜN — Kampa dönülüyor..."

	if not main.settings_wrap.visible:
		var m := Input.MOUSE_MODE_VISIBLE if want_mouse() else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != m:
			Input.mouse_mode = m


func cards_open() -> bool:
	return cards_box != null and cards_box.visible


func want_mouse() -> bool:
	return (inv_wrap != null and inv_wrap.visible) or cards_open()


func _input(e: InputEvent) -> void:
	if main.settings_wrap.visible:
		return
	var key: int = e.physical_keycode if e is InputEventKey and e.pressed and not e.echo else 0
	if inv_wrap.visible and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("interact") or key == KEY_TAB):
		_toggle_inv()
		get_viewport().set_input_as_handled()
		return
	if cards_open() and key in [KEY_1, KEY_2, KEY_3]:
		_choose(key - KEY_1)
		get_viewport().set_input_as_handled()
		return
	if key == KEY_TAB and player and int(player.get("hp")) > 0:
		_toggle_inv()
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("interact") and player and int(player.get("hp")) > 0:
		if ow and ow.try_open_nearby_crate():
			get_viewport().set_input_as_handled()
			return
		_toggle_inv()
		get_viewport().set_input_as_handled()


func _update_top_left() -> void:
	if ow.is_night:
		day_lbl.text = "☾  GECE  •  Ev Fenerleri Açık  •  +%50 XP"
		day_lbl.add_theme_color_override("font_color", Color(0.68, 0.82, 1.0))
	else:
		var phase := "🌅  GÜN BATIMI" if ow.day_t > 0.44 and ow.day_t < 0.56 else "☀  GÜNDÜZ"
		day_lbl.text = "%s  •  AÇIK DÜNYA" % phase
		day_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	rival_lbl.text = "⚔ Muhafız: %d/%d" % [ow.rivals_killed, ow.rivals_total]
	monster_lbl.text = "☠ Yaratık: %d/%d" % [ow.monsters_killed, ow.monsters_total]
	crate_lbl.text = "✦ Kutu: %d/%d" % [ow.crates_opened, ow.crates_total]


func _update_xp(dt: float) -> void:
	var lvl: int = ow.level
	if lvl != _last_lvl:
		_last_lvl = lvl
		lvl_lbl.text = "SV %d" % lvl
		xp_flash.color.a = 0.9
		lvl_badge.scale = Vector2(1.4, 1.4)
		var tw := create_tween().set_parallel()
		tw.tween_property(xp_flash, "color:a", 0.0, 0.7)
		tw.tween_property(lvl_badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target_f := clampf(float(ow.xp) / maxf(float(ow.xp_next), 1.0), 0.0, 1.0)
	_xp_f = lerpf(_xp_f, target_f, minf(1.0, dt * 8.0))
	xp_fill.anchor_right = _xp_f


func _update_prompt() -> void:
	var c: Dictionary = ow.nearby_crate
	if c.is_empty() or inv_wrap.visible or cards_open():
		prompt_box.hide()
	else:
		prompt_lbl.text = "[E]  Kutuyu Aç  •  %s" % str(c.get("house", ""))
		prompt_box.show()


func _show_toast(text: String, col: Color) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", col)
	if toast_tw:
		toast_tw.kill()
	toast_box.modulate.a = 0.0
	toast_tw = create_tween()
	toast_tw.tween_property(toast_box, "modulate:a", 1.0, 0.22)
	toast_tw.tween_interval(3.0)
	toast_tw.tween_property(toast_box, "modulate:a", 0.0, 0.55)


# ---------- Envanter & Hotbar ----------

func _item(d: Dictionary) -> Dictionary:
	var id := str(d.get("id", ""))
	var src := {}
	match str(d.get("kind", "")):
		"item": src = items.get(id, {})
		"equip": src = equips.get(id, {})
		_:
			for w in weapons:
				if w.get("id") == id:
					src = w
	var c: Color = src.get("color", Color.WHITE)
	if src.has("rarity"):
		c = rarity.get(src.rarity, {}).get("color", c)
	return {"name": id.capitalize() if src.is_empty() else tr(str(src.name)), "color": c}


func _update_hotbar() -> void:
	var inv: Array = player.get("inv")
	var sel: int = int(player.get("slot"))
	for i in 5:
		var d: Dictionary = inv[i] if i < inv.size() and inv[i] is Dictionary else {}
		var c: Dictionary = cells[i]
		var it := _item(d) if not d.is_empty() else {"name": "", "color": Color(GREY, 0.45)}
		c.name.text = it.name
		var tex: Texture2D = main.weapon_icon(str(d.get("id", ""))) if d.get("kind", "") == "weapon" else null
		c.icon.texture = tex
		c.name.size_flags_vertical = SIZE_SHRINK_END if tex else SIZE_FILL
		c.name.add_theme_font_size_override("font_size", 11 if tex else 13)
		var left := 0.0
		if d.get("id", "") == "shield": left = float(player.get("shield_cd"))
		elif d.get("id", "") == "wall": left = float(player.get("wall_cd"))
		elif d.get("kind", "") == "weapon" and sel == i + 1: left = float(player.get("cd"))
		if sel == i + 1 and bool(player.get("reloading")):
			left = float(player.get("reload_t"))
		c.cd_max = maxf(c.cd_max, left) if left > 0.0 else 0.0
		c.cd.value = left / c.cd_max if c.cd_max > 0.0 else 0.0
		c.count.text = "x%d" % d.count if int(d.get("count", 1)) > 1 else ""
		c.count.modulate = Color.WHITE
		var mag := 0
		if d.get("kind", "") == "weapon":
			for w in weapons:
				if w.get("id") == d.id:
					mag = int(w.get("mag", 0))
		if mag > 0:
			var am: int = int(d.get("ammo", mag))
			c.count.text = tr("%%%d") % roundi(am * 100.0 / mag) if d.id == "flame" else "%d / ∞" % am
			if am <= 0:
				c.count.modulate = Color(1.0, 0.25, 0.2, 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012))
			elif am <= mag / 4:
				c.count.modulate = Color(1.0, 0.6, 0.15)
		c.pips.text = "●".repeat(clampi(int(d.get("lvl", 0)), 0, 8))
		c.sb.border_color = it.color
		c.sb.bg_color = Color(0.24, 0.16, 0.05, 0.92) if sel == i + 1 else Color(0.08, 0.10, 0.16, 0.84)
		c.sb.shadow_color = Color(1.0, 0.82, 0.28, 0.55)
		c.sb.shadow_size = 10 if sel == i + 1 else 0

	var ch: Dictionary = player.get("ch")
	var cd := float(player.get("skill_cd"))
	cells[5].name.text = "%s\n%s" % [tr(str(ch.get("skill_name", ""))), main._cd_text(cd)]
	cells[5].sb.border_color = ch.get("color", GREY) if cd <= 0.0 else Color(GREY, 0.55)


func _inv_at(idx: int) -> Dictionary:
	var arr: Array = player.get("inv" if idx < 5 else "bag")
	var i := idx if idx < 5 else idx - 5
	return arr[i] if i < arr.size() and arr[i] is Dictionary else {}


func _inv_can_move(a: int, b: int) -> bool:
	return Weapons.move_item(player.get("inv").duplicate(true), player.get("bag").duplicate(true), a, b)


func _inv_move(a: int, b: int) -> void:
	inv_sel = -1
	if player.has_method("move_item") and _inv_can_move(a, b):
		player.move_item(a, b)
		inv_msg.text = " "
	else:
		inv_msg.text = "Buraya taşınamaz: silah / ekipman 1–3, eşya 4–5. slota girer."
		inv_msg.add_theme_color_override("font_color", RED)


func _inv_drag(_at: Vector2, idx: int) -> Variant:
	var d := _inv_at(idx)
	if d.is_empty():
		return null
	inv_sel = -1
	var pv := PanelContainer.new()
	_t(pv, _item(d).name, 16, GOLD)
	set_drag_preview(pv)
	return {"inv_from": idx}


func _inv_can_drop(_at: Vector2, data: Variant, idx: int) -> bool:
	return data is Dictionary and data.has("inv_from") and _inv_can_move(int(data.inv_from), idx)


func _inv_drop(_at: Vector2, data: Variant, idx: int) -> void:
	_inv_move(int(data.inv_from), idx)


func _inv_click(e: InputEvent, idx: int) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if inv_sel < 0:
		inv_sel = idx if not _inv_at(idx).is_empty() else -1
	elif inv_sel == idx:
		inv_sel = -1
	else:
		_inv_move(inv_sel, idx)


func _refresh_inv() -> void:
	var held: int = int(player.get("slot")) - 1
	for i in inv_cells.size():
		var c: Dictionary = inv_cells[i]
		var d := _inv_at(i)
		var it := _item(d) if not d.is_empty() else {"name": "", "color": Color(GREY, 0.45)}
		c.name.text = it.name
		var tex: Texture2D = main.weapon_icon(str(d.get("id", ""))) if d.get("kind", "") == "weapon" else null
		c.icon.texture = tex
		c.name.size_flags_vertical = SIZE_SHRINK_END if tex else SIZE_FILL
		var txt := "x%d" % d.count if int(d.get("count", 1)) > 1 else ""
		if d.get("kind", "") in ["weapon", "equip"]:
			txt = tr("Sv %d") % int(d.get("lvl", 1))
		c.info.text = txt
		c.sb.border_color = GOLD if i == inv_sel else it.color
		c.sb.bg_color = Color(0.95, 0.5, 0.1, 0.42) if i == inv_sel else (Color(0.95, 0.5, 0.1, 0.18) if i == held else Color(0.08, 0.10, 0.16, 0.72))


func _toggle_inv() -> void:
	inv_wrap.visible = not inv_wrap.visible
	inv_sel = -1
	inv_msg.text = " "
	if inv_wrap.visible:
		_refresh_inv()


# ---------- Seviye Kartları (Evrim dahil!) ----------

func _update_cards() -> void:
	var cards: Array = player.get("cards")
	if cards == null or cards.is_empty():
		cards_box.hide()
		card_sig = ""
		return
	var sig := str(cards)
	if sig != card_sig:
		card_sig = sig
		_make_cards(cards)
	cards_box.show()


func _make_cards(cards: Array) -> void:
	for n in cards_row.get_children():
		n.queue_free()
	for i in cards.size():
		var d: Dictionary = cards[i]
		var r: Dictionary = rarity.get(d.get("rarity", ""), {})
		var c: Color = r.get("color", Color(0.8, 0.84, 0.94))
		var evo := str(d.get("type", "")) == "evo"
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(280, 218)
		card.pivot_offset = Vector2(140, 109)
		var sb: StyleBoxFlat = main._sb(Color(c.darkened(0.86), 0.95), 14, 14)
		sb.set_border_width_all(4 if evo else 2)
		sb.border_width_top = 7
		sb.border_color = GOLD if evo else c
		if evo:
			sb.shadow_color = Color(GOLD, 0.7)
			sb.shadow_size = 18
		card.add_theme_stylebox_override("panel", sb)
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_choose(i))
		card.mouse_entered.connect(func(): sb.bg_color = Color(c.darkened(0.70), 0.97))
		card.mouse_exited.connect(func(): sb.bg_color = Color(c.darkened(0.86), 0.95))
		cards_row.add_child(card)

		var v := VBoxContainer.new()
		v.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var head := HBoxContainer.new()
		head.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_child(head)
		if evo:
			_chip(head, "✦ EVRİM", GOLD, Color(0.12, 0.06, 0.0), 13)
		var ty := _t(head, "" if evo else TYPES.get(d.get("type", ""), "KART"), 12)
		ty.modulate.a = 0.8
		ty.size_flags_horizontal = SIZE_EXPAND_FILL
		_t(head, tr(str(r.get("name", ""))).to_upper(), 12, c)
		var title := _t(v, str(d.get("title", "?")), 22, c.lightened(0.3), true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var desc := _t(v, str(d.get("desc", "")), 14)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_vertical = SIZE_EXPAND_FILL
		desc.modulate.a = 0.9
		_t(v, "[ %d ]" % (i + 1), 20, Color.WHITE, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _choose(i: int) -> void:
	var cards: Array = player.get("cards")
	if player and player.has_method("choose_card") and cards != null and i < cards.size():
		player.choose_card(i)
		Sfx.play2d(Sfx.chime, -5.0)
