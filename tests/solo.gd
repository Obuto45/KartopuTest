extends Node
## Tek başına TD: Steam'siz, OfflineMultiplayerPeer ile maç açılıyor mu, zorluk seçeneği td.gd'ye ulaşıyor mu.

func _ready() -> void:
	var main = load("res://main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.5).timeout
	var ok := multiplayer.multiplayer_peer is OfflineMultiplayerPeer and multiplayer.is_server()
	print("offline sunucu: ", ok)
	main._solo_td()
	main._solo_start("hard") # kilitsiz seçilebilmeli
	await get_tree().create_timer(1.0).timeout
	var td = get_tree().get_first_node_in_group("td")
	print("oyuncu=", main.players.get_child_count(), " td=", td != null, " opts=", td.opts if td else null)
	print("SOLO ", "[OK]" if ok and td != null and main.players.get_child_count() == 1 and td.opts.get("difficulty") == "hard" else "[HATA]")
	get_tree().quit()
