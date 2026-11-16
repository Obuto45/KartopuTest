extends Node
## 52 karakterin yeteneğini tek süreçte dener: godot --headless res://tests/skills.tscn
##   A) kurban gözünden: sahte oyuncu yeteneğini bize kullanır -> can / etki / savrulma oldu mu?
##   B) atan gözünden: aynı yeteneği biz kullanırız -> kendimize etkisi, roket, duvar oldu mu?
## Not: can emme, var olmayan 2 numaralı eşe "gain" yollamaya çalışır; o tek hata satırı beklenir.

const Chars := preload("res://characters.gd")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	Net.set_char(9) # Vitrin Mankeni: pasifi yok, sıyrılma şansı sonucu bozmasın
	Net.host_local()
	main._on_start()
	await _wait(0.6)
	var me = main.players.get_node("1")
	var home: Vector3 = me.global_position
	var fwd := Vector3(0, 0, 1) # sahte oyuncudan bize doğru
	var good := 0
	for i in Chars.LIST.size():
		var c: Dictionary = Chars.LIST[i]
		var sk: Dictionary = c.sk
		Net.chars[2] = i
		var d: CharacterBody3D = load("res://player.gd").new()
		d.name = "2"
		d.set_multiplayer_authority(2)
		d.spawn_pos = home + Vector3(0, 0, -2)
		main.players.add_child(d)
		# --- A: kurban biziz
		for z in main.world.get_children(): # önceki turdan kalan etki alanları sonucu bozmasın
			if z.get_script() == load("res://zone.gd"):
				z.free()
		me.ch = Chars.LIST[9]
		me.global_position = home
		me.velocity = Vector3.ZERO
		me.rotation.y = 0.0
		me.look.rotation.x = 0.0
		me.hp = me.max_hp
		me.buffs.clear()
		me.shield_on = false
		await _wait(0.1)
		d.use_skill(d.global_position, home, fwd, 1)
		if sk.get("area", {}).get("land", false):
			d.skill_area(d.global_position, fwd)
		var seen := {}
		var vmax := 0.0
		for f in (40 if sk.has("homing") else 16):
			await _wait(0.1)
			vmax = maxf(vmax, me.velocity.length())
			for k in me.buffs:
				seen[k] = true
		var lost: int = me.max_hp - me.hp
		var hostile := sk.has("area") or sk.has("homing") or sk.has("swap")
		var a_ok: bool = not hostile or lost > 0 or not seen.is_empty() or vmax > 1.0 or me.global_position.distance_to(home) > 0.5
		if sk.get("area", {}).has("zheal"):
			a_ok = seen.has("slow")
		# --- B: atan biziz
		me.ch = c
		me.sk = sk
		me.global_position = home
		me.velocity = Vector3.ZERO
		me.hp = 50
		me.buffs.clear()
		me.shield_on = false
		me.cd = 5.0
		var r0: int = me.rocket_n
		me._use_skill()
		await _wait(0.5)
		var walls: int = main.world.get_children().filter(func(n): return str(n.name).begins_with("W1_")).size()
		var moved: float = me.global_position.distance_to(home)
		var selfish := sk.has("self") or sk.has("volley") or sk.has("walls") or sk.has("swap") or sk.has("backstab")
		var b_ok: bool = not selfish or me.hp != 50 or not me.buffs.is_empty() or moved > 0.3 or me.rocket_n > r0 \
			or walls > 0 or me.shield_on or me.cd <= 0.0
		for w in main.world.get_children():
			if str(w.name).begins_with("W1_"):
				w.free()
		if a_ok and b_ok:
			good += 1
		print("[%s] %02d %-20s %-18s | A: can-%d etki=%s hız=%.0f | B: can%+d güç=%s yol=%.1f roket=%d duvar=%d" % [
			"OK" if a_ok and b_ok else "HATA", i, c.name, c.skill_name, lost, seen.keys(), vmax,
			me.hp - 50, me.buffs.keys(), moved, me.rocket_n - r0, walls])
		main.players.remove_child(d)
		d.free()
		await _wait(0.1)
	print("SONUÇ: %d / %d yetenek çalışıyor" % [good, Chars.LIST.size()])
	get_tree().quit()
