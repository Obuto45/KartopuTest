extends SceneTree
## godot --headless --path . res://tests/audio_test.tscn
## Bus'lar, dosyasız yedek sesler, eşzamanlı sınır, ayarların kaydı.

var fails := 0


func _eq(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", msg)


func _init() -> void:
	await process_frame
	for b in ["Master", "SFX", "Music", "UI", "Ambient"]:
		_eq(AudioServer.get_bus_index(b) >= 0, "bus yok: " + b)
		if b != "Master" and AudioServer.get_bus_index(b) >= 0:
			_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(b)) == &"Master", b + " Master'a gitmiyor")

	var sfx: Node = root.get_node("Sfx")
	_eq(sfx.pick("fire", sfx.fire) == sfx.fire, "dosyasız fire yedeğe düşmedi")
	_eq(sfx.variants("weapons/pistol_fire").is_empty(), "olmayan dosya bulundu")
	sfx.weapon("pistol", "fire", Vector3.ZERO, 0.0, sfx.fire)
	sfx.weapon("pistol", "reload") # dosya ve yedek yok: sessiz, hatasız
	sfx.music("battle")
	sfx.ambient("forest")
	_eq(sfx._loops["music"].p == null, "dosyasız müzik oynuyor")
	sfx.ui("click")
	sfx.foley("step", Vector3.ZERO)

	for i in 20:
		sfx.play2d(sfx.tick)
	_eq(int(sfx._active[sfx.tick.get_instance_id()]) == sfx.MAX_VOICES, "eşzamanlı sınır: %s" % sfx._active.get(sfx.tick.get_instance_id()))
	var n := 0
	for c in sfx.get_children():
		if c is AudioStreamPlayer and c.stream == sfx.tick:
			n += 1
			_eq(c.bus == &"SFX", "bus SFX değil")
	_eq(n == sfx.MAX_VOICES, "tick oynatıcı sayısı %d" % n)

	var st: Node = root.get_node("Settings")
	var old: Dictionary = st.bus_vol.duplicate()
	st.bus_vol["music"] = 0.35
	st.apply_audio()
	_eq(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.35)) < 0.01, "apply_audio Music")
	st.save()
	var c := ConfigFile.new()
	c.load(st.PATH)
	_eq(absf(float(c.get_value("audio", "music", -1)) - 0.35) < 0.001, "kayıt dosyasında music yok")
	st.bus_vol = old
	st.save()

	print("AUDIO_TEST ", "FAIL %d" % fails if fails else "OK")
	quit(1 if fails else 0)
