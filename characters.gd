extends RefCounted
## Seçilebilir karakterler. Sıra = ağda gönderilen karakter numarası (değiştirirken sona ekle).
## model: varsa basit şekiller yerine bu 3D model gösterilir (model_yaw: önünü -Z'ye çeviren dönüş).
## skill: player.gd'deki _use_skill / use_skill içinde işlenir. quote: Q basınca kafa üstü balon.

const LIST := [
	{
		"name": "Keloğlan", "role": "Şanslı Kel", "color": Color(0.75, 0.32, 0.18), "look": "bald",
		"hp": 100, "speed": 1.0, "shield_cd": 8.0, "dodge": 0.15,
		"passive": "%15 şansla gelen hasar parlak kafadan seker.",
		"skill": "flash", "skill_name": "KAFA PARLATMA", "cd": 12.0,
		"skill_desc": "8 m içinde sana bakanların ekranı 1,5 sn bembeyaz olur.",
		"quote": "Gözünüz kamaşmasın!",
		"model": "res://models/keloglan.glb", "model_yaw": PI / 2, # modelin önü +X'e bakıyor
	},
	{
		"name": "Terlikli Anne", "role": "Ev Hanımı", "color": Color(0.92, 0.45, 0.62), "look": "curlers",
		"hp": 100, "speed": 1.0, "shield_cd": 8.0, "throw_mult": 1.25,
		"passive": "Ateş topları %25 daha hızlı ve uzağa gider.",
		"skill": "slipper", "skill_name": "GÜDÜMLÜ TERLİK", "cd": 8.0,
		"skill_desc": "Terlik en yakın düşmanı kovalar: 30 hasar. Kaçmak mümkün... belki.",
		"quote": "Gel buraya!",
	},
	{
		"name": "Pazarcı Abi", "role": "Semt Pazarı", "color": Color(0.28, 0.6, 0.3), "look": "cap",
		"hp": 110, "speed": 1.0, "shield_cd": 8.0,
		"passive": "110 can. Bağırdıktan sonra 4 sn ateş topları 30 hasar.",
		"skill": "pull", "skill_name": "GEL ABLA GEL", "cd": 10.0,
		"skill_desc": "8 m içindekileri kendine çeker, 10 hasar verir.",
		"quote": "Gel abla gel, domates bunlar!",
	},
	{
		"name": "Kaptan Dron", "role": "Dron Pilotu", "color": Color(0.95, 0.55, 0.15), "look": "helmet",
		"hp": 120, "speed": 1.0, "shield_cd": 8.0,
		"passive": "100 yerine 120 canla başlar.",
		"skill": "drone", "skill_name": "DRON BOMBASI", "cd": 9.0,
		"skill_desc": "Nişan noktasına (30 m) 1 sn sonra bomba düşer: 35 hasar, 3 m alan.",
		"quote": "Hedef kilitlendi!",
	},
]


static func get_char(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
