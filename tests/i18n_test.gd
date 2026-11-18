extends Node
## İngilizce yerelleştirme denetimi: en dilinde menü sayfalarını, seçim ekranlarını, ayarları ve TD arayüzünü
## (mağaza, stat paneli, bütün kart türleri, maç sonu) kurar; görünen Label / Button / OptionButton metinlerinde
## Türkçe'ye özgü harf (ç ğ ı İ ö ş ü) arar. Veri tabloları (52 karakter, silahlar, kartlar) ayrıca taranır.
## godot --headless --path . res://tests/i18n_test.tscn   ->  I18N_TEST: x/y

const Chars := preload("res://characters.gd")
const Profile := preload("res://profile.gd")
const W := preload("res://weapons.gd")
const TR_RE := "[çğıİöşüÇĞÖŞÜ]"

var re := RegEx.create_from_string(TR_RE)
var ok := 0
var total := 0
var bad := {} # yazı -> nerede (aynı hatayı bir kez yaz)
var seen := {} # aynı yazı bir kez sayılır


func _chk(text: String, where: String) -> void:
	if text.strip_edges() == "" or seen.has(text):
		return
	seen[text] = true
	total += 1
	if re.search(text) == null:
		ok += 1
	elif not bad.has(text):
		bad[text] = where


func _eq(cond: bool, what: String) -> void:
	total += 1
	if cond:
		ok += 1
	else:
		bad[what] = "denetim"


## Görünen her Control'ün ekranda çizilen (çevrilmiş) metni.
func _scan(root: Node, where: String) -> void:
	for n in root.find_children("*", "Control", true, false):
		if not (n as Control).is_visible_in_tree():
			continue
		if n is Label or n is Button:
			_chk(n.atr(n.text), where)
		if n is Control and n.tooltip_text != "":
			_chk(n.atr(n.tooltip_text), where + " (ipucu)")
		if n is OptionButton:
			for i in n.item_count:
				if not n.get_item_text(i) in ["Türkçe", "English"]: # dil adları kendi dilinde kalır
					_chk(n.atr(n.get_item_text(i)), where + " (liste)")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	Profile.use_path("user://i18n_profile.cfg") # kilitli silah / açılım satırları görünsün
	Profile.save_data({"gold": 120, "stats": {"best_match_kills": 40}})
	TranslationServer.set_locale("tr")
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(0.3)
	# Türkçe'de çevrilen pasif yazısı characters.gd ile birebir aynı olmalı (kopya kayması denetimi).
	var same := Chars.LIST.all(func(c): return main.passive_text(c) == Chars.passive_text(c))
	_eq(same, "main.passive_text != Chars.passive_text (tr)")

	TranslationServer.set_locale("en")
	main._retranslate()
	_eq(tr("BAZUKA SAVAŞI") == "BAZOOKA BUDDIES", "en.po yüklenmedi")
	for c in Chars.LIST: # 52 karakter: ad, rol, yetenek, açıklama, replik, pasif
		for k in ["name", "role", "skill_name", "skill_desc", "quote"]:
			_chk(tr(c[k]), "characters.gd %s" % k)
		_chk(main.passive_text(c), "passive_text")
	for p in ["intro", "main", "modes"]:
		main._show_page(p)
		_scan(main.ui, p)
	for m in ["arena", "td"]:
		main._pick_mode(m)
		_scan(main.ui, "lobby_" + m)
	main._open_find()
	_scan(main.ui, "find")
	main._on_lobbies([{"id": 1, "name": "Alex", "mode": "td", "diff": "hard", "n": 2}])
	_scan(main.ui, "find (liste)")
	main._on_lobbies([])
	_scan(main.ui, "find (boş)")
	main._open_growth()
	_scan(main.ui, "growth")
	main._show_page("main")
	main._open_chars()
	for i in Chars.LIST.size():
		main._show_char(i)
		_scan(main.char_wrap, "chars")
	main.char_wrap.hide()
	main._open_weapons()
	_scan(main.weapon_wrap, "weapons")
	main.weapon_wrap.hide()
	main._open_settings()
	_scan(main.settings_wrap, "settings")
	main._close_settings()
	main._on_invited("Alex", 1)
	_scan(main.invite_box, "invite")

	# TD maçı (Steam'siz tek kişilik)
	main._solo_td()
	await _wait(1.5)
	var ui = main.td_ui
	var td = get_tree().get_first_node_in_group("td")
	var me = main.players.get_node("1")
	_scan(main.hud, "td_hud")
	_scan(ui, "td_break")
	ui._open_shop()
	_scan(ui, "td_shop")
	ui.shop_wrap.hide()
	ui._toggle_inv()
	_scan(ui.inv_wrap, "td_inv")
	ui._toggle_inv()
	_eq(ui._num("armor", 0.1) == "10%", "yüzde biçimi: " + ui._num("armor", 0.1))
	var cards: Array = W.pool(me) # bütün kart türleri: stat, karakter, yeni silah, ekipman
	me.ups["bazooka:blast"] = 2
	me.ups["bazooka:reload"] = 2
	me.stats["shot_power"] = 2.0
	cards.append_array(W.pool(me).filter(func(c): return c.type in ["weapon_up", "evo"]))
	var types := {}
	for c in cards:
		var t: Array = ui.card_text(c)
		_chk(t[0] + " / " + t[1], "kart " + c.id)
		types[c.type] = true
	_eq(types.size() == 5, "kart türleri eksik: " + str(types.keys()))
	me.cards = cards.slice(0, 3)
	await _wait(0.2)
	ui.cards_at = 0
	await _wait(0.2)
	_scan(ui, "td_cards")
	me.cards = []
	td.set_physics_process(false)
	td.state = "fight"
	td.wave = 5
	td.mods = ["fast", "night", "elite"]
	await _wait(0.3)
	_scan(ui, "td_fight")
	for s in ui._mods_text(td.mods, true).split("\n"):
		_chk(s, "mods")
	_chk(ui._boss_title("ogre") + " " + ui._boss_title("boss"), "boss")
	td.state = "won"
	ui._on_summary({"won": true, "wave": 10, "difficulty": "hard", "endless": false, "mvp": 1, "players": {
		1: {"dmg": 1000, "kills": 50, "crits": 9, "builds": 3, "deaths": 0}}})
	await _wait(0.3)
	_scan(ui.end_wrap, "td_end")
	for id in Profile.QUESTS:
		_chk(main._quest_text(id), "quest " + id)

	for t in bad:
		print("TÜRKÇE KALDI [%s]: %s" % [bad[t], t.replace("\n", " | ")])
	print("I18N_TEST: %d/%d" % [ok, total])
	TranslationServer.set_locale("tr")
	Profile.use_path("")
	get_tree().quit()
