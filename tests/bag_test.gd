extends Node
## Çanta: taşma, taşıma / takas kuralları (saf Weapons mantığı). Son satır: BAG_TEST: N/M
## godot --headless --path . res://tests/bag_test.tscn

const W := preload("res://weapons.gd")
var good := 0
var total := 0


func _ok(title: String, cond: bool, note := "") -> void:
	total += 1
	good += int(cond)
	print("[%s] %s %s" % ["OK" if cond else "HATA", title, note])


func _ready() -> void:
	var inv: Array = [{}, {}, {}, {}, {}]
	var bag := W.empty_bag()
	_ok("çanta 15 boş slot", bag.size() == 15 and bag.all(func(d): return d.is_empty()))
	# taşma: el 4–5 dolu, yapı çantaya
	inv[3] = {"kind": "build", "id": "wall", "count": 1, "lvl": 1}
	inv[4] = {"kind": "build", "id": "trap", "count": 1, "lvl": 1}
	var turret := {"kind": "build", "id": "turret"}
	_ok("el dolu: find_slot -1, çanta 0", W.find_slot(inv, turret) == -1 and W.bag_slot(inv, bag, turret) == 0 and W.has_room(inv, bag, turret))
	bag[0] = {"kind": "build", "id": "turret", "count": 1, "lvl": 1}
	_ok("aynı yapı çantada yığılır", W.bag_slot(inv, bag, turret) == 0)
	for i in 15:
		bag[i] = {"kind": "item", "id": "bomb%d" % i, "count": 1}
	_ok("çanta dolu: yer yok", not W.has_room(inv, bag, {"kind": "build", "id": "mine"}))
	_ok("çanta doluyken el yığını hâlâ alır", W.has_room(inv, bag, {"kind": "build", "id": "wall"}))
	# silah: elde ya da çantada olan ikinci kez alınmaz
	bag = W.empty_bag()
	inv[0] = {"kind": "weapon", "id": "pistol", "count": 1, "lvl": 3, "ammo": 7}
	_ok("elde olan silah çantaya girmez", W.bag_slot(inv, bag, {"kind": "weapon", "id": "pistol"}) == -1)
	bag[2] = {"kind": "weapon", "id": "bow", "count": 1, "lvl": 2, "ammo": 5}
	_ok("çantadaki silah ikinci kez alınmaz", W.bag_slot(inv, bag, {"kind": "weapon", "id": "bow"}) == -1)
	# taşıma kuralları
	_ok("silah çantadan boş silah slotuna (ammo/lvl korunur)", W.move_item(inv, bag, 5 + 2, 1) and inv[1].id == "bow" and inv[1].lvl == 2 and inv[1].ammo == 5 and bag[2].is_empty())
	_ok("silah yapı slotuna girmez", not W.move_item(inv, bag, 0, 3) and inv[0].id == "pistol" and inv[3].id == "wall")
	_ok("yapı silah slotuna girmez", not W.move_item(inv, bag, 3, 2) and inv[3].id == "wall")
	_ok("silah el içinde takas", W.move_item(inv, bag, 0, 1) and inv[0].id == "bow" and inv[1].id == "pistol" and inv[1].ammo == 7)
	bag[0] = {"kind": "weapon", "id": "smg", "count": 1, "lvl": 1, "ammo": 30}
	_ok("silah çanta silahıyla takas", W.move_item(inv, bag, 0, 5) and inv[0].id == "smg" and bag[0].id == "bow" and bag[0].lvl == 2)
	_ok("takas kuralı bozarsa değişmez (yapı <-> silah)", not W.move_item(inv, bag, 3, 5) and inv[3].id == "wall" and bag[0].id == "bow")
	bag[4] = {"kind": "build", "id": "wall", "count": 2, "lvl": 1}
	_ok("aynı yapı yığılır", W.move_item(inv, bag, 5 + 4, 3) and inv[3].count == 3 and bag[4].is_empty())
	_ok("boş kaynak / aynı slot / aralık dışı reddedilir", not W.move_item(inv, bag, 5 + 9, 0) and not W.move_item(inv, bag, 0, 0) and not W.move_item(inv, bag, 0, 99) and not W.move_item(inv, bag, -1, 0))
	_ok("çanta içi taşıma", W.move_item(inv, bag, 5, 5 + 7) and bag[7].id == "bow" and bag[0].is_empty())
	print("BAG_TEST: %d/%d" % [good, total])
	get_tree().quit(0 if good == total else 1)
