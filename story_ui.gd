extends Control
## Açık Dünya Hikaye Arayüzü: görev takip kartı + yön pusulası, NPC etkileşim uyarısı,
## sinematik RPG diyalog kutusu, boss can barı, 5+Q cam envanter çubuğu ve hikaye zafer ekranı.

const Weapons := preload("res://weapons.gd")
const GOLD := Color(1.0, 0.82, 0.25)
const ORANGE := Color(1.0, 0.62, 0.18)
const GREY := Color(0.55, 0.57, 0.62)

var main: Node
var story: Node
var player: Node3D

var quest_title: Label
var quest_desc: Label
var quest_dist: Label
var prompt_pill: PanelContainer
var prompt_lbl: Label
var toast_card: PanelContainer
var toast_title: Label
var toast_sub: Label
var toast_tw: Tween

var dlg_wrap: PanelContainer
var dlg_name: Label
var dlg_role: Label
var dlg_body: Label
var dlg_btn: Button
var dlg_lines: Array = []
var dlg_idx := 0

var boss_box: VBoxContainer
var boss_fill: ColorRect
var boss_txt: Label

var cells := [] # 5 envanter + Q
var minimap: MinimapView
var win_wrap: ColorRect
var win_stats: Label
var dead_lbl: Label


## Canlı dairesel açık dünya radarı: oyuncu yönü, NPC'ler (yeşil), düşmanlar (kırmızı), sandıklar (camgöbeği) ve görev hedefi (altın).
class MinimapView extends Control:
	var story: Node
	var player: Node3D
	const RANGE := 68.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(c.x, c.y) - 3.0
		draw_circle(c, r, Color(0.04, 0.05, 0.09, 0.78))
		draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.84, 0.42, 0.38), 2.0, true)
		draw_arc(c, r * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.08), 1.0, true)
		draw_line(c + Vector2(-r + 6, 0), c + Vector2(r - 6, 0), Color(1, 1, 1, 0.06), 1.0)
		draw_line(c + Vector2(0, -r + 6), c + Vector2(0, r - 6), Color(1, 1, 1, 0.06), 1.0)
		if story == null or player == null or not is_instance_valid(story) or not is_instance_valid(player):
			return
		var pp := player.global_position
		var yaw := player.rotation.y
		# Yardımcı: dünya ofsetini oyuncu bakışına göre radar düzlemine çevirir (yukarı = oyuncunun önü)
		var to_map := func(wp: Vector3) -> Vector2:
			var dx := wp.x - pp.x
			var dz := wp.z - pp.z
			var rx := dx * cos(yaw) - dz * sin(yaw)
			var rz := dx * sin(yaw) + dz * cos(yaw)
			var v := Vector2(rx, rz) / RANGE * (r - 8.0)
			return v.limit_length(r - 7.0)
		# Düşmanlar (kırmızı)
		for e in story.elist:
			if is_instance_valid(e) and e.hp > 0:
				var pt: Vector2 = c + to_map.call(e.global_position)
				draw_circle(pt, 3.6 if e.type == "boss" else 2.6, Color(0.95, 0.22, 0.22, 0.95))
		# Açılmamış sandıklar (camgöbeği elmas)
		for ch in story._chests:
			if not ch.opened:
				var pt: Vector2 = c + to_map.call(ch.pos)
				draw_rect(Rect2(pt - Vector2(3, 3), Vector2(6, 6)), Color(0.35, 0.92, 1.0, 0.95))
		# NPC'ler (zümrüt yeşil)
		for id in story._npcs:
			var pt: Vector2 = c + to_map.call(story._npcs[id].pos)
			draw_circle(pt, 3.4, Color(0.32, 0.94, 0.52, 0.95))
		# Aktif görev hedefi (nabız atan altın halka)
		var tgt: Vector3 = story.objective_pos()
		if tgt != Vector3.ZERO and story.stage < 7:
			var pt: Vector2 = c + to_map.call(tgt)
			var pulse := 4.5 + 1.8 * absf(sin(Time.get_ticks_msec() * 0.006))
			draw_arc(pt, pulse, 0.0, TAU, 16, Color(1.0, 0.85, 0.25, 0.95), 2.0, true)
			draw_circle(pt, 2.5, Color(1.0, 0.94, 0.55))
		# Merkezde oyuncu yön oku
		var tri := PackedVector2Array([c + Vector2(0, -6), c + Vector2(-4.5, 5), c + Vector2(0, 2.5), c + Vector2(4.5, 5)])
		draw_colored_polygon(tri, Color(1.0, 0.95, 0.80))


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	theme = main.ui.theme
	_build_quest_card()
	_build_minimap()
	_build_boss_bar()
	_build_prompt()
	_build_toast()
	_build_dialog()
	_build_hotbar()
	_build_win()
	dead_lbl = _txt(self, "", 44, Color(1.0, 0.32, 0.28))
	dead_lbl.set_anchors_preset(PRESET_CENTER)
	dead_lbl.grow_horizontal = GROW_DIRECTION_BOTH
	dead_lbl.grow_vertical = GROW_DIRECTION_BOTH
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_lbl.hide()

	story = get_tree().get_first_node_in_group("story")
	if story:
		story.story_updated.connect(_refresh_quest)
		story.dialog_requested.connect(_open_dialog)
		story.toast_requested.connect(_show_toast)
		story.story_won.connect(_show_win)
		_refresh_quest()


func _txt(parent: Node, text: String, sz: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _glass(radius := 12, border := Color(1, 1, 1, 0.16)) -> StyleBoxFlat:
	var sb: StyleBoxFlat = main._sb(Color(0.05, 0.06, 0.10, 0.82), radius, 0)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	return sb


func _build_quest_card() -> void:
	var card := PanelContainer.new()
	card.position = Vector2(18, 94) # sol üst can barının hemen altında
	card.custom_minimum_size = Vector2(348, 0)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := _glass(12, Color(1.0, 0.82, 0.35, 0.30))
	sb.border_width_left = 4
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	quest_title = _txt(v, "", 13, GOLD)
	quest_desc = _txt(v, "", 15, Color(0.95, 0.96, 1.0))
	quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_dist = _txt(v, "", 13, Color(0.68, 0.88, 1.0))


func _build_minimap() -> void:
	minimap = MinimapView.new()
	minimap.custom_minimum_size = Vector2(148, 148)
	minimap.set_anchors_preset(PRESET_TOP_RIGHT)
	minimap.grow_horizontal = GROW_DIRECTION_BEGIN
	minimap.offset_top = 66
	minimap.offset_right = -20
	minimap.offset_left = -168
	minimap.offset_bottom = 214
	minimap.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(minimap)
	var leg := _txt(self, "● NPC   ● Düşman   ■ Sandık", 10, Color(0.84, 0.88, 0.95, 0.85))
	leg.set_anchors_preset(PRESET_TOP_RIGHT)
	leg.grow_horizontal = GROW_DIRECTION_BEGIN
	leg.offset_top = 216
	leg.offset_right = -18
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_boss_bar() -> void:
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(PRESET_CENTER_TOP)
	boss_box.grow_horizontal = GROW_DIRECTION_BOTH
	boss_box.offset_top = 18
	boss_box.mouse_filter = MOUSE_FILTER_IGNORE
	boss_box.add_theme_constant_override("separation", 4)
	boss_box.hide()
	add_child(boss_box)
	var t := _txt(boss_box, "♛  BOSS: ORMAN LORDU", 24, Color(0.86, 0.56, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(540, 24)
	bar.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _glass(8, Color(0.85, 0.52, 1.0, 0.45)))
	boss_box.add_child(bar)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.68, 0.22, 0.90)
	boss_fill.set_anchors_preset(PRESET_FULL_RECT)
	boss_fill.offset_left = 3; boss_fill.offset_top = 3; boss_fill.offset_bottom = -3
	boss_fill.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_child(boss_fill)
	boss_txt = _txt(bar, "", 14, Color.WHITE)
	boss_txt.set_anchors_preset(PRESET_FULL_RECT)
	boss_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_prompt() -> void:
	prompt_pill = PanelContainer.new()
	prompt_pill.set_anchors_preset(PRESET_CENTER_BOTTOM)
	prompt_pill.grow_horizontal = GROW_DIRECTION_BOTH
	prompt_pill.grow_vertical = GROW_DIRECTION_BEGIN
	prompt_pill.offset_bottom = -168
	prompt_pill.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := _glass(12, Color(1.0, 0.85, 0.35, 0.55))
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	prompt_pill.add_theme_stylebox_override("panel", sb)
	prompt_pill.hide()
	add_child(prompt_pill)
	prompt_lbl = _txt(prompt_pill, "", 17, Color(1.0, 0.95, 0.80))


func _build_toast() -> void:
	toast_card = PanelContainer.new()
	toast_card.set_anchors_preset(PRESET_CENTER_TOP)
	toast_card.grow_horizontal = GROW_DIRECTION_BOTH
	toast_card.offset_top = 74
	toast_card.mouse_filter = MOUSE_FILTER_IGNORE
	var sb := _glass(12, Color(1.0, 0.82, 0.32, 0.5))
	sb.content_margin_left = 24; sb.content_margin_right = 24
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	toast_card.add_theme_stylebox_override("panel", sb)
	toast_card.modulate.a = 0.0
	add_child(toast_card)
	var v := VBoxContainer.new()
	v.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	toast_card.add_child(v)
	toast_title = _txt(v, "", 20, GOLD)
	toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_sub = _txt(v, "", 15, Color(0.92, 0.95, 1.0))
	toast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_dialog() -> void:
	dlg_wrap = PanelContainer.new()
	dlg_wrap.set_anchors_preset(PRESET_CENTER_BOTTOM)
	dlg_wrap.grow_horizontal = GROW_DIRECTION_BOTH
	dlg_wrap.grow_vertical = GROW_DIRECTION_BEGIN
	dlg_wrap.offset_bottom = -160
	dlg_wrap.custom_minimum_size = Vector2(720, 0)
	var sb := _glass(14, Color(1.0, 0.78, 0.30, 0.55))
	sb.bg_color = Color(0.04, 0.05, 0.09, 0.95)
	sb.content_margin_left = 24; sb.content_margin_right = 24
	sb.content_margin_top = 16; sb.content_margin_bottom = 16
	dlg_wrap.add_theme_stylebox_override("panel", sb)
	dlg_wrap.hide()
	add_child(dlg_wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dlg_wrap.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	dlg_name = _txt(head, "", 22, GOLD)
	dlg_role = _txt(head, "", 14, Color(0.68, 0.80, 0.96))
	dlg_role.size_flags_vertical = SIZE_SHRINK_END
	dlg_body = _txt(v, "", 18, Color(0.95, 0.96, 1.0))
	dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_body.custom_minimum_size = Vector2(670, 56)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	dlg_btn = main._btn(foot, "Devam Et  [E / Boşluk]", _next_dialog)
	dlg_btn.custom_minimum_size = Vector2(210, 36)


func _build_hotbar() -> void:
	var help_pill := PanelContainer.new()
	help_pill.mouse_filter = MOUSE_FILTER_IGNORE
	help_pill.set_anchors_preset(PRESET_CENTER_BOTTOM)
	help_pill.grow_horizontal = GROW_DIRECTION_BOTH
	help_pill.grow_vertical = GROW_DIRECTION_BEGIN
	help_pill.offset_bottom = -8
	var hsb := _glass(10, Color(1, 1, 1, 0.10))
	hsb.bg_color = Color(0.04, 0.05, 0.09, 0.62)
	hsb.content_margin_left = 16; hsb.content_margin_right = 16
	hsb.content_margin_top = 4; hsb.content_margin_bottom = 4
	help_pill.add_theme_stylebox_override("panel", hsb)
	add_child(help_pill)
	_txt(help_pill, "WASD Yürü  •  Boşluk Zıpla  •  Shift Atıl  •  E Konuş  •  1-5 Silah/Eşya  •  Q Yetenek  •  ESC Menü", 12, Color(0.88, 0.91, 0.96, 0.9))

	var dock := PanelContainer.new()
	dock.mouse_filter = MOUSE_FILTER_IGNORE
	dock.set_anchors_preset(PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = GROW_DIRECTION_BOTH
	dock.grow_vertical = GROW_DIRECTION_BEGIN
	dock.offset_bottom = -42
	var dsb := _glass(14, Color(1.0, 0.86, 0.55, 0.22))
	dsb.bg_color = Color(0.04, 0.05, 0.09, 0.74)
	dsb.content_margin_left = 10; dsb.content_margin_right = 10
	dsb.content_margin_top = 8; dsb.content_margin_bottom = 8
	dock.add_theme_stylebox_override("panel", dsb)
	add_child(dock)
	var bar := HBoxContainer.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 8)
	dock.add_child(bar)

	var keys_txt := ["1", "2", "3", "4", "5", "Q"]
	for i in 6:
		if i == 5:
			var sep := ColorRect.new()
			sep.custom_minimum_size = Vector2(2, 66)
			sep.size_flags_vertical = SIZE_SHRINK_CENTER
			sep.color = Color(1, 1, 1, 0.16)
			sep.mouse_filter = MOUSE_FILTER_IGNORE
			bar.add_child(sep)
		var is_q := i == 5
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(130 if is_q else 96, 86)
		cell.clip_contents = true
		cell.mouse_filter = MOUSE_FILTER_IGNORE
		var sb: StyleBoxFlat = main._sb(Color(0.08, 0.10, 0.16, 0.86), 10, 0)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.50, 0.55, 0.65, 0.30)
		cell.add_theme_stylebox_override("panel", sb)
		var inner := Control.new()
		inner.set_anchors_preset(PRESET_FULL_RECT)
		inner.mouse_filter = MOUSE_FILTER_IGNORE
		cell.add_child(inner)
		var kbox := PanelContainer.new()
		kbox.position = Vector2(6, 5)
		kbox.mouse_filter = MOUSE_FILTER_IGNORE
		var ksb: StyleBoxFlat = main._sb(Color(0.03, 0.04, 0.07, 0.88), 5, 0)
		ksb.content_margin_left = 5; ksb.content_margin_right = 5
		ksb.set_border_width_all(1)
		ksb.border_color = Color(1, 1, 1, 0.22)
		kbox.add_theme_stylebox_override("panel", ksb)
		_txt(kbox, keys_txt[i], 11, Color(1.0, 0.90, 0.65) if is_q else Color(0.9, 0.94, 1.0)).add_theme_constant_override("outline_size", 0)
		inner.add_child(kbox)
		var icon := TextureRect.new()
		icon.set_anchors_preset(PRESET_FULL_RECT)
		icon.offset_left = 10; icon.offset_right = -10
		icon.offset_top = 16; icon.offset_bottom = -24
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		var name_lbl := _txt(inner, "", 12, Color(0.95, 0.96, 1.0))
		name_lbl.set_anchors_preset(PRESET_FULL_RECT)
		name_lbl.offset_left = 4; name_lbl.offset_right = -4
		name_lbl.offset_top = 24 if is_q else 56
		name_lbl.offset_bottom = -22 if is_q else -6
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sub_lbl := _txt(inner, "", 11, GOLD)
		sub_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
		sub_lbl.offset_left = 5; sub_lbl.offset_right = -5
		sub_lbl.offset_top = -22; sub_lbl.offset_bottom = -5
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if not is_q else HORIZONTAL_ALIGNMENT_CENTER
		bar.add_child(cell)
		cells.append({"sb": sb, "icon": icon, "name": name_lbl, "sub": sub_lbl, "ksb": ksb})


func _build_win() -> void:
	win_wrap = ColorRect.new()
	win_wrap.set_anchors_preset(PRESET_FULL_RECT)
	win_wrap.color = Color(0.02, 0.03, 0.06, 0.72)
	win_wrap.hide()
	add_child(win_wrap)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(PRESET_FULL_RECT)
	win_wrap.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sb := _glass(16, Color(1.0, 0.82, 0.28, 0.65))
	sb.bg_color = Color(0.05, 0.06, 0.11, 0.96)
	sb.content_margin_left = 28; sb.content_margin_right = 28
	sb.content_margin_top = 24; sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := _txt(v, "★  ORMAN KURTULDU!  ★", 34, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _txt(v, "Orman Lordu'nu devirdin ve kadim ormana yeniden barış getirdin.", 17, Color(0.9, 0.94, 1.0))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_stats = _txt(v, "", 16, Color(0.7, 0.9, 1.0))
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	v.add_child(btns)
	main._btn(btns, "Keşfetmeye Devam Et", func() -> void:
		win_wrap.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	main._btn(btns, "Ana Menüye Dön", func() -> void:
		Net.leave())


# ---------- Akış ve Güncelleme ----------

func want_mouse() -> bool:
	return dlg_wrap.visible or win_wrap.visible


func _refresh_quest() -> void:
	if story == null or not is_instance_valid(story):
		return
	quest_title.text = story.chapter_title()
	quest_desc.text = story.objective_text()


func _show_toast(title: String, sub: String, col: Color) -> void:
	toast_title.text = title
	toast_title.add_theme_color_override("font_color", col)
	toast_sub.text = sub
	if toast_tw:
		toast_tw.kill()
	toast_card.modulate.a = 0.0
	toast_tw = create_tween()
	toast_tw.tween_property(toast_card, "modulate:a", 1.0, 0.25)
	toast_tw.tween_interval(3.4)
	toast_tw.tween_property(toast_card, "modulate:a", 0.0, 0.6)


func _open_dialog(speaker: String, role: String, lines: Array) -> void:
	dlg_name.text = speaker
	dlg_role.text = "•  " + role
	dlg_lines = lines
	dlg_idx = 0
	dlg_body.text = str(lines[0]) if not lines.is_empty() else ""
	dlg_btn.text = "Devam Et  [E]" if lines.size() > 1 else "Tamam  [E]"
	dlg_wrap.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _next_dialog() -> void:
	dlg_idx += 1
	if dlg_idx < dlg_lines.size():
		dlg_body.text = str(dlg_lines[dlg_idx])
		dlg_btn.text = "Devam Et  [E]" if dlg_idx < dlg_lines.size() - 1 else "Tamam  [E]"
	else:
		dlg_wrap.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if story and is_instance_valid(story):
			story.finish_dialog()


func _show_win() -> void:
	var mins := int(story.elapsed_t) / 60
	var secs := int(story.elapsed_t) % 60
	win_stats.text = "Yenilen Yaratıklar: %d   •   Süre: %02d:%02d" % [story.kills, mins, secs]
	win_wrap.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(e: InputEvent) -> void:
	if main.settings_wrap.visible or win_wrap.visible:
		return
	if dlg_wrap.visible:
		if e.is_action_pressed("interact") or e.is_action_pressed("jump") or e.is_action_pressed("ui_accept"):
			_next_dialog()
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("interact") and player and is_instance_valid(player) and player.hp > 0:
		var npc: Dictionary = story.nearby_npc(player.global_position)
		if not npc.is_empty():
			story.interact_npc(npc.id)
			get_viewport().set_input_as_handled()
			return
		var ch: Dictionary = story.nearby_chest(player.global_position)
		if not ch.is_empty():
			story.open_chest(ch.id)
			get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if story == null or not is_instance_valid(story):
		return
	if (player == null or not is_instance_valid(player)) and main.players:
		player = main.players.get_node_or_null(str(multiplayer.get_unique_id()))
	if player == null or not is_instance_valid(player):
		return

	# Fare yakalama yönetimi
	if not main.settings_wrap.visible:
		var m := Input.MOUSE_MODE_VISIBLE if want_mouse() else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != m:
			Input.mouse_mode = m

	# Ölüm yazısı
	dead_lbl.visible = player.hp <= 0
	if dead_lbl.visible:
		dead_lbl.text = "YERE DÜŞTÜN\nKöy Kampı'nda uyanıyorsun: %d sn" % maxi(ceili(player.respawn_t), 0)

	# Görev hedefi yön ve mesafe
	var tgt: Vector3 = story.objective_pos()
	if tgt != Vector3.ZERO and story.stage < 7:
		var diff := tgt - player.global_position
		diff.y = 0.0
		var dist := roundi(diff.length())
		var fwd := -player.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := player.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var dir_n := diff.normalized() if dist > 0 else fwd
		var fdot := fwd.dot(dir_n)
		var rdot := right.dot(dir_n)
		var arrow := "↑ İleri" if fdot > 0.6 else ("↓ Arka" if fdot < -0.6 else ("→ Sağ" if rdot > 0.0 else "← Sol"))
		quest_dist.text = "Hedef: %d m  (%s)" % [dist, arrow]
	else:
		quest_dist.text = "★ Tüm görevler tamamlandı"

	# NPC / Sandık etkileşim uyarısı
	if not dlg_wrap.visible and not win_wrap.visible and player.hp > 0:
		var npc: Dictionary = story.nearby_npc(player.global_position)
		var ch: Dictionary = story.nearby_chest(player.global_position) if npc.is_empty() else {}
		prompt_pill.visible = not npc.is_empty() or not ch.is_empty()
		if not npc.is_empty():
			prompt_lbl.text = "[E]  Konuş  —  %s (%s)" % [npc.name, npc.role]
		elif not ch.is_empty():
			prompt_lbl.text = "[E]  Sandığı Aç  —  %s" % ch.title
	else:
		prompt_pill.hide()

	if minimap:
		minimap.story = story
		minimap.player = player
		minimap.queue_redraw()

	# Boss barı
	var boss = story._by_id.get(story.boss_eid) if story.boss_eid != 0 else null
	boss_box.visible = boss != null and is_instance_valid(boss) and boss.hp > 0
	if boss_box.visible:
		boss_fill.anchor_right = clampf(float(boss.hp) / maxi(boss.max_hp, 1), 0.0, 1.0)
		boss_txt.text = "%d / %d" % [boss.hp, boss.max_hp]

	_update_hotbar()


func _update_hotbar() -> void:
	var inv: Array = player.inv
	var sel: int = player.slot
	for i in 5:
		var c: Dictionary = cells[i]
		var d: Dictionary = inv[i] if i < inv.size() and inv[i] is Dictionary else {}
		var active := (sel == i + 1)
		c.sb.border_color = GOLD if active else Color(0.50, 0.55, 0.65, 0.30)
		c.sb.bg_color = Color(0.22, 0.17, 0.06, 0.90) if active else Color(0.08, 0.10, 0.16, 0.84)
		c.ksb.border_color = GOLD if active else Color(1, 1, 1, 0.20)
		if d.is_empty():
			c.icon.texture = null
			c.name.text = "—"
			c.name.modulate.a = 0.35
			c.sub.text = ""
			continue
		c.name.modulate.a = 1.0
		var id: String = str(d.get("id", ""))
		var kind: String = str(d.get("kind", ""))
		c.icon.texture = main.weapon_icon(id) if kind == "weapon" else null
		if kind == "weapon":
			var w := Weapons.find(id)
			c.name.text = tr(str(w.get("name", id))).to_upper()
			var mag: int = w.get("mag", 0)
			c.sub.text = "%d / ∞" % int(d.get("ammo", mag)) if mag > 0 else ""
		elif kind == "equip":
			var eq: Dictionary = Weapons.EQUIPS.get(id, {})
			c.name.text = tr(str(eq.get("name", id))).to_upper()
			c.sub.text = tr("HAZIR") if player.shield_cd <= 0.0 else ("%d sn" % ceili(player.shield_cd))
		else:
			var it: Dictionary = Weapons.ITEMS.get(id, {})
			c.name.text = tr(str(it.get("name", id))).to_upper()
			c.sub.text = "x%d" % int(d.get("count", 1))
	# Q yeteneği
	var qc: Dictionary = cells[5]
	var ready_q: bool = player.skill_cd <= 0.0
	qc.sb.border_color = player.ch.color.lightened(0.15) if ready_q else Color(0.45, 0.48, 0.56, 0.35)
	qc.sb.bg_color = player.ch.color.darkened(0.72) if ready_q else Color(0.08, 0.09, 0.14, 0.78)
	qc.sb.bg_color.a = 0.88 if ready_q else 0.76
	qc.name.text = tr(player.ch.skill_name)
	qc.sub.text = tr("HAZIR") if ready_q else ("%d sn" % ceili(player.skill_cd))
	qc.sub.add_theme_color_override("font_color", Color(0.38, 0.95, 0.52) if ready_q else Color(1.0, 0.72, 0.32))
