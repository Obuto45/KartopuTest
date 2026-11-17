extends Node
## Ses dosyası yok: tüm efektler açılışta koddan üretilir (16-bit mono WAV).

const RATE := 22050

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


func play3d(stream: AudioStream, pos: Vector3, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 10.0
	p.max_distance = 90.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play2d(stream: AudioStream, db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
