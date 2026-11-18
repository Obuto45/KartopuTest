extends Node
## Oyun ayarları (ses, ekran, grafik kalitesi, kamera sarsıntısı). user://settings.cfg dosyasına kaydedilir.

const PATH := "user://settings.cfg"
const MODES := ["Pencere", "Tam ekran", "Kenarlıksız tam ekran"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

var volume := 0.8 # 0..1
var mode := 0 # MODES indeksi
var resolution := 0 # RESOLUTIONS indeksi
const QUALITIES := ["Düşük", "Orta", "Yüksek"]
var quality := 2 # QUALITIES indeksi: Düşük = SSAO / hacimsel sis kapalı, 2 bölmeli gölge, FXAA
var shake := 1.0 # kamera sarsıntısı çarpanı 0..1 (mide bulantısı yapanlar için)
const LANGUAGES := ["auto", "tr", "en"]
var language := "auto" # auto: sistem dili Türkçe ise tr, değilse en

signal changed # grafik kalitesi değişti: ortam (forest.gd) kendini günceller


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK: # dosya elle bozulmuş olabilir: sınırla
		volume = clampf(float(c.get_value("audio", "volume", volume)), 0.0, 1.0)
		mode = clampi(int(c.get_value("display", "mode", mode)), 0, MODES.size() - 1)
		resolution = clampi(int(c.get_value("display", "resolution", resolution)), 0, RESOLUTIONS.size() - 1)
		quality = clampi(int(c.get_value("graphics", "quality", quality)), 0, QUALITIES.size() - 1)
		shake = clampf(float(c.get_value("graphics", "shake", shake)), 0.0, 1.0)
		language = str(c.get_value("general", "language", language))
		if not language in LANGUAGES:
			language = "auto"
	apply_language()
	apply_audio()
	apply_display()
	apply_quality()


## Kenar yumuşatma burada; ışık/sis ayarlarını "changed" ile ortam uygular.
func apply_quality() -> void:
	var vp := get_tree().root
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	changed.emit()


## Kaynak dil Türkçe (msgid = Türkçe metin); İngilizce locale/en.po'dan gelir.
func apply_language() -> void:
	var l := language if language != "auto" else ("tr" if OS.get_locale_language() == "tr" else "en")
	for a in OS.get_cmdline_user_args(): # testler: -- --lang=en (ayara yazılmaz)
		if a.begins_with("--lang="):
			l = a.trim_prefix("--lang=")
	TranslationServer.set_locale(l)


func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.001)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: Vector2i = RESOLUTIONS[resolution]
			var screen := DisplayServer.screen_get_usable_rect()
			size = size.min(screen.size) # ekrandan büyük olmasın
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func save() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "volume", volume)
	c.set_value("display", "mode", mode)
	c.set_value("display", "resolution", resolution)
	c.set_value("graphics", "quality", quality)
	c.set_value("graphics", "shake", shake)
	c.set_value("general", "language", language)
	c.save(PATH)
