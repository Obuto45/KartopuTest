extends Node
## Tower Defense mod denetçisi. world'ün "TD" adlı çocuğu, grup "td" (yoksa Arena: hiçbir TD kodu çalışmaz).
## Host (peer 1) otoriter: dalga, yaratık, kule canı, yapı, para, XP. İstemci isteği rpc_id(1) ile yollar;
## host tüm durumu tek _state rpc'siyle yayar, sinyaller her makinede bu rpc'deki farktan üretilir.
## Akış: mola -> savaş -> mola ... -> dalga 10 bitince "won"; kule canı 0 olunca "lost".
## Dalga / doğma düzeni fikri: quiver-dev/tower-defense-godot4 (MIT) okunarak; kod kopyalanmadı.
## NOT: sözleşmedeki `ready` sözlüğü Node.ready sinyaliyle çakıştığı için adı `ready_votes` (bkz. is_ready).

signal changed
signal wave_started(wave: int)
signal leveled(level: int)
signal run_ended(won: bool)
signal summary_ready(d: Dictionary) # maç sonu: {"won", "wave", "difficulty", "endless", "players": {peer: pstats}, "mvp": peer}

const Balance := preload("res://balance.gd")
const EnemyScript := preload("res://enemy.gd")
const BuildScript := preload("res://build.gd")
const TowerScript := preload("res://tower.gd")
const Fx := preload("res://explosion.gd")
const Profile := preload("res://profile.gd")
const HALF := 30.0 # forest.gd HALF
const SYNC_DT := 1.0 / 12.0 # yaratık konum yayını
const STATE_DT := 0.1 # durum yayını en sık bu aralıkla (kule dövülürken kare başı rpc gitmesin)
const TELE := 1.5 # doğma uyarısı (yerde kırmızı halka) ile ilk yaratık arası
const SLAM_EVERY := 8.0 # Kara Şövalye yer darbesi aralığı
const SLAM_T := 1.2 # darbe uyarısı süresi
const SLAM_R := 5.0
const SLAM_DMG := 30
const DROP_LIFE := 15.0 # yerdeki eşya kaç sn kalır
const DROP_R := 1.5 # alma uzaklığı
const CHEST_MONEY := 40
const CHEST_XP := 40

var wave := 0
var state := "break" # "break" | "fight" | "won" | "lost"
var time_left := 0.0
var money := 0
var level := 1
var xp := 0
var xp_next := 0
var tower_hp := 0
var tower_max := 0
var enemies_left := 0
var kills := 0
var ready_votes := {} # peer -> true
var opts := {"difficulty": "normal", "endless": false} # main.start_td verir (_ready'den önce)
var difficulty := "normal" # Balance.DIFFS anahtarı
var mods: Array = [] # bu dalganın / sıradaki dalganın modifikatörleri (Balance.roll_mods), molada ilan edilir
var boss_eid := 0 # yaşayan boss'un yaratık no'su; 0 = yok (arayüz boss barı)
var endless := false # 10. dalgadan sonra devam
var pstats := {} # host: peer -> {"dmg": int, "kills": int, "crits": int, "builds": int, "deaths": int}

var tower: Node3D
var enemies: Node3D
var builds: Node3D
var elist: Array = [] # canlı yaratıklar (yaratık / yapı döngüleri her seferinde dizi üretmesin)
var plist: Array = [] # oyuncular; host ~4 Hz yeniler
var _by_id := {} # yaratık no -> düğüm
var _seen_state := "break" # sinyaller için: bu makinede en son gösterilen durum
var _seen_level := 1
var _seen_hp := 0
# Yalnızca host:
var _queue := [] # [zaman, tür ("" = uyarı halkası), konum], zamana göre sıralı
var _wd := {} # geçerli Balance.wave()
var _wave_t := 0.0
var _to_spawn := 0
var _n := 1 # dalga başındaki oyuncu sayısı
var _eid := 0
var _bid := 0
var _dirty := true
var _state_t := 0.0
var _sync_t := 0.0
var _plist_t := 0.0
var _ids := PackedInt32Array()
var _pos := PackedVector3Array()
var _yaw := PackedByteArray()
var _mod_seed := 0 # maç başında host'ta randi(); sıradaki dalganın modları bundan
var _boss: Node3D # host: yaşayan boss
var _slam_cd := SLAM_EVERY
var _summoned := false
var _drops := {} # host: eşya no -> [konum, id, yaş]
var _dnodes := {} # her makine: eşya no -> görsel düğüm
var _did := 0
var _alive := {} # host: peer -> canlı mıydı (ölüm sayacı için)


func _ready() -> void:
	add_to_group("td")
	var world := get_parent()
	tower = TowerScript.new()
	tower.name = "Tower"
	enemies = Node3D.new()
	enemies.name = "Enemies"
	builds = Node3D.new()
	builds.name = "Builds"
	for n in [tower, enemies, builds]:
		world.add_child(n)
	# Başlangıç değerleri her makinede aynı: arayüz ilk _state gelmeden de doğru göstersin.
	difficulty = str(opts.get("difficulty", "normal"))
	endless = bool(opts.get("endless", false))
	_n = _count_players()
	tower_max = Balance.tower_hp(_n)
	money = Balance.START_MONEY * _n
	time_left = Balance.BREAK_TIME
	if multiplayer.is_server(): # kalıcı yükseltmeler ve ilk maç rehberi: yalnız host'un profili (değerler _state ile yayılır)
		tower_max = roundi(Balance.tower_hp(_n) * Profile.tower_hp_mult())
		money += Profile.start_money_bonus()
		if not Profile.tutorial_done():
			time_left = 90.0 # ilk mola rehber bitene dek (en çok 90 sn); herkes hazır olunca yine 3 sn'ye iner
	tower_hp = tower_max
	_seen_hp = tower_hp
	xp_next = Balance.xp_for(1, _n)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	if multiplayer.is_server():
		_mod_seed = randi()
		mods = Balance.roll_mods(1, difficulty, _mod_seed)


func is_ready(peer: int) -> bool:
	return ready_votes.has(peer)


func _players() -> Node:
	return get_parent().get_node_or_null("Players")


func _count_players() -> int:
	var p := _players()
	return clampi(p.get_child_count() if p else 1, 1, 4)


func _local_player() -> Node:
	var p := _players()
	return p.get_node_or_null(str(multiplayer.get_unique_id())) if p else null


## rpc'yi gönderen; yerel çağrıda kendi kimliğim.
func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


## Oyuncunun sahibi olan makinede p.method(args) çalıştırır (yerelse doğrudan). Yöntem yoksa false.
func _to_owner(p: Node, method: String, args: Array) -> bool:
	if not is_instance_valid(p) or not p.has_method(method):
		return false
	var id := p.get_multiplayer_authority()
	if id == multiplayer.get_unique_id():
		p.callv(method, args)
	elif id in multiplayer.get_peers():
		p.callv("rpc_id", [id, method] + args)
	return true


func _physics_process(dt: float) -> void:
	if state == "break":
		time_left = maxf(time_left - dt, 0.0)
	if not multiplayer.is_server():
		return
	_plist_t -= dt
	if _plist_t <= 0.0:
		_plist_t = 0.25
		var p := _players()
		plist = p.get_children() if p else []
		_track_deaths()
	_drops_tick(dt)
	if state == "break":
		if time_left > 3.0 and _all_ready(): # herkes hazır: kısa geri sayım
			time_left = 3.0
			_dirty = true
		if time_left <= 0.0:
			_start_wave()
	elif state == "fight":
		_wave_t += dt
		while not _queue.is_empty() and _queue[0][0] <= _wave_t and elist.size() < Balance.MAX_ALIVE:
			var q: Array = _queue.pop_front()
			if q[1] == "":
				_tele.rpc(q[2], 3.2, TELE)
			else:
				_spawn_now(q[1], q[2], q.size() > 3 and q[3])
		_boss_tick(dt)
		if _queue.is_empty() and elist.is_empty():
			_end_wave()
		_sync_t -= dt
		if _sync_t <= 0.0:
			_sync_t = SYNC_DT
			_send_sync()
	_state_t -= dt
	if _dirty and _state_t <= 0.0:
		_dirty = false
		_state_t = STATE_DT
		enemies_left = _to_spawn + elist.size()
		# Dizi yalnız SONA eklenerek büyür (eski indeksler sabit): 11 difficulty, 12 mods, 13 boss_eid, 14 endless, 15 tower_max
		_state.rpc([wave, state, time_left, money, level, xp, xp_next, tower_hp, enemies_left, kills, ready_votes,
			difficulty, mods, boss_eid, endless, tower_max])


# ---------- Durum yayını (her makinede) ----------

@rpc("authority", "call_local", "reliable")
func _state(a: Array) -> void:
	wave = a[0]; state = a[1]; time_left = a[2]; money = a[3]; level = a[4]; xp = a[5]; xp_next = a[6]
	tower_hp = a[7]; enemies_left = a[8]; kills = a[9]; ready_votes = a[10]
	if a.size() > 14:
		difficulty = a[11]; mods = a[12]; boss_eid = a[13]; endless = a[14]
	if a.size() > 15:
		tower_max = a[15]
	if tower_hp != _seen_hp:
		tower.set_hp(float(tower_hp) / tower_max, tower_hp < _seen_hp)
		_seen_hp = tower_hp
	if state != _seen_state:
		_seen_state = state
		if state == "fight":
			Sfx.play2d(Sfx.thunder, -8.0)
			wave_started.emit(wave)
		elif state == "won" or state == "lost":
			if state == "lost":
				tower.collapse()
			run_ended.emit(state == "won")
	if level > _seen_level:
		_seen_level = level
		leveled.emit(level)
	changed.emit()


# ---------- Maç sonu özeti ve düşen eşyalar (sözleşme; içleri özellik ajanlarınca doldurulur) ----------

## Host maç bitince çağırır; her makinede summary_ready yayınlanır.
@rpc("authority", "call_local", "reliable")
func _summary(d: Dictionary) -> void:
	summary_ready.emit(d)


## Host: yere eşya bırakır (item_id: "potion" | "bomb" | "chest"); herkeste görünür, DROP_LIFE sn durur.
func drop(pos: Vector3, item_id: String) -> void:
	_did += 1
	_drops[_did] = [pos, item_id, 0.0]
	_drop_new.rpc(_did, pos, item_id)


@rpc("authority", "call_local", "reliable")
func _drop_new(n: int, pos: Vector3, id: String) -> void:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	var c := Color(1.0, 0.8, 0.2) if id == "chest" else (Color(0.2, 0.9, 0.4) if id == "potion" else Color(0.9, 0.2, 0.2))
	if id == "potion":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.12
		cm.bottom_radius = 0.2
		cm.height = 0.45
		mi.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * (0.55 if id == "chest" else 0.4)
		mi.mesh = bm
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	mi.position = pos + Vector3.UP * 0.5
	get_parent().add_child(mi)
	mi.create_tween().set_loops().tween_property(mi, "rotation:y", TAU, 2.0).as_relative()
	_dnodes[n] = mi


@rpc("authority", "call_local", "reliable")
func _drop_gone(n: int) -> void:
	if _dnodes.has(n):
		_dnodes[n].queue_free()
		_dnodes.erase(n)


## Host: süresi dolanı sil, 1,5 m'ye giren ilk canlı oyuncuya ver.
func _drops_tick(dt: float) -> void:
	for n in _drops.keys():
		var d: Array = _drops[n]
		d[2] += dt
		if d[2] >= DROP_LIFE:
			_drops.erase(n)
			_drop_gone.rpc(n)
			continue
		for p in plist:
			if is_instance_valid(p) and p.hp > 0 and Vector2(p.global_position.x - d[0].x, p.global_position.z - d[0].z).length() < DROP_R:
				_take(n, p)
				break


## Eşyayı p'ye verir; zaten alınmışsa false (iki oyuncu aynı anda alırsa bir kez).
func _take(n: int, p: Node) -> bool:
	if not _drops.has(n):
		return false
	var id: String = _drops[n][1]
	_drops.erase(n)
	_drop_gone.rpc(n)
	if id == "chest":
		# shortcut: "chest" kartı player.gd gerektirir; şimdilik para + XP verir. Kart açılınca burası değişir.
		money += CHEST_MONEY
		_add_xp(CHEST_XP)
		_dirty = true
	else:
		_to_owner(p, "add_item", [{"kind": "item", "id": id}])
	return true


func _add_xp(n: int) -> void:
	xp += n
	while xp >= xp_next: # taşan XP sonraki seviyeye kalır
		xp -= xp_next
		level += 1
		xp_next = Balance.xp_for(level, _n)
		for p in plist:
			_to_owner(p, "level_up", [])


## Host: istatistik sayacı (peer -> pstats).
func _stat(peer: int, key: String, n := 1) -> void:
	if peer <= 0:
		return
	if not pstats.has(peer):
		pstats[peer] = {"dmg": 0, "kills": 0, "crits": 0, "builds": 0, "deaths": 0}
	pstats[peer][key] += n


## Host: oyuncu canlıdan ölüye geçince deaths++.
func _track_deaths() -> void:
	for p in plist:
		if is_instance_valid(p):
			var peer: int = p.get_multiplayer_authority()
			var a: bool = p.hp > 0
			if _alive.get(peer, true) and not a:
				_stat(peer, "deaths")
			_alive[peer] = a


## Host: maç bitti; özeti herkese yayar. MVP = dmg + 50 x yapı - 100 x ölüm.
func _finish(won: bool) -> void:
	for p in plist:
		if is_instance_valid(p):
			_stat(p.get_multiplayer_authority(), "dmg", 0) # hiç vurmayan da listede olsun
	var mvp := 0
	var best := -INF
	for peer in pstats:
		var st: Dictionary = pstats[peer]
		var sc: float = st.dmg + 50 * st.builds - 100 * st.deaths
		if sc > best:
			best = sc
			mvp = peer
	_summary.rpc({"won": won, "wave": wave, "difficulty": difficulty, "endless": endless, "players": pstats, "mvp": mvp})


# ---------- Dalga (host) ----------

func _all_ready() -> bool:
	if plist.is_empty():
		return false
	for p in plist:
		if is_instance_valid(p) and not ready_votes.has(p.get_multiplayer_authority()):
			return false
	return true


## Gruplar BATCH'lik kümelere bölünür, karıştırılır, SPAWN_SPAN süresine yayılır. İlk dalgalar az yönden
## gelir (savunma tek tarafa kurulabilsin), dalga ilerledikçe 8 noktanın hepsi açılır.
func _start_wave() -> void:
	wave += 1
	_n = _count_players()
	_wd = Balance.wave(wave, _n, difficulty, mods)
	var batches := []
	for g in _wd.groups:
		var left: int = g.count
		while left > 0:
			batches.append([g.type, mini(left, Balance.BATCH), _wd.elite]) # 3.: kümede 1 elit
			left -= Balance.BATCH
	batches.shuffle()
	if _wd.boss != "": # boss dalganın ortasında
		batches.insert(batches.size() / 2, [_wd.boss, 1, false])
	var pts := Balance.SPAWN_POINTS.size()
	var first := randi() % pts
	var open := mini(pts, 2 + wave)
	var gap := minf(8.0, Balance.SPAWN_SPAN / batches.size()) # az kümeli ilk dalgalar da yayılsın (boş geçmesin)
	_queue.clear()
	_to_spawn = 0
	var t := 1.0
	for b in batches:
		var sp: Vector3 = Balance.SPAWN_POINTS[(first + randi() % open) % pts]
		_queue.append([t, "", sp])
		for i in b[1]:
			_queue.append([t + TELE + i * 0.45, b[0], sp + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), b[2] and i == 0])
		_to_spawn += b[1]
		t += gap
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_wave_t = 0.0
	ready_votes = {}
	state = "fight"
	_dirty = true
	_state_t = 0.0


func _end_wave() -> void:
	ready_votes = {}
	if wave >= Balance.WAVE_COUNT and not endless:
		state = "won"
		_finish(true)
	else:
		state = "break"
		time_left = Balance.BREAK_TIME
		money += roundi(Balance.wave_bonus(wave, _n) * Balance.DIFFS[difficulty].money)
		mods = Balance.roll_mods(wave + 1, difficulty, _mod_seed) # molada ilan edilir
		tower_hp = mini(tower_max, tower_hp + roundi(tower_max * Balance.TOWER_REPAIR))
	_dirty = true
	_state_t = 0.0


func _spawn_now(type: String, pos: Vector3, elite := false) -> void:
	var e: Dictionary = Balance.ENEMIES[type]
	var space := tower.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = 1
	for i in 6: # ağacın / kayanın içinde doğmasın
		q.position = pos + Vector3.UP
		if space.intersect_point(q, 1).is_empty():
			break
		pos += Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	_eid += 1
	_to_spawn -= 1
	var x := {"spd": Balance.enemy_speed(type, _wd) / e.speed, "armor": _wd.get("armor_add", 0), "elite": elite,
		"money": maxi(roundi(e.money * _wd.get("money_mult", 1.0) * Balance.DIFFS[difficulty].money), 1)}
	var hp: float = e.hp * _wd.hp_mult * (_wd.boss_hp if type == _wd.boss else 1.0) * (3.0 if elite else 1.0)
	_spawn.rpc(_eid, type, pos, roundi(hp), roundi(e.dmg * _wd.dmg_mult), x)
	if type == _wd.boss: # dalganın boss'u (çağrılan hortlaklar boss türü değil)
		_boss = _by_id[_eid]
		boss_eid = _eid
		_slam_cd = SLAM_EVERY
		_summoned = false
	_dirty = true


@rpc("authority", "call_local", "reliable")
func _spawn(id: int, type: String, pos: Vector3, hp: int, dmg: int, x: Dictionary) -> void:
	var e: CharacterBody3D = EnemyScript.new()
	e.name = "E%d" % id
	e.eid = id
	e.type = type
	e.hp = hp
	e.dmg = dmg
	e.spd_k = x.spd
	e.bonus_armor = x.armor
	e.elite = x.elite
	e.money = x.money
	e.td = self
	e.position = pos
	e.rotation.y = atan2(pos.x, pos.z) # kuleye dönük
	enemies.add_child(e)
	_by_id[id] = e
	elist.append(e)


## Doğma uyarısı: noktada 1,5 sn büyüyen kırmızı halka.
@rpc("authority", "call_local", "reliable")
func _tele(pos: Vector3, r: float, t: float) -> void:
	var c := Color(1.0, 0.15, 0.1, 0.9)
	var ring := Fx.ground(r, c, Vector4(0.2, 0.1, 0.2, 1.6))
	ring.position = pos + Vector3.UP * 0.06
	get_parent().add_child(ring)
	var tw := ring.create_tween().set_parallel()
	Fx.anim(tw, ring, "shape", Vector4(0.2, 0.1, 0.2, 1.6), Vector4(0.9, 0.08, 0.2, 1.6), t)
	Fx.anim(tw, ring, "col", c, Color(c, 0.0), 0.5).set_delay(t)
	tw.chain().tween_callback(ring.queue_free)
	Sfx.play3d(Sfx.rumble, pos, 2.0)


func _send_sync() -> void:
	if multiplayer.get_peers().is_empty():
		return
	var n := elist.size()
	_ids.resize(n)
	_pos.resize(n)
	_yaw.resize(n)
	for i in n:
		var e: Node3D = elist[i]
		_ids[i] = e.eid
		_pos[i] = e.global_position
		_yaw[i] = (int(fposmod(e.rotation.y, TAU) / TAU * 128.0) & 127) | (128 if e.moving else 0) # 7 bit yön + yürüyor mu
	_sync.rpc(_ids, _pos, _yaw)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(ids: PackedInt32Array, pos: PackedVector3Array, yaw: PackedByteArray) -> void:
	for i in ids.size():
		var e: Node3D = _by_id.get(ids[i])
		if e:
			e.net_vel = ((pos[i] - e.net_pos) / SYNC_DT).limit_length(12.0) if e.net_pos != Vector3.ZERO else Vector3.ZERO
			e.net_pos = pos[i]
			e.net_yaw = (yaw[i] & 127) / 128.0 * TAU
			e.moving = yaw[i] >= 128


## Host: Kara Şövalye. Her SLAM_EVERY sn'de SLAM_T sn uyarılı yer darbesi; canı %50 altına inince bir kez 4 hortlak çağırır.
func _boss_tick(dt: float) -> void:
	if not is_instance_valid(_boss) or _boss.hp <= 0 or _boss.type != "boss":
		return
	_slam_cd -= dt
	if _slam_cd <= 0.0:
		_slam_cd = SLAM_EVERY
		var at := _boss.global_position
		_tele.rpc(at, SLAM_R / 0.9, SLAM_T) # halka 0,9 x r'ye büyür
		get_tree().create_timer(SLAM_T, false).timeout.connect(func() -> void:
			if state != "fight":
				return
			for p in plist:
				if is_instance_valid(p) and p.hp > 0 and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < SLAM_R:
					hit_player(p, roundi(SLAM_DMG * _wd.dmg_mult)))
	if not _summoned and _boss.hp * 2 < _boss.max_hp:
		_summoned = true
		_to_spawn += 4 # _spawn_now sıradan sayar
		for i in 4:
			_spawn_now("grunt", _boss.global_position + Vector3.RIGHT.rotated(Vector3.UP, i * TAU / 4.0) * 3.0)


# ---------- Hasar ----------

## Mermiyi atan makine isabeti hesaplar ve host'a bildirir (host ise doğrudan çağırır).
@rpc("any_peer", "call_local", "reliable")
func damage_enemy(enemy_name: String, dmg: int, crit: bool) -> void:
	if multiplayer.is_server():
		var e: Node3D = _by_id.get(enemy_name.trim_prefix("E").to_int())
		if e:
			damage(e, dmg, crit, 0, _sender())


## Yavaşlatma / sersemletme (hız 0) / itme: atan makine bildirir, host uygular.
## shortcut: "vuln" (fazla hasar alma) uygulanmıyor; gerekince damage() içine çarpan eklenir.
@rpc("any_peer", "call_local", "reliable")
func effect_enemy(enemy_name: String, fx: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var e: Node3D = _by_id.get(enemy_name.trim_prefix("E").to_int())
	if e == null or e.hp <= 0:
		return
	if fx.has("stun"):
		e.slow_k = 0.0
		e.slow_t = minf(float(fx.stun), 5.0)
	elif fx.has("slow"):
		e.slow_k = clampf(float(fx.slow[0]), 0.0, 1.0)
		e.slow_t = minf(float(fx.slow[1]), 8.0)
	if fx.get("knock") is Vector3:
		e.move_and_collide((fx.knock as Vector3).limit_length(12.0) * Vector3(0.25, 0, 0.25))


## Host: zırhı düşer, canı yayar, ölümde ödülü havuza ekler. n = -1: kendini patlattı (ödül yok).
func damage(e: Node3D, dmg: int, crit: bool, n := 0, by := 0) -> void:
	if e.hp <= 0 or state != "fight":
		return
	if n == 0:
		n = maxi(dmg - e.armor, ceili(dmg * 0.4)) # zırh hasarın en fazla %60'ını keser: hızlı silahlar geç dalgada da işe yarar
	var hp := maxi(e.hp - maxi(n, 0), 0) if n > 0 else 0
	var was: int = e.hp # _hit apply_hit'te e.hp'yi düşürür
	_hit.rpc(e.eid, hp, n, crit)
	if n > 0:
		_stat(by, "dmg", mini(n, was))
		_stat(by, "crits", int(crit))
	if hp > 0:
		return
	if e.eid == boss_eid:
		boss_eid = 0
	if n > 0:
		kills += 1
		_stat(by, "kills")
		money += e.money
		_add_xp(e.d.xp)
		var id := Balance.roll_drop(randf(), e.elite)
		if id != "":
			drop(e.global_position, id)
	_dirty = true


@rpc("authority", "call_local", "reliable")
func _hit(id: int, hp: int, n: int, crit: bool) -> void:
	var e: Node3D = _by_id.get(id)
	if e == null:
		return
	if hp <= 0:
		_by_id.erase(id)
		elist.erase(e)
	e.apply_hit(hp, n, crit)


## Vuruş anı görseli (animasyon, tükürük). Kaybolursa oyun bozulmaz: güvenilmez.
@rpc("authority", "call_local", "unreliable")
func enemy_fx(id: int, pos: Vector3) -> void:
	var e: Node3D = _by_id.get(id)
	if e:
		e.attack_fx(pos)


func hurt_tower(dmg: int) -> void:
	if state != "fight":
		return
	tower_hp = maxi(tower_hp - dmg, 0)
	if tower_hp == 0:
		state = "lost"
		_state_t = 0.0
		_finish(false)
		_send_sync()
	_dirty = true


## Yaratığın oyuncuya vuruşu: B'nin td_hit rpc'si (zırh statı orada); yoksa yerel oyuncuda eski take_hit.
func hit_player(p: Node, dmg: int) -> void:
	if not _to_owner(p, "td_hit", [dmg]) and is_instance_valid(p) and p.is_multiplayer_authority():
		p.take_hit(dmg)


## Uzaktan atış: t sn sonra oyuncu hâlâ nişan alınan yerdeyse isabet (yana kaçan kurtulur).
func delayed_hit(p: Node, at: Vector3, dmg: int, t: float) -> void:
	get_tree().create_timer(t, false).timeout.connect(func() -> void:
		if is_instance_valid(p) and p.hp > 0 and p.global_position.distance_to(at) < 1.6:
			hit_player(p, dmg))


## Patlayan yaratık hedefe vardı: kuleye tam, yapılara tam, oyunculara yarı hasar; kendisi ödülsüz ölür.
func explode(e: Node3D) -> void:
	var r: float = e.d.explode
	var at := e.global_position
	if Vector2(at.x, at.z).length() < r + TowerScript.R:
		hurt_tower(e.dmg)
	for b in builds.get_children():
		if b.hp > 0 and b.global_position.distance_to(at) < r + 1.0:
			hurt_build(b, e.dmg)
	for p in plist:
		if is_instance_valid(p) and p.hp > 0 and p.global_position.distance_to(at) < r:
			hit_player(p, e.dmg / 2)
	damage(e, 0, false, -1)


# ---------- Hazır oyu, mağaza, yapılar ----------

func ready_up() -> void:
	if multiplayer.is_server():
		_req_ready()
	else:
		_req_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _req_ready() -> void:
	if multiplayer.is_server() and state == "break":
		ready_votes[_sender()] = true
		_dirty = true


## Çağıranın envanterine 1 yapı. Yerelde ön kontrol (para, yer), sonra host parayı düşüp add_item'ı çağırır.
func buy(id: String) -> bool:
	var d := Balance.shop(id)
	var me := _local_player()
	if d.is_empty() or money < d.price or me == null or not me.has_method("add_item") or not _has_room(me, id):
		return false
	if multiplayer.is_server():
		_req_buy(id)
	else:
		_req_buy.rpc_id(1, id)
	return true


## Yapı slotlarında (4–5) boş yer ya da aynı yapının yığını var mı? (inv: B'nin sözleşmedeki dizisi.)
func _has_room(me: Node, id: String) -> bool:
	var inv = me.get("inv")
	if not (inv is Array) or inv.size() < 5:
		return true # bilinmiyor: add_item karar versin
	for i in [3, 4]:
		var s: Dictionary = inv[i]
		if s.is_empty() or (s.get("kind") == "build" and s.get("id") == id):
			return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func _req_buy(id: String) -> void:
	var d := Balance.shop(id)
	if not multiplayer.is_server() or d.is_empty() or money < d.price or state == "won" or state == "lost":
		return
	var p := _players().get_node_or_null(str(_sender()))
	if _to_owner(p, "add_item", [{"kind": "build", "id": id}]):
		money -= d.price
		_dirty = true


## Yerel ön kontrol: harita içi, zeminde, kuleye >= 3 m, başka yapıya >= 1,5 m, yapı sınırı dolmamış.
func can_place(id: String, pos: Vector3) -> bool:
	if Balance.shop(id).is_empty() or state == "won" or state == "lost" or builds.get_child_count() >= Balance.MAX_BUILDS:
		return false
	if absf(pos.x) > HALF - 1.5 or absf(pos.z) > HALF - 1.5 or absf(pos.y) > 1.0 or Vector2(pos.x, pos.z).length() < 3.0:
		return false
	for b in builds.get_children():
		if b.hp > 0 and Vector2(b.position.x - pos.x, b.position.z - pos.z).length() < 1.5:
			return false
	return true


func place(id: String, pos: Vector3, yaw: float) -> void:
	if multiplayer.is_server():
		_req_place(id, pos, yaw)
	else:
		_req_place.rpc_id(1, id, pos, yaw)


@rpc("any_peer", "call_remote", "reliable")
func _req_place(id: String, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	if not can_place(id, pos): # yarış (aynı yere iki kişi): eşya boşa gitmesin, geri ver
		_to_owner(_players().get_node_or_null(str(_sender())), "add_item", [{"kind": "build", "id": id}])
		return
	_bid += 1
	_stat(_sender(), "builds")
	_place.rpc(_bid, id, Vector3(pos.x, 0, pos.z), yaw)


@rpc("authority", "call_local", "reliable")
func _place(n: int, id: String, pos: Vector3, yaw: float) -> void:
	var b: StaticBody3D = BuildScript.new()
	b.name = "B%d" % n
	b.bid = n
	b.id = id
	b.td = self
	b.position = pos
	b.rotation.y = yaw
	builds.add_child(b)


func hurt_build(b: Node3D, dmg: int) -> void:
	if b.hp > 0:
		_bhp.rpc(b.bid, maxi(b.hp - dmg, 0))


@rpc("authority", "call_local", "reliable")
func _bhp(n: int, hp: int) -> void:
	var b := builds.get_node_or_null("B%d" % n)
	if b:
		b.set_hp(hp)


@rpc("authority", "call_local", "unreliable")
func build_fx(n: int, pos: Vector3) -> void:
	var b := builds.get_node_or_null("B%d" % n)
	if b:
		b.fx(pos)


func _on_peer_left(id: int) -> void:
	if multiplayer.is_server():
		ready_votes.erase(id)
		_dirty = true
