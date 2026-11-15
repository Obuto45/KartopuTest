extends Node3D
## Menü, HUD, test sahnesi ve tur yönetimi (tur kararlarını host verir).

const PlayerScript := preload("res://player.gd")
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
var slots := [] # [[StyleBoxFlat, Label], ...]
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
	multiplayer.peer_disconnected.connect(_on_peer_left)
	_refresh()


func _setup_input() -> void:
	var keys := {"fwd": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "slot1": KEY_1, "slot2": KEY_2}
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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	ui = CenterContainer.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var panel := PanelContainer.new()
	ui.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(440, 0)
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_lbl(v, "ROKET SAVAŞI (test)", 30)
	_lbl(v, "Steam: " + (Net.my_name() if Net.steam_ok else "BAĞLI DEĞİL (Steam açık mı?)"), 16)
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
	start_btn = _btn(v, "Oyunu Başlat (host)", _on_start)
	_btn(v, "Lobiden Çık", Net.leave)
	_lbl(v, "— Tek PC testi —", 14)
	_btn(v, "Yerel Host", Net.host_local)
	_btn(v, "Yerel Katıl (127.0.0.1)", Net.join_local)
	members = _lbl(v, "", 16)
	info = _lbl(v, "Arkadaşın daveti kabul edince lobiye girer. Sonra 'Oyunu Başlat'.", 14)
	_btn(v, "Çıkış", get_tree().quit)

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
	_full_label(14, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM).text = \
		"WASD yürü | Boşluk zıpla (havada 2. zıplama) | Shift+WASD dash | 1 roketatar | 2 kalkan | Sol tık kullan | ESC fare | F10 çık"
	# Alt envanter çubuğu (hotbar)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -95; bar.offset_right = 95
	bar.offset_top = -140; bar.offset_bottom = -50
	bar.add_theme_constant_override("separation", 10)
	hud.add_child(bar)
	for i in 2:
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
		var texts := ["1\nROKETATAR", "2\nKALKAN\n" + sh]
		for i in 2:
			slots[i][0].border_color = Color(1, 0.85, 0.2) if me.slot == i + 1 else Color(0.5, 0.5, 0.5, 0.6)
			slots[i][1].text = texts[i]
	var s := PackedStringArray()
	for p in players.get_children():
		s.append("%s  %d" % [Net.display_name(p.name.to_int()), p.hp])
	score_lbl.text = "\n".join(s)


func _unhandled_input(e: InputEvent) -> void:
	if world == null:
		return
	if e.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
	ui.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


# ---------- Test sahnesi ----------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(pos: Vector3, size: Vector3, c: Color, rot_y := 0.0) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	world.add_child(b)


func _tree(pos: Vector3, s: float) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	b.scale = Vector3.ONE * s
	var parts := [ # [üst yarıçap, alt yarıçap, yükseklik, y, renk]
		[0.25, 0.3, 2.0, 1.0, Color(0.4, 0.25, 0.12)],
		[0.0, 1.4, 2.6, 2.9, Color(0.1, 0.4, 0.18)],
		[0.0, 1.0, 2.0, 4.1, Color(0.85, 0.92, 0.95)], # karlı tepe
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = p[0]; cm.bottom_radius = p[1]; cm.height = p[2]
		mi.mesh = cm
		mi.position.y = p[3]
		mi.material_override = _mat(p[4])
		b.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.35; sh.height = 5.0
	cs.shape = sh
	cs.position.y = 2.5
	b.add_child(cs)
	world.add_child(b)


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)

	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60), Color(0.95, 0.97, 1.0)) # karlı zemin
	for w in [[Vector3(0, 1.5, -30), Vector3(60, 3, 1)], [Vector3(0, 1.5, 30), Vector3(60, 3, 1)],
			[Vector3(-30, 1.5, 0), Vector3(1, 3, 60)], [Vector3(30, 1.5, 0), Vector3(1, 3, 60)]]:
		_box(w[0], w[1], Color(0.7, 0.75, 0.8))

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 # herkeste aynı harita
	var placed := 0
	while placed < 45:
		var pos := Vector3(rng.randf_range(-27, 27), 0, rng.randf_range(-27, 27))
		var near_spawn := SPAWNS.any(func(sp): return Vector2(sp.x - pos.x, sp.z - pos.z).length() < 4.0)
		var kind := rng.randf() # her döngüde aynı sırayla rng çağrısı -> deterministik
		var size := rng.randf_range(0.8, 2.0)
		var rot := rng.randf() * TAU
		if near_spawn:
			continue
		if placed < 22:
			_tree(pos, 0.8 + kind * 0.6)
		else:
			_box(pos + Vector3(0, size * 0.5, 0), Vector3.ONE * size, Color(0.55, 0.38, 0.2).lerp(Color(0.7, 0.55, 0.3), kind), rot)
		placed += 1

	players = Node3D.new()
	players.name = "Players"
	world.add_child(players)
