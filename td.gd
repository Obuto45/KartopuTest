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

const Balance := preload("res://balance.gd")
const EnemyScript := preload("res://enemy.gd")
const BuildScript := preload("res://build.gd")
const TowerScript := preload("res://tower.gd")
const Fx := preload("res://explosion.gd")
const HALF := 30.0 # forest.gd HALF
const SYNC_DT := 1.0 / 12.0 # yaratık konum yayını
const STATE_DT := 0.1 # durum yayını en sık bu aralıkla (kule dövülürken kare başı rpc gitmesin)
const TELE := 1.5 # doğma uyarısı (yerde kırmızı halka) ile ilk yaratık arası

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
	_n = _count_players()
	tower_max = Balance.TOWER_HP
	tower_hp = tower_max
	_seen_hp = tower_hp
	money = Balance.START_MONEY * _n
	xp_next = Balance.xp_for(1, _n)
	time_left = Balance.BREAK_TIME
	multiplayer.peer_disconnected.connect(_on_peer_left)


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
				_tele.rpc(q[2])
			else:
				_spawn_now(q[1], q[2])
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
		_state.rpc([wave, state, time_left, money, level, xp, xp_next, tower_hp, enemies_left, kills, ready_votes])


# ---------- Durum yayını (her makinede) ----------

@rpc("authority", "call_local", "reliable")
func _state(a: Array) -> void:
	wave = a[0]; state = a[1]; time_left = a[2]; money = a[3]; level = a[4]; xp = a[5]; xp_next = a[6]
	tower_hp = a[7]; enemies_left = a[8]; kills = a[9]; ready_votes = a[10]
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
	_wd = Balance.wave(wave, _n)
	var batches := []
	for g in _wd.groups:
		var left: int = g.count
		while left > 0:
			batches.append([g.type, mini(left, Balance.BATCH)])
			left -= Balance.BATCH
	batches.shuffle()
	if _wd.boss != "": # boss dalganın ortasında
		batches.insert(batches.size() / 2, [_wd.boss, 1])
	var pts := Balance.SPAWN_POINTS.size()
	var first := randi() % pts
	var open := mini(pts, 2 + wave)
	var gap := minf(3.5, Balance.SPAWN_SPAN / batches.size())
	_queue.clear()
	_to_spawn = 0
	var t := 1.0
	for b in batches:
		var sp: Vector3 = Balance.SPAWN_POINTS[(first + randi() % open) % pts]
		_queue.append([t, "", sp])
		for i in b[1]:
			_queue.append([t + TELE + i * 0.45, b[0], sp + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))])
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
	if wave >= Balance.WAVE_COUNT:
		state = "won"
	else:
		state = "break"
		time_left = Balance.BREAK_TIME
		money += Balance.wave_bonus(wave, _n)
		tower_hp = mini(tower_max, tower_hp + roundi(tower_max * Balance.TOWER_REPAIR))
	_dirty = true
	_state_t = 0.0


func _spawn_now(type: String, pos: Vector3) -> void:
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
	_spawn.rpc(_eid, type, pos, roundi(e.hp * _wd.hp_mult * (_wd.boss_hp if type == _wd.boss else 1.0)), roundi(e.dmg * _wd.dmg_mult))
	_dirty = true


@rpc("authority", "call_local", "reliable")
func _spawn(id: int, type: String, pos: Vector3, hp: int, dmg: int) -> void:
	var e: CharacterBody3D = EnemyScript.new()
	e.name = "E%d" % id
	e.eid = id
	e.type = type
	e.hp = hp
	e.dmg = dmg
	e.td = self
	e.position = pos
	e.rotation.y = atan2(pos.x, pos.z) # kuleye dönük
	enemies.add_child(e)
	_by_id[id] = e
	elist.append(e)


## Doğma uyarısı: noktada 1,5 sn büyüyen kırmızı halka.
@rpc("authority", "call_local", "reliable")
func _tele(pos: Vector3) -> void:
	var c := Color(1.0, 0.15, 0.1, 0.9)
	var ring := Fx.ground(3.2, c, Vector4(0.2, 0.1, 0.2, 1.6))
	ring.position = pos + Vector3.UP * 0.06
	get_parent().add_child(ring)
	var tw := ring.create_tween().set_parallel()
	Fx.anim(tw, ring, "shape", Vector4(0.2, 0.1, 0.2, 1.6), Vector4(0.9, 0.08, 0.2, 1.6), TELE)
	Fx.anim(tw, ring, "col", c, Color(c, 0.0), 0.5).set_delay(TELE)
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


# ---------- Hasar ----------

## Mermiyi atan makine isabeti hesaplar ve host'a bildirir (host ise doğrudan çağırır).
@rpc("any_peer", "call_local", "reliable")
func damage_enemy(enemy_name: String, dmg: int, crit: bool) -> void:
	if multiplayer.is_server():
		var e: Node3D = _by_id.get(enemy_name.trim_prefix("E").to_int())
		if e:
			damage(e, dmg, crit)


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
func damage(e: Node3D, dmg: int, crit: bool, n := 0) -> void:
	if e.hp <= 0 or state != "fight":
		return
	if n == 0:
		n = maxi(dmg - e.armor, ceili(dmg * 0.4)) # zırh hasarın en fazla %60'ını keser: hızlı silahlar geç dalgada da işe yarar
	var hp := maxi(e.hp - maxi(n, 0), 0) if n > 0 else 0
	_hit.rpc(e.eid, hp, n, crit)
	if hp > 0:
		return
	if n > 0:
		kills += 1
		money += e.d.money
		xp += e.d.xp
		while xp >= xp_next: # taşan XP sonraki seviyeye kalır
			xp -= xp_next
			level += 1
			xp_next = Balance.xp_for(level, _n)
			for p in plist:
				_to_owner(p, "level_up", [])
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
