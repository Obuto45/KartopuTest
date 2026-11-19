extends Node
## Ağ katmanı: Steam lobi + SteamMultiplayerPeer (Valve relay), test için ENet yedeği.

signal status(msg: String)
signal lobby_changed
signal left
signal invited(from_name: String, lobby: int)
signal lobbies_found(list: Array) # [{id, name, mode, diff, n}, ...]

const APP_ID := 480 # Spacewar test App ID'si; kendi App ID'n olunca değiştir.
const LOCAL_PORT := 7777
const Profile := preload("res://profile.gd")

var steam_ok := false
var lobby_id := 0
var names := {} # peer_id -> görünen ad
var chars := {} # peer_id -> karakter numarası (characters.gd LIST sırası)
var my_char := 0
var weapons := {} # peer_id -> TD başlangıç silahı (weapons.gd LIST sırası)
var my_weapon := 0
var cosm := {} # peer_id -> {tint, title, fx} kozmetik seçimi (profile.gd COSMETICS id'leri; doğrulanmış)
var public_lobby := false # kurulacak lobi herkese açık mı
var meta := {"mode": "arena", "diff": "normal"} # lobi verisi: host main.gd'den günceller


func _ready() -> void:
	var r: Dictionary = Steam.steamInitEx(APP_ID, true)
	steam_ok = r.get("status", 1) == 0
	if steam_ok:
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.join_requested.connect(_on_join_requested)
		Steam.lobby_invite.connect(func(inviter, lobby, _game): invited.emit(Steam.getFriendPersonaName(inviter), lobby))
		Steam.lobby_match_list.connect(_on_match_list)
		Steam.lobby_chat_update.connect(func(_a, _b, _c, _d): lobby_changed.emit())
	else:
		push_warning("Steam başlatılamadı: %s" % r)
	multiplayer.peer_connected.connect(func(_id): lobby_changed.emit())
	multiplayer.peer_disconnected.connect(func(id): names.erase(id); chars.erase(id); weapons.erase(id); cosm.erase(id); lobby_changed.emit())
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): status.emit("Bağlantı başarısız."); leave())
	multiplayer.server_disconnected.connect(func(): status.emit("Host ayrıldı."); leave())


func my_name() -> String:
	return Steam.getPersonaName() if steam_ok else tr("Oyuncu")


func display_name(id: int) -> String:
	return names.get(id, tr("Oyuncu %d") % id)


## Unvan rozetiyle: "[Avcı] Ad".
func tagged_name(id: int) -> String:
	var t := Profile.cosm_title(cosm_of(id).title)
	return display_name(id) if t == "" else "[%s] %s" % [tr(t), display_name(id)]


## Oyuncunun kozmetik seçimi; kendimiz için profilden (çevrimdışı / lobi öncesi de çalışsın).
func cosm_of(id: int) -> Dictionary:
	if id == multiplayer.get_unique_id():
		return Profile.cosm_sel()
	return cosm.get(id, Profile.cosm_clean(null))


func online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


# --- Steam ---

func host_steam() -> void:
	if not steam_ok:
		status.emit("Steam açık değil / başlatılamadı.")
		return
	leave()
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC if public_lobby else Steam.LOBBY_TYPE_FRIENDS_ONLY, 4)
	status.emit("Lobi kuruluyor...")


## Çevrimiçi Steam arkadaşları: [[steam_id, ad, lobi_id (yoksa 0)], ...]
func online_friends() -> Array:
	var out := []
	if not steam_ok:
		return out
	for i in Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE):
		var id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		if Steam.getFriendPersonaState(id) != Steam.PERSONA_STATE_OFFLINE:
			var g: Dictionary = Steam.getFriendGamePlayed(id)
			var lobby: int = g.get("lobby", 0) if g.get("id", 0) == APP_ID else 0
			out.append([id, Steam.getFriendPersonaName(id), lobby])
	return out


func join_lobby(id: int) -> void:
	_on_join_requested(id, 0)


## Overlay gerektirmez: davet Steam sohbetine düşer, arkadaş "Katıl" der.
func invite_friend(id: int, friend_name: String) -> void:
	if lobby_id == 0:
		status.emit("Önce Steam lobisi kur.")
		return
	if Steam.inviteUserToLobby(lobby_id, id):
		status.emit(tr("%s davet edildi. Oyunu açıkken Steam sohbetindeki daveti kabul etsin.") % friend_name)
	else:
		status.emit("Davet gönderilemedi.")


## Host: lobi listesinde görünen mod ve zorluk.
func set_meta_data(mode: String, diff: String) -> void:
	meta = {"mode": mode, "diff": diff}
	if steam_ok and lobby_id != 0 and multiplayer.is_server():
		Steam.setLobbyData(lobby_id, "mode", mode)
		Steam.setLobbyData(lobby_id, "diff", diff)


## Açık lobileri ara (yalnız aynı sürüm); sonuç lobbies_found ile gelir.
func find_lobbies() -> void:
	if not steam_ok:
		lobbies_found.emit([])
		return
	Steam.addRequestLobbyListStringFilter("ver", Updater.version(), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListFilterSlotsAvailable(1)
	Steam.requestLobbyList()


func _on_match_list(lobbies: Array) -> void:
	var out := []
	for id in lobbies:
		out.append({"id": id, "name": Steam.getLobbyData(id, "name"), "mode": Steam.getLobbyData(id, "mode"),
			"diff": Steam.getLobbyData(id, "diff"), "n": Steam.getNumLobbyMembers(id)})
	lobbies_found.emit(out)


## Steam'siz tek kişilik oyun: OfflineMultiplayerPeer zaten sunucu (id 1), call_local rpc çalışır.
func solo() -> void:
	names[1] = my_name()
	chars[1] = my_char
	weapons[1] = my_weapon


func _new_steam_peer() -> SteamMultiplayerPeer:
	var peer := SteamMultiplayerPeer.new()
	peer.set_server_relay(true) # Valve relay: NAT sorunsuz, düşük ping
	peer.set_no_nagle(true) # paketleri bekletmeden gönder
	return peer


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		status.emit(tr("Lobi kurulamadı (kod %d).") % result)
		return
	lobby_id = id
	Steam.setLobbyData(id, "name", tr("%s lobisi") % my_name())
	Steam.setLobbyData(id, "ver", Updater.version())
	set_meta_data(meta.mode, meta.diff)
	var peer := _new_steam_peer()
	peer.host_with_lobby(id)
	multiplayer.multiplayer_peer = peer
	_register_self()
	status.emit("Lobi hazır. 'Arkadaş Davet Et' ile çağır.")


func _on_join_requested(id: int, _friend: int) -> void:
	leave()
	Steam.joinLobby(id)
	status.emit("Lobiye katılınıyor...")


func _on_lobby_joined(id: int, _perm: int, _locked: bool, response: int) -> void:
	if response != 1:
		status.emit(tr("Lobiye katılınamadı (kod %d).") % response)
		return
	if Steam.getLobbyOwner(id) == Steam.getSteamID():
		return # kendi lobimiz, host tarafı zaten kuruldu
	lobby_id = id
	var peer := _new_steam_peer()
	peer.connect_to_lobby(id)
	multiplayer.multiplayer_peer = peer
	status.emit("Hosta bağlanılıyor...")


# --- Tek PC testi (ENet) ---

func host_local() -> void:
	leave()
	var p := ENetMultiplayerPeer.new()
	if p.create_server(LOCAL_PORT, 4) != OK:
		status.emit(tr("Port %d açılamadı.") % LOCAL_PORT)
		return
	multiplayer.multiplayer_peer = p
	_register_self()
	status.emit(tr("Yerel host açık (port %d).") % LOCAL_PORT)


func join_local() -> void:
	leave()
	var p := ENetMultiplayerPeer.new()
	if p.create_client("127.0.0.1", LOCAL_PORT) != OK:
		status.emit("İstemci oluşturulamadı.")
		return
	multiplayer.multiplayer_peer = p
	status.emit("Yerel hosta bağlanılıyor...")


# --- Ortak ---

func leave() -> void:
	if steam_ok and lobby_id != 0:
		Steam.leaveLobby(lobby_id)
	lobby_id = 0
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	names.clear()
	chars.clear()
	weapons.clear()
	cosm.clear()
	left.emit()


func _on_connected() -> void:
	_register_self()
	status.emit("Bağlandı. Hostun oyunu başlatmasını bekle.")


func _register_self() -> void:
	var n := my_name()
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		n += " #%d" % (multiplayer.get_unique_id() % 1000) # aynı PC'de iki pencere ayırt edilsin
	if multiplayer.is_server():
		names[1] = n
		chars[1] = my_char
		weapons[1] = my_weapon
		cosm[1] = Profile.cosm_sel()
		lobby_changed.emit()
	else:
		register_name.rpc_id(1, n, my_char)
		register_weapon.rpc_id(1, my_weapon)
		register_cosm.rpc_id(1, Profile.cosm_sel())


## Karakter değişince lobiye bildir (bağlı değilsek sadece hatırla).
func set_char(c: int) -> void:
	my_char = c
	if not online():
		return
	if multiplayer.is_server():
		chars[1] = c
		sync_names.rpc(names, chars)
		lobby_changed.emit()
	else:
		register_char.rpc_id(1, c)


@rpc("any_peer", "reliable")
func register_name(n: String, c: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	names[id] = n
	chars[id] = c
	sync_names.rpc(names, chars)
	lobby_changed.emit()


@rpc("any_peer", "reliable")
func register_char(c: int) -> void:
	chars[multiplayer.get_remote_sender_id()] = c
	sync_names.rpc(names, chars)
	lobby_changed.emit()


@rpc("authority", "reliable")
func sync_names(d: Dictionary, c: Dictionary) -> void:
	names = d
	chars = c
	lobby_changed.emit()


## TD silah seçimi: karakter seçimiyle aynı yol, ayrı rpc'ler (register_name imzası değişmesin).
func set_weapon(i: int) -> void:
	my_weapon = i
	if not online():
		return
	if multiplayer.is_server():
		weapons[1] = i
		sync_weapons.rpc(weapons)
		lobby_changed.emit()
	else:
		register_weapon.rpc_id(1, i)


@rpc("any_peer", "reliable")
func register_weapon(i: int) -> void:
	weapons[multiplayer.get_remote_sender_id()] = i
	sync_weapons.rpc(weapons)
	lobby_changed.emit()


@rpc("authority", "reliable")
func sync_weapons(w: Dictionary) -> void:
	weapons = w
	lobby_changed.emit()


## Kozmetikler: gelen veri katalogla doğrulanır, bilinmeyen id yok sayılır.
@rpc("any_peer", "reliable")
func register_cosm(c: Dictionary) -> void:
	cosm[multiplayer.get_remote_sender_id()] = Profile.cosm_clean(c)
	sync_cosm.rpc(cosm)
	lobby_changed.emit()


@rpc("authority", "reliable")
func sync_cosm(d: Dictionary) -> void:
	cosm.clear()
	for k in d:
		if k is int:
			cosm[k] = Profile.cosm_clean(d[k])
	lobby_changed.emit()
