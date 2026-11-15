extends RefCounted
## Seçilebilir karakterler. Sıra = ağda gönderilen karakter numarası (değiştirirken sona ekle).
## model: varsa basit şekiller yerine bu 3D model gösterilir (model_yaw: önünü -Z'ye çeviren dönüş).
## rig: modele kodla takılan iskeletin eklem yerleri (rig.gd). staff: ateş asasının görünümü.
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
		"rig": {"belt": 0.055, "neck": 0.30, "shoulder": Vector2(0.10, 0.24), "elbow": Vector2(0.20, 0.14),
			"hand": Vector2(0.36, 0.185), "hip": Vector2(0.05, 0.0), "knee": Vector2(0.07, -0.23), "ankle": Vector2(0.09, -0.41)},
		"staff": "crook", # çoban değneği
	},
	{
		"name": "Terlikli Anne", "role": "Ev Hanımı", "color": Color(0.92, 0.45, 0.62), "look": "curlers",
		"hp": 100, "speed": 1.0, "shield_cd": 8.0, "throw_mult": 1.25,
		"passive": "Ateş topları %25 daha hızlı ve uzağa gider.",
		"skill": "slipper", "skill_name": "GÜDÜMLÜ TERLİK", "cd": 8.0,
		"skill_desc": "Terlik en yakın düşmanı kovalar: 30 hasar. Kaçmak mümkün... belki.",
		"quote": "Gel buraya!",
		"staff": "oklava",
	},
	{
		"name": "Pazarcı Abi", "role": "Semt Pazarı", "color": Color(0.28, 0.6, 0.3), "look": "cap",
		"hp": 110, "speed": 1.0, "shield_cd": 8.0,
		"passive": "110 can. Bağırdıktan sonra 4 sn ateş topları 30 hasar.",
		"skill": "pull", "skill_name": "GEL ABLA GEL", "cd": 10.0,
		"skill_desc": "8 m içindekileri kendine çeker, 10 hasar verir.",
		"quote": "Gel abla gel, domates bunlar!",
		"staff": "leek", # pırasa
	},
	{
		"name": "Kahvehane Dayısı", "role": "Okey Ustası", "color": Color(0.42, 0.4, 0.5), "look": "dayi",
		"hp": 100, "speed": 1.0, "shield_cd": 8.0, "sit_shield": true,
		"passive": "2 sn yerinden kıpırdamazsa kendiliğinden kalkan alır.",
		"skill": "tile", "skill_name": "TAŞ AT!", "cd": 9.0,
		"skill_desc": "Okey taşı en yakın düşmana gider, 3 kişiye kadar seker: her birine 20 hasar.",
		"quote": "Okey bende, taş at!",
		"model": "res://models/dayi.glb", "model_yaw": PI / 2,
		"rig": {"belt": -0.02, "neck": 0.265, "shoulder": Vector2(0.10, 0.21), "elbow": Vector2(0.185, 0.10),
			"hand": Vector2(0.28, -0.03), "hip": Vector2(0.055, -0.07), "knee": Vector2(0.07, -0.265), "ankle": Vector2(0.095, -0.43)},
		"staff": "cane", # baston
	},
]


static func get_char(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
