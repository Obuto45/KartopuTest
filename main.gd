extends Node3D
## Menü, HUD, test sahnesi ve tur yönetimi (tur kararlarını host verir).

const PlayerScript := preload("res://player.gd")
const ForestScript := preload("res://forest.gd")
const SPAWNS := [Vector3(-14, 1, -14), Vector3(14, 1, 14), Vector3(-14, 1, 14), Vector3(14, 1, -14)]

var ui: Control
var info: Label
var members: Label
var start_btn: Button
var friends_box: VBoxContainer
var invite_box: VBoxContainer
var dmg_rect: ColorRect
var hud: Control
var hp_lbl: Label
var score_lbl: Label
var center_lbl: Label
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
		"dash": KEY_SHIFT, "slot1": KEY_1, "slot2": KEY_2, "slot3": KEY_3, "slot4": KEY_4}
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

	var title := _lbl(v, "ASA SAVAŞI", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	var sub := _lbl(v, "Steam: " + (Net.my_name() if Net.steam_ok else "BAĞLI DEĞİL (Steam açık mı?)"), 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.text += "   •   sürüm " + Updater.version()
	invite_box = VBoxContainer.new() # gelen davetler burada çıkar
	v.add_child(invite_box)
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
	_full_label(28, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER).text = "+"
	hp_lbl = _full_label(28, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	score_lbl = _full_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	center_lbl = _full_label(52, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	spec_lbl = _full_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	spec_lbl.offset_top = 60
	_full_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM).text = \
		"WASD yürü | Boşluk zıpla (havada 2. zıplama) | Shift+WASD dash | 1-4 eşya | Sol tık kullan | ESC menü/ayarlar | F10 çık"
	# Alt envanter çubuğu (hotbar)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -195; bar.offset_right = 195
	bar.offset_top = -140; bar.offset_bottom = -50
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)
	for i in 4:
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
	hud.hide()
	_build_settings(layer, theme)


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
		lines.append(("★ " if id == 1 else "• ") + str(Net.names[id]))
	members.text = "Lobidekiler:\n" + "\n".join(lines) if Net.online() else ""
	start_btn.disabled = not (Net.online() and multiplayer.is_server())


func _process(_dt: float) -> void:
	if players == null:
		return
	var me = players.get_node_or_null(str(multiplayer.get_unique_id()))
	if me:
		hp_lbl.text = "Can: %d" % me.hp
		dmg_rect.color.a = me.flash * 1.2
		var sh := "AKTİF" if me.shield_on else ("%d sn" % ceili(me.shield_cd) if me.shield_cd > 0.0 else "HAZIR")
		var texts := ["1\nATEŞ ASASI", "2\nKALKAN\n" + sh,
			"3\nYILDIRIM\n" + _cd_text(me.lightning_cd), "4\nDUVAR\n" + _cd_text(me.wall_cd)]
		for i in 4:
			slots[i][0].border_color = Color(1, 0.85, 0.2) if me.slot == i + 1 else Color(0.5, 0.5, 0.5, 0.6)
			slots[i][1].text = texts[i]
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
		if settings_wrap.visible:
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
