extends Node
## TD denge simülasyonu: gerçek td.gd / balance.gd / enemy.gd / build.gd ile, oyuncu ateşini sayısal modelle taklit eder.
## godot --headless --path . res://tests/balance_sim.tscn -- players=2 dps_scale=1.0 build=1
## Argümansız: players=1,2,4 dps_scale=1.0 diff=normal. Liste verilebilir (players=1,2,4 dps_scale=0.7,1.0,1.4 diff=easy,hard).
## Diğer parametreler: acc=0.7 (isabet), growth=0.1 (seviye başına hasar), spend=0.6 (molada yapıya giden para),
## seed=1, speed=16 (zaman hızı; fizik adımı 1/60 sn kalır).
## Öneri denemesi (oyun dosyasına dokunmadan): tower_hp=0 (0 = Balance), e_hp=1 / e_dmg=1 (dalga can / hasar çarpanına ek).
## Model: her oyuncu tabanca kullanır (dmg/rate, şarjör + doldurma dahil), kuleye en yakın yaratığa ateş eder;
## isabet acc olasılıkla, %5 kritik (x2); hasar td.damage_enemy -> td.damage yolundan geçer (zırh oyundaki gibi).
## Oyuncular kule çevresinde durur, yaratıklar onlara gerçekten vurur (ölür, RESPAWN_TIME sonra döner).
## Yapı kuralı (build=1): her mola başında paranın spend kadarı: önce taret (90), artan tuzak (30) / duvar (25).
## Satır: SIM n=1 wave=3 t=42.1 tower=88% enemies=14 hp=2100 lvl=4 money=210 deaths=0; koşu sonu: BALANCE_SIM: ...

const Balance := preload("res://balance.gd")
const Weapons := preload("res://weapons.gd")
const PlayerScript := preload("res://player.gd")
const WAVE_LIMIT := 600.0 # bir dalga bundan uzun sürerse (takılan yaratık) koşu "timeout" sayılır

var cfg := {"players": [1.0, 2.0, 4.0], "dps_scale": [1.0], "diff": ["normal"], "build": 1.0, "tower_hp": 0.0, "e_hp": 1.0, "e_dmg": 1.0, "acc": 0.7, "growth": 0.1,
	"spend": 0.6, "seed": 1.0, "speed": 16.0}
var gun: Dictionary = Weapons.find("pistol")
var rng := RandomNumberGenerator.new()
var main: Node
var td: Node
var n := 1
var scale := 1.0
var clock := 0.0
var t0 := 0.0
var seen := ""
var last_tower := 0
var deaths := 0
var result := ""
var wmods: Array = [] # dalganın modları (mola başında td.mods sıradaki dalgaya geçer)
var guns := {} # oyuncu -> [ateş bekleme, mermi, ölü süre]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2 or not cfg.has(kv[0]):
			print("bilinmeyen argüman: ", a)
			continue
		var vals := Array(kv[1].split(","))
		cfg[kv[0]] = vals if kv[0] == "diff" else (vals.map(func(v: String) -> float: return v.to_float()) if cfg[kv[0]] is Array else kv[1].to_float())
	main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.3).timeout
	Net.host_local()
	var sp: float = cfg.speed
	Engine.physics_ticks_per_second = roundi(60 * sp)
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = sp
	var base: float = gun.dmg * gun.mag / (gun.rate * gun.mag + gun.get("reload_empty", gun.reload))
	print("SIM_CFG %s taban_dps=%.1f etkin=%.1f (tabanca, şarjör dahil, isabet %d%%)" % [str(cfg), base, base * cfg.acc, roundi(cfg.acc * 100)])
	for df in cfg.diff:
		for pn in cfg.players:
			for sc in cfg.dps_scale:
				_start(int(pn), sc, df)
				while result == "":
					await get_tree().physics_frame
				print("BALANCE_SIM: n=%d dps_scale=%.2f diff=%s build=%d result=%s wave=%d tower=%d%% lvl=%d money=%d time=%.0f" % [n, scale,
					df, int(cfg.build), result, td.wave, roundi(100.0 * last_tower / td.tower_max), td.level, td.money, clock])
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	get_tree().quit()


## main.start_td gibi, ama tüm oyuncular yerel (yetki 1): yaratık vuruşu hepsine işler, arayüz kurulmaz.
func _start(players: int, dps_scale: float, diff: String) -> void:
	n = players
	scale = dps_scale
	seed(int(cfg.seed))
	rng.seed = int(cfg.seed)
	var consts: Dictionary = main.get_script().get_script_constant_map()
	main._clear_world()
	main._set_menu_bg(false)
	main._build_world(consts.TD_CLEAR)
	guns.clear()
	for i in n:
		var p: CharacterBody3D = PlayerScript.new()
		p.name = str(i + 1)
		p.set_multiplayer_authority(1)
		p.spawn_pos = consts.TD_SPAWNS[i]
		main.players.add_child(p)
		guns[p] = [0.0, gun.mag, 0.0]
	td = load("res://td.gd").new()
	td.name = "TD"
	td.opts = {"difficulty": diff, "endless": false}
	main.world.add_child(td)
	if cfg.tower_hp > 0.0:
		td.tower_max = int(cfg.tower_hp)
		td.tower_hp = td.tower_max
	clock = 0.0
	seen = ""
	deaths = 0
	result = ""
	last_tower = td.tower_max


func _physics_process(dt: float) -> void:
	if result != "" or td == null or not is_instance_valid(td) or not td.is_inside_tree():
		return
	clock += dt
	var s: String = td.state
	if s == "fight" or s == "lost": # mola başında onarım eklenir: dalga sonu canı onarımdan önce okunur
		last_tower = td.tower_hp
	if s != seen:
		if seen == "fight":
			_report()
		if s == "break":
			if cfg.build > 0.0:
				_build()
			td.ready_up()
		elif s == "fight": # _start_wave bu karede çalıştı; ilk doğma 1+TELE sn sonra: çarpanlar zamanında
			t0 = clock
			deaths = 0
			wmods = td.mods.duplicate()
			td._wd.hp_mult *= cfg.e_hp
			td._wd.dmg_mult *= cfg.e_dmg
		elif s == "won" or s == "lost":
			result = s
		seen = s
	if s == "fight":
		_shoot(dt)
		if clock - t0 > WAVE_LIMIT:
			_report()
			result = "timeout"


func _report() -> void:
	var wd: Dictionary = Balance.wave(td.wave, n, td.difficulty, wmods)
	var cnt := 0
	var hp := 0
	for g in wd.groups:
		cnt += g.count
		hp += g.count * roundi(Balance.ENEMIES[g.type].hp * wd.hp_mult * cfg.e_hp) # elit (x3) sayılmaz
	if wd.boss != "":
		cnt += 1
		hp += roundi(Balance.ENEMIES[wd.boss].hp * wd.hp_mult * cfg.e_hp * wd.boss_hp)
	print("SIM n=%d dps=%.2f wave=%d t=%.1f tower=%d%% enemies=%d hp=%d lvl=%d money=%d deaths=%d builds=%d mods=%s" % [n, scale, td.wave,
		clock - t0, roundi(100.0 * last_tower / td.tower_max), cnt, hp, td.level, td.money, deaths, td.builds.get_child_count(), ",".join(wmods)])


func _shoot(dt: float) -> void:
	var k: float = scale * (1.0 + cfg.growth * (td.level - 1))
	for p in guns:
		var g: Array = guns[p]
		if p.hp <= 0:
			if g[2] == 0.0:
				deaths += 1
			g[2] += dt
			if g[2] > Balance.RESPAWN_TIME + 0.5: # oyuncunun kendi dönüşü işlemezse (fare yakalı değil)
				p.respawn()
			continue
		g[2] = 0.0
		g[0] -= dt
		while g[0] <= 0.0:
			var e := _target(p.global_position)
			if e == null:
				g[0] = 0.0
				break
			g[0] += gun.rate
			g[1] -= 1
			if g[1] <= 0:
				g[1] = gun.mag
				g[0] += gun.get("reload_empty", gun.reload)
			if rng.randf() < cfg.acc:
				var crit := rng.randf() < 0.05
				td.damage_enemy(e.name, roundi(gun.dmg * k * (2.0 if crit else 1.0)), crit)


## Oyuncuya 4 m içinde saldıran varsa o (kendini savunur), yoksa kuleye en yakın canlı yaratık.
func _target(me: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in td.elist:
		if e.hp > 0:
			var at: Vector3 = e.global_position
			var d := Vector2(at.x, at.z).length_squared()
			if Vector2(at.x - me.x, at.z - me.z).length_squared() < 16.0:
				d -= 10000.0
			if d < bd:
				bd = d
				best = e
	return best


## Taretler yollar arasına (kuleye 5–8 m), tuzak ve duvarlar 8 doğma yönüne (8 / 11 m) kurulur.
func _build() -> void:
	var budget := int(td.money * cfg.spend)
	while budget >= 25:
		var id := "turret" if budget >= 90 else ("trap" if budget >= 30 else "wall")
		var spot := _spot(id)
		if spot.is_empty():
			return
		var price: int = Balance.shop(id).price
		td.money -= price
		budget -= price
		td.place(id, spot[0], spot[1])
	td._dirty = true


func _spot(id: String) -> Array:
	var rings: Array = {"turret": [5.0, 6.5, 8.0], "trap": [8.0, 9.5], "wall": [11.0, 14.0]}[id]
	var off := PI / 8 if id == "turret" else 0.0
	for r in rings:
		for k in 8:
			var a := k * PI / 4 + off
			var pos: Vector3 = Vector3(cos(a), 0, sin(a)) * r
			if td.can_place(id, pos):
				return [pos, -a - PI / 2] # duvar yola dik (yerel X teğet)
	return []
