extends Node
## Önce res://audio/<ad>.ogg (+ <ad>_1.ogg, _2...) aranır; dosya yoksa açılışta koddan üretilen
## prosedürel ses (16-bit mono WAV) çalar. Dosyalar için audio/KAYNAKLAR.md.

const RATE := 22050
const MAX_VOICES := 6 # aynı sesten eşzamanlı en çok
const PITCH_VAR := 0.06
const STEP_DIST := 2.3 # iki adım arası yol (m)

var fire: AudioStreamWAV
var boom: AudioStreamWAV
var hurt: AudioStreamWAV
var whoosh: AudioStreamWAV
var shield_up: AudioStreamWAV
var shield_break: AudioStreamWAV
var thunder: AudioStreamWAV
var rumble: AudioStreamWAV
var tick: AudioStreamWAV # isabet
var kill: AudioStreamWAV # yaratık öldü
var ui_click: AudioStreamWAV
var ui_hover: AudioStreamWAV
var step: AudioStreamWAV
var jump: AudioStreamWAV
var land: AudioStreamWAV

var _names := {} # prosedürel akış -> dosya adı (audio/<ad>.ogg ile değiştirilebilir)
var _files := {} # ad -> Array[AudioStream] (önbellek; boş = dosya yok)
var _active := {} # akış kimliği -> çalan sayısı
var _loops := {} # "music"/"ambient" -> {"p": AudioStreamPlayer, "name": String}


func _ready() -> void:
	fire = _gen(0.45, func(t, n): return n * 0.5 * exp(-t * 7.0) + sin(TAU * (260.0 - 300.0 * t) * t) * 0.35 * exp(-t * 5.0), 0.35)
	boom = _gen(1.2, func(t, n): return n * 1.4 * exp(-t * 3.5) + sin(TAU * 48.0 * t) * 0.8 * exp(-t * 4.0), 0.06)
	hurt = _gen(0.2, func(t, _n): return (1.0 if fmod(t * (220.0 - 400.0 * t), 1.0) < 0.5 else -1.0) * 0.4 * exp(-t * 14.0), 1.0)
	whoosh = _gen(0.35, func(t, n): return n * 0.6 * sin(PI * t / 0.35), 0.25)
	shield_up = _gen(0.35, func(t, _n): return sin(TAU * (300.0 + 900.0 * t) * t) * 0.35 * sin(PI * t / 0.35), 1.0)
	thunder = _gen(1.6, func(t, n): return n * (1.6 * exp(-t * 16.0) + 0.7 * exp(-t * 2.2)), 0.3)
	rumble = _gen(0.5, func(t, n): return n * 1.2 * exp(-t * 5.0) + sin(TAU * 70.0 * t) * 0.4 * exp(-t * 6.0), 0.05)
	tick = _gen(0.05, func(t, _n): return sin(TAU * 1800.0 * t) * 0.35 * exp(-t * 70.0), 1.0)
	kill = _gen(0.25, func(t, n): return ((1.0 if fmod(t * (400.0 + 2000.0 * t), 1.0) < 0.5 else -1.0) * 0.22 + n * 0.25) * exp(-t * 10.0), 0.5)
	shield_break = _gen(0.4, func(t, n): return (n * 0.7 + sin(TAU * 1400.0 * t) * 0.3) * exp(-t * 9.0), 0.9)
	ui_click = _gen(0.04, func(t, _n): return sin(TAU * 900.0 * t) * 0.3 * exp(-t * 90.0), 1.0)
	ui_hover = _gen(0.025, func(t, _n): return sin(TAU * 1500.0 * t) * 0.15 * exp(-t * 120.0), 1.0)
	step = _gen(0.06, func(t, n): return n * 0.12 * exp(-t * 60.0), 0.3)
	jump = _gen(0.12, func(t, n): return n * 0.08 * sin(PI * t / 0.12), 0.2)
	land = _gen(0.1, func(t, n): return n * 0.2 * exp(-t * 35.0), 0.15)
	for n in ["fire", "boom", "hurt", "whoosh", "shield_up", "shield_break", "thunder", "rumble", "tick", "kill", "ui_click", "ui_hover"]:
		_names[get(n)] = n
	for n in ["step", "jump", "land"]:
		_names[get(n)] = "foley/" + n
	get_tree().node_added.connect(_on_node_added)


## f(t, filtrelenmiş_gürültü) -> örnek. lp: gürültü alçak geçiren katsayısı (küçük = bas).
func _gen(dur: float, f: Callable, lp: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var b := PackedByteArray()
	b.resize(n * 2)
	var noise := 0.0
	for i in n:
		noise = lerp(noise, randf_range(-1.0, 1.0), lp)
		var s: float = f.call(float(i) / RATE, noise)
		b.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = b
	return w


## audio/<ad>.ogg ve <ad>_1.ogg, _2... varyantları; yoksa boş dizi.
func variants(name: String) -> Array:
	if not _files.has(name):
		var a: Array = []
		var base := "res://audio/%s" % name
		for stem in [base] + range(1, 30).map(func(i: int) -> String: return "%s_%d" % [base, i]):
			for ext in [".ogg", ".wav", ".mp3"]:
				if ResourceLoader.exists(stem + ext):
					a.append(load(stem + ext))
					break
		_files[name] = a
	return _files[name]


## Dosya varsa rastgele varyantı, yoksa fallback.
func pick(name: String, fallback: AudioStream = null) -> AudioStream:
	var a := variants(name)
	return a.pick_random() if not a.is_empty() else fallback


func _resolve(stream: AudioStream) -> AudioStream:
	return pick(_names[stream], stream) if _names.has(stream) else stream


## false: bu sesten zaten MAX_VOICES tane çalıyor.
func _claim(p: Node, stream: AudioStream) -> bool:
	var key := stream.get_instance_id()
	if int(_active.get(key, 0)) >= MAX_VOICES:
		p.free()
		return false
	_active[key] = int(_active.get(key, 0)) + 1
	p.finished.connect(func() -> void:
		_active[key] -= 1
		p.queue_free())
	return true


func play3d(stream: AudioStream, pos: Vector3, db := 0.0, bus := &"SFX") -> void:
	var s := _resolve(stream)
	var p := AudioStreamPlayer3D.new()
	if not _claim(p, s):
		return
	p.stream = s
	p.volume_db = db
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-PITCH_VAR, PITCH_VAR)
	p.unit_size = 10.0
	p.max_distance = 90.0
	add_child(p)
	p.global_position = pos
	p.play()


func play2d(stream: AudioStream, db := 0.0, bus := &"SFX") -> void:
	var s := _resolve(stream)
	var p := AudioStreamPlayer.new()
	if not _claim(p, s):
		return
	p.stream = s
	p.volume_db = db
	p.bus = bus
	p.pitch_scale = 1.0 + randf_range(-PITCH_VAR, PITCH_VAR)
	add_child(p)
	p.play()


## Arayüz sesi: "click" / "hover" (UI bus'ı).
func ui(name: String) -> void:
	var fb = get("ui_" + name) # buy / error için prosedürel yedek yok
	var s := pick("ui_" + name, fb if fb is AudioStream else null)
	if s != null:
		play2d(s, -6.0, &"UI")


## Silah sesi: audio/weapons/<id>_<event>.ogg (event: fire, reload, empty); yoksa fallback (boş olabilir).
## pos verilmezse 2D çalar.
func weapon(id: String, event: String, pos = null, db := 0.0, fallback: AudioStream = null) -> void:
	var s := pick("weapons/%s_%s" % [id, event], fallback)
	if s == null:
		return
	if pos is Vector3:
		play3d(s, pos, db)
	else:
		play2d(s, db)


## Müzik: audio/music/<ad>.ogg, 1.5 sn çapraz geçiş, döngü; "" ya da dosya yoksa sessiz.
func music(name: String) -> void:
	_loop("music", "music/" + name if name != "" else "", &"Music", name)


## Ortam: audio/ambient/<ad>.ogg, Ambient bus'ı, döngü.
func ambient(name: String) -> void:
	_loop("ambient", "ambient/" + name if name != "" else "", &"Ambient", name)


func _loop(kind: String, file: String, bus: StringName, name: String) -> void:
	var cur: Dictionary = _loops.get(kind, {"p": null, "name": ""})
	if cur.name == name:
		return
	if cur.p != null and is_instance_valid(cur.p):
		var old: AudioStreamPlayer = cur.p
		var t := create_tween()
		t.tween_property(old, "volume_db", -60.0, 1.5)
		t.tween_callback(old.queue_free)
	var s: AudioStream = pick(file) if file != "" else null
	var p: AudioStreamPlayer = null
	if s != null:
		if "loop" in s:
			s.loop = true
		p = AudioStreamPlayer.new()
		p.stream = s
		p.bus = bus
		p.volume_db = -60.0
		add_child(p)
		p.play()
		create_tween().tween_property(p, "volume_db", 0.0, 1.5)
	_loops[kind] = {"p": p, "name": name}


## Ayak sesi olayı: "step", "jump", "land".
func foley(event: String, pos: Vector3) -> void:
	play3d(get(event), pos, -6.0)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.mouse_entered.connect(ui.bind("hover"))
		n.pressed.connect(ui.bind("click"))
