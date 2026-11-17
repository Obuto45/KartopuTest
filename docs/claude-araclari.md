# Claude ve Godot araçları

Seçilen 40 repodan birbiriyle çakışmayanlar kuruldu. Kurulmadan önce Claude plugin'leri NVIDIA SkillSpector ile tarandı (statik tarama, `--no-llm`). Tarayıcının "kurma" (DO_NOT_INSTALL) dediği her bulgu tek tek okundu; hepsi örnek metin ya da savunma amaçlı kod çıktı.

## Godot eklentileri (`addons/`)

| Eklenti | Sürüm | Durum |
|---|---|---|
| `godot_ai` (hi-godot/godot-ai) | 4.4.2 | **Açık** (sadece editörde çalışır, oyunun dışa aktarımına girmez) |
| `panku_console` (Ark2000/PankuConsole) | 1.7.9 | Dosyalar kurulu, **kapalı** |
| `netfox` + `netfox.internals` (foxssake/netfox) | 1.35.3 | Dosyalar kurulu, **kapalı** |

- **godot_ai:** Bilgisayarında [uv](https://docs.astral.sh/uv/) kurulu olmalı. Godot'da **Godot AI** paneli → **Configure** ile Claude Code'a bağlanır. Anonim veri toplama varsayılan olarak açık; kapatmak için panelde **Clients & Settings → Settings → Telemetry** kutusundaki işareti kaldır.
- **PankuConsole / netfox:** Açıldıklarında oyuna autoload ekledikleri için (Panku 1, netfox 9 tane) kapalı bırakıldılar. Açmak için: **Project → Project Settings → Plugins**. netfox, ağ kodu onun rollback modeline göre yazılırsa işe yarar.

## Claude plugin'leri (`.claude/settings.json`, proje kapsamı)

Repoyu Claude Code ile açınca bu plugin'ler kurulur.

| Plugin | Repo |
|---|---|
| andrej-karpathy-skills | multica-ai/andrej-karpathy-skills |
| agent-skills | addyosmani/agent-skills |
| codebase-memory | DeusData/codebase-memory-mcp |
| commit-commands, hookify | anthropics/claude-plugins-official |
| agentic-bundle-indie-game-dev | sickn33/agentic-awesome-skills (Godot dahil 7 oyun skill'i) |
| ui-ux-pro-max | nextlevelbuilder/ui-ux-pro-max-skill (logo üretici betiği yalnızca senin API anahtarınla 3. taraf görsel servislerine bağlanır) |
| diagram-design | cathrynlavery/diagram-design |
| brag | latent-spaces/brag |
| claude-hud | jarrodwatts/claude-hud (durum çubuğu için kendi bilgisayarında bir kez `/hud` çalıştır; Node 22.18+ gerekir) |

ponytail ve caveman claude.ai hesabından zaten geliyor, burada tekrar kurulmadı.

Sadece göz atmak için eklenen pazar yerleri (hiçbir plugin'i açık değil): `claude-code-workflows` (wshobson/agents), `claude-code-skills` (alirezarezvani/claude-skills). Tek tek kurmak için `/plugin` kullan.

## Godot ajanları (Donchitos/Claude-Code-Game-Studios, MIT)

- `.claude/agents/godot-specialist.md`, `godot-gdscript-specialist.md`, `godot-shader-specialist.md`
- `.claude/rules/scene-files.md`: `.tscn`/`.tres` dosyalarını elle düzenleme kuralları
- `.claude/scripts/godot-parse-check.gd`: betiklerin yüklenip yüklenmediğini kontrol eder
- `docs/engine-reference/godot/`: Godot 4.7 API değişiklik notları (ajanlar buradan okur)

## Kurulmayanlar ve nedenleri

| # | Repo | Neden |
|---|---|---|
| 50 | steam-multiplayer-peer | GodotSteam'in `SteamMultiplayerPeer` sınıfıyla aynı isimde (`net.gd`), çakışır |
| 44 | godot-mcp | godot_ai ile aynı işi yapıyor |
| 45 | Terrain3D | Derlenmiş dosyaları bu oturumdan indirilemedi; gerekirse Godot AssetLib'den tek tıkla kurulur |
| 47 | Godot-Game-Template | Oyunun kendi menüsü zaten var |
| 41 | nakama | Ayrı sunucu gerektiriyor; Steam lobisi aynı işi görüyor |
| 1, 24, 33, 34 | Dev skill paketleri | Toptan kurulunca bağlamı şişirir ve hook'lar çakışır; 24'ten sadece oyun paketi alındı |
| 8, 5, 36 | claude-mem, graphify, planning-with-files | Hafıza için codebase-memory seçildi (veri toplamıyor) |
| 12, 14 | rtk, headroom | caveman ile aynı amaç; API trafiğini kendi proxy'lerinden geçiriyorlar |
| 22, 23 | emilkowalski/skills, hallmark | Web tasarım skill'leri; ui-ux-pro-max ile çakışır |
| 10 | archify | diagram-design ile aynı iş |
| 26 security-guidance | claude-plugins-official | Her tur sonunda ve commit'te ek Claude incelemesi başlatıyor; yerleşik `/security-review` var |
| 3, 6 | ponytail, caveman | claude.ai hesabından zaten kurulu |
| 19 | t3code | Ayrı masaüstü uygulaması |
| 37 | SkillSpector | Bir CLI aracı: `uv tool install git+https://github.com/NVIDIA/skillspector.git` |
| 13, 15, 16, 21, 30, 43 | Rehberler ve listeler | Kurulacak bir şey yok |
