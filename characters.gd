extends RefCounted
## Seçilebilir karakterler. Sıra = ağda gönderilen karakter numarası (değiştirirken sona ekle).
## skill: player.gd'deki _use_skill / use_skill içinde işlenir.

const LIST := [
	{
		"name": "Bit-7", "role": "Yapay Zeka", "color": Color(0.72, 0.78, 0.9), "look": "antenna",
		"hp": 100, "speed": 1.0, "shield_cd": 5.0, "regen": false,
		"passive": "Kalkan bekleme süresi 8 yerine 5 sn.",
		"skill": "blink", "skill_name": "IŞINLANMA", "cd": 5.0,
		"skill_desc": "Baktığın yöne 8 m ışınlanır (duvardan geçmez).",
	},
	{
		"name": "Canlı Kaan", "role": "Yayıncı", "color": Color(0.62, 0.3, 0.95), "look": "headphones",
		"hp": 100, "speed": 1.15, "shield_cd": 8.0, "regen": false,
		"passive": "%15 daha hızlı koşar.",
		"skill": "hype", "skill_name": "HYPE MODU", "cd": 14.0,
		"skill_desc": "4 sn boyunca ateş topu iki kat hızlı, koşu %30 daha hızlı.",
	},
	{
		"name": "Yeşil Eda", "role": "İklim Aktivisti", "color": Color(0.25, 0.75, 0.35), "look": "leaves",
		"hp": 100, "speed": 1.0, "shield_cd": 8.0, "regen": true,
		"passive": "3 sn hasar almazsa saniyede 4 can yeniler.",
		"skill": "wave", "skill_name": "SEL DALGASI", "cd": 10.0,
		"skill_desc": "Çevresindeki 5 m'ye 15 hasar verir ve herkesi savurur.",
	},
	{
		"name": "Kaptan Dron", "role": "Dron Pilotu", "color": Color(0.95, 0.55, 0.15), "look": "helmet",
		"hp": 120, "speed": 1.0, "shield_cd": 8.0, "regen": false,
		"passive": "100 yerine 120 canla başlar.",
		"skill": "drone", "skill_name": "DRON BOMBASI", "cd": 9.0,
		"skill_desc": "Nişan noktasına (30 m) 1 sn sonra bomba düşer: 35 hasar, 3 m alan.",
	},
]


static func get_char(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]
